-module(p42_recetas_sup).
-behaviour(supervisor).
%% Un proceso gen_statem por receta. transient: si una receta muere de forma
%% anormal se reinicia y recupera su estado desde ETS; si termina normal, no.

-export([start_link/0, nueva/1, reiniciar_todo/0]).
-export([init/1]).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

nueva(Datos) ->
  supervisor:start_child(?MODULE, [Datos]).

reiniciar_todo() ->
  [supervisor:terminate_child(?MODULE, P) || {_, P, _, _} <- supervisor:which_children(?MODULE), is_pid(P)],
  ok.

init([]) ->
  Hijo = #{id => p42_receta,
           start => {p42_receta, start_link, []},
           restart => transient,
           shutdown => 2000,
           type => worker},
  {ok, {#{strategy => simple_one_for_one, intensity => 50, period => 10}, [Hijo]}}.
