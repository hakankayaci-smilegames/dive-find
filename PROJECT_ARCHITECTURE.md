# Dive&Find — Proje Mimari ve Sistem Dokümantasyonu

Bu doküman, **Dive&Find** oyununun motor yapısını, sahne hiyerarşisini, kod mimarisini, veri modellerini, matematiksel formüllerini ve sistemler arası sinyal ağını detaylıca açıklar.

---

## 1. Oyun Döngüsü & Genel Bakış (Core Game Loop)

```mermaid
graph TD
    A[Ana Menü: YENİ OYUN / DEVAM ET] --> B[Loading Ekranı]
    B --> C[Ofis & Dalış Karargahı Otomatik Açılır - Kapı Açılma Sesi]
    C --> D[Çöpcü / Antikacı / Kara Borsa / Ekipman Yükseltme / Gün İlerletme]
    C -- DALIŞA BAŞLA [ESC / Tıkla] --> E[Kapı Kapanma Sesi + Spawn Suya Giriş]
    E --> F[Okyanusta Serbest Dalış & Loot Arama]
    F --> G{Oksijen / Can Durumu}
    G -- Boğulma / Can 0 --> H[Game Over Ekranı]
    H --> I[Çanta Silinir, Keşifler Kalır]
    I --> C
    G -- Yüzeye Çıkış & Ofis Butonu [E] --> C
    F -- Eşya Bulma [E] --> J[PopupUI: İncele / AL]
    J --> K[GlobalInventory Çantaya Ekler + Keşfi Kaydeder]
    C -- KAYDET & ÇIK --> L[GlobalInventory.save_game -> user://savegame.json]
    L --> A
```

---

## 2. Autoload (Singleton) Sistemleri

Proje genelinde `project.godot` üzerinden 3 temel Autoload tanımlıdır:

