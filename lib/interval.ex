defmodule Interval do
  @moduledoc """
  Interval - A library for working with intervals in Elixir.

  It is modelled after Postgres' range types. In cases where behaviour is ambiguous,
  the "correct" behaviour is whatever Postgres does.

  An interval represents the points between two endpoints.

  The interval can be empty.
  The empty interval is never contained in any other interval,
  and itself contains no points.

  It can be left and/or right unbounded, in which case
  it contains all points in the unbounded direction.
  A fully unbounded interval contains all other intervals, except
  the empty interval.

  ## Features

  Supports intervals of stdlib types like `DateTime`.
  Also comes with support for `Decimal` out of the box.

  Automatically generates an `Ecto.Type` for use with Postgres' range types
  (see https://www.postgresql.org/docs/current/rangetypes.html)

  You can very easily implement your own types into the interval
  with the `Interval.__using__/1` macro.

  Built in intervals:
    - `Interval.IntegerInterval`
    - `Interval.FloatInterval`
    - `Interval.DateInterval`
    - `Interval.DateTimeInterval`
    - `Interval.NaiveDateTimeInterval`
    - `Interval.DecimalInterval`

  ## Interval Notation

  Throughout the documentation and comments, you'll see a notation for
  writing about intervals.
  As this library is inspired by the functionality in PostgreSQL's range types,
  we align ourselves with it's  notation choice and borrow it
  (https://www.postgresql.org/docs/current/rangetypes.html)

  This notation is also described in ISO 31-11.

      [left-inclusive, right-inclusive]
      (left-exclusive, right-exclusive)
      [left-inclusive, right-exclusive)
      (left-exclusive, right-inclusive]
      empty

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
  The built-in intervals are:

  - `Interval.DateInterval` containing points of type `Date`
  - `Interval.DateTimeInterval` containing points of type `DateTime`
  - `Interval.NaiveDateTimeInterval` containing points of type `NaiveDateTime`
  - `Interval.FloatIntervalInterval` containing points of type `Float`
  - `Interval.IntegerIntervalInterval` containing points of type `Integer`
  - `Interval.DecimalInterval` containing points of type `Decimal` (See https://hexdocs.pm/decimal/2.0.0)

  However, you can quite easily implement an interval by implementing
  the `Interval.Behaviour`.

  The easiest way to do so, is by using the `Interval.__using__` macro:

      defmodule MyInterval do
        use Interval, type: MyType, discrete: false
      end

  You must implement a few functions defined in `Interval.Behaviour`.
  Once that's done, all operations available in the `Interval` module (like
  interesection, union, overlap etc) will work on your interval struct.

  An obvious usecase for this would be to implement an interval that works
  with the https://hexdocs.pm/decimal library.

  ## Discrete vs Continuous intervals

  Depending on the behaviour you want from your interval, it is either said to be
  discrete or continuous.

  A discrete interval represents a set of finite points (like integers).
  A continuous interval can be said to represent the infinite number of points between
  two endpoints (like an interval between two floats).

  With discrete points, it is possible to define what the next and previous
  point is, and we normalise these intervals to the bound type `[)`.

  The distinction between a discrete and continuous interval is important
  because the two behave slightly different in some of the library functions.

  A discrete interval is adjacent to another discrete interval, if there
  is no points between the two interval.
  Contrast this to continuous intervals of real numbers where there is always
  an infinite number of real numbers between two distinct real numbers,
  and so continuous intervals are only said to be adjacent to each other
  if they include the same point, and one point is inclusive where the other
  is exclusive.

  Where relevant, the function documentation will mention the differences
  between discrete and continuous intervals.

  ## Create an Interval

  See `new/1`

  ## Normalization

  When creating an interval through `new/1`, it will get normalized
  so that intervals that represents the same points,
  are also represented in the same way in the struct.
  This allows you to compare two intervals for equality by using `==`
  (and using pattern matching).

  It is therefore not recommended to modify an interval struct directly,
  but instead do so by using one of the functions that modify the interval.

  An interval is said to be empty if it spans zero points.
  The normalized form of an empty interval is the special interval struct
  where left and right is set to `:empty`,
  however a non-normalized empty struct will still correctly report
  empty via the `empty?/1` function.
  """
  alias Interval.IntervalOperationError

  @typedoc """
  An interval struct, representing all points between
  two endpoints.

  The struct has two fields: `left` and `right`,
  representing the left (lower) and right (upper) points
  in the interval.

  If either left or right is set to `:empty`, the both must be
  set to `:empty`.

  The specific struct type depends on the interval implementation,
  but the `left` and `right` field is always present, all will
  be manipulated by the `Interval` module regardless of the interval
  implementation.
  """
  @type t(point) :: %{
          __struct__: module(),
          # Left endpoint
          left: endpoint(point),
          # Right  endpoint
          right: endpoint(point)
        }

  @typedoc """
  An endpoint of an interval.

  Can be either
  - `:empty` representing an empty interval (both endpoints will be empty)
  - `:unbounded` representing an unbounded endpoint
  - `{bound(), t}` representing a bounded endpoint
  """
  @type endpoint(t) :: :empty | :unbounded | {bound(), t}

  @typedoc """
  Shorthand for `t(any())`
  """
  @type t() :: t(any())

  @typedoc """
  A point in an interval.
  """
  @type point() :: any()

  @typedoc """
  The bound type of an endpoint.
  """
  @type bound() :: :inclusive | :exclusive

  @typedoc """
  Options are:  "[]" | "()" | "(]" | "[)" | "[" | "]" | "(" | ")" | ""
  """
  @type strbounds() :: String.t()

  @doc """
  Create a new interval.

  ## Options


  - `left` The left (or lower) endpoint value of the interval (default: `:unbounded`)
  - `right` The right (or upper) endpoint value of the interval (default: `:unbounded`)
  - `bounds` The bound mode to use (default: `"[)"`)
  - `empty` If set to `true`, the interval will be empty (default: `false`)
  - `module` The interval implementation to use.
     When calling `new/1` from an `Interval.Behaviour` this is inferred.

  Specifying `left` or `right` as `nil` will be interpreted as `:unbounded`.
  The endpoint will also be considered unbounded if the `bounds` explicitly sets it as unbounded.

  Specifying `left` or `right` as `:empty` will create an empty interval.

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

      iex> new(module: Interval.IntegerInterval)

      iex> new(module: Interval.IntegerInterval, empty: true)

      iex> new(module: Interval.IntegerInterval, left: 1)

      iex> new(module: Interval.IntegerInterval, left: 1, right: 1, bounds: "[]")

      iex> new(module: Interval.IntegerInterval, left: 10, right: 20, bounds: "()")
  """
  @spec new(Keyword.t()) :: t()
  def new(opts) when is_list(opts) do
    module = Keyword.fetch!(opts, :module)
    empty = Keyword.get(opts, :empty, false)
    left = with nil <- Keyword.get(opts, :left), do: :unbounded
    right = with nil <- Keyword.get(opts, :right), do: :unbounded
    bounds = with nil <- Keyword.get(opts, :bounds), do: "[)"

    if empty == true or left == :empty or right == :empty do
      # if we need to create an empty struct, we can short-circuit to an empty:
      struct!(module, left: :empty, right: :empty)
    else
      # otherwise we need to do bounds checking and normalization:
      {left_bound, right_bound} = unpack_bounds(bounds)
      left_endpoint = normalize_endpoint(module, left, left_bound)
      right_endpoint = normalize_endpoint(module, right, right_bound)
      normalize(struct!(module, left: left_endpoint, right: right_endpoint))
    end
  end

  defp normalize_endpoint(module, point, bound) do
    case {point, bound} do
      # point value takes precedence over bound:
      {:unbounded, _} -> :unbounded
      # if the point is set, the bound value discribes bound-ness:
      {_, :unbounded} -> :unbounded
      {_, :inclusive} -> {:inclusive, normalize_point!(module, point)}
      {_, :exclusive} -> {:exclusive, normalize_point!(module, point)}
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

      iex> empty?(new(module: Interval.IntegerInterval, left: 0, right: 0))
      true

      iex> empty?(new(module: Interval.FloatInterval, left: 1.0))
      false

      iex> empty?(new(module: Interval.IntegerInterval, left: 1, right: 2))
      false

  """
  @spec empty?(t()) :: boolean()
  def empty?(a)

  # if either side is empty, the interval is empty (normalized form will ensure both are set empty)
  def empty?(%{left: :empty}), do: true
  def empty?(%{right: :empty}), do: true

  def empty?(%{left: :unbounded}), do: false
  def empty?(%{right: :unbounded}), do: false

  # If the interval is not properly normalized, we have to check for all possible combinations.
  # an interval is empty if it spans a single point but the point is excluded (from either side)
  def empty?(%{left: {:exclusive, p}, right: {:exclusive, p}}), do: true
  def empty?(%{left: {:inclusive, p}, right: {:exclusive, p}}), do: true
  def empty?(%{left: {:exclusive, p}, right: {:inclusive, p}}), do: true

  def empty?(%module{left: {left_bound, left_point}, right: {right_bound, right_point}}) do
    compare = module.point_compare(left_point, right_point)

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
      module.discrete?() and
        left_bound == :exclusive and right_bound == :exclusive ->
        :eq ==
          left_point
          |> then(&point_step(module, &1, +1))
          |> module.point_compare(right_point)

      # If none of the above, then the interval is not empty
      true ->
        false
    end
  end

  @doc """
  Return the left point.

  This function always returns nil when no point exist.
  Use the functions `empty?/1`, `inclusive_left?/1` and `unbounded_left?/1`
  to check for the meaning of the point.

  ## Example

      iex> left(new(module: Interval.IntegerInterval, left: 1, right: 2))
      1
  """
  @spec left(t()) :: point()
  def left(%{left: {_, value}}), do: value
  def left(%{left: _}), do: nil

  @doc """
  Return the right point.

  This function always returns nil when no point exist.
  Use the functions `empty?/1`, `inclusive_right?/1` and `unbounded_right?/1`
  to check for the meaning of the point.

  ## Example

      iex> right(new(module: Interval.IntegerInterval, left: 1, right: 2))
      2
  """
  @spec right(t()) :: point()
  def right(%{right: {_, value}}), do: value
  def right(%{right: _}), do: nil

  @doc """
  Check if the interval is left-unbounded.

  The interval is left-unbounded if all points
  left of the right bound is included in this interval.

  ## Examples

      iex> unbounded_left?(new(module: Interval.IntegerInterval))
      true

      iex> unbounded_left?(new(module: Interval.IntegerInterval, right: 2))
      true

      iex> unbounded_left?(new(module: Interval.IntegerInterval, left: 1, right: 2))
      false

  """
  @spec unbounded_left?(t()) :: boolean()
  def unbounded_left?(%{left: :unbounded}), do: true
  def unbounded_left?(%{}), do: false

  @doc """
  Check if the interval is right-unbounded.

  The interval is right-unbounded if all points
  right of the left bound is included in this interval.

  ## Examples

      iex> unbounded_right?(new(module: Interval.IntegerInterval, right: 1))
      false

      iex> unbounded_right?(new(module: Interval.IntegerInterval))
      true

      iex> unbounded_right?(new(module: Interval.IntegerInterval, left: 1))
      true

  """
  @spec unbounded_right?(t()) :: boolean()
  def unbounded_right?(%{right: :unbounded}), do: true
  def unbounded_right?(%{}), do: false

  @doc """
  Is the interval left-inclusive?

  The interval is left-inclusive if the left endpoint
  value is included in the interval.

  > #### Note {: .info}
  > Discrete intervals (like `Interval.IntegerInterval` and `Interval.DateInterval`) are always normalized
  > to be left-inclusive right-exclusive (`[)`).


      iex> inclusive_left?(new(module: Interval.FloatInterval, left: 1.0, right: 2.0, bounds: "[]"))
      true

      iex> inclusive_left?(new(module: Interval.FloatInterval, left: 1.0, right: 2.0, bounds: "[)"))
      true

      iex> inclusive_left?(new(module: Interval.FloatInterval, left: 1.0, right: 2.0, bounds: "()"))
      false

  """
  @spec inclusive_left?(t()) :: boolean()
  def inclusive_left?(%{left: {:inclusive, _}}), do: true
  def inclusive_left?(%{}), do: false

  @doc """
  Is the interval right-inclusive?

  The interval is right-inclusive if the right endpoint
  value is included in the interval.

  > #### Note {: .info}
  > Discrete intervals (like `Interval.IntegerInterval` and `Interval.DateInterval`) are always normalized
  > to be left-inclusive right-exclusive (`[)`).


      iex> inclusive_right?(new(module: Interval.FloatInterval, left: 1.0, right: 2.0, bounds: "[]"))
      true

      iex> inclusive_right?(new(module: Interval.FloatInterval, left: 1.0, right: 2.0, bounds: "[)"))
      false

      iex> inclusive_right?(new(module: Interval.FloatInterval, left: 1.0, right: 2.0, bounds: "()"))
      false

  """
  @spec inclusive_right?(t()) :: boolean()
  def inclusive_right?(%{right: {:inclusive, _}}), do: true
  def inclusive_right?(%{}), do: false

  @doc """
  Is the interval left-exclusive?

  The interval is left-exclusive if the left endpoint value is excluded from the interval.

  > #### Note {: .info}
  > Discrete intervals (like `Interval.IntegerInterval` and `Interval.DateInterval`) are always normalized
  > to be left-inclusive right-exclusive (`[)`).


      iex> exclusive_left?(new(module: Interval.FloatInterval, left: 1.0, right: 2.0, bounds: "[]"))
      false

      iex> exclusive_left?(new(module: Interval.FloatInterval, left: 1.0, right: 2.0, bounds: "(]"))
      true

      iex> exclusive_left?(new(module: Interval.FloatInterval, left: 1.0, right: 2.0, bounds: "()"))
      true

  """
  @spec exclusive_left?(t()) :: boolean()
  def exclusive_left?(%{left: {:exclusive, _}}), do: true
  def exclusive_left?(%{}), do: false

  @doc """
  Is the interval right-exclusive?

  The interval is right-exclusive if the right endpoint value is excluded from the interval.

  > #### Note {: .info}
  > Discrete intervals (like `Interval.IntegerInterval` and `Interval.DateInterval`) are always normalized
  > to be left-inclusive right-exclusive (`[)`).


      iex> exclusive_right?(new(module: Interval.FloatInterval, left: 1.0, right: 2.0, bounds: "[]"))
      false

      iex> exclusive_right?(new(module: Interval.FloatInterval, left: 1.0, right: 2.0, bounds: "[)"))
      true

      iex> exclusive_right?(new(module: Interval.FloatInterval, left: 1.0, right: 2.0, bounds: "()"))
      true

  """
  @spec exclusive_right?(t()) :: boolean()
  def exclusive_right?(%{right: {:exclusive, _}}), do: true
  def exclusive_right?(%{}), do: false

  @doc """
  Is `a` strictly left of `b`.

  `a` is strictly left of `b` if no point in `a` is in `b`,
  and all points in `a` is left (<) of all points in `b`.

  ## Examples

      # a: [---)
      # b:     [---)
      # r: true

      # a: [---)
      # b:        [---)
      # r: true

      # a: [---)
      # b:    [---)
      # r: false (overlaps)

      iex> strictly_left_of?(new(module: Interval.IntegerInterval, left: 1, right: 2), new(module: Interval.IntegerInterval, left: 3, right: 4))
      true

      iex> strictly_left_of?(new(module: Interval.IntegerInterval, left: 1, right: 3), new(module: Interval.IntegerInterval, left: 2, right: 4))
      false

      iex> strictly_left_of?(new(module: Interval.IntegerInterval, left: 3, right: 4), new(module: Interval.IntegerInterval, left: 1, right: 2))
      false
  """
  @spec strictly_left_of?(t(), t()) :: boolean()
  def strictly_left_of?(%module{} = a, %module{} = b) do
    not unbounded_right?(a) and
      not unbounded_left?(b) and
      not empty?(a) and
      not empty?(b) and
      compare_bounds(:right, a, :left, b) == :lt
  end

  @doc """
  Is `a` strictly right of `b`.

  `a` is strictly right of `b` if no point in `a` is in `b`,
  and all points in `a` is right (>) of all points in `b`.

  ## Examples

      # a:     [---)
      # b: [---)
      # r: true

      # a:        [---)
      # b: [---)
      # r: true

      # a:    [---)
      # b: [---)
      # r: false (overlaps)

      iex> strictly_right_of?(new(module: Interval.IntegerInterval, left: 1, right: 2), new(module: Interval.IntegerInterval, left: 3, right: 4))
      false

      iex> strictly_right_of?(new(module: Interval.IntegerInterval, left: 1, right: 3), new(module: Interval.IntegerInterval, left: 2, right: 4))
      false

      iex> strictly_right_of?(new(module: Interval.IntegerInterval, left: 3, right: 4), new(module: Interval.IntegerInterval, left: 1, right: 2))
      true
  """
  @spec strictly_right_of?(t(), t()) :: boolean()
  def strictly_right_of?(%module{} = a, %module{} = b) do
    not unbounded_left?(a) and
      not unbounded_right?(b) and
      not empty?(a) and
      not empty?(b) and
      compare_bounds(:left, a, :right, b) == :gt
  end

  @doc """
  Is the interval `a` adjacent to `b`, to the left of `b`.

  `a` is adjacent to `b` left of `b`, if `a` and `b` do _not_ overlap,
  and there are no points between `a.right` and `b.left`.

      # a: [---)
      # b:     [---)
      # r: true

      # a: [---]
      # b:     [---]
      # r: false (overlaps)

      # a: (---)
      # b:        (---)
      # r: false (points exist between a.right and b.left)

  ## Examples


      iex> adjacent_left_of?(new(module: Interval.IntegerInterval, left: 1, right: 2), new(module: Interval.IntegerInterval, left: 2, right: 3))
      true

      iex> adjacent_left_of?(new(module: Interval.IntegerInterval, left: 1, right: 3), new(module: Interval.IntegerInterval, left: 2, right: 4))
      false

      iex> adjacent_left_of?(new(module: Interval.IntegerInterval, left: 3, right: 4), new(module: Interval.IntegerInterval, left: 1, right: 2))
      false

      iex> adjacent_left_of?(new(module: Interval.IntegerInterval, right: 2, bounds: "[]"), new(module: Interval.IntegerInterval, left: 3))
      true
  """
  @spec adjacent_left_of?(t(), t()) :: boolean()
  def adjacent_left_of?(%module{} = a, %module{} = b) do
    prerequisite =
      not unbounded_right?(a) and
        not unbounded_left?(b) and
        not empty?(a) and
        not empty?(b)

    with true <- prerequisite do
      if module.discrete?() do
        # for discrete types, to detect adjacency, we need to ensure normalized bounds.
        assert_bounds(a, "[)")
        assert_bounds(b, "[)")
      end

      inclusive_right?(a) != inclusive_left?(b) and
        module.point_compare(right(a), left(b)) == :eq
    end
  end

  @doc """
  Is the interval `a` adjacent to `b`, to the right of `b`.

  `a` is adjacent to `b` right of `b`, if `a` and `b` do _not_ overlap,
  and there are no points between `a.left` and `b.right`.

      # a:     [---)
      # b: [---)
      # r: true

      # a:     [---)
      # b: [---]
      # r: false (overlaps)

      # a:        (---)
      # b: (---)
      # r: false (points exist between a.left and b.right)

  ## Examples

      iex> adjacent_right_of?(new(module: Interval.IntegerInterval, left: 2, right: 3), new(module: Interval.IntegerInterval, left: 1, right: 2))
      true

      iex> adjacent_right_of?(new(module: Interval.IntegerInterval, left: 1, right: 3), new(module: Interval.IntegerInterval, left: 2, right: 4))
      false

      iex> adjacent_right_of?(new(module: Interval.IntegerInterval, left: 1, right: 2), new(module: Interval.IntegerInterval, left: 3, right: 4))
      false

      iex> adjacent_right_of?(new(module: Interval.IntegerInterval, left: 3), new(module: Interval.IntegerInterval, right: 2, bounds: "]"))
      true
  """
  @spec adjacent_right_of?(t(), t()) :: boolean()
  def adjacent_right_of?(%module{} = a, %module{} = b) do
    prerequisite =
      not unbounded_left?(a) and
        not unbounded_right?(b) and
        not empty?(a) and
        not empty?(b)

    with true <- prerequisite do
      if module.discrete?() do
        # for discrete types, to detect adjacency, we need to ensure normalized bounds.
        assert_bounds(a, "[)")
        assert_bounds(b, "[)")
      end

      module.point_compare(left(a), right(b)) == :eq and
        inclusive_left?(a) != inclusive_right?(b)
    end
  end

  @doc """
  Check if two intervals are adjacent.

  Two intervals are adjacent if they do not overlap, and there are no points between them.

  This function is a shorthand for `adjacent_left_of(a, b) or adjacent_right_of?(a, b)`.
  """
  @doc since: "2.0.0"
  def adjacent?(a, b) do
    adjacent_left_of?(a, b) or adjacent_right_of?(a, b)
  end

  @doc """
  Does `a` overlap with `b`?

  `a` overlaps with `b` if any point in `a` is also in `b`.

      # a: [---)
      # b:   [---)
      # r: true

      # a: [---)
      # b:     [---)
      # r: false

      # a: [---]
      # b:     [---]
      # r: true

      # a: (---)
      # b:     (---)
      # r: false

      # a: [---)
      # b:        [---)
      # r: false

  ## Examples

      # [--a--)
      #     [--b--)

      iex> overlaps?(new(module: Interval.IntegerInterval, left: 1, right: 3), new(module: Interval.IntegerInterval, left: 2, right: 4))
      true


      # [--a--)
      #       [--b--)

      iex> overlaps?(new(module: Interval.IntegerInterval, left: 1, right: 3), new(module: Interval.IntegerInterval, left: 3, right: 5))
      false


      # [--a--]
      #       [--b--]

      iex> overlaps?(new(module: Interval.IntegerInterval, left: 1, right: 3), new(module: Interval.IntegerInterval, left: 2, right: 4))
      true


      # (--a--)
      #       (--b--)

      iex> overlaps?(new(module: Interval.IntegerInterval, left: 1, right: 3), new(module: Interval.IntegerInterval, left: 3, right: 5))
      false


      # [--a--)
      #          [--b--)

      iex> overlaps?(new(module: Interval.IntegerInterval, left: 1, right: 2), new(module: Interval.IntegerInterval, left: 3, right: 4))
      false
  """
  @spec overlaps?(t(), t()) :: boolean()
  def overlaps?(%module{} = a, %module{} = b) do
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

      # a: [-------]
      # b:   [---]
      # r: true

      # a: [---]
      # b: [---]
      # r: true

      # a: [---]
      # b: (---)
      # r: true

      # a: (---)
      # b: [---]
      # r: false

      # a:   [---]
      # b: [-------]
      # r: false

  This means that `a.left` is less than `b.left` (or unbounded), and `a.right` is greater than
  `b.right` (or unbounded)

  If `a` and `b`'s point match, then `b` is "in" `a` if `a` and `b` share bound types.

  E.g. if `a.left` and `b.left` matches, then `a` contains `b` if both `a` and `b`'s
  `left` is inclusive or exclusive.

  If either of `b` endpoints are unbounded, then `a` only contains `b`
  if the corresponding endpoint in `a` is also unbounded.

  ## Examples

      iex> contains?(new(module: Interval.IntegerInterval, left: 1, right: 2), new(module: Interval.IntegerInterval, left: 1, right: 2))
      true

      iex> contains?(new(module: Interval.IntegerInterval, left: 1, right: 3), new(module: Interval.IntegerInterval, left: 2, right: 3))
      true

      iex> contains?(new(module: Interval.IntegerInterval, left: 2, right: 3), new(module: Interval.IntegerInterval, left: 1, right: 4))
      false

      iex> contains?(new(module: Interval.IntegerInterval, left: 1, right: 3), new(module: Interval.IntegerInterval, left: 1, right: 2))
      true

      iex> contains?(new(module: Interval.IntegerInterval, left: 1, right: 2, bounds: "()"), new(module: Interval.IntegerInterval, left: 1, right: 3))
      false

      iex> contains?(new(module: Interval.IntegerInterval, right: 1), new(module: Interval.IntegerInterval, left: 0, right: 1))
      true
  """
  @spec contains?(t(), t()) :: boolean()

  def contains?(%module{} = a, %module{} = b) do
    cond do
      # if a == b then a by definition contains b
      a == b ->
        true

      # all ranges contains the empty range
      empty?(b) ->
        true

      # if a contains no points, and b contains some points, then a cannot contain b
      empty?(a) ->
        false

      true ->
        compare_bounds(module, :left, a.left, :left, b.left) in [:lt, :eq] and
          compare_bounds(module, :right, a.right, :right, b.right) in [:gt, :eq]
    end
  end

  @doc """
  Does `a` contain the point `x`?

  ## Examples

      iex> contains_point?(new(module: Interval.IntegerInterval, left: 1, right: 2), 0)
      false

      iex> contains_point?(new(module: Interval.IntegerInterval, left: 1, right: 2), 1)
      true
  """
  @doc since: "0.1.4"
  @spec contains_point?(t(), point()) :: boolean()
  def contains_point?(%module{} = a, x) do
    contains?(a, new(module: module, left: x, right: x, bounds: "[]"))
  end

  @doc """
  Computes the union of `a` and `b`.

  The union contains all of the points that are either in `a` or `b`.

  If either `a` or `b` are empty, the returned interval will be the non-empty interval.

      # a: [---)
      # b:   [---)
      # r: [-----)


  ## Examples

      # [--A--)
      #     [--B--)
      # [----C----)

      iex> union(new(module: Interval.IntegerInterval, left: 1, right: 3), new(module: Interval.IntegerInterval, left: 2, right: 4))
      new(module: Interval.IntegerInterval, left: 1, right: 4)


      # [-A-)
      #     [-B-)
      # [---C---)

      iex> union(new(module: Interval.IntegerInterval, left: 1, right: 2), new(module: Interval.IntegerInterval, left: 2, right: 3))
      new(module: Interval.IntegerInterval, left: 1, right: 3)

      iex> union(new(module: Interval.IntegerInterval, left: 1, right: 2), new(module: Interval.IntegerInterval, left: 3, right: 4))
      ** (Interval.IntervalOperationError) cannot union non-overlapping non-adjacent intervals as the result would be non-contiguous
  """
  @spec union(t(), t()) :: t()
  def union(%module{} = a, %module{} = b) do
    cond do
      # if either is empty, return the other
      empty?(a) ->
        b

      empty?(b) ->
        a

      # if a and b overlap or are adjacent, we can union the intervals
      overlaps?(a, b) or adjacent_left_of?(a, b) or adjacent_right_of?(a, b) ->
        left =
          case compare_bounds(module, :left, a.left, :left, b.left) do
            :lt -> a.left
            _ -> b.left
          end

        right =
          case compare_bounds(module, :right, a.right, :right, b.right) do
            :gt -> a.right
            _ -> b.right
          end

        from_endpoints(module, left, right)

      # no overlap, not adjacent, not empty.
      # We cannot union these intervals as the result would not be contiguous.
      true ->
        raise IntervalOperationError,
          message:
            "cannot union non-overlapping non-adjacent intervals as the result would be non-contiguous"
    end
  end

  @doc """
  Compute the intersection between `a` and `b`.

  The intersection contains all of the points that are both in `a` and `b`.

  If either `a` or `b` are empty, the returned interval will be empty.

      # a: [----]
      # b:    [----]
      # r:    [-]

      # a: (----)
      # b:    (----)
      # r:    (-)

      # a: [----)
      # b:    [----)
      # r:    [-)

  ## Examples:

  Discrete:

      # a: [----)
      # b:    [----)
      # c:    [-)
      iex> intersection(new(module: Interval.IntegerInterval, left: 1, right: 3), new(module: Interval.IntegerInterval, left: 2, right: 4))
      new(module: Interval.IntegerInterval, left: 2, right: 3)

  Continuous:

      # a: [----)
      # b:    [----)
      # c:    [-)
      iex> intersection(new(module: Interval.FloatInterval, left: 1.0, right: 3.0), new(module: Interval.FloatInterval, left: 2.0, right: 4.0))
      new(module: Interval.FloatInterval, left: 2.0, right: 3.0)

      # a: (----)
      # b:    (----)
      # c:    (-)
      iex> intersection(
      ...>   new(module: Interval.FloatInterval, left: 1.0, right: 3.0, bounds: "()"),
      ...>   new(module: Interval.FloatInterval, left: 2.0, right: 4.0, bounds: "()")
      ...> )
      new(module: Interval.FloatInterval, left: 2.0, right: 3.0, bounds: "()")

      # a: [-----)
      # b:   [-------
      # c:   [---)
      iex> intersection(new(module: Interval.FloatInterval, left: 1.0, right: 3.0), new(module: Interval.FloatInterval, left: 2.0))
      new(module: Interval.FloatInterval, left: 2.0, right: 3.0)

  """
  @spec intersection(t(), t()) :: t()
  def intersection(%module{} = a, %module{} = b) do
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
        new_empty(module)

      # otherwise, we can compute the intersection
      true ->
        # The intersection between `a` and `b` is the points that exist in both `a` and `b`.
        # Since we know they overlap, we can just pick the left-most right bound and the right-most left bound.

        left =
          case compare_bounds(module, :left, a.left, :left, b.left) do
            :lt -> b.left
            _ -> a.left
          end

        right =
          case compare_bounds(module, :right, a.right, :right, b.right) do
            :gt -> b.right
            _ -> a.right
          end

        from_endpoints(module, left, right)
    end
  end

  @doc """
  Computes the difference between `a` and `b` by subtracting all points in `b` from `a`.

  `b` must not be contained in `a` in such a way that the difference would not be a single interval.

  ## Examples:

  Discrete:

      # a: [-----)
      # b:     [-----)
      # c: [---)
      iex> difference(Interval.IntegerInterval.new(1, 4), Interval.IntegerInterval.new(3, 5))
      Interval.IntegerInterval.new(1, 3)

      # a:     [-----)
      # b: [-----)
      # c:       [---)
      iex> difference(Interval.IntegerInterval.new(3, 5), Interval.IntegerInterval.new(1, 4))
      Interval.IntegerInterval.new(4, 5)

  Continuous:

      # a: [------)
      # b:     [-----)
      # c: [---)
      iex> difference(Interval.FloatInterval.new(1.0, 4.0), Interval.FloatInterval.new(3.0, 5.0))
      Interval.FloatInterval.new(1.0, 3.0)

      # a: [-----)
      # b:     (-----)
      # c: [---]
      iex> difference(Interval.FloatInterval.new(1.0, 4.0), Interval.FloatInterval.new(3.0, 5.0, "()"))
      Interval.FloatInterval.new(1.0, 3.0, "[]")
  """
  @doc since: "2.0.0"
  def difference(a, b)

  def difference(%{} = a, %{} = a) do
    new_empty(a.__struct__)
  end

  def difference(%module{} = a, %module{} = b) do
    if empty?(a) or empty?(b) do
      # if a or b are empty, then the a - b = a
      a
    else
      cmp_al_bl = compare_bounds(module, :left, a.left, :left, b.left)
      cmp_al_br = compare_bounds(module, :left, a.left, :right, b.right)
      cmp_ar_bl = compare_bounds(module, :right, a.right, :left, b.left)
      cmp_ar_br = compare_bounds(module, :right, a.right, :right, b.right)

      cond do
        # if a.left < b.left and a.right > b.right then a contains b which would result in multiple intervals
        cmp_al_bl === :lt and cmp_ar_br === :gt ->
          raise IntervalOperationError,
            message: "subtracting B from A would result in multiple intervals"

        # if a.left > b.right or a.right < b.left then a does not overlap b, so a - b = a
        cmp_al_br === :gt or cmp_ar_bl === :lt ->
          a

        # if a.left >= b.left and a.right <= b.right then b covers a, so: a - b = empty
        cmp_al_bl in [:gt, :eq] and cmp_ar_br in [:lt, :eq] ->
          new_empty(module)

        # a: [------)
        # b:    [------)
        # if a.left <= b.left and a.right >= b.left and a.right <= b.right
        cmp_al_bl in [:lt, :eq] and cmp_ar_bl in [:gt, :eq] and cmp_ar_br in [:lt, :eq] ->
          from_endpoints(module, a.left, inverted_bound(b.left))

        # a:    [------)
        # b: [------)
        # if a.left >= b.left and a.right >= b.right and a.left <= b.right
        cmp_al_bl in [:gt, :eq] and cmp_ar_br in [:gt, :eq] and cmp_al_br in [:lt, :eq] ->
          from_endpoints(module, inverted_bound(b.right), a.right)
      end
    end
  end

  defp inverted_bound({:inclusive, point}), do: {:exclusive, point}
  defp inverted_bound({:exclusive, point}), do: {:inclusive, point}

  @doc """
  Partition an interval `a` into 3 intervals using  `x`:

  - The interval with all points from `a` where `a` < `x`
  - The interval with `x`
  - The interval with all points from `a` where `a` > `x`

  If `x` is not in `a` this function returns an empty list.

  Note: Since 2.0.0, `x` can be a point _or_ an interval.
  When `x` is a point, the middle interval will be an interval such that `[x,x]`.

  If there are no points in a to the left of `x`, an empty interval is returned for the left side.
  The same of course applies to the right side of `x`.

  ## Examples

      iex> partition(Interval.IntegerInterval.new(1, 5, "[]"), 3)
      [
        Interval.IntegerInterval.new(1, 3, "[)"),
        Interval.IntegerInterval.new(3, 3, "[]"),
        Interval.IntegerInterval.new(3, 5, "(]")
      ]

      iex> partition(Interval.IntegerInterval.new(1, 5), -10)
      []

      iex> partition(Interval.IntegerInterval.new(1, 6), Interval.IntegerInterval.new(3, 4))
      [
        Interval.IntegerInterval.new(1, 3, "[)"),
        Interval.IntegerInterval.new(3, 4, "[)"),
        Interval.IntegerInterval.new(4, 6, "[)")
      ]

      iex> partition(Interval.FloatInterval.new(1.0, 6.0), Interval.FloatInterval.new(1.0, 3.0, "[]"))
      [
        Interval.FloatInterval.new(1.0, 1.0, "[)"),
        Interval.FloatInterval.new(1.0, 3.0, "[]"),
        Interval.FloatInterval.new(3.0, 6.0, "()")
      ]
  """
  @doc since: "0.1.4"
  @spec partition(t(), point() | t()) :: [t()] | []
  def partition(%module{} = a, %module{} = x) do
    if contains?(a, x) and not empty?(x) do
      # x might be unbounded, in which case the left/right side of x will be the empty interval.
      left_of =
        if unbounded_left?(x) do
          new_empty(module)
        else
          from_endpoints(module, a.left, inverted_bound(x.left))
        end

      right_of =
        if unbounded_right?(x) do
          new_empty(module)
        else
          from_endpoints(module, inverted_bound(x.right), a.right)
        end

      [left_of, x, right_of]
    else
      []
    end
  end

  def partition(%module{} = a, x) do
    partition(a, new(module: module, left: x, right: x, bounds: "[]"))
  end

  @doc """
  Compare the left/right side of `a` with the left/right side of `b`

  Returns `:lt | :gt | :eq` depending on `a`s relationship to `b`.

  Other interval operations use this function as primitive.
  """
  @doc since: "2.0.0"
  @spec compare_bounds(:left | :right, t(), :left | :right, t()) :: :lt | :eq | :gt
  def compare_bounds(a_side, %module{} = a, b_side, %module{} = b) do
    compare_bounds(module, a_side, Map.fetch!(a, a_side), b_side, Map.fetch!(b, b_side))
  end

  ##
  ## Helpers
  ##

  defp compare_bounds(_module, _, a, _, b) when a == :empty or b == :empty do
    # deals with empty intervals. This should be checked before calling this function
    raise IntervalOperationError, message: "cannot compare bounds of empty intervals"
  end

  defp compare_bounds(_module, a_side, a, b_side, b) when a == :unbounded or b == :unbounded do
    # deals with unbounded points
    case {a, b} do
      {:unbounded, :unbounded} ->
        # if both are unbounded, then they are equal unless one is left and other is right
        # in which case we need to return the corresponding :lt / :gt
        case {a_side, b_side} do
          {same, same} -> :eq
          {:left, :right} -> :lt
          {:right, :left} -> :gt
        end

      {:unbounded, _} ->
        # a is unbounded. If it is a left-side then it is always less than b
        if a_side == :left, do: :lt, else: :gt

      {_, :unbounded} ->
        # b is unbounded. If it is a left-side then a is always greater than b
        if b_side == :left, do: :gt, else: :lt
    end
  end

  defp compare_bounds(module, a_side, {a_bound, a_point}, b_side, {b_bound, b_point}) do
    # bound bounds are finite, we can compare a and b points
    # if result is :eq, we might need to modify it depending on bounds and sides
    with :eq <- module.point_compare(a_point, b_point) do
      case {a_bound, b_bound, a_side, b_side} do
        # both points are inclusive, so the points are indeed :eq
        {:inclusive, :inclusive, _, _} -> :eq
        # both are exclusive, so they are equal if they are of the same side
        # and :lt / :gt if they are of different sides
        {:exclusive, :exclusive, side, side} -> :eq
        {:exclusive, :exclusive, :left, :right} -> :gt
        {:exclusive, :exclusive, :right, :left} -> :lt
        # if a is inclusive:
        {:inclusive, :exclusive, :left, :left} -> :lt
        {:inclusive, :exclusive, :right, :right} -> :gt
        {:inclusive, :exclusive, :left, :right} -> :gt
        {:inclusive, :exclusive, :right, :left} -> :lt
        # if b is inclusive:
        {:exclusive, :inclusive, :left, :left} -> :gt
        {:exclusive, :inclusive, :right, :right} -> :lt
        {:exclusive, :inclusive, :left, :right} -> :gt
        {:exclusive, :inclusive, :right, :left} -> :lt
      end
    end
  end

  defp from_endpoints(module, left, right) do
    new(
      module: module,
      left: point(left),
      right: point(right),
      bounds: pack_bounds({bound(left), bound(right)})
    )
  end

  defp new_empty(module) do
    module.new(empty: true)
  end

  defp bound(:unbounded), do: :unbounded
  defp bound({:exclusive, _}), do: :exclusive
  defp bound({:inclusive, _}), do: :inclusive

  defp point(:unbounded), do: nil
  defp point({_, point}), do: point

  defp normalize_point!(module, point) do
    case module.point_normalize(point) do
      {:ok, point} -> point
      :error -> raise ArgumentError, message: "Invalid point #{inspect(point)} for #{module}"
    end
  end

  defp normalize(%module{} = interval) do
    case module.discrete?() do
      true -> normalize_discrete(interval)
      false -> normalize_continuous(interval)
    end
  end

  defp normalize_continuous(%module{} = interval) do
    if empty?(interval), do: new_empty(module), else: interval
  end

  defp normalize_discrete(%module{} = interval) do
    if empty?(interval) do
      new_empty(module)
    else
      %{
        interval
        | left: normalize_left_endpoint(module, interval.left),
          right: normalize_right_endpoint(module, interval.right)
      }
    end
  end

  defp normalize_right_endpoint(_module, :unbounded), do: :unbounded

  defp normalize_right_endpoint(module, {right_bound, right_point}) do
    case {module.discrete?(), right_bound} do
      {true, :inclusive} -> {:exclusive, point_step(module, right_point, +1)}
      {_, _} -> {right_bound, right_point}
    end
  end

  defp normalize_left_endpoint(_module, :unbounded), do: :unbounded

  defp normalize_left_endpoint(module, {left_bound, left_point}) do
    case {module.discrete?(), left_bound} do
      {true, :exclusive} -> {:inclusive, point_step(module, left_point, +1)}
      {_, _} -> {left_bound, left_point}
    end
  end

  @bounds %{
    "" => {:unbounded, :unbounded},
    ")" => {:unbounded, :exclusive},
    "(" => {:exclusive, :unbounded},
    "]" => {:unbounded, :inclusive},
    "[" => {:inclusive, :unbounded},
    "()" => {:exclusive, :exclusive},
    "[]" => {:inclusive, :inclusive},
    "[)" => {:inclusive, :exclusive},
    "(]" => {:exclusive, :inclusive}
  }

  for {str, tuple} <- @bounds do
    defp unpack_bounds(unquote(str)), do: unquote(tuple)
    defp pack_bounds(unquote(tuple)), do: unquote(str)
  end

  defp assert_bounds(%{} = a, bounds) when is_binary(bounds) do
    assert_bounds(a, unpack_bounds(bounds))
  end

  defp assert_bounds(%{left: :empty, right: :empty}, {_left, _right}), do: :ok
  defp assert_bounds(%{left: {left, _}, right: {right, _}}, {left, right}), do: :ok
  defp assert_bounds(%{left: {left, _}, right: :unbounded}, {left, _right}), do: :ok
  defp assert_bounds(%{left: :unbounded, right: {right, _}}, {_left, right}), do: :ok
  defp assert_bounds(%{left: :unbounded, right: :unbounded}, {_left, _right}), do: :ok

  defp assert_bounds(a, bounds) do
    raise ArgumentError,
      message: "expected bounds #{pack_bounds(bounds)} for interval #{inspect(a)}"
  end

  defp point_step(module, point, step) do
    case module.point_step(point, step) do
      nil ->
        raise IntervalOperationError, message: "#{module}.point_step/2 did not return a point"

      stepped ->
        stepped
    end
  end

  ##
  ## using-macro
  ##

  @doc """
  Define an interval struct of a specific point type.

  Support for `Ecto.Type` and the `Postgrex.Range` can be automatically
  generated by specifying `ecto_type: <type>` when `use`ing.

  ## Options

  - `type` - The internal point type in this interval. *required*
  - `discrete` - Is this interval discrete? `default: false`

  ## Examples

      defmodule MyInterval do
        use Interval, type: MyType, discrete: false
      end
  """
  defmacro __using__(opts) do
    Interval.Macro.define_interval(opts)
  end
end
