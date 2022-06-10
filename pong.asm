stack segment para stack
    DB 64 DUP (' ')
stack ends

data segment para 'data'

	window_width DW 140h   						;the width of the window (320 pixels)
	window_height DW 0c8h  						;the height of the window (200 pixels)
	window_bounds DW 6     						;varible used to chech collisions early (prevent the ball from exiting the screen)

	time_aux DB 0 								;varible used when checking if the time has changed
	GAME_ACTIVE DB 1							;True (1) if a game is running, False (0) if the game is over
	EXITING_GAME DB 00h							;1 if the user wants to exit
	WINNER_INDEX DB 0  							;the index of the winner (1 is player 1, 2 is player 2)
	CURRENT_SCENE DB 0							; the index of the current game state (0 is main menu, 1 is the game)
	
	text_player_one_points DB '0','$'			;text with the player one points
	text_player_two_points DB '0','$'			;text with the player two points
	text_game_over_title DB 'GAME OVER','$'     ;text with the game over menu title
	text_game_over_winner DB 'player 0 won','$' ;text with the player that won the game
	text_game_over_play_again DB 'press R to play again','$' ;play againg MSG
	text_game_over_main_menu DB 'press E to exit to menu','$';quit to menu MSG
	text_main_menu_title DB 'MAIN MENU', '$'    ;the text with the main menu title
	text_main_menu_singleplayer DB 'SINGLEPLAYER - S key','$' ;the text with the singleplayer MSG
	text_main_menu_multiplayer DB 'MULTIPLAYER - M key','$' ;the text with the multiplayer MSG
	text_main_menu_exit DB 'EXIT GAME - E key','$' ;the text with the exit MSG
    
    ball_original_x DW 0a0h						;ball x position on the beginning of a game
	ball_original_y DW 64h						;ball y position on the beginning of a game
	ball_x DW 0ah 								;ball x position (the current position - updating)
    ball_y DW 0ah 								;ball y position (the current position - updating)
    ball_size DW 04h						    ;size of the ball (width x height)
    ball_velocity_x DW 05h 						;x velocity of the ball
    ball_velocity_y DW 02h 						;y velocity of the ball
	
	paddle_left_x DW 0ah						;x position of the left paddle (the current position - updating)
	paddle_left_y DW 0ah						;y position of the left paddle (the current position - updating)
	player_one_points DB 0 						;current points of player 1 (left)
	
	paddle_right_x DW 130h						;x position of the right paddle (the current position - updating)
	paddle_right_y DW 0ah						;y position of the right paddle (the current position - updating)
	player_two_points DB 0						;current points of player 2 (right)
	AI_controlled DB 0						    ;is the right paddle controlled by the AI
	
	paddle_width DW 05h							;default paddle width
	paddle_height DW 1fh						;default paddle height
	paddle_velocity DW 05h						;default paddle velocity
    
data ends

code segment para 'code'

    main proc far
    assume cs:code,ds:data,ss:stack 			;assune as code, data and stack segment the repective registers
    push ds                        				;push to the stack the DS segment
    sub ax, ax                      			;clean the AX register
    push ax                         			;push ax to the stack
    mov ax,data                     			;save the contents of the data segment on ax
    mov ds, ax                     				;save on the ds segment the contents of ax
    pop ax                      				;release the top item from the stack to AX
    
		call clear_screen						;set initial videeo mode configurations
    
		check_time:  							;time checking loop 
        
			CMP EXITING_GAME,01h
			JE START_EXIT_PROCESS
			CMP CURRENT_SCENE,00h
			JE SHOW_MAIN_MENU
			cmp GAME_ACTIVE, 00h
			JE SHOW_GAME_OVER
		
			mov ah,2ch 							;get the system tyme
			int 21h    							;CH = hour CL = minute DH = second DL = 1/100 seconds
    
    
			cmp dl,time_aux           			;is the current time equal to the previous one (time_aux)
			je check_time             			;if the time is same, check again

		    ;if the code got here, the time has passed


			mov time_aux,DL 					;update the time
        
			call clear_screen					;clear the screen
		
			call move_ball						;move the ball
			call draw_ball						;draw the ball
		
			call move_paddles					;move the paddles (check for key press)
			call draw_paddles					;draw the paddles
			
			call draw_ui 						;draw all the game user interface
        
			jmp check_time 					    ;after everything, check the time again
			
			SHOW_GAME_OVER:
				call DRAW_GAME_OVER_MENU
				JMP CHECK_TIME
				
		    SHOW_MAIN_MENU:
				CALL DRAW_MAIN_MENU
				JMP check_time
			
			START_EXIT_PROCESS:
				CALL CONCLUDE_EXIT_GAME
			
			RET
    main ENDP
        
 MOVE_BALL PROC NEAR                  ;proccess the movement of the ball
        
