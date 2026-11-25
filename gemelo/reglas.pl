/*  reglas.pl — Cómo se decide en la farmacia (gemelo digital del proyecto #42)

    Hugo Iram Aguirre Dávila · Programación Lógica y Funcional · TecNM Tijuana

    Predicados centrales (contrato de gemelo/CONTEXTO_AGENTES.md):

      decide(+Solicitudes, -Decision, -Explicacion)
          Reparto completo para una LISTA de solicitudes de mostrador. Al pedir más
          soluciones (;) entrega las demás alternativas válidas, de la mejor a la peor.
      situacion(?Entidad, ?Situacion, -Evidencia)
          Situaciones deducidas, consultables en cualquier dirección.
      que_falta(+Solicitud, -Faltas)           «la pregunta al revés»
      hipotesis(+Cambios, :Meta)              «¿qué pasaría si…?»
      retiro(+Lote, -Informe)                 cadena lote → venta → receta → paciente → aviso

    Toda condición tiene TRES resultados: si | no | no_se.
    Un dato ausente (alergia no capturada, sucursal sin reporte) nunca cuenta como «no».

    Una solicitud de mostrador es:
      sol(Id, Mostrador, Paciente, Receta, Med, Cantidad, DiasTratamiento, Instante)
        Paciente: átomo o anonimo · Receta: id o ninguna · Instante: minuto del día
*/
:- encoding(utf8).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(aggregate)).
:- use_module(library(pairs)).

:- discontiguous situacion/3, condicion/4, texto/4.

% ============================================================ utilidades

interactuan(A, B) :- interaccion(A, B).
interactuan(A, B) :- interaccion(B, A).

nombre_med(Med, N)      :- ( nombre_comercial(Med, N0) -> N = N0 ; N = Med ).
nombre_suc(S, N)        :- ( sucursal(S, N0) -> N = N0 ; N = S ).
nombre_medico(M, N)     :- ( medico(M, N0, _) -> N = N0 ; N = M ).
nombre_persona(anonimo, 'cliente no identificado') :- !.
nombre_persona(P, N)    :- sub_atom(P, 0, 1, _, F), upcase_atom(F, FU),
                           sub_atom(P, 1, _, 0, Resto), atom_concat(FU, Resto, N).

entregado(Entregas, K) :- foldl([_-N, A0, A]>>(A is A0 + N), Entregas, 0, K).

% ============================================================ lotes

%! estado_lote(?Lote, -Estado, -Evidencia) is nondet.
%  Estado: retirado | vencido | agotado | por_caducar | disponible (en ese orden de prioridad).
estado_lote(L, Estado, Ev) :-
    lote(L, Med, Cad, Est),
    ahora(H),
    ( existencia(L, U) -> true ; U = 0 ),
    (   lote_retirado(L, DR)
    ->  Estado = retirado, Ev = [lote_retirado(L, DR), existencia(L, U)]
    ;   Cad =< H
    ->  Estado = vencido, Ev = [lote(L, Med, Cad, Est), ahora(H)]
    ;   U =:= 0
    ->  Estado = agotado, Ev = [existencia(L, 0)]
    ;   dias_caducidad_cercana(C), Cad - H =< C
    ->  Estado = por_caducar, Ev = [lote(L, Med, Cad, Est), ahora(H), dias_caducidad_cercana(C)]
    ;   Estado = disponible, Ev = [lote(L, Med, Cad, Est), existencia(L, U)]
    ).

dias_restantes(L, D) :- lote(L, _, Cad, _), ahora(H), D is Cad - H.

%! evaluar_lote(+Med, +Dias, ?Lote, -Caducidad, -Veredicto) is nondet.
%  ¿Sirve este lote para un tratamiento de Dias días? Veredicto: si | no(Motivo).
%  Límite: el tratamiento no debe sobrevivir a la caducidad.
evaluar_lote(Med, Dias, L, Cad, Ver) :-
    lote(L, Med, Cad, _),
    estado_lote(L, E, _),
    ahora(H), Fin is H + Dias,
    (   E == retirado -> Ver = no(retirado)
    ;   E == vencido  -> Ver = no(vencido)
    ;   Fin > Cad     -> Ver = no(caduca_antes_de_terminar(Cad, Fin))
    ;   Ver = si
    ).

stock_inicial(St) :- findall(L-U, existencia(L, U), St).

%! aptos_con_stock(+Med, +Dias, +Stock, -Aptos) is det.
%  Aptos = [Lote-Caducidad-Restantes], primero el que caduca antes (FEFO).
aptos_con_stock(Med, Dias, St, Aptos) :-
    findall(Cad-L-R, ( evaluar_lote(Med, Dias, L, Cad, si),
                       memberchk(L-R, St), R > 0 ), A0),
    msort(A0, A1),
    findall(L-Cad-R, member(Cad-L-R, A1), Aptos).

% ============================================================ recetas

emision(R, S, Dia) :- evento_receta(R, emitida, S, Dia), !.

surtido_total(R, N) :- aggregate_all(sum(K), evento_receta(R, surtida(K), _, _), N).

pendiente(R, P) :- receta(R, _, _, _, _, C), surtido_total(R, S), P is max(0, C - S).

sucursal_sin_reporte(S, Ult) :-
    sucursal(S, _), reporte_sucursal(S, Ult),
    ahora(H), tolerancia_reporte(T), H - Ult > T.

%! uso_receta(+Receta, -Valor, -Evidencia) is det.   ¿Ya se surtió en alguna sucursal?
uso_receta(R, si, [evento_receta(R, surtida(N), S, D)]) :-
    evento_receta(R, surtida(N), S, D), !.
uso_receta(_, no_se, Ev) :-
    findall(sucursal_sin_reporte(S, U), sucursal_sin_reporte(S, U), Ev),
    Ev \== [], !.
