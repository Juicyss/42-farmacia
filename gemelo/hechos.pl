/*  hechos.pl — Estado de la farmacia (gemelo digital del proyecto #42)

    Hugo Iram Aguirre Dávila · Programación Lógica y Funcional · TecNM Tijuana

    Escala reducida (supuestos en ../gemelo/README.md):
      2 sucursales (Tijuana Centro con 3 mostradores, Otay con 1),
      11 medicamentos, 15 lotes, 4 pacientes, 2 médicos.
    El «ahora» es un HECHO (día 200 del modelo), no el reloj del sistema:
    así cada respuesta es repetible y se puede probar con plunit.

    Todo es dinámico para poder razonar hipótesis («¿qué pasaría si…?»)
    agregando o quitando hechos temporalmente (ver hipotesis/2 en reglas.pl).
*/
:- encoding(utf8).

:- dynamic
    ahora/1, dias_caducidad_cercana/1, vigencia_receta/1, tolerancia_reporte/1,
    ventana_interaccion/1,
    sucursal/2, mostrador/2, reporte_sucursal/2,
    medicamento/3, nombre_comercial/2, antibiotico/1,
    lote/4, existencia/2, lote_retirado/2, alerta_sanitaria/4,
    paciente/1, alergias_capturadas/1, alergia/2, contacto/2,
    medico/3, receta/6, folio_especial/2, evento_receta/4,
    interaccion/2, venta/7, devolucion/5.

:- discontiguous evento_receta/4, receta/6, venta/7, folio_especial/2.

% ---------------------------------------------------------------- tiempo
ahora(200).                         % instante del modelo, en días
dias_caducidad_cercana(90).         % «3 meses» del original = 90 días (supuesto)
vigencia_receta(30).                % días que una receta es válida desde su emisión (supuesto)
tolerancia_reporte(1).              % días sin reportar antes de volverse dato dudoso (supuesto)
ventana_interaccion(14).            % días hacia atrás para buscar interacciones (supuesto)

% ------------------------------------------------ sucursales y mostradores
sucursal(centro, 'Tijuana Centro').        % principal
sucursal(otay,   'Otay').

mostrador(m1, centro).
mostrador(m2, centro).
mostrador(m3, centro).
mostrador(o1, otay).

% reporte_sucursal(Sucursal, UltimoDiaReportado): hasta qué día subió sus surtidos
reporte_sucursal(centro, 200).
reporte_sucursal(otay,   196).             % Otay no reporta desde el día 196

% ------------------------------------------------------------ medicamentos
% medicamento(Med, PrincipioActivo, Requisito)   Requisito: libre | receta | controlado
medicamento(paracetamol_500,  paracetamol,            libre).
medicamento(ibuprofeno_400,   ibuprofeno,             libre).
medicamento(aspirina_100,     acido_acetilsalicilico, libre).
medicamento(loratadina_10,    loratadina,             libre).
medicamento(omeprazol_20,     omeprazol,              libre).
medicamento(amoxicilina_500,  amoxicilina,            receta).
medicamento(amoxil_500,       amoxicilina,            receta).   % otro nombre, mismo principio
medicamento(azitromicina_500, azitromicina,           receta).
medicamento(warfarina_5,      warfarina,              receta).
medicamento(clonazepam_2,     clonazepam,             controlado).
medicamento(tramadol_50,      tramadol,               controlado).

% nombre_comercial(Med, Texto): solo para mostrar
nombre_comercial(paracetamol_500,  'Paracetamol 500 mg').
nombre_comercial(ibuprofeno_400,   'Ibuprofeno 400 mg').
nombre_comercial(aspirina_100,     'Aspirina Protect 100 mg').
nombre_comercial(loratadina_10,    'Loratadina 10 mg (blíster)').
nombre_comercial(omeprazol_20,     'Omeprazol 20 mg').
nombre_comercial(amoxicilina_500,  'Amoxicilina 500 mg (genérico)').
nombre_comercial(amoxil_500,       'Amoxil 500 mg').
nombre_comercial(azitromicina_500, 'Azitromicina 500 mg').
nombre_comercial(warfarina_5,      'Warfarina 5 mg').
nombre_comercial(clonazepam_2,     'Clonazepam 2 mg').
nombre_comercial(tramadol_50,      'Tramadol 50 mg').

