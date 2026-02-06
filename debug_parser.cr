require "./src/logos"
parser = Logos::PatternParser::Parser.new("(ab)", true, false)
ast = parser.parse
puts "AST class: #{ast.class}"
puts "AST: #{ast.inspect}"
