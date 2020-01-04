struct InteractivePlay end

hear(s::Scene{InteractivePlay}, ::Genesis!) = for a in stage_ref(s).state.actors
    a.state isa Person && put!(a.inbox, Genesis!())
    break
end

struct Person end

"Start a minimal actor system which you can interact with from the REPL"
interact!() = interact!(InteractivePlay())

"""Like [`play!`](@ref), but allows you to send and receive messages from the REPL

Calling this will asynchronously start a `play` and return a 2-tuple of
[`Scene`](@ref) and `Task`. The `Scene` can be used to call various methods in
the actor system and the task can be checked to see if the actor system has
failed.

The function [`local_addresses`](@ref) can be used to find out what
[`Id`](@ref) a given actor has.

!!! warning

    This is only intended for interactive use in the Julia REPL or similar
    scenario.

### Example

```jldoctest
julia> using Actors

julia> struct Ponger end

julia> struct Echo
       who::Id
       msg::String
       end

julia> Actors.hear(s::Scene{Ponger}, msg::Echo) = say(s, msg.who, msg.msg)

julia> (s, t) = interact!()
(Scene{Actors.Person}, Task (runnable) @0x00007fafc7dad600)

julia> me(s)
Actors.Person@1

julia> ponger = enter!(s, Ponger())
Ponger@5

julia> ask(s, ponger, Echo(me(s), "Echo, echo, ..."), String)
"Echo, echo, ..."

julia> local_addresses(s)
5-element Array{Pair{Int64,DataType},1}:
 1 => Actors.Person
 2 => Actors.Logger{Base.TTY}
 3 => Actors.PassiveMinder{Id{Actors.Logger{Base.TTY},Union{Leave!, Actors.LogDied!, LogInfo!}}}
 4 => Actors.InteractivePlay
 5 => Ponger

```
"""
function interact!(play)
    inb = Channel{Any}(512)
    env = capture_environment(id)
    st_id = Id{Stage}(UInt32(0))
    local a_id

    task = @async begin
        st = Actor(Channel{Any}(1024), Stage(), st_id, current_task(), st_id)
        a_id = push!(st.state.actors, Actor(inb, Person(), st_id))

        put!(st.inbox, PreGenesis!(play))
        put!(inb, st)

        play!(Scene(st, st), env)
    end

    st = take!(inb)
    a = Actor(inb, Person(), st_id, current_task(), a_id)
    st.state.actors[a_id] = a

    yield()

    Scene(a, st), task
end

listen!(s::Scene{Person}) = take!(inbox(s))

"""Return a list of all the [`Id`](@ref)s and what type of [`Actor`](@ref) they point to

!!! warning

    This is only intended for interactive use in the REPL or for diagnostics.
"""
local_addresses(s::Scene) = [i => typeof(a.state) for (i, a) in enumerate(stage_ref(s).state.actors)]
