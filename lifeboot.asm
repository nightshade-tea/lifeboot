bits 16
org 7c00h

; =============================================================================

; settings --------------------------------------------------------------------

%define DEAD ' '            ; char to represent a dead cell
%define ALIVE '.'           ; char to represent an alive cell
%define PRINT_COLOR 07h     ; grey on black
%define ITER_LIM 500        ; reset the simulation after this # iterations

; constants -------------------------------------------------------------------

%define COLS 80
%define ROWS 25
%define VGAPGSZ 1000h       ; (bytes)

; memory layout ---------------------------------------------------------------

%define ORG 7c00h
%define VGA 0b8000h
%define DAT ORG + 512

; static variables ------------------------------------------------------------

%define xss DAT             ; xs() state (word)
%define currvgapg DAT + 2   ; current vga page near pointer (word)
%define iter DAT + 4        ; current iteration # (word)

; =============================================================================

; entry point -----------------------------------------------------------------

entry:

; initialize segment registers
mov ax, VGA >> 4
mov es, ax                  ; es:0 -> video memory

xor ax, ax
mov ds, ax                  ; ds = 0
mov ss, ax                  ; ss = 0

; set stack pointers
mov bp, ORG
mov sp, bp

; clear direction flag
cld

; disable cursor
mov ch, 3fh                 ; cursor start and options
mov ah, 01h                 ; set text-mode cursor shape
int 10h                     ; bios video services

; initialize xss
.set_xss:
    mov ah, 00h             ; get system time
    int 1ah                 ; bios time services
                            ; cx:dx = # clock ticks since midnight
    or dx, dx
    jz .set_xss             ; wait for something meaningful

mov [xss], dx

; initialize currvgapg
mov word [currvgapg], 0

; start simulation from random state ------------------------------------------

start:

call init_grid
mov word [iter], 0

.next_state:

    call vsync_wait
    call update_grid

    call vsync_wait
    call flip_vgapg

    inc word [iter]
    cmp word [iter], ITER_LIM
    jl .next_state

jmp start                   ; reset

; =============================================================================

; functions -------------------------------------------------------------------

; vsync_wait() - wait for display to enter the next retrace cycle -------------

; clobbers al, dx

vsync_wait:

mov dx, 3dah                ; input status #1 register

.wait_retrace_end:
    in al, dx
    test al, 08h            ; vertical retrace bit
    jnz .wait_retrace_end

.wait_retrace_start:
    in al, dx
    test al, 08h
    jz .wait_retrace_start

ret

; xs() - xorshift pseudorandom number generator -------------------------------

; output:
; [xss]     = updated state
; bx        = [xss]

; clobbers bx, dx

xs:

mov bx, [xss]
mov dx, bx

shl dx, 1                   ; dx = xss << 1
xor bx, dx                  ; bx = xss ^ (xss << 1)
mov dx, bx

shr dx, 3                   ; dx = xss' >> 3
xor bx, dx                  ; bx = xss' ^ (xss' >> 3)
mov dx, bx

shl dx, 10                  ; dx = xss'' << 10
xor bx, dx                  ; bx = xss'' ^ (xss'' << 10)
mov [xss], bx

ret

; init_grid() - initialize grid cells randomly --------------------------------

; clobbers ax, bx, cx, dx, di

init_grid:

mov ah, PRINT_COLOR         ; ah = color attribute
mov di, [currvgapg]         ; es:di -> grid start
mov cx, COLS * ROWS         ; for each cell

.write_cell:                ; do {
    call xs                 ;     bx = random value
    mov al, DEAD            ;     al = DEAD (likely)

    test bx, 0b11

    jnz  .nz                ;     if (bx % 4 == 0)
    mov al, ALIVE           ;         al = ALIVE

.nz:
    stosw                   ;     [es:di] = ax, di += 2

    loop .write_cell        ; } while (--cx)

ret

; flip_vgapg() - flip active display page -------------------------------------

; output:
; [currvgapg] ^= VGAPGSZ

; clobbers ax

flip_vgapg:

xor word [currvgapg], VGAPGSZ

