# Hybrid ANPR: API pembaca nopol untuk aplikasi parkir

Aplikasi parkir mengirim IP kamera, username, dan password. Layanan membaca nopol dari kamera itu dan
menjawab **±1 detik** untuk plat biasa (maksimal 3 detik untuk plat sulit: miring / kontras rendah / kecil).

## Ringkas

```bash
curl -X POST http://<ip-server-anpr>:8090/baca \
     -H "Content-Type: application/json" -H "X-API-Key: <kunci>" \
     -d '{"ip": "192.168.1.101", "username": "admin", "password": "rahasia"}'
```

```json
{"status": true, "nopol": "BK1626WV"}
```

Jawaban selalu dua field: `status` (`true`/`false`) dan `nopol`.
`status: true` **hanya** kalau nopol terbaca **lengkap dan pasti** — `nopol` berisi platnya (huruf besar tanpa spasi).
`status: false` untuk semua kondisi lain (terbaca sebagian, tidak terbaca, atau kamera bermasalah) dengan `nopol` kosong `""` — nopol yang belum pasti tidak diserahkan, supaya tidak ada plat salah.

## Endpoint

| Metode | Path | Fungsi |
|---|---|---|
| `POST` | `/baca` | Baca nopol dari satu kamera. Body JSON: `ip`, `username`, `password`; opsional `port` (HTTP/ONVIF kamera, default 80), `channel` (default 1), `rtsp` (alamat RTSP manual kalau ONVIF kamera mati). |
| `GET` | `/baca?ip=..&username=..&password=..` | Sama dengan di atas, untuk klien sederhana. Lebih aman pakai `POST` (password tidak masuk ke URL). |
| `POST` | `/kamera` | Sambungkan kamera lebih dulu tanpa membaca (body sama dengan `/baca`), supaya `/baca` pertama pun cepat. |
| `GET` | `/kamera` | Daftar kamera yang tersambung: merek/model, status, umur keyframe, jarak keyframe (cek GOP). |
| `GET` | `/riwayat` | 50 hasil terakhir. |
| `GET` | `/sehat` | Cek layanan hidup (tanpa kunci API). |
| `GET` | `/label` | Halaman label data latih (lihat "Melatih ulang OCR"). Hanya aktif kalau `ANPR_KUMPUL_DIR` diisi. |

Kalau kunci API aktif, semua endpoint kecuali `/sehat` wajib mengirim header `X-API-Key`. Kunci dibuat dan disalin
di **panel admin → Pengaturan → Kunci API** (berlaku seketika, tanpa restart), atau diisi di `ANPR_API_KEY`. Kunci dari
panel mengalahkan `ANPR_API_KEY`.

## Jawaban `/baca`

Dua field saja:

| Field | Arti |
|---|---|
| `status` | `true` = nopol terbaca lengkap dan pasti. `false` = sebagian / tidak terbaca / kamera bermasalah. |
| `nopol` | Nopol (huruf besar tanpa spasi, mis. `BK1626WV`) kalau `status: true`; `""` kalau `status: false`. |

```json
{"status": true,  "nopol": "BK1626WV"}
{"status": false, "nopol": ""}
```

Walau isi body ringkas, **kode HTTP** tetap membedakan masalah agar mudah dipantau: `200` untuk hasil baca
(termasuk `status: false` kalau tidak terbaca), `502` kalau kamera tidak terjangkau / login ditolak, `400` kalau
body salah, `401` kalau kunci API salah. Aplikasi parkir cukup membaca `status`; buka palang hanya kalau `true`.

**Anjuran saat `status: false`:** layanan sengaja menjawab `false` daripada menebak plat yang belum pasti (tidak
pernah ada plat salah). Untuk plat sulit (miring / kontras rendah / kecil), **panggil ulang `/baca` 1–2 kali lagi**
— kendaraan masih diam di gerbang, jadi panggilan ulang biasanya langsung berhasil. Cara ini aman: tidak menaikkan
risiko plat salah sama sekali. Contoh: coba sampai 3 kali dengan jeda ±0.3 detik; kalau tetap `false`, minta petugas
ketik manual.

> Detail lengkap (status `sebagian`/`tidak_terbaca`, `conf`, waktu proses, pesan error) tetap bisa dilihat di
> **panel admin** (menu Status → Bacaan terakhir, dan Coba Baca), hanya tidak dikirim lewat API ini.

## Cara kerja dan waktu

- **Panggilan pertama ke sebuah kamera** mencari alamat video lewat ONVIF lalu menyambung: **±2–4 detik**. Setelah
  itu sambungan dibiarkan hidup (ditutup otomatis setelah 24 jam tidak dipakai). Supaya panggilan pertama pun
  cepat, isi daftar kamera di `/etc/anpr/kamera.json` atau panggil `POST /kamera` saat aplikasi parkir start.
- **Panggilan berikutnya: ±0.5–1 detik** untuk plat biasa; **maksimal 3 detik** untuk plat sulit (miring/kontras
  rendah/kecil) yang perlu menunggu 2 keyframe sepakat. Kalau tetap tidak yakin dalam batas itu → `status:false`.
  Batas ini diatur `ANPR_MAX_TIME` (1.5 = maks 3 detik). Video diterima terus tanpa di-decode (CPU ±2.5% per kamera). Saat
  dipanggil, keyframe terakhir dan berikutnya di-decode dan dibaca. Nopol diputuskan kalau 2 keyframe terbaca
  sama persis, dengan aturan keyakinan per huruf.
