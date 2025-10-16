defmodule LedgerTest do
  import ExUnit.CaptureIO
  use ExUnit.Case, async: false
  # , Repo}
  alias Ledger.{Usuario, FileHandler, Moneda, Transaccion, CLI}

  @archivo_tmp Path.join("test_tmp", "archivo_tmp.txt")

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Ledger.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Ledger.Repo, {:shared, self()})

    Ledger.Repo.delete_all(Ledger.Usuario)
    Ledger.Repo.delete_all(Ledger.Moneda)
    Ledger.Repo.delete_all(Ledger.Transaccion)
    File.write!(@archivo_tmp, "")

    :ok
  end

  describe "Tests para Ledger.Usuario" do
    test "crear_usuario válido" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1900-05-06")
      assert {usuario.nombre, usuario.fecha_nacimiento} == {"userA", ~D[1900-05-06]}
    end

    test "crear_usuario con nombre vacío" do
      assert {:error, "El nombre es obligatorio"} ==
               Usuario.crear_usuario("", "1900-05-06")
    end

    test "crear_usuario con fecha inválida" do
      assert {:error, "Fecha de nacimiento inválida. Formato esperado: AAAA-MM-DD"} ==
               Usuario.crear_usuario("userA", "")

      assert {:error, "Fecha de nacimiento inválida. Formato esperado: AAAA-MM-DD"} ==
               Usuario.crear_usuario("userA", "05-06-1999")
    end

    test "crear_usuario con minoría de edad" do
      assert {:error, "El usuario debe ser mayor de edad"} ==
               Usuario.crear_usuario("userA", "2025-05-06")
    end

    test "crar_usuario con nombre en uso" do
      Usuario.crear_usuario("userA", "1990-05-06")

      assert {:error, "El nombre ya está en uso"} ==
               Usuario.crear_usuario("userA", "1991-05-06")
    end

    test "editar_usuario con id y nombre válidos" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario_editado} = Usuario.editar_usuario(usuario.id, "userB")
      assert {usuario_editado.nombre} == {"userB"}
    end

    test "editar_usuario con id inexistente" do
      assert {:error, "Usuario no encontrado"} == Usuario.editar_usuario(1, "userB")
    end

    test "editar_usuario con mismo nombre" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")

      assert {:error, "El nuevo nombre debe ser distinto al actual"} ==
               Usuario.editar_usuario(usuario.id, "userA")
    end

    test "editar_usuario con un nombre ya en uso" do
      Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-07")
      assert {:error, "El nombre ya está en uso"} == Usuario.editar_usuario(usuario2.id, "userA")
    end

    test "editar_usuario con nombre vacío" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")

      assert {:error, "El nombre es obligatorio"} ==
               Usuario.editar_usuario(usuario.id, "")
    end

    test "ver_usuario con usuario válido" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Usuario.ver_usuario(usuario.id, "stdout")
        end)

      assert String.contains?(output, "USUARIO #{usuario.id}")
      assert String.contains?(output, "Nombre: userA")
      assert String.contains?(output, "Fecha de Nacimiento: 1990-05-06")
      assert String.contains?(output, "Creado:")
      assert String.contains?(output, "Modificado:")
    end

    test "ver_usuario con usuario inexistente" do
      assert {:error, "Usuario no encontrado"} == Usuario.ver_usuario(1, @archivo_tmp)
    end

    test "borrar_usuario borra usuario válido" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      assert {:ok, "Usuario borrado exitosamente"} == Usuario.borrar_usuario(usuario.id)
      assert {:error, "Usuario no encontrado"} == Usuario.ver_usuario(usuario.id, @archivo_tmp)
    end

    test "borrar_usuario con usuario inexistente" do
      assert {:error, "Usuario no encontrado"} == Usuario.borrar_usuario(1)
    end

    test "borrar_usuario con transacciones asociadas" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda1.id, 5)
      {:ok, _} = Transaccion.realizar_swap(usuario.id, moneda1.id, moneda2.id, 5)

      assert {:error, "El usuario tiene transacciones asociadas"} ==
               Usuario.borrar_usuario(usuario.id)
    end
  end

  describe "Tests para Ledger.Moneda" do
    test "crear_moneda válido" do
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      assert {moneda.nombre, moneda.precio_usd} == {"EUR", 1.18}

      {:ok, moneda} = Moneda.crear_moneda("BTC", "55000")
      assert {moneda.nombre, moneda.precio_usd} == {"BTC", 55000}
    end

    test "crear_moneda con nombre vacío" do
      assert {:error, "El nombre es obligatorio"} ==
               Moneda.crear_moneda("", "1.18")
    end

    test "crear_moneda con precio inválido" do
      assert {:error, "El precio en dólares es obligatorio"} ==
               Moneda.crear_moneda("EUR", "")

      assert {:error, "El precio debe ser un número positivo"} ==
               Moneda.crear_moneda("EUR", "0")

      assert {:error, "El precio debe ser un número positivo"} ==
               Moneda.crear_moneda("EUR", "-1")
    end

    test "crear_moneda con largo de nombre inválido" do
      assert {:error, "El nombre de la moneda debe tener entre 3 y 4 caracteres"} ==
               Moneda.crear_moneda("EU", "1.18")

      assert {:error, "El nombre de la moneda debe tener entre 3 y 4 caracteres"} ==
               Moneda.crear_moneda("EUROS", "1.18")
    end

    test "crear_moneda con nombre en uso" do
      Moneda.crear_moneda("EUR", "1.18")

      assert {:error, "El nombre ya está en uso"} ==
               Moneda.crear_moneda("EUR", "1.19")
    end

    test "obtener_moneda válido" do
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      assert {:ok, moneda} == Moneda.obtener_moneda(moneda.id)
    end

    test "obtener_moneda con ID inválido" do
      assert {:error, "Moneda no encontrada"} == Moneda.obtener_moneda(1)
    end

    test "editar_moneda con id y precio válidos" do
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda_editada} = Moneda.editar_moneda(moneda.id, "1.20")
      assert {moneda_editada.precio_usd} == {1.20}
    end

    test "editar_moneda con id inválido" do
      assert {:error, "Moneda no encontrada"} == Moneda.editar_moneda(1, "userB")
    end

    test "editar_moneda con precio inválido" do
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")

      assert {:error, "El precio es obligatorio"} ==
               Moneda.editar_moneda(moneda.id, "")

      assert {:error, "El precio debe ser un número positivo"} ==
               Moneda.editar_moneda(moneda.id, "0")

      assert {:error, "El precio debe ser un número positivo"} ==
               Moneda.editar_moneda(moneda.id, "-1")
    end

    test "ver_moneda con moneda válida" do
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Moneda.ver_moneda(moneda.id, "stdout")
        end)

      assert String.contains?(output, "MONEDA #{moneda.id}")
      assert String.contains?(output, "Nombre: EUR")
      assert String.contains?(output, "Precio: 1.18")
    end

    test "ver_moneda con moneda inexistente" do
      assert {:error, "Moneda no encontrada"} == Moneda.ver_moneda(1, @archivo_tmp)
    end

    test "borrar_moneda borra moneda válida" do
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      assert {:ok, "Moneda borrada exitosamente"} == Moneda.borrar_moneda(moneda.id)
      assert {:error, "Moneda no encontrada"} == Moneda.ver_moneda(moneda.id, @archivo_tmp)
    end

    test "borrar_moneda con moneda inexistente" do
      assert {:error, "Moneda no encontrada"} == Moneda.borrar_moneda(1)
    end

    test "borrar_moneda con transacciones asociadas" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda1.id, 5)
      {:ok, _} = Transaccion.realizar_swap(usuario.id, moneda1.id, moneda2.id, 5)

      assert {:error, "La moneda tiene transacciones asociadas"} ==
               Moneda.borrar_moneda(moneda1.id)
    end

    test "cambiar_a_moneda con cambio entero" do
      {:ok, moneda1} = Moneda.crear_moneda("AAA", "1")
      {:ok, moneda2} = Moneda.crear_moneda("BBB", "2")

      assert {:ok, 5} == Moneda.cambiar_a_moneda(10, moneda1.id, moneda2.id)
    end

    test "cambiar_a_moneda con montos decimales" do
      {:ok, moneda1} = Moneda.crear_moneda("AAA", "0.5")
      {:ok, moneda2} = Moneda.crear_moneda("BBB", "0.2")

      assert {:ok, 0.25} == Moneda.cambiar_a_moneda(0.1, moneda1.id, moneda2.id)
    end

    test "obtener_nombre de moneda válida" do
      {:ok, moneda} = Moneda.crear_moneda("ASD", "1")
      assert "ASD" == Moneda.obtener_nombre(moneda.id)
    end

    test "obtener_nombre de moneda inválida" do
      assert {:error, "Moneda no encontrada"} == Moneda.obtener_nombre(1)
    end
  end

  describe "Tests para Ledger.Transaccion" do
    test "alta_cuenta válido" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, transaccion} = Transaccion.alta_cuenta(usuario.id, moneda.id, 5)

      assert {transaccion.tipo, transaccion.cuenta_origen_id, transaccion.moneda_origen_id,
              transaccion.monto} ==
               {"alta", usuario.id, moneda.id, 5}
    end

    test "alta_cuenta con monto float" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, transaccion} = Transaccion.alta_cuenta(usuario.id, moneda.id, 5.56)

      assert {transaccion.tipo, transaccion.cuenta_origen_id, transaccion.moneda_origen_id,
              transaccion.monto} ==
               {"alta", usuario.id, moneda.id, 5.56}
    end

    test "alta_cuenta con usuario y moneda inexistentes" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")

      assert {:error, "Usuario no encontrado"} ==
               Transaccion.alta_cuenta(usuario.id + 1, moneda.id, 5)

      assert {:error, "Moneda no encontrada"} ==
               Transaccion.alta_cuenta(usuario.id, moneda.id + 1, 5)
    end

    test "alta_cuenta con monto inválido" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")

      assert {:error, "El monto debe ser un número positivo"} ==
               Transaccion.alta_cuenta(usuario.id, moneda.id, 0)

      assert {:error, "El monto debe ser un número positivo"} ==
               Transaccion.alta_cuenta(usuario.id, moneda.id, -1)
    end

    test "alta_cuenta con una cuenta preexistente" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda.id, 5)

      assert {:error, "Ya existe una cuenta para este usuario y moneda"} ==
               Transaccion.alta_cuenta(usuario.id, moneda.id, 6)
    end

    test "alta_cuenta de diferentes cuentas con mismo usuario" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, transaccion1} = Transaccion.alta_cuenta(usuario.id, moneda1.id, 5)
      {:ok, transaccion2} = Transaccion.alta_cuenta(usuario.id, moneda2.id, 5)

      assert {transaccion1.tipo, transaccion1.cuenta_origen_id, transaccion1.moneda_origen_id,
              transaccion1.monto} ==
               {"alta", usuario.id, moneda1.id, 5}

      assert {transaccion2.tipo, transaccion2.cuenta_origen_id, transaccion2.moneda_origen_id,
              transaccion2.monto} ==
               {"alta", usuario.id, moneda2.id, 5}
    end

    test "realizar_swap válido" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda1.id, 5)
      {:ok, transaccion2} = Transaccion.realizar_swap(usuario.id, moneda1.id, moneda2.id, 5)

      assert {transaccion2.tipo, transaccion2.cuenta_origen_id, transaccion2.moneda_origen_id,
              transaccion2.moneda_destino_id,
              transaccion2.monto} ==
               {"swap", usuario.id, moneda1.id, moneda2.id, 5}
    end

    test "realizar_swap con usuario inexistente" do
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")

      assert {:error, "Usuario no encontrado"} ==
               Transaccion.realizar_swap(1, moneda1.id, moneda2.id, 5)
    end

    test "realizar_swap con moneda inválida" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, moneda3} = Moneda.crear_moneda("BTC", "55000")
      moneda_borrada_id = moneda3.id
      {:ok, _} = Moneda.borrar_moneda(moneda_borrada_id)

      assert {:error, "Moneda no encontrada"} ==
               Transaccion.realizar_swap(usuario.id, moneda_borrada_id, moneda2.id, 5)

      assert {:error, "Moneda no encontrada"} ==
               Transaccion.realizar_swap(usuario.id, moneda1.id, moneda_borrada_id, 5)
    end

    test "realizar_swap con cuenta inexistente" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")

      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")

      assert {:error, "No hay una cuenta asociada con esa moneda"} ==
               Transaccion.realizar_swap(usuario.id, moneda1.id, moneda2.id, 5)
    end

    test "realizar_swap con monto inválido" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda1.id, 5)

      assert {:error, "El monto debe ser un número positivo"} ==
               Transaccion.realizar_swap(usuario.id, moneda1.id, moneda2.id, 0)

      assert {:error, "El monto debe ser un número positivo"} ==
               Transaccion.realizar_swap(usuario.id, moneda1.id, moneda2.id, -1)
    end

    test "realizar_swap con saldo insuficiente" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda1.id, 5)

      assert {:error, "Saldo insuficiente"} ==
               Transaccion.realizar_swap(usuario.id, moneda1.id, moneda2.id, 10)
    end

    test "realizar_transferencia válida con cuentas existentes" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-07")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario2.id, moneda.id, 5)

      {:ok, transaccion} =
        Transaccion.realizar_transferencia(usuario1.id, usuario2.id, moneda.id, 1)

      assert {transaccion.tipo, transaccion.cuenta_origen_id, transaccion.cuenta_destino_id,
              transaccion.moneda_origen_id,
              transaccion.monto} == {"transferencia", usuario1.id, usuario2.id, moneda.id, 1}
    end

    test "realizar_transferencia válida con cuenta destino inexistente" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-07")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda.id, 5)

      {:ok, transaccion} =
        Transaccion.realizar_transferencia(usuario1.id, usuario2.id, moneda.id, 1)

      assert {transaccion.tipo, transaccion.cuenta_origen_id, transaccion.cuenta_destino_id,
              transaccion.moneda_origen_id,
              transaccion.monto} == {"transferencia", usuario1.id, usuario2.id, moneda.id, 1}
    end

    test "realizar_transferencia con usuarios inexistentes" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda.id, 5)

      assert {:error, "Usuario no encontrado"} ==
               Transaccion.realizar_transferencia(usuario.id + 1, usuario.id, moneda.id, 1)

      assert {:error, "Usuario no encontrado"} ==
               Transaccion.realizar_transferencia(usuario.id, usuario.id + 1, moneda.id, 1)
    end

    test "realizar_transferencia con moneda inexistente" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-07")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario2.id, moneda.id, 5)

      assert {:error, "Moneda no encontrada"} ==
               Transaccion.realizar_transferencia(usuario1.id, usuario2.id, moneda.id + 1, 1)
    end

    test "realizar_transferencia con monto inválido" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-07")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario2.id, moneda.id, 5)

      assert {:error, "El monto debe ser un número positivo"} ==
               Transaccion.realizar_transferencia(usuario1.id, usuario2.id, moneda.id, 0)

      assert {:error, "El monto debe ser un número positivo"} ==
               Transaccion.realizar_transferencia(usuario1.id, usuario2.id, moneda.id, -1)
    end

    test "realizar_transferencia con saldo insuficiente" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-07")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario2.id, moneda.id, 5)

      assert {:error, "Saldo insuficiente"} ==
               Transaccion.realizar_transferencia(usuario1.id, usuario2.id, moneda.id, 10)
    end

    test "ver_transaccion con transaccion válida" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, transaccion} = Transaccion.alta_cuenta(usuario.id, moneda.id, 5)

      output =
        capture_io(fn ->
          Transaccion.ver_transaccion(transaccion.id, "stdout")
        end)

      assert String.contains?(output, [
               "TRANSACCIÓN #{transaccion.id}",
               "alta",
               "#{transaccion.cuenta_origen_id}",
               "#{transaccion.moneda_origen_id}",
               "#{transaccion.monto}",
               "#{transaccion.inserted_at}",
               "#{transaccion.updated_at}"
             ])
    end

    test "ver_transaccion con transaccion inexistente" do
      assert {:error, "Transaccion no encontrada"} == Transaccion.ver_transaccion(1, @archivo_tmp)
    end

    test "deshacer_transaccion válido con ambas cuentas existentes deshace swap" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda1.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda2.id, 5)
      {:ok, transaccion1} = Transaccion.realizar_swap(usuario.id, moneda1.id, moneda2.id, 5)
      {:ok, transaccion2} = Transaccion.deshacer_transaccion(transaccion1.id)

      assert {"swap", usuario.id, moneda2.id, moneda1.id, 5} ==
               {transaccion2.tipo, transaccion2.cuenta_origen_id, transaccion2.moneda_origen_id,
                transaccion2.moneda_destino_id, transaccion2.monto}
    end

    test "deshacer_transaccion válido con cuenta destino inexistente deshace swap" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda1.id, 5)
      {:ok, transaccion1} = Transaccion.realizar_swap(usuario.id, moneda1.id, moneda2.id, 5)
      {:ok, transaccion2} = Transaccion.deshacer_transaccion(transaccion1.id)

      assert {"swap", usuario.id, moneda2.id, moneda1.id, 5} ==
               {transaccion2.tipo, transaccion2.cuenta_origen_id, transaccion2.moneda_origen_id,
                transaccion2.moneda_destino_id, transaccion2.monto}
    end

    test "deshacer_transaccion a swap con id inválido" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda1.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda2.id, 5)

      assert {:error, "Transaccion no encontrada"} == Transaccion.deshacer_transaccion(99999)
    end

    test "deshacer_transaccion válido con ambas cuentas existentes deshace transferencia" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-06")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario2.id, moneda.id, 5)

      {:ok, transaccion1} =
        Transaccion.realizar_transferencia(usuario1.id, usuario2.id, moneda.id, 1)

      {:ok, transaccion2} = Transaccion.deshacer_transaccion(transaccion1.id)

      assert {"transferencia", usuario2.id, usuario1.id, moneda.id, 1} ==
               {transaccion2.tipo, transaccion2.cuenta_origen_id, transaccion2.cuenta_destino_id,
                transaccion2.moneda_origen_id, transaccion2.monto}
    end

    test "deshacer_transaccion válido con cuenta destino inexistente deshace transferencia" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-06")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda.id, 5)

      {:ok, transaccion1} =
        Transaccion.realizar_transferencia(usuario1.id, usuario2.id, moneda.id, 1)

      {:ok, transaccion2} = Transaccion.deshacer_transaccion(transaccion1.id)

      assert {"transferencia", usuario2.id, usuario1.id, moneda.id, 1} ==
               {transaccion2.tipo, transaccion2.cuenta_origen_id, transaccion2.cuenta_destino_id,
                transaccion2.moneda_origen_id, transaccion2.monto}
    end

    test "deshacer_transaccion a transferencia con id inválido" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-06")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario2.id, moneda.id, 5)

      assert {:error, "Transaccion no encontrada"} == Transaccion.deshacer_transaccion(99999)
    end

    test "deshacer_transaccion a alta_cuenta" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, transaccion} = Transaccion.alta_cuenta(usuario.id, moneda.id, 5)

      assert {:error, "No se puede deshacer un alta de cuenta"} ==
               Transaccion.deshacer_transaccion(transaccion.id)
    end

    test "obtener_transacciones sin filtros" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda1.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda2.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario2.id, moneda1.id, 5)
      {:ok, _} = Transaccion.realizar_swap(usuario1.id, moneda1.id, moneda2.id, 5)
      {:ok, _} = Transaccion.realizar_transferencia(usuario2.id, usuario1.id, moneda1.id, 1)

      {:ok, transacciones} = Transaccion.obtener_transacciones("", "")
      assert length(transacciones) == 5
    end

    test "obtener_transacciones con según cuenta origen" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda1.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda2.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario2.id, moneda1.id, 5)
      {:ok, _} = Transaccion.realizar_swap(usuario1.id, moneda1.id, moneda2.id, 5)

      {:ok, transacciones} = Transaccion.obtener_transacciones(usuario1.id, "")
      assert length(transacciones) == 3
    end

    test "obtener_transacciones con según cuenta destino" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda1.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario2.id, moneda1.id, 5)
      {:ok, _} = Transaccion.realizar_transferencia(usuario1.id, usuario2.id, moneda1.id, 1)

      {:ok, transacciones} = Transaccion.obtener_transacciones("", usuario2.id)
      assert length(transacciones) == 1
    end

    test "obtener_transacciones con según cuenta origen y destino" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda1.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario2.id, moneda1.id, 5)
      {:ok, _} = Transaccion.realizar_transferencia(usuario1.id, usuario2.id, moneda1.id, 1)
      {:ok, _} = Transaccion.realizar_transferencia(usuario2.id, usuario1.id, moneda1.id, 1)

      {:ok, transacciones} = Transaccion.obtener_transacciones(usuario1.id, usuario2.id)
      assert length(transacciones) == 1
    end

    test "obtener_transacciones con usuarios inexistentes" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")

      assert {:error, "Usuario no encontrado"} ==
               Transaccion.obtener_transacciones(usuario.id + 1, "")

      assert {:error, "Usuario no encontrado"} ==
               Transaccion.obtener_transacciones("", usuario.id + 1)

      assert {:error, "Usuario no encontrado"} ==
               Transaccion.obtener_transacciones(usuario.id + 1, usuario.id + 1)
    end

    test "listar_transacciones muestra transacciones en stdout" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda1.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda2.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario2.id, moneda1.id, 5)
      {:ok, _} = Transaccion.realizar_swap(usuario1.id, moneda1.id, moneda2.id, 5)
      {:ok, _} = Transaccion.realizar_transferencia(usuario2.id, usuario1.id, moneda1.id, 1)

      output =
        capture_io(fn ->
          {:ok, transacciones} = Transaccion.listar_transacciones(usuario1.id, "", "stdout")
          assert length(transacciones) == 3
        end)

      assert String.contains?(output, "TRANSACCIÓN")
      assert String.contains?(output, "alta")
      assert String.contains?(output, "swap")
    end

    test "listar_transacciones muestra transacciones en archivo" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda1.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda2.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario2.id, moneda1.id, 5)
      {:ok, _} = Transaccion.realizar_swap(usuario1.id, moneda1.id, moneda2.id, 5)
      {:ok, _} = Transaccion.realizar_transferencia(usuario2.id, usuario1.id, moneda1.id, 1)

      {:ok, transacciones} = Transaccion.listar_transacciones(usuario1.id, "", @archivo_tmp)
      assert length(transacciones) == 3
      contenido = File.read!(@archivo_tmp)
      assert String.contains?(contenido, "TRANSACCIÓN")
      assert String.contains?(contenido, "alta")
      assert String.contains?(contenido, "swap")
    end

    test "listar_balance en stdout" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda1.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda2.id, 2)

      output =
        capture_io(fn ->
          {:ok, balance} = Transaccion.listar_balance(usuario.id, "", "stdout")
          assert balance == %{moneda1.id => 5.0, moneda2.id => 2.0}
        end)

      assert String.contains?(output, "EUR=5.000000")
      assert String.contains?(output, "USDT=2.000000")
    end

    test "listar_balance en archivo" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda1.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda2.id, 2)

      {:ok, balance} = Transaccion.listar_balance(usuario.id, "", @archivo_tmp)
      assert balance == %{moneda1.id => 5.0, moneda2.id => 2.0}
      contenido = File.read!(@archivo_tmp)

      assert String.contains?(contenido, "EUR=5.000000")
      assert String.contains?(contenido, "USDT=2.000000")
    end

    test "listar_balance con total en una moneda" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda1.id, 1)
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda2.id, 1)

      output =
        capture_io(fn ->
          {:ok, balance} = Transaccion.listar_balance(usuario.id, moneda2.id, "stdout")
          assert 2.18 == Float.round(balance[moneda2.id], 2)
        end)

      assert String.contains?(output, "USDT=2.180000")
    end

    test "listar_balance con usuario inexistente" do
      assert {:error, "Usuario no encontrado"} == Transaccion.listar_balance(1, "", "stdout")
    end

    test "listar_balance con usuario sin cuentas" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, balance} = Transaccion.listar_balance(usuario.id, "", @archivo_tmp)
      assert balance == %{}
    end
  end

  describe "Tests para Ledger.FileHandler" do
    test "mostrar_balance muestra balance en stdout" do
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      balance = %{moneda1.id => 5.0, moneda2.id => 2.0}

      contenido =
        capture_io(fn ->
          FileHandler.mostrar_balance(balance, "stdout")
        end)

      assert String.contains?(contenido, "EUR=5.000000")
      assert String.contains?(contenido, "USDT=2.000000")
    end

    test "mostrar_balance escribe balance en archivo" do
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      balance = %{moneda1.id => 5.0, moneda2.id => 2.0}
      FileHandler.mostrar_balance(balance, @archivo_tmp)
      contenido = File.read!(@archivo_tmp)

      assert String.contains?(contenido, "EUR=5.000000")
      assert String.contains?(contenido, "USDT=2.000000")
    end

    test "mostrar_usuario muestra usuario en stdout" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")

      contenido =
        capture_io(fn ->
          FileHandler.mostrar_usuario(usuario, "stdout")
        end)

      assert String.contains?(contenido, [
               to_string(usuario.id),
               usuario.nombre,
               Date.to_iso8601(usuario.fecha_nacimiento),
               NaiveDateTime.to_iso8601(usuario.inserted_at),
               NaiveDateTime.to_iso8601(usuario.updated_at)
             ])
    end

    test "mostrar_usuario escribe usuario en archivo" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      FileHandler.mostrar_usuario(usuario, @archivo_tmp)
      contenido = File.read!(@archivo_tmp)

      assert String.contains?(contenido, [
               to_string(usuario.id),
               usuario.nombre,
               Date.to_iso8601(usuario.fecha_nacimiento),
               NaiveDateTime.to_iso8601(usuario.inserted_at),
               NaiveDateTime.to_iso8601(usuario.updated_at)
             ])
    end

    test "mostrar_moneda muestra moneda en stdout" do
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")

      contenido =
        capture_io(fn ->
          FileHandler.mostrar_moneda(moneda, "stdout")
        end)

      assert String.contains?(contenido, [
               to_string(moneda.id),
               moneda.nombre,
               to_string(moneda.precio_usd),
               NaiveDateTime.to_iso8601(moneda.inserted_at),
               NaiveDateTime.to_iso8601(moneda.updated_at)
             ])
    end

    test "mostrar_moneda escribe moneda en archivo" do
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      FileHandler.mostrar_moneda(moneda, @archivo_tmp)
      contenido = File.read!(@archivo_tmp)

      assert String.contains?(contenido, [
               to_string(moneda.id),
               moneda.nombre,
               to_string(moneda.precio_usd),
               NaiveDateTime.to_iso8601(moneda.inserted_at),
               NaiveDateTime.to_iso8601(moneda.updated_at)
             ])
    end

    test "mostrar_error muestra error en stdout" do
      contenido =
        capture_io(fn ->
          FileHandler.mostrar_error("Este es un mensaje de error")
        end)

      assert "{:error, Este es un mensaje de error}\n" == contenido
    end
  end

  describe "Tests para Ledger.CLI" do
    test "procesar_argumentos sin arguemntos" do
      assert {:error, "No se proporcionó ningún comando"} == CLI.procesar_argumentos([])
    end

    test "procesar_argumentos con comando inválido" do
      args = ["ruleta", "-c1=2"]
      assert {:error, "ruleta: El comando no es válido"} == CLI.procesar_argumentos(args)
    end

    test "comando válido sin flags" do
      assert {:ok, %{"comando" => "crear_usuario"}} == CLI.procesar_argumentos(["crear_usuario"])
    end

    test "comando válido con flags" do
      args = ["crear_usuario", "-n=Juan", "-b=1990-05-06"]

      assert {:ok,
              %{
                "comando" => "crear_usuario",
                "n" => "Juan",
                "b" => "1990-05-06"
              }} == CLI.procesar_argumentos(args)
    end

    test "efectuar_comando con comando crear_usuario" do
      flags_ok = %{"comando" => "crear_usuario", "n" => "Juan", "b" => "1990-05-06"}
      {res_ok, _} = CLI.efectuar_comando(flags_ok)
      flags_err = %{"comando" => "crear_usuario", "n" => "", "b" => "1990-05-06"}
      {res_err, razon} = CLI.efectuar_comando(flags_err)

      assert :ok == res_ok
      assert :error == res_err
      assert String.contains?(razon, "crear_usuario")
    end

    test "efectuar_comando con comando editar_usuario" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      flags_ok = %{"comando" => "editar_usuario", "id" => "#{usuario.id}", "n" => "Pedro"}
      {res_ok, _} = CLI.efectuar_comando(flags_ok)
      flags_err = %{"comando" => "editar_usuario", "id" => "9999", "n" => "Pedro"}
      {res_err, razon} = CLI.efectuar_comando(flags_err)

      assert :ok == res_ok
      assert :error == res_err
      assert String.contains?(razon, "editar_usuario")
    end

    test "efectuar_comando con comando borrar_usuario" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      flags_ok = %{"comando" => "borrar_usuario", "id" => "#{usuario.id}"}
      {res_ok, _} = CLI.efectuar_comando(flags_ok)
      flags_err = %{"comando" => "borrar_usuario", "id" => "9999"}
      {res_err, razon} = CLI.efectuar_comando(flags_err)

      assert :ok == res_ok
      assert :error == res_err
      assert String.contains?(razon, "borrar_usuario")
    end

    test "efectuar_comando con ver_usuario" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      flags_ok = %{"comando" => "ver_usuario", "id" => "#{usuario.id}", "out" => @archivo_tmp}
      {res_ok, _} = CLI.efectuar_comando(flags_ok)
      flags_err = %{"comando" => "ver_usuario", "id" => "9999", "out" => @archivo_tmp}
      {res_err, razon} = CLI.efectuar_comando(flags_err)

      assert :ok == res_ok
      assert :error == res_err
      assert String.contains?(razon, "ver_usuario")
    end

    test "efectuar_comando con comando crear_moneda" do
      flags_ok = %{"comando" => "crear_moneda", "n" => "EUR", "p" => "1.18"}
      {res_ok, _} = CLI.efectuar_comando(flags_ok)
      flags_err = %{"comando" => "crear_moneda", "n" => "", "p" => "1.18"}
      {res_err, razon} = CLI.efectuar_comando(flags_err)

      assert :ok == res_ok
      assert :error == res_err
      assert String.contains?(razon, "crear_moneda")
    end

    test "efectuar_comando con editar_moneda" do
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      flags_ok = %{"comando" => "editar_moneda", "id" => "#{moneda.id}", "p" => "1.20"}
      {res_ok, _} = CLI.efectuar_comando(flags_ok)
      flags_err = %{"comando" => "editar_moneda", "id" => "9999", "p" => "1.20"}
      {res_err, razon} = CLI.efectuar_comando(flags_err)

      assert :ok == res_ok
      assert :error == res_err
      assert String.contains?(razon, "editar_moneda")
    end

    test "efectuar_comando con comando borrar_moneda" do
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      flags_ok = %{"comando" => "borrar_moneda", "id" => "#{moneda.id}"}
      {res_ok, _} = CLI.efectuar_comando(flags_ok)
      flags_err = %{"comando" => "borrar_moneda", "id" => "9999"}
      {res_err, razon} = CLI.efectuar_comando(flags_err)

      assert :ok == res_ok
      assert :error == res_err
      assert String.contains?(razon, "borrar_moneda")
    end

    test "efectuar_comando con ver_moneda" do
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      flags_ok = %{"comando" => "ver_moneda", "id" => "#{moneda.id}", "out" => @archivo_tmp}
      {res_ok, _} = CLI.efectuar_comando(flags_ok)
      flags_err = %{"comando" => "ver_moneda", "id" => "9999", "out" => @archivo_tmp}
      {res_err, razon} = CLI.efectuar_comando(flags_err)

      assert :ok == res_ok
      assert :error == res_err
      assert String.contains?(razon, "ver_moneda")
    end

    test "efectuar_comando con comando alta_cuenta" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")

      flags_ok = %{
        "comando" => "alta_cuenta",
        "u" => "#{usuario.id}",
        "m" => "#{moneda.id}",
        "a" => "5"
      }

      {res_ok, _} = CLI.efectuar_comando(flags_ok)

      flags_err = %{
        "comando" => "alta_cuenta",
        "u" => "9999",
        "m" => "#{moneda.id}",
        "a" => "5"
      }

      {res_err, razon} = CLI.efectuar_comando(flags_err)

      assert :ok == res_ok
      assert :error == res_err
      assert String.contains?(razon, "alta_cuenta")
    end

    test "efectuar_comando con comando realizar_swap" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda1.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda2.id, 5)

      flags_ok = %{
        "comando" => "realizar_swap",
        "u" => "#{usuario.id}",
        "mo" => "#{moneda1.id}",
        "md" => "#{moneda2.id}",
        "a" => "5"
      }

      {res_ok, _} = CLI.efectuar_comando(flags_ok)

      flags_err = %{
        "comando" => "realizar_swap",
        "u" => "#{usuario.id}",
        "mo" => "#{moneda1.id}",
        "md" => "#{moneda2.id}",
        "a" => "10"
      }

      {res_err, razon} = CLI.efectuar_comando(flags_err)
      assert :ok == res_ok
      assert :error == res_err
      assert String.contains?(razon, "realizar_swap")
    end

    test "efectuar_comando con comando realizar_transferencia" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-07")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario2.id, moneda.id, 5)

      flags_ok = %{
        "comando" => "realizar_transferencia",
        "o" => "#{usuario1.id}",
        "d" => "#{usuario2.id}",
        "m" => "#{moneda.id}",
        "a" => "1"
      }

      {res_ok, _} = CLI.efectuar_comando(flags_ok)

      flags_err = %{
        "comando" => "realizar_transferencia",
        "o" => "#{usuario1.id}",
        "d" => "#{usuario2.id}",
        "m" => "#{moneda.id}",
        "a" => "10"
      }

      {res_err, razon} = CLI.efectuar_comando(flags_err)
      assert :ok == res_ok
      assert :error == res_err
      assert String.contains?(razon, "realizar_transferencia")
    end

    test "efectuar_comando con comando ver_transaccion" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, transaccion} = Transaccion.alta_cuenta(usuario.id, moneda.id, 5)

      flags_ok = %{
        "comando" => "ver_transaccion",
        "id" => "#{transaccion.id}",
        "out" => @archivo_tmp
      }

      {res_ok, _} = CLI.efectuar_comando(flags_ok)

      flags_err = %{
        "comando" => "ver_transaccion",
        "id" => "9999",
        "out" => @archivo_tmp
      }

      {res_err, razon} = CLI.efectuar_comando(flags_err)
      assert :ok == res_ok
      assert :error == res_err
      assert String.contains?(razon, "ver_transaccion")
    end

    test "efectuar_comando con comando deshacer_transaccion" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda1.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda2.id, 5)
      {:ok, transaccion} = Transaccion.realizar_swap(usuario.id, moneda1.id, moneda2.id, 5)

      flags_ok = %{
        "comando" => "deshacer_transaccion",
        "id" => "#{transaccion.id}"
      }

      {res_ok, _} = CLI.efectuar_comando(flags_ok)

      flags_err = %{
        "comando" => "deshacer_transaccion",
        "id" => "9999"
      }

      {res_err, razon} = CLI.efectuar_comando(flags_err)
      assert :ok == res_ok
      assert :error == res_err
      assert String.contains?(razon, "deshacer_transaccion")
    end

    test "efectuar_comando con comando transacciones" do
      {:ok, usuario1} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, usuario2} = Usuario.crear_usuario("userB", "1990-05-07")
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, _} = Transaccion.alta_cuenta(usuario1.id, moneda.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario2.id, moneda.id, 5)
      {:ok, _} = Transaccion.realizar_transferencia(usuario1.id, usuario2.id, moneda.id, 1)

      flags_ok = %{
        "comando" => "transacciones",
        "c1" => "#{usuario1.id}",
        "c2" => "#{usuario2.id}",
        "out" => @archivo_tmp
      }

      {res_ok, _} = CLI.efectuar_comando(flags_ok)

      flags_err = %{
        "comando" => "transacciones",
        "c1" => "#{usuario1.id}",
        "c2" => "9999",
        "out" => @archivo_tmp
      }

      {res_err, razon} = CLI.efectuar_comando(flags_err)
      assert :ok == res_ok
      assert :error == res_err
      assert String.contains?(razon, "transacciones")
    end

    test "efectuar_comando con comando balance" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      {:ok, moneda1} = Moneda.crear_moneda("EUR", "1.18")
      {:ok, moneda2} = Moneda.crear_moneda("USDT", "1")
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda1.id, 5)
      {:ok, _} = Transaccion.alta_cuenta(usuario.id, moneda2.id, 2)
      flags_ok = %{"comando" => "balance", "c1" => "#{usuario.id}", "out" => @archivo_tmp}
      {res_ok, _} = CLI.efectuar_comando(flags_ok)
      flags_err = %{"comando" => "balance", "c1" => "9999", "out" => @archivo_tmp}
      {res_err, razon} = CLI.efectuar_comando(flags_err)
      assert :ok == res_ok
      assert :error == res_err
      assert String.contains?(razon, "balance")
    end
  end

  describe "Tests para Ledger" do
    test "procesar_comandos con argumentos vacíos" do
      capture_io(fn ->
        assert {:error, "No se proporcionó ningún comando"} == Ledger.procesar_comandos([])
      end)
    end

    test "procesar_comandos con comando inválido" do
      args = ["ruleta", "-c1=2"]

      capture_io(fn ->
        assert {:error, "ruleta: El comando no es válido"} == Ledger.procesar_comandos(args)
      end)
    end

    test "procesar_comandos con comando válido" do
      args = ["crear_usuario", "-n=Juan", "-b=1990-05-06"]
      assert :ok == elem(Ledger.procesar_comandos(args), 0)
    end

    test "procesar_comandos con varios comandos válidos" do
      args = [
        "crear_usuario",
        "-n=Juan",
        "-b=1990-05-06",
        "crear_moneda",
        "-n=EUR",
        "-p=1.18"
      ]

      assert :ok == elem(Ledger.procesar_comandos(args), 0)
    end
  end
end
