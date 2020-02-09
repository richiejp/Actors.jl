struct AddressTable
    readers::Threads.Atomic{UInt}
    entries::Vector{Union{Actor, Nothing}}
    rev_entries::IdDict{Actor, Set{UInt32}}
end

AddressTable() = AddressTable(Threads.Atomic{UInt}(), [], IdDict{Actor, Set{UInt32}}())

struct AddressBook
    write_lock::ReentrantLock
    flips::Threads.Atomic{UInt}
    live::NTuple{2, AddressTable}
end

AddressBook() = AddressBook(ReentrantLock(), Threads.Atomic{UInt}(),
                            (AddressTable(), AddressTable()))

atomic_inc!(atom::Threads.Atomic{T}) where T = Threads.atomic_add!(atom, T(1))
atomic_dec!(atom::Threads.Atomic{T}) where T = Threads.atomic_sub!(atom, T(1))

function read_lock(fn::Function, book::AddressBook)
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
        fn(book.live[flop])
    finally
        atomic_dec!(book.live[flop].readers)
    end
end

Base.getindex(book::AddressBook, id::Id) = getindex(book, id.inner)
function Base.getindex(book::AddressBook, id::Integer)
    a = read_lock(book) do table
        table.entries[id]
    end

    a === nothing && throw(KeyError(id))

    a
end

Base.getindex(book::AddressBook, a::Actor) = read_lock(book) do table
    collect(table.rev_entries[a])
end

Base.isempty(book::AddressBook) = read_lock(book) do table
    isempty(table.rev_entries)
end

Base.lastindex(book::AddressBook) = read_lock(book) do table
    lastindex(table.entries)
end

Base.iterate(book::AddressBook, state=1) = try
    (book[state], state + 1)
catch ex
    ex isa BoundsError || rethrow()

    nothing
end

Base.length(book::AddressBook) = read_lock(book) do table
    length(table.entries)
end

function write_lock(fn::Function, book::AddressBook)
    retries = 11
    retry = 0

    lock(book.write_lock)
    try
        table = book.live[2 - book.flips[] % 2]

        @assert table.readers[] == 0 "Previous flip should have drained readers"

        fn(table)

        table = book.live[2 - (atomic_inc!(book.flips) + 1) % 2]

        while table.readers[] > 0
            @assert retry < retries "Waited a long time to drain readers: $(table.readers[])"
            sleep(2^retry * 0.0001)
            retry += 1
        end

        fn(table)
    finally
        unlock(book.write_lock)
    end
end

Base.push!(book::AddressBook, a::Actor{S, M}) where {S, M} = write_lock(book) do table
    i = lastindex(table.entries) + 1

    @assert i < typemax(UInt32) "Can't add actor, no local addresses left"

    push!(table.entries, a)

    # For some reason get!() was behaving like get()
    rev_entries = get(Set, table.rev_entries, a)
    push!(rev_entries, UInt32(i))
    table.rev_entries[a] = rev_entries

    Id{S, M}(UInt32(i))
end

Base.setindex!(book::AddressBook, ::Nothing, id::Id) = write_lock(book) do table
    old_a = table.entries[id.inner]

    rentries = delete!(table.rev_entries[old_a], id.inner)
    isempty(rentries) && delete!(table.rev_entries, old_a)

    table.entries[id.inner] = nothing
end

Base.setindex!(book::AddressBook, a::Actor, id::Id) = write_lock(book) do table
    old_a = table.entries[id.inner]

    rentries = delete!(table.rev_entries[old_a], id.inner)
    isempty(rentries) && delete!(table.rev_entries, old_a)

    table.entries[id.inner] = a

    rev_entries = get(Set, table.rev_entries, a)
    push!(rev_entries, id.inner)
    table.rev_entries[a] = rev_entries

    id
end
