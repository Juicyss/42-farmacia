-module(p42_receta).
-behaviour(gen_statem).
%% Maquina de estados de una receta:
%%
%%   emitida ──surtir──> surtida_parcial ──surtir──> surtida
%%      │                     │
%%      └──── vigencia ───────┴──────────> vencida
%%
%% Al ser un proceso por receta, dos mostradores que intentan surtir la MISMA
%% receta al mismo tiempo quedan en fila en su buzon: el primero la surte y el
%% segundo la encuentra ya "surtida" y es rechazado.
%%
%% El estado se guarda en ETS en cada transicion: si el proceso muere, el
%% supervisor lo reinicia y continua donde iba.

-export([start_link/1, surtir/2, consultar/1, pid/1]).
-export([init/1, callback_mode/0, handle_event/4]).

start_link(Datos) ->
  gen_statem:start_link(?MODULE, Datos, []).

surtir(Id, Mostrador) -> llamar(Id, {surtir, Mostrador}, 2).

consultar(Id) -> llamar(Id, consultar, 2).

pid(Id) ->
  case ets:lookup(p42_receta_pid, Id) of
    [{_, P}] -> P;
    [] -> undefined
  end.

llamar(Id, Msg, Intentos) ->
  case pid(Id) of
    undefined ->
      {error, no_existe};
    Pid ->
      try
        gen_statem:call(Pid, Msg, 5000)
      catch
        %% la receta se estaba reiniciando; damos chance al supervisor
        exit:{noproc, _} when Intentos > 0 ->
          timer:sleep(100),
          llamar(Id, Msg, Intentos - 1);
        exit:{killed, _} when Intentos > 0 ->
          timer:sleep(100),
          llamar(Id, Msg, Intentos - 1)
      end
  end.

callback_mode() -> handle_event_function.

init(Datos = #{id := Id, expira := Expira}) ->
  ets:insert(p42_receta_pid, {Id, self()}),
  {Estado, D} =
    case ets:lookup(p42_recetas, Id) of
      [{_, D0, E0}] ->
        p42_bitacora:registrar(alerta, "receta ~ts reiniciada en ~p, retoma estado ~p", [Id, self(), E0]),
        {E0, D0};
      [] ->
        ets:insert(p42_recetas, {Id, Datos, emitida}),
        {emitida, Datos}
    end,
  Ms = max(0, (Expira - p42_reloj:ahora_s()) * 1000),
  {ok, Estado, D, [{{timeout, vigencia}, Ms, vencer}]}.

handle_event({call, From}, consultar, Estado, D) ->
  {keep_state_and_data, [{reply, From, D#{estado => Estado, pid => pid_bin(self())}}]};

handle_event({call, From}, {surtir, M}, Estado, D = #{id := Id})
    when Estado =:= emitida; Estado =:= surtida_parcial ->
  case surtir_items(D, M) of
    {_D2, [], Errores} ->
      p42_metricas:inc(recetas_rechazadas),
      Razon = case lists:member(inventario_no_disponible, Errores) of
                true -> inventario_no_disponible;
                false -> sin_existencias
              end,
      p42_bitacora:registrar(alerta, "receta ~ts sin surtir en mostrador ~p: ~p", [Id, M, Razon]),
      {keep_state_and_data, [{reply, From, {error, Razon}}]};
    {D2, Entregado, _} ->
      Nuevo = estado_de(D2),
      ets:insert(p42_recetas, {Id, D2, Nuevo}),
      case Nuevo of
        surtida -> p42_metricas:inc(recetas_surtidas);
        surtida_parcial -> p42_metricas:inc(recetas_surtidas_parcial)
      end,
      p42_bitacora:registrar(ok, "receta ~ts ~p en mostrador ~p", [Id, Nuevo, M]),
      {next_state, Nuevo, D2, [{reply, From, {ok, #{id => Id, estado => Nuevo, entregado => Entregado}}}]}
  end;

handle_event({call, From}, {surtir, M}, surtida, #{id := Id}) ->
  p42_metricas:inc(recetas_rechazadas),
  p42_bitacora:registrar(alerta, "receta ~ts YA SURTIDA: rechazado en mostrador ~p", [Id, M]),
  {keep_state_and_data, [{reply, From, {error, ya_surtida}}]};

handle_event({call, From}, {surtir, _M}, vencida, _D) ->
  p42_metricas:inc(recetas_rechazadas),
  {keep_state_and_data, [{reply, From, {error, vencida}}]};

handle_event({timeout, vigencia}, vencer, Estado, D = #{id := Id})
    when Estado =:= emitida; Estado =:= surtida_parcial ->
  ets:insert(p42_recetas, {Id, D, vencida}),
  p42_metricas:inc(recetas_vencidas),
  p42_bitacora:registrar(alerta, "receta ~ts vencio (estaba ~p)", [Id, Estado]),
  {next_state, vencida, D};

handle_event(_Tipo, _Evento, _Estado, _D) ->
  keep_state_and_data.

%%% internas

surtir_items(D = #{items := Items, paciente := P, id := Id}, M) ->
  Ctx = #{cliente => P, receta => Id, mostrador => M},
  {Items2, {Ent, Err}} =
    lists:mapfoldl(
      fun(I = #{sku := S, cantidad := C, surtido := Su, lotes := Ls}, {AccE, AccErr}) ->
          case C - Su of
            Pend when Pend > 0 ->
              case pedir(S, Pend, Ctx) of
                {ok, 0, _} -> {I, {AccE, [sin_existencias | AccErr]}};
                {ok, N, Usados} ->
                  {I#{surtido := Su + N, lotes := Ls ++ Usados},
                   {[#{sku => S, cantidad => N, lotes => Usados} | AccE], AccErr}};
                {error, R} -> {I, {AccE, [R | AccErr]}}
              end;
            _ ->
              {I, {AccE, AccErr}}
          end
      end, {[], []}, Items),
  {D#{items := Items2}, lists:reverse(Ent), Err}.

%% Si el inventario esta reiniciandose no tiramos la receta: reportamos el
%% error y el mostrador reintenta.
pedir(S, Pend, Ctx) ->
  try p42_inventario:surtir(S, Pend, Ctx)
  catch exit:_ -> {error, inventario_no_disponible}
  end.

estado_de(#{items := Is}) ->
  case lists:all(fun(#{cantidad := C, surtido := S}) -> S >= C end, Is) of
    true -> surtida;
    false -> surtida_parcial
  end.

pid_bin(P) -> list_to_binary(pid_to_list(P)).
