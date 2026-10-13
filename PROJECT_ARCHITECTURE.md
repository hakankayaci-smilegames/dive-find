# Dive&Find — Güncel Mimari ve Sistem Referansı

Bu belge, mevcut kaynak kodu ve sahne tanımlarından çıkarılmış teknik başvuru kaynağıdır. Oyunun veri sahipliğini, sahne akışını, sistem sınırlarını ve performans kararlarını tek yerde açıklar.

Eski sürüm günlükleri ve tekrar eden görsel iyileştirme notları bu belgeden özellikle çıkarılmıştır. Bir davranış değiştiğinde ilgili bölüm ile birlikte [GEMINI.md](GEMINI.md) talimatları da gözden geçirilmelidir.

## İçindekiler

1. Çalışma zamanı özeti
2. Oyuncu akışı ve sahne geçişleri
3. Proje ayarları ve Autoload katmanı
4. Kalıcı durum, kayıt ve ayarlar
5. Dalış dünyası ve oyuncu denetimi
6. Sonsuz harita ve ganimet üretimi
7. Ekonomi, envanter ve üretim
8. Merkezler, şehir haritası ve günlük döngü
9. Arayüz, giriş ve mobil katman
10. Veri, yerelleştirme ve varlık düzeni
11. Sinyal ve veri akışı özeti
12. Performans, sınırlar ve geliştirme notları

---

## 1. Çalışma zamanı özeti

| Başlık | Güncel durum |
| --- | --- |
| Motor | Godot 4.7, GDScript |
| Renderer | GL Compatibility; masaüstü ve mobil |
| Ana sahne | Scenes/main_menu.tscn |
| Oyun dünyası | Scenes/main.tscn |
| Kalıcı kullanıcı verisi | Godot user:// alanındaki JSON ve CFG dosyaları |
| Dil | Türkçe varsayılan, çalışma zamanında TR/EN geçişi |
| Oyun durumu | Autoload singleton'ları + aktif sahnedeki oyuncu bileşeni |

Temel döngü; şehir/liman merkezinden dalışa çıkmak, eşyaları toplamak, bunları satmak veya üretimde kullanmak, ekipmanı güçlendirmek ve sonraki gün daha derine inmektir. Dalış dünyası main.tscn içinde yaşamaya devam eder; merkezler ve menüler bu sahnenin üstüne eklenen CanvasLayer arayüzleridir. Böylece oyuncu ve dünya durumu sahne değişimi olmadan korunur.

~~~mermaid
flowchart LR
    Menu[Ana Menü] --> Load[Yükleme Ekranı]
    Load --> World[Dalış Dünyası]
    World --> City[Şehir Haritası]
    City --> Shack[İskele Barakası]
    Shack --> Dive[Dalışa başla]
    Dive --> World
    City --> Shops[Mağaza / Laboratuvar / Şarj]
    World --> GameOver[Boğulma]
    GameOver --> Shack
~~~

> Scenes/office_menu.tscn ve Scripts/office_menu.gd repoda bulunan eski merkez arayüzüdür. Geliştirici konsolunun office komutuyla hâlâ açılabilir; normal başlangıç akışının merkezi city_map.tscn ve dock_shack.tscn ikilisidir.

---

## 2. Oyuncu akışı ve sahne geçişleri

### Başlangıç ve kayıt yükleme

1. main_menu.gd, user://settings.cfg içinden ses, tam ekran ve dil tercihlerini uygular.
2. İlk açılışta veya oyun sürümü değiştiğinde dil seçimi gösterilir.
3. **Yeni Oyun**, GlobalInventory.start_new_game() ile oyun kaydını, envanteri, parayı ve ekipmanı sıfırlar; koleksiyon defteri korunur.
4. **Devam Et**, GlobalInventory.apply_save_to_game() ile gün, saat, para, ekipman ve envanteri belleğe alır.
5. Her iki yol loading_screen.tscn üzerinden main.tscn sahnesine geçer.
6. CanvasLayer._open_office_at_start() varsayılan olarak city_map.tscn örneğini açar ve oyun ağacını duraklatır.

