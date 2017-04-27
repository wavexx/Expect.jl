using Expect
using Base.Test
using Compat: readline

# like @test, but stops execution of the testset
macro require(expr)
    quote
        value = $(esc(expr))
        if value
            res = Base.Test.Pass(:test, nothing, nothing, nothing)
            Base.Test.record(Base.Test.get_testset(), res)
        else
            throw(Main.Base.AssertionError(string($(Expr(:inert, expr)))))
        end
    end
end
