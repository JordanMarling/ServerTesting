; ----------------------------------------------------------------------------
; SOURCE FILE
;
; Name:			polling_server_lt.asm
;
; Program:		Assign2
;
; Developer:	Jordan Marling
;
; Created On:	2015-02-09
;
; Functions:
;		void epoll_server_et(eax dword port, ebx dword process_count)
;		ax epoll_server_add_descriptor(rax qword socket_descriptor)
;		void epoll_server_worker()
;		void epoll_server_worker_accept()
;
; Description:
;		This is the level-triggered polling server. It creates a new process for each
;		incoming connection.
;
; ----------------------------------------------------------------------------

%include "common.h"
%include "constants.asm"

; ----------------------------------------------------------------------------
; GLOBAL FUNCTION DECLARATIONS
global epoll_server_lt
; ----------------------------------------------------------------------------


section .bss
	; these are global and thread-safe because they are only set once, before
	; any child threads are created.
	epoll_listening_socket: 	resq 	1		; the listening server socket
	epoll_descriptor:			resq	1		; epoll descriptor



section .text



; ----------------------------------------------------------------------------
;FUNCTION
;
;Name:			epoll server level triggered
;
;Prototype:		void epoll_server_lt(eax dword port, ebx dword process_count)
;
;Developer:		Jordan Marling
;
;Created On: 	2015-02-09
;
;Parameters:
;		dword port: the port in network byte order to start the server on
;		dword process_count: the amount of processes to spawn
;
;Return Values:
;		none
;
;Description:
;		This function creates the epoll descriptor and listening socket.
;
; ----------------------------------------------------------------------------
epoll_server_lt:
	
	; Register uses:
	; r15	:	process_count (tmp)
	
	
	mov r15d, ebx								; store the process count
	
	
	; -- initialize the listening socket --
	;port is already in eax
	;mov eax, eax								; pass the port into the intialize socket function
	call initialize_server_socket
	mov [epoll_listening_socket], rax			; store the server socket
	
	cmp rax, -1									; check if the error code was returned
	je EPOLL_SERVER_ERROR
	
	
	; -- Set listening socket to non-blocking --
	mov rax, [epoll_listening_socket]			; socket descriptor
	call set_nonblocking_socket
	
	cmp rax, -1									; check if the error code was returned
	je EPOLL_SERVER_ERROR
	
	
	
	; -- EPOLL_CREATE --
	mov rdi, 1									; size, ignored
	mov rax, SYS_EPOLL_CREATE					; epoll_create()
	syscall
	
	cmp rax, -1									; returns an invalid descriptor
	jle EPOLL_SERVER_ERROR
	
	mov [epoll_descriptor], rax					; store epoll descriptor
	
	
	; -- Add listening socket to epoll descriptor --
	mov rax, [epoll_listening_socket]			; listening socket
	call epoll_server_add_descriptor
	
	cmp rax, -1									; check for error code
	je EPOLL_SERVER_ERROR
	
	
	; -- Create child threads --
	mov rcx, r15								; set loop counter to process count
	dec rcx
	
	; check to see if there should be more threads to be created.
	cmp rcx, 1
	jle EPOLL_SERVER_THREAD_LOOP_END
	
	
	EPOLL_SERVER_THREAD_LOOP:					; for (rcx = proc_count - 1; rcx >= 0; rcx--)
		
		push rcx
		
		; -- CREATE THREAD --
		mov rax, epoll_server_worker			; the function to be called in the thread
		mov rbx, EPOLL_STACK_SIZE				; the stack size
		call create_thread
		
		pop rcx
		
		dec rcx									; increment loop counter
	cmp rcx, 1
	jge EPOLL_SERVER_THREAD_LOOP
	
	
	EPOLL_SERVER_THREAD_LOOP_END:
	
	; -- Finished creating threads --
	; -- Become a worker thread --
	call epoll_server_worker
	
	
	EPOLL_SERVER_ERROR:
	ret
	
	
	
	
	
	
