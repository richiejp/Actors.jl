module Actors

using DocStringExtensions

# Misc Types
export Id, Scene

# Actors
export Stage, Troupe

# Functions
export genesis, stage, play!, enter!, leave!, ask, say, hear, me, my, my!
export delegate, shout, minder, @say_info, @try_async

# Messages
export Genesis!, Entered!, Enter!, Leave!, LogInfo!, Died!, Left!, AsyncFail!

# _Naming Conventions_
#
# Variable names should be reasonably descriptive with the following
# exceptions.
#
# a   = Actor or an actor ID
# as  = Actors
# ex  = Exception
# i   = index
# j   = index when i is taken
# msg = message
# re  = return address (i.e. who to reply to)
# st  = Stage
# s   = Scene
# Abs = Abstract
# env = environment
# m   = minder
#
# Avoid using any other abbreviations except in algorithms with a high level
# of abstraction where the variables have no "common sense" meaning. You don't
# have to use these abbreviations if there is a compelling alternative.
#
# Only use cammel case and capitals in type names or constructors. Use
# underscores for everything else.
#
# _Functions_
#
# Use the short form of functions wherever possible.
# Define the parameter types wherever practical.
#
# _Message types_
#
# Types/Structs which are messages have a bang attached (e.g. Leave!)

@template TYPES = """
$DOCSTRING

### Members

$TYPEDFIELDS
"""

@template (FUNCTIONS, METHODS, MACROS) = """
$DOCSTRING

### Signatures

$TYPEDSIGNATURES
"""

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
mutable struct Actor{S, M}
    "How the Actor recieves messages, see [`listen!`](@ref)"
    inbox::Channel{M}
    "An arbitrary value which is usually thought of as the Actor"
    state::S
    "The Task this actor runs/ran in"
    task::Union{Task, Nothing}
    "The `Id` of another actor which will manages and supports this actor"
    minder
end

"Create an Actor with the given state and minder"
Actor{M}(data, minder) where M = Actor(Channel{M}(420), data, nothing, minder)

"""The Address of an [`Actor`](@ref)

This is a safe reference to an [`Actor`](@ref). It is most commonly used to
send messages to an [`Actor`](@ref). However many accessor methods take an
`Id` to safely get or set some `Actor`'s internals or associated data.

!!! note

    One `Actor` should be able to have multiple addresses and the `Actor`
    an address points to should be mutable. However this needs more work,
    so expect address handling to change.

"""
struct Id{S, M}
    "The Address"
    i::UInt64
    "A reference to the actor value, usually accessed with [`my_ref`](@ref)"
    ref::Union{Ref{Actor{S, M}}, Nothing}
end

Base.:(==)(a::Id, b::Id) = a.i == b.i

"""Get a reference to [`Actor`](@ref)'s self

Will throw an exception if called from a task other than the one which the
`Actor` was started on. It is rare for the user to access this directly.
"""
function my_ref(a::Id)
    @assert a.ref !== nothing "Trying to get a remote actor's state"
    @assert a.ref[].task !== nothing "Actor is not playing"
    @assert a.ref[].task === current_task() "Trying to get another actor's state"

    a.ref
end

"""Safely get the current [`Actor`](@ref)'s state

Usually the user passes the [`Scene`](@ref) to this and gets the executing
[`Actor`](@ref)'s state in return.
"""
my(a::Id) = my_ref(a)[].state

"""Set the current [`Actor`](@ref)'s state

The inverse of [`my`](@ref); it is currently useful when the state type is
immutable.

!!! note

    In the future, if messages are handled in parallel, then this could signal
    that the next message may start to be processed.
"""
my!(a::Id, state) = my_ref(a)[].state = state

"""Get the inbox of an [`Actor`](@ref)

Useful when overriding functions such as [`listen!`](@ref) or
[`leave!`](@ref). Otherwise it is quite unusual for the user to call
this.
"""
inbox(a::Id) = a.ref[].inbox

"""Get the address of an [`Actor`](@ref)'s minder

When called on the [`Scene`](@ref) it will get the current Actor's minder. If
called on an [`Id`](@ref) it will get the minder of the Actor pointed to by
the address.

See [`AbsMinder`](@ref).

"""
minder(a::Id)::Id = my_ref(a)[].minder

"""Set the [`Actor`](@ref)'s minder

Inverse of [`minder`](@ref).
"""
minder!(a::Id, m::Id)::Id = my_ref(a)[].minder = m

