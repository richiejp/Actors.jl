Presently the behaviour of Actors.jl is changing quite rapidly so this
documentation may not be up to date.

# Background

## The Actor Model

Informally, an Actor is some arbitrary state (e.g. a Julia `struct`), an inbox
which contains received messages and some behaviours (e.g. Julia methods)
which are activated when messages are taken from the inbox.

Each actor has at least one address which can be used to send it
messages. Messages are some arbitrary value (e.g. `1` or `struct Foo end`).

Messages are delivered in an arbitrary order and are buffered. That is the
inbox (a Julia `Channel` in this case) can store multiple messages. This makes
Actors asynchronous as they can continue to receive messages before finishing
processing the current one.

While processing a message an Actor may update its state, thus changing its
behaviour. It may send more messages, create new actors or *do nothing* in
response to a message.

!!! note

    Often when people refer to the Actor Model, they really mean
    [Erlang's](https://www.erlang.org/) implementation of it. However there is
    also formal definition of the Actor model set forth in
    [Actors](https://www.amazon.de/dp/026251141X/ref=sr_1_2?keywords=actor+model&qid=1571479272&sr=8-2). This
    library takes inspiration from everywhere.

## Messages Vs. Methods

Julia's multi-methods (which we exploit heavily in Actors.jl) are quite
similar to messages except in three very important regards.

1. Messages are asynchronous
2. Messages can be ignored
3. Messages never return a value

Sending messages is similar to calling a multi-method with `@spawn` (similar to
`@async`, but really happens in parallel) without fetching the task's result.

```@example
struct Foo end
struct Bar end

behaviour(::Foo) = println("Dispatched Foo")
behaviour(::Bar) = println("Dispatched Bar")

send(msg) = Threads.@spawn behaviour(msg)

foo_task = send(Foo())
bar_task = send(Bar())

sleep(1)
```

The only way we know that `foo_task` and `bar_task` succeeded and what order
they were processed in is if look at the side effects. In this case the side
effects are printing to `stdout`.

With actual messages we would confirm some action by sending another message
in return.

# Stopwatch tutorial

To begin with we will create an actor system with an actor which can function
as a stop watch.

## Setting the Stage and starting the Play

At the root of an independent "actor system" is the [`Stage`](@ref). This the
first [`Actors.Actor`](@ref) and it manages the system. Like any other actor
you can pass it messages and it can pass them back.

[`Stage`](@ref) bootstraps the system and then passes a message
([`Genesis!`](@ref)) to the `Play` actor to get things started. The `Play`
actor is defined by you, the user. The `Play` actor can be of any type, even
an `Int`.

!!! note

    This is a lie, the type is actually `Actor{Int, Any}`; `Int` is the type
    of the actor's state. However it is sometimes to convenient to refer to
    the state as the actor itself.

```@example
using Actors
# This allows us to add new Actors.hear methods without writing Actors.hear
import Actors: hear

function hear(s::Scene{Int}, ::Genesis!)
	my(s) = 1

	@say_info s "My state is $(my(s))"

	say(s, stage(s), Leave!())
end

play!(0)
```

OK, this is a bit silly, lets do it again with a dedicated play type.

```@example
using Actors
import Actors: hear

struct StopwatchPlay
	i::Int
end

function hear(s::Scene{StopwatchPlay}, ::Genesis!)
	my(s) = StopwatchPlay(1)

	@say_info s "My state is $(my(s).i)"

	say(s, stage(s), Leave!())
end

play!(StopwatchPlay(0))
```

So, first we define our play actor, then we define a message handler for
[`Genesis!`](@ref) (by defining a new [`hear`](@ref) method) and then we start
the actor system with [`play!`](@ref).

The [`Stage`](@ref) is passed `StopwatchPlay` which it turns into an
[`Actors.Actor`](@ref) and it then sends that actor `Genesis!`. Looking at
`hear(s::Scene{StopwatchPlay}, ...)` we can see the special [`Scene`](@ref)
variable which has our play actor as the type parameter. In any other framework
this would be called the 'context'.

The majority of the Actors.jl's API takes `s::Scene` as the first
argument. This allows us to get commonly needed information about the actor
system and current actor. It is recommended to always call this variable `s`,
so that you have the option of using unhygenic macros which implicitly use
this information.

The [`my`](@ref) accessor method allows us to get or set the actor
state. `StopwatchPlay` is immutable, so we can't do `my(s).i = 1`.

!!! note

    Because `StopwatchPlay` only contains a plain bit type `Int`, it is therefor a
    plain bit type itself. If we make it immutable then it becomes something quite
    different. As a general rule it is better for performance and safety if
    your data is made up of immutable types, in particular plain bit types. Especially
    if this data is passed between actors allowing you to accidentally access
    the safe reference in two different threads.

The [`@say_info`](@ref) macro sends a message to an automatically created
actor which logs messages to stdout. Finally we send [`Leave!`](@ref) to the
[`Stage`](@ref) actor which then propagates this to all other actors and
shutsdown the actor system.
