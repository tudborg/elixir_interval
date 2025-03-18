defmodule Interval.Support.EctoType do
  @moduledoc """
  Implements support for auto-implementing Ecto.Type.

  ## Example

      use Interval.Support.EctoType, ecto_type: :numrange
  """

  @supported? Code.ensure_loaded?(Ecto)

  @doc """
  Returns if Interval was compiled with support for `Ecto.Type`
  """
  @spec supported?() :: unquote(@supported?)
  def supported?(), do: @supported?

  if @supported? do
    defmacro __using__(opts) do
      ecto_type = Keyword.fetch!(opts, :ecto_type)

      quote do
        use Ecto.Type
        alias Interval.Support.EctoType

        @doc false
        def type(), do: unquote(ecto_type)

        @doc false
        def cast(value), do: EctoType.cast(value, __MODULE__)

        @doc false
        def load(value), do: EctoType.load(value, __MODULE__)

        @doc false
        def dump(value), do: EctoType.dump(value, __MODULE__)

        defoverridable Ecto.Type
      end
    end
  end

  @postgrex_range :"Elixir.Postgrex.Range"
  @postgres_range_types [
    :int4range,
    :int8range,
    :numrange,
    :tsrange,
    :tstzrange,
    :daterange
  ]

  ##
  # Cast
  ##
  def cast(nil, _module) do
    {:ok, nil}
  end

  def cast(%module{} = struct, module) do
    {:ok, struct}
  end

  def cast(string, module) when is_binary(string) do
    case Interval.parse(string, module) do
      {:ok, interval} -> {:ok, interval}
      {:error, _reason} -> :error
    end
  end

  def cast(%@postgrex_range{} = range, module) do
    {:ok, from_postgrex_range(range, module)}
  end

  ##
  # Load
  ##
  def load(nil, _module) do
    {:ok, nil}
  end

  def load(%@postgrex_range{} = range, module) do
    {:ok, from_postgrex_range(range, module)}
  end

  def load(string, module) when is_binary(string) do
    cast(string, module)
  end

  ##
  # Dump
  ##
  def dump(nil, _module) do
    {:ok, nil}
  end

  def dump(interval, module) do
    case module.type() do
      type when is_atom(type) and type in @postgres_range_types ->
        {:ok, to_postgrex_range(interval, module)}

      _ ->
        {:ok, Interval.format(interval)}
    end
  end

  def from_postgrex_range(%{__struct__: :"Elixir.Postgrex.Range"} = range, module) do
    bounds =
      [
        if(range.lower_inclusive, do: "[", else: "("),
        if(range.upper_inclusive, do: "]", else: ")")
      ]
      |> Enum.join()

    module.new(left: from_point(range.lower), right: from_point(range.upper), bounds: bounds)
  end

  def to_postgrex_range(interval, module \\ nil)

  def to_postgrex_range(%module{left: left, right: right}, module) do
    {lower, lower_inclusive} = to_point(left)
    {upper, upper_inclusive} = to_point(right)

    struct!(:"Elixir.Postgrex.Range",
      lower: lower,
      upper: upper,
      lower_inclusive: lower_inclusive,
      upper_inclusive: upper_inclusive
    )
  end

  def to_postgrex_range(%module{} = struct, nil) do
    to_postgrex_range(struct, module)
  end

  defp to_point(:unbounded), do: {:unbound, false}
  defp to_point(:empty), do: {:empty, false}
  defp to_point({:inclusive, point}), do: {point, true}
  defp to_point({:exclusive, point}), do: {point, false}

  defp from_point(:unbound), do: nil
  defp from_point(:empty), do: :empty
  defp from_point(point), do: point
end
