module luvvie

# Types
export Id, Actor, Stage, Scene

# Functions
export genesis, stage, play!, say, roar, hear, me, my, stage

# Message Types
export Genesis!, Entered!, Enter!, TheEnd!, Roar!

imap(f) = x -> Iterators.Generator(f, itr)
ifilter(f) = x -> Iterators.filter(f, x)

# _Naming Conventions_
#
# Variable names should be descriptive and obvious with the following common
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
# Types/Structs which are messages have a bang attached (e.g. TheEnd!)

mutable struct Actor{S}
    inbox::Channel{Any}
    state::S
    task::Union{Task, Nothing}
end

Actor(data) = Actor(Channel(420), data, nothing)
my(a::Actor) = a.state

struct Id{S}
    i::UInt64
    ref::Union{Ref{Actor{S}}, Nothing}
end

function my(a::Id)
    @assert a.ref !== nothing "Trying to get a remote actor's state"
    @assert a.ref[].task !== nothing "Actor is not playing"
    @assert a.ref[].task === current_task() "Trying to get another actor's state"

    my(a.ref[])
end

inbox(a::Id) = a.ref[].inbox

Base.show(io::IO, id::Id{S}) where S = print(io, "$S@", id.i)

struct Stage
    actors::Vector{Id}
end

function genesis()
    a = Id(UInt64(0), Ref(Actor(Stage(Id[]))))

    put!(a.ref[].inbox, Genesis!())

    a
end

struct Scene{S}
    subject::Id{S}
    stage::Id{Stage}
end

me(s::Scene) = s.subject
my(s::Scene) = my(me(s))
stage(s::Scene) = s.stage

say(s::Scene, to::Id, msg) = if to.ref === nothing
    error("Remote addresses not implemented")
else
    @debug "$(stage(s))/$(me(s)) send to $to" msg
    put!(inbox(to), msg)
    nothing
end

roar(s::Scene, msg) = say(s, stage(s), Roar!(msg))

hear(::Scene{S}, msg::M) where {S, M} =
    error("Missing message handler, need hear(::Scene{$S}, ::$M)")

listen!(st::Id{Stage}, a::Id) = for msg in inbox(a)
    @debug "$st/$a recv" msg
    s = Scene(a, st)

    try
        hear(s, msg)
    catch ex
        close(inbox(a))
        showerror(stderr, ex, catch_backtrace())
    end
end

play!(st::Id{Stage}) = play!(st, st)

function play!(st::Id{Stage}, a::Id)
    @assert a.ref[].task === nothing "Actor is already playing"

    a.ref[].task = current_task()

    listen!(st, a)
end

# Messages

struct Genesis! end

hear(::Scene{Stage}, ::Genesis!) = error("You can't ignore Genesis!")

struct Entered!
    who::Id
end

struct Enter!
    actor_state
    re::Union{Id, Nothing}
end

function hear(s::Scene{Stage}, msg::Enter!)
    as = my(s).actors
    a = Id(UInt64(length(as) + 1), Ref(Actor(msg.actor_state)))
    push!(as, a)

    st = stage(s)
    task = Task(() -> play!(st, a))
    task.sticky = false
    schedule(task)

    isnothing(msg.re) || say(s, msg.re, Entered!(a))
end

struct Roar!
    msg
end

hear(s::Scene{Stage}, roar::Roar!) = for a in my(s).actors
    say(s, a, roar.msg)
end

struct TheEnd! end

function hear(s::Scene{Stage}, msg::TheEnd!)
    hear(s, Roar!(msg))
    close(inbox(s))
end

end # module
