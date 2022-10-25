defmodule IntervalBuiltinTest do
  use ExUnit.Case, async: true

  # doctest the default implementations
  doctest Interval.Integer, import: true
  doctest Interval.Date, import: true
  doctest Interval.Float, import: true
  doctest Interval.DateTime, import: true
end
