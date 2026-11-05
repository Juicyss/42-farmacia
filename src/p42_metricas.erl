-module(p42_metricas).
%% Contadores y gauges en ETS (sin proceso: update_counter es atomico).
-export([inc/1, inc/2, set/2, valor/1, todas/0, siguiente/1, texto/0]).

inc(K) -> inc(K, 1).

inc(K, N) ->
  try ets:update_counter(p42_metricas, K, N, {K, 0}) of _ -> ok
  catch error:badarg -> ok
  end.

set(K, V) ->
  try ets:insert(p42_metricas, {K, V}) of _ -> ok
  catch error:badarg -> ok
  end.

valor(K) ->
  case ets:lookup(p42_metricas, K) of
    [{_, V}] -> V;
    [] -> 0
  end.

%% Secuencias (ids de receta) viven en la misma tabla con prefijo seq_.
siguiente(Seq) ->
  ets:update_counter(p42_metricas, {seq, Seq}, 1, {{seq, Seq}, 0}).

todas() ->
  maps:from_list([{K, V} || {K, V} <- ets:tab2list(p42_metricas), is_atom(K)]).

%% Formato de exposicion de Prometheus.
texto() ->
  Propias = lists:sort(maps:to_list(todas())),
  Vm = [
    {vm_procesos, erlang:system_info(process_count)},
    {vm_memoria_bytes, erlang:memory(total)},
    {vm_cola_ejecucion, erlang:statistics(run_queue)},
    {vm_proceso_mayor_memoria_bytes, mayor_memoria()}
  ],
  [[<<"# TYPE farmacia_">>, atom_to_binary(K), <<" gauge\nfarmacia_">>,
    atom_to_binary(K), <<" ">>, integer_to_binary(V), <<"\n">>]
   || {K, V} <- Propias ++ Vm, is_integer(V)].

%% recon: el proceso que mas memoria usa (diagnostico sin observer).
mayor_memoria() ->
  case recon:proc_count(memory, 1) of
    [{_Pid, Bytes, _Info}] -> Bytes;
    _ -> 0
  end.
