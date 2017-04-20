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

# Test pty support
proc = ExpectProc(`cat`, 1)
@static if is_unix()
    @test typeof(proc.out_stream) <: Expect.TTY
else
    @test typeof(proc.out_stream) <: Pipe
end

# Ensure the transport is already 8bit safe
buf = [UInt8(i) for i in 0:255]
write(proc, buf)
ret = Vector{UInt8}(length(buf))
readbytes!(proc, ret)
@test buf == ret

# raw! is unnecessary (it's toggled during construction), but it should be a
# no-op on windows for compatibility
@test Expect.raw!(proc, true)

# Check that all reading function emit an ExpectTimeout exception
@test_throws ExpectTimeout read(proc, UInt8)
@test_throws ExpectTimeout readbytes!(proc, Vector{UInt8}(1))
@test_throws ExpectTimeout readuntil(proc, '\n')
@test_throws ExpectTimeout Expect.wait_readnb(proc, 1)
@test_throws ExpectTimeout readstring(proc)
@test_throws ExpectTimeout readline(proc)

@test process_running(proc)
close(proc)
wait(proc)

# Test with pty=false
proc = ExpectProc(`cat`, 1; pty=false)
@test typeof(proc.out_stream) <: Pipe
@test process_running(proc)
close(proc)
wait(proc)
