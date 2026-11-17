Logos.define ExportToken do
  subpattern :digit, "[0-9]", bytes: false
  skip_token " "
  token "let", :Let, priority: 10
  regex "(?&digit)+", :Integer, payload: Int32 do |lex|
    lex.slice.to_i32
  end
end
