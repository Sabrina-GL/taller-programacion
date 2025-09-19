defmodule Ledger.Currency do
  @moduledoc """
  Módulo para gestionar las monedas y sus tasas de cambio en el sistema Ledger.
  Proporciona funciones para leer y procesar las tasas de cambio desde un archivo CSV.
  """

  @doc """
  Parsea un monto desde una cadena a un número flotante.

  ## Parámetros
  - `monto`: Cadena que representa el monto a parsear.
  ## Retorno
  - Monto como número flotante. Si el parseo falla, retorna 0.
  """
  def parsear_monto(monto) do
    case Float.parse(monto) do
      {valor, _resto} -> valor
      :error -> 0.0
    end
  end

  @doc """
  Convierte un monto de una moneda a otra usando las tasas de cambio proporcionadas.

  ## Parámetros
  - `monto`: Monto a convertir.
  - `moneda_origen`: Moneda original del monto.
  - `moneda_destino`: Moneda a la cual se convertirá el monto.
  - `monedas`: Mapa de tasas de cambio entre monedas.
  ## Retorno
  - Monto convertido a la moneda destino.
  """
  def cambiar_a_moneda(monto, moneda_origen, moneda_destino, monedas) do
    monto * Map.get(monedas, moneda_origen) / Map.get(monedas, moneda_destino)
  end

  @doc """
  Procesa un archivo CSV de monedas y sus tasas de cambio, devolviendo un mapa de monedas.

  ## Parámetros
  - `archivo`: Ruta del archivo CSV que contiene las monedas y sus tasas de cambio.
  ## Retorno
  - `{:ok, monedas}` si la lectura y procesamiento fue exitoso, donde `monedas` es un mapa de tasas de cambio.
  - `{:error, razón}` si ocurrió un error al leer o procesar el archivo.
  """
  def procesar_monedas(archivo) do
    case Ledger.FileHandler.leer_archivo(archivo) do
      {:error, razon} ->
        {:error, razon}

      [] ->
        {:error, "Archivo de monedas vacío"}

      lineas ->
        monedas =
          lineas
          |> Enum.reduce(%{}, fn linea, acc ->
            Map.put(acc, Enum.at(linea, 0), parsear_monto(Enum.at(linea, 1)))
          end)

        {:ok, monedas}
    end
  end
end
