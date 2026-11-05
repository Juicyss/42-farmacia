# Prompt para Google Stitch — #42 Farmacia

Copia y pega esto en https://stitch.withgoogle.com (modo Mobile o Web):

```
Diseña una app web responsiva en español para la farmacia de un hospital llamada
"Farmacia #42". Estilo limpio, profesional, color principal verde farmacia (#0f6e5c),
fondo gris muy claro, tarjetas blancas con bordes redondeados. Colores de estado:
verde = ok, ámbar = alerta (caduca pronto / punto de reorden), rojo = falla
(caducado, lote retirado, receta rechazada). Debe verse bien en celular.

Pantallas:
1. Tablero en tiempo real: barra superior con nombre y un punto "en vivo".
   Tarjetas KPI: Productos, Lotes, Unidades, Próximos a caducar (≤90 días),
   Caducados por retirar, En punto de reorden, Recetas surtidas, Recetas rechazadas,
   Lotes retirados. Debajo dos tablas: "Lotes próximos a caducar (FEFO)" con columnas
   Lote, SKU, Caduca (chip de color con días restantes), Unidades; y "Quiebre / reorden"
   con SKU, Producto, Existencias (chip), Punto de reorden.
2. Detalle de producto: nombre, tipo (venta libre / receta / antibiótico / controlado),
   existencias vendibles y tabla de lotes con caducidad, unidades, vendidas y estado
   (ok / caduca pronto / caducado / retirado). Tarjeta "Alerta sanitaria" con campo de
   lote y botones "¿A quién se le vendió?" y "Retirar lote" (rojo).
3. Recetas: formulario "Nueva receta" (paciente, medicamento, cantidad, alergias,
   folio para controlados, sucursal) y panel "Surtir" (id de receta, mostrador 1-3).
   Lista de últimas recetas con chip de estado: emitida, surtida parcial, surtida, vencida.
4. Bitácora: lista cronológica de eventos con hora y borde de color según nivel.
```

Exporta el zip desde Stitch y descomprímelo en esta carpeta (`design/`),
incluyendo `DESIGN.md`. Pon aquí también las capturas de cada pantalla.
