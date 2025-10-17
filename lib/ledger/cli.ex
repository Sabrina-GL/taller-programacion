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
    "realizar_swap",
    "ver_transaccion",
    "deshacer_transaccion"
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
  Efectúa el comando especificado en flags["comando"] con sus respectivos parámetros.
  """
  def efectuar_comando(flags) do
    comando = flags["comando"]

    case efectuar_comando(comando, flags) do
      {:error, razon} -> {:error, "#{comando}: #{razon}"}
      {:ok, resultado} -> {:ok, resultado}
    end
  end

  defp efectuar_comando("transacciones", flags) do
    flag_c1 = Map.get(flags, "c1", "")
    flag_c2 = Map.get(flags, "c2", "")

    with {:ok, c1} <- if(flag_c1 != "", do: parsear_id(flags, "c1"), else: {:ok, ""}),
         {:ok, c2} <- if(flag_c2 != "", do: parsear_id(flags, "c2"), else: {:ok, ""}) do
      Ledger.Transaccion.listar_transacciones(c1, c2, Map.get(flags, "out", "stdout"))
    end
  end

  defp efectuar_comando("balance", flags) do
    with {:ok, c1} <- parsear_id(flags, "c1") do
      m = Map.get(flags, "m", "")

      if m != "" do
        parsear_id(flags, "m")
      end

      o = Map.get(flags, "out", "stdout")
      Ledger.Transaccion.listar_balance(c1, m, o)
    end
  end

  defp efectuar_comando("crear_usuario", flags) do
    Ledger.Usuario.crear_usuario(
      Map.get(flags, "n", ""),
      Map.get(flags, "b", "")
    )
  end

  defp efectuar_comando("editar_usuario", flags) do
    with {:ok, id} <- parsear_id(flags, "id") do
      Ledger.Usuario.editar_usuario(
        id,
        Map.get(flags, "n", "")
      )
    end
  end

  defp efectuar_comando("borrar_usuario", flags) do
    with {:ok, id} <- parsear_id(flags, "id") do
      Ledger.Usuario.borrar_usuario(id)
    end
  end

  defp efectuar_comando("ver_usuario", flags) do
    with {:ok, id} <- parsear_id(flags, "id") do
      Ledger.Usuario.ver_usuario(id, Map.get(flags, "out", "stdout"))
    end
  end

  defp efectuar_comando("crear_moneda", flags) do
    with {:ok, p} = parsear_monto(flags, "p") do
      Ledger.Moneda.crear_moneda(Map.get(flags, "n", ""), p)
    end
  end

  defp efectuar_comando("editar_moneda", flags) do
    with {:ok, id} <- parsear_id(flags, "id"),
         {:ok, p} <- parsear_monto(flags, "p") do
      Ledger.Moneda.editar_moneda(id, p)
    end
  end

  defp efectuar_comando("borrar_moneda", flags) do
    with {:ok, id} <- parsear_id(flags, "id") do
      Ledger.Moneda.borrar_moneda(id)
    end
  end

  defp efectuar_comando("ver_moneda", flags) do
    with {:ok, id} <- parsear_id(flags, "id") do
      Ledger.Moneda.ver_moneda(id, Map.get(flags, "out", "stdout"))
    end
  end

  defp efectuar_comando("alta_cuenta", flags) do
    with {:ok, u} <- parsear_id(flags, "u"),
         {:ok, m} <- parsear_id(flags, "m"),
         {:ok, a} <- parsear_monto(flags, "a") do
      Ledger.Transaccion.alta_cuenta(u, m, a)
    end
  end

  defp efectuar_comando("realizar_transferencia", flags) do
    with {:ok, o} <- parsear_id(flags, "o"),
         {:ok, d} <- parsear_id(flags, "d"),
         {:ok, m} <- parsear_id(flags, "m"),
         {:ok, a} <- parsear_monto(flags, "a") do
      Ledger.Transaccion.realizar_transferencia(o, d, m, a)
    end
  end

  defp efectuar_comando("realizar_swap", flags) do
    with {:ok, u} <- parsear_id(flags, "u"),
         {:ok, mo} <- parsear_id(flags, "mo"),
         {:ok, md} <- parsear_id(flags, "md"),
         {:ok, a} <- parsear_monto(flags, "a") do
      Ledger.Transaccion.realizar_swap(u, mo, md, a)
    end
  end

  defp efectuar_comando("ver_transaccion", flags) do
    with {:ok, id} <- parsear_id(flags, "id") do
      Ledger.Transaccion.ver_transaccion(id, Map.get(flags, "out", "stdout"))
    end
  end

  defp efectuar_comando("deshacer_transaccion", flags) do
    with {:ok, id} <- parsear_id(flags, "id") do
      Ledger.Transaccion.deshacer_transaccion(id)
    end
  end

  defp parsear_id(flags, flag) do
    id = Map.get(flags, flag, "")

    case id do
      id when is_integer(id) ->
        {:ok, id}

      id when is_binary(id) ->
        case Integer.parse(id) do
          {id_int, ""} -> {:ok, id_int}
          _ -> {:error, "ID inválido, debe ser un número entero"}
        end

      _ ->
        {:error, "ID inválido, debe ser un número entero"}
    end
  end

  defp parsear_monto(flags, flag) do
    valor = Map.get(flags, flag, "")

    case valor do
      valor when is_integer(valor) ->
        {:ok, valor / 1}

      valor when is_float(valor) ->
        {:ok, valor}

      valor when is_binary(valor) ->
        case Float.parse(valor) do
          {monto_float, ""} -> {:ok, monto_float}
          _ -> {:error, "Valor inválido, debe ser un número"}
        end

      _ ->
        {:error, "Valor inválido, debe ser un número"}
    end
  end
end
