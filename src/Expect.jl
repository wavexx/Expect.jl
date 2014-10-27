module Expect
export ExpectProc, expect!, write, sendline
export ExpectTimeout, ExpectEOF

## Imports
import Base.Process
import Base.write

@unix_only begin
    import Base.TTY
end


## Types
type ExpectTimeout <: Exception end
type ExpectEOF <: Exception end

type ExpectProc
    proc::Process
    timeout::Real
    in_stream
    out_stream
    before::ByteString
    match
    buffer::ByteString

    function ExpectProc(cmd::Cmd, timeout::Real; env::Base.EnvHash=ENV)
        in_stream, out_stream, proc = _spawn(cmd, env)
        new(proc, timeout, in_stream, out_stream, "", nothing, "")
    end
end


## Support functions
@unix_only begin
    function raw!(tty::TTY, raw::Bool)
        # TODO: raw! does not currently set the correct line discipline
        #       https://github.com/JuliaLang/libuv/pull/27
        ccall(:uv_tty_set_mode, Int32, (Ptr{Void},Int32), tty.handle, int32(raw)) != -1
    end
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
        raw!(ttym, true)

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


# Some helpers
sendline(proc::ExpectProc, line::ByteString) = write(proc, line * "\n")

function write(proc::ExpectProc, str::ByteString)
    write(proc.out_stream, str)
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

function expect!(proc::ExpectProc, vec)
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
        if nb_available(proc.in_stream) == 0 && (!isopen(proc.in_stream) || process_exited(proc.proc))
            throw(ExpectEOF())
        end
        cond = Condition()
        @schedule begin
            proc.buffer = proc.buffer * readavailable(proc.in_stream)
            notify(cond, true)
        end
        @schedule begin
            sleep(proc.timeout)
            notify(cond, false)
        end
        if wait(cond) == false
            throw(ExpectTimeout())
        end
    end
    proc.before = proc.buffer[1:pos[1]-1]
    proc.buffer = proc.buffer[pos[end]+1:end]
    return idx
end

end
