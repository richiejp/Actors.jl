# Popularity begets popularity
#
# Script:
#   We create the stage and this triggers Genesis!
#   In the handler for the Genesis! message we create two actors
#   One actor is created by sending the Enter! message (Nigel)
#   The other actor is created inline (Brian)
#   When Nigel's Enter! message is processed Entered! is sent
#   In the Entered! handler we ask all the other actors who loves who
#   Each actor recieves WhoLoves! messages asking if they love another actor
#   They spawn a Stooge (with delegate()) to query the other's popularity
#   (if they didn't it could result in deadlock)
#   If the other actor is more or equally popular, they give them love
#   Brian is more popular than Nigel so she gets some love and Nigel doesn't
#   After Brian increases his popularity, he tells the whole Stage to leave
#   When the Stage recieves the Leave message, it tests Brians popularity
#   The library then tells all the actors to leave.
#
@testset "luvvies sim" begin
    struct Actor
        name::String
        pop::Int
    end

    struct WhoLoves!
        re::Id
    end

    struct HowPopularAreYou!
        re::Id
    end

    luvvy.hear(s::Scene{Actor}, msg::HowPopularAreYou!) =
        say(s, msg.re, my(s).pop)

    luvvy.hear(s::Scene{Actor}, msg::WhoLoves!) = if me(s) != msg.re
        delegate(s, my(s).pop, msg.re) do s, my_pop, re
            other_pop = ask(s, re, HowPopularAreYou!(me(s)), Int)

            my_pop <= other_pop && say(s, re, Val(:i_love_you!))
        end
    end

    luvvy.hear!(s::Scene{Actor}, ::Val{:i_love_you!}) = let state = my(s)
        my!(s, Actor(state.name, state.pop + 1))

        say(s, stage(s), Leave!())
    end

    function luvvy.hear(s::Scene{Stage}, msg::Entered!)
        roar(s, WhoLoves!(msg.who))     # Nigel
        roar(s, WhoLoves!(my(s).props)) # Brian
    end

    luvvy.hear(s::Scene{Stage}, ::Genesis!) = let st = stage(s)
        say(s, st, Enter!(Actor("Nigel", 0), st))
        my(s).props = enter!(s, Actor("Brian", 1))
    end

    function luvvy.hear(s::Scene{Stage}, msg::Leave!)
        @test ask(s, my(s).props, HowPopularAreYou!(me(s)), Int) == 2

        leave!(s)
    end

    play!(Stage())
end
