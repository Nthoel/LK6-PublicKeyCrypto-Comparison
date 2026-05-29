# LK6 Public Key Crypto Comparison

README ini disusun untuk membantu user lain menginstal, membangun, dan menjalankan proyek **LK 6 – Perbandingan Sistem Kriptografi Kunci Publik** dengan rapi dan konsisten.

## Ringkasan Proyek

Proyek ini membandingkan empat skema kriptografi yang diwajibkan pada LK 6:

- **RSA**
- **ECC / ECIES**
- **ElGamal**
- **Hybrid RSA-AES**

Fokus proyek:

- implementasi modular dengan C++
- build dengan **CMake**
- dependency kriptografi menggunakan **Crypto++**
- eksekusi benchmark dan ekspor hasil ke **CSV**
- struktur proyek yang rapi agar mudah dikerjakan berkelompok

> Catatan: pada implementasi ini, bagian **ECC direpresentasikan dengan ECIES**, karena lebih realistis untuk skenario enkripsi dibanding “ECC mentah”.

---

## Fitur Utama

- Struktur proyek modular
- Integrasi Crypto++ melalui CMake
- Benchmark runner untuk pengujian algoritma
- Output hasil eksperimen ke file CSV
- Script PowerShell untuk build dan benchmark
- Siap dikembangkan untuk analisis performa, ukuran output, dan keamanan

---

## Struktur Folder

Contoh struktur root proyek:

```text
LK6-PublicKeyCrypto-Comparison/
├── build/
├── cmake/
├── config/
├── data/
│   ├── input/
│   ├── raw/
│   └── processed/
├── docs/
├── include/
│   ├── algorithms/
│   ├── benchmarks/
│   ├── core/
│   └── utils/
├── results/
│   ├── csv/
│   └── logs/
├── scripts/
│   ├── run-build.ps1
│   └── run-benchmark.ps1
├── src/
│   ├── algorithms/
│   ├── benchmarks/
│   ├── core/
│   ├── utils/
│   └── main.cpp
├── tests/
├── third_party/
├── CMakeLists.txt
├── vcpkg.json
└── README.md
```

### Penjelasan singkat

