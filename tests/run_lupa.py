#!/usr/bin/env python3
"""Запуск tests/run.lua через встроенный Lua 5.4 из пакета lupa.

Нужен, если в системе нет lua/luau: pip install lupa
Использование (из корня репозитория): python3 tests/run_lupa.py
"""
import os
import sys

from lupa import lua54

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = lua54.LuaRuntime(unpack_returned_tuples=True)
g = lua.globals()
g.arg = lua.table_from({0: "tests/run.lua", 1: root})

exit_code = {"code": 0}


def _exit(code=0):
    exit_code["code"] = 0 if code in (None, True) else (1 if code is False else int(code))


g.os.exit = _exit

# Список исходников для проверки синтаксиса
sources = []
for dirpath, _, files in os.walk(os.path.join(root, "src")):
    for name in sorted(files):
        if name.endswith(".lua"):
            sources.append(os.path.join(dirpath, name))
sources.sort()
g.SOURCE_FILES = lua.table_from(sources)

with open(os.path.join(root, "tests", "run.lua"), encoding="utf-8") as f:
    src = f.read()
lua.execute(src)
sys.exit(exit_code["code"])
