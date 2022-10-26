defmodule Interval.Behaviour do
  @moduledoc """
  Defines the Interval behaviour.
  You'll usually want to use this behaviour by using

      use Interval, type: MyType

  In your own interval modules, instead of defining
  the behaviour directly.
  """

  @type new_opt() ::
          {:left, Interval.point()}
          | {:right, Interval.point()}
          | {:bounds, String.t()}
  @type new_opts() :: [new_opt()]

  ##
  ## Creating an interval
  ##

  @doc """
  Create a new `t:Interval.t/0`
  """
  @callback new(new_opts()) :: Interval.t()

  ##
  ## Functions specific to each implementation
  ##

  @doc """
  Return the "size" of the interval.
  The returned value depends on the interval implementation used.

  ## For Discrete Intervals

  For discrete point types, the size represents the number of elements the
  interval contains.

  I.e. for `Date` the size is the number of `Date` structs the interval
  can be said to "contain" (the number of days)

  ### Examples

      iex> size(new(module: Interval.Integer, left: 1, right: 1, bounds: "[]"))
      1

      iex> size(new(module: Interval.Integer, left: 1, right: 3, bounds: "[)"))
      2

      # Note that this interval will be normalized to an empty interval
      # due to the bounds:
      iex> size(new(module: Interval.Integer, left: 1, right: 2, bounds: "()"))
      0

  ## For Continuous Intervals

  For continuous intervals, the size is reported as the difference
  between the left and right points.

  ### Examples

      # The size of the interval `[1.0, 5.0)` is also 4:
      iex> size(new(module: Interval.Float, left: 1.0, right: 5.0, bounds: "[)"))
      4.0

      # And likewise, so is the size of `[1.0, 5.0]` (note the bound change)
      iex> size(new(module: Interval.Float, left: 1.0, right: 5.0, bounds: "[]"))
      4.0

      # Exactly one point contained in  this continuous interval,
      # so technically not empty, but it also has zero  size.
      iex> size(new(module: Interval.Float, left: 1.0, right: 1.0, bounds: "[]"))
      0.0

      # Empty continuous interval
      iex> size(new(module: Interval.Float, left: 1.0, right: 1.0, bounds: "()"))
      0.0

  """
  @callback size(Interval.t()) :: any()

  ##
  ## Callbacks related to working with the interval's points.
  ##

  @doc """
  Is this implementation of an interval considered discrete?

  The interval is implicitly continuous if not discrete.
  """
  @callback discrete?() :: boolean()

  @doc """
  Is the given argument a valid point in this Interval implementation.
  """
  @callback point_valid?(Interval.point()) :: boolean()

  @doc """
  Compare two points, returning if `a == b`, `a > b` or `a < b`.
  """
  @callback point_compare(Interval.point(), Interval.point()) :: :eq | :gt | :lt

  @doc """
  Step a discrete point `n` steps.

  If `n` is negative, the point is stepped backwards.
  For integers this is simply addition (`point + n`)
  """
  @callback point_step(Interval.point(), n :: integer()) :: Interval.point()
end
