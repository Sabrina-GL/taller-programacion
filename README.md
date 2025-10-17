# TP2 - Ledger

**Ledger es un sistema de libro contables que registra transacciones de
diferentes monedas entre usuarios.**


## Comandos de configuración y desarrollo

### Iniciar contenedor Docker
```
make docker
```

### Inicializar proyecto
**Comando completo**
```
make init
```
**Comandos individuales**
```
make deps
make compile
make escript
```

### Inicializar bases de datos
**Base de desarrollo**
```
make db-start
```

### Resettear bases de datos
**Base de desarrollo**
```
make db-reset
```
**Base de tests**
```
make test-db-reset
```

### Ejecutar tests
```
make test
```

## Ejecución

### Usar el ejecutable
```
./ledger balance -c1=userA
```


## Componentes principales
El sistema está compuesto por 3 entidades principales que se almacenan en la base de datos:

### Usuarios
Almacena la información de los usuarios del sistema. La entidad tiene id (numérico), nombre de usuario (string), fecha de nacimiento
(date), fecha de creación de usuario (date), fecha de edición del usuario.
```sql
- id            
- nombre   
- fecha_nacimiento   
- timestamps           -- Fechas de creación y modificación         
```

**Validaciones:**
* Id único, primary key.
* El nombre de usuario es único.
* El usuario debe tener más de 18 años al crear la cuenta.
* El nombre de usuario puede editarse, al editarse, debe ser distinto al que tenía.
* El usuario puede borrarse, solo si no tiene ninguna transacción asociada.
* Todos los campos son obligatorios.

