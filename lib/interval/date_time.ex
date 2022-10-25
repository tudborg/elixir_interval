defmodule Interval.DateTime do
  @moduledoc false

  use Interval, type: DateTime, discrete: false

  def size(%__MODULE__{right: :unbounded}), do: nil
  def size(%__MODULE__{left: :unbounded}), do: nil
  def size(%__MODULE__{left: :empty, right: :empty}), do: 0.0
  def size(%__MODULE__{left: {_, a}, right: {_, b}}), do: DateTime.diff(b, a)

  def point_valid?(a), do: is_struct(a, DateTime)

  @doc """
      iex> point_compare(~U[2022-01-01 00:00:00Z], ~U[2022-01-01 00:00:00Z])
      :eq
      
      iex> point_compare(~U[2022-01-01 00:00:00Z], ~U[2022-01-02 00:00:00Z])
      :lt

      iex> point_compare(~U[2022-01-02 00:00:00Z], ~U[2022-01-01 00:00:00Z])
      :gt
  """
  defdelegate point_compare(a, b), to: DateTime, as: :compare

  @doc """
      iex> point_step(~U[2022-01-01 00:00:00Z], 1)
      nil
  """
  def point_step(%DateTime{}, _n), do: nil
end
