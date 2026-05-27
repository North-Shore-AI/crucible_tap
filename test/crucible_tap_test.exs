defmodule CrucibleTapTest do
  use ExUnit.Case
  doctest CrucibleTap

  test "exposes package version" do
    assert CrucibleTap.version() == "0.1.0"
  end
end