uso_receta(_, no, [todas_las_sucursales_reportaron]).

% ============================================================ pacientes

%! alergia_a(+Paciente, +Med, -Valor, -Evidencia) is det.
%  Encadena nombre comercial → principio activo → alergia declarada.
alergia_a(Pac, Med, si, [medicamento(Med, PA, Req), alergia(Pac, PA)]) :-
    medicamento(Med, PA, Req), alergia(Pac, PA), !.
alergia_a(Pac, Med, no, [alergias_capturadas(Pac), medicamento(Med, PA, Req)]) :-
    alergias_capturadas(Pac), medicamento(Med, PA, Req), !.
alergia_a(Pac, _, no_se, [sin_ficha_de_alergias(Pac)]).

%! reciente(?Paciente, ?Med, ?Sucursal, ?Dia) is nondet.   Lo que recibió dentro de la ventana.
reciente(Pac, Med, S, D) :-
    venta(_, L, _, Pac, _, S, D), Pac \== desconocido,
    lote(L, Med, _, _),
    ahora(H), ventana_interaccion(W), D =< H, H - D =< W.

%! interaccion_con(+Paciente, +Med, -Valor, -Evidencia) is det.
interaccion_con(Pac, Med, si, [recibio(Pac, M2, S, D), interaccion(PA, PB)]) :-
    medicamento(Med, PA, _),
    reciente(Pac, M2, S, D), medicamento(M2, PB, _),
    interactuan(PA, PB), !.
interaccion_con(anonimo, _, no_se, [cliente_no_identificado]) :- !.
interaccion_con(Pac, _, no_se, [compra_en(Pac, S), sucursal_sin_reporte(S, U)]) :-
    sucursal_sin_reporte(S, U),
    venta(_, _, _, Pac, _, S, _), !.
interaccion_con(_, _, no, [ventana_interaccion(W)]) :- ventana_interaccion(W).

% ============================================================ condiciones

negar3(si, no).
negar3(no, si).
negar3(no_se, no_se).

%! condiciones(+Sol, -Condiciones) is det.   Condiciones = [c(Nombre, Valor, Evidencia)]
condiciones(Sol, Cs) :- findall(c(N, V, E), condicion(Sol, N, V, E), Cs).

% El orden de las cláusulas es el orden en que el farmacéutico las revisa.
condicion(sol(_,_,_,R,Med,_,_,_), receta_presentada, V, Ev) :-
    medicamento(Med, PA, Req), Req \== libre,
    (   R \== ninguna, receta(R, P, M, T, MR, C)
    ->  V = si, Ev = [receta(R, P, M, T, MR, C)]
    ;   V = no, Ev = [medicamento(Med, PA, Req)]
    ).
condicion(sol(_,_,Pac,R,Med,_,_,_), receta_corresponde, V, Ev) :-
    R \== ninguna, receta(R, P, M, T, MR, C),
    Ev = [receta(R, P, M, T, MR, C)],
    ( P == Pac, MR == Med -> V = si ; V = no ).
condicion(sol(_,_,_,R,Med,_,_,_), receta_especial, V, Ev) :-
    medicamento(Med, PA, controlado), R \== ninguna, receta(R, P, M, T, MR, C),
    Ev = [medicamento(Med, PA, controlado), receta(R, P, M, T, MR, C)],
    ( T == especial -> V = si ; V = no ).
condicion(sol(_,_,_,R,Med,_,_,_), folio_registrado, V, Ev) :-
    medicamento(Med, _, controlado), R \== ninguna, receta(R, _, _, especial, _, _),
    ( folio_especial(R, F) -> V = si, Ev = [folio_especial(R, F)] ; V = no, Ev = [sin_folio(R)] ).
condicion(sol(_,_,_,R,_,_,_,_), receta_vigente, V, Ev) :-
    R \== ninguna, receta(R, _, _, _, _, _),
    emision(R, S, E), vigencia_receta(Vg), ahora(H), Vence is E + Vg,
    Ev = [evento_receta(R, emitida, S, E), vigencia_receta(Vg), ahora(H)],
    ( H =< Vence -> V = si ; V = no ).
condicion(sol(_,_,_,R,Med,_,_,_), sin_uso_previo, V, Ev) :-
    medicamento(Med, _, controlado), R \== ninguna, receta(R, _, _, _, _, _),
    uso_receta(R, U, Ev), negar3(U, V).
condicion(sol(_,_,_,R,_,_,_,_), cantidad_pendiente, V, Ev) :-
    R \== ninguna, receta(R, _, _, _, _, C),
    surtido_total(R, S), P is C - S,
    Ev = [prescribe(R, C), surtido_total(R, S)],
    ( P > 0 -> V = si ; V = no ).
condicion(sol(_,_,Pac,_,Med,_,_,_), sin_alergia, V, Ev) :-
    medicamento(Med, _, _),
    alergia_a(Pac, Med, A, Ev), negar3(A, V).
condicion(sol(_,_,Pac,_,Med,_,_,_), sin_interaccion, V, Ev) :-
    medicamento(Med, _, _),
    interaccion_con(Pac, Med, I, Ev), negar3(I, V).

%! duda_bloquea(+Condicion, +Requisito) is semidet.
%  Qué incertidumbres detienen el surtido (suspender) y cuáles solo advierten.
duda_bloquea(sin_uso_previo, _).               % un controlado no se surte «a ciegas»
duda_bloquea(sin_alergia, Req) :- Req \== libre.

preveredicto(Req, Conds, Pre, Adv) :-
    findall(N, member(c(N, no, _), Conds), Bloq),
    findall(N, ( member(c(N, no_se, _), Conds), duda_bloquea(N, Req) ), Dudas),
    findall(N, ( member(c(N, no_se, _), Conds), \+ duda_bloquea(N, Req) ), Adv),
    (   Bloq \== []  -> Pre = rechazar(Bloq)
    ;   Dudas \== [] -> Pre = suspender(Dudas)
    ;   Pre = ok
    ).

