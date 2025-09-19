defmodule LedgerTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  doctest Ledger

  @monedas %{"BTC" => 55000.0, "USDT" => 1.0, "ARS" => 0.0012}
  @archivo_tmp Path.join("test_tmp", "archivo_tmp.csv")

  describe "Tests para Ledger.FileHandler" do
    test "lee archivo CSV correctamente dividido" do
      contenido = "a;b;c\nd;e;f\ng;h;i"
      File.write!(@archivo_tmp, contenido)
      esperado = [["a", "b", "c"], ["d", "e", "f"], ["g", "h", "i"]]

      assert Ledger.FileHandler.leer_archivo(@archivo_tmp) == esperado
    end

    test "lee archivo vacío" do
      contenido = ""
      File.write!(@archivo_tmp, contenido)

      assert Ledger.FileHandler.leer_archivo(@archivo_tmp) == []
    end

    test "saltea lineas vacias" do
      contenido = "a;b;c\n\n\nd;e;f"
      File.write!(@archivo_tmp, contenido)
      esperado = [["a", "b", "c"], ["d", "e", "f"]]

      assert Ledger.FileHandler.leer_archivo(@archivo_tmp) == esperado
    end

    test "mostrar_linea escribe en archivo" do
      File.rm_rf!(@archivo_tmp)
      linea = ["a", "b", "c"]
      Ledger.FileHandler.mostrar_linea(linea, @archivo_tmp)

      assert File.read!(@archivo_tmp) == "a;b;c\n"
    end

    test "mostrar_linea escribe en stdout" do
      linea = ["a", "b", "c"]

      assert capture_io(fn ->
               Ledger.FileHandler.mostrar_linea(linea, "stdout")
             end) == "a;b;c\n"
    end

    test "mostrar_linea escribe varias lineas en archivo" do
      File.rm_rf!(@archivo_tmp)
      linea1 = ["a", "b", "c"]
      linea2 = ["d", "e", "f"]
      Ledger.FileHandler.mostrar_linea(linea1, @archivo_tmp)
      Ledger.FileHandler.mostrar_linea(linea2, @archivo_tmp)

      assert File.read!(@archivo_tmp) == "a;b;c\nd;e;f\n"
    end

    test "mostrar_balance escribe en archivo una moneda" do
      File.rm_rf!(@archivo_tmp)
      montos = %{"BTC" => 2.0, "USDT" => 100.0}
      Ledger.FileHandler.mostrar_balance("ARS", montos, @monedas, @archivo_tmp)

      assert File.read!(@archivo_tmp) == "ARS=91750000.000000\n"
    end

    test "mostrar_balance escribe en stdout una moneda" do
      montos = %{"BTC" => 2.0, "USDT" => 100.0}

      assert capture_io(fn ->
               Ledger.FileHandler.mostrar_balance("ARS", montos, @monedas, "stdout")
             end) == "ARS=91750000.000000\n"
    end

    test "mostrar_balance escribe en archivo todas las monedas" do
      File.rm_rf!(@archivo_tmp)
      montos = %{"BTC" => 2.0, "USDT" => 100.0}
      Ledger.FileHandler.mostrar_balance("", montos, @monedas, @archivo_tmp)

      assert File.read!(@archivo_tmp) == "BTC=2.000000\nUSDT=100.000000\n"
    end
  end

  describe "Tests para Ledger.Currency" do
    test "parsear_monto convierte string a float" do
      assert Ledger.Currency.parsear_monto("123.45") == 123.45
    end

    test "parsear_monto con string inválido devuelve 0.0" do
      assert Ledger.Currency.parsear_monto("abc") == 0.0
    end

    test "cambiar_a_moneda convierte entre monedas" do
      assert Ledger.Currency.cambiar_a_moneda(1.0, "BTC", "USDT", @monedas) == 55000.0
      assert Ledger.Currency.cambiar_a_moneda(55000.0, "USDT", "BTC", @monedas) == 1.0
      assert Ledger.Currency.cambiar_a_moneda(1000.0, "ARS", "USDT", @monedas) == 1.2
    end

    test "procesar_monedas lee archivo monedas.csv y devuelve mapa" do
      esperado = %{
        "BTC" => 55000.0,
        "ETH" => 3000.0,
        "ARS" => 0.0012,
        "USDT" => 1.0,
        "EUR" => 1.18
      }

      assert Ledger.Currency.procesar_monedas() == esperado
    end
  end

  describe "Tests para Ledger.Transaction" do
    test "alta_cuenta válido" do
      linea = ["2", "1756751404", "USDT", "", "2.0", "userA", "", "alta_cuenta"]
      esperado = %{"userA" => %{"USDT" => 2.0}}

      assert {:ok, esperado} ==
               Ledger.Transaction.valor_transaccion("alta_cuenta", %{}, linea, @monedas)
    end

    test "alta_cuenta con moneda inválida" do
      linea = ["2", "1756751404", "VERDES", "", "2.0", "userA", "", "alta_cuenta"]

      assert {:error, "2"} ==
               Ledger.Transaction.valor_transaccion("alta_cuenta", %{}, linea, @monedas)
    end

    test "hacer alta_cuenta con monto inválido" do
      linea1 = ["1", "1756751404", "USDT", "", "-2.0", "userA", "", "alta_cuenta"]
      linea2 = ["2", "1756751404", "USDT", "", "abc", "userA", "", "alta_cuenta"]
      linea3 = ["3", "1756751404", "USDT", "", "0.0", "userA", "", "alta_cuenta"]

      assert {:error, "1"} ==
               Ledger.Transaction.valor_transaccion("alta_cuenta", %{}, linea1, @monedas)

      assert {:error, "2"} ==
               Ledger.Transaction.valor_transaccion("alta_cuenta", %{}, linea2, @monedas)

      assert {:error, "3"} ==
               Ledger.Transaction.valor_transaccion("alta_cuenta", %{}, linea3, @monedas)
    end

    test "alta_cuenta con una cuenta preexistente" do
      linea1 = ["2", "1756751404", "USDT", "", "2.0", "userA", "", "alta_cuenta"]
      linea2 = ["3", "1756751405", "USDT", "", "3.0", "userA", "", "alta_cuenta"]
      {:ok, cuentas} = Ledger.Transaction.valor_transaccion("alta_cuenta", %{}, linea1, @monedas)

      assert {:error, "3"} ==
               Ledger.Transaction.valor_transaccion("alta_cuenta", cuentas, linea2, @monedas)
    end

    test "swap válido" do
      linea1 = ["2", "1756751404", "BTC", "", "2.0", "userA", "", "alta_cuenta"]
      linea2 = ["3", "1756751405", "BTC", "USDT", "1.0", "userA", "", "swap"]
      {:ok, cuentas} = Ledger.Transaction.valor_transaccion("alta_cuenta", %{}, linea1, @monedas)
      esperado = %{"userA" => %{"BTC" => 1.0, "USDT" => 55000.0}}

      assert {:ok, esperado} ==
               Ledger.Transaction.valor_transaccion("swap", cuentas, linea2, @monedas)
    end

    test "swap con cuenta inexistente" do
      linea = ["3", "1756751405", "BTC", "USDT", "1.0", "userA", "", "swap"]

      assert {:error, "3"} ==
               Ledger.Transaction.valor_transaccion("swap", %{}, linea, @monedas)
    end

    test "swap con moneda inválida" do
      linea1 = ["1", "1756751404", "BTC", "", "2.0", "userA", "", "alta_cuenta"]
      linea2 = ["2", "1756751405", "VERDES", "USDT", "1.0", "userA", "", "swap"]
      linea3 = ["3", "1756751406", "BTC", "", "1.0", "userA", "", "swap"]
      {:ok, cuentas} = Ledger.Transaction.valor_transaccion("alta_cuenta", %{}, linea1, @monedas)

      assert {:error, "2"} ==
               Ledger.Transaction.valor_transaccion("swap", cuentas, linea2, @monedas)

      assert {:error, "3"} ==
               Ledger.Transaction.valor_transaccion("swap", cuentas, linea3, @monedas)
    end

    test "swap con monto inválido" do
      linea1 = ["1", "1756751404", "BTC", "", "2.0", "userA", "", "alta_cuenta"]
      linea2 = ["2", "1756751405", "BTC", "USDT", "-1.0", "userA", "", "swap"]
      linea3 = ["3", "1756751406", "BTC", "USDT", "abc", "userA", "", "swap"]
      linea4 = ["4", "1756751407", "BTC", "USDT", "0.0", "userA", "", "swap"]
      linea5 = ["5", "1756751407", "BTC", "USDT", "3.0", "userA", "", "swap"]
      {:ok, cuentas} = Ledger.Transaction.valor_transaccion("alta_cuenta", %{}, linea1, @monedas)

      assert {:error, "2"} ==
               Ledger.Transaction.valor_transaccion("swap", cuentas, linea2, @monedas)

      assert {:error, "3"} ==
               Ledger.Transaction.valor_transaccion("swap", cuentas, linea3, @monedas)

      assert {:error, "4"} ==
               Ledger.Transaction.valor_transaccion("swap", cuentas, linea4, @monedas)

      assert {:error, "5"} ==
               Ledger.Transaction.valor_transaccion("swap", cuentas, linea5, @monedas)
    end

    test "transferencia válida" do
      linea1 = ["2", "1756751404", "USDT", "", "100.0", "userA", "", "alta_cuenta"]
      linea2 = ["3", "1756751405", "USDT", "", "50.0", "userB", "", "alta_cuenta"]
      linea3 = ["4", "1756751406", "USDT", "USDT", "30.0", "userA", "userB", "transferencia"]
      {:ok, cuentas} = Ledger.Transaction.valor_transaccion("alta_cuenta", %{}, linea1, @monedas)

      {:ok, cuentas} =
        Ledger.Transaction.valor_transaccion("alta_cuenta", cuentas, linea2, @monedas)

      esperado = %{"userA" => %{"USDT" => 70.0}, "userB" => %{"USDT" => 80.0}}

      assert {:ok, esperado} ==
               Ledger.Transaction.valor_transaccion("transferencia", cuentas, linea3, @monedas)
    end

    test "transferencia con cuenta origen inexistente" do
      linea = ["3", "1756751405", "USDT", "USDT", "50.0", "userA", "userB", "transferencia"]

      assert {:error, "3"} ==
               Ledger.Transaction.valor_transaccion("transferencia", %{}, linea, @monedas)
    end

    test "transferencia con cuenta destino inexistente" do
      linea1 = ["2", "1756751404", "USDT", "", "100.0", "userA", "", "alta_cuenta"]
      linea2 = ["3", "1756751405", "USDT", "USDT", "50.0", "userA", "userB", "transferencia"]
      {:ok, cuentas} = Ledger.Transaction.valor_transaccion("alta_cuenta", %{}, linea1, @monedas)

      assert {:error, "3"} ==
               Ledger.Transaction.valor_transaccion("transferencia", cuentas, linea2, @monedas)
    end

    test "transferencia con moneda inválida" do
      linea1 = ["1", "1756751403", "USDT", "", "100.0", "userA", "", "alta_cuenta"]
      linea2 = ["2", "1756751404", "USDT", "", "100.0", "userB", "", "alta_cuenta"]
      linea3 = ["3", "1756751405", "VERDES", "USDT", "50.0", "userA", "userB", "transferencia"]
      linea4 = ["4", "1756751406", "USDT", "VERDES", "50.0", "userA", "userB", "transferencia"]
      {:ok, cuentas} = Ledger.Transaction.valor_transaccion("alta_cuenta", %{}, linea1, @monedas)

      {:ok, cuentas} =
        Ledger.Transaction.valor_transaccion("alta_cuenta", cuentas, linea2, @monedas)

      assert {:error, "3"} ==
               Ledger.Transaction.valor_transaccion("transferencia", cuentas, linea3, @monedas)

      assert {:error, "4"} ==
               Ledger.Transaction.valor_transaccion("transferencia", cuentas, linea4, @monedas)
    end

    test "transferencia con monto inválido" do
      linea1 = ["1", "1756751403", "USDT", "", "100.0", "userA", "", "alta_cuenta"]
      linea2 = ["2", "1756751404", "USDT", "", "100.0", "userB", "", "alta_cuenta"]
      linea3 = ["3", "1756751405", "USDT", "USDT", "-50.0", "userA", "userB", "transferencia"]
      linea4 = ["4", "1756751406", "USDT", "USDT", "abc", "userA", "userB", "transferencia"]
      linea5 = ["5", "1756751407", "USDT", "USDT", "0.0", "userA", "userB", "transferencia"]
      linea6 = ["6", "1756751408", "USDT", "USDT", "150.0", "userA", "userB", "transferencia"]
      {:ok, cuentas} = Ledger.Transaction.valor_transaccion("alta_cuenta", %{}, linea1, @monedas)

      {:ok, cuentas} =
        Ledger.Transaction.valor_transaccion("alta_cuenta", cuentas, linea2, @monedas)

      assert {:error, "3"} ==
               Ledger.Transaction.valor_transaccion("transferencia", cuentas, linea3, @monedas)

      assert {:error, "4"} ==
               Ledger.Transaction.valor_transaccion("transferencia", cuentas, linea4, @monedas)

      assert {:error, "5"} ==
               Ledger.Transaction.valor_transaccion("transferencia", cuentas, linea5, @monedas)

      assert {:error, "6"} ==
               Ledger.Transaction.valor_transaccion("transferencia", cuentas, linea6, @monedas)
    end

    test "transferencia con moneda origen y destino diferentes" do
      linea1 = ["1", "1756751403", "USDT", "", "100.0", "userA", "", "alta_cuenta"]
      linea2 = ["2", "1756751404", "USDT", "", "100.0", "userB", "", "alta_cuenta"]
      linea3 = ["3", "1756751405", "USDT", "BTC", "50.0", "userA", "userB", "transferencia"]
      {:ok, cuentas} = Ledger.Transaction.valor_transaccion("alta_cuenta", %{}, linea1, @monedas)

      {:ok, cuentas} =
        Ledger.Transaction.valor_transaccion("alta_cuenta", cuentas, linea2, @monedas)

      assert {:error, "3"} ==
               Ledger.Transaction.valor_transaccion("transferencia", cuentas, linea3, @monedas)
    end

    test "transaccion invalida" do
      linea = ["1", "1756751403", "USDT", "", "100.0", "userA", "", "asd"]

      assert {:error, "1"} ==
               Ledger.Transaction.valor_transaccion("asd", %{}, linea, @monedas)
    end

    test "procesar_transacciones con archivo válido" do
      contenido = """
      1;1756751403;USDT;;100.0;userA;;alta_cuenta
      2;1756751404;USDT;;100.0;userB;;alta_cuenta
      3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
      4;1756751406;BTC;;2.0;userC;;alta_cuenta
      5;1756751407;BTC;USDT;1.0;userC;;swap
      """

      File.write!(@archivo_tmp, contenido)

      esperado = %{
        "userA" => %{"USDT" => 50.0},
        "userB" => %{"USDT" => 150.0},
        "userC" => %{"BTC" => 1.0, "USDT" => 55000.0}
      }

      assert esperado == Ledger.Transaction.procesar_transacciones(@archivo_tmp, @monedas)
    end

    test "procesar_transacciones con archivo inexistente" do
      assert {:error, 0} == Ledger.Transaction.procesar_transacciones("inexistente.csv", @monedas)
    end

    test "procesar_transacciones con archivo con error en línea" do
      contenido = """
      1;1756751403;USDT;;100.0;userA;;alta_cuenta
      2;1756751404;USDT;;100.0;userB;;alta_cuenta
      3;1756751405;USDT;USDT;150.0;userA;userB;transferencia
      4;1756751406;BTC;;2.0;userC;;alta_cuenta
      5;1756751407;BTC;USDT;1.0;userC;;swap
      """

      File.write!(@archivo_tmp, contenido)

      assert {:error, "3"} == Ledger.Transaction.procesar_transacciones(@archivo_tmp, @monedas)
    end

    test "procesar_transacciones con varios errores en línea" do
      contenido = """
      1;1756751403;USDT;;100.0;userA;;alta_cuenta
      2;1756751404;USDT;;100.0;userB;;alta_cuenta
      3;1756751405;USDT;USDT;150.0;userA;userB;transferencia
      4;1756751406;BTC;;2.0;userC;;alta_cuenta
      5;1756751407;BTC;USDT;-1.0;userC;;swap
      6;1756751408;VERDES;;2.0;userD;;alta_cuenta
      """

      File.write!(@archivo_tmp, contenido)

      assert {:error, "3"} == Ledger.Transaction.procesar_transacciones(@archivo_tmp, @monedas)
    end

    test "listar_transacciones escribe en archivo" do
      archivo_transacciones = Path.join("test_tmp", "transacciones_test.csv")
      contenido = "1;1756751403;USDT;;100.0;userA;;alta_cuenta"
      cuentas = %{"userA" => %{"USDT" => 100.0}}
      flags = %{"c1" => "userA", "t" => archivo_transacciones, "o" => @archivo_tmp}
      esperado = contenido <> "\n"
      File.rm_rf!(@archivo_tmp)
      File.write!(archivo_transacciones, contenido)

      assert {:ok, 0} == Ledger.Transaction.listar_transacciones(flags, cuentas)
      assert File.read!(@archivo_tmp) == esperado
    end

    test "listar_transacciones escribe en stdout" do
      File.rm_rf!(@archivo_tmp)

      contenido = """
      1;1756751403;USDT;;100.0;userA;;alta_cuenta
      2;1756751404;USDT;;100.0;userB;;alta_cuenta
      3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
      4;1756751406;BTC;;2.0;userC;;alta_cuenta
      """

      File.write!(@archivo_tmp, contenido)

      cuentas = %{
        "userA" => %{"USDT" => 50.0},
        "userB" => %{"USDT" => 150.0},
        "userC" => %{"BTC" => 2.0}
      }

      flags = %{"c1" => "userA", "t" => @archivo_tmp}

      esperado =
        "1;1756751403;USDT;;100.0;userA;;alta_cuenta\n3;1756751405;USDT;USDT;50.0;userA;userB;transferencia\n"

      assert capture_io(fn ->
               Ledger.Transaction.listar_transacciones(flags, cuentas)
             end) == esperado
    end

    test "listar_transacciones con cuenta inexistente" do
      cuentas = %{
        "userA" => %{"USDT" => 50.0},
        "userB" => %{"USDT" => 150.0}
      }

      flags = %{"c1" => "userX", "t" => @archivo_tmp}
      flags2 = %{"c2" => "userY", "t" => @archivo_tmp}
      assert {:error, 0} == Ledger.Transaction.listar_transacciones(flags, cuentas)
      assert {:error, 0} == Ledger.Transaction.listar_transacciones(flags2, cuentas)
    end

    test "listar_transacciones con flag c1" do
      contenido = """
      1;1756751403;USDT;;100.0;userA;;alta_cuenta
      2;1756751404;USDT;;100.0;userB;;alta_cuenta
      3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
      4;1756751406;BTC;;2.0;userC;;alta_cuenta
      """

      File.write!(@archivo_tmp, contenido)

      cuentas = %{
        "userA" => %{"USDT" => 50.0},
        "userB" => %{"USDT" => 150.0},
        "userC" => %{"BTC" => 2.0}
      }

      flags = %{"c1" => "userA", "t" => @archivo_tmp}

      esperado =
        "1;1756751403;USDT;;100.0;userA;;alta_cuenta\n3;1756751405;USDT;USDT;50.0;userA;userB;transferencia\n"

      assert capture_io(fn ->
               Ledger.Transaction.listar_transacciones(flags, cuentas)
             end) == esperado
    end

    test "listar_transacciones con flag c2" do
      contenido = """
      1;1756751403;USDT;;100.0;userA;;alta_cuenta
      2;1756751404;USDT;;100.0;userB;;alta_cuenta
      3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
      4;1756751406;BTC;;2.0;userC;;alta_cuenta
      """

      File.write!(@archivo_tmp, contenido)

      cuentas = %{
        "userA" => %{"USDT" => 50.0},
        "userB" => %{"USDT" => 150.0},
        "userC" => %{"BTC" => 2.0}
      }

      flags = %{"c2" => "userB", "t" => @archivo_tmp}

      esperado =
        "3;1756751405;USDT;USDT;50.0;userA;userB;transferencia\n"

      assert capture_io(fn ->
               Ledger.Transaction.listar_transacciones(flags, cuentas)
             end) == esperado
    end

    test "listar_transacciones con flags c1 y c2" do
      contenido = """
      1;1756751403;USDT;;100.0;userA;;alta_cuenta
      2;1756751404;USDT;;100.0;userB;;alta_cuenta
      3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
      4;1756751406;BTC;;2.0;userC;;alta_cuenta
      """

      File.write!(@archivo_tmp, contenido)

      cuentas = %{
        "userA" => %{"USDT" => 50.0},
        "userB" => %{"USDT" => 150.0},
        "userC" => %{"BTC" => 2.0}
      }

      flags = %{"c1" => "userA", "c2" => "userB", "t" => @archivo_tmp}

      esperado =
        "3;1756751405;USDT;USDT;50.0;userA;userB;transferencia\n"

      assert capture_io(fn ->
               Ledger.Transaction.listar_transacciones(flags, cuentas)
             end) == esperado
    end

    test "listar_transacciones sin flags c1 ni c2" do
      contenido = """
      1;1756751403;USDT;;100.0;userA;;alta_cuenta
      2;1756751404;USDT;;100.0;userB;;alta_cuenta
      3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
      4;1756751406;BTC;;2.0;userC;;alta_cuenta
      """

      File.write!(@archivo_tmp, contenido)

      cuentas = %{
        "userA" => %{"USDT" => 50.0},
        "userB" => %{"USDT" => 150.0},
        "userC" => %{"BTC" => 2.0}
      }

      flags = %{"t" => @archivo_tmp}

      esperado =
        "1;1756751403;USDT;;100.0;userA;;alta_cuenta\n2;1756751404;USDT;;100.0;userB;;alta_cuenta\n3;1756751405;USDT;USDT;50.0;userA;userB;transferencia\n4;1756751406;BTC;;2.0;userC;;alta_cuenta\n"

      assert capture_io(fn ->
               Ledger.Transaction.listar_transacciones(flags, cuentas)
             end) == esperado
    end
  end

  describe "Tests para Ledger.Balance" do
    test "listar_balance con cuenta inexistente" do
      cuentas = %{
        "userA" => %{"USDT" => 50.0},
        "userB" => %{"USDT" => 150.0}
      }

      flags = %{"c1" => "userX"}

      assert {:error, 0} == Ledger.Balance.listar_balance(flags, cuentas, @monedas)
    end

    test "listar_balance sin cuenta" do
      cuentas = %{
        "userA" => %{"USDT" => 50.0},
        "userB" => %{"USDT" => 150.0}
      }

      flags = %{}

      assert {:error, 0} == Ledger.Balance.listar_balance(flags, cuentas, @monedas)
    end

    test "listar_balance con moneda inexistente" do
      cuentas = %{
        "userA" => %{"USDT" => 50.0},
        "userB" => %{"USDT" => 150.0}
      }

      flags = %{"c1" => "userA", "m" => "VERDES"}
      assert {:error, 0} == Ledger.Balance.listar_balance(flags, cuentas, @monedas)
    end

    test "listar_balance escribe en archivo una moneda" do
      File.rm_rf!(@archivo_tmp)
      cuentas = %{"userA" => %{"BTC" => 2.0, "USDT" => 100.0}}
      flags = %{"c1" => "userA", "m" => "ARS", "o" => @archivo_tmp}
      esperado = "ARS=91750000.000000\n"
      assert {:ok, 0} == Ledger.Balance.listar_balance(flags, cuentas, @monedas)
      assert File.read!(@archivo_tmp) == esperado
    end

    test "listar_balance escribe en stdout una moneda" do
      cuentas = %{"userA" => %{"BTC" => 2.0, "USDT" => 100.0}}
      flags = %{"c1" => "userA", "m" => "ARS"}

      esperado = "ARS=91750000.000000\n"

      assert capture_io(fn ->
               Ledger.Balance.listar_balance(flags, cuentas, @monedas)
             end) == esperado
    end

    test "listar_balance escribe en archivo todas las monedas" do
      File.rm_rf!(@archivo_tmp)
      cuentas = %{"userA" => %{"BTC" => 2.0, "USDT" => 100.0}}
      flags = %{"c1" => "userA", "o" => @archivo_tmp}
      esperado = "BTC=2.000000\nUSDT=100.000000\n"
      assert {:ok, 0} == Ledger.Balance.listar_balance(flags, cuentas, @monedas)
      assert File.read!(@archivo_tmp) == esperado
    end

    test "listar_balance escribe en stdout todas las monedas" do
      cuentas = %{"userA" => %{"BTC" => 2.0, "USDT" => 100.0}}
      flags = %{"c1" => "userA"}
      esperado = "BTC=2.000000\nUSDT=100.000000\n"

      assert capture_io(fn ->
               Ledger.Balance.listar_balance(flags, cuentas, @monedas)
             end) == esperado
    end
  end

  describe "Tests para Ledger.CLI" do
    test "procesar_argumentos sin comando" do
      assert {:error, 0} == Ledger.CLI.procesar_argumentos([])
    end

    test "procesar_argumentos con comando inválido" do
      assert {:error, 0} == Ledger.CLI.procesar_argumentos(["asd"])
    end

    test "procesar_argumentos con argumentos válidos" do
      assert {:ok, %{"comando" => "balance", "c1" => "userA"}} ==
               Ledger.CLI.procesar_argumentos(["balance", "-c1=userA"])

      assert {:ok, %{"comando" => "transacciones", "c1" => "userA"}} ==
               Ledger.CLI.procesar_argumentos(["transacciones", "-c1=userA"])
    end

    test "efectuar_comando con comando inválido" do
      assert {:error, 0} == Ledger.CLI.efectuar_comando(%{"comando" => "asd"}, %{}, %{})
    end

    test "efectuar_comando con comando válido" do
      cuentas = %{"userA" => %{"BTC" => 2.0, "USDT" => 100.0}}
      flags_balance = %{"comando" => "balance", "c1" => "userA"}
      flags_transacciones = %{"comando" => "transacciones", "c1" => "userA"}
      assert {:ok, 0} == Ledger.CLI.efectuar_comando(flags_balance, cuentas, @monedas)
      assert {:ok, 0} == Ledger.CLI.efectuar_comando(flags_transacciones, cuentas, @monedas)
    end
  end

  describe "Tests para Ledger.main" do
    test "main con argumentos inválidos" do
      assert {:error, 0} == Ledger.main([])
      assert {:error, 0} == Ledger.main(["asd"])
      assert {:error, 0} == Ledger.main(["balance"])
    end

    test "main con comando balance y argumentos válidos" do
      contenido = """
      1;1756751403;USDT;;100.0;userA;;alta_cuenta
      2;1756751404;USDT;;100.0;userB;;alta_cuenta
      3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
      4;1756751406;BTC;;2.0;userC;;alta_cuenta
      5;1756751407;BTC;USDT;1.0;userC;;swap
      """

      File.write!(@archivo_tmp, contenido)

      esperado = %{
        "userA" => %{"USDT" => 50.0},
        "userB" => %{"USDT" => 150.0},
        "userC" => %{"BTC" => 1.0, "USDT" => 55000.0}
      }

      assert {:ok, 0} ==
               Ledger.main([
                 "balance",
                 "-c1=userA",
                 "-m=ARS",
                 "-t=#{@archivo_tmp}",
                 "-o=stdout"
               ])

      assert esperado == Ledger.Transaction.procesar_transacciones(@archivo_tmp, @monedas)
    end

    test "main con comando transacciones y argumentos válidos" do
      contenido = """
      1;1756751403;USDT;;100.0;userA;;alta_cuenta
      2;1756751404;USDT;;100.0;userB;;alta_cuenta
      3;1756751405;USDT;USDT;50.0;userA;userB;transferencia
      4;1756751406;BTC;;2.0;userC;;alta_cuenta
      5;1756751407;BTC;USDT;1.0;userC;;swap
      """

      File.write!(@archivo_tmp, contenido)

      esperado = %{
        "userA" => %{"USDT" => 50.0},
        "userB" => %{"USDT" => 150.0},
        "userC" => %{"BTC" => 1.0, "USDT" => 55000.0}
      }

      assert {:ok, 0} ==
               Ledger.main([
                 "transacciones",
                 "-c1=userA",
                 "-t=#{@archivo_tmp}",
                 "-o=stdout"
               ])

      assert esperado == Ledger.Transaction.procesar_transacciones(@archivo_tmp, @monedas)
    end
  end
end
