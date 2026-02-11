module Logos
  # Annotation for class-level Logos options (skip, extras, error_type, utf8)
  annotation Options
  end

  # Annotation for defining a reusable subpattern
  annotation Subpattern
  end

  # Annotation for literal token patterns
  annotation Token
  end

  # Annotation for regex token patterns
  annotation Regex
  end

  # Annotation to mark variant as error token
  annotation ErrorToken
  end

  # Annotation to mark variant as skip token
  annotation SkipToken
  end
end
