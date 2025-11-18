bits 16
org 0x7c00

%define ORG 0x7c00
%define VGA 0xb8000

%define COLS 80
%define ROWS 25

%define DEAD ' '            ; char to represent a dead cell
%define ALIVE '#'           ; char to represent an alive cell
%define PRINT_COLOR 0x07    ; grey on black

%define GRID        ORG + 512               ; current cell grid (80 * 25 bytes)
%define NEXT_GRID   GRID + COLS * ROWS      ; next cell grid (80 * 25 bytes)
%define XSS         NEXT_GRID + COLS * ROWS ; xs() state

; entry point -----------------------------------------------------------------

; initialize segment registers
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax

; set stack pointers
mov sp, ORG
mov bp, ORG

; clear direction flag
cld

; disable cursor
mov ch, 0x3f
mov ah, 0x01
int 0x10

; setup -----------------------------------------------------------------------

setup:

; initialize xss
mov ah, 0x00                ; get
int 0x1a                    ;  system time
mov [XSS], dx               ; cx:dx = number of clock ticks since midnight

; initialize grid
mov di, GRID                ; es:di -> GRID
mov cx, COLS * ROWS         ; for each cell

.initgrid:                  ; do {
    call xs                 ;     [XSS] = rand
    mov al, DEAD            ;     al = DEAD (likely)

    test [XSS], 0b11

    jnz  .initgrid_nz       ;     if ([XSS] % 4 == 0)
    mov al, ALIVE           ;         al = ALIVE

.initgrid_nz:
    stosb                   ;     [es:(di++)] = al

    loop .initgrid          ; } while (--cx)

call print_grid

jmp halt

; functions -------------------------------------------------------------------

; xs() - xorshift pseudorandom number generator -------------------------------

; output:
; [XSS]     = updated state

; clobbers bx, dx

xs:

mov bx, [XSS]
mov dx, bx

shl dx, 1                   ; dx = xss << 1
xor bx, dx                  ; bx = xss ^ (xss << 1)
mov dx, bx

shr dx, 3                   ; dx = xss' >> 3
xor bx, dx                  ; bx = xss' ^ (xss' >> 3)
mov dx, bx

shl dx, 10                  ; dx = xss'' << 10
xor bx, dx                  ; bx = xss'' ^ (xss'' << 10)
mov [XSS], bx

ret

; print_grid() - print GRID cells to screen -----------------------------------

; (*) this function expects ds = 0 when called and sets es = 0 before
;     returning. this is simpler because in the rest of the program we want the
;     segment registers to be zeroed anyway.

; clobbers ax, cx, di, si

print_grid:

mov ax, VGA >> 4
xor di, di

mov es, ax                  ; es:di -> VGA
mov si, GRID                ; ds:si -> GRID

mov ah, PRINT_COLOR         ; ah = color attribute

mov cx, COLS * ROWS         ; for each cell

.print_cell:                ; do {

    lodsb                   ;     al = [ds:(si++)]
    stosw                   ;     [es:di] = ax ; di += 2

    loop .print_cell        ; } while (--cx)

mov es, cx                  ; es = 0
ret

; halt() - stop program execution ---------------------------------------------

halt:

cli                         ; disable interrupts
hlt
jmp halt

; -----------------------------------------------------------------------------

times 510 - ($ - $$) db 0   ; fill remaining bytes with zeroes
dw 0xaa55                   ; mbr magic byte
