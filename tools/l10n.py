"""Localization (gettext): the English text in the code is the message id, locale/es.po holds the Spanish.

    python tools/l10n.py extract       -> locale/laaf.pot from the code + the world signs, merged into locale/es.po
                                          (translations kept, new ids added empty, gone ones dropped and listed)
    python tools/l10n.py check         -> exit 1 if a message has no Spanish, or its placeholders / key letters
                                          differ (also run by tests/l10n_test.gd, from inside Godot)
    python tools/l10n.py count         -> messages per source file
    python tools/l10n.py merge FILE..  -> fills es.po from translation memory files (blocks of "EN: ..." / "ES: ..."
                                          lines, optional "CTX: ..."; \\n for a line break)

What is a message: every string literal in the game's scripts (scripts/, player/) that reads as text, i.e. not an
id (lower-case word, path, node / bone / class name). IGNORE below lists the literals that look like text but are
never shown; FILES_SKIPPED the scripts with no visible text. tr("text", "context") gives a message a context, for
the same English that needs different Spanish. The game translates at the point it shows text (hud.gd's subtitle,
banner, note, objective, prompt; the menus; the minigames), so its state, saves and tests keep the English ids.
World signs: every Label3D in maps/hollowmere.tscn that build_assets.py lets translate (auto_translate_mode not 2).
"""
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
POT = os.path.join(ROOT, "locale", "laaf.pot")
PO = os.path.join(ROOT, "locale", "es.po")
SOURCES = ["scripts", "player"]
FILES_SKIPPED = {"humanoid_anim.gd", "actor.gd", "icons.gd", "item_fx.gd", "arrow.gd", "spin.gd", "zone.gd",
                 "flicker.gd", "weather.gd", "feel.gd", "fuel_barrel.gd", "gas_cloud.gd", "smoke_cloud.gd", "threat_arcs.gd",
                 "hud_eyes.gd", "alert_icon.gd", "g.gd", "snd.gd", "audio.gd", "menu_draw.gd"}  # (audio.gd: bus names, the
# sound captions' keywords, matched against the English id and never shown)
SCENES = ["maps/hollowmere.tscn"]
BS = chr(92)

# literals that read like text but never reach the screen: node / class / bone / bus names, keys, glyph art
IGNORE = {
    "Node3D", "WorldEnvironment", "Moon", "Weather", "OmniLight3D", "Light3D", "MeshInstance3D", "GeometryInstance3D",
    "CPUParticles3D", "Button", "Label", "HUD", "Guide", "Chapter1", "Chapter2", "Chapter3", "Player", "Body",
    "Props/Boss", "HandL", "HandR", "Head", "Spine", "Headlamp", "Model", "Anim", "SFX", "Voice", "Master", "Game",
    "Audio", "L", "R", "*", "#loop", ".!?", ",;:—-…", "áàä", "éè", "íì", "óò", "%s %s", "[i]%s[/i]",
    "[b][color=#%s]%s:[/color][/b] %s", "%d / %d", "%s ×%d [%s]", "[%d %s]", "%d %s", "%d. %s", "~#%*=:/" + BS * 2,
    "A", "J", "Q", "K", "G", "T", "H", "E", "N", "<", ">", "+", "x", "?", "!", "#", "—", "♪", "MHz", "%d·%d", "~#%*=:/" + BS,
    "×%.2f", "×%.1f", "%d%%", "%3d%%", "%.1f×", "  %3d%%", "■", "□", "LAAF", "HOLLOWMERE", "English", "Español",
    "Marked Man", "Marked Woman", "marked one", "lucía", "tomás", "I", "II", "III", "…", " · ", "— ", "  · ", "> ",
    " ▶ ", "ENTER", "ESC", "TAB", "Y", "B", "A D", "W S", "W A S D", "%s · %s", "%s · %s · %s · %s", "Mark",
    "(@)", "Hand", "Brand", "ShepLamp", "Saved",  # (hud.gd: the save sound for "Saved." notes; the note itself is its own message)
    "Q E", "X", "F", "%d · %d", "%d × %d", "×%d", "%d / 3", "#%d", "???",  # (inventory.gd: keycaps, counts)
    "Ch.%d · %s",  # (a save's "label", kept in English for older builds; the menus show "objective" translated)
    # Moth Run's high-score table and marquee: names and title as the arcade cabinet has them
    "LILY V.", "TOMAS R.", "SAM K.", "LUCIA M.", "OWEN B.", "NORA H.", "GRADY", "M O T H   R U N",
}
IGNORE_PREFIX = ("--",)
IGNORE_CALLS = ("_plate(",)  # radio_tuning.gd: what's printed on the set itself stays in its English
ID = re.compile(r"[a-z0-9_./:%-]*")
SHADER = "shader_type"


