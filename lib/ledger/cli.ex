defmodule Ledger.CLI do
  def procesar_argumentos(args) do
    cond do
      length(args) < 1 ->
        {:error, "No se proporcionó ningún comando"}

      true ->
        [comando | args] = args

        cond do
          comando in ["transacciones", "balance"] ->
            flags =
              Enum.reduce(args, %{}, fn arg, acc ->
                case String.split(arg, "=") do
                  [flag, contenido] ->
                    Map.put(acc, String.trim(flag, "-"), contenido)

                  _ ->
                    acc
                end
              end)

            {:ok, Map.put(flags, "comando", comando)}

          true ->
            {:error, "El comando no es válido"}
        end
    end
  end

  def efectuar_comando(flags, cuentas, monedas) do
    case flags["comando"] do
      "transacciones" ->
        Ledger.Transaction.listar_transacciones(flags, cuentas)

      "balance" ->
        Ledger.Balance.listar_balance(flags, cuentas, monedas)

      _ ->
        {:error, "El comando no es válido"}
    end
  end
end
