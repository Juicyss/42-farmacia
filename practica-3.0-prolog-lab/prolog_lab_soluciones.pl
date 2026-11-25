/*  prolog_lab_soluciones.pl — Mis soluciones a los 20 niveles (69 retos) de Prolog Lab
    https://prolog-lab.fly.dev  ·  Práctica 3.0/3.2 «Prolog Lab y tu Gemelo Digital»

    Hugo Iram Aguirre Dávila · Programación Lógica y Funcional · TecNM Tijuana

    Cada reto dice si es CONSULTA (se escribe en la terminal ?-) o PROGRAMA (se agrega al
    archivo del nivel y se vuelve a consultar). Todo va comentado para que este archivo
    cargue sin ejecutar nada. Las 69 se validaron en el Lab (69/69 ✓) y además en
    SWI-Prolog 11 local con un verificador que replica lab_check/2 del Lab.
*/

% ==============================================================================
% Nivel 1 · Lección 1 · Hechos y consultas — La familia   (archivo del Lab: familia.pl)
% ==============================================================================

% Reto 1 (consulta): ¿Quiénes son los hijos de lucia? Escribe la consulta en la terminal.
%   ?- madre(lucia, X).

% Reto 2 (consulta): ¿Quién es el padre de los hijos de ana? Obtén padre e hijo en una sola consulta.
%   ?- padre(P, H), madre(ana, H).

% Reto 3 (programa): Agrega al programa que carmen es madre de diego y vuelve a consultar.
%   madre(carmen, diego).

% ==============================================================================
% Nivel 2 · Lección 2a · Reglas y recursión — La familia crece   (archivo del Lab: familia2.pl)
% ==============================================================================

% Reto 1 (consulta): ¿Quiénes son los nietos de maria? (no existe abuela/2: combina metas).
%   ?- madre(maria, P), progenitor(P, N).

% Reto 2 (programa): Define hermano(X, Y): comparten un progenitor y son distintos.
%   % hermano(X, Y): comparten al menos un progenitor y son personas distintas.
%   hermano(X, Y) :-
%       progenitor(P, X),
%       progenitor(P, Y),
%       X \= Y.

% Reto 3 (programa): Define ancestro(A, D) de forma recursiva.
%   % ancestro(A, D): caso base (progenitor directo) y caso recursivo.
%   ancestro(A, D) :- progenitor(A, D).
%   ancestro(A, D) :- progenitor(A, X), ancestro(X, D).

% ==============================================================================
% Nivel 2 · Lección 2b · Recursión — Viajes en coche, tren y avión   (archivo del Lab: viajes.pl)
% ==============================================================================

% Reto 1 (programa): Define viajar(X, Y): se puede llegar de X a Y con uno o más tramos.
%   % viajar(X, Y): uno o más tramos directos.
%   viajar(X, Y) :- directo(X, Y).
%   viajar(X, Y) :- directo(X, Z), viajar(Z, Y).

% Reto 2 (consulta): ¿A qué ciudades se puede viajar desde saarbruecken?
%   ?- viajar(saarbruecken, X).

% Reto 3 (programa): Define viajar(X, Y, Ruta) que construya la ruta: ir(X, Y) si es directo, ir(X, Z, Resto) si hay escala.
%   % viajar(X, Y, Ruta): construye la ruta como término anidado.
%   viajar(X, Y, ir(X, Y)) :- directo(X, Y).
%   viajar(X, Y, ir(X, Z, Resto)) :- directo(X, Z), viajar(Z, Y, Resto).

% ==============================================================================
% Nivel 3 · Lección 3a · Unificación — Líneas verticales y horizontales   (archivo del Lab: lineas.pl)
% ==============================================================================

% Reto 1 (programa): Define horizontal/1: los dos puntos comparten la Y.
%   % horizontal/1: ambos puntos comparten la misma Y (unificación pura).
%   horizontal(linea(punto(_, Y), punto(_, Y))).

