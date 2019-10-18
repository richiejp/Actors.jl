mutable struct ListImpl{C}
    len::UInt
    first::Union{C, Nothing}
    last::Union{C, Nothing}
end

mutable struct Cons{T}
    list::ListImpl{Cons{T}}
    next::Union{Cons{T}, Nothing}
    data::T
    prev::Union{Cons{T}, Nothing}
end

ListImpl{C}() where {C<:Cons} = ListImpl{C}(0, nothing, nothing)

const List{T} = ListImpl{Cons{T}}

Base.:(==)(u::List{T}, v::List{T}) where T = all(zip(u, v)) do x, y
    x == y
end

Base.IteratorSize(::Type{List{T}}) where T = Base.SizeUnknown()
Base.eltype(::Type{List{T}}) where T = T

function Base.push!(list::List{T}, data::T) where T
    cons = Cons(list, nothing, data, list.last)

    if list.len == 0
        list.first = cons
    else
        list.last.next = cons
    end

    cons.prev = list.last
    list.last = cons
    list.len += 1

    list
end

function Base.delete!(cons::Cons)
    list = cons.list

    if cons.prev === nothing
        list.first = cons.next
    else
        cons.prev.next = cons.next
    end

    if cons.next === nothing
        list.last = cons.prev
    else
        cons.next.prev = cons.prev
    end

    list.len -= 1

    list
end

Base.iterate(list::List{T}) where T = iterate(list, list.first)
Base.iterate(list::List{T}, ::Nothing) where T = nothing
Base.iterate(list::List{T}, cons::Union{Cons{T}, Nothing}) where T =
    isnothing(cons) ? nothing : (cons, cons.next)
