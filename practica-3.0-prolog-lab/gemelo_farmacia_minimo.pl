/*  gemelo_farmacia_minimo.pl — Práctica 3.0/3.2 «Prolog Lab y tu Gemelo Digital»

    Hugo Iram Aguirre Dávila · Programación Lógica y Funcional · TecNM Tijuana
    Proyecto #42 Farmacia (base de conocimiento mínima del gemelo).

    Uso:   swipl gemelo_farmacia_minimo.pl
           ?- demo.                 % corre las consultas y explica cada respuesta

    Cada bloque dice qué nivel del Prolog Lab aplica:
      1–2  hechos y reglas          7   negación y setof        11  grafos / cadenas
      12   BD dinámica (assert)     13  sistema experto + «cómo» 15  DCG (lenguaje natural)
    Datos simulados; no es un sistema de dispensación real.
*/
:- encoding(utf8).
:- dynamic surtido/3.

% ======================================================= HECHOS (21) — nivel 1
ahora(200).                                          % el «ahora» es un hecho (día del modelo)

% medicamento(Med, PrincipioActivo, Requisito)
medicamento(amoxil_500,      amoxicilina, receta).   % nombre comercial
medicamento(amoxicilina_500, amoxicilina, receta).   % genérico, mismo principio
medicamento(clonazepam_2,    clonazepam,  controlado).
medicamento(ibuprofeno_400,  ibuprofeno,  libre).
medicamento(warfarina_5,     warfarina,   receta).
medicamento(omeprazol_20,    omeprazol,   libre).

% lote(Lote, Med, Caducidad)
lote(l_amox_a, amoxicilina_500, 250).
lote(l_amox_b, amoxicilina_500, 600).
lote(l_omep_a, omeprazol_20,    320).
lote_retirado(l_omep_a, 198).                        % alerta sanitaria

% pacientes: alergias declaradas y fichas capturadas
alergia(ana, amoxicilina).
ficha_alergias(ana).
ficha_alergias(luis).                                % pedro: ficha nunca capturada

% historial y recetas
recibio(luis, warfarina_5, otay, 194).
interaccion(warfarina, ibuprofeno).
receta(r103, luis, especial, clonazepam_2).
reporte(centro, 200).
reporte(otay,   196).                                % Otay no reporta desde el día 196

% ventas del lote retirado: venta(Venta, Lote, Comprador)
venta(v401, l_omep_a, ana).
venta(v403, l_omep_a, desconocido).
venta(v405, l_omep_a, pedro).

% ======================================================= REGLAS (7) — niveles 2, 7, 11, 13

% R1 (niveles 1–2) Encadenar: nombre comercial → principio activo → alergia declarada.
%    Ningún hecho dice «ana es alérgica al Amoxil»: se DEDUCE.
alergico(P, Med) :-
    medicamento(Med, PA, _),
    alergia(P, PA).

% R2 (nivel 7, negación) Interacción con algo recibido en los últimos 14 días.
interactua(P, Med, Med2) :-
    medicamento(Med, A, _),
    recibio(P, Med2, _, Dia), ahora(H), H - Dia =< 14,
    medicamento(Med2, B, _),
    ( interaccion(A, B) ; interaccion(B, A) ).

% R3 (nivel 7, negación por fallo) Lote apto: no retirado y no caduca a medio tratamiento.
lote_apto(Med, Dias, L) :-
    lote(L, Med, Cad),
    \+ lote_retirado(L, _),
    ahora(H), H + Dias =< Cad.

% R4 (nivel 11, cadena lote → venta → paciente) ¿A quién avisar de un lote retirado?
por_avisar(Lote, P) :-
    lote_retirado(Lote, _),
    venta(_, Lote, P), P \== desconocido.
sin_rastro(Lote, V) :- venta(V, Lote, desconocido).

% R5 (tres valores) ¿Ya se usó la receta en otra sucursal?  si | no | no_se
uso_receta(R, si)    :- surtido(R, _, _), !.
uso_receta(_, no_se) :- reporte(_, Ult), ahora(H), H - Ult > 1, !.   % alguien no reporta
uso_receta(_, no).

