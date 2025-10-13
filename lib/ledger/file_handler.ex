defmodule Ledger.FileHandler do
  @moduledoc """
  Módulo para manejo de archivos y salida de datos en el sistema Ledger.
  Proporciona funciones para leer archivos, mostrar líneas, balances y errores.
  """

  alias Ledger.Moneda

  @doc """
  Lee un archivo y devuelve su contenido como una lista de listas, donde cada sublista representa una línea dividida por punto y coma.

  ## Parámetros
  - `archivo`: Ruta del archivo a leer.
  ## Retorno
  - `{:ok, contenido}` si la lectura fue exitosa, donde `contenido` es una lista de listas.
  - `{:error, razón}` si ocurrió un error al leer el archivo.
  """
  def leer_archivo(archivo) do
    case File.read(archivo) do
      {:ok, contenido} ->
        contenido
        |> String.split("\n")
        |> Enum.map(fn linea -> String.split(linea, ";") end)
        |> Enum.filter(fn
          [""] -> false
          [] -> false
          _linea -> true
        end)

      {:error, razon} ->
        {:error, razon}
    end
  end

  @doc """
  Muestra una línea en la salida estándar o la escribe en un archivo.

  ## Parámetros
  - `linea`: Lista de elementos que conforman la línea.
  - `archivo`: Ruta del archivo donde se escribirá la línea o "stdout" para salida estándar.
  """
  def mostrar_linea(linea, archivo) do
    linea_str = Enum.join(linea, ";")

    cond do
      archivo == "stdout" -> IO.puts(linea_str)
      true -> File.write!(archivo, linea_str <> "\n", [:append])
    end
  end

  def mostrar_balance(balance, archivo) do
    Enum.each(balance, fn {moneda, monto} ->
      mostrar_linea_balance(moneda, monto, archivo)
    end)
  end

  @doc """
  Muestra el balance de montos en diferentes monedas, convirtiéndolos a una moneda específica si se indica.

  ## Parámetros
  - `moneda`: Moneda a la cual se convertirán todos los montos. Si es una cadena vacía, se muestran los montos en sus monedas originales.
  - `montos`: Lista de tuplas `{moneda, monto}` representando los montos en diferentes monedas.
  - `monedas`: Mapa de tasas de cambio entre monedas.
  - `archivo`: Ruta del archivo donde se escribirá el balance o "stdout" para salida estándar.
  """
  def mostrar_balance(moneda, montos, monedas, archivo) do
    if moneda != "" do
      total =
        Enum.reduce(montos, 0.0, fn {moneda_actual, monto}, acc2 ->
          acc2 + Ledger.Currency.cambiar_a_moneda(monto, moneda_actual, moneda, monedas)
        end)

      mostrar_linea_balance(moneda, total, archivo)
    else
      Enum.each(montos, fn {moneda_actual, monto} ->
        mostrar_linea_balance(moneda_actual, monto, archivo)
      end)
    end
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

            _ ->
              "Error desconocido"
          end
      end

    mensaje_error
  end
end
