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
    |> validar_segun_tipo(attrs)
  end

  defp validar_segun_tipo(changeset, attrs) do
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

      _ ->
        add_error(changeset, :tipo, "Tipo de transacción inválido")
    end
  end

  # TODO: chequear si ya existe cuenta
  def alta_cuenta(comando, usuario_id, moneda_id, monto) do
    changeset =
      %__MODULE__{}
      |> changeset_crear(%{
        tipo: "alta",
        cuenta_origen_id: usuario_id,
        moneda_origen_id: moneda_id,
        monto: monto
      })

    case Repo.insert(changeset) do
      {:ok, transaccion} ->
        {:ok, transaccion}

      {:error, razon} ->
        {:error, "#{comando}: No se pudo crear la transacción: #{inspect(razon)}"}
    end
  end

  # def changeset_transferencia(transaccion, attrs) do
  #   transaccion
  #   |> cast(attrs, [
  #     :tipo,
  #     :cuenta_origen_id,
  #     :cuenta_destino_id,
  #     :moneda_origen_id,
  #     :moneda_destino_id,
  #     :monto
  #   ])
  #   |> validate_required([
  #     :tipo,
  #     :cuenta_origen_id,
  #     :cuenta_destino_id,
  #     :moneda_origen_id,
  #     :moneda_destino_id,
  #     :monto
  #   ])
  #   |> validar_segun_tipo()
  # end

  # TODO: verificar que tiene dinero para hacer la transferencia
  def realizar_transferencia(comando, cuenta_origen_id, cuenta_destino_id, moneda_id, monto) do
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

      {:error, razon} ->
        {:error, "#{comando}: #{inspect(razon)}"}
    end
  end

  def realizar_swap(
        comando,
        cuenta_id,
        moneda_origen_id,
        moneda_destino_id,
        monto
      ) do
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

      {:error, razon} ->
        {:error, "#{comando}: #{inspect(razon)}"}
    end
  end

  defp existe_cuenta?(cuenta_id) do
    case(Usuario.obtener_usuario(cuenta_id)) do
      nil ->
        false

      _cuenta ->
        true
    end
  end

  defp obtener_transacciones(cuenta_origen_id, cuenta_destino_id) do
    cond do
      (cuenta_origen_id == "" or existe_cuenta?(cuenta_origen_id)) and
          (cuenta_destino_id == "" or existe_cuenta?(cuenta_destino_id)) ->
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

      true ->
        {:error, "Se proporcionó una cuenta inexistente"}
    end
  end

  @doc """
  Lista las transacciones filtradas por cuentas y las muestra en el destino especificado.

  ## Parámetros
  - `flags`: Mapa con las opciones de filtrado y salida.
  - `cuentas`: Mapa con las cuentas existentes.
  ## Retorno
  - `{:ok, 0}` si la operación fue exitosa.
  - `{:error, razón}` si ocurrió algún error.
  """
  def listar_transacciones(comando, flags) do
    c1 = Map.get(flags, "c1", "")
    c2 = Map.get(flags, "c2", "")
    # o = Map.get(flags, "o", "stdout")
    case obtener_transacciones(c1, c2) do
      {:error, razon} ->
        {:error, "#{comando}: #{razon}"}

      {:ok, transacciones} ->
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
    end
  end

  def listar_balance(comando, cuenta_id, moneda_id, archivo) do
    balance = %{}

    case obtener_transacciones(cuenta_id, "") do
      {:error, razon} ->
        {:error, "#{comando}: #{razon}"}

      {:ok, transacciones_salientes} ->
        case obtener_transacciones("", cuenta_id) do
          {:error, razon} ->
            {:error, "#{comando}: #{razon}"}

          {:ok, transacciones_entrantes} ->
            balance_actualizado =
              (transacciones_salientes ++ transacciones_entrantes)
              |> Enum.sort_by(& &1.inserted_at, {:asc, NaiveDateTime})
              |> Enum.reduce(balance, fn t, acc -> calcular_balance(acc, t, cuenta_id) end)

            if moneda_id != "" do
              case Moneda.obtener_moneda(moneda_id) do
                nil ->
                  {:error, "#{comando}: Moneda inexistente"}

                moneda ->
                  balance_en_moneda = cambiar_balance_a_moneda(balance_actualizado, moneda.id)
                  FileHandler.mostrar_balance(balance_en_moneda, archivo)
              end
            else
              FileHandler.mostrar_balance(balance_actualizado, archivo)
            end

            {:ok, 0}
        end
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
            monto_actual +
              Moneda.cambiar_a_moneda(t.monto, t.moneda_origen_id, t.moneda_destino_id)
          end)

        balance_actualizado

      true ->
        balance
        # IO.puts("⚠️ Transacción desconocida o sin coincidencia:")
        # IO.inspect(t)
    end
  end

  defp cambiar_balance_a_moneda(balance, moneda_id) do
    total =
      Enum.reduce(balance, 0.0, fn {moneda_actual_id, monto}, acc ->
        acc + Moneda.cambiar_a_moneda(monto, moneda_actual_id, moneda_id)
      end)

    %{moneda_id => total}
  end
end
