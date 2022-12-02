defmodule Interval.BuiltinTest do
  use ExUnit.Case, async: true

  # doctest the default implementations
  doctest Interval.Integer, import: true
  doctest Interval.Date, import: true
  doctest Interval.Float, import: true
  doctest Interval.DateTime, import: true
  doctest Interval.Decimal, import: true

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

    test "size/1" do
      assert 0 ===
               Interval.Integer.new(left: 1, right: 1)
               |> Interval.size()

      assert 1 ===
               Interval.Integer.new(left: 1, right: 2)
               |> Interval.size()

      assert nil ===
               Interval.Integer.new(left: 1, right: nil)
               |> Interval.size()

      assert nil ===
               Interval.Integer.new(left: nil, right: 2)
               |> Interval.size()
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

    test "size/1" do
      assert 0 ===
               Interval.Date.new(left: ~D[2022-01-01], right: ~D[2022-01-01])
               |> Interval.size()

      assert 1 ===
               Interval.Date.new(left: ~D[2022-01-01], right: ~D[2022-01-02])
               |> Interval.size()

      assert nil ===
               Interval.Date.new(left: ~D[2022-01-01], right: nil)
               |> Interval.size()

      assert nil ===
               Interval.Date.new(left: nil, right: ~D[2022-01-02])
               |> Interval.size()
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

    test "size/1" do
      assert 0.0 ===
               Interval.Float.new(left: 1.0, right: 1.0)
               |> Interval.size()

      assert 1.0 ===
               Interval.Float.new(left: 1.0, right: 2.0)
               |> Interval.size()

      assert nil ===
               Interval.Float.new(left: 1.0, right: nil)
               |> Interval.size()

      assert nil ===
               Interval.Float.new(left: nil, right: 2.0)
               |> Interval.size()
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

  describe "NaiveDateTime" do
    test "point_step/2" do
      assert nil === Interval.NaiveDateTime.point_step(~N[2022-01-01 00:00:00], 2)
    end

    test "Interval.Intervalable" do
      assert Interval.NaiveDateTime.new(
               left: ~N[2022-01-01 00:00:00],
               right: ~N[2022-01-02 00:00:00]
             ) ===
               Interval.new(left: ~N[2022-01-01 00:00:00], right: ~N[2022-01-02 00:00:00])
    end
  end

  describe "Decimal" do
    test "point_step/2" do
      assert nil === Interval.Decimal.point_step(Decimal.new(1), 2)
    end

    test "discrete?/1" do
      refute Interval.Decimal.discrete?()
    end

    test "size/1" do
      assert Decimal.new(0) ===
               Interval.Decimal.new(left: Decimal.new(1), right: Decimal.new(1))
               |> Interval.size()

      assert Decimal.new(1) ===
               Interval.Decimal.new(left: Decimal.new(1), right: Decimal.new(2))
               |> Interval.size()

      assert nil ===
               Interval.Decimal.new(left: Decimal.new(1), right: nil)
               |> Interval.size()

      assert nil ===
               Interval.Decimal.new(left: nil, right: Decimal.new(2))
               |> Interval.size()
    end

    test "Interval.Intervalable" do
      assert Interval.Decimal.new(
               left: Decimal.new(1),
               right: Decimal.new(2)
             ) ===
               Interval.new(
                 left: Decimal.new(1),
                 right: Decimal.new(2)
               )
    end
  end
end
