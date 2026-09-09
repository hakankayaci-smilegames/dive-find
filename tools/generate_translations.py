#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Dive & Find - Translations CSV Generator (Aşama 1 & 2)
Tüm UI metinlerini, ipuçlarını, HUD, tüccarlar, pazar, laboratuvar ve menüleri kapsar.
"""

import csv
import json
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCENES_DIR = PROJECT_ROOT / "Scenes"
DATA_DIR = PROJECT_ROOT / "Data"
OUTPUT_CSV = PROJECT_ROOT / "Translations" / "translations.csv"

TRANSLATION_MAP = {
    # --- ANA MENÜ & AYARLAR ---
    "YENİ OYUN": "NEW GAME",
    "DEVAM ET": "CONTINUE",
    "▶ DEVAM ET": "▶ CONTINUE",
    "DEVAM ET  (Gün %d • %d Zurna)": "CONTINUE  (Day %d • %d Zurna)",
    "Kayıtlı oyun bulunamadı.": "No save file found.",
    "KOLEKSİYON DEFTERİ": "COLLECTION LOG",
    "Koleksiyon Defteri": "Collection Log",
    "KOLEKSİYON": "COLLECTION",
    "Koleksiyon": "Collection",
    "📖 KOLEKSİYON [C]": "📖 COLLECTION [C]",
    "AYARLAR": "SETTINGS",
    "Ayarlar": "Settings",
    "⚙️ AYARLAR": "⚙️ SETTINGS",
    "BİLGİ": "INFO",
    "Bilgi": "Info",
    "BİLGİ & YARDIM": "INFO & HELP",
    "OYUNDAN ÇIK": "QUIT GAME",
    "ÇIKIŞ": "QUIT",
    "Çıkış": "Exit",
    "KAYDET & ÇIK": "SAVE & QUIT",
    "GERİ": "BACK",
    "Geri": "Back",
    "KAPAT": "CLOSE",
    "Kapat": "Close",
    "Müzik": "Music",
    "Müzik Sesi": "Music Volume",
    "Ses Efektleri": "Sound Effects",
    "Efekt Sesi (SFX)": "SFX Volume",
    "Tam Ekran Modu": "Fullscreen Mode",
    "Tam Ekran": "Fullscreen",
    "Dokunmatik Joystick Boyutu": "Touch Joystick Size",
    "Joystick Boyutu": "Joystick Size",
    "Mobil Fener Nişanlama": "Mobile Flashlight Aim",
    "Mobil Fener Yönü": "Mobile Flashlight Aim",
    "🕹️ Yüzüş Yönü (Joystick)": "🕹️ Swim Direction (Joystick)",
    "👆 Dokunmatik (Serbest Aim)": "👆 Free Touch Aim",
    "✨ Akıllı Hibrit (Joystick + Dokunma)": "✨ Smart Hybrid (Joystick + Touch)",
    "Koleksiyon Verileri": "Collection Data",
    "KOLEKSİYONU SIFIRLA": "RESET COLLECTION",
    "Geliştirici Kodu": "Developer Code",
    "Gizli kod...": "Secret code...",
    "DevCode": "DevCode",
    "UYGULA": "APPLY",
    "AKTİF ET": "ACTIVATE",
    "SIFIRLANDI!": "RESET COMPLETE!",
    "KOD GEÇERSİZ!": "INVALID CODE!",
    "GİZLİ KOD AKTİF!": "SECRET CODE ACTIVATED!",
    "Smile Games Sunar": "Smile Games Presents",
    "⚓ Smile Games Sunar": "⚓ Smile Games Presents",
    "Dal, bul, sat, derinlere in": "Dive, find, sell, plunge into the deep",
    "Derinliklerin Gizemli Hazinelerini Keşfet": "Discover the Mysterious Treasures of the Deep",
    "✦ REMASTERED ✦": "✦ REMASTERED ✦",

    # --- ONAY MODALLARI ---
    "⚠️ MEVCUT KAYIT SİLİNECEK": "⚠️ EXISTING SAVE WILL BE ERASED",
    "Mevcut kayıtlı oyunun (Gün %d • %d Zurna) ve satın aldığın tüm ekipman seviyeleri sıfırlanacak.\n(Keşfettiğin eşya koleksiyonu korunur)\n\nBu işlem geri alınamaz! Yeni bir oyuna başlamak istediğinden emin misin?": "Your current saved game (Day %d • %d Zurna) and all purchased equipment levels will be reset.\n(Your discovered item collection will be preserved)\n\nThis cannot be undone! Are you sure you want to start a new game?",
    "VAZGEÇ": "CANCEL",
    "EVET, YENİ OYUN 🚀": "YES, NEW GAME 🚀",
    "⚠️ KOLEKSİYONU SIFIRLA": "⚠️ RESET COLLECTION",
    "Tüm keşfettiğin eşyalar koleksiyon defterinden kalıcı olarak silinecektir.\nBu işlem geri alınamaz!\n\nKoleksiyonu sıfırlamak istediğinden emin misin?": "All items you have discovered will be permanently erased from your collection log.\nThis cannot be undone!\n\nAre you sure you want to reset your collection?",
    "EVET, SIFIRLA 🗑️": "YES, RESET 🗑️",

    # --- OFİS MENÜSÜ & HUD ---
    "DALIŞA GEÇ [E]": "DIVE IN [E]",
    "DALIŞA GEÇ": "DIVE IN",
    "Dalışa Geç": "Dive In",
    "🤿 DALIŞA BAŞLA / OKYANUS": "🤿 START DIVE / OCEAN",
    "ÇANTA [I]": "BAG [I]",
    "Çanta [I]": "Bag [I]",
    "🎒 ÇANTA [I]": "🎒 BAG [I]",
    "🎒 Çanta [I]": "🎒 Bag [I]",
    "ÇANTA": "BAG",
    "Çanta": "Bag",
    "🎒 Çantadaki Eşyalar": "🎒 Bag Inventory",
    "Envanter (0/5)": "Inventory (0/5)",
    "0 / 5 Eşya": "0 / 5 Items",
    "0 Adet": "0 Items",
    "KOLEKSİYON [C]": "COLLECTION [C]",
    "⚡ ŞARJ ET": "⚡ CHARGE",
    "⚡ Şarj Et": "⚡ Charge",
    "🏪 EKİPMAN MAĞAZASI": "🏪 EQUIPMENT SHOP",
    "Ekipman Mağazası": "Equipment Shop",
    "Ekipman": "Equipment",
    "🧪 BİYOKİMYA LABORATUVARI": "🧪 BIOCHEMISTRY LAB",
    "Biyokimya Laboratuvarı": "Biochemistry Lab",
    "LABORATUVAR": "LABORATORY",
    "Laboratuvar": "Laboratory",
    "🧪 LABORATUVAR & SENTEZ MERKEZİ": "🧪 LAB & SYNTHESIS CENTER",
    "Bakiye: %d Zurna": "Balance: %d Zurna",
    "💰 %d Zurna": "💰 %d Zurna",
    "0 Zurna": "0 Zurna",
    "💰 0 Zurna": "💰 0 Zurna",
    "+0 Zurna": "+0 Zurna",
    "Bakiye: 0 Zurna": "Balance: 0 Zurna",
    "Değer: 50 Zurna": "Value: 50 Zurna",
    "📅 GÜN %d": "📅 DAY %d",
    "Gün: %d": "Day: %d",
    "Gün: 1": "Day: 1",
    "📅 Gün 1": "📅 Day 1",
    "Saat: %02d:%02d": "Time: %02d:%02d",
    "19:00": "19:00",
    "⏰ Gün Kapanış Saati": "⏰ Day Closing Time",
    "⚓ YÜZEYDESİN (0m)": "⚓ AT SURFACE (0m)",
    "⚓ %dm  |  ↑ Yüzey: %dm": "⚓ %dm  |  ↑ Surface: %dm",
    "⚓ DERİNLİK: 0m": "⚓ DEPTH: 0m",
    "0 m": "0 m",
    "Tekneye Dön [E]": "Return to Boat [E]",
    "🚤 Tekneye Çık [E]": "🚤 Board Boat [E]",
    "YÜZEYE ÇIK": "SURFACE",
    "⏱️ YÜZEY: --s  │  🫧 KALAN O2: --s": "⏱️ SURFACE: --s  │  🫧 O2 LEFT: --s",
    "⚠️ DİKKAT: Oksijen yüzeye yetmeyebilir!": "⚠️ WARNING: Oxygen may not be enough to surface!",
    "O₂": "O₂",
    "🫧 OKSİJEN:": "🫧 OXYGEN:",
    "BATARYA": "BATTERY",
    "Batarya": "Battery",
    "⚡ BATARYA:": "⚡ BATTERY:",
    "⚡ Fener Yok": "⚡ No Flashlight",
    "🔋 %%%d": "🔋 %%%d",
    "❤️ CAN:": "❤️ HEALTH:",

    # --- TOAST VE SİSTEM BİLDİRİMLERİ ---
    "⚠️ Fenerin yok! Önce Ekipman Mağazasından satın almalısın.": "⚠️ You don't have a flashlight! Buy one from the Equipment Shop first.",
    "⚠️ Bataryan zaten tamamen dolu!": "⚠️ Battery is already fully charged!",
    "❌ Yetersiz bakiye!": "❌ Insufficient funds!",
    "🔋 Batarya başarıyla şarj edildi!": "🔋 Battery charged successfully!",
    "🎒 Çantan tamamen dolu!": "🎒 Your bag is full!",
    "Eşya kilitlendi.": "Item locked.",
    "Eşya kilidi açıldı.": "Item unlocked.",
    "Yeni Eşya Keşfedildi!": "New Item Discovered!",
    "✨ YENİ KEŞİF": "✨ NEW DISCOVERY",

    # --- ŞARJ İSTASYONU ---
    "⚡ ŞARJ İSTASYONU": "⚡ CHARGE STATION",
    "Dalış Feneri (Lv. %d)": "Dive Light (Lv. %d)",
    "Dalış Feneri (Lv. 1)": "Dive Light (Lv. 1)",
    "Dalış Feneri: [F] tuşu ile açılıp kapanır": "Dive Light: Toggle with [F] key",
    "MAX": "MAX",
    "⚡ ŞARJ ET (%d Zurna)": "⚡ CHARGE (%d Zurna)",
    "⚡ TAM DOLU": "⚡ FULLY CHARGED",
    "❌ YETERSİZ BAKİYE": "❌ INSUFFICIENT FUNDS",
    "Şarj Ediliyor...": "Charging...",

    # --- EKİPMAN MAĞAZASI & SLOTLAR ---
    "EKİPMAN MAĞAZASI": "EQUIPMENT SHOP",
    "Oksijen Tüpü": "Oxygen Tank",
    "Palet": "Fins",
    "Dalış Gözlüğü": "Diving Mask",
    "Sırt Çantası": "Backpack",
    "Dalış Feneri": "Dive Light",
    "GELİŞTİR": "UPGRADE",
    "Geliştir": "Upgrade",
    "MAKS SEVİYE": "MAX LEVEL",
    "Maks Seviye": "Max Level",
    "Yetersiz Zurna": "Insufficient Zurna",
    "Seviye: %d": "Level: %d",
    "Lv. %d": "Lv. %d",
    "Lv.0": "Lv.0",
    "Lv.1": "Lv.1",
    "+Stat": "+Stat",
    "Oksijen Tüpü: Su altında kalma süresini artırır": "Oxygen Tank: Increases underwater dive time",
    "Palet: Yüzüş hızını ve ivmesini artırır": "Fins: Increases swimming speed and acceleration",
    "Dalış Gözlüğü: Görüş açısını ve zoom'u genişletir": "Diving Mask: Expands field of view and zoom",
    "Çanta: Envanter kapasitesini artırır (+5 slot)": "Backpack: Increases inventory capacity (+5 slots)",
    "Sırt Çantası: Envanter kapasitesini artırır": "Backpack: Increases inventory capacity",

    # --- BİYOKİMYA LABORATUVARI ---
    "BİYOKİMYA LABORATUVARI": "BIOCHEMISTRY LAB",
    "Dönüştür / Üret": "Refine / Craft",
    "Hammaddeler ile İleri Craft & Sentez": "Advanced Crafting & Synthesis with Raw Materials",
    "📋 TARİF FİHRİSTİ": "📋 RECIPE INDEX",
    "🧪 GEREKLİ HAMMADDELER (KİLİTSİZ):": "🧪 REQUIRED MATERIALS (UNLOCKED):",
    "Gereken Malzemeler": "Required Materials",
    "Laboratuvar Masrafı: 0 Zurna": "Lab Cost: 0 Zurna",
    "Üretilen Gelişmiş Eşyaların Satışı": "Sale of Advanced Crafted Items",
    "ÜRET": "CRAFT",
    "Üret": "Craft",
    "Yetersiz Malzeme": "Insufficient Materials",
    "Çanta Dolu": "Bag Full",
    "Başarıyla Üretildi!": "Successfully Crafted!",
    "Eşya Seçin...": "Select Item...",
    "Eşya Adı": "Item Name",
    "Eşya açıklaması...": "Item description...",
    "Açıklama metni...": "Description text...",

    # --- KOLEKSİYON & ENVANTER ---
    "KOLEKSİYON DEFTERİ": "COLLECTION LOG",
    "Tümü": "All",
    "Hepsi": "All",
    "Çöp": "Trash",
    "🗑️ Çöp": "🗑️ Trash",
    "Kaynak": "Resource",
    "🧪 Madde": "🧪 Substance",
    "Nadir": "Rare",
    "🏛️ Nadir": "🏛️ Rare",
    "Değerli": "Valuable",
    "💎 Değerli": "💎 Valuable",
    "Özel": "Special",
    "🔴 Özel": "🔴 Special",
    "* Efsanevi": "* Legendary",
    "Üretim": "Crafted",
    "🔨 Üretilen": "🔨 Crafted",
    "Keşfedilen: %d / %d": "Discovered: %d / %d",
    "Keşfedilen: 0 / 0": "Discovered: 0 / 0",
    "0 / 0": "0 / 0",
    "HEPSİNİ SAT": "SELL ALL",
    "Hepsini Sat": "Sell All",
    "SIRALA": "SORT",
    "Sırala": "Sort",
    "🔄 Sırala": "🔄 Sort",
    "Fiyat": "Price",
    "Tür": "Type",
    "Adet": "Qty",
    "Ad": "Name",
    "Kilitli": "Locked",
    "KİLİTLE": "LOCK",
    "KİLİDİ AÇ": "UNLOCK",
    "💡 Sağ Tık / Basılı Tut: Kilitle 🔒": "💡 Right Click / Hold: Lock 🔒",
    "💡 Sol Tık: Eşyayı Seç / Bırak  •  Sağ Tık (Mobilde Basılı Tut): Kilitle 🔒": "💡 Left Click: Select / Drop Item  •  Right Click (Mobile: Hold): Lock 🔒",
    "💡 İpucu: Eşyayı kilitlemek / açmak için Sağ Tıkla veya Basılı Tut 🔒 (Hepsini Sat kilitli eşyaları satmaz)": "💡 Tip: Right Click or Hold to lock/unlock an item 🔒 ('Sell All' will never sell locked items)",
    "🔒 Sağ Tık / Basılı Tut:\nEşyayı kilitle (Korunur)": "🔒 Right Click / Hold:\nLock item (Protected)",
    "🔒 Sağ Tık / Basılı Tut: Eşyayı kilitle\n(Hepsini Sat'ta korunur)": "🔒 Right Click / Hold: Lock item\n(Protected in Sell All)",

    # --- TÜCCARLAR & PAZAR ---
    "PAZAR": "MARKET",
    "Pazar": "Market",
    "ÇÖPÇÜ": "SCAVENGER",
    "ÇÖPCÜ": "SCAVENGER",
    "Çöpçü": "Scavenger",
    "KARA BORSA": "BLACK MARKET",
    "Kara Borsa": "Black Market",
    "ANTİKACI": "ANTIQUARIAN",
    "Antikacı": "Antiquarian",
    "AL [E]": "TAKE [E]",
    "BIRAK [ESC]": "DROP [ESC]",
    "🗑️ Bırak": "🗑️ Drop",
    "SAT": "SELL",
    "Sat": "Sell",
    "Tahmini Satış Değeri: 0 Zurna": "Estimated Sale Value: 0 Zurna",
    "💰 Tahmini Satış Değeri: 0 Zurna": "💰 Estimated Sale Value: 0 Zurna",
    "Ücret: 20 Zurna (+%50)": "Price: 20 Zurna (+50%)",
    "Çöp hariç değerli buluntuları alır": "Buys valuable finds except trash",
    "Hoşgeldin adamım?, bugun ne pazarlık ediyoruz?": "Welcome my man! What are we haggling over today?",

    # --- DURAKLATMA MENÜSÜ ---
    "DURAKLATILDI": "PAUSED",
    "⏸️ DURAKLATILDI": "⏸️ PAUSED",
    "Duraklatıldı": "Paused",
    "ANA MENÜYE DÖN": "RETURN TO MAIN MENU",
    "🚪 ANA MENÜYE DÖN": "🚪 RETURN TO MAIN MENU",
    "Ana Menü": "Main Menu",

    # --- OYUN BİTTİ (GAME OVER) ---
    "OKSİJENİN BİTTİ": "OUT OF OXYGEN",
    "BOĞULDUN...": "YOU DROWNED...",
    "BOĞULDUN": "YOU DROWNED",
    "Dalgıç bilincini kaybetti ve sahil güvenlik tarafından kurtarıldı.": "The diver lost consciousness and was rescued by the coast guard.",
    "Çantandaki eşyalar kayboldu!": "The items in your bag were lost!",
    "OFİSE DÖN": "RETURN TO OFFICE",
    "GÜNÜ TEKRAR ET": "RETRY DAY",

    # --- GÜN SONU (DAY SUMMARY) ---
    "GÜN SONU RAPORU": "DAY SUMMARY REPORT",
    "GÜN %d TAMAMLANDI": "DAY %d COMPLETED",
    "GÜN 1 TAMAMLANDI": "DAY 1 COMPLETED",
    "Günün Operasyon & Bilanço Raporu": "Daily Operations & Balance Sheet",
    "Dalış Özeti": "Dive Summary",
    "Toplanan Eşya": "Items Collected",
    "📦 Satılan Eşya": "📦 Items Sold",
    "Kazanılan Zurna": "Zurna Earned",
    "💰 Günün Kazancı": "💰 Day's Earnings",
    "Toplam Bakiye": "Total Balance",
    "0 Dalış": "0 Dives",
    "🤿 Yapılan Dalış": "🤿 Dives Completed",
    "🌊 En Derin Nokta": "🌊 Deepest Point",
    "SONRAKİ GÜNE GEÇ": "PROCEED TO NEXT DAY",
    "GÜNÜ İLERLET ☀️": "ADVANCE DAY ☀️",

    # --- MOBİL KONTROLLER ---
    "🖐️ İNCELE": "🖐️ EXAMINE",
    "⚡ DEPAR": "⚡ SPRINT",
    "⚡ AÇIK": "⚡ SPRINT ON",
    "⚡ DİREKT AL": "⚡ QUICK TAKE",
    "❌ DOLU": "❌ FULL",
    "🔦 FENER": "🔦 LIGHT",
    "🔦 AÇIK": "🔦 LIGHT ON",
    "🔦 YOK": "🔦 NO LIGHT",
    "🥽+": "🥽+",
    "🥽-": "🥽-",
    "⏸️": "⏸️",

    # --- YÜKLEME EKRANI & İPUÇLARI ---
    "YÜKLENİYOR...": "LOADING...",
    "Yükleniyor...": "Loading...",
    "Hazırlanıyor...": "Preparing...",
    "✦ DALIŞA HAZIRLANIYOR ✦": "✦ PREPARING FOR DIVE ✦",
    "Eski kalıntılar ve hazineler taranıyor...": "Scanning ancient relics and treasures...",
    "▶ DEVAM ETMEK İÇİN EKRANA DOKUNUN VEYA BİR TUŞA BASIN ◀": "▶ TOUCH SCREEN OR PRESS ANY KEY TO CONTINUE ◀",
    "💡 [E] Kısayolu: Su yüzeyine çıktığında teknene hızlıca binmek için [E] tuşuna basabilirsin.": "💡 [E] Shortcut: When you reach the surface, press [E] to quickly board your boat.",
    "💡 Eşya Kilitleme: Çantandaki değerli eşyaları korumak için üzerlerine Sağ Tıkla kilit 🔒 vurabilirsin.": "💡 Item Locking: Right-click valuable items in your bag to lock 🔒 and protect them.",
    "💡 Güvenli Satış: 'Hepsini Sat' butonu kilitli eşyalarını asla satmaz.": "💡 Safe Selling: The 'Sell All' button will never sell your locked items.",
    "💡 Derinlik & Basınç: Derinlere indikçe oksijenin çok daha hızlı tükenir, Atölye'den tüpünü geliştirmeyi unutma!": "💡 Depth & Pressure: Oxygen depletes much faster at greater depths; don't forget to upgrade your tank in the Workshop!",
    "💡 Çanta Düzeni: Çanta ekranındaki 'Sırala' butonu ile eşyalarını fiyata veya türe göre dizebilirsin.": "💡 Bag Organization: Use the 'Sort' button in your bag to organize items by price or category.",
    "💡 Tüccar Uzmanlıkları: Hurda ve çöpleri Çöpçüye, antikaları Antikacıya, gizemli kırmızı eşyaları Kara Borsa'ya sat.": "💡 Merchant Specialties: Sell scrap to the Scavenger, antiques to the Antiquarian, and mysterious red items to the Black Market.",
    "💡 Bulanık Derinlikler: Dalış gözlüğünü geliştirerek diplerdeki görüş mesafeni artırabilirsin.": "💡 Murky Depths: Upgrade your diving mask to improve your visibility in the deep.",
    "💡 Hızlı Yüzüş: Palet seviyeni artırarak su altında daha çevik hareket edebilir ve akıntılara karşı koyabilirsin.": "💡 Fast Swimming: Upgrade your fins to move more agilely underwater and resist ocean currents.",
    "💡 Mesai Saati: Akşam 19:00 olduğunda hava kararır ve dalış kilitlenir; gününü iyi planla!": "💡 Shift Hours: At 19:00, darkness falls and diving is locked; plan your day carefully!",

    # --- KONSOL ---
    "[~] KONSOL": "[~] CONSOLE",
    "◆ DIVE & FIND — GELİŞTİRİCİ & HİLE KONSOLU": "◆ DIVE & FIND — DEV & CHEAT CONSOLE",
    "Komut girin... (yardım için: help)": "Enter command... (help for info)"
}


def clean_godot_string(raw: str) -> str:
    """Godot TSCN escape karakterlerini temizler."""
    s = raw.replace('\\"', '"').replace('\\n', '\n').strip()
    return s


def collect_scene_strings():
    """Tüm sahnelerden metinleri toplar."""
    strings = set()
    patterns = [
        re.compile(r'text\s*=\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
        re.compile(r'tooltip_text\s*=\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
        re.compile(r'placeholder_text\s*=\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    ]
    for p in SCENES_DIR.glob("**/*.tscn"):
        content = p.read_text(encoding="utf-8", errors="ignore")
        for pat in patterns:
            for m in pat.finditer(content):
                s = clean_godot_string(m.group(1))
                if s and not s.isdigit() and len(s) > 1:
                    strings.add(s)
    return strings


def main():
    print("Metinler taranıyor...")
    scene_strings = collect_scene_strings()

    # Yükleme ipuçlarını da ekle
    tips_file = DATA_DIR / "loading_tips.json"
    if tips_file.exists():
        tips = json.loads(tips_file.read_text(encoding="utf-8"))
        for t in tips:
            scene_strings.add(t.strip())

    # Haritadaki tüm bilinen çevirileri birleştir
    all_keys = set(TRANSLATION_MAP.keys())
    all_keys.update(scene_strings)

    rows = []
    translated_count = 0
    missing_count = 0

    for key in sorted(all_keys):
        if key.isdigit() or key.startswith("res://") or key.startswith("uid://"):
            continue
        if key.startswith("#") and len(key) in [4, 7, 9]:
            continue

        en_val = TRANSLATION_MAP.get(key)
        if en_val:
            translated_count += 1
        else:
            en_val = key
            missing_count += 1

        rows.append({
            "id": key,
            "en": en_val,
            "tr": key
        })

    OUTPUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_CSV, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["id", "en", "tr"], quoting=csv.QUOTE_ALL)
        writer.writeheader()
        for r in rows:
            writer.writerow(r)

    print(f"\n✓ Başarıyla oluşturuldu: {OUTPUT_CSV}")
    print(f"  • Toplam Satır      : {len(rows)}")
    print(f"  • Tam Çevrilen      : {translated_count}")
    print(f"  • Kalan             : {missing_count}")


if __name__ == "__main__":
    main()
