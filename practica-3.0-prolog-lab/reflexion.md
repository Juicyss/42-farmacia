# Reflexión — ¿Qué conocimiento de mi gemelo pude deducir con reglas?

**Hugo Iram Aguirre Dávila · Proyecto #42 Farmacia · Práctica 3.0/3.2**

En mi gemelo de la farmacia ningún hecho dice «Ana es alérgica al Amoxil», «el lote l_amox_a no le sirve a un
tratamiento de 60 días» o «a Luis no se le puede vender ibuprofeno». Lo que guardé son datos sueltos: Ana es
alérgica a la *amoxicilina*, el Amoxil *contiene* amoxicilina, el lote caduca el día 250, Luis *recibió* warfarina
en Otay. Con tres o cuatro reglas el gemelo conecta esos datos y llega a conclusiones que nadie capturó: encadena
nombre comercial → principio activo → alergia, cruza caducidad con la duración del tratamiento, y sigue la cadena
lote retirado → venta → paciente para saber a quién avisar.

La ventaja frente a solo almacenar datos es que **una misma regla contesta muchas preguntas**. En una base de
datos o en un script tendría que escribir una consulta o una función nueva para «¿le surto?», otra para
«¿por qué no?» y otra para «¿qué le falta?». En Prolog son la misma relación consultada en distintas direcciones,
y la explicación sale gratis: es la lista de hechos que el motor usó para probar la meta. Cuando agrego un hecho
con `assert` (por ejemplo, que Otay reportó el surtido de la receta r103), las respuestas cambian solas, sin
tocar las reglas.

Lo que más me cambió la forma de pensar fue el «no se sabe». En Python habría escrito `alergias = []` y el
programa habría concluido «no es alérgico». En el gemelo distingo tres valores: sí, no y no se sabe; la ficha de
alergias de Pedro nunca se capturó y Otay no reporta desde el día 196, así que el gemelo suspende en lugar de
surtir a ciegas. Ver el árbol de búsqueda en el Prolog Lab me ayudó a entender que el *backtracking* no es un
ciclo que yo programo: Prolog prueba una alternativa, falla, regresa y prueba la siguiente, y eso es justo lo
que hace mi gemelo cuando busca un lote que sí sirva.
