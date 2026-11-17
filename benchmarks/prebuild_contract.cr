require "../src/logos"
require "../temp/generated_benchmark_token"

Logos.define BenchmarkToken do
  skip_regex "[ \t\r\n]+", :Whitespace
  token "let", :Let
  token "=", :Equals
  token ";", :Semicolon
  regex "[A-Za-z_][A-Za-z0-9_]*", :Identifier
  regex "[0-9]+", :Integer
end

Logos.define OracleToken do
  skip_regex "[ \t\r\n]+", :Whitespace
  token "let", :Let
  token "=", :Equals
  token ";", :Semicolon
  regex "[A-Za-z_][A-Za-z0-9_]*", :Identifier
  regex "[0-9]+", :Integer
end

raise "strict benchmark binding missing" unless Logos.generated_matcher_binding?("BenchmarkToken")

["let variable = 12345;\n", "letter let let1 _a 0;", "é = ? 99", "", " \n\t"].each do |source|
  generated = BenchmarkToken.lexer(source)
  oracle = OracleToken.lexer(source)
  loop do
    left = generated.next
    right = oracle.next
    if left.is_a?(Iterator::Stop) || right.is_a?(Iterator::Stop)
      raise "stop mismatch" unless left.is_a?(Iterator::Stop) && right.is_a?(Iterator::Stop)
      break
    end
    raise "span mismatch" unless generated.span == oracle.span
    raise "error mismatch" unless left.ok? == right.ok?
    raise "variant mismatch" if left.ok? && left.unwrap.to_s != right.unwrap.to_s
  end
end
puts "generated/runtime contract passed"
