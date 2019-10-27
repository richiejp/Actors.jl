module luvvy

# Types
export Id, Stage, Scene

# Functions
export genesis, stage, play!, enter!, leave!, ask, say, roar, hear, me, my,
       my!, delegate

# Message Types
export Genesis!, Entered!, Enter!, Leave!, Roar!, Forward!

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

mutable struct Actor{S}
    inbox::Channel{Any}
    state::S
    task::Union{Task, Nothing}
end

Actor(data) = Actor(Channel(420), data, nothing)

struct Id{S}
    i::UInt64
    ref::Union{Ref{Actor{S}}, Nothing}
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

Base.show(io::IO, id::Id{S}) where S = print(io, "$S@", id.i)

abstract type AbsStage end

mutable struct Stage <: AbsStage
    actors::Set{Id}
    play::Id

    function Stage(play)
        st = new(Set{Id}())
        a = Id(UInt64(0), Ref(Actor(st)))

        put!(inbox(a), PreGenesis!(play))

        a
    end
end

struct Scene{S}
    subject::Id{S}
    stage::Id{Stage}
end

me(s::Scene) = s.subject
my(s::Scene) = my(me(s))
my!(s::Scene, state) = my!(me(s), state)
stage(s::Scene) = s.stage
inbox(s::Scene) = inbox(me(s))

say(s::Scene, to::Id, msg) = if to.ref === nothing
    error("$to appears to be a remote actor; use shout instead")
else
    @debug "$(stage(s))/$(me(s)) send to $to" msg
    put!(inbox(to), msg)
end

shout(s::Scene, to::Id, msg) = error("Not implemented")
roar(s::Scene, msg) = say(s, stage(s), Roar!(msg))
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
    finally
        close(inb)
    end
end

function listen!(s::Scene{<:AbsStage})
    inb = inbox(s)
    as = my(s).actors

    @debug "$s listening"
    try
        for msg in inb
            @debug "$s recv" msg

            hear(s, msg)
        end
    finally
        kill_all!(as)
    end

    empty!(as)
end

leave!(s::Scene) = close(inbox(s))

capture_environment(::Id) = nothing

play!(play) = let st = Stage(play)
    play!(Scene(st, st), capture_environment(st))
end

function prologue!(s::Scene, environment) end

function play!(s::Scene, environment)
    try
        let a = s.subject.ref[]
            @assert a.task === nothing "Actor is already playing"
            a.task = current_task()
        end

        prologue!(s, environment)
        listen!(s)
    catch ex
        showerror(stderr, ex, catch_backtrace())
    finally
        close(inbox(s))
    end

    epilogue!(s, environment)
end

epilogue!(s::Scene, environment) = try
    say(s, stage(s), Left!(me(s)))
catch
end

function fork(fn::Function)
    task = Task(fn)
    task.sticky = false
    schedule(task)
end

enter!(s::Scene, actor_state) = ask(s, stage(s), Enter!(actor_state, me(s)), Entered!).who
function enter!(s::Scene{Stage}, actor_state)
    as = my(s).actors
    a = Id(UInt64(length(as) + 1), Ref(Actor(actor_state)))
    push!(as, a)

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
    play = my(s).play = enter!(s, msg.play)
    say(s, play, Genesis!())
end

struct Genesis! end

struct Entered!{S}
    who::Id{S}
end

struct Enter!{S}
    actor_state::S
    re::Union{Id, Nothing}
end

Enter!(actor_state) = Enter!(actor_state, nothing)

function hear(s::Scene{Stage}, msg::Enter!)
    a = enter!(s, msg.actor_state)

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

struct Forward!{T}
    msg::T
end

struct Roar!{T}
    msg::T
end

hear(s::Scene{Stage}, roar::Roar!) = for a in my(s).actors
    try
        say(s, a, roar.msg)
    catch ex
        ex isa InvalidStateException || rethrow()
        @debug "$(me(s)) $a left without saying goodbye!"
    end
end

struct Leave! end

hear(s::Scene, msg::Leave!) = close(inbox(s))
hear(s::Scene{<:AbsStage}, msg::Leave!) = close(inbox(s)) # Prevent ambiguity

# Extras

struct Stooge
    action::Function
    args::Tuple
end

hear(s::Scene{Stooge}, ::Entered!{Stooge}) = let stooge = my(s)
    stooge.action(s, stooge.args...)

    close(inbox(s))
end

delegate(action::Function, s::Scene, args...) =
    say(s, stage(s), Enter!(Stooge(action, args), nothing))

end # module
