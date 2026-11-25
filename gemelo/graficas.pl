/*  graficas.pl — Prolog deduce los datos y le pide a Python (matplotlib) que los dibuje.

    Prolog es el programa: decide QUÉ lotes, en qué estado y con qué cifras; Python
    solo recibe listas y devuelve un PNG. Ninguna regla del dominio vive en Python.

    Dos caminos, el mismo resultado:
      * Con Janus (Linux/WSL/EC2 con SWI-Prolog de la PPA, o Docker):
            py_call(graficas:caducidades(Lotes, Dias, ...), _)      ← mismo proceso
      * Sin Janus (SWI-Prolog para Windows instalado sin el componente janus):
            Prolog escribe los argumentos en JSON y ejecuta  python graficas.py …
    modo_python/1 dice cuál se está usando.
*/
:- encoding(utf8).
:- use_module(library(process)).
:- if(exists_source(library(json))).        % SWI-Prolog ≥ 9.3
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(filesex)).
:- use_module(library(pairs)).

:- dynamic dir_gemelo/1.
:- prolog_load_context(directory, D), retractall(dir_gemelo(_)), assertz(dir_gemelo(D)).

salida(Nombre, Ruta) :-
    dir_gemelo(D), directory_file_path(D, salida, S),
    make_directory_path(S), directory_file_path(S, Nombre, Ruta).

% ------------------------------------------------------------ puente a Python
:- if(exists_source(library(janus))).

:- use_module(library(janus)).
:- dir_gemelo(D), py_add_lib_dir(D).          % para que Python encuentre graficas.py
modo_python(janus).
llamar_python(Funcion, Args) :-
    G =.. [Funcion|Args],
    py_call(graficas:G, _).

:- else.

modo_python(proceso).
llamar_python(Funcion, Args) :-
    dir_gemelo(D), directory_file_path(D, 'graficas.py', Script),
    tmp_file_stream(text, Json, S0),
    set_stream(S0, encoding(utf8)),
    json_write_dict(S0, _{args: Args}), close(S0),
    python(Py),
    process_create(Py, [Script, Funcion, Json],
                   [stdout(null), stderr(pipe(Err)), process(Pid)]),
    read_string(Err, _, Msg), close(Err),
    process_wait(Pid, Estado),
    catch(delete_file(Json), _, true),
    (   Estado == exit(0) -> true
    ;   throw(error(python_fallo(Funcion, Msg), _))
    ).

python(Py) :-
    (   getenv('PYTHON', P) -> Py = P
    ;   ( current_prolog_flag(windows, true) -> Ext = [exe] ; Ext = [''] ),
        member(N, [python3, python]),
        % access(exist): en Windows python.exe suele ser un alias de la Microsoft Store
        absolute_file_name(path(N), Py, [access(exist), extensions(Ext), file_errors(fail)])
    ->  true
    ).

:- endif.

python_disponible :- catch(( modo_python(janus) -> true ; python(_) ), _, fail).

% ------------------------------------------------------------ gráficas

%! grafica_caducidades(-Archivo) is det.
%  Días restantes por lote, coloreados por el estado que DEDUCE estado_lote/3.
grafica_caducidades(Archivo) :-
    findall(Cad-f(L, D, U, E),
            ( lote(L, _, Cad, _), estado_lote(L, E, _), dias_restantes(L, D),
              ( existencia(L, U) -> true ; U = 0 ) ), P0),
    keysort(P0, P1), pairs_values(P1, Fs),
    findall(L, member(f(L,_,_,_), Fs), Ls),
    findall(D, member(f(_,D,_,_), Fs), Ds),
    findall(U, member(f(_,_,U,_), Fs), Us),
    findall(E, member(f(_,_,_,E), Fs), Es),
    dias_caducidad_cercana(Umbral),
    salida('caducidades.png', Archivo),
    llamar_python(caducidades, [Ls, Ds, Us, Es, Umbral, Archivo]).

%! grafica_recetas(-Archivo) is det.
grafica_recetas(Archivo) :-
    findall(R-s(S, P, E),
            ( receta(R, _, _, _, _, C), surtido_total(R, S), P is max(0, C - S),
              estado_receta(R, E0, _), functor(E0, E, _) ), Rs),
    pairs_keys_values(Rs, Ids, Vs),
    findall(S, member(s(S,_,_), Vs), Ss),
    findall(P, member(s(_,P,_), Vs), Ps),
    findall(E, member(s(_,_,E), Vs), Es),
    salida('recetas.png', Archivo),
    llamar_python(recetas, [Ids, Ss, Ps, Es, Archivo]).

%! grafica_retiro(+Lote, -Archivo) is semidet.
%  Cadena lote → venta → paciente: avisables, sin rastro y lo que sigue en estante.
grafica_retiro(Lote, Archivo) :-
    retiro(Lote, retiro(_, _, Avisar, SinRastro, estante(_, EnEstante), _, _)),
    aggregate_all(sum(U), ( member(aviso(P, Medio, _), Avisar), Medio \= no_localizable,
                            venta(_, Lote, U, P, _, _, _) ), Loc),
    aggregate_all(sum(U), member(sin_rastro(_, U, _, _), SinRastro), Sin),
    format(string(T), "Lote ~w: ¿dónde están sus unidades?", [Lote]),
    salida('retiro.png', Archivo),
    llamar_python(retiro, [["Vendidas · paciente localizable", "Vendidas · NO SE SABE a quién", "En estante · sacar hoy"],
                           [Loc, Sin, EnEstante],
                           ["#0f6e5c", "#ba1a1a", "#006398"], T, Archivo]).
