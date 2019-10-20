import Test: AbstractTestSet, DefaultTestSet, record, finish

struct LuvvyTestSet <: AbstractTestSet
    default::DefaultTestSet

    st::Id{Stage}

    LuvvyTestSet(desc; stage=nothing) = new(DefaultTestSet(desc), stage)
end

struct Record!
    ts::LuvvyTestSet
    res
end

luvvy.hear(s::Scene{Stage}, msg::Record!) = record(msg.ts, msg.res)

record(ts::LuvvyTestSet, res) = put!(luvvy.inbox(ts.st), Record(ts, res))
finish(ts::LuvvyTestSet) = ts.default

