/* ----------------------------------------------------------------------------
SOURCE FILE

Name:		main.c

Program:	Assign2

Developer:	Jordan Marling

Created On:	2015-02-02

Functions:
	int main(int argc, char **argv)
	void print_usage(char *program_name)

Description:
	This program can gathers data about three server models:
		- Polling
		- Select
		- Epoll
	The data from these servers can then be compared externally
	
	Usage: ./assign2
		-h: prints this help information.
		-p: sets the port.
		-t: the type of server (poll/select/epoll)
		-P: the amount of processes

---------------------------------------------------------------------------- */
#include <getopt.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>

#include "constants.h"
#include "servers.h"


void print_usage(char *program_name);


int main(int argc, char **argv) {
	
	int opt, opt_index;
	struct option option_args[] = {
		{ "help", 			no_argument, 		0, 'h' },
		{ "port",			required_argument,	0, 'p' },
		{ "type",			required_argument,	0, 't' },
		{ "processes",		required_argument,	0, 'P' }
	};
	
	int type = DEFAULT_TYPE_POLL;
	int port = DEFAULT_PORT;
	int process_count = DEFAULT_PROCESS_COUNT;
	
	//get the command line arguments.
	while ((opt = getopt_long(argc, argv, "hp:t:P:", option_args, &opt_index)) != -1) {
		switch (opt) {
			//help
			case 'h':
				
				print_usage(argv[0]);
				return 0;
			
			//port
			case 'p':
				if (sscanf(optarg, "%d", &port) != 1) {
					print_usage(argv[0]);
					return 1;
				}
				break;
			
			//type (poll, select, epoll)
			case 't':
				if (strcmp(optarg, "poll") == 0) {
					type = DEFAULT_TYPE_POLL;
				}
				else if (strcmp(optarg, "level") == 0) {
					type = DEFAULT_TYPE_EPOLL_LEVEL;
				}
				else if (strcmp(optarg, "edge") == 0) {
					type = DEFAULT_TYPE_EPOLL_EDGE;
				}
				else {
					print_usage(argv[0]);
					return 1;
				}
				break;
			
			//thread count
			case 'P':
				if (sscanf(optarg, "%d", &process_count) != 1) {
					print_usage(argv[0]);
					return 1;
				}
				break;
			
		}
	}
	
	switch(type) {
		
		case DEFAULT_TYPE_POLL:
			
			polling_server(htons(port));
			
			break;
		
		case DEFAULT_TYPE_EPOLL_LEVEL:
			
			epoll_server_lt(htons(port));
			
			break;
		
		case DEFAULT_TYPE_EPOLL_EDGE:
			
			epoll_server_et(htons(port), process_count);
			
			break;
		
		default:
			print_usage(argv[0]);
			return 1;
	}
	
	return 0;
}

void print_usage(char *program_name) {
	
	printf("Usage: %s [-h] [-t type] [-p port] [-P count]\n", program_name);
	printf("\t-h: prints this help information.\n");
	printf("\t-p: sets the port (default: %d)\n", DEFAULT_PORT);
	printf("\t-t: the type of server (poll/select/epoll) (default: poll)\n");
	printf("\t-P: the amount of processes to use (default: %d)\n", DEFAULT_PROCESS_COUNT);
	printf("\t\n");
}
