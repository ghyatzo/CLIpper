const OrState{X} = Option{Tuple{Int,ParseSuccess{X}}}

# a parser that returns the first parsers that matches, in the order provided!
struct ConstrOr{T,S,p,P}
    initialState::S
    parsers::P
end

ConstrOr(parsers::Tuple) =
    ConstrOr{
        Union{map(tval, parsers)...},
        OrState{Union{map(tstate, parsers)...}},
        mapreduce(p -> priority(p), max, parsers),
        typeof(parsers)
    }(none(Tuple{Int,ParseSuccess{Union{map(tstate, parsers)...}}}), parsers)

function parse(p::ConstrOr, ctx::Context{OrState{S}})::ParseResult{OrState{S},String} where {S}
    error = length(ctx.buffer) < 1 ?
            (0, "No matching option or command.") : (0, "Unexpected option or subcommand: $(ctx.buffer[1])")

    i = 1
    for parser in p.parsers


        childstate = is_ok_and(st -> st[1] == i, ctx.state) ?
                     unwrap(ctx.state)[2].next.state : parser.initialState

        childctx = @set ctx.state = childstate

        result = parse(parser, childctx)
        if !is_error(result) && length(unwrap(result).consumed) > 0 # (ignores constants)
            parse_ok = unwrap(result)
            # If we successfully match something, but the current state is telling us that we've already matched
            # something else, and those two things aren't the same thing, then error.
            # Or only matches one!

            if is_ok_and(st -> st[1] != i, ctx.state)
                st = unwrap(ctx.state)
                return ParseErr(length(ctx.buffer) - length(parse_ok.next.buffer),
                    "$(st[2].consumed) and $(parse_ok.consumed) can't be used together.")
            end

            # rebuild the result so that it results as a union type
            union_context = Context{S}(parse_ok.next.buffer, parse_ok.next.state, parse_ok.next.optionsTerminated)
            union_parse_ok = ParseSuccess{S}(parse_ok.consumed, union_context)
            return ParseOk(
                parse_ok.consumed, Context{OrState{S}}(
                    parse_ok.next.buffer,
                    some((i, union_parse_ok)),
                    parse_ok.next.optionsTerminated
                )
            )
        elseif is_error(result)
            if error[1] <= unwrap_error(result).consumed
                parse_err = unwrap_error(result)
                error = (parse_err.consumed, parse_err.error)
            end
        end
        i += 1
    end

    return ParseErr(error[1], error[2])
end

function complete(p::ConstrOr{T}, maybest::TState)::Result{T,String} where {T,TState<:OrState}
    isnothing(base(maybest)) && return Err("No matching option or command.")
    ith, parse_success = @something base(maybest)

    result = complete(p.parsers[ith], parse_success.next.state)

    if !is_error(result)
        return Ok(unwrap(result))
    else
        return Err(unwrap_error(result))
    end

end