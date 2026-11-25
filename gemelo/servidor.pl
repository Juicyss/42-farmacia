/*  servidor.pl — Servidor web del gemelo digital (SWI-Prolog, library(http))

    Uso:   swipl servidor.pl            → http://localhost:8042/
           swipl servidor.pl 9000       → otro puerto

    La página (web/) SOLO pregunta y muestra: toda decisión, umbral y explicación
    sale de reglas.pl. Las gráficas las deduce Prolog y las dibuja Python (graficas.pl).

    | Ruta                          | Responde                                                  |
    |-------------------------------|-----------------------------------------------------------|
    | /                             | la interfaz (web/index.html)                              |
    | /api/estado                   | «ahora», indicadores, sucursales, hipótesis disponibles   |
    | /api/existencias              | existencias por lote con su estado deducido               |
    | /api/recetas                  | lo prescrito, lo surtido, estado y «qué falta»            |
    | /api/escenarios               | las cinco situaciones como solicitudes de mostrador      |
    | /api/decide?escenario=&hipotesis=&alternativa= | decisión + explicación + qué falta       |
    | /api/retiro?lote=             | a quién avisar, ventas sin rastro, devoluciones           |
    | /api/situaciones?entidad=&tipo= | situaciones deducidas en cualquier dirección           |
    | /grafica/caducidades | /grafica/recetas | /grafica/retiro?lote=  | PNG (Prolog → Python)  |
*/
:- encoding(utf8).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_header)).

:- ensure_loaded(gemelo).
:- ensure_loaded(graficas).

:- initialization(main, main).

:- dynamic dir_web/1.
:- prolog_load_context(directory, D), directory_file_path(D, web, W),
   retractall(dir_web(_)), assertz(dir_web(W)).

:- http_handler(root(.),                 servir_web,      [prefix]).
:- http_handler(root(api/estado),        api_estado,      []).
:- http_handler(root(api/existencias),   api_existencias, []).
:- http_handler(root(api/recetas),       api_recetas,     []).
:- http_handler(root(api/escenarios),    api_escenarios,  []).
:- http_handler(root(api/decide),        api_decide,      []).
:- http_handler(root(api/retiro),        api_retiro,      []).
:- http_handler(root(api/situaciones),   api_situaciones, []).
:- http_handler(root(grafica/caducidades), g_caducidades, []).
:- http_handler(root(grafica/recetas),     g_recetas,     []).
:- http_handler(root(grafica/retiro),      g_retiro,      []).

main(Argv) :-
    (   Argv = [A|_], atom_number(A, Puerto) -> true ; Puerto = 8042 ),
    http_server(http_dispatch, [port(Puerto)]),
    modo_python(M),
    format("Gemelo digital de la Farmacia #42 en http://localhost:~w/  (Python vía ~w)~n", [Puerto, M]),
    thread_get_message(_).

% Las hipótesis agregan y quitan hechos temporalmente: una petición a la vez.
seguro(G) :- with_mutex(gemelo, G).

servir_web(Req) :-
    dir_web(W),
    (   http_reply_from_files(W, [indexes(['index.html'])], Req) -> true
    ;   http_404([], Req)
    ).

% ------------------------------------------------------------ utilidades JSON
txt(T, S) :- ( string(T) -> S = T ; atom(T) -> atom_string(T, S)
             ; copy_term(T, T2), numbervars(T2, 0, _, [singletons(true)]),   % variables → _
               format(string(S), "~W", [T2, [quoted(true), numbervars(true), spacing(next_argument)]]) ).

hechos_json(Hs, Ss) :- maplist(txt, Hs, Ss).

param_atom(Req, Nombre, Defecto, Valor) :-
    P =.. [Nombre, Valor, [default(Defecto), atom]],
    http_parameters(Req, [P]).

% ------------------------------------------------------------ /api/estado
api_estado(_) :- seguro(estado_json(J)), reply_json_dict(J).

