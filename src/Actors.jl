module Actors

using DocStringExtensions

# Misc Types
export Id, Scene

# Actors
export Stage, Troupe

# Functions
export stage, play!, enter!, invite!, leave!, forward!, expect, ask, say, hear, me, my
export delegate, shout, minder, @say_info, async, interact!, local_addresses

# Messages
export Genesis!, Leave!, LogInfo!, Died!, Left!, AsyncFail!

@template TYPES = """
$DOCSTRING

### Members

$TYPEDFIELDS
"""

"""The Address of an [`Actor`](@ref)

This is a safe reference to an [`Actor`](@ref). It is most commonly used to
send messages to an [`Actor`](@ref). However many accessor methods take an
`Addr` to safely get or set some `Actor`'s internals or associated data.

!!! warning

    This will grow in size as remote actors are added.

### Type Parameters

- `S` The type of the actor state.
- `M` The message types the actor accepts, usually Any.

"""
struct Id{S, M}
    "The local index within the owning stage"
    inner::UInt32

    Id(inner) = Id{Any, Any}(inner)
    Id{S}(inner) where S = Id{S, Any}(inner)
    function Id{S, M}(inner) where {S, M}
        @assert inner > 0 && inner <= typemax(UInt32)

        Id{S, M}(UInt32(inner))
    end
    Id{S, M}(inner::UInt32) where {S, M} = new{S, M}(inner)
end

Base.:(==)(a::Id, b::Id) = a.inner == b.inner
Base.show(io::IO, id::Id{S}) where S = print(io, "$S@", id.inner)

"""The star of the show (but not really)

This holds internal state for an Actor, it wraps the user defined state
value. We usually think of the Actor as being the state value rather than this
structure which is mostely hidden. It is rare that a user will need to access
this directly. Usually Actors are referenced by an [`Id`](@ref) and we get the
actor's details by calling accessor functions on either the `Id` or the
[`Scene`](@ref).

If you do access this, then you need to be careful to avoid concurrency
violations.

### Type Parameters

- `S` The type of the user defined actor state.
- `M` The message types the actor accepts, usually Any.

It is rare to set `M`, but if it is set then it should include at least
[`Leave!`](@ref).
"""
struct Actor{S, M}
    "How the Actor recieves messages, see [`listen!`](@ref)"
    inbox::Channel{M}
    "An arbitrary value which is usually thought of as the actor"
    state::S
    "The `Id` of another actor which manages and supports this actor"
    minder::Id
    "The Task this actor runs/ran in"
    task::Union{Task, Nothing}
    "The cannonical `Id` of this `Actor`"
    me::Id{S, M}

    Actor(inbox::Channel{M}, state::S, minder) where {S, M} =
        new{S, M}(inbox, state, minder, nothing)
    Actor(inbox::Channel{M}, state::S, minder, task, me) where {S, M} =
        new{S, M}(inbox, state, minder, task, me)
end

"Create an Actor with the given state and minder"
Actor{M}(state, task, minder, me) where M =
    Actor(Channel{M}(420), state, task, minder, me)

include("addressing.jl")

"""Abstract Stage

Mainly used to allow overriding of [`Stage`](@ref)'s methods.
"""
abstract type AbsStage end

"""The Root Actor

This contains the addresses for all the actors and bootstraps the
`play`. Currently all actors are created by sending messages to the `Stage`
although this will probably change in the future.

Any messages which the `Stage` can not handle, it forwards to the `play`.

The `Stage` bootstraps itself by putting the [`PreGenesis!`](@ref) message in
its [`inbox`](@ref). It processes this message first then sends
[`Genesis!`](@ref) to the actor specified by [`play!`](@ref).

It is unusual for the user to access this directly or override its
behaviour. Most things can be achieved by creating a new [`AbsMinder`](@ref)
type or allowing messages to be forwarded to the Play actor.
"""
mutable struct Stage <: AbsStage
    "All the `Actor`s in the play"
    actors::AddressBook
    "Grace period timer before force leaving"
    time_to_leave::Union{Timer, Nothing}
    "User defined play `Actor`"
    play::Id

    Stage() = new(AddressBook(), nothing)
end

abstract type AbsScene{S, M} end

