-module(p42_bitacora).
-behaviour(gen_server).
%% Bitacora de eventos y alertas. Empuja cada evento a los suscriptores
%% (conexiones SSE del navegador) para el tablero en tiempo real.

-export([start_link/0, registrar/3, listar/0, suscribir/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(MAX, 300).

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Nivel: ok | alerta | falla
registrar(Nivel, Fmt, Args) ->
  Texto = iolist_to_binary(io_lib:format(Fmt, Args)),
  gen_server:cast(?MODULE, {evento, #{ts => p42_reloj:ahora_iso(),
                                      nivel => Nivel, texto => Texto}}).

listar() ->
  gen_server:call(?MODULE, listar).

suscribir(Pid) ->
  gen_server:cast(?MODULE, {suscribir, Pid}).

init([]) ->
  {ok, #{eventos => [], subs => #{}}}.

handle_call(listar, _From, S = #{eventos := Ev}) ->
  {reply, Ev, S}.

handle_cast({evento, E = #{nivel := N, texto := T}}, S = #{eventos := Ev, subs := Subs}) ->
  case N of
    falla -> logger:warning("~ts", [T]);
    _ -> logger:info("~ts", [T])
  end,
  [P ! {evento, E} || P <- maps:keys(Subs)],
  {noreply, S#{eventos := lists:sublist([E | Ev], ?MAX)}};
handle_cast({suscribir, Pid}, S = #{subs := Subs}) ->
  Ref = erlang:monitor(process, Pid),
  {noreply, S#{subs := Subs#{Pid => Ref}}}.

handle_info({'DOWN', _Ref, process, Pid, _}, S = #{subs := Subs}) ->
  {noreply, S#{subs := maps:remove(Pid, Subs)}};
handle_info(_Info, S) ->
  {noreply, S}.
