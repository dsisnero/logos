require "./regex/syntax/hir"

module Regex::Syntax
  VERSION = "0.1.0"

  # Main entry point for parsing regular expressions
  def self.parse(pattern : String, **options) : Hir::Hir
    parser = Parser.new(**options)
    parser.parse(pattern)
  end

  # Abstract syntax tree representation
  module AST
    # TODO: Implement AST types
  end

  # Parser for converting regex strings to AST/HIR
  class Parser
    def initialize(*, unicode : Bool = true, ignore_case : Bool = false, nest_limit : Int32? = nil)
      @unicode = unicode
      @ignore_case = ignore_case
      @nest_limit = nest_limit
    end

    def parse(pattern : String) : Hir::Hir
      # TODO: Implement parsing
      raise "Not implemented"
    end
  end

  # Error types
  class Error < Exception
  end

  class ParseError < Error
  end
end