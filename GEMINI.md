# Workspace Instructions & Rules

## 1. Deep Analysis & Planning First
- Her mekanik, sistem veya özellik eklemesinden önce derinlemesine mimari analiz ve adım adım plan çıkar.
- Kullanıcı onayı almadan doğrudan büyük kod değişikliklerine başlama.

## 2. Test ve Doğrulama Protokolü
- Kod yazarken statik tip güvenliğine (`var speed: float = 100.0`), Godot standartlarına ve talimatlara %100 uy.
- Kendi kendine gereksiz/sentetik headless test scriptleri (`SceneTree` harness vb.) çalıştırarak vakit ve context harcama.
- Kodundan ve mimarisinden emin olduğun an işi tamamla ve doğrudan **Kullanıcıdan Test Feedback'i İste**.

## 3. Kod ve Mimari Standartları
- Godot 4.x 2D, statik tipli GDScript.
- Veri odaklı `.tres` Resource mimarisi.
- CachyOS Linux ortamı, net ve doğrudan iletişim tarzı ("kanka"), sıfır laf kalabalığı (zero fluff).

## 4. Proje Dokümantasyonu & Mimari Senkronizasyonu (Architecture Sync)
- Yeni projeye başlandığında veya mimari yapının kavranması gerektiğinde, tüm `.tscn`, `.tres`, `.gd` ve yapılandırma dosyalarını okuyarak bağlantıları açıklayan bir `PROJECT_ARCHITECTURE.md` oluşturmayı öner veya oluştur.
- Projede kod, sahne, resource veya mekanik değişikliği yapıldığında; `PROJECT_ARCHITECTURE.md` dokümanını zorunlu olarak senkronize ve güncel tut.