;       Move the ball horizontally
        MOV AX,BALL_VELOCITY_X    
        ADD BALL_X,AX                   
        
;       Check if the ball has passed the left boundarie (BALL_X < 0 + WINDOW_BOUNDS)
;       If is colliding, restart its position       
        MOV AX,WINDOW_BOUNDS
        CMP BALL_X,AX                    ;BALL_X is compared with the left boundarie of the screen (0 + WINDOW_BOUNDS)          
        JL GIVE_POINT_TO_PLAYER_TWO      ;if is less, give one point to the player two and reset ball position
        
;       Check if the ball has passed the right boundarie (BALL_X > WINDOW_WIDTH - BALL_SIZE  - WINDOW_BOUNDS)
;       If is colliding, restart its position       
        MOV AX,WINDOW_WIDTH
        SUB AX,BALL_SIZE
        SUB AX,WINDOW_BOUNDS
        CMP BALL_X,AX                   ;BALL_X is compared with the right boundarie of the screen (BALL_X > WINDOW_WIDTH - BALL_SIZE  - WINDOW_BOUNDS)  
        JG GIVE_POINT_TO_PLAYER_ONE     ;if is greater, give one point to the player one and reset ball position
        JMP MOVE_BALL_VERTICALLY
        
        GIVE_POINT_TO_PLAYER_ONE:        ;give one point to the player one and reset ball position
            INC PLAYER_ONE_POINTS       ;increment player one points
            CALL RESET_BALL_POSITION     ;reset ball position to the center of the screen
            
            CALL UPDATE_TEXT_PLAYER_ONE_POINTS ;update the text of the player one points
            
            CMP PLAYER_ONE_POINTS,05h   ;check if this player has reached 5 points
            JGE GAME_OVER                ;if this player points is 5 or more, the game is over
            RET
        
        GIVE_POINT_TO_PLAYER_TWO:        ;give one point to the player two and reset ball position
            INC PLAYER_TWO_POINTS      ;increment player two points
            CALL RESET_BALL_POSITION     ;reset ball position to the center of the screen
            
            CALL UPDATE_TEXT_PLAYER_TWO_POINTS ;update the text of the player two points
            
            CMP PLAYER_TWO_POINTS,05h  ;check if this player has reached 5 points
            JGE GAME_OVER                ;if this player points is 5 or more, the game is over
            RET
            
        GAME_OVER:                       ;someone has reached 5 points
            CMP PLAYER_ONE_POINTS,05h    ;check wich player has 5 or more points
            JNL WINNER_IS_PLAYER_ONE     ;if the player one has not less than 5 points is the winner
            JMP WINNER_IS_PLAYER_TWO     ;if not then player two is the winner
            
            WINNER_IS_PLAYER_ONE:
                MOV WINNER_INDEX,01h     ;update the winner index with the player one index
                JMP CONTINUE_GAME_OVER
            WINNER_IS_PLAYER_TWO:
                MOV WINNER_INDEX,02h     ;update the winner index with the player two index
                JMP CONTINUE_GAME_OVER
                
            CONTINUE_GAME_OVER:
                MOV PLAYER_ONE_POINTS,00h   ;restart player one points
                MOV PLAYER_TWO_POINTS,00h  ;restart player two points
                CALL UPDATE_TEXT_PLAYER_ONE_POINTS
                CALL UPDATE_TEXT_PLAYER_TWO_POINTS
                MOV GAME_ACTIVE,00h            ;stops the game
                RET 

