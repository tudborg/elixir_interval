defmodule Interval.Macro do
  @moduledoc """
  Macro helpers for Interval
  """

  def define_interval(opts) do
    type = Keyword.fetch!(opts, :type)
    discrete = Keyword.get(opts, :discrete, false)

    quote do
      @moduledoc """
      Represents a #{if unquote(discrete), do: "discrete", else: "continuous"} interval containing `#{inspect(unquote(type))}`

      Defines a struct with two fields, `left` and `right`, representing the left and right endpoints of the interval.
      The endpoint fields are of type `t:Interval.endpoint(#{inspect(unquote(type))})`

      This module delegates most functionality to the `Interval` module.
      """

      @behaviour Interval.Behaviour
      @discrete unquote(discrete)

      @typedoc "An interval of point type `#{inspect(unquote(type))}`"
      @type t() :: %__MODULE__{}
      @type point_type() :: unquote(type)

      defstruct left: nil, right: nil

      @spec new(left :: point_type(), right :: point_type(), bounds :: Interval.strbounds()) ::
              t()
      def new(left, right, bounds \\ "[)") do
        new(left: left, right: right, bounds: bounds)
      end

      def new(opts \\ []) do
        opts
        |> Keyword.put(:module, __MODULE__)
        |> Interval.new()
      end

      @spec discrete?() :: unquote(discrete)
      def discrete?(), do: @discrete

      # default implementation for point_step/2
      # continuous intervals do not support a step function, and will not need to implement this.
      @spec point_step(point_type(), integer()) :: nil
      def point_step(a, _n),
        do: raise(Interval.IntervalOperationError, "point_step not implemented for #{__MODULE__}")

      defoverridable point_step: 2

      # delegate functionality to Interval
      defdelegate empty?(interval), to: Interval
      defdelegate left(interval), to: Interval
      defdelegate right(interval), to: Interval
      defdelegate unbounded_left?(interval), to: Interval
      defdelegate unbounded_right?(interval), to: Interval
      defdelegate inclusive_left?(interval), to: Interval
      defdelegate inclusive_right?(interval), to: Interval
      defdelegate strictly_left_of?(a, b), to: Interval
      defdelegate strictly_right_of?(a, b), to: Interval
      defdelegate adjacent_left_of?(a, b), to: Interval
      defdelegate adjacent_right_of?(a, b), to: Interval
      defdelegate adjacent?(a, b), to: Interval
      defdelegate overlaps?(a, b), to: Interval
      defdelegate contains?(a, b), to: Interval
      defdelegate contains_point?(a, x), to: Interval
      defdelegate union(a, b), to: Interval
      defdelegate intersection(a, b), to: Interval
      defdelegate partition(a, x), to: Interval
      defdelegate difference(a, b), to: Interval
    end
  end
end
