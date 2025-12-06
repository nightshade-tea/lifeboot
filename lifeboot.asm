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
%define VGAPGSZ (COLS * ROWS * 2)

; memory layout ---------------------------------------------------------------

%define ORG 0x7c00
%define VGA 0xb8000
%define DAT ORG + 512

; static variables ------------------------------------------------------------

%define xss DAT             ; xs() state (word)
%define currvgapg xss + 2   ; current vga page near pointer (word)

; =============================================================================

; entry point -----------------------------------------------------------------

; initialize segment registers
mov ax, VGA >> 4
mov ds, ax
mov es, ax

xor ax, ax
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
mov ah, 0x00                ; get
int 0x1a                    ;  system time
mov [xss], dx               ; cx:dx = number of clock ticks since midnight

; initialize currvgapg
mov word [currvgapg], VGAPGSZ

; setup -----------------------------------------------------------------------

setup:

call init_grid
call flip_vga_page
call delay

jmp setup

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

; vsync() - wait for display to enter the next VBlank cycle -------------------

; clobbers ax, dx

vsync:

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

call vsync

xor word [currvgapg], VGAPGSZ   ; flip currvgapg
setnz al                        ; al = !(currvgapg == 0)

mov ah, 0x05                ; select active display page
int 0x10                    ; video services

ret

; halt() - stop program execution ---------------------------------------------

halt:

cli                         ; disable interrupts
hlt
jmp halt

; =============================================================================

times 510 - ($ - $$) db 0   ; fill remaining bytes with zeroes
dw 0xaa55                   ; mbr magic byte
