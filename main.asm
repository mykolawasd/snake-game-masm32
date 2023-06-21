; A snake game written in assembly using Kip Irvnine's Irvine32 library.

include msvcrt.inc
include	Irvine32.inc
include Macros.inc


DIRECTION typedef BYTE


DEFAULT_ATTRIB equ 07h

APPLE_CHAR equ "@"

BORDER_WIDTH        equ 64 
BORDER_LEN          equ 25
BORDER_CHAR         equ 219
BORDER_UPPER_LEFT   equ 0
BORDER_LOWER_LEFT   equ 1
BORDER_UPPER_RIGHT  equ 2
BORDER_LOWER_RIGHT  equ 3

SCOREBOARD_X equ 0
SCOREBOARD_Y equ BORDER_LEN + 2

SNAKE_CAP          equ 64
SNAKE_INITIAL_SIZE equ 4
SNAKE_CHAR		   equ "O"
SNAKE_HEAD_CHAR    equ "Q"

LEFT  equ 0
UP    equ 1
RIGHT equ 2
DOWN  equ 3

; їїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїї

mWriteInitialScore MACRO
	mov al, '0'
	call WriteChar
ENDM

; їїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїї

mMoveTail MACRO pos
	mov ecx, snakeSize
	dec ecx
	lea edi, [pos+ecx]
	mov esi, edi
	dec esi
	std
	rep movsb

	EXITM		
ENDM

; їїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїї

mMoveSnake MACRO pos1, pos2, dir
	LOCAL CheckLeft, CheckDown, CheckUp, OutOfBounds, Continue
	mMoveTail pos1
	mMoveTail pos2

	mov al, xPosCoin
	mov ah, yPosCoin

	cmp xPosSnake,  al
	jne @f
	cmp yPosSnake,  ah
	jne @f

	mov pickedUpCoin, 1
	inc score 
	mov al, score
	.IF  scoreRecord <  al
		mov scoreRecord, al
	.ENDIF


	mov eax, SNAKE_CAP 
	cmp snakeSize, eax
	jge @f
	inc snakeSize

	@@:
	call CheckDeath
	add BYTE PTR [pos1], dir
	EXITM		
ENDM

; їїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїї



mCheckDirection MACRO directionToCheck, directionToMove
        .IF direction == directionToCheck
                jmp Update
        .ELSE
                mov direction, directionToMove
                jmp Update
        .ENDIF
ENDM



option casemap:none

GetAsyncKeyState PROTO KEY:DWORD
ReadConsoleOutputCharacterA PROTO STDCALL :DWORD,:DWORD,:DWORD,:DWORD,:DWORD



.data
consoleTitle BYTE "Snake game by mykolawasd", 0	
border       BYTE BORDER_WIDTH dup(BORDER_CHAR), 0

; Upper left, lower left, upper right, and lower right borders.
xPosBorder BYTE 0, 0,            BORDER_WIDTH, BORDER_WIDTH
yPosBorder BYTE 0, BORDER_LEN,   0,            BORDER_LEN


sScore       BYTE "Score: ", 0
sScoreRecord BYTE "Record: ", 0


score       BYTE 0
scoreRecord BYTE 0  

snake	  BYTE SNAKE_HEAD_CHAR, SNAKE_CAP - 1 dup(SNAKE_CHAR)
snakeSize DWORD SNAKE_INITIAL_SIZE
xPosSnake BYTE 20, 19, 18, 17, SNAKE_CAP-SNAKE_INITIAL_SIZE dup(?)
yPosSnake BYTE 20, 20, 20, 20, SNAKE_CAP-SNAKE_INITIAL_SIZE dup(?)

xPosSnakeDefault BYTE 20, 19, 18, 17
yPosSnakeDefault BYTE 20, 20, 20, 20

direction DIRECTION RIGHT

xPosCoin	 BYTE ?
yPosCoin	 BYTE ?
pickedUpCoin BYTE 1


