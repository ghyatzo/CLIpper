# Help Generation System for OptParse.jl

# This module provides GNU-style help generation while maintaining type stability

using ..OptParse: AbstractParser, Parser, Context, ParseResult, ParseSuccess, ParseFailure
using ..OptParse: ArgFlag, ArgOption, ArgArgument, ArgCommand
using ..OptParse: ConstrObject, ConstrOr, ConstrTuple
using ..OptParse: unwrap, unwrap_error, is_error

# Help Metadata Types
abstract type HelpMetadata end

struct FlagHelp <: HelpMetadata
    names::Vector{String}
    description::String
end

struct OptionHelp <: HelpMetadata
    names::Vector{String}
    description::String
    metavar::String
end

struct ArgumentHelp <: HelpMetadata
    description::String
    metavar::String
end

struct CommandHelp <: HelpMetadata
    names::Vector{String}
    description::String
end

const AnyHelp = Union{FlagHelp, OptionHelp, ArgumentHelp, CommandHelp}

# Help State
struct HelpState
    current_path::Vector{String}
    visited_metadata::Vector{AnyHelp}
    error_token::Union{Nothing,String}
    error_position::Int
end

# Extended Context with Help State
struct HelpContext{S} <: Context{S}
    buffer::Vector{String}
    state::S
    optionsTerminated::Bool
    help_state::HelpState
end

# Help Metadata Extraction
function create_help_metadata(p::ArgFlag)::FlagHelp
    return FlagHelp(p.names, getfield(p, :help, ""))
end

function create_help_metadata(p::ArgOption)::OptionHelp
    return OptionHelp(p.names, getfield(p, :help, ""), p.valparser.metavar)
end

function create_help_metadata(p::ArgArgument)::ArgumentHelp
    return ArgumentHelp(getfield(p, :help, ""), p.valparser.metavar)
end

function create_help_metadata(p::ArgCommand)::CommandHelp
    return CommandHelp(p.names, getfield(p, :help, ""))
end

function create_help_metadata(p::ConstrObject)::Vector{AnyHelp}
    metadata = AnyHelp[]
    for (field, parser) in pairs(p.parsers)
        append!(metadata, create_help_metadata(parser))
    end
    return metadata
end

function create_help_metadata(p::ConstrOr)::Vector{AnyHelp}
    metadata = AnyHelp[]
    for parser in p.parsers
        append!(metadata, create_help_metadata(parser))
    end
    return metadata
end

function create_help_metadata(p::ConstrTuple)::Vector{AnyHelp}
    metadata = AnyHelp[]
    for parser in p.parsers
        append!(metadata, create_help_metadata(parser))
    end
    return metadata
end

# Default case for other parser types
create_help_metadata(p::AbstractParser) = AnyHelp[]

# Help Generation Functions
function generate_usage_line(help_state::HelpState)::String
    usage = "Usage: "

    # Add current command path
    if !isempty(help_state.current_path)
        usage *= "$(join(help_state.current_path, " ")) "
    end

    # Separate options and arguments
    options = filter(m -> m isa Union{FlagHelp, OptionHelp}, help_state.visited_metadata)
    arguments = filter(m -> m isa ArgumentHelp, help_state.visited_metadata)

    # Add options section if any
    if !isempty(options)
        usage *= "[OPTIONS] "
    end

    # Add arguments
    for arg in arguments
        usage *= "<$(arg.metavar)> "
    end

    return rstrip(usage)
end