estado_json(_{ahora: H, caducidad_cercana: C, vigencia_receta: V, ventana_interaccion: W,
              python: Py, indicadores: K, sucursales: Ss, hipotesis: Hs}) :-
    ahora(H), dias_caducidad_cercana(C), vigencia_receta(V), ventana_interaccion(W),
    ( python_disponible -> modo_python(M), atom_string(M, Py) ; Py = "no disponible" ),
    contar(lote(vencido), Ve), contar(lote(retirado), Re), contar(lote(por_caducar), Pc),
    contar(lote(agotado), Ag),
    aggregate_all(count, situacion(_, receta_abierta(_), _), Ab),
    aggregate_all(count, situacion(_, receta_dudosa(_), _), Du),
    aggregate_all(count, situacion(_, venta_sin_rastro, _), Sr),
    K = _{vencidos: Ve, retirados: Re, por_caducar: Pc, agotados: Ag,
          recetas_abiertas: Ab, recetas_dudosas: Du, ventas_sin_rastro: Sr},
    findall(_{id: S, nombre: N, ultimo_reporte: U, sin_reporte: B, mostradores: Ms},
            ( sucursal(S, N), reporte_sucursal(S, U),
              ( sucursal_sin_reporte(S, _) -> B = true ; B = false ),
              findall(M0, mostrador(M0, S), Ms) ), Ss),
    findall(_{id: I, pregunta: Q}, hipotesis_predefinida(I, Q, _), Hs).

contar(S, N) :- aggregate_all(count, situacion(_, S, _), N).

% ------------------------------------------------------------ /api/existencias
api_existencias(_) :- seguro(findall(J, lote_json(J), Js)), reply_json_dict(Js).

lote_json(_{lote: L, medicamento: Med, nombre: N, principio: PA, requisito: Req,
            caducidad: Cad, dias: D, estante: Est, unidades: U, estado: E, evidencia: Ev}) :-
    lote(L, Med, Cad, Est), medicamento(Med, PA, Req), nombre_med(Med, N),
    ( existencia(L, U) -> true ; U = 0 ),
    dias_restantes(L, D), estado_lote(L, E, Ev0), hechos_json(Ev0, Ev).

% ------------------------------------------------------------ /api/recetas
api_recetas(_) :- seguro(findall(J, receta_json(J), Js)), reply_json_dict(Js).

receta_json(_{receta: R, paciente: P, medico: NM, tipo: T, medicamento: Med, nombre: N,
              prescrito: C, surtido: S, pendiente: Pe, estado: E, motivos: Ms,
              historial: Hs, faltas: Fs}) :-
    receta(R, P, M, T, Med, C), nombre_med(Med, N), nombre_medico(M, NM),
    surtido_total(R, S), pendiente(R, Pe),
    estado_receta(R, E0, _),
    ( E0 = invalida(Ns) -> E = invalida, Ms = Ns
    ; E0 = dudosa(Ns)   -> E = dudosa,   Ms = Ns
    ; E = valida, Ms = [] ),
    findall(_{dia: D, evento: Ev, sucursal: Su},
            ( evento_receta(R, Ev0, Su, D), txt(Ev0, Ev) ), Hs0),
    sort(dia, @=<, Hs0, Hs),
    que_falta_receta(R, F0), maplist(falta_json, F0, Fs).

falta_json(falta(C, V, A), _{condicion: C, valor: V, accion: S}) :- txt(A, S).

% ------------------------------------------------------------ /api/escenarios
api_escenarios(_) :- findall(J, escenario_json(J), Js), reply_json_dict(Js).

escenario_json(_{id: I, situacion: S, titulo: T, descripcion: D, tipo: Tipo,
                 solicitudes: Ss, lote: Lote, hipotesis: Hs}) :-
    escenario(I, S, T, D, Sols, HIds),
    (   Sols = retiro(Lote) -> Tipo = retiro, Ss = []
    ;   Tipo = decision, Lote = null, maplist(sol_json, Sols, Ss) ),
    findall(_{id: H, pregunta: Q}, ( member(H, HIds), hipotesis_predefinida(H, Q, _) ), Hs).

sol_json(sol(Id, Mo, Pac, R, Med, Cant, Dias, Inst),
         _{id: Id, mostrador: Mo, paciente: NP, receta: R, medicamento: Med, nombre: N,
           cantidad: Cant, dias: Dias, hora: Hora}) :-
    nombre_med(Med, N), nombre_persona(Pac, NP),
    Hh is Inst // 60, Mm is Inst mod 60, format(string(Hora), "~|~`0t~d~2+:~|~`0t~d~2+", [Hh, Mm]).

% ------------------------------------------------------------ /api/decide
api_decide(Req) :-
    http_parameters(Req, [ escenario(Esc, [atom]),
                           hipotesis(Hip, [atom, default(ninguna)]),
                           alternativa(N, [integer, default(1)]) ]),
    (   seguro(decision_json(Esc, Hip, N, J))
    ->  reply_json_dict(J)
    ;   reply_json_dict(_{error: "Escenario, hipótesis o alternativa inexistente"}, [status(404)])
    ).

