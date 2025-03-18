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

    test "point_format/1" do
      assert "2" === IntegerInterval.point_format(2)
    end

    test "point_parse/1" do
      assert {:ok, 2} === IntegerInterval.point_parse("2")
      assert :error === IntegerInterval.point_parse("2.0")
      assert :error === IntegerInterval.point_parse("potato")
    end

    test "to_string/1" do
      assert "[1,2)" === IntegerInterval.parse("[1,2)") |> unwrap!() |> to_string()
    end
  end

  describe "Date" do
    test "point_step/2" do
      assert ~D[2022-01-03] === DateInterval.point_step(~D[2022-01-01], 2)
    end

    test "point_normalize/1" do
      assert {:ok, ~D[2022-01-01]} === DateInterval.point_normalize(~D[2022-01-01])
      assert :error === DateInterval.point_normalize(~U[2023-01-01 00:00:00Z])
    end

    test "point_compare/2" do
      assert :eq === DateInterval.point_compare(~D[2022-01-01], ~D[2022-01-01])
      assert :lt === DateInterval.point_compare(~D[2022-01-01], ~D[2022-01-02])
      assert :gt === DateInterval.point_compare(~D[2022-01-02], ~D[2022-01-01])
    end

    test "point_format/1" do
      assert "2022-01-01" === DateInterval.point_format(~D[2022-01-01])
    end

    test "point_parse/1" do
      assert {:ok, ~D[2022-01-01]} === DateInterval.point_parse("2022-01-01")
      assert :error === DateInterval.point_parse("2022-01-01T00:00:00Z")
    end

    test "to_string/1" do
      assert "[2022-01-01,2022-01-02)" ===
               DateInterval.parse("[2022-01-01,2022-01-02)") |> unwrap!() |> to_string()
    end
  end

  describe "Float" do
    test "point_step/2" do
      assert_raise Interval.IntervalOperationError, fn ->
        FloatInterval.point_step(2.0, 2)
      end
    end

    test "point_normalize/1" do
      assert {:ok, 2.0} === FloatInterval.point_normalize(2.0)
      assert {:ok, +0.0} === FloatInterval.point_normalize(0.0)
      assert {:ok, +0.0} === FloatInterval.point_normalize(-0.0)
      assert :error === FloatInterval.point_normalize(~D[2023-01-01])
    end

    test "point_format/1" do
      assert "2.0" === FloatInterval.point_format(2.0)
    end

    test "point_parse/1" do
      assert {:ok, 2.0} === FloatInterval.point_parse("2.0")
      assert :error === FloatInterval.point_parse("2.0.0")
      assert :error === FloatInterval.point_parse("potato")
    end

    test "to_string/1" do
      assert "[1.0,2.0]" === FloatInterval.parse("[1.0,2.0]") |> unwrap!() |> to_string()
    end
  end

  describe "DateTime" do
    test "point_step/2" do
      assert_raise Interval.IntervalOperationError, fn ->
        DateTimeInterval.point_step(~U[2022-01-01 00:00:00Z], 2)
      end
    end

    test "point_normalize/1" do
      a = ~U[2022-01-01 00:00:00Z]
      b = ~U[2022-01-01 00:00:00.000000Z]

      assert {:ok, a} === DateTimeInterval.point_normalize(a)
      assert {:ok, b} === DateTimeInterval.point_normalize(b)
      assert :error === DateTimeInterval.point_normalize(~D[2023-01-01])
    end

    test "point_compare/2" do
      a = ~U[2022-01-01 00:00:00Z]
      b = ~U[2022-01-01 00:00:01Z]

      assert :lt === DateTimeInterval.point_compare(a, b)
      assert :eq === DateTimeInterval.point_compare(a, a)
      assert :gt === DateTimeInterval.point_compare(b, a)
    end

    test "point_format/1" do
      assert "2022-01-01T00:00:00Z" === DateTimeInterval.point_format(~U[2022-01-01 00:00:00Z])
    end

    test "point_parse/1" do
      assert {:ok, ~U[2022-01-01 00:00:00Z]} ===
               DateTimeInterval.point_parse("2022-01-01T00:00:00Z")

      assert :error === DateTimeInterval.point_parse("2022-01-01")
    end

    test "to_string/1" do
      assert "[2022-01-01T00:00:00Z,2022-01-01T00:00:01Z)" ===
               DateTimeInterval.parse("[2022-01-01T00:00:00Z,2022-01-01T00:00:01Z)")
               |> unwrap!()
               |> to_string()
    end
  end

  describe "NaiveDateTime" do
    test "point_step/2" do
      assert nil === NaiveDateTimeInterval.point_step(~N[2022-01-01 00:00:00], 2)
    end

    test "point_normalize/1" do
      assert {:ok, ~N[2022-01-01 00:00:00]} ===
               NaiveDateTimeInterval.point_normalize(~N[2022-01-01 00:00:00])

      assert {:ok, ~N[2022-01-01 00:00:00.000000]} ===
               NaiveDateTimeInterval.point_normalize(~N[2022-01-01 00:00:00.000000])

      assert :error === NaiveDateTimeInterval.point_normalize(~D[2023-01-01])
    end

    test "point_compare/2" do
      a = ~N[2022-01-01 00:00:00]
      b = ~N[2022-01-01 00:00:01]

      assert :lt === NaiveDateTimeInterval.point_compare(a, b)
      assert :eq === NaiveDateTimeInterval.point_compare(a, a)
      assert :gt === NaiveDateTimeInterval.point_compare(b, a)
    end

    test "point_format/1" do
      assert "2022-01-01T00:00:00" === NaiveDateTimeInterval.point_format(~N[2022-01-01 00:00:00])
    end

    test "point_parse/1" do
      assert {:ok, ~N[2022-01-01 00:00:00]} ===
               NaiveDateTimeInterval.point_parse("2022-01-01T00:00:00")

      assert :error === NaiveDateTimeInterval.point_parse("2022-01-01")
    end

    test "to_string/1" do
      assert "[2022-01-01T00:00:00,2022-01-01T00:00:01)" ===
               NaiveDateTimeInterval.parse("[2022-01-01T00:00:00,2022-01-01T00:00:01)")
               |> unwrap!()
               |> to_string()
    end
  end

  describe "Decimal" do
    test "point_step/2" do
      assert_raise Interval.IntervalOperationError, fn ->
        DecimalInterval.point_step(Decimal.new(1), 2)
      end
    end

    test "discrete?/1" do
      refute DecimalInterval.discrete?()
    end

    test "point_normalize/1" do
      assert {:ok, Decimal.new(2)} === DecimalInterval.point_normalize(Decimal.new(2))
      assert {:ok, Decimal.new(0)} === DecimalInterval.point_normalize(Decimal.new(0))
      assert {:ok, Decimal.new(0)} === DecimalInterval.point_normalize(Decimal.new(-0))
      assert :error === DecimalInterval.point_normalize(~D[2023-01-01])
    end

    test "point_compare/2" do
      assert :lt === DecimalInterval.point_compare(Decimal.new(1), Decimal.new(2))
      assert :eq === DecimalInterval.point_compare(Decimal.new(2), Decimal.new(2))
      assert :gt === DecimalInterval.point_compare(Decimal.new(2), Decimal.new(1))
    end

    test "point_format/1" do
      assert "1" === DecimalInterval.point_format(Decimal.new(1))
    end

    test "point_parse/1" do
      assert {:ok, Decimal.new(1)} === DecimalInterval.point_parse("1")
      assert {:ok, Decimal.new("1.0")} === DecimalInterval.point_parse("1.0")
      assert :error === DecimalInterval.point_parse("1.0.0")
      assert :error === DecimalInterval.point_parse("potato")
    end

    test "to_string/1" do
      assert "[1,2]" === DecimalInterval.parse("[1,2]") |> unwrap!() |> to_string()
    end
  end

  defp unwrap!({:ok, value}), do: value
end
