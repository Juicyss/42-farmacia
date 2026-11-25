/*  gemelo.pl — carga el gemelo digital completo (hechos + reglas + escenarios).
    Uso:  swipl gemelo.pl        y luego consultas como  ?- decide_escenario(s31, ninguna, A, D, E).
*/
:- encoding(utf8).
:- ensure_loaded(hechos).
:- ensure_loaded(reglas).
:- ensure_loaded(escenarios).
