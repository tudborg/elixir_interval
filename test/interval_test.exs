defmodule Interval.IntervalTest do
  use ExUnit.Case, async: true

  doctest Interval, import: true

  defp inti(p), do: inti(p, p, "[]")
  defp inti(l, r), do: inti(l, r, nil)
  defp inti(l, r, bounds), do: Interval.Integer.new(left: l, right: r, bounds: bounds)

  # defp floati(p), do: floati(p, p, "[]")
  defp floati(l, r), do: floati(l, r, nil)
  defp floati(l, r, bounds), do: Interval.Float.new(left: l, right: r, bounds: bounds)

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

  test "size/1" do
    # size of  unbounded intervals is  nil
    assert 0 === Interval.size(inti(:empty, :empty))
    assert 1 === Interval.size(inti(1, 2))
    assert nil === Interval.size(inti(nil, 1))
    assert nil === Interval.size(inti(1, nil))
    assert nil === Interval.size(inti(nil, nil))

    # size of bounded intervals
    assert 0.0 === Interval.size(floati(1.0, 1.0, "()"))
    assert 1.0 === Interval.size(floati(1.0, 2.0))
    assert nil === Interval.size(floati(1.0, nil))
    assert nil === Interval.size(floati(nil, 2.0))
    assert nil === Interval.size(floati(nil, nil))

    assert 0 === Interval.size(Interval.Date.new(left: :empty, right: :empty))
    assert nil === Interval.size(Interval.Date.new(left: ~D[2021-01-01]))
    assert nil === Interval.size(Interval.Date.new(right: ~D[2021-01-01]))
    assert nil === Interval.size(Interval.Date.new())
    assert 31 === Interval.size(Interval.Date.new(left: ~D[2021-01-01], right: ~D[2021-02-01]))

    assert 0.0 === Interval.size(Interval.DateTime.new(left: :empty, right: :empty))
    assert nil === Interval.size(Interval.DateTime.new(left: ~U[2021-01-01 00:00:00Z]))
    assert nil === Interval.size(Interval.DateTime.new(right: ~U[2021-01-01 00:00:00Z]))
    assert nil === Interval.size(Interval.DateTime.new())

    assert 31 * 86_400 ===
             Interval.size(
               Interval.DateTime.new(
                 left: ~U[2021-01-01 00:00:00Z],
                 right: ~U[2021-02-01 00:00:00Z]
               )
             )

    assert 0.0 === Interval.size(Interval.NaiveDateTime.new(left: :empty, right: :empty))
    assert nil === Interval.size(Interval.NaiveDateTime.new(left: ~N[2021-01-01 00:00:00]))
    assert nil === Interval.size(Interval.NaiveDateTime.new(right: ~N[2021-01-01 00:00:00]))
    assert nil === Interval.size(Interval.NaiveDateTime.new())

    assert 31 * 86_400 ===
             Interval.size(
               Interval.NaiveDateTime.new(
                 left: ~N[2021-01-01 00:00:00],
                 right: ~N[2021-02-01 00:00:00]
               )
             )
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
    non_normalized_1 = %Interval.Integer{
      left: {:exclusive, 1},
      right: {:exclusive, 2}
    }

    assert Interval.empty?(non_normalized_1)

    non_normalized_2 = %Interval.Integer{
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
    a = %Interval.Integer{left: :unbounded, right: {:inclusive, 1}}
    b = %Interval.Integer{left: {:inclusive, 1}, right: :unbounded}

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
    a = %Interval.Integer{left: {:inclusive, 1}, right: :unbounded}
    b = %Interval.Integer{left: :unbounded, right: {:inclusive, 1}}

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

  test "to_map/1" do
    assert Interval.to_map(inti(1, 4)) ===
             %{
               type: "Interval.Integer",
               empty: false,
               left: %{inclusive: true, value: 1},
               right: %{inclusive: false, value: 4}
             }

    assert Interval.to_map(inti(1, nil)) ===
             %{
               type: "Interval.Integer",
               empty: false,
               left: %{inclusive: true, value: 1},
               right: nil
             }

    assert Interval.to_map(inti(1, 1)) ===
             %{
               type: "Interval.Integer",
               empty: true,
               left: nil,
               right: nil
             }
  end
end
