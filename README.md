# #42 — Farmacia

**Dominio:** Salud · inventario por lote, caducidades (FEFO) y recetas.
**Alumno:** Hugo Iram Aguirre Dávila · ISC · TecNM Tijuana · Programación Lógica y Funcional

## Equipo

| Rol | Integrante |
|---|---|
| Backend (OTP) | Hugo Iram Aguirre Dávila |
| Frontend (Stitch + cowboy) | Hugo Iram Aguirre Dávila |
| Ops/QA | Hugo Iram Aguirre Dávila |

## Arranque

```bash
rebar3 compile
rebar3 eunit          # 14 pruebas
rebar3 shell          # abre http://localhost:8080
```

Release + systemd: ver `deploy/p42_farmacia.service` y `scripts/`.

## Diseño OTP

```
p42_farmacia_sup (one_for_one)          <- duenio de las tablas ETS
├── p42_bitacora        gen_server   eventos + suscriptores SSE (tiempo real)
├── p42_farmacia_server gen_server   ping/estado (esqueleto original)
├── p42_inventario      gen_server   UNICO escritor de existencias; FEFO; reglas de venta
├── p42_recetas_sup     supervisor   simple_one_for_one, restart transient
│   └── p42_receta      gen_statem   uno por receta: emitida → surtida_parcial → surtida | vencida
└── p42_revisor         gen_server   revisor periodico de caducidades y reorden (independiente)
```

| Decisión | Por qué (casos difíciles) |
|---|---|
| `p42_inventario` es el único que escribe existencias | El buzón de un gen_server serializa los mensajes: **dos mostradores pidiendo el último blister** quedan en fila; uno se lleva el lote A y el otro recibe el lote B o "sin existencias". Nunca hay sobreventa. |
| Un `gen_statem` por receta | **Surtir la misma receta en paralelo**: ambos pedidos llegan al mismo proceso; el primero la deja `surtida`, el segundo recibe `ya_surtida`. **Surtido parcial en dos visitas** = estado `surtida_parcial`. La vigencia es un timeout que la pasa a `vencida`. |
| ETS cuyo dueño es el supervisor raíz | Si se mata el inventario o una receta, el supervisor lo reinicia y **retoma el estado desde ETS** (no se pierde stock ni el avance de la receta). Por eso basta `one_for_one`. |
| `p42_recetas_sup` con `transient` | Una receta que muere anormalmente se reinicia; una que termina normal, no. Si una receta truena, no afecta a las demás. |
| Folios de controlados con `ets:insert_new` | **Receta de controlado ya usada en otra sucursal**: la inserción es atómica, el segundo intento recibe `{folio_ya_usado, Sucursal}`. |
| Tabla `p42_ventas` (bag) por lote | **¿Cómo localizar a todos los clientes de un lote retirado?** Búsqueda directa por llave = O(1) por lote. |
| `p42_revisor` separado | Si el revisor truena, las ventas siguen. Si el inventario truena, el revisor sigue. |

### Reglas inviolables (están en el código, no en el criterio del empleado)

1. FEFO: siempre sale primero el lote que caduca antes.
2. Nunca se surte un lote caducado ni uno retirado por alerta sanitaria.
3. Lo que no es de venta libre (receta, antibiótico, controlado) solo se surte con receta.
4. Alergia del paciente al principio activo → receta rechazada.
5. Interacciones peligrosas (warfarina + ibuprofeno / aspirina; clonazepam + tramadol) → rechazada.
6. Controlados exigen folio y el folio solo se usa una vez en toda la cadena.
7. Devoluciones: solo reingresan si vienen **sin abrir**, el lote no está retirado ni caducado; lo demás es merma.

## API (cowboy)

