defmodule Ledger.Repo.Migrations.CreateUsuarios do
  use Ecto.Migration

  def change do
    create table(:usuarios) do
      add :nombre, :string, null: false
      add :fecha_nacimiento, :date, null: false
      timestamps()
    end

    create unique_index(:usuarios, [:nombre])
  end
end