; ----------------------------------------------------------------------------
;FUNCTION
;
;Name:			Add Epoll Descriptor level-triggered
;
;Prototype:		ax epoll_server_add_descriptor(rax qword socket_descriptor)
;
;Developer:		Jordan Marling
;
;Created On: 	2015-02-10
;
;Parameters:
;		qword socket_descriptor: the socket to add
;
;Return Values:
;		ax 0 if success, -1 if failure
;
;Description:
;		This function adds the socket to the epoll descriptor
;
; ----------------------------------------------------------------------------
epoll_server_add_descriptor:
	
	; Register uses:
	
	; save registers
	push r10
	
	; -- EPOLL_CTL --
	mov qword [ epoll_event + ee_data ], rax	; move the listening socket
	mov dword [ epoll_event + ee_events ], EPOLLIN | EPOLLERR | EPOLLHUP	; flags
	mov rdi, [epoll_descriptor]					; epoll descriptor
	mov rsi, 1									; EPOLL_CTL_ADD
	mov rdx, rax								; socket descriptor
	mov r10, epoll_event						; pointer to epoll_event struct
	mov rax, SYS_EPOLL_CTL						; epoll_ctl()
	syscall
	
	cmp rax, -1									; check if error code
	je EPOLL_SERVER_ADD_DESCRIPTOR_ERROR
	
	
	mov rax, 0									; success
	pop r10
	ret
	
	
	EPOLL_SERVER_ADD_DESCRIPTOR_ERROR:
	mov rax, -1									; error code
	pop r10
	ret
	

; ----------------------------------------------------------------------------
;FUNCTION
;
;Name:			Epoll Server Worker Process
;
;Prototype:		void epoll_server_worker()
;
;Developer:		Jordan Marling
;
;Created On: 	2015-02-10
;
;Parameters:
;
;Return Values:
;		none
;
;Description:
;		This function is the main logic for the epoll worker process.
;
; ----------------------------------------------------------------------------
epoll_server_worker:
	
	; Register uses:
	; r15	:	starting address of the epoll_event struct array.
	; r14d	:	epoll_event structure events parameter
	; r13	:	epoll_event structure data parameter
	; r12	:	buffer pointer, buffer length: 1024 bytes
	
	
	; save registers
	push r15
	push r14
	push r13
	push r12
	push r11
	push r10
	push r9
	push r8
	
	push rbp									; save stack pointer
	mov rbp, rsp								; new base stack pointer
	
	
	; -- MMAP buffer --
	xor rdi, rdi	 							; addr, 0 means kernel chooses location
	mov rsi, EPOLL_BUFFER_LEN					; buffer length
	mov rdx, 0x3								; prot (PROT_READ (0x1) | PROT_WRITE (0x2))
	mov r10, 0x22								; flags (MAP_PRIVATE (0x002) | MAP_ANONYMOUS (0x020))
	mov r8, -1									; fd ignored with MAP_ANONYMOUS (-1 for some implementations)
	;xor r9, r9									; offset ignored with MAP_ANONYMOUS
	mov rax, SYS_MMAP
	syscall
	mov r12, rax								; save the buffer position
	
	
	; -- MMAP epoll_event array --
	xor rdi, rdi	 							; addr, 0 means kernel chooses location
	mov rsi, EPOLL_QUEUE_LEN*12					; buffer length
	mov rdx, 0x3								; prot (PROT_READ (0x1) | PROT_WRITE (0x2))
	mov r10, 0x22								; flags (MAP_PRIVATE (0x002) | MAP_ANONYMOUS (0x020))
	mov r8, -1									; fd ignored with MAP_ANONYMOUS (-1 for some implementations)
	;xor r9, r9									; offset ignored with MAP_ANONYMOUS
	mov rax, SYS_MMAP
	syscall
	mov r15, rax								; save the epoll_event array position
	
	
	; server loop
	EPOLL_SERVER_WORKER_LOOP:
		
		
		; -- EPOLL_WAIT --
		mov rdi, [epoll_descriptor]				; epoll descriptor
		mov rsi, r15					
					
		mov rdx, EPOLL_QUEUE_LEN				; amount of epoll_event structs
		mov r10, -1								; timeout -1 is infinite.
		mov rax, SYS_EPOLL_WAIT					; epoll_wait()
		syscall
		
		cmp rax, 0								; check how many events are triggered
		jl EPOLL_SERVER_WORKER_ERROR
		
		mov rcx, rax							; move the number of ready descriptors into loop
		dec rcx									; loop goes from rcx-1 to 0
		
		; epoll event loop
		EPOLL_SERVER_WORKER_EVENT_LOOP:			; for (i = rcx - 1; rcx >= 0; rcx--)
			
			; r15 + (rcx*12) - the position of the epoll_event element
			mov rax, rcx
			imul rax, 12
			add rax, r15
			
			
			mov r14d, [rax]						; move the epoll_event event into the register
			mov r13, [rax + 4]					; move the epoll_event data into the register
			
			
			push rcx							; save rcx counter
			
			
			; if socket has closed or an error has happened
			mov r11d, r14d						; copy the event
			and r11d, EPOLLHUP | EPOLLERR		; compare with (EPOLLHUP | EPOLLERR) for close/error
			jnz EPOLL_SERVER_WORKER_EVENT_LOOP_CLOSE
			
			; if socket is listening socket
			cmp r13, [epoll_listening_socket]	; check if the fd is the server socket
			je EPOLL_SERVER_WORKER_EVENT_LOOP_ACCEPT
			
			; else incoming data
			jmp EPOLL_SERVER_WORKER_EVENT_LOOP_DATA
			
			
			
			
			; -- ERROR OR CLOSE --
			EPOLL_SERVER_WORKER_EVENT_LOOP_CLOSE:
			
				; -- CLOSE --
				mov rdi, r13						; the socket descriptor
				mov rax, SYS_CLOSE					; close()
				syscall
			
			jmp EPOLL_SERVER_WORKER_EVENT_LOOP_END
			
			
			
			; -- INCOMING CONNECTION --
			EPOLL_SERVER_WORKER_EVENT_LOOP_ACCEPT:
			
				; -- ACCEPT4 -- 
				call epoll_server_worker_accept
			
			jmp EPOLL_SERVER_WORKER_EVENT_LOOP_END
			
			
			
			; -- INCOMING DATA --
			EPOLL_SERVER_WORKER_EVENT_LOOP_DATA:
			
			
				; -- RECVFROM LOOP
				EPOLL_SERVER_WORKER_EVENT_LOOP_DATA_RECV:
					
					
					; echo the data
					
					
					; -- RECVFROM --
					mov rdi, r13								; the client socket
					mov rsi, r12								; buffer
					mov rdx, EPOLL_BUFFER_LEN					; buffer length
					xor r10, r10								; flags
					xor r8, r8									; sockaddr struct
					xor r9, r9									; addrlen
					mov rax, SYS_RECVFROM						; recvfrom()
					syscall
					mov r14, rax								; how many bytes were recieved
					
					; check for error
					cmp rax, 0
					je EPOLL_SERVER_WORKER_EVENT_LOOP_CLOSE		; rax = 0: CLOSED
					jl EPOLL_SERVER_WORKER_EVENT_LOOP_END 		; rax < 0: EAGAIN
					
					
					; echo to client.
					; -- WRITE --
					;mov rdi, r13								; the client socket - already there
					;mov rsi, r12								; the buffer location - already there
					mov rdx, r14								; buffer length
					mov rax, SYS_WRITE
					syscall
					
					
				jmp EPOLL_SERVER_WORKER_EVENT_LOOP_DATA_RECV
			
			
			EPOLL_SERVER_WORKER_EVENT_LOOP_END:
			
			
			pop rcx
			dec rcx
		cmp rcx, 0
		jge EPOLL_SERVER_WORKER_EVENT_LOOP
		
		
	jmp EPOLL_SERVER_WORKER_LOOP
	
	
	
	EPOLL_SERVER_WORKER_ERROR:
	pop rbp										; restore stack frame
	
	; pop saved registers
	pop r8
	pop r9
	pop r10
	pop r11
	pop r12
	pop r13
	pop r14
	pop r15
	ret



