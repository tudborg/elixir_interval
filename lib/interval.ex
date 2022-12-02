defmodule Interval do
  @moduledoc """
  An interval represents the points between two endpoints.

  The interval can be empty.
  The empty interval is never contained in any other interval,
  and itself contains no points.

  It can be left and/or right unbounded, in which case
  it contains all points in the unbounded direction.
  A fully unbounded interval contains all other intervals, except
  the empty interval.

  ## Features

  The key features of this library are

  - Common interval operations built in are
    - `intersection/2`
    - `union/2`
    - `overlaps?/2`
    - `contains?/2`
    - `partition/2`
    - adjacent?
    - empty?
    - unbounded?
  - Built in support for intervals containing
      - `Integer`
      - `Float`
      - `Date`
      - `DateTime`
      - `NaiveDateTime`
      - `Decimal`
  - Also implements
    - `Ecto.Type`
    - `Jason.Encoder`

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
      :empty

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

  - `Interval.Date` containing points of type `Date`
  - `Interval.DateTime` containing points of type `DateTime`
  - `Interval.NaiveDateTime` containing points of type `NaiveDateTime`
  - `Interval.Float` containing points of type `Float`
  - `Interval.Integer` containing points of type `Integer`
  - `Interval.Decimal` containing points of type `Decimal` (See https://hexdocs.pm/decimal/2.0.0)

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

  See `new/1`.

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
          __struct__: atom(),
          # Left endpoint
          left: :empty | :unbounded | {bound(), point},
          # Right  endpoint
          right: :empty | :unbounded | {bound(), point}
        }

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

  @doc """
  Create a new interval.

  ## Options

  - `module` The interval implementation to use.
     When calling `new/1` from a `Interval.Behaviour` this is inferred.
  - `left` The left (or lower) endpoint of the interval
  - `right` The right (or upper) endpoint of the interval
  - `bounds` The bound mode to use. Defaults to `"[)"`

  A `nil` (`left` or `right`) endpoint is considered unbounded.
  The endpoint will also be considered unbounded if the `bounds` is explicitly
  set as unbounded.

  A special value `:empty` can be given to `left` and `right` to
  construct an empty interval.

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

      iex> new(module: Interval.Integer)

      iex> new(module: Interval.Integer, left: :empty, right: :empty)

      iex> new(module: Interval.Integer, left: 1)

      iex> new(module: Interval.Integer, left: 1, right: 1, bounds: "[]")

      iex> new(module: Interval.Integer, left: 10, right: 20, bounds: "()")
  """
  @spec new(Keyword.t()) :: t()
  def new(opts) when is_list(opts) do
    module = Keyword.get(opts, :module, nil)
    left = Keyword.get(opts, :left, nil)
    right = Keyword.get(opts, :right, nil)
    bounds = Keyword.get(opts, :bounds, nil)
    {left_bound, right_bound} = unpack_bounds(bounds)

    module = module || infer_implementation([left, right])

    if is_nil(module) do
      raise ArgumentError,
        message: "No implementation for interval available. Options given: #{inspect(opts)}"
    end

    left_endpoint = normalize_bound(left, left_bound)
    right_endpoint = normalize_bound(right, right_bound)

    module
    |> struct!(left: left_endpoint, right: right_endpoint)
    |> normalize()
  end

  defp normalize_bound(point, bound) do
    case {point, bound} do
      {:empty, _} -> :empty
      {nil, _} -> :unbounded
      {:unbound, _} -> :unbounded
      {_, :unbounded} -> :unbounded
      {_, :inclusive} -> {:inclusive, point}
      {_, :exclusive} -> {:exclusive, point}
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

      iex> empty?(new(module: Interval.Integer, left: 0, right: 0))
      true

      iex> empty?(new(module: Interval.Float, left: 1.0))
      false

      iex> empty?(new(module: Interval.Integer, left: 1, right: 2))
      false

  """
  @spec empty?(t()) :: boolean()
  def empty?(a)
  def empty?(%{left: :unbounded}), do: false
  def empty?(%{right: :unbounded}), do: false
  def empty?(%{left: :empty, right: :empty}), do: true

  # If the interval is not properly normalized, we don't want to give an
  # incorrect answer, so we do the math to check if the interval is indeed empty:
  def empty?(%{
        left: {:exclusive, p},
        right: {:exclusive, p}
      }) do
    true
  end

  def empty?(%module{
        left: {left_bound, left_point},
        right: {right_bound, right_point}
      }) do
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
          |> module.point_step(+1)
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

      iex> left(new(module: Interval.Integer, left: 1, right: 2))
      1
  """
  @compile {:inline, left: 1}
  @spec left(t()) :: point()
  def left(%{left: {_, value}}), do: value
  def left(%{left: _}), do: nil

  @doc """
  Return the right point.

  This function always returns nil when no point exist.
  Use the functions `empty?/1`, `inclusive_right?/1` and `unbounded_right?/1`
  to check for the meaning of the point.

  ## Example

      iex> right(new(module: Interval.Integer, left: 1, right: 2))
      2
  """
  @compile {:inline, right: 1}
  @spec right(t()) :: point()
  def right(%{right: {_, value}}), do: value
  def right(%{right: _}), do: nil

  @doc """
  Check if the interval is left-unbounded.

  The interval is left-unbounded if all points
  left of the right bound is included in this interval.

  ## Examples

      iex> unbounded_left?(new(module: Interval.Integer))
      true

      iex> unbounded_left?(new(module: Interval.Integer, right: 2))
      true

      iex> unbounded_left?(new(module: Interval.Integer, left: 1, right: 2))
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

      iex> unbounded_right?(new(module: Interval.Integer, right: 1))
      false

      iex> unbounded_right?(new(module: Interval.Integer))
      true

      iex> unbounded_right?(new(module: Interval.Integer, left: 1))
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
  > Discrete intervals (like `Interval.Integer` and `Interval.Date`) are always normalized
  > to be left-inclusive right-exclusive (`[)`).


      iex> inclusive_left?(new(module: Interval.Float, left: 1.0, right: 2.0, bounds: "[]"))
      true

      iex> inclusive_left?(new(module: Interval.Float, left: 1.0, right: 2.0, bounds: "[)"))
      true

      iex> inclusive_left?(new(module: Interval.Float, left: 1.0, right: 2.0, bounds: "()"))
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
  > Discrete intervals (like `Interval.Integer` and `Interval.Date`) are always normalized
  > to be left-inclusive right-exclusive (`[)`).


      iex> inclusive_right?(new(module: Interval.Float, left: 1.0, right: 2.0, bounds: "[]"))
      true

      iex> inclusive_right?(new(module: Interval.Float, left: 1.0, right: 2.0, bounds: "[)"))
      false

      iex> inclusive_right?(new(module: Interval.Float, left: 1.0, right: 2.0, bounds: "()"))
      false

  """
  @spec inclusive_right?(t()) :: boolean()
  def inclusive_right?(%{right: {:inclusive, _}}), do: true
  def inclusive_right?(%{}), do: false

  @doc since: "0.1.3"
  @spec size(t()) :: any()
  def size(%module{} = a), do: module.size(a)

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

      iex> strictly_left_of?(new(module: Interval.Integer, left: 1, right: 2), new(module: Interval.Integer, left: 3, right: 4))
      true

      iex> strictly_left_of?(new(module: Interval.Integer, left: 1, right: 3), new(module: Interval.Integer, left: 2, right: 4))
      false

      iex> strictly_left_of?(new(module: Interval.Integer, left: 3, right: 4), new(module: Interval.Integer, left: 1, right: 2))
      false
  """
  @spec strictly_left_of?(t(), t()) :: boolean()
  def strictly_left_of?(%module{} = a, %module{} = b) do
    not unbounded_right?(a) and
      not unbounded_left?(b) and
      not empty?(a) and
      not empty?(b) and
      case module.point_compare(right(a), left(b)) do
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

      # a:     [---)
      # b: [---)
      # r: true

      # a:        [---)
      # b: [---)
      # r: true

      # a:    [---)
      # b: [---)
      # r: false (overlaps)

      iex> strictly_right_of?(new(module: Interval.Integer, left: 1, right: 2), new(module: Interval.Integer, left: 3, right: 4))
      false

      iex> strictly_right_of?(new(module: Interval.Integer, left: 1, right: 3), new(module: Interval.Integer, left: 2, right: 4))
      false

      iex> strictly_right_of?(new(module: Interval.Integer, left: 3, right: 4), new(module: Interval.Integer, left: 1, right: 2))
      true
  """
  @spec strictly_right_of?(t(), t()) :: boolean()
  def strictly_right_of?(%module{} = a, %module{} = b) do
    not unbounded_left?(a) and
      not unbounded_right?(b) and
      not empty?(a) and
      not empty?(b) and
      case module.point_compare(left(a), right(b)) do
        :lt -> false
        :eq -> not inclusive_left?(a) or not inclusive_right?(b)
        :gt -> true
      end
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


      iex> adjacent_left_of?(new(module: Interval.Integer, left: 1, right: 2), new(module: Interval.Integer, left: 2, right: 3))
      true

      iex> adjacent_left_of?(new(module: Interval.Integer, left: 1, right: 3), new(module: Interval.Integer, left: 2, right: 4))
      false

      iex> adjacent_left_of?(new(module: Interval.Integer, left: 3, right: 4), new(module: Interval.Integer, left: 1, right: 2))
      false

      iex> adjacent_left_of?(new(module: Interval.Integer, right: 2, bounds: "[]"), new(module: Interval.Integer, left: 3))
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
      # Assuming we've normalized both a and b,
      # if the point types are discrete, and and normalized to `[)`
      # then continuous and discrete intervals are checked in the same way.
      # To ensure we don't give the wrong answer though,
      # we have an assertion that that a discrete point type must be
      # bounded as `[)`:
      assert_normalized_bounds(a)
      assert_normalized_bounds(b)

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

      iex> adjacent_right_of?(new(module: Interval.Integer, left: 2, right: 3), new(module: Interval.Integer, left: 1, right: 2))
      true

      iex> adjacent_right_of?(new(module: Interval.Integer, left: 1, right: 3), new(module: Interval.Integer, left: 2, right: 4))
      false

      iex> adjacent_right_of?(new(module: Interval.Integer, left: 1, right: 2), new(module: Interval.Integer, left: 3, right: 4))
      false

      iex> adjacent_right_of?(new(module: Interval.Integer, left: 3), new(module: Interval.Integer, right: 2, bounds: "]"))
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
      # Assuming we've normalized both a and b,
      # if the point types are discrete, and and normalized to `[)`
      # then continuous and discrete intervals are checked in the same way.
      # To ensure we don't give the wrong answer though,
      # we have an assertion that that a discrete point type must be
      # bounded as `[)`:
      assert_normalized_bounds(a)
      assert_normalized_bounds(b)

      module.point_compare(left(a), right(b)) == :eq and
        inclusive_left?(a) != inclusive_right?(b)
    end
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

      iex> overlaps?(new(module: Interval.Integer, left: 1, right: 3), new(module: Interval.Integer, left: 2, right: 4))
      true


      # [--a--)
      #       [--b--)

      iex> overlaps?(new(module: Interval.Integer, left: 1, right: 3), new(module: Interval.Integer, left: 3, right: 5))
      false


      # [--a--]
      #       [--b--]

      iex> overlaps?(new(module: Interval.Integer, left: 1, right: 3), new(module: Interval.Integer, left: 2, right: 4))
      true


      # (--a--)
      #       (--b--)

      iex> overlaps?(new(module: Interval.Integer, left: 1, right: 3), new(module: Interval.Integer, left: 3, right: 5))
      false


      # [--a--)
      #          [--b--)

      iex> overlaps?(new(module: Interval.Integer, left: 1, right: 2), new(module: Interval.Integer, left: 3, right: 4))
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

      iex> contains?(new(module: Interval.Integer, left: 1, right: 2), new(module: Interval.Integer, left: 1, right: 2))
      true

      iex> contains?(new(module: Interval.Integer, left: 1, right: 3), new(module: Interval.Integer, left: 2, right: 3))
      true

      iex> contains?(new(module: Interval.Integer, left: 2, right: 3), new(module: Interval.Integer, left: 1, right: 4))
      false

      iex> contains?(new(module: Interval.Integer, left: 1, right: 3), new(module: Interval.Integer, left: 1, right: 2))
      true

      iex> contains?(new(module: Interval.Integer, left: 1, right: 2, bounds: "()"), new(module: Interval.Integer, left: 1, right: 3))
      false

      iex> contains?(new(module: Interval.Integer, right: 1), new(module: Interval.Integer, left: 0, right: 1))
      true
  """
  @spec contains?(t(), t()) :: boolean()
  def contains?(%module{} = a, %module{} = b) do
    # Neither A or B must be empty, so that's a prerequisite for
    # even checking anything.
    prerequisite = not (empty?(a) or empty?(b))

    with true <- prerequisite do
      # check that left(a) is less than or equal to (if inclusive) left(b):
      contains_left =
        unbounded_left?(a) or
          (not unbounded_left?(b) and
             case module.point_compare(left(a), left(b)) do
               :gt -> false
               :eq -> inclusive_left?(a) == inclusive_left?(b)
               :lt -> true
             end)

      # check that right(a) is greater than or equal to (if inclusive) right(b):
      contains_right =
        unbounded_right?(a) or
          (not unbounded_right?(b) and
             case module.point_compare(right(a), right(b)) do
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

      iex> contains_point?(new(module: Interval.Integer, left: 1, right: 2), 0)
      false

      iex> contains_point?(new(module: Interval.Integer, left: 1, right: 2), 1)
      true
  """
  @doc since: "0.1.4"
  @spec contains_point?(t(), point()) :: boolean()
  def contains_point?(%module{} = a, x) do
    with true <- not empty?(a) do
      contains_left =
        unbounded_left?(a) or
          case module.point_compare(left(a), x) do
            :gt -> false
            :eq -> inclusive_left?(a)
            :lt -> true
          end

      contains_right =
        unbounded_right?(a) or
          case module.point_compare(right(a), x) do
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

      # a: [---)
      # b:   [---)
      # r: [-----)


  ## Examples

      # [--A--)
      #     [--B--)
      # [----C----)

      iex> union(new(module: Interval.Integer, left: 1, right: 3), new(module: Interval.Integer, left: 2, right: 4))
      new(module: Interval.Integer, left: 1, right: 4)


      # [-A-)
      #     [-B-)
      # [---C---)

      iex> union(new(module: Interval.Integer, left: 1, right: 2), new(module: Interval.Integer, left: 2, right: 3))
      new(module: Interval.Integer, left: 1, right: 3)

      iex> union(new(module: Interval.Integer, left: 1, right: 2), new(module: Interval.Integer, left: 3, right: 4))
      new(module: Interval.Integer, left: 0, right: 0)
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
        left = pick_union_left(module, a.left, b.left)
        right = pick_union_right(module, a.right, b.right)

        from_endpoints(module, left, right)

      # fall-through, if neither A or B is empty,
      # but there is also no overlap or adjacency,
      # then the two intervals are either strictly left or strictly right,
      # we return empty (A and B share an empty amount of points)
      true ->
        # This assertion _must_ be true, since overlap?/2 returned false
        # so there is no point in running it.
        # true == strictly_left_of?(a, b) or strictly_right_of?(a, b)
        new_empty(module)
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
      iex> intersection(new(module: Interval.Integer, left: 1, right: 3), new(module: Interval.Integer, left: 2, right: 4))
      new(module: Interval.Integer, left: 2, right: 3)

  Continuous:

      # a: [----)
      # b:    [----)
      # c:    [-)
      iex> intersection(new(module: Interval.Float, left: 1.0, right: 3.0), new(module: Interval.Float, left: 2.0, right: 4.0))
      new(module: Interval.Float, left: 2.0, right: 3.0)

      # a: (----)
      # b:    (----)
      # c:    (-)
      iex> intersection(
      ...>   new(module: Interval.Float, left: 1.0, right: 3.0, bounds: "()"),
      ...>   new(module: Interval.Float, left: 2.0, right: 4.0, bounds: "()")
      ...> )
      new(module: Interval.Float, left: 2.0, right: 3.0, bounds: "()")

      # a: [-----)
      # b:   [-------
      # c:   [---)
      iex> intersection(new(module: Interval.Float, left: 1.0, right: 3.0), new(module: Interval.Float, left: 2.0))
      new(module: Interval.Float, left: 2.0, right: 3.0)

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
        # The intersection between `a` and `b` is the points that exist in
        # both `a` and `b`.
        left = pick_intersection_left(module, a.left, b.left)
        right = pick_intersection_right(module, a.right, b.right)
        from_endpoints(module, left, right)
    end
  end

  @doc """
  Partition an interval `a` into 3 intervals using  `x`:

  - The interval with all points from `a` < `x`
  - The interval with just `x`
  - The interval with  all points from `a` > `x`

  If `x` is not in `a` this function returns an empty list.

  ## Examples

      iex> partition(new(module: Interval.Integer, left: 1, right: 5, bounds: "[]"), 3)
      [
        new(module: Interval.Integer, left: 1, right: 3, bounds: "[)"),
        new(module: Interval.Integer, left: 3, right: 3, bounds: "[]"),
        new(module: Interval.Integer, left: 3, right: 5, bounds: "(]")
      ]

      iex> partition(new(module: Interval.Integer, left: 1, right: 5), -10)
      []
  """
  @doc since: "0.1.4"
  @spec partition(t(), point()) :: [t()] | []
  def partition(%module{} = a, x) do
    case contains_point?(a, x) do
      false ->
        []

      true ->
        [
          from_endpoints(module, a.left, {:exclusive, x}),
          from_endpoints(module, {:inclusive, x}, {:inclusive, x}),
          from_endpoints(module, {:exclusive, x}, a.right)
        ]
    end
  end

  @doc """
  Convert an `t:Interval.t/0` to a map.

  The returned map contains the struct module used for the interval
  in the `type` key, so that it is possible to reconstruct the interval from the map.
  """
  @doc since: "0.3.0"
  @spec to_map(t()) :: %{
          type: String.t(),
          empty: boolean(),
          left: nil | %{inclusive: boolean(), value: any()},
          right: nil | %{inclusive: boolean(), value: any()}
        }
  def to_map(%module{} = a) do
    empty? = Interval.empty?(a)

    %{
      type: Module.split(module) |> Enum.join("."),
      empty: empty?,
      left:
        if(not Interval.unbounded_left?(a) and not empty?,
          do: %{
            inclusive: Interval.inclusive_left?(a),
            value: Interval.left(a)
          }
        ),
      right:
        if(not Interval.unbounded_right?(a) and not empty?,
          do: %{
            inclusive: Interval.inclusive_right?(a),
            value: Interval.right(a)
          }
        )
    }
  end

  @doc false
  @doc since: "0.3.4"
  @spec to_inspect_doc(t(), Inspect.Opts.t()) :: Inspect.Algebra.t()
  def to_inspect_doc(%module{left: _, right: _} = a, opts) do
    content =
      case empty?(a) do
        true ->
          "empty"

        false ->
          open =
            cond do
              unbounded_left?(a) -> ""
              inclusive_left?(a) -> "["
              not inclusive_left?(a) -> "("
            end
            |> Inspect.Algebra.color(:list, opts)

          close =
            cond do
              unbounded_right?(a) -> ""
              inclusive_right?(a) -> "]"
              not inclusive_right?(a) -> ")"
            end
            |> Inspect.Algebra.color(:list, opts)

          sep = Inspect.Algebra.color(",", :list, opts)

          Inspect.Algebra.container_doc(
            open,
            [left(a), right(a)],
            close,
            opts,
            &to_interval_value_doc/2,
            separator: sep
          )
      end

    prefix =
      ["#", Inspect.Algebra.to_doc(module, opts), "<"]
      |> Inspect.Algebra.concat()
      |> Inspect.Algebra.group()

    postfix = ">"

    Inspect.Algebra.concat([
      prefix,
      Inspect.Algebra.nest(content, :cursor, :break),
      postfix
    ])
    |> Inspect.Algebra.group()
  end

  defp to_interval_value_doc(value, opts)
  defp to_interval_value_doc(nil, _), do: ""
  defp to_interval_value_doc(value, opts), do: Inspect.Algebra.to_doc(value, opts)

  ##
  ## Helpers
  ##

  defp from_endpoints(module, left, right) do
    left_bound =
      case left do
        :unbounded -> :unbounded
        {:exclusive, _} -> :exclusive
        {:inclusive, _} -> :inclusive
      end

    right_bound =
      case right do
        :unbounded -> :unbounded
        {:exclusive, _} -> :exclusive
        {:inclusive, _} -> :inclusive
      end

    left_point =
      case left do
        :unbounded -> nil
        {_, point} -> point
      end

    right_point =
      case right do
        :unbounded -> nil
        {_, point} -> point
      end

    new(
      module: module,
      left: left_point,
      right: right_point,
      bounds: pack_bounds({left_bound, right_bound})
    )
  end

  # non-empty non-unbounded Interval:
  defp normalize(
         %module{
           left: {left_bound, left_point} = left,
           right: {right_bound, right_point} = right
         } = original
       ) do
    if not module.point_valid?(left_point) do
      raise ArgumentError,
        message: "#{left_point} not a valid left point in #{module}"
    end

    if not module.point_valid?(right_point) do
      raise ArgumentError,
        message: "#{right_point} not a valid right point in #{module}"
    end

    type = if module.discrete?(), do: :discrete, else: :continuous
    comp = module.point_compare(left_point, right_point)

    case {type, comp, left_bound, right_bound} do
      # left > right is an error:
      {_, :gt, _, _} ->
        raise ArgumentError,
          message: "#{left_point} > #{right_point} which is not valid in an interval #{module}"

      # intervals given as either (p,p), [p,p) or (p,p]
      # (If you want a single point in an interval, give it as [p,p])
      # The (p,p) interval is already normalize form
      {_, :eq, :exclusive, :exclusive} ->
        new_empty(module)

      # [p,p) and (p,p] is normalized by taking the exlusive endpoint and
      # setting it as both left and right
      {_, :eq, :inclusive, :exclusive} ->
        new_empty(module)

      {_, :eq, :exclusive, :inclusive} ->
        new_empty(module)

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
        case module.point_compare(module.point_step(left_point, 1), right_point) do
          :eq ->
            new_empty(module)

          :lt ->
            %{original | left: normalize_left_endpoint(module, left)}
        end

      # Remaining bound combinations are:
      # [], (], [)
      # we don't need to touch [), so we only need to deal with
      # the ones that are upper-inclusive. We want to perform the following
      # transformations:
      # [a,b] -> [a, b+1)
      # (a,b] -> [a+1, b+1)
      {:discrete, _, :inclusive, :inclusive} ->
        %{
          original
          | right: normalize_right_endpoint(module, right)
        }

      {:discrete, _, :exclusive, :inclusive} ->
        %{
          original
          | left: normalize_left_endpoint(module, left),
            right: normalize_right_endpoint(module, right)
        }

      # Finally, if we have an [) interval, then the original was
      # valid:
      {:discrete, :lt, :inclusive, :exclusive} ->
        original
    end
  end

  # the interval is already empty normalized form
  defp normalize(%_module{left: :empty, right: :empty} = original) do
    original
  end

  # Either left or right or both must be unbounded
  defp normalize(%module{left: left, right: right} = original) do
    %{
      original
      | left: normalize_left_endpoint(module, left),
        right: normalize_right_endpoint(module, right)
    }
  end

  defp normalize_right_endpoint(_module, :unbounded), do: :unbounded

  defp normalize_right_endpoint(module, {right_bound, right_point} = right) do
    case {module.discrete?(), right_bound} do
      {true, :inclusive} -> {:exclusive, module.point_step(right_point, 1)}
      {_, _} -> right
    end
  end

  defp normalize_left_endpoint(_module, :unbounded), do: :unbounded

  defp normalize_left_endpoint(module, {left_bound, left_point} = left) do
    case {module.discrete?(), left_bound} do
      {true, :exclusive} -> {:inclusive, module.point_step(left_point, 1)}
      {_, _} -> left
    end
  end

  # Pick the exclusive endpoint if it exists
  defp pick_exclusive({:exclusive, _} = a, _), do: a
  defp pick_exclusive(_, {:exclusive, _} = b), do: b
  defp pick_exclusive(a, b) when a < b, do: b
  defp pick_exclusive(a, _b), do: a

  # Pick the inclusive endpoint if it exists
  defp pick_inclusive({:inclusive, _} = a, _), do: a
  defp pick_inclusive(_, {:inclusive, _} = b), do: b
  defp pick_inclusive(a, b) when a < b, do: b
  defp pick_inclusive(a, _b), do: a

  # Pick the left point of a union from two left points
  defp pick_union_left(_, :unbounded, _), do: :unbounded
  defp pick_union_left(_, _, :unbounded), do: :unbounded

  defp pick_union_left(module, a, b) do
    case module.point_compare(point(a), point(b)) do
      :gt -> b
      :lt -> a
      :eq -> pick_inclusive(a, b)
    end
  end

  # Pick the right point of a union from two right points
  defp pick_union_right(_, :unbounded, _), do: :unbounded
  defp pick_union_right(_, _, :unbounded), do: :unbounded

  defp pick_union_right(module, a, b) do
    case module.point_compare(point(a), point(b)) do
      :gt -> a
      :lt -> b
      :eq -> pick_inclusive(a, b)
    end
  end

  # Pick the left point of a intersection from two left points
  defp pick_intersection_left(_, :unbounded, :unbounded), do: :unbounded
  defp pick_intersection_left(_, a, :unbounded), do: a
  defp pick_intersection_left(_, :unbounded, b), do: b

  defp pick_intersection_left(module, a, b) do
    case module.point_compare(point(a), point(b)) do
      :gt -> a
      :lt -> b
      :eq -> pick_exclusive(a, b)
    end
  end

  # Pick the right point of a intersection from two right points
  defp pick_intersection_right(_, :unbounded, :unbounded), do: :unbounded
  defp pick_intersection_right(_, a, :unbounded), do: a
  defp pick_intersection_right(_, :unbounded, b), do: b

  defp pick_intersection_right(module, a, b) do
    case module.point_compare(point(a), point(b)) do
      :gt -> b
      :lt -> a
      :eq -> pick_exclusive(a, b)
    end
  end

  # completely unbounded:
  @compile {:inline, unpack_bounds: 1}
  defp unpack_bounds(nil), do: unpack_bounds("[)")
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

  @compile {:inline, pack_bounds: 1}
  defp pack_bounds({:unbounded, :unbounded}), do: ""
  # unbounded either left or right
  defp pack_bounds({:unbounded, :exclusive}), do: ")"
  defp pack_bounds({:exclusive, :unbounded}), do: "("
  defp pack_bounds({:unbounded, :inclusive}), do: "]"
  defp pack_bounds({:inclusive, :unbounded}), do: "["
  # bounded both sides
  defp pack_bounds({:exclusive, :exclusive}), do: "()"
  defp pack_bounds({:inclusive, :inclusive}), do: "[]"
  defp pack_bounds({:inclusive, :exclusive}), do: "[)"
  defp pack_bounds({:exclusive, :inclusive}), do: "(]"

  defp new_empty(module) do
    module.new(left: :empty, right: :empty)
  end

  # Endpoint value extraction:
  @compile {:inline, point: 1}
  defp point({_, point}), do: point

  # Left is bounded and has a point
  defp assert_normalized_bounds(%module{left: {_, _}} = a) do
    assert_normalized_bounds(a, module.discrete?())
  end

  # right is bounded and has a point
  defp assert_normalized_bounds(%module{right: {_, _}} = a) do
    assert_normalized_bounds(a, module.discrete?())
  end

  defp assert_normalized_bounds(%module{} = a, true) do
    left_ok = unbounded_left?(a) or inclusive_left?(a)
    right_ok = unbounded_right?(a) or not inclusive_right?(a)

    if not (left_ok and right_ok) do
      raise ArgumentError,
        message:
          "non-normalized discrete interval #{module}: #{inspect(a)} " <>
            "(expected normalized bounds `[)`)"
    end
  end

  defp assert_normalized_bounds(_a, _discrete) do
    nil
  end

  defp infer_implementation(values) do
    implementations =
      values
      # reject nil-values (they mean "unbounded")
      |> Enum.reject(&is_nil/1)
      # check that an implementation exists for the value
      |> Enum.map(&(Interval.Intervalable.impl_for(&1) && &1))
      # reject if nil implementation
      |> Enum.reject(&is_nil/1)
      # call infer_implementation/1 on the remaining values we know has an implementation
      |> Enum.map(&Interval.Intervalable.infer_implementation/1)
      # get the unique list of implementations available
      |> Enum.uniq()

    case implementations do
      [] ->
        nil

      [impl] ->
        impl

      [_first_impl | _] = multiple ->
        raise ArgumentError,
          message: "Got multiple potential implementations for intervals: #{inspect(multiple)}"
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
  - `jason_encoder` - Should it include `Jason.Encoder` implementation? default: `true` 

  ## Examples

      defmodule MyInterval do
        use Interval, type: MyType, discrete: false
      end
  """
  defmacro __using__(opts) do
    quote location: :keep,
          bind_quoted: [
            type: Keyword.fetch!(opts, :type),
            discrete: Keyword.get(opts, :discrete, false),
            jason_encoder: Keyword.get(opts, :jason_encoder, true)
          ] do
      @moduledoc """
      Represents a #{if discrete, do: "discrete", else: "continuous"}
      interval containing `#{type}`
      """

      @behaviour Interval.Behaviour
      @discrete discrete

      @typedoc "An interval of point type `#{type}`"
      @type t() :: %__MODULE__{}

      defstruct left: nil, right: nil

      @spec new(Keyword.t()) :: Interval.t()
      def new(opts \\ []) do
        Interval.new(Keyword.put(opts, :module, __MODULE__))
      end

      @spec discrete?() :: boolean()
      def discrete?(), do: @discrete

      ##
      ## Implement the inspect protocol automatically:
      ##
      defimpl Inspect do
        @moduledoc false
        def inspect(interval, opts), do: Interval.to_inspect_doc(interval, opts)
      end

      ##
      ## Jason support
      ## If Jason is loaded, we define an implementation for Jason.Encoder.
      ##
      if jason_encoder and Code.ensure_loaded?(Jason) do
        defimpl Jason.Encoder do
          @moduledoc false
          def encode(%{left: _, right: _} = interval, opts) do
            Jason.Encode.map(Interval.to_map(interval), opts)
          end
        end
      end
    end
  end
end
