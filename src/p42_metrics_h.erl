-module(p42_metrics_h).
-export([init/2]).

init(Req0, St) ->
  Req = cowboy_req:reply(200, #{<<"content-type">> => <<"text/plain; version=0.0.4">>},
                         p42_metricas:texto(), Req0),
  {ok, Req, St}.
