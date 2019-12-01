push!(LOAD_PATH, "../src/")

using Documenter
using Actors

makedocs(
    sitename = "Actors",
    format = Documenter.HTML(),
    modules = [Actors]
)
