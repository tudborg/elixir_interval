defmodule IntervalTest do
  use ExUnit.Case

  alias Interval.Endpoint

  doctest Interval, import: true

  defp inter(p), do: Interval.single(p)
  defp inter(l, r), do: Interval.new(left: l, right: r)

  defp inter(l, r, bounds) do
    Interval.new(left: l, right: r, bounds: bounds)
  end

  test "new/1" do
    # some normal construction
    assert Interval.new(left: 1, right: 2)
    assert Interval.new(left: 1, right: 3, bounds: "()")

    # unbounded specified by the bounds
    assert ubr = Interval.new(left: 1, right: 1, bounds: "[")
    assert ubl = Interval.new(left: 1, right: 1, bounds: "]")
    assert Interval.unbounded_left?(ubl)
    assert Interval.unbounded_right?(ubr)
    assert Interval.new(left: 1, right: 1, bounds: "(")
    assert Interval.new(left: 1, right: 1, bounds: ")")
    assert Interval.new(left: 1, right: 1, bounds: "")

    assert Interval.new(left: 1.0, right: 2.0)
    assert Interval.new(left: 1.0, right: 3.0, bounds: "()")

    # discrete type normalization
    assert Interval.new(left: 1, right: 2) ===
             Interval.new(left: 1, right: 1, bounds: "[]")

    assert Interval.new(left: 1, right: 3, bounds: "()") ===
             Interval.new(left: 2, right: 2, bounds: "[]")

    # unbounded left and right and both
    assert Interval.new(left: 1) |> Interval.unbounded_right?()
    assert Interval.new(right: 1) |> Interval.unbounded_left?()
    assert Interval.new() |> Interval.unbounded_left?()
    assert Interval.new() |> Interval.unbounded_right?()

    # bounds on discrete type (bounds always normalized to '[)')
    assert Interval.new(left: 1, right: 2, bounds: "[)") |> Interval.inclusive_left?()
    assert Interval.new(left: 1, right: 2, bounds: "(]") |> Interval.inclusive_left?()
    refute Interval.new(left: 1, right: 2, bounds: "(]") |> Interval.inclusive_right?()
    refute Interval.new(left: 1, right: 2, bounds: "[)") |> Interval.inclusive_right?()

    # bounds on continuous type
    assert Interval.new(left: 1.0, right: 2.0, bounds: "[)") |> Interval.inclusive_left?()
    refute Interval.new(left: 1.0, right: 2.0, bounds: "(]") |> Interval.inclusive_left?()
    assert Interval.new(left: 1.0, right: 2.0, bounds: "(]") |> Interval.inclusive_right?()
    refute Interval.new(left: 1.0, right: 2.0, bounds: "[)") |> Interval.inclusive_right?()
  end

  test "normalize/1" do
    # normalizing an empty results in an empty.
    empty = Interval.new(left: 0, right: 0)
    assert Interval.normalize(empty) == empty

    # left and right type mismatch raises
    assert_raise RuntimeError, fn ->
      Interval.new(left: 0, right: 0.0)
    end

    # if left > right, raises
    left = Endpoint.new(2, :inclusive)
    right = Endpoint.new(1, :inclusive)

    assert_raise RuntimeError, fn ->
      Interval.from_endpoints(left, right)
    end
  end

  test "empty?/1" do
    # (1,1) should also be empty
    assert Interval.empty?(inter(1, 1, "()"))
    # [1,1] should not be empty
    refute Interval.empty?(inter(1, 1, "[]"))

    # Integer interval "(1,2)" should be empty
    # because neither 1 or 2 is in the interval,
    # and there is no integers between 1 and 2
    assert Interval.empty?(inter(1, 2, "()"))
    # but (1,3) should be non-empty because 2 is in the interval
    refute Interval.empty?(inter(1, 3, "()"))
  end

  test "inclusive_left?/1" do
    a = inter(1.0, 2.0, "[]")
    b = inter(1.0, 2.0, "()")
    empty = inter(1.0, 1.0, "()")
    assert Interval.inclusive_left?(a)
    refute Interval.inclusive_left?(b)
    refute Interval.inclusive_left?(empty)
  end

  test "inclusive_right?/1" do
    a = inter(1.0, 2.0, "[]")
    b = inter(1.0, 2.0, "()")
    empty = inter(1.0, 1.0, "()")
    assert Interval.inclusive_right?(a)
    refute Interval.inclusive_right?(b)
    refute Interval.inclusive_right?(empty)
  end

  test "strictly_left_of?/2" do
    a = inter(1, 3, "[]")

    refute Interval.strictly_left_of?(a, inter(0))
    refute Interval.strictly_left_of?(a, inter(1))
    refute Interval.strictly_left_of?(a, inter(2))
    refute Interval.strictly_left_of?(a, inter(3))
    assert Interval.strictly_left_of?(a, inter(4))
    assert Interval.strictly_left_of?(a, inter(4, 5))
  end

  test "strictly_right_of?/2" do
    a = inter(1, 3, "[]")

    assert Interval.strictly_right_of?(a, inter(0))
    refute Interval.strictly_right_of?(a, inter(1))
    refute Interval.strictly_right_of?(a, inter(2))
    refute Interval.strictly_right_of?(a, inter(3))
    refute Interval.strictly_right_of?(a, inter(4))
  end

  test "overlaps?/2" do
    # inclusive
    a = inter(1, 3, "[]")
    refute Interval.overlaps?(a, inter(0))
    assert Interval.overlaps?(a, inter(1))
    assert Interval.overlaps?(a, inter(2))
    assert Interval.overlaps?(a, inter(3))
    refute Interval.overlaps?(a, inter(4))

    # exclusive
    a = inter(1, 3, "()")
    refute Interval.overlaps?(a, inter(0))
    refute Interval.overlaps?(a, inter(1))
    assert Interval.overlaps?(a, inter(2))
    refute Interval.overlaps?(a, inter(3))
    refute Interval.overlaps?(a, inter(4))

    # {inclusive, exclusive} (default)
    a = inter(1, 3, "[)")
    refute Interval.overlaps?(a, inter(0))
    assert Interval.overlaps?(a, inter(1))
    assert Interval.overlaps?(a, inter(2))
    refute Interval.overlaps?(a, inter(3))
    refute Interval.overlaps?(a, inter(4))

    # {exclusive, inclusive}
    a = inter(1, 3, "(]")
    refute Interval.overlaps?(a, inter(0))
    refute Interval.overlaps?(a, inter(1))
    assert Interval.overlaps?(a, inter(2))
    assert Interval.overlaps?(a, inter(3))
    refute Interval.overlaps?(a, inter(4))

    ##
    # empty never overlaps with anything, not even itself:
    ##

    # Integers (discrete)
    refute Interval.overlaps?(inter(1, 1, "()"), inter(2, 2, "()"))
    refute Interval.overlaps?(inter(1, 1, "()"), inter(1, 1, "()"))
    refute Interval.overlaps?(inter(1, 3, "()"), inter(2, 2, "()"))
    refute Interval.overlaps?(inter(1, 2, "()"), inter(2, 3, "()"))
    # Floats (continuous)
    refute Interval.overlaps?(inter(1.0, 1.0, "()"), inter(1.0, 1.0, "()"))
    refute Interval.overlaps?(inter(1.0, 1.0, "()"), inter(2.0, 2.0, "()"))
  end

  test "intersection/2" do
    # intersection with empty is always empty (and we use the "empty" that was empty)
    assert Interval.intersection(inter(1, 10, "[]"), inter(3, 3, "()")) === inter(3, 3, "()")
    assert Interval.intersection(inter(1, 10, "[]"), inter(3, 4, "()")) === inter(3, 4, "()")

    # [----A----)
    #     [----B----)
    #     [--C--)
    assert Interval.intersection(inter(1, 3, "[)"), inter(2, 4, "[)")) ===
             inter(2, 3, "[)")

    assert Interval.intersection(inter(1.0, 3.0, "[)"), inter(2.0, 4.0, "[)")) ===
             inter(2.0, 3.0, "[)")
  end

  test "contains/2 regression 2022-10-07 - `,1)` failed to contain `[0,1)`" do
    a = %Interval{left: :unbounded, right: %Interval.Endpoint{inclusive: false, point: 1}}

    b = %Interval{
      left: %Interval.Endpoint{inclusive: true, point: 0},
      right: %Interval.Endpoint{inclusive: false, point: 1}
    }

    assert Interval.contains?(a, b)
  end
end
