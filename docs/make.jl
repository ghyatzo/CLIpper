using Documenter
using CLIpper

makedocs(
    sitename = "CLIpper.jl Documentation",
    pages = [
        "index.md",
        "Examples" => "examples.md",
        "API Docstrings" => "reference.md",
    ],
    # modules = [CLIpper] # not yet ready to test docstrings
)
