#!/usr/bin/env bash
# Instala lo necesario para el gemelo digital en Ubuntu 24.04 (WSL o EC2 de AWS Academy).
# La PPA es necesaria: el SWI-Prolog de los repositorios de Ubuntu 24.04 es anterior a Janus.
set -euo pipefail

echo "==> SWI-Prolog (PPA estable, trae library(janus)) y matplotlib"
sudo apt-get update -y
sudo apt-get install -y software-properties-common
sudo apt-add-repository -y ppa:swi-prolog/stable
sudo apt-get update -y
sudo apt-get install -y swi-prolog python3-matplotlib

echo "==> ¿Prolog ve a Python?"
swipl -g "use_module(library(janus)), py_call(sys:version, V), writeln(V)" -t halt

echo "==> Pruebas"
swipl -g run_tests -t halt tests/reglas_tests.pl

echo "Listo. Arranca con:  swipl servidor.pl    (abre el puerto 8042 en el grupo de seguridad de EC2)"
