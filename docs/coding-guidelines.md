# Coding Guidelines

## Crystal Conventions

### Naming

- **Classes and modules**: `CamelCase`
- **Methods and variables**: `snake_case`
- **Constants**: `SCREAMING_SNAKE_CASE`
- **Private methods**: Prefix with underscore `_private_method`
- **Predicate methods**: End with `?` (`valid?`, `empty?`)
- **Dangerous methods**: End with `!` when they modify receiver or raise

### Types

- Use Crystal's type system effectively
- Avoid unnecessary `as` casts
- Prefer union types over `nil` checks
- Use generic types when appropriate
- Document public API types with YARD comments

### Code Style

```crystal
# Good
def process_input(input : String) : Array(String)
  input.split('\n').map(&.strip)
end

# Bad
def process_input(input)
  input.split("\n").map { |x| x.strip }
end
```

## Porting Guidelines

### Rust to Crystal

1. **Match Rust logic exactly**:

   ```rust
   // Rust
   fn calculate(&self) -> Result<i32, Error> {
       Ok(self.value * 2)
   }
   ```

   ```crystal
   # Crystal
   def calculate : Int32
     @value * 2
   end
   ```

2. **Error handling**:
   - Rust `Result<T, E>` → Crystal exceptions or `Nil` union
   - Use `raise` for unrecoverable errors
   - Use `nil` return for optional results

3. **Ownership and borrowing**:
   - Rust references → Crystal references (automatic)
   - No need to manually manage lifetimes
   - Be mindful of mutable vs immutable

### Go to Crystal

1. **Interfaces**:

   ```go
   // Go
   type Reader interface {
       Read(p []byte) (n int, err error)
   }
   ```

   ```crystal
   # Crystal
   module Reader
     abstract def read(buffer : Bytes) : Int32
   end
   ```

2. **Error handling**:
   - Go `(T, error)` return → Crystal exceptions or `Nil` union
   - Use `raise` for fatal errors
   - Return `nil` for "not found" scenarios

3. **Concurrency**:
   - Go goroutines → Crystal fibers
   - Go channels → Crystal `Channel`
   - Go `sync` package → Crystal `Mutex`, `Atomic`

## Performance

### Zero-Copy Parsing

- Use `Slice(UInt8)` for input data
- Avoid string allocations when possible
- Use `String.build` for constructing output
- Prefer iterator methods over collecting arrays

### Memory Efficiency

```crystal
# Good - uses iterator
def process_lines(input : String)
  input.each_line do |line|
    yield line.strip
  end
end

# Bad - allocates array
def process_lines(input : String)
  input.lines.map(&.strip)
end
```

### DFA Optimization

- Minimize state transitions
- Use bitmasks for look-around assertions
- Cache computed values
- Avoid unnecessary object allocations in hot paths

## Testing Patterns

### Spec Structure

```crystal
describe Logos::Lexer do
  describe "#next" do
    it "returns next token" do
      lexer = Logos::Lexer.new("fn main")
      lexer.next.should eq :KeywordFn
    end

    it "handles EOF" do
      lexer = Logos::Lexer.new("")
      lexer.next.should be_nil
    end
  end
end
```

### Test Data

- Use `let` for shared setup
- Keep tests independent
- Test edge cases and error conditions
- Include property tests for complex logic

### Ported Tests

When porting Rust/Go tests:

```crystal
# Port Rust test exactly
it "matches Rust behavior for word boundaries" do
  # Original Rust assertion:
  # assert_eq!(look.is_word(), true);
  look.word?.should be_true
end

# Mark incomplete functionality as pending
pending "CRLF anchor handling" do
  # Test will be implemented later
end
```

## Documentation

### Code Comments

- Use YARD format for public APIs
- Explain why, not what
- Document edge cases and limitations
- Include examples for complex methods

```crystal
# Parses input string into tokens.
#
# @param input [String] The input to parse
# @return [Array(Token)] Array of parsed tokens
# @raise [ParseError] If input contains invalid tokens
def parse(input : String) : Array(Token)
  # implementation
end
```

### README and Guides

- Keep documentation up to date
- Include usage examples
- Document installation and setup
- Provide troubleshooting guide

## Code Organization

### File Structure

- One class/module per file (when reasonable)
- Group related functionality
- Separate concerns clearly
- Use `src/` for main code, `spec/` for tests

### Imports

```crystal
# Standard library first
require "json"
require "time"

# Dependencies second
require "regex-automata"

# Local requires last
require "./lexer"
require "./tokens"
```

### Module Organization

```crystal
module Logos
  # Core functionality
  module Lexer
    class Base
      # implementation
    end
  end

  # Supporting modules
  module Regex
    # regex utilities
  end
end
```

## Quality Gates

### Before Committing

1. **Format code**: `make format`
2. **Run linter**: `make lint`
3. **Run tests**: `make test`
4. **Check markdown**: `make markdown-check`

### Continuous Integration

- All tests must pass
- No linting errors
- Code must be properly formatted
- Documentation must be valid

## Exception Handling

### When to Raise

- Invalid input data
- Internal consistency errors
- Unsupported operations
- Resource exhaustion

### When to Return Nil

- Optional results
- "Not found" scenarios
- Skippable errors in lexers

### Error Types

```crystal
class ParseError < Exception
  property position : Int32

  def initialize(message, @position)
    super(message)
  end
end
```
