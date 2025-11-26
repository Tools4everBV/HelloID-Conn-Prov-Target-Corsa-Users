#################################################
# HelloID-Conn-Prov-Target-Corsa-Users-Create
# Create or correlate to CSV row
# PowerShell V2
#################################################
# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region account
# Define correlation
$correlationField = $actionContext.CorrelationConfiguration.AccountField
$correlationValue = [string]$actionContext.CorrelationConfiguration.accountFieldValue

$account = $actionContext.Data

#endregion

try {
    #region Verify correlation configuration
    $actionMessage = "verifying correlation configuration and properties"

    if ($actionContext.CorrelationConfiguration.Enabled -eq $true) {
        if ([string]::IsNullOrEmpty($correlationField)) { throw "Correlation is enabled but not configured correctly." }
        if ([string]::IsNullOrEmpty($correlationValue)) { throw "The correlation value for [$correlationField] is empty." }
    }
    else { throw "Correlation is disabled. This connector requires correlation." }
    #endregion

    #region Import CSV data
    $actionMessage = "importing data from CSV file at path [$($actionContext.Configuration.CsvPath)]"
    $csvContent = @()
    if (Test-Path $actionContext.Configuration.CsvPath) {
        $csvContent = Import-Csv -Path $actionContext.Configuration.CsvPath `
                                 -Delimiter "`t" `
                                 -Encoding $actionContext.Configuration.Encoding
    }

    # Remove empty/null rows
    $csvContent = $csvContent | Where-Object { $_ -ne $null }

    # Group by correlation field
    $csvContentGrouped = @{}
    if ($csvContent) {
        $csvContentGrouped = $csvContent | Group-Object -Property $correlationField -AsString -AsHashTable
    }

    Write-Information "Imported data from CSV file at path [$($actionContext.Configuration.CsvPath)]. Result count: $(($csvContent | Measure-Object).Count)"
    #endregion

    #region Get current row for person
    $actionMessage = "querying CSV row where [$($correlationField)] = [$($correlationValue)]"
    $currentRow = $null
    if ($null -ne $csvContentGrouped) {
        $currentRow = $csvContentGrouped["$($correlationValue)"]
    }
    Write-Information "Queried CSV row where [$($correlationField)] = [$($correlationValue)]. Result count: $(($currentRow | Measure-Object).Count)"
    #endregion

    #region Determine action
    $actionMessage = "calculating action"
    if (($currentRow | Measure-Object).Count -eq 0) { $action = "Create" }
    elseif (($currentRow | Measure-Object).Count -eq 1) { $action = "Correlate" }
    else { $action = "MultipleFound" }
    #endregion

    #region Process
    switch ($action) {
        "Create" {
            $actionMessage = "creating row in CSV"

            # Initialize updated CSV content without empty/null rows
            $updatedCsvContent = [System.Collections.ArrayList]::new()
            $csvContent | ForEach-Object { [void]$updatedCsvContent.Add($_) }

            # Only add new user if not already in CSV
            if (-not $csvContentGrouped.ContainsKey($correlationValue)) {
                [void]$updatedCsvContent.Add($account)
            }

            $exportCsvSplatParams = @{
                Path              = $actionContext.Configuration.CsvPath
                Delimiter         = "`t"
                Encoding          = $actionContext.Configuration.Encoding
                ErrorAction       = "Stop"
            }

            if (-not $actionContext.DryRun) {
                if (Test-Path $actionContext.Configuration.CsvPath) {
                    # Export CSV with headers, remove quotes
                    $updatedCsvContent | ForEach-Object { $_ } |
                        Select-Object "Code_personeel", 
                            "CODE_GEBRUIK",
                            "NETWERK_GEBRUIK",
                            "Autorisatie",
                            "Resultaatvenster",
                            "Bevoegden",
                            "Variabel_venster",
                            "Vertrouwelijkheid",
                            "Werkproces",
                            "Zaaktype",
                            "SDGebruikersNaam" |
                        ConvertTo-Csv -Delimiter $exportCsvSplatParams.Delimiter |
                        ForEach-Object { $_ -replace '"','' } |
                        Set-Content -Path $exportCsvSplatParams.Path -Encoding $exportCsvSplatParams.Encoding
                }
                else {
                    $account | Select-Object "Code_personeel", 
                            "CODE_GEBRUIK",
                            "NETWERK_GEBRUIK",
                            "Autorisatie",
                            "Resultaatvenster",
                            "Bevoegden",
                            "Variabel_venster",
                            "Vertrouwelijkheid",
                            "Werkproces",
                            "Zaaktype",
                            "SDGebruikersNaam" | 
                        ConvertTo-Csv -Delimiter "`t" | 
                        ForEach-Object {$_ -replace '"',''} | 
                        Set-Content -path $exportCsvSplatParams.Path -Encoding $exportCsvSplatParams.Encoding
                        
                }

                $outputContext.AccountReference = "$($correlationValue)"
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Created row in CSV [$($exportCsvSplatParams.Path)] where [$($correlationField)] = [$($correlationValue)]."
                    IsError = $false
                })
            }
            else {
                Write-Warning "DryRun: Would create row in CSV [$($exportCsvSplatParams.Path)] where [$($correlationField)] = [$($correlationValue)]."
                $outputContext.AccountReference = "DryRun: Currently not available"
            }
        }

        "Correlate" {
            $actionMessage = "correlating to CSV row"
            $outputContext.AccountReference = "$($correlationValue)"
            $outputContext.Data = $currentRow[0]
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "CorrelateAccount"
                Message = "Correlated to CSV row with AccountReference: $($outputContext.AccountReference) on [$($correlationField)] = [$($correlationValue)]."
                IsError = $false
            })
            $outputContext.AccountCorrelated = $true
        }

        "MultipleFound" {
            throw "Multiple CSV rows found where [$($correlationField)] = [$($correlationValue)]. Persons must be unique."
        }
    }
    #endregion

}
catch {
    $ex = $_
    $actionMessageEscaped = $actionMessage -replace '"','`"'
    Write-Warning "Error ${actionMessageEscaped}: $($ex.Exception.Message)"
    $outputContext.AuditLogs.Add([PSCustomObject]@{
        Message = "Error ${actionMessageEscaped}: $($ex.Exception.Message)"
        IsError = $true
    })
}
finally {
    $outputContext.Success = -not ($outputContext.AuditLogs.IsError -contains $true)

    if ([string]::IsNullOrEmpty($outputContext.AccountReference)) {
        if ($actionContext.DryRun) {
            $outputContext.AccountReference = "DryRun: Currently not available"
        }
        else {
            $outputContext.AccountReference = "$($correlationValue)"
        }
    }
}