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
  Create a new interval with the specified left and right endpoints, and bounds.

  This is a specialization of the more general `new/1`
  """
  @callback new(left :: Interval.point(), right :: Interval.point(), bounds :: String.t()) ::
              Interval.t()

  @doc """
  Create a new `t:Interval.t/0`
  """
  @callback new(new_opts()) :: Interval.t()

  ##
  ## Callbacks related to working with the interval's points.
  ##

  @doc """
  Is this implementation of an interval considered discrete?

  The interval is implicitly continuous if not discrete.
  """
  @callback discrete?() :: boolean()

  @doc """
  Normalize a point to a canonical form. Returns :error if the point is invalid.
  """
  @callback point_normalize(point :: Interval.point()) :: :error | {:ok, Interval.point()}

  @doc """
  Compare two points, returning if `a == b`, `a > b` or `a < b`.
  """
  @callback point_compare(a :: Interval.point(), b :: Interval.point()) :: :eq | :gt | :lt

  @doc """
  Step a discrete point `n` steps.

  If `n` is negative, the point is stepped backwards.
  For integers this is simply addition (`point + n`)
  """
  @callback point_step(point :: Interval.point(), n :: integer()) :: Interval.point()

  @doc """
  Return a string representation of a point for use in formatting intervals.
  """
  @callback point_format(point :: Interval.point()) :: String.t()

  @doc """
  Parse a string representation of a point into a point, for use in parsing intervals.
  """
  @callback point_parse(string :: String.t()) :: {:ok, Interval.point()} | :error

  @optional_callbacks point_format: 1, point_parse: 1
end
