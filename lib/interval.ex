defmodule Interval do
  @moduledoc """
  An interval represents the points between two endpoints.

  The interval can be empty.
  The empty interval is never contained in any other interval,
  and contains itself no points.

  It can be left and/or right unbounded, in which case
  it contains all points in the unbounded direction.
  A fully unbounded interval contains all other intervals, except
  the empty interval.

  ## Interval Notation

  Throughout the documentation and comments, you'll see a notation for
  writing about intervals.
  As this library is inspired by the functionality in PostgreSQL's range types,
  we align ourselves with it's  notation choice and borrow it
  (https://www.postgresql.org/docs/current/rangetypes.html)
  with the exception that we write the normalised empty interval as `(0,0)`.

  This notation is also described in ISO 31-11.

      [left-inclusive, right-inclusive]
      (left-exclusive, right-exclusive)
      [left-inclusive, right-exclusive)
      (left-exclusive, right-inclusive]
      (0,0)

  An unbounded interval is written by omitting the bound type and point:

      ,right-exclusive)
      [left-inclusive,

  When specifying bound types we sometimes leave the point out and just write
  the left and right bounds:

      []
      ()
      (]
      [)
      (
      )
      [
      ]

  ## Types of Interval

  This library ships with a few different types of intervals.
  The built-in intervals are intervals for

  - `Date`
  - `DateTime`
  - `Float`
  - `Integer`

  However, you can quite easily implement an interval using your own
  point types, by implementing the `Interval.Point` protocol.

  The `Interval.Point` protocols defines a few handfuls of functions
  you'll need to define on your struct to be able to use it as a point
  in the interval.

  An obvious usecase for this would be to implement an interval that works
  with the https://hexdocs.pm/decimal library.

  ## Discrete vs Continuous intervals

  Depending on the type of point used, an interval is either said to be
  discrete or continuous.

  A discrete interval represents a set of finite points (like integers or dates).
  A continuous can be said to represent the infinite number of points between
  two endpoints (like float and datetime).

  With discrete points, it is possible to define what the next and previous
  point is, and we normalise these intervals to the bound type `[)`.  
  The only exception is the empty interval, which is still represented as
  the exclusive bounded zero point. For integers that would be `(0,0)`.

  The distinction between discrete and continuous intervals is important
  because the two behave slightly differently in some of the libraries functions.
  E.g. A discrete interval is adjacent to another discrete interval, if there
  is no points between the two interval.  
  Contrast this to continuous intervals like real numbers where there is always
  an infinite number of real numbers between two distinct real numbers,
  and so continuous intervals are only said to be adjacent to each other
  if they include the same point, and one point is inclusive where the other
  is exclusive.

  Where relevant, the function documentation will mention the differences
  between discrete and continuous intervals.

  ## Create an Interval

  See `new/1`.

  ## Normalization

  When creating an interval through `new/1`, it will get normalized
  so that intervals that represents the same exact same points,
  are also represented in the same way in the struct.
  This allows you to compare two intervals for equality by using `==`
  (and using pattern matching).

  It is therefore not recommended to modify an `Interval` struct directly,
  but instead do so by using one of the functions that modify the interval.

  An interval is said to be empty if it spans zero points.
  We represent the empty interval as an exclusive interval in between
  two "zero points".  
  Any empty interval will be normalized to this `(0,0)` interval.
  see `Interval.Point.zero/1` for details on what a zero point is.

  """

  alias Interval.Point

  defstruct left: nil, right: nil

  @typedoc """
  The `Interval` struct, representing all points between
  two endpoints.

  The struct has two fields: `left` and `right`,
  representing the left (lower) and right (upper) points
  in the interval.
  """
  @type t(point) :: %__MODULE__{
          # Left endpoint
          left: :unbounded | {bound(), point},
          # Right  endpoint
          right: :unbounded | {bound(), point}
        }

  @typedoc """
  Shorthand for `t:t(any())`
  """
  @type t() :: t(any())

  @type bound() :: :inclusive | :exclusive

  @doc """
  Create a new Interval containing a single point.
  """
  def single(point) when not is_list(point) do
    # assert that Point is implemented for given variable
    true = Point.type(point) in [:discrete, :continuous]
    endpoint = {:inclusive, point}
    from_endpoints(endpoint, endpoint)
  end

  @doc """
  Create a new unbounded interval.

  This is the exactly the same as `new/1` with an empty list of options.
  """
  @spec new() :: t()
  def new() do
    new([])
  end

  @doc """
  Create a new interval.

  ## Options

  - `left` The left (or lower) endpoint of the interval
  - `right` The right (or upper) endpoint of the interval
  - `bounds` The bound mode to use. Defaults to `"[)"`

  A `nil` (`left` or `right`) endpoint is considered unbounded.  
  The endpoint will also be considered unbounded if the `bounds` is explicitly
  set as unbounded.

  ## Bounds

  The `bounds` options contains the left and right bound mode to use.
  The bound can be inclusive, exclusive or unbounded.

  The following valid bound values are supported:

  - `"[)"` left-inclusive, right-exclusive (default)
  - `"(]"` left-exclusive, right-inclusive
  - `"[]"` left-inclusive, right-inclusive
  - `"()"` left-exclusive, right-exclusive
  - `")"`  left-unbounded, right-exclusive
  - `"]"`  left-unbounded, right-inclusive
  - `"("`  left-exclusive, right-unbounded
  - `"["`  left-inclusive, right-unbounded

  ## Examples

      iex> new([])

      iex> new(left: 1)

      iex> new(left: 1, right: 1, bounds: "[]")

      iex> new(left: 10, right: 20, bounds: "()")
  """
  def new(opts) when is_list(opts) do
    left = Keyword.get(opts, :left, nil)
    right = Keyword.get(opts, :right, nil)
    bounds = Keyword.get(opts, :bounds, "[)")
    {left_bound, right_bound} = unpack_bounds(bounds)

    left_endpoint =
      case {left, left_bound} do
        {nil, _} -> :unbounded
        {_, :unbounded} -> :unbounded
        {_, :inclusive} -> {:inclusive, left}
        {_, :exclusive} -> {:exclusive, left}
      end

    right_endpoint =
      case {right, right_bound} do
        {nil, _} -> :unbounded
        {_, :unbounded} -> :unbounded
        {_, :inclusive} -> {:inclusive, right}
        {_, :exclusive} -> {:exclusive, right}
      end

    from_endpoints(left_endpoint, right_endpoint)
  end

  def from_endpoints(left, right)
      when (left == :unbounded or is_tuple(left)) and
             (right == :unbounded or is_tuple(right)) do
    %__MODULE__{left: left, right: right}
    |> normalize()
  end

  @doc """
  Normalize an `Interval` struct
  """
  # non-empty non-unbounded Interval:
  def normalize(
        %__MODULE__{
          left: {left_bound, left_point} = left,
          right: {right_bound, right_point} = right
        } = original
      ) do
    left_point_impl = Point.impl_for(left_point)
    right_point_impl = Point.impl_for(right_point)

    if left_point_impl != right_point_impl do
      raise """
      The Interval.Point implementation for the left and right side
      of the interval must be identical, but got
      left=#{left_point_impl},  right=#{right_point_impl}
      """
    end

    type = Point.type(left_point)
    comp = Point.compare(left_point, right_point)

    case {type, comp, left_bound, right_bound} do
      # left > right is an error:
      {_, :gt, _, _} ->
        raise "left > right which is invalid"

      # intervals given as either (p,p), [p,p) or (p,p]
      # (If you want a single point in an interval, give it as [p,p])
      # The (p,p) interval is already normalize form
      {_, :eq, :exclusive, :exclusive} ->
        normalized_empty(original)

      # [p,p) and (p,p] is normalized by taking the exlusive endpoint and
      # setting it as both left and right
      {_, :eq, :inclusive, :exclusive} ->
        normalized_empty(original)

      {_, :eq, :exclusive, :inclusive} ->
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
      {:discrete, _, :exclusive, :exclusive} ->
        case Point.compare(Point.next(left_point), right_point) do
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
      {:discrete, _, :inclusive, :inclusive} ->
        %__MODULE__{
          original
          | right: normalize_right_endpoint(right)
        }

      {:discrete, _, :exclusive, :inclusive} ->
        %__MODULE__{
          original
          | left: normalize_left_endpoint(left),
            right: normalize_right_endpoint(right)
        }

      # Finally, if we have an [) interval, then the original was
      # valid:
      {:discrete, :lt, :inclusive, :exclusive} ->
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

  defp normalize_right_endpoint({right_bound, right_point} = right) do
    case {Point.type(right_point), right_bound} do
      {:discrete, :inclusive} -> {:exclusive, Point.next(right_point)}
      {_, _} -> right
    end
  end

  defp normalize_left_endpoint(:unbounded), do: :unbounded

  defp normalize_left_endpoint({left_bound, left_point} = left) do
    case {Point.type(left_point), left_bound} do
      {:discrete, :exclusive} -> {:inclusive, Point.next(left_point)}
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
        left: {:exclusive, p},
        right: {:exclusive, p}
      }) do
    true
  end

  # If the interval is not properly normalized, we don't want to give an
  # incorrect answer, so we do the math to check if the interval is indeed empty:
  def empty?(%__MODULE__{
        left: {left_bound, left_point},
        right: {right_bound, right_point}
      }) do
    compare = Point.compare(left_point, right_point)

    cond do
      # left and right is equal, then the interval is empty
      # if the point is not included in the interval.
      # We don't want to rely on normalized intervals in empty?/1
      # in this function body, because if the interval was already normalized,
      # we'd only have to check for the `(zero,zero)` interval.
      # Therefore we must assume that the bounds could be incorrectly set to e.g. [p,p)
      compare == :eq ->
        left_bound == :exclusive or right_bound == :exclusive

      # if the point type is discrete and both bounds are exclusive,
      # then the interval could _also_ be empty if next(left) == right,
      # because the interval would represent 0 points.
      Point.type(left_point) == :discrete and
        left_bound == :exclusive and right_bound == :exclusive ->
        :eq ==
          left_point
          |> Point.next()
          |> Point.compare(right_point)

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
  def inclusive_left?(%__MODULE__{left: {:inclusive, _}}), do: true
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
  def inclusive_right?(%__MODULE__{right: {:inclusive, _}}), do: true
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
  @doc since: "0.1.3"
  @spec size(t(), unit :: any()) :: any()
  def size(a, unit \\ nil)
  def size(%__MODULE__{left: :unbounded}, _unit), do: nil
  def size(%__MODULE__{right: :unbounded}, _unit), do: nil
  def size(%__MODULE__{} = a, nil), do: Point.subtract(rpoint(a), lpoint(a))
  def size(%__MODULE__{} = a, unit), do: Point.subtract(rpoint(a), lpoint(a), unit)

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
      case Point.compare(rpoint(a), lpoint(b)) do
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
      case Point.compare(lpoint(a), rpoint(b)) do
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
      # Assuming we've normalized both a and b,
      # if the point types are discrete, and and normalized to `[)`
      # then continuous and discrete intervals are checked in the same way.
      # To ensure we don't give the wrong answer though,
      # we have an assertion that that a discrete point type must be
      # bounded as `[)`:
      assert_normalized_bounds(a)
      assert_normalized_bounds(b)

      inclusive_right?(a) != inclusive_left?(b) and
        Point.compare(rpoint(a), lpoint(b)) == :eq
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
      # Assuming we've normalized both a and b,
      # if the point types are discrete, and and normalized to `[)`
      # then continuous and discrete intervals are checked in the same way.
      # To ensure we don't give the wrong answer though,
      # we have an assertion that that a discrete point type must be
      # bounded as `[)`:
      assert_normalized_bounds(a)
      assert_normalized_bounds(b)

      Point.compare(lpoint(a), rpoint(b)) == :eq and
        inclusive_left?(a) != inclusive_right?(b)
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
      # check that lpoint(a) is less than or equal to (if inclusive) lpoint(b):
      contains_left =
        unbounded_left?(a) or
          (not unbounded_left?(b) and
             case Point.compare(lpoint(a), lpoint(b)) do
               :gt -> false
               :eq -> inclusive_left?(a) == inclusive_left?(b)
               :lt -> true
             end)

      # check that rpoint(a) is greater than or equal to (if inclusive) rpoint(b):
      contains_right =
        unbounded_right?(a) or
          (not unbounded_right?(b) and
             case Point.compare(rpoint(a), rpoint(b)) do
               :gt -> true
               :eq -> inclusive_right?(a) == inclusive_right?(b)
               :lt -> false
             end)

      # a contains b if both the left check and right check passes:
      contains_left and contains_right
    end
  end

  @doc """
  Does `a` contain the point `x`?

  ## Examples

      iex> contains_point?(new(left: 1, right: 2), 0)
      false

      iex> contains_point?(new(left: 1, right: 2), 1)
      true
  """
  @doc since: "0.1.4"
  def contains_point?(%__MODULE__{} = a, x) do
    with true <- not empty?(a) do
      contains_left =
        unbounded_left?(a) or
          case Point.compare(lpoint(a), x) do
            :gt -> false
            :eq -> inclusive_left?(a)
            :lt -> true
          end

      contains_right =
        unbounded_right?(a) or
          case Point.compare(rpoint(a), x) do
            :gt -> true
            :eq -> inclusive_right?(a)
            :lt -> false
          end

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
        left = pick_union_left(a.left, b.left)
        right = pick_union_right(a.right, b.right)

        from_endpoints(left, right)

      # fall-through, if neither A or B is empty,
      # but there is also no overlap or adjacency,
      # then the two intervals are either strictly left or strictly right,
      # we return empty (A and B share an empty amount of points)
      true ->
        # This assertion _must_ be true, since overlap?/2 returned false
        # so there is no point in running it.
        # true == strictly_left_of?(a, b) or strictly_right_of?(a, b)
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

      # otherwise, we can compute the intersection
      true ->
        # The intersection between `a` and `b` is the points that exist in
        # both `a` and `b`.
        left = pick_intersection_left(a.left, b.left)
        right = pick_intersection_right(a.right, b.right)
        from_endpoints(left, right)
    end
  end

  @doc """
  Partition an interval `a` into 3 intervals using  `x`:

  - The interval with all points from `a` < `x`
  - The interval with just `x`
  - The interval with  all points from `a` > `x`

  If `x` is not in `a` this function returns an empty list.

  ## Examples

      iex> partition(new(left: 1, right: 5, bounds: "[]"), 3)
      [
        new(left: 1, right: 3, bounds: "[)"),
        new(left: 3, right: 3, bounds: "[]"),
        new(left: 3, right: 5, bounds: "(]")
      ]

      iex> partition(new(left: 1, right: 5), -10)
      []
  """
  @doc since: "0.1.4"
  @spec partition(t(), Point.t()) :: [t()] | []
  def partition(a, x) do
    case contains_point?(a, x) do
      false ->
        []

      true ->
        [
          from_endpoints(a.left, {:exclusive, x}),
          from_endpoints({:inclusive, x}, {:inclusive, x}),
          from_endpoints({:exclusive, x}, a.right)
        ]
    end
  end

  ##
  ## Helpers
  ##

  # Pick the exclusive endpoint if it exists, else pick `a`
  defp pick_exclusive({:exclusive, _} = a, _), do: a
  defp pick_exclusive(_, {:exclusive, _} = b), do: b
  defp pick_exclusive(a, _b), do: a

  # Pick the inclusive endpoint if it exists, else pick `a`
  defp pick_inclusive({:inclusive, _} = a, _), do: a
  defp pick_inclusive(_, {:inclusive, _} = b), do: b
  defp pick_inclusive(a, _b), do: a

  # Pick the left point of a union from two left points
  defp pick_union_left(:unbounded, _), do: :unbounded
  defp pick_union_left(_, :unbounded), do: :unbounded

  defp pick_union_left(a, b) do
    case Point.compare(point(a), point(b)) do
      :gt -> b
      :lt -> a
      :eq -> pick_inclusive(a, b)
    end
  end

  # Pick the right point of a union from two right points
  defp pick_union_right(:unbounded, _), do: :unbounded
  defp pick_union_right(_, :unbounded), do: :unbounded

  defp pick_union_right(a, b) do
    case Point.compare(point(a), point(b)) do
      :gt -> a
      :lt -> b
      :eq -> pick_inclusive(a, b)
    end
  end

  # Pick the left point of a intersection from two left points
  defp pick_intersection_left(:unbounded, :unbounded), do: :unbounded
  defp pick_intersection_left(a, :unbounded), do: a
  defp pick_intersection_left(:unbounded, b), do: b

  defp pick_intersection_left(a, b) do
    case Point.compare(point(a), point(b)) do
      :gt -> a
      :lt -> b
      :eq -> pick_exclusive(a, b)
    end
  end

  # Pick the right point of a intersection from two right points
  defp pick_intersection_right(:unbounded, :unbounded), do: :unbounded
  defp pick_intersection_right(a, :unbounded), do: a
  defp pick_intersection_right(:unbounded, b), do: b

  defp pick_intersection_right(a, b) do
    case Point.compare(point(a), point(b)) do
      :gt -> b
      :lt -> a
      :eq -> pick_exclusive(a, b)
    end
  end

  defp normalized_empty(%__MODULE__{left: left, right: right} = a) do
    point =
      case {left, right} do
        {{_bound, point}, _} ->
          Point.zero(point)

        {_, {_bound, point}} ->
          Point.zero(point)
      end

    endpoint = {:exclusive, point}
    %{a | left: endpoint, right: endpoint}
  end

  # completely unbounded:
  @compile {:inline, unpack_bounds: 1}
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

  # Endpoint value extraction:

  @compile {:inline, rpoint: 1}
  defp rpoint(%{right: right}), do: point(right)
  @compile {:inline, lpoint: 1}
  defp lpoint(%{left: left}), do: point(left)

  @compile {:inline, point: 1}
  defp point({_, point}), do: point

  # Left is bounded and has a point
  defp assert_normalized_bounds(%{left: {_, point}} = a) do
    assert_normalized_bounds(a, Point.type(point))
  end

  # right is bounded and has a point
  defp assert_normalized_bounds(%{right: {_, point}} = a) do
    assert_normalized_bounds(a, Point.type(point))
  end

  defp assert_normalized_bounds(a, :discrete) do
    left_ok = unbounded_left?(a) or inclusive_left?(a)
    right_ok = unbounded_right?(a) or not inclusive_right?(a)

    if not (left_ok and right_ok) do
      raise "Discrete intervals should be normalized to the bounds `[)`, but got #{inspect(a)}"
    end
  end

  defp assert_normalized_bounds(_a, _) do
    nil
  end
end
