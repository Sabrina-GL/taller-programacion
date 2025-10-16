defmodule Ledger do
  @moduledoc """
  Módulo principal del sistema Ledger.

  Sistema de libro contable para gestionar transacciones entre usuarios con soporte para múltiples monedas y conversiones.
  """

  alias Ledger.{CLI, FileHandler}

  @doc """
  Función principal de entrada para la línea de comandos.

  ## Parámetros
  - `args`: Lista de argumentos de línea de comandos
  ## Retorno
  - `{:ok, 0}` si la ejecución fue exitosa
  - `{:error, razón}` si ocurrió algún error
  """
  def main(args \\ System.argv()) do
    # {:ok, _} = Application.ensure_all_started(:ecto)
    # {:ok, _} = Application.ensure_all_started(:postgrex)
    case Application.ensure_all_started(:ledger) do
      {:ok, _} ->
        procesar_comandos(args)

      {:error, {:already_started, _}} ->
        procesar_comandos(args)

      error ->
        error
    end
  end

  def procesar_comandos(args) do
    case CLI.procesar_argumentos(args) do
      {:error, razon} ->
        FileHandler.mostrar_error(razon)
        {:error, razon}

      {:ok, flags} ->
        case CLI.efectuar_comando(flags) do
          {:error, razon} ->
            FileHandler.mostrar_error(razon)
            {:error, razon}

          resultado ->
            resultado
        end
    end
  end
end