### Merkez ve dalış geçişi

- **Şehir Haritası (CityMap):** Pinler aracılığıyla mağaza, laboratuvar, pazar, şarj istasyonu ve liman eylemlerini açar. Aktifken oyun duraklatılır.
- **İskele Barakası (DockShack):** Dalışa başlama, şehir haritasını ziyaret etme, çanta, koleksiyon ve ayarlara erişim sağlar. Dalışa başlanırken GlobalTime.record_dive() çağrılır, saat çalıştırılır, oyuncu su yüzeyine taşınır ve arayüz kapanır.
- **Dalış dünyası (main.tscn):** HUD aktif kalır; yüzeye yakınken merkez dönüşü erişilebilir olur. Geçişler loading_screen.gd'nin overlay modunu kullanır.
- **Game Over:** game_over.gd çantayı temizler, koleksiyon bilgisini korur ve oyuncuyu iskele barakasına döndürür.

### Gün kapatma

Oyun saati 19:00'a ulaştığında yeni dalışlar kilitlenir. Şehir haritası veya eski ofis arayüzü gün özeti sahnesini açar. day_summary.gd:

- Günlük kazanç, dalış sayısı, satılan eşya sayısı ve en derin noktayı gösterir.
- Yeni gün başlatıldığında GlobalTime.start_new_day() çağırır.
- Gün ve ekipman anlık durumuyla kayıt alır.
- Kısa overlay yükleme geçişi bittiğinde çağıran merkeze geri döner.

---

## 3. Proje ayarları ve Autoload katmanı

project.godot, ana sahneyi, renderer tercihini, çeviri kaynaklarını ve aşağıdaki altı Autoload'u tanımlar. Bu altı servis sahne sınırlarının ötesinde yaşayan küresel durum katmanıdır.

| Autoload | Kaynak | Sahip olduğu durum / sorumluluk |
| --- | --- | --- |
| GlobalInventory | Scripts/global_inventory.gd | Çanta, koleksiyon, eşya önbelleği, ekipman önbelleği, oyun kaydı ve autosave tercihi |
| GlobalEconomy | Scripts/GlobalEconomy.gd | Zurna bakiyesi ve para değişim sinyali |
| GlobalSoundManager | Scripts/global_sound_manager.gd | SFX önbelleği, Music/SFX bus'ları ve karıştırılmış müzik oynatma |
| GlobalTime | Scripts/global_time.gd | Gün/saat, günlük istatistikler, dalış kilidi |
| DevConsole | Scripts/dev_console.gd | Kilitli geliştirici konsolu ve test komutları |
| ItemTranslator | Scripts/item_translator.gd | Eşya çeviri JSON'unun yüklenmesi ve TR/EN çözümlemesi |

### Autoload olmayan destek sınıfları

- ItemData ve EquipmentUpgradeData, Godot Resource sınıflarıdır; sahne dışı veri tanımı için kullanılır.
- InfiniteMapManager, ItemSpawner, MobileControls, CityMap, DockShack ve MapPin sınıf adı olan sahne bileşenleridir; Autoload değildir.
- Scripts/global_player_data.gd repoda bulunsa da project.godot içinde Autoload olarak kaydedilmemiştir. Normal oyun akışının durum kaynağı değildir; yeni kodda ekipman veya kayıt için GlobalInventory kullanılmalıdır.

### Zaman servisi

GlobalTime başlangıçta gün 1, saat 10:00 ile çalışır. Saat her **20 gerçek saniyede 15 oyun dakikası** ilerler. time_speed_multiplier geliştirici komutları için çarpan sağlar.

| Sinyal | Tetikleyici | Tüketen sistem örnekleri |
| --- | --- | --- |
| time_changed(hour, minute) | Saat ilerlemesi veya kayıt yükleme | HUD, şehir ışığı, merkez başlıkları |
| day_changed(new_day) | Yeni gün veya kayıt yükleme | Harita eşya sıfırlama, merkezler, HUD |
| dive_lock_changed(is_locked) | Saat değişimi / gün başlangıcı | Dalış butonları |
| day_summary_requested(summary) | Ayrılmış arayüz sözleşmesi | Gün özeti entegrasyon noktası |

