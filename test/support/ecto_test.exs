defmodule Interval.Support.EctoTypeTest do
  use ExUnit.Case, async: true

  alias Interval.Support.EctoType

  # We use Interval.Integer as the module to test on
  # since it's a builtin and we know that it can use Ecto.
  # We could also define a dummy interval in this module
  # if we want cleaner seperation.
  @module Interval.Integer

  test "Interval.Integer implements Ecto.Type behaviour" do
    assert Kernel.function_exported?(@module, :type, 0)
    assert Kernel.function_exported?(@module, :cast, 1)
    assert Kernel.function_exported?(@module, :load, 1)
    assert Kernel.function_exported?(@module, :dump, 1)
  end

  test "Interval.Integer.type/0" do
    assert @module.type() == :int4range
  end

  test "Interval.Integer.cast/1" do
    # Since cast/1 does the exact same thing for a Postgrex.Range
    # as load/1, we only test that cast with a range a little bit.
    # The coverage comes from the load/1 test.
    assert @module.cast(range(:empty, :empty, false, false)) ==
             {:ok, %@module{left: :empty, right: :empty}}

    # When DB returns NULL:
    assert @module.cast(nil) == {:ok, nil}

    # When we cast something that is already an Interval:
    interval = @module.new(left: 1, right: 2)
    assert @module.cast(interval) == {:ok, interval}
  end

  test "Interval.Integer.load/1" do
    assert @module.load(range(:empty, :empty, false, false)) ==
             {:ok, %@module{left: :empty, right: :empty}}

    assert @module.load(range(:unbound, :unbound, false, false)) ==
             {:ok, %@module{left: :unbounded, right: :unbounded}}

    assert @module.load(range(:unbound, 2, false, false)) ==
             {:ok, %@module{left: :unbounded, right: {:exclusive, 2}}}

    assert @module.load(range(1, :unbound, true, false)) ==
             {:ok, %@module{left: {:inclusive, 1}, right: :unbounded}}

    # discrete interval normalization:
    # NOTE: Postgres would never send a non-normalized discrete
    # interval to us, but let's test that it works anyway.
    assert @module.load(range(1, 2, false, true)) ==
             {:ok, %@module{left: {:inclusive, 2}, right: {:exclusive, 3}}}

    # When DB returns NULL:
    assert @module.load(nil) == {:ok, nil}
  end

  test "Interval.Integer.dump/1" do
    assert @module.dump(%@module{left: :empty, right: :empty}) ==
             {:ok, range(:empty, :empty, false, false)}

    assert @module.dump(%@module{left: :unbounded, right: :unbounded}) ==
             {:ok, range(:unbound, :unbound, false, false)}

    assert @module.dump(%@module{left: :unbounded, right: {:exclusive, 2}}) ==
             {:ok, range(:unbound, 2, false, false)}

    assert @module.dump(%@module{left: {:inclusive, 1}, right: :unbounded}) ==
             {:ok, range(1, :unbound, true, false)}

    # When we want to send a NULL
    assert @module.dump(nil) == {:ok, nil}
  end

  ##
  ## Postgrex Range helpers
  ##

  test "roundtrip conversion of empty into builtins" do
    empty = range(:empty, :empty, false, false)

    assert empty == to_interval_to_range(empty, Interval.Date)
    assert empty == to_interval_to_range(empty, Interval.DateTime)
    assert empty == to_interval_to_range(empty, Interval.NaiveDateTime)
    assert empty == to_interval_to_range(empty, Interval.Float)
    assert empty == to_interval_to_range(empty, Interval.Integer)
  end

  test "roundtrip conversion of unbounded into builtins" do
    unbound = range(:unbound, :unbound, false, false)

    assert unbound == to_interval_to_range(unbound, Interval.Date)
    assert unbound == to_interval_to_range(unbound, Interval.DateTime)
    assert unbound == to_interval_to_range(unbound, Interval.NaiveDateTime)
    assert unbound == to_interval_to_range(unbound, Interval.Float)
    assert unbound == to_interval_to_range(unbound, Interval.Integer)
  end

  test "Interval.Integer [1,2)" do
    range = range(1, 2, true, false)
    assert range == to_interval_to_range(range, Interval.Integer)

    interval = EctoType.from_postgrex_range(range, Interval.Integer)

    assert interval.left == {:inclusive, 1}
    assert interval.right == {:exclusive, 2}
  end

  test "Interval.Integer (1,2] (discrete interval normalization)" do
    range = range(1, 2, false, true)
    interval = EctoType.from_postgrex_range(range, Interval.Integer)

    assert interval.left == {:inclusive, 2}
    assert interval.right == {:exclusive, 3}

    normalized_range = EctoType.to_postgrex_range(interval)

    assert normalized_range == range(2, 3, true, false)
  end

  test "Interval.Float [1.0,2,0)" do
    range = range(1.0, 2.0, true, false)
    assert range == to_interval_to_range(range, Interval.Float)

    interval = EctoType.from_postgrex_range(range, Interval.Float)

    assert interval.left == {:inclusive, 1.0}
    assert interval.right == {:exclusive, 2.0}
  end

  test "Interval.Float (1.0,2.0] (continuous interval)" do
    range = range(1.0, 2.0, false, true)
    interval = EctoType.from_postgrex_range(range, Interval.Float)

    assert interval.left == {:exclusive, 1.0}
    assert interval.right == {:inclusive, 2.0}
  end

  ##
  ## Helpers
  ##

  # roundtrip into module type and back to range
  defp to_interval_to_range(range, module) do
    range
    |> EctoType.from_postgrex_range(module)
    |> EctoType.to_postgrex_range(module)
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