### Monedas
Almacena la información de las monedas del sistema. La entidad tiene id (numerico), nombre de moneda (string), precio en dolares
(float), fecha de creación de moneda (date), fecha de edición de moneda (date).
- id         
- nombre  
- precio_usd   
- timestamps           -- Fechas de creación y modificación          
```

**Validaciones:**
* Id unico, primary key.
* El nombre de la moneda es único, no puede editarse, y debe ser de mínimo 3 letras y máximo 4.
* La moneda puede borrarse, solo si no tiene ninguna transacción asociada.
* El precio no puede ser negativo.
* Todos los campos son obligatorios.

### Transacciones
Almacena la información de las transacciones del sistema. La entidad tiene id (numerico), tipo (string), cuenta origen (foreign key a usuarios), cuenta destino (foreign key a usuarios), moneda origen (foreign_key a monedas), moneda destino (foreign key a monedas), monto (float), precio al momento de la transacción de la moneda origen, precio al momento de la transacción de la moneda destino, timestamp.
```sql
- id                     -- Identificador único
- tipo                   -- Tipo: "alta", "transferencia", "swap"
- cuenta_origen_id (FK)→usuarios.id
- cuenta_destino_id (FK)→usuarios.id -- nil para altas
- moneda_origen_id (FK)→monedas.id
- moneda_destino_id (FK)→monedas.id  -- nil para altas/transferencias
- monto               
- precio_moneda_origen 
- precio_moneda_destino
- timestamps             -- Fechas de creación y modificación        
```
**Validaciones:**
* Id único, primary key.
* Solo puede deshacerse una transaccion si es la última de el/los usuarios asociados.
* Al deshacer una transacción, se genera una nueva, pero opuesta.
  * Caso swap: mismo monto con monedas origen y destino intercambiadas.
  * Caso transferencia: mismo monto con usuarios origen y destino intercambiados 
* Solo se pueden realizar transaccion desde cuentas que han sido creadas previamente.

## Comandos de Usuario

### Crear usuario
```
./ledger crear_usuario -n=<nombre-de-usuario> -b=<fecha-nacimiento>
```
* El nombre de usuario debe ser único.
* Formato esperado para la fecha de nacimiento: AAAA-MM-DD.
* El usuario debe tener más de 18 años.

### Editar usuario
```
./ledger editar_usuario -id=<id-usuario> -n=<nuevo-nombre-de-usuario>
```
* El nuevo nombre debe ser distinto al previo.

### Borrar usuario
```
./ledger borrar_usuario -id=<id-usuario>
```
* El usuario no debe tener transacciones asociadas.

### Ver usuario
```
./ledger ver_usuario -id=<id-usuario> -out=<archivo-de-salida.txt>
```
* El flag *out* es opcional, si no se usa, se muestra la información por salida estándar.

## Comandos de Moneda

### Crear moneda
```
./ledger crear_moneda -n=<nombre-de-moneda> -p=<precio-respecto-dolar>
```
* El nombre de la moneda debe ser único.
* El nombre debe ser de mínimo 3 letras y máximo 4.
* El precio debe ser mayor o igual a 0.

### Editar moneda
```
./ledger editar_moneda -id=<id-moneda> -p=<nuevo-precio-respecto-dolar>
```
* El precio debe ser mayor o igual a 0.

### Borrar moneda
```
./ledger borrar_moneda -id=<id-moneda>
```
* La moneda no debe tener transacciones asociadas.

### Ver moneda
```
./ledger ver_moneda -id=<id-moneda> -out=<archivo-de-salida.txt>
```
* El flag *out* es opcional, si no se usa, se muestra la información por salida estándar.

## Comandos de Transacción

### Alta cuenta
```
./ledger alta_cuenta -u=<id-usuario> -m=<id-moneda> -a=<monto>
```
* Debe existir un usuario asociado con ese id-usuario.
* Debe existir una moneda asociada con ese id-moneda.
* No debe existir una cuenta ya asociada con esos id-usuario e id-moneda.
* El monto debe ser un número positivo.

### Realizar transferencia
```
/ledger realizar_transferencia -o=<id-usuario-origen> -d=<id-usuario-destino> -
m=<id-moneda> -a=<monto>
```
* Deben existir los usuarios asiciados con id-usuario-origen e id-usuario-destino.
* Debe existir una moneda aosciada con ese id-moneda.
* Debe existir una cuenta ya asociada con id-usuario-origen e id-moneda.
* Sino existe una cuenta asociada con id-usuario-destino e id-moneda, se le hace internamente un alta cuenta con monto 0 para poder realizar la transferencia.
* El monto debe ser un número positivo.
* La cuenta desde la que sea realiza la transferencia debe tener un saldo suficiente para realizarla.

### Realizar swap
```
./ledger realizar_swap -u=<id-usuario> -mo=<id-moneda-origen> -md=<id-moneda-destino> -a=<monto>
```
* Debe existir el usuario asiciado con id-usuario.
* Deben existir las monedas aosciadas con id-moneda-origen e id-moneda-destino.
* Debe existir una cuenta ya asociada con id-usuario e id-moneda-origen.
* Sino existe una cuenta asociada con id-usuario e id-moneda-destino, se le hace internamente un alta cuenta con monto 0 para poder realizar el swap.
* El monto debe ser un número positivo.
* La cuenta desde la que sea realiza el swap debe tener un saldo suficiente para realizarlo.

### Deshacer transacción
```
./ledger deshacer_transaccion -id=<id-transaccion>
```
* Debe existir una transacción asociada con *id-transaccion*.
* Solo puede deshacerse una transaccion si es la última de el/los usuarios asociados.
* No puede deshacerse un alta cuenta.
* Al deshacer una transferencia, se realiza una transferencia con el mismo monto con los usuarios origen y destino intercambiados.
* Al deshacer un swap, se realiza un swap con el mismo monto con las monedas origen y destino intercambiadas.

### Ver transacción
```
./ledger ver_transaccion -id=<id-transaccion> -out=<archivo-de-salida.txt>
```
* Debe existir una transacción asociada con *id-transaccion*.
* El flag *out* es opcional, si no se usa, se muestra la información por salida estándar.

### Balance
El comando balance calculará el balance de una cuenta.
```
./ledger balance -c1=<id-usuario> -m=<id-moneda> -out=<archivo-de-salida.txt>
```
* Debe existir un usuario asociado con id-usuario.
* El flag *m* es opcional, si no se usa, se muestra el balance por cada moneda.
* Si se usa el flag *m*, se muestra el balance total convertido al valor de esa moneda.
* El flag *out* es opcional, si no se usa, se muestra la información por salida estándar.
Ejemplos:
```
./ledger balance -c1=867
```
Lista por salida estándar el balance de todas las monedas del usuario 867.

./ledger balance -c1=867 -m=BTC -out=result.txt
Lista el balance del usuario 867 convertido a BTC y lo almacena en el archivo result.txt.

### Transacciones

El subcomando transacciones listará por pantalla todas las transacciones que cumplen con los flags propuestos.
```
./ledger transacciones -c1=<id-usuario-origen> -c2=<id-usuario-destino> -out=<archivo-de-salida.txt>
```
* Los flags *c1* y *c2* son opcionales, si se usan,debe existir un usuario asociado con cada id.
* Si no se pasa *c1* ni *c2*, se listarán todas las transacciones del sistema.
* Si sólo se pasa *c1*, se listarán aquellas transacciones que tengan el id pasado como cuenta de origen.
* Si sólo se pasa *c2*, se listarán aquellas transacciones que tengan el id pasado como cuenta de destino.
* Si se pasan ambos *c1* y *c2*, se listarán aquellas transacciones que tengan el *d-usuario-origen* como cuenta de origen e *id-usuario-destino* como cuenta de destino.
* El flag *out* es opcional, si no se usa, se muestra la información por salida estándar.

Ejemplos:
```
./ledger transacciones
```
Lista por salida estándar todas las transacciones del sistema.

```
./ledger transacciones -t=transac.csv -c1=345 -out=result.txt
```
Lista todas las transacciones del sistema que fueron realizadas desde la cuenta con id 345 y las almacena en el archivo result.txt

## Errores chequeados
 En caso de encontrar una incosistencia, se muestra el error con el siguiente formato:
 ```
 {:error, <comando>: <descripción del error>} . 
```
 Por ejemplo si se quiere dar de alta un usuario con un nombre que ya está en uso, se muestra:
 ```
  {:error, crear_usuario: El nombre ya está en uso}
 ```
