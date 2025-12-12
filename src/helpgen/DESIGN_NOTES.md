# Help Generation System - Design Notes and Future Work

This document contains detailed design notes, implementation decisions, and future work plans for the OptParse.jl help generation system.

## Current Implementation Status

### ✅ Completed Components

1. **Help Metadata Types**
   - `FlagHelp`, `OptionHelp`, `ArgumentHelp`, `CommandHelp`
   - Type-stable union type `AnyHelp`

2. **Help State Tracking**
   - `HelpState` struct integrated into `Context`
   - Tracks visited parsers, current path, and error context

3. **Automatic Metadata Extraction**
   - Functions for all parser types (primitives, constructors)
   - Leverages existing `help`, `names`, and `metavar` fields

4. **Help Generation Functions**
   - `generate_usage_line()` - context-aware usage lines
   - `generate_detailed_help()` - comprehensive help output
   - `enhance_error()` - error messages with context
   - `find_similar_options()` - smart suggestions

5. **Help-Aware Parsing**
   - `parse_with_help()` wrapper function
   - `argparse_with_help()` main entry point
   - Automatic `--help`/`-h` handling

### 🚧 Known Limitations

1. **Help Context for Commands**
   - Current implementation doesn't fully track command paths
   - Need to update `current_path` when parsing commands

2. **Subcommand Help**
   - Help for nested commands could be more detailed
   - Should show command hierarchy in usage

3. **Performance Optimization**
   - Metadata extraction happens during parsing
   - Could cache metadata for better performance

4. **Error Context**
   - Error position tracking is basic
   - Could provide more detailed error context

5. **Help Formatting**
   - Basic GNU-style formatting
   - Could add ANSI colors, wrapping, etc.

## Future Work Priorities

### High Priority (Next Steps)

#### 1. Command Path Tracking
**Problem**: Current help state doesn't properly track command paths for subcommands.

**Solution**:
```julia
function parse_with_help(p::ArgCommand, ctx::HelpContext)::ParseResult
    # Update current path with command name
    new_path = vcat(ctx.help_state.current_path, p.names[1])
    
    new_help_state = HelpState(
        new_path,
        ctx.help_state.visited_metadata,
        ctx.help_state.error_token,
        ctx.help_state.error_position
    )
    
    # Continue with updated context
    # ...
end
```

#### 2. Subcommand Help Improvement
**Problem**: Help for nested commands doesn't show hierarchy well.

**Solution**:
- Update `generate_detailed_help()` to show command hierarchy
- Add indentation for subcommands
- Show full command paths in usage

#### 3. Help Caching
**Problem**: Metadata extraction happens repeatedly during parsing.

**Solution**:
```julia
# Add cache to parser or context
struct HelpCache
    metadata::Dict{AbstractParser, AnyHelp}
end

# Modify create_help_metadata to use cache
function create_help_metadata(p::AbstractParser, cache::HelpCache)::AnyHelp
    if haskey(cache.metadata, p)
        return cache.metadata[p]
    end
    
    metadata = create_help_metadata_impl(p)
    cache.metadata[p] = metadata
    return metadata
end
```

### Medium Priority

#### 4. Enhanced Error Context
**Problem**: Error context could be more detailed.

**Improvements**:
- Track which parsers were expected at error position
- Show valid options at point of error
- Highlight where in the command the error occurred

#### 5. Help Sections
**Problem**: Large help outputs can be overwhelming.

**Solution**:
```julia
struct HelpSection
    title::String
    metadata::Vector{AnyHelp}
end

# Update help generation to support sections
function generate_detailed_help(parser::Parser, sections::Vector{HelpSection})::String
    # Organize help by sections
end
```

#### 6. Better Suggestion Algorithm
**Problem**: Current similarity algorithm is very basic.

**Improvements**:
- Implement proper Levenshtein distance
- Add phonetic matching (Soundex, etc.)
- Consider common typos and transpositions

### Low Priority

#### 7. ANSI Color Support
**Problem**: Help output is plain text only.

**Solution**:
```julia
struct HelpStyle
    use_colors::Bool
    color_scheme::Dict{Symbol,String}  # :option => "\e[34m" (blue)
end

# Update help generation to use styles
function generate_detailed_help(parser::Parser, style::HelpStyle)::String
    # Apply colors based on style
end
```

#### 8. Manual Page Generation
**Problem**: No support for man page format.

**Solution**:
```julia
function generate_man_page(parser::Parser)::String
    # Generate output in groff/man format
    """.TH MYAPP 1 "$(Dates.now())" "1.0" "My Application"
.SH NAME
myapp - does something useful
.SH SYNOPSIS
.B myapp
[OPTIONS] <INPUT> <OUTPUT>
..."
```

#### 9. Localization Support
**Problem**: Help text is English-only.

**Solution**:
```julia
struct LocalizedHelp
    default::String
    translations::Dict{String,String}  # "es" => "Ayuda", etc.
end

# Update parser to support localized help
function create_help_metadata(p::ArgOption, locale::String)::OptionHelp
    # Return help in specified locale
end
```

## Implementation Guidelines

### Type Stability Requirements

1. **All help functions must return `String`**
   - Never return parser types or modify parser behavior
   - Keep help generation separate from parsing logic

2. **Help state must be separate from parser state**
   - Help tracking should not affect parser return types
   - Use separate context extension for help data

3. **Avoid modifying existing parser types**
   - Extract metadata from existing fields only
   - Don't add new fields to parser structs

