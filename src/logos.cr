# Logos - Create ridiculously fast Lexers
#
# See https://logos.maciej.codes/ for documentation and examples.
require "./logos/result"
require "./logos/source"
require "./logos/lexer"
require "./logos/pattern"
require "./logos/annotations"
require "./logos/define_macro"
require "./logos/macros"

module Logos
  VERSION = "0.1.0"

  # Predefined callback that will inform the `Lexer` to skip a definition.
  def self.skip(lexer : Lexer(T)) : Skip forall T
    Skip.new
  end
end
