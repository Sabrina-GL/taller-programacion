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
    timestamps()
  end

  # TODO: agregar precio actual de cada moneda en la transaccion por si se edita
  # TODO: deshacer_transaccion

  def alta_cuenta(usuario, moneda, monto) do
    cond do
      monto <= 0 ->
        {:error, "El monto debe ser un número positivo"}

      monto > 0 ->
        alta_cuenta_interna(usuario, moneda, monto)
    end
  end

  # TODO no permitir transferencia entre mismo usuario

  def realizar_transferencia(cuenta_origen_id, cuenta_destino_id, moneda_id, monto) do
    with {:ok, _usuario_origen} <- Usuario.obtener_usuario(cuenta_origen_id),
         {:ok, _usuario_destino} <- Usuario.obtener_usuario(cuenta_destino_id),
         {:ok, _moneda} <- Moneda.obtener_moneda(moneda_id) do
      case existe_cuenta?(cuenta_destino_id, moneda_id) do
        {:error, _} -> alta_cuenta_interna(cuenta_destino_id, moneda_id, 0)
        :ok -> nil
      end

      changeset =
        %__MODULE__{}
        |> changeset_crear(%{
          tipo: "transferencia",
          cuenta_origen_id: cuenta_origen_id,
          cuenta_destino_id: cuenta_destino_id,
          moneda_origen_id: moneda_id,
          moneda_destino_id: moneda_id,
          monto: monto
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
          monto: monto
        })

      case Repo.insert(changeset) do
        {:ok, transaccion} ->
          {:ok, transaccion}

        {:error, _razon} ->
          {:error, FileHandler.extraer_error(changeset)}
      end
    end
  end

  def deshacer_transaccion(transaccion_id) do
    case Repo.get(Ledger.Transaccion, transaccion_id) do
      nil ->
        {:error, "Transaccion no encontrada"}

      t ->
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

  def listar_transacciones(c1, c2, _o) do
    with {:ok, transacciones} <- obtener_transacciones(c1, c2) do
      Enum.each(transacciones, fn t ->
        IO.puts("""
        ----------------------------
        Id: #{t.id}
        Tipo: #{t.tipo}
        Monto: #{t.monto}
        Id cuenta origen: #{t.cuenta_origen_id}
        Id cuenta destino: #{t.cuenta_destino_id}
        Id moneda origen: #{t.moneda_origen_id}
        Id moneda destino: #{t.moneda_destino_id}
        Fecha: #{t.inserted_at}
        ----------------------------
        """)
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
        with {:ok, moneda} <- Moneda.obtener_moneda(moneda_id) do
          balance_en_moneda = cambiar_balance_a_moneda(balance_actualizado, moneda.id)
          FileHandler.mostrar_balance(balance_en_moneda, archivo)
        end
      else
        FileHandler.mostrar_balance(balance_actualizado, archivo)
      end
    end

    {:ok, nil}
  end

  def changeset_crear(transaccion, attrs) do
    transaccion
    |> cast(attrs, [
      :tipo,
      :cuenta_origen_id,
      :moneda_origen_id,
      :monto
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

    case tipo do
      "alta" ->
        changeset
        |> validate_number(:monto,
          greater_than_or_equal_to: 0,
          message: "El monto debe ser un número positivo"
        )
        |> foreign_key_constraint(:cuenta_origen_id)
        |> foreign_key_constraint(:moneda_origen_id)
        |> validar_cuenta_no_existe()

      "transferencia" ->
        changeset
        |> cast(attrs, [:cuenta_destino_id, :moneda_destino_id])
        |> validate_required([:cuenta_destino_id, :moneda_destino_id])
        |> validate_number(:monto,
          greater_than: 0,
          message: "El monto debe ser un número positivo"
        )
        |> foreign_key_constraint(:cuenta_origen_id)
        |> foreign_key_constraint(:cuenta_destino_id)
        |> foreign_key_constraint(:moneda_origen_id)
        |> foreign_key_constraint(:moneda_destino_id)

      "swap" ->
        changeset
        |> cast(attrs, [:moneda_destino_id])
        |> validate_number(:monto,
          greater_than: 0,
          message: "El monto debe ser un número positivo"
        )
        |> foreign_key_constraint(:cuenta_origen_id)
        |> foreign_key_constraint(:moneda_origen_id)
        |> foreign_key_constraint(:moneda_destino_id)
        |> validar_saldo_sufieciente()

      _ ->
        add_error(changeset, :tipo, "Tipo de transacción inválido")
    end
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

    saldo = calcular_balance_para_moneda(usuario_id, moneda_id)

    if saldo < monto do
      add_error(changeset, :monto, "Saldo insuficiente")
    else
      changeset
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
          monto: monto
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
    case Usuario.obtener_usuario(cuenta_id) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, "Se proporcionó una cuenta inexistente"}
    end
  end

  defp calcular_balance_para_moneda(cuenta_id, moneda_id) do
    with {:ok, transacciones_salientes} <- obtener_transacciones(cuenta_id, ""),
         {:ok, transacciones_entrantes} <- obtener_transacciones("", cuenta_id) do
      balance = %{}

      (transacciones_salientes ++ transacciones_entrantes)
      |> Enum.reduce(balance, fn t, acc -> calcular_balance(acc, t, cuenta_id) end)
      |> Map.get(moneda_id, 0.0)
    end
  end

  defp calcular_balance(balance, t, cuenta_id) do
    cond do
      t.tipo == "alta" ->
        balance_actualizado =
          Map.update(balance, t.moneda_origen_id, t.monto, fn monto_actual ->
            monto_actual + t.monto
          end)

        balance_actualizado

      t.tipo == "transferencia" and t.cuenta_origen_id == cuenta_id ->
        balance_actualizado =
          Map.update(balance, t.moneda_origen_id, t.monto, fn monto_actual ->
            monto_actual - t.monto
          end)

        balance_actualizado

      t.tipo == "transferencia" and t.cuenta_destino_id == cuenta_id ->
        balance_actualizado =
          Map.update(balance, t.moneda_origen_id, t.monto, fn monto_actual ->
            monto_actual + t.monto
          end)

        balance_actualizado

      t.tipo == "swap" ->
        balance_actualizado =
          Map.update(balance, t.moneda_origen_id, t.monto, fn monto_actual ->
            monto_actual - t.monto
          end)
          |> Map.update(t.moneda_destino_id, t.monto, fn monto_actual ->
            with {:ok, monto_cambiado} <-
                   Moneda.cambiar_a_moneda(t.monto, t.moneda_origen_id, t.moneda_destino_id) do
              monto_actual + monto_cambiado
            end
          end)

        balance_actualizado

      true ->
        balance
    end
  end

  defp cambiar_balance_a_moneda(balance, moneda_id) do
    total =
      Enum.reduce(balance, 0.0, fn {moneda_actual_id, monto}, acc ->
        with {:ok, monto_cambiado} <-
               Moneda.cambiar_a_moneda(monto, moneda_actual_id, moneda_id) do
          acc + monto_cambiado
        end
      end)

    %{moneda_id => total}
  end
end
