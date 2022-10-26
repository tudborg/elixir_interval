defmodule IntervalBuiltinTest do
  use ExUnit.Case, async: true

  # doctest the default implementations
  doctest Interval.Integer, import: true
  doctest Interval.Date, import: true
  doctest Interval.Float, import: true
  doctest Interval.DateTime, import: true

  test "Interval.Intervalable" do
    assert Interval.new(left: 1)
    assert Interval.new(right: 1)

    assert_raise ArgumentError,
                 ~r/No implementation for interval/,
                 fn -> Interval.new(left: :foo, right: :bar) end

    assert_raise ArgumentError,
                 ~r/multiple potential implementations/,
                 fn -> Interval.new(left: 0.0, right: 1) end
  end

  describe "Integer" do
    test "point_step/2" do
      assert 4 === Interval.Integer.point_step(2, 2)
    end

    test "Interval.Intervalable" do
      assert Interval.Integer.new(left: 0, right: 1) ===
               Interval.new(left: 0, right: 1)
    end
  end

  describe "Date" do
    test "point_step/2" do
      assert ~D[2022-01-03] === Interval.Date.point_step(~D[2022-01-01], 2)
    end

    test "Interval.Intervalable" do
      assert Interval.Date.new(left: ~D[2022-01-01], right: ~D[2022-01-02]) ===
               Interval.new(left: ~D[2022-01-01], right: ~D[2022-01-02])
    end
  end

  describe "Float" do
    test "point_step/2" do
      assert nil === Interval.Float.point_step(2.0, 2)
    end

    test "Interval.Intervalable" do
      assert Interval.Float.new(left: 0.0, right: 1.0) ===
               Interval.new(left: 0.0, right: 1.0)
    end
  end

  describe "DateTime" do
    test "point_step/2" do
      assert nil === Interval.DateTime.point_step(~U[2022-01-01 00:00:00Z], 2)
    end

    test "Interval.Intervalable" do
      assert Interval.DateTime.new(
               left: ~U[2022-01-01 00:00:00Z],
               right: ~U[2022-01-02 00:00:00Z]
             ) ===
               Interval.new(left: ~U[2022-01-01 00:00:00Z], right: ~U[2022-01-02 00:00:00Z])
    end
  end
end
