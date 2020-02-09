struct LoggerPlay
    io::IO
end

struct LoggerPlayMinder <: Actors.AbsMinder end

hear(s::Scene{LoggerPlayMinder}, ::Left!) = say(s, stage(s), Leave!())

function hear(s::Scene{LoggerPlay}, ::Genesis!)
    log = invite!(s, Actors.Logger(my(s).io))
    m1 = invite!(s, LoggerPlayMinder())
    m2 = enter!(s, Actors.PassiveMinder(log), m1)

    delegate(s, m2) do s
        @say_info s "Noise"
        error("Drama")
    end
end

@testset "Logger Test" begin
    io = Base.BufferStream()

    play!(LoggerPlay(io))

    close(io)
    s = String(take!(io.buffer))

    @test occursin("Noise", s)
    @test occursin("Drama", s)
end
