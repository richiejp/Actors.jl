# Popularity begets popularity
mutable struct Darling
    name::String
    pop::Int
    play::Id
end

mutable struct LuvviesPlay
    brian::Id{Darling}
    nigel::Id{Darling}

    LuvviesPlay() = new()
    LuvviesPlay(b, n) = new(b, n)
end

struct WhoLoves!
    re::Id
end

struct HowPopularAreYou!
    re::Id
end

struct DeclarePop!
    pop::Int
    who::Id
end

hear(s::Scene{Darling}, msg::HowPopularAreYou!) =
    say(s, msg.re, my(s).pop)

hear(s::Scene{Darling}, msg::WhoLoves!) = if me(s) != msg.re
    delegate(s, my(s).pop, msg.re) do s, my_pop, re
        other_pop = ask(s, re, HowPopularAreYou!(me(s)), Int)

        my_pop <= other_pop && say(s, re, Val(:i_love_you!))
    end
end

hear(s::Scene{Darling}, ::Val{:i_love_you!}) =
    say(s, my(s).play, DeclarePop!((my(s).pop += 1), me(s)))

function hear(s::Scene{LuvviesPlay}, ::Genesis!)
    nigel = my(s).nigel = enter!(s, Darling("Nigel", 0, me(s)))
    brian = my(s).brian = enter!(s, Darling("Brian", 1, me(s)))
    troupe = enter!(s, Troupe(nigel, brian))

    shout(s, troupe, WhoLoves!(nigel))
    shout(s, troupe, WhoLoves!(brian))
end

function hear(s::Scene{LuvviesPlay}, msg::DeclarePop!)
    @test msg.who == my(s).brian
    @test msg.pop == 2
    @test ask(s, my(s).nigel, HowPopularAreYou!(me(s)), Int) == 0

    say(s, stage(s), Leave!())
end

@testset LuvvyTestSet expect=3 "luvvies sim" begin
    play!(LuvviesPlay())
end
