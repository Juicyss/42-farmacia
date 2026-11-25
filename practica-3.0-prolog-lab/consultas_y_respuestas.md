# Consultas y respuestas del gemelo mínimo — Farmacia #42

Archivo: [`gemelo_farmacia_minimo.pl`](gemelo_farmacia_minimo.pl) · 21 hechos · 7 reglas · 1 DCG · 7 consultas.
Para reproducirlo:

```bash
swipl gemelo_farmacia_minimo.pl
?- demo.
```

La salida completa, tal como la imprime SWI-Prolog 11, está en [`salida_demo.txt`](salida_demo.txt).
Cada consulta extrae algo que **no está escrito como hecho**: lo deduce el motor uniendo hechos con reglas.

---

## 1. ¿Ana es alérgica al Amoxil?

```prolog
?- alergico(ana, amoxil_500).
true.
```

**Qué se dedujo.** El único hecho es `alergia(ana, amoxicilina)`. Nadie escribió «Ana es alérgica al Amoxil».
**Cómo razonó.** `alergico/2` unifica `medicamento(amoxil_500, PA, _)` → `PA = amoxicilina` y luego prueba
`alergia(ana, amoxicilina)`. Es una cadena nombre comercial → principio activo → alergia (niveles 1–2 del Lab).
Un `if nombre == "amoxicilina"` habría dejado pasar el Amoxil.

## 2. ¿Qué lotes de amoxicilina sirven para un tratamiento de 60 días?

```prolog
?- setof(L, lote_apto(amoxicilina_500, 60, L), Lotes).
Lotes = [l_amox_b].
```

**Qué se dedujo.** `l_amox_a` NO sirve aunque no está vencido: caduca el día 250 y un tratamiento que empieza el
día 200 termina el 260. **Cómo razonó.** `setof/3` (nivel 7) recorre por *backtracking* los dos lotes: con
`l_amox_a` falla `200 + 60 =< 250` y Prolog retrocede al siguiente lote; con `l_amox_b` todas las metas se cumplen.
La negación por fallo `\+ lote_retirado(L, _)` descarta los lotes retirados.

## 3. ¿A quién avisar del lote retirado y qué ventas no tienen rastro?

```prolog
?- findall(P, por_avisar(l_omep_a, P), Avisar), findall(V, sin_rastro(l_omep_a, V), SinRastro).
Avisar = [ana, pedro],
SinRastro = [v403].
```

**Qué se dedujo.** La lista de pacientes a avisar no existe en ningún hecho: sale de recorrer la cadena
`lote_retirado → venta → comprador` (nivel 11, relaciones como grafo). La venta `v403` se declara **sin rastro**:
el dato que falta no se rellena.

## 4. ¿Se le puede vender ibuprofeno a Luis?

```prolog
?- decide(luis, ibuprofeno_400, Decision, Porque).
Decision = no_surtir,
Porque = [interaccion_con(warfarina_5), recibio(luis, warfarina_5, otay, 194)].
```

**Qué se dedujo.** El ibuprofeno es de venta libre, pero Luis recibió warfarina hace 6 días en **otra sucursal**.
**Cómo razonó.** `decide/4` es un pequeño sistema experto (nivel 13): prueba sus cláusulas en orden; la primera
(alergia) falla, retrocede, y la segunda encuentra `interactua(luis, ibuprofeno_400, warfarina_5)`.
La explicación (`Porque`) es la lista de hechos que sostienen la conclusión.

## 5. ¿Se le surte amoxicilina a Pedro?

```prolog
?- decide(pedro, amoxicilina_500, Decision, Porque).
Decision = suspender,
Porque = [sin_ficha_de_alergias(pedro)].
```

**Qué se dedujo.** Pedro no tiene ficha de alergias. El gemelo **no** concluye «no es alérgico»: concluye
«no se sabe» y suspende hasta capturar la ficha.

## 6. ¿Ya se usó la receta especial r103?

```prolog
?- uso_receta(r103, Uso).
Uso = no_se.
```

**Qué se dedujo.** No hay ningún surtido registrado, pero Otay no reporta desde el día 196. Por eso la respuesta
es `no_se` y no `no`. Tres valores: `si`, `no`, `no_se`.

## 7. En lenguaje natural (DCG)

```prolog
?- pregunta_natural("¿le surto amoxil_500 a ana?", Decision, Porque).
Decision = no_surtir,
Porque = [alergia(ana, amoxicilina), medicamento(amoxil_500, amoxicilina, receta)].
```

**Cómo razonó.** La gramática `pregunta//2` (nivel 15) convierte la frase en `pregunta(ana, amoxil_500)` y la
misma regla `decide/4` contesta.

## 8. El gemelo aprende (nivel 12)

```prolog
?- registrar_surtido(r103, otay), uso_receta(r103, Uso).
Uso = si.        % antes era no_se
```

Con `assertz/1` el gemelo incorpora un evento y su respuesta cambia sin tocar las reglas.

---

### Árbol de búsqueda y backtracking

En el Prolog Lab usé el botón **Árbol de búsqueda** para ver cómo Prolog explora y retrocede
(capturas [`04`](capturas/04-arbol-busqueda-abuelo.jpg) y [`05`](capturas/05-arbol-backtracking-mapa.jpg)):

- `abuelo(juan, N)`: 11 nodos, 2 fallos (`madre(pedro, N)`, `padre(ana, N)`), 4 retrocesos y 3 soluciones.
- `colorear(BC, BCS, SON, CHIH, SIN, DGO)`: 21 nodos, 5 fallos y 5 retrocesos antes de la primera coloración.

Las consultas 2 y 4 de arriba hacen lo mismo con el gemelo: cuando una meta falla, Prolog regresa al último punto
de elección (otro lote, otra cláusula de `decide/4`) y prueba la siguiente alternativa.
