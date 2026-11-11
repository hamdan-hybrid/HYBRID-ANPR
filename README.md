# Hybrid ANPR

Pembaca nopol (ANPR) untuk Hybrid Parking: aplikasi parkir mengirim IP, username, dan password kamera ke
`POST /baca`, lalu layanan menjawab nopolnya dalam ±1 detik.

Instalasi cukup dengan **satu perintah: `sudo bash install.sh`**. Program dan model AI sudah ada di paket ini,
jadi Anda **tidak perlu** memasang Python atau library apa pun sendiri.

## Kebutuhan server

| | |
|---|---|
| Sistem operasi | Ubuntu 24.04 atau lebih baru, 64-bit (x86_64) |
| RAM | layanan memakai ±450–620 MB |
| Disk | minimal 2 GB kosong |
| Internet | dibutuhkan saat instalasi dan update |
| Akses | user yang bisa menjalankan `sudo` |
| Kamera | ONVIF aktif dan jarak keyframe (GOP) ≤ 0,5 detik, mis. GOP 12 pada 25 fps |

## Instalasi

**1. Unduh aplikasi**

```bash
sudo apt-get install -y git curl
sudo git clone --depth 1 https://github.com/hamdan-hybrid/HYBRID-ANPR.git /var/www/HYBRID-ANPR
```

Pakai `git clone`, jangan Download ZIP: ZIP tidak menyimpan symlink library dengan benar. Ukuran unduhan
±700 MB (program + model AI).

**2. Jalankan install**

```bash
cd /var/www/HYBRID-ANPR
sudo bash install.sh
```

Install memasang program ke `/opt/anpr`, konfigurasi ke `/etc/anpr/anpr.env`, data ke `/var/lib/anpr`, dan
layanan `anpr-api` yang berjalan otomatis setiap komputer dinyalakan. Di akhir, alamat layanan dan panel admin
tampil di layar.

**3. Buka panel admin**

- Alamat: `http://<ip-server>:8090/admin` (port bawaan 8090).
- Login awal: user **admin**, password dari `sudo cat /var/lib/anpr/admin_password_awal.txt`. Segera ganti
  password di menu **Pengaturan**.

**4. Hubungkan ke Hybrid Parking**

1. Di panel admin **Pengaturan → Kunci API**, klik **Buat kunci**, lalu **Salin**.
2. Di Hybrid Parking, buka **Data Perusahaan → Hybrid ANPR**:
   - **Link Hybrid ANPR**: `http://<ip-server-anpr>:8090`, atau `http://localhost:8090` bila satu server
   - **API key Hybrid ANPR**: tempel kunci tadi
   - klik **Test koneksi**, lalu **Simpan**
3. Opsional: di panel admin menu **Status**, tambahkan kamera gate supaya sudah tersambung sejak layanan
   dinyalakan, dan atur **Area plat** bila plat sering tidak terbaca.

## Perbarui ke versi baru

```bash
cd /var/www/HYBRID-ANPR
sudo git pull
sudo bash install.sh
```

Konfigurasi, akun admin, kunci API, kamera, dan zona plat tidak hilang.

## Perintah harian

| Keperluan | Perintah |
|---|---|
| Status layanan | `systemctl status anpr-api` |
| Log langsung | `journalctl -u anpr-api -f` |
| Restart (wajib setelah mengubah `/etc/anpr/anpr.env`) | `sudo systemctl restart anpr-api` |
| Ganti port | ubah `ANPR_PORT` di `/etc/anpr/anpr.env`, lalu restart |
| Melatih ulang OCR dari panel | sekali saja: `sudo apt-get install -y python3-venv` |

## Hapus

```bash
cd /var/www/HYBRID-ANPR
sudo bash uninstall.sh
```

Konfigurasi di `/etc/anpr` dan data di `/var/lib/anpr` tidak ikut dihapus.

API untuk pembuat aplikasi parkir: [API.md](API.md).
