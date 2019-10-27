struct TypedMessages end

struct Pinger
    pings::UInt
end

struct Ponger
    pongs::UInt
end

struct Ping!{R <: Id}
    re::R
end

struct Pong!
    pongs::UInt
end

hear(s::Scene{Pinger}, msg::Ping!) = let pings = my(s).pings
    local pong

    for _ in 1:pings
        pong = ask(s, msg.re, Ping!(me(s)), Pong!)
    end

    say(s, stage(s), pong)
end

hear(s::Scene{Ponger}, msg::Ping!) = let pongs = my(s).pongs + 1
    say(s, msg.re, Pong!(pongs))
    my!(s, Ponger(pongs))
end

function hear(s::Scene{TypedMessages}, ::Genesis!)
    big = 100_000 # 1_000_000
    little = 220

    enter_pingpong = (pings) -> (enter!(s, Pinger(pings)), enter!(s, Ponger(0)))

    (pinger, ponger) = enter_pingpong(little)
    pong = ask(s, pinger, Ping!(ponger), Pong!)
    @test pong.pongs == little

    (pinger, ponger) = enter_pingpong(big)
    any_time = @elapsed ask(s, pinger, Ping!(ponger), Pong!)

    enter_pingpong =
        (pings) -> (enter!(s, Pinger(pings), Union{Leave!, Ping!, Pong!}),
                    enter!(s, Ponger(0), Union{Leave!, Ping!}))

    (pinger, ponger) = enter_pingpong(little)
    pong = ask(s, pinger, Ping!(ponger), Pong!)
    @test pong.pongs == little

    (pinger, ponger) = enter_pingpong(big)
    union_time = @elapsed ask(s, pinger, Ping!(ponger), Pong!)

    @debug "Typed message times" any_time union_time

    say(s, stage(s), Leave!())
end

@testset LuvvyTestSet "Typed Messages" begin
    play!(TypedMessages())
end
