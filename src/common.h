; ----------------------------------------------------------------------------
; SOURCE FILE
;
; Name:			common.h
;
; Program:		Assign2
;
; Developer:	Jordan Marling
;
; Created On:	2015-02-09
;
; Functions:
;		qword initialize_socket(dword port)
;		void set_nonblocking_socket(rax qword socket)
;		rax create_thread(rax qword child_func_ptr)
;
; Description:
;		This function contains the function declarations of common.asm
;		Also, this has strutures that are used in multiple files.
;
; ----------------------------------------------------------------------------


; -- functions --
extern initialize_server_socket
extern set_nonblocking_socket
extern create_thread


; Defined epoll_event structure
struc struct_epoll_event
	ee_events	 		resd	1
	ee_data				resq	1		; (ptr: qword, fd: dword, u32: dword, u64: qword)
endstruc


section .data
	; epoll_event struct
	epoll_event:
		istruc struct_epoll_event
			at ee_events, 		dw		0			; default to 0, changed later
			at ee_data, 		dq 		0			; default to 0, changed later
		iend
