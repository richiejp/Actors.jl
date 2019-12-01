push!(LOAD_PATH, joinpath(@__DIR__, "../src"))

using Documenter
using Actors

makedocs(
    sitename = "Actors",
    format = Documenter.HTML(),
    modules = [Actors],
    pages = [
        "Guide" => "index.md",
        "Reference" => "reference.md",
        "Contributing" => "contributing.md"
    ]
)
