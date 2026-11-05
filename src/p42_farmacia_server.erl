-module(p42_farmacia_server).
-behaviour(gen_server).

-export([start_link/0, ping/0, state/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

ping() ->
  gen_server:call(?MODULE, ping).

state() ->
  gen_server:call(?MODULE, state).

%% Estado como mapa para poder agregar campos del dominio sin romper los callbacks.
init([]) ->
  logger:info("~s iniciado", [?MODULE], #{proyecto => p42_farmacia}),
  {ok, #{iniciado_en => erlang:system_time(second)}}.

handle_call(ping, _From, State) ->
  {reply, pong, State};
handle_call(state, _From, State) ->
  {reply, State, State}.

handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.
