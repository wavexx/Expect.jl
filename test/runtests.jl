using Expect
using Base.Test
using Compat: readline

# Test simple matches
proc = ExpectProc(`printf 'hello\nworld\n'`, 1)
@test expect!(proc, "\n") == "hello"
@test expect!(proc, "\n") == "world"

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
close(proc)
wait(proc)

# print/println
proc = ExpectProc(`cat`, 1)
println(proc, "hello world")
@test expect!(proc, "\n") == "hello world"
@test process_running(proc)
close(proc)
wait(proc)

# Test IO interface
proc = ExpectProc(`printf 'hello\nworld\n'`, 1)
@test readstring(proc) == "hello\nworld\n"
@test eof(proc)

proc = ExpectProc(`printf 'hello\nworld\n'`, 1)
@test readuntil(proc, "\n") == "hello\n"
@test readuntil(proc, '\n') == "world\n"
@test eof(proc)

proc = ExpectProc(`printf 'hello\nworld\n'`, 1)
@test readline(proc) == "hello"
@test !eof(proc)

# Test with pty=false
proc = ExpectProc(`cat`, 1; pty=false)
@test typeof(proc.out_stream) <: Pipe
@test process_running(proc)
close(proc)
wait(proc)
