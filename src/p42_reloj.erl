-module(p42_reloj).
-export([hoy/0, fecha/1, ahora_s/0, ahora_iso/0]).

%% Dias gregorianos de hoy (entero facil de comparar).
hoy() -> calendar:date_to_gregorian_days(date()).

fecha(Dias) ->
  {Y, M, D} = calendar:gregorian_days_to_date(Dias),
  iolist_to_binary(io_lib:format("~4..0B-~2..0B-~2..0B", [Y, M, D])).

ahora_s() -> erlang:system_time(second).

ahora_iso() ->
  {{Y, Mo, D}, {H, Mi, S}} = calendar:local_time(),
  iolist_to_binary(io_lib:format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B",
                                 [Y, Mo, D, H, Mi, S])).
