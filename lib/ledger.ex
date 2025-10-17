defmodule Ledger do
  @moduledoc """
  Módulo principal del sistema Ledger.

  Sistema de libro contable para gestionar transacciones entre usuarios con soporte para múltiples monedas y conversiones.
  """

  alias Ledger.{CLI, FileHandler}

  @doc """
  Punto de entrada principal para la aplicación Ledger.
  Inicializa la aplicación y procesa los comandos proporcionados.
  ## Parámetros
  - `args`: Lista de argumentos de línea de comandos.
  ## Retorno
  - `{:ok, resultado}` si la aplicación se ejecutó exitosamente.
  - `{:error, razón}` si ocurrió algún error durante la ejecución.
  """
  def main(args \\ System.argv()) do
    case Application.ensure_all_started(:ledger) do
      {:ok, _} ->
        procesar_comandos(args)

      {:error, {:already_started, _}} ->
        procesar_comandos(args)

      error ->
        error
    end
  end

  @doc """
  Procesa los comandos de línea de comandos.
  ## Parámetros
  - `args`: Lista de argumentos de línea de comandos.
  ## Retorno
  - `{:ok, resultado}` si los comandos fueron procesados exitosamente.
  - `{:error, razón}` si ocurrió algún error durante el procesamiento.
  """
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
