# Batman Petrol Ağası

Batman (Türkiye) şehrinin petrol kimliğini konu alan idle/tycoon mobil oyunu (Flutter MVP).
Raman'dan başla, sondaj yap, at kafalarını kur, petrolü sat, Garzan'a ve Rafineri Bölgesi'ne uzan.

> Bu oyun Batman ilinin petrol tarihinden ilham alır. DC Comics'in Batman karakteri, logosu
> veya yarasa sembolüyle hiçbir ilgisi yoktur ve bunların hiçbiri kullanılmaz.

- **Görsel dosya yok:** Tüm görseller `CustomPainter`, şekiller ve Material ikonlarıyla çizilir
  (at kafası, sondaj kulesi, yer altı kesiti, harita, maskot Usta).
- **Arayüz tamamen Türkçe.**
- Platformlar: Android, iOS, Web.

## Oyun döngüsü

| Ekran | Ne yapılır |
|---|---|
| **Harita** | Batman'ın stilize haritası: Raman Dağı, Batman Çayı, Dicle, şehir, rafineri. Kilitli sahalar TL ile açılır. |
| **Saha** | 3x3 parsel. Boş → Etüt (opsiyonel, verim ipucu) → Sondaj → Petrol / Kuru kuyu → Üretimde. |
| **Sondaj** | Yer altı kesiti (toprak, kil, kaya, kireçtaşı, rezervuar). Matkap iner, derinlik sayacı akar. Ekrana dokunmak hızlandırır. Petrol bulunursa fışkırır. |
| **Üretim** | At kafası sallanır, kuyunun deposu dolar. Dokununca toplanır. Yükseltmeler: pompa ve depo. Uzun basış veya ⚙ ile kuyu ayrıntısı. |
| **Pazar** | Varil satışı, birkaç dakikada bir dalgalanan fiyat ve grafik. Rafineri açılınca varil akaryakıta çevrilir. |
| **Ayarlar** | Titreşim, ses, rehberi tekrar izle, kaydet, istatistikler, sıfırla. |

Ayrıca:
- **Çevrimdışı kazanç:** Uygulama açılınca geçen süre (en fazla 4 saat) hesaplanır ve "Sen yokken X varil çıktı" penceresi gösterilir.
- **Olaylar:** Batman sıcağı (üretim -%20, 2 dk), Fiyat uçtu (satış x2, 1 dk), Arıza (kuyu durur, 3 dokunuşla tamir).
- **Usta:** Orijinal maskot; 5 adımlık ilk rehber, ipuçları ve olaylara esprili tepkiler. HUD'daki Usta'ya dokununca ipucu verir.
- **Gün-gece döngüsü:** 8 dakikalık döngü. Gökyüzü tonu değişir, gece şehir ve rafineri ışıkları yanar.
- **Geri bildirim:** "+N varil" yükselen yazılar, parçacıklar, `HapticFeedback`.
- **Kayıt:** `shared_preferences`, her 10 saniyede ve uygulama arka plana geçince otomatik.

## Görsel gerçekçilik (görsel dosya olmadan)

| Katman | Nasıl |
|---|---|
| **At kafası** | Gerçek dört-çubuk mekanizması: krank sabit hızla döner, biyel kolu sabit boydadır, kiriş açısı iki çemberin kesişiminden hesaplanır. At başı pivot merkezli bir yay olduğundan halat hep dikey sarkar ve cilalı çubuk düz iner. Metal gradyanlar, karşı ağırlık, kayış koruyucu, titreşen motor, egzoz dumanı, kuyu başında petrol lekesi, güneş yönüne göre düşen gölge, gece çalışma lambası. Her kuyu farklı fazda başlar. |
| **Sondaj kulesi** | Alt yapı, platform, sondajcı kabini, dönen vinç tamburu, kafes direk, iniş-çıkış yapan makara bloğu, istiflenmiş borular, çamur tankları, dalgalanan bayrak, yanıp sönen ikaz lambası. |
| **Yer altı kesiti** | Dalgalı ve kubbeli (petrol kapanı) katman sınırları, tanecik dokusu, derinlikle artan karanlık, muhafaza borusu, halka boşlukta yukarı akan kırıntılar, üç konili dönen matkap. Petrol bulununca kuyuda petrol yükselir, ekran sarsılır, ardından fışkırma başlar. |
| **Fışkırma** | Fiziksel parçacık sistemi (`core/visuals/particles.dart`): yerçekimi, hava direnci, rüzgâr, hıza göre uzayan damlalar, yere çarpınca sıçrama, hacimle büyüyen ve yanardöner petrol gölü, sis. |
| **Shader'lar** (`shaders/*.frag`, GLSL kodu) | `sky.frag`: fbm gürültülü hareketli bulutlar, güneş ışıması, gece yıldızları. `heat_haze.frag`: Batman sıcağı sırasında ekranı kaplayan ısı dalgası. `oil_sheen.frag`: rezervuarda ince film yanardönerliği. Shader yüklenemezse gradyan yedeğine düşülür. |
| **Manzara** (`landscape.frag`) | Tek shader'da tam sahne: dört katman aşınmış dağ sırtı ve belirgin Raman Dağı kütlesi, güneş yönüne göre yamaç ışığı, erozyon olukları, kireçtaşı yüzleri, vadi sisi, atmosferik perspektif, bulut gölgeleri, çalılık, akşam ışık hüzmeleri ve sırt ışığı, gece köy ışıkları, ön planda bozkır, ince film greni. Üstünde uzak at kafaları ve kuşlar. |
| **Toprak** (`soil.frag`) | Kurak bozkır toprağı: renk lekeleri, kuraklık çatlakları (voronoi), çakıllar, kum taneciği, kuru ot. Saha zemini, parseller (sürülmüş tarla izleriyle) ve harita arazisi. Statik, önbelleklenir. |
| **Jeoloji** (`geology.frag`) | Yer altı kesitinde kayaç başına doku: köklü toprak, dalgalı tabakalı kil, bloklu ve damarlı kaya, tabakalı ve fosilli kireçtaşı, gözenekli kumtaşı rezervuar; katman temas gölgeleri. |
| **Ortam** | Paralaks, süzülen kuşlar, araziyi gezen bulut gölgeleri. |

