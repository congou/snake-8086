IDEAL
MODEL small
STACK 100h
DATASEG
    head dw 4
    tail dw 0
    snakeX db 200 dup(0)
    snakeY db 200 dup(0)
    dirX db 1
    dirY db 0
    gameOverMsg db 'Game Over$'
    score dw 0

CODESEG
start:
    mov ah, 0
    mov al, 3
    int 10h

	mov ax, @data
	mov ds, ax

    mov ax, 0B800h
    mov es, ax

    ;resetting variables to deafult
    call reset_variables

    ;removing default cursor
    mov ah, 01h
    mov cx, 2000h
    int 10h

    mov si, 0
    mov cx, 5
    mov dl, 8
    mov dh, 12

;draws the snakeX positions 8, 9, 10, 11, 12.
;draws the snakeY positions 12, 12, 12, 12, 12.
draw_snake:
    mov [snakeX + si], dl
    mov [snakeY + si], dh
    call screen_convert
    mov al, 'O'
    mov ah, 0Ah
    call draw
    inc si
    inc dl
    loop draw_snake

    call spawn_apple
  
draw_walls:
    mov cx, 80
    mov dl, 0
    draw_X:
        mov dh, 0
        call draw_walls_at
        mov dh, 24
        call draw_walls_at
        inc dl
    loop draw_X
    
    mov cx, 25
    mov dh, 0
    draw_Y:
        mov dl, 0
        call draw_walls_at
        mov dl, 79
        call draw_walls_at
        inc dh
    loop draw_Y

    call show_score

    mov ah, 00h
    int 16h

game_loop:
    mov ah, 1
    int 16h
    jz skip_keys
    mov ah, 0
    int 16h

    cmp ah, 48h ;checks up
    jne chk_down

    cmp [dirY], 1 ;checks if the snake is moving in the opposite direction.
    je skip_keys

    mov [dirX], 0
    mov [dirY], -1
    jmp skip_keys

    chk_down:
        cmp ah, 50h
        jne chk_left

        cmp [dirY], -1 ;checks if the snake is moving in the opposite direction.
        je skip_keys

        mov [dirX], 0
        mov [dirY], 1
        jmp skip_keys

    chk_left:
        cmp ah, 4Bh
        jne chk_right

        cmp [dirX], 1 ;checks if the snake is moving in the opposite direction.
        je skip_keys

        mov [dirX], -1
        mov [dirY], 0
        jmp skip_keys

    chk_right:
        cmp ah, 4Dh
        jne chk_esc

        cmp [dirX], -1 ;checks if the snake is moving in the opposite direction.
        je skip_keys

        mov [dirX], 1
        mov [dirY], 0
        jmp skip_keys

    chk_esc:
        cmp ah, 01h
        je exit

    skip_keys:
        call move

        cmp al, 1 ;the snake died (gets this value from 'move')
        je end_game

        mov al, 'O' ;the charchater
        mov ah, 0Ah ;the color
        call draw

    ;horizontal speed: 50 ms per step
    mov cx, 0
    mov dx, 50000

    ;moving up/down looks faster, so if needed wait longer.
    cmp [dirY], 0
    je do_delay
    
    ;vertical speed: 65 ms per step
    mov dx, 65000

    do_delay:
        call delay
    
    jmp game_loop

end_game:
    ;moving cursor to the middle of the screen
    mov dh, 13
    mov dl, 36
    mov bh, 0
    mov ah, 02h
    int 10h

    ;prints the game over msg where the cursor is (the middle of the screen)
    mov ah, 09h
    mov dx, offset gameOverMsg
    int 21h

    ;waits for an input before jumping to start again.
    mov ah, 00h
    int 16h

    ;pressing esc exits the game
    cmp ah, 01h
    je exit

    jmp start

exit:
	mov ax, 4c00h
	int 21h

;X in dl, Y in dh
screen_convert:
    mov al, dh
    mov bl, 160
    mul bl
    
    mov bl, dl
    add bl, bl
    xor bh, bh
    add ax, bx

    mov di, ax
    ret

move:
    mov si, [head]
    mov dl, [snakeX + si]
    mov dh, [snakeY + si]
    add dl, [dirX]
    add dh, [dirY]
    
    inc [head]

    ;checks for array overflow (head index):
    cmp [head], 200
    jne head_ok
    mov [head], 0

    head_ok:
    mov si, [head]
    mov [snakeX + si], dl
    mov [snakeY + si], dh

    call check_square

    cmp al, '*'
    je found_apple

    cmp al, ' '
    je erase_tail

    ;anything else is a game over, unless it's the tail
    mov si, [tail]
    cmp dl, [snakeX + si] ;the head X value from check_square
    jne snake_died
    cmp dh, [snakeY + si] ;the head Y value from check_square
    jne snake_died

    erase_tail:
        mov si, [tail]
        mov dl, [snakeX + si]
        mov dh, [snakeY + si]
        call screen_convert
        mov al, ' '
        mov ah, 07h
        call draw
        inc [tail]

    ;checks for array overflow (tail index):
    cmp [tail], 200
    jne move_done
    mov [tail], 0
    
    jmp move_done

    snake_died:
        mov al, 1 ;signaling that the snake is dead
        ret

    found_apple:
        inc [score]
        call show_score
        call spawn_apple
    
    move_done:
        mov si, [head]
        mov dl, [snakeX + si]
        mov dh, [snakeY + si]
        call screen_convert
        mov al, 0 ;signaling that the snake is still alive
    ret

;gets the charchter from al.
draw:
    mov [byte es:di], al
    mov [byte es:di+1], ah
    ret

spawn_apple:
    try_spawn:
        mov ah, 00h
        int 1Ah
        mov ax, dx
        xor dx, dx
        mov bx, 23
        div bx ;Y value in dl
        inc dl ;to make it so the range is 1-23.
        mov cl, dl ;Y value in cl

        xor dx, dx
        mov bx, 78
        div bx ;X value in dl
        inc dl ;to make it so the range is 1-78.
        mov dh, cl ;Y value in dh
    
    call screen_convert
    ;checks if the apple is on the snake body.
    mov al, [byte es:di]
    cmp al, ' '
    jne try_spawn

    mov al, '*'
    mov ah, 0Ch
    call draw
    ret

check_square:
    mov si, [head]
    mov dl, [snakeX + si]
    mov dh, [snakeY + si]
    call screen_convert

    mov al, [byte es:di]
    ret

;waits cx:dx microseconds
delay:
    mov ah, 86h
    int 15h
    ret

draw_walls_at:
    call screen_convert

    ;sets the walls symbol
    mov al, '#'
    mov ah, 07h

    call draw
    ret

reset_variables:
    mov [head], 4
    mov [tail], 0
    mov [dirX], 1
    mov [dirY], 0
    mov [score], 0
    ret

;ax = the number, di = the screen position of the last digit
draw_number:
    mov bx, 10
    mov cx, 3

    next_digit:
        xor dx, dx
        div bx
        add dl, '0' ;turns it from the digit to a char (for example 7 -> '7')
        mov [byte es:di], dl
        mov [byte es:di+1], 0Eh
        sub di, 2
    loop next_digit
    ret

show_score:
    mov dl, 40
    mov dh, 0
    call screen_convert
    mov ax, [score]
    call draw_number
    ret

END start