# Popularity begets popularity
@testset "luvvies sim" begin
    struct Darling
        name::String
        pop::Int
    end

    mutable struct LuvviesPlay
        brian::Id{Darling}
        nigel::Id{Darling}

        LuvviesPlay() = new()
    end

    struct WhoLoves!
        re::Id
    end

    struct HowPopularAreYou!
        re::Id
    end

    luvvy.hear(s::Scene{Darling}, msg::HowPopularAreYou!) =
        say(s, msg.re, my(s).pop)

    luvvy.hear(s::Scene{Darling}, msg::WhoLoves!) = if me(s) != msg.re
        delegate(s, my(s).pop, msg.re) do s, my_pop, re
            other_pop = ask(s, re, HowPopularAreYou!(me(s)), Int)

            my_pop <= other_pop && say(s, re, Val(:i_love_you!))
        end
    end

    luvvy.hear(s::Scene{Darling}, ::Val{:i_love_you!}) = let state = my(s)
        my!(s, Darling(state.name, state.pop + 1))

        say(s, stage(s), Leave!())
    end

    luvvy.hear(s::Scene{LuvviesPlay}, ::Genesis!) = let st = stage(s)
        nigel = enter!(s, Darling("Nigel", 0))
        brian = enter!(s, Darling("Brian", 1))

        roar(s, WhoLoves!(nigel))
        roar(s, WhoLoves!(brian))

        state = my(s)
        state.nigel = nigel
        state.brian = brian
    end

    play = LuvviesPlay()
    play!(play)

    @test play.brian.ref[].state.pop == 2
    @test play.nigel.ref[].state.pop == 0
end
