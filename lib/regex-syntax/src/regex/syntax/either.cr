module Regex::Syntax
  # Internal binary sum type matching the vendored Rust helper.
  struct Either(Left, Right)
    enum Kind
      Left
      Right
    end

    getter kind : Kind
    getter left : Left?
    getter right : Right?

    def self.left(value : Left) forall Left, Right
      new(Kind::Left, value, nil)
    end

    def self.right(value : Right) forall Left, Right
      new(Kind::Right, nil, value)
    end

    def left? : Bool
      @kind.left?
    end

    def right? : Bool
      @kind.right?
    end

    def left! : Left
      @left.not_nil!
    end

    def right! : Right
      @right.not_nil!
    end

    private def initialize(@kind : Kind, @left : Left?, @right : Right?)
    end
  end
end