setnz al                    ; al = !(currvgapg == 0)
mov ah, 05h                 ; select active display page
int 10h                     ; bios video services

ret

; alive_neighbours() - get number of alive adjacent cells ---------------------

; input:
; es:si     -> current grid
; cx        -> cell index

; output:
; ax = # alive neighbours

; clobbers ax, bx, dx

alive_neighbours:
enter 5, 0

; [bp - 1]: row
; [bp - 2]: col
; [bp - 3]: neighbours
; [bp - 4]: i
; [bp - 5]: j

mov ax, cx                  ; ax = idx
mov bl, COLS                ; bl = COLS
div bl                      ; al = idx / COLS, ah = idx % COLS

mov [bp - 1], al            ; row = idx / COLS
mov [bp - 2], ah            ; row = idx % COLS
mov byte [bp - 3], 0        ; neighbours = 0

mov byte [bp - 4], -1       ; i = -1
.i:                         ; do {

    mov byte [bp - 5], -1           ; j = -1
.j:                                 ; do {

        mov al, [bp - 4]
        or al, [bp - 5]                 ; if (!i && !j)
        jz .continue                    ;     continue

        mov al, [bp - 1]
        add al, [bp - 4]                ; al = row + i

        cmp al, 0                       ; if (row + i < 0)
        jl .continue                    ;     continue

        cmp al, ROWS                    ; if (row + i >= ROWS)
        jge .continue                   ;     continue

        mov ah, [bp - 2]
        add ah, [bp - 5]                ; ah = col + j

        cmp ah, 0                       ; if (col + j < 0)
        jl .continue                    ;     continue

        cmp ah, COLS                    ; if (col + j >= COLS)
        jge .continue                   ;     continue

        movzx bx, ah                    ; bx = col + j

        mov ah, COLS
        mul ah                          ; ax = (row + i) * COLS

        add bx, ax                      ; bx = cell index
        shl bx, 1                       ; bx = grid offset

        mov dx, [es:si + bx]            ; dl = cell state

        cmp dl, ALIVE                   ; if (!ALIVE)
        jne .continue                   ;     continue

        inc byte [bp - 3]               ; neighbours++

.continue:
        inc byte [bp - 5]
        cmp byte [bp - 5], 1
        jle .j                      ; } while (++j <= 1)

    inc byte [bp - 4]
    cmp byte [bp - 4], 1
    jle .i                  ; } while (++i <= 1)

movzx ax, byte [bp - 3]     ; ax = # alive neighbours

leave
ret

; update_cell() - write next cell state ---------------------------------------

; input:
; es:si     -> current grid
; es:di     -> next grid
; cx        -> cell index

; output:
; [es:di + cx * 2] = updated cell state

; clobbers ax, bx, dx

update_cell:

call alive_neighbours       ; ax = # alive neighbours

mov bx, cx
shl bx, 1

mov dx, [es:si + bx]        ; dl = cell current state

cmp dl, ALIVE               ; if (ALIVE) {
jne .else

shr ax, 1
xor ax, 1                   ;     if (n != 2 || n != 3)
jnz .dead                   ;         return DEAD (likely)

jmp .alive                  ;     return ALIVE

.else:                      ; }

cmp ax, 3                   ; if (n != 3)
jne .dead                   ;     return DEAD

.alive:                     ; return ALIVE
mov dl, ALIVE
jmp .write

.dead:
mov dl, DEAD

.write:
mov [es:di + bx], dx

ret

; update_grid() - write next grid (inactive vga page) -------------------------

; clobbers di, si, ax, bx, cx, dx

update_grid:

mov si, [currvgapg]         ; es:si -> current page

mov di, VGAPGSZ
xor di, si                  ; es:di -> next page

mov cx, COLS * ROWS - 1     ; for each cell (index)

.update_loop:               ; do {

    call update_cell

    dec cx
    jns .update_loop        ; } while (--cx > 0)

ret

; halt() - stop program execution ---------------------------------------------

halt:

cli                         ; disable interrupts
hlt
jmp halt

; =============================================================================

times 510 - ($ - $$) db 0   ; fill remaining bytes with zeroes
dw 0aa55h                   ; mbr magic byte
