import Test: AbstractTestSet, DefaultTestSet, record, finish, Result
import luvvy: Actor

"Makes sure the DefaultTestSet is only updated by a single thread"
mutable struct LuvvyTestSet <: AbstractTestSet
    ts::DefaultTestSet

    myself::Id{LuvvyTestSet}

    LuvvyTestSet(desc) = new(DefaultTestSet(desc))
end

hear(s::Scene{LuvvyTestSet}, res::Result) = record(my(s).ts, res)
record(ts::LuvvyTestSet, res::Result) = put!(luvvy.inbox(ts.myself), res)
finish(ts::LuvvyTestSet) = finish(ts.ts)

# Note that overriding the following methods is considered a last resort for
# integrating with another library.

# Inject the test set actor into our play
function luvvy.prologue!(::Id{Stage}, st::Actor{Stage}, id::Id{Stage})
    @assert st.task === nothing "Actor is already playing"
    st.task = current_task()

    ts = Test.get_testset()
    ts.myself = enter!(Scene(id, id), ts)
end

# Inject the test set into a new actor's Task local storage
function luvvy.fork!(fn::Function, s::Scene)
    ts = Test.get_testset()
    task = Task() do
        Test.push_testset(ts)
        fn()
    end

    task.sticky = false
    schedule(task)
end