- **include/**: header file utama
- **src/**: implementasi source code
- **scripts/**: helper script PowerShell
- **data/**: dataset benchmark
- **results/**: output hasil pengujian
- **docs/**: catatan setup, metodologi, dan dokumentasi kelompok

---

## Kebutuhan Sistem

Proyek ini paling nyaman dijalankan di **Windows**.

### Wajib

- **Windows 10/11**
- **Visual Studio Community / Build Tools** dengan workload:
  - `Desktop development with C++`
- **CMake**
- **Git**
- **PowerShell**
- **vcpkg**
- **Crypto++** melalui vcpkg

### Komponen Visual Studio yang disarankan

Saat install Visual Studio / Build Tools, pastikan ini tersedia:

- MSVC Build Tools
- C++ CMake tools for Windows
- Windows SDK
- vcpkg package manager

---

## Instalasi Dependency

## 1) Install Visual Studio / Build Tools

Install salah satu:

- **Visual Studio Community**
- atau **Build Tools for Visual Studio**

Lalu centang workload:

```text
Desktop development with C++
```

---

## 2) Install vcpkg

Buka PowerShell, lalu jalankan:

```powershell
cd C:\
git clone https://github.com/microsoft/vcpkg.git
cd .\vcpkg
.\bootstrap-vcpkg.bat
```

Setelah itu, set environment variable untuk sesi PowerShell saat ini:

```powershell
$env:VCPKG_ROOT="C:\vcpkg"
$env:PATH="$env:VCPKG_ROOT;$env:PATH"
```

---

## 3) Install Crypto++

Install dependency utama:

```powershell
vcpkg install cryptopp:x64-windows
```

Kalau sukses, set path Crypto++:

```powershell
$env:CRYPTOPP_ROOT="C:\vcpkg\installed\x64-windows"
```

Cek header dan library:

```powershell
Test-Path C:\vcpkg\installed\x64-windows\include\cryptopp\cryptlib.h
Test-Path C:\vcpkg\installed\x64-windows\lib
```

Kalau keduanya menghasilkan `True`, maka Crypto++ sudah siap dipakai.

---

## Build Proyek

> Disarankan menjalankan build dari **Developer PowerShell for Visual Studio** agar toolchain MSVC dan CMake langsung terbaca.

Masuk ke root proyek:

```powershell
cd D:\Ngoding\LK6-PublicKeyCrypto-Comparison
```

Set path Crypto++:

```powershell
$env:CRYPTOPP_ROOT="C:\vcpkg\installed\x64-windows"
```

Lalu build:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-build.ps1 -Config Release -CryptoPPRoot $env:CRYPTOPP_ROOT
```

Kalau berhasil, executable biasanya akan terbentuk di:

```text
build\Release\lk6_crypto_compare.exe
```

---

## Menjalankan Program

### Menjalankan executable langsung

```powershell
.\build\Release\lk6_crypto_compare.exe
```

### Menjalankan benchmark via script

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-benchmark.ps1 -DatasetRoot ".\data\input"
```

Kalau script benchmark sudah punya default path, kadang cukup:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-benchmark.ps1
```

---

## Dataset

Sesuai kebutuhan LK, siapkan dataset minimal **100 file/plainteks** dengan ukuran bervariasi. Format file dapat berupa:

- `.txt`
- `.csv`
- `.json`

Kategori ukuran yang disarankan:

- **very_small**: `< 10 KB`
- **small**: `10–100 KB`
- **medium**: `100 KB – 1 MB`
- **large**: `1–5 MB`
- **very_large**: `> 5 MB`

Contoh organisasi:

```text
data/input/
├── very_small/
├── small/
├── medium/
├── large/
└── very_large/
```

Pastikan:

- isi file tidak identik
- ukuran file benar-benar bervariasi
- dataset cukup untuk membandingkan waktu, ukuran output, dan karakteristik algoritma

---

## Output Hasil

Hasil benchmark biasanya disimpan ke:

```text
results/csv/
results/logs/
```

Contoh metrik yang dapat dicatat:

- nama algoritma
- ukuran file
- waktu enkripsi
- waktu dekripsi
- ukuran ciphertext / output
- catatan error atau keterbatasan algoritma

---

## Arsitektur Proyek

Proyek ini mengikuti pendekatan **modularity harmony**, yaitu:

- **Single Responsibility**: tiap modul menangani satu tugas utama
- **Low Coupling**: antar modul tidak terlalu saling terikat
- **High Cohesion**: fungsi yang sejenis dikelompokkan dalam modul yang sama
- **Consistent Interfaces**: tiap algoritma mengikuti pola API yang sejenis
- **Benchmark Separation**: logika eksperimen dipisahkan dari logika algoritma

### Pembagian folder secara logis

- **core/**: tipe data, interface, factory
- **algorithms/**: implementasi RSA, ECIES, ElGamal, Hybrid RSA-AES
- **benchmarks/**: runner untuk eksperimen
- **utils/**: file I/O, timer, CSV writer, helper lain

---

## Catatan Tentang Avalanche Effect

Bagian **avalanche effect** perlu diperhatikan secara metodologis.

Untuk algoritma seperti:

- RSA
- ElGamal
- ECIES

hasil enkripsi modern biasanya **bersifat probabilistik / randomized**, sehingga ciphertext bisa berubah walaupun plaintext sama. Akibatnya, pengukuran avalanche effect pada ciphertext harus dianalisis dengan hati-hati.

Rekomendasi:

- gunakan bagian avalanche effect dengan metodologi yang dijelaskan jelas di laporan
- beri catatan bahwa skema public-key modern tidak selalu deterministik
- untuk analisis yang lebih stabil, avalanche effect lebih cocok dievaluasi pada bagian simetris seperti **AES** dalam skema hybrid

> Jadi, bila proyek ini belum sepenuhnya mengotomatisasi avalanche effect, bagian tersebut dapat ditambahkan sebagai modul eksperimen lanjutan.

---

## Troubleshooting

### 1) Script `.ps1` tidak bisa dijalankan

Jika PowerShell menolak script karena execution policy:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Lalu jalankan ulang script.

---

### 2) `cmake` tidak dikenali

Jika muncul error:

```text
cmake : The term 'cmake' is not recognized
```

Solusi:
- tutup terminal lama, buka lagi
- gunakan **Developer PowerShell for Visual Studio**
- cek:

```powershell
cmake --version
```

---

### 3) vcpkg tidak menemukan Visual Studio

Jika muncul error terkait:

```text
Unable to find a valid Visual Studio instance
```

pastikan workload berikut sudah terinstall:

```text
Desktop development with C++
```

---

### 4) Crypto++ tidak ditemukan saat build

Pastikan environment variable ini sudah diset:

```powershell
$env:CRYPTOPP_ROOT="C:\vcpkg\installed\x64-windows"
```

Lalu cek file berikut ada:

```powershell
Test-Path C:\vcpkg\installed\x64-windows\include\cryptopp\cryptlib.h
```

---

## Saran Pengembangan Lanjutan

Beberapa peningkatan yang bisa ditambahkan:

- generator dataset otomatis
- perhitungan avalanche effect otomatis
- visualisasi hasil benchmark
- export laporan ringkas dari CSV
- validasi ukuran ciphertext dan key size untuk tiap algoritma

---

## Quick Start

Kalau semua dependency sudah terpasang, langkah singkatnya:

```powershell
cd D:\Ngoding\LK6-PublicKeyCrypto-Comparison
$env:CRYPTOPP_ROOT="C:\vcpkg\installed\x64-windows"
powershell -ExecutionPolicy Bypass -File .\scripts\run-build.ps1 -Config Release -CryptoPPRoot $env:CRYPTOPP_ROOT
powershell -ExecutionPolicy Bypass -File .\scripts\run-benchmark.ps1 -DatasetRoot ".\data\input"
```

---

## Status Implementasi

README ini ditulis untuk membantu instalasi dan penggunaan proyek **stage 2** yang sudah berhasil:

- build dengan CMake
- integrasi Crypto++
- benchmark dasar
- struktur modular

Jika ada modul tambahan setelah ini, cukup perluas README pada bagian:
- dataset
- benchmark metrics
- avalanche effect
- format hasil CSV

---

## Lisensi dan Penggunaan

Proyek ini disusun untuk kebutuhan akademik LK 6. Silakan gunakan sebagai basis pengembangan kelompok, lalu sesuaikan:
- nama kelompok
- data eksperimen
- hasil analisis
- kesimpulan akhir