%! evaluar(+Rank, +Sol, -Eval) is det.
%  Eval = ev(Rank, Sol, Requisito, Condiciones, Preveredicto, Advertencias, Objetivo)
evaluar(Rank, Sol, ev(Rank, Sol, Req, Conds, Pre, Adv, Obj)) :-
    Sol = sol(_, _, _, R, Med, Cant, _, _),
    (   medicamento(Med, _, Req)
    ->  condiciones(Sol, Conds),
        preveredicto(Req, Conds, Pre, Adv),
        (   R \== ninguna, pendiente(R, P) -> Obj is min(Cant, P) ; Obj = Cant )
    ;   Req = desconocido, Conds = [c(medicamento_conocido, no, [Med])],
        Pre = rechazar([medicamento_conocido]), Adv = [], Obj = 0
    ).

preparar(Sols, Evals) :-
    findall(I-S, ( member(S, Sols), S = sol(_,_,_,_,_,_,_,I) ), P0),
    keysort(P0, P1), pairs_values(P1, Ordenadas),          % por orden de llegada
    findall(E, ( nth1(K, Ordenadas, S), evaluar(K, S, E) ), Evals).

% ============================================================ reparto de lotes

%! asignar(+Evals, +Stock0, -Stock, -Asignacion) is nondet.
%  Asignacion = [a(SolId, [Lote-Unidades])]. Genera TODAS las formas de repartir.
asignar([], St, St, []).
asignar([E|Es], St0, St, [a(Id, Ent)|As]) :-
    E = ev(_, sol(Id, _, _, _, Med, _, Dias, _), Req, _, Pre, _, Obj),
    (   Pre == ok
    ->  aptos_con_stock(Med, Dias, St0, Aptos),
        foldl([_-_-R, A0, A]>>(A is A0 + R), Aptos, 0, Total),
        (   Req == controlado                     % un controlado: completo o nada
        ->  ( Total >= Obj -> K = Obj ; K = 0 )
        ;   Max is min(Obj, Total), between(0, Max, I), K is Max - I
        ),
        repartir(Aptos, K, Ent),
        descontar(Ent, St0, St1)
    ;   Ent = [], St1 = St0
    ),
    asignar(Es, St1, St, As).

repartir([], 0, []).
repartir([L-_-Rem|Ls], N, Ent) :-
    Max is min(N, Rem), between(0, Max, I), K is Max - I,
    N1 is N - K,
    repartir(Ls, N1, Ent0),
    ( K > 0 -> Ent = [L-K|Ent0] ; Ent = Ent0 ).

descontar([], St, St).
descontar([L-K|Es], St0, St) :-
    selectchk(L-R, St0, St1), R1 is R - K,
    descontar(Es, [L-R1|St1], St).

%! maximal(+Evals, +Asignacion, +StockFinal) is semidet.
%  Válida = nadie se queda corto mientras sobra un lote que le serviría.
maximal(Evals, As, StF) :-
    forall(( member(ev(_, sol(Id,_,_,_,Med,_,Dias,_), Req, _, ok, _, Obj), Evals),
             memberchk(a(Id, Ent), As), entregado(Ent, K), K < Obj,
             Req \== controlado ),
           aptos_con_stock(Med, Dias, StF, [])).

%! costo(+Evals, +Asignacion, -Costo) is det.
%  c(UnidadesSinSurtir, FEFO, Llegada): menor es mejor, en ese orden.
%    FEFO    = Σ unidades × caducidad          (sale primero lo que caduca antes)
%    Llegada = Σ rango × unidades × (cadMax − caducidad)   (desempate: quien llegó primero)
costo(Evals, As, c(Faltan, Fefo, Lleg)) :-
    findall(F, ( member(ev(_, sol(Id,_,_,_,_,_,_,_), _, _, ok, _, Obj), Evals),
                 memberchk(a(Id, Ent), As), entregado(Ent, K), F is Obj - K ), Fs),
    sum_list(Fs, Faltan),
    findall(X-Y, ( member(ev(Rk, sol(Id,_,_,_,Med,_,_,_), _, _, _, _, _), Evals),
                   memberchk(a(Id, Ent), As), member(L-K, Ent),
                   lote(L, _, Cad, _), cad_max(Med, Mx),
                   X is K * Cad, Y is Rk * K * (Mx - Cad) ), XYs),
    pairs_keys_values(XYs, Xs, Ys),
    sum_list(Xs, Fefo), sum_list(Ys, Lleg).

cad_max(Med, Mx) :- aggregate_all(max(C), lote(_, Med, C, _), Mx).

% ============================================================ decisión

%! decide(+Solicitudes, -Decision, -Explicacion) is nondet.
decide(Sols, Decision, Explicacion) :-
    decide(Sols, _, Decision, Explicacion).

%! decide(+Solicitudes, ?alternativa(N, Total), -Decision, -Explicacion) is nondet.
%  Decision = [r(SolId, Veredicto, Entregas, AccionesReceta, Avisos)]
%  Explicacion = [porque(SolId, Tipo, Texto, Hechos)]
%  Nunca falla en silencio: si nada se puede surtir, el veredicto dice por qué.
decide(Sols, alternativa(N, Total), Decision, Explicacion) :-
    preparar(Sols, Evals),
    stock_inicial(St0),
    findall(C-As, ( asignar(Evals, St0, StF, As),
                    maximal(Evals, As, StF),
                    costo(Evals, As, C) ), P0),
    sort(P0, Pares),                       % la mejor primero, sin repetidas
    length(Pares, Total),
    nth1(N, Pares, Costo-As),
    maplist(resultado(As), Evals, Decision),
    explicar(Evals, As, Decision, N, Total, Costo, Pares, Explicacion).

