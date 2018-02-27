#ifndef SERVERS_H
#define SERVERS_H

//check to see which compiler is being used.
#ifdef __cplusplus
extern "C" void polling_server(int port);
extern "C" void epoll_server_et(int port, int process_count);
extern "C" void epoll_server_lt(int port);
#else
void polling_server(int port);
void epoll_server_et(int port, int process_count);
void epoll_server_lt(int port);
#endif

#endif
