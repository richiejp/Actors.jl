using Random
import Actors: AddressBook

@testset "Addressing" begin
    rng = MersenneTwister(33)
    book = AddressBook()

    @test_throws BoundsError book[Id(1)]
    @test book.live[1].readers[] == 0
    @test book.live[2].readers[] == 0
    @test book.flips[] == 0

    null_id = Id(UInt32(0))
    a = Actors.Actor{Any}(1, null_id)
    @test Id(1) == push!(book, a)
    @test book.flips[] == 1
    @test book.live[1].entries[1] == a
    @test book.live[2].entries[1] == a
    @test book[Id(1)] == a

    for a in [Actors.Actor{Any}(i, null_id) for i in 2:1000]
        push!(book, a)
    end

    Threads.@threads for a in [Actors.Actor{Any}(i, null_id) for i in 1:1000]
        push!(book, a)
    end

    @test book.live[1].entries == book.live[2].entries

    filler = Actors.Actor{Any}(:filler, null_id)
    Threads.@threads for i in 1:1000
        i % 100 == 0 && push!(book, filler)
        @assert i == book[Id(i)].state
    end

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
end