resultado(As, ev(_, Sol, Req, Conds, Pre, _, Obj), r(Id, Ver, Ent, Acc, Avisos)) :-
    Sol = sol(Id, _, _, R, Med, _, _, _),
    memberchk(a(Id, Ent), As), entregado(Ent, K),
    veredicto(Pre, K, Obj, Ver),
    acciones_receta(R, Med, Req, K, Acc),
    findall(A, ( aviso(Sol, Conds, A), aviso_relevante(Ver, A) ), Avisos).

% Si ya se rechaza por otra causa, confirmar el folio con la otra sucursal no cambia nada.
aviso_relevante(rechazar(_), avisar(sucursal(_), confirmar_folio)) :- !, fail.
aviso_relevante(_, _).

veredicto(rechazar(Ns), _, _, rechazar(Ns)).
veredicto(suspender(Ns), _, _, suspender(Ns)).
veredicto(ok, K, Obj, V) :-
    (   K =:= 0  -> V = rechazar([sin_existencias_aptas])
    ;   K < Obj  -> V = surtir_parcial(K, Obj)
    ;   V = surtir(K)
    ).

%! acciones_receta(+Receta, +Med, +Requisito, +Unidades, -Acciones) is det.
acciones_receta(ninguna, _, _, K, Acc) :- !,
    ( K > 0 -> Acc = [registrar_venta(K)] ; Acc = [] ).
acciones_receta(_, _, _, 0, [devolver_receta_sin_surtir]) :- !.
acciones_receta(R, _, controlado, K, [registrar_salida(K), retener_receta, asentar_libro_control(F)]) :- !,
    ( folio_especial(R, F) -> true ; F = sin_folio ).
acciones_receta(R, Med, receta, K, Acc) :-
    medicamento(Med, PA, _), antibiotico(PA), !,
    receta(R, _, _, _, _, C), surtido_total(R, S0), Total is S0 + K, ahora(H),
    (   Total >= C
    ->  Acc = [sellar_receta(K, H), registrar_bitacora_antibioticos, retener_receta]
    ;   Falta is C - Total,
        Acc = [sellar_receta(K, H), registrar_bitacora_antibioticos, devolver_al_paciente(falta(Falta))]
    ).
acciones_receta(_, _, receta, K, [registrar_surtido(K), devolver_al_paciente(resurtible)]) :- !.
acciones_receta(_, _, _, K, [registrar_venta_con_receta(K)]).

%! aviso(+Sol, +Condiciones, -Aviso) is nondet.   ¿A quién se avisa?
aviso(sol(_,_,_,R,_,_,_,_), Conds, avisar(medico(M), alergia(PA))) :-
    member(c(sin_alergia, no, Ev), Conds), memberchk(alergia(_, PA), Ev),
    R \== ninguna, receta(R, _, M, _, _, _).
aviso(sol(_,_,Pac,R,_,_,_,_), Conds, avisar(medico(M), interaccion(M2))) :-
    member(c(sin_interaccion, no, Ev), Conds), memberchk(recibio(Pac, M2, _, _), Ev),
    medico_responsable(R, Pac, M2, M).
aviso(_, Conds, avisar(sucursal(S), confirmar_folio)) :-
    member(c(sin_uso_previo, no_se, Ev), Conds), member(sucursal_sin_reporte(S, _), Ev).
aviso(_, Conds, avisar(responsable_sanitario, receta_ya_surtida(S, D))) :-
    member(c(sin_uso_previo, no, Ev), Conds), member(evento_receta(_, surtida(_), S, D), Ev).
aviso(sol(_,_,Pac,_,_,_,_,_), Conds, avisar(paciente(Pac), capturar_ficha_alergias)) :-
    member(c(sin_alergia, no_se, _), Conds), Pac \== anonimo.

medico_responsable(R, _, _, M) :- R \== ninguna, receta(R, _, M, _, _, _), !.
medico_responsable(_, Pac, M2, M) :-
    venta(_, L, _, Pac, R2, _, _), lote(L, M2, _, _),
    R2 \== ninguna, receta(R2, _, M, _, _, _), !.

% ============================================================ explicación
% porque(SolId, Tipo, Texto, Hechos)
%   Tipo: decision | bloqueo | duda | dilema | contraintuitivo | lote | advertencia | apoyo
%   Lo que le sirve al farmacéutico va primero; «apoyo» es la evidencia (se muestra plegada).

explicar(Evals, As, Decision, N, Total, Costo, Pares, Expl) :-
    global(N, Total, Costo, Pares, G),
    findall(P, ( member(E, Evals), porque_sol(E, As, Decision, Evals, P) ), Ps),
    append(G, Ps, Expl).

global(N, Total, Costo, Pares, [porque(todas, decision, T, [])|Comp]) :-
    format(string(T),
           "Alternativa ~w de ~w. Preferencia: (1) surtir más unidades, (2) FEFO: sale primero el lote que caduca antes, (3) desempate por orden de llegada.",
           [N, Total]),
    (   N > 1, Pares = [Mejor-_|_]
    ->  comparar(Mejor, Costo, TC), Comp = [porque(todas, advertencia, TC, [])]
    ;   Comp = []
    ).

comparar(c(F1, E1, L1), c(F2, E2, L2), T) :-
    (   F2 > F1 -> D is F2 - F1,
        format(string(T), "Es válida pero peor que la 1: deja ~w unidad(es) más sin surtir.", [D])
    ;   E2 > E1 -> format(string(T), "Es válida pero peor que la 1: no respeta FEFO (deja en el estante unidades de un lote que caduca antes).", [])
    ;   L2 > L1 -> format(string(T), "Es válida pero peor que la 1: da el lote que caduca antes a quien llegó después.", [])
    ;   T = "Equivalente a la alternativa 1."
    ).

