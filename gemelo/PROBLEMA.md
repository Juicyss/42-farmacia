# #42 — Farmacia: gemelo digital con programación lógica

> Extensión del proyecto #42. El problema original está en
> [`../problema/readme.md`](../problema/readme.md) y no cambia. Aquí no hay solución:
> la construyes tú, con apoyo de tu agente (ver [`CONTEXTO_AGENTES.md`](CONTEXTO_AGENTES.md)).
> Es un ejercicio con datos simulados, no un sistema de dispensación real.

## Del simulador al gemelo

En la parte de Erlang simulaste la farmacia: un inventario por lote, recetas que pasan de
emitidas a surtidas, un revisor de caducidades y dos mostradores que no deben vender lo
mismo dos veces. Esa simulación responde «¿qué hay en el estante y qué ocurrió con la
receta?». El farmacéutico necesita algo más: «¿le surto esto a esta persona, de qué lote,
y por qué?».

El gemelo digital es el **modelo lógico** de la farmacia: hechos que reflejan su estado y
reglas que reflejan cómo se decide en ella. Se escribe en Prolog porque lo que hay que
resolver aquí no es contar existencias, sino decidir quién puede recibir qué, justificar
la negativa y reconocer cuándo la farmacia no tiene cómo saber.

## La farmacia que se clona

Una farmacia comunitaria de Tijuana con dos sucursales, reducida a unos diez
medicamentos, tres mostradores en la sucursal principal y cuatro pacientes.

| Parte | Contenido |
|---|---|
| Entidades | sucursal → mostrador; medicamento → lote → unidad; receta; paciente; médico |
| Estado por medicamento | principio activo, requisito de venta (libre, con receta o controlado) |
| Estado por lote | caducidad, unidades disponibles, si está retirado, en qué estante |
| Estado por receta | tipo (común o especial), qué prescribe y cuánto, cuánto se ha surtido, dónde, si está retenida |
| Estado por paciente | alergias declaradas, medicamentos que ya recibió |
| Eventos | se emite una receta, se surte (completa o parcial), se devuelve un producto, se retira un lote, llega una alerta sanitaria |
| Decisiones | ¿se surte?, ¿de qué lote?, ¿cuánto?, ¿se retiene la receta?, ¿a quién se avisa? |

## Situaciones que tu gemelo debe razonar

Las cinco parten del problema original; la 2, la 4 y la 5 llevan un complemento derivado
(se indica en cada una). En cada una, tu gemelo debe llegar a una decisión **y poder
explicarla**.

### Situación 1 — La receta que parece buena

- **Qué pasa.** Un paciente llega al mostrador con receta de un medicamento controlado.
  El papel está firmado y trae el nombre correcto. Pero la receta de un controlado debe
  ser especial, quedar registrada y asentarse en el libro de control, y esta pudo haberse
  surtido ya en la otra sucursal. Un error aquí es una sanción de la autoridad sanitaria
  y un desvío de un producto peligroso.
- **Qué datos hay.** Requisito de venta de cada medicamento, tipo de receta, registro de
  surtidos por sucursal y el libro de control. Ningún dato dice «receta válida».
- **Qué debe deducir.** Si la receta cumple lo que ese medicamento exige, si ya se usó, y
  si el registro de la otra sucursal es consultable. Un antibiótico exige receta
  retenida o registrada; uno de venta libre no.
- **Qué debe contestar.** Surtir, rechazar o suspender, con el requisito que falla. Si la
  otra sucursal no ha reportado, la respuesta es «no se sabe», distinta de «no se usó».
- **Por qué es lógica.** La validez nace de cruzar tipo de medicamento, tipo de receta y
  registro. Lo intuitivo («trae receta, se surte») está mal para un controlado.

### Situación 2 — Medio tratamiento hoy, el resto mañana

- **Qué pasa.** Una receta de antibiótico pide más cajas de las que hay en estante. El
  paciente se lleva una parte hoy y volverá por el resto. La farmacia debe retener o
  registrar la receta, pero si la retiene entera, el paciente no podría completar el
  tratamiento en otra farmacia, y si no la retiene, podría surtirse dos veces. (Complemento
  derivado: que el paciente quiera cambiar de farmacia.)
