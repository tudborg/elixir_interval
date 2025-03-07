defmodule IntegerIntervalIntervalPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Interval.IntegerInterval

  property "overlaps?/2 is commutative" do
    check all(
            a <- Helper.integer_interval(),
            b <- Helper.integer_interval()
          ) do
      assert Interval.overlaps?(a, b) === Interval.overlaps?(b, a)
    end
  end

  property "union/2 is commutative" do
    check all(
            a <- Helper.integer_interval(),
            b <- Helper.integer_interval()
          ) do
      assert Interval.union(a, b) === Interval.union(b, a)
    end
  end

  property "intersection/2 is commutative" do
    check all(
            a <- Helper.integer_interval(),
            b <- Helper.integer_interval()
          ) do
      assert Interval.intersection(a, b) === Interval.intersection(b, a)
    end
  end

  property "intersection/2's relationship with contains?/2" do
    check all(
            a <- Helper.integer_interval(),
            b <- Helper.integer_interval()
          ) do
      intersection = Interval.intersection(a, b)

      cond do
        # when A contains B (or later, B contains A) then the
        # intersection between the two intervals will be the contained one.
        Interval.contains?(a, b) ->
          assert intersection === b

        Interval.contains?(b, a) ->
          assert intersection === a

        true ->
          assert Interval.intersection(a, b) === Interval.intersection(b, a)
      end
    end
  end

  property "contains?/2 & contains_point?/2" do
    check all(
            a <- Helper.integer_interval(),
            b <- Helper.integer_interval()
          ) do
      cond do
        Interval.empty?(a) or Interval.empty?(b) ->
          refute Interval.contains?(a, b)
          refute Interval.contains?(b, a)

        a == b ->
          assert Interval.contains?(a, b)
          assert Interval.contains?(b, a)

        a != b ->
          a_contains_b = Interval.contains?(a, b)
          b_contains_a = Interval.contains?(b, a)

          assert(
            (a_contains_b and not b_contains_a) or
              (b_contains_a and not a_contains_b) or
              (not a_contains_b and not b_contains_a)
          )

          if a_contains_b do
            case b.left do
              :unbounded -> :ok
              {:inclusive, p} -> assert Interval.contains_point?(a, p)
            end

            case b.right do
              :unbounded ->
                :ok

              {:exclusive, p} ->
                assert Interval.contains_point?(a, IntegerInterval.point_step(p, -1))
            end
          end

          if b_contains_a do
            case a.left do
              :unbounded -> :ok
              {:inclusive, p} -> assert Interval.contains_point?(b, p)
            end

            case a.right do
              :unbounded ->
                :ok

              {:exclusive, p} ->
                assert Interval.contains_point?(b, IntegerInterval.point_step(p, -1))
            end
          end
      end
    end
  end

  property "strictly_left_of?/2 and strictly_right_of?/2 relationship" do
    check all(
            a <- Helper.integer_interval(empty: false),
            b <- Helper.integer_interval(empty: false)
          ) do
      if Interval.overlaps?(a, b) do
        refute Interval.strictly_left_of?(a, b)
        refute Interval.strictly_right_of?(a, b)
      else
        if Interval.strictly_left_of?(a, b) do
          refute Interval.overlaps?(a, b)
          refute Interval.strictly_right_of?(a, b)
        end

        if Interval.strictly_right_of?(a, b) do
          refute Interval.overlaps?(a, b)
          refute Interval.strictly_left_of?(a, b)
        end
      end
    end
  end

  property "adjacent_left_of?/2 and adjacent_right_of?/2 relationship" do
    check all(
            a <- Helper.integer_interval(empty: false),
            b <- Helper.integer_interval(empty: false)
          ) do
      if Interval.overlaps?(a, b) do
        refute Interval.adjacent_left_of?(a, b)
        refute Interval.adjacent_right_of?(a, b)
      else
        if Interval.adjacent_left_of?(a, b) do
          refute Interval.overlaps?(a, b)
          refute Interval.adjacent_right_of?(a, b)
        end

        if Interval.adjacent_right_of?(a, b) do
          refute Interval.overlaps?(a, b)
          refute Interval.adjacent_left_of?(a, b)
        end
      end
    end
  end
end
