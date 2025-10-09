defmodule Ledger.Transaccion do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Ledger.{Repo, Usuario, Moneda}

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
    # case Ledger.Cuenta.crear_cuenta(comando, usuario_id, moneda_id) do
    # {:ok, cuenta} ->
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
        # end

        # {:error, razon} ->
        # {:error, razon}
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
                where: t.cuenta_origen_id == ^String.to_integer(co)
              )

            {"", cd} ->
              from(t in query,
                where: t.cuenta_destino_id == ^String.to_integer(cd)
              )

            {co, cd} ->
              from(t in query,
                where:
                  t.cuenta_origen_id == ^String.to_integer(co) and
                    t.cuenta_destino_id == ^String.to_integer(cd)
              )
          end

        transacciones = Ledger.Repo.all(query)

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

  def listar_balance(comando, flags) do
    c1 = Map.get(flags, "c1", "")
    # m = Map.get(flags, "m", "")
    # o = Map.get(flags, "o", "stdout")
    balance = %{}

    case obtener_transacciones(c1, "") do
      {:error, razon} ->
        {:error, "#{comando}: #{razon}"}

      {:ok, transacciones_salientes} ->
        case obtener_transacciones("", c1) do
          {:error, razon} ->
            {:error, "#{comando}: #{razon}"}

          {:ok, transacciones_entrantes} ->
            balance_actualizado =
              (transacciones_salientes ++ transacciones_entrantes)
              |> Enum.sort_by(& &1.inserted_at, {:asc, NaiveDateTime})
              |> Enum.reduce(balance, fn t, acc -> calcular_balance(acc, t, c1) end)

            # TODO: cambiar a moneda si corresponde e imprimir
            IO.inspect(balance_actualizado)
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
    end
  end
end
