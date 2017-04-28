include("prelude.jl")

# Ensure the output buffer can be drained after closing the input and/or after
# the program exists. For this, we use a large buffer in order to delay any
# pending read long enough to trigger potential issues
BUFSIZE = 1024*128

# TODO: both tests have issues

#=
@testset "pty" begin
    interact(`cat`, 1) do proc
        buf = " " ^ BUFSIZE
        print(proc, buf)
        sendeof(proc)
        wait(proc)

        # we intentionally ignore anything after the newline
        tmp = readline(proc)
        @test length(tmp) == BUFSIZE
        @test success(proc)
    end
end


@testset "nopty" begin
    interact(`cat`, 1; pty=false) do proc
        buf = " " ^ BUFSIZE
        print(proc, buf)
        sendeof(proc)
        wait(proc)

        # we intentionally ignore anything after the newline
        tmp = readline(proc)
        @test length(tmp) == BUFSIZE
        @test success(proc)
    end
end
=#
