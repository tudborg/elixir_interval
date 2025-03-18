defmodule Interval.Support.EctoType do
  @moduledoc """
  Implements support for auto-implementing Ecto.Type.

  ## Example

      use Interval.Support.EctoType, ecto_type: :numrange
  """

  @supported? Code.ensure_loaded?(Postgrex) and Code.ensure_loaded?(Ecto)

  @doc """
  Returns if Interval was compiled with support for `Ecto.Type`
  """
  @spec supported?() :: unquote(@supported?)
  def supported?(), do: @supported?

  if @supported? do
    defmacro __using__(opts) do
      quote location: :keep,
            bind_quoted: [
              ecto_type: Keyword.fetch!(opts, :ecto_type)
            ] do
        use Ecto.Type
        alias Interval.Support.EctoType

        @doc false
        def type(), do: unquote(ecto_type)

        @doc false
        def cast(nil), do: {:ok, nil}
        def cast(%Postgrex.Range{} = r), do: load(r)
        def cast(%__MODULE__{} = i), do: {:ok, i}
        def cast(_), do: :error

        @doc false
        def load(nil), do: {:ok, nil}
        def load(%Postgrex.Range{} = r), do: {:ok, EctoType.from_postgrex_range(r, __MODULE__)}
        def load(_), do: :error

        @doc false
        def dump(nil), do: {:ok, nil}
        def dump(%__MODULE__{} = i), do: {:ok, EctoType.to_postgrex_range(i, __MODULE__)}
        def dump(_), do: :error

        defoverridable Ecto.Type
      end
    end

    @doc """
    Convert a `Postgrex.Range` to a struct of type `module`
    """
    def from_postgrex_range(%Postgrex.Range{} = range, module) do
      bounds =
        [
          if(range.lower_inclusive, do: "[", else: "("),
          if(range.upper_inclusive, do: "]", else: ")")
        ]
        |> Enum.join()

      module.new(left: from_point(range.lower), right: from_point(range.upper), bounds: bounds)
    end

    @doc """
    Convert an `Interval` struct to a `Postgrex.Range`.
    """
    def to_postgrex_range(interval, module \\ nil)

    def to_postgrex_range(%module{left: left, right: right}, module) do
      {lower, lower_inclusive} = to_point(left)
      {upper, upper_inclusive} = to_point(right)

      %Postgrex.Range{
        lower: lower,
        upper: upper,
        lower_inclusive: lower_inclusive,
        upper_inclusive: upper_inclusive
      }
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
end
