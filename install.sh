#!/usr/bin/env bash
# Pasang / perbarui Hybrid ANPR di Ubuntu 24.04+.  Pemakaian:  sudo ./install.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Jalankan dengan sudo: sudo ./install.sh"; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"

id anpr &>/dev/null || useradd --system --home-dir /opt/anpr --shell /usr/sbin/nologin anpr
mkdir -p /opt/anpr /var/lib/anpr/models /etc/anpr      # models: OCR hasil latih ulang
systemctl stop anpr-api 2>/dev/null || true

# Buka kunci "immutable" dari versi lama (kalau ada) supaya bisa diperbarui.
chattr -R -i /opt/anpr/anpr-api /opt/anpr/home 2>/dev/null || true
rm -rf /opt/anpr/anpr-api /opt/anpr/home
cp -a "$HERE/anpr-api" /opt/anpr/
cp -a "$HERE/home" /opt/anpr/home                       # model AI
# Konfigurasi lama tidak ditimpa saat memperbarui.
if [ -f /etc/anpr/anpr.env ]; then
    # Konfigurasi lama tidak ditimpa; setelan baru dari versi ini ditambahkan kalau belum ada.
    while IFS= read -r line; do
        k="${line%%=*}"
        case "$line" in ANPR_*=*) grep -q "^$k=" /etc/anpr/anpr.env || echo "$line" >> /etc/anpr/anpr.env ;; esac
    done < "$HERE/anpr.env"
else
    cp "$HERE/anpr.env" /etc/anpr/anpr.env
fi
[ -f /etc/anpr/kamera.json ] || echo '[]' > /etc/anpr/kamera.json

# shellcheck disable=SC1091
source /etc/anpr/anpr.env

# --- Hak akses: program TIDAK bisa diubah klien, data tetap bisa ditulis layanan ---
# Program (kode terkompilasi + model) milik root. User layanan 'anpr' hanya boleh baca & jalankan.
chown -R root:root /opt/anpr
find /opt/anpr/anpr-api /opt/anpr/home -type d -exec chmod 755 {} +
find /opt/anpr/anpr-api /opt/anpr/home -type f -exec chmod 644 {} +
chmod 755 /opt/anpr/anpr-api/anpr-api
find /opt/anpr/anpr-api \( -name '*.so' -o -name '*.so.*' \) -exec chmod 755 {} +
# Data (zona, akun admin, model hasil latih, log) milik layanan dan bisa ditulis.
chown -R anpr:anpr /var/lib/anpr
chmod 750 /var/lib/anpr
# Konfigurasi hanya root yang boleh ubah; berisi kunci API / password kamera.
chown root:anpr /etc/anpr/anpr.env /etc/anpr/kamera.json
chmod 640 /etc/anpr/anpr.env /etc/anpr/kamera.json

# Kunci kode program agar tidak bisa ditimpa/diedit (bahkan oleh root tanpa membuka kunci). Best-effort.
if chattr -R +i /opt/anpr/anpr-api 2>/dev/null; then
    echo "Program dikunci (immutable); untuk memperbarui cukup jalankan ./install.sh lagi."
else
    echo "Catatan: filesystem tidak mendukung kunci immutable; proteksi tetap dari kepemilikan root."
fi

cp "$HERE/anpr-api.service" /etc/systemd/system/anpr-api.service
systemctl daemon-reload
systemctl enable --now anpr-api

echo -n "Menunggu layanan siap"
for _ in $(seq 1 60); do
    if curl -s -m 1 "http://127.0.0.1:${ANPR_PORT}/sehat" >/dev/null; then
        IP="$(hostname -I | awk '{print $1}')"
        echo; echo "Hybrid ANPR berjalan  : http://$IP:${ANPR_PORT}/baca"
        echo "Panel Hybrid ANPR     : http://$IP:${ANPR_PORT}/admin"
        [ -f /var/lib/anpr/admin_password_awal.txt ] && echo "Password admin awal   : sudo cat /var/lib/anpr/admin_password_awal.txt"
        echo "Log: journalctl -u anpr-api -f     Konfigurasi: /etc/anpr/anpr.env"
        echo "(Melatih OCR dari panel butuh: sudo apt install python3-venv)"
        exit 0
    fi
    echo -n "."; sleep 1
done
echo; echo "Layanan belum menjawab. Cek: journalctl -u anpr-api -n 50"; exit 1
