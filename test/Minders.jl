const ERROR_MSG = "Pretend Error"

struct MinderUser end

function hear(s::Scene{MinderUser}, ::Val{:die!})
    invite!(s, MinderUser())
    error(ERROR_MSG)
end

function hear(s::Scene{MinderUser}, ::Leave!)
    # Should be called by the minder before Stage has chance
    @test isnothing(Actors.stage_ref(s).state.time_to_leave)
    leave!(s)
end

struct MinderPlay end

function hear(s::Scene{MinderPlay}, ::Genesis!)
    user = invite!(s, MinderUser())

    say(s, user, Val(:die!))

    msg = expect(s, Died!)
    @test msg.corpse.task.exception.msg == ERROR_MSG
    leave!(s)
end

@testset LuvvyTestSet expect=2 "Minders" begin
    play!(MinderPlay())
end