porque_sol(ev(_, Sol, Req, Conds, Pre, _, Obj), _As, Decision, Evals, P) :-
    Sol = sol(Id, Mo, Pac, R, Med, Cant, Dias, Inst),
    memberchk(r(Id, Ver, Ent, Acc, _), Decision),
    (   texto_veredicto(Sol, Ver, T), P = porque(Id, decision, T, [Sol])
    ;   Cant > Obj, Obj > 0, R \== ninguna,
        format(string(T), "Pidió ~w, pero a la receta ~w solo le faltan ~w: lo que pide el mostrador se ajusta a lo pendiente.", [Cant, R, Obj]),
        P = porque(Id, apoyo, T, [prescribe_y_surtido(R)])
    ;   member(c(N, V, Ev), Conds),
        tipo_por_valor(N, V, Req, Tipo),
        texto(N, V, Ev, T0), atom_string(T0, T),
        P = porque(Id, Tipo, T, Ev)
    ;   Pre == ok, member(L-K, Ent), lote(L, _, Cad, Est),
        format(string(T), "Se entrega(n) ~w u de ~w (caduca el día ~w, estante ~w).", [K, L, Cad, Est]),
        P = porque(Id, lote, T, [lote(L, Med, Cad, Est)])
    ;   Pre == ok, evaluar_lote(Med, Dias, L, Cad, no(M)), lote(L, _, _, EstL),
        texto_lote(L, Cad, M, T), P = porque(Id, lote, T, [lote(L, Med, Cad, EstL)])
    ;   memberchk(devolver_al_paciente(falta(F)), Acc),
        texto_dilema(F, T), P = porque(Id, dilema, T, [antibiotico(Med)])
    ;   contraintuitivo(Sol, Ent, Evals, Decision, T),
        P = porque(Id, contraintuitivo, T, [mostrador(Mo), instante(Inst), paciente(Pac)])
    ).

tipo_por_valor(_, no, _, bloqueo).
tipo_por_valor(N, no_se, Req, duda)        :- duda_bloquea(N, Req), !.
tipo_por_valor(_, no_se, _, advertencia).
tipo_por_valor(_, si, _, apoyo).

%  Lo «obvio» (el lote que caduca antes para quien llegó primero) no siempre conviene.
contraintuitivo(sol(Id,_,Pac,_,Med,_,Dias,Inst), Ent, Evals, Decision, T) :-
    member(L-_, Ent), lote(L, _, CadMia, _),
    member(ev(_, sol(Id2,_,Pac2,_,Med,_,_,Inst2), _, _, _, _, _), Evals),
    Id2 \== Id, Inst2 > Inst,
    memberchk(r(Id2, _, Ent2, _, _), Decision),
    member(L2-_, Ent2), lote(L2, _, Cad2, _), Cad2 < CadMia,
    evaluar_lote(Med, Dias, L2, _, no(caduca_antes_de_terminar(Cad2, Fin))), !,
    nombre_persona(Pac, NP), nombre_persona(Pac2, NP2),
    format(string(T),
           "Contra la intuición: ~w llegó primero, pero ~w caduca el día ~w y su tratamiento terminaría el día ~w. Por eso ~w recibe ~w y ~w (tratamiento corto) se lleva el blíster que caduca antes: así se cumple FEFO sin entregar algo que vencería a medio tratamiento.",
           [NP, L2, Cad2, Fin, NP, L, NP2]).

texto_lote(L, _, retirado, T) :- !,
    lote_retirado(L, D), format(string(T), "~w no se usa: retirado por alerta sanitaria el día ~w.", [L, D]).
texto_lote(L, Cad, vencido, T) :- !,
    format(string(T), "~w no se usa: venció el día ~w.", [L, Cad]).
texto_lote(L, Cad, caduca_antes_de_terminar(Cad, Fin), T) :-
    format(string(T), "~w no sirve para este paciente: caduca el día ~w y el tratamiento terminaría el día ~w.", [L, Cad, Fin]).

texto_dilema(F, T) :-
    format(string(T),
           "Dilema: retener la receta impediría completar el tratamiento en otra farmacia; no retenerla permitiría surtirla dos veces. Regla (Acuerdo DOF 27/05/2010): en cada surtido se SELLA la receta con cantidad y fecha y se registra en la bitácora; se retiene solo al agotar lo prescrito. Pierde la farmacia: asume el riesgo residual de un doble surtido (lo mitigan el sello y la bitácora). Gana el paciente: puede completar las ~w caja(s) que faltan aquí o en otra farmacia.",
           [F]).

texto_veredicto(sol(_,_,_,_,Med,_,_,_), surtir(K), T) :-
    nombre_med(Med, N), format(string(T), "SURTIR ~w unidad(es) de ~w.", [K, N]).
texto_veredicto(sol(_,_,_,_,Med,_,_,_), surtir_parcial(K, Obj), T) :-
    nombre_med(Med, N), F is Obj - K,
    format(string(T), "SURTIR PARCIAL: ~w de ~w unidad(es) de ~w; quedan ~w pendiente(s).", [K, Obj, N, F]).
texto_veredicto(_, rechazar(Ns), T) :-
    maplist(etiqueta, Ns, Es), atomic_list_concat(Es, '; ', A),
    format(string(T), "RECHAZAR: ~w.", [A]).
texto_veredicto(_, suspender(Ns), T) :-
    maplist(etiqueta, Ns, Es), atomic_list_concat(Es, '; ', A),
    format(string(T), "SUSPENDER (no se sabe, no se surte a ciegas): ~w.", [A]).