function generate_detailed_help(parser::Parser)::String
    # Get all possible help metadata
    all_metadata = create_help_metadata(parser)

    help_text = "Usage: [COMMAND] [OPTIONS]\n\n"

    # Organize by type
    flags = filter(m -> m isa FlagHelp, all_metadata)
    options = filter(m -> m isa OptionHelp, all_metadata)
    arguments = filter(m -> m isa ArgumentHelp, all_metadata)
    commands = filter(m -> m isa CommandHelp, all_metadata)

    # Format flags and options together
    if !isempty(flags) || !isempty(options)
        help_text *= "Options:\n"
        for info in vcat(flags, options)
            if info isa FlagHelp
                names_str = join(info.names, ", ")
                help_text *= "  $(names_str)\n"
            else  # OptionHelp
                names_str = join(info.names, ", ")
                help_text *= "  $(names_str) $(info.metavar)\n"
            end
            if !isempty(info.description)
                help_text *= "    $(info.description)\n"
            end
        end
        help_text *= "\n"
    end

    # Format arguments
    if !isempty(arguments)
        help_text *= "Arguments:\n"
        for info in arguments
            help_text *= "  <$(info.metavar)>\n"
            if !isempty(info.description)
                help_text *= "    $(info.description)\n"
            end
        end
        help_text *= "\n"
    end

    # Format commands
    if !isempty(commands)
        help_text *= "Commands:\n"
        for info in commands
            help_text *= "  $(info.names[1])\n"
            if !isempty(info.description)
                help_text *= "    $(info.description)\n"
            end
        end
    end

    return help_text
end

# Error Enhancement
function enhance_error(error::String, help_state::HelpState)::String
    error_msg = "Error: $error\n\n"

    # Add usage line with current context
    error_msg *= generate_usage_line(help_state)
    error_msg *= "\n\n"

    # Add specific error context
    if help_state.error_token !== nothing
        error_msg *= "Unexpected token: '$(help_state.error_token)'\n"

        # Suggest similar options if possible
        suggestions = find_similar_options(help_state.error_token, help_state.visited_metadata)
        if !isempty(suggestions)
            error_msg *= "Did you mean: $(join(suggestions, ", "))?\n"
        end
    end

    error_msg *= "\nTry '--help' for more information."

    return error_msg
end

function find_similar_options(token::String, metadata::Vector{AnyHelp})::Vector{String}
    suggestions = String[]
    options = filter(m -> m isa Union{FlagHelp, OptionHelp}, metadata)

    for opt in options
        for name in opt.names
            # Simple similarity checks
            if startswith(name, token) || 
               endswith(name, token) || 
               contains(name, token)
                push!(suggestions, name)
            end
        end
    end

    return unique(suggestions)
end

# Help-Aware Parsing Wrapper
function parse_with_help(p::AbstractParser, ctx::Context)::ParseResult
    # Create help metadata for this parser
    metadata = create_help_metadata(p)
    
    # Ensure we have a HelpContext
    if !(ctx isa HelpContext)
        # Convert regular Context to HelpContext
        help_ctx = HelpContext(
            ctx.buffer,
            ctx.state,
            ctx.optionsTerminated,
            HelpState(String[], AnyHelp[], nothing, 0)
        )
    else
        help_ctx = ctx
    end

    # Update help state
    new_help_state = HelpState(
        help_ctx.help_state.current_path,
        vcat(help_ctx.help_state.visited_metadata, metadata),
        help_ctx.help_state.error_token,
        help_ctx.help_state.error_position
    )

    # Create new context with updated help state
    new_ctx = HelpContext(
        help_ctx.buffer,
        help_ctx.state,
        help_ctx.optionsTerminated,
        new_help_state
    )

    # Call original parse function
    return parse(p, new_ctx)
end

# Help-Aware Argparse
function argparse_with_help(parser::Parser, args::Vector{String})
    # Check for help flags
    if "--help" in args || "-h" in args
        println(generate_detailed_help(parser))
        exit(0)
    end

    # Initialize help state
    initial_help_state = HelpState(
        String[],        # current_path
        AnyHelp[],       # visited_metadata
        nothing,         # error_token
        0                # error_position
    )

    # Create initial context
    ctx = HelpContext(args, parser.initialState, false, initial_help_state)

    # Parse with help tracking
    result = parse_with_help(parser, ctx)

    if is_error(result)
        error_info = unwrap_error(result)
        final_help_state = ctx.help_state

        # If error is about unexpected token, update help state
        if occursin("Unexpected", error_info.error) && !isempty(ctx.buffer)
            final_help_state = HelpState(
                final_help_state.current_path,
                final_help_state.visited_metadata,
                ctx.buffer[1],  # The unexpected token
                1               # Position 1
            )
        end

        enhanced_error = enhance_error(error_info.error, final_help_state)
        return Err(enhanced_error)
    end

    return result
end

# Export the help-aware argparse function
export argparse_with_help