I got interested in programming languages very early on. In high-school I was
bouncing between Python, C, and Scheme - not doing anything particularly
notable in any of them, but was drawn to languages as a topic. That carried
into college - I found OCaml and Haskell, then turned into your stereotypical
static functional programming weenie. "If only you expressed this as pure
functions, life would be easy." "The compiler can optimize everything away and
make all this code parallel." And so on.

PLs led to an interest in language runtimes, which led to distributed systems,
which led to networking, which led to performance engineering... and so on. I
have a tendency to get curious about a topic, dig deeply into it, then move on
- but I always stick around the areas of systems programming.

Languages don't change frequently in systems programming. It was C, then it was
C and C++, and only recently have there been serious competitors. Generally I
don't care so much what I work in so long as it's somewhat reasonable (and many
languages are somewhat reasonable). But I have realized that my productivity is
notably higher in languages that I enjoy - not necessarily higher because of
any specific constructs that the language touts, but simply because I find
writing in that language pleasurable.

So with that in mind, I figured I'd put down some thoughts on languages I've
used over the past few years, why I'm not entirely satisfied with any of them
(and never will be - I think that's impossible), and how my toolkit has
changed.

First, I've shipped production code in many languages. C, C++, Objective-C,
Java, Kotlin, Scala, Python, Perl, Bash, Go, and so on. I hate jumping across
many languages at once though - it's too easy to fall into the shallows,
spending all of your time reading documentation and trying to glue frameworks
together. I'm fairly averse to third-party code in general, so that doesn't
work well for me. Lately I've been thinking about how to be more intentional
about the languages I use to rebuild some of that deep familiarity and my
personal libraries.

Enter Go. I'd mostly missed the rise of Go - Java was dominant when I was last
doing distributed systems, and during its ascension I was doing low-level
coding on mobile. Now I'm needing to dip into some web services again and
there's this new player. It's... fine. I appreciate that it's a simple
language, but I also find it often to be simplistic and overly pedantic. No
form of macros means that I'm reliant on the core team to standardize new
features, and when things like `try` fail to get added it feels like I'm
consistently stuck at the lowest level of abstraction. Similarly, I've never
liked the Python-esque overly pedantic style guides, I don't like how many tiny
things slow down normal exploratory development (unused vars are a very good
lint or release build error, not a debug error), not enough gc tuning
parameters, and worse of all I've found a lot of the community to be
insufferable on these points. One of the reasons I stuck with Perl for so long
was because it has an amazing community. People are helpful, kind, willing to
entertain discussions - asking how to do something inadvisable will still
likely get you an answer(s), and _then_ a conversation about why it's
inadvisable. With Go, every community interaction feels like I'm walking into a
holy war. See, for example, the long-standing issue on adding 128-bit integers
to the language. It turns into a righteous crusade on This Is How It Is To Be.
That said, it has two things going for it: the language is value instead of
reference oriented, meaning I can actually write dense, performant
datastructures (and it can sidestep some of the cost of a gc), and the standard
library is very full-featured. That's been enough for me to move to it as my
main 'scripting language' for writing small CLI utilities.
TODO: mention functional options as well

Rust. It cares deeply about things I only care a little bit about. The library
ecosystem is a mess and quality is mixed. I'm not convinced about async/await.
Really the only thing I like about it is good support for ADTs/destructuring,
and it has enough mindshare that it may turn into a credible alternative to C++
for some of my applications.

C++. I'm at a point where I'm so exhausted having an opinion about C++ that I'm
not sure I even have an opinion anymore. The language is huge; it's tiring to
write in modern C++ because of the number of concerns I have to keep in my
head, some libraries are fantastic and some are like staring into the void and
some are both. The standard library has a lot of crap in it and bad APIs.
Everyone trots out the aphorism "you pick a subset of the language", but I've
found that very difficult in practice - codebases of any size and teams of any
size have a tendency to grow to include all features unless kept strictly under
control. I don't want many of the new features. I'm mostly okay with std::move
and unique_ptr, but it also seems close to the straw that broke the camel's
back. Often I write something close to straight C, then do a pass over it to
turn it into modern C++ once I'm done prototyping and ready to commit.

C. It's still very good. It has a lot of faults, but some of those are
well-trod. Compiler compatibility on newer revisions can suck. Things have
gotten better with sanitizers. You need to develop a reusable library, but I
think that's much less work than people think it is. I've had people choose C++
because they didn't want to write a dynamic array or hash map - I have trouble
understanding that mindset. Working with strings sucks.

D. I'd like to live in the alternate reality where Facebook adopted D instead
of C++ as their primary programming language while Andrei was working there.

Zig: making unsigned integer overflow undefined.
Nim: 
Jai:
