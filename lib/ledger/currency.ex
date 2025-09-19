defmodule Ledger.Currency do
  def parsear_monto(monto) do
    case Float.parse(monto) do
      {valor, _resto} -> valor
      :error -> 0.0
    end
  end

  def cambiar_a_moneda(monto, moneda_origen, moneda_destino, monedas) do
    monto * Map.get(monedas, moneda_origen) / Map.get(monedas, moneda_destino)
  end

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
