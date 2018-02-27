; ----------------------------------------------------------------------------
; SOURCE FILE
;
; Name:			common.asm
;
; Program:		Assign2
;
; Developer:	Jordan Marling
;
; Created On:	2015-02-09
;
; Functions:
;		qword initialize_socket(eax dword port)
;		void set_nonblocking_socket(rax qword socket)
;		rax create_thread(rax qword child_func_ptr)
;
; Description:
;		This file contains all common functions that each of the types of
;		servers can use.
;
; ----------------------------------------------------------------------------

%include "constants.asm"

; ----------------------------------------------------------------------------
; GLOBAL FUNCTION DECLARATIONS
global initialize_server_socket
global set_nonblocking_socket
global create_thread
; ----------------------------------------------------------------------------



; sockaddr_in struct to be bound to the server socket
struc struct_sockaddr_in
	sin_family 		resw	1
	sin_port		resw	1
	sin_addr		resd	1
endstruc


section .data
	
	; Server sockaddr struct
	sockaddr_in:
		istruc struct_sockaddr_in
			at sin_family, 	dw		2			; AF_INET
			at sin_port, 	dw 		0xB822		; port 8888 (0x22B8) by default in network byte order
			at sin_addr, 	dd 		0			; INADDR_ANY
		iend



section .bss
	
	
	
section .text

; ----------------------------------------------------------------------------
;FUNCTION
;
;Name:			initialize socket
;
;Prototype:		qword initialize_socket(dword port)
;
;Developer:		Jordan Marling
;
;Created On: 	2015-02-09
;
;Parameters:
;		dword port: the port in network byte order to start the server on
;
;Return Values:
;		qword socket descriptor
;
;Description:
;		This function creates a listening server socket on the specified
;		port. It sets the SO_REUSEADDR socket option, binds the socket,
;		and sets the server to listen with a backlog of 10.
;
; ----------------------------------------------------------------------------
initialize_server_socket:
	
	; Register uses:
	; r15	: 	socket descriptor
	; r14d	: 	the port number in network byte order
	
	; store previous registers
	push r15
	push r14
	push r10
	push r8
	
	
	push rbp									; save stack pointer
	mov rbp, rsp								; new base stack pointer
	
	
	mov r14d, eax								; store the port into r15d
	
	
	; -- CREATE SOCKET --
	mov rdi, 2									; AF_INET = 2
	mov rsi, 1									; SOCK_STREAM = 1
	mov rdx, 6									; IPPROTO_TCP = 6
	mov rax, SYS_SOCKET							; socket() 
	syscall
	mov r15, rax								; save the socket descriptor
	
	
	; -- SOCKOPT REUSE --
	mov rdi, r15								; listening socket
	mov r8, 8									; sizeof int
	mov qword [rbp-24], 1						; option value
	mov r10, rbp
	sub r10, 24									; pointer of option value (rbp-24)
	mov rdx, SO_REUSEADDR						; SO_REUSEADDR
	mov rsi, SOL_SOCKET							; SOL_SOCKET
	mov rax, SYS_SETSOCKOPT						; setsockopt()
	syscall
	
	
	; -- FILL SOCKADDR_IN STRUCT --
	mov dword [ sockaddr_in + sin_port ], r14d	; put the port into the sockaddr_in struct
	
	
	; -- BIND --
	mov rdi, r15								; the server socket	
	mov rsi, sockaddr_in						; the server socket address, including port
	mov rdx, 16									; the size of the socket address
	mov rax, SYS_BIND							; bind()
	syscall
	
	
	cmp rax, -1									; check if bind returned -1 (error)
	je INITIALIZE_SERVER_SOCKET_ERROR
	
	
	; -- LISTEN --
	mov rdi, r15								; the server socket	
	mov rsi, GLOBAL_LISTEN_BACKLOG				; backlog
	mov rax, SYS_LISTEN							; listen()
	syscall
	
	
	
	; success
	mov rax, r15								; return the socket descriptor
	
	pop rbp										; restore stack frame
	
	
	; pop saves registers
	pop r8
	pop r10
	pop r14
	pop r15
	
	
	ret
	
	
	INITIALIZE_SERVER_SOCKET_ERROR:
	
	; an error has happened. return -1
	mov rax, -1									; return the error code
	
	pop rbp										; restore stack frame
	
	
	; pop saves registers
	pop r14
	pop r15
	
	
	ret




