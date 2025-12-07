# CLIpper

A Type Stable Composable CLI Parser for Julia, heavily inspired (basically a port) by [optparse-applicative](https://github.com/pcapriotti/optparse-applicative) and [Optique](https://optique.dev/) (typescript version).

[![Build Status](https://github.com/ghyatzo/CLIpper/workflows/CI/badge.svg)](https://github.com/ghyatzo/CLIpper/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

> ⚠️ **Work In Progress**: CLIpper is in active development. The API is experimental and subject to change.
> Type stability is tested and promising, but needs more real-world validation.

## Philosophy

In CLIpper, everything is a parser. Complex parsers are built from simpler ones through composition.
Following the principle of "parse, don't validate," CLIpper returns exactly what you ask for—or fails with a clear explanation.

Each parser is a tree of subparsers. Leaf nodes do the actual parsing, intermediate nodes compose and orchestrate parsers to
create new behaviours. Parsing is done in two passes:

- in the first, the input is checked against each branch of the tree until a match is found. Each node updates its state
to reflect if it succeded or not. This is the `parse` step.
- if the input match any of the branches we consider the step successful, otherwise we return the error of why it failed to match.
- the second pass is the `complete` step. The tree is collapsed, eventual validation error handled and a final object returned.

## Quick Start

```julia
using CLIpper

# Define a parser
parser = object((
    name = option("-n", "--name", str()),
    port = option("-p", "--port", integer(min=1000)),
    verbose = optflag("-v", "--verbose")
))

# Parse arguments
result = argparse(parser, ["--name", "myserver", "-p", "8080", "-v"])

@assert result.name == "myserver"
@assert result.port == 8080
@assert result.verbose == true
```

## Core Concepts

CLIpper provides four types of building blocks:

### Primitives

The fundamental parsers that match command-line tokens:

- **`option`** - Matches key-value pairs: `--port 8080` or `-p 8080`
- **`flag`** - Boolean switches: `--verbose` or `-v`
- **`argument`** - Positional arguments: `source destination`
- **`command`** - Subcommands: `git add file.txt`

```julia
# Options with different styles
port = option("-p", "--port", integer())
result = argparse(port, ["--port=8080"])  # Long form with =
result = argparse(port, ["-p", "8080"])   # Short form

# Flags can be bundled
parser = object((
    all = flag("-a"),
    long = flag("-l"),
    human = flag("-h")
))
result = argparse(parser, ["-alh"])  # Equivalent to ["-a", "-l", "-h"]
```

### Value Parsers

Type-safe parsers that convert strings to values:

- **`str()`** - String values with optional pattern validation
- **`integer()`** / **`i8()`**, **`u32()`**, etc. - Integer types with min/max bounds
- **`flt()`** / **`flt32()`**, **`flt64()`** - Floating point numbers
- **`choice()`** - Enumerated values
- **`uuid()`** - UUID validation

```julia
# Type-safe parsing with constraints
port = option("-p", integer(min=1000, max=65535))
level = option("-l", choice("debug", "info", "warn", "error"))
config = option("-c", str(pattern=r".*\.toml$"))
```

### Modifiers

Enhance parsers with additional behavior:

- **`optional`** - Makes a parser optional (returns `nothing` if absent)
- **`withDefault`** - Provides a fallback value
- **`multiple`** - Allows repeated matches, returns a vector

```julia
# Optional values
email = optional(option("-e", "--email", str()))

# With defaults
port = withDefault(option("-p", integer()), 8080)

# Multiple values
packages = multiple(argument(str()))  # pkg add Package1 Package2 Package3

# Verbosity levels
verbosity = multiple(flag("-v"))  # -v -v -v or -vvv
```

### Constructors

Compose parsers into complex structures:

- **`object`** - Named tuple of parsers (most common)
- **`or`** - Mutually exclusive alternatives (for subcommands)
- **`tup`** - Ordered tuple (preserves parser order)
- **`objmerge`** / **`concat`** - Merge multiple parser groups

```julia
# Object composition
parser = object((
    input = argument(str(metavar="INPUT")),
    output = option("-o", "--output", str()),
    force = optflag("-f", "--force")
))

# Alternative commands with or
addCmd = command("add", object((
    action = @constant(:add),
    packages = multiple(argument(str()))
)))

removeCmd = command("remove", object((
    action = @constant(:remove),
    packages = multiple(argument(str()))
)))

pkgParser = or(addCmd, removeCmd)
```

## Complete Example

Here's a more realistic example showing subcommands:

```julia
using CLIpper

# Shared options
commonOpts = object((
    verbose = optflag("-v", "--verbose"),
    quiet = optflag("-q", "--quiet")
))

# Add command
addCmd = command("add", objmerge(
    commonOpts,
    object((packages = multiple(argument(str(metavar="PACKAGE"))),))
))

# Remove command
removeCmd = command("remove", "rm", objmerge(
    commonOpts,
    object((
        all = optflag("--all"),
        packages = multiple(argument(str(metavar="PACKAGE")))
    ))
))

# Instantiate command
instantiateCmd = command("instantiate", objmerge(
    commonOpts,
    object((
        manifest = optflag("-m", "--manifest"),
        project = optflag("-p", "--project")
    ))
))

# Complete parser
parser = or(addCmd, removeCmd, instantiateCmd)

# Usage examples:
# julia pkg.jl add DataFrames Plots -v
# julia pkg.jl remove --all -q
# julia pkg.jl instantiate --manifest
```

## Type Stability

CLIpper is designed for type stability. The return type of your parser is fully determined at compile time:

```julia
parser = object((
    name = option("-n", str()),
    port = option("-p", integer())
))

# Return type: @NamedTuple{name::String, port::Int64)}

parser = or(
    object((mode = @constant(:a), value = integer())),
    object((mode = @constant(:b), value = str()))
)

# Return type: Union{@NamedTuple{mode::Val{:a}, ...}, NamedTuple{mode::Val{:b}, ...}}
```

## Error Handling

When parsing fails, CLIpper provides clear error messages indicating what went wrong:

```julia
parser = option("-p", integer(min=1000))

# Invalid value
argparse(parser, ["-p", "abc"])  # Error: Expected integer

# Out of range
argparse(parser, ["-p", "500"])  # Error: Value must be >= 1000

# Missing required option
argparse(parser, [])  # Error: Required option -p not found
```

## Comparison with Alternatives

For more detailed documentation and design philosophy, see [Optique's excellent documentation](https://optique.dev/),
which heavily influenced CLIpper's design.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/ghyatzo/CLIpper")
```

## Documentation

Comprehensive documentation is available through Julia's help system:

```juliarepl
julia> using CLIpper

julia> ?option
julia> ?object
julia> ?or
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

CLIpper's design is heavily inspired by:
- [Optique](https://optique.dev/) - Typescript CLI parsing library
- [optparse-applicative](https://github.com/pcapriotti/optparse-applicative) - Haskell command-line parser
<!-- # CLIpper
A Type Stable Composable CLI Parser (heavily) inspired by [Optique](https://optique.dev/) and [optparse-applicative](https://github.com/pcapriotti/optparse-applicative).

This is currently in a heavily experimental and work in progress phase. The tests are thorough, but
,like the night, the inner workings are complex and full of edge cases.
Type stability is tested and it's promising but it will need much more real world and actual trimming attempts to say for sure.

## Overview

In CLIpper everything is a parser. Complex parsers are made up of smaller simpler parsers.
At the cry of "parse, don't validate" CLIpper aims at returning exactly what you ask it. Or fail trying.
If it succeed, then you're sure you're in a valid state. If it doesn't it should tell you exactly why.

There are 3 main types of parsers:

 - **primitive**: These are the main building blocks, the bricks of your grandiose parser.
    they are the parsers that actually match the tokens in your input. The main ones are `option`, `flag`
    `argument`, and `command`.

 - **value parsers**: These are specialized parsers that take on the responsibility of translating
    the actual raw input strings from your command line into strongly typed values that can be used directly by your program. Some of them are: `str()`, `integer()`, `choice()`, `float()`, `uuid()`.

 - **modifiers**: These act as addons to your existing parsers. They can enhance or modify the behaviour of a parsers
    while keeping it's main purpose. These are the main tools to use to add more complex behaviour to your parsers while
    remaining type-stable.
    Some of them are: `optional`, `withDefault`, `multiple`

 - **constructors**/**combinators**: These are the framework of your CLI app. Use them to compose together multiple parsers and create complex parsing structures capable of matching multiple states at the same time. Some of them are: `object`, `or`, `tup`

For a more thorough and clear explaination I suggest you pay a visit to [Optique's amazing documentation](https://optique.dev/). This package was directly inspired by it in design and follows pretty closely its design, making the documentations very much appliable also here. Another source of information is [this blogpost]
## Quick Start

Here’s a minimal example of defining and parsing options:

```julia
using CLIpper

# Define a parser for two options: name and port
parser = object((
    name = option("-n", "--name", str()),
    port = option("-p", "--port", integer(min=1000))
))

# Parse arguments
result = argparse(parser, ["--name", "server", "--port", "8080"])

@assert result.name == "server"
@assert result.port == 8080

```

---

CLIpper supports subcommands using combinators:

```julia
addCmd = command("add", object((
    action = @constant(:add),
    key = argument(str(metavar="KEY")),
    value = argument(str(metavar="VALUE"))
)))

removeCmd = command("remove", object((
    action = @constant(:remove),
    key = argument(str(metavar="KEY"))
)))

parser = or(addCmd, removeCmd)

# Parse: add key value
result = argparse(parser, ["add", "username", "me"])

@assert result.action == :add
@assert result.key == "username"
@assert result.value == "me"
```

---

## Parsers

### Primitives

The meatballs in your spaghetti

#### `flag`s
Nice and simple `flag`s parsers are useful to represent on/off behaviours. In their simplest form they act as gate keepers for other parsers, for example, to activate a certain option, you must also have a specific flag active. Think of some feature that needs `--experimental` (*cough* `--trim` *cough*).

```julia
parser = object((
    experimental = flag("--experimental"),
    trimming = option("--trim", choice("safe", "unsafe"))
))

result = argparse(parser, ["--trim", "safe"]) # ERROR! --trim requires also the --experimental flag!
```

To instead obtain the classic `true` if present, `false` otherwise, you should use the variant `optflag`
```julia
parser = optflag("-v", "--verbose")

verbose = argparse(parser, String[])

@assert verbose == false

```

Exercise for the reader: try to guess how `optflag` is implemented. Hint: it's a oneliner.

`flag` supports bundled short options such as `-abc` will be parsed as `-a -b -c`.

#### `option`s

`option`s are your bread and butter. They match a key and they associate to it a certain value.
Together with `argument`s they are the main users of the value parsers to parse the value you want to give to your option.

They can match multiple patterns:

 - `--option value`/`--option=value`
 - `-Lvalue` (not yet actually)
 - `/O val`/`/O:val`

#### `argument`s

The `argument` parsers deals with positional arguments not associated with a specific key or option.
Very simply they just take a value parser that tells them what it is they whould match.

```julia

parser = object((
    source = argument(str(metavar="SOURCE"))
    dest = argument(str(metavar="DEST"))
))

result = argparse(parser, ["/from/here", "/to/here"])

@assert result.source == "/from/here"
@assert result.dest == "/to/here"
```

#### `command`s

These parsers are slightly more complicated than the ones we've seen so far. They are in-between a primitive parser and a combinator. Think of them as wierd `option` parsers that as their `valueparser` they take another parser.
Their main usecase is to build up subcommands:

```julia

instantiateCmd = command("instantiate", object((
    verbose = optflag("-v", "--verbose"),
    workspace = optflag("--workspace"),
    strict_version = optflag("--julia_version_strict"),
    manifest = optflag("-m", "--manifest"),
    project = optflag("-p", "--project")
)))

removeCmd = command("remove", "rm", object((
    project = optflag("-p", "--project"),
    all = optflag("--all"),
    packages = multiple(argument(str(meta="PACKAGE")))
)))

PkgAtHome = or(instantiateCmd, removeCmd)

result = argparse(PkgAtHome, ["remove", "CLIpper"])

```

### Value parsers

The meat of your meatballs.
All value parsers take a `metavar` keyword that takes in a `String` that gives them a label. It is used in the
printing of the help and usage.

#### `str()`
Very basic, from a raw string input, returns another `String`. Takes the `pattern` keyword that accepts a `Regex` to validate the kind of raw string input it can accept.

#### `choice()`
Limits the possible parsing options to the finite set of choices you give. The type of the choices must be the same for all. If the choices are string, you can pass in the keyword argument `caseInsensitive`.


#### `integer()`
Parses a string into an integer. Internally it uses julia's `parse` function. By default it returns an `Int64` integer, but it accepts a type to specify what it will try to parse the input into: `integer(Int8)`. Some rust-like shorthand helpers are provided: `i8()`, `u32()`, `i16()`...

Takes the `min` or `max` keywords the clamp the range of acceptable values it accepts.

#### `flt()`
Similar to `integer()` but for floats. Go figure. Additional options are `allowNans` and `allowInfinity`. Shorthand helpers also available: `flt32()`, `flt64()`. Defaults to `Float64`.

#### `uuid()`
Parses a string as a valid `uuid`. Accepts a vector of `Int`s of allowed versions.



### Modifiers

The sauce on your meatballs

#### `withDefault`

Gives a default value to a parser in case it's not present in the arguments or if it fails to parse.
The default does not necessarily need to be the same type as the inner parser.

Has a single argument version: `withDefault(false)(flag("--verbose"))`

#### `optional`

Turns a parser that return `T` into a parser that returns `Union{Nothing, T}`.
it's actually just a wrapper of `withDefault(parser, nothing)`

#### `multiple`

Makes a parser match multiple times the same thing. Useful for multiple arguments: `pkg add PKG1 PKG2 PKG3` or for expressing different levels using a flag: `-v -v -v` or `-vvv` (very verbose).

### Constructors

The spaghetti

#### `object`

You probably have seen this parser in almost every example so far. Well, that's because it's the base of your
parser. The `object` parser is a named tuple with extra steps. It will return a collection of values extracted from the
command line arguments and slotted in with the correct label.

#### `tup`

Similar in spirit to the `object` parser, but this one maintains the order of it's parsers. This does not mean that the
arguments must be in the exact order of its constituent parsers, the matching can happen out of order, but the returned result will always be in the same order.

#### `or`

Probably the superhero of all parsers here. Deals with mutually exclusive subtrees. Only one of its parsers can successfully match.


## License

MIT License. See LICENSE for details.
 -->