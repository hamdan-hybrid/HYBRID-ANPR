# Hybrid ANPR

Layanan pembaca nopol (ANPR) untuk Hybrid Parking. Aplikasi parkir mengirim IP, username, dan password kamera
ke `POST /baca`, lalu layanan menjawab nopolnya dalam ±1 detik. Dokumentasi API ada di [API.md](API.md).

## Syarat

- Ubuntu 24.04 atau lebih baru, 64-bit (x86_64). Layanan memakai memori ±450–620 MB.
- `git` dan `curl`: `sudo apt install git curl`
- Kamera: ONVIF aktif dan jarak keyframe (GOP) ≤ 0,5 detik, mis. GOP 12 pada 25 fps.

## Instal

```bash
git clone https://github.com/hamdan-hybrid/HYBRID-ANPR.git
cd HYBRID-ANPR
sudo ./install.sh
```

Pakai `git clone`, jangan Download ZIP: ZIP tidak menyimpan symlink library dengan benar. Ukuran unduhan
±700 MB (program + model AI).

`install.sh` memasang:

| Lokasi | Isi |
|---|---|
| `/opt/anpr` | Program dan model AI (dikunci, tidak bisa diubah) |
| `/etc/anpr/anpr.env` | Konfigurasi: port, batas waktu, model OCR |
| `/var/lib/anpr` | Data: akun admin, kunci API, kamera, zona plat |
| layanan `anpr-api` | Berjalan otomatis setiap komputer dinyalakan |

Setelah selesai, alamat layanan dan panel admin tampil di layar.

## Setelah instal

1. Buka panel admin `http://<ip-server>:8090/admin`. Login dengan user `admin` dan password awal dari
   `sudo cat /var/lib/anpr/admin_password_awal.txt`, lalu ganti password di menu **Pengaturan**.
2. Di **Pengaturan → Kunci API**, klik **Buat kunci**, lalu **Salin**.
3. Di Hybrid Parking, buka **Data Perusahaan → Hybrid ANPR**:
   - **Link Hybrid ANPR**: `http://<ip-server-anpr>:8090`, atau `http://localhost:8090` bila satu komputer
   - **API key Hybrid ANPR**: tempel kunci tadi
   - klik **Test koneksi**, lalu **Simpan**
4. Opsional: di panel admin menu **Status**, tambahkan kamera gate supaya sudah tersambung sejak layanan
   dinyalakan, dan atur **Area plat** bila plat sering tidak terbaca.

## Perbarui ke versi baru

```bash
cd HYBRID-ANPR
git pull
sudo ./install.sh
```

Konfigurasi, akun admin, kunci API, kamera, dan zona plat tidak hilang.

## Perintah berguna

| Keperluan | Perintah |
|---|---|
| Status layanan | `systemctl status anpr-api` |
| Log langsung | `journalctl -u anpr-api -f` |
| Restart (wajib setelah mengubah `/etc/anpr/anpr.env`) | `sudo systemctl restart anpr-api` |
| Ganti port | ubah `ANPR_PORT` di `/etc/anpr/anpr.env`, lalu restart |
| Melatih ulang OCR dari panel | sekali saja: `sudo apt install python3-venv` |

## Hapus

```bash
sudo ./uninstall.sh
```

Konfigurasi di `/etc/anpr` dan data di `/var/lib/anpr` tidak ikut dihapus.