"""The context of message processing

Contains common information which is used by many different methods during
message handling. You should assume that the members of this struct are likely
to change.

### Type Parameters

- `S` The type of the current [`Actor`](@ref)'s state. This is commonly
  specified when adding a method for [`hear`](@ref) (amongst much else).

- `M` The message types accepted by the current `Actor`, usually `Any`.

"""
struct Scene{S, M} <: AbsScene{S, M}
    "The current [`Actor`](@ref)"
    subject::Actor{S, M}
    "The [`Stage`](@ref)"
    stage::Actor{Stage}
end

struct AsyncScene{S, M} <: AbsScene{S, M}
    s::Scene{S, M}
    task::Task
end

Base.show(io::IO, s::Scene{S}) where S = print(io, "Scene{$S}")
Base.show(io::IO, s::AsyncScene{S}) where S = print(io, "AsyncScene{$S}")

const WRONG_TASK =
    "The given Scene or Actor is not associated with this task. You are either trying to access another Actor's state or have used @async (use @try_async)."

subject(s::Scene) = let a = s.subject
    @assert a.task !== nothing "Actor is not playing"
    @assert a.task === current_task() WRONG_TASK

    a
end

function subject(s::AsyncScene)
    @assert s.task === current_task() WRONG_TASK

    s.s.subject
end

stage_ref(s::Scene) = let a = s.subject
    @assert a.task !== nothing "Actor is not playing"
    @assert a.task === current_task() WRONG_TASK

    s.stage
end

function stage_ref(s::AsyncScene)
    @assert s.task === current_task() WRONG_TASK

    s.s.stage
end

"""Safely get the current [`Actor`](@ref)'s state

Usually the user passes the [`Scene`](@ref) to this and gets the executing
[`Actor`](@ref)'s state in return.
"""
my(s::AbsScene) = subject(s).state

"""Get the inbox of an [`Actor`](@ref)

Useful when overriding functions such as [`listen!`](@ref) or
[`leave!`](@ref). Otherwise it is quite unusual for the user to call
this. You should use [`say`](@ref) and [`ask`](@ref) to send messages.

The `inbox` is how an `Actor` recieves messages. In a local system the sender
directly places a message into the `inbox`. Currently inboxes are implemented
with a Julia `Channel` which can be safely accessed by multiple threads,
however it is generally expected that you don't `pop!` messages from another
actor's inbox unless that actor is dead.
"""
inbox(s::AbsScene, a::Id) = stage_ref(s).state.actors[a].inbox
inbox(s::AbsScene) = subject(s).inbox

"""Get the address of an [`Actor`](@ref)'s minder

When called on the [`Scene`](@ref) it will get the current Actor's minder. If
called on an [`Id`](@ref) it will get the minder of the Actor pointed to by
the address.

!!! warning

    It is generally not thread-safe to change `Actor.minder`. However you can
    re-assign a minder's [`Id`](@ref) to another actor.

See [`AbsMinder`](@ref).
"""
minder(s::AbsScene, a::Id)::Id = stage_ref(s).state.actors[a].minder
minder(s::AbsScene) = subject(s).minder

"Get the address ([`Id`](@ref)) of the current [`Actor`](@ref)"
me(s::AbsScene) = subject(s).me

"Get the address ([`Id`](@ref)) of the [`Stage`](@ref)"
function stage(s::AbsScene)
    subject(s)

    Id{Stage}(UInt32(0))
end

"""Send a message asynchronously

This returns immediately and doesn't guarantee the message is processed by the
actor specified by `to`. Nor does it guarantee messages will be delivered in
the order `say` is called.

This may throw an error if, for example, `to` only accepts certain message
types.

This doesn't expect a response from `to`. For that see [`ask`](@ref).
"""
function say(s::AbsScene, to::Id, msg)
    @debug "$s send" to msg
    put!(inbox(s, to), msg)
end

say(s::AbsScene, ::Id{Stage}, msg) = put!(stage_ref(s).inbox, msg)

"""Like [`say`](@ref), but *less likely* to throw an exception if `to` is
dead. This is commonly useful when an unexpected error has occurred and you
want to perform some cleanup without knowing which actors are still
alive. Under normal operation you should expect other actors to be alive if
you are sending them a message.

!!! note

    If, for example, `to` exceeds the highest known ID in the local
    [`Stage`](@ref) then this will still throw a `BoundsError`. This is to
    help prevent silent errors.

"""
try_say(s::AbsScene, to::Id, msg) = try
    say(s, to, msg)