record_dive, record_depth ve record_sale fonksiyonları gün özetini besler. Gün başlatılırken bu sayaçlar sıfırlanır.

---

## 4. Kalıcı durum, kayıt ve ayarlar

### Dosyalar

| Yol | İçerik | Yazan/okuyan |
| --- | --- | --- |
| user://savegame.json | Gün, saat, para, ekipman, çantadaki resource yolları ve kilit durumları | GlobalInventory |
| user://collection_save.json | Keşfedilmiş eşya resource yolları | GlobalInventory |
| user://settings.cfg | Ses, görüntü, dil, autosave ve mobil kontrol tercihleri | Ana menü, ayarlar, mobil katman |

Bu dosyalar kullanıcıya aittir ve Git'e girmez.

### Oyun kaydı şeması

save_game() aşağıdaki alanları yazar:

~~~text
version, save_time,
current_day, current_hour, current_minute,
money,
equipment { tube_level, fins_level, goggles_level,
            backpack_level, flashlight_level, current_battery },
inventory_count, inventory_paths[], inventory_locked[]
~~~

Yükleme sırası önemlidir: önce ekipman önbelleği yüklenir, sonra GlobalTime ve GlobalEconomy güncellenir; son olarak her resource yolu yeniden yüklenip ItemData örneği kopyalanarak çantaya eklenir. Çanta eşyaları kopyadır; kaynak .tres dosyası asla kilit durumuyla değiştirilmez.

### Koleksiyon kaydı

Koleksiyon, çantadan bağımsızdır. Bir eşya ilk kez alınırken resource_path → true eşleşmesi discovered_items sözlüğüne yazılır. Bu yazma WorkerThreadPool göreviyle ve mutex altında yapılır. Eşya satılsa, bırakılırsa veya oyuncu ölürse keşif kaydı korunur.

### Ekipman durumu

GlobalInventory.equipment_data, oyuncu sahnede değilken ekipmanın bellek temsilidir. Oyuncu varken get_equipment_stat() doğrudan oyuncudan okur ve önbelleği eşitler. equipment_updated(stat_key, level) ve inventory_updated sinyalleri HUD ile açık menüleri yeniler.

---

## 5. Dalış dünyası ve oyuncu denetimi

### main.tscn bileşenleri

| Düğüm / sistem | Script | Görev |
| --- | --- | --- |
| Diver | player_controller.gd | Hareket, oksijen, sağlık, fener, kamera |
| MapMaker | map_maker.gd | Görünür chunk'ların üretimi ve kaldırılması |
| ItemSpawner | item_spawner.gd | Chunk tabanlı eşya üretimi / durum koruma |
| AmbientLight | ambient_light_controller.gd | Derinlik ve saate bağlı CanvasModulate |
| CanvasLayer | canvas_layer.gd | HUD, çanta, duraklatma ve merkez geçişi |

### Hareket, sprint ve yüzey

player_controller.gd, CharacterBody2D tabanlıdır. Klavye yön tuşları/WASD veya mobil joystick yön vektörü kullanılır. Yatay hareket sürtünmeyle, dikey hareket ise su içi süzülme ve doğal batışla yumuşatılır.

| Parametre | Güncel varsayılan | Etki |
| --- | ---: | --- |
| Taban azami hız | 220 px/s | Normal yüzme |
| İvme / sürtünme | 600 / 500 | Hızlanma ve bırakınca yavaşlama |
| Sprint hız bonusu | +110 px/s | Hareket varken Shift/mobil sprint |
| Sprint ivme çarpanı | 1.45× | Sprint tepkisi |
| Sprint oksijen çarpanı | 2.6× | Sprint maliyeti |
| Doğal batış tavanı | 40 px/s | Giriş yokken dikey süzülme |
| Derinlik ölçeği | 50 px = 1 m | HUD ve oksijen hesabı |

Oyuncu su yüzeyi bandındayken oksijen yeniler. Yüzeyin üstüne çıkmaya çalışırsa surface_push_force ile kontrollü olarak tekrar suya itilir. Bu, oyuncunun gökyüzü katmanına kaçmasını engeller.