### Performance Considerations

1. **Help generation should be lazy**
   - Only generate help when needed (errors or `--help`)
   - Don't impact normal parsing performance

2. **Cache expensive operations**
   - Cache metadata extraction
   - Cache string formatting where possible

3. **Prioritize correctness over speed**
   - Help generation is not performance-critical
   - Focus on accurate, helpful output

### Error Handling Principles

1. **Provide actionable error messages**
   - Tell users exactly what went wrong
   - Show valid alternatives when possible

2. **Show context from parsing**
   - Highlight where in the command the error occurred
   - Show what was expected vs what was found

3. **Offer helpful suggestions**
   - Find similar options for typos
   - Suggest `--help` for more information

### Help Output Standards

1. **Follow GNU conventions**
   - `Usage:` line first
   - Options in alphabetical order (usually)
   - Consistent indentation

2. **Be concise but complete**
   - Show all available options
   - Include descriptions when available
   - Use metavar for placeholders

3. **Format for readability**
   - 80-character line wrapping
   - Consistent spacing
   - Clear section headers

## Testing Strategy

### Test Coverage Needed

1. **Metadata Extraction Tests**
   - All parser types (primitives, constructors)
   - Nested parsers (objects, tuples)
   - Edge cases (empty help, missing fields)

2. **Help Generation Tests**
   - Usage line generation
   - Detailed help formatting
   - Error message enhancement
   - Suggestion finding

3. **Integration Tests**
   - Help with simple parsers
   - Help with complex parsers
   - Help with subcommands
   - Error scenarios

4. **Edge Case Tests**
   - Empty parsers
   - Parsers with no help text
   - Very long option names
   - Unicode in help text

### Example Test Cases

```julia
# Test metadata extraction from complex parser
complex_parser = object((
    common = objmerge(
        object((verbose = optflag("-v", help="Verbose"))),
        object((quiet = optflag("-q", help="Quiet")))
    ),
    command = or(
        command("add", object((
            files = multiple(argument(str(metavar="FILE")))
        ))),
        command("remove", object((
            force = optflag("-f", help="Force")
        )))
    )
))

@test length(create_help_metadata(complex_parser)) > 0
```

## Integration Checklist

### For Merging into Main Codebase

1. **Update OptParse.jl module**
   - Add `include("helpgen/helpgen.jl")`
   - Export `argparse_with_help`
   - Consider making it the default

2. **Update Context definition**
   - Merge `HelpContext` into main `Context`
   - Add help_state field with default

3. **Update parse functions**
   - Add help tracking to all parse methods
   - Ensure type stability is maintained

4. **Update documentation**
   - Add help generation section
   - Update examples to show help
   - Add API documentation

### Migration Path

1. **Phase 1: Optional Help**
   - Keep `argparse()` as is
   - Add `argparse_with_help()` as alternative
   - Users opt-in to help features

2. **Phase 2: Default Help**
   - Make help tracking default
   - `argparse()` gets help features
   - Add option to disable help

3. **Phase 3: Enhanced Features**
   - Add advanced help features
   - Improve error messages
   - Add formatting options

## Open Questions

### Design Decisions Needing Resolution

1. **Should help be automatic or opt-in?**
   - Current: Opt-in via `argparse_with_help()`
   - Future: Should it be the default?

2. **How to handle missing help text?**
   - Current: Empty strings
   - Future: Generate default descriptions?

3. **Should help affect parser priorities?**
   - Current: No impact
   - Future: Should help options have special priority?

4. **How to handle very complex parsers?**
   - Current: Show all options
   - Future: Paginate or categorize help?

### Technical Challenges

1. **Type stability with help caching**
   - How to cache metadata without affecting types
   - Where to store cache (parser? context?)

2. **Command path tracking**
   - How to handle aliases and multiple names
   - How to show full command hierarchy

3. **Performance optimization**
   - When does help generation become too slow?
   - How to optimize without complexity?



## Getting Back to Work

### Quick Start Guide

1. **Review current implementation**
   - Read `helpgen.jl` for current code
   - Check `README.md` for usage examples

2. **Identify next priority**
   - See "High Priority" section above
   - Start with command path tracking

3. **Implementation steps**
   - Add command path tracking to `parse_with_help`
   - Update help generation to use paths
   - Test with nested commands

4. **Testing**
   - Create test cases for new features
   - Verify type stability
   - Check error handling

5. **Integration**
   - Merge changes into main codebase
   - Update documentation
   - Add examples

### Helpful Resources

1. **GNU Help Conventions**
   - https://www.gnu.org/prep/standards/standards.html#g_t_002d_002dhelp

2. **Julia Documentation**
   - https://docs.julialang.org/

3. **OptParse.jl Architecture**
   - Review `AGENTS.md` for architecture overview
   - Check existing parser implementations

4. **Similar Projects**
   - Python's argparse help system
   - Rust's clap help generation
   - Haskell's optparse-applicative

## Conclusion

This help generation system provides a solid foundation for user-friendly CLI applications built with OptParse.jl. The current implementation offers:

- ✅ Automatic help metadata extraction
- ✅ Context-aware error messages
- ✅ GNU-style help output
- ✅ Smart suggestions for typos
- ✅ Type-stable design

Future work should focus on:

1. **Command path tracking** (highest priority)
2. **Subcommand help improvement**
3. **Help caching for performance**
4. **Enhanced error context**

The system is designed to be gradually enhanced without breaking existing functionality, making it easy to pick up development at any time.