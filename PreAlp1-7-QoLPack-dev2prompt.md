# Dive&Find Pre-Alpha 1.7 QoL Pack — Dev 2 Implementation Prompt

Bu belgeyi uygulama görevi olarak kabul et. Önce mevcut repo durumunu ve ilgili kaynakları incele; sonra aşağıdaki kapsamda küçük, gözden geçirilebilir değişiklikler yap. Bu prompt tek başına commit veya push yetkisi vermez.

## Hedef

Mevcut Dive&Find deneyimindeki kayıt güvenilirliğini, hata mesajlarının doğruluğunu, ayarlar ekranının yazma davranışını ve ölçümle doğrulanmış performans/ekran uyumunu iyileştir. Oyunun 2D dalış döngüsünü, kurallarını ve görsel kimliğini koru.

## Sabit proje kuralları

- Önce `GEMINI.md` ve `PROJECT_ARCHITECTURE.md` dosyalarını oku; kod değişikliğinden önce ilgili sahne, script ve resource bağlantılarını doğrula.
- Yalnızca bu paketin gerektirdiği satırlara dokun. Çalışan kodu yeniden düzenleme veya yeni soyutlama katmanları ekleme.
- Dalış fiziği, oksijen/sağlık formülleri, zaman hızı, ganimet miktarı ve havuzları, nadirlik, ekonomi, ekipman maliyetleri, tarifler, çanta kapasitesi ve eşya kayıp/koruma kuralları aynı kalmalı.
- Yeni veya değiştirilen oyuncuya görünen her metni Türkçe ve İngilizce sun. Statik metinlerde `tools/generate_translations.py` içindeki `TRANSLATION_MAP` ve `Translations/translations.csv` akışını kullan; üretilmiş çevirileri elle ve kaynaktan kopuk biçimde düzenleme. Eşya adları/açıklamaları için mevcut `ItemTranslator` ve `item_translations.json` düzenini koru.
- Dil değişiminde açık ekranlar mevcut `refresh_ui()` akışıyla güncellenmeli.
- Kod, sahne, formül, sinyal veya akış değişirse `PROJECT_ARCHITECTURE.md` aynı değişiklik içinde güncellenmeli.
- Sentetik/headless test harness oluşturma. Bu projede olmayan test altyapısı ekleme. Uygun statik kontrolleri ve aşağıdaki elle doğrulamaları kullan.
- Var olan kullanıcı değişikliklerini koru. Başlangıçta `git status --short` ve ilgili `git diff` çıktısını incele; mevcut değişiklikleri sıfırlama, stage etme veya bu paket commit’ine dahil etme.

## Başlangıçta doğrulanacak repo durumu

Önce `git status --short` çalıştır. İncelemenin önceki halinde kullanıcıya ait değişiklikler `Scripts/city_map.gd`, `Translations/translations.en.translation`, `Translations/translations.tr.translation` ve screenshot `.import` dosyalarında görülüyordu. Bunlar hâlâ değişikse içeriklerini koru; çeviri dosyası üretimi veya sahne düzenlemesi sırasında üzerlerine yazma. Herhangi bir hedef dosyada çakışan kullanıcı değişikliği varsa o dosyada dur ve raporla.

## Karar kapısı: oyun saati kapsamı

Kod ile mimari doküman arasında saat davranışı farkı var:

- `PROJECT_ARCHITECTURE.md`, saatin okyanusta ilerlediğini belirtiyor.
- `Scripts/global_time.gd`, `PROCESS_MODE_ALWAYS` kullanıyor ve saati başlangıçta çalıştırıyor.
- `Scripts/dock_shack.gd` dalış başlarken saati çalıştırıyor; mevcut script taramasında hub ekranlarına girerken çağrılan bir `pause_clock()` bulunmadı.

Bu fark mevcut oyuncu davranışını etkileyebilir. Saatin şehir/baraka ekranlarında ilerlemesinin istenip istenmediği açıkça doğrulanmadan `GlobalTime` davranışını değiştirme. Yanıt yoksa saat sistemine dokunmadan devam et, doküman-kod farkını sonuç raporunda belirt ve davranış kararını engel olarak kaydet. Kullanıcıya onay sorulması gereken başka bir kural değişikliği de aynı şekilde bekletilmeli.

## Uygulama kapsamı

### 1. Koleksiyon kaydında son durumu koru

**İlgili kaynak:** `Scripts/global_inventory.gd` (`_save_collection()`, `_load_collection()`, `reset_collection()`, `unlock_all_collection()`).

