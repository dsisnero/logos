# Pull Request Workflow

## Overview

This document outlines the process for contributing changes through PRs.
The workflow ensures code quality and follows Crystal best practices.

## PR Lifecycle

### 1. Pre-PR Preparation

#### Branch Strategy

- **Main branch**: `main` (protected)
- **Feature branches**: `feat/description` (e.g., `feat/look-around-assertions`)
- **Fix branches**: `fix/issue-description` (e.g., `fix/dfa-memory-leak`)
- **Docs branches**: `docs/topic` (e.g., `docs/api-reference`)

#### Before Creating a PR

1. **Sync with main**:

   ```bash
   git checkout main
   git pull --rebase
   git checkout -b feat/feature-name
   ```

2. **Run quality gates**:

   ```bash
   make format
   make lint
   make test
   make markdown-check
   ```

3. **Verify changes**:
   - All tests pass
   - No linting errors
   - Code is properly formatted
   - Documentation is updated if needed

### 2. Creating a PR

#### PR Title Format

```text
type(scope): description
```

**Types**:

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Test changes
- `chore`: Maintenance tasks

**Examples**:

- `feat(regex): add look-around assertion support`
- `fix(lexer): handle UTF-8 boundary errors`
- `docs(api): update callback_value documentation`

#### PR Description Template

```markdown
## Summary

Brief description of changes (1-3 sentences).

## Changes

- Change 1: Description
- Change 2: Description
- Change 3: Description

## Testing

- [ ] All existing tests pass
- [ ] New tests added for functionality
- [ ] Tests ported from Rust/Go (if applicable)
- [ ] Performance tested (if applicable)

## Verification

- [ ] Code follows Crystal conventions
- [ ] Matches Rust Logos behavior (for ports)
- [ ] Documentation updated if needed
- [ ] No breaking changes (or documented if intentional)

## Related Issues

Closes #123, References #456
```

#### Creating the PR

```bash
# Push branch
git push -u origin feat/feature-name

# Create PR using GitHub CLI
gh pr create --title "feat(scope): description" --body-file pr_description.md

# Or through GitHub UI
open https://github.com/dsisnero/logos/compare
```

### 3. PR Review Process

#### Review Checklist

**Code Reviewer Should Verify**:

- [ ] **Behavioral parity**: Changes match Rust Logos behavior (for ports)
- [ ] **Code quality**: Follows Crystal conventions and project guidelines
- [ ] **Test coverage**: Adequate tests for new/changed functionality
- [ ] **Performance**: No significant performance regressions
- [ ] **Documentation**: APIs are properly documented
- [ ] **Edge cases**: Error conditions and boundary cases handled
- [ ] **Backward compatibility**: No breaking changes without migration path

#### Review Comments

- Use GitHub's review feature with "Request changes" or "Approve"
- Be specific about what needs to change
- Reference relevant code sections
- Suggest concrete improvements

#### Addressing Feedback

1. **Acknowledge comments**: Respond to each review comment
2. **Make changes**: Update code based on feedback
3. **Push updates**: Commit and push changes

   ```bash
   git add .
   git commit -m "address review feedback"
   git push
   ```

4. **Re-request review**: Mark conversation as resolved and re-request review

### 4. PR Approval and Merge

#### Approval Criteria

- At least one maintainer approval
- All CI checks pass
- No outstanding review comments
- PR description complete
- Changes are ready for merge

#### Merge Strategy

```bash
# Rebase onto main before merging
git checkout feat/feature-name
git pull --rebase origin main

# Resolve any conflicts
# Run quality gates again
make format
make lint
make test

# Push updates
git push --force-with-lease

# Merge via GitHub UI or CLI
gh pr merge --squash
```

#### Post-Merge

1. **Delete branch** (optional):

   ```bash
   git branch -d feat/feature-name
   git push origin --delete feat/feature-name
   ```

2. **Update local main**:

   ```bash
   git checkout main
   git pull
   ```

3. **Create follow-up issues** if needed

## Special Cases

### Porting from Rust/Go

#### Additional Requirements

1. **Source reference**: Include link to Rust/Go source code
2. **Test parity**: Demonstrate that tests match source behavior
3. **Performance comparison**: Show no significant performance regression
4. **Behavioral verification**: Confirm edge cases handled identically

#### PR Description Addendum

```markdown
## Porting Details

**Source**: [Rust Logos regex-automata/src/util/look.rs](https://github.com/rust-lang/regex/blob/main/regex-automata/src/util/look.rs)

**Changes ported**:

- `Look` enum variants
- `LookSet` bitmask operations
- `is_word_byte` utility function

**Behavioral verification**:

- [ ] All Rust tests ported and passing
- [ ] Edge cases match Rust implementation
- [ ] Performance within 10% of Rust version

**Differences from source**:

- Crystal enum doesn't support payloads, using callback system
- Error handling uses exceptions instead of Result types
```

### Breaking Changes

#### When Allowed

