#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: primitives" do
  it "types a bool" do
    assert_type("false") { bool }
  end

  it "types an int32" do
    assert_type("1") { int32 }
  end

  it "types a int64" do
    assert_type("1_i64") { int64 }
  end

  it "types a float32" do
    assert_type("2.3_f32") { float32 }
  end

  it "types a float64" do
    assert_type("2.3_f64") { float64 }
  end

  it "types a char" do
    assert_type("'a'") { char }
  end

  it "types a symbol" do
    assert_type(":foo") { symbol }
  end

  it "types a string" do
    assert_type("\"foo\"") { string }
  end

  it "types nil" do
    assert_type("nil") { |mod| mod.nil }
  end

  it "types nop" do
    assert_type("") { |mod| mod.nil }
  end

  it "types an expression" do
    assert_type("1; 'a'") { char }
  end

  it "types 1 + 2" do
    assert_type("1 + 2") { int32 }
  end
end
