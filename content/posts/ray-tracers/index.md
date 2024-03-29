---
date: "2020-08-02T00:00:00Z"
title: Learning About Ray Tracing
aliases:
    - /2020/08/02/ray-tracers.html
---

I've had more time than usual for side projects since I've been stuck inside
the past few months. I spent the majority of June digging into graphics, getting
acquainted with the field by building a ray tracer. The initial version is now
online as [ecl_rt](https://github.com/elindsey/ecl_rt_legacy).

Rather than write yet another post about building a ray tracer, I'll point to
the handful of resources (from the multitude available) that were actually useful:

* [Ray Tracing in One Weekend](https://raytracing.github.io) is the canonical
  introductory tutorial. I didn't love it - I wasn't on board with the code
structure and found it very light on explanation. I still think it's a decent
way to get something on the screen fast, so I'd recommend going through it
quickly to get a prototype working and then move on.

* [Physically Based Rendering](https://www.pbrt.org) is dense and long, but
  also deep, insightful, and a pleasure to read. I wish I had picked it up
earlier instead of spending so much time on various other books/tutorials. In
general, I think you should do the minimum amount of work to get something on
the screen and get the basic background knowledge to understand this book, then
simply work through PBRT cover to cover. It's incredible that the whole thing
is available online for free (though I'd recommend picking up a physical copy
if you expect you'll be spending a lot of time with it).

* [Aras' blog series on path
  tracers](https://aras-p.info/blog/2018/03/28/Daily-Pathtracer-Part-0-Intro/)
is a lot of fun.  He implemented a ray tracer in every imaginable way; it makes
for great reading to compare some of the paths I didn't take (eg. Metal or
other modern GPU frameworks).

There's a lot of work left, but it's still fun to look at how far things have
come. Here's a few images showing the evolution of my ray tracer's output, from
the very first image it rendered to the current state:

![](1.png)

![](2.png)

![](3.png)

![](4.png)

![](5.png)

![](6.png)