decision_json(Esc, Hip, N, _{escenario: E, hipotesis: HJ, alternativa: N, total: Total,
                             resultados: Rs, explicacion: Xs, faltas: Fs}) :-
    escenario(Esc, _, _, _, Sols, _), is_list(Sols),
    escenario_json(E), get_dict(id, E, Esc), !,
    (   Hip == ninguna -> HJ = null, Cambios = []
    ;   hipotesis_predefinida(Hip, Q, Cambios), maplist(txt, Cambios, CS),
        HJ = _{id: Hip, pregunta: Q, cambios: CS} ),
    hipotesis(Cambios, analisis(Sols, alternativa(N, Total), Dec, Exp, Faltas)),
    maplist(resultado_json, Dec, Rs),
    maplist(porque_json, Exp, Xs),
    dict_pairs(Fs, _, Faltas).

analisis(Sols, Alt, Dec, Exp, Faltas) :-
    decide(Sols, Alt, Dec, Exp),
    findall(Id-FJ, ( member(Sol, Sols), arg(1, Sol, Id),
                     que_falta(Sol, F0), maplist(falta_json, F0, FJ) ), Faltas).

resultado_json(r(Id, Ver, Ent, Acc, Av),
               _{id: Id, veredicto: V, unidades: K, objetivo: Obj, motivos: Ms,
                 entregas: Es, acciones: As, avisos: AvS}) :-
    (   Ver = surtir(K)               -> V = surtir, Obj = K, Ms = []
    ;   Ver = surtir_parcial(K, Obj)  -> V = surtir_parcial, Ms = []
    ;   Ver = rechazar(Ns)            -> V = rechazar, K = 0, Obj = null, maplist(motivo_json, Ns, Ms)
    ;   Ver = suspender(Ns)           -> V = suspender, K = 0, Obj = null, maplist(motivo_json, Ns, Ms)
    ),
    findall(_{lote: L, unidades: U, caducidad: Cad, estante: Est},
            ( member(L-U, Ent), lote(L, _, Cad, Est) ), Es),
    maplist(texto_accion, Acc, As),
    maplist(texto_aviso, Av, AvS).

motivo_json(N, _{condicion: N, texto: T}) :- etiqueta(N, A), atom_string(A, T).

porque_json(porque(Id, Tipo, Texto, Hs), _{solicitud: Id, tipo: Tipo, texto: S, hechos: HS}) :-
    txt(Texto, S), hechos_json(Hs, HS).

texto_accion(registrar_venta(K), S)            :- format(string(S), "Registrar la venta (~w u).", [K]).
texto_accion(registrar_venta_con_receta(K), S) :- format(string(S), "Registrar la venta (~w u) ligada a la receta.", [K]).
texto_accion(registrar_salida(K), S)           :- format(string(S), "Registrar la salida de ~w u del anaquel bajo llave.", [K]).
texto_accion(registrar_surtido(K), S)          :- format(string(S), "Registrar el surtido de ~w u en la receta.", [K]).
texto_accion(retener_receta, "Retener la receta (queda en la farmacia).").
texto_accion(asentar_libro_control(F), S)      :- format(string(S), "Asentar en el libro de control (folio ~w).", [F]).
texto_accion(sellar_receta(K, D), S)           :- format(string(S), "Sellar la receta: ~w u surtidas el día ~w.", [K, D]).
texto_accion(registrar_bitacora_antibioticos, "Registrar en la bitácora de antibióticos.").
texto_accion(devolver_al_paciente(falta(F)), S) :- format(string(S), "Devolver la receta sellada al paciente (le faltan ~w u).", [F]).
texto_accion(devolver_al_paciente(resurtible), "Devolver la receta al paciente (resurtible según el médico).").
texto_accion(devolver_receta_sin_surtir, "Devolver la receta sin surtir.").
texto_accion(A, S) :- txt(A, S).

texto_aviso(avisar(medico(M), alergia(PA)), S) :-
    nombre_medico(M, N), format(string(S), "Consultar a ~w: el paciente es alérgico a ~w.", [N, PA]), !.