% Reto 2 (consulta): Encuentra el punto P tal que linea(punto(1,1), P) sea vertical y horizontal.
%   ?- vertical(linea(punto(1,1), P)), horizontal(linea(punto(1,1), P)).

% Reto 3 (consulta): Unifica k(s(g), Y) con k(X, t(k)) (LPN ej. 2.1).
%   ?- k(s(g), Y) = k(X, t(k)).

% ==============================================================================
% Nivel 3 · Lección 3b · Unificación — El crucigrama   (archivo del Lab: crucigrama.pl)
% ==============================================================================

% Reto 1 (consulta): ¿Qué palabras tienen una a como 4.ª letra?
%   ?- word(W, _, _, _, a, _, _, _).

% Reto 2 (programa): Define crossword/6 y resuelve el crucigrama.
%   % crossword/6: las letras 2, 4 y 6 de cada vertical se cruzan con las horizontales.
%   crossword(V1, V2, V3, H1, H2, H3) :-
%       word(V1, _, A, _, B, _, C, _),
%       word(V2, _, D, _, E, _, F, _),
%       word(V3, _, G, _, H, _, I, _),
%       word(H1, _, A, _, D, _, G, _),
%       word(H2, _, B, _, E, _, H, _),
%       word(H3, _, C, _, F, _, I, _).

% ==============================================================================
% Nivel 4 · Lección 4a · Backtracking — Coloreado de mapas   (archivo del Lab: mapa.pl)
% ==============================================================================

% Reto 1 (consulta): ¿Cuántas coloraciones válidas existen? Obtén el número en una variable N.
%   ?- aggregate_all(count, colorear(_, _, _, _, _, _), N).

% Reto 2 (consulta): Encuentra todas las coloraciones en que Sonora y Durango son azul.
%   ?- colorear(BC, BCS, azul, CHIH, SIN, azul).

% Reto 3 (programa): Define colorear7/7 agregando Coahuila (COA), vecina de Chihuahua y Durango.
%   % colorear7/7: Coahuila (COA) es vecina de Chihuahua y Durango.
%   colorear7(BC, BCS, SON, CHIH, SIN, DGO, COA) :-
%       colorear(BC, BCS, SON, CHIH, SIN, DGO),
%       color(COA), COA \= CHIH, COA \= DGO.

% ==============================================================================
% Nivel 4 · Lección 4b · Backtracking — N reinas   (archivo del Lab: reinas.pl)
% ==============================================================================

% Reto 1 (consulta): ¿Cuántas soluciones tiene el problema de las 8 reinas? Obtén N.
%   ?- aggregate_all(count, reinas(8, _), N).

% Reto 2 (programa): Escribe reinas_gt(N, Qs) con generar-y-probar: permutation/2 y luego verificar todas las diagonales.
%   % reinas_gt/2: generar (permutation/2) y probar (diagonales) al final.
%   reinas_gt(N, Qs) :-
%       numlist(1, N, Filas),
%       permutation(Filas, Qs),
%       sin_ataques(Qs).
%
%   sin_ataques([]).
%   sin_ataques([Q|Qs]) :- segura(Q, Qs, 1), sin_ataques(Qs).

% ==============================================================================
% Nivel 5 · Lección 5 · Aritmética simbólica — Peano y Torres de Hanói   (archivo del Lab: peano.pl)
% ==============================================================================

% Reto 1 (consulta): Usa suma/3 al revés: ¿qué pares X, Y suman s(s(s(0)))?
%   ?- suma(X, Y, s(s(s(0)))).

% Reto 2 (consulta): ¿Cuántos movimientos necesita Hanói con 5 discos? Obtén el número en N.
%   ?- hanoi(5, a, b, c, _M), length(_M, N).

