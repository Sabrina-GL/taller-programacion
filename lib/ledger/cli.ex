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
    "asd"
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
  def efectuar_comando(flags, cuentas, monedas) do
    comando = flags["comando"]
    efectuar_comando(comando, flags, cuentas, monedas)
  end

  defp efectuar_comando("transacciones", flags, cuentas, _monedas) do
    Ledger.Transaction.listar_transacciones(flags, cuentas)
  end

  defp efectuar_comando("balance", flags, cuentas, monedas) do
    Ledger.Balance.listar_balance(flags, cuentas, monedas)
  end

  defp efectuar_comando("crear_usuario", flags, _cuentas, _monedas) do
    Ledger.Usuario.crear_usuario(
      "crear_usuario",
      Map.get(flags, "n", ""),
      Map.get(flags, "b", "")
    )
  end

  defp efectuar_comando(comando = "editar_usuario", flags, _cuentas, _monedas) do
    Ledger.Usuario.editar_usuario(
      comando,
      Map.get(flags, "id", ""),
      Map.get(flags, "n", "")
    )
  end

  defp efectuar_comando(comando = "borrar_usuario", flags, _cuentas, _monedas) do
    Ledger.Usuario.borrar_usuario(comando, Map.get(flags, "id", ""))
  end

  defp efectuar_comando(comando = "ver_usuario", flags, _cuentas, _monedas) do
    Ledger.Usuario.ver_usuario(comando, Map.get(flags, "id", ""))
  end

  defp efectuar_comando(comando = "crear_moneda", flags, _cuentas, _monedas) do
    Ledger.Moneda.crear_moneda(
      comando,
      Map.get(flags, "n", ""),
      Map.get(flags, "p", "")
    )
  end

  defp efectuar_comando(comando = "editar_moneda", flags, _cuentas, _monedas) do
    Ledger.Moneda.editar_moneda(
      comando,
      Map.get(flags, "id", ""),
      Map.get(flags, "p", "")
    )
  end

  defp efectuar_comando(comando = "borrar_moneda", flags, _cuentas, _monedas) do
    Ledger.Moneda.borrar_moneda(comando, Map.get(flags, "id", ""))
  end

  defp efectuar_comando(comando = "ver_moneda", flags, _cuentas, _monedas) do
    Ledger.Moneda.ver_moneda(comando, Map.get(flags, "id", ""))
  end

  defp efectuar_comando(comando = "alta_cuenta", flags, _cuentas, _monedas) do
    usuario_id = Map.get(flags, "u", "")
    moneda_id = Map.get(flags, "m", "")
    monto = Map.get(flags, "a", "")

    Ledger.Transaccion.alta_cuenta(comando, usuario_id, moneda_id, monto)
  end

  # defp efectuar_comando(_comando, _flags, _cuentas, _monedas) do
  #   {:error, "El comando no es válido"}
  # end
end
