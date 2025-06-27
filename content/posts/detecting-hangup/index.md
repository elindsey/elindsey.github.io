---
date: "2025-06-27T00:00:00Z"
title: Detecting Hangup
aliases:
    - /2025/06/27/detecting-hangup
---

Let's suppose you create a TCP connection but may not use it for some time, for
example in a preconnected pool of TCP connections. When you eventually go to use
it, there's a possibility that the other end has already decided to hang up and
close the connection - at which point you'd like to either pull another
connection, establish an entirely fresh connection, or take some other action.

Let's further suppose that a connection is 'dead' for our purposes if it's
either half or fully closed. There are some valid uses for half-closed
connections, but they're uncommon and a layer 7 request/response protocol (http,
DNS, etc.) is generally not one of them.

How would you go about detecting that a connection taken from the preconnected
pool is dead?

The first idea is to simply write() to it and see if it returns an error. But
this can incur much more latency than you might think. If the other end has
closed and sent us a FIN then the connection will be half-closed.  The write()
succeeds, the bytes go across the network, the remote host sends a RST in
response, and subsequent calls to write() will now return an error. It takes us
a network round trip to discover that the connection is dead, and our
application logic becomes much more complicated since it now needs some form of
"retry with another connection from the pool" logic for writes _after_ the first
one.

Ideally we'd be able to detect that the FIN was received and treat half-closed
connections as dead prior to the initial write(). On some operating systems
(FreeBSD, Linux) there's an explicit event that can be polled for to detect this
condition: `POLLRDHUP`. On operating systems that don't support this event
(Darwin), you can usually get away with polling for readability via `POLLIN`.
Assuming a request/response layer 7 protocol, if the client has preconnected a
TCP connection but not yet used it then any readability events (including FIN
received) are unexpected and cause for discarding the connection.
