# OptParse.jl Help Generation System

This directory contains the help generation system for OptParse.jl, designed to provide GNU-style help output while maintaining type stability.

## Overview

The help system provides two types of help:

1. **Usage Help**: Context-aware help shown when parsing errors occur
2. **Full Help**: Comprehensive help shown when `--help` or `-h` flags are used

## Design Principles

1. **Type Stability**: Help generation doesn't affect parser return types
2. **Automatic Metadata**: Help information extracted from existing parser structure
3. **Context-Aware**: Help reflects actual parsing progress
4. **GNU Compatibility**: Follows standard GNU help conventions
5. **Smart Suggestions**: Provides helpful suggestions for common errors

## Components

### 1. Help Metadata Types

- `FlagHelp`: Help information for flags
- `OptionHelp`: Help information for options (with metavar)
- `ArgumentHelp`: Help information for arguments (with metavar)
- `CommandHelp`: Help information for commands

### 2. Help State

The `HelpState` is added to `Context` and tracks:
- `current_path`: Current command path
- `visited_metadata`: Help metadata for visited parsers
- `error_token`: Token that caused error (if any)
- `error_position`: Position where error occurred

### 3. Automatic Metadata Extraction

Each parser type has a `create_help_metadata` function that extracts help information from the parser's existing fields:
- Names (from `p.names`)
- Description (from `p.help`)
- Metavar (from `p.valparser.metavar` for options/arguments)

### 4. Help Generation Functions

- `generate_usage_line()`: Creates context-aware usage line
- `generate_detailed_help()`: Creates comprehensive help output
- `enhance_error()`: Enhances error messages with help context
- `find_similar_options()`: Finds suggestions for typos

### 5. Help-Aware Parsing

The `parse_with_help()` function wraps the original parse functions to:
1. Extract help metadata
2. Update help state
3. Pass through to original parsing logic

## Integration

### Adding Help to Your Parser

No special syntax is needed! The help system automatically extracts information from your existing parser definitions:

```julia
parser = object((
    source = argument(str(metavar="SOURCE"), help="Source file"),
    dest = argument(str(metavar="DEST"), help="Destination"),
    force = optflag("-f", "--force", help="Overwrite files")
))
```

### Using Help-Aware Argparse

Replace `argparse()` with `argparse_with_help()`:

```julia
# Instead of:
result = argparse(parser, args)

# Use:
result = argparse_with_help(parser, args)
```

### Automatic Help Invocation

The system automatically handles `--help` and `-h` flags:

```bash
$ julia app.jl --help
Usage: app.jl [OPTIONS] <SOURCE> <DEST>

Options:
  -f, --force    Overwrite files

Arguments:
  <SOURCE>       Source file
  <DEST>         Destination
```

### Error Enhancement

Errors are automatically enhanced with context and suggestions:

```bash
$ julia app.jl --forsce file1 file2
Error: No matched option for '--forsce'

Usage: app.jl [OPTIONS] <SOURCE> <DEST>

Unexpected token: '--forsce'
Did you mean: --force?

Try '--help' for more information.
```

## Implementation Details

### Type Stability

- All help functions return `String`
- Help state is separate from parser state
- No impact on parser return types
- Uses existing parser metadata

### Performance

- Help generation is only done when needed (errors or `--help`)
- Metadata extraction is cached during parsing
- String operations are optimized for readability over performance

### Error Handling

- Errors are enhanced with context from help state
- Suggestions are provided for common typos
- Usage lines reflect actual parsing progress

## Future Enhancements

Potential improvements to the help system:

1. **ANSI Color Support**: Add optional colored output
2. **Help Sections**: Support for organizing help into sections
3. **Subcommand Help**: Better help for nested commands
4. **Manual Pages**: Generate man page output
5. **Localization**: Support for multiple languages

## Testing

The help system should be tested with:

1. Various parser combinations
2. Error scenarios
3. Different command structures
4. Edge cases (empty parsers, etc.)

## Contributing

Contributions to the help system are welcome! Please:

1. Maintain type stability
2. Follow existing code style
3. Add tests for new features
4. Document new functionality

## License

This help system is part of OptParse.jl and is licensed under the MIT License.