| Método | Ruta | Qué hace |
|---|---|---|
| GET | `/api/estado` | Resumen para el tablero |
| GET | `/api/productos?q=` · `/api/productos/:sku` | Buscar / detalle con lotes |
| GET | `/api/caducidades?dias=90` | Lotes por caducar (FEFO) |
| GET | `/api/criticos` | Productos en punto de reorden |
| POST | `/api/recetas` | Emitir receta (valida reglas) |
| POST | `/api/recetas/:id/surtir` | Surtir (body `{"mostrador":1}`) |
| POST | `/api/ventas` | Venta libre de mostrador |
| POST | `/api/lotes/:lote/retirar` | Alerta sanitaria: retira y devuelve a quién se vendió |
| GET | `/api/lotes/:lote/clientes` | Trazabilidad del lote |
| POST | `/api/devoluciones` | `{"lote","cantidad","motivo":"sin_abrir"\|"abierto"}` |
| GET | `/api/bitacora` · `/api/eventos` (SSE) | Bitácora / tiempo real |
| POST | `/api/simular` | Escenario completo del problema |
| POST | `/api/caos/:objetivo` | `inventario`, `receta`, `revisor`, `doble_surtido` |
| GET | `/metrics` | Formato Prometheus (+ diagnóstico con `recon`) |

## Simulación del escenario

`POST /api/simular` (o `p42_sim:escenario().` en el shell):

- 1,500 productos generados (12 reales + sintéticos), ~3,000 lotes con caducidades aleatorias.
- 3 mostradores en paralelo, 400 ventas en total (70% venta libre, 30% con receta).
- 40 ventas del lote `L-ALERTA-01`, luego se retira → se localizan los 40 clientes y la siguiente venta sale de `L-OMEP-B`.
- Dos mostradores piden al mismo tiempo el último blister de `L-LORA-A` → uno recibe A, el otro B; A queda en 0.
- **Fallas inyectadas** a media corrida: `kill` a `p42_inventario` y a una receta; los mostradores reintentan.
- Receta de controlado con folio usado en otra sucursal → rechazada.

## Prueba de caos

| Qué maté | Qué esperaba | Qué ocurrió |
|---|---|---|
| `p42_inventario` (`exit(Pid, kill)`) | Reinicio con otro pid sin perder stock | Nuevo pid, `unidades_antes == unidades_despues` |
| Una receta en `surtida_parcial` | Reinicio y conserva su estado | Nuevo pid, sigue `surtida_parcial` |
| `p42_revisor` | Reinicio, las ventas no se enteran | Nuevo pid, reanuda revisión |
| Surtir la misma receta 2 veces en paralelo | 1 éxito, 1 rechazo | 1 `surtida`, 1 `ya_surtida` |

## Supuestos propios

- Las existencias viven en ETS en memoria (no PostgreSQL): si se reinicia todo el nodo, se regenera el catálogo. Suficiente para la demo; en producción se persistiría con epgsql.
- "Caducidad cercana" = 90 días (configurable en `sys.config`, `dias_alerta_caducidad`).
- Vigencia de receta por defecto: 30 días.
- Cada producto sintético tiene 1–3 lotes con 6–120 unidades y caducidad entre −15 y +720 días.
- Distribución sintética: 60% venta libre, 25% receta, 12% antibiótico, 3% controlado.
- Si el inventario muere exactamente a mitad de un surtido, la receta reporta `inventario_no_disponible` y el mostrador reintenta.
- Se usó Erlang/OTP 25 (paquete de Ubuntu 24.04) con rebar3 3.22.1; el código no usa nada exclusivo de OTP 27.

## Cifras del problema que verifiqué

- Antibióticos con receta en México desde 2010: acuerdo publicado en el DOF en mayo de 2010, multas desde agosto 2010; la farmacia retiene o sella la receta. Fuentes: [Gaceta Médica de México 2015](https://www.medigraphic.com/pdfs/gaceta/gm-2015/gm155s.pdf), [Boletín Fármacos nov 2010](https://www.saludyfarmacos.org/boletin-farmacos/boletines/nov2010/En-agosto-multas-por-ventas).
- 1,500 productos, 3 mostradores, 400 ventas/día y 40 unidades vendidas del lote retirado: tomadas del enunciado como órdenes de magnitud.

## Pendiente (checklist del profe)

- [x] Diseñar pantallas en Stitch (`design/`)
- [x] Modelar el dominio: procesos y supervisores
- [x] Endpoints `/api/...` y tiempo real (SSE) con cowboy
- [x] Métricas `/metrics` y diagnóstico con recon
- [x] Release + systemd
- [x] Prueba de caos