etiqueta(receta_presentada,    'falta la receta médica').
etiqueta(receta_corresponde,   'la receta no es de este paciente o de este medicamento').
etiqueta(receta_especial,      'un controlado exige receta especial').
etiqueta(folio_registrado,     'la receta especial no tiene folio registrado').
etiqueta(receta_vigente,       'la receta ya no está vigente').
etiqueta(sin_uso_previo,       'uso previo de la receta en otra sucursal').
etiqueta(cantidad_pendiente,   'la receta ya está cerrada (todo surtido)').
etiqueta(sin_alergia,          'alergia al principio activo').
etiqueta(sin_interaccion,      'interacción peligrosa con lo que ya recibió').
etiqueta(sin_existencias_aptas,'no hay lote apto con existencias').
etiqueta(medicamento_conocido, 'medicamento desconocido').

% ---------------------------------------------- textos de cada condición
texto(receta_presentada, si, [receta(R, _, M, T, _, _)], X) :-
    nombre_medico(M, NM), format(atom(X), "Presenta la receta ~w (~w), firmada por ~w.", [R, T, NM]).
texto(receta_presentada, no, [medicamento(Med, _, Req)], X) :-
    nombre_med(Med, N), format(atom(X), "~w exige receta (~w) y no se presentó.", [N, Req]).
texto(receta_corresponde, si, [receta(R, P, _, _, Med, _)], X) :-
    nombre_med(Med, N), nombre_persona(P, NP),
    format(atom(X), "La receta ~w es de ~w y prescribe ~w.", [R, NP, N]).
texto(receta_corresponde, no, [receta(R, P, _, _, Med, _)], X) :-
    nombre_med(Med, N), nombre_persona(P, NP),
    format(atom(X), "La receta ~w no corresponde: es de ~w y prescribe ~w.", [R, NP, N]).
texto(receta_especial, si, _, 'Es receta especial, como exige un controlado.').
texto(receta_especial, no, [medicamento(Med, _, _), receta(_, _, _, T, _, _)], X) :-
    nombre_med(Med, N),
    format(atom(X), "~w es controlado: exige receta ESPECIAL, registrada y asentada en el libro de control; esta es ~w. Lo intuitivo («trae receta firmada, se surte») está mal aquí.", [N, T]).
texto(folio_registrado, si, [folio_especial(_, F)], X) :-
    format(atom(X), "Folio de receta especial registrado: ~w.", [F]).
texto(folio_registrado, no, _, 'La receta especial no tiene folio registrado.').
texto(receta_vigente, V, [evento_receta(_, emitida, _, E), vigencia_receta(Vg), _], X) :-
    Vence is E + Vg,
    (   V == si -> format(atom(X), "Vigente: emitida el día ~w, vence el día ~w.", [E, Vence])
    ;   format(atom(X), "Vencida: emitida el día ~w, venció el día ~w.", [E, Vence]) ).
texto(sin_uso_previo, si, _, 'No se ha surtido en ninguna sucursal y todas reportaron: «no se usó».').
texto(sin_uso_previo, no, [evento_receta(_, surtida(N), S, D)], X) :-
    nombre_suc(S, NS), format(atom(X), "Ya se usó: se surtieron ~w unidad(es) en ~w el día ~w.", [N, NS, D]).
texto(sin_uso_previo, no_se, Ev, X) :-
    findall(T, ( member(sucursal_sin_reporte(S, U), Ev), nombre_suc(S, NS),
                 format(atom(T), "~w no reporta desde el día ~w", [NS, U]) ), Ts),
    atomic_list_concat(Ts, '; ', A),
    format(atom(X), "NO SE SABE si ya se usó: ~w. «No sé si se usó» no es lo mismo que «no se usó».", [A]).
texto(cantidad_pendiente, V, [prescribe(_, C), surtido_total(_, S)], X) :-
    F is C - S,
    (   V == si -> format(atom(X), "Prescribe ~w; ya se surtieron ~w; faltan ~w.", [C, S, F])
    ;   format(atom(X), "Receta cerrada: prescribe ~w y ya se surtieron ~w.", [C, S]) ).
texto(sin_alergia, si, [alergias_capturadas(P), medicamento(_, PA, _)], X) :-
    nombre_persona(P, NP),
    format(atom(X), "~w tiene ficha de alergias y no es alérgico(a) a ~w.", [NP, PA]).
texto(sin_alergia, no, [medicamento(Med, PA, _), alergia(P, PA)], X) :-
    nombre_med(Med, N), nombre_persona(P, NP),
    format(atom(X), "~w es alérgico(a) a ~w, el principio activo de ~w (aunque el nombre comercial sea otro).", [NP, PA, N]).
texto(sin_alergia, no_se, [sin_ficha_de_alergias(anonimo)], 'Cliente no identificado: sus alergias son desconocidas (advertir de palabra).') :- !.
texto(sin_alergia, no_se, [sin_ficha_de_alergias(P)], X) :-
    nombre_persona(P, NP),
    format(atom(X), "NO SE SABE si ~w es alérgico(a): su ficha nunca se capturó. Eso es «no se sabe», no «sin alergias».", [NP]).
texto(sin_interaccion, si, [ventana_interaccion(W)], X) :-
    format(atom(X), "Sin interacciones con lo que recibió en los últimos ~w días.", [W]).
texto(sin_interaccion, no, [recibio(P, M2, S, D), interaccion(PA, PB)], X) :-
    nombre_persona(P, NP), nombre_med(M2, N2), nombre_suc(S, NS),
    format(atom(X), "Interacción peligrosa ~w + ~w: ~w recibió ~w en ~w el día ~w.", [PA, PB, NP, N2, NS, D]).
texto(sin_interaccion, no_se, [cliente_no_identificado], 'Cliente no identificado: no se puede revisar su historial (preguntar qué medicamentos toma).') :- !.
texto(sin_interaccion, no_se, [compra_en(P, S), sucursal_sin_reporte(S, U)], X) :-
    nombre_persona(P, NP), nombre_suc(S, NS),
    format(atom(X), "Historial incompleto: ~w compra en ~w y esa sucursal no reporta desde el día ~w (preguntar al paciente).", [NP, NS, U]).
