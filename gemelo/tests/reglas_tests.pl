/*  reglas_tests.pl — Pruebas plunit del gemelo digital (al menos una por situación)

    Ejecutar:  swipl -g run_tests -t halt tests/reglas_tests.pl
*/
:- encoding(utf8).
:- use_module(library(plunit)).
:- prolog_load_context(directory, D), atom_concat(D, '/../gemelo', G), ensure_loaded(G).

% ------------------------------------------------------------ utilidades de prueba
sol_de(Esc, S) :- escenario(Esc, _, _, _, [S|_], _).
sols_de(Esc, Ss) :- escenario(Esc, _, _, _, Ss, _).

veredicto_de(Esc, Id, V) :-
    sols_de(Esc, Ss), decide(Ss, alternativa(1, _), D, _), memberchk(r(Id, V, _, _, _), D).

% =========================================================== Situación 1
:- begin_tests(s1_receta_que_parece_buena).

test(controlado_con_receta_comun_se_rechaza) :-
    veredicto_de(s11, s11, rechazar(Ns)),
    memberchk(receta_especial, Ns).

test(misma_receta_comun_si_sirve_para_med_con_receta) :-
    veredicto_de(s12, s12, surtir(1)).

% La MISMA receta r102: si prescribiera un controlado, se rechaza.
test(la_misma_receta_con_controlado_se_rechaza) :-
    hipotesis([ -receta(r102, _, _, _, _, _),
                +receta(r102, carmen, dr_soto, comun, clonazepam_2, 1) ],
              decide([sol(x, m1, carmen, r102, clonazepam_2, 1, 30, 600)], D, _)), !,
    D = [r(x, rechazar(Ns), [], _, _)],
    memberchk(receta_especial, Ns).

test(sin_reporte_de_otay_es_no_se_sabe_y_no_se_surte) :-
    sol_de(s13, S), condiciones(S, Cs),
    memberchk(c(sin_uso_previo, no_se, _), Cs),       % «no se sabe», no «no se usó»
    \+ memberchk(c(sin_uso_previo, si, _), Cs),
    veredicto_de(s13, s13, suspender([sin_uso_previo])).

test(si_otay_reporta_se_surte_y_se_retiene) :-
    decide_escenario(s13, otay_reporta, alternativa(1, _), [r(s13, surtir(1), _, Acc, _)], _), !,
    memberchk(retener_receta, Acc),
    memberchk(asentar_libro_control('F-2026-0103'), Acc).

test(receta_especial_ya_usada_se_rechaza_y_se_avisa) :-
    sols_de(s14, Ss), decide(Ss, [r(s14, rechazar(Ns), [], _, Av)], _), !,
    memberchk(sin_uso_previo, Ns),
    memberchk(avisar(responsable_sanitario, receta_ya_surtida(otay, 195)), Av).

:- end_tests(s1_receta_que_parece_buena).

% =========================================================== Situación 2
:- begin_tests(s2_surtido_parcial).

test(lo_que_falta_se_deduce_del_historial) :-
    pendiente(r201, 3).

test(surtido_parcial_no_excede_lo_prescrito) :-
    veredicto_de(s21, s21, surtir_parcial(2, 3)),
    receta(r201, _, _, _, _, Prescrito), surtido_total(r201, Antes),
    Antes + 2 =< Prescrito.

test(se_sella_y_se_devuelve_no_se_retiene) :-
    sols_de(s21, Ss), decide(Ss, [r(s21, _, _, Acc, _)], _), !,
    memberchk(sellar_receta(2, 200), Acc),
    memberchk(devolver_al_paciente(falta(1)), Acc),
    \+ memberchk(retener_receta, Acc).

test(el_dilema_nombra_quien_pierde, [nondet]) :-
    sols_de(s21, Ss), decide(Ss, _, E), !,
    member(porque(s21, dilema, T, _), E),
    sub_string(T, _, _, _, "Pierde la farmacia").

test(al_completar_se_retiene_la_receta) :-
    decide_escenario(s21, llega_amox, alternativa(1, _), [r(s21, surtir(3), _, Acc, _)], _), !,
    memberchk(retener_receta, Acc).

:- end_tests(s2_surtido_parcial).

% =========================================================== Situación 3
:- begin_tests(s3_ultimo_blister).

test(reparto_contraintuitivo) :-
    sols_de(s31, Ss), decide(Ss, alternativa(1, _), D, _), !,
    memberchk(r(s31, surtir(1), [l_lora_b-1], _, _), D),   % Luis llegó primero…
    memberchk(r(s32, surtir(1), [l_lora_a-1], _, _), D).   % …pero el último blíster es de Ana

test(hay_alternativas_validas_y_se_explica_la_descartada, [nondet]) :-
    sols_de(s31, Ss),
    findall(N-D, decide(Ss, alternativa(N, _), D, _), Alts),
    length(Alts, 2),
    decide(Ss, alternativa(2, _), _, E2), !,
    member(porque(todas, advertencia, T, _), E2),
    sub_string(T, _, _, _, "FEFO").

test(el_lote_que_caduca_antes_no_sirve_para_tratamiento_largo) :-
    evaluar_lote(loratadina_10, 45, l_lora_a, 230, no(caduca_antes_de_terminar(230, 245))).

