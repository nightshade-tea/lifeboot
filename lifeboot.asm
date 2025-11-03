bits 16
org 0x7c00

%define ORG 0x7c00
%define VGA 0xb8000

%define COLS 80
%define ROWS 25

%define GRID ORG + 512
%define NEXT_GRID GRID_CUR + COLS * ROWS

%define DEAD ' '
%define ALIVE '#'

%define PRINT_COLOR 0x07            ; grey on black

; entry point -----------------------------------------------------------------

; initialize segment registers
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax

; set stack pointers
mov sp, ORG
mov bp, ORG

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
