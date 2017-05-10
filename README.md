# ad-server
Ad Server that responds to GET and POST requests

This progam is a simple ad server which responds to GET and POST requests using the HTTP protocol. It is implemented in perl and can run from command line in any directory on a linux-based OS with the simple invocation:
user@host-machine:~/ perl ./ad-server.pl <port>
	
The directory where it is installed is the server's document root. The server responds to GET and POST requests from browsers and simple http clients like telnet or the Mozilla Firefox Poster tool. 

The server can be reached by calling:
"http://\<host>:<port\>/PARTNER_ID" (GET request) or "http://\<host\>:\<port\>/" (POST request with a json object).
