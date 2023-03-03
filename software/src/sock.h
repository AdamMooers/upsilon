#pragma once

/* Initialize server to listen on the port passed as an argument. */
int server_init_sock(int port);

/* Accept a client and allocate a file descriptor for the client. */
int server_accept_client(int server);
