using Test
using luvvie

abstract type Luvvie end

struct Duck <: Luvvie
    name::String
    pop::Int
end

struct Director <: Luvvie
    name::String
    pop::Int
end

struct WhoLovesMe
    sender::Id
end

struct HowPopularAreYou
    sender::Id
end

hear(scene::Scene, msg::HowPopularAreYou) = with_state_copy(scene) do state
    next(scene)
    say(scene, msg.sender, state.pop)
end

hear(scene::Scene, cast::Id{Cast}) = say(scene, cast, WhoLovesMe(scene.target))

function hear(scene::Scene, msg::WhoLovesMe)
    other_pop = ask(scene, msg.sender, Val(:how_popular_are_you))
    my_pop = take_state(scene).pop
    next(scene)

    if my_pop <= other_pop
        say(scene, sender, Val(:i_love_you))
    end
end

hear(scene::Scene, ::Val{:i_love_you}) = update_state(scene) do state
    Duck(state.name, state.pop + 1)
end

stage = Stage()

brian = enter!(stage, () -> Duck("Brian", 1))
nigel = enter!(state, () -> Duck("Nigel", 0))

say(stage, nigel, WhoLovesMe(brian))

sleep(1)

@test brian.ref[].pop == 2


