<div align="center">

# PayloadFlashableZip

**OTA Package Builder for Termux**

Build flashable OTA packages with payload.bin support for Custom Recovery

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Termux-green.svg)](https://termux.com)
[![Recovery](https://img.shields.io/badge/Recovery-TWRP%20%7C%20OrangeFox%20%7C%20PBRP-orange.svg)]()

</div>

---

## 📖 Usage

```bash
./build_ota.sh -d <device> -o <output.zip>
```

| Option | Description | Required |
|:------:|-------------|:--------:|
| `-d` | Device codename | ✓ |
| `-o` | Output filename | ✓ |
| `-p` | payload.bin path (auto-detect) | ✗ |
| `-P` | payload_properties.txt path | ✗ |
| `-h` | Show help | ✗ |

---

## 🚀 Quick Start

```bash
# Clone repository
git clone https://github.com/hoshiyomiX/PayloadFlashableZip.git
cd PayloadFlashableZip

# Add payload files
cp /path/to/payload.bin .
cp /path/to/payload_properties.txt .

# Build OTA package
./build_ota.sh -d X695C -o MyROM.zip

# Flash via Custom Recovery
```

---

## 📱 Supported Recoveries

| Recovery | Minimum Version | Payload Support |
|:---------|:---------------:|:---------------:|
| TWRP | 3.5+ | ✅ |
| OrangeFox | R11+ | ✅ |
| PBRP | Latest | ✅ |
| SkyHawk | Latest | ✅ |
| RedWolf | Latest | ✅ |
| Stock Recovery | Any | ❌ |

---

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| `payload.bin not found` | Place payload.bin in script directory |
| `Update engine failed` | Verify payload.bin is valid |
| Bootloop | `fastboot flash vbmeta --disable-verity vbmeta.img` |
| Assertion failed | Check device codename matches |

---

<div align="center">

## 📄 License

**MIT** © [hoshiyomiX](https://github.com/hoshiyomiX)

</div>
