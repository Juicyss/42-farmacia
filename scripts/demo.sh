#!/usr/bin/env bash
# Demo guiada para grabar con asciinema:
#   asciinema rec farmacia42.cast -c ./scripts/demo.sh
# Supone que el servicio ya corre en :8080 (systemd o rebar3 shell en otra terminal).
set -uo pipefail
API=${API:-http://localhost:8080}
PAUSA=${PAUSA:-2}

paso() { echo; printf '\033[1;32m==> %s\033[0m\n' "$*"; sleep "$PAUSA"; }
ver()  { printf '\033[0;36m$ %s\033[0m\n' "$*"; eval "$*"; sleep "$PAUSA"; }

paso "1. Maquina virtual: AWS EC2"
ver "uname -a"
ver "erl -noshell -eval 'io:format(\"Erlang/OTP ~s~n\",[erlang:system_info(otp_release)]),halt().'"

paso "2. Compilar y pruebas unitarias (eunit)"
ver "rebar3 compile 2>&1 | tail -3"
ver "rebar3 eunit 2>&1 | grep -E 'tests|Failed|failures'"

paso "3. El servicio esta arriba (systemd)"
ver "systemctl is-active p42_farmacia || true"
ver "curl -s $API/api/estado | jq '{productos, lotes, unidades, proximos_caducar_total, criticos_total, pid_inventario}'"

paso "4. FEFO: el lote que caduca antes sale primero (el caducado nunca)"
ver "curl -s $API/api/productos/PARA500 | jq '.lotes[] | {lote, caducidad, cantidad}'"
ver "curl -s -X POST $API/api/ventas -d '{\"sku\":\"PARA500\",\"cantidad\":1}' | jq"

paso "5. Regla inviolable: antibiotico sin receta se rechaza"
ver "curl -s -X POST $API/api/ventas -d '{\"sku\":\"AMOX500\",\"cantidad\":1}' | jq"

paso "6. Receta: alergia e interaccion se rechazan"
ver "curl -s -X POST $API/api/recetas -d '{\"paciente\":\"Ana\",\"alergias\":[\"amoxicilina\"],\"items\":[{\"sku\":\"AMOX500\",\"cantidad\":1}]}' | jq"
ver "curl -s -X POST $API/api/recetas -d '{\"paciente\":\"Beto\",\"items\":[{\"sku\":\"WARF5\",\"cantidad\":1},{\"sku\":\"IBU400\",\"cantidad\":1}]}' | jq"

paso "7. Receta valida -> surtir -> surtir otra vez (rechazada)"
ID=$(curl -s -X POST $API/api/recetas -d '{"paciente":"Carla","items":[{"sku":"AMOX500","cantidad":2}]}' | jq -r .id)
echo "receta creada: $ID"; sleep "$PAUSA"
ver "curl -s -X POST $API/api/recetas/$ID/surtir -d '{\"mostrador\":1}' | jq"
ver "curl -s -X POST $API/api/recetas/$ID/surtir -d '{\"mostrador\":2}' | jq"

paso "8. Surtido parcial en dos visitas (solo hay 6 losartan, piden 10)"
ID2=$(curl -s -X POST $API/api/recetas -d '{"paciente":"Diego","items":[{"sku":"LOSA50","cantidad":10}]}' | jq -r .id)
ver "curl -s -X POST $API/api/recetas/$ID2/surtir -d '{\"mostrador\":1}' | jq '{estado, entregado}'"

paso "9. PRUEBA DE CAOS: kill al inventario"
ver "curl -s -X POST $API/api/caos/inventario | jq"

paso "10. PRUEBA DE CAOS: surtir la misma receta 2 veces en paralelo"
ver "curl -s -X POST $API/api/caos/doble_surtido | jq '{exitosos, correcto, resultados: [.resultados[] | {mostrador, r: (.resultado.error // .resultado.ok.estado)}]}'"

paso "11. Simulacion del escenario: 1500 productos, 3 mostradores, 400 ventas, fallas inyectadas"
ver "curl -s -X POST $API/api/simular | jq '{productos, lotes, mostradores, fallas_inyectadas, lote_retirado, ultimo_blister: {lote_a_queda: .ultimo_blister.lote_a_queda, sobreventa: .ultimo_blister.sobreventa}, controlado_otra_sucursal, doble_surtido: .doble_surtido.correcto, duracion_ms}'"

paso "12. Metricas Prometheus + recon"
ver "curl -s $API/metrics | grep -v TYPE"

paso "Fin de la demo. Interfaz web en http://<IP-publica>:8080"
