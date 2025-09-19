defmodule Ledger.FileHandler do
  def leer_archivo(archivo) do
    case File.read(archivo) do
      {:ok, contenido} ->
        contenido
        |> String.split("\n")
        |> Enum.map(fn linea -> String.split(linea, ";") end)
        |> Enum.filter(fn
          [""] -> false
          [] -> false
          _linea -> true
        end)

      {:error, _razon} ->
        []
    end
  end

  def mostrar_linea(linea, archivo) do
    linea_str = Enum.join(linea, ";")

    cond do
      archivo == "stdout" -> IO.puts(linea_str)
      true -> File.write!(archivo, linea_str <> "\n", [:append])
    end
  end

  def mostrar_balance(moneda, montos, monedas, archivo) do
    if moneda != "" do
      total =
        Enum.reduce(montos, 0.0, fn {moneda_actual, monto}, acc2 ->
          acc2 + Ledger.Currency.cambiar_a_moneda(monto, moneda_actual, moneda, monedas)
        end)

      mostrar_linea_balance(moneda, total, archivo)
    else
      Enum.each(montos, fn {moneda_actual, monto} ->
        mostrar_linea_balance(moneda_actual, monto, archivo)
      end)
    end
  end

  defp mostrar_linea_balance(moneda, monto, archivo) do
    monto_decimales = :io_lib.format("~.6f", [monto]) |> to_string()
    monto_str = "#{moneda}=#{monto_decimales}"

    cond do
      archivo == "stdout" -> IO.puts(monto_str)
      true -> File.write!(archivo, monto_str <> "\n", [:append])
    end
  end

  def mostrar_error(razon) do
    IO.puts("{:error, " <> razon <> "}")
  end
end
