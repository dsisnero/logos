Logos.define ReorderedBindingToken do
  token "b", :B
  token "a", :A
end

Logos.define KindBindingToken do
  token "a", :A
end

Logos.define SkipBindingToken do
  token "a", :A
end

Logos.define EncodingBindingToken do
  utf8 false
  token "a", :A
end

Logos.define RuleEncodingBindingToken do
  utf8 false
  regex ".", :A, bytes: false
end

Logos.define OptionsBindingToken do
  token "a", :A, ignore_case: true
end

Logos.define VariantBindingToken do
  token "a", :B
end

Logos.define SubpatternBindingToken do
  subpattern :digit, "[1-9]"
  regex "(?&digit)", :Number
end

{% for type, field in {ReorderedBindingToken => "rule 0", KindBindingToken => "kind", SkipBindingToken => "skip", EncodingBindingToken => "utf8", RuleEncodingBindingToken => "unicode", OptionsBindingToken => "ignore_case", VariantBindingToken => "variant", SubpatternBindingToken => "subpattern"} %}
  begin
    {{ type }}.lexer({% if type == EncodingBindingToken || type == RuleEncodingBindingToken %} "a".to_slice {% else %} "a" {% end %}).next
    raise "expected binding mismatch for #{ {{ type.stringify }} }"
  rescue error
    message = error.message || ""
    raise error unless message.includes?("Generated matcher binding") && message.includes?({{ field }})
  end
{% end %}

Logos.define BoundToken do
  regex "[0-9]+", :Number do |lex|
    Logos::Filter::Emit.new(lex.slice.to_i)
  end
  skip_token " ", :Space
  token "+", :Plus
end

Logos.define BoundResolvedToken do
  regex "[0-9]+", :Number do |lex|
    Logos::Filter::Emit.new(lex.slice.to_i)
  end
  skip_token " ", :Space
  token "+", :Plus
end

Logos.define UnboundOracle do
  regex "[0-9]+", :Number do |lex|
    Logos::Filter::Emit.new(lex.slice.to_i)
  end
  skip_token " ", :Space
  token "+", :Plus
end

{% for type in [BoundToken, BoundResolvedToken] %}
  generated = {{ type }}.lexer("12 + 34")
  oracle = UnboundOracle.lexer("12 + 34")
  generated_results = generated.spanned.to_a
  oracle_results = oracle.spanned.to_a
  raise "generated matcher is not registered" unless {{ type }}.precompiled_dfa?
  raise "binding stream differs" unless generated_results.map { |result, span| {result.unwrap.to_s, span, result.payload_for(result.unwrap, Int32)} } ==
                                       oracle_results.map { |result, span| {result.unwrap.to_s, span, result.payload_for(result.unwrap, Int32)} }
{% end %}

Logos.define ByteArrayBoundToken do
  utf8 false
  subpattern :digit, %q(\d), bytes: false
  regex "~(?&digit)", :Digit
  token "\xFF", :Mark
end

byte_stream = ByteArrayBoundToken.lexer(Bytes[0xFF, 0x7E, 0xD9, 0xA1]).spanned.to_a
raise "byte binding payload differs" unless byte_stream == [
                                              {Logos::Result(ByteArrayBoundToken, Nil).ok(ByteArrayBoundToken::Mark), 0...1},
                                              {Logos::Result(ByteArrayBoundToken, Nil).ok(ByteArrayBoundToken::Digit), 1...4},
                                            ]

matcher = Logos.generated_matcher?("BoundToken") || raise "missing registered matcher"
Logos.register_generated_matcher("BoundToken", matcher,
  binding: Logos::GeneratedBinding.new(true, [] of Hash(String, String), [] of {String, String, Bool}))
begin
  BoundToken.lexer("12").next
  raise "replacement binding was not validated"
rescue error
  raise error unless error.message.try(&.includes?("rule count"))
end
