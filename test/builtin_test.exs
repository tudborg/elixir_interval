defmodule Interval.BuiltinTest do
  alias Interval.DateInterval
  alias Interval.DateTimeInterval
  alias Interval.DecimalInterval
  alias Interval.FloatInterval
  alias Interval.IntegerInterval
  alias Interval.NaiveDateTimeInterval

  use ExUnit.Case, async: true

  # doctest the default implementations
  doctest Interval.DateInterval, import: true
  doctest Interval.DateTimeInterval, import: true
  doctest Interval.DecimalInterval, import: true
  doctest Interval.FloatInterval, import: true
  doctest Interval.IntegerInterval, import: true

  describe "Integer" do
    test "point_step/2" do
      assert 4 === IntegerInterval.point_step(2, 2)
    end
  end

  describe "Date" do
    test "point_step/2" do
      assert ~D[2022-01-03] === DateInterval.point_step(~D[2022-01-01], 2)
    end
  end

  describe "Float" do
    test "point_step/2" do
      assert nil === FloatInterval.point_step(2.0, 2)
    end
  end

  describe "DateTime" do
    test "point_step/2" do
      assert nil === DateTimeInterval.point_step(~U[2022-01-01 00:00:00Z], 2)
    end
  end

  describe "NaiveDateTime" do
    test "point_step/2" do
      assert nil === NaiveDateTimeInterval.point_step(~N[2022-01-01 00:00:00], 2)
    end
  end

  describe "Decimal" do
    test "point_step/2" do
      assert nil === DecimalInterval.point_step(Decimal.new(1), 2)
    end

    test "discrete?/1" do
      refute DecimalInterval.discrete?()
    end
  end
end
