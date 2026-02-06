require "../spec_helper"

module Logos
  describe Source do
    describe "String implementation" do
      it "returns correct length" do
        "hello".length.should eq(5)
        "hello".bytesize.should eq(5)
      end

      it "reads single bytes" do
        "foo".read_u8(0).should eq('f'.ord)
        "foo".read_u8(1).should eq('o'.ord)
        "foo".read_u8(2).should eq('o'.ord)
        "foo".read_u8(3).should be_nil
        "foo".read_u8(-1).should be_nil
      end

      it "reads multiple bytes" do
        bytes = "foo".read_bytes(2, 0)
        bytes.should_not be_nil
        bytes.try(&.size).should eq(2)
        bytes.try(&.[0]).should eq('f'.ord)
        bytes.try(&.[1]).should eq('o'.ord)

        "foo".read_bytes(4, 0).should be_nil
        "foo".read_bytes(2, 2).should be_nil
      end

      it "slices correctly" do
        str = "hello world"
        str.slice(0...5).should eq("hello")  # exclusive range
        str.slice(6...11).should eq("world") # exclusive range
        str.slice(0...100).should be_nil
      end

      it "checks boundaries correctly" do
        str = "hello"
        str.boundary?(0).should be_true
        str.boundary?(5).should be_true
        str.boundary?(2).should be_true
        str.boundary?(6).should be_false
        str.boundary?(-1).should be_false

        # UTF-8 boundary check
        "é".boundary?(0).should be_true
        "é".boundary?(1).should be_false # Middle of 2-byte char
        "é".boundary?(2).should be_true
      end

      it "finds boundaries" do
        str = "héllo"
        # 'é' is 2 bytes: bytes 1-2
        str.find_boundary(0).should eq(0)
        str.find_boundary(1).should eq(1) # start of 'é'
        str.find_boundary(2).should eq(3) # second byte of 'é' -> skip to 'l'
        str.find_boundary(3).should eq(3)
        str.find_boundary(4).should eq(4)
        str.find_boundary(5).should eq(5)
        str.find_boundary(6).should eq(6) # end of string
      end
    end

    describe "Slice(UInt8) implementation" do
      it "returns correct length" do
        slice = Slice(UInt8).new(3) { |i| (i + 1).to_u8 }
        slice.length.should eq(3)
      end

      it "reads single bytes" do
        slice = Slice[1_u8, 2_u8, 3_u8]
        slice.read_u8(0).should eq(1)
        slice.read_u8(1).should eq(2)
        slice.read_u8(2).should eq(3)
        slice.read_u8(3).should be_nil
      end

      it "reads multiple bytes" do
        slice = Slice[1_u8, 2_u8, 3_u8, 4_u8, 5_u8]
        bytes = slice.read_bytes(3, 1)
        bytes.should_not be_nil
        bytes.try(&.size).should eq(3)
        bytes.try(&.[0]).should eq(2)
        bytes.try(&.[1]).should eq(3)
        bytes.try(&.[2]).should eq(4)
      end

      it "slices correctly" do
        slice = Slice[1_u8, 2_u8, 3_u8, 4_u8, 5_u8]
        slice.slice(1...4).should eq(Slice[2_u8, 3_u8, 4_u8]) # exclusive range
        slice.slice(0...100).should be_nil
      end

      it "checks boundaries correctly" do
        slice = Slice[1_u8, 2_u8, 3_u8]
        slice.boundary?(0).should be_true
        slice.boundary?(3).should be_true
        slice.boundary?(2).should be_true
        slice.boundary?(4).should be_false
        slice.boundary?(-1).should be_false
      end
    end
  end
end
