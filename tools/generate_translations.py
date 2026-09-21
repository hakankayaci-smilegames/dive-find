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
    "Otomatik Kayıt": "Auto-Save",
    "Geçişlerde Otomatik Kayıt": "Auto-Save on Transitions",
    "💾 Oyun Kaydedildi": "💾 Game Saved",
    "Dokunmatik Joystick Boyutu": "Touch Joystick Size",
    "Joystick Boyutu": "Joystick Size",
    "Dil": "Language",
    "Dil / Language": "Language / Dil",
    "DİL / LANGUAGE": "LANGUAGE / DİL",
    "Language": "Language",
    "🇹🇷 Türkçe": "🇹🇷 Türkçe",
    "🇬🇧 English": "🇬🇧 English",
    "DİL SEÇİMİ": "LANGUAGE SELECTION",
    "DİL SEÇİMİ / LANGUAGE SELECTION": "LANGUAGE SELECTION / DİL SEÇİMİ",
    "Lütfen oyunu oynamak istediğiniz dili seçin\nPlease select your preferred language": "Please select your preferred language\nLütfen oyunu oynamak istediğiniz dili seçin",
    "* Bu ayarı daha sonra Ayarlar menüsünden değiştirebilirsiniz.\n* You can change this setting anytime in the Settings menu.": "* You can change this setting anytime in the Settings menu.\n* Bu ayarı daha sonra Ayarlar menüsünden değiştirebilirsiniz.",
    "📋 YENİLİKLER & GÜNCELLEMELER": "📋 UPDATES & CHANGELOG",
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
    "AKTİF ✅": "ACTIVE ✅",
    "HATALI! ❌": "INVALID! ❌",
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
    "📅 Gün %d": "📅 Day %d",
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
    "💰 Fiyat": "💰 Price",
    "🏷️ Tür": "🏷️ Type",
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

    # --- ŞEHİR HARİTASI (CITY MAP & PINS) ---
    "📍Portovero Kasabası": "📍 Portovero Town",
    "Portovero Kasabası": "Portovero Town",
    "⏭️ DİNLEN / İLERLET": "⏭️ REST / ADVANCE",
    "🎒 ÇANTA (%d/%d)": "🎒 BAG (%d/%d)",
    "🚪 HARİTADAN ÇIK": "🚪 EXIT MAP",
    "Haritadan Çık": "Exit Map",
    "▶ GİR [TIKLA]": "▶ ENTER [CLICK]",
    "Bölge Başlığı": "Location Title",
    "Bölge hakkında kısa bilgi...": "Short info about location...",
    "Bildirim mesajı...": "Notification message...",
    "📅 GÜN 1": "📅 DAY 1",
    "💰 0 Zurna": "💰 0 Zurna",
    "📍Portovero Kasabası": "📍 Portovero Town",
    "Liman İskelesi & Dalış": "Harbor Pier & Dive",
    "Suya dalış yap veya rıhtım iskelesinden açıl.": "Dive into the ocean from the wooden pier.",
    "Genel ticaret ve alım satım tezgahları.": "General trade and barter stalls.",
    "Tüp, palet, maske ve çantanı yükselt.": "Upgrade tank, fins, goggles and bag.",
    "Tarihi ve değerli eşyaları iyi fiyata alır.": "Buys relics and valuables for good coin.",
    "Plastik ve metal atıkları geri dönüştür.": "Recycle plastic and metal into ingots.",
    "Özel ve gizli ganimetleri yüksek fiyata alır.": "Buys contraband & special loot for high pay.",
    "Dalış fenerinin bataryasını doldur.": "Recharge your diving flashlight battery.",

    # --- İSKELE BARAKASI (DOCK SHACK & PIER HUB) ---
    "⚓ LİMAN BARAKASI & İSKELE": "⚓ DOCK SHACK & PIER",
    "🤿 DALIŞ HAZIRLIK İSKELESİ": "🤿 DIVE PREPARATION PIER",
    "Ekipmanlarını kontrol et, fenerini şarj et ve derinliklere dalış yap.": "Check your equipment, recharge your flashlight, and dive into the deep.",
    "🤿 DALIŞA BAŞLA": "🤿 START DIVE",
    "⚡ FENERİ ŞARJ ET": "⚡ CHARGE FLASHLIGHT",
    "🗺️ ŞEHRE ÇIK": "🗺️ VISIT CITY",
    "Sırt Çantası Lv.1\n8 Slot": "Backpack Lv.1\n8 Slots",
    "Oksijen Tüpü Lv.1\n~60s Kapasite": "O2 Tank Lv.1\n~60s Capacity",
    "Dalış Maskesi Lv.1\nZoom: x1.1": "Diving Mask Lv.1\nZoom: x1.1",
    "Palet Lv.1\nHız: +%0": "Fins Lv.1\nSpeed: +0%",
    "Dalış Feneri Lv.1": "Diving Flashlight Lv.1",
    "💡 İskeleden suya daldığında hava kararana (19:00) kadar serbestçe dalabilirsin.": "💡 You can freely explore the depths until nightfall (19:00).",
    "⚠️ DALIŞ KAPALI (GECE)": "⚠️ DIVE CLOSED (NIGHT)",
    "⚠️ Hava karardı (19:00+). Dalış yapabilmek için şehre dönüp günü ilerletmelisin!": "⚠️ Night has fallen (19:00+). Return to town and advance the day to dive!",
    "⚠️ Fener bataryası azaldı! Kasabadaki Şarj İstasyonunda doldurabilirsin.": "⚠️ Flashlight battery is low! You can recharge it at the town's Charge Station.",
    "💡 Ekipmanlarını kontrol et ve derinliklere dal! Şarj ve geliştirmeler kasabadadır.": "💡 Check your gear and dive into the depths! Recharges and upgrades are available in town.",
    "Bildirim mesajı": "Notification message",
    "🎒 ÇANTA": "🎒 BAG",
    "📖 KOLEKSİYON": "📖 COLLECTION",
    "⏰ 08:00": "⏰ 08:00",
    "PreAlpha 1.7.0": "PreAlpha 1.7.0",

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
    "Şehir haritası ve liman animasyonu hazırlanıyor...": "Preparing city map and harbor animation...",
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
    "Komut girin... (yardım için: help)": "Enter command... (help for info)",

    # --- İLAVE TSCN METİNLERİ & SÜRÜM NOTLARI ---
    "%0": "%0",
    "%100": "%100",
    "%50 → %100": "%50 → %100",
    "OFİS & DALIŞ KARARGAHI": "OFFICE & DIVE HEADQUARTERS",
    "Oksijen Tüpü: Oksijen tüketimini azaltır": "Oxygen Tank: Reduces oxygen consumption",
    "Oksijen tüpün bitti ve yüzeye ulaşamadın, yandan geçen bir balıkçı seni buldu ve kurtardı ancak uyandığında çantan yoktu.\nDevam etmek için TAMAM'a bas, ofise geri gönderileceksin.": "You ran out of oxygen and couldn't reach the surface. A passing fisherman spotted and rescued you, but your bag was gone when you woke up.\nPress OK to return to the office.",
    "Palet: Yüzme hızını artırır": "Fins: Increases swim speed",
    "SATIŞ PAZARI": "MARKETPLACE",
    "SENTEZLE / ÜRET ✨": "SYNTHESIZE / CRAFT ✨",
    "Sadece çöp ve hurda eşyaları alır": "Only buys trash and scrap items",
    "Sadece özel ve gizli ganimetleri alır": "Only buys special & contraband loot",
    "Seviye arttıkça dalış gücün artar": "Dive capabilities increase with higher levels",
    "Seviye: 0": "Level: 0",
    "TAMAM": "OK",
    "TESİSLER VE ÜRETİM ALANLARI": "FACILITIES & PRODUCTION",
    "Tesisler, Tüccarlar ve Operasyon Yönetim Merkezi": "Facilities, Traders & Operations Hub",
    "TÜCCARLAR VE ALIM MERKEZLERİ": "TRADERS & ACQUISITIONS",
    "Tüp, Palet, Gözlük ve Çanta Yükselt": "Upgrade Tank, Fins, Mask & Bag",
    "UPGRADE": "UPGRADE",
    "YENİ GÜNE BAŞLA ☀️": "START NEW DAY ☀️",
    "[ AKTİF ]": "[ ACTIVE ]",
    "[ DEĞERLİ ]": "[ VALUABLE ]",
    "[ Kapatmak için: é veya ESC ]": "[ To Close: ~ or ESC ]",
    "v0.0.2 (Devbuild)": "v0.0.2 (Devbuild)",
    "⏰ 10:00": "⏰ 10:00",
    "⚙️": "⚙️",
    "🏛️": "🏛️",
    "📋 YENİLİKLER & GÜNCELLEMELER": "📋 CHANGELOG & UPDATES",
    "🔋 %100": "🔋 100%",
    "🕶️": "🕶️",
    "🗑️": "🗑️",
    "[center][color=#ffd54f][font_size=16][b]⚓ PRE-ALPHA 1.7.0 SÜRÜM NOTLARI[/b][/font_size][/color][/center]\n\n[color=#ffd54f][b]🚀 GÜNCELLEMELER & YENİLİKLER:[/b][/color]\n• [color=#00e5ff]Şehir Haritası Tam Entegrasyonu:[/color] Oyun döngüsü artık doğrudan Liman Kasabası Şehir Haritası'ndan başlar. Tüm tesisler, mağazalar ve operasyonlar harita pinleri üzerinden yönetilir.\n• [color=#00e5ff]İskele Barakası & Dalış Hazırlık Hub'ı:[/color] Şehir ile okyanus arasına denizci temalı Dalış Hazırlık İskelesi eklendi. Dalış öncesi ekipman durumu (çanta, oksijen tüpü, maske, palet, fener ve canlı batarya) tek ekranda incelenebilir, fener şarj edilebilir ve tek tuşla dalışa geçilebilir.\n• [color=#00e5ff]Sinematik Yükleme Ekranı Geçişleri:[/color] Şehir Haritası, İskele Barakası, Okyanus Dalışı ve Ana Menü arasındaki tüm geçişler akıcı yükleme ekranı animasyonu eşliğinde pürüzsüzleştirildi.\n• [color=#00e5ff]Doğrudan Ana Menüye Çıkış & Otomatik Kayıt:[/color] Şehir Haritası'ndaki çıkış butonu ile tüm ilerleme otomatik kaydedilerek doğrudan ana menüye dönülebilmesi sağlandı.\n\n[color=#ff7043][b]⚡ PERFORMANS & HATA DÜZELTMELERİ:[/b][/color]\n• [color=#81c784]Mobil Kontroller & Menü Çakışma Düzeltmesi:[/color] Şehir ve baraka menülerindeyken mobil dokunmatik kontrollerin ekranda kontrolsüzce belirme hatası giderildi; kontroller yalnızca okyanusta aktifleşir.\n\n[center][color=#546e7a]──────────────────────────────────────[/color][/center]\n\n[center][color=#ffd54f][font_size=16][b]⚓ PRE-ALPHA 1.6.3 SÜRÜM NOTLARI[/b][/font_size][/color][/center]\n\n[color=#ffd54f][b]🚀 GÜNCELLEMELER & YENİLİKLER:[/b][/color]\n• [color=#00e5ff]%100 İngilizce Dil Desteği:[/color] Oyunun tüm arayüzleri, menüleri, diyalogları, eşyaları, bildirimleri ve rehberleri için eksiksiz Türkçe / İngilizce çift dilli yerelleştirme (Bilingual Localization) tamamlandı. Ayarlar menüsünden anında geçiş yapılabilir.\n• [color=#00e5ff]Eşya Açıklamaları & Hikaye Düzeltmeleri:[/color] Tüm deniz altı eşyalarının açıklamaları, yazım hataları ve hikaye metinleri baştan sona gözden geçirilip düzeltildi; her eşyaya derinlik katan tematik açıklamalar işlendi.\n• [color=#00e5ff]Fiyatlandırma & Nadirlik (Rarity) Rework'ü:[/color] Tüm eşyaların nadirlik sınıfları ve satış fiyatları derinlik seviyelerine, craft zincirine ve oyun ekonomisine uygun şekilde yeniden yapılandırılarak dengeli ve ödüllendirici hale getirildi.\n• [color=#00e5ff]Ana Menü & Yükleme Ekranı UI Rework'ü:[/color] Ana menü ve yükleme (loading) ekranı modern ve estetik bir arayüz tasarımına kavuşturuldu; akıcı geçiş animasyonları, modernize tipografi ve yeni görsel düzen entegre edildi.\n• [color=#00e5ff]Yeni Oyun Simgesi & Splash Screen:[/color] Yepyeni yüksek çözünürlüklü oyun simgesi ve açılışta karşılayan özel animasyonlu Splash Screen sahnesi eklendi.\n\n[center][color=#546e7a]──────────────────────────────────────[/color][/center]\n\n[center][color=#00e5ff][font_size=16][b]⚓ PRE-ALPHA 1.6.2 SÜRÜM NOTLARI[/b][/font_size][/color][/center]\n\n[color=#ffd54f][b]🚀 GÜNCELLEMELER & YENİLİKLER:[/b][/color]\n• [color=#00e5ff]Ofis Şarj İstasyonu & Ücretli Batarya:[/color] Yüzeyde ve ofise girişteki ücretsiz otomatik şarj kaldırıldı. Ofis alt barına Şarj İstasyonu (HSlider ve MAX dolum) ile canlı batarya rozeti eklendi.\n• [color=#00e5ff]Dinamik Batarya Fiyatlandırması:[/color] Fener şarj maliyeti sabit fiyattan saniye/kapasite bazlı adil modele geçirildi (0.30 Zurna/sn; Lv.1 ~23Z, Lv.15 ~60Z).\n• [color=#00e5ff]Derinlik & Gece Kararması Buff'ı:[/color] Okyanus kararma eğrisi güçlendirildi (260m referans derinlik, daha dik abis geçişi, zifiri karanlık dip suları).\n• [color=#00e5ff]Yeni Oyun Güvenlik Modalı:[/color] Kayıtlı oyun varken yanlışlıkla \"Yeni Oyun\" denildiğinde ilerlemenin ve ekipmanların silinmesini önleyen onay penceresi eklendi.\n• [color=#00e5ff]Mobil Dalış Duraklatma (Pause) Tuşu:[/color] Mobil dokunmatik arayüzün sağ üst köşesine kompakt duraklatma butonu ([ ⏸️ ]) eklendi.\n• [color=#00e5ff]Laboratuvar Craft Kar Dengelemesi:[/color] Üretilen eşyaların satış gelirleri ve kar marjları piyasa dengesini koruyacak şekilde yeniden dengelendi.\n• [color=#00e5ff]Geliştirici Konsolu Karartma Komutu:[/color] Konsola dinamik test için `darkness` (ve `karartma`) komutu ile hazır önayarlar (abis, day, reset) eklendi.\n\n[color=#ff7043][b]⚡ PERFORMANS & HATA DÜZELTMELERİ:[/b][/color]\n• [color=#81c784]Toast Bildirim Ekran Esneme (Stretch) Fix'i:[/color] Uzun bildirim mesajlarında ofis menüsü ve ekran kenarlarının dışa taşması ToastLabel bağımsız yüzen panele taşınarak tamamen çözüldü.\n• [color=#81c784]Anlık Ekipman Rozet Senkronizasyonu:[/color] Mağazadan fener veya ekipman satın alındığı anda alt bardaki durum rozetinin mağaza kapanmadan anında güncellenmesi sağlandı.\n\n[center][color=#546e7a]──────────────────────────────────────[/color][/center]\n\n[center][color=#00e5ff][font_size=16][b]⚓ PRE-ALPHA 1.6.1 SÜRÜM NOTLARI[/b][/font_size][/color][/center]\n\n[color=#ffd54f][b]🚀 GÜNCELLEMELER & YENİLİKLER:[/b][/color]\n• [color=#00e5ff]Direkt Alma Özelliği (PC Entegrasyonu):[/color] Eşyaları menü açmadan tek tuşla anında çantaya alma kabiliyeti PC'ye de getirildi (Sağ Klik).\n• [color=#00e5ff]Mobil Fener Nişanlama & Hassasiyet Ayarları:[/color] Ayarlar menüsüne 3 modlu mobil fener hedefleme seçeneği eklendi (Joystick Yüzüş Yönü, Serbest Dokunmatik Aim, Akıllı Hibrit).\n• [color=#00e5ff]Koleksiyon Sıfırlama Güvenlik Onayı:[/color] Koleksiyon defterini sıfırlama butonuna yanlışlıkla basılmaları önleyen denizci temalı iki aşamalı onay penceresi entegre edildi.\n\n[color=#ff7043][b]⚡ PERFORMANS & HATA DÜZELTMELERİ:[/b][/color]\n• [color=#81c784]Toplu Satış & Hızlı Yükseltme Optimizasyonu:[/color] \"Hepsini Sat\" yapıldığında tek karede yüzlerce slot sahnesi üretilip silinmesi engellendi; hızlı geliştirmedeki gereksiz çifte tetiklemeler ve tween çakışmaları sıfırlandı.\n• [color=#81c784]Yeni Eşya Keşif Takılması (Lag Spike) Giderildi:[/color] Yeni eşyalar ilk kez keşfedildiğinde yaşanan disk yazma takılması WorkerThreadPool arka plan I/O mimarisiyle tamamen akıcı hale getirildi.\n• [color=#81c784]Fener Işık & Fizik (FPS) Optimizasyonu:[/color] Fener doku üretimi ve dinamik ışık motoru optimize edilerek fener ilk açıldığında oluşan fps düşüşü ve takılmalar tamamen giderildi.\n• [color=#81c784]Fener HUD (Ekipman Dock) Senkronizasyonu:[/color] Okyanustaki sağ alt ekipman dock'unda fener seviyesinin (Lv.X) güncellenmeme ve görünmeme sorunu çözüldü.\n• [color=#81c784]Mobil Buton Teması Düzeltildi:[/color] Mobil fener ve depar butonlarının varsayılan gri temaya düşme ve temassız/stilsiz görünme hatası önbellek stiliyle düzeltildi.": "[center][color=#ffd54f][font_size=16][b]⚓ PRE-ALPHA 1.7.0 PATCH NOTES[/b][/font_size][/color][/center]\n\n[color=#ffd54f][b]🚀 UPDATES & NEW FEATURES:[/b][/color]\n• [color=#00e5ff]Full City Map Integration:[/color] Game loop now directly launches into the Port Town City Map. All facilities, merchant stalls, and operations are managed via map pins.\n• [color=#00e5ff]Dock Shack & Dive Preparation Pier Hub:[/color] Added a nautical Dock Shack hub between town and ocean. Check all equipment stats (backpack, O2 tank, mask, fins, flashlight and live battery), recharge flashlight, and dive into the deep.\n• [color=#00e5ff]Cinematic Loading Screen Transitions:[/color] Seamless loading screen transitions smoothly bridge City Map, Dock Shack, Ocean Diving, and the Main Menu.\n• [color=#00e5ff]Direct Exit to Main Menu & Auto-Save:[/color] Exit Map button on the City Map automatically saves progress and returns directly to the Main Menu.\n\n[color=#ff7043][b]⚡ PERFORMANCE & BUG FIXES:[/b][/color]\n• [color=#81c784]Mobile Controls & Hub UI Conflict Fixed:[/color] Resolved the bug where mobile touch controls spawned when closing menus; controls now strictly activate only while diving in the ocean.\n\n[center][color=#546e7a]──────────────────────────────────────[/color][/center]\n\n[center][color=#ffd54f][font_size=16][b]⚓ PRE-ALPHA 1.6.3 PATCH NOTES[/b][/font_size][/color][/center]\n\n[color=#ffd54f][b]🚀 UPDATES & NEW FEATURES:[/b][/color]\n• [color=#00e5ff]100% English Language Support:[/color] Full bilingual localization (TR / EN) implemented across all UI screens, menus, dialogs, items, notifications, and guides. Seamless instant language switching via Settings.\n• [color=#00e5ff]Item Descriptions & Lore Overhaul:[/color] All underwater items, artifacts, and lore texts have been revised, typos fixed, and enriched with flavorful maritime descriptions.\n• [color=#00e5ff]Economy & Rarity Rework:[/color] Complete overhaul of item rarity tiers and base sell values tuned across depth zones and crafting recipes for a rewarding economy.\n• [color=#00e5ff]Main Menu & Loading Screen UI Rework:[/color] Completely redesigned sleek and modern layouts for the Main Menu and Loading Screens with smooth responsive animations, modernized typography, and polished visuals.\n• [color=#00e5ff]New Game Icon & Animated Splash Screen:[/color] Brand new high-resolution game icon and a dedicated animated Splash Screen intro sequence.\n\n[center][color=#546e7a]──────────────────────────────────────[/color][/center]\n\n[center][color=#00e5ff][font_size=16][b]⚓ PRE-ALPHA 1.6.2 PATCH NOTES[/b][/font_size][/color][/center]\n\n[color=#ffd54f][b]🚀 UPDATES & NEW FEATURES:[/b][/color]\n• [color=#00e5ff]Office Charging Station & Paid Battery:[/color] Free automatic charging upon surfacing and office entry removed. Added Charging Station (HSlider and MAX fill) and live battery badge to office bottom bar.\n• [color=#00e5ff]Dynamic Battery Pricing:[/color] Flashlight charging cost changed from flat rate to fair second/capacity-based model (0.30 Zurna/sec; Lv.1 ~23Z, Lv.15 ~60Z).\n• [color=#00e5ff]Depth & Night Darkness Buff:[/color] Ocean darkening curve intensified (260m reference depth, steeper abyss gradient, pitch-black deep waters).\n• [color=#00e5ff]New Game Confirmation Modal:[/color] Added confirmation prompt when starting a \"New Game\" with existing save data to prevent accidental loss of progress and equipment.\n• [color=#00e5ff]Mobile Dive Pause Button:[/color] Added compact pause button ([ ⏸️ ]) to upper-right corner of mobile touch interface.\n• [color=#00e5ff]Laboratory Craft Profit Rebalancing:[/color] Adjusted item sell values and profit margins to maintain economic balance.\n• [color=#00e5ff]Dev Console Darkness Command:[/color] Added `darkness` (and `karartma`) command to console with quick presets (abyss, day, reset) for dynamic testing.\n\n[color=#ff7043][b]⚡ PERFORMANCE & BUG FIXES:[/b][/color]\n• [color=#81c784]Toast Notification Stretch Fix:[/color] Long notification messages causing office menu stretching fixed by migrating ToastLabel to an independent floating panel.\n• [color=#81c784]Instant Equipment Badge Sync:[/color] Buying flashlights or equipment updates bottom bar status badges immediately without closing shop.\n\n[center][color=#546e7a]──────────────────────────────────────[/color][/center]\n\n[center][color=#00e5ff][font_size=16][b]⚓ PRE-ALPHA 1.6.1 PATCH NOTES[/b][/font_size][/color][/center]\n\n[color=#ffd54f][b]🚀 UPDATES & NEW FEATURES:[/b][/color]\n• [color=#00e5ff]Direct Pickup (PC Integration):[/color] Added right-click shortcut to immediately store items into backpack without opening pop-up.\n• [color=#00e5ff]Mobile Flashlight Aim & Sensitivity Settings:[/color] Added 3-mode mobile flashlight aiming options to settings (Swim Direction, Free Touch Aim, Smart Hybrid).\n• [color=#00e5ff]Collection Reset Confirmation:[/color] Integrated nautical-themed two-step confirmation window to prevent accidental collection log resets.\n\n[color=#ff7043][b]⚡ PERFORMANCE & BUG FIXES:[/b][/color]\n• [color=#81c784]Bulk Sell & Fast Upgrade Optimization:[/color] Prevented instantiating and freeing hundreds of slot scenes during \"Sell All\"; eliminated double triggers and tween conflicts in fast upgrades.\n• [color=#81c784]New Item Discovery Lag Spike Resolved:[/color] Disk write stutter upon discovering new items resolved using WorkerThreadPool background I/O architecture.\n• [color=#81c784]Flashlight Lighting & Physics Optimization:[/color] Flashlight texture generation and dynamic light engine optimized, eliminating initial FPS drops and stutters.\n• [color=#81c784]Flashlight HUD Sync:[/color] Resolved issue where flashlight level (Lv.X) did not update or appear in ocean equipment dock.\n• [color=#81c784]Mobile Button Theme Fixed:[/color] Resolved mobile flashlight and sprint buttons reverting to default gray styling using cached styles.",
    "[center][font_size=24][color=#00e5ff][b]🤿 DIVE & FIND 🤿[/b][/color][/font_size][/center]\n\n[color=#72b5ff][b]Hikaye & Konsept:[/b][/color]\nDerin okyanusların gizemli sularına dalış yap! Dipte saklı kalan antik eserleri, değerli kalıntıları ve tuhaf objeleri topla, yüzeye çıkarıp sat ve ekipmanlarını geliştir.\n\n[color=#72b5ff][b]Temel Kontroller (PC):[/b][/color]\n• [color=#00e5ff]WASD / Yön Tuşları:[/color] Yüzme ve Hareket\n• [color=#00e5ff]Shift (Basılı Tut):[/color] Hızlı Yüzme / Depar (Sprint — %50 hız artışı, 2.6x oksijen tüketimi)\n• [color=#00e5ff]Sol Tık / E Tuşu:[/color] Eşyayı İncele (Detay penceresi ve alma menüsü açar)\n• [color=#00e5ff]Sağ Tık:[/color] Doğrudan Çantaya Al (Pop-up açmadan hızlı alma)\n• [color=#00e5ff]F Tuşu:[/color] Dalış Fenerini Aç / Kapat (Işık mouse imlecine yönelir, batarya tüketir)\n• [color=#00e5ff]Fare Tekerleği / [ + ] [ - ] / P & O:[/color] Kamera Yakınlaştır / Uzaklaştır (Gözlük seviyesiyle genişler)\n• [color=#00e5ff]I / Tab Tuşu:[/color] Sırt Çantasını Aç / Kapat (Envanter)\n• [color=#00e5ff]C Tuşu:[/color] Koleksiyon Defterini Aç / Kapat (Keşfedilenler)\n• [color=#00e5ff]Sağ Tık (Çantada):[/color] Eşyayı Kilitle / Kilidi Aç (🔒 Satış ve craft koruması)\n• [color=#00e5ff]E (Su Yüzeyinde):[/color] Tekneye Çık & Ofis Karargahına Dön\n• [color=#00e5ff]ESC:[/color] Açık pencereleri kapat / Ofisteyken dalışı başlat\n\n[color=#72b5ff][b]Mobil Kontroller (Dokunmatik):[/b][/color]\n• [color=#00e5ff]Sol Ekran:[/color] Dinamik Analog Joystick (360° serbest yüzüş)\n• [color=#00e5ff]⚡ DEPAR:[/color] Hızlı yüzme modunu açar / kapatır\n• [color=#00e5ff]⚡ DİREKT AL:[/color] Menzildeki eşyayı pop-up açmadan çantaya atar\n• [color=#00e5ff]🖐️ İNCELE:[/color] Menzildeki eşyanın detay penceresini açar\n• [color=#00e5ff]🥽+ / 🥽- :[/color] Kamerayı kademeli yakınlaştırıp uzaklaştırır\n• [color=#00e5ff]🔦 FENER:[/color] Dalış fenerini açar / kapatır (Ayarlardan 3 yön modu seçilebilir)\n• [color=#00e5ff]Uzun Basış (0.35s):[/color] Çantada eşyayı kilitler / açar 🔒\n\n[center][font_size=13][color=#5e8ca8]Yapımcılar: Queen Of Femboyss & Hakan Bey[/color][/font_size]\n[font_size=15][color=#00e5ff][i]⚓ Smile Games sunar[/i][/color][/font_size][/center]": "[center][font_size=24][color=#00e5ff][b]🤿 DIVE & FIND 🤿[/b][/color][/font_size][/center]\n\n[color=#72b5ff][b]Story & Concept:[/b][/color]\nDive into the mysterious waters of deep oceans! Discover ancient relics, valuable salvage, and bizarre artifacts resting on the seafloor, surface to sell them, and upgrade your equipment.\n\n[color=#72b5ff][b]Basic Controls (PC):[/b][/color]\n• [color=#00e5ff]WASD / Arrow Keys:[/color] Swim & Move\n• [color=#00e5ff]Shift (Hold):[/color] Fast Swim / Sprint (+50% speed, 2.6x oxygen consumption)\n• [color=#00e5ff]Left Click / E Key:[/color] Examine Item (Opens detail popup and take menu)\n• [color=#00e5ff]Right Click:[/color] Quick Take (Instantly pick up into bag without popup)\n• [color=#00e5ff]F Key:[/color] Toggle Dive Light (Aims toward mouse cursor, consumes battery)\n• [color=#00e5ff]Mouse Wheel / [ + ] [ - ] / P & O:[/color] Camera Zoom In / Out (Expands with diving mask upgrades)\n• [color=#00e5ff]I / Tab Key:[/color] Open / Close Backpack (Inventory)\n• [color=#00e5ff]C Key:[/color] Open / Close Collection Log (Discovered Items)\n• [color=#00e5ff]Right Click (In Bag):[/color] Lock / Unlock Item (🔒 Sell & craft protection)\n• [color=#00e5ff]E (At Surface):[/color] Board Boat & Return to Office Headquarters\n• [color=#00e5ff]ESC:[/color] Close open windows / Start dive when in office\n\n[color=#72b5ff][b]Mobile Controls (Touch):[/b][/color]\n• [color=#00e5ff]Left Screen:[/color] Dynamic Analog Joystick (360° free swim)\n• [color=#00e5ff]⚡ SPRINT:[/color] Toggle sprint mode on / off\n• [color=#00e5ff]⚡ QUICK TAKE:[/color] Instantly take nearby item into bag\n• [color=#00e5ff]🖐️ EXAMINE:[/color] Open detail popup for nearby item\n• [color=#00e5ff]🥽+ / 🥽- :[/color] Step camera zoom in / out\n• [color=#00e5ff]🔦 LIGHT:[/color] Toggle dive light on / off (3 aim modes selectable in settings)\n• [color=#00e5ff]Long Press (0.35s):[/color] Lock / unlock item in backpack 🔒\n\n[center][font_size=13][color=#5e8ca8]Developers: Queen Of Femboyss & Hakan Bey[/color][/font_size]\n[font_size=15][color=#00e5ff][i]⚓ Presented by Smile Games[/i][/color][/font_size][/center]"
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
    missing_keys = []

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
            missing_keys.append(key)

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

    if missing_keys:
        print("\n⚠️ TRANSLATION_MAP içine eklenmesi gereken eksik çeviriler:")
        for mk in missing_keys:
            print(f'    "{mk}": "TODO_ENGLISH",')



if __name__ == "__main__":
    main()
