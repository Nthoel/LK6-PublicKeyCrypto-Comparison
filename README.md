# LK 6 â€” Perbandingan Sistem Kriptografi Kunci Publik

Proyek ini disusun untuk memenuhi LK 6 mata kuliah Kriptografi, dengan fokus pada perbandingan:

- RSA
- ECC / ECIES
- ElGamal
- Hybrid RSA-AES

## Prinsip Arsitektur: Modularity Harmony

Struktur proyek ini memakai konsep **modularity harmony**:
- **Single Responsibility**: setiap modul menangani satu tugas utama.
- **Low Coupling**: algoritma tidak saling bergantung secara langsung.
- **High Cohesion**: fungsi yang serupa berada dalam modul yang sama.
- **Consistent Interfaces**: seluruh algoritma mengikuti pola API yang mirip.
- **Benchmark-Ready**: eksperimen dipisahkan dari logika algoritma.

## Struktur Folder

- `include/core` dan `src/core` â†’ kontrak inti, interface, config
- `include/algorithms` dan `src/algorithms` â†’ RSA, ECC/ECIES, ElGamal, Hybrid RSA-AES
- `include/benchmarks` dan `src/benchmarks` â†’ pengukuran performa
- `include/utils` dan `src/utils` â†’ helper I/O file, timer, CSV writer
- `data/raw` â†’ dataset uji berdasarkan ukuran file
- `results/csv` â†’ output benchmark
- `docs` â†’ catatan analisis dan laporan

## Library yang Disarankan

- Crypto++ untuk RSA, ElGamal, ECC/ECIES, AES
- Alternatif: OpenSSL untuk RSA/AES/ECC, namun ElGamal biasanya kurang nyaman

## Langkah Awal

1. Lengkapi implementasi di folder `src/algorithms`
2. Siapkan dataset minimal 100 file bervariasi
3. Jalankan benchmark
4. Simpan hasil ke `results/csv`
5. Analisis performa, ukuran kunci, ukuran ciphertext, dan keamanan

## Build

Contoh build dengan CMake:

```powershell
cmake -S . -B build
cmake --build build
```
