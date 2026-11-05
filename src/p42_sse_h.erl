-module(p42_sse_h).
%% Server-Sent Events: la bitacora empuja cada evento al navegador.
-export([init/2, info/3]).

init(Req0, St) ->
  Req = cowboy_req:stream_reply(200, #{<<"content-type">> => <<"text/event-stream">>,
                                       <<"cache-control">> => <<"no-cache">>}, Req0),
  p42_bitacora:suscribir(self()),
  erlang:send_after(15000, self(), ping),
  {cowboy_loop, Req, St}.

info({evento, E}, Req, St) ->
  cowboy_req:stream_body([<<"data: ">>, jsx:encode(E), <<"\n\n">>], nofin, Req),
  {ok, Req, St};
info(ping, Req, St) ->
  cowboy_req:stream_body(<<": ping\n\n">>, nofin, Req),
  erlang:send_after(15000, self(), ping),
  {ok, Req, St};
info(_, Req, St) ->
  {ok, Req, St}.
