using Test
using Actors
import Actors: hear

# We really want to test with true concurrency. Even if we are only running in
# a VM with one vCPU (i.e. Gitlab CI), we are more likely to see errors with
# atleast two OS threads. Unfortunately Julia limits the number of threads to
# the CPU count though.
if Sys.CPU_THREADS > 1
    @assert Threads.nthreads() > 1 "Set environment variable JULIA_NUM_THREADS to > 1"
else
    @warn "Only testing with one thread"
end

include("TestSet.jl")
include("addressing.jl")

"Our Play"
struct HelloWorld
    chnl::Channel
end

"Our Actor"
struct Julia end

"Our Message"
struct HelloWorld!
    chnl::Channel
end

function hear(s::Scene{A}, msg::HelloWorld!) where A
    put!(msg.chnl, "Hello, World! I am $(A)!")
    say(s, stage(s), Leave!())
end

function hear(s::Scene{HelloWorld}, ::Genesis!)
    julia = invite!(s, Julia())
    say(s, julia, HelloWorld!(my(s).chnl))
end

struct TestSetTest end

function hear(s::Scene{TestSetTest}, ::Genesis!)
    @assert Test.get_testset() isa LuvvyTestSet
    @test true

    say(s, stage(s), Leave!())
end

# Running the tests asynchronously without properly interleaving the results
# creates messy output
@sync begin
    @async @testset "Hello, World!" begin
        p = HelloWorld(Channel(1))

        play!(p)
        @test take!(p.chnl) == "Hello, World! I am Julia!"
        close(p.chnl)
    end

    @async include("Minders.jl")
    @async include("Logger.jl")

    @async @testset LuvvyTestSet expect=1 "TestSet Test" begin
        play!(TestSetTest())
    end

    @async include("Async.jl")
    @async include("Luvvies.jl")
    @async include("Stack.jl")
    @async include("TypedMessages.jl")
end
