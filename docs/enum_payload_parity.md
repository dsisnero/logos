# Enum Payload Parity Plan (Rust Logos -> Crystal Logos)

## Current state

Rust Logos supports associated data directly on enum variants (for example `Number(i64)`).
Crystal enums do not support per-variant payloads, so this port currently stores callback output in `Lexer#callback_value` and returns only the enum variant from `lexer.next`.

Current Crystal usage pattern:

1. Read token variant from `lexer.next`.
2. Read parsed value from `lexer.callback_value_as(T)`.

This is functional but less ergonomic than Rust examples and easy to misuse if callback value and token handling drift.

## Parity target

Match Rust ease-of-use as closely as Crystal allows:

1. Keep token dispatch explicit and fast.
2. Provide typed payload extraction that is structurally tied to the token variant.
3. Preserve advanced functionality (extras, callbacks, custom errors, annotation + define APIs).
4. Maintain backward compatibility for `callback_value_as` during migration.

## Proposed direction

1. Introduce generated payload union aliases per token enum (or equivalent generated wrapper type).
2. Add generated typed helpers on lexer/result to extract payload for a specific token variant.
3. Keep `callback_value` as compatibility layer, then deprecate when ergonomic API is stable.
4. Port Rust payload-heavy examples to prove the final API is concise in real usage.

## Work breakdown

- `logos-nxw`: Design token-payload API with Crystal union-backed values.
- `logos-15n`: Implement typed payload extraction helpers on Lexer/Result.
- `logos-pk9`: Port Rust enum-payload examples to Crystal ergonomic equivalents.

## Known constraints

- Crystal enum model differs from Rust associated-data enums; parity is API-level, not syntax-level.
- Generated unions must avoid runaway compile-time complexity.
- The API must remain consistent across annotation and `Logos.define` macro entry points.
