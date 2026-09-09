#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Dive & Find - Otomatik Build ve Sürüm Yönetim Scripti
Platformlar: Windows Desktop, Linux, Android
"""

import os
import re
import sys
import time
import subprocess
from pathlib import Path

# ANSI Renk Kodları
C_RESET = "\033[0m"
C_BOLD = "\033[1m"
C_RED = "\033[91m"
C_GREEN = "\033[92m"
C_YELLOW = "\033[93m"
C_BLUE = "\033[94m"
C_CYAN = "\033[96m"

PROJECT_ROOT = Path(__file__).resolve().parent
EXPORT_PRESETS_FILE = PROJECT_ROOT / "export_presets.cfg"
MAIN_MENU_GD = PROJECT_ROOT / "Scripts" / "main_menu.gd"


def print_banner() -> None:
    print(f"\n{C_CYAN}{C_BOLD}===================================================={C_RESET}")
    print(f"{C_YELLOW}{C_BOLD}     🌊 DIVE & FIND - OTOMATİK BUILD HATTI 🚀       {C_RESET}")
    print(f"{C_CYAN}{C_BOLD}===================================================={C_RESET}\n")


def get_desktop_dir() -> Path:
    """Masaüstü yolunu xdg-user-dir veya varsayılan dizinlerden tespit eder."""
    try:
        res = subprocess.run(["xdg-user-dir", "DESKTOP"], capture_output=True, text=True, check=True)
        path_str = res.stdout.strip()
        if path_str and os.path.isdir(path_str):
            return Path(path_str)
    except Exception:
        pass

    home = Path.home()
    if (home / "Masaüstü").exists():
        return home / "Masaüstü"
    elif (home / "Desktop").exists():
        return home / "Desktop"
    return home / "Masaüstü"


def parse_export_presets() -> dict:
    """export_presets.cfg dosyasından mevcut Android version_code, version_name ve package adını çeker."""
    info = {
        "version_code": 1,
        "version_name": "1.0.0",
        "package_name": "com.smilegames.divefind"
    }
    if not EXPORT_PRESETS_FILE.exists():
        return info

    content = EXPORT_PRESETS_FILE.read_text(encoding="utf-8")

    code_m = re.search(r'version/code=(\d+)', content)
    if code_m:
        info["version_code"] = int(code_m.group(1))

    name_m = re.search(r'version/name="([^"]+)"', content)
    if name_m:
        info["version_name"] = name_m.group(1)

    pkg_m = re.search(r'package/unique_name="([^"]+)"', content)
    if pkg_m:
        info["package_name"] = pkg_m.group(1)

    return info


def update_android_preset(new_code: int, new_name: str, new_pkg: str) -> None:
    """export_presets.cfg içindeki Android ayarlarını günceller."""
    if not EXPORT_PRESETS_FILE.exists():
        print(f"{C_RED}Hata: export_presets.cfg bulunamadı!{C_RESET}")
        return

    content = EXPORT_PRESETS_FILE.read_text(encoding="utf-8")

    content = re.sub(r'version/code=\d+', f'version/code={new_code}', content)
    content = re.sub(r'version/name="[^"]*"', f'version/name="{new_name}"', content)
    content = re.sub(r'package/unique_name="[^"]*"', f'package/unique_name="{new_pkg}"', content)

    EXPORT_PRESETS_FILE.write_text(content, encoding="utf-8")
    print(f"{C_GREEN}✓ export_presets.cfg güncellendi:{C_RESET}")
    print(f"   • version/code = {new_code}")
    print(f"   • version/name = \"{new_name}\"")
    print(f"   • package/unique_name = \"{new_pkg}\"")


def update_main_menu_version(game_version_str: str) -> None:
    """Scripts/main_menu.gd içindeki @export var game_version değerini günceller."""
    if not MAIN_MENU_GD.exists():
        return

    content = MAIN_MENU_GD.read_text(encoding="utf-8")
    new_content = re.sub(
        r'@export var game_version:\s*String\s*=\s*"[^"]*"',
        f'@export var game_version: String = "{game_version_str}"',
        content
    )
    if new_content != content:
        MAIN_MENU_GD.write_text(new_content, encoding="utf-8")
        print(f"{C_GREEN}✓ main_menu.gd oyun içi sürüm metni güncellendi: \"{game_version_str}\"{C_RESET}")


def format_size(bytes_size: int) -> str:
    mb = bytes_size / (1024 * 1024)
    return f"{mb:.2f} MB"


def main():
    print_banner()

    # 1. Mevcut ayarları oku
    cfg_info = parse_export_presets()
    current_code = cfg_info["version_code"]
    current_pkg = cfg_info["package_name"]

    # 2. Model Serisi Girişi
    default_model = "PreAlpha"
    model_input = input(f"{C_BOLD}Model Serisi{C_RESET} [{default_model}]: ").strip()
    model_series = model_input if model_input else default_model

    # 3. Sürüm No Girişi
    ver_match = re.search(r'(\d+\.\d+(?:\.\d+)?)', cfg_info["version_name"])
    default_ver = ver_match.group(1) if ver_match else "1.6.2"
    ver_input = input(f"{C_BOLD}Sürüm Numarası{C_RESET} [{default_ver}]: ").strip()
    version_no = ver_input if ver_input else default_ver

    # 4. Android Version Code
    next_code = current_code + 1
    code_input = input(f"{C_BOLD}Android Sürüm Kodu (version_code){C_RESET} [Mevcut: {current_code} → Yeni: {next_code}]: ").strip()
    try:
        final_code = int(code_input) if code_input else next_code
    except ValueError:
        print(f"{C_YELLOW}Geçersiz sayı, varsayılan {next_code} kullanılıyor.{C_RESET}")
        final_code = next_code

    # 5. Android Package Name
    pkg_input = input(f"{C_BOLD}Android Paket Adı{C_RESET} [{current_pkg}]: ").strip()
    final_pkg = pkg_input if pkg_input else current_pkg

    # 6. Platform Seçimi
    print(f"\n{C_BOLD}Hangi platformlar derlensin?{C_RESET}")
    print("  [1] Windows Desktop (.exe)")
    print("  [2] Linux (.x86_64)")
    print("  [3] Android (.apk)")
    print(f"  {C_GREEN}[4] Tümü (Windows + Linux + Android){C_RESET} (Varsayılan)")
    platform_choice = input(f"Seçiminiz [1/2/3/4]: ").strip()
    if platform_choice not in ["1", "2", "3", "4"]:
        platform_choice = "4"

    # 7. Derleme Türü
    build_type_input = input(f"\n{C_BOLD}Derleme Türü{C_RESET} ([R]elease / [D]ebug) [R]: ").strip().lower()
    is_debug = build_type_input.startswith("d")
    export_flag = "--export-debug" if is_debug else "--export-release"
    mode_name = "DEBUG" if is_debug else "RELEASE"

    # Klasör ve Dosya İsimlendirme
    folder_name = f"{model_series}_{version_no}"
    desktop_dir = get_desktop_dir()
    target_dir = desktop_dir / folder_name
    target_dir.mkdir(parents=True, exist_ok=True)

    formatted_version_name = f"{model_series} {version_no}"
    menu_version_str = f"{model_series} {version_no} (Afterjam Remaster)"

    # Özet Bilgi Gösterimi
    print(f"\n{C_CYAN}{C_BOLD}--- DERLEME ÖZETİ ---{C_RESET}")
    print(f"  • Model Serisi  : {C_BOLD}{model_series}{C_RESET}")
    print(f"  • Sürüm No      : {C_BOLD}{version_no}{C_RESET}")
    print(f"  • Android Kod   : {C_BOLD}{final_code}{C_RESET} (Önceki: {current_code})")
    print(f"  • Android Paket : {C_BOLD}{final_pkg}{C_RESET}")
    print(f"  • Mod           : {C_BOLD}{mode_name}{C_RESET}")
    print(f"  • Hedef Klasör  : {C_YELLOW}{target_dir}{C_RESET}")
    print(f"{C_CYAN}-----------------------{C_RESET}\n")

    confirm = input(f"{C_BOLD}Derleme başlatılsın mı? [E/h]: {C_RESET}").strip().lower()
    if confirm and not confirm.startswith("e") and not confirm.startswith("y"):
        print(f"{C_YELLOW}İşlem iptal edildi.{C_RESET}")
        sys.exit(0)

    # Config Güncellemeleri
    print(f"\n{C_BLUE}Config dosyaları güncelleniyor...{C_RESET}")
    update_android_preset(final_code, formatted_version_name, final_pkg)
    update_main_menu_version(menu_version_str)

    # Derlenecek Görevler
    tasks = []
    if platform_choice in ["1", "4"]:
        out_win = target_dir / f"DiveFind_{model_series}_{version_no}_Windows.exe"
        tasks.append(("Windows Desktop", out_win, "Windows"))
    if platform_choice in ["2", "4"]:
        out_linux = target_dir / f"DiveFind_{model_series}_{version_no}_Linux.x86_64"
        tasks.append(("Linux", out_linux, "Linux"))
    if platform_choice in ["3", "4"]:
        out_android = target_dir / f"DiveFind_{model_series}_{version_no}_Android.apk"
        tasks.append(("Android", out_android, "Android"))

    # Derlemeleri Başlat
    total_start = time.time()
    successful_builds = []
    failed_builds = []

    for preset_name, out_path, label in tasks:
        print(f"\n{C_YELLOW}🔨 [{label}] Derleniyor...{C_RESET}")
        print(f"   Çıktı: {out_path.name}")
        cmd = [
            "godot",
            "--headless",
            export_flag,
            preset_name,
            str(out_path)
        ]

        t0 = time.time()
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            cwd=str(PROJECT_ROOT)
        )

        for line in iter(process.stdout.readline, ''):
            clean_line = line.strip()
            if clean_line.startswith("ERROR:") or clean_line.startswith("WARNING:"):
                print(f"   {C_RED}{clean_line}{C_RESET}")
            elif "Progress:" in clean_line or "Exporting" in clean_line:
                print(f"   {clean_line}", end="\r", flush=True)

        process.wait()
        elapsed = time.time() - t0

        if process.returncode == 0 and out_path.exists():
            file_size = format_size(out_path.stat().st_size)
            print(f"\n{C_GREEN}✓ [{label}] Başarıyla tamamlandı! ({elapsed:.1f}s, {file_size}){C_RESET}")
            successful_builds.append((label, out_path, file_size))
        else:
            print(f"\n{C_RED}✗ [{label}] HATA: Derleme başarısız oldu! (Return code: {process.returncode}){C_RESET}")
            failed_builds.append((label, out_path))

    total_elapsed = time.time() - total_start

    # Final Raporu
    print(f"\n{C_CYAN}{C_BOLD}===================================================={C_RESET}")
    print(f"{C_BOLD}DERLEME RAPORU (Toplam Süre: {total_elapsed:.1f}s){C_RESET}")
    print(f"Klasör: {C_YELLOW}{target_dir}{C_RESET}\n")

    for label, path, size in successful_builds:
        print(f"  {C_GREEN}✓ {label:<15}{C_RESET}: {path.name} ({size})")

    for label, path in failed_builds:
        print(f"  {C_RED}✗ {label:<15}{C_RESET}: BAŞARISIZ!")

    print(f"{C_CYAN}{C_BOLD}===================================================={C_RESET}\n")


if __name__ == "__main__":
    main()
