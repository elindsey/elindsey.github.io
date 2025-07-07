---
date: "2025-07-14T00:00:00Z"
title: Connected UDP Sockets and ICMP Errors
aliases:
    - /2025/07/14/connectedudp
---

UDP sockets can be created as connected or unconnected. This is purely a local
convenience and has no bearing on the underlying protocol - it's the same
connectionless UDP protocol either way. A connected UDP socket is just a way to
say "this socket will always send to and receive from remote address FOO", thus
letting you use the simpler `send()/recv()` syscalls instead of
`sendto()/recvfrom()`.

However, this may also have a quirky effect on what errors are surfaced.
Specifically, asynchronous network errors on Linux are supposed to be surfaced
to the UDP socket whether or not it's connected, but on BSDs you will likely
only see errors surfaced for connected sockets. This comes from differing
interpretations/implementations of [RFC 1122](https://www.rfc-editor.org/rfc/rfc1122#page-78).

In practice what this ends up meaning is that errors communicated via ICMP (eg.
time exceeded, destination unreachable) will show up as syscall return errors
for some subsequent socket operation (EHOSTUNREACH and ECONNREFUSED,
respectively).  This can be surprising and a bit annoying in cases where you're
actually intending to generate these ICMP reponses, such as a traceroute
implementation or similar network probing. In those cases, depending on the
platform and depending on if the socket is connected or unconnected you may need
to ignore and retry certain classes of errors on read/write.