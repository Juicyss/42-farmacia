-module(p42_db).
%% Tablas ETS compartidas. Las crea el supervisor raiz (su duenio), de modo que
%% sobreviven a la caida de cualquier worker.
-export([init/0, reset/0]).

-define(TABLAS, [
  {p42_productos, set},    %% {Sku, #{sku, nombre, tipo, principio, reorden}}
  {p42_lotes, set},        %% {Lote, #{lote, sku, cantidad, inicial, caducidad, retirado, vendidas}}
  {p42_lotes_sku, bag},    %% {Sku, Lote}  indice secundario
  {p42_ventas, bag},       %% {Lote, #{cliente, cantidad, receta, mostrador, ts}}  trazabilidad
  {p42_recetas, set},      %% {Id, Datos, Estado}  estado durable de cada gen_statem
  {p42_receta_pid, set},   %% {Id, Pid}
  {p42_folios, set},       %% {Folio, RecetaId, Sucursal}  recetas de controlados ya usadas
  {p42_metricas, set}      %% {Nombre, Valor}
]).

init() ->
  lists:foreach(
    fun({T, Tipo}) ->
      case ets:whereis(T) of
        undefined -> ets:new(T, [named_table, public, Tipo, {read_concurrency, true}]);
        _ -> ok
      end
    end, ?TABLAS),
  ok.

reset() ->
  [ets:delete_all_objects(T) || {T, _} <- ?TABLAS],
  ok.
