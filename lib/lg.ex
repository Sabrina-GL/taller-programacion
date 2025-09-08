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
    flags = procesar_argumentos(args)
    efectuar_comando(flags)
  end

  defp procesar_argumentos(args) do
    [comando | args] = args

    flags =
      Enum.reduce(args, %{}, fn arg, acc ->
        case String.split(arg, "=") do
          [flag, contenido] ->
            Map.put(acc, String.trim(flag, "-"), contenido)

          _ ->
            acc
        end
      end)

    Map.put(flags, "comando", comando)
  end

  defp efectuar_comando(flags) do
    case flags["comando"] do
      "transacciones" ->
        listar_transacciones(flags)

      # "balance" ->
      # listar_balance(flags)

      # PRINt comando invalido
      _ ->
        nil
    end
  end

  defp listar_transacciones(flags) do
    c1 = Map.get(flags, "c1", "")
    c2 = Map.get(flags, "c2", "")
    # t = Map.get(flags, "t", "./transacciones.csv")
    o = Map.get(flags, "o", "stdout")

    leer_archivo()
    |> Enum.each(fn linea ->
      # id_transaccion = Enum.at(linea, 0)
      # timestamp = Enum.at(linea, 1)
      # moneda_origen = Enum.at(linea, 2)
      # moneda_destino = Enum.at(linea, 3)
      # monto = Enum.at(linea, 4)
      cuenta_origen = Enum.at(linea, 5)
      cuenta_destino = Enum.at(linea, 6)
      # tipo = Enum.at(linea, 7)

      case {c1, c2} do
        {"", ""} -> mostrar_linea(linea, o)
        {^cuenta_origen, ^cuenta_destino} -> mostrar_linea(linea, o)
        {^cuenta_origen, _} -> mostrar_linea(linea, o)
        {_, ^cuenta_destino} -> mostrar_linea(linea, o)
        _ -> mostrar_linea(linea, o)
      end
    end)
  end

  # defp listar_balance(flags) do
  # end

  defp leer_archivo(t \\ "./transacciones.csv") do
    File.read!(t)
    |> String.split("\n")
    |> Enum.map(fn linea -> String.split(linea, ";") end)
  end

  defp mostrar_linea(linea, "stdout") do
    IO.inspect(linea)
  end

  defp mostrar_linea(linea, archivo) do
    File.write!(archivo, Enum.join(linea, ";") <> "\n", [:append])
  end
end
