defmodule Ledger.CLI do
  @moduledoc """
  Módulo para manejar la interfaz de línea de comandos del sistema Ledger.
  Proporciona funciones para procesar argumentos y ejecutar comandos específicos.
  """

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
          comando in [
            "transacciones",
            "balance",
            "crear_usuario",
            "ver_usuario",
            "borrar_usuario",
            "editar_usuario"
          ] ->
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

    case comando do
      "transacciones" ->
        Ledger.Transaction.listar_transacciones(flags, cuentas)

      "balance" ->
        Ledger.Balance.listar_balance(flags, cuentas, monedas)

      "crear_usuario" ->
        Ledger.Usuario.crear_usuario(
          comando,
          Map.get(flags, "n", ""),
          Map.get(flags, "b", "")
        )

      "ver_usuario" ->
        Ledger.Usuario.ver_usuario(comando, Map.get(flags, "id", ""))

      "borrar_usuario" ->
        Ledger.Usuario.borrar_usuario(comando, Map.get(flags, "id", ""))

      "editar_usuario" ->
        Ledger.Usuario.editar_usuario(
          comando,
          Map.get(flags, "id", ""),
          Map.get(flags, "n", "")
        )

      _ ->
        {:error, "El comando no es válido"}
    end
  end
end
