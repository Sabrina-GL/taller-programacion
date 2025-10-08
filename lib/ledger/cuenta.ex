defmodule Ledger.Cuenta do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ledger.Repo

  schema "cuentas" do
    belongs_to(:usuario, Ledger.Usuario)
    belongs_to(:moneda, Ledger.Moneda)
    timestamps()
  end

  def changeset_crear(cuenta, attrs) do
    cuenta
    |> cast(attrs, [:usuario_id, :moneda_id])
    |> validate_required([:usuario_id, :moneda_id])
    |> unique_constraint(:usuario_id,
      name: :cuentas_usuario_id_moneda_id_index,
      message: "El usuario ya tiene una cuenta con esta moneda"
    )
    |> foreign_key_constraint(:usuario_id)
    |> foreign_key_constraint(:moneda_id)
  end

  def crear_cuenta(comando, usuario_id, moneda_id) do
    changeset =
      %__MODULE__{}
      |> changeset_crear(%{
        usuario_id: usuario_id,
        moneda_id: moneda_id
      })

    case Repo.insert(changeset) do
      {:ok, cuenta} ->
        {:ok, cuenta}

      {:error, razon} ->
        {:error, "#{comando}: #{inspect(razon)}"}
    end
  end
end