### Oksijen, sağlık ve dönüş riski

Derinlik ve tüketim hesabı:

~~~text
depth_m = max((player_y - water_surface_y) / 50, 0)
depth_penalty = 1 + depth_m / 250
tube_efficiency = 1 + (tube_level - 1) × 1.25
drain_per_second = 1.8 × depth_penalty / tube_efficiency
~~~

Oyuncu sprintteyse son tüketim 2.6 ile çarpılır. Yüzeyde oksijen saniyede 30 puan yenilenir. Oksijen %15'in altına düştüğünde sağlık saniyede 2, oksijen sıfırken saniyede 15 azalır; oksijen tamamen dolu iken sağlık saniyede 12 yenilenir.

get_surface_return_info() HUD için dikey yüzeye çıkış süresini, ortalama tüketimi, gerekli oksijeni ve uyarı/eşik durumlarını hesaplar. HUD, bu bilgiyle dikkat ve kritik dönüş uyarıları gösterir.

### Ekipman etkileri

| Ekipman | Kaynak | Güncel hesap / davranış |
| --- | --- | --- |
| Tüp | tube_level | Her seviye oksijen verimine +1.25 ekler |
| Palet | fins_level | Azami hıza seviye başına +55 px/s, ivmeye bunun 2.5 katını ekler |
| Gözlük | goggles_level | Kamera minimum zoom'unu seviye başına 0.04 düşürür; alt sınır 0.01 |
| Çanta | backpack_level | Kapasite 5 + level × 5 |
| Fener | flashlight_level | Seviye 0'da kapalı; seviye arttıkça açı, menzil ve batarya büyür |

Fener seviyesinde ışık konisi bir kez üretilip seviyeye göre önbelleğe alınır. Seviye 1'de batarya 75 sn, menzil 1050 px, açı 95°'dir; sonraki seviyeler sırasıyla yaklaşık +8.93 sn, +110.71 px ve +4.286° ekler. Fener açıkken batarya saniyede 1 azalır. Şarj istasyonu, satın alınan şarj yüzdesine göre bataryayı geri doldurur.

### Etkileşim ve ölüm

- InteractableItem düğümleri interactable_items grubundadır.
- Yakındaki eşya E, sol tık veya mobil **İncele** ile popup açar; sağ tık/mobil **Direkt Al** ile doğrudan çantaya eklenir.
- Dolu çanta eşyayı almaz; hem popup hem HUD hata geri bildirimi verir.
- Sağlık sıfırlandığında game_over.tscn açılır. Çanta temizlenir, ancak koleksiyon silinmez.

---

## 6. Sonsuz harita ve ganimet üretimi

### Chunk ömrü

InfiniteMapManager, her yatay bölüm için 3840 px genişlikte bir Node2D chunk üretir. Her chunk; gökyüzü, su yüzeyi dahil okyanus katmanları ve zemin sprite'larını içerir. Katman sınırları layer_bounds metadata'sına yazılır; ItemSpawner bu bilgiyi kullanır.

Kamera hareket ettiğinde görünür sınır ile iki güvenlik tampon chunk'ı hesaplanır. Hesap, gözlüğün geniş görüşünde gereksiz yeniden üretim olmaması için anlık kamera zoom'u yerine en geniş referans zoom 0.08'i kullanır. Gerekli olmayan chunk'lar önce chunk_destroyed, ardından queue_free() ile kaldırılır.

~~~mermaid
sequenceDiagram
    participant Map as InfiniteMapManager
    participant Spawn as ItemSpawner
    participant Chunk as Chunk
    Map->>Chunk: generate_chunk(index)
    Map-->>Spawn: chunk_created(chunk, index)
    Spawn->>Chunk: yeni eşya üret / saklananları geri yükle
    Map-->>Spawn: chunk_destroyed(chunk, index)
    Spawn->>Spawn: toplanmamış eşya konumlarını sakla
    Map->>Chunk: queue_free()
~~~

### Katman ve kategori kuralları

