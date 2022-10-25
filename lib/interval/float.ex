defmodule Interval.Float do
  @moduledoc false

  use Interval, type: Float, discrete: false

  def point_valid?(a), do: is_float(a)

  def size(%__MODULE__{left: {_, a}, right: {_, b}}), do: b - a
  def size(%__MODULE__{left: :empty, right: :empty}), do: 0.0
  def size(%__MODULE__{left: :unbounded}), do: nil
  def size(%__MODULE__{right: :unbounded}), do: nil

  @doc """
      iex> point_compare(1.0, 1.0)
      :eq
      
      iex> point_compare(1.0, 2.0)
      :lt

      iex> point_compare(2.0, 1.0)
      :gt
  """
  def point_compare(a, a) when is_float(a), do: :eq
  def point_compare(a, b) when is_float(a) and is_float(b) and a > b, do: :gt
  def point_compare(a, b) when is_float(a) and is_float(b) and a < b, do: :lt

  @doc """
      iex> point_step(1.0, 1)
      nil
  """
  def point_step(a, _n) when is_float(a), do: nil
end
