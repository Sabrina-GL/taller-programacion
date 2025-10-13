# Makefile para Ledger

MIX = mix
ESCRIPT = ./ledger
MIX_ENV ?= dev

# Comandos con entorno específico
MIX_DEV = MIX_ENV=dev $(MIX)
MIX_TEST = MIX_ENV=test $(MIX)

.PHONY: all deps compile test clean

all: compile

deps:
	$(MIX) deps.get

compile:
	$(MIX) compile

escript:
	$(MIX) escript.build

docker:
	docker compose up -d

# Comandos de base de datos - especificar entorno explícitamente
db-create:
	$(MIX_DEV) ecto.create

db-migrate:
	$(MIX_DEV) ecto.migrate

db-drop:
	$(MIX_DEV) ecto.drop

db-reset: db-drop db-create db-migrate

# Comandos de base de datos para test
test-db-drop:
	-$(MIX_TEST) ecto.drop

test-db-create:
	$(MIX_TEST) ecto.create

test-db-migrate:
	$(MIX_TEST) ecto.migrate

test-db-reset: test-db-drop test-db-create test-db-migrate


test: compile test-db-reset
	$(MIX_TEST) test

clean:
	$(MIX) clean

redo: clean compile escript

crear: escript
	$(ESCRIPT) crear_usuario -n=Juan -b=1900-05-06
	$(ESCRIPT) crear_usuario -n=Ana -b=1980-11-23
	$(ESCRIPT) crear_moneda -n=ARG -p=0.5
	$(ESCRIPT) crear_moneda -n=USDT -p=1
	$(ESCRIPT) alta_cuenta -u=1 -m=1 -a=100
	$(ESCRIPT) alta_cuenta -u=2 -m=1 -a=200

ver:
	$(ESCRIPT) ver_usuario -id=1
	$(ESCRIPT) ver_usuario -id=2
	$(ESCRIPT) ver_moneda -id=1
	$(ESCRIPT) ver_moneda -id=2

# Comando para verificar estado
status:
	@echo "=== Desarrollo ==="
	-$(MIX_DEV) ecto.version
	@echo "=== Test ==="
	-$(MIX_TEST) ecto.version