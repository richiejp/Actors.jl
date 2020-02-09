using Random
import Actors: Actor, AddressBook

@testset "Addressing" begin
    null_id = Id(UInt32(0))
    test_actor(state) = Actor(Channel{Any}(), state, null_id)
    rng = MersenneTwister(33)
    book = AddressBook()

    @test_throws BoundsError book[Id(1)]
    @test book.live[1].readers[] == 0
    @test book.live[2].readers[] == 0
    @test book.flips[] == 0
    @test isempty(book)

    a = test_actor(1)
    @test Id(1) == push!(book, a)
    @test book.flips[] == 1
    @test book.live[1].entries[1] == a
    @test book.live[2].entries[1] == a
    @test book[Id(1)] == a
    @test book[a] == [UInt32(1)]
    @test !isempty(book)

    for a in [test_actor(i) for i in 2:1000]
        push!(book, a)
    end

    Threads.@threads for a in [test_actor(i) for i in 1:1000]
        push!(book, a)
    end

    @test book.live[1].entries == book.live[2].entries

    filler = test_actor(:filler)
    Threads.@threads for i in 1:1000
        i % 100 == 0 && push!(book, filler)
        @assert i == book[Id(i)].state
    end

    Threads.@threads for i in 1:lastindex(book)
        a = book[Id(i)]
        if a.state === :filler
            book[Id(i)] = nothing
        end
    end

    @test_throws KeyError book[filler]
    @test book.live[1].entries == book.live[2].entries
    @test book.live[1].readers[] == 0
    @test book.live[2].readers[] == 0

    Threads.@threads for i in rand(rng, 1:2000, 10000)
        if i % 100 == 0
            book[Id(i)] = filler
        end
        @assert book[Id(i)].state != nothing
    end

    @test book.live[1].entries == book.live[2].entries
    @test book.live[1].readers[] == 0
    @test book.live[2].readers[] == 0

    book[Id(1)] = nothing
    @test_throws KeyError book[Id(1)]
end
