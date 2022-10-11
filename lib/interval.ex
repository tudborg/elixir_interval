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

  The endpoints are stored as an `t:Interval.Endpoint.t/1` or
  the atom `:unbounded`.

  """
  @type t(point) :: %__MODULE__{
          # Left endpoint
          left: :unbounded | Interval.Endpoint.t(point),
          # Right  endpoint
          right: :unbounded | Interval.Endpoint.t(point)
        }

  @type t() :: t(any())

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
    inclusive_left = Endpoint.inclusive?(left)
    inclusive_right = Endpoint.inclusive?(right)

    case {type, comp, inclusive_left, inclusive_right} do
      # left > right is an error:
      {_, :gt, _, _} ->
        raise "left > right which is invalid"

      # intervals given as either (p,p), [p,p) or (p,p]
      # (If you want a single point in an interval, give it as [p,p])
      # The (p,p) interval is already normalize form
      {_, :eq, false, false} ->
        normalized_empty(original)

      # [p,p) and (p,p] is normalized by taking the exlusive endpoint and
      # setting it as both left and right
      {_, :eq, true, false} ->
        normalized_empty(original)

      {_, :eq, false, true} ->
        normalized_empty(original)

      # otherwise, if the point type is continuous, the the orignal
      # interval was already normalized form:
      {:continuous, _, _, _} ->
        original

      ## Discrete types:
      # if discrete type, we want to always normalize to bounds == [)
      # because it makes life a bit easier elsewhere.

      # if both bounds are exclusive, we also need to check for empty, because
      # we could still have an empty interval like (1,2)
      # which is the same as (1,1) so we normalize by setting
      # both endpoints to the same value.
      {:discrete, _, false, false} ->
        case Point.compare(Point.next(left.point), right.point) do
          :eq ->
            normalized_empty(original)

          :lt ->
            %__MODULE__{original | left: normalize_left_endpoint(left)}
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
          | right: normalize_right_endpoint(right)
        }

      {:discrete, _, false, true} ->
        %__MODULE__{
          original
          | left: normalize_left_endpoint(left),
            right: normalize_right_endpoint(right)
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
  Any interval containing no points is considered empty.

  An unbounded interval is never empty.

  For continuous points, the interval is empty when the left and
  right points are identical, and the point is not included in the interval.

  For discrete points, the interval is empty when the left and right point
  isn't inclusive, and there are no points between the left and right point.

  ## Examples

      iex> empty?(new(left: 0, right: 0))
      true

      iex> empty?(single(1.0))
      false

      iex> empty?(new(left: 1, right: 2))
      false

  """
  def empty?(%__MODULE__{left: :unbounded}), do: false
  def empty?(%__MODULE__{right: :unbounded}), do: false
  # If properly normalized, all empty intervals have been normalized to the form
  # `(zero, zero)` so we can match directly on that:
  def empty?(%__MODULE__{
        left: %{inclusive: false, point: p},
        right: %{inclusive: false, point: p}
      }),
      do: true

  # If the interval is not properly normalized, we don't want to give an
  # incorrect answer, so we do the math to check if the interval is indeed empty:
  def empty?(%__MODULE__{left: %Endpoint{} = left, right: %Endpoint{} = right}) do
    compare = Point.compare(left.point, right.point)

    cond do
      # left and right is equal, then the interval is empty
      # if the point is not included in the interval.
      # We don't want to rely on normalized intervals in empty?/1
      # in this function body, because if the interval was already normalized,
      # we'd only have to check for the `(zero,zero)` interval.
      # Therefore we must assume that the bounds could be incorrectly set to e.g. [p,p)
      compare == :eq ->
        not left.inclusive or not right.inclusive

      # if the point type is discrete and both bounds are exclusive,
      # then the interval could _also_ be empty if next(left) == right,
      # because the interval would represent 0 points.
      Point.type(left.point) == :discrete and not left.inclusive and not right.inclusive ->
        :eq ==
          left.point
          |> Point.next()
          |> Point.compare(right.point)

      # If none of the above, then the interval is not empty
      true ->
        false
    end
  end

  @doc """
  Check if the interval is left-unbounded.

  The interval is left-unbounded if all points
  left of the right bound is included in this interval.

  ## Examples

      iex> unbounded_left?(new())
      true
      
      iex> unbounded_left?(new(right: 2))
      true
      
      iex> unbounded_left?(new(left: 1, right: 2))
      false

  """
  def unbounded_left?(%__MODULE__{left: :unbounded}), do: true
  def unbounded_left?(%__MODULE__{}), do: false

  @doc """
  Check if the interval is right-unbounded.

  The interval is right-unbounded if all points
  right of the left bound is included in this interval.

  ## Examples

      iex> unbounded_right?(new(right: 1))
      false
      
      iex> unbounded_right?(new())
      true
      
      iex> unbounded_right?(new(left: 1))
      true

  """
  def unbounded_right?(%__MODULE__{right: :unbounded}), do: true
  def unbounded_right?(%__MODULE__{}), do: false

  @doc """
  Is the interval left-inclusive?

  The interval is left-inclusive if the left endpoint
  value is included in the interval.

  > #### Note {: .info}
  > Discrete intervals (like integers and dates) are always normalized
  > to be left-inclusive right-exclusive (`[)`) which this function reflects.


      iex> inclusive_left?(new(left: 1.0, right: 2.0, bounds: "[]"))
      true
      
      iex> inclusive_left?(new(left: 1.0, right: 2.0, bounds: "[)"))
      true
      
      iex> inclusive_left?(new(left: 1.0, right: 2.0, bounds: "()"))
      false

  """
  def inclusive_left?(%__MODULE__{left: %Endpoint{} = left}), do: Endpoint.inclusive?(left)
  def inclusive_left?(%__MODULE__{}), do: false

  @doc """
  Is the interval right-inclusive?

  The interval is right-inclusive if the right endpoint
  value is included in the interval.

  > #### Note {: .info}
  > Discrete intervals (like integers and dates) are always normalized
  > to be left-inclusive right-exclusive (`[)`) which this function reflects.


      iex> inclusive_right?(new(left: 1.0, right: 2.0, bounds: "[]"))
      true
      
      iex> inclusive_right?(new(left: 1.0, right: 2.0, bounds: "[)"))
      false
      
      iex> inclusive_right?(new(left: 1.0, right: 2.0, bounds: "()"))
      false

  """
  def inclusive_right?(%__MODULE__{right: %Endpoint{} = right}), do: Endpoint.inclusive?(right)
  def inclusive_right?(%__MODULE__{}), do: false

  @doc """
  Return the "size" of the interval.
  The returned value depends on the Point implementation used.

  - If the interval is unbounded, this function returns `nil`.

  > #### Note {: .info}
  > The size is implemented as `right - left`, ignoring inclusive/exclusive bounds.
  > This works for discrete intervals because they are always normalized to `[)`.
  > The implementation is the same for continuous intervals, but here we
  > completely ignore the bounds, so the size of `(1.0, 3.0)` is exactly the same
  > as the size of `[1.0, 3.0]`.

  A second argument `unit` can be given to this function, which in turn
  is handed to the call to `Interval.Point.subtract/3`, to return the difference
  between the two points in the desired unit.

  The default value for `unit` is Point implementation specific.

  These are the default returned sizes for the built-in implementations:

  - `Date` - days (integer)
  - `DateTime` - seconds (integer)
  - `Integer` - integer
  - `Float` - float

  ## For Discrete Intervals

  For discrete point types, the size represents the number of elements the
  interval contains (or `nil`, when empty).

  I.e. for `Date` the size is the number of `Date` structs the interval
  can be said to "contain" (aka. number of days)

  ### Examples

      iex> size(new(left: 1, right: 1, bounds: "[]"))
      1

      iex> size(new(left: 1, right: 3, bounds: "[)"))
      2

      # Note that this interval will be normalized to an empty (0,0) interval
      # but the math is still the same: `right - left` 
      iex> size(new(left: 1, right: 2, bounds: "()"))
      0

  ## For Continuous Intervals

  For continuous intervals, the size is reported as the difference
  between the left and right points.

  ### Examples

      # The size of the interval `[1.0, 5.0)` is also 4:
      iex> size(new(left: 1.0, right: 5.0, bounds: "[)"))
      4.0

      # And likewise, so is the size of `[1.0, 5.0]` (note the bound change)
      iex> size(new(left: 1.0, right: 5.0, bounds: "[]"))
      4.0

      # Exactly one point contained in  this continuous interval,
      # so technically not empty, but it also has zero  size.
      iex> size(new(left: 1.0, right: 1.0, bounds: "[]"))
      0.0

      # Empty continuous interval
      iex> size(new(left: 1.0, right: 1.0, bounds: "()"))
      0.0

  """
  @spec size(t(), unit :: any()) :: any()
  def size(%__MODULE__{} = a, unit \\ nil) do
    cond do
      unbounded_left?(a) ->
        nil

      unbounded_right?(a) ->
        nil

      true ->
        case unit do
          nil -> Point.subtract(a.right.point, a.left.point)
          unit -> Point.subtract(a.right.point, a.left.point, unit)
        end
    end
  end

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
    not unbounded_right?(a) and
      not unbounded_left?(b) and
      not empty?(a) and
      not empty?(b) and
      case Point.compare(a.right.point, b.left.point) do
        :lt -> true
        :eq -> not inclusive_right?(a) or not inclusive_left?(b)
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
    not unbounded_left?(a) and
      not unbounded_right?(b) and
      not empty?(a) and
      not empty?(b) and
      case Point.compare(a.left.point, b.right.point) do
        :lt -> false
        :eq -> not inclusive_left?(a) or not inclusive_right?(b)
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
      not unbounded_right?(a) and
        not unbounded_left?(b) and
        not empty?(a) and
        not empty?(b)

    with true <- prerequisite do
      case Point.type(a.right.point) do
        :discrete ->
          check =
            inclusive_right?(a) != inclusive_left?(b) and
              Point.compare(a.right.point, b.left.point) == :eq

          # NOTE: Don't think this is needed when we also
          # normalize discrete values to [)
          next_check =
            inclusive_right?(a) and inclusive_left?(b) and
              Point.compare(Point.next(a.right.point), b.left.point) == :eq

          check or next_check

        :continuous ->
          inclusive_right?(a) != inclusive_left?(b) and
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
      not unbounded_left?(a) and
        not unbounded_right?(b) and
        not empty?(a) and
        not empty?(b)

    with true <- prerequisite do
      case Point.type(a.left.point) do
        :discrete ->
          check =
            inclusive_left?(a) != inclusive_right?(b) and
              Point.compare(a.left.point, b.right.point) == :eq

          # NOTE: Don't think this is needed when we also
          # normalize discrete values to [)
          next_check =
            inclusive_left?(a) and inclusive_right?(b) and
              Point.compare(Point.previous(a.left.point), b.right.point) == :eq

          check or next_check

        :continuous ->
          Point.compare(a.left.point, b.right.point) == :eq and
            inclusive_left?(a) != inclusive_right?(b)
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
        unbounded_left?(a) or
          (not unbounded_left?(b) and
             case Point.compare(a.left.point, b.left.point) do
               :gt -> false
               :eq -> inclusive_left?(a) == inclusive_left?(b)
               :lt -> true
             end)

      # check that a.right.point is greater than or equal to (if inclusive) b.right.point:
      contains_right =
        unbounded_right?(a) or
          (not unbounded_right?(b) and
             case Point.compare(a.right.point, b.right.point) do
               :gt -> true
               :eq -> inclusive_right?(a) == inclusive_right?(b)
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
        left = min_endpoint(a.left, b.left, :prefer_unbounded)
        right = max_endpoint(a.right, b.right, :prefer_unbounded)

        from_endpoints(left, right)

      # fall-through, if neither A or B is empty,
      # but there is also no overlap or adjacency,
      # then the two intervals are either strictly left or strictly right,
      # we return empty (A and B share an empty amount of points)
      true ->
        # TODO: remove this assertion.
        # It should always be true, so no point in checking:
        true == strictly_left_of?(a, b) or strictly_right_of?(a, b)

        normalized_empty(a)
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

      a: [-----)
      b:   [-------
      c:   [---)
      iex> intersection(new(left: 1.0, right: 3.0), new(left: 2.0))
      new(left: 2.0, right: 3.0)

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
        normalized_empty(a)

      # otherwise, we can compute the intersection:
      true ->
        left = max_endpoint(a.left, b.left, :prefer_bounded)
        right = min_endpoint(a.right, b.right, :prefer_bounded)
        from_endpoints(left, right)
    end
  end

  ##
  ## Helpers
  ##
  defp min_endpoint(:unbounded, _b, :prefer_unbounded), do: :unbounded
  defp min_endpoint(_a, :unbounded, :prefer_unbounded), do: :unbounded
  defp min_endpoint(:unbounded, b, :prefer_bounded), do: b
  defp min_endpoint(a, :unbounded, :prefer_bounded), do: a

  defp min_endpoint(left, right, _) do
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

  defp max_endpoint(:unbounded, _b, :prefer_unbounded), do: :unbounded
  defp max_endpoint(_a, :unbounded, :prefer_unbounded), do: :unbounded
  defp max_endpoint(:unbounded, b, :prefer_bounded), do: b
  defp max_endpoint(a, :unbounded, :prefer_bounded), do: a

  defp max_endpoint(left, right, _) do
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

  defp normalized_empty(%__MODULE__{left: left, right: right} = a) do
    point =
      case {left, right} do
        {%Endpoint{point: point}, _} ->
          Point.zero(point)

        {_, %Endpoint{point: point}} ->
          Point.zero(point)

        {:unbounded, :unbounded} ->
          raise "cannot convert unbounded interval into empty interval"
      end

    endpoint = Endpoint.new(point, :exclusive)

    %{a | left: endpoint, right: endpoint}
  end
end