catch ex
    ex isa Union{InvalidStateException, KeyError} || rethrow()
end

"""Handle a received message

Usually called by [`listen!`](@ref) to handle a message taken from the
[`inbox`](@ref). The user defines new `hear` methods to handle messages for
different [`Actor`](@ref)-message type combinations.

It is passed a [`Scene`](@ref) object which has the [`Actor`](@ref) state type
as the first type parameter. By convention this argument is always called `s`,
if you use a different name it may break some non-essential macros. The other
parameter is the message, which is usually called `msg`, unless you have a
more appropriate name, and can be of any type (in a local system).

If `hear` returns a value it will most likely be ignored (unless you override
[`listen!`](@ref)). If you need to respond to a message then use [`say`](@ref)
or [`ask`](@ref).
"""
hear(s::AbsScene{<:AbsStage}, msg) = say(s, my(s).play, msg)

"""Take messages from the [`inbox`](@ref) and process them

By default this simply takes messages from the [`inbox`](@ref) and calls
[`hear`](@ref) on them. However you may wish to process some messages
specially or do some work inbetween messages, in which case you can override
this for a given [`Actor`](@ref) type.

As a general rule, you should make sure to call [`hear`](@ref) on a message if
you can't process it some other way. Otherwise you will prevent some standard
messages from working (such as [`Leave!`](@ref)).
"""
function listen!(s::Scene)
    @debug "$s listening"

    for msg in inbox(s)
        @debug "$s recv" msg

        hear(s, msg)
    end
end

function listen!(s::Scene{<:AbsStage})
    inb = inbox(s)
    as = my(s).actors

    @debug "$s listening"
    for msg in inb
        @debug "$s recv" msg

        hear(s, msg)

        if !isnothing(my(s).time_to_leave) && isempty(as)
            @debug "All actors left on time"
            close(my(s).time_to_leave)
            close(inb)
        end
    end

    @assert !isnothing(my(s).time_to_leave)
end

"""Signal that the current [`Actor`](@ref) should exit (leave)

Usually this closes the [`inbox`](@ref) which will cause the actor to exit
once it has processed any messages it already received. Some actors (e.g
[`Stage`](@ref)) have a grace period where they will continue to accept new
messages.

If you wish to exit immediately then throw an exception.

Also see [`Leave!`](@ref).
"""
leave!(s::AbsScene) = close(inbox(s))

function leave!(s::Scene{<:AbsStage})
    write_lock(my(s).actors) do table
        for a in keys(table.rev_entries)
            try
                put!(a.inbox, Leave!())
            catch ex
                ex isa InvalidStateException || rethrow()
            end
        end
    end

    inb = inbox(s)
    as = my(s).actors
    my(s).time_to_leave = timer = Timer(3)
    @async begin
        wait(timer)
        close(inb)
        @debug "$s Exit grace period over"

        write_lock(as) do table
            for a in keys(table.rev_entries)
                @debug "$a took too long to leave, forcibly closing inbox..."
                close(a.inbox)

                try
                    isnothing(a.task) || wait(a.task)
                catch ex
                    @debug "$a Errored" ex
                end
            end
        end
    end
end

function forward!(s::AbsScene, to::Id)
    as = stage_ref(s).state.actors
    ids = as[subject(s)]
    to_a = as[to]

    for id in ids
        as[Id(id)] = to_a
    end

    task = async(s) do s
        for msg in inbox(s)
            say(s, to, msg)
        end
    end

    yield()
    leave!(s)
    wait(task)
end

"""Used to capture variables from the parent thread/task

This is a workaround for integrating third party libraries which use Task
local storage or similar. By default it does nothing and it is probably best
to avoid using it. See [`enter!`](@ref) and [`play!`](@ref).

Note that this is not necessary for getting OS "environment variables", which
are typically shared amongst threads.
"""
capture_environment(id) = nothing

play!(play) = let id = Id{Stage}(UInt32(0))
    a = Actor(Channel{Any}(1024), Stage(), id, current_task(), id)

    put!(a.inbox, PreGenesis!(play))

    play!(Scene(a, a), capture_environment(id))
