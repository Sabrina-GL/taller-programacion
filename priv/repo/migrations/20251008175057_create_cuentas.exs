defmodule Ledger.Repo.Migrations.CreateCuentas do
  use Ecto.Migration

  def change do
    create table(:cuentas) do
      add :usuario_id, references(:usuarios, on_delete: :nothing), null: false
      add :moneda_id, references(:monedas, on_delete: :nothing), null: false
      timestamps()
    end

    create unique_index(:cuentas, [:usuario_id, :moneda_id])
  end
end
