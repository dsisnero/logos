# Release Notes - Logos Crystal Port

Date: 2026-02-10

## Highlights

- Completed the Logos lexer generator port to Crystal.
- Fully implemented regex parsing, NFA/DFA construction, and look-around support.
- Added subpattern support, case-folding helpers, and callback value plumbing.
- Ported and enabled the entire spec suite with no pending tests.

## Notable Features

- `Logos.define` macro with literal and regex patterns, skip rules, priorities, and callbacks.
- Regex subpatterns via `subpattern` and `(?&name)` substitution.
- UTF-8 aware lexing and boundary-safe slicing.
- Error handling and callback filter results compatible with the Rust API.

## Testing

- `crystal spec` passes with 176 examples.
- `crystal tool format src spec`
- `ameba --fix src spec`, `ameba src`, `ameba spec`
