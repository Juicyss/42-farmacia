# Prompt para Google Stitch — Gemelo digital de la Farmacia #42

La interfaz del gemelo reutiliza el sistema de diseño **«Clinical Precision»** que exporté de Google Stitch en la
fase de Erlang ([`DESIGN.md`](DESIGN.md) y las pantallas `stitch_*.png` de esta carpeta): verde azulado clínico,
tarjetas blancas de 16 px de radio, chips de estado (OK / caduca pronto / caducado / retirado), Plus Jakarta Sans +
Inter, y navegación inferior en el celular. Sobre ese mismo sistema, este es el prompt de Stitch para las
pantallas del gemelo (pegarlo en <https://stitch.withgoogle.com> y guardar aquí el zip exportado):

```text
Using the existing "Clinical Precision" design system (teal #005445 primary, white 16px-radius
cards on #faf8ff, status chips: OK green, "Caduca pronto" blue, "Caducado"/"Retirado" red),
design the screens of a pharmacy DIGITAL TWIN called "Farmacia #42 · Gemelo digital".
A Prolog logic engine decides; the UI only asks and shows the decision with its explanation.
All text in Spanish. Mobile-first (bottom tab bar on phones, top tabs on desktop). No stock photos.

Header: logo chip "Rx", title, subtitle "Prolog decide y explica · Python solo dibuja",
pills "Día 200 del modelo" and "Python vía Janus". A warning banner when a branch has not
reported: "Otay no reporta desde el día 196 — cuenta como «no se sabe», nunca como «no»".
KPI row: lotes vencidos, retirados, caducan en ≤ 90 días, recetas abiertas, recetas «no se sabe»,
ventas sin rastro.

Tabs: Situaciones · Lotes · Recetas · Retiro · Consultas.

1. Situaciones: left list of scenarios grouped by "Situación 1..5"; right panel with the
   counter requests table (hora, mostrador, paciente, medicamento, receta, pide, tratamiento),
   hypothesis chips "¿Qué pasaría si…?", a pager "Alternativa 1 de 2 ‹ ›", and one result card
   per request: verdict badge (SURTIR green, SURTIR PARCIAL amber, RECHAZAR red,
   SUSPENDER · NO SE SABE blue), lots delivered (id, units, expiry, shelf), "Qué se hace con
   la receta" checklist, "A quién se avisa" list, "Por qué" explanation items color-coded by
   type (Bloquea, No se sabe, Dilema, Contra la intuición, Lotes, Advertencia), a collapsed
   "Evidencia" section with Prolog facts as small code chips, and "¿Qué falta para que cambie?".
2. Lotes: grid of lot cards with status chip, units, expiry and shelf; a chart image card.
3. Recetas: cards with prescribed vs dispensed progress bar, status, event timeline.
4. Retiro (recall): red header card "Lote l_omep_a retirado", three KPIs (pacientes por
   avisar, unidades «no se sabe a quién», en estante: sacar hoy), "A quién avisar" with the
   contact channel and the chain lote → venta → receta → paciente as code chips, a table
   "Ventas sin rastro" with "no se sabe" in red, and "Devoluciones" with destination chips
   (Cuarentena, Regresa al inventario, Merma) and "de qué depende".
5. Consultas: form "Entidad" + "Tipo de situación" and a results table.

Every chart is a ready-made PNG from the backend: show it as an <img> in a card, never draw
charts in HTML. Footer chip "Cómo se hizo: decide/4 → que_falta/2 → hipotesis/2".
Accessible contrast, 44 px touch targets, visible focus states.
```

La interfaz se implementó en [`../web/`](../web/) (HTML + CSS + JS sin frameworks) siguiendo este prompt y los
tokens de `DESIGN.md`, conectada a la API real de `servidor.pl`. Se agregó un tema oscuro con las mismas variables (botón 🌙/☀️), porque Chrome con modo
oscuro forzado invertía los colores. Capturas del resultado: [`../capturas/`](../capturas/).