% Antibióticos: desde 2010 exigen receta que se sella en cada surtido
% y se retiene al agotarse lo prescrito (Acuerdo DOF 27/05/2010).
antibiotico(amoxicilina).
antibiotico(azitromicina).

% interaccion(PrincipioA, PrincipioB): pares peligrosos (simétrica en reglas.pl)
interaccion(warfarina, ibuprofeno).              % riesgo de sangrado (MedlinePlus: Warfarin)
interaccion(warfarina, acido_acetilsalicilico).  % riesgo de sangrado (MedlinePlus: Warfarin)
interaccion(clonazepam, tramadol).               % benzodiacepina + opioide (FDA, 2016)

% ------------------------------------------------------------------ lotes
% lote(Lote, Med, Caducidad, Estante)      Caducidad: día del modelo
lote(l_para_a,  paracetamol_500,  180, e1).   % ya vencido (180 < 200)
lote(l_para_b,  paracetamol_500,  420, e1).
lote(l_ibu_a,   ibuprofeno_400,   350, e1).
lote(l_asa_a,   aspirina_100,     500, e1).
lote(l_lora_a,  loratadina_10,    230, e2).   % el último blíster: caduca en 30 días
lote(l_lora_b,  loratadina_10,    560, e2).
lote(l_omep_a,  omeprazol_20,     320, e2).   % lo retira una alerta sanitaria
lote(l_omep_b,  omeprazol_20,     650, e2).
lote(l_amox_a,  amoxicilina_500,  250, e3).   % caducidad cercana (50 días)
lote(l_amox_b,  amoxicilina_500,  600, e3).
lote(l_amoxil_a, amoxil_500,      540, e3).
lote(l_azi_a,   azitromicina_500, 400, e3).
lote(l_warf_a,  warfarina_5,      480, e4).
lote(l_clona_a, clonazepam_2,     700, e5).   % e5: anaquel bajo llave
lote(l_trama_a, tramadol_50,      610, e5).

% existencia(Lote, Unidades) en la sucursal principal
existencia(l_para_a,   10).
existencia(l_para_b,   40).
existencia(l_ibu_a,    25).
existencia(l_asa_a,    12).
existencia(l_lora_a,    1).
existencia(l_lora_b,    3).
existencia(l_omep_a,    5).
existencia(l_omep_b,   18).
existencia(l_amox_a,    1).
existencia(l_amox_b,    1).
existencia(l_amoxil_a,  4).
existencia(l_azi_a,     6).
existencia(l_warf_a,    8).
existencia(l_clona_a,   6).
existencia(l_trama_a,   4).

% Alerta sanitaria: el fabricante reporta impureza en el lote de omeprazol
alerta_sanitaria(a1, l_omep_a, 198, 'Impureza reportada por el fabricante').
lote_retirado(l_omep_a, 198).

% -------------------------------------------------------------- personas
paciente(ana).
paciente(luis).
paciente(carmen).
paciente(pedro).

% Ficha de alergias: SOLO quien tiene ficha capturada tiene dato.
% Sin ficha, la respuesta sobre alergias es «no se sabe», nunca «no».
alergias_capturadas(ana).
alergias_capturadas(luis).
alergias_capturadas(carmen).
% pedro: su ficha de alergias nunca se capturó

alergia(ana, amoxicilina).          % las declaradas (luis y carmen: ninguna)

contacto(ana,   '664-555-0101').
contacto(luis,  '664-555-0177').
contacto(pedro, '664-555-0190').
% carmen: sin teléfono registrado

% medico(Medico, Nombre, Cedula)  — cédulas de ejemplo, no reales
medico(dra_ruiz, 'Dra. Elena Ruiz',  'CED-0000001').
medico(dr_soto,  'Dr. Marco Soto',   'CED-0000002').