Shader'lar `ShaderSlot` ile widget başına kalıcı tutulur. Her çizimde yeni örnek oluşturmak, önbelleğe alınmış resimlerde uniform'ların bozulmasına yol açıyordu.

## Premium arayüz

- **Açılış ekranı:** Gerçekçi manzara önünde altın altıgen amblem (kule + petrol damlası), parlayan başlık; dokununca atlanır.
- **Buzlu cam HUD ve alt menü:** İçerik tam ekran; üst bilgi ve alt menü arka planı bulanıklaştıran cam paneller olarak yüzer. Para ve varil sayarak ilerler.
- **Premium butonlar** (`core/ui/premium.dart`): gradyan, üst parlama, periyodik ışık süpürmesi, basınca küçülme.
- **Cam kartlar**, altın gradyanlı başlıklar, ince altın çizgili bölüm başlıkları, yumuşak solma + yakınlaşma sayfa geçişi, cam üst barlı sondaj ekranı.

## Ekip (işçiler)

Usta'nın yanında sahada bir ekip çalışır. Her işçinin bir **adı**, bir **görevi** ve görevine özgü
**gerçek bir unvanı** (rütbesi) vardır. Unvanlar Türkiye'deki kara sondaj sahalarında kullanılan
kadrolardan alınmıştır. Klasik kariyer yolu şöyledir: vasıfsız işçi → anahtarcı (masa işçisi) → derikmen →
sondör muavini → sondör → başsondör → sondaj amiri (tulpuşer). Sahanın başında kule mühendisi bulunur.

| Görev | Unvan basamakları | Etki |
|---|---|---|
| Kule Mühendisi | Stajyer Mühendis → Kule Mühendisi → Kıdemli Kule Mühendisi → Şirket Temsilcisi → Saha Müdürü | Tüm ekibin etkisini büyütür |
| Sondör | Sondör Muavini → Sondör → Kıdemli Sondör → Başsondör → Sondaj Amiri | Sondaj süresini kısaltır |
| Derikmen | Masa İşçisi → Anahtarcı → Derikmen → Kıdemli Derikmen → Sondör Muavini | Dokunuş gücünü artırır |
| Jeolog | Çamur Logcusu → Kuyu Jeoloğu → Kıdemli Jeolog → Baş Jeolog → Arama Müdürü | Kuru kuyu ihtimalini düşürür |
| Pompacı | Pompacı Yardımcısı → Pompacı → Üretim Operatörü → Kıdemli Operatör → Üretim Şefi | Üretimi artırır |
| Makinist | Makinist Yardımcısı → Makinist → Kıdemli Makinist → Baş Makinist → Bakım Şefi | Arızaları kendiliğinden tamir eder |
| Tanker Şoförü | Stajyer Şoför → Tanker Şoförü → Kıdemli Şoför → Filo Sorumlusu → Lojistik Şefi | Depoları düzenli boşaltır (çevrimdışı dahil) |
| Tüccar | Satış Elemanı → Tüccar → Kıdemli Tüccar → Satış Müdürü → Ticaret Müdürü | Satış fiyatını artırır |
| Saha İşçisi (6 kişi) | Vasıfsız İşçi → Saha İşçisi → Kıdemli Saha İşçisi → Ekip Başı → Saha Formeni | Üretime küçük katkı |

