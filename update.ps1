#################################################
# HelloID-Conn-Prov-Target-Corsa-Users-Update
# Update csv row
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
#endregion functions

#region account
# Define correlation
$correlationField = $actionContext.CorrelationConfiguration.AccountField
$correlationValue = $actionContext.CorrelationConfiguration.accountFieldValue

$account = $actionContext.Data

$accountPropertiesToCompare = $account.PsObject.Properties.Name
#endRegion account

try {
    #region Verify account reference
    $actionMessage = "verifying account reference"
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw "The account reference could not be found"
    }
    #endregion Verify account reference

    #region Import CSV data
    $actionMessage = "importing data from CSV file at path [$($actionContext.Configuration.CsvPath)]"

    $csvContent = $null
    if(Test-Path $actionContext.Configuration.CsvPath)
    {
        $csvContent = Import-Csv -Path $actionContext.Configuration.CsvPath `
                                 -Delimiter "`t" `
                                 -Encoding $actionContext.Configuration.Encoding
    }
    
    # Group on correlation field to match employee to CSV row(s)
    $csvContentGrouped = $csvContent | Group-Object -Property $correlationField -AsString -AsHashTable

    Write-Verbose "Imported data from CSV file at path [$($actionContext.Configuration.CsvPath)]. Result count: $(($csvContent | Measure-Object).Count)"
    #endregion Import CSV data

    if ($actionContext.CorrelationConfiguration.Enabled -eq $true) {
        #region Get current row for person
        $actionMessage = "querying CSV row where [$($correlationField)] = [$($correlationValue)]"

        $currentRow = $null
        if ($null -ne $csvContentGrouped) {
            $currentRow = $csvContentGrouped["$($correlationValue)"]
        }

        Write-Information "Queried CSV row where [$($correlationField)] = [$($correlationValue)]. Result count: $(($currentRow | Measure-Object).Count)"
        #endregion Get current row for person
    }

    #region Account
    #region Calulate action
    $actionMessage = "calculating action"
    if (($currentRow | Measure-Object).count -eq 1) {
        $actionMessage = "comparing current account to mapped properties"

        # Set Previous data (if there are no changes between PreviousData and Data, HelloID will log "update finished with no changes")
        $outputContext.PreviousData = $currentRow | Select-Object -First 1

        # Create reference object from correlated account
        $accountReferenceObject = [PSCustomObject]@{}
        foreach ($currentRowProperty in ($currentRow | Get-Member -MemberType NoteProperty)) {
            # Add property using -join to support array values
            $accountReferenceObject | Add-Member -MemberType NoteProperty -Name $currentRowProperty.Name -Value ($currentRow.$($currentRowProperty.Name) -join ",") -Force
        }

        # Create difference object from mapped properties
        $accountDifferenceObject = [PSCustomObject]@{}
        foreach ($accountAccountProperty in $account.PSObject.Properties) {
            # Add property using -join to support array values
            $accountDifferenceObject | Add-Member -MemberType NoteProperty -Name $accountAccountProperty.Name -Value ($accountAccountProperty.Value -join ",") -Force
        }

        $accountSplatCompareProperties = @{
            ReferenceObject  = $accountReferenceObject.PSObject.Properties | Where-Object { $_.Name -in $accountPropertiesToCompare }
            DifferenceObject = $accountDifferenceObject.PSObject.Properties | Where-Object { $_.Name -in $accountPropertiesToCompare }
        }

        if ($null -ne $accountSplatCompareProperties.ReferenceObject -and $null -ne $accountSplatCompareProperties.DifferenceObject) {
            $accountPropertiesChanged = Compare-Object @accountSplatCompareProperties -PassThru
            $accountOldProperties = $accountPropertiesChanged | Where-Object { $_.SideIndicator -eq "<=" }
            $accountNewProperties = $accountPropertiesChanged | Where-Object { $_.SideIndicator -eq "=>" }
        }

        if ($accountNewProperties) {
            $action = "Update"
            Write-Information "Account property(s) required to update: $($accountNewProperties.Name -join ', ')"
        }
        else {
            $action = "NoChanges"
        }

        Write-Verbose "Compared current account to mapped properties. Result: $action"
    }
    elseif (($currentRow | Measure-Object).count -gt 1) {
        $action = "MultipleFound"
    }
    elseif (($currentRow | Measure-Object).count -eq 0) {
        $action = "Create"
    }
    #endregion Calulate action

    #region Process
    switch ($action) {
        "Update" {
            #region Update csv row
            $actionMessage = "updating row in CSV"

            # Create custom object with old and new values (for logging)
            $accountChangedPropertiesObject = [PSCustomObject]@{
                OldValues = @{}
                NewValues = @{}
            }

            foreach ($accountOldProperty in ($accountOldProperties | Where-Object { $_.Name -in $accountNewProperties.Name })) {
                $accountChangedPropertiesObject.OldValues.$($accountOldProperty.Name) = $accountOldProperty.Value
            }

            foreach ($accountNewProperty in $accountNewProperties) {
                $accountChangedPropertiesObject.NewValues.$($accountNewProperty.Name) = $accountNewProperty.Value
            }

            #region Create custom updated csv object without current row for person (to make sure only HelloID input remains)
            $updatedCsvContent = $null
            $updatedCsvContent = [System.Collections.ArrayList](, ($csvContent | Where-Object { $_ -notin $currentRow }))
            #endregion Create custom updated csv object without current row for person (to make sure only HelloID input remains)

            #region Add new CSV row to custom updated csv object
            [void]$updatedCsvContent.Add($account)
            #endregion Add new CSV row to custom updated csv object

            #region Export updated CSV object
            $exportCsvSplatParams = @{
                Path              = $actionContext.Configuration.CsvPath
                Delimiter         = "`t"
                Encoding          = $actionContext.Configuration.Encoding
                ErrorAction       = "Stop"
                Verbose           = $false
            }

            if (-Not($actionContext.DryRun -eq $true)) {
                $null = $updatedCsvContent | Foreach-Object { $_ } | Select-Object "Code_personeel", 
                            "CODE_GEBRUIK",
                            "NETWERK_GEBRUIK",
                            "Autorisatie",
                            "Resultaatvenster",
                            "Bevoegden",
                            "Variabel_venster",
                            "Vertrouwelijkheid",
                            "Werkproces",
                            "Zaaktype",
                            "SDGebruikersNaam" | ConvertTo-Csv -Delimiter $exportCsvSplatParams.Delimiter | Foreach-Object {$_ -replace '"',''} |  Set-Content -path $actionContext.Configuration.CsvPath -Encoding $actionContext.Configuration.Encoding

                #region Set AccountReference
                $outputContext.AccountReference = "$($correlationValue)"
                #endregion Set AccountReference

                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        # Action  = "" # Optional
                        Message = "Updated row in CSV [$($exportCsvSplatParams.Path)] with AccountReference: $($outputContext.AccountReference | ConvertTo-Json). Old values: $($accountChangedPropertiesObject.oldValues | ConvertTo-Json). New values: $($accountChangedPropertiesObject.newValues | ConvertTo-Json)"
                        IsError = $false
                    })
            }
            else {
                Write-Warning "DryRun: Would update row in CSV [$($exportCsvSplatParams.Path)] where [$($correlationField)] = [$($correlationValue)]. Old values: $($accountChangedPropertiesObject.oldValues | ConvertTo-Json). New values: $($accountChangedPropertiesObject.newValues | ConvertTo-Json)"
            }
            #endregion Update csv row

            break
        }

        "NoChanges" {
            #region No changes
            $actionMessage = "skipping updating row in CSV"

            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    # Action  = "" # Optional
                    Message = "Skipped updating row in CSV with AccountReference: $($actionContext.References.Account | ConvertTo-Json). Reason: No changes."
                    IsError = $false
                })
            #endregion No changes

            break
        }

        "MultipleFound" {
            #region Multiple accounts found
            $actionMessage = "updating row in CSV"

            # Throw terminal error
            throw "Multiple CSV rows found where [$($correlationField)] = [$($correlationValue)]. Please correct this so the persons are unique."
            #endregion Multiple accounts found

            break
        }

        "Create" {
            #region Create csv row
            $actionMessage = "creating row in CSV"

            #region Create custom updated csv object
            $updatedCsvContent = $null
            $updatedCsvContent = [System.Collections.ArrayList](, ($csvContent))
            #endregion Create custom updated csv object

            #region Add new CSV row to custom updated csv object
            [void]$updatedCsvContent.Add($account)
            #endregion Add new CSV row to custom updated csv object

            #region Export updated CSV object
            $exportCsvSplatParams = @{
                Path              = $actionContext.Configuration.CsvPath
                Delimiter         = "`t"
                Encoding          = $actionContext.Configuration.Encoding
                ErrorAction       = "Stop"
                Verbose           = $false
            }
            
            if (-Not($actionContext.DryRun -eq $true)) {
                if (Test-Path $actionContext.Configuration.CsvPath) {
                    $null = $updatedCsvContent | Foreach-Object { $_ } | Select-Object "Code_personeel", 
                            "CODE_GEBRUIK",
                            "NETWERK_GEBRUIK",
                            "Autorisatie",
                            "Resultaatvenster",
                            "Bevoegden",
                            "Variabel_venster",
                            "Vertrouwelijkheid",
                            "Werkproces",
                            "Zaaktype",
                            "SDGebruikersNaam" | ConvertTo-Csv -Delimiter $exportCsvSplatParams.Delimiter | Foreach-Object {$_ -replace '"',''} |  Set-Content -path $actionContext.Configuration.CsvPath -Encoding $actionContext.Configuration.Encoding
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
                            "SDGebruikersNaam" | ConvertTo-Csv -Delimiter $exportCsvSplatParams.Delimiter | Foreach-Object {$_ -replace '"',''} | Set-Content -path $actionContext.Configuration.CsvPath -Encoding $actionContext.Configuration.Encoding
                }

                #region Set AccountReference
                $outputContext.AccountReference = "$($correlationValue)"
                #endregion Set AccountReference

                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        # Action  = "" # Optional
                        Message = "Created row in CSV [$($exportCsvSplatParams.Path)] where [$($correlationField)] = [$($correlationValue)] with AccountReference: $($outputContext.AccountReference | ConvertTo-Json)."
                        IsError = $false
                    })
            }
            else {
                Write-Warning "DryRun: Would create row in CSV [$($exportCsvSplatParams.Path)] where [$($correlationField)] = [$($correlationValue)]."
            }
            #endregion Create csv row

            break
        }
    }
    #endregion Process
    #endregion Account
}
catch {
    $ex = $PSItem
    $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    Write-Warning "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

    $outputContext.AuditLogs.Add([PSCustomObject]@{
            # Action  = "" # Optional
            Message = $auditMessage
            IsError = $true
        })
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if ($outputContext.AuditLogs.IsError -contains $true) {
        $outputContext.Success = $false
    }
    else {
        $outputContext.Success = $true
    }
}