end

"""Ran before [`listen!`](@ref) and in [`async`](@ref)

By default does nothing, but can be overriden to mess with an
[`Actor`](@ref)'s internals. It is passed `env` which is taken by
[`capture_environment`](@ref).

See [`enter!`](@ref) and [`play!`](@ref).
"""
function prologue!(s::AbsScene, env) end

"""Start the 'Actor System' or a single [`Actor`](@ref)

Typically the user calls this method on some value which is used as the 'play'
[`Actor`](@ref) state. This then blocks the calling thread until the
[`Stage`](@ref) is sent [`Leave!`](@ref) or dies due to an error which was
allowed to propagate.

This is also called by [`enter!`](@ref), in a new Thread/Task, to run a single
[`Actor`](@ref). Nothing should happen before or after [`play!`](@ref) so it
contains the `Actor`'s full lifetime (excluding Julia internals).

The liftime of the `Actor` looks something like:
1. [`prologue!`](@ref)
2. [`listen!`](@ref)   (unless `prologue!` errors)
3. [`epilogue!`](@ref) (unless `listen!` errors)

Then, if there is an error

4. [`dieing_breath!`](@ref)

You can override any of the above, so if you are forced to override
`play!(s::Scene, env)` this is considered a library design error. Usually if
you feel the need to override any of these, then you should solve the problem
with [`AbsMinder`](@ref) or more message passing instead.
"""
play!(s::Scene, env) = try
    prologue!(s, env)
    listen!(s)
    epilogue!(s, env)
catch ex
    dieing_breath!(s, ex, env)
    rethrow()
finally
    close(inbox(s))
end

"""Run after [`listen!`](@ref)

By default says to [`minder`](@ref) that the [`Actor`](@ref)
[`Left!`](@ref). However it can be overriden to mess with the `Actor`'s
internals.It is passed `env` which is taken by [`capture_environment`](@ref).

See [`enter!`](@ref) and [`play!`](@ref).
"""
epilogue!(::AbsScene, env) = nothing
epilogue!(s::Scene, env) = say(s, minder(s), Left!(me(s)))
epilogue!(::Scene{<:AbsStage}, env) = nothing

"""Run if an exception is thrown in [`play!`](@ref)

By default says to [`minder`](@ref) that the [`Actor`](@ref)
[`Died!`](@ref). However it can be overriden to mess with the `Actor`'s
internals. It is passed `env` which is taken by [`capture_environment`](@ref).

See [`enter!`](@ref) and [`play!`](@ref).
"""
function dieing_breath!(s::Scene, ex, env)
    @debug "$(me(s)) Died" ex
    say(s, minder(s), Died!(me(s), s.subject))
end
dieing_breath!(s::Scene{<:AbsStage}, ex, env) = leave!(s)

"Create a new Task, Thread or similar primitive"
function fork(fn::Function)
    task = Task(fn)
    task.sticky = false
    schedule(task)
end

enter!(s::AbsScene, actor_state::S) where S = enter!(s, actor_state, Any)
enter!(s::AbsScene, actor_state::S, ::Type{M}) where {S, M} =
    enter!(s, actor_state, minder(s), M)
enter!(s::AbsScene, actor_state::S, minder::Id) where S =
    enter!(s, actor_state, minder, Any)
enter!(s::AbsScene, actor_state::S, minder::Id, ::Type{M}) where {S, M} =
    enter!(s, Actor(Channel{M}(512), actor_state, minder))

"""Add a new [`Actor`](@ref) to the [`Stage`](@ref)/Play and return its
[`Id`](@ref). This is usually called by a [`AbsMinder`](@ref)'s
[`Invite!`](@ref) handler.

!!! note

    The `Actor` struct `a` is recreated by the new `Actor` so you can not use
    it to do a reverse lookup of the `Id`.

"""
function enter!(s::AbsScene, a::Actor{S, M}) where {S, M}
    st = stage_ref(s)
    id = push!(st.state.actors, a)
    env = capture_environment(id)

    @debug "$s forking" a
    fork() do
        try
            a = Actor(a.inbox, a.state, a.minder, current_task(), id)
            st.state.actors[id] = a
            play!(Scene(a, st), env)
        catch ex
            @debug "Actor died" s a ex
            rethrow()
        end
    end

    id
