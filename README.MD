# ROM Extraction Utility

PowerShell-based toolkit for unpacking and converting Android firmware images.  
Supports `.zip`, `.dat.br`, and `payload.bin` ROMs — automatically converting them to mountable `system.img` images or full extracted filesystems.

---

## Features

- **ZIP → IMG Conversion**  
  Extracts a full ROM ZIP and converts `system.new.dat(.br)` into `system.img`.

- **DAT.BR → IMG Conversion**  
  Converts `system.new.dat.br` + `system.transfer.list` directly to `system.img`.

- **Manual DAT.BR Selection**  
  Lets you interactively pick any `.dat.br` file for conversion.

- **Payload Extraction**  
  Extracts all partitions from `payload.bin` using `payload_dumper.exe`.

- **Filesystem Extraction**  
  Extracts contents of `system.img` (and optionally `vendor.img`) into readable folders.

- **Safe Overwrite Protection**  
  Prevents accidental file overwrites; auto-renames duplicates with timestamps.

- **Interactive, Color-Coded TUI**  
  Colorized numbered menu with `[FOUND]` indicators for available options.

- **Cleanup Prompt**  
  Option to delete temporary extraction directories on exit.

---

## Requirements

### 🔹 Tools Folder
Place these executables and scripts under a `tools` directory in the same folder as the PowerShell script:

| File | Purpose |
|------|----------|
| `7z.exe` | Archive extractor |
| `brotli.exe` | Decompresses `.dat.br` files |
| `sdat2img.py` | Converts `.dat` + `.transfer.list` to `.img` |
| `payload_dumper.exe` | Extracts `payload.bin` partitions |
| `Imgextractor.exe` | Unpacks `.img` filesystem images |

> **Note:** Python 3 must be installed and accessible in your system PATH.

---

## Directory Structure

```
ROM-Extractor/
│
├─ sys-img-extractor.ps1
├─ tools/
│   ├─ 7z.exe
│   ├─ brotli.exe
│   ├─ sdat2img.py
│   ├─ payload_dumper.exe
│   └─ Imgextractor.exe
│
├─ temp_files/
│   └─ rom/                # Extraction workspace
│
└─ extracted_files/
    └─ system/             # Final output files
```

---

## Usage

1. **Launch PowerShell as Administrator**
2. Navigate to the script folder:
   ```powershell
   cd "C:\Path\To\ROM-Extractor"
   ```
3. **Run the script**:
   ```powershell
   .\sys-img-extractor.ps1
   ```
4. Follow the interactive menu:
   ```
   ==============================
      ROM Extraction Utility
   ==============================

   [1] Full ZIP to system.img           [FOUND]
   [2] system.new.dat.br to system.img  [ ]
   [3] payload.bin to images            [ ]
   [4] Extract system.img to filesystem [ ]
   [5] Manually select .dat.br to system.img [OPTIONAL]

   [Q] Quit
   ```

---

## Cleanup Behavior

When exiting, if the `temp_files\rom` directory exists, the script will prompt:
```
Temporary directory detected: C:\ROM-Extractor\temp_files\rom
Delete temporary files now? (y/N)
```
Press **Y** to clean up or any other key to retain temporary data.

---

## Notes

- The script is **non-destructive** — it won’t overwrite existing output unless you explicitly confirm.
- Handles corrupted or missing input files gracefully with clear, color-coded error messages.
- Designed for educational and analysis use only.

---

## Example Conversion Flow

```
1. Place your ROM ZIP or system.new.dat.br in the main folder.
2. Run the script → choose [1] or [2].
3. Wait for conversion to complete → system.img appears under extracted_files.
4. Choose [4] to unpack system.img into a readable filesystem.
5. Optional: delete temp files on exit.
```
