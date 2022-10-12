defmodule IntervalTest do
  use ExUnit.Case

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
    left = {:inclusive, 2}
    right = {:inclusive, 1}

    assert_raise RuntimeError, fn ->
      Interval.from_endpoints(left, right)
    end
  end

  test "size/1" do
    # size of  unbounded intervals is  nil
    assert nil === Interval.size(inter(nil, nil))
    assert nil === Interval.size(inter(nil, 1))
    assert nil === Interval.size(inter(1, nil))

    # size of bounded intervals
    assert 1 === Interval.size(inter(1, 2))
    assert 1.0 === Interval.size(inter(1.0, 2.0))

    # specifying units
    assert 31 === Interval.size(inter(~D[2021-01-01], ~D[2021-02-01]))
    assert 31 === Interval.size(inter(~D[2021-01-01], ~D[2021-02-01]), nil)

    assert 31 * 86_400 ===
             Interval.size(inter(~U[2021-01-01 00:00:00Z], ~U[2021-02-01 00:00:00Z]), :second)
  end

  test "empty?/1" do
    # (1,1) should also be empty
    assert Interval.empty?(inter(1, 1, "()"))
    # [1,1] should not be empty
    refute Interval.empty?(inter(1, 1, "[]"))
    # [1,1) and (1,1] normalises to empty
    assert Interval.empty?(inter(1, 1, "[)"))
    assert Interval.empty?(inter(1, 1, "(]"))

    # Integer interval "(1,2)" should be empty
    # because neither 1 or 2 is in the interval,
    # and there is no integers between 1 and 2
    assert Interval.empty?(inter(1, 2, "()"))
    # but (1,3) should be non-empty because 2 is in the interval
    refute Interval.empty?(inter(1, 3, "()"))

    # Check that even non-normalized intervals correctly indicates empty
    non_normalized_1 = %Interval{
      left: {:exclusive, 1},
      right: {:exclusive, 2}
    }

    assert Interval.empty?(non_normalized_1)

    non_normalized_2 = %Interval{
      left: {:exclusive, 1},
      right: {:inclusive, 1}
    }

    assert Interval.empty?(non_normalized_2)
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

  test "adjacent_left_of?/2" do
    assert Interval.adjacent_left_of?(inter(1, 2), inter(2, 3))
    refute Interval.adjacent_left_of?(inter(1, 2), inter(3, 4))
    refute Interval.adjacent_left_of?(inter(nil, nil), inter(1, 2))
    refute Interval.adjacent_left_of?(inter(1, 2), inter(nil, nil))

    # non-normalized bounds should raise:
    a = %Interval{left: :unbounded, right: {:inclusive, 1}}
    b = %Interval{left: {:inclusive, 1}, right: :unbounded}

    assert_raise RuntimeError, fn ->
      Interval.adjacent_left_of?(a, b)
    end
  end

  test "adjacent_right_of?/2" do
    assert Interval.adjacent_right_of?(inter(2, 3), inter(1, 2))
    refute Interval.adjacent_right_of?(inter(3, 4), inter(1, 2))
    refute Interval.adjacent_right_of?(inter(1, 2), inter(nil, nil))
    refute Interval.adjacent_right_of?(inter(nil, nil), inter(1, 2))

    # non-normalized bounds should raise:
    a = %Interval{left: {:inclusive, 1}, right: :unbounded}
    b = %Interval{left: :unbounded, right: {:inclusive, 1}}

    assert_raise RuntimeError, fn ->
      Interval.adjacent_right_of?(a, b)
    end
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

    # testing min_endpoint and max_endpoint
    assert Interval.intersection(inter(2.0, 3.0, "[]"), inter(2.0, 3.0, "[]")) ===
             inter(2.0, 3.0, "[]")

    assert Interval.intersection(inter(2.0, 3.0, "()"), inter(2.0, 3.0, "()")) ===
             inter(2.0, 3.0, "()")

    assert Interval.intersection(inter(2.0, 3.0, "()"), inter(2.0, 3.0, "[]")) ===
             inter(2.0, 3.0, "()")

    assert Interval.intersection(inter(2.0, 3.0, "()"), inter(2.0, 3.0, "(]")) ===
             inter(2.0, 3.0, "()")
  end

  test "intersection/2 with unbounded intervals" do
    a = Interval.new(left: 1, right: 3)
    b = Interval.new(left: 0, right: nil)
    assert Interval.intersection(a, b) === Interval.intersection(b, a)
    assert Interval.intersection(a, b) === a
  end

  test "contains_point?/2" do
    refute Interval.contains_point?(inter(1, 2), 0)
    assert Interval.contains_point?(inter(1, 2), 1)
    refute Interval.contains_point?(inter(1, 2), 2)
    refute Interval.contains_point?(inter(1, 2), 3)

    assert Interval.contains_point?(inter(nil, 2), 0)
    assert Interval.contains_point?(inter(nil, 2), 1)
    refute Interval.contains_point?(inter(nil, 2), 2)
    refute Interval.contains_point?(inter(nil, 2), 3)

    refute Interval.contains_point?(inter(1, nil), 0)
    assert Interval.contains_point?(inter(1, nil), 1)
    assert Interval.contains_point?(inter(1, nil), 2)
  end

  test "partition/2" do
    assert Interval.partition(inter(1, 4), 2) === [inter(1, 2), inter(2), inter(3)]
    assert Interval.partition(inter(1, 4), 1) === [inter(0, 0), inter(1, 2), inter(2, 4)]
    assert Interval.partition(inter(1, 4), 3) === [inter(1, 3), inter(3), inter(0, 0)]
    assert Interval.partition(inter(1, 4), 0) === []
    assert Interval.partition(inter(1, 4), 4) === []
  end

  test "contains/2 regression 2022-10-07 - `,1)` failed to contain `[0,1)`" do
    a = %Interval{left: :unbounded, right: {:exclusive, 1}}

    b = %Interval{
      left: {:inclusive, 0},
      right: {:exclusive, 1}
    }

    assert Interval.contains?(a, b)
  end

  test "intersection regression 2022-10-12 - incorrect bounds" do
    # The bad code wanted this intersection to be [2.0,3.0], but it should be [2.0,3.0)
    assert Interval.intersection(
             inter(2.0, 3.0, "[)"),
             inter(2.0, 3.0, "[]")
           ) === inter(2.0, 3.0, "[)")
  end
end
