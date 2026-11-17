# Lexer authoring roadmap

Phase 9 is complete. Start with Phase 10 for lexer authoring work.
Phase 8 in [the parity roadmap](parity.md) is the independent performance
baseline. The API examples below are proposed contracts. Each numbered phase
ends in one reviewable commit.

## Phase 9. First lexer, anonymous skips, and declaration diagnostics

**Complete.** The anonymous rule failed macro expansion before the fix, and
the typo fixture had compiled successfully. The runtime and strict generated
fixtures now agree on token kinds, spans, the extras increment, and EOF.
Use JSON `"variant": null` with `"skip": true` to bind an anonymous action
explicitly. The installed package runs the shorter Quick Start.

1. Compare the Rust calculator's enum-level skip with the newline callback in
   [Rust extras](../logos_rust/examples/extras.rs). Trace how
   [the annotation macro](../src/logos/macros.cr) represents an anonymous skip
   and how [the DSL](../src/logos/define_macro.cr) assigns rule IDs and emits
   enum members. Preserve the existing ordering used for priority and binding.
2. **Red.** Add an ergonomics fixture using one-argument
   `skip_regex "[ ]+"` and an anonymous newline rule whose block increments
   an extras counter. Lex `a  \nb!` and assert the two word results at
   `0...1` and `4...5`, an error at `5...6`, one newline callback, and EOF.
   Assert that the public enum contains only the declared word variant. Add a
   compile-fail fixture with `priorty: 10` and assert the diagnostic names
   the option and directive. Run negative fixtures in a separate compiler
   process so the main spec suite can compile.
3. **Green.** Accept the anonymous form alongside named skips. Keep rule
   identity independent of the optional emitted variant, including in strict
   binding metadata. Run a skip callback once before continuing the scan.
   Validate named options against the supported options for each DSL directive
   and point errors at the offending declaration. Exercise existing valid
   priority, bytes, case, greedy and callback options.
4. Simplify the README Quick Start using the default error type, anonymous
   whitespace and `lexer.each`. Keep its input and expected output so
   [the package spec](../spec/logos/package_spec.cr) verifies the new example.
   Show `spanned.each` for byte spans and how to handle an error result.
5. **Done when** runtime and generated lexers agree on the fixture, the typo
   fails compilation, and existing named skips and annotated skips still pass.

## Phase 10. Typed callback payload declarations

1. Compare [the Rust calculator](../logos_rust/examples/calculator.rs) and
   [the Crystal calculator](../examples/calculator.cr). Trace payload storage
   in [Result](../src/logos/result.cr) and the saved-result assertions in
   [the ergonomics specs](../spec/logos/ergonomics_spec.cr).
2. **Red.** Declare `regex "[0-9]+", :Integer, payload: Int64` with a block
   returning `lex.slice.to_i64`. Save the first result of lexing `42 7`,
   consume the second, and assert `Token.integer_value!(first) == 42`.
   Check the second value, a wrong variant, and an error result. Add
   compile-fail cases for an incompatible callback return type, conflicting
   payload types on the same variant, and a generated accessor name collision.
3. **Green.** Make the payload declaration opt in. Type-check the callback
   where it is invoked, box its value on the emitted result, and generate
   one variant-checked accessor per declared variant using `payload_for!`.
   Cover explicit Bool and Nil payloads and preserve existing filter, skip,
   and error behavior on untyped rules. Reuse the same contract for the
   corresponding regex annotation. Keep current wrapper-based callers valid.
4. Migrate the calculator integer rule and its parser together. Document the
   raw typed return and the existing fallible callback forms with examples.
   **Done when** runtime and prebuilt DSL results and annotated runtime results
   preserve saved payloads, the calculator example passes, and invalid typed
   declarations fail at compile time.

## Phase 11. Generate strict prebuild manifests from declarations

1. Follow [the extras declaration](../examples/extras.cr) through its
   [handwritten manifest](../examples/extras.logos.json), the
   [generator](../src/logos_codegen.cr), and the existing binding validator.
   Use Rust derive as the model for declaring each rule once. Crystal's
   deliverable is an export that the existing CLI can consume.
2. **Red.** Add a consumer fixture containing only a token declaration.
   Export its manifest, invoke the built CLI, compile the emitted matcher,
   and compare runtime and generated results on the same input. Check token
   identity, skipped input, callback payloads, error spans and EOF. Change a
   rule in the fixture, regenerate, and assert that the new behavior appears
   in both modes. Binding the old matcher to the edited declaration must fail.
3. **Green.** Expose evaluated rule metadata from the DSL in matcher rule-ID
   order. Export deterministic JSON including matcher name, encoding,
   subpatterns, rule kinds, exact text or byte arrays, case/greedy flags,
   priorities and explicitness, variants and skip actions. Enable strict
   binding. Keep callback execution in the consumer. Reuse CLI manifest
   parsing and emission and keep existing hand-authored manifests supported.
4. Document a runnable export/build command using a declaration-only source
   file so exporting does not start an example application's main routine.
   Exercise extras, custom errors, brainfuck and the benchmark with the new
   workflow before retiring duplicate inputs. Preserve the benchmark's
   resolved-priority semantics and the negative binding fixtures.
5. **Done when** a clean consumer can edit one declaration, regenerate, and
   pass the shipped contracts through the installed CLI without hand-editing
   JSON. Document which declaration styles support prebuilding.

## Verification and handoff

For each phase, start from the current parity handoff and a clean lint/test
baseline. Record the failing focused spec or compiler diagnostic before the
fix, then run it again after the fix. Run `make format`, `make lint`,
`make test`, `make test-prebuilt`, and `make test-package` for the public API
and generated/package paths above. Run `make markdown-check` for gated docs.
Refresh the affected inventory evidence and the current focus, next phase,
gate counts, and intentional Crystal differences in the parity plan. Include
the vendored Logos v0.16.1 revision `c7d40fa` and gate results in each
feature commit.
