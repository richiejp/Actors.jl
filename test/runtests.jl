using Test
using luvvie

struct Duck
    name::String
    pop::Int
end

struct WhoLovesMe
    re::Id
end

struct HowPopularAreYou
    re::Id
end

luvvie.hear(s::Scene{Duck}, msg::HowPopularAreYou) =
    say(s, msg.re, my(s).pop)

function luvvie.hear(s::Scene{Duck}, msg::WhoLovesMe)
    other_pop = ask(s, msg.re, HowPopularAreYou(me(s)))
    my_pop = my(s).pop

    if my_pop <= other_pop
        say(s, msg.re, Val(:i_love_you))
    end
end

function luvvie.hear(s::Scene{Duck}, ::Val{:i_love_you})
    my(s).pop += 1

    say(stage(s), TheEnd!())
end

luvvie.hear(s::Scene{Stage}, msg::Entered!) =
    roar(s, WhoLovesMe(msg.who))

function luvvie.hear(s::Scene{Stage}, ::Genesis!)
    st = stage(s)

    say(s, st, Enter!(Duck("Nigel", 0), st))
    say(s, st, Enter!(Duck("Brian", 1), st))
end

st = genesis()

play!(st)

@test st.ref[].state.actors[1].ref[].state.pop == 2


