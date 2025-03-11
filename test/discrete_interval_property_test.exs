defmodule DiscreteIntervalPropertyTest do
  use ExUnitProperties

  use ExUnit.Case,
    async: true,
    parameterize: [
      %{impl: Interval.IntegerInterval}
    ]

  setup ctx do
    # older versions of ExUnit do not support parameterize,
    # so we fall back to a signle discrete module to test
    Map.put_new(ctx, :impl, Interval.IntegerInterval)
  end

  property "overlaps?/2 is commutative", %{impl: impl} do
    check all(
            a <- Helper.interval(impl),
            b <- Helper.interval(impl)
          ) do
      assert Interval.overlaps?(a, b) === Interval.overlaps?(b, a)
    end
  end

  property "union/2 is commutative", %{impl: impl} do
    check all(
            a <- Helper.interval(impl),
            b <- Helper.interval(impl)
          ) do
      cond do
        Interval.overlaps?(a, b) ->
          assert Interval.union(a, b) === Interval.union(b, a)

        Interval.adjacent?(a, b) ->
          assert Interval.union(a, b) === Interval.union(b, a)

        Interval.empty?(a) and not Interval.empty?(b) ->
          assert Interval.union(a, b) === b

        Interval.empty?(b) and not Interval.empty?(a) ->
          assert Interval.union(a, b) === a

        Interval.empty?(a) and Interval.empty?(b) ->
          assert Interval.empty?(Interval.union(a, b))
          assert Interval.empty?(Interval.union(b, a))

        not Interval.empty?(b) and not Interval.empty?(a) ->
          assert_raise Interval.IntervalOperationError, fn ->
            Interval.union(a, b)
          end
      end
    end
  end

  property "intersection/2 is commutative", %{impl: impl} do
    check all(
            a <- Helper.interval(impl),
            b <- Helper.interval(impl)
          ) do
      assert Interval.intersection(a, b) === Interval.intersection(b, a)
    end
  end

  property "intersection/2's relationship with contains?/2", %{impl: impl} do
    check all(
            a <- Helper.interval(impl),
            b <- Helper.interval(impl)
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

  property "difference/2", %{impl: impl} do
    check all(
            a <- Helper.interval(impl),
            b <- Helper.interval(impl)
          ) do
      cond do
        # if a does not overlap b, we always expect first argument back
        not Interval.overlaps?(a, b) ->
          assert Interval.difference(a, b) === a

        # if a contains b, and a does not share an endpoint with b, difference/2 would raise
        Interval.contains?(a, b) and not (a.left == b.left or a.right == b.right) ->
          assert_raise Interval.IntervalOperationError, fn ->
            Interval.difference(a, b)
          end

        # if a overlaps b, we are always going to to change a
        Interval.overlaps?(a, b) ->
          assert Interval.difference(a, b) !== a
      end
    end
  end

  property "contains?/2 & contains_point?/2", %{impl: impl} do
    check all(
            a <- Helper.interval(impl),
            b <- Helper.interval(impl)
          ) do
      cond do
        Interval.empty?(a) and not Interval.empty?(b) ->
          refute Interval.contains?(a, b)

        Interval.empty?(b) ->
          assert Interval.contains?(a, b)

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
                assert Interval.contains_point?(a, impl.point_step(p, -1))
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
                assert Interval.contains_point?(b, impl.point_step(p, -1))
            end
          end
      end
    end
  end

  property "strictly_left_of?/2 and strictly_right_of?/2 relationship", %{impl: impl} do
    check all(
            a <- Helper.interval(impl, empty: false),
            b <- Helper.interval(impl, empty: false)
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

  property "adjacent_left_of?/2 and adjacent_right_of?/2 relationship", %{impl: impl} do
    check all(
            a <- Helper.interval(impl, empty: false),
            b <- Helper.interval(impl, empty: false)
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

  property "partition/2", %{impl: impl} do
    check all(
            a <- Helper.interval(impl),
            b <- Helper.interval(impl)
          ) do
      if Interval.contains?(a, b) and not Interval.empty?(b) do
        [p1, p2, p3] = Interval.partition(a, b)
        # the middle partition is b (when b is an interval)
        assert p2 == b
        # a contains p1,p2,p3 (since we sliced up a in 3 parts)
        assert Interval.contains?(a, p1)
        assert Interval.contains?(a, p3)
        # the union of p1,p2,3 is a
        a_prime = p1 |> Interval.union(p2) |> Interval.union(p3)
        assert a_prime == a

        if Interval.unbounded_left?(b) do
          assert Interval.empty?(p1)
        end

        if Interval.unbounded_right?(b) do
          assert Interval.empty?(p3)
        end
      else
        assert [] == Interval.partition(a, b)
      end
    end
  end
end
