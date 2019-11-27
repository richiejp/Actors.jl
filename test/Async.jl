struct AsyncTestMinder <: Actors.AbsMinder end

const ERROR_MSG = "Error Message"

function hear(s::Scene{AsyncTestMinder}, msg::Died!)
    @test msg.corpse.task.exception.msg == ERROR_MSG

    say(s, stage(s), msg)
end

struct AsyncUser end

hear(s::Scene{AsyncUser}, ::Val{:go!}) = @try_async s error(ERROR_MSG)

struct AsyncPlay end

function hear(s::Scene{AsyncPlay}, ::Genesis!)
    mindy = enter!(s, AsyncTestMinder())
    user = enter!(s, AsyncUser(), mindy)

    say(s, user, Val(:go!))
end

@testset LuvvyTestSet expect=1 "Async" begin
    play!(AsyncPlay())
end