texto_aviso(avisar(medico(M), interaccion(M2)), S) :-
    nombre_medico(M, N), nombre_med(M2, N2),
    format(string(S), "Consultar a ~w: interacción con ~w que ya recibió.", [N, N2]), !.
texto_aviso(avisar(sucursal(Su), confirmar_folio), S) :-
    nombre_suc(Su, N), format(string(S), "Llamar a ~w para confirmar si el folio ya se surtió.", [N]), !.
texto_aviso(avisar(responsable_sanitario, receta_ya_surtida(Su, D)), S) :-
    nombre_suc(Su, N),
    format(string(S), "Avisar al responsable sanitario: intento de surtir una receta especial ya surtida en ~w (día ~w).", [N, D]), !.
texto_aviso(avisar(paciente(P), capturar_ficha_alergias), S) :-
    nombre_persona(P, N), format(string(S), "Capturar con ~w su ficha de alergias.", [N]), !.
texto_aviso(A, S) :- txt(A, S).

% ------------------------------------------------------------ /api/retiro
api_retiro(Req) :-
    param_atom(Req, lote, l_omep_a, Lote),
    (   seguro(retiro_json(Lote, J)) -> reply_json_dict(J)
    ;   reply_json_dict(_{error: "Ese lote no está retirado"}, [status(404)])
    ).

retiro_json(Lote, _{lote: Lote, medicamento: NMed, dia_retiro: DR, alerta: Al,
                    avisar: As, sin_rastro: Ss, estante: _{estante: Est, unidades: EU},
                    devoluciones: Ds, incidentes: Is, retirados: Rets}) :-
    retiro(Lote, retiro(_, DR, Avisar, SinRastro, estante(Est, EU), _Devs, Inc)),
    lote(Lote, Med, _, _), nombre_med(Med, NMed),
    ( alerta_sanitaria(_, Lote, _, Mot) -> atom_string(Mot, Al) ; Al = null ),
    findall(_{paciente: NP, medio: Medio, detalle: Det, unidades: U, venta: V, sucursal: Su, dia: D, cadena: Cad},
            ( member(aviso(P, Med0, Cad0), Avisar), nombre_persona(P, NP),
              memberchk(venta(V, _, U, _, _, Su, D), Cad0),
              medio_json(Med0, Medio, Det), hechos_json(Cad0, Cad) ), As),
    findall(_{venta: V, unidades: U, sucursal: Su, dia: D, a_quien: "no se sabe"},
            member(sin_rastro(V, U, Su, D), SinRastro), Ss),
    findall(_{devolucion: Dv, medicamento: M2, lote: L2, empaque: Em, destino: De, depende: Dep},
            ( devolucion(Dv, M2, L2, Em, _), destino_devolucion(Dv, De, Dep0, _), txt(Dep0, Dep) ), Ds),
    findall(_{venta: V, sucursal: Su, dia: D}, member(venta_posterior(V, Su, D), Inc), Is),
    findall(L, lote_retirado(L, _), Rets).

medio_json(telefono(T), "teléfono", T).
medio_json(via_medico(M), "vía su médico", N) :- nombre_medico(M, N).
medio_json(no_localizable, "no localizable", "sin contacto ni receta").

% ------------------------------------------------------------ /api/situaciones
api_situaciones(Req) :-
    http_parameters(Req, [ entidad(E0, [atom, default('')]), tipo(T0, [atom, default('')]) ]),
    seguro(findall(_{entidad: E, situacion: S, evidencia: Ev},
                   ( ( E0 == '' -> true ; E = E0 ),
                     situacion(E, S0, Ev0),
                     ( T0 == '' -> true ; functor(S0, T0, _) ),
                     txt(S0, S), hechos_json(Ev0, Ev) ), Js)),
    reply_json_dict(Js).

% ------------------------------------------------------------ gráficas (Prolog → Python)
g_caducidades(Req) :- grafica(grafica_caducidades(F), F, Req).
g_recetas(Req)     :- grafica(grafica_recetas(F), F, Req).
g_retiro(Req)      :- param_atom(Req, lote, l_omep_a, L), grafica(grafica_retiro(L, F), F, Req).

grafica(Meta, Archivo, Req) :-
    (   catch(seguro(Meta), E, ( print_message(warning, E), fail ))
    ->  http_reply_file(Archivo, [unsafe(true), cache(false)], Req)
    ;   reply_json_dict(_{error: "No se pudo dibujar: ¿Python con matplotlib instalado?"}, [status(503)])
    ).
