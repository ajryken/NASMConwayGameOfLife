segment .data

	; CUSTOMIZABLE GRID SIZE (EQU IS CONST VERION OF DB)
	rows		equ 32
	columns 	equ 64
	arr_len		equ rows * columns + rows

	; GRID STATE
	alive		equ 'O'
	dead		equ 32	; [SPACE]

	time:
   		tv_sec  dq 0		; SECONDS
   		tv_nsec dq 50000000	; NANOSECONDS			50000000 = .05 SECONDS

	; ARRAYS FOR CURRENT GENERATION AND NEXT GENERATION
	current_gen 		times arr_len db 10
	next_gen			times arr_len db 10

	gen_num		dd	0
	gen_msg		db	"Generation %d",10,0

	clrscrn		db 27, "[2J", 27, "[H"
	clrscrn_len	equ	$-clrscrn

	menu_msg		db	"************************************************************************",10,"*                                                                      *",10,"*                             GAME OF LIFE                             *",10,"*                                RULES:                                *",10,"*                                                                      *",10,"*  1. Any living cell with 2 or 3 neighbors survives the generation.   *",10,"*  2. Any dead cell with 3 neighbors becomes a living cell.            *",10,"*  3. All other living cells die and all other dead cells stay dead.   *",10,"*                                                                      *",10,"************************************************************************",10,10,"PRESS ENTER TO BEGIN...",10,0
	menu_len	equ $-menu_msg

segment .bss


segment .text
	global main
	extern printf

; SYSCALL_WRITE MACRO BECAUSE I USE IT TOO MUCH IN THIS PROGRAM
%macro display 2
	mov		eax, 1
	mov		edi, 1
	mov		rsi, %1
	mov		edx, %2
	syscall
%endmacro

main:
	push	rbp
	mov		rbp, rsp
	; ********** CODE STARTS HERE **********

	; MENU DISPLAY
	display clrscrn, clrscrn_len
	display	menu_msg, menu_len
	mov		rax, 0
	mov		rdi, 0
	mov		rdx, 1
	syscall						; REALLY GREAT AND TOTALLY NOT A WEIRD WORKAROUND FOR PAUSE UNTIL ENTER IS PRESSED

	call 	basegen
	mov 	r15, current_gen
	mov 	r14, next_gen
	.initialize:
		inc			DWORD [gen_num]
		xchg 		r14, r15		; SWAPS FOR FUTURE GENERATION
		display 	r14, arr_len	; OUTPUTS GENERATION
		mov			rdi, gen_msg
		mov			rsi, [gen_num]
		call		printf			; KEEPS TRACK OF THE GENERATIONS ELAPSED

		mov 		eax, 35			; SYS_NANOSLEEP
		mov 		rdi, time
		mov			esi, 0
		syscall
		display 	clrscrn, clrscrn_len
		jmp 		nextgen

	; ********** CODE ENDS HERE **********
	mov		rax, 0
	mov		rsp, rbp
	pop		rbp
	ret