item_spawner.gd, item_pool sahnelerini başlangıçta bir kez örnekleyip kategori, nadirlik ve spawn_weight bilgilerini önbelleğe alır. Her katman için birleşik ağırlıklı havuz oluşturulur.

| Katman | Uygun kategoriler |
| --- | --- |
| 0 | Spawn yok; su yüzeyi bandı |
| 1 | Trash |
| 2 | Trash, Resource |
| 3 | Resource, Rare Found |
| 4 | Resource, Rare Found, Valuable |
| 5–6 | Valuable, Resource |
| 7 | Valuable, Resource; bağımsız %5 Special denemesi |

Bir katmandaki nominal eşya sayısı:

~~~text
base_items       = 60 × base_spawn_chance
density_modifier = 1 / (1 + 0.25 × (layer_index - 1))
count            = round(base_items × density_modifier) + random(-1, 2)
count            = int(count × global_loot_multiplier)
~~~

Eşya seçimi kategori havuzundan spawn_weight ile yapılır; bu değer yoksa rarity geri dönüş değeridir. Nadirlik UI sunumu içindir, doğrudan katman yoğunluğunu değiştirmez.

### Aynı gün içi durum koruma

Spawner, bir chunk ilk kez görüldüğünde _spawned_chunk_indices_today içine indeksini ekler. Chunk kamera dışına çıktığında toplanmamış eşyaların sahnesi ve konumu _saved_chunk_items içinde saklanır. Oyuncu aynı gün geri dönerse yeni ganimet atmak yerine kalan eşyalar geri yüklenir. day_changed sinyali iki önbelleği temizler, aktif chunk'lardaki eski etkileşim eşyalarını kaldırır ve taze dağıtım başlatır.

### Atmosfer

AmbientLightController, yüzey rengi ile abis rengini hem derinlik hem oyun saatiyle karıştırır. max_depth_reference = 260 m ve eğri üssü 0.60 varsayılanlarıyla ilk derinlikler daha hızlı koyulaşır. DevConsole parlaklık override'ı otomatik hesabın önüne geçebilir.

---

## 7. Ekonomi, envanter ve üretim

### Ekonomi ve envanter

GlobalEconomy yalnızca money: int alanını yönetir. add_money() sıfır veya negatif eklemeyi, spend_money() ise yetersiz bakiye harcamasını reddeder. Her başarılı değişim money_changed(new_amount) yayar.

GlobalInventory.collected_items, anlık çanta listesidir. Eşya eklenirken kaynak ItemData kopyalanır, source_path atanır ve ilk kez görülüyorsa koleksiyona işlenir. Kapasite, oyuncu mevcutsa oyuncudan, değilse ekipman önbelleğinden hesaplanır.

Kilit (is_locked) yalnızca çanta kopyasında tutulur:

- Kilitli eşya toplu satışta hesaba katılmaz ve satılmaz.
- Laboratuvar kilitli eşyayı malzeme olarak tüketmez.
- Kilitli eşya çantadan denize bırakılamaz.
- Kayıtta inventory_paths[] ile paralel inventory_locked[] dizisi kullanılır.

Envanter değer veya kategori sırasına göre düzenlenebilir. Dalışta bırakılan eşya, uygun eşya sahnesiyle oyuncu yakınında tekrar üretilir; kaynak sahnesi yoksa item_temp.tscn fallback'i kullanılır.

### Satış ve ekipman

item_seller.gd aynı UI/script'i farklı shop_filter değerleriyle kullanır:

| Filtre | Amaç |
| --- | --- |
| TrashOnly | Çöpçü |
| NoTrash | Antikacı; çöp, özel, hammadde ve üretilmiş ürünleri dışarıda bırakır |
| SpecialOnly | Kara Borsa |
| CraftedOnly | Üretim/Pazar satışları |

Fiyat round(item.value × sell_multiplier) olarak hesaplanır. Tekli veya toplu satış tamamlanınca ekonomi güncellenir, envanterden silinir ve GlobalTime.record_sale() ile günlük bilanço beslenir.

equstore.gd, EquipmentUpgradeData resource'ları üzerinden ekipman kartlarını oluşturur. Kart maliyeti:

