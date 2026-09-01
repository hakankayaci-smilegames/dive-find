---
description: Proje mimari analizi, mimari MD dokümantasyon önerisi ve kod değişikliklerinde mimari dokümanın güncel tutulması kuralı.
globs: ["**/*"]
always_on: true
---

# Architecture Documentation & Continuous Sync Rule

## 1. Mimari Doküman Önerisi ve Oluşturulması
- Yeni bir projeye girildiğinde veya projenin genel yapısının anlaşılması gerektiğinde; tüm scriptleri, sahneleri, resource'ları ve sistem bağlantılarını içeren kapsamlı bir mimari dokümanın (`PROJECT_ARCHITECTURE.md`) oluşturulmasını öner veya oluştur.

## 2. Zorunlu Mimari Doküman Senkronizasyonu (Continuous Sync)
- Projede mekanik, sahne hiyerarşisi, yeni script, `.tres` resource, sinyal bağlantısı, formül veya sistem akışı değiştirildiğinde ya da yeni özellik eklendiğinde;
- Projede mevcut olan `PROJECT_ARCHITECTURE.md` (veya ilgili mimari dokümantasyon) dosyasını **aynı adımda ve zorunlu olarak güncelle**.
- Dokümantasyonun kod tabanının güncel gerçeğiyle daima %100 senkronize kalmasını sağla.
