import Test: AbstractTestSet, DefaultTestSet, record, finish, Result, Pass
import Actors: Actor

"Allows the Test macros to be safely used in any actor"
mutable struct LuvvyTestSet <: AbstractTestSet
    desc::String
    results::Vector{Result}
    expect::Int

    myself::Id{LuvvyTestSet}

    LuvvyTestSet(desc; expect=0) = new(desc, [], expect)
end

hear(s::Scene{LuvvyTestSet}, res::Result) = push!(my(s).results, res)
record(ts::LuvvyTestSet, res::Result) = put!(Actors.inbox(ts.myself), res)
finish(ts::LuvvyTestSet) = let dts = DefaultTestSet(ts.desc)
    wrong_length = ts.expect > 0 && ts.expect != length(ts.results)

    if any(res -> !(res isa Pass), ts.results) || wrong_length
        sleep(0.5)
    end

    foreach(res -> record(dts, res), ts.results)
    finish(dts)

    if wrong_length
        printstyled("Test Set Error: "; bold=true, color=Base.error_color())
        printstyled("Expected $(ts.expect) '$(ts.desc)' tests in total!\n";
                    color=Base.error_color())
    end
end

# Note that overriding the following methods is considered a last resort for
# integrating with another library.

struct TestEnvironment
    ts::LuvvyTestSet
end

# Get our test set from the main task's (The Stage's task) local storage
Actors.capture_environment(::Id{Stage}) = TestEnvironment(Test.get_testset())

# Inject the test set actor into our play when the Stage starts
Actors.prologue!(s::Scene{Stage}, env::TestEnvironment) =
    env.ts.myself = enter!(s, env.ts)

# Inject the test set into a new actor's Task local storage
Actors.prologue!(s::Scene, env::TestEnvironment) = Test.push_testset(env.ts)