;       Move the ball vertically        
        MOVE_BALL_VERTICALLY:       
            MOV AX,BALL_VELOCITY_Y
            ADD BALL_Y,AX             
        
;       Check if the ball has passed the top boundarie (BALL_Y < 0 + WINDOW_BOUNDS)
;       If is colliding, reverse the velocity in Y
        MOV AX,WINDOW_BOUNDS
        CMP BALL_Y,AX                    ;BALL_Y is compared with the top boundarie of the screen (0 + WINDOW_BOUNDS)
        JL NEG_VELOCITY_Y                ;if is less reverve the velocity in Y

;       Check if the ball has passed the bottom boundarie (BALL_Y > WINDOW_HEIGHT - BALL_SIZE - WINDOW_BOUNDS)
;       If is colliding, reverse the velocity in Y      
        MOV AX,WINDOW_HEIGHT    
        SUB AX,BALL_SIZE
        SUB AX,WINDOW_BOUNDS
        CMP BALL_Y,AX                    ;BALL_Y is compared with the bottom boundarie of the screen (BALL_Y > WINDOW_HEIGHT - BALL_SIZE - WINDOW_BOUNDS)
        JG NEG_VELOCITY_Y                ;if is greater reverve the velocity in Y
        
;       Check if the ball is colliding with the right paddle
        ; maxx1 > minx2 && minx1 < maxx2 && maxy1 > miny2 && miny1 < maxy2
        ; BALL_X + BALL_SIZE > PADDLE_RIGHT_X && BALL_X < PADDLE_RIGHT_X + PADDLE_WIDTH 
        ; && BALL_Y + BALL_SIZE > PADDLE_RIGHT_Y && BALL_Y < PADDLE_RIGHT_Y + PADDLE_HEIGHT
        
        MOV AX,BALL_X
        ADD AX,BALL_SIZE
        CMP AX,PADDLE_RIGHT_X
        JNG CHECK_COLLISION_WITH_LEFT_PADDLE  ;if there's no collision check for the left paddle collisions
        
        MOV AX,PADDLE_RIGHT_X
        ADD AX,PADDLE_WIDTH
        CMP BALL_X,AX
        JNL CHECK_COLLISION_WITH_LEFT_PADDLE  ;if there's no collision check for the left paddle collisions
        
        MOV AX,BALL_Y
        ADD AX,BALL_SIZE
        CMP AX,PADDLE_RIGHT_Y
        JNG CHECK_COLLISION_WITH_LEFT_PADDLE  ;if there's no collision check for the left paddle collisions
        
        MOV AX,PADDLE_RIGHT_Y
        ADD AX,PADDLE_HEIGHT
        CMP BALL_Y,AX
        JNL CHECK_COLLISION_WITH_LEFT_PADDLE  ;if there's no collision check for the left paddle collisions
        
;       If it reaches this point, the ball is colliding with the right paddle

        JMP NEG_VELOCITY_X

;       Check if the ball is colliding with the left paddle
        CHECK_COLLISION_WITH_LEFT_PADDLE:
        ; maxx1 > minx2 && minx1 < maxx2 && maxy1 > miny2 && miny1 < maxy2
        ; BALL_X + BALL_SIZE > PADDLE_LEFT_X && BALL_X < PADDLE_LEFT_X + PADDLE_WIDTH 
        ; && BALL_Y + BALL_SIZE > PADDLE_LEFT_Y && BALL_Y < PADDLE_LEFT_Y + PADDLE_HEIGHT
        
        MOV AX,BALL_X
        ADD AX,BALL_SIZE
        CMP AX,PADDLE_LEFT_X
        JNG EXIT_COLLISION_CHECK  ;if there's no collision exit procedure
        
        MOV AX,PADDLE_LEFT_X
        ADD AX,PADDLE_WIDTH
        CMP BALL_X,AX
        JNL EXIT_COLLISION_CHECK  ;if there's no collision exit procedure
        
        MOV AX,BALL_Y
        ADD AX,BALL_SIZE
        CMP AX,PADDLE_LEFT_Y
        JNG EXIT_COLLISION_CHECK  ;if there's no collision exit procedure
        
        MOV AX,PADDLE_LEFT_Y
        ADD AX,PADDLE_HEIGHT
        CMP BALL_Y,AX
        JNL EXIT_COLLISION_CHECK  ;if there's no collision exit procedure
        
