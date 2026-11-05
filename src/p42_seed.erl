-module(p42_seed).
%% Datos generados. base/0 es un catalogo chico y fijo (para pruebas);
%% catalogo/1 agrega productos sinteticos hasta llegar a N.
-export([base/0, catalogo/1]).

base() ->
  Hoy = p42_reloj:hoy(),
  Productos = [
    {<<"PARA500">>, <<"Paracetamol 500 mg">>, libre, <<"paracetamol">>, 20},
    {<<"IBU400">>, <<"Ibuprofeno 400 mg">>, libre, <<"ibuprofeno">>, 20},
    {<<"ASA100">>, <<"Aspirina protect 100 mg">>, libre, <<"acido acetilsalicilico">>, 10},
    {<<"OMEP20">>, <<"Omeprazol 20 mg">>, libre, <<"omeprazol">>, 20},
    {<<"LORA10">>, <<"Loratadina 10 mg (blister)">>, libre, <<"loratadina">>, 2},
    {<<"AMOX500">>, <<"Amoxicilina 500 mg">>, antibiotico, <<"amoxicilina">>, 15},
    {<<"AZI500">>, <<"Azitromicina 500 mg">>, antibiotico, <<"azitromicina">>, 10},
    {<<"WARF5">>, <<"Warfarina 5 mg">>, receta, <<"warfarina">>, 5},
    {<<"LOSA50">>, <<"Losartan 50 mg">>, receta, <<"losartan">>, 10},
    {<<"METF850">>, <<"Metformina 850 mg">>, receta, <<"metformina">>, 15},
    {<<"CLONA2">>, <<"Clonazepam 2 mg">>, controlado, <<"clonazepam">>, 5},
    {<<"TRAMA50">>, <<"Tramadol 50 mg">>, controlado, <<"tramadol">>, 5}
  ],
  [ok = p42_inventario:alta_producto(#{sku => S, nombre => N, tipo => T, principio => P, reorden => R})
   || {S, N, T, P, R} <- Productos],
  Lotes = [
    {<<"L-PARA-VENC">>, <<"PARA500">>, 10, Hoy - 5},     %% caducado: nunca se surte
    {<<"L-PARA-A">>, <<"PARA500">>, 50, Hoy + 40},        %% FEFO: sale primero
    {<<"L-PARA-B">>, <<"PARA500">>, 100, Hoy + 400},
    {<<"L-IBU-A">>, <<"IBU400">>, 80, Hoy + 200},
    {<<"L-ASA-A">>, <<"ASA100">>, 40, Hoy + 300},
    {<<"L-ALERTA-01">>, <<"OMEP20">>, 60, Hoy + 120},     %% el lote que se retira
    {<<"L-OMEP-B">>, <<"OMEP20">>, 80, Hoy + 500},
    {<<"L-LORA-A">>, <<"LORA10">>, 1, Hoy + 10},          %% el ultimo blister
    {<<"L-LORA-B">>, <<"LORA10">>, 3, Hoy + 365},
    {<<"L-AMOX-A">>, <<"AMOX500">>, 30, Hoy + 25},
    {<<"L-AMOX-B">>, <<"AMOX500">>, 60, Hoy + 300},
    {<<"L-AZI-A">>, <<"AZI500">>, 20, Hoy + 180},
    {<<"L-WARF-A">>, <<"WARF5">>, 20, Hoy + 365},
    {<<"L-LOSA-A">>, <<"LOSA50">>, 6, Hoy + 60},
    {<<"L-METF-A">>, <<"METF850">>, 90, Hoy + 240},
    {<<"L-CLONA-A">>, <<"CLONA2">>, 10, Hoy + 500},
    {<<"L-TRAMA-A">>, <<"TRAMA50">>, 12, Hoy + 400}
  ],
  [ok = p42_inventario:alta_lote(#{lote => L, sku => S, cantidad => C, caducidad => Cad})
   || {L, S, C, Cad} <- Lotes],
  ok.

catalogo(N) ->
  ok = base(),
  rand:seed(exsss, {42, 42, 42}),
  Hoy = p42_reloj:hoy(),
  Extra = max(0, N - 12),
  lists:foreach(
    fun(I) ->
      Sku = iolist_to_binary(io_lib:format("GEN-~4..0B", [I])),
      Tipo = tipo(rand:uniform(100)),
      ok = p42_inventario:alta_producto(#{sku => Sku,
                                          nombre => iolist_to_binary(io_lib:format("Generico ~p (~p)", [I, Tipo])),
                                          tipo => Tipo,
                                          principio => iolist_to_binary(io_lib:format("principio_~p", [I])),
                                          reorden => 10}),
      lists:foreach(
        fun(J) ->
          Lote = iolist_to_binary(io_lib:format("L-~4..0B-~p", [I, J])),
          ok = p42_inventario:alta_lote(#{lote => Lote, sku => Sku,
                                          cantidad => 5 + rand:uniform(115),
                                          caducidad => Hoy - 15 + rand:uniform(735)})
        end, lists:seq(1, rand:uniform(3)))
    end, lists:seq(1, Extra)),
  p42_bitacora:registrar(ok, "catalogo generado: ~p productos, ~p lotes",
                         [ets:info(p42_productos, size), ets:info(p42_lotes, size)]),
  ok.

%% 60% libre, 25% con receta, 12% antibiotico, 3% controlado
tipo(X) when X =< 60 -> libre;
tipo(X) when X =< 85 -> receta;
tipo(X) when X =< 97 -> antibiotico;
tipo(_) -> controlado.
