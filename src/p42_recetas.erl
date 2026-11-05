-module(p42_recetas).
%% Fachada para crear y listar recetas.
-export([crear/1, listar/1]).

-define(VIGENCIA_DEFECTO, 30 * 86400).

%% R = #{paciente, items => [#{sku, cantidad}], alergias, folio, sucursal, vigencia_seg}
crear(R) ->
  case p42_reglas:validar_receta(R) of
    {error, E} ->
      p42_metricas:inc(recetas_rechazadas),
      p42_bitacora:registrar(alerta, "receta rechazada para ~ts: ~p", [maps:get(paciente, R, <<"?">>), E]),
      {error, E};
    {ok, #{controlada := Controlada, retenida := Retenida}} ->
      N = p42_metricas:siguiente(receta),
      Id = iolist_to_binary(io_lib:format("R-~6..0B", [N])),
      Sucursal = maps:get(sucursal, R, <<"centro">>),
      Folio = maps:get(folio, R, null),
      %% Receta de controlado: el folio solo puede usarse UNA vez en toda la
      %% cadena. insert_new es atomico, asi que dos sucursales a la vez no
      %% pueden usar el mismo folio.
      case not Controlada orelse ets:insert_new(p42_folios, {Folio, Id, Sucursal}) of
        false ->
          [{_, Otra, OtraSuc}] = ets:lookup(p42_folios, Folio),
          p42_metricas:inc(recetas_rechazadas),
          p42_bitacora:registrar(falla, "folio ~ts ya usado en receta ~ts (sucursal ~ts)", [Folio, Otra, OtraSuc]),
          {error, {folio_ya_usado, OtraSuc}};
        true ->
          Datos = #{id => Id,
                    paciente => maps:get(paciente, R, <<"anonimo">>),
                    alergias => maps:get(alergias, R, []),
                    folio => Folio,
                    sucursal => Sucursal,
                    controlada => Controlada,
                    retenida => Retenida,
                    creada => p42_reloj:ahora_iso(),
                    expira => p42_reloj:ahora_s() + maps:get(vigencia_seg, R, ?VIGENCIA_DEFECTO),
                    items => [#{sku => S, cantidad => C, surtido => 0, lotes => []}
                              || #{sku := S, cantidad := C} <- maps:get(items, R)]},
          {ok, _Pid} = p42_recetas_sup:nueva(Datos),
          p42_metricas:inc(recetas_emitidas),
          {ok, Id}
      end
  end.

listar(Max) ->
  Todas = [D#{estado => E} || {_, D, E} <- ets:tab2list(p42_recetas)],
  Ord = lists:sort(fun(#{id := A}, #{id := B}) -> A >= B end, Todas),
  lists:sublist(Ord, Max).