- **Qué datos hay.** Lo prescrito, lo surtido en cada visita, el registro de la receta y
  las existencias por lote.
- **Qué debe deducir.** Lo que falta por surtir a partir de lo ya surtido; si lo que
  pide el mostrador cabe en lo que falta; qué cuenta como receta cerrada.
- **Qué debe contestar.** Cuánto se surte, qué anotación queda en la receta y si se
  retiene, con la razón. Frente al dilema (el paciente necesita completar contra el
  riesgo de duplicar), qué parte pierde y por qué.
- **Por qué es lógica.** El estado de la receta cambia con cada visita; los límites se
  deducen del historial, no de un contador suelto.

### Situación 3 — El último blister

- **Qué pasa.** Dos mostradores atienden a dos pacientes al mismo tiempo y los dos
  piden el último blister del lote que caduca primero. El otro lote del mismo
  medicamento caduca más tarde. La regla de la casa es surtir primero el lote que
  caduca antes; pero un paciente lleva un tratamiento largo y el otro uno corto.
- **Qué datos hay.** Lotes con su caducidad, unidades disponibles, las dos solicitudes
  con su duración de tratamiento y el instante en que llegó cada una.
- **Qué debe deducir.** Qué lote le corresponde a cada paciente, quién se queda con el
  último blister del lote que vence primero y quién no.
- **Qué debe contestar.** El reparto completo (con alternativas válidas si las hay) y por
  qué a uno se le falla o se le da otro lote. Lo «obvio» es dárselo a quien llegó
  primero con el lote que caduca antes: pregunta si eso siempre conviene.
- **Por qué es lógica.** Hay una política (primero el que caduca antes), un límite (el
  tratamiento no debe sobrevivir a la caducidad) y un desempate. Declararlas una vez
  hace que valgan en todos los casos.

### Situación 4 — El lote retirado: ¿quién se lo llevó?

- **Qué pasa.** Llega una alerta sanitaria y un lote se retira. De ese lote ya se
  vendieron unidades. Algunas con receta registrada, otras de mostrador sin dato del
  comprador. Además hay una devolución de otra unidad: no se sabe si es del lote
  retirado. (Complemento derivado: el rastro por receta.)
- **Qué datos hay.** Ventas con lote y receta, los datos de contacto cuando existen, la
  alerta con su instante y las devoluciones.
- **Qué debe deducir.** A quién avisar, a quién se le puede localizar y a quién no, qué
  unidades siguen en la farmacia y cuáles hay que sacar del estante, y si lo devuelto
  vuelve al inventario o no.
- **Qué debe contestar.** La lista de pacientes por avisar, la lista de ventas sin
  rastro (marcadas como «no se sabe a quién») y qué se hace con cada devolución.
  Lo devuelto, ¿regresa al inventario? El gemelo debe decir de qué depende.
- **Por qué es lógica.** Es una cadena: lote, venta, receta, paciente, aviso. Y el dato
  que falta no se rellena: se declara como desconocido.

### Situación 5 — Con receta, pero no para esta persona

- **Qué pasa.** Una receta correcta, vigente y firmada trae un medicamento al que el
  paciente es alérgico por el principio activo, aunque con otro nombre comercial. En otro
  caso, el medicamento chocaría con uno que el paciente recibió hace unos días en la otra
  sucursal. Y hay un paciente cuya alergia nunca se capturó. (Complemento derivado: el
  historial entre visitas.)
- **Qué datos hay.** Medicamentos con su principio activo, las alergias declaradas, la
  tabla de interacciones peligrosas que tú definas y lo que el paciente ya recibió.
- **Qué debe deducir.** Qué medicamentos contienen el principio al que alguien es
  alérgico, qué pares chocan, y qué pasa cuando la alergia no consta.
- **Qué debe contestar.** No surtir y a quién consultar, o surtir con una advertencia, y
  el hecho que lo bloquea. Para quien no tiene alergias capturadas: «no se sabe», no
  «no es alérgico». El médico y el paciente tienen razón (uno prescribió, el otro está en
  riesgo); la regla decide a quién se le falla.
