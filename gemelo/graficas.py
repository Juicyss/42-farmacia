"""Gráficas del gemelo digital de la farmacia (#42).

Este módulo NO decide nada: recibe listas que Prolog ya dedujo y solo las dibuja.
Prolog lo llama de dos formas (ver graficas.pl):
  * con Janus, dentro del mismo proceso:   py_call(graficas:caducidades(...), _)
  * sin Janus (Windows sin el componente): python graficas.py <funcion> <args.json>

Se usa la API de objetos de matplotlib (Figure, sin pyplot) para que funcione en un
servidor sin pantalla y desde varios hilos, igual que logicDemo2 del curso.
Colores del sistema de diseño «Clinical Precision» (Google Stitch).
"""

import json
import sys

from matplotlib.figure import Figure

FONDO = "#ffffff"
TEXTO = "#131b2e"
SUAVE = "#3f4945"
LINEA = "#bec9c4"
COLOR_ESTADO = {
    "disponible": "#0f6e5c",
    "por_caducar": "#5bb8fe",
    "vencido": "#ba1a1a",
    "retirado": "#93000a",
    "agotado": "#6f7975",
}


def _figura(titulo, ancho=9.0, alto=5.0):
    fig = Figure(figsize=(ancho, alto), facecolor=FONDO, layout="constrained")
    ax = fig.subplots()
    ax.set_facecolor(FONDO)
    ax.set_title(titulo, color=TEXTO, fontsize=13, loc="left", pad=12, fontweight="bold")
    ax.tick_params(colors=SUAVE, labelsize=9)
    for lado in ("top", "right"):
        ax.spines[lado].set_visible(False)
    for lado in ("bottom", "left"):
        ax.spines[lado].set_color(LINEA)
    return fig, ax


def caducidades(lotes, dias, unidades, estados, umbral, archivo):
    """Días que le quedan a cada lote (barra) y sus unidades (etiqueta).
    Prolog decide el estado de cada lote; aquí solo se colorea."""
    fig, ax = _figura("Lotes: días para caducar (Prolog deduce el estado)", 9, 0.42 * len(lotes) + 1.6)
    ys = list(range(len(lotes)))[::-1]
    colores = [COLOR_ESTADO.get(str(e), "#6f7975") for e in estados]
    ax.barh(ys, dias, color=colores, height=0.62)
    ax.set_yticks(ys, [str(l) for l in lotes])
    ax.axvline(0, color=TEXTO, linewidth=0.8)
    ax.axvline(umbral, color="#006398", linewidth=1, linestyle="--")
    ax.text(umbral, len(lotes) - 0.35, f"  caducidad cercana ({umbral} días)", color="#006398", fontsize=8)
    for y, d, u, e in zip(ys, dias, unidades, estados):
        etiqueta = f" {u} u · {str(e).replace('_', ' ')}"
        ax.text(max(d, 0) + 4, y, etiqueta, va="center", fontsize=8, color=SUAVE)
    ax.set_xlabel("días restantes (negativo = vencido)", color=SUAVE, fontsize=9)
    ax.set_xlim(min(min(dias), 0) - 20, max(dias) + 140)
    fig.savefig(archivo, dpi=120)
    return archivo


def recetas(ids, surtido, pendiente, estados, archivo):
    """Lo surtido frente a lo pendiente de cada receta."""
    fig, ax = _figura("Recetas: surtido vs. pendiente", 9, 4.6)
    xs = list(range(len(ids)))
    ax.bar(xs, surtido, color="#0f6e5c", label="surtido", width=0.6)
    ax.bar(xs, pendiente, bottom=surtido, color="#cfe7df", edgecolor="#0f6e5c",
           label="pendiente", width=0.6)
    ax.set_xticks(xs, [f"{i}\n{str(e).replace('_', ' ')}" for i, e in zip(ids, estados)], fontsize=8)
    ax.yaxis.get_major_locator().set_params(integer=True)
    ax.set_ylabel("unidades", color=SUAVE, fontsize=9)
    ax.legend(frameon=False, fontsize=9)
    fig.savefig(archivo, dpi=120)
    return archivo


def retiro(etiquetas, valores, colores, titulo, archivo):
    """Destino de las unidades de un lote retirado (Prolog arma la cadena)."""
    fig, ax = _figura(titulo, 9, 3.4)
    ys = list(range(len(etiquetas)))[::-1]
    ax.barh(ys, valores, color=colores, height=0.6)
    ax.set_yticks(ys, [str(e) for e in etiquetas])
    for y, v in zip(ys, valores):
        ax.text(v + 0.08, y, str(v), va="center", fontsize=9, color=TEXTO)
    ax.set_xlabel("unidades", color=SUAVE, fontsize=9)
    ax.xaxis.get_major_locator().set_params(integer=True)
    fig.savefig(archivo, dpi=120)
    return archivo


if __name__ == "__main__":
    # Modo proceso: python graficas.py <funcion> <args.json>
    funcion = globals()[sys.argv[1]]
    with open(sys.argv[2], encoding="utf-8") as f:
        args = json.load(f)["args"]
    print(funcion(*args))
