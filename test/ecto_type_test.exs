defmodule Interval.Support.EctoTypeTest do
  use ExUnit.Case, async: true

  alias Interval.Support.EctoType

  # We use Interval.IntegerInterval as the module to test on
  # since it's a builtin and we know that it can use Ecto.
  # We could also define a dummy interval in this module
  # if we want cleaner separation.
  @module Interval.IntegerInterval

  test "Interval.IntegerInterval implements Ecto.Type behaviour" do
    assert function_exported?(@module, :type, 0)
    assert function_exported?(@module, :cast, 1)
    assert function_exported?(@module, :load, 1)
    assert function_exported?(@module, :dump, 1)
  end

  test "Interval.IntegerInterval.type/0" do
    assert @module.type() == :int4range
  end

  test "Interval.IntegerInterval.cast/1" do
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

    # cast from string
    assert @module.cast("[1,2)") === {:ok, @module.new(1, 2, "[)")}
    assert @module.cast("empty") === {:ok, @module.new(:empty, :empty)}
    assert @module.cast("potato") === :error
  end

  test "Interval.IntegerInterval.load/1" do
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

    # load from DB as string
    assert @module.load("[1,2)") === {:ok, @module.new(1, 2, "[)")}
  end

  test "Interval.IntegerInterval.dump/1" do
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

    assert empty == to_interval_to_range(empty, Interval.DateInterval)
    assert empty == to_interval_to_range(empty, Interval.DateTimeInterval)
    assert empty == to_interval_to_range(empty, Interval.NaiveDateTimeInterval)
    assert empty == to_interval_to_range(empty, Interval.FloatInterval)
    assert empty == to_interval_to_range(empty, Interval.IntegerInterval)
  end

  test "roundtrip conversion of unbounded into builtins" do
    unbound = range(:unbound, :unbound, false, false)

    assert unbound == to_interval_to_range(unbound, Interval.DateInterval)
    assert unbound == to_interval_to_range(unbound, Interval.DateTimeInterval)
    assert unbound == to_interval_to_range(unbound, Interval.NaiveDateTimeInterval)
    assert unbound == to_interval_to_range(unbound, Interval.FloatInterval)
    assert unbound == to_interval_to_range(unbound, Interval.IntegerInterval)
  end

  test "Interval.IntegerInterval [1,2)" do
    range = range(1, 2, true, false)
    assert range == to_interval_to_range(range, Interval.IntegerInterval)

    interval = EctoType.from_postgrex_range(range, Interval.IntegerInterval)

    assert interval.left == {:inclusive, 1}
    assert interval.right == {:exclusive, 2}
  end

  test "Interval.IntegerInterval (1,2] (discrete interval normalization)" do
    range = range(1, 2, false, true)
    interval = EctoType.from_postgrex_range(range, Interval.IntegerInterval)

    assert interval.left == {:inclusive, 2}
    assert interval.right == {:exclusive, 3}

    normalized_range = EctoType.to_postgrex_range(interval)

    assert normalized_range == range(2, 3, true, false)
  end

  test "Interval.FloatInterval [1.0,2.0)" do
    range = range(1.0, 2.0, true, false)
    assert range == to_interval_to_range(range, Interval.FloatInterval)

    interval = EctoType.from_postgrex_range(range, Interval.FloatInterval)

    assert interval.left == {:inclusive, 1.0}
    assert interval.right == {:exclusive, 2.0}
  end

  test "Interval.FloatInterval (1.0,2.0] (continuous interval)" do
    range = range(1.0, 2.0, false, true)
    interval = EctoType.from_postgrex_range(range, Interval.FloatInterval)

    assert interval.left == {:exclusive, 1.0}
    assert interval.right == {:inclusive, 2.0}
  end

  test "EctoType.supported?/0" do
    assert EctoType.supported?()
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
