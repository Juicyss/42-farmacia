# Contexto para agentes — gemelo digital del proyecto #42 (Farmacia)

Este archivo es para el agente (OpenCode u otro) que acompaña al estudiante. Léelo
completo, junto con [`PROBLEMA.md`](PROBLEMA.md) y
[`../problema/readme.md`](../problema/readme.md), antes de proponer cualquier cosa.

## Tu papel

- El proyecto es individual y se califica el razonamiento del estudiante. **Explica,
  pregunta y propone; no entregues la solución completa.**
- Antes de escribir una regla, pide al estudiante que la diga en español.
- Primero la prueba plunit, después la regla.
- Trabaja una situación a la vez, en el orden de `PROBLEMA.md`.
- No inventes cifras. Las de `PROBLEMA.md` vienen del problema original; cualquier otra
  (vigencia de la receta, número de surtidas parciales, interacciones, principios
  activos) se marca como supuesto y se le pide al estudiante la fuente.
- Es un ejercicio con datos simulados, no un sistema de dispensación real.

## Dominio

| Término | Significado |
|---|---|
| Venta libre | Medicamento que no exige receta |
| Con receta | Medicamento que exige receta médica; los antibióticos están aquí desde 2010 |
| Controlado | Psicotrópico o estupefaciente: exige receta especial, registro y libro de control |
| Lote | Tanda de fabricación con su propia fecha de caducidad |
| FEFO | Se surte primero el lote que caduca antes |
| Caducidad cercana | Menos de unos 3 meses: activa promoción, devolución al proveedor o retiro |
| Lote retirado | Lote que una alerta sanitaria o un defecto saca de circulación |
| Principio activo | Sustancia que causa el efecto; varios nombres comerciales pueden compartirlo |
| Interacción | Combinación de medicamentos que resulta peligrosa |
| Surtido parcial | Se entrega solo una parte de lo prescrito; el resto queda pendiente |

Cifras de referencia (todas del problema original): antibióticos con receta desde 2010;
caducidad cercana de menos de 3 meses; escenario de 1,500 productos, 3 mostradores y 400
ventas al día; un lote retirado con 40 unidades ya vendidas; dos mostradores sobre el
último blister del lote que caduca primero. Las interacciones, la vigencia de la receta y
los principios activos NO están en el original: el estudiante los fija y los verifica.

## Arquitectura (obligatoria)

- **Todo en SWI-Prolog**: estado, reglas, explicación y servidor web
  (`library(http/...)`, respuestas JSON bajo `/api/`, archivos estáticos para la interfaz).
- **Ninguna decisión del dominio fuera de Prolog.** Ni umbrales ni reglas en JavaScript,
  Python u otro lenguaje. La interfaz solo consulta y muestra.
- Python es opcional y solo **llamado desde Prolog** con Janus (`py_call/2`), para
  generar ventas simuladas o graficar. Prolog nunca es una librería de Python aquí.
- Sin `get_time`, `random` ni fecha del sistema en las reglas: el «ahora» es un hecho.
  Si el escenario necesita azar (qué sucursal reporta tarde), entra como hecho, no se
  sortea.
- Solo bibliotecas estándar de SWI-Prolog (`plunit`, `lists`, `aggregate`, `apply`,
  `clpfd`, `http`).
- Dentro de `gemelo/` aplica este stack, no el de Erlang/OTP del resto del repositorio.
  No modifiques el código Erlang ni `../problema/readme.md`.

## Vocabulario base de hechos

Punto de partida común; el estudiante puede añadir predicados, no renombrar estos.

```prolog
ahora(Dia).                                   % instante del modelo, en días
medicamento(Med, PrincipioActivo, Requisito). % Requisito: libre | receta | controlado
lote(Lote, Med, Caducidad, Estante).          % Caducidad: día del modelo
existencia(Lote, Unidades).
lote_retirado(Lote, Dia).                     % alerta sanitaria, con su instante
paciente(Paciente).
alergia(Paciente, PrincipioActivo).           % solo las declaradas
receta(Receta, Paciente, Medico, Tipo, Med, Cantidad).  % Tipo: comun | especial
evento_receta(Receta, Evento, Sucursal, Dia). % emitida | surtida(N) | retenida | devuelta
interaccion(PrincipioA, PrincipioB).          % pares peligrosos que define el estudiante
```

## Contrato del gemelo

- `decide(+Solicitudes, -Decision, -Explicacion)` — predicado central. `Solicitudes` es
  la LISTA de solicitudes de mostrador (puede ser de una), cada una con paciente, receta
  y cantidad. `Decision` es el reparto completo: qué se surte, de qué lote, cuánto, qué
  se rechaza o suspende y qué se retiene. Al pedir más soluciones, da las demás
  alternativas válidas. Si no existe ninguna (lote agotado, receta inválida), lo dice y
  señala el motivo, sin fallar en silencio. `Explicacion` es una lista de hechos y
  condiciones que lo justifican.
- `situacion(?Entidad, ?Situacion, -Evidencia)` — situaciones deducidas (receta válida,
  receta ya usada, lote por caducar, venta sin rastro, interacción), consultables en
  cualquier dirección.
- Toda condición distingue tres resultados: se cumple, no se cumple, no se sabe. Un dato
  ausente (alergia no capturada, sucursal sin reporte) nunca cuenta como «no».
- La API expone al menos: las existencias por lote, la decisión con su explicación, los
  pacientes por avisar de un lote retirado y «qué falta para que cambie».

## Criterios de aceptación

Sin valores exactos a propósito: el estudiante fija su escenario y sus umbrales.

1. **Receta válida.** La misma receta se surte para un medicamento con receta y se
   rechaza para un controlado si no es especial. Una receta de controlado que otra
   sucursal pudo haber usado, sin reporte de esa sucursal, da «no se sabe» y no se surte
   en silencio.
2. **Surtido parcial.** Dos visitas no suman más de lo prescrito; la evidencia muestra lo
   que falta. Ante el dilema de retener o no la receta, la decisión nombra a qué parte se
   le falla.
3. **Último blister.** Con un solo blister del lote que caduca primero y dos solicitudes,
   el reparto da alternativas válidas y justifica cuál se descarta. Hay al menos un caso
   donde el resultado no coincide con «el lote que caduca antes, al que llegó primero».
4. **Lote retirado.** La consulta devuelve a quién avisar, las ventas sin rastro marcadas
   como «no se sabe» y el destino de cada devolución, todo sustentado en la cadena lote,
   venta, receta, paciente.
5. **Alergia e interacción.** Una receta correcta con un principio activo al que el
   paciente es alérgico no se surte aunque el nombre comercial sea distinto. Un paciente
   sin alergias capturadas recibe «no se sabe», nunca «sin alergias».
6. **Las cinco preguntas** de «Por qué no basta un script» se contestan con consultas
   sobre las mismas reglas, sin predicados duplicados por pregunta.

## Verificación

```bash
swipl -g run_tests -t halt tests/reglas_tests.pl   # pruebas plunit
swipl servidor.pl                                   # arranca el gemelo y su interfaz
```

Nombres de archivo sugeridos: `hechos.pl`, `reglas.pl`, `servidor.pl`,
`tests/reglas_tests.pl`, `web/`. No afirmes que algo pasa si no lo ejecutaste.

## Interfaz

Se diseña en Google Stitch antes de programarla. Debe mostrar las existencias por lote
con su caducidad y estado, la receta con lo prescrito y lo surtido, la decisión con su
explicación, la lista de avisos de un lote retirado (con las ventas sin rastro aparte) y
la respuesta a «qué falta». Debe verse bien en celular.
