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
      {:error, razon} ->
        Ledger.FileHandler.mostrar_error(razon)
        {:error, razon}

      {:ok, flags} ->
        case Ledger.Currency.procesar_monedas() do
          {:error, razon} ->
            Ledger.FileHandler.mostrar_error(razon)
            {:error, razon}

          monedas ->
            arch_transacciones = Map.get(flags, "t", "./transacciones.csv")

            case Ledger.Transaction.procesar_transacciones(arch_transacciones, monedas) do
              {:error, razon} ->
                Ledger.FileHandler.mostrar_error(razon)
                {:error, razon}

              cuentas ->
                case Ledger.CLI.efectuar_comando(flags, cuentas, monedas) do
                  {:error, razon} ->
                    Ledger.FileHandler.mostrar_error(razon)
                    {:error, razon}

                  resultado ->
                    resultado
                end
            end
        end
    end
  end
end
