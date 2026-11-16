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

## Work breakdown

- `logos-nxw`: Design token-payload API. Complete.
- `logos-15n`: Bind typed payload extraction to each result. Complete.
- `logos-pk9`: Port Rust payload-oriented examples to the result API. Open.
