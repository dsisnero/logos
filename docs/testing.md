# Testing

## Testing Strategy

### Philosophy

- **Test parity**: Match Rust/Go test behavior exactly
- **Behavioral correctness**: Ensure Crystal implementation matches source language
- **Comprehensive coverage**: Test edge cases and error conditions
- **Performance validation**: Verify performance characteristics are preserved

### Test Types

1. **Unit tests**: Individual functions and classes
2. **Integration tests**: Component interactions
3. **Property tests**: Randomized input validation
4. **Golden tests**: Output comparison against expected results
5. **Performance tests**: Benchmark critical paths

## Test Structure

### Spec Organization

```text
spec/
├── logos/           # Main lexer tests
│   ├── lexer_spec.cr
│   ├── macros_spec.cr
│   └── tokens_spec.cr
├── regex/           # Regex engine tests
│   ├── automata_spec.cr
│   └── syntax_spec.cr
├── integration/     # End-to-end tests
└── benchmarks/      # Performance tests
```

### Example Spec

```crystal
require "spec"
require "../src/logos"

describe Logos::Lexer do
  describe "#next" do
    it "returns tokens in order" do
      lexer = Logos.define(Token) do
        token "fn", :KeywordFn
        token "let", :KeywordLet
      end.new("fn let")

      lexer.next.should eq :KeywordFn
      lexer.next.should eq :KeywordLet
      lexer.next.should be_nil
    end

    it "handles regex patterns" do
      lexer = Logos.define(Token) do
        regex "[0-9]+", :Number
      end.new("123 456")

      lexer.next.should eq :Number
      lexer.callback_value.should eq "123"
    end
  end
end
```

## Porting Tests

### From Rust

When porting Rust tests from `vendor/regex-syntax/`:

1. **Find source tests**:

   ```bash
   grep -r "#\[test\]" vendor/regex-syntax/regex-automata/
   ```

2. **Understand test intent**:
   - Read Rust test comments
   - Trace through assertions
   - Note edge cases covered

3. **Port to Crystal**:

   ```rust
   // Rust test
   #[test]
   fn test_word_boundary() {
       let look = Look::Word;
       assert!(look.is_word());
   }
   ```

   ```crystal
   # Crystal spec
   it "detects word boundaries" do
     look = Regex::Automata::Look::Word
     look.word?.should be_true
   end
   ```

4. **Handle differences**:
   - Rust `Result` → Crystal exceptions/nil
   - Rust ownership → Crystal references
   - Rust macros → Crystal macros

### From Go

When porting Go tests from `vendor/go-colorful/`:

1. **Find source tests**:

   ```bash
   grep -r "func Test" vendor/go-colorful/
   ```

2. **Convert test tables**:

   ```go
   // Go test table
   func TestHexColor(t *testing.T) {
       tests := []struct{
           input string
           expected Color
       }{
           {"#ff0000", Color{R: 255}},
           {"#00ff00", Color{G: 255}},
       }

       for _, tt := range tests {
           got := HexColor(tt.input)
           if got != tt.expected {
               t.Errorf("HexColor(%q) = %v, want %v", tt.input, got, tt.expected)
           }
       }
   }
   ```

   ```crystal
   # Crystal spec with table
   describe ".hex_color" do
     test_cases = [
       {"#ff0000", Color.new(r: 255)},
       {"#00ff00", Color.new(g: 255)},
     ]

     test_cases.each do |input, expected|
       it "parses #{input}" do
         Color.hex_color(input).should eq expected
       end
     end
   end
   ```

3. **Handle floating-point precision**:
   - Go and Crystal may have different floating-point behavior
   - Use approximate comparisons: `value.should be_close(expected, delta)`
   - Document known precision differences

## Property Testing

### Using Spec::Property

```crystal
require "spec/property"

describe "String reversal" do
  it "reverses any string" do
    Spec::Property.of(String) do |string|
      reversed = string.reverse
      reversed.reverse.should eq string
    end
  end
end
```

### Custom Generators

```crystal
module TestGenerators
  def self.regex_pattern : Spec::Property::Generator(String)
    Spec::Property::Generator.of do |r|
      # Generate random regex patterns
      patterns = ["[a-z]+", "[0-9]{1,3}", "\\w+", "\\s*"]
      patterns.sample(random: r)
    end
  end
end

describe Logos::Lexer do
  it "handles generated regex patterns" do
    Spec::Property.of(TestGenerators.regex_pattern) do |pattern|
      lexer = Logos.define(Token) do
        regex pattern, :Pattern
      end.new("test")

      # Should not crash
      expect { lexer.next }.not_to raise_error
    end
  end
end
```

## Golden Tests

### Purpose

- Compare output against known-good results
- Detect behavioral regressions
- Ensure porting accuracy

