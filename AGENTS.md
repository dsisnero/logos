# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Issue Tracking Workflow

**DO NOT use internal todo list or task list tools** - Use beads for all issue tracking and work management:

1. **Strategic, multi-session work**: Track in beads using `bd create`
2. **Dependencies and blockers**: Use `bd dep add` to link issues
3. **Session planning**: Use `bd ready` to find unblocked work
4. **Progress tracking**: Use `bd update <id> --status in_progress` when starting, `bd close <id>` when complete

**When creating multiple tasks**: Use parallel subagents for efficiency with `bd create` commands.

**Example workflow**:

```bash
# Create issues for test porting
bd create --title="Port color conversion tests from Go to Crystal spec" --type=task --priority=2
bd create --title="Port color space tests from Go to Crystal spec" --type=task --priority=2
bd create --title="Port blending tests from Go to Crystal spec" --type=task --priority=2

# Claim work
bd update beads-xxx --status=in_progress

# Complete work
bd close beads-xxx beads-yyy beads-zzz
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
   * **Crystal-specific quality gates**:

      ```bash
      crystal tool format
      ameba --fix
      ameba
      crystal spec

    ```text

    * **other gates**
      - rumdl format

      Ensure no formatting issues remain, all ameba errors are fixed, and all tests pass before committing.
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:

   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```

5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**

* Work is NOT complete until `git push` succeeds
* NEVER stop before pushing - that leaves work stranded locally
* NEVER say "ready to push when you are" - YOU must push
* If push fails, resolve and retry until it succeeds

## Crystal Development Guidelines

This project ports code from multiple source languages:
- **Go code** from `vendor/go-colorful` (color library)
- **Rust code** from `vendor/regex-syntax/` (regex-automata library)

Follow Crystal idioms and best practices:

* Use Crystal's built-in formatter: `crystal tool format`
* Use ameba for linting: `ameba --fix` then `ameba` to verify
* Prefer Crystal's standard library over custom implementations
* Use Crystal's type system effectively (avoid unnecessary `as` casts)
* Follow Crystal naming conventions (snake_case for methods/variables, CamelCase for classes)
* Write specs for new functionality using Crystal's built-in spec framework

### Test Porting Guidelines

When porting Go tests to Crystal specs:

1. **Port test logic exactly** - Don't adjust test assertions or expected values
2. **Use Crystal idioms for structure** - Convert Go test tables to Crystal `it` blocks
3. **Mark missing functionality as pending** - Use `pending` for tests that can't run yet
4. **Follow Go test patterns** - Maintain the same test coverage and edge cases
5. **Verify against Go implementation** - Ensure Crystal behavior matches Go exactly

 Example: If a Go test expects color conversions to produce specific values, replicate that check in Crystal even if Crystal's floating-point handling produces slightly different output.

## Regex-Automata Port (Rust Source)

**Current focus**: Porting regex-automata library from Rust to Crystal for look-around assertions (`^`, `$`, `\b`, `\B`, `\A`, `\z`, `\Z`).

**Source of truth**: Rust implementation in `vendor/regex-syntax/`. The Rust code is the authoritative reference.

**Critical rules**:
1. **Match Rust logic exactly** - Do not invent new approaches or algorithms
2. **Test logic must match Rust tests exactly** - Replicate test assertions and expected values
3. **Consult Rust source first** - Always examine the corresponding Rust code in `vendor/` before implementing
4. **Preserve performance characteristics** - The port should have similar performance to Rust version

**Rust source locations**:
- Core regex-automata: `vendor/regex-syntax/regex-automata/src/`
- NFA/DFA implementation: `vendor/regex-syntax/regex-automata/src/util/determinize/`
- Look-around assertions: `vendor/regex-syntax/regex-automata/src/util/look.rs`
- UTF-8 utilities: `vendor/regex-syntax/regex-automata/src/util/utf8.rs`

**Current implementation status**:
- ✅ Look and LookSet types ported (`lib/regex-automata/src/regex/automata/look.cr`)
- ✅ `is_word_byte` utility for ASCII word detection
- ✅ DFA state tracks `is_from_word` and `is_half_crlf` flags
- ⏳ DFA builder computes word boundary assertions (partial)
- ❌ CRLF anchor handling not implemented
- ❌ LookSet integration incomplete (still using UInt8 bitmask)
- ❌ DFA matching algorithm needs EOI transition updates

**Next steps reference**:
- `logos-44y`: Update DFA state to use LookSet instead of UInt8 bitmask
- `logos-zz7`: Implement start assertion handling in DFA builder (`^`, `\A`)
- `logos-b4r`: Implement CRLF anchor handling (multiline mode)
- `logos-y3y`: Update DFA matching algorithm to respect look-around assertions (EOI transitions)
- `logos-w4c`: Update DFA state to track `look_have` and `look_need` like Rust
- `logos-997`: Implement proper determinization with look-around assertion updates

**Rust reference functions**:
- `determinize::next()`: Main transition logic (`vendor/regex-syntax/regex-automata/src/util/determinize/mod.rs:92`)
- `epsilon_closure()`: Epsilon closure with look assertions (`vendor/regex-syntax/regex-automata/src/util/determinize/mod.rs:369`)
- `LookSet` operations: Bitmask-based assertion sets (`vendor/regex-syntax/regex-automata/src/util/look.rs`)

**Testing strategy**:
1. All existing tests must continue to pass
2. Look-around assertion tests should match Rust regex-automata test behavior
3. Use `LOGOS_DEBUG_DFA_BUILD` env var for DFA construction debugging
4. Verify DFA states match Rust's determinization output