def literals(src):
    """(line, text, start, end) for every string literal (comments skipped)."""
    i, n, line = 0, len(src), 1
    out = []
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c == "#":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c in "\"'":
            q = c
            triple = src[i:i + 3] == q * 3
            start_line = line
            j = i + (3 if triple else 1)
            buf = []
            while j < n:
                if src[j] == BS:
                    buf.append(src[j:j + 2])
                    j += 2
                    continue
                if triple and src[j:j + 3] == q * 3:
                    j += 3
                    break
                if not triple and src[j] == q:
                    j += 1
                    break
                if src[j] == "\n":
                    line += 1
                buf.append(src[j])
                j += 1
            prefix = src[i - 1] if i > 0 else ""
            if prefix not in "&^$%":  # (StringName / NodePath / $Node literals)
                out.append((start_line, unescape("".join(buf)), i, j))
            i = j
            continue
        i += 1
    return out


def unescape(s):
    out, i = [], 0
    while i < len(s):
        if s[i] == BS and i + 1 < len(s):
            k = s[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "'": "'", BS: BS}.get(k, BS + k))
            i += 2
        else:
            out.append(s[i])
            i += 1
    return "".join(out)


def is_text(s):
    if not s.strip() or s in IGNORE or s.startswith(IGNORE_PREFIX) or SHADER in s:
        return False
    if s.startswith(("res://", "user://")) or ID.fullmatch(s):
        return False
    return True


CALL = re.compile(r"(?:\btr|TranslationServer\.translate|\btr_n|TranslationServer\.translate_plural)\(\s*$")


def scan_gd(path, rel):
    """[(ctx, msgid, plural, ref)] for one script."""
    src = open(path, encoding="utf-8").read()
    lits = literals(src)
    out = []
    skip = set()
    for k, (line, s, a, b) in enumerate(lits):
        if k in skip:
            continue
        before = src[max(0, a - 40):a]
        m = CALL.search(before)
        ctx, plural = "", None
        if m:
            name = m.group(0)
            if "_n(" in name or "plural(" in name:  # tr_n("one", "many", n, ctx)
                if k + 1 < len(lits) and re.fullmatch(r"\s*,\s*", src[b:lits[k + 1][2]]):
                    plural = lits[k + 1][1]
                    skip.add(k + 1)
                    nxt = k + 2
                    tail = src[lits[k + 1][3]:]
                    mm = re.match(r"\s*,\s*[^,()]+,\s*\"([^\"]*)\"\s*\)", tail)
                    if mm:
                        ctx = mm.group(1)
                        for kk in range(nxt, min(nxt + 1, len(lits))):
                            skip.add(kk)
            else:  # tr("text", "context")
                if k + 1 < len(lits) and re.fullmatch(r"\s*,\s*", src[b:lits[k + 1][2]]) \
                        and src[lits[k + 1][3]:].lstrip().startswith(")"):
                    ctx = lits[k + 1][1]
                    skip.add(k + 1)
        line_start = src.rfind(chr(10), 0, a) + 1
        if not m and any(c in src[line_start:a] for c in IGNORE_CALLS):
            continue
        if m or is_text(s):
            if not s.strip():
                continue
            out.append((ctx, s, plural, "%s:%d" % (rel, line)))
    return out


LABEL = re.compile(r'\[node name="[^"]*" type="Label3D"[^\]]*\]\n((?:[^\[\n][^\n]*\n)*)')
ZONE = re.compile(r'^zone_name = "((?:[^"' + BS * 2 + r']|' + BS * 2 + r'.)*)"', re.M)


def scan_scene(path, rel):
    src = open(path, encoding="utf-8").read()
    out = []
    for m in LABEL.finditer(src):
        body = m.group(1)
        if re.search(r"^auto_translate_mode = 2$", body, re.M):
            continue
        t = re.search(r'^text = "((?:[^"' + BS * 2 + r']|' + BS * 2 + r'.)*)"$', body, re.M)
        if t:
            line = src.count("\n", 0, m.start()) + 1
            out.append(("", unescape(t.group(1)), None, "%s:%d" % (rel, line)))
    return out


