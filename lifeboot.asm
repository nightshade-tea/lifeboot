bits 16
org 0x7c00

; =============================================================================

; settings --------------------------------------------------------------------

%define DEAD ' '            ; char to represent a dead cell
%define ALIVE '#'           ; char to represent an alive cell
%define PRINT_COLOR 0x07    ; grey on black
%define WAIT_DELAY 0x02     ; 0.131072 seconds

; constants -------------------------------------------------------------------

%define COLS 80
%define ROWS 25
%define VGAPGSZ (COLS * ROWS * 2 + 96)  ; why 96 ??????

; memory layout ---------------------------------------------------------------

%define ORG 0x7c00
%define VGA 0xb8000
%define DAT ORG + 512

; static variables ------------------------------------------------------------

%define xss DAT             ; xs() state (word)
%define currvgapg DAT + 2   ; current vga page near pointer (word)

; =============================================================================

; entry point -----------------------------------------------------------------

; initialize segment registers
mov ax, VGA >> 4
mov es, ax

xor ax, ax
mov ds, ax
mov ss, ax

; set stack pointers
mov bp, ORG
mov sp, bp

; clear direction flag
cld

; disable cursor
mov ch, 0x3f                ; cursor start and options
mov ah, 0x01                ; set text-mode cursor shape
int 0x10                    ; video services

; initialize xss

set_xss_seed:

mov ah, 0x00                ; get
int 0x1a                    ;  system time

cmp dx, 0
je set_xss_seed             ; if seed is 0, xs wont work properly

mov [xss], dx               ; cx:dx = number of clock ticks since midnight

; initialize currvgapg
mov word [currvgapg], 0

; start simulation from random state ------------------------------------------

start:

call init_grid

; apply game of life's rules to determine the next state ----------------------

next_state:

call write_next_vga_page
call wait_keypress
call flip_vga_page

jmp next_state

; =============================================================================

; functions -------------------------------------------------------------------

; delay() - suspend program execution temporarily -----------------------------

; clobbers ah, cx, dx

delay:

mov cx, WAIT_DELAY          ; cx:dx = interval in microseconds
mov dx, 0

mov ah, 0x86
int 0x15                    ; wait

ret

; wait_keypress() - wait for any keypress -------------------------------------

; clobbers: ax

wait_keypress:

mov ah, 0x00        ; read key press
int 0x16            ; keyboard services

ret

; vsync_wait() - wait for display to enter the next VBlank cycle --------------

; clobbers ax, dx

vsync_wait:

mov dx, 0x3da               ; input status #1 register

.wait_on:
    in al, dx
    test al, 0x08           ; vertical retrace bit
    jnz .wait_on

.wait_off:
    in al, dx
    test al, 0x08
    jz .wait_off

ret

; xs() - xorshift pseudorandom number generator -------------------------------

; output:
; [xss]     = updated state

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
    call xs                 ;     [xss] = rand
    mov al, DEAD            ;     al = DEAD (likely)

    test word [xss], 0b11

    jnz  .nz                ;     if ([xss] % 4 == 0)
    mov al, ALIVE           ;         al = ALIVE

.nz:
    stosw                   ;     [es:di] = ax ; di += 2

    loop .write_cell        ; } while (--cx)

ret

; flip_vga_page() - flip active display page ----------------------------------

; clobbers ax, dx

flip_vga_page:

call vsync_wait

xor word [currvgapg], VGAPGSZ   ; flip currvgapg
setnz al                        ; al = !(currvgapg == 0)

mov ah, 0x05                ; select active display page
int 0x10                    ; video services

ret

; alive_neighbours() ----------------------------------------------------------

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
div bl                      ; al = idx / COLS ; ah = idx % COLS

mov [bp - 1], al            ; row = idx / COLS
mov [bp - 2], ah            ; row = idx % COLS
mov byte [bp - 3], 0        ; neighbours = 0

mov byte [bp - 4], -1       ; i = -1
.i:                         ; do {

    mov byte [bp - 5], -1           ; j = -1
.j:                                 ; do {

        mov al, [bp - 4]
        or al, [bp - 5]
        jz .continue                    ; if (!i && !j) continue

        mov al, [bp - 1]
        add al, [bp - 4]                ; al = row + i

        cmp al, 0
        jl .continue                    ; if (row + i < 0) continue

        cmp al, ROWS
        jge .continue                   ; if (row + i >= ROWS) continue

        mov ah, [bp - 2]
        add ah, [bp - 5]                ; ah = col + j

        cmp ah, 0
        jl .continue                    ; if (col + j < 0) continue

        cmp ah, COLS
        jge .continue                   ; if (col + j >= COLS) continue

        movzx bx, ah                    ; bx = col + j

        mov ah, COLS
        mul ah                          ; ax = (row + i) * COLS

        add bx, ax                      ; bx = cell index
        shl bx, 1                       ; bx = grid offset

        mov dx, [es:si + bx]            ; dl = cell state

        cmp dl, ALIVE                   ; if (!ALIVE) continue
        jne .continue

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

; write_next_cell_state() -----------------------------------------------------

; input:
; es:si     -> current grid
; es:di     -> next grid
; cx        -> cell index

; output:
; [es:di + cx * 2] = updated cell state

; clobbers ax, bx, dx

write_next_cell_state:

call alive_neighbours       ; ax = # alive neighbours

mov bx, cx
shl bx, 1

mov dx, [es:si + bx]        ; dl = cell current state

cmp dl, ALIVE               ; if (ALIVE) {
jne .else

cmp ax, 2                   ;     if (n < 2)
jl .dead                    ;         return DEAD

cmp ax, 3                   ;     if (n > 3)
jg .dead                    ;         return DEAD

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

; write_next_vga_page() -------------------------------------------------------

; clobbers di, si, ax, bx, cx, dx

write_next_vga_page:

mov si, [currvgapg]         ; es:si -> current page

mov di, VGAPGSZ
xor di, si                  ; es:di -> next page

xor cx, cx                  ; i = 0

.update_loop:
call write_next_cell_state

inc cx
cmp cx, COLS * ROWS
jl .update_loop             ; for i in [0 .. COLS * ROWS - 1]

ret

; halt() - stop program execution ---------------------------------------------

halt:

cli                         ; disable interrupts
hlt
jmp halt

; =============================================================================

times 510 - ($ - $$) db 0   ; fill remaining bytes with zeroes
dw 0xaa55                   ; mbr magic byte