;       If it reaches this point, the ball is colliding with the left paddle    

        JMP NEG_VELOCITY_X
        
        NEG_VELOCITY_Y:
            NEG BALL_VELOCITY_Y   ;reverse the velocity in Y of the ball (BALL_VELOCITY_Y = - BALL_VELOCITY_Y)
            RET
        NEG_VELOCITY_X:
            NEG BALL_VELOCITY_X              ;reverses the horizontal velocity of the ball
            RET                              
            
        EXIT_COLLISION_CHECK:
            RET
    MOVE_BALL ENDP
	
	move_paddles proc near						;process the movement of the paddles
	
		;left paddle movement:
		
		;check if any key is being pressed (if not - check the right paddle keys)
		mov ah,01h
		int 16h
		jz check_right_paddle_momement ;ZF = 1, jz -> jump if zero
		
		;if the above is true, check which key is being pressed (AL = ascii character)
		mov ah,00h
		int 16h
		
		;if it is 'w' or 'W' move up
		cmp al,77h  ;'w'
		je move_left_paddle_up
		cmp al,57h  ;'W'
		je move_left_paddle_up
		
		;if it is 's' or 'S' move down
		cmp al,73h  ;'s'
		je move_left_paddle_down
		cmp al,53h  ;'S'
		je move_left_paddle_down
		jmp check_right_paddle_momement
		
		move_left_paddle_up:
			mov ax, paddle_velocity
			sub paddle_left_y,ax
			
			mov ax,window_bounds
			cmp paddle_left_y,ax
			jl fix_paddle_left_top_position
			jmp check_right_paddle_momement
			
			
			fix_paddle_left_top_position:
				mov ax,window_bounds
				mov paddle_left_y,ax
				jmp check_right_paddle_momement
			
		move_left_paddle_down:
			mov ax, paddle_velocity
			add paddle_left_y,ax
			mov ax,window_height
			sub ax,window_bounds
			sub ax,paddle_height
			cmp paddle_left_y,ax
			jg fix_paddle_left_bottom_position
			jmp check_right_paddle_momement
			
			fix_paddle_left_bottom_position:
				mov paddle_left_y,ax
				jmp check_right_paddle_momement
				
		
		;right paddle movement:
		check_right_paddle_momement:
		
			CMP AI_controlled,01h
			JE CONTROL_BY_AI
	
;			when the paddle is controlled by the user pressing the keys	
			CHECK_FOR_KEYS:
				;if it is 'o' or 'O' move up
				cmp al,6Fh  ;'o'
				je move_right_paddle_up
				cmp al,4Fh  ;'O'
				je move_right_paddle_up
		
				;if it is 'l' or 'L' move down
				cmp al,6ch  ;'l'
				je move_right_paddle_down
				cmp al,4ch  ;'L'
				je move_right_paddle_down
				jmp exit_paddle_movement
		
