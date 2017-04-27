include("prelude.jl")

# Test simple matches
@testset "simple" begin
    interact(`printf 'hello\nworld\n'`, 1) do proc
        @test expect!(proc, "\n") == "hello"
        @test proc.match == "\n"
        @test expect!(proc, "\n") == "world"
        @test proc.match == "\n"
    end
end

# Test match/before
@testset "match" begin
    interact(`printf 'a\nbB'`, 1) do proc
        @test expect!(proc, [r"[AB]"]) == 1
        @test proc.match == "B"
        @test proc.before == "a\nb"
        @test_throws ExpectEOF expect!(proc, ["test"])
        @test_throws ExpectEOF expect!(proc, "test")
        @test_throws ExpectEOF expect!(proc, r"test")
        @test proc.match == nothing
    end
end

# expect! with coprocess
@testset "async" begin
    interact(`cat`, 1) do proc
        write(proc, "hello\nworld\n")
        expect!(proc, ["hello\n", "world\n"]) == 1
        @test proc.match == "hello\n"
        @test expect!(proc, ["hello\n", "world\n"]) == 2
        @test proc.match == "world\n"
        @test_throws ExpectTimeout expect!(proc, ["test"])
        @test proc.match == nothing
        @test process_running(proc)
    end
end