~~~text
upgrade_cost = round(base_cost × cost_multiplier^current_level)
~~~

max_level = -1, sınırsız geliştirme anlamına gelir. Başarılı yükseltme bakiye düşürür, oyuncu/önbellek ekipman değerini günceller ve ilgili sinyalleri yayar.

charge_station.gd, feneri olmayan oyuncu için işlem yapmaz. Hedef yüzde ile mevcut yüzde farkından şarj saniyesini çıkarır; maliyet ceil(charged_seconds × 0.30) ve en az 1 Zurna'dır. Başarılı şarj hem oyuncunun hem equipment_data.current_battery değerinin güncellenmesini sağlar.

### Laboratuvar

Tarifler Data/recipes.json içinden yüklenir. Her tarifin çıktı .tres yolu, para maliyeti ve { item_name, count } biçiminde malzemeleri vardır. Üretim; yeterli para, kilitsiz malzeme sayısı ve malzemeler çıkarıldıktan sonra çıktı için yeterli çanta alanı ister.

Başarılı üretim önce malzemeleri kaldırır, sonra para maliyetini çeker ve çıktı ItemData kopyasını çantaya ekler. Kaynak .tres bulunamazsa JSON verisiyle Crafted kategorisinde fallback eşya oluşturulur.

---

## 8. Merkezler, şehir haritası ve günlük döngü

### Şehir Haritası

CityMap, hub_menu, city_map ve popup_ui gruplarına katılır; açılışta oyun ağacını duraklatır. Her MapPin, iki dilli başlık/açıklama, isteğe bağlı sahne ve isteğe bağlı özel eylem taşır.

| Özel eylem | Sonuç |
| --- | --- |
| shack_dive | Overlay geçişiyle DockShack açılır |
| charge_station | Fener seviyesi kontrol edilir, ardından şarj arayüzü açılır |

Diğer pinler ilgili alt sahneyi açar. Aynı anda yalnızca bir _active_sub_menu tutulur. Şehir haritası animasyon karelerini statik önbellekten yürütür; ortam sesi SFX bus üzerinde yumuşakça açılıp kapanır.

### İskele Barakası ve eski ofis

DockShack, dalış öncesi hızlı merkezdir. Çanta, koleksiyon ve ayarlar doğrudan; şehir haritası ise yükleme overlay'i üzerinden açılır. Dalış düğmesi gün saatinin dalışa izin verdiğini denetler; oyuncuyu yüzey çevresine alır, dalış sayacını artırır, saati başlatır ve dünyayı yeniden etkinleştirir.

office_menu.gd, benzer ticaret/üretim arayüzlerini içeren uyumluluk ekranıdır. Yeni sistem eklerken yalnızca bu sahneye bağlanmak yerine CityMap ve DockShack akışında erişilebilirliği ayrıca değerlendirin.

---

## 9. Arayüz, giriş ve mobil katman

### HUD ve duraklatma

canvas_layer.gd şunları yönetir:

- Sağlık, oksijen, batarya, derinlik, para, gün ve saat göstergeleri,
- Dönüş için gereken oksijen uyarıları,
- Ekipman dock'u ve çanta kısayolu,
- Koleksiyon/uyarı toast'ları,
- Su altında isteğe bağlı renk perdesi,
- Envanter popup'ı, duraklatma menüsü ve merkez overlay geçişi.

Duraklatma menüsü CanvasLayer katmanında çalışır ve ağacı duraklatır. Ayarlar ekranını açabilir veya onay sonrası ana menüye dönebilir. Açık popup, merkez veya yükleme ekranı varken HUD uygun girişleri tüketir.

### Mobil kontroller

MobileControls yalnızca OS.has_feature("mobile") ise HUD tarafından eklenir. Sistem sol alanda ölçeklenebilir analog joystick; incele/direkt alma, sprint, fener, zoom ve duraklatma düğmeleri; ayrıca joystick, dokunmatik veya hibrit fener hedefleme modları sunar.

