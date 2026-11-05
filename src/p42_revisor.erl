-module(p42_revisor).
-behaviour(gen_server).
%% Revisor periodico e independiente: cada N ms cuenta lotes proximos a
%% caducar, caducados con existencia y productos en quiebre/reorden; actualiza
%% metricas y avisa a la bitacora solo cuando algo cambia.

-export([start_link/1, revisar_ahora/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

start_link(IntervaloMs) ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, IntervaloMs, []).

revisar_ahora() ->
  gen_server:call(?MODULE, revisar).

init(IntervaloMs) ->
  erlang:send_after(1000, self(), tick),
  {ok, #{intervalo => IntervaloMs, ultimo => #{}}}.

handle_call(revisar, _From, S) ->
  {Rep, S2} = revisar(S),
  {reply, Rep, S2}.

handle_cast(_Msg, S) ->
  {noreply, S}.

handle_info(tick, S = #{intervalo := I}) ->
  {_, S2} = revisar(S),
  erlang:send_after(I, self(), tick),
  {noreply, S2};
handle_info(_Info, S) ->
  {noreply, S}.

revisar(S = #{ultimo := Ultimo}) ->
  Dias = application:get_env(p42_farmacia, dias_alerta_caducidad, 90),
  Rep = #{lotes_proximos_caducar => length(p42_inventario:caducidades(Dias)),
          lotes_caducados_con_existencia => length(p42_inventario:caducados()),
          productos_criticos => length(p42_inventario:criticos())},
  maps:foreach(fun(K, V) -> p42_metricas:set(K, V) end, Rep),
  case Rep =:= Ultimo of
    true -> ok;
    false ->
      p42_bitacora:registrar(alerta,
        "revisor: ~p lotes caducan en <=~p dias, ~p caducados por retirar, ~p productos en reorden",
        [maps:get(lotes_proximos_caducar, Rep), Dias,
         maps:get(lotes_caducados_con_existencia, Rep),
         maps:get(productos_criticos, Rep)])
  end,
  {Rep, S#{ultimo := Rep}}.