% Reto 3 (programa): Define mult(X, Y, Z) en Peano usando suma/3 (0·Y = 0; s(X)·Y = Y + X·Y).
%   % mult(X, Y, Z): 0*Y = 0 ; s(X)*Y = Y + X*Y
%   mult(0, _, 0).
%   mult(s(X), Y, Z) :- mult(X, Y, Z0), suma(Y, Z0, Z).

% ==============================================================================
% Nivel 6 · Lección 6 · Listas — P-99, quicksort y mergesort   (archivo del Lab: listas.pl)
% ==============================================================================

% Reto 1 (consulta): ¿Cuál es el último elemento de [p,r,o,l,o,g]? Usa ultimo/2.
%   ?- ultimo(X, [p, r, o, l, o, g]).

% Reto 2 (consulta): Con append/3, obtén todas las formas de partir [a,b,c] en dos listas X e Y.
%   ?- append(X, Y, [a, b, c]).

% Reto 3 (programa): Define comprimir(L, C) (P08): elimina duplicados consecutivos. [a,a,b,a] → [a,b,a].
%   % comprimir(L, C)  (P08): elimina duplicados consecutivos.
%   comprimir([], []).
%   comprimir([X], [X]).
%   comprimir([X, X|T], C) :- comprimir([X|T], C).
%   comprimir([X, Y|T], [X|C]) :- X \= Y, comprimir([Y|T], C).

% Reto 4 (programa): Define mergesort(L, S): divide a la mitad, ordena cada parte y mézclalas con mezclar/3.
%   % mergesort(L, S): divide a la mitad, ordena cada parte y mezcla.
%   mergesort([], []).
%   mergesort([X], [X]).
%   mergesort(L, S) :-
%       L = [_, _|_],
%       length(L, N), M is N // 2,
%       length(Izq, M), append(Izq, Der, L),
%       mergesort(Izq, SI), mergesort(Der, SD),
%       mezclar(SI, SD, S).
%
%   % mezclar(A, B, M): mezcla dos listas ordenadas.
%   mezclar([], L, L).
%   mezclar([X|Xs], [], [X|Xs]).
%   mezclar([X|Xs], [Y|Ys], [X|Zs]) :- X =< Y, mezclar(Xs, [Y|Ys], Zs).
%   mezclar([X|Xs], [Y|Ys], [Y|Zs]) :- X > Y, mezclar([X|Xs], Ys, Zs).

% ==============================================================================
% Nivel 7 · Lección 7 · Corte, negación, setof — El problema de la cebra   (archivo del Lab: cebra.pl)
% ==============================================================================

% Reto 1 (consulta): ¿Quiénes son solteros?
%   ?- soltero(X).

% Reto 2 (consulta): Con setof/3, obtén la lista ordenada y sin repetidos de todas las edades.
%   ?- setof(E, P^edad(P, E), Es).

% Reto 3 (consulta): Resuelve el acertijo: ¿quién tiene la cebra y quién bebe agua?
%   ?- cebra(D, A, _).

% Reto 4 (programa): Define clasifica(N, Tipo) con cortes: negativo, cero o positivo.
%   % clasifica(N, Tipo): cortes verdes; la salida se unifica DESPUES del corte.
%   clasifica(N, T) :- N < 0, !, T = negativo.
%   clasifica(N, T) :- N =:= 0, !, T = cero.
%   clasifica(_, positivo).

% ==============================================================================
% Nivel 8 · Lección 8 · Búsqueda — Granjero, lobo, cabra y col   (archivo del Lab: granjero.pl)
% ==============================================================================

% Reto 1 (consulta): Desde estado(i,i,i,i), ¿qué acción A lleva a un estado E seguro?
%   ?- mover(estado(i,i,i,i), A, E), seguro(E).

% Reto 2 (consulta): ¿Cuántos movimientos tiene la solución más corta? Obtén N.
%   ?- aggregate_all(min(L), (resolver(_R), length(_R, L)), N).

