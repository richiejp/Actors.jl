struct LoggerPlay
    io::IOBuffer
end

function hear(s::Scene{LoggerPlay}, ::Genesis!)
    log = enter!(s, Actors.Logger(my(s).io), Actors.LoggerMsgs)
    mindy = enter!(s, Actors.PassiveMinder(log))

    delegate(s, mindy) do s
        @say_info s "Noise"
        error("Drama")
    end
end

@testset "Logger Test" begin
    io = IOBuffer()

    play!(LoggerPlay(io))

    s = String(take!(io))
    @test occursin("Noise", s)
    @test occursin("Drama", s)
end
