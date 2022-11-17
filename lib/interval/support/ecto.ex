if Code.ensure_loaded?(Ecto.Type) do
  defmodule Interval.Support.Ecto do
    @moduledoc """
    Implements support for auto-implementing Ecto.Type.

    ## Example

        use Interval.Support.Ecto, ecto_type: :numrange
    """

    defmacro __using__(opts) do
      quote location: :keep, bind_quoted: [ecto_type: Keyword.get(opts, :ecto_type)] do
        # If Ecto.Type and Postgrex.Range is loaded, we can implement support
        # for using this Interval as an Ecto.Type
        if not is_nil(ecto_type) and
             Code.ensure_loaded?(Ecto.Type) and
             Code.ensure_loaded?(Interval.Support.Postgrex) do
          use Ecto.Type
          alias Interval.Support
          alias Postgrex.Range

          @doc false
          def type(), do: unquote(ecto_type)

          @doc false
          def cast(nil), do: {:ok, nil}
          def cast(%Range{} = r), do: load(r)
          def cast(%__MODULE__{} = i), do: {:ok, i}
          def cast(_), do: :error

          @doc false
          def load(nil), do: {:ok, nil}
          def load(%Range{} = r), do: {:ok, Support.Postgrex.from_range(r, __MODULE__)}
          def load(_), do: :error

          @doc false
          def dump(nil), do: {:ok, nil}
          def dump(%__MODULE__{} = i), do: {:ok, Support.Postgrex.to_range(i, __MODULE__)}
          def dump(_), do: :error
        end
      end
    end
  end
end