end

"""Wait for a message of type `R` and return it

This will block waiting for a message of the right type. It will cause the
[`Actor`](@ref) to become 'insensitive', meaning that all other messages will
be buffered while waiting.

When a message of the right type is recieved, then the buffered messages will
be put back in the [`inbox`](@ref) and the matching message is returned.

In theory this could accept the wrong message if the type matches, but it was
from an old request or it was sent for some other reason. One way to
avoid this is to [`delegate`](@ref) the [`ask`](@ref) request, or the entire
operation, to a [`Stooge`](@ref) which will have a new address.
"""
function expect(s::AbsScene, ::Type{R}) where R
    inb = inbox(s)
    msg = take!(inb)
    msg isa R && return msg

    scratch = Any[msg]
    for outer msg in inb
        msg isa R && break

        push!(scratch, msg)
    end

    foreach(m -> put!(inb, m), scratch)

    msg
end

"""Like [`say`](@ref), but wait for a response of a given type `R`

Simply calls `say` then [`expect`](@ref).
"""
function ask(s::AbsScene, a::Id, favor, ::Type{R}) where R
    me(s) == a && error("Asking oneself results in deadlock")
    say(s, a, favor)
    expect(s, R)
end

# Messages

"Used by the [`Stage`](@ref) for bootstraping"
struct PreGenesis!{T}
    "The state of the first user defined [`Actor`](@ref)"
    play::T
end

function hear(s::Scene{<:AbsStage}, msg::PreGenesis!{S}) where S
    logger = enter!(s, Logger(stdout), me(s), LoggerMsgs)
    passive_minder = enter!(s, PassiveMinder(logger), me(s))
    tree_minder = enter!(s, TreeMinder(passive_minder), passive_minder)

    play = my(s).play = ask(s, tree_minder, Invite!(me(s), msg.play), Invited!{S}).who
    say(s, play, Genesis!())
end

"Sent to the users 'play' [`Actor`](@ref) to get things started"
struct Genesis! end

"Informs that an [`Actor`](@ref) left"
struct Left!
    "The `Actor` who left"
    who::Id
end

function hear(s::Scene{Stage}, msg::Left!)
    my(s).actors[msg.who] = nothing

    isnothing(my(s).time_to_leave) && leave!(s)
end

"Informs that an [`Actor`](@ref) died"
struct Died!
    "The `Actor` who died"
    who::Id
    "The `Actor` who died's data"
    corpse::Actor
end

hear(s::Scene{<:AbsStage}, msg::Died!) = leave!(s)

"Tell an [`Actor`](@ref) to [`leave!`](@ref)"
struct Leave! end

hear(s::AbsScene, msg::Leave!) = leave!(s)
hear(s::AbsScene{<:AbsStage}, msg::Leave!) = say(s, my(s).play, msg)

# Actors (Other than Stage)

"""An [`Actor`](@ref) which prints messages to an `IO` stream

By default one of these is created which writes to stdout exlusively.
"""
struct Logger{I <: IO}
    io::I
end

struct LogDied!
    header::String
    died::Died!
end

hear(s::Scene{<:Logger}, msg::LogDied!) = try
    io = my(s).io

    printstyled(io, "Error: "; bold=true, color=Base.error_color())
    printstyled(io, msg.header; color=Base.error_color())
    println(io)

    task = msg.died.corpse.task
    if isnothing(task)
        println(io, "Actor task is nothing; actor was not started?")
    elseif isnothing(task.exception)
        println(io, "Actor task has no exception? $(task)")
    else
        showerror(io, task.exception, task.backtrace)
    end

    flush(io)
catch ex
    @debug "Arhhgg; Logger died while trying to do its basic duty" ex
    rethrow()
end

struct LogInfo!
    from::Id
    mod::String
    file::String
    line::Int64
    info::String
end

"""Print an info message

Uses the [`Logger`](@ref) provided by [`minder`](@ref) to print some
informational text.
"""
macro say_info(s, exp)
    (mod, file, line) = Base.CoreLogging.@_sourceinfo
    file = basename(file)
    mod = string(mod)

    esc(:(say($s, minder($s), LogInfo!(me($s), $mod, $file, $line, $exp))))