Base.show(io::IO, id::Id{S}) where S = print(io, "$S@", id.i)

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
    actors::Set{Id}
    "Grace period timer before force leaving"
    time_to_leave::Union{Timer, Nothing}
    "User defined play `Actor`"
    play::Id

    "Create a new [`Stage`](@ref) with `play` state (not `Id`)"
    function Stage(play)
        st = new(Set{Id}(), nothing)
        actor = Actor{Any}(st, Id{Nothing, Nothing}(UInt64(0), nothing))
        a = Id(UInt64(0), Ref(actor))
        actor.minder = a

        put!(inbox(a), PreGenesis!(play))

        a
    end
end

"""The context of message processing

Contains common information which is used by many different methods during
message handling. You should assume that the members of this struct are likely
to change.

### Type Parameters

- `S` The type of the current [`Actor`](@ref)'s state. This is commonly
  specified when adding a method for [`hear`](@ref) (amongst much else).

- `M` The message types accepted by the current `Actor`, usually `Any`.

"""
struct Scene{S, M}
    "The address of the current [`Actor`](@ref)"
    subject::Id{S, M}
    "The [`Stage`](@ref)"
    stage::Id{Stage, Any}
end

"Get the address ([`Id`](@ref)) of the current [`Actor`](@ref)"
me(s::Scene) = s.subject
my(s::Scene) = my(me(s))
my!(s::Scene, state) = my!(me(s), state)

"Get the address ([`Id`](@ref)) of the [`Stage`](@ref)"
stage(s::Scene) = s.stage
inbox(s::Scene) = inbox(me(s))
minder(s::Scene) = minder(me(s))
minder!(s::Scene, m::Id) = minder!(me(s), m)

"""Send a message asynchronously

This returns immediately and doesn't guarantee the message is processed by the
actor specified by `to`. Nor does it guarantee messages will be delivered in
the order `say` is called.

This may throw an error if, for example, `to` only accepts certain message
types.

This doesn't expect a response from `to`. For that see [`ask`](@ref).
"""
say(s::Scene, to::Id, msg) = if to.ref === nothing
    error("$to appears to be a remote actor; use shout instead")
else
    @debug "$(stage(s))/$(me(s)) send to $to" msg
    put!(inbox(to), msg)
end

hear(s::Scene{<:AbsStage}, msg) = say(s, my(s).play, msg)

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

leave!(s::Scene) = close(inbox(s))
function leave!(s::Scene{<:AbsStage})
    actors = my(s).actors

    for a in actors
        try
            put!(inbox(a), Leave!())
        catch ex
            ex isa InvalidStateException || rethrow()
        end
    end

    my(s).time_to_leave = timer = Timer(3)
    @async begin
        wait(timer)
        close(inbox(s))
        @debug "$s Exit grace period over"

        for a in actors
            @debug "$a took too long to leave, forcibly closing inbox..."
            close(inbox(a))
            try
                wait(a.ref[].task)
            catch ex
                @debug "$a Errored" ex
            end
        end
    end
end

capture_environment(::Id) = nothing

play!(play) = let st = Stage(play)
    play!(Scene(st, st), capture_environment(st))
end

function prologue!(s::Scene, env) end

function play!(s::Scene, env)
    try
        let a = s.subject.ref[]
            @assert a.task === nothing "Actor is already playing"
            a.task = current_task()
            a.task.sticky = true
        end

        prologue!(s, env)
        listen!(s)
        epilogue!(s, env)
    catch ex
        dieing_breath!(s, ex, env)
        rethrow()
    finally
        close(inbox(s))
    end
end

epilogue!(s::Scene, env) = say(s, minder(s), Left!(me(s)))
epilogue!(s::Scene{<:AbsStage}, env) = nothing
dieing_breath!(s::Scene, ex, env) = let a = me(s)
    @debug "$a Died" ex
    say(s, minder(s), Died!(a, my_ref(a)[]))
end

function register!(s::Scene{<:AbsStage}, actor::Actor)::Id
    as = my(s).actors
    a = Id(UInt64(length(as) + 1), Ref(actor))

    push!(as, a)

    a
end

function fork(fn::Function)
    task = Task(fn)
    task.sticky = false
    schedule(task)
end

function enter!(s::Scene{<:AbsStage}, actor::Actor)
    a = register!(s, actor)
    st = stage(s)
    env = capture_environment(st)

    fork(() -> play!(Scene(a, st), env))

    a