### Implementation

```crystal
describe "DFA construction" do
  GOLDEN_PATH = "spec/golden/dfa_construction.txt"

  it "matches golden output" do
    dfa = build_dfa("[a-z]+")
    output = dfa.to_debug_string

    if File.exists?(GOLDEN_PATH)
      golden = File.read(GOLDEN_PATH)
      output.should eq golden
    else
      # First run - create golden file
      File.write(GOLDEN_PATH, output)
      pending "Created golden file for first run"
    end
  end
end
```

### Updating Golden Files

```bash
# Regenerate all golden files
rm spec/golden/*.txt
crystal spec spec/golden/
```

## Performance Testing

### Benchmarks

```crystal
require "benchmark"

describe "Lexer performance" do
  it "parses quickly" do
    lexer = create_complex_lexer
    input = "a" * 10000

    elapsed = Benchmark.measure do
      100.times { lexer.reset(input) }
    end

    elapsed.real.should be < 1.0  # Should complete in under 1 second
  end
end
```

### Memory Usage

```crystal
it "uses minimal memory" do
  initial_memory = GC.stats.heap_size

  1000.times do
    lexer = Logos::Lexer.new("test")
    lexer.next
  end

  GC.collect
  final_memory = GC.stats.heap_size

  memory_growth = final_memory - initial_memory
  memory_growth.should be < 1_000_000  # Less than 1MB growth
end
```

## Integration Testing

### End-to-End Tests

```crystal
describe "Full lexer pipeline" do
  it "parses a simple language" do
    lexer = define_simple_language.new(<<-CODE)
      fn main() {
        let x = 42;
        print(x);
      }
    CODE

    tokens = [] of Token
    while token = lexer.next
      tokens << token
    end

    tokens.should eq [
      :KeywordFn, :Identifier, :LParen, :RParen,
      :LBrace, :KeywordLet, :Identifier, :Equal,
      :Number, :Semicolon, :Identifier, :LParen,
      :Identifier, :RParen, :Semicolon, :RBrace
    ]
  end
end
```

### Cross-Language Validation

```crystal
it "matches Rust Logos output" do
  # Test case from Rust Logos repository
  input = "fn main() { let x = 123; }"

  # Crystal implementation
  crystal_tokens = parse_with_crystal_logos(input)

  # Expected from Rust (would need actual Rust binary)
  # rust_tokens = `cargo run --example simple -- "#{input}"`

  # For now, use hardcoded expected values from Rust tests
  expected = [:KeywordFn, :Identifier, :LParen, :RParen, :LBrace,
              :KeywordLet, :Identifier, :Equal, :Number, :Semicolon, :RBrace]

  crystal_tokens.should eq expected
end
```

## Test Utilities

### Helpers

```crystal
module TestHelpers
  def self.create_lexer(*tokens)
    Logos.define(Token) do
      tokens.each do |(pattern, name)|
        if pattern.starts_with?('/') && pattern.ends_with?('/')
          regex pattern[1...-1], name
        else
          token pattern, name
        end
      end
    end
  end

  def self.tokenize(lexer_class, input)
    lexer = lexer_class.new(input)
    tokens = [] of Symbol
    while token = lexer.next
      tokens << token
    end
    tokens
  end
end
```

### Fixtures

```crystal
module TestFixtures
  SIMPLE_CODE = <<-CRYSTAL
    def hello
      puts "world"
    end
  CRYSTAL

  COMPLEX_REGEX = %r{
    \b(?:func|def|proc)\b          # Function keyword
    \s+                            # Whitespace
    ([a-zA-Z_][a-zA-Z0-9_]*)       # Function name
    }x
end
```

## Running Tests

### Basic Commands

```bash
# Run all tests
make test

# Run specific test file
crystal spec spec/logos/lexer_spec.cr

# Run with verbose output
crystal spec -v

# Run tests matching pattern
crystal spec -e "word boundary"
```

### CI Configuration

```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: crystal-lang/install-crystal@v1
      - run: make install
      - run: make format
      - run: make lint
      - run: make test
```

## Debugging Tests

### Verbose Output

```bash
# Show test names as they run
crystal spec -v

# Show backtrace for failures
crystal spec --backtrace

# Stop on first failure
crystal spec --fail-fast
```

### Debugging Specific Tests

```crystal
it "debug failing test" do
  lexer = create_test_lexer

  # Add debug output
  puts "Lexer state: #{lexer.inspect}"

  token = lexer.next
  puts "First token: #{token.inspect}"

  token.should eq :ExpectedToken
end
```

### Test Isolation

```crystal
# Run single test
crystal spec spec/logos/lexer_spec.cr:25

# Run specific describe block
crystal spec spec/logos/lexer_spec.cr -e "describe #next"
```