Yakın eşya taraması her frame yerine 10 Hz'e sınırlanır. Kontroller user://settings.cfg içindeki joystick ölçeğini ve fener hedefleme modunu okur. Bir merkez, popup veya duraklatma açıkken mobil katman görünmez olur ve joystick sıfırlanır.

### Yerelleştirme sonrası UI yenileme

Dil değişimi TranslationServer.set_locale() ile yapılır. DevConsole._refresh_active_uis() ve ayarlar ekranı; açık HUD, popup, mağaza, laboratuvar, ekipman mağazası ve ilgili grupların refresh_ui() metotlarını çağırarak görünür arayüzü yeniler.

---

## 10. Veri, yerelleştirme ve varlık düzeni

### Dizin sorumlulukları

| Yol | İçerik |
| --- | --- |
| Scenes/ | Ana dünya, menüler, hub'lar ve UI sahneleri |
| Scripts/ | Sistem, UI ve sahne davranışları |
| all_items_tres/ | Kalıcı ItemData tanımları |
| all_items_tscn/ | Haritaya üretilebilen InteractableItem sahneleri |
| Data/recipes.json | Üretim tarifleri |
| Data/loading_tips.json | Yükleme ekranı ipuçları |
| Translations/ | Godot metin çevirileri ile eşya çeviri JSON'u |
| Sprites/, Sounds/, Musics/ | Görsel ve ses varlıkları |

### Eşya modeli

| Alan | Anlamı |
| --- | --- |
| item_name, description, sprite | Kaynak ad, açıklama ve görsel |
| rarity | UI kalite kademesi 0–6 |
| spawn_weight | Aynı havuzdaki ağırlıklı seçim katsayısı |
| value | Taban Zurna değeri |
| category | Trash, Resource, Rare Found, Valuable, Special veya Crafted |
| is_locked | Yalnızca çalışma zamanı çanta kopyasının koruma durumu |
| source_path | Kaydetme/çeviri için kaynak resource yolu |

Kategori; mağaza filtresini, koleksiyon sekmesini ve popup rengini belirler. Nadirlik ise popup/slot görselinde Common ile Divine arasındaki rengi ve etiketi belirler.

### Metin çevirileri

İki ayrı kanal vardır:

1. **UI ve kod içi metinler:** Godot .translation kaynakları ve tr(...) çağrıları kullanılır. Kaynak CSV, Translations/translations.csv dosyasıdır.
2. **Eşyalar:** Translations/item_translations.json, res://all_items_tres/*.tres yollarını name ve description için tr/en nesnelerine eşler. ItemTranslator; önce source_path, ardından resource_path, dosya adı ve son olarak ham ad ile eşleştirmeyi dener.

Yeni oyuncuya görünen metin eklenirken iki dili birlikte eklemek zorunludur. Yeni eşya eklenirken resource, etkileşim sahnesi (haritada çıkacaksa), çeviri JSON'u ve uygun spawn havuzu birlikte güncellenmelidir.

---

## 11. Sinyal ve veri akışı özeti

~~~mermaid
flowchart TD
    Item[InteractableItem] -->|add_item| Inventory[GlobalInventory]
    Inventory -->|inventory_updated| UI[HUD / Çanta / Mağazalar]
    Inventory -->|collection_updated| Collection[Koleksiyon / HUD toast]
    Seller[Satış / Üretim / Yükseltme] --> Economy[GlobalEconomy]
    Economy -->|money_changed| UI
    Time[GlobalTime] -->|time_changed| HUD[HUD / Şehir Işığı]
    Time -->|day_changed| Spawner[ItemSpawner]
    Spawner -->|chunk_created/destroyed| Map[InfiniteMapManager]
    Settings[Ayarlar / DevConsole] --> Locale[TranslationServer]
    Locale --> UI
~~~

