using Test
using ComposableCLIParse
using ErrorTypes
using WrappedUnions: @unionsplit
using JET

@testset "Value Parsers" begin

	using ComposableCLIParse: StringVal, Choice

	@testset "StringVal" begin
		sval = stringval(metavar = "TEST", pattern = r"^A.*")
		@test (@? sval("AAA")) == "AAA"
		@test is_error(sval("BBB"))
		@test_opt sval("AAA")
	end

	@testset "Choice" begin
		ch = choice(["HELLO", "WoRlD"], metavar = "TEST", caseInsensitive=true)
		@test (@? ch("HELLO")) == "hello"
		@test (@? ch("world")) == "world"
		@test is_error(ch("!!!"))
		@test_opt ch("world")
	end


end

@testset "Primitives" begin
	using ComposableCLIParse: Context, parse

	@testset "Flag parser" begin

	    @testset "should parse single short flag" begin
	        parser = flag(["-v"])
	        context = Context(["-v"], parser.initialState, false)

	        result = @unionsplit parse(parser, context)

	        @test is_ok_and(result) do succ; is_ok_and(==(true), succ.next.state) end
	       	succ = unwrap(result)
            @test succ.next.buffer == String[]
            @test succ.consumed == ("-v",)
	    end

	    @testset "should parse long flag" begin
	        parser = flag(["--verbose"])
	        context = Context(["--verbose"], parser.initialState, false)

	        result = @unionsplit parse(parser, context)

	        @test is_ok_and(result) do succ; is_ok_and(==(true), succ.next.state) end
       		succ = unwrap(result)
            @test succ.next.buffer == String[]
            @test succ.consumed == ("--verbose",)
	    end

	    @testset "should parse multiple flag names" begin
	        parser = flag(["-v", "--verbose"])

	        # First: "-v"
	        context1 = Context(["-v"], parser.initialState, false)
	        result1 = @unionsplit parse(parser, context1)
	        @test is_ok_and(result1) do succ; is_ok_and(==(true), succ.next.state) end

	        # Second: "--verbose"
	        context2 = Context(["--verbose"], parser.initialState, false)
	        result2 = @unionsplit parse(parser, context2)
	        @test is_ok_and(result2) do succ; is_ok_and(==(true), succ.next.state) end
	    end

	    @testset "should fail when flag is already set" begin
	        parser = flag(["-v"])
	        # Represent "already set" using Result-based state:
	        context = Context(["-v"], Result{Bool, String}(Ok(true)), false)

	        result = @unionsplit parse(parser, context)

	        @test is_error(result)
	        unwrap_or_else(result) do fail
	            @test fail.consumed == 1
	            @test occursin("cannot be used multiple times", fail.error)
	        end
	    end

	    @testset "should handle bundled short flags" begin
	        parser = flag(["-v"])
	        context = Context(["-vd"], parser.initialState, false)

	        result = @unionsplit parse(parser, context)

	        @test is_ok_and(result) do succ
	        	is_ok_and(==(true), succ.next.state) end
	        succ = unwrap(result)
            @test succ.next.buffer == ["-d"]
            @test succ.consumed == ("-v",)
	    end

	    @testset "should fail when flags are terminated" begin
	        parser = flag(["-v"])
	        context = Context(["-v"], parser.initialState, true)

	        result = @unionsplit parse(parser, context)

	        @test is_error(result)
	        unwrap_or_else(result) do fail
	            @test fail.consumed == 0
	            @test occursin("No more",fail.error)
	        end
	    end

	    @testset "should handle flags terminator --" begin
	        parser = flag(["-v"])
	        context = Context(["--"], parser.initialState, false)

	        result = @unionsplit parse(parser, context)

	        @test !is_error(result)
	        is_ok_and(result) do succ
	            @test succ.next.optionsTerminated == true
	            @test succ.next.buffer == String[]
	            @test succ.consumed == ("--",)
	            true
	        end
	    end

	    @testset "should handle empty buffer" begin
	        parser = flag(["-v"])
	        context = Context(String[], parser.initialState, false)

	        result = @unionsplit parse(parser, context)

	        @test is_error(result)
	        unwrap_or_else(result) do fail
	            @test fail.consumed == 0
	            @test occursin("Expected a", fail.error)
	        end
	    end

	    @testset "should be type stable" begin
	    	@test_opt flag(["-v"])
	    	parser = flag(["-v"])

	    	context = Context(["-v"], parser.initialState, false)

	    	_p(par, ctx) = @unionsplit parse(par, ctx)
	    	@test_opt _p(parser, context)
	    end
	end

end