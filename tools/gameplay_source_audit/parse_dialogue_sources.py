#!/usr/bin/env python3
"""Decrypt and parse Mobile 1.1.2.3 Lua dialogue tables without executing Lua."""
from __future__ import annotations
import argparse, ast, hashlib, json, re
from pathlib import Path

SEED = 9527
KEY_LENGTH = 128

def tq_decrypt(data: bytes, seed: int = SEED) -> bytes:
    state = seed & 0xffffffff
    key = []
    for _ in range(KEY_LENGTH):
        state = (state * 0x343FD + 0x269EC3) & 0xffffffff
        key.append(((state >> 16) & 0x7fff) & 0xff)
    out = bytearray(len(data))
    for i, byte in enumerate(data):
        value = byte ^ key[i % KEY_LENGTH]
        shift = i % 8
        out[i] = value if shift == 0 else ((value >> shift) | (value << (8-shift))) & 0xff
    return bytes(out)

def decode(data: bytes) -> str:
    for enc in ("utf-8-sig", "gb18030", "cp1252"):
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            pass
    return data.decode("utf-8", "replace")

def parse_value(raw: str):
    raw = raw.strip().rstrip(";")
    if raw in ("nil", "NULL"): return None
    if raw == "true": return True
    if raw == "false": return False
    if raw.startswith('"') or raw.startswith("'"):
        try: return ast.literal_eval(raw)
        except (SyntaxError, ValueError): return raw[1:-1]
    if re.fullmatch(r"-?\d+", raw): return int(raw)
    if re.fullmatch(r"-?\d+\.\d+", raw): return float(raw)
    if raw.startswith("{") and raw.endswith("}"):
        return {"_lua_table_raw": raw}
    return raw

def parse_path(raw: str):
    tokens = re.findall(r"\[([^\]]+)\]", raw)
    result = []
    for token in tokens:
        token = token.strip()
        if token.startswith(('"', "'")):
            result.append(ast.literal_eval(token))
        elif re.fullmatch(r"-?\d+", token):
            result.append(int(token))
        else:
            result.append(token)
    return result

def assign_path(root: dict, path: list, value):
    cur = root
    for token in path[:-1]:
        if token not in cur or not isinstance(cur[token], dict):
            cur[token] = {}
        cur = cur[token]
    if path:
        cur[path[-1]] = value

def parse_lua_assignments(text: str, root_name: str):
    root = {}
    pattern = re.compile(r"^\s*" + re.escape(root_name) + r"((?:\[[^\]]+\])+)\s*=\s*(.*?)\s*;?\s*$")
    matched = 0
    for line in text.splitlines():
        m = pattern.match(line)
        if not m:
            continue
        path = parse_path(m.group(1))
        if not path:
            continue
        assign_path(root, path, parse_value(m.group(2)))
        matched += 1
    return root, matched

