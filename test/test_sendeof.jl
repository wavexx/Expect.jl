include("prelude.jl")

@static if is_unix()
    @testset "pty" begin
        interact(`cat`, 1) do proc
            @require sendeof(proc)
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
