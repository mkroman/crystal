#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: class var" do
  it "types class var" do
    assert_type("
      class Foo
        @@foo = 1

        def self.foo
          @@foo
        end
      end

      Foo.foo
      ") { int32 }
  end

  it "types class var as nil" do
    assert_type("
      class Foo
        def self.foo
          @@foo
        end
      end

      Foo.foo
      ") { |mod| mod.nil }
  end

  it "types class var inside instance method" do
    assert_type("
      class Foo
        @@foo = 1

        def foo
          @@foo
        end
      end

      Foo.new.foo
      ") { int32 }
  end

  it "types class var as nil if assigned for the first time inside method" do
    assert_type("
      class Foo
        def self.foo
          @@foo = 1
          @@foo
        end
      end

      Foo.foo
      ") { |mod| union_of(mod.nil, int32) }
  end

  it "types class var of program" do
    assert_type("
      @@foo = 1
      @@foo
      ") { int32 }
  end

  it "types class var of program as nil" do
    assert_type("
      @@foo
      ") { |mod| mod.nil }
  end
end
