# Enum payload parity

Rust Logos attaches callback values directly to enum variants. Crystal Logos
stores the enum variant and its boxed callback value together in a
`Logos::Result`. Both `Logos.define` and `logos_derive` support this API.

```crystal
number = Token::Number
results = Token.lex_all("42 7")
results.map { |result| result.payload_for!(number, Int32) } # => [42, 7]
```

`Result#payload_for` returns the value when the result holds the requested
variant and the callback emitted the requested type. It returns `nil` for an
error, a different variant, or a missing or mismatched payload.
`Result#payload_for!` raises on those cases. The result retains its payload
after the lexer advances. Result equality and hashing still use the variant or
error and its success status.

Existing `Lexer#payload_for` and `Lexer#payload_for!` calls read the supplied
result. `Lexer#callback_value_as` remains available for reading the lexer’s
current callback value.

## Callback returns

Use `Logos::Filter::Emit.new(value)`, `Logos::FilterResult::Emit.new(value)`,
or a successful `Logos::Result` or `Logos::Option` to attach a payload.
Rust can infer a bare payload from an enum variant's declared field type.
Crystal uses wrappers to distinguish payloads such as `false` from control
returns.

A bare `false` or an empty `Logos::Option` runs the configured default error
callback on the matched slice. Explicit errors carry the object returned by
the callback. Convert it to the configured error type in the callback when
needed. Return `Logos.skip(lexer)` to discard a match, or use a declared skip
rule with a unit return or successful skip result.

## Work breakdown

- `logos-nxw`: Design token-payload API. Complete.
- `logos-15n`: Bind typed payload extraction to each result. Complete.
- `logos-pk9`: Port Rust payload-oriented examples to the result API. Open.

## Executable examples

The [token values example](../examples/token_values.cr) collects the lexer
results before reading their integer, float, and string payloads.
The [calculator](../examples/calculator.cr) passes results with their payloads
to the parser. The custom error, extras, and interpolation examples use
payloads alongside error results, lexer state, and mode changes. The Crystal
extras example displays one-based lines and zero-based byte columns. The Rust
example starts both at zero.

Both JSON examples preserve raw quoted string spelling. The
[owned example](../examples/json.cr) stores Crystal `String` values. The
[borrowed example](../examples/json_borrowed.cr) stores read-only `Bytes` views
into the UTF-8 source, including object keys. It creates strings when pretty
printing the parsed value. Rust's borrowed example uses `&str` views.

Run the example checks with:

```sh
crystal spec spec/logos/payload_examples_spec.cr
```
