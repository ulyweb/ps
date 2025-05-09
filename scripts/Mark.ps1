Get-ChildItem -Path "C:\Users" -Directory |
    Select-Object @{
        Name = "Size"
        Expression = {
            $bytes = (Get-ChildItem $_.FullName -Recurse -File | Measure-Object Length -Sum).Sum
            if ($bytes -ge 1GB) {
                "{0:N2} GB" -f ($bytes / 1GB)
            } elseif ($bytes -ge 1MB) {
                "{0:N2} MB" -f ($bytes / 1MB)
            } elseif ($bytes -ge 1KB) {
                "{0:N2} KB" -f ($bytes / 1KB)
            } else {
                "$bytes Bytes"
            }
        }
    }, Name, CreationTime |
    Sort-Object CreationTime -Descending |
    Out-GridView -Title "User Folders with Sizes"
