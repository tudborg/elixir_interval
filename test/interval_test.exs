defmodule Interval.IntervalTest do
  use ExUnit.Case, async: true

  doctest Interval, import: true

  alias Interval.IntegerInterval
  alias Interval.FloatInterval
  alias DateIntervalInterval
  alias DateTimeIntervalInterval

  def inti(p), do: inti(p, p, "[]")
  def inti(left, right, bounds \\ "[)"), do: IntegerInterval.new(left, right, bounds)

  def floati(p), do: floati(p, p, "[]")
  def floati(left, right, bounds \\ "[)"), do: FloatInterval.new(left, right, bounds)

  test "new/1" do
    # some normal construction
    assert IntegerInterval.new(1, 1)
    assert IntegerInterval.new(1, 3, "()")

    assert IntegerInterval.new(empty: true)
    assert IntegerInterval.new(left: :empty)
    assert IntegerInterval.new(right: :empty)

    # unbounded specified by the bounds
    assert ubr = IntegerInterval.new(1, 1, "[")
    assert ubl = IntegerInterval.new(1, 1, "]")
    assert Interval.unbounded_left?(ubl)
    assert Interval.unbounded_right?(ubr)
    assert IntegerInterval.new(1, 1, "(")
    assert IntegerInterval.new(1, 1, ")")
    assert IntegerInterval.new(1, 1, "")

    assert FloatInterval.new(1.0, 2.0)
    assert FloatInterval.new(1.0, 3.0, "()")

    # discrete type normalization
    assert IntegerInterval.new(1, 2) ===
             IntegerInterval.new(1, 1, "[]")

    assert IntegerInterval.new(1, 3, "()") ===
             IntegerInterval.new(2, 2, "[]")

    assert_raise ArgumentError, fn ->
      IntegerInterval.new(1.0, 2.0, "[]")
    end
  end

  test "value retrieval functions" do
    a = inti(1, 2, "[)")

    assert 1 == Interval.left(a)
    assert 2 == Interval.right(a)

    a = inti(nil, nil)

    assert nil == Interval.left(a)
    assert nil == Interval.right(a)

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

    assert Interval.empty?(%IntegerInterval{left: :empty, right: :unbounded})
    assert Interval.empty?(%IntegerInterval{left: :unbounded, right: :empty})
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

    refute Interval.strictly_left_of?(a, inti(nil, nil))
    refute Interval.strictly_left_of?(a, inti(0))
    refute Interval.strictly_left_of?(a, inti(1))
    refute Interval.strictly_left_of?(a, inti(2))
    refute Interval.strictly_left_of?(a, inti(3))
    assert Interval.strictly_left_of?(a, inti(4))
    assert Interval.strictly_left_of?(a, inti(4, 5))

    refute Interval.strictly_left_of?(inti(nil, nil), inti(0))
  end

  test "strictly_right_of?/2" do
    a = inti(1, 3, "[]")

    assert Interval.strictly_right_of?(a, inti(0))
    refute Interval.strictly_right_of?(a, inti(1))
    refute Interval.strictly_right_of?(a, inti(2))
    refute Interval.strictly_right_of?(a, inti(3))
    refute Interval.strictly_right_of?(a, inti(4))
    refute Interval.strictly_right_of?(a, inti(nil, nil))

    refute Interval.strictly_right_of?(inti(nil, nil), inti(0))
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

  test "adjacent?/2" do
    # integers
    assert Interval.adjacent?(inti(1, 2), inti(2, 3))
    assert Interval.adjacent?(inti(1, 2, "[]"), inti(3, 4, "[]"))
    refute Interval.adjacent?(inti(1, 2), inti(4, 5))
    refute Interval.adjacent?(inti(nil, nil), inti(1, 2))
    refute Interval.adjacent?(inti(1, 2), inti(nil, nil))

    # floats
    assert Interval.adjacent?(floati(1.0, 2.0), floati(2.0, 3.0))
    refute Interval.adjacent?(floati(1.0, 2.0), floati(3.0, 4.0))
    refute Interval.adjacent?(floati(1.0, 2.0), floati(4.0, 5.0))

    refute Interval.adjacent?(floati(1.0, 2.0, "[]"), floati(2.0, 3.0, "[]"))
    assert Interval.adjacent?(floati(1.0, 2.0, "[)"), floati(2.0, 3.0, "[]"))
    assert Interval.adjacent?(floati(1.0, 2.0, "[]"), floati(2.0, 3.0, "(]"))
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

  test "union/2" do
    assert Interval.union(inti(1, 3, "[]"), inti(2, 4, "[]")) === inti(1, 4, "[]")
    assert Interval.union(inti(2, 4, "[]"), inti(1, 3, "[]")) === inti(1, 4, "[]")

    assert Interval.union(inti(:empty), inti(0, 3, "()")) === inti(0, 3, "()")
    assert Interval.union(inti(0, 3, "()"), inti(:empty)) === inti(0, 3, "()")
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

    # one is empty
    assert Interval.intersection(inti(1, 3, "[)"), inti(:empty)) === inti(:empty)
    assert Interval.intersection(inti(:empty), inti(1, 3, "[)")) === inti(:empty)

    # disjoint
    assert Interval.intersection(inti(1, 3, "[)"), inti(4, 5, "[)")) === inti(:empty)
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

    a = floati(0.0, 1.0, "()")
    b = floati(1.0, 2.0, "()")
    assert Interval.compare_bounds(:right, a, :left, b) === :lt
    assert Interval.compare_bounds(:right, a, :right, b) === :lt
    assert Interval.compare_bounds(:left, a, :left, b) === :lt
    assert Interval.compare_bounds(:left, a, :right, b) === :lt

    a = floati(1.0, 2.0, "()")
    b = floati(0.0, 1.0, "()")
    assert Interval.compare_bounds(:right, a, :left, b) === :gt
    assert Interval.compare_bounds(:right, a, :right, b) === :gt
    assert Interval.compare_bounds(:left, a, :left, b) === :gt
    assert Interval.compare_bounds(:left, a, :right, b) === :gt
  end

  test "compare_bounds/4 - unboundeded and empty endpoints" do
    assert_raise Interval.IntervalOperationError, fn ->
      Interval.compare_bounds(:left, floati(:empty), :left, floati(0.0, 1.0, "[]"))
    end

    assert_raise Interval.IntervalOperationError, fn ->
      Interval.compare_bounds(:left, floati(0.0, 1.0, "[]"), :left, floati(:empty))
    end

    a = floati(nil, 1.0)
    b = floati(nil, 2.0)
    assert Interval.compare_bounds(:left, a, :left, b) === :eq
    assert Interval.compare_bounds(:left, a, :right, b) === :lt
    assert Interval.compare_bounds(:right, a, :right, b) === :lt
    assert Interval.compare_bounds(:right, a, :left, b) === :gt

    a = floati(nil, nil)
    b = floati(nil, nil)
    assert Interval.compare_bounds(:left, a, :left, b) === :eq
    assert Interval.compare_bounds(:left, a, :right, b) === :lt
    assert Interval.compare_bounds(:right, a, :right, b) === :eq
    assert Interval.compare_bounds(:right, a, :left, b) === :gt
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

  test "partition/2 around a point" do
    assert Interval.partition(inti(1, 4), 2) === [inti(1, 2), inti(2), inti(3)]
    assert Interval.partition(inti(1, 4), 1) === [inti(0, 0), inti(1, 2), inti(2, 4)]
    assert Interval.partition(inti(1, 4), 3) === [inti(1, 3), inti(3), inti(0, 0)]
    assert Interval.partition(inti(1, 4), 0) === []
    assert Interval.partition(inti(1, 4), 4) === []

    assert Interval.partition(floati(1.0, 3.0, "[)"), 2.0) === [
             floati(1.0, 2.0, "[)"),
             floati(2.0, 2.0, "[]"),
             floati(2.0, 3.0, "()")
           ]

    assert Interval.partition(floati(nil, nil, "[]"), 2.0) === [
             floati(nil, 2.0, "[)"),
             floati(2.0, 2.0, "[]"),
             floati(2.0, nil, "()")
           ]

    assert Interval.partition(inti(1, 4), 4) === []
  end

  test "partition/2 around an interval" do
    a = inti(1, 4)
    b = inti(2, 2, "[]")
    assert Interval.partition(a, b) === [inti(1, 2), inti(2, 2, "[]"), inti(3)]

    a = inti(1, 4)
    b = inti(nil, nil)
    assert Interval.partition(a, b) === []

    a = inti(nil, 5)
    b = inti(2, 3, "[]")
    assert Interval.partition(a, b) === [inti(nil, 2), inti(2, 3, "[]"), inti(3, 5, "()")]

    a = inti(1, nil)
    b = inti(2, 3, "[]")
    assert Interval.partition(a, b) === [inti(1, 2, "[)"), inti(2, 3, "[]"), inti(3, nil, "()")]

    a = inti(nil, nil)
    b = inti(1, 2)
    assert Interval.partition(a, b) === [inti(nil, 1), inti(1, 2), inti(2, nil)]

    a = inti(nil, nil)
    b = inti(nil, nil)
    assert Interval.partition(a, b) === [inti(:empty), inti(nil, nil), inti(:empty)]

    a = inti(nil, nil)
    b = inti(nil, 2)
    assert Interval.partition(a, b) === [inti(:empty), inti(nil, 2), inti(2, nil)]

    a = inti(nil, nil)
    b = inti(2, nil)
    assert Interval.partition(a, b) === [inti(nil, 2), inti(2, nil), inti(:empty)]
  end

  test "partition/2's result unioned together is it's input interval" do
    a = inti(1, 4)
    b = a |> Interval.partition(2) |> Enum.reduce(&Interval.union/2)
    assert a === b
  end

  test "difference/2" do
    empty = inti(1, 1, "()")
    ##
    # Discrete interval
    ##
    # a - a = empty
    assert Interval.difference(inti(1, 4), inti(1, 4)) === empty
    # a - empty = a
    assert Interval.difference(inti(1, 4), empty) === inti(1, 4)
    # empty - a = empty
    assert Interval.difference(empty, inti(1, 4)) === empty
    # a - b when b covers left side of a
    assert Interval.difference(inti(1, 4), inti(0, 2)) === inti(2, 4)
    # a - b when b covers right side of a
    assert Interval.difference(inti(1, 4), inti(3, 5)) === inti(1, 3)
    # a - b when b covers a = empty
    assert Interval.difference(inti(1, 4), inti(0, 5)) === empty
    # a - b when a covers b is Error
    assert_raise Interval.IntervalOperationError, fn ->
      Interval.difference(inti(1, 4), inti(2, 3))
    end

    # b's endpoint matches a's endpoint on one side exactly
    assert Interval.difference(inti(1, 4), inti(3, 4)) === inti(1, 3)
    assert Interval.difference(inti(1, 4), inti(1, 2)) === inti(2, 4)

    # unbounded endpoints
    # different mutations of unbounded b (where b covers a completely)
    assert Interval.difference(inti(1, 4), inti(nil, nil)) === empty
    assert Interval.difference(inti(1, 4), inti(0, nil)) === empty
    assert Interval.difference(inti(1, 4), inti(nil, 5)) === empty
    # b only partially covers a
    assert Interval.difference(inti(1, 4), inti(2, nil)) === inti(1, 2)
    assert Interval.difference(inti(1, 4), inti(nil, 3)) === inti(3, 4)
    # a also unbounded and b is not
    assert_raise Interval.IntervalOperationError, fn ->
      Interval.difference(inti(nil, nil), inti(1, 4))
    end

    # a is unbounded and b is unbounded
    assert Interval.difference(inti(1, nil), inti(2, nil)) === inti(1, 2)
    assert Interval.difference(inti(nil, 4), inti(nil, 3)) === inti(3, 4)
    assert Interval.difference(inti(nil, 4), inti(nil, nil)) === empty
    assert Interval.difference(inti(1, nil), inti(nil, nil)) === empty
    assert Interval.difference(inti(nil, nil), inti(nil, nil)) === empty
    assert Interval.difference(inti(nil, nil), inti(nil, 3)) === inti(3, nil)
    assert Interval.difference(inti(nil, nil), inti(3, nil)) === inti(nil, 3)

    assert Interval.difference(inti(1, 2), inti(3, 4)) === inti(1, 2)
    assert Interval.difference(inti(3, 4), inti(1, 2)) === inti(3, 4)

    ##
    # Continuous interval
    ##
    # (we don't need to cover the basics, because those are the asme as for discrete intervals
    # but we want to make sure we've covered what happens at the endpoints with bounds)
    # empty = floati(1.0, 1.0, "()")

    assert Interval.difference(floati(3.0, 5.0), floati(3.0, 5.0)) === floati(:empty)

    assert Interval.difference(floati(1.0, 4.0, "[]"), floati(3.0, 4.0, "[]")) ===
             floati(1.0, 3.0, "[)")

    assert Interval.difference(floati(1.0, 4.0, "[]"), floati(1.0, 2.0, "[]")) ===
             floati(2.0, 4.0, "(]")

    # a: [------)
    # b:    [------)
    a = floati(1.0, 4.0, "[)")
    b = floati(3.0, 5.0, "[)")
    assert Interval.difference(a, b) === floati(1.0, 3.0, "[)")

    # a: [------]
    # b:    (------]
    a = floati(1.0, 4.0, "[]")
    b = floati(3.0, 5.0, "(]")
    assert Interval.difference(a, b) === floati(1.0, 3.0, "[]")

    # a: [-----------]
    # b:   (------)
    a = floati(1.0, 5.0, "[]")
    b = floati(3.0, 4.0, "()")

    assert_raise Interval.IntervalOperationError, fn ->
      Interval.difference(a, b)
    end

    assert Interval.difference(b, a) === floati(:empty)
  end
end
