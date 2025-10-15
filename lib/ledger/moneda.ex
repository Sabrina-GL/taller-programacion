defmodule Ledger.Moneda do
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

  def obtener_moneda(id) do
    case Repo.get(Ledger.Moneda, id) do
      nil -> {:error, "Moneda no encontrada"}
      moneda -> {:ok, moneda}
    end
  end

  def editar_moneda(id, nuevo_precio_usd) do
    case obtener_moneda(id) do
      {:error, razon} ->
        {:error, razon}

      {:ok, moneda} ->
        case Float.parse(nuevo_precio_usd) do
          {precio, ""} when precio > 0 ->
            changeset =
              moneda
              |> changeset_editar(%{
                precio_usd: precio
              })

            case Repo.update(changeset) do
              {:ok, moneda} ->
                {:ok, moneda}

              {:error, razon} ->
                {:error, razon}
            end

          _ ->
            {:error, "El nuevo precio debe ser un número positivo"}
        end
    end
  end

  def borrar_moneda(id) do
    with {:ok, moneda} <- obtener_moneda(id),
         :ok <- puede_borrarse?(id) do
      case Repo.delete(moneda) do
        {:ok, _struct} -> {:ok, "Moneda borrada exitosamente"}
        {:error, razon} -> {:error, razon}
      end
    end
  end

  def ver_moneda(id, archivo) do
    case obtener_moneda(id) do
      {:error, razon} ->
        {:error, razon}

      {:ok, moneda} ->
        {:ok, FileHandler.mostrar_moneda(moneda, archivo)}
    end
  end

  def cambiar_a_moneda(monto, moneda_origen_id, moneda_destino_id) do
    with {:ok, moneda_origen} <- obtener_moneda(moneda_origen_id),
         {:ok, moneda_destino} <- obtener_moneda(moneda_destino_id) do
      {:ok, monto * moneda_origen.precio_usd / moneda_destino.precio_usd}
    end
  end

  def obtener_nombre(id) do
    with {:ok, moneda} <- obtener_moneda(id) do
      moneda.nombre
    end
  end

  defp changeset_crear(moneda, attrs) do
    moneda
    |> cast(attrs, [:nombre, :precio_usd])
    |> validate_required(:nombre, message: "El nombre es obligatorio")
    |> validate_required(:precio_usd, message: "El precio en dólares es obligatorio")
    |> unique_constraint(:nombre)
    |> validate_number(:precio_usd,
      greater_than: 0,
      message: "El precio debe ser un número positivo"
    )
    |> validate_format(:nombre, ~r/^[A-Z]{3,4}$/,
      message: "El nombre de la moneda debe tener entre 3 y 4 caracteres"
    )
  end

  defp changeset_editar(moneda, attrs) do
    moneda
    |> cast(attrs, [:precio_usd])
    |> validate_required([:precio_usd])
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
