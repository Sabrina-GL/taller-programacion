defmodule Ledger.Repo.Migrations.CreateUsuarios do
  use Ecto.Migration

  def change do
    create table(:usuarios) do
      add :nombre, :string, null: false
      add :fecha_nacimiento, :date, null: false
      add :fecha_creacion, :date, null: false
      add :fecha_edicion, :date, null: false
    end

    create unique_index(:usuarios, [:nombre])
  end
end
