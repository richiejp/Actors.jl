module luvvie

import Threads.@spawn

export Id, Actor, Stage, enter!, say, hear

imap(f) = x -> Iterators.Generator(f, itr)
ifilter(f) = x -> Iterators.filter(f, x)

# import List
include("double_linked_list.jl")

struct Id{A <: Actor}
    i::UInt64
    ref::Union{Ref{A}, Nothing}
end

struct Hissyfit{I <: Id} <: Exception
    actor::I
    loose_ends::List{Task}
end

struct Actor{T}
    inbox::Channel{Envelope}
    state::T
end

Actor(data) = Actor(Channel(), data)

function play!(stage::Stage, actor::A, actor_id::Id{A}) where {A <: Actor}
    loose_ends = List{Task}()

    cleanup_loose_ends() = for cons in loose_ends
        task = cons.data

        if istaskfailed(task)
            close(actor.inbox)

            throw_hissyfit(actor_id, loose_ends)
        elseif istaskdone(task)
            delete!(tasks, cons)
        end
    end

    for msg in actor.inbox
        scene = Scene(false, actor_id, stage)

        task = Task(() -> hear(scene, msg))
        yield(task)

        cleanup_loose_ends()

        while !scene.moved_on && !istaskdone(task)
            cleanup_loose_ends()
            yield()
        end

        if istaskfailed(task)
            push!(loose_ends, task)
            cleanup_loose_ends()
        end

        if !istaskdone(task)
            push!(loose_ends, task)
        end
    end
end

struct Stage
    actors::Vector{Actor}
end

function enter!(stage::Stage, create_actor_state::Function)
    actors = push!(stage.actors, Actor(create_actor_state()))
    i = length(actors)

    Id{A}(i, Ref(actors, i))
end

function say(stage::Stage, target::Id, msg)
    if target.ref === nothing
        error("Remote addresses not implemented")
    else
        put!(target.ref[].inbox, msg)
    end
end

struct Scene{I <: Id}
    moved_on::Bool
    subject::I
    stage::Stage
end

"A group of actors"
struct Cast
end

# enter!(scene::Scene, actor::Id) = push!(scene.actors, actor.i)[end]

# hear(scene::Scene, msg, sender::Id) = for actor in scene.actors
#     say(

greet() = print("Hello World!")

end # module
