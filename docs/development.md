# Development

## Setup

### Prerequisites

- Crystal 1.11+ (check with `crystal --version`)
- Git
- Make

### Installation

```bash
# Clone the repository
git clone https://github.com/dsisnero/logos.git
cd logos

# Install dependencies
make install
```

### Development Dependencies

- **ameba**: Crystal linter (`brew install ameba` or `shards install ameba`)
- **rumdl**: Markdown formatter (`brew install rumdl` or `shards install rumdl`)

## Workflow

### Daily Development

1. **Sync with upstream**:

   ```bash
   git pull --rebase
   make update
   ```

2. **Run quality gates** (before committing):

   ```bash
   make format
   make lint
   make test
   make markdown-check
   ```

3. **Create feature branch**:

   ```bash
   git checkout -b feat/feature-name
   ```

### Porting from Rust

When porting code from Rust (`vendor/regex-syntax/`):

1. **Examine Rust source first**:

   ```bash
   # Find relevant Rust code
   grep -r "function_name" vendor/regex-syntax/
   ```

2. **Understand the algorithm**:
   - Read Rust documentation
   - Trace through test cases
   - Note performance characteristics

3. **Port to Crystal**:
   - Match Rust logic exactly
   - Adapt to Crystal idioms
   - Preserve performance characteristics

4. **Write tests**:
   - Port Rust tests exactly
   - Add Crystal-specific edge cases
   - Ensure behavioral parity

### Porting from Go

When porting code from Go (`vendor/go-colorful/`):

1. **Examine Go source**:

   ```bash
   grep -r "functionName" vendor/go-colorful/
   ```

2. **Handle type differences**:
   - Go interfaces → Crystal modules
   - Go structs → Crystal classes/structs
   - Go error handling → Crystal exceptions

3. **Test porting**:
   - Convert Go test tables to Crystal specs
   - Maintain exact assertions
   - Handle floating-point precision differences

## Debugging

### Lexer Debugging

```bash
# Enable debug logging
LOGOS_DEBUG=1 crystal run examples/simple.cr

# Debug DFA construction
LOGOS_DEBUG_DFA_BUILD=1 crystal spec
```

### Performance Profiling

```bash
# Build with debug symbols
crystal build --debug examples/simple.cr

# Run with perf (Linux)
perf record ./simple
perf report
```

### Memory Analysis

```bash
# Build with memory profiling
crystal build --release --no-debug examples/simple.cr

# Use valgrind (Linux/macOS)
valgrind --leak-check=full ./simple
```

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run specific test file
crystal spec spec/logos/lexer_spec.cr

# Run with verbose output
crystal spec -v

# Run with fail-fast
crystal spec --fail-fast
```

### Test Patterns

- **Unit tests**: Test individual functions and classes
- **Integration tests**: Test lexer generation and usage
- **Property tests**: Use Crystal's `Spec::Property` for randomized testing
- **Golden tests**: Compare output against expected results

### Test Porting Guidelines

When porting tests from Rust/Go:

1. **Exact assertions**: Don't adjust expected values
2. **Test structure**: Convert test tables to Crystal `it` blocks
3. **Pending tests**: Mark incomplete functionality as `pending`
4. **Edge cases**: Include all original edge cases

## Code Quality

### Formatting

```bash
# Check formatting
make format

# Auto-format (if tool supports it)
crystal tool format
```

### Linting

```bash
# Run linter with auto-fix
ameba --fix

# Verify linting
ameba
```

### Documentation

```bash
# Format markdown
make markdown

# Check markdown formatting
make markdown-check
```

## Release Process

1. **Update version** in `shard.yml`
2. **Run full test suite**:

   ```bash
   make clean
   make install
   make test
   ```

3. **Update CHANGELOG.md** with changes
4. **Create git tag**:

   ```bash
   git tag v1.2.3
   git push --tags
   ```

5. **Publish to GitHub Releases**

## Troubleshooting

### Common Issues

**"Shard not found"**:

```bash
make update
```

**"Formatting errors"**:

```bash
crystal tool format
```

**"Linter errors"**:

```bash
ameba --fix
ameba
```

**"Tests failing"**:

- Check test output for specific failures
- Verify ported logic matches source
- Ensure dependencies are up to date
