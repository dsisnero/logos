require "../spec_helper"

describe "Logos::Source implementation" do
  it "String implements Source" do
    str = "hello"
    str.should be_a(Logos::Source(String))
    str.length.should eq(5)
    str.read_u8(0).should eq('h'.ord)
    str.read_u8(4).should eq('o'.ord)
    str.read_u8(5).should be_nil
  end

  it "Slice(UInt8) implements Source" do
    slice = Slice[1_u8, 2_u8, 3_u8]
    slice.should be_a(Logos::Source(Slice(UInt8)))
    slice.length.should eq(3)
    slice.read_u8(0).should eq(1)
    slice.read_u8(2).should eq(3)
    slice.read_u8(3).should be_nil
  end
end
