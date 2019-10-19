# Luvvy - An Actor Model Library for Julia

*This library is very much experimental as is Julia threading, so you can take
my claims with some salt*

Luvvy[^Etymology] helps you to write error resistant, highly parallel
code. It encourages you to fully embrace the Actor model[^Actors], thus
creating extremely distributed and robust applications.

All else being equal, this library optimises for parallisation and resilience
over single core performance or memory efficiency. This may be slower in the
common case, but much improves the performance of the worst case.

The Luvvy base library aims to have no dependencies beyond what is included
in Julia itself. I doubt it will work Julia versions less than v1.3.

## Hello, World!

```julia
using luvvy

"Our Actor"
struct Julia end

"Our Message"
struct HelloWorld! end

# Set handler for all actors for the message HelloWorld!
luvvy.hear(s::Scene{A}, ::HelloWorld!) where A =
    # We shouldn't really use println
	println("Hello, World! I am $(A)!")

# Set the Genesis! message handler for the builtin Stage actor
function luvvy.hear(s::Scene{Stage}, ::Genesis!)
	# Juila enters the stage
	julia = enter!(s, Julia())

	# Send the HelloWorld! message to Julia (The Stage talks to some actors)
	say(s, julia, HelloWorld!())

	# The stage leaves, but don't worry, Julia can say her line before
	# gravity takes effect.
	leave!(s)
end

# Create the stage and send it Genesis! (this blocks until the stage leaves)
play!(Stage())
```

This should print "Hello, World! I am Julia!". The `A` in `Scene{A}` takes the
type of the Actor (technically the Actor's state) in the Scene.

Note that this isn't the simplest possible use of Luvvy. For that we could
just print "Hello, World!" in the `Genesis!` handler or use `delegate` to
spawn a temporary actor (A `Stooge`) without defining it.

See `test/runtest.jl` for (one) more example(s).

## More spiel

In effect, if you use the actor model liberally you no longer need be
concerned about whether something should be asynchronous or executed in
parallel, because everything generally is.

Luvvy aims to make defining and calling messages easy. Making them as similar
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

This is really just an experiment at this stage however, you can presently
create local Actors which run on multiple threads if you set
`JULIA_THREADS`. The API will most likely change dramatically over time.

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

### Deliberate error propagation and handling

Currently errors are propagated on an ad-hoc basis, mainly as an accident of
how Channels work. We should formalise this and add some standard actors for
handling errors e.g. A monitory which restarts actors when they fail for any
reason.

When a failure occurs repeatedly it may even be possible to block the message
which triggers it and save the sequence for later examination.

## Alternatives

- [Actors.jl](https://github.com/oschulz/Actors.jl)

## References

[^Etymology]: https://dictionary.cambridge.org/dictionary/english/luvvy
[^Actors]: https://www.amazon.de/dp/026251141X/ref=sr_1_2?keywords=actor+model&qid=1571479272&sr=8-2
[^Trio]: https://vorpus.org/blog/timeouts-and-cancellation-for-humans/#cancel-scopes-trio-s-human-friendly-solution-for-timeouts-and-cancellation

