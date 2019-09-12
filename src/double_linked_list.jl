mutable struct Cons{T}
    list::List{T}
    next::Union{Cons{T}, Nothing}
    data::T
    prev::Union{Cons{T}, Nothing}
end

mutable struct List{T}
    len::UInt
    first::Union{Cons{T}, Nothing}
    last::Union{Cons{T}, Nothing}
end

List() = List(0, nothing, nothing)

function Base.push!(list::List{T}, data::T) where T
    cons = Cons(list, nothing, data, list.last)

    if list.len === 0
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
Base.iterate(list::List{T}, ::Nothing) = nothing
Base.iterate(list::List{T}, cons::Cons{T}) = if cons.next === nothing
    nothing
else
    (cons.next, cons.next)
end