| Autoload Adı | Script Dosyası | Sorumluluk Alanı | Temel Değişkenler & Sinyaller |
| :--- | :--- | :--- | :--- |
| **`GlobalInventory`** | [`Scripts/global_inventory.gd`](file:///home/hakan/dive&find/Scripts/global_inventory.gd) | Çanta içeriği, keşif defteri, `.tres` önbelleği ve **Tam Oyun Save/Load Motoru** | `collected_items: Array[ItemData]`<br>`discovered_items: Dictionary`<br>`save_game()`, `apply_save_to_game()`, `apply_save_to_player()`, `has_save()`<br>Signals: `inventory_updated`, `collection_updated(item)` |
| **`GlobalEconomy`** | [`Scripts/GlobalEconomy.gd`](file:///home/hakan/dive&find/Scripts/GlobalEconomy.gd) | Para (Zurna) yönetimi, harcama ve bakiye sorgulama | `money: int`<br>Signals: `money_changed(new_amount)` |
| **`GlobalSoundManager`** | [`Scripts/global_sound_manager.gd`](file:///home/hakan/dive&find/Scripts/global_sound_manager.gd) | SFX bus ses yönetimi, Spotify shuffle müzik çaları, kapı sesleri (`door_open`, `door_close`) | `sfx_paths: Dictionary`<br>`play_sfx(sound_name)`<br>Buses: `"Music"`, `"SFX"` |
| **`GlobalTime`** | [`Scripts/global_time.gd`](file:///home/hakan/dive&find/Scripts/global_time.gd) | Dinamik gün ve saat döngüsü (10:00 başlangıç, 19:00 mesai sonu, 15dk adımlar), dalış kilidi, günlük bilanço takibi | `current_day`, `current_hour`, `current_minute`<br>`start_new_day()`, `is_dive_allowed()` |
| **`DevConsole`** | [`Scripts/dev_console.gd`](file:///home/hakan/dive&find/Scripts/dev_console.gd) | Küresel hile ve geliştirici konsolu (`é` / `~` tuşu), komut geçmişi, modüler komut sistemi | `money`, `upgrade`, `upgrade_all`, `fill_inv`, `god`, `surface`, `tp`, `office`, `die`, `time`, `add_time`, `time_speed`, `skip_day`<br>Layer: `128` |

---

## 3. Geliştirici & Hile Konsolu Komutları

| Komut | Parametre | Açıklama | Örnek Kullanım |
| :--- | :--- | :--- | :--- |
| **`help`** | - | Tüm kayıtlı komutları listeler | `help` |
| **`clear`** | - | Konsol ekranını temizler | `clear` |
| **`money`** | `<miktar>` | Cüzdana Zurna ekler / çıkarır | `money 5000` |
| **`upgrade`** | `<tüp/palet/gözlük/çanta> [seviye]` | Seçilen ekipmanın seviyesini ayarlar veya +1 artırır | `upgrade tube 5`, `upgrade fins` |
| **`upgrade_all`**| `[seviye]` | 4 ekipmanı birden o seviyeye ayarlar veya +1 artırır | `upgrade_all 4` |
| **`fill_inv`** | - | Çantayı kapasitesi dolana kadar rastgele eşyalarla doldurur | `fill_inv` |
| **`god`** | - | Ölümsüzlük modunu açar/kapatır (Can ve oksijen tükenmez) | `god` |
| **`surface`** | - | Karakteri anında su yüzeyine (0 metreye) ışınlar | `surface` |
| **`tp`** | `<metre>` | Karakteri belirtilen derinliğe anında ışınlar | `tp 700` |
| **`office`** | - | Nerede olunursa olunsun Ofis Karargahını anında açar | `office` |
| **`die`** | - | Karakteri anında öldürüp Game Over ekranını tetikler | `die` |
| **`time`** | `<saat> [dakika]` | Oyun saatini doğrudan ayarlar | `time 18 45` |
| **`add_time`** | `<dakika>` | Saati belirtilen dakika kadar ileri sarar | `add_time 30` |
| **`time_speed`**| `<çarpan>` | Zaman akış hızını hızlandırır/yavaşlatır | `time_speed 5.0` |
| **`skip_day`** | - | Günü anında 19:00'a sarıp Gün Özeti Ekranını açar | `skip_day` |

---

## 4. Dinamik Gün & Saat Döngüsü (Day & Time Loop)

- **Mesai Başlangıcı:** `10:00` (Ofis ve dalış açık)
- **Mesai Sonu / Dalış Kesintisi:** `19:00` (Ofiste yeni dalışlar kilitlenir, "GÜNÜ BİTİR & İLERLET" vurgulanır)
- **Zaman Akışı:** Her `30` gerçek saniyede bir saat `15` oyun dakikası ilerler (Bir tam günlük dalış mesaisi ~`18` dakika sürer). Saat hem okyanusta hem ofiste küresel olarak kesintisiz akar.
- **Erken Gün Bitirme Uyarısı:** Mesai (19:00) bitmeden "Günü İlerlet" basıldığında onay paneli çıkar; teyit edilirse gün erken kapatılır.
- **Gün Özeti & Bilanço Ekranı ([`Scenes/day_summary.tscn`](file:///home/hakan/dive&find/Scenes/day_summary.tscn)):**
  - Günlük toplam kazanç (+Zurna)
  - Yapılan toplam dalış sayısı
  - Satılan eşya adedi
  - Ulaşılan en derin nokta
  - Çanta durumu
  - "YENİ GÜNE BAŞLA ☀️" tıklandığında oyun otomatik kaydedilir, havalı bir `loading_screen` (1.6 sn) geçişi çalışır ve yeni güne (Saat 10:00) ofisten başlanır.

---

## 3. Kayıt ve Yükleme Sistemi (Save / Load)

- **Merkez**: [`Scripts/global_inventory.gd`](file:///home/hakan/dive&find/Scripts/global_inventory.gd)
- **Kayıt Yolu**: `user://savegame.json`
- **Kaydedilen Veriler**:
  - `current_day` (Mevcut gün sayısı)
  - `current_hour`, `current_minute` (Mevcut saat ve dakika)
  - `money` (Cüzdandaki toplam Zurna)
  - `equipment` (`tube_level`, `fins_level`, `goggles_level`, `backpack_level`)
  - `inventory_paths` (Çantadaki eşyaların `.tres` dosya yolları)
  - `inventory_locked` (Çantadaki eşyaların kilit durumları - Array[bool])
  - `save_time` (Kayıt tarihi ve saati)
- **Ana Menü Entegrasyonu**:
  - **"YENİ OYUN"**: `GlobalInventory.start_new_game()` çağırır. Diskteki kaydı siler, çantayı boşaltır, parayı sıfırlar (0), `GlobalTime`'ı Gün 1 ve saat 10:00'a resetler (`reset_to_new_game()`), mesai kilidini kaldırır, oyuncu ekipmanlarını varsayılana (Tüp 1, Palet 0, Gözlük 0, Çanta 0) çeker ve ofiste başlatır.
  - **"DEVAM ET"**: Kayıtlı oyun varsa aktifleşir; fare üzerine gelince detaylı kayıt özeti tooltip'i gösterir (Gün, Para, Eşya, Ekipman Seviyeleri, Tarih) ve ofiste başlatır.
- **Ofis Entegrasyonu**:
  - "KAYDET & ÇIK" tıklandığında anlık durum diske yazılır, kapı kapanma sesi çalar ve ana menüye dönülür.

---

## 4. Veri Modelleri & Kategori Renk Sistemi

### 4.1. Eşya Verisi — `ItemData`
- **Script**: [`Scripts/ItemData.gd`](file:///home/hakan/dive&find/Scripts/ItemData.gd) (`extends Resource`, `class_name ItemData`)
- **Dosyalar**: `res://all_items_tres/*.tres` (30 Adet Tanımlı Eşya)
- **Kategori Dağılımı ve Standart Renkler**:

| Kategori (`category`) | Görsel Renk Tonu | Hex / RGBA | Anlamı & Kabul Eden Dükkan |
| :--- | :--- | :--- | :--- |
| **`Trash`** | Gri / Taş | `Color(0.65, 0.65, 0.65)` | Düşük değerli atıklar $\rightarrow$ **ÇÖPCÜ** |
| **`Resource`** | Cyan / Açık Mavi | `Color(0.25, 0.75, 0.95)` | Hammaddeler (Craft için ayrılmıştır, dükkanlarda satılmaz) $\rightarrow$ **LABORATUVAR** |
| **`Rare Found`** | Mor / Magenta | `Color(0.75, 0.40, 0.95)` | Nadir buluntular $\rightarrow$ **ANTİKACI** |
| **`Valuable`** | Altın Sarısı | `Color(0.95, 0.80, 0.20)` | Yüksek değerli eşyalar $\rightarrow$ **ANTİKACI** |
| **`Special`** | Mercan / Kırmızı | `Color(0.95, 0.30, 0.45)` | Özel buluntular $\rightarrow$ **KARA BORSA** |

### 4.2. Ekipman Geliştirme Verisi — `EquipmentUpgradeData`
- **Script**: [`Scripts/EquipmentUpgradeData.gd`](file:///home/hakan/dive&find/Scripts/EquipmentUpgradeData.gd)
- **Formül**: $\text{Cost} = \text{round}(\text{base\_cost} \times \text{cost\_multiplier}^{\text{level}})$

| Ekipman | Başlangıç | Max Level | Base Cost | Cost Multiplier | Açıklama & Etki |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Oksijen Tüpü** | Lvl 1 | **Sınırsız (-1)** | 40 Zurna | **`1.75`** | Her seviyede $+1.25$ verimlilik |
| **Palet (Hız)** | Lvl 0 | **Sınırsız (-1)** | 25 Zurna | **`1.65`** | Her seviyede $+25\text{ px/s}$ yüzme & ivme hızı |
| **Gözlük (Görüş)** | Lvl 0 | **Sınırsız (-1)** | 60 Zurna | **`1.90`** | Her seviyede $-0.04$ min zoom |
| **Çanta** | 5 Slot | **Sınırsız (-1)** | 20 Zurna | **`1.50`** | Her seviyede $+5$ slot kapasite |

---

## 5. Oynanış ve Karakter Fiziği — `player_controller.gd`

- **Sınıf**: [`Scripts/player_controller.gd`](file:///home/hakan/dive&find/Scripts/player_controller.gd) (`extends CharacterBody2D`, Grup: `"player"`)
- **Spawn**: Su yüzeyinin $60\text{px}$ üstünden $450\text{px/s}$ hızla anında ve dinamik dalış.
- **Ekipman Seviyeleri**: `GlobalInventory.apply_save_to_player(self)` ile kayıtlı oyundan otomatik yüklenir.
- **Hareket & Yüzme**: `max_speed` ($220 + \text{fins\_level} \times 25$), `acceleration` ($600 + \text{fins\_level} \times 25$), `friction`, `sink_speed`, `max_sink_velocity`.
- **Kamera & Görüş**: Başlangıç zoom $0.45$, min zoom $0.45 - (\text{goggles\_level} \times 0.04)$.
- **Yüzey Sekme Kuvveti**: `InfiniteMapManager.water_surface_y` üstüne çıkmaya çalıştıkça aşağı iten yay kuvveti (`surface_push_force`).
- **Derinlik & Oksijen Dengesi**:
  $$\text{depth\_m} = \max\left(0, \frac{\text{global\_position.y} - \text{water\_surface\_y}}{\text{pixels\_per\_meter}}\right)$$
  $$\text{drain\_rate} = \text{base\_oxygen\_drain\_rate} \times \left(\frac{1.0 + \frac{\text{depth\_m}}{250.0}}{1.0 + (\text{tube\_level} - 1) \times 1.25}\right)$$
- **Can & Boğulma**: Oksijen $\%15$ altındayken yavaş, $\%0$ iken agresif can kaybı. Can sıfırlanınca `Scenes/game_over.tscn` açılır.

---

## 6. Sonsuz Harita & Katman Mimarisi — `map_maker.gd`

- **Script**: [`Scripts/map_maker.gd`](file:///home/hakan/dive&find/Scripts/map_maker.gd) (`class_name InfiniteMapManager`)
- **Katmanlar**: Sky $\rightarrow$ lvl0 (Yüzey) $\rightarrow$ lvl1-lvl7 (Okyanus Katmanları) $\rightarrow$ Ground (Zemin).
- **Dinamik Yükleme**: Kamera hareketine göre chunk'lar dinamik yüklenir ve silinir.

---

## 7. Eşya Üretim ve Katman Havuzlama — `item_spawner.gd`

- **Script**: [`Scripts/item_spawner.gd`](file:///home/hakan/dive&find/Scripts/item_spawner.gd) (`class_name ItemSpawner`)
- **Katman Eşleşmesi**:
  - Katman 1: `Trash`
  - Katman 2: `Trash`, `Resource`
  - Katman 3: `Resource`, `Rare Found`
  - Katman 4: `Resource`, `Rare Found`, `Valuable`
  - Katman 5-6: `Valuable`, `Resource`
  - Katman 7: `Resource`, `Special`
- Ağırlıklı rastgele seçim: `rarity` (weight) üzerinden hesaplanır.

---

## 8. Kullanıcı Arayüzü (UI/UX) & Menü Mimarisi

### 8.1. Ana Menü ([`Scripts/main_menu.gd`](file:///home/hakan/dive&find/Scripts/main_menu.gd) & `Scenes/main_menu.tscn`)
- **YENİ OYUN & DEVAM ET**:
  - `DEVAM ET`: Kayıtlı oyun varsa aktif, fare üzerinde detaylı save özeti tooltip'i (Gün, Para, Eşyalar, Ekipmanlar, Kayıt Tarihi).
  - `YENİ OYUN`: Sıfırdan temiz bir başlangıç açar.
- **Sürüm Yönetimi**: `@export var game_version: String = "v0.0.2 (Devbuild)"` değişkeni hem `VersionLabel` hem Bilgi panelini senkronize eder.

### 8.2. Ofis & Dalış Karargahı ([`Scripts/office_menu.gd`](file:///home/hakan/dive&find/Scripts/office_menu.gd) & `Scenes/office_menu.tscn`)
- **Tam Ekran Opak Yatay Düzen**:
  - Oyun açılışında otomatik olarak oyuncuyu karşılar (Kapı açılma sesiyle).
  - **Üst Bar**: Başlık, Gün Sayacı, "GÜNÜ İLERLET ☀️" (Erken gün onay popup'lı), Zurna Cüzdan Rozeti, "KAYDET & ÇIK" (`GlobalInventory.save_game`).
  - **Canlı Tüccar Rozetleri (Loot Badges & Glow)**:
    - Çantadaki eşyaları anlık tarayarak Çöpçü (`🟢 3 Hurda (+180 Z)`), Antikacı (`🟢 1 Antika (+90 Z)` - Ham maddeler craft için hariç tutulur) ve Kara Borsa (`🔴 1 Özel (+300 Z)`) kartlarının üstünde canlı rozetler gösterir.
    - Satılabilir eşyası olan tüccarlar şık bir nabız / nefes alma animasyonuyla (`Pulse Glow Tween`) hafifçe parıldar.
    - Ekipman Atölyesi kartı, cüzdandaki para herhangi bir geliştirmeye yetiyorsa parıldayan `✨ Yükseltme Hazır!` rozeti takar.
  - **ESC Kapatma Hiyerarşisi**: Açık bir tüccar, çanta veya koleksiyon penceresi varsa `ESC` önce o alt pencereyi kapatır; alt pencere yoksa dalışı başlatır.
  - **Alt Tesisler Bölgesi**: Ekipman Mağazası (Aktif), Laboratuvar (Çok Yakında), Satış Pazarı (Çok Yakında).
  - **Alt Bar**: Çanta [I], Koleksiyon [C], Dinamik Toast Bildirimleri, Dalışa Başla [ESC].

---

## 8. Okyanus HUD & Kompakt Arayüz Mimarisi (`canvas_layer.gd`)

- **Sağ Üst Action Bar & Bağlamsal Eylemler:**
  - `💰 0 Zurna`: Koyu ahşap ve eskitilmiş altın çerçeveli kompakt cüzdan rozeti.
  - `🎒 Çanta [I] (%d/%d)`: Çanta butonu ve klavye kısayolu ([I] / [Tab]). Çanta dolduğunda kırmızı uyarı tonu alır.
  - `🚤 Tekneye Çık [E]` (Bağlamsal Ofise Dönüş): Dalgıç suyun dibindeyken ekranda gereksiz yer kaplamaz, tamamen gizlenir (`modulate.a = 0.0`). Yüzeye yaklaşıldığında yumuşakça parıldayarak belirir ve klavyeden `[E]` tuşuyla da tekneye binilebilir.
- **Kompakt Ekipman Dock'u (`EquipmentDock`):**
  - Eski 260x220 dev kutu yerine sağ altta 195x50 boyutlarında ultra hafif ve ferah yatay dock.
  - Atölyedeki orijinal ikonlar kullanılır (`oksijen_tupu.png`, `palet.png`, `dalis_gozluk.png`, `canta.png`).
  - Her ikonun altında anlık seviye (`Lv.1`), üzerine gelindiğinde detaylı bilgilendirme tooltip'i gösterilir.
- **Responsive Anchor Düzeni:**
  - `TimePanel` ekranın tam üst ortasına (`anchors_preset = 5`) kilitlendi, her ekran oranında merkezlenir.
  - `Depth` göstergesi sol alt köşeye bağlandı (`anchors_preset = 2`).
- **Canlı Yüzey & Derinlik Takibi:**
  - `⚓ DERİNLİK: 45m  |  ↑ Yüzey: 45m` formatı ile oyuncunun yüzeye olan mesafesi anlık bildirilir. Yüzeydeyken `⚓ YÜZEYDESİN (0m)` yazar.
- **Kritik Oksijen Nabız Alarmı:**
  - Oksijen %25'in altına düştüğünde oksijen göstergesi kırmızı nabız gibi parıldayarak (`Pulse Tween`) oyuncuyu uyarır.

---

## 9. Sahne ve Script Çapraz Referans Tablosu

| Sahne (`.tscn`) | Bağlı Script (`.gd`) | Açıklama |
| :--- | :--- | :--- |
| `Scenes/main_menu.tscn` | `main_menu.gd` | Ana menü (Yeni Oyun, Devam Et + Tooltip, Ayarlar, Sürüm) |
| `Scenes/main.tscn` | `canvas_layer.gd`, `player_controller.gd`, `map_maker.gd`, `item_spawner.gd` | Ana dalış dünyası ve HUD |
| `Scenes/office_menu.tscn` | `office_menu.gd` | Ofis & Dalış Karargahı (Tam Ekran Yatay Hub, Kaydet & Çık) |
| `Scenes/loading_screen.tscn` | `loading_screen.gd` | Yükleme ekranı & `.tres` önbellekleyicisi |
| `Scenes/pickup.tscn` | `popupui.gd` | Eşya inceleme & alma pop-up'ı (Önizleme modu destekli) |
| `Scenes/inventory.tscn` | `inventory.gd` | Çanta arayüzü & toplam değer |
| `Scenes/inventory_slot.tscn` | `inventory_slot.gd` | Kategori renkli dinamik slot |
| `Scenes/equstore.tscn` | `equstore.gd` | Ekipman mağazası |
| `Scenes/equipment_slot.tscn` | `equipment_slot.gd` | Ekipman yükseltme hücresi |
| `Scenes/copcu.tscn` | `item_seller.gd` | Sadece Trash kategorisi satış dükkanı |
| `Scenes/antikaci.tscn` | `item_seller.gd` | Çöp hariç normal & değerli eşya satışı |
| `Scenes/kara_borsa.tscn` | `item_seller.gd` | Özel kategori eşya satışı (Hepsini Sat destekli) |
| `Scenes/collection.tscn` | `collection.gd` | Keşif defteri (Önizleme kartı açılışlı) |
| `Scenes/collection_slot.tscn` | `collection_slot.gd` | Keşif defteri hücresi (Tıklanabilir keşifler) |
| `Scenes/game_over.tscn` | `game_over.gd` | Boğulma / ölüm ekranı |
| `Scenes/laboratory.tscn` | `laboratory.gd` | Kompakt sentez/crafting tezgahı & JSON tarif okuyucusu |
| `Scenes/pazar.tscn` | `item_seller.gd` | Üretilen Crafted eşyaların satıldığı ihracat pazarı |
| `all_items_tscn/item_temp.tscn` | `interactable_item.gd` | Haritadaki toplanabilir eşya tabanı |

---

## 10. Envanter (Çanta) & Satış Ekranı QOL Mimarisi

- **Eşya Kilitleme / Koruma Sistemi (Right-Click Lock 🔒):**
  - Çantada veya tüccar ekranında slot üzerine **Sağ Tık** yapıldığında eşyaya kilit vurulur (`is_locked: bool`).
  - Kilitlenen slotların sağ üst köşesinde `🔒` rozeti (`LockBadge`) belirir.
  - **Güvenli Satış (Hepsini Sat Koruması):** `item_seller.gd` içindeki "HEPSİNİ SAT" butonu kilitli eşyaları kesinlikle satmaz, toplam satış tutarını da yalnızca kilitsiz eşyalardan hesaplar. Tüm eşyalar kilitliyse buton devre dışı kalarak `TÜMÜ KİLİTLİ 🔒` yazar.
  - Tekli satış butonuna kilitli bir eşyayla basıldığında satış engellenir ve `error` SFX çalar.
  - Kilit durumları kayıt dosyasına (`user://savegame.json -> inventory_locked`) kaydedilir ve geri yüklenir.
- **Akıcı Hover Önizleme (Instant Preview):**
  - Fare bir slotun üzerine geldiği an (`mouse_entered`), sağdaki detay paneli anında güncellenir. Tıklama zorunluluğu kalkmıştır.
- **Çanta Otomatik Sıralama (Sort):**
  - Çantaya eklenen `🔄 Sırala` butonu tek tıkla çantayı Fiyata Göre (`sort_inventory_by_value()`) veya Türe/Kategoriye Göre (`sort_inventory_by_category()`) dizer.
- **Çanta Doluluk Uyarısı (Audio + Visual Shake):**
  - Çanta tamamen doluyken su altında eşya alınmaya çalışıldığında `GlobalSoundManager.play_sfx("error")` çalar ve "DOLU" butonu kırmızı parıldayarak sağa-sola titrer (`Micro-Shake Tween`).
- **Arayüz İpuçları (Hint Labels):**
  - Hem çanta panelinde hem de dükkan ekranında oyuncuya sağ tıkla eşya kilitleme ve güvenli satış özelliğini hatırlatan bilgilendirme etiketleri yer alır.

---

## 11. Koleksiyon Kitabı & Ekipman Atölyesi QOL Mimarisi

- **Koleksiyon Kitabı Kategori Sekmeleri (`CategoryTabs`):**
  - Üst kısma yerleştirilen `[Hepsi] [🗑️ Çöp] [🧪 Madde] [🏛️ Nadir] [💎 Değerli] [🔴 Özel]` butonları ile 30 eşyalık defter tek tıkla filtrelenir.
  - Seçili kategoriye göre anlık kategori ilerlemesi (`Hammaddeler: 4 / 6 Keşfedildi`) ve genel defter tamamlama yüzdesi (`ProgressBar`) eşzamanlı gösterilir.
  - Aktif filtre sekmesi görsel vurgu alır.
- **Ekipman Atölyesi Stat Kazanç Önizlemesi (`StatPreviewLabel`):**
  - Her ekipman hücresinde bir sonraki yükseltmenin getireceği somut kazanç yeşil renkle açıkça belirtilir:
    - Oksijen Tüpü: `Oksijen: x1.00 ➔ x2.25`
    - Sırt Çantası: `Kapasite: 5 ➔ 10 Slot`
    - Palet: `Hız: +0 ➔ +25 px/s`
    - Dalış Gözlüğü: `Görüş: Lvl 0 ➔ 1`
  - Maksimum seviyeye ulaşan ekipmanlarda `MAKSİMUM SEVİYE` etiketi ve pasif `MAX` butonu gösterilir.
- **Canlı Bakiye ve Yetersiz Para Hesabı:**
  - Paranın yetmediği durumlarda buton pasifleşir ve eksik tutar anlık yazılır: `YETERSİZ (-45 Z)` + detaylı tooltip.
- **Geliştirme Hissiyatı (Micro-Punch Animasyonu):**
  - Yükseltme satın alındığında kart hafifçe büyüyüp yerine oturur (`play_upgrade_feedback()`) ve `upgrade` SFX çalar.

---

## 12. Juice, Polish & Mikro-Etkileşim Mimarisi

- **Rolling Money Counter (Akıcı Bakiye Sayacı):**
  - Hem okyanus HUD'ında (`canvas_layer.gd`) hem de Ofis menüsünde (`office_menu.gd`), bakiye artışı veya azalışında değer aniden değişmek yerine `Tween.TRANS_QUAD` ile 0.45 saniye içinde yumuşakça yuvarlanarak hedef tutara ulaşır.
- **Floating Cash / Kayan Altın Efekti (`_spawn_floating_cash`):**
  - Dükkanlarda tekli veya toplu satış yapıldığında (`item_seller.gd`) ya da bakiye arttığında, butonun veya cüzdanın üzerinden yukarı doğru süzülerek sönen altın rengi `+X Zurna` kayan etiketleri belirir.
- **Micro-Punch Dokunsal Buton Tepkisi (`_setup_button_juice`):**
  - Butonların üzerine gelindiğinde `scale ➔ 1.03-1.04` hafif kabarma, tıklandığında `scale ➔ 0.95 ➔ 1.0` yaylanma tepkisi vererek arayüze fiziksel ve tatmin edici bir dokunsal hissiyat kazandırır.
- **Bağlamsal Tuş Kısayolları (Seamless Controls):**
  - Dalıştayken `[I]` veya `[Tab]` tuşu ile çanta açma/kapatma.
  - Su yüzeyindeyken `[E]` tuşu ile doğrudan tekneye çıkıp ofis karargahına geçiş.

---

## 13. Yükleme Ekranı & Gerçek Asenkron Yükleme Mimarisi (`loading_screen.gd`)

- **Şeffaf & Atmosferik Okyanus Tasarımı (`loading_screen.tscn`):**
  - Eski koyu kahverengi hantal kutu kaldırılarak Ana Menü ile tam görsel uyum sağlandı.
  - 3 katmanlı okyanus paralaksı (`SkyTexture`, `OceanTexture`, `DeepTexture`) ve saydam koyu okyanus filtresi (`BackgroundTint`).
  - Merkezde neon cyan ışıltılı `Dive & Find` logosu ve parıldayan `✦ DALIŞA HAZIRLANIYOR ✦` rozeti.
- **Gerçek Asenkron Sahne Yükleme (`ResourceLoader.load_threaded_request`):**
  - Sahte `Tween` bar yerine Godot'nun yerleşik asenkron yükleyicisi bağlandı. `ResourceLoader.load_threaded_get_status()` ile diskten RAM'e aktarılan gerçek dosya boyutu/yüzdesi okunur.
  - Sahne belleğe tam olarak yüklendiğinde `get_tree().change_scene_to_packed()` ile sıfır donmayla geçiş yapılır.
- **SFX Pre-Caching & Ses Takılmalarının Sıfırlanması:**
  - [`global_sound_manager.gd`](file:///home/hakan/dive&find/Scripts/global_sound_manager.gd) içinde `preload_all_sfx()` ve `_sfx_cache` eklendi. Tüm ses efektleri loading esnasında RAM'e alınarak oyun içindeki ilk etkileşim takılmaları (audio stutter) önlendi.
- **Yatay Geniş Loading Bar & Aşama Durumları:**
  - Ekranın alt kenarı boyunca uzanan ince, şık ve neon turkuaz dolgulu ProgressBar (`#00e5ff`).
  - Dinamik yüzde sayacı (`%0 ➔ %100`) ve aşamalı teknik durum metni (`Eski kalıntılar taranıyor...` ➔ `Ses dosyaları ve harita katmanları hazırlanıyor...` ➔ `Dalışa Hazır!`).
- **Sinematik Geçişler (Fade-to-Black & Fade-in):**
  - Yükleme tamamlandığında 0.25sn yumuşak kararma (`Fade to Black`) ile pürüzsüz çıkış.
  - Ofis karargahı (`office_menu.gd`) açıldığında `$Background.modulate.a` 0.35 saniyede soluktan nete gelerek (`Fade-in`) sinematik bir giriş hissi sunar.
- **Modüler İpucu Sistemi ([`Data/loading_tips.json`](file:///home/hakan/dive&find/Data/loading_tips.json)):**
  - İpuçları koda gömülmek yerine bağımsız JSON dosyasında tutulur. Koda dokunmadan kolayca genişletilebilir.
  - Her yükleme ekranı açılışında rastgele bir oynanış ipucu seçilip gösterilir.

---

## 14. Laboratuvar (Crafting) & Satış Pazarı Mimarisi

- **`Crafted` Kategori Entegrasyonu:**
  - `ItemData.category` enum'ına `"Crafted"` eklendi (`#ff8c00` amber/turuncu zanaat rengi).
  - `inventory_slot.gd`, `popupui.gd`, `inventory.gd` ve `item_seller.gd` arayüzlerine tam uyum sağlandı.
  - **Önemli Kural:** `Crafted` eşyalar `ItemSpawner` havuzuna **asla dahil edilmez**, okyanusta doğal olarak spawn olmaz. Sadece Laboratuvarda üretilir ve Pazarda satılır.
- **Modüler Tarif Fihristi ([`Data/recipes.json`](file:///home/hakan/dive&find/Data/recipes.json)):**
  - Tarifler kod dışından JSON ile tanımlanır. Yeni tarif eklemek için kod değiştirmeye gerek yoktur.
  - Her tarif; id, ad, açıklama, çıktı `.tres` yolu, Zurna masrafı ve gerekli malzeme listesini (`ingredients`) içerir.
- **Kompakt Laboratuvar & Sentez Masası ([`Scenes/laboratory.tscn`](file:///home/hakan/dive&find/Scenes/laboratory.tscn) & [`Scripts/laboratory.gd`](file:///home/hakan/dive&find/Scripts/laboratory.gd)):**
  - 860x540 kompakt ofis tasarımında açılan sentez penceresi.
  - Sol taraf: Tarif fihristi (kartlar üzerinde anlık malzeme stok durumu `2/2 ✅` ve üretilebilirlik vurgusu).
  - Sağ taraf: Seçili ürün detayları, çanta stoğu, Zurna maliyeti ve üretim butonu.
  - **Kilit Güvenliği (Right-Click Lock 🔒):** Çantada kilitlenmiş eşyalar asla craft malzemesi olarak harcanmaz.
  - **Görsel Geri Bildirim:** Üretimde yeşil `✨ +1 [Eşya Adı]` kayan metin efekti, mikro-punch yaylanması ve `upgrade` SFX.
- **Satış Pazarı ([`Scenes/pazar.tscn`](file:///home/hakan/dive&find/Scenes/pazar.tscn)):**
  - `item_seller.gd` motorunu `shop_filter = "CraftedOnly"` ile kullanan ihracat dükkanı.
  - Üretilen eşyaların toplu satışı, kilit koruması ve kayan altın kazanç efektleri hazır olarak çalışır.
- **Aktif Tarifler ve Ürünler:**
  - `Ananas Suyu` (90 Z) ➔ 2x Ananas? + 5 Zurna ([`all_items_tres/ananas_suyu.tres`](file:///home/hakan/dive&find/all_items_tres/ananas_suyu.tres))
  - `İşlenmiş Plastik Bobini` (35 Z) ➔ 3x Pet şişe + 2x Poşet + 2 Zurna ([`all_items_tres/geri_donusum_plastigi.tres`](file:///home/hakan/dive&find/all_items_tres/geri_donusum_plastigi.tres))
  - `Preslenmiş Alüminyum Bloğu` (85 Z) ➔ 2x Bükük kola + 2x Bükük pepsi + 1x Monster Kutusu + 1x Bükük Çatal + 10 Zurna ([`all_items_tres/aluminyum_blogu.tres`](file:///home/hakan/dive&find/all_items_tres/aluminyum_blogu.tres))
  - `Tropikal Radyoaktif Kokteyl` (280 Z) ➔ 1x Gizemli Şişe + 2x Ananas? + 1x Monster Kutusu + 15 Zurna ([`all_items_tres/radyoaktif_kokteyl.tres`](file:///home/hakan/dive&find/all_items_tres/radyoaktif_kokteyl.tres))
  - `Restore Edilmiş Tablo` (3800 Z) ➔ 1x Kırık Altın Çerçeve + 1x Zoktayın Saç Renginde Boya + 1x Isırılmış Kitap + 150 Zurna ([`all_items_tres/restore_tablo.tres`](file:///home/hakan/dive&find/all_items_tres/restore_tablo.tres))
- **Koleksiyon Defteri Entegrasyonu:**
  - `collection.gd` ve `collection_slot.gd` içine `Crafted` (amber/turuncu zanaat rengi) eklendi.
  - Koleksiyon arayüzüne `🔨 Üretilen` sekmesi ([`Scenes/collection.tscn`](file:///home/hakan/dive&find/Scenes/collection.tscn)) entegre edildi.
  - Laboratuvarda ürün üretildiğinde `resource_path` kaybı engellenerek `GlobalInventory._mark_discovered()` tetiklemesi sağlandı; üretilen ürün anında koleksiyon defterinde keşfedilmiş olarak açılır.

