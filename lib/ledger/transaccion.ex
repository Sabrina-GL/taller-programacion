defmodule Ledger.Transaccion do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ledger.{Repo, Cuenta, Moneda}

  schema "transacciones" do
    field(:tipo, :string)
    field(:monto, :float)
    belongs_to(:cuenta_origen, Cuenta)
    belongs_to(:cuenta_destino, Cuenta)
    belongs_to(:moneda_origen, Moneda)
    belongs_to(:moneda_destino, Moneda)
    timestamps()
  end

  def changeset_crear(transaccion, attrs) do
    transaccion
    |> cast(attrs, [
      :tipo,
      :cuenta_origen_id,
      :moneda_origen_id,
      :monto
    ])
    |> validate_required([
      :tipo,
      :cuenta_origen_id,
      :moneda_origen_id,
      :monto
    ])
    |> validar_segun_tipo()
  end

  defp validar_segun_tipo(changeset) do
    tipo = get_field(changeset, :tipo)

    case tipo do
      "alta" ->
        changeset
        |> validate_number(:monto,
          greater_than: 0,
          message: "El monto debe ser un número positivo"
        )
        |> foreign_key_constraint(:cuenta_origen_id)
        |> foreign_key_constraint(:moneda_origen_id)

      "transferencia" ->
        changeset
        |> validate_required(:cuenta_destino_id)
        |> validate_number(:monto,
          greater_than: 0,
          message: "El monto debe ser un número positivo"
        )
        |> foreign_key_constraint(:cuenta_origen_id)
        |> foreign_key_constraint(:cuenta_destino_id)
        |> foreign_key_constraint(:moneda_origen_id)

      "swap" ->
        changeset
        |> validate_number(:monto,
          greater_than: 0,
          message: "El monto debe ser un número positivo"
        )
        |> foreign_key_constraint(:cuenta_origen_id)
        |> foreign_key_constraint(:cuenta_destino_id)
        |> foreign_key_constraint(:moneda_origen_id)
        |> foreign_key_constraint(:moneda_destino_id)

      _ ->
        add_error(changeset, :tipo, "Tipo de transacción inválido")
    end
  end

  def alta_cuenta(comando, usuario_id, moneda_id, monto) do
    case Ledger.Cuenta.crear_cuenta(comando, usuario_id, moneda_id) do
      {:ok, cuenta} ->
        changeset =
          %__MODULE__{}
          |> changeset_crear(%{
            tipo: "alta",
            cuenta_origen_id: cuenta.id,
            moneda_origen_id: moneda_id,
            monto: monto
          })

        case Repo.insert(changeset) do
          {:ok, transaccion} ->
            {:ok, transaccion}

          {:error, razon} ->
            {:error, "#{comando}: No se pudo crear la transacción: #{inspect(razon)}"}
        end

      {:error, razon} ->
        {:error, razon}
    end
  end
end
