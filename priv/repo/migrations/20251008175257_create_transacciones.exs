defmodule Ledger.Repo.Migrations.CreateTransacciones do
  use Ecto.Migration

  def change do
    create table(:transacciones) do
      add :tipo, :string, null: false
      add :cuenta_origen_id, references(:cuentas, on_delete: :nothing), null: false
      add :cuenta_destino_id, references(:cuentas, on_delete: :nothing)
      add :moneda_origen_id, references(:monedas, on_delete: :nothing), null: false
      add :moneda_destino_id, references(:monedas, on_delete: :nothing)
      add :monto, :float, null: false
      timestamps()
    end

    create index(:transacciones, [:cuenta_origen_id])
    create index(:transacciones, [:cuenta_destino_id])
    create index(:transacciones, [:moneda_origen_id])
    create index(:transacciones, [:moneda_destino_id])
  end
end
