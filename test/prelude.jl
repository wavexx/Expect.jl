using Expect
using Test
using Compat: readline

# like @test, but stops execution of the testset
macro require(expr)
    quote
        value = $(esc(expr))
        if value
            res = Test.Pass(:test, nothing, nothing, nothing)
            Test.record(Test.get_testset(), res)
        else
            throw(Main.Base.AssertionError(string($(Expr(:inert, expr)))))
        end
    end
end
