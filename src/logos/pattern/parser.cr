module Logos
  module PatternParser
    class Parser
      @input : String
      @pos : Int32
      @unicode : Bool
      @ignore_case : Bool

      def initialize(@input : String, @unicode : Bool = true, @ignore_case : Bool = false)
        @pos = 0
      end

      def parse : PatternAST::Node
        parse_alternation
      end

      private def parse_alternation : PatternAST::Node
        # Parse concatenation sequences separated by |
        terms = [] of PatternAST::Node
        terms << parse_concatenation

        while current_char == '|'
          advance # skip '|'
          terms << parse_concatenation
        end

        if terms.size == 1
          terms.first
        else
          PatternAST::Alternation.new(terms)
        end
      end

      private def parse_concatenation : PatternAST::Node
        # Parse sequence of atoms
        atoms = [] of PatternAST::Node

        while !eof? && current_char != '|' && current_char != ')'
          atom = parse_atom
          atoms << atom unless atom.is_a?(PatternAST::Empty)
        end

        case atoms.size
        when 0
          PatternAST::Empty.new
        when 1
          atoms.first
        else
          PatternAST::Concat.new(atoms)
        end
      end

      private def parse_atom : PatternAST::Node
        parse_quantified
      end

      private def parse_quantified : PatternAST::Node
        atom = parse_primary

        case current_char
        when '*', '+', '?', '{'
          min, max, greedy = parse_repetition_spec
          PatternAST::Repetition.new(atom, min, max, greedy)
        else
          atom
        end
      end

      private def parse_repetition_spec : {Int32, Int32?, Bool}
        case current_char
        when '*'
          advance
          {0, nil, check_greedy_flag}
        when '+'
          advance
          {1, nil, check_greedy_flag}
        when '?'
          advance
          {0, 1, check_greedy_flag}
        when '{'
          advance # skip '{'
          min = parse_number

          if current_char == ','
            advance # skip ','
            if current_char == '}'
              # {n,} - unbounded max
              advance # skip '}'
              {min, nil, check_greedy_flag}
            else
              # {n,m}
              max = parse_number
              if current_char == '}'
                advance # skip '}'
                {min, max, check_greedy_flag}
              else
                # Error: expected '}'
                {min, min, true}
              end
            end
          elsif current_char == '}'
            # {n}
            advance # skip '}'
            {min, min, check_greedy_flag}
          else
            # Error: expected ',' or '}'
            {min, min, true}
          end
        else
          {0, nil, true}
        end
      end

      private def check_greedy_flag : Bool
        if current_char == '?'
          advance
          false # non-greedy
        else
          true # greedy
        end
      end

      private def parse_primary : PatternAST::Node
        case current_char
        when '.'
          advance
          parse_dot
        when '['
          advance
          parse_character_class
        when '('
          advance
          parse_group
        when '\\'
          advance
          parse_escape
        when ')'
          # End of group - caller will handle
          PatternAST::Empty.new
        else
          parse_literal
        end
      end

      private def parse_dot : PatternAST::Node
        if @unicode
          PatternAST::CharClass.new(PatternAST::CharClass::Kind::AnyChar)
        else
          PatternAST::CharClass.new(PatternAST::CharClass::Kind::AnyByte)
        end
      end

      private def parse_character_class : PatternAST::Node
        # Check for negation
        negated = false
        if current_char == '^'
          negated = true
          advance
        end

        ranges = [] of Range(Char, Char)

        while !eof? && current_char != ']'
          start_char = parse_character_class_char

          if current_char == '-' && peek_next_char != ']'
            # Range
            advance # skip '-'
            end_char = parse_character_class_char
            ranges << (start_char..end_char)
          else
            # Single character
            ranges << (start_char..start_char)
          end
        end

        if current_char == ']'
          advance # skip ']'
        else
          # Error: unmatched '['
        end

        if ranges.empty?
          # Empty class matches nothing
          PatternAST::Empty.new
        else
          kind = negated ? PatternAST::CharClass::Kind::NegatedRange : PatternAST::CharClass::Kind::Range
          PatternAST::CharClass.new(kind, ranges)
        end
      end

      private def parse_character_class_char : Char
        if current_char == '\\'
          advance # skip backslash
          parse_escape_inside_class
        else
          char = current_char
          advance
          char
        end
      end

      private def parse_escape_inside_class : Char
        return '\0' if eof?

        case current_char
        when 'd', 'D', 'w', 'W', 's', 'S', 'b', 'B'
          # Shorthand classes not allowed inside character class in standard regex
          # but we'll treat as literal character
          char = current_char
          advance
          char
        when ']', '[', '\\', '-', '^', '$'
          # Escape special character
          char = current_char
          advance
          char
        else
          # Unknown escape, treat as literal
          char = current_char
          advance
          char
        end
      end

      private def peek_next_char : Char
        (@pos + 1) < @input.size ? @input[@pos + 1] : '\0'
      end

      private def parse_number : Int32
        start_pos = @pos
        while !eof? && current_char.ascii_number?
          advance
        end

        if @pos > start_pos
          @input.byte_slice(start_pos, @pos - start_pos).to_i
        else
          0
        end
      end

      private def parse_group : PatternAST::Node
        # Parse alternation inside group
        node = parse_alternation

        if current_char == ')'
          advance # skip ')'
        else
          # Mismatched paren - error or treat as literal?
          # For now, return node
        end

        node
      end

      private def parse_escape : PatternAST::Node
        return PatternAST::Empty.new if eof?

        case current_char
        when 'd'
          advance
          PatternAST::CharClass.new(PatternAST::CharClass::Kind::Digit)
        when 'D'
          advance
          PatternAST::CharClass.new(PatternAST::CharClass::Kind::NonDigit)
        when 'w'
          advance
          PatternAST::CharClass.new(PatternAST::CharClass::Kind::Word)
        when 'W'
          advance
          PatternAST::CharClass.new(PatternAST::CharClass::Kind::NonWord)
        when 's'
          advance
          PatternAST::CharClass.new(PatternAST::CharClass::Kind::Space)
        when 'S'
          advance
          PatternAST::CharClass.new(PatternAST::CharClass::Kind::NonSpace)
        when 'b'
          advance
          PatternAST::Look.new(PatternAST::Look::Kind::WordBoundary)
        when 'B'
          advance
          PatternAST::Look.new(PatternAST::Look::Kind::NonWordBoundary)
        when 't', 'n', 'r', 'f', 'v', '\\', '.', '*', '+', '?', '|', '(', ')', '[', ']', '{', '}', '^', '$'
          # Escape special character
          char = current_char
          advance
          PatternAST::Literal.from_string(char.to_s)
        else
          # Unknown escape, treat as literal
          char = current_char
          advance
          PatternAST::Literal.from_string("\\" + char.to_s)
        end
      end

      private def parse_literal : PatternAST::Node
        start_pos = @pos
        while !eof? && !special_char?(current_char)
          advance
        end

        if @pos > start_pos
          lit = @input.byte_slice(start_pos, @pos - start_pos)
          PatternAST::Literal.from_string(lit)
        else
          PatternAST::Empty.new
        end
      end

      private def special_char?(char : Char) : Bool
        char.in?('\\', '.', '*', '+', '?', '|', '(', ')', '[', ']', '{', '}', '^', '$')
      end

      private def current_char : Char
        return '\0' if eof?
        @input[@pos]
      end

      private def advance : Nil
        @pos += 1
      end

      private def eof? : Bool
        @pos >= @input.size
      end
    end
  end
end
