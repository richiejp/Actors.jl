import Test: AbstractTestSet, DefaultTestSet, record, finish, Result
import luvvy: Actor

"Makes sure the DefaultTestSet is only updated by Stage (i.e. the main thread)"
mutable struct LuvvyTestSet <: AbstractTestSet
    ts::DefaultTestSet

    myself::Id{LuvvyTestSet}

    LuvvyTestSet(desc) = new(DefaultTestSet(desc))
end

function hear(s::Scene{LuvvyTestSet}, res::Result)
    @info "Recording" res

    record(my(s).ts, msg.res)
end

function record(ts::LuvvyTestSet, res::Result)
    @info "send record" res

    put!(luvvy.inbox(ts.myself), res)
end

function finish(ts::LuvvyTestSet)
    @info "In finish"
    finish(ts.ts)
end

function luvvy.prologue!(::Id{Stage}, st::Actor{Stage}, id::Id{Stage})
    @assert st.task === nothing "Actor is already playing"
    @info "in stage prologue"
    st.task = current_task()

    ts = Test.get_testset()
    ts.myself = enter!(Scene(id, id), ts)
end
