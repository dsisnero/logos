class AnonymousSkipExtras
  property newlines = 0
end

Logos.define AnonymousSkipToken do
  extras AnonymousSkipExtras
  skip_regex "[ ]+"
  skip_regex "\n" do |lexer|
    lexer.extras.newlines += 1
    Logos::Skip.new
  end
  regex "[a-z]", :Word
end
