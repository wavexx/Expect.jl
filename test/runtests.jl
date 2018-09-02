using Test
using Printf

tests = Test.DefaultTestSet("all")
Test.push_testset(tests)

dir = dirname(@__FILE__)
for f in readdir(dir)
    m = match(r"^test_(.*)\.jl$", f)
    fp = joinpath(dir, f)
    if m === nothing || !isfile(fp)
        continue
    end

    name = m.captures[1]
    @printf("%-12s ... ", name)

    ts = Test.DefaultTestSet(name)
    Test.push_testset(ts)
    try
        evalfile(fp)
    catch err
        res = Test.Error(:nontest_error, :(), err, catch_backtrace())
        Test.record(ts, res)
    end
    Test.pop_testset()
    Test.finish(ts)

    # lazy: use get_test_counts to set ts.anynonpass
    Test.get_test_counts(ts)
    ts.anynonpass || println("OK")
end

Test.pop_testset()
Test.finish(tests)
