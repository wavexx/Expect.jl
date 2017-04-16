## Exports
module Expect
export ExpectProc, expect!
export ExpectTimeout, ExpectEOF

## Imports
import Base.Libc: strerror
import Base: Process, TTY, wait, wait_readnb
import Base: kill, process_running, process_exited
import Base: write, print, println, flush, eof, close
import Base: read, readbytes!, readuntil, readavailable

## Types
type ExpectTimeout <: Exception end
type ExpectEOF <: Exception end

type ExpectProc <: IO
    proc::Process
    timeout::Real
    encode::Function
    decode::Function
    in_stream::IO
    out_stream::IO
    before
    match
    buffer::Vector{UInt8}

    function ExpectProc(cmd::Cmd, timeout::Real; env::Base.EnvHash=ENV, encoding="utf8", pty=true)
        # TODO: only utf8 is currently supported
        @assert encoding == "utf8"
        encode = x->transcode(UInt8, x)
        decode = x->transcode(String, x)

        in_stream, out_stream, proc = _spawn(cmd, env, pty)
        new(proc, timeout, encode, decode,
            in_stream, out_stream,
            nothing, nothing, [])
    end
end


## Support functions
function raw!(tty::TTY, raw::Bool)
    # UV_TTY_MODE_IO (cfmakeraw) is only available with libuv 1.0 and not
    # directly supported by jl_tty_set_mode (JL_TTY_MODE_RAW still performs NL
    # conversion).
    const UV_TTY_MODE_NORMAL = 0
    const UV_TTY_MODE_IO = 2
    mode = raw? UV_TTY_MODE_IO: UV_TTY_MODE_NORMAL
    ret = ccall(:uv_tty_set_mode, Cint, (Ptr{Void},Cint), tty.handle, mode)
    ret == 0
end

function raw!(proc::ExpectProc, raw::Bool)
    @static if VERSION < v"0.7"
        # libuv keeps an internal "mode" state which prevents us to call
        # cfmakeraw() again, even if the connected slave changed the discipline
        # on our back. Work this around by toggling the mode twice.
        # See: https://github.com/libuv/libuv/issues/1292
        # TODO: determine valid VERSION when fix gets merged
        raw!(proc.out_stream, !raw)
    end
    raw!(proc.out_stream, raw)
end


function _spawn(cmd::Cmd, env::Base.EnvHash, pty::Bool)
    env = copy(ENV)
    env["TERM"] = "dumb"
    setenv(cmd, env)

    if pty && is_unix()
        const O_RDWR = Base.Filesystem.JL_O_RDWR
        const O_NOCTTY = Base.Filesystem.JL_O_NOCTTY
        const F_SETFD = 2
        const FD_CLOEXEC = 1

        fdm = RawFD(ccall(:posix_openpt, Cint, (Cint,), O_RDWR|O_NOCTTY))
        fdm == RawFD(-1) && error("openpt failed: $(strerror())")
        ttym = TTY(fdm; readable=true)
        in_stream = out_stream = ttym

        rc = ccall(:fcntl, Cint, (Cint,Cint,Cint), fdm, F_SETFD, FD_CLOEXEC)
        rc != 0 && error("fcntl failed: $(strerror())")

        rc = ccall(:grantpt, Cint, (Cint,), fdm)
        rc != 0 && error("grantpt failed: $(strerror())")

        rc = ccall(:unlockpt, Cint, (Cint,), fdm)
        rc != 0 && error("unlockpt failed: $(strerror())")

        pts = ccall(:ptsname, Ptr{UInt8}, (Cint,), fdm)
        pts == C_NULL && error("ptsname failed: $(strerror())")

        fds = RawFD(ccall(:open, Cint, (Ptr{UInt8}, Cint), pts, O_RDWR|O_NOCTTY))
        fds == RawFD(-1) && error("open failed: $(strerror())")
        raw!(out_stream, true) || error("raw! failed: $(strerror())")

        proc = nothing
        try
            proc = spawn(cmd, (fds, fds, fds))
            Base.start_reading(in_stream)
        catch ex
            close(out_stream)
            rethrow(ex)
        finally
            ccall(:close, Cint, (Cint,), fds)
        end
    else
        in_stream, out_stream, proc = readandwrite(cmd)
        Base.start_reading(Base.pipe_reader(in_stream))
    end

    return (in_stream, out_stream, proc)
end



# Base IO functions
eof(proc::ExpectProc) = eof(proc.in_stream)
flush(proc::ExpectProc) = flush(proc.out_stream)
close(proc::ExpectProc) = close(proc.out_stream)

kill(proc::ExpectProc, signum::Integer=15) = kill(proc.proc, signum)
wait(proc::ExpectProc) = wait(proc.proc)
process_running(proc::ExpectProc) = process_running(proc.proc)
process_exited(proc::ExpectProc) = process_exited(proc.proc)

write(proc::ExpectProc, buf::Vector{UInt8}) = write(proc.out_stream, buf)
write(proc::ExpectProc, buf::String) = write(proc, proc.encode(buf))
print(proc::ExpectProc, x::String) = write(proc, x)
println(proc::ExpectProc, x::String) = write(proc, string(x, "\n"))

read(proc::ExpectProc, ::Type{UInt8}) = read(proc.in_stream, UInt8)
readbytes!(proc::ExpectProc, b::AbstractVector{UInt8}, nb=length(b)) = readbytes!(proc.in_stream, b, nb)
readuntil(proc::ExpectProc, delim::AbstractString) = readuntil(proc.in_stream, delim)
readavailable(proc::ExpectProc) = readavailable(proc.in_stream)


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
            proc.buffer = vcat(proc.buffer, readavailable(proc.in_stream))
        end
        if length(proc.buffer) > 0
            buffer = try proc.decode(proc.buffer) end
            if buffer != nothing
                ret = _expect_search(buffer, vec)
                if ret != nothing
                    idx, proc.match, pos = ret
                    break
                end
            end
        end
        if !isopen(proc.in_stream)
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
    proc.before = proc.decode(proc.buffer[1:pos[1]-1])
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
