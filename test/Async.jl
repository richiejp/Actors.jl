const ERROR_MSG = "Error Message"

struct AsyncUser end

hear(s::Scene{AsyncUser}, ::Val{:die!}) = async(s) do s
    error(ERROR_MSG)
end

struct AsyncPlay end

function hear(s::Scene{AsyncPlay}, ::Genesis!)
    user = invite!(s, AsyncUser())

    async(s) do s
        @test my(s) isa AsyncPlay

        say(s, user, Val(:die!))
    end

    msg = expect(s, Died!)
    @test msg.corpse.task.exception.task.exception.msg == ERROR_MSG
    leave!(s)
end

@testset LuvvyTestSet expect=2 "Async" begin
    play!(AsyncPlay())
end