; ----------------------------------------------------------------------------
;FUNCTION
;
;Name:			set nonblocking socket
;
;Prototype:		void set_nonblocking_socket(rax qword socket)
;
;Developer:		Jordan Marling
;
;Created On: 	2015-02-09
;
;Parameters:
;		qword socket: the socket to make non-blocking
;
;Return Values:
;		none
;
;Description:
;		Sets the socket to be non-blocking.
;
; ----------------------------------------------------------------------------
set_nonblocking_socket:
	
	; Register uses:
	; r15	: 	socket descriptor
	
	; save registers
	push r15
	
	
	mov r15, rax								; store socket descriptor
	
	
	; -- GET FLAGS --
	mov rdi, r15								; socket descriptor
	mov rsi, F_GETFL							; F_GETFL = 3
	;mov rdx, 0									; ignored
	mov rax, SYS_FCNTL							; fcntl()
	syscall
	
	
	or rax, O_NONBLOCK							; add O_NONBLOCK to flags
	
	
	; -- SET FLAGS --
	mov rdi, r15								; socket descriptor
	mov rsi, F_SETFL							; F_SETFL = 4
	mov rdx, rax								; flags
	mov rax, SYS_FCNTL							; fcntl()
	syscall
	
	; pop saved registers
	pop r15
	
	ret




	
; ----------------------------------------------------------------------------
;FUNCTION
;
;Name:			create thread
;
;Prototype:		rax create_thread(rax qword child_func_ptr, rbx qword stack_size, rcx qword child_variable)
;
;Developer:		Jordan Marling
;
;Created On: 	2015-02-10
;
;Parameters:
;		qword child_func_ptr: The address of the instruction to be called on the child
;		qword stack_size: The size of the stack in bytes
;		qword child_variable: The variable to be passed into the child.
;
;Return Values:
;		rax qword a pointer to the stack address
;
;Description:
;		Creates a new thread with the specificed stack size. It puts the rcx variable into
;		the rax register.
;
; ----------------------------------------------------------------------------
create_thread:
	
	; Register uses:
	; r15	: 	stack ptr
	; r14	:	child_variable
	
	; save registers
	push r15
	push r14
	push r10
	push r9
	push r8
	
	
	mov r15, rax								; save the child function
	mov r14, rcx								; save the child variable
	
	
	; -- MMAP (Create new stack space) --
	xor rdi, rdi	 							; addr, 0 means kernel chooses location
	mov rsi, rbx	 							; stack size
	mov rdx, 0x3								; prot (PROT_READ (0x1) | PROT_WRITE (0x2))
	mov r10, 0x122								; flags (MAP_PRIVATE (0x002) | MAP_ANONYMOUS (0x020) | MAP_GROWSDOWN (0x100))
	mov r8, -1									; fd ignored with MAP_ANONYMOUS (-1 for some implementations)
	;xor r9, r9									; offset ignored with MAP_ANONYMOUS
	mov rax, SYS_MMAP
	syscall
	
	; -- CLONE (Create new thread) --
	mov rdi, 0x10f11
	mov rsi, rax								; child stack pointer from SYS_MMAP system call
	xor rdx, rdx								; parent_tidptr
	xor r10, r10								; child_tidptr
	xor r8, r8									; tls_val
	mov rax, SYS_CLONE							; clone()
	syscall
	
	cmp rax, 0									; check if the return value indicates parent, if so exit function
	jnz CREATE_THREAD_PARENT
	
	
	; -- CHILD HERE --
	mov rax, r14								; insert variable
	jmp r15										; push the childs function address
	; no return because of jmp.
	
	
	; -- PARENT HERE --
	CREATE_THREAD_PARENT:
	
	; pop saved registers
	pop r8
	pop r9
	pop r10
	pop r14
	pop r15
	
	ret








