# OCR cct-s-v2 yang di-fine-tune dengan plat Indonesia (eksperimen, 2026-11-11)

- Asal: `cct_s_v2_global.keras` (fast-plate-ocr), dilatih ulang 15 epoch, lr 2e-4, batch 32.
- Data: ICVLP (https://github.com/risangbaskoro/icvlpr-dataset, lisensi C-UDA): 385 latih, 37 validasi, 46 uji.
  Semua plat kuning kendaraan niaga.
- Hasil di 83 plat yang tidak dilatih (OCR saja): benar 40 -> 42, salah yang yakin 7 -> 3.
- Plat putih sendiri (kamera gerbang): sedikit memburuk (33 -> 30 dari 54 foto), jadi BELUM jadi default.
- Pakai: `--ocr-model models/ocr-id-finetune/cct_s_v2_id.onnx`
- Ulangi pelatihan: `fast-plate-ocr train --weights-path cct_s_v2_global.keras --annotations train.csv ...`
  (perlu `pip install fast-plate-ocr tensorflow-cpu keras` di venv terpisah; parameter lengkap di hyper_params.json).
