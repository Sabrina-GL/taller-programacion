defmodule Ledger do
  @moduledoc """
  Documentation for `LG`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Ledger.hello()
      :world

  """
  def hello do
    :world
  end

  def main(args \\ System.argv()) do
    case Ledger.CLI.procesar_argumentos(args) do
      {:error, nro_linea} ->
        {:error, nro_linea}

      {:ok, flags} ->
        case Ledger.Currency.procesar_monedas() do
          {:error, nro_linea} ->
            {:error, nro_linea}

          monedas ->
            arch_transacciones = Map.get(flags, "t", "./transacciones.csv")

            case Ledger.Transaction.procesar_transacciones(arch_transacciones, monedas) do
              {:error, nro_linea} -> {:error, nro_linea}
              cuentas -> Ledger.CLI.efectuar_comando(flags, cuentas, monedas)
            end
        end
    end
  end
end