end

hear(s::Scene{<:Logger}, msg::LogInfo!) = try
    io = my(s).io

    printstyled(io, "Info"; bold=true, color=Base.info_color())
    printstyled(io, " $(msg.from) $(msg.mod) $(msg.file):$(msg.line): "; color=:light_cyan)
    println(io, msg.info)
    flush(io)
catch ex
    @debug "Arhhgg; Logger died while trying to do its basic duty" ex
    rethrow()
end

const LogMsgs = Union{LogInfo!, LogDied!}
const LoggerMsgs = Union{LogMsgs, Leave!}

"""Request an actor be created with the given `state`. This is usually sent to
an actor's minder which uses [`enter!`](@ref) to create the new actor.

It is expected that minders (subtypes of [`AbsMinder`](@ref)) implement this
unless they are only intended for use with a special set of actors.
"""
struct Invite!{S}
    re::Id
    state::S
end

"A response to [`Invite!`](@ref)"
struct Invited!{S}
    who::Id{S}
end

"""Request an actor be created with the given `state` and return the new
[`Id`](@ref). This is just a wrapper for sending [`Invite!`](@ref) to the
current actor's [`minder`](@ref) and waiting for a response.
"""
invite!(s::Scene, state::S) where S =
    ask(s, minder(s), Invite!(me(s), state), Invited!{S}).who

"""An [`Actor`](@ref) which looks after other `Actors`'s

Every `Actor` is assigned a [`minder`](@ref) which it can call upong to
provide general services (e.g. logging). The [`minder`](@ref) is also notified
when an `Actor` dies or decides to [`Leave!`](@ref). Therefor the `minder` can
take action to replace a failed actor.
"""
abstract type AbsMinder end

hear(s::Scene{<:AbsMinder}, msg::LogMsgs) = say(s, minder(s), msg)
hear(s::Scene{<:AbsMinder}, msg::Left!) = let as = stage_ref(s).state.actors
    wait(as[msg.who].task)
    as[msg.who] = nothing
    leave!(s)
end
hear(s::Scene{<:AbsMinder}, msg::Died!) = say(s, minder(s), msg)

struct PassiveMinder{L <: Id} <: AbsMinder
    logger::Union{L, Nothing}
end

hear(s::Scene{<:PassiveMinder}, msg::Invited!) = nothing
hear(s::Scene{<:PassiveMinder}, msg::LogMsgs) = say(s, my(s).logger, msg)
hear(s::Scene{<:PassiveMinder}, msg::Died!) = try
    Base._wait(msg.corpse.task)
    say(s, my(s).logger, LogDied!("$(me(s)): Actor $(msg.who) died!", msg))
    leave!(s)
catch ex
    @debug "Arrgg; $(typeof(my(s))) died while trying to do its basic duty" ex
    rethrow()
end

"""Organises actors into a hieracy or tree structure. This is used as the
default [`AbsMinder`](@ref) for the play.

When an actor with this minder uses [`invite!`](@ref) the returned actor will
be a child of the current actor (the current actor being the parent). An actor
may have many children, but only a single parent.

* If a child actor dies then the parent recieves [`Died!`](@ref). By default
  actors don't know how to handle this so they will also die. (In any case the
  death will be logged).

* If a parent leaves or dies, then its children are also asked to
  [`Leave!`](@ref).

If you don't wish for an actor to die when one of its children do, then define
[`hear`](@ref) for the [`Died!`](@ref) message.
"""
mutable struct TreeMinder <: AbsMinder
    root::Id
    minded::Union{Id, Nothing}
    children::Set{Id}
end

TreeMinder(root) = TreeMinder(root, nothing, Set())

hear(s::Scene{TreeMinder}, msg::Invite!{S}) where S = let m = my(s)
    if m.minded === nothing
        m.minded = enter!(s, msg.state, me(s))
        say(s, msg.re, Invited!(m.minded))
    else
        child_m = enter!(s, TreeMinder(m.root), me(s))
        say(s, child_m, msg)
        push!(m.children, child_m)
    end
end

hear(s::Scene{TreeMinder}, msg::Leave!) = if isnothing(my(s).minded)
    leave!(s)