% R6 (nivel 13, sistema experto) Decide y EXPLICA (la explicación es la lista de hechos).
decide(P, Med, no_surtir, [alergia(P, PA), medicamento(Med, PA, Req)]) :-
    alergico(P, Med), medicamento(Med, PA, Req), !.
decide(P, Med, no_surtir, [interaccion_con(Med2), recibio(P, Med2, S, D)]) :-
    interactua(P, Med, Med2), recibio(P, Med2, S, D), !.
decide(P, Med, suspender, [sin_ficha_de_alergias(P)]) :-
    \+ ficha_alergias(P), medicamento(Med, _, Req), Req \== libre, !.
decide(P, Med, suspender, [no_se_sabe_si_se_uso(R), reporte(S, U)]) :-
    medicamento(Med, _, controlado), receta(R, P, especial, Med),
    uso_receta(R, no_se), reporte(S, U), ahora(H), H - U > 1, !.
decide(_, _, surtir, [ninguna_regla_lo_impide]).

% R7 (nivel 12, BD dinámica) El gemelo aprende: registrar un surtido cambia sus respuestas.
registrar_surtido(R, Sucursal) :- ahora(H), assertz(surtido(R, Sucursal, H)).

% ======================================================= DCG (nivel 15)
% «le surto amoxil_500 a ana»  →  pregunta(ana, amoxil_500)
pregunta(P, Med) --> [le, surto], [Med], [a], [P].

pregunta_natural(Frase, Decision, Porque) :-
    split_string(Frase, " ", "¿?", Ps0), exclude(==(""), Ps0, Ps),
    maplist([S, A]>>(string_lower(S, L), atom_string(A, L)), Ps, Palabras),
    phrase(pregunta(P, Med), Palabras),
    decide(P, Med, Decision, Porque).

% ======================================================= CONSULTAS (6)
% Cada una extrae algo que NO está escrito como hecho. Se escriben como en la terminal.
consulta(1, "¿Ana es alérgica al Amoxil? (el hecho dice amoxicilina, no Amoxil)",
         "alergico(ana, amoxil_500).").
consulta(2, "¿Qué lotes de amoxicilina sirven para un tratamiento de 60 días?",
         "setof(L, lote_apto(amoxicilina_500, 60, L), Lotes).").
consulta(3, "¿A quién avisar del lote retirado y qué ventas no tienen rastro?",
         "findall(P, por_avisar(l_omep_a, P), Avisar), findall(V, sin_rastro(l_omep_a, V), SinRastro).").
consulta(4, "¿Se le puede vender ibuprofeno a Luis?",
         "decide(luis, ibuprofeno_400, Decision, Porque).").
consulta(5, "¿Se le surte amoxicilina a Pedro? (su ficha de alergias nunca se capturó)",
         "decide(pedro, amoxicilina_500, Decision, Porque).").
consulta(6, "¿Ya se usó la receta especial r103? («no» no es lo mismo que «no se sabe»)",
         "uso_receta(r103, Uso).").
consulta(7, "En lenguaje natural (DCG): «¿le surto amoxil_500 a ana?»",
         "pregunta_natural(\"¿le surto amoxil_500 a ana?\", Decision, Porque).").

%! demo is det.   Corre las consultas y las imprime como la terminal de SWI-Prolog.
demo :-
    forall(consulta(N, Texto, Src),
           ( term_string(Meta, Src, [variable_names(Bs)]),
             format("~n[~w] ~s~n?- ~s~n", [N, Texto, Src]),
             (   call(Meta)
             ->  ( Bs == [] -> writeln("true.")
                 ; forall((member(V = X, Bs), nonvar(X)), format("   ~w = ~W~n", [V, X, [quoted(true), spacing(next_argument)]])) )
             ;   writeln("false.") ) )),
    format("~n[8] El gemelo aprende (assert/retract, nivel 12): Otay reporta que surtió r103…~n"),
    format("?- registrar_surtido(r103, otay), uso_receta(r103, Uso).~n"),
    registrar_surtido(r103, otay),
    uso_receta(r103, U), format("   Uso = ~w        ← antes era no_se~n", [U]),
    retractall(surtido(r103, _, _)).