| Kaynak | Sinyal | Başlıca etkiler |
| --- | --- | --- |
| GlobalInventory | inventory_updated | Çanta kapasitesi, mağaza listesi, laboratuvar ve HUD yenileme |
| GlobalInventory | equipment_updated | Ekipman dock'u, merkez kartları, batarya erişimi |
| GlobalInventory | collection_updated(item) | Koleksiyon kitabı ve yeni keşif toast'ı |
| GlobalInventory | game_saved | Kayıt sonrası genişletme noktası |
| GlobalEconomy | money_changed(amount) | Cüzdan etiketleri, fiyat düğmeleri |
| GlobalTime | time_changed / day_changed | Gün/saat metinleri, ışık, spawn yenileme |
| InfiniteMapManager | chunk_created / chunk_destroyed | Eşya üretme ve item state retention |
| Oyuncu | oxygen_changed, health_changed, battery_changed | Durum barları ve merkez batarya göstergeleri |

---

## 12. Performans, sınırlar ve geliştirme notları

### Var olan optimizasyon kararları

| Alan | Uygulanan yaklaşım |
| --- | --- |
| Eşya tanımları | GlobalInventory.get_all_items() ilk yüklemede .tres tarar; sonraki çağrılar RAM önbelleğinden döner |
| SFX | GlobalSoundManager.preload_all_sfx() ses akışlarını yükleme aşamasında önbelleğe alır |
| Şehir haritası | Animasyon kareleri statik önbellekte tutulur; yükleme ekranı şehir sahnesini threaded olarak ister |
| Harita | Sadece kamera çevresindeki chunk'lar yaşar; geniş zoom için sabit simülasyon zarfı kullanılır |
| Spawn | Kategori ve katman havuzları bir kez oluşturulur; aynı gün chunk geri dönüşü saklı eşya konumlarından kurulur |
| Mobil | Yakın etkileşim taraması her frame yerine 10 Hz çalışır |
| Koleksiyon yazımı | JSON kaydı WorkerThreadPool görevinde ve mutex altında yapılır |

### Geliştirme kuralları

1. Yeni kalıcı durum eklerken GlobalInventory kayıt şemasını, yükleme yolunu ve yeni oyun sıfırlamasını birlikte güncelleyin.
2. Yeni ekipmanda; resource verisi, oyuncu etkisi, UI etiketi, kayıt anahtarı ve equipment_updated akışını birlikte ele alın.
3. Yeni eşya için ItemData resource yolu kayıt ve çevirinin ana anahtarıdır. Dosya taşınırsa mevcut kayıt ve item_translations.json eşleşmeleri etkilenir.
4. Harita katmanı veya kategori tablosu değişirse ItemSpawner.LAYER_CATEGORY_TABLE ve item pool sahne referanslarını birlikte doğrulayın.
5. Açık UI'larda dil değişimini test edin; yalnızca tr() kullanmak, dinamik eşya metninin otomatik yenilmesini garanti etmez.
6. Hub davranışını değiştirirken CityMap, DockShack ve eski OfficeMenu arasındaki aktif/uyumluluk farkını koruyun.
7. Dalışa ilişkin performans değişikliklerinde aynı gün geri dönülen chunk'larda toplanmamış eşya konumlarının korunup korunmadığını kontrol edin.

### Hızlı doğrulama rehberi

| Değişiklik alanı | Elle doğrulama |
| --- | --- |
| Kayıt | Oyunu kaydet, ana menüye dön, devam et; gün/saat/para/eşya kilidi/ekipmanı karşılaştır |
| Spawn | Bir chunk'tan uzaklaş, geri dön; aynı gün kalan eşyaların yerinde kaldığını, yeni günün yenilediğini denetle |
| Oksijen | Yüzey, derin dalış, sprint ve düşük oksijen dönüş uyarılarını dene |
| Ticaret | Kilitli eşyanın satılamadığını ve üretimde tüketilmediğini dene |
| Mobil | Hub açıkken kontrollerin gizlendiğini; joystick, sprint ve fener hedefleme modlarını dene |
| Dil | Ana menü, HUD, açık mağaza/popup ve eşya detaylarında TR/EN geçişini dene |

### Repo hijyeni

export_presets.cfg ve üretilen build dosyaları bu public repoda tutulmaz. Yerel export ayarları ile derlenmiş çıktılar .gitignore kapsamındadır. Mimari ve talimat belgeleri (PROJECT_ARCHITECTURE.md, GEMINI.md) bilerek takip edilir; geliştirme davranışının görünür kaynaklarıdır.
