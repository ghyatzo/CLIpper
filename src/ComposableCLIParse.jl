module ComposableCLIParse

using WrappedUnions
using ErrorTypes

# based on: https://optique.dev/concepts

# primitive parsers: building blocks of command line interfaces
#	- constant()
#	- option()
#	- flag()
#	- argument()
#	- command()
#	- parsers priority: command > argument > option/flag > constant


# value parsers: specialized components that convert raw string into desired outputs
#	- string(pattern)
#	- integer(min, max, type)
#	- float(min, max, allowInfinity, allowNan)
#	- choice([list of choices], caseinsensitive)
#	- uri()
#	- uuid()
#	- path()
#	- instant() # moment in time
#	- duration()
#	- zone-datetime()
#	- date()
#	- time()
#	- datetime()
#	- yearmonth()
#	- monthday()
#	- timezone()
#	- custom value parser:
#		Interface ValueParser{T}:
#			must have a metavar keyword arg
#			a parse function String -> ParseResult{T}
#			a format function T -> String


# modifying combinators: Transform existing Parsers adding additional behaviour on top of the core one
#	- optional()
#	- withDefault()
#	- map()
#	- multiple(min, max) (match multiple times, collect into an array.)
#	-

# construct combinators: combine different parsers into new ones
# 	- object(), combines multiple named parsers into a single parser that produces a single object
#	- tuple(), combines parsers to produce tuple of results. preserves order.
#	- or(), mutually exclusive alternatives
#	- merge(), takes two parsers and generate a new single parser combining both
#	- concat(), appends tuple parsers
#	- longest-match(), tries all parses and selects the one with the longest match.
#	- group(), documentation only combinator, adds a group label to parsers inside.
function map_err(f, ::Type{E}, x::Result{O})::Result{O, E} where {O, E}
	data = x.x
	return Result{O, E}(data isa Ok ? Ok(data.x) : Err(f(data.x)))
end

export option, flag, argparse, stringval, object


include("parser.jl")

include("valueparsers.jl")
include("primitives.jl")
include("constructors.jl")

@wrapped struct Parser{T, S}
	union::Union{
		ArgFlag{T, S},
		ArgOption{T, S},
		Object{T, S}
	}
end

Base.getproperty(p::Parser, f::Symbol) = @unionsplit Base.getproperty(p, f)

tval(::Type{Parser{T, S}}) where {T, S} = T
tstate(::Type{Parser{T,S}}) where {T,S} = S

# primitives
option(names::Vector{String}, valparser::ValueParser{T}; kw...) where {T} =
	Parser{T, Result{T, String}}(ArgOption(names, valparser; kw...))

flag(names::Vector{String}; kw...) =
	Parser{Bool, Result{Bool, String}}(ArgFlag(names; kw...))


# constructors
object(obj::NamedTuple) = let
	labels, parsers, obj_t, obj_tstates, priority, initialState = _extract_parser_info(obj)
	Parser{obj_t, obj_tstates}(Object{obj_t, obj_tstates}(priority, initialState, parsers, ""))
end
object(objlabel, obj::NamedTuple) = let
	labels, parsers, obj_t, obj_tstates, priority, initialState = _extract_parser_info(obj)
	Parser{obj_t, obj_tstates}(Object{obj_t, obj_tstates}(priority, initialState, parsers, objlabel))
end




#####
# entry point
function argparse(parser::Parser{T, S}, args::Vector{String})::Result{T, String} where {T, S}

	ctx = Context(args, parser.initialState)

	while true
		mayberesult::ParseResult{S, String} = @unionsplit parse(parser, ctx)

		is_error(mayberesult) && return Err(unwrap_error(mayberesult).error)
		result = ErrorTypes.unwrap(mayberesult)

		previous_buffer = ctx.buffer
		ctx = result.next

		if ( length(ctx.buffer) > 0 &&
			 length(ctx.buffer) == length(previous_buffer) &&
			 ctx.buffer[0] === previous_buffer[0])

			return Err("Unexpected option or argument: $(ctx.buffer[0]).")
		end

		length(ctx.buffer) > 0 || break
	end

	endResult = @unionsplit complete(parser, ctx.state)
end

macro comment(_...) end

@comment begin
	args = ["--host", "me", "--verbose"]

	opt = option(["--host"], stringval(;metavar = "HOST"))
	flg = flag(["--verbose"])

	obj = object("test", (
		option = opt,
		flag = flg
	))

	@show argparse(opt, args)
	@show argparse(flg, args)
end

end # module ComposableCLIParse
