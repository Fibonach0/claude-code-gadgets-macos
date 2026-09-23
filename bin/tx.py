#!/usr/bin/env python3
"""Lee tus propias sesiones de Claude Code y las convierte en números.

Todo lo que hace este archivo sale de lo que Claude Code ya escribe en
~/.claude/projects/<carpeta>/<sesión>.jsonl. No manda nada a ningún lado.

Lo usan claude-horas, claude-panel, claude-diario y claude-buscar.

    python3 tx.py sesiones --desde 2026-09-01     # una línea JSON por sesión
    python3 tx.py dias --dias 14                  # totales por día y proyecto

El tiempo trabajado no se puede medir "de la primera a la última línea": una
sesión abierta toda la tarde con dos preguntas daría cuatro horas. Se suma el
tiempo ENTRE eventos consecutivos, y sólo cuando el hueco es corto (5 minutos
por defecto): si estuviste media hora sin escribir, esa media hora no se cuenta.
"""

from __future__ import annotations   # el python del sistema puede ser 3.9

import argparse
import json
import os
import pathlib
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone

RAIZ = pathlib.Path.home() / ".claude" / "projects"
HUECO = 300          # segundos: más que esto, no se cuenta como trabajo

# Precios de lista de la API, por millón de tokens (jun-2026). Sirven para
# estimar, NO para facturar: con suscripción no se paga por token.
# La escritura de caché son dos precios distintos según dure 5 minutos o 1 hora.
PRECIOS = {
    "opus":   {"in": 5.0,  "out": 25.0, "read": 0.50, "w5": 6.25,  "w1h": 10.0},
    "sonnet": {"in": 2.0,  "out": 10.0, "read": 0.20, "w5": 2.50,  "w1h": 4.0},
    "haiku":  {"in": 1.0,  "out": 5.0,  "read": 0.10, "w5": 1.25,  "w1h": 2.0},
}


def familia(modelo: str) -> str:
    m = (modelo or "").lower()
    for f in ("opus", "sonnet", "haiku", "fable"):
        if f in m:
            return "opus" if f == "fable" else f
    return "sonnet"


def costo(tok: dict, modelo: str) -> float:
    p = PRECIOS[familia(modelo)]
    return (tok["in"] * p["in"] + tok["out"] * p["out"] + tok["read"] * p["read"]
            + tok["w5"] * p["w5"] + tok["w1h"] * p["w1h"]) / 1_000_000


def _cuando(linea: dict):
    t = linea.get("timestamp")
    if not t:
        return None
    try:
        return datetime.fromisoformat(t.replace("Z", "+00:00")).astimezone()
    except ValueError:
        return None


def leer_sesion(archivo: pathlib.Path) -> dict | None:
    """Una sesión, resumida. None si el archivo no tiene nada aprovechable."""
    eventos, tokens, modelos = [], defaultdict(float), defaultdict(int)
    carpetas = defaultdict(int)
    cwd = primera = None
    prompts = 0
    try:
        with archivo.open(errors="ignore") as fh:
            for linea in fh:
                try:
                    o = json.loads(linea)
                except json.JSONDecodeError:
                    continue
                t = _cuando(o)
                if t:
                    eventos.append(t)
                # La carpeta de la sesión es la MÁS FRECUENTE, no la primera ni la
                # última: las sesiones suelen arrancar en el home y terminar donde
                # sea, y el proyecto real es donde se pasó el rato.
                if o.get("cwd"):
                    carpetas[o["cwd"]] += 1
                if o.get("type") == "user" and not o.get("isSidechain"):
                    prompts += 1
                    if primera is None:
                        c = o.get("message", {}).get("content")
                        if isinstance(c, str):
                            primera = c[:200]
                        elif isinstance(c, list) and c and isinstance(c[0], dict):
                            primera = (c[0].get("text") or "")[:200]
                if o.get("type") != "assistant":
                    continue
                msg = o.get("message", {})
                u = msg.get("usage") or {}
                modelos[msg.get("model") or "?"] += 1
                tokens["in"] += u.get("input_tokens", 0)
                tokens["out"] += u.get("output_tokens", 0)
                tokens["read"] += u.get("cache_read_input_tokens", 0)
                cc = u.get("cache_creation") or {}
                if cc:
                    tokens["w5"] += cc.get("ephemeral_5m_input_tokens", 0)
                    tokens["w1h"] += cc.get("ephemeral_1h_input_tokens", 0)
                else:
                    tokens["w5"] += u.get("cache_creation_input_tokens", 0)
    except OSError:
        return None
    if not eventos:
        return None

    eventos.sort()
    activo = sum(
        (b - a).total_seconds()
        for a, b in zip(eventos, eventos[1:])
        if (b - a).total_seconds() <= HUECO
    )
    modelo = max(modelos, key=modelos.get) if modelos else "?"
    cwd = max(carpetas, key=carpetas.get) if carpetas else ""
    proyecto = os.path.basename(cwd.rstrip("/")) if cwd else archivo.parent.name
    for k in ("in", "out", "read", "w5", "w1h"):
        tokens[k] = int(tokens[k])
    return {
        "sesion": archivo.stem,
        "proyecto": proyecto or "(sin nombre)",
        "cwd": cwd or "",
        "dia": eventos[0].strftime("%Y-%m-%d"),
        "desde": eventos[0].isoformat(timespec="seconds"),
        "hasta": eventos[-1].isoformat(timespec="seconds"),
        "minutos": round(activo / 60, 1),
        "prompts": prompts,
        "modelo": modelo,
        "tokens": dict(tokens),
        "costo": round(costo(tokens, modelo), 4),
        "tema": (primera or "").strip().replace("\n", " ")[:120],
        "archivo": str(archivo),
    }


def sesiones(desde: datetime | None = None, hasta: datetime | None = None):
    for archivo in sorted(RAIZ.glob("*/*.jsonl")):
        s = leer_sesion(archivo)
        if not s:
            continue
        d = datetime.fromisoformat(s["desde"])
        if desde and d < desde:
            continue
        if hasta and d > hasta:
            continue
        yield s


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("modo", choices=["sesiones", "dias"])
    ap.add_argument("--dias", type=int, default=0, help="últimos N días")
    ap.add_argument("--desde", default="", help="AAAA-MM-DD")
    a = ap.parse_args()

    desde = None
    if a.dias:
        desde = datetime.now(timezone.utc).astimezone() - timedelta(days=a.dias)
        desde = desde.replace(hour=0, minute=0, second=0, microsecond=0)
    elif a.desde:
        desde = datetime.fromisoformat(a.desde).astimezone()

    todas = list(sesiones(desde))
    if a.modo == "sesiones":
        for s in todas:
            print(json.dumps(s, ensure_ascii=False))
        return

    dias = defaultdict(lambda: defaultdict(lambda: {
        "minutos": 0.0, "costo": 0.0, "prompts": 0, "sesiones": 0,
        "tokens": defaultdict(int)}))
    for s in todas:
        d = dias[s["dia"]][s["proyecto"]]
        d["minutos"] += s["minutos"]
        d["costo"] += s["costo"]
        d["prompts"] += s["prompts"]
        d["sesiones"] += 1
        for k, v in s["tokens"].items():
            d["tokens"][k] += v
    salida = {dia: {p: {**v, "minutos": round(v["minutos"], 1),
                        "costo": round(v["costo"], 4), "tokens": dict(v["tokens"])}
                    for p, v in proys.items()}
              for dia, proys in dias.items()}
    json.dump(salida, sys.stdout, ensure_ascii=False, indent=1)
    print()


if __name__ == "__main__":
    main()