def extract():
    """[(ctx, msgid, plural, [refs])] in source order, merged by (ctx, msgid)."""
    found = {}
    order = []
    files = []
    for d in SOURCES:
        for f in sorted(os.listdir(os.path.join(ROOT, d))):
            if f.endswith(".gd") and f not in FILES_SKIPPED:
                files.append((os.path.join(ROOT, d, f), "%s/%s" % (d, f), scan_gd))
    for s in SCENES:
        files.append((os.path.join(ROOT, s), s, scan_scene))
    for path, rel, fn in files:
        for ctx, msgid, plural, ref in fn(path, rel):
            key = (ctx, msgid)
            if key not in found:
                found[key] = [ctx, msgid, plural, []]
                order.append(key)
            found[key][3].append(ref)
            if plural and not found[key][2]:
                found[key][2] = plural
    return [found[k] for k in order]


# ------------------------------------------------------------------ .po files

def po_quote(s):
    s = s.replace(BS, BS * 2).replace('"', BS + '"').replace("\t", BS + "t")
    if "\n" in s and s != "\n":
        parts = s.split("\n")
        lines = [p + BS + "n" for p in parts[:-1]] + ([parts[-1]] if parts[-1] else [])
        return '""\n' + "\n".join('"%s"' % p for p in lines)
    return '"%s"' % s.replace("\n", BS + "n")


def po_unquote(lines):
    s = "".join(l[1:-1] for l in lines)
    return unescape(s)


def read_po(path):
    """{(ctx, msgid): {"str": [msgstr...], "plural": msgid_plural}} (header skipped)."""
    entries = {}
    if not os.path.exists(path):
        return entries
    cur = {}
    field = None

    def flush():
        if "msgid" in cur and cur["msgid"] != "":
            entries[(cur.get("msgctxt", ""), cur["msgid"])] = {"str": cur.get("msgstr", [""]),
                                                               "plural": cur.get("msgid_plural")}

    buf = []

    def end_field():
        nonlocal buf
        if field is None:
            return
        val = po_unquote(buf)
        if field.startswith("msgstr["):
            cur.setdefault("msgstr", [])
            idx = int(field[7:-1])
            while len(cur["msgstr"]) <= idx:
                cur["msgstr"].append("")
            cur["msgstr"][idx] = val
        elif field == "msgstr":
            cur["msgstr"] = [val]
        else:
            cur[field] = val
        buf = []

    for raw in open(path, encoding="utf-8").read().split("\n"):
        line = raw.strip()
        if line.startswith("#") or line == "":
            if line == "" or line.startswith("#~"):
                end_field()
                field = None
                if line == "":
                    flush()
                    cur = {}
            continue
        if line.startswith('"'):
            buf.append(line)
            continue
        end_field()
        key, _, rest = line.partition(" ")
        field = key
        buf = [rest.strip()]
    end_field()
    flush()
    return entries


HEADER = '''msgid ""
msgstr ""
"Project-Id-Version: LAAF\\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8-bit\\n"
"Language: %s\\n"
"Plural-Forms: nplurals=2; plural=(n != 1);\\n"
'''


def write_po(path, msgs, old, lang):
    out = [HEADER % lang]
    for ctx, msgid, plural, refs in msgs:
        out.append("")
        out.append("#: " + " ".join(refs[:6]) + (" …" if len(refs) > 6 else ""))
        if ctx:
            out.append("msgctxt " + po_quote(ctx))
        out.append("msgid " + po_quote(msgid))
        prev = old.get((ctx, msgid), {}).get("str", [""]) if old is not None else [""]
        if plural:
            out.append("msgid_plural " + po_quote(plural))
            for i in range(2):
                out.append("msgstr[%d] %s" % (i, po_quote(prev[i] if i < len(prev) else "")))
        else:
            out.append("msgstr " + po_quote(prev[0] if prev else ""))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")


# ------------------------------------------------------------------ checks

PLACEHOLDER = re.compile(r"%(?:%|[-+ 0#]*\d*(?:\.\d+)?[sdfxXcov])")
KEYCAP = re.compile(r"[\[(]([A-Z]|[A-Z]/[A-Z]|Esc|Shift|Space|Tab|Enter)[\])]")
BBCODE = re.compile(r"\[/?[a-z]+[^\]]*\]")


