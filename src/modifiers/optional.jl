struct ModOptional{T, S, p, P}
    initialState::S
    parser::P

    ModOptional(parser::P) where {P} =
        new{Option{tval(P)}, Option{tstate(P)}, priority(P), P}(none(tstate(P)), parser)
end


function parse(p::ModOptional{T, S}, ctx::Context)::ParseResult{S, String} where {T, S}
    result = parse(p.parser, ctx)::ParseResult{tstate(p.parser), String}

    if !is_error(result)
        parse_ok = unwrap(result)
        newctx = set(parse_ok.next, PropertyLens(:state), some(parse_ok.next.state))
        return ParseOk(parse_ok.consumed, newctx)
    else
        # newctx = (@set ctx.state = S(Err(unwrap_error(result).error)))
        # return ParseOk(String[], newctx)
        parse_err = unwrap_error(result)
        return ParseErr(parse_err.consumed, parse_err.error)
    end
end

function complete(p::ModOptional{T, S, _p, P}, maybestate::S)::Result{T, String} where {T, S, _p, P}
    state = base(maybestate) # collapses the optional to a nothing or a Some
    isnothing(state) && return Ok(none(tval(P)))

    result = complete(p.parser, something(state))::Result{tval(P), String}

    if !is_error(result)
        return Ok(some(unwrap(result)))
    else
        return Err(unwrap_error(result))
    end

end
