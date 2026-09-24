#!/usr/bin/env python3
"""Cruza tus PRs mergeados con el tiempo que les dedicaste.

No existe un registro de "este rato fue para este PR", así que se reparte: de
cada día se toman las horas que trabajaste en ese proyecto y se dividen entre
los PRs cuyos commits son de ese día. Es una aproximación, y es honesta —
cuando en un día entran cuatro PRs, cada uno se lleva la cuarta parte.

Lo usan claude-pr y claude-ritmo. Los repos salen de tus propias sesiones: los
proyectos donde más trabajaste, o los que pongas en PR_REPOS.
"""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timedelta

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import tx  # noqa: E402


def repos_desde_sesiones(desde: datetime, minimo: float = 10.0) -> dict:
    """{ruta del repo: nombre} de los proyectos donde realmente trabajaste."""
    minutos = defaultdict(float)
    for s in tx.sesiones(desde):
        if s["cwd"]:
            minutos[s["cwd"]] += s["minutos"]
    repos = {}
    for cwd, m in minutos.items():
        if m < minimo:
            continue
        raiz = _raiz_git(cwd)
        if raiz:
            repos[raiz] = pathlib.Path(raiz).name
    return repos


def _raiz_git(cwd: str) -> str:
    try:
        r = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True)
        return r.stdout.strip()
    except OSError:
        return ""


def prs_mergeados(repo: str, dias: int) -> list:
    """Los PRs mergeados del repo en los últimos N días, con sus fechas."""
    desde = (datetime.now().astimezone() - timedelta(days=dias)).date().isoformat()
    try:
        r = subprocess.run(
            ["gh", "pr", "list", "-R", _slug(repo), "--state", "merged", "--limit", "80",
             "--json", "number,title,createdAt,mergedAt,additions,deletions,author"],
            capture_output=True, text=True)
        datos = json.loads(r.stdout or "[]")
    except (OSError, json.JSONDecodeError):
        return []
    salida = []
    for p in datos:
        if not p.get("mergedAt") or p["mergedAt"][:10] < desde:
            continue
        p["dias_de_trabajo"] = _dias_de_commits(repo, p["number"])
        p["horas_abierto"] = _horas(p["createdAt"], p["mergedAt"])
        salida.append(p)
    return salida


def _slug(repo: str) -> str:
    try:
        r = subprocess.run(["git", "-C", repo, "remote", "get-url", "origin"],
                           capture_output=True, text=True)
        u = r.stdout.strip()
        return u.split("github.com")[-1].lstrip(":/").removesuffix(".git")
    except OSError:
        return ""


def _dias_de_commits(repo: str, numero: int) -> list:
    try:
        r = subprocess.run(["gh", "pr", "view", str(numero), "-R", _slug(repo),
                            "--json", "commits"], capture_output=True, text=True)
        commits = json.loads(r.stdout or "{}").get("commits", [])
    except (OSError, json.JSONDecodeError):
        return []
    return sorted({c["committedDate"][:10] for c in commits if c.get("committedDate")})


def _horas(a: str, b: str) -> float:
    try:
        ta = datetime.fromisoformat(a.replace("Z", "+00:00"))
        tb = datetime.fromisoformat(b.replace("Z", "+00:00"))
        return round((tb - ta).total_seconds() / 3600, 1)
    except ValueError:
        return 0.0


def tiempo_por_dia(desde: datetime) -> dict:
    """{(proyecto, día): {min, prompts}} de tus sesiones."""
    out = defaultdict(lambda: {"min": 0.0, "pr": 0})
    for s in tx.sesiones(desde):
        d = out[(s["proyecto"], s["dia"])]
        d["min"] += s["minutos"]; d["pr"] += s["prompts"]
    return out


def repartir(repos: dict, dias: int) -> list:
    """Un registro por PR, con el tiempo que le tocó."""
    desde = (datetime.now().astimezone() - timedelta(days=dias + 7)).replace(
        hour=0, minute=0, second=0, microsecond=0)
    tiempos = tiempo_por_dia(desde)

    todos = []
    for ruta, nombre in repos.items():
        for p in prs_mergeados(ruta, dias):
            p["proyecto"] = nombre
            todos.append(p)

    # Cuántos PRs se tocaron cada día, por proyecto: eso es el divisor.
    cuantos = defaultdict(int)
    for p in todos:
        for d in p["dias_de_trabajo"]:
            cuantos[(p["proyecto"], d)] += 1

    for p in todos:
        minutos = prompts = 0.0
        for d in p["dias_de_trabajo"]:
            t = tiempos.get((p["proyecto"], d))
            if not t:
                continue
            n = cuantos[(p["proyecto"], d)] or 1
            minutos += t["min"] / n
            prompts += t["pr"] / n
        p["minutos"] = round(minutos, 1)
        p["prompts"] = int(prompts)
    return todos
