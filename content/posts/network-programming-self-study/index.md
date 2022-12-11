---
date: "2020-05-10T00:00:00Z"
title: Network Programming Self-Study
aliases:
    - /2020/05/10/network-programming-self-study.html
---

Lately I've been getting more questions about how to start out in network programming: what books to read, what projects to do, and how to make a career of it.

I've been in this space ten years now, working across layers 3 to 7 on CDNs, DNS, and protocol stacks at a couple of FAANGs and a startup. If you name a piece of software that runs in an edge network, I've probably seen one (or three) versions of it.

Advice is tricky. It's easy to turn things I learned into Things Everyone Should Learn. It's also easy to fit an inaccurate narrative to a path, to recast something as a logical progression when it was really blind stumbling around. 
I could spin a yarn about how networking was the first thing I did with computers, how I did a CCNA in high-school and something something destiny. But I could also tell the story of how I did that CCNA primarily to get out of taking PE, and how I found my college networking class so tedious that I dropped it in the first week and never tried again (for some inexplicable reason it was an optional elective at my university).

I'll avoid all that - I don't think my exact career path is all that interesting. But I'll offer one piece of advice (because I can't entirely resist), and a handful of books that I've found useful and interesting (because too many are not both). If the advice doesn't resonate, ignore it. If a book seems boring, skip it.

### General Advice 

Networks are not a pure, abstract technology. Honestly nothing is, but networks in particular are physical, temporal things. They exist in a certain place at a certain time, influenced by people, technology, nature, and politics. 

You will be a better developer if you involve yourself in the reality of networking.  Follow NANOG, OARC, or other lists where operators hang out, try to understand the discussion, their mindsets and biases. Pay attention to things, and pay attention _as they are happening_. If there's an operational event or outage, follow it, attempt to debug as it unfolds, then later compare notes with whoever was working it. Working on something independently until you get stuck and then articulating exactly what you're stuck on is one of the most useful skills you can develop, and working events in realtime is a great way to practice.

### Networking Resources

1. [High Performance Browser Networking](https://hpbn.co) - this is an excellent crash course on protcols and browsers. This is 90% of what most software developers need to know about networking. It's available for free online.
2. [Interconnections](https://www.amazon.com/Interconnections-Bridges-Switches-Internetworking-Protocols/dp/0201634481) - this is my favorite resource for learning about routing protocols. Perlman is extremely accomplished in the field _and_ has an accessible writing style. A few newer protocols are missing, but this will give you the necessary background to pick those up easily. It's very affordable since it's an older book.
3. [Network Routing](https://www.amazon.com/Network-Routing-Algorithms-Architectures-Networking-ebook/dp/B075H8ZPZK) - I only recommend this for the chapter on hardware, and possibly the chapter on label switching. It has a great overview of how a physical router is put together and works, but most of the book is dry and nowhere near as engaging as Perlman. Unfortunately it is an expensive text; borrow it if you can.
4. [The Internet Peering Playbook](http://drpeering.net/core/bookOutline.html) - this book is all about the people/business side of how the Internet functions. It's a fascinating read and even if you don't work in the space will help you understand the dynamics of eg. cable companies, large Internet players, etc. The physical book is impossible to obtain, but the Kindle edition is inexpensive and much of the content is available for free on the DrPeering site.

### Systems Programming Resources

Network programming is a form of systems programming. There are certain systems programming resources that I consider indispensible. These are generally not books to go buy all at once and read cover to cover (though you could!), but if there are specific topics you need to understand in more depth - say, lock-free datastructures or sockets or epoll - then this is where you go first. Internet resources are woefully inaccurate or out of date on many of these topics.

1. [Perfbook](https://mirrors.edge.kernel.org/pub/linux/kernel/people/paulmck/perfbook/perfbook.html) - this is the primary resource for anything related to parallel programming. CPU architecture, memory access semantics, threads, locks, atomics, RCU, hazard pointers, parallel data structures. It's a phenomenal resource, freely available and frequently updated.
2. [Computer Systems: A Programmer's Perspective](https://www.amazon.com/Computer-Systems-Programmers-Perspective-3rd/dp/013409266X) - this is a good first stop for any hardware or systems questions. Things like how does virtual memory work, how does a linker work, and so on. Often if you need more depth it will only serve as a jumping off point to relevant OS or CPU manuals, but I still find it valuable. Unfortunately it's quite expensive since it's a current textbook.
3. [The Linux Programming Interface](https://www.amazon.com/Linux-Programming-Interface-System-Handbook-ebook/dp/B004OEJMZM) - in the tradition of _The Unix Programming Environment_ and _TCP/IP Illustrated_, this is my preferred one-stop shop for Linux APIs. Lucid, in-depth writing, broad coverage.
4. [Systems Performance](https://www.amazon.com/Systems-Performance-Enterprise-Brendan-Gregg-ebook/dp/B00FLYU9T2/) - you will need to think about performance, it comes with the territory. This is the book to read on performance. Also, check out Brendan Gregg's blog, talks, and more recent work on BPF.

### Project Ideas

1. Read the DNS RFCs and implement either a stub resolver or an authoritative server in your language of choice. Start with a few record types and expand as long as you're interested. Use wireshark to view the traffic and debug.

    You'll eventually need to learn how to read RFCs, and the original DNS RFCs are straightforward. DNS isn't encrypted so you'll have an easy time sniffing your traffic during development. Best of all, it's exciting getting a piece of software you wrote interacting with something you didn't write - either using your stub resolver to query a public DNS server, or using dig/unbound to query your authoritative server. DNS is fun.

2. Play with a lab network. This doesn't need to be a physical lab - [GNS3](https://www.gns3.com) with [VyOS](https://www.vyos.io), [MikroTik](https://wiki.mikrotik.com/wiki/Manual:CHR), or any Linux distro running [FRRouting](https://frrouting.org) makes a great environment for experimentation. You can build a complex network environment, packet sniff every single link to see how routers are communicating, and drop a container or VM running your own network software into the mix. If you need a goal, try setting up two separate ASes, one running IS-IS and one running OSPF. Model an Internet exchange and have them peer.

### Tangent: Languages

I'm going to avoid languages except for one note: you'll need to know C, even if it's just enough to read others' code. There are plenty of ways to learn it, but I'd recommend [Modern C](https://modernc.gforge.inria.fr). I have some minor nits with the book, but it's a high-quality, concise, freely available text that covers all the language features you need to know and points out many of the problematic areas.

C is a simple language. It doesn't benefit from reading many books or tutorials. Most of the complexity lies in working with memory and dealing with optimizing compilers, so you must use it to understand it.

If you want a starter C project, try implementing malloc. You'll learn about virtual memory, commited versus reserved pages, fragmentation, and how to write fast software. You'll also gain an understanding of how even simple looking C stdlib functions hide significant complexity (try to imagine what complexity a higher level langauge hides). When you're done, read about tcmalloc or jemalloc and compare notes. Run your code under asan and ubsan to find bugs.

### The End

Good luck and have fun!

### Addenda

Most people will get the DNS knowledge they need from the books listed in the Networking Resources section. But if you want significantly more depth (eg. if you're starting a new job at a DNS company) then I recommend [Managing Mission-Critical Domains and DNS](https://www.amazon.com/Managing-Mission-Critical-Demystifying-nameservers-ebook/dp/B07F71QMFM). I like that it covers the entire ecosystem - registrars, WHOIS, DNS, DNSSEC, some major open-source implementations, and even touches on operations/DDOS.
