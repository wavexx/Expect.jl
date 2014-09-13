using Expect
using Base.Test

proc = ExpectProc("printf 'a\\nb'; echo B", 1)
@test expect!(proc, [r"[AB]"]) == 1
@test proc.match == "B"
@test proc.before == "a\nb"
@test_throws ExpectEOF expect!(proc, ["test"]) == 2

proc = ExpectProc("cat", 1)
write(proc, "hello\nworld\n")
@test expect!(proc, ["hello\n", "world\n"]) == 1
@test expect!(proc, ["hello\n", "world\n"]) == 2
@test_throws ExpectTimeout expect!(proc, ["test"])
