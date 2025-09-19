defmodule Ledger.Balance do
  @moduledoc """
  Módulo para gestionar y listar balances de cuentas en el sistema Ledger.
  Proporciona funciones para listar el balance de una cuenta específica, con soporte para conversiónes de moneda.
  """

  @doc """
  Lista el balance de una cuenta específica, con opciones para conversión de moneda y salida a archivo o stdout.

  ## Parámetros
  - `flags`: Mapa de opciones que incluye:
    - `"c1"`: Cuenta a consultar (obligatorio).
    - `"m"`: Moneda a la cual convertir el balance (opcional).
    - `"o"`: Archivo de salida o "stdout" para salida estándar (opcional, por defecto "stdout").
  - `cuentas`: Mapa de cuentas con sus balances.
  - `monedas`: Mapa de tasas de cambio entre monedas.
  ## Retorno
  - `{:ok, 0}` si la operación fue exitosa.
  - `{:error, razón}` si ocurrió algún error, como cuenta o moneda inexistente.
  """
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
