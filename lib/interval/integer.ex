defmodule Interval.Integer do
  @moduledoc false

  use Interval, type: Integer, discrete: true

  def point_valid?(a), do: is_integer(a)

  def size(%__MODULE__{left: {_, a}, right: {_, b}}), do: b - a
  def size(%__MODULE__{left: :empty, right: :empty}), do: 0
  def size(%__MODULE__{left: :unbounded}), do: nil
  def size(%__MODULE__{right: :unbounded}), do: nil

  @doc """
      iex> point_compare(1, 1)
      :eq
      
      iex> point_compare(1, 2)
      :lt

      iex> point_compare(2, 1)
      :gt
  """
  def point_compare(a, a) when is_integer(a), do: :eq
  def point_compare(a, b) when is_integer(a) and is_integer(b) and a > b, do: :gt
  def point_compare(a, b) when is_integer(a) and is_integer(b) and a < b, do: :lt

  @doc """
      iex> point_step(1, 2)
      3

      iex> point_step(3, -2)
      1
  """
  def point_step(a, n) when is_integer(a) and is_integer(n), do: a + n
end