% Reto 3 (programa): Define ruta_corta(R) con profundidad iterativa: fija la longitud con length/2 antes de llamar a camino/4.
%   % ruta_corta(R): profundidad iterativa; length/2 fija primero la longitud.
%   ruta_corta(R) :-
%       length(R, _),
%       camino(estado(i,i,i,i), estado(d,d,d,d), [estado(i,i,i,i)], R), !.

% ==============================================================================
% Nivel 9 · Lección 9 · Búsqueda informada — 8-puzzle con A*   (archivo del Lab: puzzle8.pl)
% ==============================================================================

% Reto 1 (consulta): ¿Cuál es la distancia Manhattan de [1,2,3,4,5,6,0,7,8]?
%   ?- manhattan([1,2,3,4,5,6,0,7,8], D).

% Reto 2 (consulta): ¿Cuántos movimientos tiene la solución óptima de [4,1,3,7,2,6,0,5,8]? Obtén N (estados − 1).
%   ?- astar([4,1,3,7,2,6,0,5,8], _C), length(_C, _L), N is _L - 1.

% Reto 3 (programa): Define fuera_de_lugar(E, N): cuántas fichas (sin contar el hueco) no están en su lugar.
%   % fuera_de_lugar(E, N): fichas (sin el hueco) que no están en su casilla meta.
%   fuera_de_lugar(E, N) :-
%       meta(M),
%       aggregate_all(count,
%           ( nth0(I, E, F), F > 0, nth0(I, M, G), F =\= G ), N).

% ==============================================================================
% Nivel 10 · Lección 10 · Planificación — Mundo de bloques (STRIPS)   (archivo del Lab: bloques.pl)
% ==============================================================================

% Reto 1 (consulta): ¿Qué acciones A se pueden aplicar en el estado inicial?
%   ?- inicial(_I), aplicar(_I, A, _).

% Reto 2 (consulta): Planea la anomalía de Sussman: meta [sobre(a, b), sobre(b, c)]. Obtén el plan P.
%   ?- inicial(_I), plan(_I, [sobre(a, b), sobre(b, c)], P).

% Reto 3 (programa): Define aplicable(E, A): cierto si las precondiciones de A se cumplen en E (sin aplicarla).
%   % aplicable(E, A): las precondiciones de A están en E (sin aplicarla).
%   aplicable(E, A) :-
%       accion(A, Pre, _, _),
%       subset(Pre, E).

% ==============================================================================
% Nivel 11 · Lección 11 · Árboles y grafos — Árboles binarios P-99 y rutas   (archivo del Lab: arboles.pl)
% ==============================================================================

% Reto 1 (consulta): Obtén el recorrido inorden L del árbol de arbol/1.
%   ?- arbol(_T), inorden(_T, L).

% Reto 2 (programa): Define altura(T, H): nil tiene altura 0; un nodo, 1 + la mayor altura de sus hijos.
%   % altura(T, H): nil mide 0; un nodo, 1 + la mayor altura de sus hijos.
%   altura(nil, 0).
%   altura(t(_, I, D), H) :-
%       altura(I, HI), altura(D, HD),
%       H is 1 + max(HI, HD).

% Reto 3 (consulta): ¿Cuál es la ruta más corta R y su distancia D de tijuana a mexicali?
%   ?- mas_corto(tijuana, mexicali, R, D).

% ==============================================================================
% Nivel 12 · Lección 12 · BD dinámica — assert/retract y ELIZA   (archivo del Lab: eliza.pl)
% ==============================================================================

% Reto 1 (consulta): Pregúntale a ELIZA: "Me siento triste".
%   ?- eliza("Me siento triste", R).

% Reto 2 (consulta): En una sola consulta, guarda con aprende/2 que tu color favorito es azul y léelo con recuerda/2.
%   ?- aprende(color, azul), recuerda(color, C).

% Reto 3 (programa): Define decrementa/0: resta 1 al contador sin bajar de 0.
%   % decrementa: resta 1 al contador sin bajar de 0.
%   decrementa :-
%       retract(contador(N)),
%       N1 is max(0, N - 1),
%       assertz(contador(N1)).

