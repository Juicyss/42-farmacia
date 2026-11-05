# #42 — Farmacia: el problema

## Contexto
Una farmacia (de hospital o comunitaria) controla miles de medicamentos con fecha de caducidad, lote y reglas de venta. Un error de surtido puede dañar a una persona y un medicamento vencido es riesgo y perdida. En Mexico, la Ley General de Salud y COFEPRIS regulan la venta de antibioticos y medicamentos controlados con receta.

## Datos del mundo real
- Los medicamentos se clasifican por requisito: de venta libre, con receta, y controlados (psicotropicos y estupefacientes) que exigen receta especial, registro y libro de control.
- Desde 2010 los antibioticos en Mexico requieren receta medica y la farmacia debe retenerla o registrarla.
- **FEFO:** se surte primero el lote que caduca antes; es comun tener varios lotes del mismo medicamento en estantes distintos.
- Para insumos de alta rotacion se manejan puntos de reorden; los de bajo consumo y alto costo se piden bajo demanda.
- Algunas combinaciones de medicamentos tienen interacciones peligrosas; los alergicos a un principio activo no deben recibirlo.
- Caducidad cercana (por ejemplo, menos de 3 meses) activa promociones, devoluciones al proveedor o retiro.

## El problema
Controlar existencias por lote y caducidad, validar una receta contra el inventario y las reglas de venta, surtir sin sobre-vender el mismo lote ante ventas simultaneas, retener recetas de controlados, alertar caducidades proximas y quiebres de stock, y poder retirar un lote reportado como defectuoso.

## Escenario a simular
- 1,500 productos, 3 mostradores, 400 ventas al dia.
- Un lote retirado por alerta sanitaria con 40 unidades ya vendidas.
- Dos mostradores surtiendo el ultimo blister del lote que caduca primero.

## Casos dificiles
- Receta surtida parcialmente en dos visitas.
- Receta de controlado ya usada en otra sucursal.
- Devolucion de un producto: ¿regresa al inventario?

## Preguntas guia
1. ¿Que reglas son inviolables y deben estar en el sistema y no en el criterio del empleado?
2. ¿Como localizas rapidamente todos los clientes de un lote retirado?

## Que debes entregar (sin que aqui se de la solucion)
- Un diseño OTP explicado brevemente: procesos, supervisores y quien reinicia a quien, justificando cada decision frente a los casos dificiles de arriba.
- La simulacion del escenario descrito, con datos generados y fallas inyectadas.
- Una lista de supuestos propios y de las cifras de este documento que verificaste.
- Una prueba de caos: que mataste, que esperabas y que ocurrio.
- `rebar3 compile` y `rebar3 eunit` en verde; capturas de Stitch y de la app real si hay interfaz.

---
*Las cifras son de referencia (ordenes de magnitud). Verifica la fuente vigente antes de citarlas en tu entrega y anota las que uses en tu README.*
