defmodule Ledger.Moneda do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ledger.Repo

  schema "monedas" do
    field(:nombre, :string)
    field(:precio_usd, :float)
    timestamps()
    has_many(:cuentas, Ledger.Cuenta)
  end

  def changeset_crear(moneda, attrs) do
    moneda
    |> cast(attrs, [:nombre, :precio_usd])
    |> validate_required([:nombre, :precio_usd])
    |> unique_constraint(:nombre)
    |> validate_number(:precio_usd,
      greater_than: 0,
      message: "El precio debe ser un número positivo"
    )
    |> validate_format(:nombre, ~r/^[A-Z]{3,4}$/,
      message: "El nombre de la moneda debe estar en mayúsculas y tener entre 3 y 4 caracteres"
    )
  end

  def changeset_editar(moneda, attrs) do
    moneda
    |> cast(attrs, [:precio_usd])
    |> validate_required([:precio_usd])
    |> unique_constraint(:nombre)
    |> validate_number(:precio_usd,
      greater_than: 0,
      message: "El precio debe ser un número positivo"
    )
  end

  def crear_moneda(comando, nombre, precio_usd) do
    case Float.parse(precio_usd) do
      {precio, ""} when precio > 0 ->
        changeset =
          %__MODULE__{}
          |> changeset_crear(%{
            nombre: String.upcase(nombre),
            precio_usd: precio
          })

        case Repo.insert(changeset) do
          {:ok, moneda} ->
            {:ok, moneda}

          {:error, razon} ->
            {:error, "#{comando}: #{inspect(razon)}"}
        end

      _ ->
        {:error, "#{comando}: El precio en dólares debe ser un número positivo"}
    end
  end

  def editar_moneda(comando, id, nuevo_precio_usd) do
    case Repo.get(Ledger.Moneda, id) do
      nil ->
        {:error, "#{comando}: Moneda no encontrada"}

      moneda ->
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
                {:error, "#{comando}: #{inspect(razon)}"}
            end

          _ ->
            {:error, "#{comando}: El nuevo precio en dólares debe ser un número positivo"}
        end
    end
  end

  # TODO: chequear que no este en ninguna transacccion
  def borrar_moneda(comando, id) do
    case Repo.get(Ledger.Moneda, id) do
      nil ->
        {:error, "#{comando}: Moneda no encontrada"}

      moneda ->
        case Repo.delete(moneda) do
          {:ok, _struct} -> {:ok, "Moneda borrada exitosamente"}
          {:error, razon} -> {:error, "#{comando}: #{inspect(razon)}"}
        end
    end
  end

  def ver_moneda(comando, id) do
    case Repo.get(Ledger.Moneda, id) do
      nil ->
        {:error, "#{comando}: Moneda no encontrada"}

      moneda ->
        IO.inspect(moneda)
        {:ok, moneda}
    end
  end

  def listar_monedas do
    Repo.all(Ledger.Moneda)
  end

  def obtener_moneda(id) do
    Repo.get(Ledger.Moneda, id)
  end
end
