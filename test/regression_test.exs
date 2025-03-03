defmodule Interval.RegressionTest do
  alias Interval.FloatInterval
  alias Interval.IntegerInterval
  use ExUnit.Case, async: true

  test "contains/2 regression 2022-10-07 - `,1)` failed to contain `[0,1)`" do
    a = %IntegerInterval{left: :unbounded, right: {:exclusive, 1}}

    b = %IntegerInterval{
      left: {:inclusive, 0},
      right: {:exclusive, 1}
    }

    assert Interval.contains?(a, b)
  end

  test "intersection regression 2022-10-12 - incorrect bounds" do
    # The bad code wanted this intersection to be [2.0,3.0], but it should be [2.0,3.0)
    assert Interval.intersection(
             FloatInterval.new(left: 2.0, right: 3.0, bounds: "[)"),
             FloatInterval.new(left: 2.0, right: 3.0, bounds: "[]")
           ) === FloatInterval.new(left: 2.0, right: 3.0, bounds: "[)")
  end
end
