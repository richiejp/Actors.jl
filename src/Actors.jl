module Actors

# Misc Types
export Id, Scene

# Actors
export Stage, Troupe

# Functions
export genesis, stage, play!, enter!, leave!, ask, say, hear, me, my, my!
export delegate, shout, minder, @say_info

# Messages
export Genesis!, Entered!, Enter!, Leave!, LogInfo!, Died!, Left!

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

mutable struct Actor{S, M}
    inbox::Channel{M}
    state::S
    task::Union{Task, Nothing}
    minder
end

Actor{M}(data, minder) where M = Actor(Channel{M}(420), data, nothing, minder)

struct Id{S, M}
    i::UInt64
    ref::Union{Ref{Actor{S, M}}, Nothing}
end

Base.:(==)(a::Id, b::Id) = a.i == b.i

function my_ref(a::Id)
    @assert a.ref !== nothing "Trying to get a remote actor's state"
    @assert a.ref[].task !== nothing "Actor is not playing"
    @assert a.ref[].task === current_task() "Trying to get another actor's state"

    a.ref
end

my(a::Id) = my_ref(a)[].state
my!(a::Id, state) = my_ref(a)[].state = state

inbox(a::Id) = a.ref[].inbox
minder(a::Id)::Id = my_ref(a)[].minder
minder!(a::Id, m::Id)::Id = my_ref(a)[].minder = m

Base.show(io::IO, id::Id{S}) where S = print(io, "$S@", id.i)

abstract type AbsStage end

mutable struct Stage <: AbsStage
    actors::Set{Id}
    time_to_leave::Union{Timer, Nothing}
    play::Id

    function Stage(play)
        st = new(Set{Id}(), nothing)
        actor = Actor{Any}(st, Id{Nothing, Nothing}(UInt64(0), nothing))
        a = Id(UInt64(0), Ref(actor))
        actor.minder = a

        put!(inbox(a), PreGenesis!(play))

        a
    end
end

struct Scene{S, M}
    subject::Id{S, M}
    stage::Id{Stage, Any}
end

me(s::Scene) = s.subject
my(s::Scene) = my(me(s))
my!(s::Scene, state) = my!(me(s), state)
stage(s::Scene) = s.stage
inbox(s::Scene) = inbox(me(s))
minder(s::Scene) = minder(me(s))
minder!(s::Scene, m::Id) = minder!(me(s), m)

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

kill_all!(actors) = for a in actors
    inb = inbox(a)

    try
        put!(inb, Leave!())
    catch ex
        ex isa InvalidStateException || rethrow()
    finally
        close(inb)
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
            close(my(s).time_to_leave)
            close(inb)
        end
    end
end

leave!(s::Scene) = close(inbox(s))
function leave!(s::Scene{<:AbsStage})
    kill_all!(my(s).actors)

    my(s).time_to_leave = timer = Timer(1)
    @async begin
        wait(timer)
        close(inbox(s))
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

hear(s::Scene{Stage}, msg::Left!) = delete!(my(s).actors, msg.who)

struct Died!
    who::Id
    corpse::Actor
end

hear(s::Scene{<:AbsStage}, msg::Died!) = close(inbox(s))

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
catch ex
    @debug "Arhhgg; Logger died while trying to do its basic duty" ex
    rethrow()
end

const LoggerMsgs = Union{LogInfo!, LogDied!, Leave!}
LoggerActor(io::IO, minder::Id) = Actor{LoggerMsgs}(Logger(io), minder)

abstract type AbsMinder end

logger(s::Scene{<:AbsMinder}) = logger(my(s))

hear(s::Scene{<:AbsMinder}, msg::Actors.LoggerMsgs) = say(s, logger(s), msg)
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

    close(inbox(s))
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

end # module