test(con_tratamientos_cortos_gana_quien_llego_primero) :-
    sols_de(s33, Ss), decide(Ss, alternativa(1, _), D, _), !,
    memberchk(r(s33, surtir(1), [l_lora_a-1], _, _), D).

test(se_explica_por_que_no_conviene_lo_obvio) :-
    sols_de(s31, Ss), decide(Ss, _, E), !,
    memberchk(porque(s31, contraintuitivo, _, _), E).

:- end_tests(s3_ultimo_blister).

% =========================================================== Situación 4
:- begin_tests(s4_lote_retirado).

test(a_quien_avisar_por_la_cadena_lote_venta_receta) :-
    findall(P-M, aviso_retiro(l_omep_a, P, M, _), Ps),
    msort(Ps, [ana-telefono(_), carmen-via_medico(dr_soto), pedro-telefono(_)]).

test(ventas_sin_rastro_se_marcan_como_no_se_sabe) :-
    findall(V, situacion(V, venta_sin_rastro, _), Vs),
    msort(Vs, [v403, v404]).

test(unidades_que_hay_que_sacar_del_estante) :-
    retiro(l_omep_a, retiro(_, 198, _, _, estante(e2, 5), _, [])).

test(devolucion_sin_lote_no_regresa_al_inventario, [nondet]) :-
    destino_devolucion(d1, cuarentena, Dep, _),
    sub_string(Dep, _, _, _, "l_omep_a").

test(devolucion_de_lote_sano_y_cerrada_regresa) :-
    destino_devolucion(d2, regresa_al_inventario, _, _).

test(devolucion_abierta_es_merma) :-
    destino_devolucion(d3, merma, _, _).

test(un_lote_retirado_nunca_se_surte) :-
    \+ evaluar_lote(omeprazol_20, 0, l_omep_a, _, si).

:- end_tests(s4_lote_retirado).

% =========================================================== Situación 5
:- begin_tests(s5_alergia_e_interaccion).

test(alergia_por_principio_activo_con_otro_nombre_comercial) :-
    veredicto_de(s51, s51, rechazar([sin_alergia])),
    \+ alergia(ana, amoxil_500),                    % el dato NO dice «Amoxil»: se deduce
    alergia_a(ana, amoxil_500, si, _).

test(interaccion_con_lo_recibido_en_la_otra_sucursal) :-
    sols_de(s52, Ss), decide(Ss, [r(s52, rechazar([sin_interaccion]), [], _, Av)], _), !,
    memberchk(avisar(medico(dra_ruiz), interaccion(warfarina_5)), Av).

test(sin_ficha_es_no_se_sabe_nunca_sin_alergias) :-
    alergia_a(pedro, azitromicina_500, no_se, _),
    \+ alergia_a(pedro, azitromicina_500, no, _),
    veredicto_de(s53, s53, suspender([sin_alergia])).

test(capturada_la_ficha_cambia_la_decision) :-
    decide_escenario(s53, ficha_pedro_sin, _, [r(s53, surtir(1), _, _, _)], _), !,
    decide_escenario(s53, ficha_pedro_azitro, _, [r(s53, rechazar([sin_alergia]), _, _, _)], _), !.

:- end_tests(s5_alergia_e_interaccion).

% =========================================================== Las cinco preguntas (criterio 6)
:- begin_tests(cinco_preguntas_mismas_reglas).

test(decision) :-
    sols_de(s12, Ss), decide(Ss, [r(s12, surtir(1), _, _, _)], _), !.

test(explicacion_del_controlado, [nondet]) :-
    sols_de(s11, Ss), decide(Ss, _, E), !,
    member(porque(s11, bloqueo, T, _), E),
    sub_string(T, _, _, _, "ESPECIAL").

test(todas_las_respuestas_lotes_vencidos_retirados_o_por_caducar) :-
    findall(L-S, ( situacion(L, lote(S), _), memberchk(S, [vencido, retirado, por_caducar]) ), Ls),
    msort(Ls, [l_amox_a-por_caducar, l_lora_a-por_caducar, l_omep_a-retirado, l_para_a-vencido]).

test(pregunta_al_reves_que_le_falta_a_la_receta) :-
    que_falta_receta(r103, F),
    memberchk(falta(sin_uso_previo, no_se, _), F).

test(hipotesis_si_retiran_el_lote_que_caduca_primero) :-
    decide_escenario(s31, retiran_lora_a, alternativa(1, _), D, _), !,
    memberchk(r(s31, surtir(1), [l_lora_b-1], _, _), D),
    memberchk(r(s32, surtir(1), [l_lora_b-1], _, _), D),
    lote_retirado(l_omep_a, _), \+ lote_retirado(l_lora_a, _).   % la hipótesis se deshizo

test(situacion_en_cualquier_direccion) :-
    situacion(r103, S, _), S = receta_dudosa(_), !,
    situacion(E, receta_dudosa(_), _), E == r103, !.

test(nunca_falla_en_silencio) :-
    decide([sol(z, m1, anonimo, ninguna, paracetamol_500, 100, 1, 600)], D, _), !,
    D = [r(z, surtir_parcial(40, 100), _, _, _)].

:- end_tests(cinco_preguntas_mismas_reglas).