- **Adlar:** İşe alınan herkese bölgede yaygın bir ad verilir (Şeyhmus, Abdulkadir, Zeynep, Rojda...). Adlar ekipte tekrar etmez; oyuncu kalemle değiştirebilir. İleride kullanıcı adlarına bağlanabilir.
- **Oyuncu adı:** Ayarlar → *Ağa adın*. İşçiler oyuncuya bu adla ("Hamit Ağa") ya da ad yoksa "ağam" diye hitap eder.
- **Rütbeye göre konuşma:** Her görevin yeni (ilk iki basamak), orta ve kıdemli kademesi için ayrı sohbet replikleri vardır. Terfide işçi yeni unvanını söyler. Olaylarda göreviyle ilgili işçi konuşur.
- Görevler, unvanlar, bedeller ve etkiler `GameConfig.crewRoles` içindedir. Replikler `features/crew/crew_lines.dart` içindedir ({ağa}, {unvan}, {ad} şablonları kullanılır).

Unvan kaynakları: [Rigzone: Toolpusher kariyer yolu](https://www.rigzone.com/insights/career-advice-4/how-to-become-a-toolpusher-in-offshore-drilling-635/),
[Penn State PNG 301](https://www.e-education.psu.edu/png301/node/724), [SLB Glossary: drilling crew](https://glossary.slb.com/terms/d/drilling_crew),
[Sondaj Terimleri (sondajcılar)](https://sondajcilar.wordpress.com/2012/03/28/sondaj-terimleri/), [Sondaj Bilgisi ders notu](http://www.kursatozcan.com/ders_notlari/sondaj_teknigi/turhan_ayyildiz_sondaj_bilgisi.pdf),
[TPAO işçi alım ilanı (Kule İşçisi/Derikmen)](https://ilan.memurlar.net/ilan/6082/tpao-isci-alim-ilani.html).

## Mobil öncelik

- Dikey ekran kilidi, kenardan kenara çizim, şeffaf durum çubuğu (Android/iOS); web manifest'te `portrait-primary`.
- Tüm butonlarda en az 48 dp dokunma alanı (kuyu ayar ikonu 40x40'a büyütüldü).
- Ayarlar → **Pil tasarrufu (düşük grafik)**: bulanıklık, bulut gölgeleri ve fışkırma parçacıkları azalır.
- Pahalı shader'lar önbelleklenir; uzun listelerdeki cam kartlar bulanıklık kullanmaz.
- Güvenli alanlar (çentik, alt çubuk) içerik boşluklarına dahildir; 360 px genişlikte test edildi.

## Ses

Ses dosyası yoktur. `core/services/synth.dart` tüm efektleri (dokunma, matkap, motor, fışkırma, kuru kuyu,
toplama, kasa zili, yükseltme, fanfar, uyarı, tamir) ve rüzgâr + motor uğultulu ortam döngüsünü matematiksel
olarak WAV'a dönüştürür; `SynthAudioService` bunları `audioplayers` ile bellekten çalar.

- Her efekt için 4 oynatıcılık havuz: hızlı ardışık dokunuşlar birbirini kesmez.
- Ortam sesi uygulama arka plana geçince susar, öne gelince devam eder; Ayarlar'dan kapatılabilir.
- Tarayıcılar sesi ilk dokunuştan sonra açar; ortam sesi ilk efektle birlikte başlar.
- Testlerde `SilentAudioService` kullanılır.

## Claude Code izinleri

`.claude/settings.json`, Flutter komutlarını (`flutter pub add/get/remove`, `analyze`, `test`, `build web`, `dart format`) sormadan çalıştırmak için izin kuralları içerir. Ayarlar oturum başında okunur; yeni oturumlarda geçerlidir.

## Çalıştırma

```bash
flutter pub get
flutter run                     # bağlı cihaz / emülatör
flutter run -d chrome           # web
flutter test                    # unit + widget testleri
flutter analyze
```

### Telefondan web ile test

```bash
flutter build web --release --no-web-resources-cdn
cd build/web && python3 -m http.server 8080
```

Aynı ağdaki telefondan `http://<bilgisayarın-IP-adresi>:8080` adresini açın.
`--no-web-resources-cdn`, CanvasKit dosyalarını Google CDN yerine uygulamanın içinden yükler.
Böylece build her ortamda (kapalı ağ, statik hosting) çalışır.
`build/web` klasörü GitHub Pages, Netlify gibi statik bir sunucuya da olduğu gibi yüklenebilir.

## Mimari

```
lib/
  main.dart                     Giriş: SharedPreferences yüklenir, ProviderScope kurulur
  app.dart                      MaterialApp, alt menü kabuğu, yaşam döngüsü (arka planda kayıt)
  config/
    game_config.dart            TÜM denge değerleri + saha listesi + olaylar + jeoloji
    palette.dart                Renk paleti
  core/
    models/                     GameState, SiteState, Parcel, ActiveEffect (JSON kayıt)
    economy/economy.dart        Saf ekonomi fonksiyonları (unit testli)
    game/simulation.dart        Saf zaman ilerletme: üretim, sondaj, fiyat, olaylar, çevrimdışı
    game/game_controller.dart   Riverpod Notifier: eylemler, tick, otomatik kayıt, olay akışı
    game/game_events.dart       Arayüzün tepki verdiği olaylar (Usta, ses, efekt)
    persistence/                SaveRepository arayüzü + SharedPreferences uygulaması
    services/                   Saat, ses, haptik, GPS, liderlik, reklam (takılabilir arayüzler)
    visuals/                    GameVisuals arayüzü, painter'lar, gün-gece
    widgets/                    Efekt katmanı (+1 varil, parçacık), HUD
  features/
    map/  site/  well/  market/  events/  mascot/  settings/
```

**Temel ilkeler**

- **Tek kaynak config:** Fiyatlar, süreler, oranlar, olaylar ve sahalar `lib/config/game_config.dart` içinde.
- **Saf simülasyon:** `Simulation.advance` hem canlı tick'te (250 ms) hem çevrimdışı hesapta kullanılır. Böylece iki yol aynı sonucu verir ve test edilebilir.
- **Zaman damgası tabanlı:** Sondaj ve etkiler başlangıç/bitiş zamanıyla tutulur. Uygulama kapalıyken de doğru ilerler.
- **Olay akışı:** `GameController.events` akışını Usta, ses ve efektler dinler. Oyun mantığı arayüzden bağımsızdır.
- **Toleranslı kayıt:** Yeni eklenen sahalar ve alanlar eski kayıtlarla uyumludur (varsayılan değerle yüklenir).

### Yeni saha eklemek

`GameConfig.sites` listesine bir `SiteConfig` satırı ekleyin:

```dart
SiteConfig(
  id: 'kozluk',
  name: 'Kozluk',
  description: 'Dağ eteğinde yeni keşif.',
  unlockCost: 300000, surveyCost: 8000, drillCost: 30000,
  drillSeconds: 240, dryChance: 0.4, yieldMultiplier: 5,
  baseBarrelsPerSecond: 0.5, baseStorage: 300, targetDepthM: 2200,
  mapX: 0.85, mapY: 0.55, latitude: 38.19, longitude: 41.49,
),
```

Harita işaretçisi, saha ekranı, kayıt ve ekonomi yeni sahayı otomatik olarak tanır.

## İleride eklenecekler için hazır noktalar

| Özellik | Nereye takılır |
|---|---|
| **GPS bonusu** (Raman'a gidince ödül) | `LocationBonusService` arayüzünü uygulayın, `locationBonusServiceProvider`'ı override edin. Sahalarda `latitude/longitude` zaten var. Ödül için `GameController.grantBoost(source: EffectSource.gps, ...)`. |
| **Supabase liderlik tablosu** | `LeaderboardService` (`submitScore`, `topScores`) uygulaması. Skor için `GameStats.totalEarned` hazır. Bulut kaydı için `SaveRepository` arayüzü. |
| **Ödüllü reklam** (2 saat üretim x2) | `RewardedAdService.showRewardedAd()` uygulanır. Ayarlar ekranındaki düğme ödülü `grantBoost` ile `ActiveEffect` olarak verir (`AdRewardConfig`). |
| **Rive animasyonları** | `GameVisuals` arayüzünü (`pumpjack`, `derrick`, `gusher`, `mascot`) uygulayan bir `RiveGameVisuals` yazıp `gameVisualsProvider`'ı override edin. |
| **Ses efektleri** | `AudioService.play(SoundCue)` uygulanır, `audioServiceProvider` override edilir. Tüm tetikleme noktaları (`SoundCue`) zaten çağrılıyor. Bir ses çalma paketi (ör. `audioplayers`) gerekir. |

## Testler

- `test/economy_test.dart`: üretim, depo, yükseltme bedelleri, kuru kuyu oranı, fiyat sınırları, satış, çevrimdışı sınırı, biçimlendirme
- `test/simulation_test.dart`: sondaj sonucu, Batman sıcağı, arıza, 4 saat sınırı, fiyat geçmişi, kayıt gidiş-dönüş
- `test/game_controller_test.dart`: bakiye kontrolü, dokunuş sınırı, topla → sat → kaydet → yükle, rafineri, tamir, çevrimdışı rapor
- `test/widget_smoke_test.dart`: uygulama açılışı ve 5 adımlık rehber
- `test/painters_test.dart`: tüm painter'lar istisnasız çizer, animasyonlar kare kare çalışır, at kafası mekanizması tüm turda çözülür
