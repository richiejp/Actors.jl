Presently the behaviour of Actors.jl is changing quite rapidly so this
documentation may not be up to date.

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

behaviour(::Foo) = println("Foo")
behaviour(::Bar) = println("Bar")

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


