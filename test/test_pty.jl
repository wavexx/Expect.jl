include("prelude.jl")

@testset "default_pty" begin
    interact(`cat`, 1) do proc
        @static if is_unix()
            @test typeof(proc.out_stream) <: Expect.TTY
        else
            @test typeof(proc.out_stream) <: Base.PipeEndpoint
        end
    end
end

@testset "8bit_pty" begin
    interact(`cat`, 1) do proc
        # Ensure the transport is already 8bit safe
        buf = [UInt8(i) for i in 0:255]
        write(proc, buf)
        ret = Vector{UInt8}(length(buf))
        readbytes!(proc, ret)
        @test buf == ret
    end
end

@testset "nop_raw!" begin
    interact(`cat`, 1) do proc
        # raw! is unnecessary (it's toggled during construction), but it should be a
        # no-op on windows for compatibility
        @test Expect.raw!(proc, true)
        @test process_running(proc)
    end
end

@testset "no_pty" begin
    # Test with pty=false
    interact(`cat`, 1; pty=false) do proc
        @test typeof(proc.out_stream) <: Base.PipeEndpoint

        # raw should always succeed on pipes/windows
        @test raw!(proc, true)

        # switching off raw without a pty should fail
        @test !raw!(proc, false)

        @test process_running(proc)
    end
end
