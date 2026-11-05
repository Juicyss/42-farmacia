#!/usr/bin/env bash
# Instala todo lo necesario en una EC2 Ubuntu 24.04 (AWS Academy).
set -euo pipefail

echo "==> Paquetes del sistema (Erlang/OTP, git, jq, asciinema)"
sudo apt-get update -y
sudo apt-get install -y erlang-nox erlang-dev erlang-eunit git curl jq asciinema

echo "==> rebar3"
curl -fsSLo /tmp/rebar3 https://github.com/erlang/rebar3/releases/download/3.22.1/rebar3
chmod +x /tmp/rebar3
sudo mv /tmp/rebar3 /usr/local/bin/rebar3

echo "==> Versiones"
erl -noshell -eval 'io:format("Erlang/OTP ~s~n", [erlang:system_info(otp_release)]), halt().'
rebar3 version
asciinema --version
echo "Listo."
