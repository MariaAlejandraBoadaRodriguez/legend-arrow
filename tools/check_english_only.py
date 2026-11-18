#!/usr/bin/env python3
"""English-only gate (owner decision D-41). Fails (exit 1) if anything that
ships in the app or the store listing contains a Spanish locale or Spanish text.

  python3 tools/check_english_only.py            # check the repository
  python3 tools/check_english_only.py --self-test # prove the check catches Spanish

What it checks
  1. Locale tables (locales/*.csv) have exactly the columns `keys,en`.
  2. project.godot lists only the English translation; no *.translation,
     *.po or *.mo files for another locale exist; no Android `values-es*`
     resource folders.
  3. No locale code "es" (or es_XX / es-XX) as a code literal in shipped code
     or data.
  4. Shipped text (strings, data, scenes, scripts, Android plugin, export
     presets, store listing files and their *file names*, privacy page) has no
     Spanish-only characters (n tilde, accented vowels, inverted marks) and
     no common Spanish words.
Stdlib only.
"""
import csv
import os
import re
import sys
import tempfile

# Shipped in the APK/AAB or shown on the Play listing.
SCAN_DIRS = ["locales", "data", "scenes", "scripts", "android/plugins/legend_ads/src",
             "addons/legend_ads", "docs/store"]
SCAN_FILES = ["project.godot", "export_presets.cfg", "docs/privacy.html"]
TEXT_EXT = {".csv", ".json", ".tscn", ".tres", ".gd", ".kt", ".java", ".xml", ".cfg",
            ".godot", ".md", ".txt", ".html", ".gdextension", ".gdshader"}
SKIP_PARTS = {"build", ".gradle", ".godot", "bin"}

SPANISH_CHARS = re.compile(r"[ñÑáéíóúÁÉÍÓÚüÜ¿¡]")
# Words that are Spanish and not English (UI, store and lore vocabulary).
SPANISH_WORDS = [
    "jugar", "juego", "bestiario", "ajustes", "configuracion", "idioma", "espanol",
    "criatura", "criaturas", "despierta", "despertar", "nivel", "niveles", "pista",
    "pistas", "deshacer", "reiniciar", "continuar", "salir", "sonido", "musica",
    "flechas", "flecha", "mundo", "mundos", "pulgadas", "capturas", "recursos",
    "grafico", "icono", "aplicacion", "telefono", "inicio", "volver", "cerrar",
    "privacidad", "politica", "anuncio", "anuncios", "dragon de", "dragones",
    "bosque", "tutorial completado", "siguiente", "atras", "ver anuncio", "gracias",
    "listo", "partida", "estrellas", "tiempo", "mejor", "nuevo record", "desbloquea",
    "desbloqueado", "bloqueado", "leyenda", "leyendas", "toca", "tocar", "aqui",
    "para", "pero", "porque", "tambien", "esta", "este", "estos", "nuestro", "nuestra",
    "usted", "puedes", "puede", "datos", "dispositivo", "ninguno", "ninguna",
]
WORD_RE = re.compile(r"(?<![A-Za-z])(" + "|".join(re.escape(w) for w in SPANISH_WORDS) + r")(?![A-Za-z])",
                     re.IGNORECASE)
# A Spanish locale code as a literal: "es", 'es', es_ES, es-419, values-es, .es.translation
LOCALE_RE = re.compile(r"""(["'])es([_-][A-Za-z0-9]{2,3})?\1|\bes[_-](ES|MX|AR|CO|US|419)\b|values-es\b|\.es\.translation""")

# English words the list would otherwise flag in English text (none today);
# keep explicit so a reviewer sees every exception.
ALLOW_LINES = re.compile(r"english-only:\s*allow", re.IGNORECASE)


def _iter_files(root):
    for rel in SCAN_FILES:
        p = os.path.join(root, rel)
        if os.path.isfile(p):
            yield rel
    for d in SCAN_DIRS:
        base = os.path.join(root, d)
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [x for x in dirnames if x not in SKIP_PARTS]
            for f in filenames:
                yield os.path.relpath(os.path.join(dirpath, f), root)


