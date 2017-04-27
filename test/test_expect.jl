include("prelude.jl")

# Test simple matches
@testset "simple" begin
    interact(`printf 'hello\nworld\n'`, 1) do proc
        @require expect!(proc, "\n") == "hello"
        @require proc.match == "\n"
        @require expect!(proc, "\n") == "world"
        @require proc.match == "\n"
    end
end

# Test match/before
@testset "match" begin
    interact(`printf 'a\nbB'`, 1) do proc
        @require expect!(proc, [r"[AB]"]) == 1
        @require proc.match == "B"
        @require proc.before == "a\nb"
        @test_throws ExpectEOF expect!(proc, ["test"])
        @test_throws ExpectEOF expect!(proc, "test")
        @test_throws ExpectEOF expect!(proc, r"test")
        @require proc.match == nothing
    end
end

# expect! with coprocess
@testset "async" begin
    interact(`cat`, 1) do proc
        write(proc, "hello\nworld\n")
        @require expect!(proc, ["hello\n", "world\n"]) == 1
        @require proc.match == "hello\n"
        @require expect!(proc, ["hello\n", "world\n"]) == 2
        @require proc.match == "world\n"
        @test_throws ExpectTimeout expect!(proc, ["test"])
        @require proc.match == nothing
        @require process_running(proc)
    end
end
