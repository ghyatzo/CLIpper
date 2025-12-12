# Example usage of the help generation system

# This example demonstrates how to use the help system with OptParse.jl

using ..OptParse
using ..OptParse.HelpGen

# Define a parser with help information
function create_example_parser()
    return object((
        # Arguments with metavar and help text
        source = argument(str(metavar="SOURCE"), help="Source file to copy"),
        dest = argument(str(metavar="DEST"), help="Destination path"),
        
        # Options with help text
        force = optflag("-f", "--force", help="Overwrite existing files"),
        verbose = optflag("-v", "--verbose", help="Enable verbose output"),
        recursive = optflag("-r", "--recursive", help="Copy directories recursively"),
        
        # Option with value parser
        depth = option("-d", "--depth", integer(min=1), help="Maximum recursion depth")
    ))
end

# Example 1: Show help output
function example_show_help()
    println("=== Example 1: Show Help Output ===")
    parser = create_example_parser()
    
    # Simulate --help flag
    println("Running: julia example.jl --help")
    println("="^50)
    println(generate_detailed_help(parser))
end

# Example 2: Show error with context
function example_show_error()
    println("\n=== Example 2: Show Error with Context ===")
    parser = create_example_parser()
    
    # Simulate an error
    args = ["--forsce", "file1.txt", "file2.txt"]
    println("Running: julia example.jl $(join(args, " "))")
    println("="^50)
    
    result = argparse_with_help(parser, args)
    if is_error(result)
        println(unwrap_error(result))
    end
end

# Example 3: Successful parsing
function example_successful_parse()
    println("\n=== Example 3: Successful Parsing ===")
    parser = create_example_parser()
    
    args = ["-v", "-f", "source.txt", "dest.txt"]
    println("Running: julia example.jl $(join(args, " "))")
    println("="^50)
    
    result = argparse_with_help(parser, args)
    if !is_error(result)
        parsed = unwrap(result)
        println("Successfully parsed:")
        println("  source: $(parsed.source)")
        println("  dest: $(parsed.dest)")
        println("  force: $(parsed.force)")
        println("  verbose: $(parsed.verbose)")
        println("  recursive: $(parsed.recursive)")
    end
end

# Run all examples
function main()
    example_show_help()
    example_show_error()
    example_successful_parse()
end

# Uncomment to run examples
# main()