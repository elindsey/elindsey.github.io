---
layout: post
title: "Don't Trust rustc --emit=asm"
---

## The short version

Cargo builds like
```bash
$ RUSTFLAGS="--emit asm" cargo build --release
$ cargo rustc --release -- --emit asm
```

Do not output the same assembly-equivalent of the machine code you'd get from
```bash
$ cargo build --release
```

Possibly `rustc --emit=asm` has some uses, like examining a single file with
no external dependencies, but it's definitely not useful for the normal case
of wanting to look at the asm for an arbitrary release build.

## The long version 

It was a long circuitous path to figure this out...

[Previously](/2020/11/06/simd-ray-tracer.html) I had rewritten my ray tracer
to use `crossbeam::scope` and `crossbeam::queue` instead of rayon. Internally
rayon is leaning pretty heavily on `crossbeam::deque` for work-stealing, so
my expectation was that this would be a neutral or slight improvement
(depending on how good of a job the compiler had been doing to condense
rayon's abstractions).

Instead it was a ~15% regression.

Looking at the asm output everything appeared sane (Narrator: "it wasn't"). I saw
no expensive levels of indirection, things were getting properly inlined and optimized.

So I first questioned my understanding of rayon and spent some time digging
through its guts. It's definitely well-engineered, and it's impressive that
clang's able to condense all of its abstractions down - but there was nothing
fundamentally novel or surprising going on. The splitting/work assignment
portion of the vec codepath looked like it would lead to slightly more even
partitioning than my hand-built crossbeam method, but not by a lot,
definitely not by 15%. So that was bust. I did notice that crossbeam needed
to heap allocate the closure I was using as my thread body, so perhaps that
caused some additional overhead, but it should have been negligible.

At this point I dumped both versions into Instruments and did some basic CPU
profiling. rayon's a bit annoying to poke around in because you end up with
extremely deep stacks of `join` frames, but nothing really stood out. The
crossbeam version was just slower.

I'd been looking for an excuse to try [Intel
VTune](https://software.intel.com/content/www/us/en/develop/tools/vtune-profiler.html)
for awhile, but since it's only supported on Windows and Linux and is best
run on bare-metal, it had always been slightly too much effort to stand up
for smaller projects. But it seemed warranted for this one! I had an existing
Windows bootcamp partition, so figured I'd see just how much hassle it was to
get everything working in that before I dusted off something to run Linux.

Turns out Rust on Windows is... really nice. I'm not a Windows dev. There are
things that I admire about the ecosystem (like an actually good first-party
debugger and some decent OS APIs), but apart from some Java way back in high
school I've never even tried to compile software on a Windows machine. It
always seemed like a nightmare for C/C++ projects - I'm familiar enough with
the ifdefs necessary to make things cross-platform, but as for actually
building things... I think cmake can spit out a Visual Studio project? And I
keep hearing about WSL? So I went in with significant trepidation. Turns out
it took all of ten minutes to install the VS C++ tools, rustup, a rust
toolchain, vtune, and get everything building and working together. Pretty
impressive.

VTune itself is a complex beast. Most (all?) of the data in it seems like stuff
you could get out of `perf`, but the collection is streamlined and the workflow
is pretty nice - it does a good job of keeping track of previous runs, grouping
them in a way so you don't lose anything, surfacing useful information based on 
top-level categories (eg. "I want to look at memory access"), and providing a 
great diff view between runs. It looks particularly useful for guiding optimization 
and refinement of a program. It's a bit less useful when I'm comparing the performance
of two fairly different programs, because many of the stack traces are unique to
either the rayon or crossbeam version, so "you have 100% more of these rayon stack traces
in this run" is not helpful. Looking through the data I saw that I was getting flagged on uarch
perf, retiring instructions maybe 5% worse in the crossbeam version. Thinking that could be stalling
waiting on memory, I ran a memory access profile and saw:

![](/assets/images/rrt/vtune_macc.png)

Crossbeam version is on the left, rayon version is on the right. Okay, 3s runtime difference - that's inline with the perf regression I'm seeing. Interesting, we're memory bound twice as frequently. That's strange because our memory access pattern should be pretty similar. We're doing over twice as many stores. We're doing some additional loads. We're...

Wait.

We're doing over twice as many stores?!

That... doesn't make sense.

Maybe heap allocating the closures is more expensive than I thought, or has
bad knock-on effects? Maybe everything I know is wrong? Fine, let me try
eliminating `crossbeam::scope` and use `std::thread` instead. This was a
quick and dirty test: the entire point of `scope` is to create an abstraction
that communicates to the borrow checker that threads we've spun off have been
joined, otherwise it doesn't know when a borrow may have ended and requires
that data references from a thread's closure are all static lifetime. In this
case I'm manually joining the threads, so I can do a transmute just to see
how performance changes. Don't ship code like this. If you ship code like
this, why bother using Rust in the first place. But it can be really handy to
circumvent these checks when doing quick prototyping and deciding if it's
worth the time to build out an abstraction (sidebar: I would welcome a "just
build this without the borrow checker" mode for cases like this, though I'm
probably in the minority. And no, wrapping it all in an unsafe block isn't
equivalent).

So the code ended up roughly looking like:
```rust
let pixels = unsafe { 
    mem::transmute::<&mut [V3], &'static mut [V3]>(pixels)
};
let handle = std::thread::spawn(move || {
    // code that uses &pixels
});
handle.join().unwrap();
```

And no significant performance gains were had.

Okay, no dice. So now I'm thinking I want to look at the assembly again, but I'd like to clearly distinguish between 
all my unchanged business logic and the rayon/crossbeam coordination code. So I open the rayon code and add `#[inline(never)]` to my primary ray processing function. And the rayon version slows down... in fact it runs exactly as fast as the crossbeam version.

So I try adding `#[inline(always)]` to that same function in the crossbeam version, and lo and behold my regression disappears.

But, how's that possible? The _first_ thing I did was look at inlining. Maybe my quick once-over missed it, maybe this is all my fault?

I generated assembly output for both the inlined and noninlined versions of the crossbeam ray tracer.

```bash
$ rg ecl_rt4cast inline.s 
21293:	.asciz	"_ZN6ecl_rt4cast17hc1100eade04dff75E"
$ rg ecl_rt4cast noinline.s 
21293:	.asciz	"_ZN6ecl_rt4cast17hc1100eade04dff75E"
```

I'm building release with symbols, so that's expected. But apparently neither version, even the non-inlined version, is making calls to `cast()`. Curious.

```bash
$ wc -l inline.s 
203969 inline.s
$ wc -l noinline.s 
203969 noinline.s
```

Now I feel like I'm being gaslighted. These are the exact same length. A diff shows that the only changes are some arbitrary IDs in debug info. I have a difficult relationship with optimizing compilers, so my first instinct is "forget this, I'll go look at the binaries..."

```bash
$ objdump -d ecl_rt_inline | rg ecl_rt4cast
<no output>
$ objdump -d ecl_rt_noinline | rg ecl_rt4cast
0000000100003190 __ZN6ecl_rt4cast17hc1100eade04dff75E:
100003299: e9 af 01 00 00              	jmp	431 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x2bd>
1000034a2: eb 1f                       	jmp	31 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x333>
1000034c6: 74 38                       	je	56 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x370>
1000034e5: 0f 82 f5 00 00 00           	jb	245 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x450>
1000034ee: 72 1d                       	jb	29 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x37d>
1000034f0: e9 eb 00 00 00              	jmp	235 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x450>
100003503: 0f 83 d7 00 00 00           	jae	215 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x450>
100003515: 0f 87 16 03 00 00           	ja	790 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x6a1>
10000351e: 0f 82 1f 03 00 00           	jb	799 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x6b3>
100003527: 0f 82 2b 03 00 00           	jb	811 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x6c8>
100003530: 0f 82 37 03 00 00           	jb	823 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x6dd>
100003539: 0f 82 40 03 00 00           	jb	832 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x6ef>
100003590: 0f 84 1a ff ff ff           	je	-230 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x320>
1000035db: e9 d0 fe ff ff              	jmp	-304 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x320>
10000360a: 0f 86 a1 01 00 00           	jbe	417 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x621>
100003637: 0f 87 57 02 00 00           	ja	599 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x704>
100003668: 0f 86 3d 02 00 00           	jbe	573 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x71b>
100003682: 0f 84 41 01 00 00           	je	321 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x639>
100003707: 0f 85 93 fb ff ff           	jne	-1133 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x110>
10000371a: 0f 86 9f 01 00 00           	jbe	415 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x72f>
100003723: 0f 86 a8 01 00 00           	jbe	424 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x741>
10000372c: 0f 86 b1 01 00 00           	jbe	433 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x753>
1000037ac: e9 57 fc ff ff              	jmp	-937 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x278>
1000037c7: eb 12                       	jmp	18 <__ZN6ecl_rt4cast17hc1100eade04dff75E+0x64b>
100009740: e8 4b 9a ff ff              	callq	-26037 <__ZN6ecl_rt4cast17hc1100eade04dff75E>
```

Bingo. Note the `callq`. I spend some time in [Ghidra](https://ghidra-sre.org) to be sure.

So clearly my crossbeam version wasn't inlining as aggresively as the rayon
version, likely due to the `Box::new(closure)`. Instructing the compiler to
do so brought performance in line with expectations. And `--emit=asm` is...
buggy? I spent some time looking around, and sure enough [there are
reports](https://users.rust-lang.org/t/emit-asm-changes-the-produced-machine-code/17701/4)
that running with `--emit=asm` will actually change the final output because
of interaction with ThinLTO/codegen unit configs.

Lesson learned, I suppose.