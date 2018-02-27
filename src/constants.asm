; ----------------------------------------------------------------------------
; SOURCE FILE
;
; Name:			constants.asm
;
; Program:		Assign2
;
; Developer:	Jordan Marling
;
; Created On:	2015-02-09
;
; Functions:
;
; Description:
;		This file contains readable defines of system calls and other
;		static values
;
; ----------------------------------------------------------------------------


; -- SYS GLOBALS --
%define		EPOLLIN					1
%define		EPOLLERR				8
%define		EPOLLHUP				16
%define		EPOLLET					0x80000000

%define		F_GETFL					3
%define		F_SETFL					4

%define		O_NONBLOCK				2048

%define		SO_REUSEADDR			2

%define		SOL_SOCKET				1

%define 	STD_IN					0
%define		STD_OUT					1
%define		STD_ERR					2

%define		SYS_WRITE				1
%define		SYS_CLOSE				3
%define		SYS_MMAP				9
%define		SYS_MUNMAP				11
%define		SYS_SELECT				23
%define 	SYS_SOCKET				41
%define		SYS_ACCEPT				43
%define		SYS_RECVFROM			45
%define		SYS_BIND				49
%define		SYS_LISTEN				50
%define		SYS_SETSOCKOPT			54
%define		SYS_GETSOCKOPT			55
%define		SYS_CLONE				56
%define		SYS_FORK				57
%define		SYS_EXIT				60
%define		SYS_FCNTL				72
%define 	SYS_EPOLL_CREATE		213
%define		SYS_EPOLL_WAIT			232
%define		SYS_EPOLL_CTL			233
%define		SYS_ACCEPT4				288


; -- PROGRAM GLOBALS --
%define		GLOBAL_LISTEN_BACKLOG	128


%define		EPOLL_BUFFER_LEN		1024
%define		EPOLL_QUEUE_LEN			128
%define		EPOLL_STACK_SIZE		128


%define		POLLING_BUFFER_LEN		1024
%define		POLLING_STACK_SIZE		1



