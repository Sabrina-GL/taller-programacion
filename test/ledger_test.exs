defmodule LedgerTest do
  import ExUnit.CaptureIO
  use ExUnit.Case, async: false
  alias Ledger.{Repo, Usuario, FileHandler, Moneda, Transaccion}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Ledger.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Ledger.Repo, {:shared, self()})

    Ledger.Repo.delete_all(Ledger.Usuario)
    Ledger.Repo.delete_all(Ledger.Moneda)
    Ledger.Repo.delete_all(Ledger.Transaccion)

    :ok
  end

  # @monedas %{"BTC" => 55000.0, "USDT" => 1.0, "ARS" => 0.0012}
  @archivo_tmp Path.join("test_tmp", "archivo_tmp.csv")

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
      assert {:error, "Usuario no encontrado"} == Usuario.ver_usuario(1, "stdout")
    end

    test "borrar_usuario borra usuario válido" do
      {:ok, usuario} = Usuario.crear_usuario("userA", "1990-05-06")
      assert {:ok, "Usuario borrado exitosamente"} == Usuario.borrar_usuario(usuario.id)
      assert {:error, "Usuario no encontrado"} == Usuario.ver_usuario(usuario.id, "stdout")
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

      assert {:error, "El nuevo precio debe ser un número positivo"} ==
               Moneda.editar_moneda(moneda.id, "")

      assert {:error, "El nuevo precio debe ser un número positivo"} ==
               Moneda.editar_moneda(moneda.id, "0")

      assert {:error, "El nuevo precio debe ser un número positivo"} ==
               Moneda.editar_moneda(moneda.id, "asd")

      assert {:error, "El nuevo precio debe ser un número positivo"} ==
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
      assert {:error, "Moneda no encontrada"} == Moneda.ver_moneda(1, "stdout")
    end

    test "borrar_moneda borra moneda válida" do
      {:ok, moneda} = Moneda.crear_moneda("EUR", "1.18")
      assert {:ok, "Moneda borrada exitosamente"} == Moneda.borrar_moneda(moneda.id)
      assert {:error, "Moneda no encontrada"} == Moneda.ver_moneda(moneda.id, "stdout")
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
  end

  describe "Tests para Ledger.FileHandler" do
    test "lee archivo CSV correctamente dividido" do
      contenido = "a;b;c\nd;e;f\ng;h;i"
      File.write!(@archivo_tmp, contenido)
      esperado = [["a", "b", "c"], ["d", "e", "f"], ["g", "h", "i"]]

      assert FileHandler.leer_archivo(@archivo_tmp) == esperado
    end

    test "lee archivo vacío" do
      contenido = ""
      File.write!(@archivo_tmp, contenido)

      assert FileHandler.leer_archivo(@archivo_tmp) == []
    end

    test "saltea lineas vacias" do
      contenido = "a;b;c\n\n\nd;e;f"
      File.write!(@archivo_tmp, contenido)
      esperado = [["a", "b", "c"], ["d", "e", "f"]]

      assert FileHandler.leer_archivo(@archivo_tmp) == esperado
    end

    test "mostrar_linea escribe en archivo" do
      File.rm_rf!(@archivo_tmp)
      linea = ["a", "b", "c"]
      FileHandler.mostrar_linea(linea, @archivo_tmp)

      assert File.read!(@archivo_tmp) == "a;b;c\n"
    end

    test "mostrar_linea escribe en stdout" do
      linea = ["a", "b", "c"]

      assert capture_io(fn ->
               FileHandler.mostrar_linea(linea, "stdout")
             end) == "a;b;c\n"
    end

    test "mostrar_linea escribe varias lineas en archivo" do
      File.rm_rf!(@archivo_tmp)
      linea1 = ["a", "b", "c"]
      linea2 = ["d", "e", "f"]
      FileHandler.mostrar_linea(linea1, @archivo_tmp)
      FileHandler.mostrar_linea(linea2, @archivo_tmp)

      assert File.read!(@archivo_tmp) == "a;b;c\nd;e;f\n"
    end

    # test "mostrar_balance escribe en archivo una moneda" do
    #   File.rm_rf!(@archivo_tmp)
    #   montos = %{"BTC" => 2.0, "USDT" => 100.0}
    #   FileHandler.mostrar_balance("ARS", montos, @monedas, @archivo_tmp)

    #   assert File.read!(@archivo_tmp) == "ARS=91750000.000000\n"
    # end

    # test "mostrar_balance escribe en stdout una moneda" do
    #   montos = %{"BTC" => 2.0, "USDT" => 100.0}

    #   assert capture_io(fn ->
    #            Ledger.FileHandler.mostrar_balance("ARS", montos, @monedas, "stdout")
    #          end) == "ARS=91750000.000000\n"
    # end

    # test "mostrar_balance escribe en archivo todas las monedas" do
    #   File.rm_rf!(@archivo_tmp)
    #   montos = %{"BTC" => 2.0, "USDT" => 100.0}
    #   Ledger.FileHandler.mostrar_balance("", montos, @monedas, @archivo_tmp)

    #   assert File.read!(@archivo_tmp) == "BTC=2.000000\nUSDT=100.000000\n"
    # end
  end

  # describe "Tests para Ledger.Currency" do
  #   test "leer archivo monedas vacío" do
  #     File.write!(@archivo_tmp, "")

  #     assert {:error, "Archivo de monedas vacío"} ==
  #              Ledger.Currency.procesar_monedas(@archivo_tmp)
  #   end

  #   test "parsear_monto convierte string a float" do
  #     assert Ledger.Currency.parsear_monto("123.45") == 123.45
  #   end

  #   test "parsear_monto con string inválido devuelve 0.0" do
  #     assert Ledger.Currency.parsear_monto("abc") == 0.0
  #   end

  #   test "cambiar_a_moneda convierte entre monedas" do
  #     assert Ledger.Currency.cambiar_a_moneda(1.0, "BTC", "USDT", @monedas) == 55000.0
  #     assert Ledger.Currency.cambiar_a_moneda(55000.0, "USDT", "BTC", @monedas) == 1.0
  #     assert Ledger.Currency.cambiar_a_moneda(1000.0, "ARS", "USDT", @monedas) == 1.2
  #   end

  #   test "procesar_monedas lee archivo monedas.csv y devuelve mapa" do
  #     File.write!(@archivo_tmp, "BTC;55000.0\nETH;3000.0\nARS;0.0012\nUSDT;1.0\nEUR;1.18")

  #     esperado = %{
  #       "BTC" => 55000.0,
  #       "ETH" => 3000.0,
  #       "ARS" => 0.0012,
  #       "USDT" => 1.0,
  #       "EUR" => 1.18
  #     }

  #     assert Ledger.Currency.procesar_monedas(@archivo_tmp) == {:ok, esperado}
  #   end
  # end

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
      IO.inspect(moneda.id)

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
      {:ok, t} = Transaccion.alta_cuenta(usuario.id, moneda2.id, 5)

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

    #   test "procesar_transacciones con archivo válido" do
    #     contenido = """
    #     1;1756751403;USDT;;100.0;userA;;alta_cuenta
    #     2;1756751404;USDT;;100.0;userB;;alta_cuenta
    #     3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
    #     4;1756751406;BTC;;2.0;userC;;alta_cuenta
    #     5;1756751407;BTC;USDT;1.0;userC;;swap
    #     """

    #     File.write!(@archivo_tmp, contenido)

    #     esperado = %{
    #       "userA" => %{"USDT" => 50.0},
    #       "userB" => %{"USDT" => 150.0},
    #       "userC" => %{"BTC" => 1.0, "USDT" => 55000.0}
    #     }

    #     assert esperado == Ledger.Transaction.procesar_transacciones(@archivo_tmp, @monedas)
    #   end

    #   test "procesar_transacciones con archivo inexistente" do
    #     assert :error ==
    #              elem(Ledger.Transaction.procesar_transacciones("inexistente.csv", @monedas), 0)
    #   end

    #   test "procesar_transacciones con archivo con error en línea" do
    #     contenido = """
    #     1;1756751403;USDT;;100.0;userA;;alta_cuenta
    #     2;1756751404;USDT;;100.0;userB;;alta_cuenta
    #     3;1756751405;USDT;USDT;150.0;userA;userB;transferencia
    #     4;1756751406;BTC;;2.0;userC;;alta_cuenta
    #     5;1756751407;BTC;USDT;1.0;userC;;swap
    #     """

    #     File.write!(@archivo_tmp, contenido)

    #     assert {:error, "3"} == Ledger.Transaction.procesar_transacciones(@archivo_tmp, @monedas)
    #   end

    #   test "procesar_transacciones con varios errores en línea" do
    #     contenido = """
    #     1;1756751403;USDT;;100.0;userA;;alta_cuenta
    #     2;1756751404;USDT;;100.0;userB;;alta_cuenta
    #     3;1756751405;USDT;USDT;150.0;userA;userB;transferencia
    #     4;1756751406;BTC;;2.0;userC;;alta_cuenta
    #     5;1756751407;BTC;USDT;-1.0;userC;;swap
    #     6;1756751408;VERDES;;2.0;userD;;alta_cuenta
    #     """

    #     File.write!(@archivo_tmp, contenido)

    #     assert {:error, "3"} == Ledger.Transaction.procesar_transacciones(@archivo_tmp, @monedas)
    #   end

    #   test "listar_transacciones escribe en archivo" do
    #     archivo_transacciones = Path.join("test_tmp", "transacciones_test.csv")
    #     contenido = "1;1756751403;USDT;;100.0;userA;;alta_cuenta"
    #     cuentas = %{"userA" => %{"USDT" => 100.0}}
    #     flags = %{"c1" => "userA", "t" => archivo_transacciones, "o" => @archivo_tmp}
    #     esperado = contenido <> "\n"
    #     File.rm_rf!(@archivo_tmp)
    #     File.write!(archivo_transacciones, contenido)

    #     assert {:ok, 0} == Ledger.Transaction.listar_transacciones(flags, cuentas)
    #     assert File.read!(@archivo_tmp) == esperado
    #   end

    #   test "listar_transacciones escribe en stdout" do
    #     File.rm_rf!(@archivo_tmp)

    #     contenido = """
    #     1;1756751403;USDT;;100.0;userA;;alta_cuenta
    #     2;1756751404;USDT;;100.0;userB;;alta_cuenta
    #     3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
    #     4;1756751406;BTC;;2.0;userC;;alta_cuenta
    #     """

    #     File.write!(@archivo_tmp, contenido)

    #     cuentas = %{
    #       "userA" => %{"USDT" => 50.0},
    #       "userB" => %{"USDT" => 150.0},
    #       "userC" => %{"BTC" => 2.0}
    #     }

    #     flags = %{"c1" => "userA", "t" => @archivo_tmp}

    #     esperado =
    #       "1;1756751403;USDT;;100.0;userA;;alta_cuenta\n3;1756751405;USDT;USDT;50.0;userA;userB;transferencia\n"

    #     assert capture_io(fn ->
    #              Ledger.Transaction.listar_transacciones(flags, cuentas)
    #            end) == esperado
    #   end

    #   test "listar_transacciones con cuenta inexistente" do
    #     cuentas = %{
    #       "userA" => %{"USDT" => 50.0},
    #       "userB" => %{"USDT" => 150.0}
    #     }

    #     flags = %{"c1" => "userX", "t" => @archivo_tmp}
    #     flags2 = %{"c2" => "userY", "t" => @archivo_tmp}
    #     assert :error == elem(Ledger.Transaction.listar_transacciones(flags, cuentas), 0)
    #     assert :error == elem(Ledger.Transaction.listar_transacciones(flags2, cuentas), 0)
    #   end

    #   test "listar_transacciones con flag c1" do
    #     contenido = """
    #     1;1756751403;USDT;;100.0;userA;;alta_cuenta
    #     2;1756751404;USDT;;100.0;userB;;alta_cuenta
    #     3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
    #     4;1756751406;BTC;;2.0;userC;;alta_cuenta
    #     """

    #     File.write!(@archivo_tmp, contenido)

    #     cuentas = %{
    #       "userA" => %{"USDT" => 50.0},
    #       "userB" => %{"USDT" => 150.0},
    #       "userC" => %{"BTC" => 2.0}
    #     }

    #     flags = %{"c1" => "userA", "t" => @archivo_tmp}

    #     esperado =
    #       "1;1756751403;USDT;;100.0;userA;;alta_cuenta\n3;1756751405;USDT;USDT;50.0;userA;userB;transferencia\n"

    #     assert capture_io(fn ->
    #              Ledger.Transaction.listar_transacciones(flags, cuentas)
    #            end) == esperado
    #   end

    #   test "listar_transacciones con flag c2" do
    #     contenido = """
    #     1;1756751403;USDT;;100.0;userA;;alta_cuenta
    #     2;1756751404;USDT;;100.0;userB;;alta_cuenta
    #     3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
    #     4;1756751406;BTC;;2.0;userC;;alta_cuenta
    #     """

    #     File.write!(@archivo_tmp, contenido)

    #     cuentas = %{
    #       "userA" => %{"USDT" => 50.0},
    #       "userB" => %{"USDT" => 150.0},
    #       "userC" => %{"BTC" => 2.0}
    #     }

    #     flags = %{"c2" => "userB", "t" => @archivo_tmp}

    #     esperado =
    #       "3;1756751405;USDT;USDT;50.0;userA;userB;transferencia\n"

    #     assert capture_io(fn ->
    #              Ledger.Transaction.listar_transacciones(flags, cuentas)
    #            end) == esperado
    #   end

    #   test "listar_transacciones con flags c1 y c2" do
    #     contenido = """
    #     1;1756751403;USDT;;100.0;userA;;alta_cuenta
    #     2;1756751404;USDT;;100.0;userB;;alta_cuenta
    #     3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
    #     4;1756751406;BTC;;2.0;userC;;alta_cuenta
    #     """

    #     File.write!(@archivo_tmp, contenido)

    #     cuentas = %{
    #       "userA" => %{"USDT" => 50.0},
    #       "userB" => %{"USDT" => 150.0},
    #       "userC" => %{"BTC" => 2.0}
    #     }

    #     flags = %{"c1" => "userA", "c2" => "userB", "t" => @archivo_tmp}

    #     esperado =
    #       "3;1756751405;USDT;USDT;50.0;userA;userB;transferencia\n"

    #     assert capture_io(fn ->
    #              Ledger.Transaction.listar_transacciones(flags, cuentas)
    #            end) == esperado
    #   end

    #   test "listar_transacciones sin flags c1 ni c2" do
    #     contenido = """
    #     1;1756751403;USDT;;100.0;userA;;alta_cuenta
    #     2;1756751404;USDT;;100.0;userB;;alta_cuenta
    #     3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
    #     4;1756751406;BTC;;2.0;userC;;alta_cuenta
    #     """

    #     File.write!(@archivo_tmp, contenido)

    #     cuentas = %{
    #       "userA" => %{"USDT" => 50.0},
    #       "userB" => %{"USDT" => 150.0},
    #       "userC" => %{"BTC" => 2.0}
    #     }

    #     flags = %{"t" => @archivo_tmp}

    #     esperado =
    #       "1;1756751403;USDT;;100.0;userA;;alta_cuenta\n2;1756751404;USDT;;100.0;userB;;alta_cuenta\n3;1756751405;USDT;USDT;50.0;userA;userB;transferencia\n4;1756751406;BTC;;2.0;userC;;alta_cuenta\n"

    #     assert capture_io(fn ->
    #              Ledger.Transaction.listar_transacciones(flags, cuentas)
    #            end) == esperado
    #   end
    # end

    # describe "Tests para Ledger.Balance" do
    #   test "listar_balance con cuenta inexistente" do
    #     cuentas = %{
    #       "userA" => %{"USDT" => 50.0},
    #       "userB" => %{"USDT" => 150.0}
    #     }

    #     flags = %{"c1" => "userX"}

    #     assert :error == elem(Ledger.Balance.listar_balance(flags, cuentas, @monedas), 0)
    #   end

    #   test "listar_balance sin cuenta" do
    #     cuentas = %{
    #       "userA" => %{"USDT" => 50.0},
    #       "userB" => %{"USDT" => 150.0}
    #     }

    #     flags = %{}

    #     assert :error == elem(Ledger.Balance.listar_balance(flags, cuentas, @monedas), 0)
    #   end

    #   test "listar_balance con moneda inexistente" do
    #     cuentas = %{
    #       "userA" => %{"USDT" => 50.0},
    #       "userB" => %{"USDT" => 150.0}
    #     }

    #     flags = %{"c1" => "userA", "m" => "VERDES"}
    #     assert :error == elem(Ledger.Balance.listar_balance(flags, cuentas, @monedas), 0)
    #   end

    #   test "listar_balance escribe en archivo una moneda" do
    #     File.rm_rf!(@archivo_tmp)
    #     cuentas = %{"userA" => %{"BTC" => 2.0, "USDT" => 100.0}}
    #     flags = %{"c1" => "userA", "m" => "ARS", "o" => @archivo_tmp}
    #     esperado = "ARS=91750000.000000\n"
    #     assert {:ok, 0} == Ledger.Balance.listar_balance(flags, cuentas, @monedas)
    #     assert File.read!(@archivo_tmp) == esperado
    #   end

    #   test "listar_balance escribe en stdout una moneda" do
    #     cuentas = %{"userA" => %{"BTC" => 2.0, "USDT" => 100.0}}
    #     flags = %{"c1" => "userA", "m" => "ARS"}

    #     esperado = "ARS=91750000.000000\n"

    #     assert capture_io(fn ->
    #              Ledger.Balance.listar_balance(flags, cuentas, @monedas)
    #            end) == esperado
    #   end

    #   test "listar_balance escribe en archivo todas las monedas" do
    #     File.rm_rf!(@archivo_tmp)
    #     cuentas = %{"userA" => %{"BTC" => 2.0, "USDT" => 100.0}}
    #     flags = %{"c1" => "userA", "o" => @archivo_tmp}
    #     esperado = "BTC=2.000000\nUSDT=100.000000\n"
    #     assert {:ok, 0} == Ledger.Balance.listar_balance(flags, cuentas, @monedas)
    #     assert File.read!(@archivo_tmp) == esperado
    #   end

    #   test "listar_balance escribe en stdout todas las monedas" do
    #     cuentas = %{"userA" => %{"BTC" => 2.0, "USDT" => 100.0}}
    #     flags = %{"c1" => "userA"}
    #     esperado = "BTC=2.000000\nUSDT=100.000000\n"

    #     assert capture_io(fn ->
    #              Ledger.Balance.listar_balance(flags, cuentas, @monedas)
    #            end) == esperado
    #   end
    # end

    # describe "Tests para Ledger.CLI" do
    #   test "procesar_argumentos sin comando" do
    #     assert :error == elem(Ledger.CLI.procesar_argumentos([]), 0)
    #   end

    #   test "procesar_argumentos con comando inválido" do
    #     assert :error == elem(Ledger.CLI.procesar_argumentos(["asd"]), 0)
    #   end

    #   test "procesar_argumentos con argumentos válidos" do
    #     assert {:ok, %{"comando" => "balance", "c1" => "userA"}} ==
    #              Ledger.CLI.procesar_argumentos(["balance", "-c1=userA"])

    #     assert {:ok, %{"comando" => "transacciones", "c1" => "userA"}} ==
    #              Ledger.CLI.procesar_argumentos(["transacciones", "-c1=userA"])
    #   end

    #   test "efectuar_comando con comando inválido" do
    #     assert :error == elem(Ledger.CLI.efectuar_comando(%{"comando" => "asd"}, %{}, %{}), 0)
    #   end

    #   test "efectuar_comando con comando válido" do
    #     cuentas = %{"userA" => %{"BTC" => 2.0, "USDT" => 100.0}}
    #     flags_balance = %{"comando" => "balance", "c1" => "userA"}
    #     flags_transacciones = %{"comando" => "transacciones", "c1" => "userA"}
    #     assert {:ok, 0} == Ledger.CLI.efectuar_comando(flags_balance, cuentas, @monedas)
    #     assert {:ok, 0} == Ledger.CLI.efectuar_comando(flags_transacciones, cuentas, @monedas)
    #   end
  end

  # describe "Tests para Ledger.main" do
  #   test "main con argumentos inválidos" do
  #     contenido = "1;1756751403;USDT;;100.0;userA;;alta_cuenta"
  #     File.write!(@archivo_tmp, contenido)

  #     assert capture_io(fn ->
  #              Ledger.main([])
  #            end) == "{:error, No se proporcionó ningún comando}\n"

  #     assert capture_io(fn ->
  #              Ledger.main(["asd"])
  #            end) == "{:error, El comando no es válido}\n"

  #     assert capture_io(fn ->
  #              Ledger.main(["balance", "-t=#{@archivo_tmp}"])
  #            end) == "{:error, La cuenta no existe}\n"
  #   end

  #   test "main con comando balance y argumentos válidos" do
  #     contenido = """
  #     1;1756751403;USDT;;100.0;userA;;alta_cuenta
  #     2;1756751404;USDT;;100.0;userB;;alta_cuenta
  #     3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
  #     4;1756751406;BTC;;2.0;userC;;alta_cuenta
  #     5;1756751407;BTC;USDT;1.0;userC;;swap
  #     """

  #     File.write!(@archivo_tmp, contenido)

  #     esperado = %{
  #       "userA" => %{"USDT" => 50.0},
  #       "userB" => %{"USDT" => 150.0},
  #       "userC" => %{"BTC" => 1.0, "USDT" => 55000.0}
  #     }

  #     assert {:ok, 0} ==
  #              Ledger.main([
  #                "balance",
  #                "-c1=userA",
  #                "-m=ARS",
  #                "-t=#{@archivo_tmp}",
  #                "-o=stdout"
  #              ])

  #     assert esperado == Ledger.Transaction.procesar_transacciones(@archivo_tmp, @monedas)
  #   end

  #   test "main con comando transacciones y argumentos válidos" do
  #     contenido = """
  #     1;1756751403;USDT;;100.0;userA;;alta_cuenta
  #     2;1756751404;USDT;;100.0;userB;;alta_cuenta
  #     3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
  #     4;1756751406;BTC;;2.0;userC;;alta_cuenta
  #     5;1756751407;BTC;USDT;1.0;userC;;swap
  #     """

  #     File.write!(@archivo_tmp, contenido)

  #     esperado = %{
  #       "userA" => %{"USDT" => 50.0},
  #       "userB" => %{"USDT" => 150.0},
  #       "userC" => %{"BTC" => 1.0, "USDT" => 55000.0}
  #     }

  #     assert {:ok, 0} ==
  #              Ledger.main([
  #                "transacciones",
  #                "-c1=userA",
  #                "-t=#{@archivo_tmp}",
  #                "-o=stdout"
  #              ])

  #     assert esperado == Ledger.Transaction.procesar_transacciones(@archivo_tmp, @monedas)
  #   end
  # end
end