hStdOut    HANDLE ?
randomSeed DWORD  1

.code

main PROC
	invoke GetStdHandle, STD_OUTPUT_HANDLE
	mov hStdOut, eax

	invoke SetConsoleTitle, OFFSET consoleTitle
	
	call InitScoreboard
	call Randomize ;re-seed generator

	call InitGame
	
	GameLoop:
		; If the coin exists, skip 
		cmp pickedUpCoin, 0 
		je $+7
		call SpawnCoin
		mGotoxy 0, 0
		mov al, BORDER_CHAR
		call WriteChar

		invoke Sleep, 50

		invoke GetAsyncKeyState, VK_RIGHT
		test ax, ax
		jnz MoveRight

		invoke GetAsyncKeyState, VK_LEFT
		test ax, ax
		jnz MoveLeft

		invoke GetAsyncKeyState, VK_UP
		test ax, ax
		jnz MoveUp

		invoke GetAsyncKeyState, VK_DOWN
		test ax, ax
		jnz MoveDown
		
		jmp Update
		
		MoveRight:
			mCheckDirection LEFT, RIGHT
		MoveLeft:
			mCheckDirection RIGHT, LEFT
		MoveUp:
			mCheckDirection DOWN, UP
		MoveDown:
			mCheckDirection UP, DOWN

		Update:
			call UpdateSnake
				
		call DrawScoreBoard
		mGotoxy 0, 0

		jmp GameLoop


	invoke ExitProcess, 0
main ENDP


; їїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїї

CheckDeath PROC
	mov esi, OFFSET xPosSnake
	mov edi, OFFSET yPosSnake
	add esi, 2
	add edi, 2

	mov edx, snakeSize
	sub edx, 2
	; Checking a collision with yourself
	mov ecx, 0
	.WHILE ecx != edx
		mov ah, BYTE PTR[esi]
		mov al, BYTE PTR[edi]

		.IF xPosSnake ==  ah && yPosSnake == al
			jmp OutOfBounds
		.ENDIF
	
		inc esi
		inc edi
		inc ecx
	.ENDW

	push ebx
	movzx bx, direction
	.IF bx == RIGHT
		; Checking for exit beyond the right limit
		mov al, [xPosSnake]
		add al, 1
		cmp al, [xPosBorder+2] 
		je OutOfBounds 

	.ELSEIF bx == LEFT
		; Checking for exit beyond the left limit
		mov al, [xPosSnake]
		sub al, 1
		cmp al, [xPosBorder]
		je OutOfBounds 
	.ELSEIF bx == DOWN
		; Checking for exit beyond the lower limit
		mov al, [yPosSnake]
		add al, 1
		cmp al, [yPosBorder+1] 
		je OutOfBounds 
	.ELSEIF bx == UP
		; Checking for exceeding the upper limit
		mov al, [yPosSnake]
		sub al, 1
		cmp al, [yPosBorder]
		je OutOfBounds
	.ENDIF


	jmp Continue

	OutOfBounds:
		jmp main+020h
		
		invoke Sleep, 5000

	Continue:
	; Код продолжения работы программы

	pop ebx
ret
CheckDeath ENDP

; їїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїї

SpawnCoin PROC
	invoke SetConsoleTextAttribute, hStdOut, yellow
	
	regenerate: 
	mov  eax, BORDER_WIDTH - 3     
    call RandomRange 
	inc al
	mov xPosCoin, al

	mov  eax, BORDER_LEN - 3      
    call RandomRange 
	inc al
	mov yPosCoin, al

	; Check if the coin intersects with the snake.
	mov al, xPosCoin
	mov ah, yPosCoin
	mov ecx, 0
	.WHILE ecx != snakeSize
		cmp BYTE PTR [xPosSnake+ecx], al
		jne @f
		cmp BYTE PTR [yPosSnake+ecx], ah
		jne @f

		jmp regenerate

		@@:
		inc ecx
	.ENDW

	mGotoxy xPosCoin, yPosCoin
	mov al, APPLE_CHAR
	call WriteChar
	
	mov pickedUpCoin, 0
	invoke SetConsoleTextAttribute, hStdOut, DEFAULT_ATTRIB
	mGotoxy 0, 0

	ret