- Major version updates
- Critical bug fixes requiring API change
- Alignment with Rust Logos breaking changes

#### Requirements

1. **Migration path**: Provide upgrade instructions
2. **Deprecation warnings**: Mark old APIs as deprecated
3. **Version bump**: Update `shard.yml` version
4. **CHANGELOG entry**: Document breaking change

#### PR Description Addendum

```markdown
## Breaking Changes

**Changed APIs**:

- `Lexer#callback_value` renamed to `Lexer#token_value`
- `Logos.define` now requires error_type parameter

**Migration path**:

1. Update method calls from `callback_value` to `token_value`
2. Add `error_type Nil` to `Logos.define` blocks
3. See `MIGRATION.md` for complete instructions

**Deprecation timeline**:

- Old APIs deprecated in v1.2.0
- Will be removed in v2.0.0
```

### Performance-Sensitive Changes

#### Requirements

1. **Benchmarks**: Include before/after performance measurements
2. **Profiling data**: Show performance impact analysis
3. **Memory usage**: Verify no memory leaks or regressions
4. **Trade-offs**: Document any readability/maintainability trade-offs

#### Verification Commands

```bash
# Run benchmarks
crystal run --release benchmarks/lexer_benchmark.cr

# Profile memory usage
valgrind --leak-check=full ./benchmark

# Compare performance
./benchmark --compare
```

## CI/CD Pipeline

### Automated Checks

- **Formatting**: `crystal tool format --check`
- **Linting**: `ameba src spec`
- **Testing**: `crystal spec`
- **Documentation**: `rumdl check . --check`
- **Build verification**: `crystal build examples/simple.cr`

### Manual Checks

- **Behavioral parity**: Verify against Rust/Go implementations
- **API consistency**: Check public API follows Crystal conventions
- **Documentation quality**: Review updated documentation
- **Example verification**: Test examples still work

### Failed CI

1. **Investigate failure**: Check CI logs for specific errors
2. **Reproduce locally**: Run failing commands locally
3. **Fix issues**: Address root cause, not just symptoms
4. **Push fixes**: Commit and push changes
5. **Re-run CI**: Wait for CI to complete

## Code Review Guidelines

### For Reviewers

- **Be constructive**: Focus on code, not person
- **Be specific**: Reference exact lines and suggest fixes
- **Consider trade-offs**: Balance perfection with practicality
- **Check fundamentals**: Verify behavioral parity and correctness first
- **Respect time**: Respond within 48 hours when possible

### For Authors

- **Be responsive**: Address feedback promptly
- **Be open**: Consider suggestions even if you disagree
- **Be thorough**: Fix all issues, not just some
- **Be patient**: Reviews take time, especially for complex changes
- **Be grateful**: Thank reviewers for their time

## PR Templates

### Feature PR Template

Save as `.github/pull_request_template.md`:

```markdown
## Summary
<!-- Brief description of changes -->

## Changes
<!-- List of specific changes -->

## Testing

- [ ] All existing tests pass
- [ ] New tests added
- [ ] Performance tested
- [ ] Edge cases covered

## Verification

- [ ] Follows Crystal conventions
- [ ] Matches Rust behavior (if port)
- [ ] Documentation updated
- [ ] No breaking changes

## Related Issues
<!-- Closes #123, References #456 -->
```

### Bug Fix PR Template

```markdown
## Problem

<!-- Describe the bug -->

## Solution

<!-- Describe the fix -->

## Testing

- [ ] Bug reproduction test added
- [ ] All existing tests pass
- [ ] Edge cases tested

## Verification

- [ ] Fix addresses root cause
- [ ] No regression introduced
- [ ] Performance impact assessed

## Related Issues

Closes #123
```

## Best Practices

### Commit Messages

- Use conventional commit format
- Keep commits focused and atomic
- Reference issues when applicable
- Write clear, descriptive messages

### Code Changes

- Make minimal necessary changes
- Follow existing patterns and conventions
- Add tests for new functionality
- Update documentation as needed

### Communication

- Use PR comments for discussion
- Tag relevant reviewers
- Update PR description if scope changes
- Close PR if superseded or abandoned

### Quality Assurance

- Test locally before pushing
- Verify CI passes before requesting review
- Address all feedback before merging
- Clean up branch after merge

## Troubleshooting

### Common Issues

**CI failing on formatting**:

```bash
crystal tool format
git add .
git commit -m "style: format code"
git push
```

**Tests failing after rebase**:

```bash
make update  # Update dependencies
make test    # Run tests
```

**Merge conflicts**:

```bash
git pull --rebase origin main
# Resolve conflicts
git add .
git rebase --continue
git push --force-with-lease
```

**Review taking too long**:

- Ping reviewers after 48 hours
- Ensure PR is ready for review (all checks pass)
- Consider breaking large PRs into smaller ones

### Getting Help

- Ask in PR comments
- Tag maintainers (@dsisnero)
- Reference related issues/PRs
- Provide reproduction steps for issues
