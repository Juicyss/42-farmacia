-module(p42_farmacia_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% Arbol de supervision (one_for_one):
%%
%%   p42_farmacia_sup (one_for_one)
%%   ├── p42_bitacora      eventos + suscriptores SSE
%%   ├── p42_farmacia_server  ping/estado (del esqueleto del profe)
%%   ├── p42_inventario    UNICO escritor del inventario (serializa surtidos => no hay sobreventa)
%%   ├── p42_recetas_sup   simple_one_for_one: un gen_statem p42_receta por receta
%%   └── p42_revisor       revisor periodico de caducidades/quiebres (independiente)
%%
%% Las tablas ETS se crean AQUI, asi que su duenio es el supervisor y no el
%% worker: si matamos p42_inventario o una receta, los datos sobreviven y el
%% proceso reiniciado retoma el estado. Por eso one_for_one basta: los hijos
%% no comparten estado en memoria, solo en ETS.
init([]) ->
  ok = p42_db:init(),
  Intervalo = application:get_env(p42_farmacia, intervalo_revisor_ms, 30000),
  Children = [
    worker(p42_bitacora, []),
    worker(p42_farmacia_server, []),
    worker(p42_inventario, []),
    #{id => p42_recetas_sup,
      start => {p42_recetas_sup, start_link, []},
      restart => permanent,
      shutdown => infinity,
      type => supervisor},
    worker(p42_revisor, [Intervalo])
  ],
  {ok, {#{strategy => one_for_one, intensity => 10, period => 60}, Children}}.

worker(Mod, Args) ->
  #{id => Mod,
    start => {Mod, start_link, Args},
    restart => permanent,
    shutdown => 5000,
    type => worker}.