; ----------------------------------------------------------------------------
;FUNCTION
;
;Name:			Epoll Server Worker Accept
;
;Prototype:		void epoll_server_worker_accept()
;
;Developer:		Jordan Marling
;
;Created On: 	2015-02-10
;
;Parameters:
;
;Return Values:
;		none
;
;Description:
;		This function accepts a socket and adds it to the epoll descriptor
;
; ----------------------------------------------------------------------------
epoll_server_worker_accept:
	
	; Register uses:
	
	; save registers
	push r10
	
	
	EPOLL_SERVER_WORKER_ACCEPT_LOOP:
		
		; -- ACCEPT4 --
		mov rdi, [epoll_listening_socket]			; server socket
		xor rsi, rsi								; sockaddr struct
		xor rdx, rdx								; addrlen
		mov r10, O_NONBLOCK							; sets the O_NONBLOCK flag automatically
		mov rax, SYS_ACCEPT4						; accept4()
		syscall
		
		; if accept4() returns -1, no socket
		cmp rax, 0									; -1 if no socket can be accepted
		jle EPOLL_SERVER_WORKER_ACCEPT_COMPLETED
		
		; else, add the socket to epoll
		;mov r15, rax								; store the new socket - already there
		call epoll_server_add_descriptor
		
		
	jmp EPOLL_SERVER_WORKER_ACCEPT_LOOP
	
	
	EPOLL_SERVER_WORKER_ACCEPT_COMPLETED:
	
	; restore registers
	pop r10
	
	ret
