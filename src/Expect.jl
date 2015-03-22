## Exports
module Expect
export ExpectProc, expect!, sendline
export ExpectTimeout, ExpectEOF

## Support lib
const libttymakeraw = Pkg.dir("Expect", "deps", "libttymakeraw.so")

## Imports
import Base: AsyncStream, Process, TTY, wait_readnb
import Base: eof, read, readbytes!, readuntil, write

## Types
type ExpectTimeout <: Exception end
type ExpectEOF <: Exception end

type ExpectProc <: IO
    proc::Process
    timeout::Real
    codec::Function
    in_stream::AsyncStream
    out_stream::AsyncStream
    before
    match
    buffer::Vector{Uint8}

    function ExpectProc(cmd::Cmd, timeout::Real; env::Base.EnvHash=ENV, codec::Function=utf8)
        in_stream, out_stream, proc = _spawn(cmd, env)
        new(proc, timeout, codec, in_stream, out_stream, "", nothing, "")
    end
end


## Support functions
function raw!(tty::TTY, raw::Bool)
    # TODO: Base.Terminals.raw! does not currently set the correct line discipline
    #       See https://github.com/JuliaLang/libuv/pull/27
    #       We use our custom little hack in order to avoid waiting for libuv.
    ccall((:tty_makeraw, libttymakeraw), Int32, (Ptr{Void}, Int32), tty.handle, Int32(raw))
end

function _spawn(cmd::Cmd, env::Base.EnvHash=ENV)
    @unix? begin
        const O_RDWR = Base.FS.JL_O_RDWR
        const O_NOCTTY = Base.FS.JL_O_NOCTTY

        fdm = RawFD(ccall(:posix_openpt, Cint, (Cint,), O_RDWR|O_NOCTTY))
        fdm == -1 && error("openpt failed: $(strerror())")

        rc = ccall(:grantpt, Cint, (Cint,), fdm)
        rc != 0 && error("grantpt failed: $(strerror())")

        rc = ccall(:unlockpt, Cint, (Cint,), fdm)
        rc != 0 && error("unlockpt failed: $(strerror())")

        pts = ccall(:ptsname, Ptr{Uint8}, (Cint,), fdm)
        fds = RawFD(ccall(:open, Cint, (Ptr{Uint8}, Cint), pts, O_RDWR|O_NOCTTY))
        fds == -1 && error("open failed: $(strerror())")

        ttym = TTY(fdm; readable=true)
        in_stream = out_stream = ttym
        raw!(ttym, true) != 0 && error("raw! failed: $(strerror())")

        env = copy(ENV)
        env["TERM"] = "dumb"

        close_fds = (_...)->ccall(:close, Cint, (Cint,), fds)
        proc = spawn(true, cmd, (fds, fds, fds), close_fds)
    end : begin
        in_stream, out_stream, proc = readandwrite(setenv(cmd, ENV))
    end

    start_reading(in_stream)
    return (in_stream, out_stream, proc)
end


# Base IO functions
eof(proc::ExpectProc) = eof(proc.in_stream)

write(proc::ExpectProc, buf::AbstractArray{Uint8}) = write(proc.out_stream, buf)
write(proc::ExpectProc, buf::Uint8) = write(proc.out_stream, buf)

function read(proc::ExpectProc, ::Type{Uint8})
    proc.buffer = []
    proc.before = nothing
    read(proc.in_stream, Uint8)
end

function readbytes!(proc::ExpectProc, b::AbstractArray{Uint8}, nb=length(b))
    proc.buffer = []
    proc.before = nothing
    readbytes!(proc.in_stream, b, nb)
end

function _readuntil(proc::ExpectProc, delim)
    proc.buffer = []
    proc.before = nothing
    readuntil(proc.in_stream, delim)
end

readuntil(proc::ExpectProc, delim::AbstractArray{Uint8}) = _readuntil(proc, delim)
readuntil(proc::ExpectProc, delim::AbstractString) = _readuntil(proc, delim)
readuntil(proc::ExpectProc, delim::Uint8) = _readuntil(proc, delim)


# Some helpers
sendline(proc::ExpectProc, line::String) = write(proc, string(line, "\n"))


# Expect
function _expect_search(buf::String, str::String)
    pos = search(buf, str)
    return pos == 0:-1? nothing: (buf[pos], pos)
end

function _expect_search(buf::String, regex::Regex)
    m = match(regex, buf)
    return m == nothing? nothing: (m.match, m.offset:(m.offset+length(m.match)-1))
end

function _expect_search(buf::String, vec::Vector)
    for idx=1:length(vec)
        ret = _expect_search(buf, vec[idx])
        if ret != nothing
            return idx, ret[1], ret[2]
        end
    end
    return nothing
end

function expect!(proc::ExpectProc, vec; timeout::Real=proc.timeout)
    pos = 0:-1
    idx = 0
    while true
        if nb_available(proc.in_stream) > 0
            proc.buffer = vcat(proc.buffer, takebuf_array(proc.in_stream.buffer))
        end
        if length(proc.buffer) > 0
            buffer = try proc.codec(proc.buffer) end
            if buffer != nothing
                ret = _expect_search(buffer, vec)
                if ret != nothing
                    idx, proc.match, pos = ret
                    break
                end
            end
        end
        if nb_available(proc.in_stream) == 0 && (!isopen(proc.in_stream) || process_exited(proc.proc))
            throw(ExpectEOF())
        end
        cond = Condition()
        @schedule begin
            wait_readnb(proc.in_stream, 1)
            notify(cond, true)
        end
        @schedule begin
            sleep(timeout)
            notify(cond, false)
        end
        if wait(cond) == false
            throw(ExpectTimeout())
        end
    end
    proc.before = proc.codec(proc.buffer[1:pos[1]-1])
    proc.buffer = proc.buffer[pos[end]+1:end]
    return idx
end

function expect!(proc::ExpectProc, regex::Regex; timeout::Real=proc.timeout)
    expect!(proc, [regex]; timeout=timeout)
    proc.before
end

function expect!(proc::ExpectProc, str::String; timeout::Real=proc.timeout)
    # TODO: this is worth implementing more efficiently
    expect!(proc, [str]; timeout=timeout)
    proc.before
end


end
