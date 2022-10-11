defmodule IntervalPointTest do
  use ExUnit.Case

  # doctest the default implementations for Interval.Point
  doctest Interval.Point.Integer, import: true
  doctest Interval.Point.Date, import: true
  doctest Interval.Point.Float, import: true
  doctest Interval.Point.DateTime, import: true

  test "min/2" do
    assert Interval.Point.min(1, 2) == 1
    assert Interval.Point.min(1.0, 2.0) == 1.0
  end

  test "max/2" do
    assert Interval.Point.max(1, 2) === 2
    assert Interval.Point.max(1.0, 2.0) === 2.0
  end

  test "subtract/3" do
    assert Interval.Point.subtract(3, 2) === 1
    assert Interval.Point.subtract(3.0, 2.0) === 1.0
  end

  test "add/3" do
    assert Interval.Point.add(2, 1) === 3
    assert Interval.Point.add(2.0, 1.0) === 3.0
  end
end
