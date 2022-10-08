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
          left: :empty | :unbounded | Interval.Endpoint.t(),
          right: :empty | :unbounded | Interval.Endpoint.t()
        }

  @doc """
  Create a new empty Interval
  """
  def empty() do
    %__MODULE__{left: :empty, right: :empty}
  end

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
    # Left and right point type must be the same.
    # Dirty assert for now:
    true = Interval.Point.impl_for!(left.point) == Interval.Point.impl_for!(right.point)

    type = Point.type(left.point)
    comp = Point.compare(left.point, right.point)
    left_inclusive = Endpoint.inclusive?(left)
    right_inclusive = Endpoint.inclusive?(right)

    case {type, comp, left_inclusive, right_inclusive} do
      # left > right is an error:
      {_, :gt, _, _} ->
        dbg({left, right})
        raise "left > right which is invalid"

      # intervals given as either (p,p), [p,p) or (p,p]
      # are all normalized to empty.
      # (If you want a single point in an interval, give it as [p,p])
      {_, :eq, false, false} ->
        empty()

      {_, :eq, true, false} ->
        empty()

      {_, :eq, false, true} ->
        empty()

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
            empty()

          :lt ->
            %__MODULE__{
              left: Endpoint.inclusive(next_left_point),
              right: right
            }
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
          left: left,
          right: Endpoint.exclusive(Point.next(right.point))
        }

      {:discrete, _, false, true} ->
        %__MODULE__{
          left: Endpoint.inclusive(Point.next(left.point)),
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
    %{original | left: normalize_left_endpoint(left), right: normalize_right_endpoint(right)}
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
  Is interval empty?

  ## Examples

      iex> empty?(empty())
      true

      iex> empty?(single(1.0))
      false

      iex> empty?(new(left: 1, right: 2))
      false

  """
  def empty?(%__MODULE__{left: :empty, right: :empty}), do: true
  def empty?(%__MODULE__{}), do: false

  @doc """
  Is the interval unbounded to the left?

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
  Is the interval unbounded to the right?

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
  Is the interval left point inclusive?

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
  Is the interval right point inclusive?

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
  A is strictly left of B, if no point in A is in B,
  and all points in A is left (<) of all points in B.

  # Examples:

      [--A--)
               [--B--)

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
  A is strictly right of B, if no point in A is in B,
  and all points in A is right (>) of all points in B.

               [--A--)
      [--B--)

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
  A is adjacent left of B if a.right.point == b.left.point and their bounds are not equal,
  or if A's type is discrete and next(a.right.point) == b.left.point and a.right.point and b.left.point is inclusive
    
  Discrete:

      |--A--)
            [--B--|

      |--A--]
            (--B--|
      
      |--A--]
              [--B--|

  Continuous:

      |--A--)
            [--B--|

      |--A--]
            (--B--|

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
  A is adjacent right of B if a.left.point == b.right.point and their bounds are not equal,
  or if A's type is discrete and next(a.left.point) == b.right.point and a.left.point and b.right.point is inclusive
    
  Discrete:

            (--A--]
      |--B--]

            [--A--|
      |--B--)
      
              [--A--|
      |--B--]

  Continuous:

            (--A--]
      |--B--]

            [--A--|
      |--B--)
      

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
  Is some points in A also in B?

  ## Examples

      [--A--)
          [--B--)

      iex> overlaps?(new(left: 1, right: 3), new(left: 2, right: 4))
      true


      [--A--)
            [--B--)

      iex> overlaps?(new(left: 1, right: 3), new(left: 3, right: 5))
      false


      [--A--]
            [--B--]

      iex> overlaps?(new(left: 1, right: 3), new(left: 2, right: 4))
      true


      (--A--)
            (--B--)

      iex> overlaps?(new(left: 1, right: 3), new(left: 3, right: 5))
      false


      [--A--)
               [--B--)

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
  Does interval `a` contain `point`?

  For an interval A to contain an interval B, all of B's points must be
  inside of A:

      [-----A-----)
        [---B---)

  This means that a.left.point is less than b.left.point (or unbounded), and a.right.point is greater than
  b.right.point (or unbounded)

  If A and B's point match, then B is "in" A if A and B share bound type.
  E.g. if a.left.point and b.left.point equals, then A contains B if both A's and B's
  left_incl is inclusive, or if both A's and B's left_incl is exclusive.

  If either of B's points are unbounded, then A only contains B
  if the corresponding point in A is also unbounded.

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
  def contains?(a, b) do
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
  Union interval A and B.
  A and B must overlap or be adjacent to produce a meaningful result,
  otherwise an empty interval is returned.

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
      Interval.empty()
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

        empty()
    end
  end

  @doc """
  Return the intersection between two intervals, such that the returned
  interval contains all of the points that A and B has in common.

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
        empty()

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
  def unpack_bounds(""), do: {:unbounded, :unbounded}
  # unbounded either left or right
  def unpack_bounds(")"), do: {:unbounded, :exclusive}
  def unpack_bounds("("), do: {:exclusive, :unbounded}
  def unpack_bounds("]"), do: {:unbounded, :inclusive}
  def unpack_bounds("["), do: {:inclusive, :unbounded}
  # bounded both sides
  def unpack_bounds("()"), do: {:exclusive, :exclusive}
  def unpack_bounds("[]"), do: {:inclusive, :inclusive}
  def unpack_bounds("[)"), do: {:inclusive, :exclusive}
  def unpack_bounds("(]"), do: {:exclusive, :inclusive}
end
