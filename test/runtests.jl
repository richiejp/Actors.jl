using Test
using luvvy
import luvvy: hear

# Sanity check without using our custom TestSet
@testset "Hello, World!" begin
    test_chnl = Channel(1)

    "Our Play"
    struct HelloWorld end

    "Our Actor"
    struct Julia end

    "Our Message"
    struct HelloWorld! end

    function luvvy.hear(s::Scene{A}, ::HelloWorld!) where A
        put!(test_chnl, "Hello, World! I am $(A)!")
        say(s, stage(s), Leave!())
    end

    function luvvy.hear(s::Scene{HelloWorld}, ::Genesis!)
        julia = enter!(s, Julia())
        say(s, julia, HelloWorld!())
    end

    play!(HelloWorld())
    @test take!(test_chnl) == "Hello, World! I am Julia!"
    close(test_chnl)
end

# Another test not using the TestSet actor
include("Luvvies.jl")

# LuvvyTestSet
include("TestSet.jl")

@testset LuvvyTestSet "TestSet Test" begin
    struct TestSetTest end

    function luvvy.hear(s::Scene{TestSetTest}, ::Genesis!)
        @assert Test.get_testset() isa LuvvyTestSet
        @test true

        say(s, stage(s), Leave!())
    end

    play!(TestSetTest())
end

include("Stack.jl")
include("TypedMessages.jl")
