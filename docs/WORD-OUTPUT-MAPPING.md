# LK6 Word Output Mapping

Script tahap ini menambahkan output CSV yang langsung dipakai untuk mengisi tabel Word LK6.

## File hasil utama

Folder output:
- `results/csv/lk6_task4_file_size.csv`
- `results/csv/lk6_task5_time.csv`
- `results/csv/lk6_task6_entropy.csv`
- `results/csv/lk6_task7_correlation.csv`
- `results/csv/lk6_task8_avalanche.csv`
- `results/csv/lk6_summary_average.csv`

## Pemetaan ke tugas Word

### Tugas 4 â€” Evaluasi Ukuran File
Gunakan:
- `lk6_task4_file_size.csv`

Kolom utama:
- `plaintext_kb`
- `rsa_kb`
- `elgamal_kb`
- `ecc_kb`
- `rsa_aes_kb`

Kolom tambahan:
- `*_overhead_ratio`

### Tugas 5 â€” Evaluasi Waktu Proses
Gunakan:
- `lk6_task5_time.csv`

Kolom:
- `*_encrypt_ms`
- `*_decrypt_ms`

### Tugas 6 â€” Evaluasi Entropi
Gunakan:
- `lk6_task6_entropy.csv`

Kolom:
- `plaintext_entropy_bit`
- `rsa_entropy_bit`
- `elgamal_entropy_bit`
- `ecc_entropy_bit`
- `rsa_aes_entropy_bit`

### Tugas 7 â€” Evaluasi Korelasi
Gunakan:
- `lk6_task7_correlation.csv`

Kolom:
- `rsa_plain_vs_cipher`
- `elgamal_plain_vs_cipher`
- `ecc_plain_vs_cipher`
- `rsa_aes_plain_vs_cipher`
- `rsa_vs_ecc_cipher`

### Tugas 8 â€” Evaluasi Avalanche Effect
Gunakan:
- `lk6_task8_avalanche.csv`

Kolom:
- `*_changed_bits`
- `*_total_bits`
- `*_avalanche_percent`

## Catatan metodologi
Pengukuran avalanche pada RSA, ElGamal, ECIES, dan Hybrid RSA-AES dilakukan dengan
membandingkan dua ciphertext hasil enkripsi plainteks asli dan plainteks yang dimutasi 1 bit.

Karena algoritma public-key modern bersifat probabilistik, nilai avalanche ini berguna sebagai
indikator praktis untuk tugas LK, tetapi harus diberi catatan pada pembahasan bahwa interpretasinya
tidak sesederhana block cipher deterministik.

## Jalankan pipeline
Gunakan:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-lk6-word-report.ps1 -DatasetRoot ".\data\input"
```
