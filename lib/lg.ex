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
    monedas = procesar_monedas()
    arch_transacciones = Map.get(flags, "t", "./transacciones.csv")

    case procesar_transacciones(arch_transacciones, monedas) do
      {:error, nro_linea} -> {:error, nro_linea}
      cuentas -> efectuar_comando(flags, cuentas, monedas)
    end
  end

  defp procesar_monedas() do
    leer_archivo("./monedas.csv")
    |> Enum.reduce(%{}, fn linea, acc ->
      Map.put(acc, Enum.at(linea, 0), parsear_monto(Enum.at(linea, 1)))
    end)
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

  defp efectuar_comando(flags, cuentas, monedas) do
    case flags["comando"] do
      "transacciones" ->
        listar_transacciones(flags, cuentas)

      "balance" ->
        listar_balance(flags, cuentas, monedas)

      _ ->
        {:error, 0}
    end
  end

  defp procesar_transacciones(arch_transacciones, monedas) do
    leer_archivo(arch_transacciones)
    |> Enum.reduce_while(%{}, fn linea, cuentas ->
      nro = Enum.at(linea, 0)
      tipo = Enum.at(linea, 7)

      case valor_transaccion(tipo, cuentas, linea, nro, monedas) do
        {:ok, cuentas_actualizadas} ->
          {:cont, cuentas_actualizadas}

        {:error, nro_linea} ->
          IO.inspect({:error, nro_linea})
          {:halt, {:error, nro_linea}}
      end
    end)
  end

  defp listar_transacciones(flags, cuentas) do
    c1 = Map.get(flags, "c1", "")
    c2 = Map.get(flags, "c2", "")
    t = Map.get(flags, "t", "./transacciones.csv")
    o = Map.get(flags, "o", "stdout")

    cond do
      not Map.has_key?(cuentas, c1) or not Map.has_key?(cuentas, c2) ->
        {:error, 0}

      true ->
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

        {:ok, 0}
    end
  end

  defp listar_balance(flags, cuentas, monedas) do
    c1 = Map.get(flags, "c1", "")
    m = Map.get(flags, "m", "")
    o = Map.get(flags, "o", "stdout")

    cond do
      c1 == "" or not Map.has_key?(cuentas, c1) ->
        {:error, 0}

      m != "" and not Map.has_key?(monedas, m) ->
        {:error, 0}

      true ->
        balance_cuenta = Map.get(cuentas, c1, %{})
        mostrar_balance(m, balance_cuenta, monedas, o)

        {:ok, 0}
    end
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

  defp valor_transaccion("transferencia", cuentas, linea, nro_linea, monedas) do
    moneda_origen = Enum.at(linea, 2)
    moneda_destino = Enum.at(linea, 3)
    monto = parsear_monto(Enum.at(linea, 4))
    cuenta_origen = Enum.at(linea, 5)
    cuenta_destino = Enum.at(linea, 6)

    cond do
      not Map.has_key?(cuentas, cuenta_origen) or not Map.has_key?(cuentas, cuenta_destino) ->
        {:error, nro_linea}

      moneda_origen != moneda_destino ->
        {:error, nro_linea}

      not Map.has_key?(monedas, moneda_origen) ->
        {:error, nro_linea}

      not Map.has_key?(cuentas[cuenta_origen], moneda_origen) or
          cuentas[cuenta_origen][moneda_origen] < monto ->
        {:error, nro_linea}

      monto <= 0.0 ->
        {:error, nro_linea}

      true ->
        cuentas_actualizadas =
          Map.update(cuentas, cuenta_origen, %{}, fn mapa_cuenta ->
            Map.update(mapa_cuenta, moneda_origen, 0.0, fn monto_actual ->
              monto_actual - monto
            end)
          end)

        cuentas_actualizadas =
          Map.update(cuentas_actualizadas, cuenta_destino, %{}, fn mapa_cuenta ->
            Map.update(mapa_cuenta, moneda_destino, 0.0, fn monto_actual ->
              monto_actual + monto
            end)
          end)

        {:ok, cuentas_actualizadas}
    end

    # |> cambiar_a_moneda(moneda_origen, moneda, monedas)
  end

  defp valor_transaccion("alta_cuenta", cuentas, linea, nro_linea, _monedas) do
    moneda = Enum.at(linea, 2)
    monto = parsear_monto(Enum.at(linea, 4))
    cuenta = Enum.at(linea, 5)

    cond do
      Map.has_key?(cuentas, cuenta) ->
        {:error, nro_linea}

      true ->
        valor_cuenta = %{moneda => monto}
        {:ok, Map.put(cuentas, cuenta, valor_cuenta)}
    end
  end

  defp valor_transaccion("swap", cuentas, linea, nro_linea, monedas) do
    moneda_origen = Enum.at(linea, 2)
    moneda_destino = Enum.at(linea, 3)
    monto = parsear_monto(Enum.at(linea, 4))
    cuenta = Enum.at(linea, 5)

    cond do
      not Map.has_key?(cuentas, cuenta) ->
        {:error, nro_linea}

      not Map.has_key?(monedas, moneda_origen) or not Map.has_key?(monedas, moneda_destino) ->
        {:error, nro_linea}

      not Map.has_key?(cuentas[cuenta], moneda_origen) or cuentas[cuenta][moneda_origen] < monto ->
        {:error, nro_linea}

      monto <= 0.0 ->
        {:error, nro_linea}

      true ->
        cuentas_actualizadas =
          Map.update(cuentas, cuenta, %{}, fn mapa_cuenta ->
            Map.update(mapa_cuenta, moneda_origen, 0.0, fn monto_actual ->
              monto_actual - monto
            end)
          end)

        cuentas_actualizadas =
          Map.update(cuentas_actualizadas, cuenta, %{}, fn mapa_cuenta ->
            Map.update(mapa_cuenta, moneda_destino, 0.0, fn monto_actual ->
              monto_actual + cambiar_a_moneda(monto, moneda_origen, moneda_destino, monedas)
            end)
          end)

        {:ok, cuentas_actualizadas}
    end
  end

  defp valor_transaccion(_tipo, _cuentas, _linea, nro_linea, _monedas) do
    {:error, nro_linea}
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
    monto_decimales = :io_lib.format("~.6f", [monto]) |> to_string()

    cond do
      archivo == "stdout" -> IO.puts("#{moneda}=#{monto_decimales}")
      true -> File.write!(archivo, "#{moneda}=#{monto_decimales}\n", [:append])
    end
  end

  defp mostrar_balance(moneda, montos, monedas, archivo) do
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
