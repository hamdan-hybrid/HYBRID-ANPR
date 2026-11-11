#!/usr/bin/env bash
# Hapus Hybrid ANPR. Konfigurasi (/etc/anpr) tidak dihapus.  Pemakaian: sudo bash uninstall.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Jalankan dengan sudo: sudo bash uninstall.sh"; exit 1; }
systemctl disable --now anpr-api 2>/dev/null || true
rm -f /etc/systemd/system/anpr-api.service
systemctl daemon-reload
chattr -R -i /opt/anpr 2>/dev/null || true       # buka kunci immutable dulu
rm -rf /opt/anpr
echo "Hybrid ANPR dihapus. Konfigurasi di /etc/anpr dan data di /var/lib/anpr tidak dihapus."
