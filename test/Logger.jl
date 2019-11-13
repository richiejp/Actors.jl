struct LoggerPlay
    io::IOBuffer
end

function hear(s::Scene{LoggerPlay}, ::Genesis!)
    log = enter!(s, Logger(my(s).io))

    say(s, log, LogInfo!(me(s), "Noise"))

    mindy = enter!(s, PassiveMinder(log))

    delegate(s, mindy) do
        error("Drama")
    end

    say(s, stage(s), Leave!())
end

@testset "Logger Test" begin
    io = IOBuffer()

    play!(LoggerPlay(io))

    s = String(take!(io))
    @test occursin("Noise", s)
    @test occursin("Drama", s)
end
