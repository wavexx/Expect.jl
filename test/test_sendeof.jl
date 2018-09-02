include("prelude.jl")

# Ensure sendeof works both with/out a pty

@static if Sys.isunix()
    @testset "pty" begin
        interact(`cat`, 1) do proc
            @require sendeof(proc)

            # A final \n before the EOF is required by the
            # canonical tty processing
            @test read(proc, String) == "\n"

            wait(proc)
            @test success(proc)
        end
    end
end

@testset "nopty" begin
    interact(`cat`, 1; pty=false) do proc
        @require sendeof(proc)
        @test length(read(proc, String)) == 0
        wait(proc)
        @test success(proc)
    end
end