% ==============================================================================
% Nivel 13 · Lección 13 · Sistemas expertos — Identificación de animales   (archivo del Lab: animales.pl)
% ==============================================================================

% Reto 1 (consulta): Observa [pelo, come_carne, color_leonado, rayas_negras] e identifica el animal A, todo en una consulta.
%   ?- observa([pelo, come_carne, color_leonado, rayas_negras]), animal(A).

% Reto 2 (programa): Agrega la regla animal(murcielago): un mamífero que vuela.
%   % murciélago: un mamífero que vuela.
%   animal(murcielago) :- mamifero, si(vuela).

% Reto 3 (consulta): Tras observar [plumas, no_vuela, nada], usa como/2 para identificar el animal X y su prueba P.
%   ?- observa([plumas, no_vuela, nada]), como(animal(X), P).

% ==============================================================================
% Nivel 14 · Lección 14 · Metaprogramación — Metaintérprete vanilla   (archivo del Lab: meta.pl)
% ==============================================================================

% Reto 1 (consulta): Usa resolver/1 para encontrar todos los descendientes D de juan.
%   ?- resolver(ancestro(juan, D)).

% Reto 2 (consulta): ¿Qué profundidad P tiene la prueba de ancestro(juan, ana)?
%   ?- profundidad(ancestro(juan, ana), P).

% Reto 3 (programa): Define contar(Meta, N): como resolver/1, pero N es cuántas metas de usuario se resolvieron.
%   % contar(Meta, N): como resolver/1, N = metas de usuario resueltas en la prueba.
%   contar(true, 0) :- !.
%   contar((A, B), N) :- !, contar(A, NA), contar(B, NB), N is NA + NB.
%   contar((A ; B), N) :- !, ( contar(A, N) ; contar(B, N) ).
%   contar(G, 0) :- predicate_property(G, built_in), !, call(G).
%   contar(G, N) :- clause(G, Cuerpo), contar(Cuerpo, N0), N is N0 + 1.

% ==============================================================================
% Nivel 15 · Lección 15 · DCG — Gramáticas y un evaluador   (archivo del Lab: dcg.pl)
% ==============================================================================

% Reto 1 (consulta): ¿Cuánto vale "2+3*(4-1)" con calcula/2?
%   ?- calcula("2+3*(4-1)", V).

% Reto 2 (consulta): ¿Qué lista L de longitud 6 genera ab?
%   ?- length(L, 6), phrase(ab, L).

% Reto 3 (programa): Define la DCG binario: acepta cadenas no vacías de 0 y 1. Prueba con string_codes("1011", C), phrase(binario, C).
%   % binario//0: uno o más dígitos 0/1.
%   binario --> bit, bits.
%   bits --> [].
%   bits --> bit, bits.
%   bit --> "0".
%   bit --> "1".

% ==============================================================================
% Nivel 16 · Lección 16 · CLP(FD) — SEND+MORE, Sudoku y horarios   (archivo del Lab: clpfd.pl)
% ==============================================================================

% Reto 1 (consulta): Resuelve SEND+MORE=MONEY y obtén el valor de cada letra S, E, N, D, M, O, R, Y.
%   ?- puzzle([S,E,N,D] + [M,O,R,E] = [M,O,N,E,Y]).

% Reto 2 (consulta): Resuelve el sudoku problema(1, F) y obtén su última fila U.
%   ?- problema(1, _F), sudoku(_F), last(_F, U).

% Reto 3 (programa): Define horario([A, B, C]): tareas de 3, 2 y 1 horas que inician entre 0 y 6, sin traslaparse, y A termina antes de que empiece C.
%   % horario([A,B,C]): duraciones 3, 2 y 1 h; inicio en 0..6; sin traslape; A antes que C.
%   horario([A, B, C]) :-
%       [A, B, C] ins 0..6,
%       A + 3 #=< C,
%       A + 3 #=< B #\/ B + 2 #=< A,
%       B + 2 #=< C #\/ C + 1 #=< B,
%       label([A, B, C]).

