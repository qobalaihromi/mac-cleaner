# Mac Cleaner

Aplikasi cleaner macOS dengan dua mode:
- CLI: `mac-cleaner`
- GUI desktop: `Mac Cleaner.app`

Fokus utama: melonggarkan storage dengan scan junk file lalu cleanup aman ke Trash.

## Fitur
- Scan junk files user-level (`Caches`, `Logs`, browser caches, temp files, old trash)
- Ringkasan potensi storage yang bisa dibebaskan
- Visual insight: breakdown per kategori + top space wasters
- Duplicate finder (hash-based) untuk deteksi file duplikat
- Kategori + level risiko (`safe`, `review`)
- Cleanup ke Trash (bukan permanent delete)
- Manifest hasil cleanup di `~/.mac-cleaner/manifests/`
- Config user di `~/.mac-cleaner/config.json`

## Prasyarat
- macOS 13+
- Xcode Command Line Tools (`xcode-select --install`)

## Build
```bash
cd /Users/fa-15511/Documents/vibecoding/mac-cleaner
swift build -c release
```

## Install CLI
```bash
./scripts/install.sh
```

Jika perlu, tambahkan PATH ke `~/.zshrc`:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Install GUI (.app)
```bash
./scripts/install-gui-app.sh
open "$HOME/Applications/Mac Cleaner.app"
```

Atau jalankan GUI langsung tanpa install:
```bash
./scripts/run-gui.sh
```

## Cara pakai CLI
```bash
mac-cleaner help
mac-cleaner storage
mac-cleaner duplicates
mac-cleaner rules
mac-cleaner init-config
mac-cleaner scan
mac-cleaner clean
```

Contoh:
```bash
mac-cleaner scan --limit 200
mac-cleaner storage --json
mac-cleaner duplicates --groups 20
mac-cleaner clean --yes --limit 200
mac-cleaner clean --include-review --yes
```

## Konfigurasi
Buat config default:
```bash
mac-cleaner init-config
```

Contoh `~/.mac-cleaner/config.json`:
```json
{
  "excludedPathPrefixes": [
    "/Users/your-user/Library/Caches/com.company.important-app"
  ],
  "includeReviewByDefault": false,
  "minFileSizeBytes": 65536,
  "userRules": []
}
```

## Keamanan
- Default hanya target file user-level.
- Rule konservatif, item berisiko ditandai `review`.
- Cleanup selalu ke Trash dulu.
- Selalu jalankan scan dulu sebelum clean.

## Uninstall
```bash
./scripts/uninstall.sh
rm -rf "$HOME/Applications/Mac Cleaner.app"
```
