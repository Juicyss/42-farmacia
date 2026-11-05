-module(p42_sim).
%% Simulacion del escenario del problema:
%%  - 1,500 productos, 3 mostradores, 400 ventas al dia
%%  - un lote retirado por alerta sanitaria con 40 unidades ya vendidas
%%  - dos mostradores surtiendo el ultimo blister del lote que caduca primero
%%  + fallas inyectadas (kill al inventario y a una receta a media corrida)
%%  + receta de controlado usada en otra sucursal
-export([escenario/0, escenario/1]).

-define(ESPECIALES, [<<"OMEP20">>, <<"LORA10">>, <<"CLONA2">>, <<"TRAMA50">>, <<"AMOX500">>, <<"METF850">>]).

escenario() -> escenario(#{}).

escenario(Opts) ->
  NP = maps:get(productos, Opts, 1500),
  NV = maps:get(ventas, Opts, 400),
  T0 = erlang:monotonic_time(millisecond),
  reiniciar(),
  ok = p42_seed:catalogo(NP),
  p42_bitacora:registrar(ok, "SIMULACION: ~p productos, 3 mostradores, ~p ventas", [NP, NV]),

  %% 1) 40 ventas del lote que luego se retira (40 clientes distintos)
  Alerta = [p42_inventario:surtir(<<"OMEP20">>, 1,
              #{cliente => iolist_to_binary(io_lib:format("Cliente-OMEP-~2..0B", [I])), mostrador => 1})
            || I <- lists:seq(1, 40)],
  40 = length([ok || {ok, 1, [#{lote := <<"L-ALERTA-01">>}]} <- Alerta]),

  %% 2) 3 mostradores en paralelo con el resto de las ventas + fallas inyectadas
  Pool = pool(),
  Restantes = NV - 40,
  Yo = self(),
  Reparto = [Restantes div 3 + extra(M, Restantes rem 3) || M <- [1, 2, 3]],
  [spawn_link(fun() -> Yo ! {fin, M, mostrador(M, N, Pool)} end) || {M, N} <- lists:zip([1, 2, 3], Reparto)],
  Fallas = inyectar_fallas(),
  Stats = [receive {fin, M, St} -> St end || M <- [1, 2, 3]],
  Total = lists:foldl(fun(S, Acc) -> maps:merge_with(fun(_, A, B) -> A + B end, S, Acc) end, #{}, Stats),

  %% 3) alerta sanitaria: retirar lote y localizar clientes
  {ok, Afectados} = p42_inventario:retirar_lote(<<"L-ALERTA-01">>),
  {ok, 1, [#{lote := LoteDespues}]} = p42_inventario:surtir(<<"OMEP20">>, 1, #{cliente => <<"Post-retiro">>, mostrador => 2}),

  %% 4) dos mostradores, mismo instante, ultimo blister del lote que caduca primero
  [spawn(fun() -> Yo ! {blister, M, p42_inventario:surtir(<<"LORA10">>, 1, #{cliente => <<"Cliente-LORA">>, mostrador => M})} end)
   || M <- [2, 3]],
  Blister = [receive {blister, M, {ok, N, U}} -> #{mostrador => M, entregado => N, lotes => U} end || M <- [2, 3]],
  [{_, #{cantidad := LoraA}}] = ets:lookup(p42_lotes, <<"L-LORA-A">>),

  %% 5) caso dificil: receta de controlado ya usada en otra sucursal
  {ok, _} = p42_recetas:crear(#{paciente => <<"Paciente C">>, folio => <<"FOLIO-CTRL-001">>,
                                sucursal => <<"Otay">>, items => [#{sku => <<"CLONA2">>, cantidad => 1}]}),
  Reuso = p42_recetas:crear(#{paciente => <<"Paciente C">>, folio => <<"FOLIO-CTRL-001">>,
                              sucursal => <<"Centro">>, items => [#{sku => <<"CLONA2">>, cantidad => 1}]}),

  %% 6) prueba de caos: doble surtido de la misma receta
  Doble = p42_caos:doble_surtido(),

  _ = p42_revisor:revisar_ahora(),
  Ms = erlang:monotonic_time(millisecond) - T0,
  p42_bitacora:registrar(ok, "SIMULACION terminada en ~p ms", [Ms]),
  #{productos => ets:info(p42_productos, size),
    lotes => ets:info(p42_lotes, size),
    ventas_objetivo => NV,
    mostradores => maps:merge(Total, #{ventas_lote_alerta => 40}),
    fallas_inyectadas => Fallas,
    lote_retirado => #{lote => <<"L-ALERTA-01">>,
                       ventas_localizadas => length(Afectados),
                       clientes_unicos => length(lists:usort([C || #{cliente := C} <- Afectados])),
                       siguiente_venta_sale_de => LoteDespues},
    ultimo_blister => #{resultados => Blister, lote_a_queda => LoraA,
                        sobreventa => LoraA < 0},
    controlado_otra_sucursal => fmt(Reuso),
    doble_surtido => Doble,
    duracion_ms => Ms}.

%%% internas

reiniciar() ->
  ok = p42_recetas_sup:reiniciar_todo(),
  ok = p42_db:reset().

extra(M, R) when M =< R -> 1;
extra(_, _) -> 0.

pool() ->
  Todos = [{S, T} || {S, T} <- p42_inventario:skus(), not lists:member(S, ?ESPECIALES), T =/= controlado],
  Libres = list_to_tuple([S || {S, libre} <- Todos]),
  ConReceta = list_to_tuple([S || {S, T} <- Todos, T =/= libre]),
  {Libres, ConReceta}.

azar(T) -> element(rand:uniform(tuple_size(T)), T).

mostrador(M, N, {Libres, ConReceta}) ->
  rand:seed(exsss, {M, 42, 7}),
  lists:foldl(
    fun(I, Acc) ->
      Cliente = iolist_to_binary(io_lib:format("Cliente-~p-~p", [M, I])),
      R = case rand:uniform(100) =< 70 of
            true ->
              reintentar(fun() -> p42_inventario:surtir(azar(Libres), rand:uniform(3),
                                                        #{cliente => Cliente, mostrador => M}) end, 3);
            false ->
              case p42_recetas:crear(#{paciente => Cliente,
                                       items => [#{sku => azar(ConReceta), cantidad => rand:uniform(2)}]}) of
                {ok, Id} -> reintentar(fun() -> p42_receta:surtir(Id, M) end, 3);
                Err -> {Err, 0}
              end
          end,
      contar(R, Acc)
    end, #{ventas => 0, completas => 0, parciales => 0, rechazadas => 0, reintentos => 0},
    lists:seq(1, N)).

%% Si el inventario esta caido (lo matamos a proposito) el mostrador reintenta.
reintentar(F, N) -> reintentar(F, N, 0).
reintentar(F, N, Hechos) ->
  try F() of
    {error, inventario_no_disponible} when N > 0 -> timer:sleep(50), reintentar(F, N - 1, Hechos + 1);
    R -> {R, Hechos}
  catch exit:_ when N > 0 -> timer:sleep(50), reintentar(F, N - 1, Hechos + 1)
  end.

contar({R, Reint}, Acc0) ->
  Acc = maps:update_with(reintentos, fun(X) -> X + Reint end, Acc0#{ventas := maps:get(ventas, Acc0) + 1}),
  K = case R of
        {ok, #{estado := surtida}} -> completas;
        {ok, #{estado := surtida_parcial}} -> parciales;
        {ok, 0, _} -> rechazadas;
        {ok, _, _} -> completas;
        _ -> rechazadas
      end,
  maps:update_with(K, fun(X) -> X + 1 end, Acc).

inyectar_fallas() ->
  timer:sleep(5),
  Inv = whereis(p42_inventario),
  exit(Inv, kill),
  p42_bitacora:registrar(falla, "SIMULACION: falla inyectada, kill a p42_inventario ~p", [Inv]),
  timer:sleep(20),
  Recetas = [P || {_, P} <- ets:tab2list(p42_receta_pid), is_process_alive(P)],
  Rec = case Recetas of
          [P | _] -> exit(P, kill), pid_bin(P);
          [] -> null
        end,
  [#{proceso => p42_inventario, pid_muerto => pid_bin(Inv), pid_nuevo => pid_bin(whereis(p42_inventario))},
   #{proceso => receta, pid_muerto => Rec}].

fmt({ok, Id}) -> #{ok => Id};
fmt({error, E}) -> #{error => list_to_binary(io_lib:format("~p", [E]))}.

pid_bin(undefined) -> null;
pid_bin(P) -> list_to_binary(pid_to_list(P)).
