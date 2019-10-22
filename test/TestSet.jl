import Test: AbstractTestSet, DefaultTestSet, record, finish

"Makes sure the DefaultTestSet is only updated by Stage (i.e. the main thread)"
struct LuvvyTestSet <: AbstractTestSet
    default::DefaultTestSet

    st::Id{Stage}

    function LuvvyTestSet(desc)
        st = Stage(props) # props is first set in runtest.jl
        global props = TestProps()

        new(DefaultTestSet(desc), st)
    end
end

struct Record!
    ts::LuvvyTestSet
    res
end

function luvvy.hear(s::Scene{Stage}, msg::Record!)
    @info "Recording" msg.res

    record(msg.ts.default, msg.res)
end

function record(ts::LuvvyTestSet, res)
    @info "send record" ts.st res

    put!(luvvy.inbox(ts.st), Record!(ts, res))
end

finish(ts::LuvvyTestSet) = finish(ts.default)

testset_play!() = play!(Test.get_testset().st)
