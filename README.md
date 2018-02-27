# ServerTesting
Testing Multi-threaded, Level Triggered, and Edge Triggered Servers


This application is written in C and 64-bit Assembly for the Linux platform. C is used at the programs
starting point to gather input arguments to direct how the servers are run. Assembly is used for
everything else. Its purpose is to measure the differences between a multithreaded, level triggered, and
edge triggered servers in performance.


The multithreaded polling server creates its child processes through the clone system call. Each
spawned process only uses 1 byte of stack space and a 1024 byte recieving buffer. This allows for each
process to have an extremely small footprint to make for quicker context changes by the kernel.


The level triggered and edge triggered servers both create one 1024 byte recieving buffer. Both of these
servers were recorded using under 5000 bytes of memory during 40,000+ client connections constantly
sending data.


These servers just echo data back to the client and can only handle up to 1024 bytes. Need a client to test this with.


## Usage

./assign2 [-h] [-t type] [-p port] [-P count]

	-h: prints this help information.
	
	-p: sets the port (default: 8888)
	
	-t: the type of server (poll/select/epoll) (default: poll)
	
	-P: the amount of processes to use (default: 2)