% ==============================================================================
% Nivel 17 · Lección 17 · Módulos + plunit — Una pila con pruebas   (archivo del Lab: modulos.pl)
% ==============================================================================

% Reto 1 (consulta): Ejecuta las pruebas unitarias del módulo.
%   ?- run_tests.

% Reto 2 (programa): Agrega tamanio(P, N) (número de elementos de la pila) y expórtalo para que se pueda llamar sin calificar.
%   :- module(pila, [vacia/1, apilar/3, desapilar/3, tope/2, tamanio/2]).      % se exporta tamanio/2
%   % tamanio(P, N): número de elementos de la pila (exportado).
%   tamanio(P, N) :- length(P, N).

% Reto 3 (consulta): Llama al predicado privado interno/1 calificándolo con su módulo.
%   ?- pila:interno(X).

% ==============================================================================
% Nivel 18 · Lección 18 · Servidor web — API REST   (archivo del Lab: api.pl)
% ==============================================================================

% Reto 1 (consulta): ¿Qué responde GET /tareas/pendientes? Obtén código C y respuesta R con atender/5 (params _{}).
%   ?- atender(get, '/tareas/pendientes', _{}, C, R).

% Reto 2 (programa): Agrega DELETE /tareas con params _{id: N}: borra la tarea y responde 200 con _{borrada: N}.
%   % DELETE /tareas con _{id: N}: 200 si existía, 404 si no.
%   ruta(delete, '/tareas', P, C, R) :-
%       get_dict(id, P, N),
%       (   retract(tarea(N, _, _))
%       ->  C = 200, R = _{borrada: N}
%       ;   C = 404, R = _{error: "no encontrado"}
%       ).

% Reto 3 (consulta): ¿Qué código C devuelve una ruta inexistente, como GET /usuarios?
%   ?- atender(get, '/usuarios', _{}, C, _).

% ==============================================================================
% Nivel 19 · Lección 19 · Janus — Prolog ↔ Python   (archivo del Lab: datos.pl)
% ==============================================================================

% Reto 1 (consulta): Obtén el promedio P de cada carrera C (como groupby().mean()).
%   ?- promedio_carrera(C, P).

% Reto 2 (consulta): ¿Quién tiene el promedio más alto? Obtén su promedio P y su nombre Nombre.
%   ?- aggregate_all(max(X, N), fila(N, _, X), max(P, Nombre)).

% Reto 3 (programa): Define aprobados_por_carrera(C, N): cuántos alumnos de la carrera C tienen 70 o más.
%   % aprobados_por_carrera(C, N): alumnos de C con promedio >= 70.
%   aprobados_por_carrera(C, N) :-
%       setof(C0, Nom^X^fila(Nom, C0, X), Cs),
%       member(C, Cs),
%       aggregate_all(count, ( fila(_, C, P), P >= 70 ), N).

% ==============================================================================
% Nivel 20 · Lección 20 · Integrador — Sistema experto + API   (archivo del Lab: integrador.pl)
% ==============================================================================

% Reto 1 (consulta): Diagnostica [enciende, lento, ruidos] con mejor/3: obtén falla D y certeza C.
%   ?- mejor([enciende, lento, ruidos], D, C).

% Reto 2 (consulta): Llama a api/2 como lo haría el servidor, con síntomas ["no_enciende"]. Obtén la respuesta R.
%   ?- api(_{sintomas: ["no_enciende"]}, R).

% Reto 3 (programa): Agrega la falla pantalla con síntomas [enciende, sin_video, sin_luz_fondo].
%   % falla de pantalla
%   falla(pantalla, [enciende, sin_video, sin_luz_fondo]).
