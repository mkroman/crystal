#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Code gen: declare var" do
  it "codegens declare var and read it" do
    run("a :: Int32; a") # TODO: initialize to zero?
  end

  it "codegens declare var and changes it" do
    run("a :: Int32; while a != 10; a = 10; end; a").to_i.should eq(10)
  end
end