texto(medicamento_conocido, no, [Med], X) :-
    format(atom(X), "~w no está en el catálogo.", [Med]).

% ============================================================ la pregunta al revés

%! que_falta(+Sol, -Faltas) is det.   Faltas = [falta(Condicion, Valor, QueHacer)]
%  Usa LAS MISMAS condiciones que decide/3: no hay reglas duplicadas.
que_falta(Sol, Faltas) :-
    preparar([Sol], [ev(_, _, _, Conds, Pre, _, Obj)]),
    findall(falta(N, V, A), ( member(c(N, V, Ev), Conds), V \== si,
                              remedio(N, V, Ev, A) ), F0),
    Sol = sol(_, _, _, _, Med, _, Dias, _),
    (   Pre == ok, stock_inicial(St), aptos_con_stock(Med, Dias, St, Aptos),
        foldl([_-_-R, A0, A1]>>(A1 is A0 + R), Aptos, 0, Total), Total < Obj
    ->  Faltan is Obj - Total, nombre_med(Med, NM),
        format(string(TA), "Reabastecer ~w: faltan ~w unidad(es) de un lote que no caduque antes de terminar el tratamiento.", [NM, Faltan]),
        append(F0, [falta(existencias, no, TA)], Faltas)
    ;   Faltas = F0
    ).

%! que_falta_receta(+Receta, -Faltas) is det.   ¿Qué le falta a la receta para surtirse?
que_falta_receta(R, Faltas) :-
    receta(R, Pac, _, _, Med, _), pendiente(R, P), Q is max(1, P),
    que_falta(sol(R, m1, Pac, R, Med, Q, 0, 0), Faltas).

remedio(receta_presentada, no, _, "Presentar receta médica del medicamento.").
remedio(receta_corresponde, no, _, "Receta a nombre del paciente y del medicamento que pide.").
remedio(receta_especial, no, _, "Receta ESPECIAL (con folio) expedida por el médico.").
remedio(folio_registrado, no, _, "Registrar el folio de la receta especial.").
remedio(receta_vigente, no, _, "Receta nueva: la actual ya venció.").
remedio(sin_uso_previo, no, _, "Nada la habilita: ya se usó. Se necesita una receta nueva.").
remedio(sin_uso_previo, no_se, Ev, A) :-
    findall(NS, ( member(sucursal_sin_reporte(S, _), Ev), nombre_suc(S, NS) ), Ss),
    atomic_list_concat(Ss, ', ', SA),
    format(string(A), "Que ~w reporte sus surtidos (o confirme por teléfono que el folio no se surtió).", [SA]).
remedio(cantidad_pendiente, no, _, "Receta nueva: ya se surtió todo lo prescrito.").
remedio(sin_alergia, no, [_, alergia(_, PA)], A) :-
    format(string(A), "Que el médico prescriba un medicamento sin ~w.", [PA]).
remedio(sin_alergia, no_se, _, "Capturar la ficha de alergias del paciente.").
remedio(sin_interaccion, no, [recibio(_, _, _, D), _], A) :-
    ventana_interaccion(W), Hasta is D + W,
    format(string(A), "Autorización/ajuste del médico, o esperar a que salga de la ventana de interacción (día ~w).", [Hasta]).
remedio(sin_interaccion, no_se, _, "Preguntar al paciente qué medicamentos tomó en los últimos días.").
remedio(medicamento_conocido, no, _, "Dar de alta el medicamento en el catálogo.").

% ============================================================ hipótesis

%! hipotesis(+Cambios, :Meta) is nondet.
%  Cambios: [+Hecho, -Hecho, ...]. Aplica los cambios, resuelve Meta con LAS MISMAS
%  reglas y deshace todo al terminar (también si Meta falla o lanza excepción).
hipotesis(Cambios, Meta) :-
    setup_call_cleanup(aplicar_cambios(Cambios, Deshacer),
                       findall(Meta, call(Meta), Rs),
                       deshacer(Deshacer)),
    member(Meta, Rs).

aplicar_cambios(Cs, D) :- foldl(aplicar_cambio, Cs, [], D).
aplicar_cambio(+H, D0, [erase(Ref)|D0]) :- assertz(H, Ref).
aplicar_cambio(-H, D0, D) :-
    findall(H, retract(H), Hs),
    foldl([X, A0, [assertz(X)|A0]]>>true, Hs, D0, D).
deshacer(D) :- forall(member(A, D), call(A)).

% ============================================================ lote retirado

%! aviso_retiro(?Lote, ?Paciente, -Medio, -Cadena) is nondet.
%  Cadena: lote → venta → receta → paciente → medio de aviso.
aviso_retiro(Lote, Pac, Medio, [lote_retirado(Lote, DR), venta(V, Lote, U, Pac, Rec, S, D)|Resto]) :-
    lote_retirado(Lote, DR),
    venta(V, Lote, U, Pac, Rec, S, D), Pac \== desconocido,
    medio_aviso(Pac, Rec, Medio, Resto).

medio_aviso(Pac, _, telefono(T), [contacto(Pac, T)]) :- contacto(Pac, T), !.
medio_aviso(Pac, Rec, via_medico(M), [receta(Rec, Pac, M, Ti, Me, C), sin_contacto(Pac)]) :-
    Rec \== ninguna, receta(Rec, Pac, M, Ti, Me, C), !.
medio_aviso(Pac, _, no_localizable, [sin_contacto(Pac)]).

%! venta_sin_rastro(?Lote, ?Venta, -Unidades, -Sucursal, -Dia) is nondet.   «no se sabe a quién»
venta_sin_rastro(Lote, V, U, S, D) :- venta(V, Lote, U, desconocido, _, S, D).

