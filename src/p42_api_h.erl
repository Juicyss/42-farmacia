-module(p42_api_h).
%% API JSON bajo /api/...
-export([init/2]).

init(Req0, St) ->
  Metodo = cowboy_req:method(Req0),
  Ruta = cowboy_req:path_info(Req0),
  {Codigo, Cuerpo, Req1} =
    try ruta(Metodo, Ruta, Req0)
    catch C:E:Stk ->
      logger:error("api ~s ~p fallo: ~p:~p ~p", [Metodo, Ruta, C, E, Stk]),
      {500, #{error => razon({C, E})}, Req0}
    end,
  Req = cowboy_req:reply(Codigo, #{<<"content-type">> => <<"application/json; charset=utf-8">>},
                         jsx:encode(Cuerpo), Req1),
  {ok, Req, St}.

ruta(<<"GET">>, [<<"estado">>], R) ->
  {200, p42_inventario:resumen(), R};

ruta(<<"GET">>, [<<"productos">>], R) ->
  {200, p42_inventario:buscar(qs(R, <<"q">>, <<>>), 50), R};

ruta(<<"GET">>, [<<"productos">>, Sku], R) ->
  case p42_inventario:detalle(Sku) of
    undefined -> {404, #{error => <<"producto no existe">>}, R};
    D -> {200, D, R}
  end;

ruta(<<"GET">>, [<<"caducidades">>], R) ->
  Dias = binary_to_integer(qs(R, <<"dias">>, <<"90">>)),
  {200, lists:sublist(p42_inventario:caducidades(Dias), 300), R};

ruta(<<"GET">>, [<<"criticos">>], R) ->
  {200, lists:sublist(p42_inventario:criticos(), 300), R};

ruta(<<"GET">>, [<<"recetas">>], R) ->
  {200, p42_recetas:listar(50), R};

ruta(<<"POST">>, [<<"recetas">>], R0) ->
  {B, R} = leer_json(R0),
  case p42_recetas:crear(receta(B)) of
    {ok, Id} -> {201, p42_receta:consultar(Id), R};
    {error, E} -> {422, #{error => razon(E)}, R}
  end;

ruta(<<"GET">>, [<<"recetas">>, Id], R) ->
  case p42_receta:consultar(Id) of
    {error, E} -> {404, #{error => razon(E)}, R};
    V -> {200, V, R}
  end;

ruta(<<"POST">>, [<<"recetas">>, Id, <<"surtir">>], R0) ->
  {B, R} = leer_json(R0),
  case p42_receta:surtir(Id, maps:get(<<"mostrador">>, B, 1)) of
    {ok, Res} -> {200, Res, R};
    {error, E} -> {409, #{error => razon(E)}, R}
  end;

%% Venta de mostrador sin receta: el inventario rechaza lo que no es libre.
ruta(<<"POST">>, [<<"ventas">>], R0) ->
  {B, R} = leer_json(R0),
  Ctx = #{cliente => maps:get(<<"cliente">>, B, <<"mostrador">>),
          mostrador => maps:get(<<"mostrador">>, B, 1)},
  case p42_inventario:surtir(maps:get(<<"sku">>, B), maps:get(<<"cantidad">>, B, 1), Ctx) of
    {ok, N, U} -> {200, #{entregado => N, lotes => U}, R};
    {error, E} -> {409, #{error => razon(E)}, R}
  end;

ruta(<<"POST">>, [<<"lotes">>, Lote, <<"retirar">>], R) ->
  case p42_inventario:retirar_lote(Lote) of
    {ok, Cl} -> {200, #{lote => Lote, ventas_a_localizar => length(Cl), clientes => Cl}, R};
    {error, E} -> {404, #{error => razon(E)}, R}
  end;

ruta(<<"GET">>, [<<"lotes">>, Lote, <<"clientes">>], R) ->
  {200, p42_inventario:clientes_lote(Lote), R};

ruta(<<"POST">>, [<<"devoluciones">>], R0) ->
  {B, R} = leer_json(R0),
  case p42_inventario:devolver(maps:get(<<"lote">>, B), maps:get(<<"cantidad">>, B, 1),
                               maps:get(<<"motivo">>, B, <<"abierto">>)) of
    {ok, Destino} -> {200, #{destino => Destino}, R};
    {error, E} -> {404, #{error => razon(E)}, R}
  end;

ruta(<<"GET">>, [<<"bitacora">>], R) ->
  {200, p42_bitacora:listar(), R};

ruta(<<"POST">>, [<<"revisar">>], R) ->
  {200, p42_revisor:revisar_ahora(), R};

ruta(<<"POST">>, [<<"simular">>], R) ->
  {200, p42_sim:escenario(), R};

ruta(<<"POST">>, [<<"caos">>, Que], R) ->
  {200, p42_caos:matar(Que), R};

ruta(_, _, R) ->
  {404, #{error => <<"ruta no encontrada">>}, R}.

%%% internas

qs(R, K, Def) ->
  case lists:keyfind(K, 1, cowboy_req:parse_qs(R)) of
    {_, V} when is_binary(V) -> V;
    _ -> Def
  end.

leer_json(R0) ->
  {ok, Body, R} = cowboy_req:read_body(R0),
  case Body of
    <<>> -> {#{}, R};
    _ -> {jsx:decode(Body, [return_maps]), R}
  end.

receta(B) ->
  Base = #{paciente => maps:get(<<"paciente">>, B, <<"anonimo">>),
           alergias => maps:get(<<"alergias">>, B, []),
           folio => maps:get(<<"folio">>, B, null),
           sucursal => maps:get(<<"sucursal">>, B, <<"centro">>),
           items => [#{sku => S, cantidad => C}
                     || #{<<"sku">> := S, <<"cantidad">> := C} <- maps:get(<<"items">>, B, [])]},
  case B of
    #{<<"vigencia_seg">> := V} -> Base#{vigencia_seg => V};
    #{<<"vigencia_dias">> := V} -> Base#{vigencia_seg => V * 86400};
    _ -> Base
  end.

razon(E) -> iolist_to_binary(io_lib:format("~p", [E])).
