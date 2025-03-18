defmodule Interval.Support.Jason do
  @moduledoc """
  Automatically generate Jason.Encoder for intervals

  ## Example

      use Interval.Support.Jason
  """

  @supported? Code.ensure_loaded?(Jason)

  @doc """
  Returns true if Interval was compiled with support for `Jason`
  """
  @spec supported?() :: unquote(@supported?)
  def supported?(), do: @supported?

  if @supported? do
    defmacro __using__(_opts) do
      quote do
        defimpl Jason.Encoder do
          def encode(value, opts) do
            Jason.Encode.string(Interval.format(value), opts)
          end
        end
      end
    end
  end
end
