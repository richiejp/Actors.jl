struct StackPlay end

mutable struct Stack{T}
    content::Union{T, Nothing}
    link::Union{Id{Stack{T}}, Nothing}
    forward::Bool
end

Stack{T}() where T = Stack{T}(nothing, nothing, false)

hear(s::Scene{Stack{T}}, msg::Tuple{Symbol, Union{T, Id}}) where T =
    if my(s).forward
        say(s, my(s).link, msg)
    else
        (type, m) = msg

        if type === :push!
            if !isnothing(my(s).content)
                my(s).link = enter!(s, Stack(my(s).content, nothing, false))
            end

            my(s).content = m
        elseif type === :pop! && !isnothing(my(s).content)
            say(s, m, my(s).content)
            my(s).content = nothing

            if !isnothing(my(s).link)
                my(s).forward = true
            end
        else
            error("Can't handle $type")
        end
    end

function hear(s::Scene{StackPlay}, ::Genesis!)
    stack = enter!(s, Stack{Symbol}())

    say(s, stack, (:push!, :a))
    @test ask(s, stack, (:pop!, me(s)), Symbol) == :a

    say(s, stack, (:push!, :b))
    @test ask(s, stack, (:pop!, me(s)), Symbol) == :b


    stack = enter!(s, Stack{Int}())

    for i in 1:5
        say(s, stack, (:push!, i))
    end

    @test ask(s, stack, (:pop!, me(s)), Int) == 5

    say(s, stack, (:push!, 6))
    @test ask(s, stack, (:pop!, me(s)), Int) == 6
    @test ask(s, stack, (:pop!, me(s)), Int) == 4

    say(s, stage(s), Leave!())
end

@testset LuvvyTestSet "Actors Stack" begin
    play!(StackPlay())
end