- Beberapa kamera (mis. 2 masuk + 2 keluar) bisa dipanggil bersamaan; tiap permintaan diproses terpisah.
  Dua permintaan bersamaan untuk kamera yang sama mendapat hasil yang sama.

## Syarat kamera

1. **ONVIF aktif** dengan user yang sama (Dahua/Hikvision: menu Network → ONVIF / Integration Protocol). Kalau
   ONVIF mati, layanan mencoba alamat RTSP baku Dahua dan Hikvision, atau kirim `rtsp` secara manual.
2. **Jarak keyframe (GOP / I-frame interval) ≤ 0.5 detik**, mis. GOP 12 pada 25 fps. Dengan nilai pabrik (biasanya
   2 detik) keyframe baru datang terlambat dan jawaban bisa `tidak_terbaca`. Cek di `GET /kamera` → `jarak_keyframe`.
3. Plat terlihat jelas dan lurus, lebar ≥ ±180 px di gambar 1080p. Kalau kamera melawan cahaya, nyalakan WDR.

## Pemasangan (Ubuntu 24.04+)

```bash
tar xzf hybrid-anpr-<versi>-ubuntu24.04-x86_64.tar.gz
cd hybrid-anpr-<versi>
sudo ./install.sh
```

- Konfigurasi: `/etc/anpr/anpr.env` (port, kunci API, batas waktu), lalu `sudo systemctl restart anpr-api`.
- Gambar kamera tidak disimpan ke disk; yang disimpan hanya zona plat per kamera (beberapa KB) di `/var/lib/anpr`.
- Log: `journalctl -u anpr-api -f`
- Hapus: `sudo ./uninstall.sh` (konfigurasi tidak ikut dihapus).

## Panel admin

Buka `http://<ip-server>:<port>/admin` di browser (login). Password awal ada di
`/var/lib/anpr/admin_password_awal.txt`; ganti di menu Pengaturan. Menu:

| Menu | Fungsi |
|---|---|
| Status | Kesehatan layanan, kamera tersambung, bacaan terakhir. Per kamera: **Area plat** dan **Reset zona**. |
| Coba Baca | Tes satu kamera seperti aplikasi parkir, lengkap dengan contoh perintah curl. |
| Label | Memberi label potongan plat untuk melatih ulang. |
| Latih & Model | Siapkan, latih (tombol), lihat hasil uji, pilih model OCR yang dipakai (tanpa restart). |
| Pengaturan | Pengumpul data nyala/mati dan batas disk, kunci API (buat, salin, matikan), ganti password admin. |
| Dokumentasi | Panduan lengkap (isi file ini dan lebih). |

**Area plat (sangat disarankan, sekali per kamera):** di Status, klik *Area plat*, tarik kotak longgar di tempat plat
kendaraan terlihat saat berhenti, lalu *Simpan*. Program memeriksa area itu lebih dulu, termasuk dengan detektor besar.
Uji nyata: plat motor miring berkontras rendah 0/8 terbaca tanpa area, 10/10 dengan area (±1.6-2.5 dtk karena platnya
sulit; plat yang menghadap lurus ±0.4-0.7 dtk). Atur ulang kalau kamera dipindah.

## Melatih ulang OCR (opsional)

OCR tidak belajar sendiri dari pemakaian. Untuk menaikkan ketepatan di lokasi sendiri:

1. **Kumpulkan.** Isi `ANPR_KUMPUL_DIR=/var/lib/anpr/kumpul` (atau folder di HDD) di `/etc/anpr/anpr.env`, lalu
   restart. Layanan menyimpan **potongan plat saja** (±5-10 KB) + hasil bacaannya, paling banyak `ANPR_KUMPUL_MAX_MB`
   (default 500 MB). Kalau penuh, potongan lama yang **belum** diberi label dihapus otomatis; yang sudah berlabel tidak.
   Kendaraan yang sama di kamera yang sama tidak disimpan ulang dalam 60 detik.
2. **Beri label** di panel admin (menu Label) atau `http://<ip-server>:<port>/label`: ketik nopol yang benar-benar terlihat (huruf besar tanpa spasi
   otomatis), Enter. "Bukan plat" untuk gambar yang bukan plat/tidak terbaca, "Lewati" kalau ragu.
3. **Latih**: di panel admin menu *Latih & Model*, klik *Siapkan* (sekali) lalu *Latih sekarang*. Atau dari terminal di
   komputer yang punya kode sumber (salin dulu folder data latihnya):
   ```bash
   .venv/bin/python latih.py siapkan                    # sekali: TensorFlow ±2.5 GB
   .venv/bin/python latih.py latih --data /path/ke/kumpul
   ```
   Skrip membagi data per nopol (kendaraan yang sama tidak ada di data latih dan uji), mencampur dataset ICVLP,
   melatih, lalu membandingkan dengan model sekarang. Model baru **hanya disimpan kalau lebih banyak benar dan tidak
   lebih banyak salah** di data uji (minimal 20 nopol berbeda di data uji, jadi butuh ±150+ nopol berlabel).
4. **Pasang**: di panel admin klik *Pakai model ini* (muncul hanya kalau model baru lebih baik). Dari terminal: salin
   `ocr_lokal_*.onnx` + `*_plate_config.yaml` ke `/var/lib/anpr/models/`, isi `ANPR_OCR_MODEL` lalu restart.

## Keamanan

Permintaan berisi password kamera. Aktifkan kunci API (panel admin → Pengaturan), batasi akses port API ke komputer aplikasi parkir
(firewall), atau jalankan aplikasi parkir di komputer yang sama dengan `ANPR_HOST=127.0.0.1`. Password tidak
dicatat di log; di memori disimpan selama kamera tersambung.
