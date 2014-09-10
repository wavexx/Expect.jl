using Expect
using Base.Test

proc = ExpectProc("printf 'a\\nb'; echo B", 1)
ret = expect(proc, [r"[AB]"])
println(proc)