else
    try_say(s, my(s).minded, msg)
end

stop_children(s::Scene, m::TreeMinder) = for child in m.children
    try_say(s, child, Leave!())
end

hear(s::Scene{TreeMinder}, msg::Left!) = let m = my(s)
    if msg.who == m.minded
        stop_children(s, m)

        as = stage_ref(s).state.actors
        wait(as[msg.who].task)
        as[msg.who] = nothing
        m.minded = nothing
    else
        @assert msg.who in m.children "$(msg.who) not in $(m.children)"
        delete!(m.children, msg.who)
    end

    isnothing(m.minded) && isempty(m.children) && leave!(s)
end

hear(s::Scene{TreeMinder}, msg::Died!) = let m = my(s)
    if msg.who in m.children
        say(s, m.root, msg)
    elseif msg.who == m.minded
        stop_children(s, m)
        say(s, minder(s), msg)

        Base._wait(msg.corpse.task)
        stage_ref(s).state.actors[msg.who] = nothing
        m.minded = nothing

        say(s, m.root, LogDied!("$(me(s)): Actor $(msg.who) died!", msg))
        isempty(m.children) && leave!(s)
    else
        isnothing(m.minded) || say(s, m.minded, msg)
    end
end

"""A temporary [`Actor`](@ref) which performs one `action` then leaves

Used by [`delegate`](@ref)
"""
struct Stooge
    "What the `Stooge` should do"
    action::Function
    "The arguments passed to `action`"
    args::Tuple
end

listen!(s::Scene{Stooge}) = let stooge = my(s)
    stooge.action(s, stooge.args...)

    leave!(s)
end

"""Perform some `action` in a temporary [`Actor`](@ref)

This creates a new `Actor`, called a [`Stooge`](@ref) and uses it to perform
some action in parallel.

!!! warning

    Do not use variables captured from the surrounding scope, pass them as
    `args...`. The `args` may be copied to avoid concurrency violations.
"""
delegate(action::Function, s::AbsScene, args...) =
    invite!(s, Stooge(action, args))
delegate(action::Function, s::AbsScene, minder::Id, args...) =
    enter!(s, Stooge(action, args), minder)

"""A group of [`Actor`](@ref)'s

Messages [`shout`](@ref)ed at the `Troupe` will be broadcast to the all the
`Actor`'s in it. To send a message to the `Troupe` itself, just use
[`say`](@ref).

### Example

Where `a1..a3` are `Actor` [`Id`](@ref)'s

```
g = enter!(s, Troupe(a1, a2, a3))
shout(s, g, Leave!())
say(s, g, Leave!())
```
"""
struct Troupe
    "The addresses of the `Actor`s in a `Troupe`"
    as::Vector{Id}

    Troupe(as...) = new([as...])
end

"Wraps a message to broadcast ([`shout`](@ref))"
struct Shout!{T}
    msg::T
end

"Broadcast a message to a [`Troupe`](@ref)"
shout(s::AbsScene, troupe::Id{Troupe}, msg) = say(s, troupe, Shout!(msg))

"Broadcast a message to a plain vector of actors"
shout(s::AbsScene, ids, msg) = for a in ids
    say(s, a, msg)
end

hear(s::Scene{Troupe}, msg::Shout!) = shout(s, my(s).as, msg.msg)

"Informs that an asynchronous `Task` failed"
struct AsyncFail!
    "What failed"
    async::Task
end

hear(s::Scene, msg::AsyncFail!) = wait(msg.async)

"""Similar to `@async`, but notifies the calling [`Actor`](@ref) if it fails.

This allows you to create an asynchronous `Task` without waiting on it to
check for errors. If an exception is thrown, the `Actor` will send
[`AsyncFail!`](@ref) to itself. By default this will cause
`TaskFailedException` to be thrown thus killing the `Actor`.
"""
function async(fn, sc::Scene)
    env = capture_environment(me(sc))

    @async begin
        s = AsyncScene(sc, current_task())

        try
            prologue!(s, env)
            fn(s)
            epilogue!(s, env)
        catch ex
            say(s, me(s), AsyncFail!(s.task))
            rethrow()
        end
    end
end

include("interactive.jl")

end # module
