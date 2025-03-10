defmodule Interval.IntervalTest do
  use ExUnit.Case, async: true

  doctest Interval, import: true

  alias Interval.IntegerInterval
  alias Interval.FloatInterval
  alias DateIntervalInterval
  alias DateTimeIntervalInterval

  defp inti(p), do: inti(p, p, "[]")
  defp inti(l, r), do: inti(l, r, nil)
  defp inti(l, r, bounds), do: IntegerInterval.new(l, r, bounds)

  # defp floati(p), do: floati(p, p, "[]")
  defp floati(l, r), do: floati(l, r, nil)
  defp floati(l, r, bounds), do: FloatInterval.new(l, r, bounds)

  test "new/1" do
    # some normal construction
    assert inti(1, 2)
    assert inti(1, 3, "()")

    # unbounded specified by the bounds
    assert ubr = inti(1, 1, "[")
    assert ubl = inti(1, 1, "]")
    assert Interval.unbounded_left?(ubl)
    assert Interval.unbounded_right?(ubr)
    assert inti(1, 1, "(")
    assert inti(1, 1, ")")
    assert inti(1, 1, "")

    assert floati(1.0, 2.0)
    assert floati(1.0, 3.0, "()")

    # discrete type normalization
    assert inti(1, 2) ===
             inti(1, 1, "[]")

    assert inti(1, 3, "()") ===
             inti(2, 2, "[]")

    # unbounded left and right and both
    assert inti(1, nil) |> Interval.unbounded_right?()
    assert inti(nil, 1) |> Interval.unbounded_left?()
    assert inti(nil, nil) |> Interval.unbounded_left?()
    assert inti(nil, nil) |> Interval.unbounded_right?()

    # bounds on discrete type (bounds always normalized to '[)')
    assert inti(1, 2, "[)") |> Interval.inclusive_left?()
    assert inti(1, 2, "(]") |> Interval.inclusive_left?()
    refute inti(1, 2, "(]") |> Interval.inclusive_right?()
    refute inti(1, 2, "[)") |> Interval.inclusive_right?()

    # bounds on continuous type
    assert floati(1.0, 2.0, "[)") |> Interval.inclusive_left?()
    refute floati(1.0, 2.0, "(]") |> Interval.inclusive_left?()
    assert floati(1.0, 2.0, "(]") |> Interval.inclusive_right?()
    refute floati(1.0, 2.0, "[)") |> Interval.inclusive_right?()
  end

  test "empty?/1" do
    # (1,1) should also be empty
    assert Interval.empty?(inti(1, 1, "()"))
    # [1,1] should not be empty
    refute Interval.empty?(inti(1, 1, "[]"))
    # [1,1) and (1,1] normalises to empty
    assert Interval.empty?(inti(1, 1, "[)"))
    assert Interval.empty?(inti(1, 1, "(]"))

    # Integer interval "(1,2)" should be empty
    # because neither 1 or 2 is in the interval,
    # and there is no integers between 1 and 2
    assert Interval.empty?(inti(1, 2, "()"))
    # but (1,3) should be non-empty because 2 is in the interval
    refute Interval.empty?(inti(1, 3, "()"))

    # Check that even non-normalized intervals correctly indicates empty
    non_normalized_1 = %IntegerInterval{
      left: {:exclusive, 1},
      right: {:exclusive, 2}
    }

    assert Interval.empty?(non_normalized_1)

    non_normalized_2 = %IntegerInterval{
      left: {:exclusive, 1},
      right: {:inclusive, 1}
    }

    assert Interval.empty?(non_normalized_2)
  end

  test "inclusive_left?/1" do
    a = floati(1.0, 2.0, "[]")
    b = floati(1.0, 2.0, "()")
    empty = floati(1.0, 1.0, "()")
    assert Interval.inclusive_left?(a)
    refute Interval.inclusive_left?(b)
    refute Interval.inclusive_left?(empty)
  end

  test "inclusive_right?/1" do
    a = floati(1.0, 2.0, "[]")
    b = floati(1.0, 2.0, "()")
    empty = floati(1.0, 1.0, "()")
    assert Interval.inclusive_right?(a)
    refute Interval.inclusive_right?(b)
    refute Interval.inclusive_right?(empty)
  end

  test "exclusive_left?/1" do
    a = floati(1.0, 2.0, "[]")
    b = floati(1.0, 2.0, "()")
    empty = floati(1.0, 1.0, "()")
    refute Interval.exclusive_left?(a)
    assert Interval.exclusive_left?(b)
    refute Interval.exclusive_left?(empty)
  end

  test "exclusive_right?/1" do
    a = floati(1.0, 2.0, "[]")
    b = floati(1.0, 2.0, "()")
    empty = floati(1.0, 1.0, "()")
    refute Interval.exclusive_right?(a)
    assert Interval.exclusive_right?(b)
    refute Interval.exclusive_right?(empty)
  end

  test "strictly_left_of?/2" do
    a = inti(1, 3, "[]")

    refute Interval.strictly_left_of?(a, inti(0))
    refute Interval.strictly_left_of?(a, inti(1))
    refute Interval.strictly_left_of?(a, inti(2))
    refute Interval.strictly_left_of?(a, inti(3))
    assert Interval.strictly_left_of?(a, inti(4))
    assert Interval.strictly_left_of?(a, inti(4, 5))
  end

  test "strictly_right_of?/2" do
    a = inti(1, 3, "[]")

    assert Interval.strictly_right_of?(a, inti(0))
    refute Interval.strictly_right_of?(a, inti(1))
    refute Interval.strictly_right_of?(a, inti(2))
    refute Interval.strictly_right_of?(a, inti(3))
    refute Interval.strictly_right_of?(a, inti(4))
  end

  test "adjacent_left_of?/2" do
    assert Interval.adjacent_left_of?(inti(1, 2), inti(2, 3))
    refute Interval.adjacent_left_of?(inti(1, 2), inti(3, 4))
    refute Interval.adjacent_left_of?(inti(nil, nil), inti(1, 2))
    refute Interval.adjacent_left_of?(inti(1, 2), inti(nil, nil))

    # non-normalized bounds should raise:
    a = %IntegerInterval{left: :unbounded, right: {:inclusive, 1}}
    b = %IntegerInterval{left: {:inclusive, 1}, right: :unbounded}

    assert_raise ArgumentError, fn ->
      Interval.adjacent_left_of?(a, b)
    end
  end

  test "adjacent_right_of?/2" do
    assert Interval.adjacent_right_of?(inti(2, 3), inti(1, 2))
    refute Interval.adjacent_right_of?(inti(3, 4), inti(1, 2))
    refute Interval.adjacent_right_of?(inti(1, 2), inti(nil, nil))
    refute Interval.adjacent_right_of?(inti(nil, nil), inti(1, 2))

    # non-normalized bounds should raise:
    a = %IntegerInterval{left: {:inclusive, 1}, right: :unbounded}
    b = %IntegerInterval{left: :unbounded, right: {:inclusive, 1}}

    assert_raise ArgumentError, fn ->
      Interval.adjacent_right_of?(a, b)
    end
  end

  test "overlaps?/2" do
    # inclusive
    a = inti(1, 3, "[]")
    refute Interval.overlaps?(a, inti(0))
    assert Interval.overlaps?(a, inti(1))
    assert Interval.overlaps?(a, inti(2))
    assert Interval.overlaps?(a, inti(3))
    refute Interval.overlaps?(a, inti(4))

    # exclusive
    a = inti(1, 3, "()")
    refute Interval.overlaps?(a, inti(0))
    refute Interval.overlaps?(a, inti(1))
    assert Interval.overlaps?(a, inti(2))
    refute Interval.overlaps?(a, inti(3))
    refute Interval.overlaps?(a, inti(4))

    # {inclusive, exclusive} (default)
    a = inti(1, 3, "[)")
    refute Interval.overlaps?(a, inti(0))
    assert Interval.overlaps?(a, inti(1))
    assert Interval.overlaps?(a, inti(2))
    refute Interval.overlaps?(a, inti(3))
    refute Interval.overlaps?(a, inti(4))

    # {exclusive, inclusive}
    a = inti(1, 3, "(]")
    refute Interval.overlaps?(a, inti(0))
    refute Interval.overlaps?(a, inti(1))
    assert Interval.overlaps?(a, inti(2))
    assert Interval.overlaps?(a, inti(3))
    refute Interval.overlaps?(a, inti(4))

    ##
    # empty never overlaps with anything, not even itself:
    ##

    # Integers (discrete)
    refute Interval.overlaps?(inti(1, 1, "()"), inti(2, 2, "()"))
    refute Interval.overlaps?(inti(1, 1, "()"), inti(1, 1, "()"))
    refute Interval.overlaps?(inti(1, 3, "()"), inti(2, 2, "()"))
    refute Interval.overlaps?(inti(1, 2, "()"), inti(2, 3, "()"))
    # Floats (continuous)
    refute Interval.overlaps?(floati(1.0, 1.0, "()"), floati(1.0, 1.0, "()"))
    refute Interval.overlaps?(floati(1.0, 1.0, "()"), floati(2.0, 2.0, "()"))
  end

  test "intersection/2" do
    # intersection with empty is always empty (and we use the "empty" that was empty)
    assert Interval.intersection(inti(1, 10, "[]"), inti(3, 3, "()")) === inti(3, 3, "()")
    assert Interval.intersection(inti(1, 10, "[]"), inti(3, 4, "()")) === inti(3, 4, "()")

    # [----A----)
    #     [----B----)
    #     [--C--)
    assert Interval.intersection(inti(1, 3, "[)"), inti(2, 4, "[)")) ===
             inti(2, 3, "[)")

    assert Interval.intersection(floati(1.0, 3.0, "[)"), floati(2.0, 4.0, "[)")) ===
             floati(2.0, 3.0, "[)")

    # testing min_endpoint and max_endpoint
    assert Interval.intersection(floati(2.0, 3.0, "[]"), floati(2.0, 3.0, "[]")) ===
             floati(2.0, 3.0, "[]")

    assert Interval.intersection(floati(2.0, 3.0, "()"), floati(2.0, 3.0, "()")) ===
             floati(2.0, 3.0, "()")

    assert Interval.intersection(floati(2.0, 3.0, "()"), floati(2.0, 3.0, "[]")) ===
             floati(2.0, 3.0, "()")

    assert Interval.intersection(floati(2.0, 3.0, "()"), floati(2.0, 3.0, "(]")) ===
             floati(2.0, 3.0, "()")
  end

  test "intersection/2 with unbounded intervals" do
    a = inti(1, 3)
    b = inti(0, nil)
    assert Interval.intersection(a, b) === Interval.intersection(b, a)
    assert Interval.intersection(a, b) === a
  end

  test "compare_bounds/4 on finite points" do
    a = floati(1.0, 2.0, "[]")
    assert Interval.compare_bounds(:left, a, :left, a) === :eq
    assert Interval.compare_bounds(:right, a, :right, a) === :eq

    a = floati(1.0, 2.0, "()")
    assert Interval.compare_bounds(:left, a, :left, a) === :eq
    assert Interval.compare_bounds(:right, a, :right, a) === :eq

    a = floati(0.5, 1.5, "[]")
    b = floati(1.0, 2.0, "()")
    assert Interval.compare_bounds(:left, a, :left, b) === :lt
    assert Interval.compare_bounds(:left, a, :right, b) === :lt
    assert Interval.compare_bounds(:right, a, :right, b) === :lt
    assert Interval.compare_bounds(:right, a, :left, b) === :gt

    a = floati(1.0, 2.0, "()")
    b = floati(0.5, 1.5, "[]")
    assert Interval.compare_bounds(:left, a, :left, b) === :gt
    assert Interval.compare_bounds(:left, a, :right, b) === :lt
    assert Interval.compare_bounds(:right, a, :right, b) === :gt
    assert Interval.compare_bounds(:right, a, :left, b) === :gt

    a = floati(1.0, 2.0, "[]")
    b = floati(1.0, 2.0, "()")
    assert Interval.compare_bounds(:left, a, :left, b) === :lt
    assert Interval.compare_bounds(:right, a, :right, b) === :gt
    assert Interval.compare_bounds(:left, a, :right, b) === :lt
    assert Interval.compare_bounds(:right, a, :left, b) === :gt

    a = floati(1.0, 2.0, "()")
    b = floati(1.0, 2.0, "[]")
    assert Interval.compare_bounds(:left, a, :left, b) === :gt
    assert Interval.compare_bounds(:right, a, :right, b) === :lt
    assert Interval.compare_bounds(:left, a, :right, b) === :lt
    assert Interval.compare_bounds(:right, a, :left, b) === :gt

    a = floati(1.0, 2.0, "()")
    b = floati(2.0, 3.0, "[]")
    assert Interval.compare_bounds(:right, a, :left, b) === :lt
    assert Interval.compare_bounds(:right, a, :right, b) === :lt
    assert Interval.compare_bounds(:left, a, :left, b) === :lt
    assert Interval.compare_bounds(:left, a, :right, b) === :lt

    a = floati(1.0, 2.0, "[]")
    b = floati(2.0, 3.0, "()")
    assert Interval.compare_bounds(:right, a, :left, b) === :lt
    assert Interval.compare_bounds(:right, a, :right, b) === :lt
    assert Interval.compare_bounds(:left, a, :left, b) === :lt
    assert Interval.compare_bounds(:left, a, :right, b) === :lt

    a = floati(1.0, 2.0, "[]")
    b = floati(2.0, 3.0, "[]")
    assert Interval.compare_bounds(:right, a, :left, b) === :eq
    assert Interval.compare_bounds(:right, a, :right, b) === :lt
    assert Interval.compare_bounds(:left, a, :left, b) === :lt
    assert Interval.compare_bounds(:left, a, :right, b) === :lt
    #
    a = floati(1.0, 2.0, "()")
    b = floati(0.0, 1.0, "[]")
    assert Interval.compare_bounds(:right, a, :left, b) === :gt
    assert Interval.compare_bounds(:right, a, :right, b) === :gt
    assert Interval.compare_bounds(:left, a, :left, b) === :gt
    assert Interval.compare_bounds(:left, a, :right, b) === :gt

    a = floati(1.0, 2.0, "[]")
    b = floati(0.0, 1.0, "()")
    assert Interval.compare_bounds(:right, a, :left, b) === :gt
    assert Interval.compare_bounds(:right, a, :right, b) === :gt
    assert Interval.compare_bounds(:left, a, :left, b) === :gt
    assert Interval.compare_bounds(:left, a, :right, b) === :gt

    a = floati(1.0, 2.0, "[]")
    b = floati(0.0, 1.0, "[]")
    assert Interval.compare_bounds(:right, a, :left, b) === :gt
    assert Interval.compare_bounds(:right, a, :right, b) === :gt
    assert Interval.compare_bounds(:left, a, :left, b) === :gt
    assert Interval.compare_bounds(:left, a, :right, b) === :eq
  end

  test "contains_point?/2" do
    refute Interval.contains_point?(inti(1, 2), 0)
    assert Interval.contains_point?(inti(1, 2), 1)
    refute Interval.contains_point?(inti(1, 2), 2)
    refute Interval.contains_point?(inti(1, 2), 3)

    assert Interval.contains_point?(inti(nil, 2), 0)
    assert Interval.contains_point?(inti(nil, 2), 1)
    refute Interval.contains_point?(inti(nil, 2), 2)
    refute Interval.contains_point?(inti(nil, 2), 3)

    refute Interval.contains_point?(inti(1, nil), 0)
    assert Interval.contains_point?(inti(1, nil), 1)
    assert Interval.contains_point?(inti(1, nil), 2)

    refute Interval.contains_point?(inti(1, 1), 0)
    refute Interval.contains_point?(inti(1, 1), 1)
    refute Interval.contains_point?(inti(1, 1), 2)

    # continuous
    assert Interval.contains_point?(floati(1.0, 2.0), 1.0)
    refute Interval.contains_point?(floati(1.0, 2.0), 2.0)
    assert Interval.contains_point?(floati(1.0, 2.0, "[]"), 2.0)
    assert Interval.contains_point?(floati(1.0, nil), 2.0)
    assert Interval.contains_point?(floati(nil, 3.0), 2.0)
    assert Interval.contains_point?(floati(nil, nil), 2.0)
  end

  test "contains?/2" do
    refute Interval.contains?(floati(1.0, 4.0, "()"), floati(1.0, 4.0, "[]"))
    assert Interval.contains?(floati(1.0, 4.0, "[]"), floati(1.0, 4.0, "()"))

    assert Interval.contains?(inti(1, 2), inti(1, 2))
    assert Interval.contains?(inti(nil, 2), inti(nil, 1))
    assert Interval.contains?(inti(1, nil), inti(2, nil))

    ## bound differs
    # same as discrete above for sanity
    assert Interval.contains?(floati(1.0, 2.0), floati(1.0, 2.0))
    assert Interval.contains?(floati(nil, 2.0), floati(nil, 1.0))
    assert Interval.contains?(floati(1.0, nil), floati(2.0, nil))
    # bounds differs but should still contain
    assert Interval.contains?(floati(1.0, 2.0, "[)"), floati(1.0, 2.0, "()"))
    assert Interval.contains?(floati(1.0, 2.0, "(]"), floati(1.0, 2.0, "()"))
    assert Interval.contains?(floati(1.0, 2.0, "[]"), floati(1.0, 2.0, "()"))
  end

  test "partition/2" do
    assert Interval.partition(inti(1, 4), 2) === [inti(1, 2), inti(2), inti(3)]
    assert Interval.partition(inti(1, 4), 1) === [inti(0, 0), inti(1, 2), inti(2, 4)]
    assert Interval.partition(inti(1, 4), 3) === [inti(1, 3), inti(3), inti(0, 0)]
    assert Interval.partition(inti(1, 4), 0) === []
    assert Interval.partition(inti(1, 4), 4) === []
  end

  test "partition/2's result unioned together is it's input interval" do
    a = inti(1, 4)

    b =
      a
      |> Interval.partition(2)
      |> Enum.reduce(&Interval.union/2)

    assert a === b
  end
end
