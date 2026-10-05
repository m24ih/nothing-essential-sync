# Nothing Phone Essential Space -> Obsidian One-Way Sync Engine

Nothing OS'in Essential Key ile alınan tüm notları, ses kayıtlarını ve ekran görüntülerini izole bir biçimde okuyup Obsidian `00-Zettelkasten` inbox klasörüne ve `99-index/Files` medya dizinine aktaran saf Unix tabanlı arka plan senkronizasyon servisi.

## 📌 Özellikler ve Güvenlik İlkeleri

- **%100 Salt-Okunur (Read-Only) Güvencesi:** Nothing OS'in canlı SQLite veritabanı kütüğüne hiçbir harici sorgu değmez. İşlem öncesi anlık kopyalama (`/data/local/tmp` RAM diskine) yapılır ve sorgular bu geçici kopya üzerinde çalıştırılır. Essential Space veritabanında veya dosyalarında hiçbir yazma, silme veya değiştirme yapılmaz.
- **Sıfır Pil ve İşlemci Tüketimi (Event-Driven):** Polling (sürekli uyanık kalıp sorgu atma) yerine Android'in çekirdek düzeyindeki `toybox inotifyd` mekanizmasını kullanır. Yalnızca veritabanına yeni bir not yazıldığında milisaniyeler içinde uyanır ve işi bitince uykuya döner.
- **Yedekli Fallback:** Olası kaçak durumlar için arka planda 15 dakikalık periyodik kontrol döngüsü bulunur.
- **Bağımsız Statik `sqlite3`:** Android sisteminde `sqlite3` CLI aracı bulunmadığından, Android NDK r27 ile derlenmiş bağımsız statik ARM64 `sqlite3` ikili dosyası kullanılır.
- **Multimodal Destek:**
  - Metin notları (`TEXT`, `NOTE_TEXT`)
  - Ekran görüntüleri (`IMAGE` - `.webp` formatında `99-index/Files/` altına kopyalanır)
  - Ses kayıtları (`AUDIO` - `.wav` formatında `99-index/Files/` altına kopyalanır)
  - AI Ses Transkripsiyonu (`TRANSCRIPTION` - Essential Space'in ürettiği metin dökümü)
  - AI Özeti ve Başlık (`cards.summary` ve `cards.title`)
- **Hayalet Not (Ghost Note) Koruması:** `last_sync_time.txt` durum takibi sayesinde bilgisayarda Obsidian'dan notlar silinse veya başka klasörlere taşınsa dahi eski notlar asla tekrar üretilmez.

---

## 📂 Dosya Mimarisi

### Cihaz İçi Konumlar (Nothing Phone 3a)
- `/data/adb/essential-sync/`:
  - `bin/sqlite3`: Statik ARM64 ikili dosyası (chmod 755).
  - `sync.sh`: Ana iş mantığını yürüten shell betiği.
  - `last_sync_time.txt`: En son başarıyla senkronize edilen kartın unix zaman damgası.
  - `sync.log`: Senkronizasyon kayıtları.
  - `daemon.log`: Servis ve inotifyd logları.
- `/data/adb/service.d/essential_sync.sh`: KernelSU otomatik başlatıcısı (Boot tamamlandığında arka planda inotifyd'yi çalıştırır).

### Hedef Obsidian Vault Konumları
- Notlar: `/storage/emulated/0/Sync/Obsidian-Vaults/Personal-Obsidian/00-Zettelkasten/`
- Medyalar: `/storage/emulated/0/Sync/Obsidian-Vaults/Personal-Obsidian/99-index/Files/`

---

## 🚀 Yönetim ve Komutlar

### Manuel Tetikleme (Test için)
```bash
adb shell "su -c 'sh /data/adb/essential-sync/sync.sh'"
```

### Logları Canlı İzleme
```bash
adb shell "su -c 'tail -f /data/adb/essential-sync/sync.log'"
```

### Servis Durumunu Kontrol Etme
```bash
adb shell "su -c 'ps -ef | grep -E \"inotifyd|essential_sync\" | grep -v grep'"
```

### Yeniden Dağıtım (Deploy)
```bash
./deploy.sh
```
