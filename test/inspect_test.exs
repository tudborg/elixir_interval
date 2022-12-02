defmodule Interval.InspectTest do
  use ExUnit.Case, async: true

  test "Interval.inspect_interval/1 basics" do
    incl_excl = Interval.Float.new(left: 1.0, right: 2.0)
    excl_incl = Interval.Float.new(left: 1.0, right: 2.0, bounds: "(]")
    empty = Interval.Float.new(left: 1.0, right: 1.0, bounds: "()")
    unbounded_left = Interval.Float.new(right: 1.0)
    unbounded_right = Interval.Float.new(left: 1.0)

    assert inspect(empty) === "#Interval.Float<empty>"
    assert inspect(incl_excl) === "#Interval.Float<[1.0, 2.0)>"
    assert inspect(excl_incl) === "#Interval.Float<(1.0, 2.0]>"
    assert inspect(unbounded_left) === "#Interval.Float<, 1.0)>"
    assert inspect(unbounded_right) === "#Interval.Float<[1.0, >"
  end

  test "DateTime" do
    str =
      [left: ~U(2022-01-01T00:00:00Z), right: ~U(2022-01-02T00:00:00Z)]
      |> Interval.DateTime.new()
      |> inspect()

    assert str === "#Interval.DateTime<[~U[2022-01-01 00:00:00Z], ~U[2022-01-02 00:00:00Z])>"
  end

  test "NaiveDateTime" do
    str =
      [left: ~N(2022-01-01T00:00:00), right: ~N(2022-01-02T00:00:00)]
      |> Interval.NaiveDateTime.new()
      |> inspect()

    assert str === "#Interval.NaiveDateTime<[~N[2022-01-01 00:00:00], ~N[2022-01-02 00:00:00])>"
  end

  test "Decimal" do
    str =
      [left: Decimal.new(1), right: Decimal.new(2)]
      |> Interval.Decimal.new()
      |> inspect()

    assert str === "#Interval.Decimal<[#Decimal<1>, #Decimal<2>)>"
  end

  test "Integer" do
    str =
      [left: 1, right: 2]
      |> Interval.Integer.new()
      |> inspect()

    assert str === "#Interval.Integer<[1, 2)>"
  end

  test "Float" do
    str =
      [left: 1.0, right: 2.0]
      |> Interval.Float.new()
      |> inspect()

    assert str === "#Interval.Float<[1.0, 2.0)>"
  end
end
