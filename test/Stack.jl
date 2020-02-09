struct StackPlay end

mutable struct Stack{T}
    content::Union{T, Nothing}
    link::Union{Id{Stack{T}}, Nothing}
end

Stack{T}() where T = Stack{T}(nothing, nothing)

function hear(s::Scene{Stack{T}}, msg::Tuple{Symbol, Union{Id, T}}) where T
    (type, m) = msg

    if type === :push!
        if !isnothing(my(s).content)
            my(s).link = invite!(s, Stack(my(s).content, nothing))
        end

        my(s).content = m
    elseif type === :pop! && !isnothing(my(s).content)
        say(s, m, my(s).content)
        my(s).content = nothing

        isnothing(my(s).link) || forward!(s, my(s).link)
    else
        error("Can't handle $type")
    end
end

function hear(s::Scene{StackPlay}, ::Genesis!)
    stack = invite!(s, Stack{Symbol}())

    say(s, stack, (:push!, :a))
    @test ask(s, stack, (:pop!, me(s)), Symbol) == :a

    say(s, stack, (:push!, :b))
    @test ask(s, stack, (:pop!, me(s)), Symbol) == :b


    stack = invite!(s, Stack{Int}())

    for i in 1:5
        say(s, stack, (:push!, i))
    end

    @test ask(s, stack, (:pop!, me(s)), Int) == 5

    say(s, stack, (:push!, 6))
    @test ask(s, stack, (:pop!, me(s)), Int) == 6
    @test ask(s, stack, (:pop!, me(s)), Int) == 4

    leave!(s)
end

@testset LuvvyTestSet "Actors Stack" begin
    play!(StackPlay())
end
