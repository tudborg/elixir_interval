defmodule Interval.Support.PostgrexTest do
  use ExUnit.Case, async: true

  alias Interval.Support

  test "roundtrip conversion of empty into builtins" do
    empty = range(:empty, :empty, false, false)

    assert empty == to_interval_to_range(empty, Interval.Date)
    assert empty == to_interval_to_range(empty, Interval.DateTime)
    assert empty == to_interval_to_range(empty, Interval.Float)
    assert empty == to_interval_to_range(empty, Interval.Integer)
  end

  test "roundtrip conversion of unbounded into builtins" do
    unbound = range(:unbound, :unbound, false, false)

    assert unbound == to_interval_to_range(unbound, Interval.Date)
    assert unbound == to_interval_to_range(unbound, Interval.DateTime)
    assert unbound == to_interval_to_range(unbound, Interval.Float)
    assert unbound == to_interval_to_range(unbound, Interval.Integer)
  end

  test "Interval.Integer [1,2)" do
    range = range(1, 2, true, false)
    assert range == to_interval_to_range(range, Interval.Integer)

    interval = Support.Postgrex.from_range(range, Interval.Integer)

    assert interval.left == {:inclusive, 1}
    assert interval.right == {:exclusive, 2}
  end

  test "Interval.Integer (1,2] (discrete interval normalization)" do
    range = range(1, 2, false, true)
    interval = Support.Postgrex.from_range(range, Interval.Integer)

    assert interval.left == {:inclusive, 2}
    assert interval.right == {:exclusive, 3}

    normalized_range = Support.Postgrex.to_range(interval)

    assert normalized_range == range(2, 3, true, false)
  end

  test "Interval.Float [1.0,2,0)" do
    range = range(1.0, 2.0, true, false)
    assert range == to_interval_to_range(range, Interval.Float)

    interval = Support.Postgrex.from_range(range, Interval.Float)

    assert interval.left == {:inclusive, 1.0}
    assert interval.right == {:exclusive, 2.0}
  end

  test "Interval.Float (1.0,2.0] (continuous interval)" do
    range = range(1.0, 2.0, false, true)
    interval = Support.Postgrex.from_range(range, Interval.Float)

    assert interval.left == {:exclusive, 1.0}
    assert interval.right == {:inclusive, 2.0}
  end

  # roundtrip into module type and back to range
  defp to_interval_to_range(range, module) do
    range
    |> Support.Postgrex.from_range(module)
    |> Support.Postgrex.to_range(module)
  end

  defp range(lower, upper, lower_inclusive, upper_inclusive) do
    %Postgrex.Range{
      lower: lower,
      upper: upper,
      lower_inclusive: lower_inclusive,
      upper_inclusive: upper_inclusive
    }
  end
end
