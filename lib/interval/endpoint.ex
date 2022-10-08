defmodule Interval.Endpoint do
  @moduledoc """
  An endpoint in an `Interval`.

  An Endpoint represents the left- or right-most point of an interval.
  """

  alias Interval.Point

  @type t() :: %__MODULE__{}
  defstruct inclusive: nil, point: nil

  @doc """
  Create a new Endpoint
  """
  def new(point, bound) when not is_nil(point) and bound in [:inclusive, :exclusive] do
    if Point.type(point) not in [:discrete, :continuous] do
      raise "Invalid point #{point}"
    end

    %__MODULE__{
      point: point,
      inclusive: bound == :inclusive
    }
  end

  @doc """
  Create a new inclusive Endpoint.
  """
  def inclusive(point) when not is_nil(point) do
    new(point, :inclusive)
  end

  @doc """
  Create a new exclusive Endpoint.
  """
  def exclusive(point) when not is_nil(point) do
    new(point, :exclusive)
  end

  # Is the endpoint inclusive?
  def inclusive?(%__MODULE__{inclusive: inclusive}), do: inclusive
end
