using Expect
using Base.Test

# Test simple matches
proc = ExpectProc(`printf 'hello\nworld\n'`, 1)
@test expect!(proc, "\n") == "hello"
@test expect!(proc, r"\n") == "world"

# Test match/before
proc = ExpectProc(`printf 'a\nbB'`, 1)
@test expect!(proc, [r"[AB]"]) == 1
@test proc.match == "B"
@test proc.before == "a\nb"
@test_throws ExpectEOF expect!(proc, ["test"]) == 2

# Asyncronous I/O
proc = ExpectProc(`cat`, 1)
write(proc, "hello\nworld\n")
@test expect!(proc, ["hello\n", "world\n"]) == 1
@test expect!(proc, ["hello\n", "world\n"]) == 2
@test_throws ExpectTimeout expect!(proc, ["test"])

# Test IO interface
proc = ExpectProc(`printf 'hello\nworld\n'`, 1)
@test readall(proc) == "hello\nworld\n"
@test eof(proc)

proc = ExpectProc(`printf 'hello\nworld\n'`, 1)
@test readuntil(proc, "\n") == "hello\n"
@test readuntil(proc, '\n') == "world\n"
@test eof(proc)

proc = ExpectProc(`printf 'hello\nworld\n'`, 1)
@test ascii(readbytes(proc, 5)) == "hello"
@test !eof(proc)
