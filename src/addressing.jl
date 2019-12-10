struct AddressTable
    readers::Threads.Atomic{UInt}
    entries::Vector{Union{Actor, Nothing}}
end

AddressTable() = AddressTable(Threads.Atomic{UInt}(), [])

struct AddressBook
    write_lock::ReentrantLock
    flips::Threads.Atomic{UInt}
    live::NTuple{2, AddressTable}
end

AddressBook() = AddressBook(ReentrantLock(), Threads.Atomic{UInt}(),
                            (AddressTable(), AddressTable()))

atomic_inc!(atom::Threads.Atomic{T}) where T = Threads.atomic_add!(atom, T(1))
atomic_dec!(atom::Threads.Atomic{T}) where T = Threads.atomic_sub!(atom, T(1))

function Base.getindex(book::AddressBook, id::Id)
    retry = 100
    flips = 0
    flop = 0

    while retry > 0
        flips = book.flips[]
        flop = flips % 2 + 1
        atomic_inc!(book.live[flop].readers)
        flips == book.flips[] && break

        atomic_dec!(book.live[flop].readers)
        retry -= 1
    end

    retry > 0 || error("Could not do address lookup due to contention")

    try
        book.live[flop].entries[id.inner]
    finally
        atomic_dec!(book.live[flop].readers)
    end
end

function Base.push!(book::AddressBook, a::Actor)
    retry = 4096

    lock(book.write_lock)
    try
        flop = 2 - book.flips[] % 2
        i = lastindex(book.live[flop].entries) + 1

        @assert i < typemax(UInt32) "Can't add actor, no local addresses left"
        @assert book.live[flop].readers[] == 0 "Previous flip should have drained readers"
        push!(book.live[flop].entries, a)

        flop = 2 - (atomic_inc!(book.flips) + 1) % 2

        while retry > 0
            book.live[flop].readers[] < 1 && break
            retry -= 1
        end

        retry > 0 || error("Gave up while waiting for readers to drain!")

        push!(book.live[flop].entries, a)

        Id(UInt32(i))
    finally
        unlock(book.write_lock)
    end
end

function Base.setindex!(book::AddressBook, a::Union{Actor, Nothing}, id::Id)
    retry = 4096

    lock(book.write_lock)
    try
        flop = 2 - book.flips[] % 2
        old_a = book.live[flop].entries[id.inner]

        @assert book.live[flop].readers[] == 0 "Previous flip should have drained readers"
        book.live[flop].entries[id.inner] = a

        flop = 2 - (atomic_inc!(book.flips) + 1) % 2

        while retry > 0
            book.live[flop].readers[] < 1 && break
            retry -= 1
        end

        if retry < 0
            book.live[flop % 2 + 1].entries[id.inner] = old_a
            error("Gave up while waiting for readers to drain!")
        end

        book.live[flop].entries[id.inner] = a

        a
    finally
        unlock(book.write_lock)
    end
end