;			when the paddle is being controlled by the AI
			CONTROL_BY_AI:
				;check if the ball is above the paddle (ball_y + ball_size < paddle_right_y)
				;if it is move up
				MOV ax, ball_y
				ADD ax, ball_size
				CMP ax, paddle_right_y
				JL move_right_paddle_up
				
				;check if the ball is below the paddle (ball_y > paddle_right_y + paddle_height)
				;if it is move down
				MOV ax, paddle_right_y
				ADD ax, paddle_height
				CMP ax, ball_y
				JL move_right_paddle_down
				
				;if none of the conditions are true do nothing
				JMP exit_paddle_movement
			
			move_right_paddle_up:
				mov ax, paddle_velocity
				sub paddle_right_y,ax
			
				mov ax,window_bounds
				cmp paddle_right_y,ax
				jl fix_paddle_right_top_position
				jmp exit_paddle_movement
			
			
				fix_paddle_right_top_position:
					mov ax,window_bounds
					mov paddle_right_y,ax
					jmp exit_paddle_movement
			
			move_right_paddle_down:
				mov ax, paddle_velocity
				add paddle_right_y,ax
				mov ax,window_height
				sub ax,window_bounds
				sub ax,paddle_height
				cmp paddle_right_y,ax
				jg fix_paddle_right_bottom_position
				jmp exit_paddle_movement
			
				fix_paddle_right_bottom_position:
					mov paddle_right_y,ax
					jmp exit_paddle_movement
	
		exit_paddle_movement:
			ret
	move_paddles endp
    
    reset_ball_position proc near						;restart ball position to the original position values
	
		mov ax, ball_original_x
		mov ball_X,ax
		
		mov ax, ball_original_y
		mov ball_y,ax
		
		ret
	reset_ball_position endp
	
	draw_ball proc NEAR
    
        mov cx,ball_x 									;set the x initial position
        mov dx, ball_y 									;set the y initial position
         
        draw_ball_horizontal:
            mov ah,0ch 									;set the configuration to writing a pixel
            mov al,0fh 									;choose white as the color
            mov bh,00h 									;set the page number
            int 10h    									;execute configuration
            inc cx     									;cx++
            mov ax,cx           						;cx - ball_x > ball_size (go line down condition)
            sub ax, ball_x
            cmp ax, ball_size
            jng draw_ball_horizontal
            mov cx,ball_x 								;the cx register goes back to the initial column
            inc dx        								;advance one line
            mov ax, dx    								;DX - ball_y > ball_size (go to next line if false, exit if true)
            sub ax,ball_y
            cmp AX, ball_size
            jng draw_ball_horizontal
            

          
          
        ret
    draw_ball ENDP
	
	draw_paddles proc near
	
		mov cx,paddle_left_x 						;set the x initial position
        mov dx, paddle_left_y 						;set the y initial position
		
		draw_paddle_left_horizontal:
			mov ah,0ch 								;set the configuration to writing a pixel
            mov al,0fh 								;choose white as the color
            mov bh,00h 								;set the page number
            int 10h    								;execute configuration
			
			inc cx     								;cx++
            mov ax,cx           					;cx - paddle_left_x > paddle_width (go line down condition)
            sub ax, paddle_left_x
            cmp ax, paddle_width
            jng draw_paddle_left_horizontal
			
			mov cx,paddle_left_x  	   			    ;the cx register goes back to the initial column
            inc dx        							;advance one line
            mov ax, dx    							;DX - paddle_left_y > paddle_height (go to next line if false, exit if true)
            sub ax,paddle_left_y
            cmp AX, paddle_height
            jng draw_paddle_left_horizontal
		
		
		MOV CX,paddle_right_x            ;set the initial column (X)
        MOV DX,paddle_right_y            ;set the initial line (Y)
		
		draw_paddle_right_horizontal:
			mov ah,0ch 								;set the configuration to writing a pixel
            mov al,0fh 								;choose white as the color
            mov bh,00h 								;set the page number
            int 10h    								;execute configuration
			
			inc cx     								;cx++
            mov ax,cx           					;cx - paddle_right_x > paddle_width (go line down condition)
            sub ax, paddle_right_x
            cmp ax, paddle_width
            jng draw_paddle_right_horizontal
			
			mov cx,paddle_right_x 					;the cx register goes back to the initial column
            inc dx        							;advance one line
            mov ax, dx    							;DX - paddle_right_y > paddle_height (go to next line if false, exit if true)
            sub ax,paddle_right_y
            cmp AX, paddle_height
            jng draw_paddle_right_horizontal
			
		ret
	draw_paddles endp
	
	draw_ui proc near
	