SpawnCoin ENDP


; їїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїї

InitGame PROC
	call InitBorder
	
	mov score, 0
	call DrawScoreBoard

	mov pickedUpCoin,  1

	mov eax, DWORD PTR[xPosSnakeDefault]
	mov DWORD PTR[xPosSnake], eax

	mov eax, DWORD PTR[yPosSnakeDefault]
	mov DWORD PTR[yPosSnake], eax

	mov direction, RIGHT 
	call DrawSnake

	invoke Sleep, 2000

	ret
InitGame ENDP

; їїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїї

InitBorder PROC 
	mGotoxy xPosBorder[BORDER_UPPER_LEFT], yPosBorder[BORDER_UPPER_LEFT]
	mWriteString OFFSET	border
	
	mGotoxy xPosBorder[BORDER_LOWER_LEFT], yPosBorder[BORDER_LOWER_LEFT]
	mWriteString OFFSET	border
		
	mov ah, xPosBorder[BORDER_UPPER_LEFT]
	mov al, yPosBorder[BORDER_UPPER_LEFT]

	mov ecx, BORDER_LEN
	dec ecx

	@@:
	inc al
	mGotoxy ah, al
	mWrite BORDER_CHAR
	mWriteSpace BORDER_WIDTH - 2
	mWrite BORDER_CHAR
	LOOP @b
	
	ret
InitBorder ENDP 

; їїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїї

InitScoreboard PROC
	mGotoxy SCOREBOARD_X, SCOREBOARD_Y
	mWriteString OFFSET sScore
	mWriteInitialScore

	mGotoxy SCOREBOARD_X, SCOREBOARD_Y+1
	mWriteString OFFSET sScoreRecord
	mWriteInitialScore

	ret
InitScoreboard ENDP


; їїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїї

DrawScoreBoard PROC
	mGotoxy SCOREBOARD_X, SCOREBOARD_Y
	mWriteString OFFSET sScore
	movzx eax, score 
	call WriteDec 

	mGotoxy SCOREBOARD_X, SCOREBOARD_Y+1
	mWriteString OFFSET sScoreRecord
	movzx eax, scoreRecord
	call WriteDec
	
	ret
DrawScoreBoard ENDP


; їїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїї

DrawSnake PROC
	invoke SetConsoleTextAttribute, hStdOut, green
	
	mov ecx, 0
	.WHILE ecx != snakeSize
		mGotoxy [xPosSnake+ecx], [yPosSnake+ecx]
		mov al, [snake+ecx]
		call WriteChar
		inc ecx
	.ENDW


	invoke SetConsoleTextAttribute, hStdOut, DEFAULT_ATTRIB
	mGotoxy 0, 0

	ret
DrawSnake ENDP


; їїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїї

UpdateSnake PROC
	mov ecx, 0
	.WHILE ecx != snakeSize
		mGotoxy [xPosSnake+ecx], [yPosSnake+ecx]
		mov al, 32 ; space
		call WriteChar
		inc ecx
	.ENDW


	.IF direction == RIGHT
		mMoveSnake xPosSnake, yPosSnake, 1
	.ELSEIF	direction == LEFT
		mMoveSnake xPosSnake, yPosSnake, -1
	.ELSEIF	direction == UP
		mMoveSnake yPosSnake, xPosSnake, -1
	.ELSEIF	direction == DOWN
		mMoveSnake yPosSnake, xPosSnake, 1
	.ENDIF				
	

	call DrawSnake

	ret
UpdateSnake ENDP

; їїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїїї

END 

