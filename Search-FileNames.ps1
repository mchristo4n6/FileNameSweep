<#
.SYNOPSIS
    Searches the filesystem for files whose names match terms from an input file.

.DESCRIPTION
    Reads a list of search terms (one per line) from a text file and walks the
    specified filesystem path looking for files whose names contain (or exactly
    match) any of those terms. Useful for IR triage and known-file identification.

.PARAMETER TermsFile
    Path to a text file containing search terms, one per line.

.PARAMETER SearchPath
    Root path to begin searching from. Defaults to C:\.

.PARAMETER OutputFile
    Path to write CSV results to. Defaults to .\results.csv.

.PARAMETER ExactMatch
    If set, requires an exact filename (or basename) match instead of substring match.

.EXAMPLE
    .\Search-FileNames.ps1
    Uses defaults: .\search_terms.txt, searches C:\, writes .\results.csv

.EXAMPLE
    .\Search-FileNames.ps1 -TermsFile .\iocs.txt -SearchPath D:\ -ExactMatch
#>

param(
    [string]$TermsFile  = ".\search_terms.txt",
    [string]$SearchPath = "C:\",
    [string]$OutputFile = ".\results.csv",
    [switch]$ExactMatch
)

# --- Validate inputs ---------------------------------------------------------
if (-not (Test-Path $TermsFile)) {
    Write-Error "Search terms file not found: $TermsFile"
    exit 1
}

$terms = Get-Content $TermsFile |
    Where-Object { $_.Trim() } |
    ForEach-Object { $_.Trim() }

if (-not $terms) {
    Write-Error "No search terms found in $TermsFile"
    exit 1
}

Write-Host "Loaded $($terms.Count) term(s) from $TermsFile" -ForegroundColor Cyan
Write-Host "Searching:   $SearchPath" -ForegroundColor Cyan
Write-Host "Match mode:  $(if ($ExactMatch) {'Exact'} else {'Substring (contains)'})" -ForegroundColor Cyan
Write-Host ""

# --- Walk filesystem ---------------------------------------------------------
$results = [System.Collections.Generic.List[object]]::new()
$start   = Get-Date
$scanned = 0

Get-ChildItem -Path $SearchPath -Recurse -File -Force -ErrorAction SilentlyContinue |
    ForEach-Object {
        $scanned++
        if ($scanned % 10000 -eq 0) {
            Write-Host "  Scanned $scanned files... (matches so far: $($results.Count))" -ForegroundColor DarkGray
        }

        $file = $_
        foreach ($term in $terms) {
            $hit = if ($ExactMatch) {
                ($file.Name -ieq $term) -or ($file.BaseName -ieq $term)
            } else {
                $file.Name -like "*$term*"
            }

            if ($hit) {
                $results.Add([PSCustomObject]@{
                    SearchTerm = $term
                    FileName   = $file.Name
                    FullPath   = $file.FullName
                    SizeBytes  = $file.Length
                    Modified   = $file.LastWriteTime
                })
            }
        }
    }

# --- Report ------------------------------------------------------------------
$elapsed = (Get-Date) - $start
Write-Host ""
Write-Host "Files scanned: $scanned" -ForegroundColor Green
Write-Host "Matches:       $($results.Count)" -ForegroundColor Green
Write-Host "Elapsed:       $([math]::Round($elapsed.TotalSeconds, 2))s" -ForegroundColor Green
Write-Host ""

if ($results.Count -gt 0) {
    $results | Format-Table SearchTerm, FileName, FullPath -AutoSize
    $results | Export-Csv -Path $OutputFile -NoTypeInformation -Force
    Write-Host "CSV saved: $OutputFile" -ForegroundColor Green
} else {
    Write-Host "No matches found." -ForegroundColor Yellow
}
