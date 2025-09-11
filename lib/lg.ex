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

      "balance" ->
        listar_balance(flags)

      # PRINt comando invalido
      _ ->
        nil
    end
  end

  defp listar_transacciones(flags) do
    c1 = Map.get(flags, "c1", "")
    c2 = Map.get(flags, "c2", "")
    t = Map.get(flags, "t", "./transacciones.csv")
    o = Map.get(flags, "o", "stdout")

    leer_archivo(t)
    |> Enum.filter(fn linea ->
      cuenta_origen = Enum.at(linea, 5)
      cuenta_destino = Enum.at(linea, 6)

      case {c1, c2} do
        {"", ""} -> true
        {co, cd} when co == cuenta_origen and cd == cuenta_destino -> true
        {co, ""} when co == cuenta_origen -> true
        {"", cd} when cd == cuenta_destino -> true
        _ -> false
      end
    end)
    |> Enum.each(fn linea -> mostrar_linea(linea, o) end)
  end

  defp listar_balance(flags) do
    # si no hay c1 error
    c1 = Map.get(flags, "c1", "")
    m = Map.get(flags, "m", "")
    t = Map.get(flags, "t", "./transacciones.csv")
    o = Map.get(flags, "o", "stdout")
    balance = %{}

    monedas =
      leer_archivo("./monedas.csv")
      |> Enum.reduce(%{}, fn linea, acc ->
        Map.put(acc, Enum.at(linea, 0), parsear_monto(Enum.at(linea, 1)))
      end)

    resultado =
      leer_archivo(t)
      |> Enum.reduce(%{}, fn linea, acc ->
        tipo = Enum.at(linea, 7)

        nuevo_acc =
          Map.merge(acc, valor_transaccion(tipo, linea, c1, monedas), fn _k, v1, v2 ->
            v1 + v2
          end)

        IO.inspect(nuevo_acc)
        nuevo_acc
      end)

    mostrar_balance(m, resultado, monedas, o)
  end

  defp parsear_monto(monto) do
    case Float.parse(monto) do
      {valor, _resto} -> valor
      :error -> 0.0
    end
  end

  defp cambiar_a_moneda(monto, moneda_origen, moneda_destino, monedas) do
    monto * Map.get(monedas, moneda_destino) / Map.get(monedas, moneda_origen)
  end

  defp valor_transaccion("transferencia", linea, cuenta, _monedas) do
    moneda_origen = Enum.at(linea, 2)
    moneda_destino = Enum.at(linea, 3)
    monto = parsear_monto(Enum.at(linea, 4))
    cuenta_origen = Enum.at(linea, 5)
    cuenta_destino = Enum.at(linea, 6)

    # if moneda_orgien != moneda_destino -> error
    # if cualquier moneda not in monedas.csv -> error

    cond do
      cuenta == cuenta_origen -> %{moneda_origen => -monto}
      cuenta == cuenta_destino -> %{moneda_destino => monto}
      true -> %{}
    end

    # |> cambiar_a_moneda(moneda_origen, moneda, monedas)
  end

  defp valor_transaccion("alta_cuenta", linea, cuenta, _monedas) do
    moneda = Enum.at(linea, 2)
    monto = parsear_monto(Enum.at(linea, 4))
    cuenta_origen = Enum.at(linea, 5)

    cond do
      cuenta == cuenta_origen -> %{moneda => monto}
      true -> %{}
    end
  end

  defp valor_transaccion("swap", linea, cuenta, monedas) do
    moneda_origen = Enum.at(linea, 2)
    moneda_destino = Enum.at(linea, 3)
    monto = parsear_monto(Enum.at(linea, 4))
    cuenta_origen = Enum.at(linea, 5)

    cond do
      cuenta == cuenta_origen ->
        %{
          moneda_origen => -monto,
          moneda_destino => cambiar_a_moneda(monto, moneda_origen, moneda_destino, monedas)
        }

      true ->
        %{}
    end
  end

  defp valor_transaccion(tipo, linea, _cuenta, _monedas) do
    %{}
  end

  defp leer_archivo(archivo) do
    File.read!(archivo)
    |> String.split("\n")
    |> Enum.map(fn linea -> String.split(linea, ";") end)
  end

  defp mostrar_linea(linea, archivo) do
    cond do
      archivo == "stdout" -> IO.puts(linea)
      true -> File.write!(archivo, Enum.join(linea, ";") <> "\n", [:append])
    end
  end

  defp mostrar_linea_balance(moneda, monto, archivo) do
    cond do
      archivo == "stdout" -> IO.puts("#{moneda}=#{monto}")
      true -> File.write!(archivo, "#{moneda}=#{monto}" <> "\n", [:append])
    end
  end

  defp mostrar_balance(moneda \\ "", montos, monedas, archivo) do
    if moneda != "" do
      total =
        Enum.reduce(montos, 0.0, fn {moneda_actual, monto}, acc2 ->
          acc2 + cambiar_a_moneda(monto, moneda_actual, moneda, monedas)
        end)

      mostrar_linea_balance(moneda, total, archivo)
    else
      Enum.each(montos, fn {moneda_actual, monto} ->
        mostrar_linea_balance(moneda_actual, monto, archivo)
      end)
    end
  end
end
