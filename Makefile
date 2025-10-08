# Makefile para Ledger

MIX = mix
ESCRIPT = ./ledger

.PHONY: all deps compile test clean

all: compile

deps:
	$(MIX) deps.get

compile:
	$(MIX) compile

escript:
	$(MIX) escript.build

db-create:
	$(MIX) ecto.create

db-migrate:
	$(MIX) ecto.migrate

db-drop:
	$(MIX) ecto.drop	

db-reset: db-drop db-create db-migrate

redo: compile escript

test:
	$(MIX) test

clean:
	$(MIX) clean

crear: 
	$(ESCRIPT) crear_usuario -n=Juan -b=1900-05-06
	$(ESCRIPT) crear_moneda -n=ARG -p=0.5
	$(ESCRIPT) alta_cuenta -u=1 -m=1 -a=100

ver:
	$(ESCRIPT) ver_usuario -id=1
	$(ESCRIPT) ver_moneda -id=1
# $(ESCRIPT) ver_cuenta -id=1