- **Por qué es lógica.** Hay que encadenar nombre comercial, principio activo, alergia y
  decisión, y reconocer una ausencia de dato como incertidumbre.

## Por qué no basta un script

Con `if caducidad < hoy: rechazar()` resuelves un lote con datos perfectos. Tu gemelo
debe contestar, **con las mismas reglas**:

| Pregunta | Tipo de consulta |
|---|---|
| ¿Le surto esta receta a este paciente? | decisión |
| ¿Por qué no se puede surtir la receta del controlado? | explicación |
| ¿Qué lotes están vencidos, retirados o por caducar? | todas las respuestas |
| ¿Qué le falta a la receta para poder surtirse? | pregunta al revés |
| ¿Qué pasaría si retiran el lote que caduca primero? | hipótesis |

En un script, cada pregunta es una función nueva. En un modelo lógico son cinco consultas
sobre lo mismo. Prolog aquí no es un accesorio de otra herramienta: es el programa.

## Preguntas guía

1. ¿Qué reglas son inviolables y deben estar en el sistema y no en el criterio del
   empleado?
2. ¿Cómo localizas rápidamente todos los clientes de un lote retirado, y qué haces con
   las ventas que no dejaron rastro?
3. ¿Cómo distingue tu gemelo «la receta no se ha usado» de «no sé si se usó»?
4. ¿Qué parte de la explicación le sirve al farmacéutico y qué parte es ruido?
5. ¿Qué evento de tu simulación en Erlang (la segunda surtida de la misma receta, el
   lote que se retira) podría alimentar a este gemelo?

## Qué entregas

- El gemelo en SWI-Prolog: hechos de la farmacia, reglas y su servidor web.
- Pruebas plunit: al menos una por situación.
- La interfaz, diseñada en Google Stitch. Solo pregunta al gemelo y muestra la decisión
  con su explicación; ninguna regla vive en la interfaz.
- Tus supuestos y las cifras de este documento que verificaste.
- Un párrafo: qué resolviste en Erlang, qué en Prolog, y por qué cada cosa en su lugar.
- Opcional: llamar a Python **desde** Prolog (Janus) para generar ventas simuladas o
  graficar.

## Supuestos de esta extensión

- Escala reducida: unos diez medicamentos, 2 sucursales, 3 mostradores y 4 pacientes,
  contra los 1,500 productos y 400 ventas al día del escenario original. Los lotes y las
  unidades de los ejemplos (cuántas unidades del lote retirado se vendieron, cuántas cajas
  pide una receta) son números de escala reducida que fijas tú; los 40 vendidos del
  original no se reproducen. Las ciudades de las sucursales son ilustrativas.
- El «ahora» es un hecho del modelo, en días, no el reloj del sistema, para que las
  respuestas se puedan repetir. Cuántos días equivalen a los «3 meses» de caducidad
  cercana lo defines tú.
- No vienen del original y los fijas tú, con fuente verificada: cuánto dura vigente una
  receta, cuántas surtidas parciales admite, las interacciones peligrosas y los
  principios activos de cada medicamento, y desde cuándo un dato sin reportar vuelve
  dudosa una receta.
- Quién es alérgico a qué, qué se vendió y a quién, y qué sucursal reporta tarde son datos
  que defines en el escenario.

## Extensiones posibles

Para quien quiera ir más lejos. Estas situaciones no vienen del problema original:
investiga y cita tus fuentes antes de fijar cifras.

- Sustitución por genérico: qué se puede cambiar y quién lo autoriza.
- Cadena de frío: medicamentos que se echan a perder si el refrigerador falla.
- Punto de reorden y pedido bajo demanda según rotación y costo.
- Receta falsificada o alterada y a quién se reporta.
- Auditoría: reconstruir qué pasó con una unidad desde la compra hasta el paciente.

---
*Las cifras son de referencia y vienen del problema original (2010 para antibióticos con
receta, caducidad cercana de 3 meses, 1,500 productos, 3 mostradores, 400 ventas al día,
40 unidades vendidas del lote retirado). Verifica la fuente vigente antes de citarlas en
tu entrega.*