def check(root):
    problems = []

    # 1. locale tables
    for f in sorted(os.listdir(os.path.join(root, "locales"))) if os.path.isdir(os.path.join(root, "locales")) else []:
        if f.endswith(".csv"):
            with open(os.path.join(root, "locales", f), newline="", encoding="utf-8") as fh:
                header = next(csv.reader(fh), [])
            if header != ["keys", "en"]:
                problems.append(f"locales/{f}: columns {header}, expected ['keys', 'en']")

    # 2. translations / resource folders
    pg = os.path.join(root, "project.godot")
    if os.path.isfile(pg):
        for line in open(pg, encoding="utf-8"):
            if line.startswith("locale/translations="):
                for t in re.findall(r'"([^"]+)"', line):
                    if not t.endswith(".en.translation"):
                        problems.append(f"project.godot: non-English translation {t}")
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [x for x in dirnames if x not in {".git", ".godot", "build", ".gradle"}]
        rel = os.path.relpath(dirpath, root)
        if re.search(r"(^|/)values-es", rel):
            problems.append(f"{rel}: Spanish Android resource folder")
        for f in filenames:
            if re.search(r"\.(po|mo)$", f) or (f.endswith(".translation") and ".en." not in f):
                problems.append(f"{os.path.join(rel, f)}: non-English translation file")

    # 3 + 4. text and file names
    for rel in _iter_files(root):
        name = os.path.basename(rel)
        stem = re.sub(r"[_\-.]+", " ", os.path.splitext(name)[0])
        if SPANISH_CHARS.search(name) or WORD_RE.search(stem):
            problems.append(f"{rel}: Spanish file name")
        if os.path.splitext(name)[1].lower() not in TEXT_EXT:
            continue
        try:
            text = open(os.path.join(root, rel), encoding="utf-8").read()
        except UnicodeDecodeError:
            continue
        for n, line in enumerate(text.splitlines(), 1):
            if ALLOW_LINES.search(line):
                continue
            m = SPANISH_CHARS.search(line) or WORD_RE.search(_fold(line)) or LOCALE_RE.search(line)
            if m:
                problems.append(f"{rel}:{n}: Spanish text or locale ({m.group(0)!r}): {line.strip()[:100]}")
    return problems


def _fold(s):
    """Strip accents so 'música' and 'musica' both match."""
    return s.translate(str.maketrans("áéíóúÁÉÍÓÚñÑ", "aeiouAEIOUnN"))


def self_test():
    """Plants Spanish in a scratch tree and asserts each kind is caught."""
    cases = {
        "csv column": ("locales/strings.csv", "keys,en,es\nHOME_PLAY,Play,Jugar\n"),
        "accent": ("data/x.json", '{"name": "Dragón"}\n'),
        "word": ("scripts/a.gd", 'var t := "Bestiario"\n'),
        "locale literal": ("scripts/b.gd", 'TranslationServer.set_locale("es")\n'),
        "store file name": ("docs/store/03_Capturas_telefono.png", ""),
        "translation file": ("locales/strings.es.translation", ""),
        "android folder": ("android/plugins/legend_ads/src/main/res/values-es/strings.xml", "<resources/>\n"),
    }
    clean_csv = ("locales/strings.csv", "keys,en\nHOME_PLAY,Play\n")
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        def write(rel, body):
            p = os.path.join(tmp, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w", encoding="utf-8") as fh:
                fh.write(body)
        write(*clean_csv)
        if check(tmp):
            failures.append(f"clean tree flagged: {check(tmp)}")
        for label, (rel, body) in cases.items():
            write(*clean_csv)
            write(rel, body)
            if not check(tmp):
                failures.append(f"not caught: {label}")
            os.remove(os.path.join(tmp, rel))
    for f in failures:
        print("self-test FAIL:", f)
    print(f"english-only self-test: {'PASS' if not failures else 'FAIL'} ({len(cases)} planted cases + clean tree)")
    return 0 if not failures else 1


def main():
    if "--self-test" in sys.argv:
        return self_test()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    problems = check(root)
    for p in problems:
        print("FAIL", p)
    print(f"english-only: {'PASS' if not problems else 'FAIL'} ({len(problems)} problem(s))")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
