Logos.define TextPrefixToken do
  error_type String do |lex|
    lex.slice
  end
  token "!", :Mark
  token "aéx", :Unicode
  token "abc", :Ascii
end

Logos.define BytePrefixToken do
  utf8 false
  error_type String do |lex|
    String.new(lex.slice)
  end
  token "!", :Mark
  token "abc", :Ascii
end

Logos.define RuntimePrefixToken do
  token "!", :Mark
  token "aéx", :Unicode
  token "abc", :Ascii
end

@[Logos::Token(:Mark, "!")]
@[Logos::Token(:Unicode, "aéx")]
@[Logos::Token(:Ascii, "abc")]
enum AnnotatedPrefixToken
  Mark
  Unicode
  Ascii
end
logos_derive(AnnotatedPrefixToken)

{% for type in [TextPrefixToken, BytePrefixToken] %}
  {% bytes = type.id == "BytePrefixToken".id %}
  source = {% if bytes %} "!ab?ab".to_slice {% else %} "!aê?ab" {% end %}
  expected = {% if bytes %}
    [{"ab", 1...3}, {"?", 3...4}, {"ab", 4...6}]
  {% else %}
    [{"aê", 1...4}, {"?", 4...5}, {"ab", 5...7}]
  {% end %}
  raise "generated matcher did not register" unless {{ type }}.precompiled_dfa?
  lexer = {{ type }}.lexer(source)
  stream = lexer.spanned
  raise "did not accept the opening marker" unless stream.next == {Logos::Result({{ type }}, String).ok({{ type }}::Mark), 0...1}
  expected.each do |slice, span|
    actual = stream.next
    raise "wrong generated error #{actual.inspect}, expected #{slice.inspect} #{span}" unless actual == {Logos::Result({{ type }}, String).error(slice), span}
  end
  raise "expected generated EOF" unless stream.next == Iterator::Stop::INSTANCE
{% end %}

{% for type in [RuntimePrefixToken, AnnotatedPrefixToken] %}
  errors = {{ type }}.lexer("!aê?ab").spanned.to_a.select { |result, _| result.error? }
  raise "wrong runtime error spans #{errors.inspect}" unless errors.map(&.[1]) == [1...4, 4...5, 5...7]
{% end %}

Logos.define GeneratedTextEndToken do
  token "b", :B
  regex "a$", :Final
end

Logos.define GeneratedLineEndToken do
  token "\n", :Newline
  regex "(?m)a$", :Final
end

raise "text-end matcher did not register" unless GeneratedTextEndToken.precompiled_dfa?
raise "line-end matcher did not register" unless GeneratedLineEndToken.precompiled_dfa?

text = GeneratedTextEndToken.lexer("ab").spanned.to_a
raise "incorrect generated text-end tokens #{text.inspect}" unless text.map { |result, span| {result.value?, span} } == [
                                                                     {nil, 0...1}, {GeneratedTextEndToken::B, 1...2},
                                                                   ]
text = GeneratedTextEndToken.lexer("ba").spanned.to_a
raise "incorrect generated EOF tokens #{text.inspect}" unless text.map { |result, span| {result.value?, span} } == [
                                                                {GeneratedTextEndToken::B, 0...1}, {GeneratedTextEndToken::Final, 1...2},
                                                              ]
line = GeneratedLineEndToken.lexer("a\na").spanned.to_a
raise "incorrect generated line-end tokens #{line.inspect}" unless line.map { |result, span| {result.value?, span} } == [
                                                                     {GeneratedLineEndToken::Final, 0...1}, {GeneratedLineEndToken::Newline, 1...2}, {GeneratedLineEndToken::Final, 2...3},
                                                                   ]