;		draw the points of the left player

		mov ah,02h								;set cursor position	
		mov bh,00h								;set page number
		mov dh,04h								;set row
		mov dl,06h								;set column
		int 10h									
		
		mov ah,09h								;write string to standard output
		lea dx,text_player_one_points			;give DX a pointer to the string text_player_one_points
		int 21h									;print the string

;		draw the points of the right player

		mov ah,02h								;set cursor position	
		mov bh,00h								;set page number
		mov dh,04h								;set row
		mov dl,1fh								;set column
		int 10h									
		
		mov ah,09h								;write string to standard output
		lea dx,text_player_two_points			;give DX a pointer to the string text_player_one_points
		int 21h									;print the string
	
		ret
	draw_ui endp
	
	update_text_player_one_points proc near
	
		xor ax,ax
		mov al,player_one_points  ;given for example that p1 -> 2 points => AL,2
		
		;now, before printing to the screen, the decimal value needs to be converted to ascii code character
		;this will be done by adding 30h (number to ascii)
		;and by subtracting 30h (ascii to number)
		
		add al,30h
		mov [text_player_one_points],al 
		
		ret
	update_text_player_one_points endp
	
	update_text_player_two_points proc near
	
		xor ax,ax
		mov al,player_two_points  ;given for example that p1 -> 2 points => AL,2
		
		;now, before printing to the screen, the decimal value needs to be converted to ascii code character
		;this will be done by adding 30h (number to ascii)
		;and by subtracting 30h (ascii to number)
		
		add al,30h
		mov [text_player_two_points],al 
	
		ret
	update_text_player_two_points endp
	
	DRAW_GAME_OVER_MENU proc near					;draw the game over menu
	
		call clear_screen 							;clear the screen becore displaying the menu

;		shows the menu title		
		mov ah,02h								;set cursor position	
		mov bh,00h								;set page number
		mov dh,06h								;set row
		mov dl,04h								;set column
		int 10h									
		
		mov ah,09h								;write string to standard output
		lea dx,text_game_over_title			   ;give DX a pointer to the string text_game_over_title
		int 21h									;print the string
		
;		shows the winner
		mov ah,02h								;set cursor position	
		mov bh,00h								;set page number
		mov dh,04h								;set row
		mov dl,04h								;set column
		int 10h									
		
		CALL UPDATE_WINNER_TEXT
		
		mov ah,09h								;write string to standard output
		lea dx,text_game_over_winner			   ;give DX a pointer to the string text_game_over_winner
		int 21h									;print the string
		
;		shows the play again MSG
		mov ah,02h								;set cursor position	
		mov bh,00h								;set page number
		mov dh,08h								;set row
		mov dl,04h								;set column
		int 10h									
		
		mov ah,09h								;write string to standard output
		lea dx,text_game_over_play_again			   ;give DX a pointer to the string text_game_over_play_again
		int 21h									;print the string
		
;		shows the main menu MSG
		mov ah,02h								;set cursor position	
		mov bh,00h								;set page number
		mov dh,0Ah								;set row
		mov dl,04h								;set column
		int 10h									
		
		mov ah,09h								;write string to standard output
		lea dx,text_game_over_main_menu			   ;give DX a pointer to the string text_game_over_main_menu
		int 21h									;print the string
		
;		waits for a key press
		mov ah, 00h
		int 16h

;		if the pressed key is 'R' or 'r' we restart the game		
		CMP AL,'R'
		JE RESTART_GAME
		CMP AL, 'r'
		JE RESTART_GAME
		
;		if the pressed key is 'E' or 'e' we quit to main menu
		CMP AL,'E'
		JE EXIT_TO_MAIN_MENU
		CMP AL,'e'
		JE EXIT_TO_MAIN_MENU
		
		RET
		RESTART_GAME:
			MOV GAME_ACTIVE,01h
			RET
	    EXIT_TO_MAIN_MENU:
			MOV GAME_ACTIVE, 00h
			mov CURRENT_SCENE,00h
			RET
	
	DRAW_GAME_OVER_MENU endp
	
	DRAW_MAIN_MENU proc near
	
		call clear_screen
		
