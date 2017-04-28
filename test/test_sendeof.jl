include("prelude.jl")

# Ensure sendeof works both with/out a pty

@static if is_unix()
    @testset "pty" begin
        interact(`cat`, 1) do proc
            @require sendeof(proc)

            # A final \n before the EOF is required by the
            # canonical tty processing
            @test readstring(proc) == "\n"

            wait(proc)
            @test success(proc)
        end
    end
end

@testset "nopty" begin
    interact(`cat`, 1; pty=false) do proc
        @require sendeof(proc)
        @test length(readstring(proc)) == 0
        wait(proc)
        @test success(proc)
    end
end
