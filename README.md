[README_2.md](https://github.com/user-attachments/files/27968615/README_2.md)
# Find-FileNames

A minimally-invasive PowerShell script for live-system triage. Reads a list of filename search terms from a text file and enumerates the filesystem to identify the presence of known files.

Built for incident response and forensic triage workflows where you need to quickly answer *"is this file on this box?"* across a list of indicators, without touching file contents or altering metadata.

## Why

During live-system triage, every action you take leaves a trace. Hashing files opens handles and can update last-access timestamps; full content inspection is invasive and slow. Filename enumeration via `Get-ChildItem` reads only MFT metadata — no file handles opened, no content touched — making it well-suited as a first-pass check against a list of known-bad or known-interesting filenames.

This script is intentionally narrow in scope: filename matching, fast, and forensically quiet.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Read access to the target filesystem (run as Administrator for full coverage of protected paths)

## Usage

1. Place `Search-FileNames.ps1` in a working directory.
2. Create a text file with search terms, one per line:

   ```
   123abcxyz
   xyzabc123
   suspicious_loader
   ```

3. Run the script:

   ```powershell
   # Defaults: reads .\search_terms.txt, scans C:\, writes .\results.csv
   .\Search-FileNames.ps1

   # Custom inputs
   .\Search-FileNames.ps1 -TermsFile .\iocs.txt -SearchPath D:\ -OutputFile .\hits.csv

   # Exact filename match instead of substring
   .\Search-FileNames.ps1 -ExactMatch
   ```

## Parameters

| Parameter     | Default                | Description                                                              |
|---------------|------------------------|--------------------------------------------------------------------------|
| `-TermsFile`  | `.\search_terms.txt`   | Path to a text file containing search terms, one per line                |
| `-SearchPath` | `C:\`                  | Root path to begin searching from                                        |
| `-OutputFile` | `.\results.csv`        | Path to write CSV results to                                             |
| `-ExactMatch` | *(off)*                | If set, requires exact filename or basename match instead of substring   |

## Matching behavior

- **Default (substring):** `123abcxyz` matches `123abcxyz`, `123abcxyz.exe`, and `backup_123abcxyz_old.zip`.
- **`-ExactMatch`:** matches only the literal filename or basename (with or without extension).
- Matching is case-insensitive in both modes.

## Output

Console output shows a running file-scanned counter every 10,000 files, followed by a results table. A CSV is written with the following columns:

| Column       | Description                                |
|--------------|--------------------------------------------|
| `SearchTerm` | The term from the input file that matched  |
| `FileName`   | Matched file's name                        |
| `FullPath`   | Absolute path to the matched file          |
| `SizeBytes`  | File size in bytes                         |
| `Modified`   | Last write time                            |

## Forensic considerations

- **Read-only on file contents.** The script never opens files for read; it only enumerates directory metadata.
- **No timestamp changes.** Enumeration does not update last-access times on modern Windows (where `NtfsDisableLastAccessUpdate` is enabled by default). On older systems where last-access updates are enabled, pure enumeration still does not trigger them — only opening file contents would.
- **Execution policy.** If blocked, either unblock the file (`Unblock-File .\Search-FileNames.ps1`) or invoke with `powershell.exe -ExecutionPolicy Bypass -File .\Search-FileNames.ps1`.
- **Reparse points and symlinks.** `Get-ChildItem -Recurse` does not follow symlinks by default but may traverse some reparse points. If you observe runaway scans, add a filter for `$_.LinkType`.
- **Permission errors are suppressed.** `-ErrorAction SilentlyContinue` is used to keep output clean across protected directories. Run elevated for complete coverage.

## Example

```
Loaded 2 term(s) from .\search_terms.txt
Searching:   C:\
Match mode:  Substring (contains)

  Scanned 10000 files... (matches so far: 0)
  Scanned 20000 files... (matches so far: 1)
  Scanned 30000 files... (matches so far: 2)

Files scanned: 38421
Matches:       2
Elapsed:       47.3s

SearchTerm FileName       FullPath
---------- --------       --------
123abcxyz  123abcxyz.exe  C:\Users\Public\Downloads\123abcxyz.exe
xyzabc123  xyzabc123.dll  C:\ProgramData\temp\xyzabc123.dll

CSV saved: .\results.csv
```

## License

MIT