%! destino_devolucion(?Dev, -Destino, -DependeDe, -Evidencia) is nondet.
destino_devolucion(Dev, Destino, Depende, Ev) :-
    devolucion(Dev, Med, L, Estado, D),
    Ev0 = [devolucion(Dev, Med, L, Estado, D)],
    (   L == desconocido
    ->  Destino = cuarentena,
        (   lote(LR, Med, _, _), lote_retirado(LR, DR)
        ->  format(string(Depende), "No se sabe de qué lote es y hay un lote retirado del mismo medicamento (~w). No regresa: queda en cuarentena hasta identificar el lote. Regresaría solo si NO es ~w, el empaque está cerrado y el lote no ha caducado.", [LR, LR]),
            Ev = [lote_retirado(LR, DR)|Ev0]
        ;   Depende = "Sin lote no se puede verificar caducidad ni retiro: cuarentena hasta identificarlo.",
            Ev = Ev0 )
    ;   lote_retirado(L, DR)
    ->  Destino = retiro_al_proveedor, Ev = [lote_retirado(L, DR)|Ev0],
        Depende = "Es del lote retirado: va con el resto del lote al proveedor; nunca al estante."
    ;   Estado == abierta
    ->  Destino = merma, Ev = Ev0,
        Depende = "Empaque abierto: no se puede garantizar el producto. Es merma."
    ;   estado_lote(L, vencido, EvV)
    ->  Destino = merma, append(EvV, Ev0, Ev), Depende = "El lote ya venció."
    ;   Destino = regresa_al_inventario, Ev = Ev0,
        Depende = "Lote identificado, vigente, no retirado y empaque cerrado."
    ).

%! retiro(+Lote, -Informe) is semidet.
retiro(Lote, retiro(Lote, DR, Avisar, SinRastro, Estante, Devs, Incidentes)) :-
    lote_retirado(Lote, DR),
    findall(aviso(P, Medio, Cad), aviso_retiro(Lote, P, Medio, Cad), Avisar),
    findall(sin_rastro(V, U, S, D), venta_sin_rastro(Lote, V, U, S, D), SinRastro),
    lote(Lote, Med, _, Est), ( existencia(Lote, EU) -> true ; EU = 0 ),
    Estante = estante(Est, EU),
    findall(dev(Dv, Dest, Dep), ( devolucion(Dv, Med, _, _, _),
                                  destino_devolucion(Dv, Dest, Dep, _) ), Devs),
    findall(venta_posterior(V, S, D), ( venta(V, Lote, _, _, _, S, D), D > DR ), Incidentes).

% ============================================================ situaciones

%! situacion(?Entidad, ?Situacion, -Evidencia) is nondet.
%  Cada cláusula genera primero la entidad desde los hechos: funciona en cualquier dirección.
situacion(L, lote(E), Ev) :- estado_lote(L, E, Ev).

situacion(R, receta_valida, Ev)         :- estado_receta(R, valida, Ev).
situacion(R, receta_invalida(Ns), Ev)   :- estado_receta(R, invalida(Ns), Ev).
situacion(R, receta_dudosa(Ns), Ev)     :- estado_receta(R, dudosa(Ns), Ev).
situacion(R, receta_usada(S, D), [evento_receta(R, surtida(N), S, D)]) :-
    receta(R, _, _, _, _, _), evento_receta(R, surtida(N), S, D).
situacion(R, receta_cerrada, [prescribe(R, C), surtido_total(R, S)]) :-
    receta(R, _, _, _, _, C), surtido_total(R, S), S >= C.
situacion(R, receta_abierta(P), [prescribe(R, C), surtido_total(R, S)]) :-
    receta(R, _, _, _, _, C), surtido_total(R, S), P is C - S, P > 0.

situacion(V, venta_sin_rastro, [venta(V, L, U, desconocido, Rc, S, D)]) :-
    venta(V, L, U, desconocido, Rc, S, D).

situacion(Pac, riesgo_interaccion(PA, PB), [recibio(Pac, M2, S, D), interaccion(PA, PB)]) :-
    paciente(Pac), reciente(Pac, M2, S, D), medicamento(M2, PB, _), interactuan(PA, PB).
situacion(Pac, alergia_en_receta(R), Ev) :-
    receta(R, Pac, _, _, Med, _), alergia_a(Pac, Med, si, Ev).
situacion(Pac, alergias_desconocidas, [sin_ficha_de_alergias(Pac)]) :-
    paciente(Pac), \+ alergias_capturadas(Pac).
situacion(Pac, por_avisar(Lote), Cadena) :-
    aviso_retiro(Lote, Pac, _, Cadena).

situacion(S, sucursal_sin_reporte(U), [reporte_sucursal(S, U), ahora(H)]) :-
    sucursal_sin_reporte(S, U), ahora(H).

%! estado_receta(?Receta, -Estado, -Evidencia) is nondet.
%  Evalúa la receta con las condiciones de decide/3 (solo las de la receta).
estado_receta(R, Estado, Ev) :-
    receta(R, Pac, _, _, Med, _),
    pendiente(R, P), Q is max(P, 1),
    condiciones(sol(R, m1, Pac, R, Med, Q, 0, 0), Cs0),
    include(cond_de_receta, Cs0, Ev),
    findall(N, member(c(N, no, _), Ev), No),
    findall(N, member(c(N, no_se, _), Ev), NS),
    (   No \== [] -> Estado = invalida(No)
    ;   NS \== [] -> Estado = dudosa(NS)
    ;   Estado = valida
    ).

cond_de_receta(c(N, _, _)) :-
    memberchk(N, [receta_presentada, receta_corresponde, receta_especial, folio_registrado,
                  receta_vigente, sin_uso_previo, cantidad_pendiente]).