;PRNG USING WEYL SEQUENCE FOR INITIALIZATION ( NOT GREAT SEQUENCE BUT BASED OFF VON NEUMANN WHO INSPIRED THE GAME'S CREATION)
basegen:
	; SEED OF GAME
	mov		eax, 201		; SYS_TIME
	mov		edi, 0
	syscall
	mov		r14d, eax
	and		eax, 1
	dec		eax

	mov		cx, 0			; RANDOM NUMBER STORED HERE
	mov		r15w, 0			; WEYL SEQUENCE STORED HERE
	mov rbx, columns

	; ACTUAL PRNG
	start:
		mov 	eax, ecx
		mul 	ecx
		add 	r15d, r14d
		add 	eax, r15d
    	mov 	al, ah
    	mov 	ah, bl
		mov 	ecx, eax
		and 	rax, 1
		cmp		rax, 0
		je		death
			add 	rax, alive - dead - 1
		death:
			add rax, dead

		; UPDATING BOARD
		mov 	[current_gen + rdi], al
		inc 	rdi
		cmp 	rdi, rbx
		jne 	next
			inc 	rdi
			add 	rbx, columns + 1

		; CHECKS IF END OF ARRAY TO MOVE ON TO NEXT GENERATION
		next:
			cmp 	rdi, arr_len
			jne 	start

	ret

; ALL GENERATIONS AFTER THE FIRST
nextgen:

	; ************************************************************************
	; *																		 *
	; *                             GAME OF LIFE                             *
	; *                                 RULES:                               *
	; *                                                                      *
	; *  1. Any living cell with 2 or 3 neighbors survives the generation.   *
	; *  2. Any dead cell with 3 neighbors becomes a living cell.            *
	; *  3. All other living cells die and all other dead cells stay dead.   *
	; *                                                                      *
	; ************************************************************************

	mov		ebx, 0
	game_logic:
		cmp		BYTE [r14 + rbx], 10
		je		next_cell									; PREVENTS WRAPAROUND COUNTING AS NEIGHBOR
		mov		eax, 0										; ALIVE NEIGHBOR COUNTER
		neighbors_above:
			mov 	rdx, rbx								; USED TO CHECK EACH NEIGHBOR FOR STATE
			dec 	rdx
			cmp		rdx, 0
			je		neighbors_below							; MIDDLE LEFT
				mov 	cl, [r14 + rdx]
				and 	cl, 1
				add 	al, cl
				sub 	rdx, columns - 1
				cmp		rdx, 0
				je 		neighbors_below						; TOP RIGHT
					mov 	cl, [r14 + rdx]
					and 	cl, 1
					add 	al, cl
					dec 	rdx
					cmp		rdx, 0
					je 		neighbors_below					; TOP MIDDLE
						mov 	cl, [r14 + rdx]
						and 	cl, 1
						add 	al, cl
						dec 	rdx
						cmp		rdx, 0
						je		neighbors_below				; TOP LEFT
							mov 	cl, [r14 + rdx]
							and 	cl, 1
							add 	al, cl
		neighbors_below:
			mov 	rdx, rbx									; RESETS REGISTER USED TO CHECK EACH NEIGHBOR
			inc 	rdx
			cmp 	rdx, arr_len - 1							; MIDDLE RIGHT
			jge 	fate
				mov 	cl, [r14 + rdx]
				and 	cl, 1
				add 	al, cl
				add 	rdx, columns - 1
				cmp 	rdx, arr_len - 1						; BOTTOM LEFT
				jge 	fate
					mov 	cl, [r14 + rdx]
					and 	cl, 1
					add 	al, cl
					inc 	rdx
					cmp 	rdx, arr_len - 1					; BOTTOM MIDDLE
					jge 	fate
						mov 	cl, [r14 + rdx]
						and 	cl, 1
						add 	al, cl
						inc 	rdx
						cmp 	rdx, arr_len - 1				; BOTTOM RIGHT
						jge fate
							mov 	cl, [r14 + rdx]
							and 	cl, 1
							add 	al, cl
		; ASSIGNS CELLS OF NEXT GENERATION
		fate:
			cmp 	al, 2
			je		status_quo									; 2 NEIGHBORS
				mov		BYTE [r15 + rbx], dead
				cmp 	al, 3
				jne 	next_cell								; DEAD CELL
					mov 	BYTE [r15 + rbx], alive
					jmp 	next_cell							; 3 NEIGHBORS
		; ASSIGNS SAME STATE TO CELL OF NEXT GENERATION
		status_quo:
			mov 	cl, [r14 + rbx]
			mov 	[r15 + rbx], cl
		; INCREMENTS THROUGH ARRAY
		next_cell:
			inc 	rbx
			cmp 	rbx, arr_len
			jne 	game_logic
			jmp 	main.initialize

	inc		DWORD [gen_num]

	ret
