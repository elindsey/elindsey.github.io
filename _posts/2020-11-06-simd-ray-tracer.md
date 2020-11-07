---
layout: post
title: "Rust Ray Tracer, an Update (and SIMD)"
---

About [a month ago](/2020/09/27/rust-ray-tracer.html) I ported my C99 ray
tracer side project to Rust. The initial port went smoothly, and I've now
been plugging away adding features and repeatedly rewriting it in my spare hours.
In parallel I'm getting up to speed on a large, production Rust codebase at work.
The contrast between the two has been interesting - I have almost
entirely positive things to say about Rust for large, multi-threaded
codebases, but it hasn't been as good of a fit for the ray tracer. 

It's not a _bad_ fit, but C/C++ are almost perfectly suited for this domain. Many of
Rust's flagship features aren't applicable and/or get in the way - for
example, the borrow checker doesn't get me anything that ASAN wouldn't in
this specific use case, though does cause some additional headaches.

What follows are a few of the quirks I've come across.

## Overhead of Thread Locals

There was a [recent blog post](https://matklad.github.io/2020/10/03/fast-thread-locals-in-rust.html)
about this, so I won't get into it very much. 

Suffice to say that thread locals in C already have more overhead than I'd
like since they introduce a level of indirection on use, and the additional
overhead of lazy initialization is significant. I found myself golfing down
TLS access whereever possible ("I'll persist this in TLS, but copy it out
to/write it back from the stack").

Nightly has [an attribute](https://github.com/rust-lang/rust/issues/29594)
that can be used to get a barebones thread local, but I'm trying to avoid
nightly if possible.

Ultimately I got rid of TLS use entirely, but it meant moving away from rayon.

## Difficulty of expressing mutable array access

At its core a ray tracer is a giant array of pixels. You read a
pixel, do some math, and write it back. This is trivial to parallelize by
assigning disjoint sets of indices to threads, but often ends up being a
little difficult to express in Rust. In particular, non-contiguous,
cross-thread write access seems impossible to model safely without doing a
copy pass over the array (ie. using split to slice it up into contiguous owned
chunks, then later copying/rearranging it into the required non-contiguous order).

This makes it a bit annoying to write a tile-based instead of row or pixel-based tracer.

## 'Undefined' Undefined Behavior

I've found it hard to tell what is and isn't undefined behavior in Rust.
There's the [Rustonomicon](https://doc.rust-lang.org/nomicon/), but it's
sparse in places. In particular, I don't have a good feel for what transmutes
are and aren't safe. One route is to outsource all that concern to something
like [bytemuck](https://crates.io/crates/bytemuck) and let
[Lokathor](https://github.com/Lokathor) worry about it. But for this project
I've been avoiding taking deps unless completely necessary, because...

## Compilation speed

...compilation speed is atrocious. My work builds take an ungodly amount of
time. I've been very picky about dependent libraries to keep this ray
tracer's incremental build as low as possible.

## Operator overloading and numeric traits

I used to dismiss operator overloading as a frivolous feature, but it's been
valuable for floating point and SIMD math. Compilers
generally aren't going to do as much algebraic rearranging/simplification
with those types, and it's much easier to notice and tease out shared
operations when operator overloading is used. That said, I would love to
be able to do arbitrary overrides for `<`, `>`, etc. because SIMD types
aren't a good fit for `std::cmp::PartialOrd`.

As much as I like traits and bounded generics, they've been 
painful when it comes to numeric types. A core type in my ray tracer is `Vec3`,
a struct of three `f32s`. I wanted to make it generic across a SIMD type to let
me work with 8 `Vec3s` at once, so instead of three `f32s` it would have three
8-wide `f32s` in struct-of-arrays form. This proved to be... not worth the
hassle. In C++ I could write the `Vec3` logic (dot product, cross product,
etc.) as usual, parameterize it by `f32` or `f32x8`, then go implement whatever
mathematical overloads were missing. In Rust I need a set of unified traits
between `f32` and `f32x8`. Either I need to define that unified trait myself,
which is a lot of boilerplate, or I can use something like [the num
crate](https://crates.io/crates/num), which would require implementing more
functionality than I actually use (and some of which isn't applicable to
SIMD).

Ultmately I didn't bother.

## Rayon

Rayon is a fantastic library. It was much nicer to work with than OpenMP,
and `iter_bridge` makes it dead simple to plug in anywhere.

Ultimately I ditched it for two reasons:
1. I couldn't find a way to directly control thread init, which meant I
couldn't replace my thread locals with stack variables. You can mostly get around this
by using the `_init` methods that take a closure, reading a thread local onto
the stack then writing it back when the thread finishes its jobs.
2. It does far more than I need, which came out in a number of small ways -
like making profiler output harder to read because of a large number of
nested joins.

I ultimately switched to using crossbeam directly, spinning up my own thread
pool reading off of a simple mpmc queue. Interestingly this is as fast as
rayon with `iter_bridge`, but is measurably slower than rayon's custom
parallel iterators for `Vecs`. I'm still looking at why exactly that is, but it
seems like rayon is doing a better job of load-balancing work. Ray tracers
have a large number of pixels that can be processed in parallel, but each
pixel has a variable amount of work, so you need to strike a balance between
making batches too big (then one thread finishes early and you don't fully
utilize the machine) and too small (more thread contention to grab jobs). I
need to add logging to rayon's join splitting, but my hunch is that it's
doing a better job of keeping the batch size as high as possible without
causing cores to go idle.

Update: Looking into it a bit more, rayon's initially splitting by the number
of threads and then breaking jobs up further only when threads go idle and need to 
steal - the optimal way to adaptively execute this workload. I'm still a tad behind
when I replicate that behavior on top of `crossbeam::deque` directly, so there are
still a few unanswered questions here.

## SIMD

There are a few different places where SIMD is applicable in a ray tracer:

* Do `Vec3` operations in SIMD. This is a common initial idea, [but it's not
particularly
fruitful](https://fgiesen.wordpress.com/2016/04/03/sse-mind-the-gap/).
* Process multiple pixels or multiple rays for the same
pixel in SIMD. This is very useful, though requires writing SIMD versions
of some libm functions (notably trig functions). It's also where you start
hitting ray coherency problems - if you shoot 8 rays in a batch at roughly
the same area of the scene, it's likely that they'll behave similarly. But as
soon as they hit an object and bounce they all head in different directions,
and pretty quickly you end up with dead lanes. Unless your scene is very
simple that's still going to be a net win. Then coherency issues can come up
_again_ once you've calculated your hits and need to process materials - a
ray of light hitting a lake leads to very different math from a ray of light
hitting a tree. A good strategy for dealing with such things is to switch
from doing a depth-first traversal of the scene to breadth-first, letting you
accumulate enough state to batch likes with likes and pull, say, '8 tree
hits', '8 water hits', etc. from the work queue all at once. The tradeoff is
now you have a significant amount of additional memory use and possibly more
thread synchronization, so it's easy to accidentally make everything worse
and slower (I've heard it's more effective on GPUs, but know less about
that). One very good paper on this style of optimized breadth-first CPU ray
tracing is [this one](https://www.embree.org/papers/2016-HPG-shading.pdf)
from Intel.
* Perform intersection checks for a single ray in SIMD. This isn't as big 
of an improvement as the former, but given the effort it has great bang for your buck. Most of the work to add SIMD
was defining pass-through functions for intrinsics, with a few gnarlier ones
here and there (eg. hmin). The trickier optimization work came from going
back over the code and looking for any small places that I could simplify the
calculations - little things like removing a negation or redundant multiply,
switching to fma, etc. added up to substantial improvements.

This was my first time using AVX2, and I didn't realize it's essentially
"SSE but bigger." In particular I was surprised that you can't permute across
128-bit lanes. 

Other surprises were that rsqrt with a refinement iteration
was slower than simply calling sqrt (though the Intel optimization manual did
warn me about this on Skylake - I have so much other math going on that it led
to port contention). And the cost of float conversions add up very quickly -
initially I was lazy and only implemented an 8-wide `f32` type, then would cast
in/out if I needed some integer type instead. Adding a proper `i32x8` got me a
few percentage points of runtime improvement.

Rust's current SIMD support is the absolute bare minimum. Intrinsics are exposed, all must be
used in unsafe, and if you dig you can find some docs on `repr(simd)`.
There's also a smattering of SIMD crates, some
[good](https://crates.io/crates/wide), some bad, some seemingly unmaintained.
There's nothing as complete or useful as [Agner Fog's
VCL](https://github.com/vectorclass/version2). There _is_ however [an active
working group](https://github.com/rust-lang/project-portable-simd) adding
portable SIMD abstractions to the core. That's very exciting, and looks like it's shaping up
nicely.

## Debugging

Debugging ray tracers is surprisingly fun; you end up with a lot of "how on earth did _that_ happen" moments. Here are a few of my recent head scratchers:

### Reference Image
![](/assets/images/rrt/reference1.png)

This is my current reference scene. Not too exciting - I need to invest some time in building out a more complex scene and possibly adding obj/triangle support. But the performance work tends to be more fun.

### Blurred
![](/assets/images/rrt/bad_blur1.png)

I have no idea what happened here. I found this in my output folder over the course of doing the refactor from rayon to crossbeam, so I don't know exactly what broke - but I thought it was neat.

### Ripples
![](/assets/images/rrt/bad_fp1.png)

This came from some bad floating point math - I think I messed up the intersection calculation in some way, but don't remember exactly how. I thought the ripple effect was kinda fun.


### Fun House Mirrors
![](/assets/images/rrt/bad_normalize1.png)

"Maybe I don't need to normalize my vectors here..."

*tries it*

"Nope, I definitely need to normalize there."

### Inside Out
![](/assets/images/rrt/bad_sqrt1.png)

This came from trying to use a fast inverse sqrt without a refinement step. A lot of my intersections were messed up, so rays ended up bouncing around _inside_ objects and things got weird.