% --------------------------------------------------------------- recetas
% receta(Receta, Paciente, Medico, Tipo, Med, Cantidad)   Tipo: comun | especial
% evento_receta(Receta, Evento, Sucursal, Dia)
%   Evento: emitida | surtida(N) | retenida | devuelta
% folio_especial(Receta, Folio): registro de la receta especial (controlados)

% Situación 1 — recetas de controlado y la otra sucursal
receta(r101, luis,   dr_soto,  comun,    clonazepam_2,     1).   % controlado en receta común
evento_receta(r101, emitida, centro, 198).
receta(r102, carmen, dr_soto,  comun,    azitromicina_500, 1).   % misma clase de receta, med con receta
evento_receta(r102, emitida, centro, 198).
receta(r103, luis,   dr_soto,  especial, clonazepam_2,     1).   % especial y firmada…
evento_receta(r103, emitida, centro, 199).
folio_especial(r103, 'F-2026-0103').
receta(r104, ana,    dr_soto,  especial, tramadol_50,      1).   % ya se surtió en Otay
evento_receta(r104, emitida, otay, 194).
folio_especial(r104, 'F-2026-0104').
evento_receta(r104, surtida(1), otay, 195).
evento_receta(r104, retenida,   otay, 195).

% Situación 2 — antibiótico surtido en dos visitas
receta(r201, carmen, dra_ruiz, comun, amoxicilina_500, 4).       % 4 cajas
evento_receta(r201, emitida,    centro, 197).
evento_receta(r201, surtida(1), centro, 197).                     % primera visita: 1 caja

% Situación 4 — ventas con receta del lote que luego se retira
receta(r401, ana,    dra_ruiz, comun, omeprazol_20, 2).
evento_receta(r401, emitida,    centro, 190).
evento_receta(r401, surtida(2), centro, 190).
receta(r402, carmen, dr_soto,  comun, omeprazol_20, 1).
evento_receta(r402, emitida,    otay, 194).
evento_receta(r402, surtida(1), otay, 194).

% Situación 5 — alergia por principio activo, interacción y ficha faltante
receta(r501, ana,   dra_ruiz, comun, amoxil_500,       1).        % Amoxil = amoxicilina
evento_receta(r501, emitida, centro, 199).
receta(r504, luis,  dra_ruiz, comun, warfarina_5,      1).        % la surtió Otay hace 6 días
evento_receta(r504, emitida,    otay, 194).
evento_receta(r504, surtida(1), otay, 194).
receta(r505, pedro, dr_soto,  comun, azitromicina_500, 1).
evento_receta(r505, emitida, centro, 199).

% ---------------------------------------------------------------- ventas
% venta(Venta, Lote, Unidades, Comprador, Receta, Sucursal, Dia)
%   Comprador: paciente o desconocido · Receta: id o ninguna
venta(v401, l_omep_a, 2, ana,         r401,    centro, 190).
venta(v402, l_omep_a, 1, carmen,      r402,    otay,   194).
venta(v403, l_omep_a, 1, desconocido, ninguna, centro, 192).
venta(v404, l_omep_a, 3, desconocido, ninguna, centro, 195).
venta(v405, l_omep_a, 1, pedro,       ninguna, centro, 196).   % cliente con tarjeta
venta(v406, l_trama_a, 1, ana,        r104,    otay,   195).
venta(v501, l_warf_a, 1, luis,        r504,    otay,   194).
venta(v201, l_amox_a, 1, carmen,      r201,    centro, 197).

% ---------------------------------------------------------- devoluciones
% devolucion(Dev, Med, Lote, Estado, Dia)   Lote: id o desconocido · Estado: cerrada | abierta
devolucion(d1, omeprazol_20,    desconocido, cerrada, 199).   % etiqueta ilegible
devolucion(d2, omeprazol_20,    l_omep_b,    cerrada, 199).
devolucion(d3, paracetamol_500, l_para_b,    abierta, 199).
