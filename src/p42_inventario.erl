-module(p42_inventario).
-behaviour(gen_server).
%% Inventario por lote y caducidad.
%%
%% Es el UNICO proceso que escribe existencias. Como un gen_server atiende un
%% mensaje a la vez, dos mostradores que piden el ultimo blister al mismo
%% tiempo quedan serializados: uno se lo lleva y el otro recibe el siguiente
%% lote (o "sin existencias"). Nunca hay sobreventa.
%%
%% Las lecturas (consultas, tablero) van directo a ETS sin pasar por el proceso.
%%
%% Reglas inviolables que viven aqui, no en el criterio del empleado:
%%   * FEFO: se surte primero el lote que caduca antes.
%%   * Nunca se surte un lote caducado ni uno retirado por alerta sanitaria.
%%   * Lo que no es de venta libre exige una receta valida (contexto con receta).

-export([start_link/0]).
-export([alta_producto/1, alta_lote/1, surtir/3, retirar_lote/1, devolver/3]).
-export([producto/1, lotes/1, existencias/1, detalle/1, buscar/2,
         caducidades/1, caducados/0, criticos/0, clientes_lote/1,
         unidades_totales/0, resumen/0, skus/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%% ---------------------------------------------------------------- escrituras

alta_producto(P = #{sku := _, nombre := _, tipo := _}) ->
  gen_server:call(?MODULE, {alta_producto, P}).

alta_lote(L = #{lote := _, sku := _, cantidad := _, caducidad := _}) ->
  gen_server:call(?MODULE, {alta_lote, L}).

%% Ctx = #{cliente := _, mostrador := _, receta => Id}
%% -> {ok, Entregado, [#{lote, cantidad}]} | {error, Razon}
%% Entregado puede ser menor a Cantidad (surtido parcial).
surtir(Sku, Cantidad, Ctx) when is_integer(Cantidad), Cantidad > 0 ->
  gen_server:call(?MODULE, {surtir, Sku, Cantidad, Ctx}).

%% Retira un lote por alerta sanitaria y devuelve a quien se le vendio.
retirar_lote(Lote) ->
  gen_server:call(?MODULE, {retirar, Lote}).

%% Devolucion: solo reingresa si viene sin abrir, el lote no esta retirado
%% ni caducado. Si no, es merma (cadena de frio / integridad no garantizada).
devolver(Lote, Cantidad, Motivo) ->
  gen_server:call(?MODULE, {devolver, Lote, Cantidad, Motivo}).

%%% ---------------------------------------------------------------- lecturas

producto(Sku) ->
  case ets:lookup(p42_productos, Sku) of
    [{_, P}] -> P;
    [] -> undefined
  end.

lotes(Sku) ->
  Ls = [L || {_, Id} <- ets:lookup(p42_lotes_sku, Sku),
             {_, L} <- ets:lookup(p42_lotes, Id)],
  lists:sort(fun(#{caducidad := A}, #{caducidad := B}) -> A =< B end, Ls).

%% Unidades que SI se pueden vender (vigentes y no retiradas).
existencias(Sku) ->
  lists:sum([C || #{cantidad := C} <- lotes_disponibles(Sku)]).

detalle(Sku) ->
  case producto(Sku) of
    undefined -> undefined;
    P -> P#{existencias => existencias(Sku),
            lotes => [vista_lote(L) || L <- lotes(Sku)]}
  end.

buscar(Q, Max) ->
  Ql = string:lowercase(Q),
  Todos = [P || {_, P = #{sku := S, nombre := N}} <- ets:tab2list(p42_productos),
                Ql =:= <<>> orelse
                  string:find(string:lowercase(N), Ql) =/= nomatch orelse
                  string:find(string:lowercase(S), Ql) =/= nomatch],
  [P#{existencias => existencias(S)} || P = #{sku := S} <- lists:sublist(lists:sort(Todos), Max)].

%% Lotes vigentes con existencia que caducan dentro de Dias.
caducidades(Dias) ->
  Hoy = p42_reloj:hoy(),
  Ls = [L || {_, L = #{cantidad := C, caducidad := Cad, retirado := false}} <- ets:tab2list(p42_lotes),
             C > 0, Cad >= Hoy, Cad =< Hoy + Dias],
  [vista_lote(L) || L <- lists:sort(fun(#{caducidad := A}, #{caducidad := B}) -> A =< B end, Ls)].

caducados() ->
  Hoy = p42_reloj:hoy(),
  [vista_lote(L) || {_, L = #{cantidad := C, caducidad := Cad}} <- ets:tab2list(p42_lotes),
                    C > 0, Cad < Hoy].

%% Productos en o bajo su punto de reorden (quiebre de stock).
criticos() ->
  [P#{existencias => E}
   || {_, P = #{sku := S, reorden := R}} <- ets:tab2list(p42_productos),
      E <- [existencias(S)], E =< R].

clientes_lote(Lote) ->
  [V#{lote => Lote} || {_, V} <- ets:lookup(p42_ventas, Lote)].

unidades_totales() ->
  lists:sum([C || {_, #{cantidad := C}} <- ets:tab2list(p42_lotes)]).

skus() ->
  [{S, T} || {S, #{tipo := T}} <- ets:tab2list(p42_productos)].

resumen() ->
  Dias = application:get_env(p42_farmacia, dias_alerta_caducidad, 90),
  Prox = caducidades(Dias),
  Crit = criticos(),
  Recetas = ets:tab2list(p42_recetas),
  PorEstado = lists:foldl(fun({_, _, E}, Acc) -> maps:update_with(E, fun(X) -> X + 1 end, 1, Acc) end,
                          #{emitida => 0, surtida_parcial => 0, surtida => 0, vencida => 0}, Recetas),
  #{productos => ets:info(p42_productos, size),
    lotes => ets:info(p42_lotes, size),
    unidades => unidades_totales(),
    criticos_total => length(Crit),
    criticos => lists:sublist(Crit, 20),
    proximos_caducar_total => length(Prox),
    proximos_caducar => lists:sublist(Prox, 20),
    caducados_con_existencia => length(caducados()),
    dias_alerta => Dias,
    recetas => PorEstado,
    metricas => p42_metricas:todas(),
    pid_inventario => pid_bin(whereis(?MODULE))}.

%%% ---------------------------------------------------------------- gen_server

init([]) ->
  %% El estado vive en ETS (duenio: supervisor). Si este proceso muere y
  %% reinicia, no se pierde nada.
  p42_metricas:inc(reinicios_inventario_arranques),
  p42_bitacora:registrar(ok, "inventario iniciado (~p), ~p lotes en ETS",
                         [self(), ets:info(p42_lotes, size)]),
  {ok, #{}}.

handle_call({alta_producto, P}, _From, S) ->
  Prod = maps:merge(#{principio => <<>>, reorden => 10}, P),
  ets:insert(p42_productos, {maps:get(sku, Prod), Prod}),
  {reply, ok, S};

handle_call({alta_lote, L = #{lote := Id, sku := Sku, cantidad := C}}, _From, S) ->
  case ets:member(p42_productos, Sku) of
    false ->
      {reply, {error, producto_desconocido}, S};
    true ->
      Lote = maps:merge(#{retirado => false, vendidas => 0, inicial => C}, L),
      ets:insert(p42_lotes, {Id, Lote}),
      ets:insert(p42_lotes_sku, {Sku, Id}),
      {reply, ok, S}
  end;

handle_call({surtir, Sku, Cant, Ctx}, _From, S) ->
  {reply, hacer_surtido(Sku, Cant, Ctx), S};

handle_call({retirar, Lote}, _From, S) ->
  case ets:lookup(p42_lotes, Lote) of
    [] ->
      {reply, {error, lote_no_existe}, S};
    [{_, L = #{sku := Sku}}] ->
      ets:insert(p42_lotes, {Lote, L#{retirado := true}}),
      Clientes = clientes_lote(Lote),
      p42_metricas:inc(lotes_retirados),
      p42_bitacora:registrar(falla, "ALERTA SANITARIA: lote ~ts (~ts) retirado; ~p ventas a localizar",
                             [Lote, Sku, length(Clientes)]),
      {reply, {ok, Clientes}, S}
  end;

handle_call({devolver, Lote, Cant, Motivo}, _From, S) ->
  Hoy = p42_reloj:hoy(),
  case ets:lookup(p42_lotes, Lote) of
    [] ->
      {reply, {error, lote_no_existe}, S};
    [{_, L = #{cantidad := C, caducidad := Cad, retirado := Ret}}]
        when Motivo =:= <<"sin_abrir">>, Ret =:= false, Cad >= Hoy ->
      ets:insert(p42_lotes, {Lote, L#{cantidad := C + Cant}}),
      p42_bitacora:registrar(ok, "devolucion lote ~ts: ~p unidades reingresan", [Lote, Cant]),
      {reply, {ok, reingresa}, S};
    [_] ->
      p42_metricas:inc(merma_unidades, Cant),
      p42_bitacora:registrar(alerta, "devolucion lote ~ts: ~p unidades a merma (~ts)", [Lote, Cant, Motivo]),
      {reply, {ok, merma}, S}
  end.

handle_cast(_Msg, S) ->
  {noreply, S}.

handle_info(_Info, S) ->
  {noreply, S}.

%%% ---------------------------------------------------------------- internas

hacer_surtido(Sku, Cant, Ctx) ->
  case ets:lookup(p42_productos, Sku) of
    [] ->
      {error, producto_desconocido};
    [{_, #{tipo := Tipo}}] ->
      case Tipo =/= libre andalso not maps:is_key(receta, Ctx) of
        true ->
          p42_metricas:inc(ventas_rechazadas),
          {error, {requiere_receta, Tipo}};
        false ->
          {Usados, Entregado} = tomar(lotes_disponibles(Sku), Cant, Ctx, [], 0),
          p42_metricas:inc(unidades_surtidas, Entregado),
          case Entregado < Cant of
            true -> p42_metricas:inc(surtidos_incompletos);
            false -> p42_metricas:inc(surtidos_completos)
          end,
          {ok, Entregado, Usados}
      end
  end.

%% FEFO: vigentes, no retirados, con existencia, ordenados por caducidad.
lotes_disponibles(Sku) ->
  Hoy = p42_reloj:hoy(),
  [L || L = #{cantidad := C, caducidad := Cad, retirado := R} <- lotes(Sku),
        C > 0, Cad >= Hoy, R =:= false].

tomar(_, 0, _Ctx, Usados, E) ->
  {lists:reverse(Usados), E};
tomar([], _Falta, _Ctx, Usados, E) ->
  {lists:reverse(Usados), E};
tomar([L = #{lote := Id, cantidad := C, vendidas := V} | Resto], Falta, Ctx, Usados, E) ->
  N = min(C, Falta),
  ets:insert(p42_lotes, {Id, L#{cantidad := C - N, vendidas := V + N}}),
  ets:insert(p42_ventas, {Id, #{cliente => maps:get(cliente, Ctx, <<"mostrador">>),
                                cantidad => N,
                                receta => maps:get(receta, Ctx, null),
                                mostrador => maps:get(mostrador, Ctx, 1),
                                ts => p42_reloj:ahora_iso()}}),
  tomar(Resto, Falta - N, Ctx, [#{lote => Id, cantidad => N} | Usados], E + N).

vista_lote(L = #{caducidad := Cad}) ->
  Hoy = p42_reloj:hoy(),
  L#{caducidad := p42_reloj:fecha(Cad), dias_restantes => Cad - Hoy}.

pid_bin(undefined) -> null;
pid_bin(P) -> list_to_binary(pid_to_list(P)).
