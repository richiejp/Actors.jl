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

Use the short form of functions wherever possible (i.e. `fn() = ...`). Define
the argument types wherever practical, however do try to allow the user to
override your methods. For example use `hear(s::Scene{<:AbsStage}) = ...`,
instead of `hear(s::Scene{Stage}) = ...`. Note that the `<:` is necessary so
that the parameter `S` of `Scene{S}` can take a concrete type value at compile
time which derives from `AbsStage`. Otherwise it will result in dynamic typing.

Functions which necessarily modify an [`Actors.Actor`](@ref)'s state should
have a bang `!` attached.

Avoid functions with large numbers of parameters (i.e. more than 5),
especially optional parameters. Create a new type to encapsulate them or find
some other way.

### Message types

Types/Structs which are primarily intended as messages have a bang attached
(e.g. [`Leave!`](@ref)).

### Whitespace

Indentation is 4 spaces and several layers of indentation sould be
avoided. Ideally lines should be no longer than 80 characters, but there is no
hard upper limit.

In general code is grouped into small semi-logical blocks, seperated by a new
line. Sometimes this coincides with actual control or block statements, like
`if..else` or `try`, but not always.
