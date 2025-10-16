defmodule Ledger.FileHandler do
  @moduledoc """
  Módulo para manejo de archivos y salida de datos en el sistema Ledger.
  Proporciona funciones para leer archivos, mostrar líneas, balances y errores.
  """

  alias Ledger.Moneda

  def mostrar_balance(balance, archivo) do
    msg_balance = "BALANCE"

    cond do
      archivo == "stdout" -> IO.puts(msg_balance)
      true -> File.write!(archivo, msg_balance <> "\n", [:append])
    end

    Enum.each(balance, fn {moneda, monto} ->
      mostrar_linea_balance(moneda, monto, archivo)
    end)
  end

  def mostrar_usuario(usuario, archivo) do
    informacion =
      """
      ✦ . ⁺ . ✦ USUARIO #{usuario.id} ✦ . ⁺ . ✦
      Nombre: #{usuario.nombre}
      Fecha de Nacimiento: #{Date.to_iso8601(usuario.fecha_nacimiento)}
      Creado: #{NaiveDateTime.to_iso8601(usuario.inserted_at)}
      Modificado: #{NaiveDateTime.to_iso8601(usuario.updated_at)}

      """

    cond do
      archivo == "stdout" -> IO.puts(informacion)
      true -> File.write!(archivo, informacion <> "\n", [:append])
    end

    informacion
  end

  def mostrar_moneda(moneda, archivo) do
    informacion =
      """
      ✦ . ⁺ . ✦ MONEDA #{moneda.id} ✦ . ⁺ . ✦
      Nombre: #{moneda.nombre}
      Precio: #{moneda.precio_usd}
      Creado: #{NaiveDateTime.to_iso8601(moneda.inserted_at)}
      Modificado: #{NaiveDateTime.to_iso8601(moneda.updated_at)}
      """

    cond do
      archivo == "stdout" -> IO.puts(informacion)
      true -> File.write!(archivo, informacion <> "\n", [:append])
    end

    informacion
  end

  def mostrar_transaccion(transaccion, archivo) do
    lineas = [
      "✦ . ⁺ . ✦ TRANSACCIÓN #{transaccion.id} ✦ . ⁺ . ✦",
      "Tipo: #{transaccion.tipo}",
      "Cuenta Origen: #{transaccion.cuenta_origen_id}",
      if(transaccion.cuenta_destino_id, do: "Cuenta Destino: #{transaccion.cuenta_destino_id}"),
      "Moneda Origen: #{transaccion.moneda_origen_id}",
      if(transaccion.moneda_destino_id, do: "Moneda Destino: #{transaccion.moneda_destino_id}"),
      "Monto: #{:io_lib.format("~.6f", [transaccion.monto]) |> to_string()}",
      "Creado: #{NaiveDateTime.to_iso8601(transaccion.inserted_at)}",
      "Modificado: #{NaiveDateTime.to_iso8601(transaccion.updated_at)}"
    ]

    informacion = lineas |> Enum.filter(& &1) |> Enum.join("\n")

    cond do
      archivo == "stdout" -> IO.puts(informacion)
      true -> File.write!(archivo, informacion <> "\n", [:append])
    end

    informacion
  end

  defp mostrar_linea_balance(moneda, monto, archivo) do
    nombre_moneda = Moneda.obtener_nombre(moneda)
    monto_decimales = :io_lib.format("~.6f", [monto]) |> to_string()
    monto_str = "#{nombre_moneda}=#{monto_decimales}"

    cond do
      archivo == "stdout" -> IO.puts(monto_str)
      true -> File.write!(archivo, monto_str <> "\n", [:append])
    end
  end

  def mostrar_error(razon) do
    IO.puts("{:error, " <> razon <> "}")
  end

  def extraer_error(changeset) do
    mensaje_error =
      case changeset.errors do
        [error | _] ->
          {_campo, {mensaje, _}} = error
          "#{mensaje}"

        [] ->
          case changeset.constraints do
            [%{type: :unique, constraint: "usuarios_nombre_index"} | _] ->
              "El nombre ya está en uso"

            [%{type: :unique, constraint: "monedas_nombre_index"} | _] ->
              "El nombre ya está en uso"

            _ ->
              "Error desconocido"
          end
      end

    mensaje_error
  end
end
