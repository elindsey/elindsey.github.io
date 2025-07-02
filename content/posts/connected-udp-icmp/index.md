---
date: "2025-07-01T00:00:00Z"
title: Connected UDP Sockets and ICMP
aliases:
    - /2025/07/14/connectedudp
draft: true
---

UDP sockets can be created as connected or unconnected. This is purely a local
convenience and has no bearing on the protocol - it's the same connectionless
UDP protocol either way. A connected UDP socket is just a way to say "this
socket will always send to and receive from remote address FOO", thus letting
you use the simpler `send()/recv()` syscalls instead of `sendmsg()/recvmsg()`. 
(or is it sendto/recvfrom?)


http://www.softlab.ntua.gr/facilities/documentation/unix/unix-socket-faq/unix-socket-faq-5.html

https://www.man7.org/linux/man-pages/man7/udp.7.html
https://www.rfc-editor.org/rfc/rfc1122#page-78

All fatal errors will be passed to the user as an error return
       even when the socket is not connected.  This includes asynchronous
       errors received from the network.  You may get an error for an
       earlier packet that was sent on the same socket.  This behavior
       differs from many other BSD socket implementations which don't
       pass any errors unless the socket is connected.