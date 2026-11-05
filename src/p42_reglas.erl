-module(p42_reglas).
%% Reglas de venta que el sistema hace cumplir siempre.
-export([validar_receta/1, interacciones/0]).

%% Pares de principios activos con interaccion peligrosa (lista de ejemplo).
interacciones() ->
  [{<<"warfarina">>, <<"ibuprofeno">>},
   {<<"warfarina">>, <<"acido acetilsalicilico">>},
   {<<"clonazepam">>, <<"tramadol">>}].

%% R = #{paciente, items => [#{sku, cantidad}], alergias => [binary], folio, sucursal}
validar_receta(R = #{items := Items}) when is_list(Items), Items =/= [] ->
  Alergias = [string:lowercase(A) || A <- maps:get(alergias, R, [])],
  case productos(Items, []) of
    {error, _} = Err -> Err;
    {ok, Prods} ->
      Principios = [string:lowercase(P) || #{principio := P} <- Prods],
      Controlada = lists:any(fun(#{tipo := T}) -> T =:= controlado end, Prods),
      Retenida = lists:any(fun(#{tipo := T}) -> T =:= controlado orelse T =:= antibiotico end, Prods),
      case {alergia(Principios, Alergias), interaccion(Principios), Controlada, maps:get(folio, R, undefined)} of
        {{si, P}, _, _, _} -> {error, {alergia, P}};
        {no, {si, A, B}, _, _} -> {error, {interaccion, A, B}};
        {no, no, true, F} when F =:= undefined; F =:= null; F =:= <<>> -> {error, folio_requerido};
        {no, no, _, _} -> {ok, #{controlada => Controlada, retenida => Retenida}}
      end
  end;
validar_receta(_) ->
  {error, receta_sin_medicamentos}.

productos([], Acc) ->
  {ok, lists:reverse(Acc)};
productos([#{sku := S, cantidad := C} | T], Acc) when is_integer(C), C > 0 ->
  case p42_inventario:producto(S) of
    undefined -> {error, {producto_desconocido, S}};
    P -> productos(T, [P | Acc])
  end;
productos([_ | _], _) ->
  {error, cantidad_invalida}.

alergia(Principios, Alergias) ->
  case [P || P <- Principios, lists:member(P, Alergias)] of
    [P | _] -> {si, P};
    [] -> no
  end.

interaccion(Ps) ->
  case [{A, B} || {A, B} <- interacciones(), lists:member(A, Ps), lists:member(B, Ps)] of
    [{A, B} | _] -> {si, A, B};
    [] -> no
  end.
