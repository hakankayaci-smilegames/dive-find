#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Dive & Find - Localization String Extractor
Tüm arayüz (.tscn), ipuçları (.json) ve dinamik script (.gd) metinlerini tarar.
Eşyalar (all_items_tres) hariç tutulur.
"""

import os
import re
import json
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCENES_DIR = PROJECT_ROOT / "Scenes"
SCRIPTS_DIR = PROJECT_ROOT / "Scripts"
DATA_DIR = PROJECT_ROOT / "Data"
OUTPUT_FILE = PROJECT_ROOT / "Translations" / "extracted_strings.txt"

def is_meaningful_text(text: str) -> bool:
    """Teknik anahtarları, boşlukları ve salt sayıları eler."""
    t = text.strip()
    if not t:
        return False
    # Salt sayı veya boşluk
    if t.isdigit() or t in ["0", "1", "100", "%d", "%s", "x", "X"]:
        return False
    # Dosya yolları veya teknik ID'ler
    if t.startswith("res://") or t.startswith("uid://") or t.startswith("user://"):
        return False
    # Çok kısa semboller
    if len(t) <= 1 and not any(ord(c) > 127 for c in t):
        return False
    # BBCode renk etiketleri tek başına
    if t.startswith("#") and len(t) in [4, 7, 9]:
        return False
    return True

def extract_from_scenes():
    found = set()
    patterns = [
        re.compile(r'text\s*=\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
        re.compile(r'tooltip_text\s*=\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
        re.compile(r'placeholder_text\s*=\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    ]
    
    for tscn_path in SCENES_DIR.glob("**/*.tscn"):
        content = tscn_path.read_text(encoding="utf-8", errors="ignore")
        for pat in patterns:
            for m in pat.finditer(content):
                val = m.group(1).encode('utf-8').decode('unicode_escape', errors='ignore')
                val = val.replace('\\"', '"').replace('\\n', '\n').strip()
                if is_meaningful_text(val):
                    found.add(val)
    return found

def extract_from_loading_tips():
    found = set()
    tips_file = DATA_DIR / "loading_tips.json"
    if tips_file.exists():
        try:
            tips = json.loads(tips_file.read_text(encoding="utf-8"))
            if isinstance(tips, list):
                for tip in tips:
                    if isinstance(tip, str) and is_meaningful_text(tip):
                        found.add(tip.strip())
        except Exception as e:
            print("Loading tips okunurken hata:", e)
    return found

def main():
    strings = set()
    scene_strings = extract_from_scenes()
    tip_strings = extract_from_loading_tips()
    
    strings.update(scene_strings)
    strings.update(tip_strings)
    
    sorted_strings = sorted(list(strings))
    print(f"Toplam {len(sorted_strings)} benzersiz UI metni çıkarıldı.")
    
    OUTPUT_FILE.write_text("\n---\n".join(sorted_strings), encoding="utf-8")
    print(f"Sonuçlar kaydedildi: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
