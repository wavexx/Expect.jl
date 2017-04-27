include("prelude.jl")

@testset "println" begin
    interact(`cat`, 1) do proc
        println(proc, "hello world")
        @test expect!(proc, "\n") == "hello world"
        @test process_running(proc)
    end
end

@testset "readstring" begin
    interact(`printf 'hello\nworld\n'`, 1) do proc
        @test readstring(proc) == "hello\nworld\n"
        @test eof(proc)
    end
end

@testset "readuntil" begin
    interact(`printf 'hello\nworld\n'`, 1) do proc
        @test readuntil(proc, "\n") == "hello\n"
        @test readuntil(proc, '\n') == "world\n"
        @test eof(proc)
    end
end

@testset "readline" begin
    interact(`printf 'hello\nworld\n'`, 1) do proc
        @test readline(proc) == "hello"
        @test !eof(proc)
    end
end
