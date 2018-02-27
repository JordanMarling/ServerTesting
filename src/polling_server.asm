; ----------------------------------------------------------------------------
; SOURCE FILE
;
; Name:			polling_server.asm
;
; Program:		Assign2
;
; Developer:	Jordan Marling
;
; Created On:	2015-02-02
;
; Functions:
;		void polling_server(eax dword port)
;		void polling_server_worker(rdi qword socket)
;
; Description:
;		This is the polling server. It creates a new process for each
;		incoming connection.
;
; ----------------------------------------------------------------------------

%include "common.h"
%include "constants.asm"

; ----------------------------------------------------------------------------
; GLOBAL FUNCTION DECLARATIONS
global polling_server;
; ----------------------------------------------------------------------------

section .text

; ----------------------------------------------------------------------------
;FUNCTION
;
;Name:			polling server
;
;Prototype:		void polling_server(eax dword port)
;
;Developer:		Jordan Marling
;
;Created On: 	2015-02-02
;
;Parameters:
;		dword port: the port in network byte order to start the server on
;
;Return Values:
;		none
;
;Description:
;		This function creates a listening server socket on the specified
;		port. It sets the SO_REUSEADDR socket option, binds the socket,
;		and sets the server to listen with a backlog of 10.
;
; ----------------------------------------------------------------------------
polling_server:									; polling_server();
	
	; Register uses:
	; r15	: 	listening socket descriptor
	; r14	:	new client socket
	
	
	; -- initialize the listening socket --
	;mov eax, eax								; pass the port into the intialize socket function - already there
	call initialize_server_socket
	mov r15, rax								; store the server socket
	
	cmp rax, -1									; check if the error code was returned
	je POLLING_SERVER_ERROR
	
	
	; -- ACCEPT LOOP --
	POLLING_SERVER_ACCEPT_LOOP:
		
		
		; -- ACCEPT --
		mov rdi, r15							; the server socket	
		xor rsi, rsi							; pointer to sockaddr struct
		xor rdx, rdx							; pointer to sockaddr struct length
		mov rax, SYS_ACCEPT						; accept()
		syscall
		mov r14, rax							; save new fd
		
		cmp rax, -1								; check if the error code was returned
		je POLLING_SERVER_ERROR
		
		
		;; -- CREATE CHILD PROCESS --
		mov rax, polling_server_worker				; the function for the child
		mov rbx, POLLING_STACK_SIZE					; the stack size of the child
		mov rcx, r14								; send the socket descriptor to the child function.
		call create_thread
		
		
	; -- END ACCEPT LOOP --
	jmp POLLING_SERVER_ACCEPT_LOOP
	
	
	; -- CLOSE --
	mov rdi, r15								; server socket
	mov rax, SYS_CLOSE							; close()
	syscall
	
	
	POLLING_SERVER_ERROR:
	ret
	

; ----------------------------------------------------------------------------
;FUNCTION
;
;Name:			polling server worker
;
;Prototype:		void polling_server_worker(rax qword socket)
;
;Developer:		Jordan Marling
;
;Created On: 	2015-02-02
;
;Parameters:
;		qword socket: the client socket
;
;Return Values:
;		none
;
;Description:
;		This function handles the logic of the client connection
;
; ----------------------------------------------------------------------------
polling_server_worker:

	; Register uses:
	; r15	: 	client socket descriptor
	; r14	:	current buffer length
	; r13	:	buffer location
	
	mov r15, rax								; store the client socket
	
	; -- MMAP buffer --
	xor rdi, rdi	 							; addr, 0 means kernel chooses location
	mov rsi, POLLING_BUFFER_LEN					; buffer length
	mov rdx, 0x3								; prot (PROT_READ (0x1) | PROT_WRITE (0x2))
	mov r10, 0x22								; flags (MAP_PRIVATE (0x002) | MAP_ANONYMOUS (0x020))
	mov r8, -1									; fd ignored with MAP_ANONYMOUS (-1 for some implementations)
	;xor r9, r9									; offset ignored with MAP_ANONYMOUS
	mov rax, SYS_MMAP
	syscall
	mov r13, rax								; save the buffer position
	
	POLLING_SERVER_WORKER_RECV_LOOP:
		
		; -- RECVFROM --
		mov rdi, r15								; the new client socket
		mov rsi, r13								; buffer
		mov rdx, POLLING_BUFFER_LEN					; buffer length
		xor r10, r10								; flags
		xor r8, r8									; sockaddr struct
		xor r9, r9									; addrlen
		mov rax, SYS_RECVFROM						; recvfrom()
		syscall
		mov r14, rax								; how many bytes were recieved
		
		cmp rax, 0
		jle POLLING_SERVER_WORKER_ERROR				; 0 or -1, nothing or an error returned.
		
		
		; -- WRITE --
		mov rdi, r15								; client socket - already there
		mov rsi, r13								; buffer - already there
		mov rdx, r14								; buffer length
		mov rax, SYS_WRITE							; write()
		syscall
		
		
		
	jmp POLLING_SERVER_WORKER_RECV_LOOP
	
	POLLING_SERVER_WORKER_ERROR:
	
	; -- CLOSE --
	;mov rdi, r15								; client socket - already there
	mov rax, SYS_CLOSE							; close()
	syscall
	
	
	; -- MUNMAP --
	mov rdi, r13								; buffer location
	mov rsi, POLLING_BUFFER_LEN					; length of buffer
	mov rax, SYS_MUNMAP							; munmap()
	syscall
	
	
	; -- EXIT --
	mov rdi, 0									; exit code, 0 for success.
	mov rax, SYS_EXIT							; exit()
	syscall
	
	;ret
	
