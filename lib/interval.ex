defmodule Interval do
  @moduledoc """
  An interval represents the points between two endpoints.

  The interval can be empty.
  The empty interval is never contained in any other interval,
  and contains itself no points.

  It can also be left and/or right unbounded, in which case
  it contains all points in the unbounded direction.
  A fully unbounded interval contains all other intervals, except
  the empty interval.
  """

  alias Interval.Point
  alias Interval.Endpoint

  defstruct left: nil, right: nil

  @typedoc """
  The `Interval` struct, representing all points between
  two endpoints.

  The struct has two fields: `left` and `right`,
  representing the left (lower) and right (upper) points
  in the interval.

  The endpoints are stored as an `t:Interval.Endpoint.t/0` or
  the atom `:unbounded`.  

  A special case exists for the empty interval,
  which is represented by both `left` and `right` being
  set to the atom `:empty`

  """
  @type t() :: %__MODULE__{
          # Left endpoint
          left: :empty | :unbounded | Interval.Endpoint.t(),
          # Right  endpoint
          right: :empty | :unbounded | Interval.Endpoint.t(),
        }

  @doc """
  Create a new Interval containing a single point.
  """
  def single(point) when not is_list(point) do
    # assert that Point is implemented for given variable
    true = Point.type(point) in [:discrete, :continuous]
    endpoint = Endpoint.inclusive(point)
    from_endpoints(endpoint, endpoint)
  end

  @doc """
  Create a new unbounded interval
  """

  def new(opts \\ [])

  def new(opts) when is_list(opts) do
    left = Keyword.get(opts, :left, nil)
    right = Keyword.get(opts, :right, nil)
    bounds = Keyword.get(opts, :bounds, "[)")
    {left_bound, right_bound} = unpack_bounds(bounds)

    left_endpoint =
      case {left, left_bound} do
        {nil, _} -> :unbounded
        {_, :unbounded} -> :unbounded
        {_, :inclusive} -> Endpoint.inclusive(left)
        {_, :exclusive} -> Endpoint.exclusive(left)
      end

    right_endpoint =
      case {right, right_bound} do
        {nil, _} -> :unbounded
        {_, :unbounded} -> :unbounded
        {_, :inclusive} -> Endpoint.inclusive(right)
        {_, :exclusive} -> Endpoint.exclusive(right)
      end

    from_endpoints(left_endpoint, right_endpoint)
  end

  def from_endpoints(left, right)
      when (left == :unbounded or is_struct(left, Endpoint)) and
             (right == :unbounded or is_struct(right, Endpoint)) do
    %__MODULE__{left: left, right: right}
    |> normalize()
  end

  @doc """
  Normalize an `Interval` struct
  """
  # lef and right endpoints set to :empty, special case for normalized empty interval
  def normalize(%__MODULE__{left: :empty, right: :empty} = self), do: self
  # non-empty non-unbounded Interval:
  def normalize(%__MODULE__{left: %Endpoint{} = left, right: %Endpoint{} = right} = original) do
    left_point_impl = Point.impl_for(left.point)
    right_point_impl = Point.impl_for(right.point)

    if left_point_impl != right_point_impl do
      raise """
      The Interval.Point implementation for the left and right side
      of the interval must be identical, but got
      left=#{left_point_impl},  right=#{right_point_impl}
      """
    end

    type = Point.type(left.point)
    comp = Point.compare(left.point, right.point)
    left_inclusive = Endpoint.inclusive?(left)
    right_inclusive = Endpoint.inclusive?(right)

    case {type, comp, left_inclusive, right_inclusive} do
      # left > right is an error:
      {_, :gt, _, _} ->
        raise "left > right which is invalid"

      # intervals given as either (p,p), [p,p) or (p,p]
      # are all normalized to empty.
      # (If you want a single point in an interval, give it as [p,p])
      {_, :eq, false, false} ->
        into_empty(original)

      {_, :eq, true, false} ->
        into_empty(original)

      {_, :eq, false, true} ->
        into_empty(original)

      # otherwise, if the point type is continuous, the the orignal
      # interval was already normalized form:
      {:continuous, _, _, _} ->
        original

      ## Discrete types:
      # if discrete type, we want to always normalize to bounds == [)
      # because it makes life a bit easier elsewhere.

      # if both bounds are exclusive, we also need to check for empty, because
      # we could still have an empty interval like (1,2)
      {:discrete, _, false, false} ->
        next_left_point = Point.next(left.point)

        case Point.compare(next_left_point, right.point) do
          :eq ->
            into_empty(original)

          :lt ->
            %__MODULE__{original | left: Endpoint.inclusive(next_left_point)}
        end

      # Remaining bound combinations are:
      # [], (], [)
      # we don't need to touch [), so we only need to deal with
      # the ones that are upper-inclusive. We want to perform the following
      # transformations:
      # [a,b] -> [a, b+1)
      # (a,b] -> [a+1, b+1)
      {:discrete, _, true, true} ->
        %__MODULE__{
          original
          | right: Endpoint.exclusive(Point.next(right.point))
        }

      {:discrete, _, false, true} ->
        %__MODULE__{
          original
          | left: Endpoint.inclusive(Point.next(left.point)),
            right: Endpoint.exclusive(Point.next(right.point))
        }

      # Finally, if we have an [) interval, then the original was
      # valid:
      {:discrete, :lt, true, false} ->
        original
    end
  end

  # Either left or right or both must be unbounded
  def normalize(%__MODULE__{left: left, right: right} = original) do
    %{
      original
      | left: normalize_left_endpoint(left),
        right: normalize_right_endpoint(right)
    }
  end

  defp normalize_right_endpoint(:unbounded), do: :unbounded

  defp normalize_right_endpoint(right) do
    case {Point.type(right.point), Endpoint.inclusive?(right)} do
      {:discrete, true} -> Endpoint.exclusive(Point.next(right.point))
      {_, _} -> right
    end
  end

  defp normalize_left_endpoint(:unbounded), do: :unbounded

  defp normalize_left_endpoint(left) do
    case {Point.type(left.point), Endpoint.inclusive?(left)} do
      {:discrete, false} -> Endpoint.inclusive(Point.next(left.point))
      {_, _} -> left
    end
  end

  @doc """
  Is the interval empty?

  An empty interval is an interval that represents no points.
  Any interval interval containing no points is considered empty.

  ## Examples

      iex> empty?(new(left: 0, right: 0))
      true

      iex> empty?(single(1.0))
      false

      iex> empty?(new(left: 1, right: 2))
      false

  """
  def empty?(%__MODULE__{left: :empty, right: :empty}), do: true
  def empty?(%__MODULE__{}), do: false

  @doc """
  Check if the interval is left-unbounded.

  The interval is left-unbounded if all points
  left of the right bound is included in this interval.

  ## Examples

      iex> left_unbounded?(new())
      true
      
      iex> left_unbounded?(new(right: 2))
      true
      
      iex> left_unbounded?(new(left: 1, right: 2))
      false

  """
  def left_unbounded?(%__MODULE__{left: :unbounded}), do: true
  def left_unbounded?(%__MODULE__{}), do: false

  @doc """
  Check if the interval is right-unbounded.

  The interval is right-unbounded if all points
  right of the left bound is included in this interval.

  ## Examples

      iex> right_unbounded?(new(right: 1))
      false
      
      iex> right_unbounded?(new())
      true
      
      iex> right_unbounded?(new(left: 1))
      true

  """
  def right_unbounded?(%__MODULE__{right: :unbounded}), do: true
  def right_unbounded?(%__MODULE__{}), do: false

  @doc """
  Is the interval left-inclusive?

  The interval is left-inclusive if the left endpoint
  value is included in the interval.

  NOTE: Discrete intervals (like integers and dates) are always normalized
  to be left-inclusive right-exclusive (`[)`) which this function reflects.


      iex> left_inclusive?(new(left: 1.0, right: 2.0, bounds: "[]"))
      true
      
      iex> left_inclusive?(new(left: 1.0, right: 2.0, bounds: "[)"))
      true
      
      iex> left_inclusive?(new(left: 1.0, right: 2.0, bounds: "()"))
      false

  """
  def left_inclusive?(%__MODULE__{left: %Endpoint{} = left}), do: Endpoint.inclusive?(left)
  def left_inclusive?(%__MODULE__{}), do: false

  @doc """
  Is the interval right-inclusive?

  The interval is right-inclusive if the right endpoint
  value is included in the interval.

  NOTE: Discrete intervals (like integers and dates) are always normalized
  to be left-inclusive right-exclusive (`[)`) which this function reflects.


      iex> right_inclusive?(new(left: 1.0, right: 2.0, bounds: "[]"))
      true
      
      iex> right_inclusive?(new(left: 1.0, right: 2.0, bounds: "[)"))
      false
      
      iex> right_inclusive?(new(left: 1.0, right: 2.0, bounds: "()"))
      false

  """
  def right_inclusive?(%__MODULE__{right: %Endpoint{} = right}), do: Endpoint.inclusive?(right)
  def right_inclusive?(%__MODULE__{}), do: false

  @doc """
  Is `a` strictly left of `b`.

  `a` is strictly left of `b` if no point in `a` is in `b`,
  and all points in `a` is left (<) of all points in `b`.

  ## Examples

      a: [---)
      b:     [---)
      r: true

      a: [---)
      b:        [---)
      r: true

      a: [---)
      b:    [---)
      r: false (overlaps)

      iex> strictly_left_of?(new(left: 1, right: 2), new(left: 3, right: 4))
      true

      iex> strictly_left_of?(new(left: 1, right: 3), new(left: 2, right: 4))
      false

      iex> strictly_left_of?(new(left: 3, right: 4), new(left: 1, right: 2))
      false
  """
  @spec strictly_left_of?(t(), t()) :: boolean()
  def strictly_left_of?(a, b) do
    not right_unbounded?(a) and
      not left_unbounded?(b) and
      not empty?(a) and
      not empty?(b) and
      case Point.compare(a.right.point, b.left.point) do
        :lt -> true
        :eq -> not right_inclusive?(a) or not left_inclusive?(b)
        :gt -> false
      end
  end

  @doc """
  Is `a` strictly right of `b`.

  `a` is strictly right of `b` if no point in `a` is in `b`,
  and all points in `a` is right (>) of all points in `b`.

  ## Examples

      a:     [---)
      b: [---)
      r: true

      a:        [---)
      b: [---)
      r: true

      a:    [---)
      b: [---)
      r: false (overlaps)

      iex> strictly_right_of?(new(left: 1, right: 2), new(left: 3, right: 4))
      false

      iex> strictly_right_of?(new(left: 1, right: 3), new(left: 2, right: 4))
      false

      iex> strictly_right_of?(new(left: 3, right: 4), new(left: 1, right: 2))
      true
  """
  @spec strictly_right_of?(t(), t()) :: boolean()
  def strictly_right_of?(a, b) do
    not left_unbounded?(a) and
      not right_unbounded?(b) and
      not empty?(a) and
      not empty?(b) and
      case Point.compare(a.left.point, b.right.point) do
        :lt -> false
        :eq -> not left_inclusive?(a) or not right_inclusive?(b)
        :gt -> true
      end
  end

  @doc """
  Is the interval `a` adjacent to `b`, to the left of `b`.

  `a` is adjacent to `b` left of `b`, if `a` and `b` do _not_ overlap,
  and there are no points between `a.right` and `b.left`.

      a: [---)
      b:     [---)
      r: true

      a: [---]
      b:     [---]
      r: false (overlaps)

      a: (---)
      b:        (---)
      r: false (points exist between a.right and b.left)

  ## Examples


      iex> adjacent_left_of?(new(left: 1, right: 2), new(left: 2, right: 3))
      true

      iex> adjacent_left_of?(new(left: 1, right: 3), new(left: 2, right: 4))
      false

      iex> adjacent_left_of?(new(left: 3, right: 4), new(left: 1, right: 2))
      false

      iex> adjacent_left_of?(new(right: 2, bounds: "[]"), new(left: 3))
      true
  """
  @spec adjacent_left_of?(t(), t()) :: boolean()
  def adjacent_left_of?(a, b) do
    prerequisite =
      not right_unbounded?(a) and
        not left_unbounded?(b) and
        not empty?(a) and
        not empty?(b)

    with true <- prerequisite do
      case Point.type(a.right.point) do
        :discrete ->
          check =
            right_inclusive?(a) != left_inclusive?(b) and
              Point.compare(a.right.point, b.left.point) == :eq

          # NOTE: Don't think this is needed when we also
          # normalize discrete values to [)
          next_check =
            right_inclusive?(a) and left_inclusive?(b) and
              Point.compare(Point.next(a.right.point), b.left.point) == :eq

          check or next_check

        :continuous ->
          right_inclusive?(a) != left_inclusive?(b) and
            Point.compare(a.right.point, b.left.point) == :eq
      end
    end
  end

  @doc """
  Is the interval `a` adjacent to `b`, to the right of `b`.

  `a` is adjacent to `b` right of `b`, if `a` and `b` do _not_ overlap,
  and there are no points between `a.left` and `b.right`.

      a:     [---)
      b: [---)
      r: true

      a:     [---)
      b: [---]
      r: false (overlaps)

      a:        (---)
      b: (---)
      r: false (points exist between a.left and b.right)

  ## Examples

      iex> adjacent_right_of?(new(left: 2, right: 3), new(left: 1, right: 2))
      true

      iex> adjacent_right_of?(new(left: 1, right: 3), new(left: 2, right: 4))
      false

      iex> adjacent_right_of?(new(left: 1, right: 2), new(left: 3, right: 4))
      false

      iex> adjacent_right_of?(new(left: 3), new(right: 2, bounds: "]"))
      true
  """
  @spec adjacent_right_of?(t(), t()) :: boolean()
  def adjacent_right_of?(a, b) do
    prerequisite =
      not left_unbounded?(a) and
        not right_unbounded?(b) and
        not empty?(a) and
        not empty?(b)

    with true <- prerequisite do
      case Point.type(a.left.point) do
        :discrete ->
          check =
            left_inclusive?(a) != right_inclusive?(b) and
              Point.compare(a.left.point, b.right.point) == :eq

          # NOTE: Don't think this is needed when we also
          # normalize discrete values to [)
          next_check =
            left_inclusive?(a) and right_inclusive?(b) and
              Point.compare(Point.previous(a.left.point), b.right.point) == :eq

          check or next_check

        :continuous ->
          Point.compare(a.left.point, b.right.point) == :eq and
            left_inclusive?(a) != right_inclusive?(b)
      end
    end
  end

  @doc """
  Does `a` overlap with `b`?

  `a` overlaps with `b` if any point in `a` is also in `b`.

      a: [---)
      b:   [---)
      r: true

      a: [---)
      b:     [---)
      r: false

      a: [---]
      b:     [---]
      r: true

      a: (---)
      b:     (---)
      r: false

      a: [---)
      b:        [---)
      r: false

  ## Examples

      [--a--)
          [--b--)

      iex> overlaps?(new(left: 1, right: 3), new(left: 2, right: 4))
      true


      [--a--)
            [--b--)

      iex> overlaps?(new(left: 1, right: 3), new(left: 3, right: 5))
      false


      [--a--]
            [--b--]

      iex> overlaps?(new(left: 1, right: 3), new(left: 2, right: 4))
      true


      (--a--)
            (--b--)

      iex> overlaps?(new(left: 1, right: 3), new(left: 3, right: 5))
      false


      [--a--)
               [--b--)

      iex> overlaps?(new(left: 1, right: 2), new(left: 3, right: 4))
      false
  """
  @spec overlaps?(t(), t()) :: boolean()
  def overlaps?(a, b) do
    not empty?(a) and
      not empty?(b) and
      not strictly_left_of?(a, b) and
      not strictly_right_of?(a, b)
  end

  @doc """
  Does `a` contain `b`?

  `a` contains `b` of all points in `b` is also in `a`.

  For an interval `a` to contain an interval `b`, all points
  in `b` must be contained in `a`:

      a: [-------]
      b:   [---]
      r: true

      a: [---]
      b: [---]
      r: true

      a: [---]
      b: (---)
      r: true

      a: (---)
      b: [---]
      r: false

      a:   [---]
      b: [-------]
      r: false

  This means that `a.left` is less than `b.left` (or unbounded), and `a.right` is greater than
  `b.right` (or unbounded)

  If `a` and `b`'s point match, then `b` is "in" `a` if `a` and `b` share bound types.
  
  E.g. if `a.left` and `b.left` matches, then `a` contains `b` if both `a` and `b`'s
  `left` is inclusive or exclusive.

  If either of `b` endpoints are unbounded, then `a` only contains `b`
  if the corresponding endpoint in `a` is also unbounded.

  ## Examples

      iex> contains?(new(left: 1, right: 2), new(left: 1, right: 2))
      true

      iex> contains?(new(left: 1, right: 3), new(left: 2, right: 3))
      true

      iex> contains?(new(left: 2, right: 3), new(left: 1, right: 4))
      false

      iex> contains?(new(left: 1, right: 3), new(left: 1, right: 2))
      true

      iex> contains?(new(left: 1, right: 2, bounds: "()"), new(left: 1, right: 3))
      false

      iex> contains?(new(right: 1), new(left: 0, right: 1))
      true
  """
  @spec contains?(t(), t()) :: boolean()
  def contains?(%__MODULE__{} = a, %__MODULE__{} = b) do
    # Neither A or B must be empty, so that's a prerequisite for
    # even checking anything.
    prerequisite = not (empty?(a) or empty?(b))

    with true <- prerequisite do
      # check that a.left.point is less than or equal to (if inclusive) b.left.point:
      contains_left =
        left_unbounded?(a) or
          (not left_unbounded?(b) and
             case Point.compare(a.left.point, b.left.point) do
               :gt -> false
               :eq -> left_inclusive?(a) == left_inclusive?(b)
               :lt -> true
             end)

      # check that a.right.point is greater than or equal to (if inclusive) b.right.point:
      contains_right =
        right_unbounded?(a) or
          (not right_unbounded?(b) and
             case Point.compare(a.right.point, b.right.point) do
               :gt -> true
               :eq -> right_inclusive?(a) == right_inclusive?(b)
               :lt -> false
             end)

      # a contains b if both the left check and right check passes:
      contains_left and contains_right
    end
  end

  @doc """
  Computes the union of `a` and `b`.

  The union contains all of the points that are either in `a` or `b`.

  If either `a` or `b` are empty, the returned interval will be empty.

      a: [---)
      b:   [---)
      r: [-----)


  ## Examples

      [--A--)
          [--B--)
      [----C----)

      iex> union(new(left: 1, right: 3), new(left: 2, right: 4))
      new(left: 1, right: 4)


      [-A-)
          [-B-)
      [---C---)

      iex> union(new(left: 1, right: 2), new(left: 2, right: 3))
      new(left: 1, right: 3)

      iex> union(new(left: 1, right: 2), new(left: 3, right: 4))
      new(left: 0, right: 0)
  """
  def union(a, b) do
    cond do
      # if either is empty, return the other
      empty?(a) ->
        b

      empty?(b) ->
        a

      # if a and b overlap or are adjacent, we can union the intervals
      overlaps?(a, b) or adjacent_left_of?(a, b) or adjacent_right_of?(a, b) ->
        left = min_endpoint(a.left, b.left)
        right = max_endpoint(a.right, b.right)

        from_endpoints(left, right)

      # fall-through, if neither A or B is empty,
      # but there is also no overlap or adjacency,
      # then the two intervals are either strictly left or strictly right,
      # we return empty (A and B share an empty amount of points)
      true ->
        # TODO: remove this assertion.
        # It should always be true, so no point in checking:
        true == strictly_left_of?(a, b) or strictly_right_of?(a, b)

        into_empty(a)
    end
  end

  @doc """
  Compute the intersection between `a` and `b`.

  The intersection contains all of the points that are both in `a` and `b`.

  If either `a` or `b` are empty, the returned interval will be empty.

      a: [----]
      b:    [----]
      r:    [-]

      a: (----)
      b:    (----)
      r:    (-)

      a: [----)
      b:    [----)
      r:    [-)

  ## Examples:

  Discrete:

      a: [----)
      b:    [----)
      c:    [-)

      iex> intersection(new(left: 1, right: 3), new(left: 2, right: 4))
      new(left: 2, right: 3)

  Continuous:

      a: [----)
      b:    [----)
      c:    [-)

      iex> intersection(new(left: 1.0, right: 3.0), new(left: 2.0, right: 4.0))
      new(left: 2.0, right: 3.0)

      a: (----)
      b:    (----)
      c:    (-)

      iex> intersection(
      ...>   new(left: 1.0, right: 3.0, bounds: "()"),
      ...>   new(left: 2.0, right: 4.0, bounds: "()")
      ...> )
      new(left: 2.0, right: 3.0, bounds: "()")
  """
  def intersection(a, b) do
    cond do
      # if A is empty, we return A
      empty?(a) ->
        a

      # if B is empty, we return B
      empty?(b) ->
        b

      # if A and B doesn't overlap,
      # then there can be no intersection
      not overlaps?(a, b) ->
        into_empty(a)

      # otherwise, we can compute the intersection:
      true ->
        left = max_endpoint(a.left, b.left)
        right = min_endpoint(a.right, b.right)

        from_endpoints(left, right)
    end
  end

  ##
  ## Helpers
  ##

  defp min_endpoint(:unbounded, _b), do: :unbounded
  defp min_endpoint(_a, :unbounded), do: :unbounded

  defp min_endpoint(left, right) do
    case Point.compare(left.point, right.point) do
      :gt ->
        right

      :eq ->
        case {Endpoint.inclusive?(left), Endpoint.inclusive?(right)} do
          {true, _} -> left
          {_, true} -> right
          _ -> left
        end

      :lt ->
        left
    end
  end

  defp max_endpoint(:unbounded, _b), do: :unbounded
  defp max_endpoint(_a, :unbounded), do: :unbounded

  defp max_endpoint(left, right) do
    case Point.compare(left.point, right.point) do
      :gt ->
        left

      :eq ->
        case {Endpoint.inclusive?(left), Endpoint.inclusive?(right)} do
          {true, _} -> left
          {_, true} -> right
          _ -> left
        end

      :lt ->
        right
    end
  end

  # completely unbounded:
  defp unpack_bounds(""), do: {:unbounded, :unbounded}
  # unbounded either left or right
  defp unpack_bounds(")"), do: {:unbounded, :exclusive}
  defp unpack_bounds("("), do: {:exclusive, :unbounded}
  defp unpack_bounds("]"), do: {:unbounded, :inclusive}
  defp unpack_bounds("["), do: {:inclusive, :unbounded}
  # bounded both sides
  defp unpack_bounds("()"), do: {:exclusive, :exclusive}
  defp unpack_bounds("[]"), do: {:inclusive, :inclusive}
  defp unpack_bounds("[)"), do: {:inclusive, :exclusive}
  defp unpack_bounds("(]"), do: {:exclusive, :inclusive}

  defp into_empty(interval) do
    %{interval | left: :empty, right: :empty}
  end

end
