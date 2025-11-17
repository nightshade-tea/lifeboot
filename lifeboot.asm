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

; clear screen ----------------------------------------------------------------

; disable cursor
mov ch, 0x3f
mov ah, 0x01
int 0x10

; clear video memory
mov cx, COLS * ROWS
mov ax, VGA >> 4
mov es, ax
xor di, di
mov ax, (PRINT_COLOR << 8) | DEAD

rep stosw                   ; fill cx words at es:di with ax

; setup -----------------------------------------------------------------------

setup:

; initialize xss
mov ah, 0x00                ; get
int 0x1a                    ;  system time
mov [XSS], dx               ; cx:dx = number of clock ticks since midnight

; initialize grid
mov cx, COLS * ROWS         ; for each cell
xor ax, ax
mov es, ax
mov di, GRID                ; es:di -> GRID

.initgrid:                  ; do {
    call xs                 ;     [XSS] = rand
    mov al, DEAD            ;     al = DEAD (likely)

    test [XSS], 0b11

    jnz  .initgrid_nz       ;     if ([XSS] % 4 == 0)
    mov al, ALIVE           ;         al = ALIVE

.initgrid_nz:
    stosb                   ;     [es:(di++)] = al

    loop .initgrid          ; } while (--cx)

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

; errors ----------------------------------------------------------------------

hello:
mov si, str.hello

; print the error message string in si and halt
; note: we assume es = VGA_SEG and ds = 0
printerr:
xor di, di
mov ah, PRINT_COLOR

; es:di = video memory
; ds:si = error message
; al = current char
; ah = color attribute

write_char:
lodsb                   ; al = [ds:si], si += 1
or  al, al              ; on null terminator,
jz  halt                ;  halt
stosw                   ; [es:di] = ax, di += 2
jmp write_char

halt:
cli                     ; disable interrupts
hlt
jmp halt

; data ------------------------------------------------------------------------

str:
.hello:
    db "lifeboot", 0

times 510 - ($ - $$) db 0   ; fill remaining bytes with zeroes
dw 0xaa55                   ; mbr magic byte
