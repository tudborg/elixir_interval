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
  Create a new `t:Interval.t()`
  """
  @callback new(new_opts()) :: Interval.t()

  ##
  ## Functions specific to each implementation
  ##

  @callback size(Interval.t()) :: any()

  ##
  ## Callbacks related to working with the interval's points.
  ##

  @callback discrete?() :: boolean()

  @callback point_valid?(Interval.point()) :: boolean()

  @callback point_compare(Interval.point(), Interval.point()) :: :eq | :gt | :lt

  @callback point_step(Interval.point(), n :: integer()) :: Interval.point()
end
