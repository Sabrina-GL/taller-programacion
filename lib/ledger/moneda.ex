defmodule Ledger.Moneda do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ledger.Repo

  schema "monedas" do
    field(:nombre, :string)
    field(:precio_usd, :float)
    field(:fecha_creacion, :date)
    field(:fecha_edicion, :date)
    timestamps()
  end

  def crear_changeset(moneda, attrs) do
    moneda
    |> cast(attrs, [:nombre, :precio_usd, :fecha_creacion, :fecha_edicion])
    |> validate_required([:nombre, :precio_usd, :fecha_creacion, :fecha_edicion])
    |> unique_constraint(:nombre)
  end

  def crear_moneda(nombre, simbolo) do
    %Ledger.Moneda{}
    |> crear_changeset(%{nombre: nombre, simbolo: simbolo})
    |> Repo.insert()
  end

  def listar_monedas do
    Repo.all(Ledger.Moneda)
  end

  def obtener_moneda(id) do
    Repo.get(Ledger.Moneda, id)
  end
end
