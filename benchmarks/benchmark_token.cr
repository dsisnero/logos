require "../src/logos"

macro define_benchmark_token(name)
  Logos.define {{ name }} do
    skip_regex "[ \t\r\n]+", :Whitespace
    token "let", :Let
    token "=", :Equals
    token ";", :Semicolon
    regex "[A-Za-z_][A-Za-z0-9_]*", :Identifier
    regex "[0-9]+", :Integer
  end
end

define_benchmark_token(BenchmarkToken)
