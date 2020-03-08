---
layout: post
title: "Network Programming for Young Bloods"
---

Around a decade in, I find that I’m now considered a specialist/expert in this
field. It wasn’t entirely intentional - previously I was very interested in
programming languages, then became interested in distributed systems, somehow
that led to edge networking and I’ve stayed here ever since.  At this point
I’ve worked at two FAANGs and a startup. I’ve written 1-3 each of
loadbalancers, proxies, caches, protocol stacks, DNS and HTTP servers. I’ve
dealt with DDOSes, mobile telcos, etc.

Networking is particularly tedious in college. I started then dropped the
elective class. But I did a CCNA in high school to get out of PE, and loved
building/futzing with many boxes on a home network - when you have a bunch of
random hardware, you eventually end up trying to build a carpet cluster.

A recent post (https://lobste.rs/s/mthk25/learn_little_network_engineering) got
me thinking about how I’d introduce someone to this field.

Most tech books are poorly written and don’t age well. At best they’re a decent
reference that goes past the docs for a specific technology at a point in time.
Usually they’re garbage.

Note that I left out any books on general software development and languages. I
do have opinions on this, but they’re not particularly strong, and there are
plenty of blogs already. If you are particularly interested, send me an email.

1. Interconnections
2. High Performance Browser Networking
3. Network Routing (only for the chapter on hardware; maybe label switching)
4. Peering Handbook

On the metal podcast - https://oxide.computer/blog/on-the-metal-6-kenneth-finnegan/

If you have an easier time starting with real-world use cases and working back:
http://www.aosabook.org/en/nginx.html
faild paper (NSDI is great)
xdp (https://github.com/ns1/xdp-workshop)

Time Management for Systems Administrators

References:
is parallel programming hard (perfbook)
Computer Systems (first stop before source code or cpu sheets)
TCP/IP Illustrated
Linux Programming Interface
System Performance
BPF Performance Tools

RFCs (dns or bgp are the easiest)

GNS3 and vyos (rolling release or build the LTS from source) or mikrotik; much
easier than a real lab (though if you have the space, it’s still great to mess
with real hardware)

Dispensing with the normal Linux/language advice - it's a hot topic and much
has already been written. You should learn Linux, you'll need to know C and 
C++. Rust is increasingly important for new software. For services it's less
clear-cut - Java, C++, Go, whatever

Stuff that’s hard to teach:

Data analysis

Operations - hard to find any good books; most sound like truisms; only advice
is to make sure you’re involved on the ops side, even if you’re not first tier
support. There is value in working events in real time instead of reading
retroactive summaries (eg. logging, problem solving) If there’s an event, try
to follow along. Especially easy if you use a shared IRC/slack channel or video
call. Pull up graphs, look at logs, etc. - note when you get stuck, try to
identify what piece of information or unanswered question would get you unstuck

Software is important, but not as important as the service it provides when running.

