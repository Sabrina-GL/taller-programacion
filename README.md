# Cuando abrís todo de nuevo

## Levantar la base de datos con Docker

docker compose up -d


Esto arranca el contenedor de Postgres.

## (Solo la primera vez o cuando agregues migraciones nuevas) correr las migraciones:

mix ecto.migrate


## Compilar el proyecto

mix compile


## Generar el ejecutable CLI

mix escript.build


## Usar los comandos que pide el TP:

./ledger crear_usuario -n=pepe -b=1990-01-01
./ledger ver_usuario -id=1
# TP1 - Ledger

**Ledger es un sistema de libro contables que registra transacciones de
diferentes monedas entre usuarios. El sistema se basa en archivos CSV, funcionando como una base de datos accesible.**


## Compilación

### Compilar el proyecto
```
mix compile
```

### Crear ejecutable escript
```
mix escript.build
```


## Ejecución

### Usar el ejecutable
```
./ledger balance -c1=userA
```


## Estructura de archivos

### Archivo de monedas (monedas.csv)
Función: Actúa como el registro maestro de las monedas disponibles y su valor de referencia en USD.

Formato: Cada línea representa una moneda.

Estructura:
```
nombre_moneda;precio_usd
```

Ejemplo:
```text
BTC;55000
ETH;3000
ARS;0.0012
USDT;1
EUR;1.18
```

### Archivo de transacciones(transacciones.csv)
Función: Registra immutablemente toda actividad financiera en el sistema. Cada línea es una transacción.

Formato: Cada línea representa una transacción única.

Estructura:

```
id_transaccion;timestamp;moneda_origen;moneda_destino;monto;cuenta_origen;cuenta_destino;tipo
```

* id_transaccion es un identificador unico por transaccion
* fecha_hora indica en que momento se realizo la transaccion
* moneda_origen y moneda_destino indican en que moneda esta el valor de la
cuenta de origen y destino, respectivamente
* monto indica el monto de la transaccion
* cuenta_origen y cuenta_destino son los identificadores unicos de las cuentas
de origen y destino, respectivamente
* tipo indica el tipo de transaccion, y este puede ser:
  * transferencia : una transaccion que transfiere un monto de una cuenta a otra
  * swap : una transaccion que convierte un monto en una moneda a otra
  * alta_cuenta : una transaccion que crea una cuenta y fija su valor inicial

Ejemplo:
```
1;1754937004;USDT;USDT;100.50;userA;userB;transferencia
2;1755541804;BTC;USDT;0.1;userB;;swap
3;1756751404;BTC;;50000;userC;;alta_cuenta
```


## Comando balance

### Para mostrar el balance de una cuenta:
```
./ledger balance -c1=userA
```
El subcomando balance calculará el balance de una cuenta. En
este subcomando, el flag -c1 es obligatorio. Si no se completa el flag -m se listan los balances de todas las monedas de esa cuenta.

Ejemplos:
```
./ledger balance -c1=867
```
Lista por terminal el balance de todas las monedas de la cuenta 867.

```
./ledger balance -c1=867 -m=BTC
```
Lista por terminal el balance la cuenta 867 convertido a BTC.


### Flags disponibles:
 * **-c1:** especifica la cuenta origen (obligatorio)

 * **-t:** archivo transacciones input (si no se completa toma por default
transacciones.csv )

  * **-m:** moneda a utilizar para el cálculo (si no se completa se listan los balances de todas las monedas de esa cuenta)

  * **-o:** archivo output (si no se completa se imprimen por terminal)


## Comando transacciones

### Para listar transacciones entre cuentas:
```
./ledger transacciones -c1=userA -c2=userB
```

El subcomando transacciones listará por pantalla todas las transacciones que cumplen con los flags propuestos.

Ejemplos:
```
./ledger transacciones
```
Lista por terminal todas las transacciones del archivo transacciones.csv


```
./ledger transacciones -t=transac.csv -c1=345 -o=result.csv
```
Lista todas las transacciones del archivo transac.csv que fueron realizadas desde la cuenta 345 y las almacena en el archivo result.csv

### Flags disponibles:
 * **- c1:** especifica la cuenta origen (si no se completa, toma todas las cuentas)

  * **- c2:** especifica la cuenta destino (si no se completa, toma todas las cuentas)

 * **- t:** archivo transacciones input (si no se completa toma por default
transacciones.csv )

  * **- o:** archivo output (si no se completa se imprimen por terminal)

## Tests

### Para ejecutar los tests:
```
mix test
```

## Validaciones y errores chequeados
 En caso de encontrar una incosistencia, se muestra por pantalla la tupla {:error, <nro linea>} . Por ejemplo si la línea 45 no cuenta con el formato indicado, de devolverá {:error, 45} , de la misma manera si una transacción se realiza en una moneda no existente, si un monto es negativo, etc. 

### Errores de cuenta

* Cuenta no dada de alta previo a realizar una transacción con ella
* Cuenta proporcionada por un flag no existe
* Cuenta intenta realizar un swap o transferencia con un monto mayor al que posee

### Errores de monedas

* Moneda proporcionada por un flag no existe en el archivo monedas.csv
* Moneda origen o moneda destino no existe en el archivo monedas.csv
* Moneda origen y moneda destino no coinciden al realizar una transferencia

### Errores de comandos

* No se proporciona ningún comando
* El comando proporcionado no es válido

### Errores de archivos

* Fallo al leer el archivo
* El archivo de transacciones o monedas está vacío

### Errores de montos

* Se intenta transferir un monto inválido (negativo o cero)

## Documentación

Para documentación detallada de todos los módulos, funciones y tipos, se puede consultar la documentación completa en HexDocs:

[https://hexdocs.pm/ledger/Ledger.html](https://hexdocs.pm/ledger/Ledger.html)
