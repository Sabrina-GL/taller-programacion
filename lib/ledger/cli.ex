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
    efectuar_comando(comando, flags)
  end

  defp efectuar_comando(comando = "transacciones", flags) do
    Ledger.Transaccion.listar_transacciones(comando, flags)
  end

  defp efectuar_comando(comando = "balance", flags) do
    c1 = parsear_flag(flags, "c1")
    m = parsear_flag(flags, "m")
    o = Map.get(flags, "o", "stdout")
    Ledger.Transaccion.listar_balance(comando, c1, m, o)
  end

  defp efectuar_comando("crear_usuario", flags) do
    Ledger.Usuario.crear_usuario(
      "crear_usuario",
      Map.get(flags, "n", ""),
      Map.get(flags, "b", "")
    )
  end

  defp efectuar_comando(comando = "editar_usuario", flags) do
    Ledger.Usuario.editar_usuario(
      comando,
      Map.get(flags, "id", ""),
      Map.get(flags, "n", "")
    )
  end

  defp efectuar_comando(comando = "borrar_usuario", flags) do
    Ledger.Usuario.borrar_usuario(comando, Map.get(flags, "id", ""))
  end

  defp efectuar_comando(comando = "ver_usuario", flags) do
    Ledger.Usuario.ver_usuario(comando, Map.get(flags, "id", ""))
  end

  defp efectuar_comando(comando = "crear_moneda", flags) do
    Ledger.Moneda.crear_moneda(
      comando,
      Map.get(flags, "n", ""),
      Map.get(flags, "p", "")
    )
  end

  defp efectuar_comando(comando = "editar_moneda", flags) do
    Ledger.Moneda.editar_moneda(
      comando,
      Map.get(flags, "id", ""),
      Map.get(flags, "p", "")
    )
  end

  defp efectuar_comando(comando = "borrar_moneda", flags) do
    Ledger.Moneda.borrar_moneda(comando, Map.get(flags, "id", ""))
  end

  defp efectuar_comando(comando = "ver_moneda", flags) do
    Ledger.Moneda.ver_moneda(comando, Map.get(flags, "id", ""))
  end

  defp efectuar_comando(comando = "alta_cuenta", flags) do
    usuario_id = Map.get(flags, "u", "")
    moneda_id = Map.get(flags, "m", "")
    monto = Map.get(flags, "a", "")

    Ledger.Transaccion.alta_cuenta(comando, usuario_id, moneda_id, monto)
  end

  defp efectuar_comando(comando = "realizar_transferencia", flags) do
    cuenta_origen = parsear_flag(flags, "o")
    cuenta_destino = parsear_flag(flags, "d")
    moneda = parsear_flag(flags, "m")
    monto = parsear_flag(flags, "a")

    Ledger.Transaccion.realizar_transferencia(
      comando,
      cuenta_origen,
      cuenta_destino,
      moneda,
      monto
    )
  end

  defp efectuar_comando(comando = "realizar_swap", flags) do
    cuenta = parsear_flag(flags, "u")
    moneda_origen = parsear_flag(flags, "mo")
    moneda_destino = parsear_flag(flags, "md")
    monto = parsear_flag(flags, "a")

    Ledger.Transaccion.realizar_swap(comando, cuenta, moneda_origen, moneda_destino, monto)
  end

  defp parsear_flag(flags, key, default \\ "") do
    case Map.get(flags, key, default) do
      "" -> default
      value when is_binary(value) -> String.to_integer(value)
      value -> value
    end
  end

  # defp efectuar_comando(_comando, _flags, _cuentas, _monedas) do
  #   {:error, "El comando no es válido"}
  # end
end