end

function ask(s::Scene, a::Id, favor, ::Type{R}) where R
    me(s) == a && error("Asking oneself results in deadlock")
    say(s, a, favor)

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

# Messages

struct PreGenesis!{T}
    play::T
end

function hear(s::Scene{<:AbsStage}, msg::PreGenesis!)
    logger = enter!(s, LoggerActor(stdout, me(s)))
    minder!(s, enter!(s, Actor{Any}(PassiveMinder(logger), me(s))))

    play = my(s).play = enter!(s, msg.play)
    say(s, play, Genesis!())
end

struct Genesis! end

struct Entered!{S, M}
    who::Id{S, M}
end

struct Enter!{S, M}
    actor::Actor{S, M}
    re::Union{Id, Nothing}
end

enter!(s::Scene, actor_state::S) where S = enter!(s, actor_state, Any)
enter!(s::Scene, actor_state::S, ::Type{M}) where {S, M} =
    enter!(s, actor_state, minder(s), M)
enter!(s::Scene, actor_state::S, minder::Id) where S =
    enter!(s, actor_state, minder, Any)
enter!(s::Scene, actor_state::S, minder::Id, ::Type{M}) where {S, M} =
    enter!(s, Actor{M}(actor_state, minder))
enter!(s::Scene, a::Actor{S, M}) where {S, M} =
    ask(s, stage(s), Enter!(a, me(s)), Entered!{S, M}).who

function hear(s::Scene{<:AbsStage}, msg::Enter!)
    a = enter!(s, msg.actor)

    if isnothing(msg.re)
        say(s, a, Entered!(a))
    else
        say(s, msg.re, Entered!(a))
    end
end

struct Left!
    who::Id
end

function hear(s::Scene{Stage}, msg::Left!)
    wait(msg.who.ref[].task)
    delete!(my(s).actors, msg.who)
end

struct Died!
    who::Id
    corpse::Actor
end

hear(s::Scene{<:AbsStage}, msg::Died!) = leave!(s)

struct Leave! end

hear(s::Scene, msg::Leave!) = leave!(s)
# Prevents ambiguity with hear(s::Scene{Stage}, msg)
hear(s::Scene{<:AbsStage}, msg::Leave!) = leave!(s)

# Actors (Other than Stage)

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
    showerror(io, task.exception, task.backtrace)
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
LoggerActor(io::IO, minder::Id) = Actor{LoggerMsgs}(Logger(io), minder)

abstract type AbsMinder end

logger(s::Scene{<:AbsMinder}) = logger(my(s))

hear(s::Scene{<:AbsMinder}, msg::LogMsgs) = say(s, logger(s), msg)
hear(s::Scene{<:AbsMinder}, msg::Left!) = nothing
hear(s::Scene{<:AbsMinder}, msg::Died!) = try
    say(s, logger(s), LogDied!("$(me(s)): Actor $(msg.who) died!", msg))
    say(s, stage(s), msg)
catch ex
    @debug "Arrgg; $(typeof(my(s))) died while trying to do its basic duty" ex
    rethrow()
end

struct PassiveMinder{L <: Id} <: AbsMinder
    logger::Union{L, Nothing}
end

logger(m::PassiveMinder) = m.logger

struct Stooge
    action::Function
    args::Tuple
end

listen!(s::Scene{Stooge}) = let stooge = my(s)
    stooge.action(s, stooge.args...)

    leave!(s)
end

delegate(action::Function, s::Scene, args...) =
    enter!(s, Stooge(action, args))
delegate(action::Function, s::Scene, minder::Id, args...) =
    enter!(s, Stooge(action, args), minder)

struct Troupe
    as::Vector{Id}

    Troupe(as...) = new([as...])
end

struct Shout!{T}
    msg::T
end

shout(s::Scene, troupe::Id{Troupe}, msg) = say(s, troupe, Shout!(msg))

hear(s::Scene{Troupe}, shout::Shout!) = for a in my(s).as
    say(s, a, shout.msg)
end

struct AsyncFail!
    async::Task
end

hear(s::Scene, msg::AsyncFail!) = wait(msg.async)

macro try_async(s, expr)
    expr = quote
        @async try
            $expr
        catch
            say($s, me($s), AsyncFail!(current_task()))
            rethrow()
        end
    end

    esc(expr)
end

end # module
