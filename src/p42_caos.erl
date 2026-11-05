-module(p42_caos).
%% Pruebas de caos: matar procesos y verificar que el sistema se recupera.
-export([matar/1, doble_surtido/0]).

%% Mata un proceso registrado y reporta que paso.
matar(<<"inventario">>) -> matar_registrado(p42_inventario);
matar(<<"revisor">>) -> matar_registrado(p42_revisor);
matar(<<"bitacora">>) -> matar_registrado(p42_bitacora);
matar(<<"receta">>) -> matar_receta();
matar(<<"doble_surtido">>) -> doble_surtido();
matar(Otro) -> #{error => <<"objetivo desconocido">>, objetivo => Otro}.

matar_registrado(Nombre) ->
  Antes = whereis(Nombre),
  UnidadesAntes = p42_inventario:unidades_totales(),
  exit(Antes, kill),
  timer:sleep(200),
  Despues = whereis(Nombre),
  p42_bitacora:registrar(falla, "CAOS: kill a ~p ~p -> nuevo pid ~p", [Nombre, Antes, Despues]),
  #{objetivo => Nombre,
    esperado => <<"el supervisor lo reinicia con otro pid y no se pierde inventario">>,
    pid_antes => pid_bin(Antes),
    pid_despues => pid_bin(Despues),
    reiniciado => is_pid(Despues) andalso Despues =/= Antes,
    unidades_antes => UnidadesAntes,
    unidades_despues => p42_inventario:unidades_totales()}.

matar_receta() ->
  {ok, Id} = p42_recetas:crear(#{paciente => <<"Paciente caos">>,
                                 items => [#{sku => <<"METF850">>, cantidad => 200}]}),
  {ok, #{estado := E1}} = p42_receta:surtir(Id, 1),
  Antes = p42_receta:pid(Id),
  exit(Antes, kill),
  timer:sleep(200),
  #{estado := E2, pid := Despues} = p42_receta:consultar(Id),
  #{objetivo => receta, receta => Id,
    esperado => <<"la receta reinicia y conserva su estado (surtida_parcial)">>,
    estado_antes => E1, estado_despues => E2,
    pid_antes => pid_bin(Antes), pid_despues => Despues}.

%% Prueba de caos del README: surtir en paralelo la misma receta dos veces,
%% la segunda debe rechazarse.
doble_surtido() ->
  {ok, Id} = p42_recetas:crear(#{paciente => <<"Paciente doble">>,
                                 items => [#{sku => <<"AMOX500">>, cantidad => 2}]}),
  Yo = self(),
  [spawn(fun() -> Yo ! {mostrador, M, p42_receta:surtir(Id, M)} end) || M <- [1, 2]],
  Res = [receive {mostrador, M, R} -> #{mostrador => M, resultado => fmt(R)} after 5000 -> timeout end
         || M <- [1, 2]],
  Oks = length([x || #{resultado := #{ok := _}} <- Res]),
  p42_bitacora:registrar(falla, "CAOS: doble surtido de ~ts en paralelo -> ~p exito(s)", [Id, Oks]),
  #{objetivo => doble_surtido, receta => Id,
    esperado => <<"exactamente 1 surtido exitoso; el otro rechazado ya_surtida">>,
    resultados => Res, exitosos => Oks, correcto => Oks =:= 1}.

fmt({ok, M}) -> #{ok => M};
fmt({error, E}) -> #{error => E}.

pid_bin(undefined) -> null;
pid_bin(P) -> list_to_binary(pid_to_list(P)).
