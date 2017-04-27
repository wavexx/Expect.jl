using Base.Test

tests = Base.Test.DefaultTestSet("all")
Base.Test.push_testset(tests)

dir = dirname(@__FILE__)
for f in readdir(dir)
    m = match(r"^test_(.*)\.jl$", f)
    fp = joinpath(dir, f)
    if m === nothing || !isfile(fp)
        continue
    end

    name = m.captures[1]
    @printf("%-12s ... ", name)

    ts = Base.Test.DefaultTestSet(name)
    Base.Test.push_testset(ts)
    try
        evalfile(fp)
    catch err
        res = Base.Test.Error(:nontest_error, :(), err, catch_backtrace())
        Base.Test.record(ts, res)
    end
    Base.Test.pop_testset()
    Base.Test.finish(ts)

    # lazy: use get_test_counts to set ts.anynonpass
    Base.Test.get_test_counts(ts)
    ts.anynonpass || println("OK")
end

Base.Test.pop_testset()
Base.Test.finish(tests)
