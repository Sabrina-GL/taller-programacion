defmodule Ledger.CLI do
  @moduledoc """
  Módulo para manejar la interfaz de línea de comandos del sistema Ledger.
  Proporciona funciones para procesar argumentos y ejecutar comandos específicos.
  """

  @comandos_validos [
    "transacciones",
    "balance",
    "crear_usuario",
    "editar_usuario",
    "borrar_usuario",
    "ver_usuario",
    "crear_moneda",
    "editar_moneda",
    "borrar_moneda",
    "ver_moneda",
    "alta_cuenta",
    "realizar_transferencia",
    "realizar_swap"
  ]

  @doc """
  Procesa los argumentos de la línea de comandos y devuelve un mapa con los flags y el comando.

  ## Parámetros
  - `args`: Lista de argumentos de línea de comandos.
  ## Retorno
  - `{:ok, flags}` si los argumentos son válidos, donde `flags` es un mapa con los flags y el comando.
  - `{:error, razón}` si los argumentos son inválidos.
  """
  def procesar_argumentos(args) do
    cond do
      length(args) < 1 ->
        {:error, "No se proporcionó ningún comando"}

      true ->
        [comando | args] = args

        cond do
          comando in @comandos_validos ->
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
            {:error, "#{comando}: El comando no es válido"}
        end
    end
  end

  @doc """
  Efectúa el comando especificado en los flags utilizando las cuentas y monedas proporcionadas.

  ## Parámetros
  - `flags`: Mapa con los flags y el comando a ejecutar.
  - `cuentas`: Mapa con las cuentas y sus balances.
  - `monedas`: Mapa con las monedas y sus tasas de cambio.
  ## Retorno
  - `{:ok, resultado}` si el comando se ejecutó exitosamente, donde `resultado` es el resultado del comando.
  - `{:error, razón}` si ocurrió algún error al ejecutar el comando.
  """
  def efectuar_comando(flags, _cuentas, _monedas) do
    comando = flags["comando"]

    case efectuar_comando(comando, flags) do
      {:error, razon} -> {:error, "#{comando}: #{razon}"}
      {:ok, resultado} -> {:ok, resultado}
    end
  end

  defp efectuar_comando("transacciones", flags) do
    Ledger.Transaccion.listar_transacciones(flags)
  end

  defp efectuar_comando("balance", flags) do
    c1 = parsear_flag(flags, "c1")
    m = parsear_flag(flags, "m")
    o = Map.get(flags, "o", "stdout")
    Ledger.Transaccion.listar_balance(c1, m, o)
  end

  defp efectuar_comando("crear_usuario", flags) do
    Ledger.Usuario.crear_usuario(
      Map.get(flags, "n", ""),
      Map.get(flags, "b", "")
    )
  end

  defp efectuar_comando("editar_usuario", flags) do
    Ledger.Usuario.editar_usuario(
      Map.get(flags, "id", ""),
      Map.get(flags, "n", "")
    )

    # case parsear_flag(flags, "id", "") do
    #   {:error, razon} ->
    #     {:error, razon}

    #   {:ok, id} ->
    #     Ledger.Usuario.editar_usuario(
    #       id,
    #       Map.get(flags, "n", "")
    #     )
    # end
  end

  defp efectuar_comando("borrar_usuario", flags) do
    Ledger.Usuario.borrar_usuario(Map.get(flags, "id", ""))
  end

  defp efectuar_comando("ver_usuario", flags) do
    Ledger.Usuario.ver_usuario(Map.get(flags, "id", ""))
  end

  defp efectuar_comando("crear_moneda", flags) do
    Ledger.Moneda.crear_moneda(
      Map.get(flags, "n", ""),
      Map.get(flags, "p", "")
    )
  end

  defp efectuar_comando("editar_moneda", flags) do
    Ledger.Moneda.editar_moneda(
      Map.get(flags, "id", ""),
      Map.get(flags, "p", "")
    )
  end

  defp efectuar_comando("borrar_moneda", flags) do
    Ledger.Moneda.borrar_moneda(Map.get(flags, "id", ""))
  end

  defp efectuar_comando("ver_moneda", flags) do
    Ledger.Moneda.ver_moneda(Map.get(flags, "id", ""))
  end

  defp efectuar_comando("alta_cuenta", flags) do
    usuario_id = Map.get(flags, "u", "")
    moneda_id = Map.get(flags, "m", "")
    monto = Map.get(flags, "a", "")

    Ledger.Transaccion.alta_cuenta(usuario_id, moneda_id, monto)
  end

  defp efectuar_comando("realizar_transferencia", flags) do
    cuenta_origen = parsear_flag(flags, "o")
    cuenta_destino = parsear_flag(flags, "d")
    moneda = parsear_flag(flags, "m")
    monto = parsear_flag(flags, "a")

    Ledger.Transaccion.realizar_transferencia(
      cuenta_origen,
      cuenta_destino,
      moneda,
      monto
    )
  end

  defp efectuar_comando("realizar_swap", flags) do
    cuenta = parsear_flag(flags, "u")
    moneda_origen = parsear_flag(flags, "mo")
    moneda_destino = parsear_flag(flags, "md")
    monto = parsear_flag(flags, "a")

    Ledger.Transaccion.realizar_swap(cuenta, moneda_origen, moneda_destino, monto)
  end

  defp parsear_flag(flags, key, default \\ "") do
    case Map.get(flags, key, default) do
      "" ->
        {:ok, default}

      value when is_binary(value) ->
        case Integer.parse(value) do
          {num, ""} ->
            {:ok, num}

          {_num, rest} ->
            # "123abc" → error
            {:error, "#{key} contiene caracteres no numéricos: '#{rest}'"}

          :error ->
            {:error, "#{key} debe ser un número válido"}
        end

      value ->
        {:ok, value}
    end
  end

  def parsear_id(id) do
    case Integer.parse(id) do
      {id_int, ""} ->
        {:ok, id_int}

      _ ->
        {:error, "ID inválido, debe ser un número"}
    end
  end

  # defp efectuar_comando(_comando, _flags, _cuentas, _monedas) do
  #   {:error, "El comando no es válido"}
  # end
end
