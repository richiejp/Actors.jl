# Contributing

Development is primarily organised on GitLab.com, please send pull requests
there.

## Coding Conventions

Please try to keep to the current style. Some guidelines are listed below.

### Naming Conventions

Variable names should be reasonably descriptive with the following
exceptions.

| Abbrev | Description          |
|:-------|:---------------------|
| a      | Actor or an actor ID |
| as     | Actors               |
| ex     | Exception            |
| i      | index                |
| j      | index                |
| msg    | message              |
| re     | return address       |
| st     | Stage                |
| s      | Scene                |
| Abs    | Abstract             |
| env    | environment          |
| m      | minder               |
| ref    | reference            |

Avoid using any other abbreviations except in algorithms with a high level
of abstraction where the variables have no "common sense" meaning. You don't
have to use these abbreviations if there is a compelling alternative.

Only use cammel case and capitals in type names or constructors. Use
underscores for everything else.

### Functions

Use the short form of functions wherever possible. Define the parameter types
wherever practical. Functions which necessarily modify an [`Actors.Actor`](@ref)'s
state should have a bang `!` attached.

### Message types

Types/Structs which are messages have a bang attached (e.g. [`Leave!`](@ref))

### Whitespace and Newlines
