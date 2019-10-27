import Test: AbstractTestSet, DefaultTestSet, record, finish, Result
import luvvy: Actor

"Allows the Test macros to be safely used in any actor"
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

struct TestEnvironment
    ts::LuvvyTestSet
end

# Get our test set from the main task's (The Stage's task) local storage
luvvy.capture_environment(::Id{Stage}) = TestEnvironment(Test.get_testset())

# Inject the test set actor into our play when the Stage starts
luvvy.prologue!(s::Scene{Stage}, env::TestEnvironment) =
    env.ts.myself = enter!(s, env.ts)

# Inject the test set into a new actor's Task local storage
luvvy.prologue!(s::Scene, env::TestEnvironment) = Test.push_testset(env.ts)
