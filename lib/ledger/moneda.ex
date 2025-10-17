defmodule Ledger.Moneda do
  @moduledoc """
  Módulo para manejar monedas en el sistema Ledger.
  Proporciona funciones para crear, listar y gestionar monedas.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Ledger.Transaccion
  alias Ledger.{Repo, FileHandler}

  schema "monedas" do
    field(:nombre, :string)
    field(:precio_usd, :float)
    timestamps()
  end

  @doc """
  Crea una nueva moneda con el nombre y el precio en dólares proporcionados.
  ## Parámetros
  - `nombre`: Nombre de la moneda (3-4 caracteres).
  - `precio_usd`: Precio de la moneda en dólares (número no negativo).
  ## Retorno
  - `{:ok, moneda}` si la moneda fue creada exitosamente.
  - `{:error, razón}` si ocurrió algún error durante la creación.
  """
  def crear_moneda(nombre, precio_usd) do
    changeset =
      %__MODULE__{}
      |> changeset_crear(%{
        nombre: String.upcase(nombre),
        precio_usd: precio_usd
      })

    case Repo.insert(changeset) do
      {:ok, moneda} ->
        {:ok, moneda}

      {:error, _razon} ->
        {:error, FileHandler.extraer_error(changeset)}
    end
  end

  @doc """
  Obtiene una moneda por su ID.
  ## Parámetros
  - `id`: ID de la moneda.
  ## Retorno
  - `{:ok, moneda}` si la moneda fue encontrada.
  - `{:error, razón}` si la moneda no fue encontrada.
  """
  def obtener_moneda(id) do
    case Repo.get(Ledger.Moneda, id) do
      nil -> {:error, "Moneda no encontrada"}
      moneda -> {:ok, moneda}
    end
  end

  @doc """
  Edita el precio en dólares de una moneda existente.
  ## Parámetros
  - `id`: ID de la moneda.
  - `nuevo_precio_usd`: Nuevo precio en dólares para la moneda.
  ## Retorno
  - `{:ok, moneda}` si la moneda fue editada exitosamente.
  - `{:error, razón}` si ocurrió algún error durante la edición.
  """
  def editar_moneda(id, nuevo_precio_usd) do
    with {:ok, moneda} <- obtener_moneda(id) do
      changeset =
        moneda
        |> changeset_editar(%{
          precio_usd: nuevo_precio_usd
        })

      case Repo.update(changeset) do
        {:ok, moneda} ->
          {:ok, moneda}

        {:error, _} ->
          {:error, FileHandler.extraer_error(changeset)}
      end
    end
  end

  @doc """
  Borra una moneda por su ID.
  ## Parámetros
  - `id`: ID de la moneda.
  ## Retorno
  - `{:ok, mensaje}` si la moneda fue borrada exitosamente.
  - `{:error, razón}` si ocurrió algún error durante el borrado.
  """
  def borrar_moneda(id) do
    with {:ok, moneda} <- obtener_moneda(id),
         :ok <- puede_borrarse?(id),
         {:ok, _} <- Repo.delete(moneda) do
      {:ok, "Moneda borrada exitosamente"}
    end
  end

  @doc """
  Muestra la información de una moneda.
  ## Parámetros
  - `id`: ID de la moneda.
  - `archivo`: Archivo donde se mostrará la información o "stdout" para mostrar por salida estándar.
  ## Retorno
  - `{:ok, informacion}` si la información fue mostrada exitosamente.
  - `{:error, razón}` si ocurrió algún error al obtener la moneda.
  """
  def ver_moneda(id, archivo) do
    with {:ok, moneda} <- obtener_moneda(id) do
      {:ok, FileHandler.mostrar_moneda(moneda, archivo)}
    end
  end

  @doc """
  Cambia un monto de una moneda a otra utilizando sus precios en dólares.
  ## Parámetros
  - `monto`: Monto a convertir.
  - `precio_origen`: Precio en dólares de la moneda de origen.
  - `precio_destino`: Precio en dólares de la moneda de destino.
  ## Retorno
  - `{:ok, monto_convertido}` con el monto convertido.
  """
  def cambiar_a_moneda(monto, precio_origen, precio_destino) do
    {:ok, monto * precio_origen / precio_destino}
  end

  @doc """
  Obtiene el nombre de una moneda por su ID.
  ## Parámetros
  - `id`: ID de la moneda.
  ## Retorno
  - `nombre` de la moneda si fue encontrada.
  - `{:error, razón}` si la moneda no fue encontrada.
  """
  def obtener_nombre(id) do
    with {:ok, moneda} <- obtener_moneda(id) do
      moneda.nombre
    end
  end

  @doc """
  Obtiene el precio en dólares de una moneda por su ID.
  ## Parámetros
  - `id`: ID de la moneda.
  ## Retorno
  - `precio_usd` de la moneda si fue encontrada.
  - `{:error, razón}` si la moneda no fue encontrada.
  """
  def obtener_precio(id) do
    with {:ok, moneda} <- obtener_moneda(id) do
      moneda.precio_usd
    end
  end

  defp changeset_crear(moneda, attrs) do
    moneda
    |> cast(attrs, [:nombre, :precio_usd])
    |> validate_required(:nombre, message: "El nombre es obligatorio")
    |> validate_required(:precio_usd, message: "El precio en dólares es obligatorio")
    |> unique_constraint(:nombre)
    |> validate_number(:precio_usd,
      greater_than_or_equal_to: 0,
      message: "El precio debe ser un número mayor o igual a 0"
    )
    |> validate_format(:nombre, ~r/^[A-Z]{3,4}$/,
      message: "El nombre de la moneda debe tener entre 3 y 4 caracteres"
    )
  end

  defp changeset_editar(moneda, attrs) do
    moneda
    |> cast(attrs, [:precio_usd])
    |> validate_required([:precio_usd], message: "El precio es obligatorio")
    |> unique_constraint(:nombre)
    |> validate_number(:precio_usd,
      greater_than: 0,
      message: "El precio debe ser un número positivo"
    )
  end

  defp puede_borrarse?(id) do
    transacciones =
      Repo.all(
        from(t in Transaccion,
          where: (t.moneda_origen_id == ^id or t.moneda_destino_id == ^id) and t.tipo != "alta"
        )
      )

    if Enum.empty?(transacciones) do
      :ok
    else
      {:error, "La moneda tiene transacciones asociadas"}
    end
  end
end