def problems(msgid, msgstr):
    out = []
    if not msgstr.strip():
        return ["no Spanish"]
    if sorted(PLACEHOLDER.findall(msgid)) != sorted(PLACEHOLDER.findall(msgstr)):
        out.append("placeholders %s vs %s" % (PLACEHOLDER.findall(msgid), PLACEHOLDER.findall(msgstr)))
    if sorted(KEYCAP.findall(msgid)) != sorted(KEYCAP.findall(msgstr)):
        out.append("key letters %s vs %s" % (KEYCAP.findall(msgid), KEYCAP.findall(msgstr)))
    if sorted(BBCODE.findall(msgid)) != sorted(BBCODE.findall(msgstr)):
        out.append("bbcode %s vs %s" % (BBCODE.findall(msgid), BBCODE.findall(msgstr)))
    if msgid.count("\n") != msgstr.count("\n") and msgid.count("\n") > 0:
        out.append("line breaks %d vs %d" % (msgid.count("\n"), msgstr.count("\n")))
    return out


def check():
    msgs = extract()
    po = read_po(PO)
    bad = 0
    for ctx, msgid, plural, refs in msgs:
        e = po.get((ctx, msgid))
        if not e:
            print("MISSING  %s  %r" % (refs[0], msgid))
            bad += 1
            continue
        for i, s in enumerate(e["str"]):
            for p in problems(plural if (plural and i > 0) else msgid, s):
                print("BAD  %s  %r: %s" % (refs[0], msgid, p))
                bad += 1
    # a Spanish text that is itself another message's id would be translated twice where a Label translates
    # what it's handed (it holds the Spanish already): it has to translate to itself
    es = {m: e["str"][0] for (c, m), e in po.items() if not c and e["str"][0]}
    for m, s in es.items():
        if s != m and s in es and es[s] != s:
            print("BAD  %r -> %r, itself the id of %r" % (m, s, es[s]))
            bad += 1
    print("%d messages, %d problems" % (len(msgs), bad))
    return bad


def count():
    msgs = extract()
    per = {}
    for ctx, msgid, plural, refs in msgs:
        f = refs[0].rsplit(":", 1)[0]
        per[f] = per.get(f, 0) + 1
    for f in sorted(per):
        print("%5d  %s" % (per[f], f))
    print("%5d  total" % len(msgs))


def merge(files):
    po = read_po(PO)
    mem = {}
    for path in files:
        ctx, en = "", None
        for raw in open(path, encoding="utf-8").read().split("\n"):
            if raw.startswith("CTX: "):
                ctx = raw[5:]
            elif raw.startswith("EN: "):
                en = raw[4:].replace(BS + "n", "\n")
            elif raw.startswith("ES: ") and en is not None:
                mem[(ctx, en)] = raw[4:].replace(BS + "n", "\n")
                ctx, en = "", None
            elif raw.startswith("ES1: ") and en is not None:  # plural forms
                mem[(ctx, en)] = [mem.pop((ctx, en), raw[5:]), raw[5:]] if False else [raw[5:]]
            elif raw.startswith("ES2: ") and en is not None:
                v = mem.get((ctx, en), [""])
                mem[(ctx, en)] = (v if isinstance(v, list) else [v]) + [raw[5:]]
                ctx, en = "", None
    filled, unknown = 0, []
    for key, val in mem.items():
        if key in po:
            po[key]["str"] = val if isinstance(val, list) else [val]
            filled += 1
        else:
            unknown.append(key)
    write_po(PO, [[c, m, po[(c, m)]["plural"], ["?"]] for (c, m) in po], po, "es")
    extract_and_write(quiet=True)  # (puts the references back)
    for k in unknown:
        print("not a message in the code:", k)
    print("filled %d, %d unknown" % (filled, len(unknown)))


def extract_and_write(quiet=False):
    msgs = extract()
    old = read_po(PO)
    write_po(POT, msgs, None, "")
    write_po(PO, msgs, old, "es")
    gone = [k for k in old if k not in {(c, m) for c, m, _, _ in msgs}]
    if not quiet:
        for k in gone:
            print("dropped (no longer in the code):", k)
        print("%d messages -> %s, %s" % (len(msgs), os.path.relpath(POT, ROOT), os.path.relpath(PO, ROOT)))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "extract"
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if cmd == "extract":
        extract_and_write()
    elif cmd == "check":
        sys.exit(1 if check() else 0)
    elif cmd == "count":
        count()
    elif cmd == "merge":
        merge(sys.argv[2:])
    else:
        print(__doc__)