;		shows the menu title
		mov ah,02h								;set cursor position	
		mov bh,00h								;set page number
		mov dh,04h								;set row
		mov dl,04h								;set column
		int 10h									
		
		mov ah,09h								;write string to standard output
		lea dx,text_main_menu_title			   ;give DX a pointer to the string text_main_menu_title
		int 21h									;print the string
		
;		shows the singleplayer
		mov ah,02h								;set cursor position	
		mov bh,00h								;set page number
		mov dh,06h								;set row
		mov dl,04h								;set column
		int 10h									
		
		mov ah,09h								;write string to standard output
		lea dx,text_main_menu_singleplayer		;give DX a pointer to the string text_main_menu_singleplayer
		int 21h									;print the string
		
;		shows the multiplayer
		mov ah,02h								;set cursor position	
		mov bh,00h								;set page number
		mov dh,08h								;set row
		mov dl,04h								;set column
		int 10h									
		
		mov ah,09h								;write string to standard output
		lea dx,text_main_menu_multiplayer		;give DX a pointer to the string text_main_menu_multiplayer
		int 21h									;print the string
		
;		shows the exit MSG
		mov ah,02h								;set cursor position	
		mov bh,00h								;set page number
		mov dh,0Ah								;set row
		mov dl,04h								;set column
		int 10h									
		
		mov ah,09h								;write string to standard output
		lea dx,text_main_menu_exit		   ;give DX a pointer to the string text_main_menu_exit
		int 21h									;print the string
	
		MAIN_MENU_WAIT_FOR_KEY:
;			waits for a key press
			mov ah, 00h
			int 16h
;			check which key was pressed		
			CMP AL,'S'
			JE START_SINGLEPLAYER
			CMP AL,'s'
			JE START_SINGLEPLAYER
		
			CMP AL,'M'
			JE START_MULTIPLAYER
			CMP AL,'m'
			JE START_MULTIPLAYER
		
			CMP AL,'E'
			JE EXIT_GAME
			CMP AL,'e'
			JE EXIT_GAME
			
			JMP MAIN_MENU_WAIT_FOR_KEY
		
		START_SINGLEPLAYER:
			MOV CURRENT_SCENE, 01h
			MOV GAME_ACTIVE, 01h
			MOV AI_controlled, 01h
			RET
		
		START_MULTIPLAYER:
			MOV CURRENT_SCENE,01h
			MOV GAME_ACTIVE, 01h
			MOV AI_controlled, 00h
			RET
		
		EXIT_GAME:
			MOV EXITING_GAME,01h
			RET
	DRAW_MAIN_MENU endp
	
	UPDATE_WINNER_TEXT proc near
		
		mov AL, WINNER_INDEX						;if the winner index is 1, AL becomes 1
		ADD AL, 30h									;to convert the value to ascii we add 31h to AL
		mov [text_game_over_winner+7], AL
		
		RET
	UPDATE_WINNER_TEXT endp
    
    clear_screen proc near          				;clear the screen by restarting the video mode
        
			mov ah,00h  							;set configuration to video mode
			mov al,13h 								;choose the video mode
			int 10h 								;execute the configuration
			
			mov ah,0bh 								;set the configuration
			mov bh,00h 								;to the background color
			mov bl, 00h 							;choose black as background
			int 10h 								;execute the configuration
        
        ret
    clear_screen endp
	
	CONCLUDE_EXIT_GAME proc near		;go back to text mode and terminate
	
		mov ah,00h  							;set configuration to text mode
		mov al,02h 								;choose the text mode
		int 10h 								;execute the configuration
		
		mov AH,4CH								;terminate program
		int 21h
	
		RET
	CONCLUDE_EXIT_GAME endp
    
    
code ends
end