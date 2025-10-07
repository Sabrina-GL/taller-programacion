defmodule Ledger.Usuario do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ledger.Repo

  schema "usuarios" do
    field(:nombre, :string)
    field(:fecha_nacimiento, :date)
    field(:fecha_creacion, :date)
    field(:fecha_edicion, :date)
  end

  def crear_changeset(usuario, attrs) do
    usuario
    |> cast(attrs, [:nombre, :fecha_nacimiento, :fecha_creacion, :fecha_edicion])
    |> validate_required([:nombre, :fecha_nacimiento, :fecha_creacion, :fecha_edicion])
    |> unique_constraint(:nombre)
    |> validar_mayoria_edad(:fecha_nacimiento)
  end

  def editar_changeset(usuario, attrs) do
    usuario
    |> cast(attrs, [:nombre, :fecha_nacimiento, :fecha_edicion])
    |> validate_required([:nombre, :fecha_edicion])
    |> unique_constraint(:nombre)
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

  def crear_usuario(comando, nombre, fecha_nacimiento) do
    case Date.from_iso8601(fecha_nacimiento) do
      {:ok, fecha} ->
        changeset =
          %__MODULE__{}
          |> crear_changeset(%{
            nombre: nombre,
            fecha_nacimiento: fecha,
            fecha_creacion: Date.utc_today(),
            fecha_edicion: Date.utc_today()
          })

        case Repo.insert(changeset) do
          {:ok, usuario} ->
            {:ok, usuario}

          {:error, razon} ->
            {:error, "#{comando}: No se pudo crear el usuario: #{inspect(razon)}"}
        end

      {:error, _} ->
        {:error, "#{comando}: Fecha de nacimiento inválida. Formato esperado: AAAA-MM-DD"}
    end
  end

  def editar_usuario(comando, id, nuevo_nombre) do
    case obtener_usuario(id) do
      nil ->
        {:error, "#{comando}: Usuario no encontrado"}

      usuario ->
        changeset =
          usuario
          |> editar_changeset(%{
            nombre: nuevo_nombre,
            fecha_edicion: Date.utc_today()
          })

        case Repo.update(changeset) do
          {:ok, usuario} ->
            {:ok, usuario}

          {:error, razon} ->
            {:error, "#{comando}: #{inspect(razon)}"}
        end
    end
  end

  def borrar_usuario(comando, id) do
    case obtener_usuario(id) do
      nil ->
        {:error, "#{comando}: Usuario no encontrado"}

      usuario ->
        case Repo.delete(usuario) do
          {:ok, _struct} -> {:ok, "Usuario borrado exitosamente"}
          {:error, razon} -> {:error, "#{comando}: #{inspect(razon)}"}
        end
    end
  end

  def ver_usuario(comando, id) do
    case obtener_usuario(id) do
      nil ->
        {:error, "#{comando}: Usuario no encontrado"}

      usuario ->
        {:ok, usuario}
    end
  end

  def obtener_usuario(id) do
    Repo.get(Ledger.Usuario, id)
  end
end
