struct LoggerPlay
    io::IOBuffer
end

function hear(s::Scene{LoggerPlay}, ::Genesis!)
    io = IObuffer()
    log = enter!(s, Logger(io))

    say(s, log, LogInfo!(me(s), "Noise"))

    mindy = enter!(s, PassiveMinder(log))

    say(s, stage(s), Leave!())
end

@testset LuvvyTestSet "Logger Test" begin
    play!(TestSetTest())
end
