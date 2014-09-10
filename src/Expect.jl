module Expect
export ExpectProc, expect, write, sendline
export ExpectTimeout, ExpectEOF

## Imports
import Base.write
import Base.TTY
import Base.Terminals.TTYTerminal
import Base.Terminals.raw!

## Types
type ExpectTimeout <: Exception end
type ExpectEOF <: Exception end

type ExpectProc
    pid::Cint
    timeout::Real
    term::TTYTerminal
    before::ByteString
    match
    buffer::ByteString

    function ExpectProc(cmd::String, timeout::Real; env::Base.EnvHash=ENV)
        pid, term = spawn(cmd, env)
        new(pid, timeout, term, "", nothing, "")
    end
end


## Support functions
function spawn(cmd::String, env::Base.EnvHash=ENV)
    amaster = Cint[0]
    env = convert(Array{String}, ["$key=$(env[key])" for key=keys(env)])
    pid = ccall((:forkpty, "libutil"), Cint,
                (Ptr{Cint}, Ptr{Uint8}, Ptr{Void}, Ptr{Void}),
                amaster, C_NULL, C_NULL, C_NULL)
    if pid == -1
        throw(SystemError("forkpty failure: $(strerror())"))
    elseif pid == 0
        ret = ccall((:execvpe, "libc"), Cint,
                    (Ptr{Uint8}, Ptr{Ptr{Uint8}}, Ptr{Ptr{Uint8}}),
                    # TODO: stty can be avoided if raw! works correctly
                    "/bin/sh", ["/bin/sh", "-c", "stty raw; " * cmd], env)
        # just calling exit here is not safe
        ccall((:_exit, "libc"), Void, (Cint,), ret)
    end

    fd = RawFD(amaster[1])
    in_stream = TTY(fd, readable=true)
    out_stream = TTY(Base.dup(fd), readable=false)
    term = TTYTerminal("dumb", in_stream, out_stream, out_stream)
    # TODO: raw! appears to do nothing?
    raw!(term, true)

    return (pid, term)
end


# Some helpers
sendline(proc::ExpectProc, line::ByteString) = write(proc, line * "\n")

function write(proc::ExpectProc, str::ByteString)
    start_reading(proc.term.in_stream)
    write(proc.term.out_stream, str)
end


# Expect
function _expect_search(buf::ByteString, str::String)
    pos = search(buf, str)
    return pos == 0:-1? nothing: (buf[pos], pos)
end

function _expect_search(buf::ByteString, regex::Regex)
    m = match(regex, buf)
    return m == nothing? nothing: (m.match, m.offset:(m.offset+length(m.match)-1))
end

function _expect_search(buf::ByteString, vec::Vector)
    for idx=[1:length(vec)]
        ret = _expect_search(buf, vec[idx])
        if ret != nothing
            return idx, ret[1], ret[2]
        end
    end
    return nothing
end

function expect(proc::ExpectProc, vec)
    pos = 0:-1
    idx = 0
    while true
        if length(proc.buffer) > 0
            ret = _expect_search(proc.buffer, vec)
            if ret != nothing
                idx, proc.match, pos = ret
                break
            end
        end
        if !isopen(proc.term.in_stream) && nb_available(proc.term.in_stream) == 0
            throw(ExpectEOF())
        end
        cond = Condition()
        @schedule begin
            proc.buffer = proc.buffer * readavailable(proc.term.in_stream)
            notify(cond, true)
        end
        @schedule begin
            sleep(proc.timeout)
            notify(cond, false)
        end
        ret = wait(cond)
        if ret == false
            throw(ExpectTimeout())
        end
    end
    proc.before = proc.buffer[1:pos[1]-1]
    proc.buffer = proc.buffer[pos[end]+1:end]
    return idx
end

end
