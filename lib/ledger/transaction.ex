defmodule Ledger.Transaction do
  def procesar_transacciones(arch_transacciones, monedas) do
    lineas = Ledger.FileHandler.leer_archivo(arch_transacciones)

    if Enum.empty?(lineas) do
      {:error, 0}
    else
      lineas
      |> Enum.reduce_while(%{}, fn linea, cuentas ->
        tipo = Enum.at(linea, 7)

        case valor_transaccion(tipo, cuentas, linea, monedas) do
          {:ok, cuentas_actualizadas} ->
            {:cont, cuentas_actualizadas}

          {:error, nro_linea} ->
            {:halt, {:error, nro_linea}}
        end
      end)
    end
  end

  def listar_transacciones(flags, cuentas) do
    c1 = Map.get(flags, "c1", "")
    c2 = Map.get(flags, "c2", "")
    t = Map.get(flags, "t", "./transacciones.csv")
    o = Map.get(flags, "o", "stdout")

    cond do
      (c1 != "" and not Map.has_key?(cuentas, c1)) or (c2 != "" and not Map.has_key?(cuentas, c2)) ->
        {:error, 0}

      true ->
        Ledger.FileHandler.leer_archivo(t)
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
        |> Enum.each(fn linea -> Ledger.FileHandler.mostrar_linea(linea, o) end)

        {:ok, 0}
    end
  end

  defp validar_transferencia(
         cuentas,
         cuenta_origen,
         cuenta_destino,
         monedas,
         moneda_origen,
         moneda_destino,
         monto
       ) do
    cond do
      not Map.has_key?(cuentas, cuenta_origen) or not Map.has_key?(cuentas, cuenta_destino) ->
        :error

      moneda_origen != moneda_destino ->
        :error

      not Map.has_key?(monedas, moneda_origen) ->
        :error

      not Map.has_key?(cuentas[cuenta_origen], moneda_origen) or
          cuentas[cuenta_origen][moneda_origen] < monto ->
        :error

      monto <= 0.0 ->
        :error

      true ->
        :ok
    end
  end

  defp validar_alta_cuenta(cuentas, cuenta, monedas, moneda, monto) do
    cond do
      Map.has_key?(cuentas, cuenta) ->
        :error

      not Map.has_key?(monedas, moneda) ->
        :error

      monto <= 0.0 ->
        :error

      true ->
        :ok
    end
  end

  defp validar_swap(cuentas, cuenta, monedas, moneda_origen, moneda_destino, monto) do
    cond do
      not Map.has_key?(cuentas, cuenta) ->
        :error

      not Map.has_key?(monedas, moneda_origen) or not Map.has_key?(monedas, moneda_destino) ->
        :error

      not Map.has_key?(cuentas[cuenta], moneda_origen) or cuentas[cuenta][moneda_origen] < monto ->
        :error

      monto <= 0.0 ->
        :error

      true ->
        :ok
    end
  end

  def valor_transaccion("transferencia", cuentas, linea, monedas) do
    nro_linea = Enum.at(linea, 0)
    moneda_origen = Enum.at(linea, 2)
    moneda_destino = Enum.at(linea, 3)
    monto = Ledger.Currency.parsear_monto(Enum.at(linea, 4))
    cuenta_origen = Enum.at(linea, 5)
    cuenta_destino = Enum.at(linea, 6)

    case validar_transferencia(
           cuentas,
           cuenta_origen,
           cuenta_destino,
           monedas,
           moneda_origen,
           moneda_destino,
           monto
         ) do
      :error ->
        {:error, nro_linea}

      :ok ->
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
  end

  def valor_transaccion("alta_cuenta", cuentas, linea, monedas) do
    nro_linea = Enum.at(linea, 0)
    moneda = Enum.at(linea, 2)
    monto = Ledger.Currency.parsear_monto(Enum.at(linea, 4))
    cuenta = Enum.at(linea, 5)

    case validar_alta_cuenta(cuentas, cuenta, monedas, moneda, monto) do
      :error ->
        {:error, nro_linea}

      :ok ->
        valor_cuenta = %{moneda => monto}
        {:ok, Map.put(cuentas, cuenta, valor_cuenta)}
    end
  end

  def valor_transaccion("swap", cuentas, linea, monedas) do
    nro_linea = Enum.at(linea, 0)
    moneda_origen = Enum.at(linea, 2)
    moneda_destino = Enum.at(linea, 3)
    monto = Ledger.Currency.parsear_monto(Enum.at(linea, 4))
    cuenta = Enum.at(linea, 5)

    case validar_swap(cuentas, cuenta, monedas, moneda_origen, moneda_destino, monto) do
      :error ->
        {:error, nro_linea}

      :ok ->
        monto_convertido =
          Ledger.Currency.cambiar_a_moneda(monto, moneda_origen, moneda_destino, monedas)

        # cuentas_actualizadas =
        #   Map.update(cuentas, cuenta, %{}, fn mapa_cuenta ->
        #     mapa_cuenta
        #     |> Map.update(moneda_origen, 0.0, fn monto_actual ->
        #       monto_actual - monto
        #     end)
        #     |> Map.update(moneda_destino, 0.0, fn monto_actual ->
        #       monto_actual + cambiar_a_moneda(monto, moneda_origen, moneda_destino, monedas)
        #     end)
        #   end)

        # restamos de la moneda origen
        cuentas_actualizadas =
          Map.update!(cuentas, cuenta, fn mapa ->
            mapa_actualizado = Map.update!(mapa, moneda_origen, &(&1 - monto))

            Map.update(
              mapa_actualizado,
              moneda_destino,
              monto_convertido,
              &(&1 + monto_convertido)
            )
          end)

        {:ok, cuentas_actualizadas}
    end
  end

  def valor_transaccion(_tipo, _cuentas, linea, _monedas) do
    nro_linea = Enum.at(linea, 0)
    {:error, nro_linea}
  end
end
