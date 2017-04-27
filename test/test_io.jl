include("prelude.jl")

@testset "println" begin
    interact(`cat`, 1) do proc
        println(proc, "hello world")
        @require expect!(proc, "\n") == "hello world"
        @require process_running(proc)
    end
end

@testset "readstring" begin
    interact(`printf 'hello\nworld\n'`, 1) do proc
        @require readstring(proc) == "hello\nworld\n"
        @require eof(proc)
    end
end

@testset "readuntil" begin
    interact(`printf 'hello\nworld\n'`, 1) do proc
        @require readuntil(proc, "\n") == "hello\n"
        @require readuntil(proc, '\n') == "world\n"
        @require eof(proc)
    end
end

@testset "readline" begin
    interact(`printf 'hello\nworld\n'`, 1) do proc
        @require readline(proc) == "hello"
        @require !eof(proc)
    end
end
