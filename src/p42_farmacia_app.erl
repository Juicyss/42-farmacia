-module(p42_farmacia_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
  {ok, Sup} = p42_farmacia_sup:start_link(),
  case application:get_env(p42_farmacia, sembrar_al_iniciar, true) of
    true ->
      N = application:get_env(p42_farmacia, productos_iniciales, 1500),
      p42_seed:catalogo(N);
    false ->
      ok
  end,
  case application:get_env(p42_farmacia, web, true) of
    true -> ok = p42_web:start();
    false -> ok
  end,
  {ok, Sup}.

stop(_State) ->
  _ = (catch p42_web:stop()),
  ok.
