defmodule Ledger.Transaccion do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Ledger.{Repo, Usuario, Moneda, FileHandler}

  schema "transacciones" do
    field(:tipo, :string)
    field(:monto, :float)
    belongs_to(:cuenta_origen, Usuario)
    belongs_to(:cuenta_destino, Usuario)
    belongs_to(:moneda_origen, Moneda)
    belongs_to(:moneda_destino, Moneda)
    field(:precio_moneda_origen, :float)
    field(:precio_moneda_destino, :float)
    timestamps()
  end

  # TODO: Solo puede deshacerse una transaccion si es la última de lo/los usuarios asociados.
  def alta_cuenta(usuario, moneda, monto) do
    cond do
      monto <= 0 ->
        {:error, "El monto debe ser un número positivo"}

      monto > 0 ->
        alta_cuenta_interna(usuario, moneda, monto)
    end
  end

  def realizar_transferencia(cuenta_origen_id, cuenta_destino_id, moneda_id, monto) do
    with :ok <- validar_transferencia(cuenta_origen_id, cuenta_destino_id, moneda_id) do
      changeset =
        %__MODULE__{}
        |> changeset_crear(%{
          tipo: "transferencia",
          cuenta_origen_id: cuenta_origen_id,
          cuenta_destino_id: cuenta_destino_id,
          moneda_origen_id: moneda_id,
          monto: monto,
          precio_moneda_origen: Moneda.obtener_precio(moneda_id)
        })

      case Repo.insert(changeset) do
        {:ok, transaccion} ->
          {:ok, transaccion}

        {:error, _razon} ->
          {:error, FileHandler.extraer_error(changeset)}
      end
    end
  end

  def realizar_swap(
        cuenta_id,
        moneda_origen_id,
        moneda_destino_id,
        monto
      ) do
    with {:ok, _usuario} <- Usuario.obtener_usuario(cuenta_id),
         {:ok, _moneda_origen} <- Moneda.obtener_moneda(moneda_origen_id),
         {:ok, _moneda_destino} <- Moneda.obtener_moneda(moneda_destino_id),
         :ok <- existe_cuenta?(cuenta_id, moneda_origen_id) do
      changeset =
        %__MODULE__{}
        |> changeset_crear(%{
          tipo: "swap",
          cuenta_origen_id: cuenta_id,
          moneda_origen_id: moneda_origen_id,
          moneda_destino_id: moneda_destino_id,
          monto: monto,
          precio_moneda_origen: Moneda.obtener_precio(moneda_origen_id),
          precio_moneda_destino: Moneda.obtener_precio(moneda_destino_id)
        })

      case Repo.insert(changeset) do
        {:ok, transaccion} ->
          {:ok, transaccion}

        {:error, _razon} ->
          {:error, FileHandler.extraer_error(changeset)}
      end
    end
  end

  def ver_transaccion(id, archivo) do
    with {:ok, transaccion} <- obtener_transaccion(id) do
      {:ok, FileHandler.mostrar_transaccion(transaccion, archivo)}
    end
  end

  def deshacer_transaccion(transaccion_id) do
    with {:ok, t} <- obtener_transaccion(transaccion_id) do
      case t.tipo do
        "alta" ->
          {:error, "No se puede deshacer un alta de cuenta"}

        "swap" ->
          case existe_cuenta?(t.cuenta_origen_id, t.moneda_destino_id) do
            {:error, _} -> alta_cuenta_interna(t.cuenta_origen_id, t.moneda_destino_id, 0)
            :ok -> nil
          end

          realizar_swap(t.cuenta_origen_id, t.moneda_destino_id, t.moneda_origen_id, t.monto)

        "transferencia" ->
          case existe_cuenta?(t.cuenta_destino_id, t.moneda_origen_id) do
            {:error, _} -> alta_cuenta_interna(t.cuenta_destino_id, t.moneda_id, 0)
            :ok -> nil
          end

          realizar_transferencia(
            t.cuenta_destino_id,
            t.cuenta_origen_id,
            t.moneda_origen_id,
            t.monto
          )
      end
    end
  end

  def obtener_transacciones(cuenta_origen_id, cuenta_destino_id) do
    with :ok <- validar_cuenta(cuenta_origen_id),
         :ok <- validar_cuenta(cuenta_destino_id) do
      query =
        from(t in Ledger.Transaccion,
          preload: [:cuenta_origen, :cuenta_destino]
        )

      query =
        case {cuenta_origen_id, cuenta_destino_id} do
          {"", ""} ->
            query

          {co, ""} ->
            from(t in query,
              where: t.cuenta_origen_id == ^co
            )

          {"", cd} ->
            from(t in query,
              where: t.cuenta_destino_id == ^cd
            )

          {co, cd} ->
            from(t in query,
              where:
                t.cuenta_origen_id == ^co and
                  t.cuenta_destino_id == ^cd
            )
        end

      transacciones = Ledger.Repo.all(query) || []

      {:ok, transacciones}
    end
  end

  def listar_transacciones(c1, c2, o) do
    with {:ok, transacciones} <- obtener_transacciones(c1, c2) do
      Enum.each(transacciones, fn t ->
        FileHandler.mostrar_transaccion(t, o)
      end)

      {:ok, transacciones}
    end
  end

  def listar_balance(cuenta_id, moneda_id, archivo) do
    balance = %{}

    with {:ok, transacciones_salientes} <- obtener_transacciones(cuenta_id, ""),
         {:ok, transacciones_entrantes} <- obtener_transacciones("", cuenta_id) do
      balance_actualizado =
        (transacciones_salientes ++ transacciones_entrantes)
        |> Enum.sort_by(& &1.inserted_at, {:asc, NaiveDateTime})
        |> Enum.reduce(balance, fn t, acc -> calcular_balance(acc, t, cuenta_id) end)

      if moneda_id != "" do
        with {:ok, _moneda} <- Moneda.obtener_moneda(moneda_id) do
          balance_en_moneda = cambiar_balance_a_moneda(balance_actualizado, moneda_id)
          FileHandler.mostrar_balance(balance_en_moneda, archivo)
          {:ok, balance_en_moneda}
        end
      else
        FileHandler.mostrar_balance(balance_actualizado, archivo)
        {:ok, balance_actualizado}
      end
    end
  end

  defp changeset_crear(transaccion, attrs) do
    transaccion
    |> cast(attrs, [
      :tipo,
      :cuenta_origen_id,
      :moneda_origen_id,
      :monto,
      :precio_moneda_origen
    ])
    |> validate_required(
      :tipo,
      message: "El tipo es obligatorio"
    )
    |> validate_required(:cuenta_origen_id, message: "La cuenta de origen es obligatoria")
    |> validate_required(:moneda_origen_id, message: "La moneda es obligatoria")
    |> validate_required(:monto, message: "El monto es obligatorio")
    |> validar_segun_tipo(attrs)
  end

  defp validar_segun_tipo(changeset, attrs) do
    tipo = get_field(changeset, :tipo)
    validar_segun_tipo(tipo, changeset, attrs)
  end

  defp validar_segun_tipo("alta", changeset, _attrs) do
    changeset
    |> validate_number(:monto,
      greater_than_or_equal_to: 0,
      message: "El monto debe ser un número positivo"
    )
    |> foreign_key_constraint(:cuenta_origen_id)
    |> foreign_key_constraint(:moneda_origen_id)
    |> validar_cuenta_no_existe()
  end

  defp validar_segun_tipo("transferencia", changeset, attrs) do
    changeset
    |> cast(attrs, [:cuenta_destino_id, :moneda_destino_id])
    |> validate_required(:cuenta_destino_id)
    |> validate_number(:monto,
      greater_than: 0,
      message: "El monto debe ser un número positivo"
    )
    |> foreign_key_constraint(:cuenta_origen_id)
    |> foreign_key_constraint(:cuenta_destino_id)
    |> foreign_key_constraint(:moneda_origen_id)
    |> validar_saldo_sufieciente()
  end

  defp validar_segun_tipo("swap", changeset, attrs) do
    changeset
    |> cast(attrs, [:moneda_destino_id, :precio_moneda_destino])
    |> validate_number(:monto,
      greater_than: 0,
      message: "El monto debe ser un número positivo"
    )
    |> foreign_key_constraint(:cuenta_origen_id)
    |> foreign_key_constraint(:moneda_origen_id)
    |> foreign_key_constraint(:moneda_destino_id)
    |> validar_saldo_sufieciente()

    # |> changeset_hasta_seis_decimales([:precio_moneda_destino])
  end

  defp validar_segun_tipo(_, changeset, _attrs) do
    add_error(changeset, :tipo, "Tipo de transacción inválido")
  end

  defp validar_cuenta_no_existe(changeset) do
    usuario_id = get_field(changeset, :cuenta_origen_id)
    moneda_id = get_field(changeset, :moneda_origen_id)

    if existe_cuenta?(usuario_id, moneda_id) == :ok do
      add_error(changeset, :cuenta_origen_id, "Ya existe una cuenta para este usuario y moneda")
    else
      changeset
    end
  end

  defp validar_saldo_sufieciente(changeset) do
    usuario_id = get_field(changeset, :cuenta_origen_id)
    moneda_id = get_field(changeset, :moneda_origen_id)
    monto = get_field(changeset, :monto)

    saldo = calcular_saldo_para_moneda(usuario_id, moneda_id)

    if saldo < monto do
      add_error(changeset, :monto, "Saldo insuficiente")
    else
      changeset
    end
  end

  defp validar_transferencia(cuenta_origen_id, cuenta_destino_id, moneda_id) do
    with {:ok, _usuario_origen} <- Usuario.obtener_usuario(cuenta_origen_id),
         {:ok, _usuario_destino} <- Usuario.obtener_usuario(cuenta_destino_id),
         {:ok, _moneda} <- Moneda.obtener_moneda(moneda_id),
         :ok <- existe_cuenta?(cuenta_origen_id, moneda_id) do
      if cuenta_origen_id == cuenta_destino_id do
        {:error, "No se puede realizar una transferencia a la misma cuenta"}
      else
        case existe_cuenta?(cuenta_destino_id, moneda_id) do
          {:error, _} -> alta_cuenta_interna(cuenta_destino_id, moneda_id, 0)
          :ok -> nil
        end

        :ok
      end
    end
  end

  defp alta_cuenta_interna(usuario, moneda, monto) do
    with {:ok, _usuario} <- Usuario.obtener_usuario(usuario),
         {:ok, _moneda} <- Moneda.obtener_moneda(moneda) do
      changeset =
        %__MODULE__{}
        |> changeset_crear(%{
          tipo: "alta",
          cuenta_origen_id: usuario,
          moneda_origen_id: moneda,
          monto: monto,
          precio_moneda_origen: Moneda.obtener_precio(moneda)
        })

      case Repo.insert(changeset) do
        {:ok, transaccion} ->
          {:ok, transaccion}

        {:error, _razon} ->
          {:error, FileHandler.extraer_error(changeset)}
      end
    end
  end

  defp existe_cuenta?(usuario_id, moneda_id) do
    existe =
      Repo.exists?(
        from(t in Ledger.Transaccion,
          where:
            t.tipo == "alta" and t.cuenta_origen_id == ^usuario_id and
              t.moneda_origen_id == ^moneda_id
        )
      )

    if existe do
      :ok
    else
      {:error, "No hay una cuenta asociada con esa moneda"}
    end
  end

  defp validar_cuenta(""), do: :ok

  defp validar_cuenta(cuenta_id) do
    with {:ok, _} <- Usuario.obtener_usuario(cuenta_id) do
      :ok
    end
  end

  defp calcular_saldo_para_moneda(cuenta_id, moneda_id) do
    with {:ok, transacciones_salientes} <- obtener_transacciones(cuenta_id, ""),
         {:ok, transacciones_entrantes} <- obtener_transacciones("", cuenta_id) do
      saldo = %{}

      (transacciones_salientes ++ transacciones_entrantes)
      |> Enum.reduce(saldo, fn t, acc -> calcular_balance(acc, t, cuenta_id) end)
      |> Map.get(moneda_id, 0.0)
    end
  end

  defp calcular_balance(balance, t, cuenta_id) do
    monto_a_sumar = t.monto * t.precio_moneda_origen / Moneda.obtener_precio(t.moneda_origen_id)

    cond do
      t.tipo == "alta" ->
        balance_actualizado =
          Map.update(balance, t.moneda_origen_id, monto_a_sumar, fn monto_actual ->
            monto_actual + monto_a_sumar
          end)

        balance_actualizado

      t.tipo == "transferencia" and t.cuenta_origen_id == cuenta_id ->
        balance_actualizado =
          Map.update(balance, t.moneda_origen_id, -monto_a_sumar, fn monto_actual ->
            monto_actual - monto_a_sumar
          end)

        balance_actualizado

      t.tipo == "transferencia" and t.cuenta_destino_id == cuenta_id ->
        balance_actualizado =
          Map.update(balance, t.moneda_origen_id, monto_a_sumar, fn monto_actual ->
            monto_actual + monto_a_sumar
          end)

        balance_actualizado

      t.tipo == "swap" ->
        balance_actualizado =
          Map.update(balance, t.moneda_origen_id, -t.monto, fn monto_actual ->
            monto_actual - monto_a_sumar
          end)
          |> Map.update(
            t.moneda_destino_id,
            t.monto * t.precio_moneda_origen / t.precio_moneda_destino,
            fn monto_actual ->
              monto_actual + t.monto * t.precio_moneda_origen / t.precio_moneda_destino
            end
          )

        balance_actualizado

      true ->
        balance
    end
  end

  defp cambiar_balance_a_moneda(balance, moneda_id) do
    total =
      Enum.reduce(balance, 0.0, fn {moneda_actual_id, monto}, acc ->
        with {:ok, monto_cambiado} <-
               Moneda.cambiar_a_moneda(
                 monto,
                 Moneda.obtener_precio(moneda_actual_id),
                 Moneda.obtener_precio(moneda_id)
               ) do
          acc + monto_cambiado
        end
      end)

    %{moneda_id => total}
  end

  defp obtener_transaccion(id) do
    case Repo.get(Ledger.Transaccion, id) do
      nil -> {:error, "Transaccion no encontrada"}
      transaccion -> {:ok, transaccion}
    end
  end
end
