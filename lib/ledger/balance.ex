defmodule Ledger.Balance do
  def listar_balance(flags, cuentas, monedas) do
    c1 = Map.get(flags, "c1", "")
    m = Map.get(flags, "m", "")
    o = Map.get(flags, "o", "stdout")

    cond do
      c1 == "" or not Map.has_key?(cuentas, c1) ->
        {:error, "La cuenta no existe"}

      m != "" and not Map.has_key?(monedas, m) ->
        {:error, "La moneda no existe"}

      true ->
        balance_cuenta = Map.get(cuentas, c1, %{})
        Ledger.FileHandler.mostrar_balance(m, balance_cuenta, monedas, o)

        {:ok, 0}
    end
  end
end