`_save_collection()` her çağrıda bir JSON anlık görüntüsünü ayrı `WorkerThreadPool` görevine veriyor. Mutex dosya yazımını sıraya koysa da görevlerin çağrılma sırasıyla tamamlanmasını garanti etmez. En küçük güvenli düzenlemeyle, diskte en yeni `discovered_items` durumunun kalmasını sağla. Uygun yaklaşım; tek yazıcı/son-değer coalescing veya eşdeğer sıralı yazım olabilir. Yeni bir kayıt servisi kurma.

Koleksiyon dosya yolu ve JSON şeması (`resource_path -> true`) değişmemeli. `reset_collection()` sonrası daha eski bir bekleyen yazım koleksiyonu geri getirmemeli. Dosya açılamazsa mevcut uyarı/hata görünürlüğünü koru.

`save_game()` mevcut dosyanın üzerine doğrudan yazıyor. Bu dosya için aynı dizinde geçici dosyaya yazıp başarılı yazım sonrası hedefe geçme seçeneğini değerlendir. Yalnızca Godot 4.7 ile uyumlu, hata durumunu raporlayan ve mevcut `version: 1` şemasını koruyan en küçük uygulamayı kullan. Uygun güvenli değiştirme yöntemi net değilse varsayım yapma; belirsizliği raporla ve mevcut kayıt yolunu değiştirme.

**Tamamlanma ölçütü:** Kayıt dosyası yolları ve alanları aynı; ardışık koleksiyon güncellemeleri ile sıfırlama sonrası yüklemede diskte son durum görülüyor; ana save/load gün, saat, para, ekipman, batarya ve kilitli eşyaları aynı şekilde geri getiriyor.

### 2. Craft düğmesinin nedenini doğru göster

**İlgili kaynak:** `Scripts/laboratory.gd` (`_select_recipe()`, craft kullanılabilirlik hesabı, `_on_craft_pressed()`).

Şu an para yetmediğinde de `can_craft` false oluyor ve düğme “Yetersiz malzeme / Not enough materials” metnini gösterebiliyor. Mevcut kontrolleri ve net slot hesabını değiştirmeden engel nedenini ayrı belirle: eksik malzeme, yetersiz bakiye veya çantada yer. Görsel hiyerarşi ve panel düzeni aynı kalsın; mevcut düğme/ücret/malzeme metinlerini doğru duruma göre güncelle.

Craft işleminin son kontrolünü koru; UI durumu değişmiş olsa bile `_on_craft_pressed()` mevcut doğrulamaları yapmaya devam etmeli. Tarif, maliyet, tüketim sırası veya çıktı değeri değiştirilmemeli.

**Tamamlanma ölçütü:** Malzeme eksik, para eksik, kapasite yetersiz ve üretilebilir durumların her biri doğru TR/EN açıklamayı gösteriyor; üretim matematiği aynı.

### 3. Etkileşim uyarılarını TR/EN tamamla

**İlgili kaynak:** `Scripts/interactable_item.gd` (`_check_quick_pickup()`, `_check_interaction()`, `quick_pickup()`) ve çeviri kaynakları.

Menzil dışı ve çanta dolu uyarılarının doğrudan Türkçe yazıldığı yolları bul. Metinleri projenin statik çeviri akışına ekle ve UI’da `tr()`/mevcut çeviri mekanizmasıyla göster. Mesafe kontrolü, çanta kontrolü, ses ve pickup sonucu aynı kalmalı. Toast metnini mevcut HUD toast görünümüne sığacak kadar kısa tut.

**Tamamlanma ölçütü:** Türkçe ve İngilizce dilde menzil dışı ve dolu çanta uyarıları doğru; başarılı ve başarısız pickup davranışı değişmemiş.

### 4. Ayar kaydırıcılarının disk yazımını azalt

**İlgili kaynak:** `Scripts/settings_menu.gd` (`_on_master_changed()`, `_on_music_changed()`, `_on_sfx_changed()`, `_on_joystick_slider_changed()`, `_save_settings()`, kapatma akışı).

Ses bus’larına ve joystick değer önizlemesine anında uygulamayı sürdür. `settings.cfg` yazımını her `value_changed` olayında yapmak yerine kullanıcı sürüklemeyi bitirdiğinde veya ekran güvenli biçimde kapatıldığında kaydet. Birden fazla değişiklikte tek kayda indir. Dil, tam ekran, autosave ve mobil fener hedefleme ayarlarının mevcut anahtarlarını ve değerlerini koru. Slider sinyallerini çift kayda yol açacak şekilde bağlama.

**Tamamlanma ölçütü:** Slider sürüklerken değer anında hissediliyor; ekran kapandıktan/yeniden açıldıktan ve uygulama yeniden başlatıldıktan sonra son değerler korunuyor; ayar şeması değişmiyor.

### 5. Performans ve ekran uyumunu ölçerek ele al

Bu bölümde profil sonucu olmadan optimizasyon iddiası üretme.

