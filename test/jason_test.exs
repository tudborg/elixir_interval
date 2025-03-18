defmodule Interval.Support.JasonTest do
  use ExUnit.Case

  @module Interval.IntegerInterval

  test "supported?" do
    assert Interval.Support.Jason.supported?() == true
  end

  test "Interval.IntegerInterval" do
    assert ~s{"[1,2)"} === @module.new(1, 2) |> Jason.encode!()
  end
end
