defmodule Ledger.Usuario do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ledger.{Repo, FileHandler, CLI}

  schema "usuarios" do
    field(:nombre, :string)
    field(:fecha_nacimiento, :date)
    timestamps()
  end

  defp crear_changeset(usuario, attrs) do
    usuario
    |> cast(attrs, [:nombre, :fecha_nacimiento])
    |> validate_required(:nombre, message: "El nombre es obligatorio")
    |> validate_required(:fecha_nacimiento)
    |> unique_constraint(:nombre, message: "El nombre ya está en uso")
    |> validar_mayoria_edad(:fecha_nacimiento)
  end

  defp editar_changeset(usuario, attrs) do
    usuario
    |> cast(attrs, [:nombre])
    |> validate_required(:nombre, message: "El nombre es obligatorio")
    |> unique_constraint(:nombre, message: "El nombre ya está en uso")
    |> validar_nombre_distinto(usuario)
  end

  defp validar_mayoria_edad(changeset, fecha) do
    case get_field(changeset, fecha) do
      nil ->
        changeset

      fecha_nacimiento ->
        años = Date.diff(Date.utc_today(), fecha_nacimiento) |> div(365)

        if años < 18 do
          add_error(changeset, fecha, "El usuario debe ser mayor de edad")
        else
          changeset
        end
    end
  end

  defp validar_nombre_distinto(changeset, usuario) do
    nuevo_nombre = get_field(changeset, :nombre)

    if nuevo_nombre == usuario.nombre do
      add_error(changeset, :nombre, "El nuevo nombre debe ser distinto al actual")
    else
      changeset
    end
  end

  def crear_usuario(nombre, fecha_nacimiento) do
    case Date.from_iso8601(fecha_nacimiento) do
      {:ok, fecha} ->
        changeset =
          %__MODULE__{}
          |> crear_changeset(%{
            nombre: nombre,
            fecha_nacimiento: fecha
          })

        case Repo.insert(changeset) do
          {:ok, usuario} ->
            {:ok, usuario}

          {:error, _razon} ->
            {:error, FileHandler.extraer_error(changeset)}
        end

      {:error, _} ->
        {:error, "Fecha de nacimiento inválida. Formato esperado: AAAA-MM-DD"}
    end
  end

  def editar_usuario(id, nuevo_nombre) do
    case obtener_usuario(id) do
      {:error, razon} ->
        {:error, razon}

      {:ok, usuario} ->
        if nuevo_nombre == "" do
          {:error, "El nombre es obligatorio"}
        else
          changeset =
            usuario
            |> editar_changeset(%{
              nombre: nuevo_nombre
            })

          case Repo.update(changeset) do
            {:ok, usuario} ->
              {:ok, usuario}

            {:error, _razon} ->
              {:error, FileHandler.extraer_error(changeset)}
          end
        end
    end
  end

  def borrar_usuario(id) do
    case obtener_usuario(id) do
      {:error, razon} ->
        {:error, razon}

      {:ok, usuario} ->
        case Repo.delete(usuario) do
          {:ok, _struct} -> {:ok, "Usuario borrado exitosamente"}
          {:error, razon} -> {:error, razon}
        end
    end
  end

  def ver_usuario(id, archivo) do
    case obtener_usuario(id) do
      {:error, razon} ->
        {:error, razon}

      {:ok, usuario} ->
        {:ok, FileHandler.mostrar_usuario(usuario, archivo)}
    end
  end

  def obtener_usuario(id) do
    case Repo.get(Ledger.Usuario, id) do
      nil -> {:error, "Usuario no encontrado"}
      usuario -> {:ok, usuario}
    end
  end
end
