-module(p42_web).
-export([start/0, stop/0]).

start() ->
  Puerto = application:get_env(p42_farmacia, puerto, 8080),
  Dispatch = cowboy_router:compile([{'_', [
    {"/", cowboy_static, {priv_file, p42_farmacia, "www/index.html"}},
    {"/static/[...]", cowboy_static, {priv_dir, p42_farmacia, "www"}},
    {"/api/eventos", p42_sse_h, []},
    {"/metrics", p42_metrics_h, []},
    {"/api/[...]", p42_api_h, []}
  ]}]),
  {ok, _} = cowboy:start_clear(p42_http, [{port, Puerto}], #{env => #{dispatch => Dispatch}}),
  logger:info("p42_farmacia escuchando en http://0.0.0.0:~p", [Puerto]),
  ok.

stop() ->
  cowboy:stop_listener(p42_http).
