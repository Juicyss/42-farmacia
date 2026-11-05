-module(p42_farmacia_tests).
-include_lib("eunit/include/eunit.hrl").

%% Cada prueba arranca un arbol limpio con el catalogo base (sin cowboy).
arranque() ->
  application:set_env(p42_farmacia, intervalo_revisor_ms, 60000),
  {ok, Pid} = p42_farmacia_sup:start_link(),
  ok = p42_seed:base(),
  Pid.

paro(Pid) ->
  unlink(Pid),
  Ref = monitor(process, Pid),
  exit(Pid, shutdown),
  receive {'DOWN', Ref, _, _, _} -> ok after 5000 -> ok end.

prueba(F) -> {setup, fun arranque/0, fun paro/1, fun(_) -> [{timeout, 20, F}] end}.

arbol_de_supervision_test_() ->
  prueba(fun() ->
    ?assertEqual(pong, p42_farmacia_server:ping()),
    ?assert(is_map(p42_farmacia_server:state()))
  end).

fefo_y_caducados_test_() ->
  prueba(fun() ->
    %% 60 unidades: 50 del lote que caduca en 40 dias + 10 del de 400 dias;
    %% el lote caducado (L-PARA-VENC) nunca se toca.
    {ok, 60, Usados} = p42_inventario:surtir(<<"PARA500">>, 60, #{cliente => <<"Ana">>, mostrador => 1}),
    ?assertEqual([#{lote => <<"L-PARA-A">>, cantidad => 50},
                  #{lote => <<"L-PARA-B">>, cantidad => 10}], Usados),
    [{_, #{cantidad := Venc}}] = ets:lookup(p42_lotes, <<"L-PARA-VENC">>),
    ?assertEqual(10, Venc)
  end).

venta_libre_de_antibiotico_rechazada_test_() ->
  prueba(fun() ->
    ?assertEqual({error, {requiere_receta, antibiotico}},
                 p42_inventario:surtir(<<"AMOX500">>, 1, #{cliente => <<"Beto">>, mostrador => 1}))
  end).

alergia_e_interaccion_test_() ->
  prueba(fun() ->
    ?assertEqual({error, {alergia, <<"amoxicilina">>}},
                 p42_recetas:crear(#{paciente => <<"C">>, alergias => [<<"Amoxicilina">>],
                                     items => [#{sku => <<"AMOX500">>, cantidad => 1}]})),
    ?assertEqual({error, {interaccion, <<"warfarina">>, <<"ibuprofeno">>}},
                 p42_recetas:crear(#{paciente => <<"D">>,
                                     items => [#{sku => <<"WARF5">>, cantidad => 1},
                                               #{sku => <<"IBU400">>, cantidad => 1}]}))
  end).

controlado_folio_unico_test_() ->
  prueba(fun() ->
    ?assertEqual({error, folio_requerido},
                 p42_recetas:crear(#{paciente => <<"E">>, items => [#{sku => <<"CLONA2">>, cantidad => 1}]})),
    {ok, _} = p42_recetas:crear(#{paciente => <<"E">>, folio => <<"F1">>, sucursal => <<"Otay">>,
                                  items => [#{sku => <<"CLONA2">>, cantidad => 1}]}),
    ?assertEqual({error, {folio_ya_usado, <<"Otay">>}},
                 p42_recetas:crear(#{paciente => <<"E">>, folio => <<"F1">>, sucursal => <<"Centro">>,
                                     items => [#{sku => <<"CLONA2">>, cantidad => 1}]}))
  end).

surtido_parcial_en_dos_visitas_test_() ->
  prueba(fun() ->
    %% Solo hay 6 losartan; la receta pide 10.
    {ok, Id} = p42_recetas:crear(#{paciente => <<"F">>, items => [#{sku => <<"LOSA50">>, cantidad => 10}]}),
    ?assertMatch({ok, #{estado := surtida_parcial}}, p42_receta:surtir(Id, 1)),
    ok = p42_inventario:alta_lote(#{lote => <<"L-LOSA-B">>, sku => <<"LOSA50">>, cantidad => 20,
                                    caducidad => p42_reloj:hoy() + 300}),
    ?assertMatch({ok, #{estado := surtida, entregado := [#{cantidad := 4}]}}, p42_receta:surtir(Id, 2)),
    ?assertEqual({error, ya_surtida}, p42_receta:surtir(Id, 3))
  end).

caos_doble_surtido_en_paralelo_test_() ->
  prueba(fun() ->
    #{exitosos := Oks, correcto := Ok} = p42_caos:doble_surtido(),
    ?assertEqual(1, Oks),
    ?assert(Ok)
  end).

ultimo_blister_sin_sobreventa_test_() ->
  prueba(fun() ->
    Yo = self(),
    [spawn(fun() -> Yo ! {r, p42_inventario:surtir(<<"LORA10">>, 1, #{cliente => M, mostrador => M})} end)
     || M <- [2, 3]],
    Rs = [receive {r, R} -> R end || _ <- [1, 2]],
    Lotes = lists:sort([L || {ok, 1, [#{lote := L}]} <- Rs]),
    %% uno se lleva el ultimo del lote A y el otro recibe el lote B
    ?assertEqual([<<"L-LORA-A">>, <<"L-LORA-B">>], Lotes),
    [{_, #{cantidad := A}}] = ets:lookup(p42_lotes, <<"L-LORA-A">>),
    ?assertEqual(0, A)
  end).

retiro_de_lote_localiza_clientes_test_() ->
  prueba(fun() ->
    [{ok, 1, _} = p42_inventario:surtir(<<"OMEP20">>, 1, #{cliente => C, mostrador => 1})
     || C <- [<<"c1">>, <<"c2">>, <<"c3">>]],
    {ok, Cl} = p42_inventario:retirar_lote(<<"L-ALERTA-01">>),
    ?assertEqual([<<"c1">>, <<"c2">>, <<"c3">>], lists:sort([C || #{cliente := C} <- Cl])),
    %% despues del retiro ya no se surte de ese lote
    ?assertMatch({ok, 1, [#{lote := <<"L-OMEP-B">>}]},
                 p42_inventario:surtir(<<"OMEP20">>, 1, #{cliente => <<"c4">>, mostrador => 1}))
  end).

caos_matar_inventario_conserva_datos_test_() ->
  prueba(fun() ->
    #{reiniciado := R, unidades_antes := A, unidades_despues := D} = p42_caos:matar(<<"inventario">>),
    ?assert(R),
    ?assertEqual(A, D),
    ?assertMatch({ok, 1, _}, p42_inventario:surtir(<<"IBU400">>, 1, #{cliente => <<"x">>, mostrador => 1}))
  end).

caos_matar_receta_conserva_estado_test_() ->
  prueba(fun() ->
    #{estado_antes := E1, estado_despues := E2, pid_antes := P1, pid_despues := P2} = p42_caos:matar(<<"receta">>),
    ?assertEqual(surtida_parcial, E1),
    ?assertEqual(E1, E2),
    ?assertNotEqual(P1, P2)
  end).

receta_vence_test_() ->
  prueba(fun() ->
    {ok, Id} = p42_recetas:crear(#{paciente => <<"G">>, vigencia_seg => 1,
                                   items => [#{sku => <<"METF850">>, cantidad => 1}]}),
    timer:sleep(1300),
    ?assertMatch(#{estado := vencida}, p42_receta:consultar(Id)),
    ?assertEqual({error, vencida}, p42_receta:surtir(Id, 1))
  end).

devoluciones_test_() ->
  prueba(fun() ->
    ?assertEqual({ok, reingresa}, p42_inventario:devolver(<<"L-IBU-A">>, 2, <<"sin_abrir">>)),
    ?assertEqual({ok, merma}, p42_inventario:devolver(<<"L-IBU-A">>, 1, <<"abierto">>)),
    {ok, _} = p42_inventario:retirar_lote(<<"L-ASA-A">>),
    ?assertEqual({ok, merma}, p42_inventario:devolver(<<"L-ASA-A">>, 1, <<"sin_abrir">>))
  end).

simulacion_escenario_test_() ->
  prueba(fun() ->
    R = p42_sim:escenario(#{productos => 300, ventas => 120}),
    ?assertMatch(#{lote_retirado := #{ventas_localizadas := 40, siguiente_venta_sale_de := <<"L-OMEP-B">>}}, R),
    ?assertMatch(#{ultimo_blister := #{sobreventa := false, lote_a_queda := 0}}, R),
    ?assertMatch(#{doble_surtido := #{correcto := true}}, R),
    ?assertMatch(#{controlado_otra_sucursal := #{error := _}}, R),
    #{mostradores := #{ventas := V}} = R,
    ?assertEqual(80, V)
  end).
