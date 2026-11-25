/*  escenarios.pl — Las cinco situaciones de gemelo/PROBLEMA.md como solicitudes de mostrador

    escenario(Id, Situacion, Titulo, Descripcion, Solicitudes, Hipotesis)
      Solicitudes: lista de sol/8  o  retiro(Lote) para la situación 4
      Hipotesis:   ids de hipotesis_predefinida/3 que tienen sentido en ese escenario

    sol(Id, Mostrador, Paciente, Receta, Med, Cantidad, DiasTratamiento, Instante)
      Instante = minuto del día (600 = 10:00)
*/
:- encoding(utf8).

% ---------------------------------------------- Situación 1: la receta que parece buena
escenario(s11, 1, "Controlado con receta común",
    "Luis presenta en el mostrador 1 una receta firmada (r101) de clonazepam, pero es receta común.",
    [sol(s11, m1, luis, r101, clonazepam_2, 1, 30, 540)], []).
escenario(s12, 1, "El mismo tipo de receta, para un medicamento con receta",
    "Carmen presenta una receta común (r102) de azitromicina: para un medicamento «con receta» sí basta.",
    [sol(s12, m2, carmen, r102, azitromicina_500, 1, 5, 545)], []).
escenario(s13, 1, "Receta especial: ¿ya se usó en Otay?",
    "Luis presenta una receta especial con folio (r103). Otay no reporta desde el día 196.",
    [sol(s13, m1, luis, r103, clonazepam_2, 1, 30, 550)], [otay_reporta]).
escenario(s14, 1, "Receta especial que ya se surtió en la otra sucursal",
    "Ana presenta la receta especial r104 de tramadol, que Otay surtió y retuvo el día 195.",
    [sol(s14, m3, ana, r104, tramadol_50, 1, 10, 555)], []).

% ---------------------------------------------- Situación 2: medio tratamiento hoy
escenario(s21, 2, "Medio tratamiento hoy, el resto mañana",
    "Carmen trae la receta r201 (4 cajas de amoxicilina; ya se llevó 1 el día 197) y pide 4. En estante hay 2 aptas. Quiere completar en otra farmacia.",
    [sol(s21, m2, carmen, r201, amoxicilina_500, 4, 10, 600)], [llega_amox]).

% ---------------------------------------------- Situación 3: el último blíster
escenario(s31, 3, "El último blíster",
    "A las 10:00 Luis (tratamiento de 45 días) y a las 10:01 Ana (7 días) piden loratadina en dos mostradores. Del lote que caduca primero (l_lora_a, día 230) queda 1 blíster.",
    [sol(s31, m1, luis, ninguna, loratadina_10, 1, 45, 600),
     sol(s32, m2, ana,  ninguna, loratadina_10, 1, 7,  601)], [retiran_lora_a]).
escenario(s33, 3, "El último blíster (dos tratamientos cortos)",
    "Mismo caso, pero el tratamiento de Luis dura 5 días: ahora sí gana quien llegó primero.",
    [sol(s33, m1, luis, ninguna, loratadina_10, 1, 5, 600),
     sol(s34, m2, ana,  ninguna, loratadina_10, 1, 7, 601)], [retiran_lora_a]).

% ---------------------------------------------- Situación 4: el lote retirado
escenario(s41, 4, "El lote retirado: ¿quién se lo llevó?",
    "Una alerta sanitaria retira el lote l_omep_a (día 198). Ya se vendieron unidades: unas con receta, otras de mostrador sin comprador. Llegó una devolución con la etiqueta ilegible.",
    retiro(l_omep_a), []).

% ---------------------------------------------- Situación 5: con receta, pero no para esta persona
escenario(s51, 5, "Receta correcta, paciente alérgica (otro nombre comercial)",
    "Ana presenta la receta r501 de Amoxil. Su ficha dice alergia a amoxicilina; el nombre comercial es otro.",
    [sol(s51, m1, ana, r501, amoxil_500, 1, 7, 620)], []).
escenario(s52, 5, "Ibuprofeno de mostrador y warfarina de la otra sucursal",
    "Luis pide ibuprofeno (venta libre). Hace 6 días Otay le surtió warfarina.",
    [sol(s52, m3, luis, ninguna, ibuprofeno_400, 1, 3, 625)], []).
escenario(s53, 5, "Ficha de alergias nunca capturada",
    "Pedro presenta la receta r505 de azitromicina. Nadie capturó su ficha de alergias.",
    [sol(s53, m2, pedro, r505, azitromicina_500, 1, 5, 630)], [ficha_pedro_sin, ficha_pedro_azitro]).

% ---------------------------------------------- hipótesis («¿qué pasaría si…?»)
% hipotesis_predefinida(Id, Pregunta, Cambios)
hipotesis_predefinida(otay_reporta,
    "¿Y si Otay reporta hoy y el folio no aparece surtido?",
    [-reporte_sucursal(otay, _), +reporte_sucursal(otay, 200)]).
hipotesis_predefinida(retiran_lora_a,
    "¿Y si retiran el lote que caduca primero (l_lora_a)?",
    [+lote_retirado(l_lora_a, 200)]).
hipotesis_predefinida(llega_amox,
    "¿Y si llega un lote nuevo de amoxicilina (5 cajas, caduca el día 700)?",
    [+lote(l_amox_c, amoxicilina_500, 700, e3), +existencia(l_amox_c, 5)]).
hipotesis_predefinida(ficha_pedro_sin,
    "¿Y si se captura la ficha de Pedro y no declara alergias?",
    [+alergias_capturadas(pedro)]).
hipotesis_predefinida(ficha_pedro_azitro,
    "¿Y si se captura la ficha de Pedro y declara alergia a azitromicina?",
    [+alergias_capturadas(pedro), +alergia(pedro, azitromicina)]).

%! decide_escenario(+Escenario, +Hipotesis, ?Alternativa, -Decision, -Explicacion) is nondet.
%  Hipotesis = ninguna o un id de hipotesis_predefinida/3.
decide_escenario(Esc, ninguna, Alt, D, E) :- !,
    escenario(Esc, _, _, _, Sols, _), is_list(Sols),
    decide(Sols, Alt, D, E).
decide_escenario(Esc, Hip, Alt, D, E) :-
    escenario(Esc, _, _, _, Sols, _), is_list(Sols),
    hipotesis_predefinida(Hip, _, Cambios),
    hipotesis(Cambios, decide(Sols, Alt, D, E)).
