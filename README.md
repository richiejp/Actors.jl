# LuvvyActors - An Actor Model Library for Julia

*This is on hold indefinitely, see
[https://github.com/JuliaActors](JuliaActors) and
[https://github.com/Circo-dev](Circo)*

Actors.jl (now renamed again) helps you to write error resistant,
highly parallel code. It encourages you to fully embrace the Actor
model[^Actors], thus creating extremely distributed and robust
applications.

All else being equal, this library optimises for parallisation and resilience
over single core performance or memory efficiency. This may be slower in the
common case, but much improves the performance of the worst case.

The Actors.jl base library aims to have no dependencies beyond what is included
in Julia itself. I doubt it will work Julia versions less than v1.3.

## Luvvy

This library was called [Luvvy](https://gitlab.com/Palethorpe/luvvy),
then was renamed to
[Actors.jl](https://gitlab.com/Palethorpe/actors.jl) and now has been
renamed to LuvvyActors because Actors.jl has become a generic Actor
interface. Luvvy is now an experimental Actor based web framework.

## Hello, World!

```julia
using Actors
# Allows us to write 'hear' instead of 'Actors.hear'
import Actors: hear

"Our Play actor"
struct HelloWorld end

"Our Actor actor"
struct Julia end

"Our Message"
struct HelloWorld! end

"Handle messages of type HelloWorld! for all actors"
function hear(s::Scene{A}, ::HelloWorld!) where A
	# Tell the Logger actor (started automatically) to print a message
	@say_info s "Hello, World! I am $(A)!"

	# Tell the 'Stage' to leave; Stage forwards Leave! to the Play which then
	# asks its children to leave.
	say(s, stage(s), Leave!())
end

"Handle Genesis! which is sent to our play actor on startup by the Stage"
function hear(s::Scene{HelloWorld}, ::Genesis!)
	# Invite Julia into the play; she will be a child of the HelloWorld actor.
	julia = invite!(s, Julia())

	# Say HellowWorld! to Julia
	say(s, julia, HelloWorld!())
end

# Start our 'play' (the actor system) and block while waiting for it to
# finish.
play!(HelloWorld())
```

This should print "Hello, World! I am Julia!". The `A` in `Scene{A}` takes the
type of the Actor (technically the Actor's state) in the Scene.

Note that this isn't the simplest possible use of Actors.jl. For that we could
just print "Hello, World!" in the `Genesis!` handler.

See `test/runtest.jl` for more examples. Also see the
[documentation](https://palethorpe.gitlab.io/Actors.jl/).

## Installation

Actors is available from the Julia registry however this is likely to be
lagging far behind development. So use:

```
pkg> add https://gitlab.com/Palethorpe/Actors.jl.git#master
```

## More spiel

In effect, if you use the actor model liberally you no longer need be
concerned about whether something should be asynchronous or executed in
parallel, because everything generally is.

Actors.jl aims to make defining and calling messages easy. Making them as similar
to ordinary method calls as possible while discouraging you from making
various mistakes. The same goes for Actors themselves which you are encouraged
to define and spawn liberally.

You also do not need to ask whether you should handle every error from every
function (which is often an unknown 'unknown'). You simply assume all actors
can fail for arbitrary reasons and decide what to do if that happens.
Errors can be allowed to propagate, killing actors, until some level of the
actor hierarchy, where a controlling actor restarts them.

While this does require some thought on your behalf to decide where expected
and unexpected errors should stop propagating. This has been proven to work
very well in practice by the likes of [Erlang](https://www.erlang.org/) and is
a significant improvement over naked exception handling.

## Current state of development

You can presently create local Actors which run on multiple threads if you set
`JULIA_THREADS`. The API will most likely change dramatically over time.

### Error handling & Services

Each actor has a 'minder', another actor that is notified if the first
actor has a problem. A problem could be that an actor has died or something
more general.

Actor's have access to the address of their minder, so they can send it
messages. This means the minder can be used to provide general services to all
actors. For example, a minder actor can store the address of a logging
actor. Any actor which uses that minder can send logging messages to it and
the minder can forward them to a logger. This means any actor can use the
logger without storing the logger's address in its state.

Because minders are also actors, they themselves have a minder. This analogous
to how, in most operating systems, child processes have parent
processes. However, unlike processes, minders can form any type of graph,
including those with loops or cycles in. An actor can even be its own minder,
or you can have two actors which are each other's minders. This may be
restricted in the future to avoid common errors.

## Future developments

Things that have not been tackled yet include:

### Timeouts and 'Dialogs'

One of the biggest problems with actor models (and asynchronous code in
general) is how to handle cumulative timeouts. Perhaps the largest useability
problem is in following the program flow.

When viewing actor code, deducing the sequences of messages which are intended
to take place is often very difficult. Even if it is possible to isolate
linear sequences of messages (these may be interwoven with other messages
during execution) the structure of the code makes them difficult to identify.

Furthermore the sequence of messages should perhaps have an overall timeout
which is defined at the beginning of the sequence, and the time spent
processing each message is counted towards it. As opposed to having idependent
timeouts for each message which will accumulate[^Trio].

To handle these two issues, I propose the vague notion of a 'dialog'. Which
isolates a sequence of messages and includes some state, such as the timeout
or some other data relevant to most stages of the sequence.

Somehow dialogs will be expressed syntatically so that a series of
interactions by (possibly) independent message handlers appear as an
imperative code sequence. Perhaps some message handlers and messages could be
expressed within the sequence.

To some extent this is already achieved by using delegate with a sequence of
`ask` calls, but it remains to be seen if there is more to be done.

### Memory protection

We want to discourage the user as much as possible from accessing shared or
global memory. All sharing, should be achieved through message passing. This
means messages themselves may need to be inspected and copied to avoid passing
references to mutable data. On the other hand we do not want to copy
unnecessarily due to performance.

This is particularly important for non x86 architectures where ordering
between threads and atomicity is far weaker. It also helps migrating actors
from local (threaded) to remote (multi-processed) where all communication
takes place over a socket or designated shared memory.

If an actor is fully self contained, then migrating it is simply a case of
changing the transport (`Stage` type).

This is perhaps mostly work that should be done upstream in Julia.

### Remote actors

Obviously it makes sense to have actors run across multiple processes and
machines. Perhaps even in other languages. This will require a number of
dependencies, so will probably require a separate module. However it should be
fairly easy to use as having actors run in someone's browser connected by
websockets is a very compelling use case.

## Alternatives

- [Circo](https://github.com/Circo-dev)
- [YAActL.jl](https://github.com/JuliaActors/YAActL.jl) Yet Another Actor Library!
- Original [Actors.jl](https://github.com/oschulz/Actors.jl)

## References

[^Actors]: https://www.amazon.de/dp/026251141X/ref=sr_1_2?keywords=actor+model&qid=1571479272&sr=8-2
[^Trio]: https://vorpus.org/blog/timeouts-and-cancellation-for-humans/#cancel-scopes-trio-s-human-friendly-solution-for-timeouts-and-cancellation

