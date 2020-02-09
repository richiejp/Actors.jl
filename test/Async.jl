struct AsyncTestMinder <: Actors.AbsMinder end

const ERROR_MSG = "Error Message"

function hear(s::Scene{AsyncTestMinder}, msg::Died!)
    Base._wait(msg.corpse.task)
    @test msg.corpse.task.exception.task.exception.msg == ERROR_MSG

    say(s, stage(s), msg)
end

struct AsyncUser end

hear(s::Scene{AsyncUser}, ::Val{:go!}) = async(s) do s
    error(ERROR_MSG)
end

struct AsyncPlay end

function hear(s::Scene{AsyncPlay}, ::Genesis!)
    mindy = enter!(s, AsyncTestMinder())
    user = enter!(s, AsyncUser(), mindy)

    say(s, user, Val(:go!))
    async(s) do s
        @test my(s) isa AsyncPlay
    end
end

@testset LuvvyTestSet expect=1 "Async" begin
    play!(AsyncPlay())
end