- Soğuk açılışta kaynak yükleme maliyetini ölç. `GlobalInventory._ready()` içinde `get_all_items()` çağrısı, `main_menu.gd` içindeki ertelenmiş `_preload_collection_cache()` ve `loading_screen.gd` ön yüklemesinin hangi işi ne zaman yaptığına bak. İlk görünen menüyü geciktirmeden ve koleksiyonun ilk açılışında takılma yaratmadan en küçük yükleme düzenini öner/uygula. Kaynak yolu, eşya önbelleği ve menü davranışı aynı kalmalı.
- `Scripts/item_spawner.gd` başlangıçta item pool sahnelerini örnekliyor; `Scripts/map_maker.gd` her kare chunk sınırlarını hesaplıyor. Bunları yalnızca profiler’da anlamlı maliyet görülürse değiştir. Chunk oluşturma/yok etme sinyalleri, `layer_bounds`, eşya yoğunluğu ve aynı gün chunk’a dönünce kalan eşyaların konumu korunmalı.
- Şehir haritası ve sabit boyutlu panelleri mevcut sanat/yapı düzenini değiştirmeden 16:9 ve dar yatay mobil çözünürlüklerde kontrol et. Taşma veya dokunma hedefi sorunu yoksa layout’u değiştirme. Sorun varsa yalnızca gerekli anchor/minimum boyut/ölçek davranışına cerrahi müdahale et.

**Tamamlanma ölçütü:** Önce/sonra ölçümü raporlanmış; doğrulanmayan performans iddiası yok; aynı gün chunk geri dönüşü ve standart/dar yatay ekranlarda temel etkileşimler korunmuş.

## Dokunulacak dosya sınırı

Beklenen hedefler, yalnızca yukarıdaki maddeler gerçekten uygulanırsa:

- `Scripts/global_inventory.gd`
- `Scripts/laboratory.gd`
- `Scripts/interactable_item.gd`
- `Scripts/settings_menu.gd`
- `Scripts/main_menu.gd`, `Scripts/loading_screen.gd`, `Scripts/item_spawner.gd` veya `Scripts/map_maker.gd` — yalnızca ölçümün gerektirdiği durumda
- `Translations/translations.csv`, `tools/generate_translations.py` ve üretilen TR/EN çeviri kaynakları — yalnızca yeni/düzeltilen UI metni varsa
- `PROJECT_ARCHITECTURE.md` — kod davranışı, veri akışı veya performans düzeni değişmişse

Gerekçe olmadan sahne hiyerarşisi, `.tres` item verileri, item pool listesi, ekonomi/tarif verileri, legacy `office_menu` veya `Scripts/city_map.gd` değiştirilmemeli. Başka bir dosyaya ihtiyaç çıkarsa önce mevcut mimaride neden gerekli olduğunu doğrula ve değişikliği en dar kapsamda tut.

## Elle doğrulama listesi

1. Yeni keşif, art arda birkaç keşif ve koleksiyon sıfırlamasından sonra oyunu kapatıp aç; son koleksiyon durumu korunmalı.
2. Devam et akışında gün/saat/para/ekipman/batarya/çanta/kilit verilerini karşılaştır.
3. Laboratuvarda dört craft durumunu (malzeme, bakiye, yer, üretilebilir) Türkçe ve İngilizce doğrula; malzeme/para/slot sayıları aynı kalmalı.
4. Dalışta menzil dışı ve dolu çanta mesajlarını iki dilde doğrula; başarılı pickup ve koleksiyon kaydı değişmemeli.
5. Ses ve mobil joystick ayarlarını değiştir, ayarlar ekranını kapatıp yeniden aç ve uygulamayı yeniden başlat; son değerler korunmalı.
6. Aynı gün bir chunk’tan uzaklaşıp geri dön; toplanmamış eşyalar aynı yerde olmalı. Yeni günde mevcut yenilenme davranışı sürmeli.
7. Şehir/baraka saat davranışını yalnızca karar kapısı yanıtlandıysa test et.
8. Şehir haritası ve temel panelleri standart 16:9 ile dar yatay mobil oranında kontrol et.

## Teslim

Değişen dosyaları ve her dosyanın gerekçesini listele. Korunan mekanik/ekonomi/spawn formüllerini açıkça belirt. Uygulanmayan ölçüm adaylarını ve saat davranışı kararı gerekiyorsa bunu ayrı yaz. Elle doğrulamalarda gerçekten yapılanları ve yapılamayanları ayır. `git status` içinde başlangıçtan gelen kullanıcı değişikliklerinin hâlâ kullanıcı değişikliği olarak kaldığını doğrula. Commit/push işlemi için ayrıca açık kullanıcı isteği yoksa git state’ini değiştirme.
