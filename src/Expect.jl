## Exports
module Expect
export ExpectProc, expect!
export ExpectTimeout, ExpectEOF

## Imports
import Base.Libc: strerror
import Base: Process, TTY, wait_readnb, eof, close
import Base: write, print, println, flush
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

    function ExpectProc(cmd::Cmd, timeout::Real; env::Base.EnvHash=ENV, encoding="utf8")
        # TODO: only utf8 is currently supported
        @assert encoding == "utf8"
        encode = x->transcode(UInt8, x)
        decode = x->transcode(String, x)

        in_stream, out_stream, proc = _spawn(cmd, env)
        new(proc, timeout, encode, decode,
            in_stream, out_stream,
            nothing, nothing, [])
    end
end


## Support functions
function raw!(tty::TTY, raw::Bool)
    # UV_TTY_MODE_IO (cfmakeraw) is only available with libuv 1.0 and not directly
    # supported by jl_tty_set_mode (JL_TTY_MODE_RAW still performs NL conversion)
    const UV_TTY_MODE_IO = 2
    mode = raw? UV_TTY_MODE_IO: 0
    ret = ccall(:uv_tty_set_mode, Cint, (Ptr{Void},Cint), tty.handle, mode)
    ret == 0
end


function _spawn(cmd::Cmd, env::Base.EnvHash=ENV)
    env = copy(ENV)
    env["TERM"] = "dumb"
    setenv(cmd, env)
    detach(cmd)

    @static is_unix()? begin
        const O_RDWR = Base.Filesystem.JL_O_RDWR
        const O_NOCTTY = Base.Filesystem.JL_O_NOCTTY

        fdm = RawFD(ccall(:posix_openpt, Cint, (Cint,), O_RDWR|O_NOCTTY))
        fdm == -1 && error("openpt failed: $(strerror())")
        ttym = TTY(fdm; readable=true)
        in_stream = out_stream = ttym
        raw!(ttym, true) || error("raw! failed: $(strerror())")

        rc = ccall(:grantpt, Cint, (Cint,), fdm)
        rc != 0 && error("grantpt failed: $(strerror())")

        rc = ccall(:unlockpt, Cint, (Cint,), fdm)
        rc != 0 && error("unlockpt failed: $(strerror())")

        pts = ccall(:ptsname, Ptr{UInt8}, (Cint,), fdm)
        pts == C_NULL && error("ptsname failed: $(strerror())")

        fds = RawFD(ccall(:open, Cint, (Ptr{UInt8}, Cint), pts, O_RDWR|O_NOCTTY))
        fds == -1 && error("open failed: $(strerror())")

        proc = nothing
        try
            proc = spawn(cmd, (fds, fds, fds))
            @schedule begin
                # ensure the descriptors get closed
                wait(proc)
                ccall(:close, Cint, (Cint,), fds)
                close(ttym)
            end
        catch ex
            ccall(:close, Cint, (Cint,), fds)
            rethrow(ex)
        end
    end : begin
        in_stream, out_stream, proc = readandwrite(cmd)
    end

    # always read asyncronously
    Base.start_reading(in_stream)
    return (in_stream, out_stream, proc)
end



# Base IO functions
eof(proc::ExpectProc) = eof(proc.in_stream)
flush(proc::ExpectProc) = flush(proc.out_stream)
close(proc::ExpectProc) = close(proc.out_stream)

write(proc::ExpectProc, buf::Vector{UInt8}) = write(proc.out_stream, buf)
write(proc::ExpectProc, buf::String) = write(proc, proc.encode(buf))
print(proc::ExpectProc, x::String) = write(proc, x)
println(proc::ExpectProc, x::String) = write(proc, string(x, "\n"))

function read(proc::ExpectProc, ::Type{UInt8})
    proc.buffer = []
    proc.before = nothing
    read(proc.in_stream, UInt8)
end

function readbytes!(proc::ExpectProc, b::AbstractVector{UInt8}, nb=length(b))
    proc.buffer = []
    proc.before = nothing
    readbytes!(proc.in_stream, b, nb)
end

function readuntil(proc::ExpectProc, delim::AbstractString)
    proc.buffer = []
    proc.before = nothing
    readuntil(proc.in_stream, delim)
end

function readavailable(proc::ExpectProc)
    proc.buffer = []
    proc.before = nothing
    readavailable(proc.in_stream)
end


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
            proc.buffer = vcat(proc.buffer, take!(proc.in_stream.buffer))
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