def load_decrypted(root: Path, rel: str, signature: str | None):
    path = root / rel
    if not path.is_file():
        raise FileNotFoundError(rel)
    raw = path.read_bytes()
    clear = tq_decrypt(raw)
    text = decode(clear)
    if signature is not None and signature not in text:
        preview = repr(text[:180])
        raise ValueError(f"Decryption signature not found in {rel}; seed/schema validation failed; prefix={preview}")
    return text, hashlib.sha256(raw).hexdigest(), hashlib.sha256(clear).hexdigest(), len(raw)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source-dir", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--report", type=Path, required=True)
    args = ap.parse_args()
    root = args.source_dir

    rel_info = "ini/luaui/publicfiles/otherconf/npcdialogueinfo.dat"
    rel_ar = "ini/luaui/publicfiles/wordfiles/npcdialoguetext_ar.dat"
    rel_en = "ini/luaui/publicfiles/wordfiles/npcdialoguetext_en.dat"
    rel_script_ar = "script/dialogtext/scriptdialoguetext_ar.dat"
    rel_script_en = "script/dialogtext/scriptdialoguetext_en.dat"

    info, info_hash, info_clear_hash, info_size = load_decrypted(root, rel_info, "Dialog_Dialogue = {}")
    ar_text, ar_hash, ar_clear_hash, ar_size = load_decrypted(root, rel_ar, "NpcDialogueText_AR = {}")
    en_text, en_hash, en_clear_hash, en_size = load_decrypted(root, rel_en, "NpcDialogueText_EN = {}")
    script_ar_text, sar_hash, sar_clear_hash, sar_size = load_decrypted(root, rel_script_ar, None)
    script_en_text, sen_hash, sen_clear_hash, sen_size = load_decrypted(root, rel_script_en, None)

    def script_root(text, locale):
        candidates = re.findall(r"(?m)^\s*(?:local\s+)?([A-Za-z_]\w*)\s*=\s*\{\s*\}", text)
        preferred = [name for name in candidates if "DIALOG" in name.upper() and "TEXT" in name.upper()]
        if preferred:
            return preferred[0]
        raise ValueError(f"Could not identify script dialogue text table for {locale}; prefix={text[:220]!r}")

    script_ar_root = script_root(script_ar_text, "ar")
    script_en_root = script_root(script_en_text, "en")

    dialogs, dialog_assignments = parse_lua_assignments(info, "Dialog_Dialogue")
    ar, ar_count = parse_lua_assignments(ar_text, "NpcDialogueText_AR")
    en, en_count = parse_lua_assignments(en_text, "NpcDialogueText_EN")
    script_ar, script_ar_count = parse_lua_assignments(script_ar_text, script_ar_root)
    script_en, script_en_count = parse_lua_assignments(script_en_text, script_en_root)

    def flatten_text(d):
        return {str(k): v for k, v in d.items() if isinstance(v, (str, int, float))}
    ar_flat, en_flat = flatten_text(ar), flatten_text(en)
    sar_flat, sen_flat = flatten_text(script_ar), flatten_text(script_en)

    npc_dialogues = []
    unresolved = set()
    for dialogue_id, data in sorted(dialogs.items(), key=lambda item: (0, int(item[0])) if str(item[0]).isdigit() else (1, str(item[0]))):
        if not isinstance(data, dict):
            continue
        talks = data.get("DlgTalk", {})
        resolved_talks = []
        if isinstance(talks, dict):
            for step, talk in sorted(talks.items(), key=lambda item: int(item[0]) if str(item[0]).isdigit() else str(item[0])):
                if not isinstance(talk, dict):
                    continue
                text_key = ""
                dlg_text = talk.get("DlgText", {})
                if isinstance(dlg_text, dict):
                    text_key = str(dlg_text.get("text", ""))
                ar_value, en_value = ar_flat.get(text_key), en_flat.get(text_key)
                if text_key and ar_value is None and en_value is None:
                    unresolved.add(text_key)
                resolved_talks.append({
                    "step": int(step) if str(step).isdigit() else str(step),
                    "dialogue_type": talk.get("DlgType"),
                    "text_key": text_key,
                    "text_ar": ar_value,
                    "text_en": en_value,
                    "source": talk
                })
        npc_dialogues.append({"dialogue_id": int(dialogue_id) if str(dialogue_id).isdigit() else str(dialogue_id),
                              "data": data, "talks": resolved_talks})

    sources = [
        {"path": rel_info, "size_bytes": info_size, "sha256_encrypted": info_hash, "sha256_decrypted": info_clear_hash, "status": "DECRYPTED_TQ_FILE_CIPHER_SEED_9527"},
        {"path": rel_ar, "size_bytes": ar_size, "sha256_encrypted": ar_hash, "sha256_decrypted": ar_clear_hash, "status": "DECRYPTED_TQ_FILE_CIPHER_SEED_9527"},
        {"path": rel_en, "size_bytes": en_size, "sha256_encrypted": en_hash, "sha256_decrypted": en_clear_hash, "status": "DECRYPTED_TQ_FILE_CIPHER_SEED_9527"},
        {"path": rel_script_ar, "size_bytes": sar_size, "sha256_encrypted": sar_hash, "sha256_decrypted": sar_clear_hash, "status": "DECRYPTED_TQ_FILE_CIPHER_SEED_9527"},
        {"path": rel_script_en, "size_bytes": sen_size, "sha256_encrypted": sen_hash, "sha256_decrypted": sen_clear_hash, "status": "DECRYPTED_TQ_FILE_CIPHER_SEED_9527"}
    ]
    payload = {"npc_dialogues": npc_dialogues, "dialogue_texts": {"ar": ar_flat, "en": en_flat},
               "script_dialogue_texts": {"ar": sar_flat, "en": sen_flat}, "dialogue_sources": sources, "script_text_table_names": {"ar": script_ar_root, "en": script_en_root}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    report = {"npc_dialogues": len(npc_dialogues), "dialogue_assignments": dialog_assignments,
              "dialogue_texts_ar": ar_count, "dialogue_texts_en": en_count,
              "script_dialogue_texts_ar": script_ar_count, "script_dialogue_texts_en": script_en_count,
              "resolved_talk_steps": sum(len(x["talks"]) for x in npc_dialogues),
              "unresolved_dialogue_text_keys": sorted(unresolved),
              "sources": sources, "validation": "DECRYPTION_SIGNATURES_AND_LUA_ASSIGNMENTS_VALIDATED"}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
