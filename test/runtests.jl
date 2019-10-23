using Test
using luvvy
import luvvy: hear # Allows us to write just 'hear(...)' instead of 'luvvy.hear(...)'

# Unusually (I hope) we need to change some of Stage's message handlers dynamically
# because we create a new stage for each test in the same process.
mutable struct TestProps
    genesis::Function
    entered::Function
    leave::Function
end

TestProps() = TestProps(
    (s, msg) -> error("Dynamic handler for Genesis! not set!"),
    (s, msg) -> error("Did we expect Stage to be sent $msg?"),
    (s, msg) -> leave!(s)
)

include("TestSet.jl")

hear(s::Scene{Stage}, msg::Genesis!) = let ts = Test.get_testset()
    if ts isa LuvvyTestSet
        ts.myself = enter!(s, ts)
    end

    my(s).props.genesis(s, msg)
end

hear(s::Scene{Stage}, msg::Entered!) = my(s).props.entered(s, msg)
hear(s::Scene{Stage}, msg::Leave!) = my(s).props.leave(s, msg)

# Used by TestSet.jl, it will be reset after each @testset LuvvyTestset
# invocation. This is to work around a bug/feature in the @testset macro which
# qualifies the name of any variable used in the optional arguments with 'Test'.
props = TestProps()

# Sanity check without using our custom TestSet
#
# Even inside the tests we try to stick to using actors for
# everything. However this test is the exception where we use a Channel
# directly for collecting the result.
@testset "Hello, World!" begin
    test_chnl = Channel(1)

    "Our Actor"
    struct Julia end

    "Our Message"
    struct HelloWorld! end

    luvvy.hear(s::Scene{A}, ::HelloWorld!) where A =
        put!(test_chnl, "Hello, World! I am $(A)!")

    props.genesis = (s, _) -> begin
        julia = enter!(s, Julia())

        say(s, julia, HelloWorld!())

        leave!(s)
    end

    testset_play!()
    @test take!(test_chnl) == "Hello, World! I am Julia!"
    close(test_chnl)
end

luvvy.prologue!(::Id{Stage}, a::Actor{LuvvyTestSet}

props = TestProps()

@testset LuvvyTestSet "TestSet Test" begin
    props.genesis = (s, _) -> delegate(s) do s
        @assert Test.get_testset() isa LuvvyTestSet
        @test true
        @test 1 + 1 == 2

        say(s, stage(s), Leave!())
    end

    testset_play!()
end

include("Luvvies.jl")
include("Stack.jl")
