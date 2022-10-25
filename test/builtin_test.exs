defmodule IntervalBuiltinTest do
  use ExUnit.Case, async: true

  # doctest the default implementations
  doctest Interval.Integer, import: true
  doctest Interval.Date, import: true
  doctest Interval.Float, import: true
  doctest Interval.DateTime, import: true

  test "Integer - point_step/2" do
    assert 4 === Interval.Integer.point_step(2, 2)
  end

  test "Date - point_step/2" do
    assert ~D[2022-01-03] === Interval.Date.point_step(~D[2022-01-01], 2)
  end

  test "Float - point_step/2" do
    assert nil === Interval.Float.point_step(2.0, 2)
  end

  test "DateTime - point_step/2" do
    assert nil === Interval.DateTime.point_step(~U[2022-01-01 00:00:00Z], 2)
  end
end
