mutable struct Stack{T}
    content::Union{T, Nothing}
    link::Union{Id{Stack{T}}, Nothing}
    forward::Bool
end

Stack{T}() where T = new{T}(nothing, nothing, false)

luvvy.hear(s::Scene{Stack{T}},
           msg::Tuple{Symbol, Union{T, Id}}) where T = if my(s).forward
    say(s, my(s).link, msg)
else
    (type, m) = msg

    if type === :push!
        if isnothing(my(s).content)
            my(s).content = content
        else
            r = ask(stage(s), Enter!(my(s)), Entered!)
            my!(s, Stack(content, r.who, false))
        end
    elseif type === :pop! && !isnothing(my(s).content)
        say(s, m, my(s).content)
        my(s).forward = true
    else
        error("Can't handle $type")
    end
end

@testset LuvvyTestSet "Actors Stack" begin
    function luvvy.hear(s::Scene{Stage}, ::Genesis!)
        stak = enter!(s, Stack{Symbol}())

        delegate(s, stak) do s, stack
            say(s, stack, (:push!, :a))
            @test ask(s, stack, (:pop!, me(s)), Symbol) == :a

            say(s, stack, (:push!, :b))
            @test ask(s, stack, (:pop!, me(s)), Symbol) == :b
        end

        stak = enter!(s, Stack{Int}())

        delegate(s, stak) do s, stack
            for i in 1:5
                say(s, stack, (:push!, i))
            end

            @test ask(s, stack, (:pop!, me(s)), Int) == 5

            say(s, stack, (:push!, 6))
            @test ask(s, stack, (:pop!, me(s)), Int) == 6
            @test ask(s, stack, (:pop!, me(s)), Int) == 4
        end

        say(s, stage(s), Leave!())
    end

    testset_play!()
end
