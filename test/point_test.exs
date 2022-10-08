defmodule IntervalPointTest do
  use ExUnit.Case

  # doctest the default implementations for Interval.Point
  doctest Interval.Point.Integer, import: true
  doctest Interval.Point.Date, import: true
  doctest Interval.Point.Float, import: true
  doctest Interval.Point.DateTime, import: true
end
