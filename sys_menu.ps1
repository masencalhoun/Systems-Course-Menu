<# ============================================================================
╔═════════════════════════════════sys_menu.ps1═════════════════════════════════╗
║This is a comprehensive PowerCLI command menu that automates the lifecycle    ║
║management of the Systems IQT course. This enables admins to rapidly deploy,  ║
║tear down, and update up to 34 identical student suites using linked-clones   ║
║while enforcing strict Layer 2 network isolation via physical and logical     ║
║air-gapped port groups and DRS affinity rules.                                ║
║                                                                              ║
║                                                                              ║
║Written by: Masen Calhoun                                                     ║
║                                                                              ║
║Last Update: 17Jun2026                                                        ║
║                                                                              ║
║17JUN:  Added Function_AuditIsolation, Invoke-DebugMenu,                      ║
║        Function_PushFiletoVM, Function_BroadcastMessage                      ║
╚══════════════════════════════════════════════════════════════════════════════╝
    TODO:
    ... ADD:    Function_Take_StudentSnap
    ... ADD:    Funciton_StaggeredShutdown
    ... ADD:    Function_PullFileFromVM

#>
# ----------------------------------------------------------------------------
# GLOBAL VARIABLES
# ----------------------------------------------------------------------------
$vCenterServer     = "vcs.learn.domain"
$datacenterName    = "Student Datacenter"
$clusterName       = "Student-Compute-Cluster"
$vdsName           = "vDS-Student-Net"
$targetDatastore   = "vol_nfs_sys_training_vm2"  
$masterFolder      = "Suite-00-Golden"           
$templatePrefix    = "^tmpl-SDC-"             
$suiteDelaySeconds = 60                          
$adDomain          = "learn.domain"
$date              = Get-Date -Format "ddMMMyyyy HH:mm"


# --- VM MAPPING DICTIONARY ---
$globalVmMapping = @{
    "Apps"       = @("Application01-00", "Application02-00")
    "Clients"    = @("ADMIN-01v-00", "SDC-01v-00", "tmpl-SDC-00")
    "Core"       = @("AD1-00", "AD2-00", "License-00") 
    "EndPoint"   = @("SCANN-00", "EPO2022-00", "MECM2019-00", "SQL2019-00")
    "EXCH"       = @("EDGE2022-00", "EXCH2022-00")
    "Network"    = @("NETAPP-01-00", "NETAPP-02-00")
}

# ----------------------------------------------------------------------------
# MENUS
# ----------------------------------------------------------------------------

function Show-MainMenu {
    Clear-Host
    Write-Host "---------------------- $vCenterServer ----------------------" -ForegroundColor Darkgray
    Write-Host "----------------------         $date          ----------------------" -ForegroundColor Darkgray
    Write-Host "-----------------------== SYSTEMS COURSE ORCHESTRATOR ==----------------------" -ForegroundColor Cyan
    Write-Host "------------ All Functions/Sub-menus have confirmation executions ------------" -ForegroundColor Darkgray
    Write-Host "╔════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Gray
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "[1] Take New Snapshot" -ForegroundColor White -NoNewLine; Write-Host -Foreground gray "                                                       ║"
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "    ╚═>Takes foundational snapshots of Golden Master VMs ($masterFolder)" -ForegroundColor DarkGray -NoNewline; Write-Host -Foreground gray -NoNewLine "  ║"
    Write-Host -Foreground gray "`n║                                                                            ║" 
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "[2] Remove Old Linked-Clones" -ForegroundColor White -NoNewLine; Write-Host -Foreground gray "                                                ║"
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "    ╚═>Teardown: Powers off/Deletes student VMs and clears old DRS Rules" -ForegroundColor DarkGray -NoNewLine; Write-Host -Foreground gray -NoNewLine "    ║"
    Write-Host -Foreground gray "`n║                                                                            ║"
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "[3] Deploy New Linked-Clones & Affinity Rules" -ForegroundColor White -NoNewLine; Write-Host -Foreground gray "                               ║"
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "    ╚═>Deployment: Stamps out suites and applies 'Keep Together' rules" -ForegroundColor DarkGray -NoNewLine; Write-Host -Foreground gray -NoNewLine "      ║"
    Write-Host -Foreground gray "`n║                                                                            ║"
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "[4] Execute Staggered Power-On" -ForegroundColor White -NoNewLine; Write-Host -Foreground gray "                                              ║"
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "    ╚═>Operational: Powers on suites in 3 waves to mitigate Boot Storms" -ForegroundColor DarkGray -NoNewLine; Write-Host -Foreground gray -NoNewLine "     ║"
    Write-Host -Foreground gray "`n║                                                                            ║"
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "[5] One-Time Setup Scripts >>>" -ForegroundColor Magenta -NoNewLine; Write-Host -Foreground gray "                                              ║"
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "    ╚═>Opens sub-menu for infrastructural boundaries and permissions" -ForegroundColor DarkGray -NoNewLine; Write-Host -Foreground gray -NoNewLine "        ║"
    Write-Host -Foreground gray "`n║                                                                            ║"
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "[6] Instructor Scripts >>>" -ForegroundColor Magenta -NoNewLine; Write-Host -Foreground gray "                                                  ║"
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "    ╚═>Opens sub-menu for targeted instructional scripts and specific tasks" -ForegroundColor DarkGray -NoNewLine; Write-Host -Foreground gray -NoNewLine " ║"
    Write-Host -Foreground gray "`n║                                                                            ║"
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "[R] Refresh Connection >>>" -ForegroundColor Magenta -NoNewLine; Write-Host -Foreground gray "                                                  ║"
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "    ╚═>Re-authenticates to vCenter and disables web operation timeouts" -ForegroundColor DarkGray -NoNewLine; Write-Host -Foreground gray -NoNewLine "      ║"
    Write-Host -Foreground gray "`n║                                                                            ║"
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "[D] Admin Debug" -ForegroundColor White -NoNewline; Write-Host -Foreground gray "                                                             ║"
    Write-Host -Foreground gray -NoNewLine "║"; Write-host "[Q] Quit Orchestrator" -ForegroundColor White -NoNewline; Write-Host -Foreground gray "                                                       ║"
    Write-Host "╚════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Gray
}

function Show-OneTimeMenu {
    Clear-Host
    Write-Host "----== ONE-TIME SETUP SCRIPTS ==----" -ForegroundColor Magenta
    Write-Host "WARNING: These scripts alter cluster infrastructure." -ForegroundColor Yellow
    Write-Host "------------------------------------------" -ForegroundColor Gray
    Write-Host "[1] Build Logical Boundaries" -ForegroundColor White
    Write-Host "    ...Creates 32 VM Folders and 32 Isolated Air-Gapped Port Groups" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "[2] Assign Folder Permissions" -ForegroundColor White
    Write-Host "    ...Binds AD Student accounts to their respective Suite Folders" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "[B] Back to Main Menu" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor Gray
}

function Show-InstructorMenu {
    Clear-Host
    Write-Host "----== INSTRUCTOR SCRIPTS ==----" -ForegroundColor Magenta
    Write-Host "Targeted operational tasks for running classes." -ForegroundColor Yellow
    Write-Host "------------------------------------------" -ForegroundColor Gray
    Write-Host "[1] Reset NetApp Training VMs (NETAPP)" -ForegroundColor White
    Write-Host "    ...Deletes current NETAPP VMs and redeploys using 'PE_ready_netapp' snapshot" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "[2] Add SDC-02v to dPG to continue Lab" -ForegroundColor White
    Write-Host "    ...Adds SDC-02v-## to the respective suite's dPG and updates affinity rules" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "[3] Pull latest version of menu" -ForegroundColor White
    Write-Host "    ...Copies and replaces the latest version of the sys_menu.ps1 from `n       '\\Repository\c$\.scripts' -> 'c:\.scripts'" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "[4] Take Snapshot of ALL student suite VMs" -ForegroundColor White
    Write-Host "    ...Takes a snapshot of all student suite VMs found, and names the snapshot 'Stu_Snap'" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "[5] Copy File to Virtual Machine" -ForegroundColor White
    Write-Host "    ... Allows for Copying of file from local 'C:\.scripts\transfer' to a VM's 'C:\temp'" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "[6] Function_PullFileFromVM" -ForegroundColor White
    Write-Host "    ... Work In Progress" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "[7] Function_BroadcastMessage" -ForegroundColor White
    Write-Host "    ... Send a Pop-Up message to a Student Workstation, using WinRM" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "[B] Back to Main Menu" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor Gray
}

function Show-DebugMenu {
    Clear-Host
    Write-Host "----== INSTRUCTOR SCRIPTS ==----" -ForegroundColor Magenta
    Write-Host "Targeted operational tasks for running classes." -ForegroundColor Yellow
    Write-Host "------------------------------------------" -ForegroundColor Gray
    Write-Host "[1] Audit Isolation" -ForegroundColor White
    Write-Host "    ...Checks Isolation compliance for Network, DRS and VM/ESX Host" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "[B] Back to Main Menu" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor Gray
}

# ----------------------------------------------------------------------------
# HELPER & SUB-MENU FUNCTIONS
# ----------------------------------------------------------------------------

function Get-TargetSuites {
    $targetChoice = Read-Host "`nSelect scope [1] Specific Suite, [2] Range, [3] ALL (1-34), or [B]ack"
    $suiteArray = @()
    switch ($targetChoice) {
        '1' { 
            $num = Read-Host "Enter Suite number"
            if ($num -match "^\d+$" -and [int]$num -ge 1 -and [int]$num -le 32) { 
                $suiteArray += [int]$num 
            } else { 
                Write-Host "Invalid." -ForegroundColor Red; return $null 
            } 
        }
        '2' { 
            $range = Read-Host "Enter range (e.g., 1-5)"
            if ($range -match "^(\d+)-(\d+)$") { 
                $start = [int]$matches[1]
                $end = [int]$matches[2]
                if ($start -ge 1 -and $end -le 34 -and $start -le $end) { 
                    $suiteArray = $start..$end 
                } else { 
                    Write-Host "Invalid." -ForegroundColor Red; return $null 
                } 
            } else { 
                return $null 
            } 
        }
        '3' { 
            $suiteArray = 1..34 
        }
        { @('b','B') -contains $_ } { 
            return $null 
        }
        default { 
            Write-Host "Invalid." -ForegroundColor Red; return $null 
        }
    }
    return $suiteArray
}

function Invoke-OneTimeMenu {
    $subMenuActive = $true
    while ($subMenuActive) {
        Show-OneTimeMenu
        $subChoice = Read-Host "Select an option"
        switch ($subChoice) {
            '1' { 
                Function_BuildBoundaries
                Pause 
            }
            '2' { 
                Function_AssignFolderPermissions
                Pause 
            }
            { @('b','B') -contains $_ } { 
                $subMenuActive = $false 
            }
            default { 
                Write-Host "Invalid." -ForegroundColor Red
                Start-Sleep 1 
            }
        }
    }
}

function Invoke-InstructorMenu {
    $subMenuActive = $true
    while ($subMenuActive) {
        Show-InstructorMenu
        $subChoice = Read-Host "Select an option"
        switch ($subChoice) {
            '1' { 
                Function_ResetNetAppClones
                Pause 
            }
            '2' {
                Function_AddSDC02vTodPG
                Pause 
            }
            '3' {
                Function_GetNewVersion
                Pause 
            }
            '4' {
                Function_Take_StudentSnap
                Pause
            } 
            '5' {
                Function_PushFiletoVM
                Pause
            }
            '6' {
                Function_PullFileFromVM
                Pause
            }
            '7' {
                Function_BroadcastMessage
                Pause
            }
            { @('b','B') -contains $_ } { 
                $subMenuActive = $false 
            }
            default { 
                Write-Host "Invalid." -ForegroundColor Red
                Start-Sleep 1 
            }
        }
    }
}

function Invoke-DebugMenu {
$subMenuActive = $true
    while ($subMenuActive) {
        Show-DebugMenu
        $subChoice = Read-Host "Select an option"
        switch ($subChoice) {
            '1' { 
                Function_AuditIsolation
                Pause 
            }
            { @('b','B') -contains $_ } { 
                $subMenuActive = $false 
            }
            default { 
                Write-Host "Invalid." -ForegroundColor Red
                Start-Sleep 1 
            }
        }
    }
}

# ----------------------------------------------------------------------------
# CORE FUNCTIONS
# ----------------------------------------------------------------------------

function Function_TakeSnapshot {
    Write-Host "--- Take New Golden Snapshot ---" -ForegroundColor Cyan
    $goldenFolder = Get-Folder -Name $masterFolder -ErrorAction SilentlyContinue
    if (-not $goldenFolder) { Write-Host "Error: Folder '$masterFolder' not found." -ForegroundColor Red; return }
    $goldenVMs = $goldenFolder | Get-VM
    if ($goldenVMs.Count -eq 0) { Write-Host "Error: No VMs found." -ForegroundColor Red; return }
    if ($goldenVMs.Count -gt 0) { Write-Host "Found $($goldenVMs.Count) " -ForegroundColor Green }

    Write-Host "Analyzing existing snapshots..." -ForegroundColor Yellow
    $allSnaps = $goldenVMs | Get-Snapshot -ErrorAction SilentlyContinue
    $baseSnaps = $allSnaps | Where-Object { $_.Name -match "^Golden-Base-(\d+)$" }

    if ($baseSnaps) {
        $maxNum = ($baseSnaps | ForEach-Object { [int]$matches[1] } | Measure-Object -Maximum).Maximum
        $nextNum = $maxNum + 1
    } else { $nextNum = 1 }

    $snapName = "Golden-Base-{0:D2}" -f $nextNum
    Write-Host "`nNext snapshot will be named: $snapName" -ForegroundColor Green
    if ((Read-Host "Proceed? (Y/N)") -notmatch "^[Yy]$") { return }
    $snapDesc = Read-Host "Description (Optional)"

    $poweredOnVMs = $goldenVMs | Where-Object { $_.PowerState -eq 'PoweredOn' }
    if ($poweredOnVMs) {
        Write-Host "Shutting down powered-on Golden VMs..." -ForegroundColor Yellow
        $poweredOnVMs | Stop-VMGuest -Confirm:$false | Out-Null
        Start-Sleep -Seconds 20 
        $hungVMs = $goldenFolder | Get-VM | Where-Object { $_.PowerState -eq 'PoweredOn' }
        if ($hungVMs) { $hungVMs | Stop-VM -Confirm:$false | Out-Null }
    }

    Write-Host "`nTaking snapshot '$snapName'..." -ForegroundColor Cyan
    foreach ($vm in $goldenVMs) {
        Write-Host "  -> Snapshotting $($vm.Name)..."
        New-Snapshot -VM $vm -Name $snapName -Description $snapDesc -RunAsync | Out-Null
    }
    Write-Host "Tasks initiated!" -ForegroundColor Green
}

function Function_RemoveClones {
    Write-Host "--- TEARDOWN: Remove Old Linked-Clones & DRS Rules ---" -ForegroundColor Cyan
    Write-Host "NOTE: Templates matching '$templatePrefix' will NOT be deleted." -ForegroundColor Yellow
    
    $suiteArray = Get-TargetSuites
    if (-not $suiteArray) { return }

    Write-Host "`nWARNING: PERMANENTLY DELETING VMs/DRS Rules for $($suiteArray.Count) suite(s)." -ForegroundColor Red
    if ((Read-Host "Are you absolutely sure? (Y/N)") -notmatch "^[Yy]$") { return }

    $cluster = Get-Cluster -Name $clusterName
    foreach ($i in $suiteArray) {
        $suiteNum = "{0:D2}" -f $i
        $folderName = "Suite-$suiteNum"
        $ruleName = "Affinity-Suite-$suiteNum"
        Write-Host "`nProcessing $folderName..." -ForegroundColor Cyan

        $drsRule = Get-DrsRule -Cluster $cluster -Name $ruleName -ErrorAction SilentlyContinue
        if ($drsRule) { Write-Host "  -> Removing DRS Rule: $ruleName"; Remove-DrsRule -Rule $drsRule -Confirm:$false }

        $targetFolder = Get-Folder -Name $folderName -ErrorAction SilentlyContinue
        if ($targetFolder) {
            $allVMs = Get-VM -Location $targetFolder -ErrorAction SilentlyContinue
            $vmsToRemove = $allVMs | Where-Object { $_.Name -notmatch $templatePrefix }
            $skippedVMs  = $allVMs | Where-Object { $_.Name -match $templatePrefix }

            if ($skippedVMs) { Write-Host "  -> Preserving template(s): $($skippedVMs.Name)" -ForegroundColor Green }
            if ($vmsToRemove) {
                Write-Host "  -> Powering off and deleting $($vmsToRemove.Count) VMs..."
                $poweredOn = $vmsToRemove | Where-Object { $_.PowerState -eq 'PoweredOn' }
                if ($poweredOn) { $poweredOn | Stop-VM -Confirm:$false | Out-Null }
                foreach ($vm in $vmsToRemove) { Remove-VM -VM $vm -DeletePermanently -Confirm:$false -RunAsync | Out-Null }
            }
        }
    }
    Write-Host "`nTeardown initiated in background." -ForegroundColor Green
}

function Function_DeployClones {
    Write-Host "--- DEPLOYMENT: New Linked-Clones & Affinity Rules ---" -ForegroundColor Cyan
    Write-Host "---      INFO: 70Gb Storage, 400Gb RAM, 75 CPU     ---" -ForegroundColor DarkGray
    $suiteArray = Get-TargetSuites
    if (-not $suiteArray) { return }

    $goldenVMs = Get-Folder -Name $masterFolder -ErrorAction SilentlyContinue | Get-VM
    if ($goldenVMs.Count -eq 0) { Write-Host "Error: No Master VMs found." -ForegroundColor Red; return }

    $sampleSnaps = Get-Snapshot -VM $goldenVMs[0] | Sort-Object Created -Descending
    Write-Host "`nAvailable Snapshots:" -ForegroundColor Yellow
    $sampleSnaps | ForEach-Object { Write-Host " - $($_.Name) ($($_.Created))" }
    $snapName = Read-Host "`nEnter EXACT Snapshot Name"
    if ([string]::IsNullOrWhiteSpace($snapName)) { return }

    if ((Read-Host "Proceed with deployment? (Y/N)") -notmatch "^[Yy]$") { return }

    $cluster = Get-Cluster -Name $clusterName
    foreach ($i in $suiteArray) {
        $suiteNum = "{0:D2}" -f $i
        $parentFolderName = "Suite-$suiteNum"
        $pgName = "dPG-StudentCore-$suiteNum"
        $ruleName = "Affinity-Suite-$suiteNum"
        Write-Host "`nDeploying $parentFolderName..." -ForegroundColor Cyan
        
        $parentFolder = Get-Folder -Name $parentFolderName -ErrorAction SilentlyContinue
        $targetPG = Get-VDPortgroup -Name $pgName -ErrorAction SilentlyContinue
        if (-not $parentFolder -or -not $targetPG) { Write-Host "Error: Root Folder or PortGroup missing." -ForegroundColor Red; continue }

        $cloneTasks = @()
        foreach ($subFolderKey in $globalVmMapping.Keys) {
            $subFolder = Get-Folder -Name "$subFolderKey-$suiteNum" -Location $parentFolder -ErrorAction SilentlyContinue
            if (-not $subFolder) { $subFolder = New-Folder -Name "$subFolderKey-$suiteNum" -Location $parentFolder }
            ##
            foreach ($masterName in $globalVmMapping[$subFolderKey]) {
                $cloneName = $masterName -replace "-00$", "-$suiteNum"
                
                if ($masterName -match $templatePrefix) {
                    if (Get-VM -Name $cloneName -Location $subFolder -ErrorAction SilentlyContinue) {
                        Write-Host "  -> Template '$cloneName' exists. Skipping." -ForegroundColor Yellow
                        continue
                    }
                }
                #Get Master
                $masterVM = Get-VM -Name $masterName -ErrorAction SilentlyContinue
                if (-not $masterVM) {
                    Write-Host "  -> ERROR: Missing Master VM ($masterName)" -ForegroundColor Red
                    continue
                }
                #Get SNAPSHOT
                $snap = Get-Snapshot -VM $masterVM -Name $snapName -ErrorAction SilentlyContinue
                if (-not $snap) { 
                    Write-Host "  -> ERROR: Missing Snapshot ($snapName) on VM ($masterName)" -ForegroundColor Red 
                    continue 
                }

                
                try {
                    $task = New-VM -Name $cloneName -VM $masterVM -ReferenceSnapshot $snap -ResourcePool $cluster -Datastore $targetDatastore -Location "$subFolder" -LinkedClone -RunAsync -ErrorAction Stop -Confirm:$false
                    Write-Host "  -> Cloning: $masterVM -> [$subFolderKey-$suiteNum]" -ForegroundColor DarkGray
                } catch { 
                    if ($cloneName -eq "tmpl-sdc-$suiteNum"){Write-Host "  -> Cloning: $cloneName  -> [Skipped]" -ForegroundColor DarkGray }
                    else {Write-Host "  -> Cloning: $cloneName  -> [Failed]" -ForegroundColor red }
                }
                
                $cloneTasks += $task
            }


        }
        $validTasks = $cloneTasks | Where-Object { $_ -ne $null}

        if ($validTasks.Count -gt 0) {
            Write-Host "  -> Waiting for vCenter to build clones..." -ForegroundColor Yellow
            $validTasks | Wait-Task -ErrorAction SilentlyContinue | Out-Null
            Write-Host "  -> INFO: Clones built, waiting for vCenter to finish processing the VMs..." -ForegroundColor DarkGray
        }

        $allSuiteVMs = Get-VM -Location $parentFolder -ErrorAction SilentlyContinue
        if ($allSuiteVMs.Count -gt 0) {
            Write-host "  -> Assigning networks to $pgName..." -ForegroundColor Yellow
            foreach ($vm in $allsuiteVMs) {
                try {
                    $vm | Get-NetworkAdapter -ErrorAction Stop | Set-NetworkAdapter -Portgroup $targetPG -ErrorAction Stop -Confirm:$false | Out-Null 
                } catch {}
            }

            $oldRule = Get-DrsRule -Cluster $cluster -Name $ruleName -ErrorAction SilentlyContinue
            if ($oldRule) { Remove-DrsRule -Rule $oldRule -Confirm:$false }
            New-DrsRule -Cluster $cluster -Name $ruleName -KeepTogether $true -VM $allSuiteVMs -Confirm:$false | Out-Null
            
            # ----------------------------------------------------------------------------
            # AUDIT 
            # ----------------------------------------------------------------------------
            Write-Host "  -> Verifying Deployment Integrity..." -ForegroundColor Cyan
            Start-Sleep -Seconds 10
            $auditErrors = 0
            # 1. Verify Network Adapters
            $wrongNetworks = $allSuiteVMs | Get-NetworkAdapter -ErrorAction SilentlyContinue | where-object { $_.NetworkName -ne $pgName }
            if ($wrongNetworks) {
                Write-Host "  [!] ERROR: $($wrongNetworks.Count)/$($allSuiteVMs.Count) adapters did not map to $pgName.`n  [!] Failed VM(s): $wrongNetworks" -ForegroundColor Red
                $auditErrors++
            }
            # 2. Verify DRS Rule
            $checkRule = Get-DrsRule -Cluster $cluster -Name $ruleName -ErrorAction SilentlyContinue
            if (-not $checkRule) {
                Write-Host "  [!] Warning: DRS Rule '$ruleName' was not created successfully." -ForegroundColor Red
                $auditErrors++
            }
            # 3. Final Output
            if ($auditErrors -eq 0) {
                Write-Host "  Success: Suite $SuiteNum Deployment Complete and Verified! ($($allSuiteVMs.Count) / 16 VMs cloned)" -ForegroundColor Green
            } else {
                Write-Host "  [!] Warning: Suite $SuiteNum Deployed, but with $auditErrors validation warning(s)." -ForegroundColor DarkYellow
            }
        }
    }
}

function Function_StaggeredBoot {
    cls
    Write-Host "--- OPERATIONAL: Execute Staggered Power-On ---" -ForegroundColor Cyan
    $suiteArray = Get-TargetSuites
    if (-not $suiteArray) { return }
    if ($suiteArray.Count -le 5){$stagDelay = 70}
    if ($suiteArray.Count -gt 5 -and $suiteArray.Count -lt 20){$stagDelay = 120}
    if ($suiteArray.Count -ge 20){$stagDelay = 180}

    if ((Read-Host "Proceed with Staggered Boot? (Y/N)") -notmatch "^[Yy]$") { return }

    $stage1Pattern = "^AD1-|^AD2-"
    $stage2Pattern = "^SQL2019-|^License-"

    foreach ($i in $suiteArray) {
        $suiteNum = "{0:D2}" -f $i
        $folderName = "Suite-$suiteNum"
        Write-Host "`nBooting $folderName..." -ForegroundColor Cyan

        $targetFolder = Get-Folder -Name $folderName -ErrorAction SilentlyContinue
        if (-not $targetFolder) { continue }

        $allVMs = Get-VM -Location $targetFolder | Where-Object { $_.PowerState -eq 'PoweredOff' }
        if ($allVMs.Count -eq 0) { Write-Host "  -> No powered-off VMs found." -ForegroundColor DarkGray; continue }

        $stage1VMs = $allVMs | Where-Object { $_.Name -match $stage1Pattern }
        if ($stage1VMs) {
            Write-Host "  -> STAGE 1: AD1/2..." -ForegroundColor Yellow
            $stage1VMs | Start-VM -RunAsync -Confirm:$false | Out-Null
            Write-Host "     Waiting $stagDelay seconds..." -ForegroundColor DarkGray; Start-Sleep -Seconds $stagDelay
        }

        $stage2VMs = $allVMs | Where-Object { $_.Name -match $stage2Pattern }
        if ($stage2VMs) {
            Write-Host "  -> STAGE 2: SQL and License..." -ForegroundColor Yellow
            $stage2VMs | Start-VM -RunAsync -Confirm:$false | Out-Null
            Write-Host "     Waiting $stagDelay seconds..." -ForegroundColor DarkGray; Start-Sleep -Seconds $stagDelay
        }

        $stage3VMs = $allVMs | Where-Object { $_.Name -notmatch $stage1Pattern -and $_.Name -notmatch $stage2Pattern -and $_.Name -notmatch "SDC-01V-$suiteNum"}
        if ($stage3VMs) {
            Write-Host "  -> STAGE 3: Clients & Endpoints..." -ForegroundColor Yellow
            $stage3VMs | Start-VM -RunAsync -Confirm:$false | Out-Null
        }
        
        Write-Host "$folderName Boot Sequence Complete!" -ForegroundColor Green
        Write-Host "Wait until all systems are online before continuing." -ForegroundColor Gray

        if ($suiteArray.Count -gt 1 -and $i -ne $suiteArray[-1]) {
            Write-Host "`nWaiting $suiteDelaySeconds seconds before starting the next suite..." -ForegroundColor Magenta
            Start-Sleep -Seconds $suiteDelaySeconds
        }
    }
}

function Funciton_StaggeredShutdown {Write-Host "[!] Work In Progress..."-ForegroundColor Red}

# ----------------------------------------------------------------------------
# ONE-TIME FUNCTIONS
# ----------------------------------------------------------------------------

function Function_BuildBoundaries {
    Write-Host "--- One-Time Setup: Build Logical Boundaries ---" -ForegroundColor Cyan
    if ((Read-Host "Proceed with infrastructure build? (Y/N)") -notmatch "^[Yy]$") { return }

    $datacenter = Get-Datacenter -Name $datacenterName
    $vds = Get-VDSwitch -Name $vdsName
    $vmRootFolder = $datacenter | Get-Folder -Name "vm"

    if (-not $vds) { Write-Host "Error: Switch '$vdsName' not found." -ForegroundColor Red; return }

    for ($i = 1; $i -le 32; $i++) {
        $suiteNum = "{0:D2}" -f $i
        $folderName = "Suite-$suiteNum"
        $pgName = "dPG-StudentCore-$suiteNum"
        Write-Host "`nProcessing Suite $suiteNum..." -ForegroundColor Cyan

        $existingFolder = Get-Folder -Name $folderName -Location $vmRootFolder -ErrorAction SilentlyContinue
        if (-not $existingFolder) { Write-Host "  -> Creating Folder: $folderName"; New-Folder -Name $folderName -Location $vmRootFolder | Out-Null } 
        
        $existingPG = Get-VDPortgroup -Name $pgName -VDSwitch $vds -ErrorAction SilentlyContinue
        if (-not $existingPG) {
            Write-Host "  -> Creating Isolated Port Group: $pgName"
            $existingPG = New-VDPortgroup -VDSwitch $vds -Name $pgName -NumPorts 128 -VlanId 0
            
            Write-Host "     -> Setting uplinks to UNUSED..." -ForegroundColor Yellow
            $teaming = Get-VDUplinkTeamingPolicy -VDPortgroup $existingPG
            $allUplinks = Get-VDUplink -VDPortgroup $existingPG
            Set-VDUplinkTeamingPolicy -VDUplinkTeamingPolicy $teaming -UnusedUplink $allUplinks | Out-Null
            
            Write-Host "     -> Hardening Security Policies..." -ForegroundColor Yellow
            Get-VDSecurityPolicy -VDPortgroup $existingPG | Set-VDSecurityPolicy -AllowPromiscuous $false -MacChanges $false -ForgedTransmits $false | Out-Null
        }
    }
    Write-Host "`nInfrastructure Build Complete!" -ForegroundColor Green
}

function Function_AssignFolderPermissions {
    Write-Host "--- One-Time Setup: Assignment of RBAC Permissions ---" -ForegroundColor Cyan
    Write-Host "Domain: $adDomain" -ForegroundColor DarkGray
    Write-Host "Group Scope: 'LEARN\Student Users' (Read-Only & Deployment)" -ForegroundColor DarkGray
    Write-Host "User Scope: Stu## (Folder Administrator & Network Assignment)" -ForegroundColor DarkGray

    if ((Read-Host "`nProceed with applying AD permissions? (Y/N)") -notmatch "^[Yy]$") { return }

    $adDomain = "learn"
    $groupPrincipal = "$adDomain\Student Users"
    $Datacenter = Get-Datacenter -name $datacenterName
    $cluster = Get-Cluster $clusterName
    $datastore = Get-Datastore -Name $targetDatastore

    # ----------------------------------------------------------------------------
    # Phase I : Group Permissions
    # ----------------------------------------------------------------------------
        Write-Host "`n[Phase I] Applying Global Group Permissions..." -ForegroundColor Yellow

    # 1. Datacenter: Read-Only (propagated)
        try {
            New-VIPermission -Entity $Datacenter -Principal $groupPrincipal -Role "ReadOnly" -Propagate $true -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Host "  -> Datacenter Read-Only visibility granted." -ForegroundColor Green
        } catch {write-host "  -> Datacenter permission failed or exists." -ForegroundColor DarkGray}

    # 2. Cluster: Student-Deployer (Non-Propagated)
        try {
        New-VIPermission -Entity $cluster -Principal $groupPrincipal -Role "Student-Deployer" -Propagate $false -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Host "  -> Cluster deployment rights granted." -ForegroundColor Green
        } catch {write-host "  -> Cluster permission failed or exists. (Ensure 'Student-Deployer' custom role exists)" -ForegroundColor DarkGray}

    # 3. Datastore: Virtual Machine Power User (Non-Propagated)
        try {
        New-VIPermission -Entity $datastore -Principal $groupPrincipal -Role "VirtualMachinePowerUser" -Propagate $false -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Host "  -> Datastore allocation rights granted." -ForegroundColor Green
        } catch {write-host "  -> Datastore permissions failed or exists." -ForegroundColor DarkGray}
    
    # 4. Explicit Denial: Locks down students to only seeing their suites.
        Write-Host "  -> Applying NoAccess Group Overrides to Suites..." -ForegroundColor Yellow
        $vds = Get-VDSwitch -Name $vdsName
        
        for ($i = 1; $i -le 34; $i++) {
            $suiteNum = "{0:D2}" -f $i
            $folderName = "Suite-$suiteNum"
            $pgName = "dPG-StudentCore-$suiteNum"
        
            # 4a. Deny Group on all Folders
            $folder = Get-Folder -Name $folderName -Type VM -ErrorAction SilentlyContinue
            if ($folder) {
                try {
                New-VIPermission -Entity $folder -Principal $groupPrincipal -Role "NoAccess" -Propagate $true -Confirm:$false -ErrorAction Stop | Out-Null
                 } catch {}
            }
            # 4b. Deny Group on dPG
            $pg = Get-VDPortgroup -name $pgName -VDSwitch $vds -ErrorAction SilentlyContinue
            if ($pg) {
                try {
                    New-VIPermission -Entity $pg -Principal $groupPrincipal -Role "NoAccess" -Propagate $false -Confirm:$false -ErrorAction Stop | Out-Null
                } catch {}
            }
        }
        Write-Host "  ->  Group No Access overrides applied." -ForegroundColor Green

    # ----------------------------------------------------------------------------
    # Phase II : Individual Student Permissions
    # ----------------------------------------------------------------------------

    Write-Host "`n[Phase II] Applying Individual Suite Permissions..." -ForegroundColor Yellow
    $vds = Get-VDSwitch -Name $vdsName

    
    for ($i = 1; $i -le 34; $i++) {
        $suiteNum = "{0:D2}" -f $i
        $folderName = "Suite-$suiteNum"
        $pgName = "dPG-StudentCore-$suiteNum"
        $userName = "Stu$suiteNum"
        $userPrincipal = "LEARN\$userName"

        Write-Host "Configuring access for $userPrincipal -> $folderName" -ForegroundColor Cyan

        # 1. VM Folder
        $folder = Get-Folder -Name $folderName -Type VM -ErrorAction SilentlyContinue
        if ($folder) {
            $existingPerm = Get-VIPermission -Entity $folder -Principal $userPrincipal -ErrorAction SilentlyContinue

            if (-not $existingPerm) {
                try {
                    New-VIPermission -Entity $folder -Principal $userPrincipal -Role 'Admin' -Propagate $true -Confirm:$false -ErrorAction Stop | Out-Null
                    Write-Host "  -> Folder Admin: Success!" -ForegroundColor Green
                } catch { Write-Host "  -> Folder Admin: Failed." -ForegroundColor Red }
            }
        }

        # 2. Port Group assignment
        $pg = Get-VDPortgroup -Name $pgName -VDSwitch $vds -ErrorAction SilentlyContinue
        if ($pg) {
            $existingPGPerm = Get-VIPermission -Entity $pg -Principal $userPrincipal -ErrorAction SilentlyContinue
            if (-not $existingPGPerm) {
                try {
                    New-VIPermission -Entity $pg -Principal $userPrincipal -Role "Student-Network-Adapter" -Propagate $false -Confirm:$false -ErrorAction Stop | Out-Null
                    Write-Host "  -> Network Access: Success!" -ForegroundColor Green
                } catch { Write-Host "  -> Network Access: Failed." -ForegroundColor Red }
            }
        }
    }
    Write-Host "`nRole-Based-Access-Control Assignment Complete!" -ForegroundColor Green
}

# ----------------------------------------------------------------------------
# DEBUG FUNCTIONS
# ----------------------------------------------------------------------------
    
function Function_AuditIsolation {
        Write-Host "--- COMPLIANCE CHECK: Audit Suite Isolation and Boundaries ---" -ForegroundColor Cyan
        $suiteArray = Get-TargetSuites
        if (-not $suiteArray) {return}
        $cluster = Get-Cluster -Name $clusterName
        $failedSuites = @() #tracks failed suites that require remediation

        foreach ($i in $suiteArray) {
        $suiteNum   = "{0:D2}" -f $i
        $folderName = "Suite-$suiteNum"
        $pgName     = "dPG-StudentCore-$suiteNum"
        $ruleName   = "Affinity-Suite-$suiteNum"
        Write-Host "`nAuditing $folderName..." -ForegroundColor Cyan

        $targetFolder = Get-Folder -Name $folderName -ErrorAction SilentlyContinue
        if (-not $targetFolder) {Write-Host "   [FAIL] Folder missing." -ForegroundColor Red; continue}

        $allVMs = Get-VM -Location $targetFolder -ErrorAction SilentlyContinue
        if ($allVMs.Count -eq 0) {Write-Host "   [PASS] Empty Suite." -ForegroundColor DarkGray; continue}

        $auditFailed = $false

        #Check 1: Network Isolation
        $wrongNetVMs = $allVMs | Get-NetworkAdapter -ErrorAction SilentlyContinue | Where-Object { $_.NetworkName -ne $pgName -and $_.NetworkName -ne "Network adapter 1"}
        if ($wrongNetVMs){
        $uniqueBadVMs = $wrongNetVMs | Select-Object -ExpandProperty Parent -Unique
            Write-Host "   [FAIL] $($uniqueBadVMs.Count) VM(s) found on wrong network" -ForegroundColor Red
            foreach ($vm in $uniqueBadVMs){
                Write-Host "          - $($vm.Name)" -ForegroundColor Red
            }
            $auditFailed = $true
        }
        #Check 2: DRS Rule Membership
        $drsRule = Get-DrsRule -Cluster $cluster -Name $ruleName -ErrorAction SilentlyContinue
        if ($drsRule){
            $missingFromDRS = $allVMs | Where-Object { $_.Id -notin $drsRule.VMIds}
            if ($missingFromDRS){
                Write-Host "   [FAIL] VMs missing from DRS Rule '$ruleName': $($missingFromDRS.Name)" -ForegroundColor Red
                $auditFailed = $true
            }
        } else {Write-Host "   [FAIL] DRS Rule '$ruleName' does not exist" -ForegroundColor Red; $auditFailed = $true}
        #Check 3: VM/ESXi Placement
        $poweredOnVMs = $allVMs | Where-Object { $_.PowerState -eq 'PoweredOn'}
        if ($poweredOnVMs.Count -gt 0){
            $hostCount = ($poweredOnVMs | Select-Object -ExpandProperty VMHost -Unique).Count
            if ($hostCount -gt 1){
                Write-Host "   [FAIL] Powered-On VMs are spanning $hostCount different physical hosts." -ForegroundColor Red
                $auditFailed = $true
            }
        }
        if (-not $auditFailed) {
            Write-Host "   [PASS] Suite Isolation is 100% Compliant!" -ForegroundColor Green
        } else { $failedSuites += $i}
    }
    #
    # Remediation
    #
    if ($failedSuites.Count -gt 0) {
        Write-Host "`nAudit Complete. $($failedSuites.Count) suite(s) require remediation." -ForegroundColor Yellow
        $remConfirm = Read-Host "Would you like to automatically remediate these suites now? (Y/N)"

        if ($remConfirm -match "^[Yy]$") {
            Write-Host "`nInitiating Auto-Remediation..." -ForegroundColor Cyan

            $cluster = Get-Cluster -Name $clusterName
            foreach ($i in $suiteArray) {
                $suiteNum = "{0:D2}" -f $i
                $parentFolderName = "Suite-$suiteNum"
                $pgName = "dPG-StudentCore-$suiteNum"
                $ruleName = "Affinity-Suite-$suiteNum"

                $parentFolder = Get-Folder -Name $parentFolderName -ErrorAction SilentlyContinue
                $targetPG = Get-VDPortgroup -Name $pgName -ErrorAction SilentlyContinue
                if (-not $parentFolder -or -not $targetPG) { Write-Host "Error: Root Folder or PortGroup missing." -ForegroundColor Red; continue }
                foreach ($subFolderKey in $globalVmMapping.Keys) {$subFolder = Get-Folder -Name "$subFolderKey-$suiteNum" -Location $parentFolder -ErrorAction SilentlyContinue}
                $allSuiteVMs = Get-VM -Location $parentFolder -ErrorAction SilentlyContinue

                if ($allSuiteVMs.Count -gt 0) {
                    Write-host "  -> Assigning networks to $pgName..." -ForegroundColor Yellow
                    foreach ($vm in $allsuiteVMs) {
                        try {
                            $vm | Get-NetworkAdapter -ErrorAction Stop | Set-NetworkAdapter -Portgroup $targetPG -ErrorAction Stop -Confirm:$false | Out-Null 
                        } catch {}
                    }
                    $oldRule = Get-DrsRule -Cluster $cluster -Name $ruleName -ErrorAction SilentlyContinue
                    if ($oldRule) { Remove-DrsRule -Rule $oldRule -Confirm:$false }
                    New-DrsRule -Cluster $cluster -Name $ruleName -KeepTogether $true -VM $allSuiteVMs -Confirm:$false | Out-Null
                }
            }
        } else {
            Write-Host "Remediation Skipped by User." -ForegroundColor DarkGray
        }
    } else{
        Write-Host "`nAudit Complete. Zero compliance issues found." -ForegroundColor Green
    }
}

# ----------------------------------------------------------------------------
# INSTRUCTOR FUNCTIONS
# ----------------------------------------------------------------------------

function Function_ResetNetAppClones {
    cls
    Write-Host "--- INSTRUCTOR TASK: Reset NetApp VMs ---" -ForegroundColor Cyan
    Write-Host "Snapshot Target: 'PE_ready_netapp'" -ForegroundColor Yellow
    
    $suiteArray = Get-TargetSuites
    if (-not $suiteArray) { return }

    if ((Read-Host "Proceed with NetApp reset for selected suites? (Y/N)") -notmatch "^[Yy]$") { return }

    $cluster = Get-Cluster -Name $clusterName
    $netappMasterNames = @("NETAPP-01-00", "NETAPP-02-00")
    $targetSnapName = "PE_ready_netapp"

    foreach ($i in $suiteArray) {
        $suiteNum = "{0:D2}" -f $i
        $parentFolderName = "Suite-$suiteNum"
        $pgName = "dPG-StudentCore-$suiteNum"
        $ruleName = "Affinity-Suite-$suiteNum"
        
        Write-Host "`nResetting NetApp VMs in $parentFolderName..." -ForegroundColor Cyan

        $parentFolder = Get-Folder -Name $parentFolderName -ErrorAction SilentlyContinue
        $networkFolder = Get-Folder -Name "Network-$suiteNum" -Location $parentFolder -ErrorAction SilentlyContinue
        $targetPG = Get-VDPortgroup -Name $pgName -ErrorAction SilentlyContinue

        if (-not $parentFolder -or -not $networkFolder) {
            Write-Host "  -> Error: Suite or Network folder missing. Skipping." -ForegroundColor Red
            continue
        }
        # Delete Old FVNETAPP VMs
        foreach ($masterName in $netappMasterNames) {
            $cloneName = $masterName -replace "-00$", "-$suiteNum"
            $oldVM = Get-VM -Name $cloneName -Location $networkFolder -ErrorAction SilentlyContinue
            if ($oldVM) {
                Write-Host "  -> Deleting old $cloneName..." -ForegroundColor DarkGray
                if ($oldVM.PowerState -eq 'PoweredOn') { $oldVM | Stop-VM -Confirm:$false | Out-Null }
                Remove-VM -VM $oldVM -DeletePermanently -Confirm:$false | Out-Null
            }
        }
        $cloneTasks = @()
        # Deploy New VMs
        foreach ($masterName in $netappMasterNames) {
            $cloneName = $masterName -replace "-00$", "-$suiteNum"
            $masterVM = Get-VM -Name $masterName -ErrorAction SilentlyContinue
            $snap = Get-Snapshot -VM $masterVM -Name $targetSnapName -ErrorAction SilentlyContinue

            if (-not $masterVM -or -not $snap) {
                Write-Host "  -> ERROR: Missing Master ($masterName) or Snapshot ($targetSnapName)!" -ForegroundColor Red
                continue
            }

            Write-Host "  -> Deploying new $cloneName..." -ForegroundColor Yellow
            $task = New-VM -Name $cloneName -VM $masterVM -ReferenceSnapshot $snap -ResourcePool $cluster -Datastore $targetDatastore -Location $networkFolder -LinkedClone -RunAsync -Confirm:$false
            $cloneTasks += $task
        }

        if ($cloneTasks.Count -gt 0) {
            Write-Host "  -> Waiting for deployment to finish..." -ForegroundColor Yellow
            Wait-Task -Task $cloneTasks -ErrorAction SilentlyContinue | Out-Null
        }
        # Re-plug networks and update DRS Affinity Rule
        $allSuiteVMs = Get-VM -Location $parentFolder -ErrorAction SilentlyContinue
        if ($allSuiteVMs.Count -gt 0) {
            Write-Host "  -> Securing networks and updating DRS rule..." -ForegroundColor Yellow
            foreach ($masterName in $netappMasterNames) {
                $cloneName = $masterName -replace "-00$", "-$suiteNum"
                $newVM = Get-VM -Name $cloneName -Location $networkFolder -ErrorAction SilentlyContinue
                if ($newVM) { $newVM | Get-NetworkAdapter -ErrorAction SilentlyContinue | Set-NetworkAdapter -Portgroup $targetPG -Confirm:$false | Out-Null }
            }
            $oldRule = Get-DrsRule -Cluster $cluster -Name $ruleName -ErrorAction SilentlyContinue
            if ($oldRule) { Remove-DrsRule -Rule $oldRule -Confirm:$false }
            New-DrsRule -Cluster $cluster -Name $ruleName -KeepTogether $true -VM $allSuiteVMs -Confirm:$false | Out-Null
        }
        Write-Host "  -> $parentFolderName NetApp reset complete." -ForegroundColor Green
    }
}

function Function_AddSDC02vTodPG {
    cls
    Write-Host "--- INSTRUCTOR TASK: Integrate Student-Created SDC ---" -ForegroundColor Cyan
    Write-Host "   Targeting: Student-created VMs Named 'SDC-02V-##'" -ForegroundColor Yellow
    $suiteArray = Get-TargetSuites
    if (-not $suiteArray) { return }

    if ((Read-Host "Proceed with securing the student-created VMs? (Y/N)") -notmatch "^[Yy]$") {return}

    $cluster = Get-Cluster -Name $clusterName

    foreach ($i in $suiteArray) {
        $suiteNum = "{0:D2}" -f $i
        $parentFolderName = "Suite-$suiteNum"
        $pgName = "dPG-StudentCore-$suiteNum"
        $ruleName = "Affinity-Suite-$suiteNum"
        $targetVMName = "SDC-02v-$suiteNum"

        Write-Host "`nScanning $parentFolderName..." -ForegroundColor Cyan
        $parentFolder = Get-Folder -Name $parentFolderName -ErrorAction SilentlyContinue
        $targetPG = Get-VDPortgroup -Name $pgName -ErrorAction SilentlyContinue
        if (-not $parentFolder -or -not $targetPG) {
            Write-Host "     -> Error: Suite Folder or PortGroup missing. Skipping" -ForegroundColor Red
            continue
        }
        #1. Locate student created vm
        $studentVM = Get-VM -Name $targetVMName -Location $parentFolder -ErrorAction SilentlyContinue
        if (-not $studentVM) {
            Write-Host "     -> No VM named '$targetVMName' found in $parentFolderName. Skipping." -ForegroundColor DarkGray
            continue
        }
        Write-Host "     -> Found '$targetVMName'. Applying Air-Gap security..." -ForegroundColor Yellow
        #2. re-plug network to isolated PG
        try {
            $studentVM | Get-NetworkAdapter -ErrorAction Stop | Set-NetworkAdapter -Portgroup $targetPG -confirm:$false -ErrorAction Stop | Out-Null
            Write-Host "     - Network secured to $pgName" -ForegroundColor Green
        } catch {Write-Host "     - Warning: Could not modify network adapter. Ensure VM is powered off or tools are installed." -ForegroundColor Yellow}
        #3. Rebuild DRS affinity Rule
        $allSuiteVMs = Get-VM -Location $parentFolder -ErrorAction SilentlyContinue

        if ($allSuiteVMs.count -gt 0) {
            $oldRule = Get-DrsRule -Cluster $cluster -Name $ruleName -ErrorAction SilentlyContinue
            if ($oldRule) { Remove-DrsRule -Rule $oldRule -Confirm:$false -ErrorAction SilentlyContinue | Out-Null}

            New-DrsRule -Cluster $cluster -Name $ruleName -KeepTogether $true -VM $allSuiteVMs -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        }
    }
    Write-host "`nStandardization Complete" -ForegroundColor Cyan
}

function Function_GetNewVersion{
    cls
    Write-Host "--- INSTRUCTOR TASK: Update sys_menu on all ADMWS ---" -ForegroundColor Cyan
    Write-Host "Targeting: ADMWS24 through ADMWS32" -ForegroundColor Yellow
    
    $sourceFile = "\\Repository\c$\.scripts\sys_menu.ps1"

    $destinationDir = "C$\.scripts"

    if (( Read-Host "`nProceed with pushing the updated menu to Admin Clients (Y/N)") -notmatch "^[Yy$]") {return}
    
    #1. Verify source file exists
    if (-not (Test-Path -Path $sourceFile)) {
        Write-Host "`n[!]Error: Source file not found at $sourceFile" -ForegroundColor Red
        return
    }

    Write-Host "`nInitiating Network File Push..." -ForegroundColor Green
    #2. Loop admws 24-32
    for ($i = 24; $i -le 32; $i++) {
        $targetWS = "admws$i"
        $targetPath = "\\$targetWS\$destinationDir\sys_menu.ps1"

        Write-Host "Updating $targetWS..." -NoNewline

        if (Test-Connection -ComputerName $targetWS -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            try {
                #ensure destination folder exists on target machine
                $destFolderObj = "\\$targetWS\$destinationDir"
                if (-not (Test-Path -Path $destFolderObj)) {
                    New-Item -ItemType Directory -Path $destFolderObj -Force -ErrorAction Stop | Out-Null
                }

                #Copy and Overwrite
                Copy-Item -Path $sourceFile -Destination $targetPath -Force -ErrorAction Stop
                unblock-file -Path $targetPath -ErrorAction SilentlyContinue
                Write-Host "Success" -ForegroundColor Green
            } catch {
                Write-Host "[!] ERROR: Failed (Access Denied or Path Error)" -ForegroundColor Red
            }
        } else {
            Write-Host "[!] ERROR: Failed (Workstation Offline/Unreachable)" -ForegroundColor DarkGray
        }
    }
    Write-Host "`nClient Menu Update Complete." -ForegroundColor Cyan
    exit
}

function Function_Take_StudentSnap {Write-Host "[!] Work In Progress..."-ForegroundColor Red}

function Function_PushFiletoVM {
    cls
    Write-Host "--- INSTRUCTOR TASK: Push File to Student VMs ---" -ForegroundColor Cyan
    $suiteArray = Get-TargetSuites
    if (-not $suiteArray) {return}

    $localDir = "c:\.scripts\transfer"
    $fileName = Read-Host "Enter the EXECT file name to push from $localDir (e.g., Reset_PW.txt)"
    $sourcePath = Join-Path -Path $localDir -ChildPath $fileName

    if (-not (Test-Path $sourcePath)) {
        Write-Host "[!] Error: File Not found at $sourcePath" -ForegroundColor Red
        Start-Sleep 2; return
    }
    Write-Host "Provide Guest OS credentials to access the VMs" -ForegroundColor Yellow
    $creds = Get-Credential
    $vms = Read-Host "What VM are you copying to? Type Exact (e.g. 'AD1')"
    cls
    write-host "`n`n`n`n`n`n "
    foreach ($i in $suiteArray) {
        $suiteNum = "{0:D2}" -f $i
        $targetVMName = "$vms-$suiteNum"
        $vm = Get-VM -Name $targetVMName -ErrorAction SilentlyContinue
        if ($vm -and $vm.PowerState -eq 'PoweredOn') {
            Write-Host "[INFO]`nItem: '$sourcePath'`nDestination:'$targetVMName'" -ForegroundColor DarkGray
            Write-Host "   -> Processing $targetVMName..." -ForegroundColor Cyan
            try {
                # step 1: check for c:\temp
                    Invoke-VMScript -VM $vm -GuestCredential $creds -ScriptText 'if (!(Test-Path "C:\temp")) { New-Item -ItemType Directory -Force -Path "C:\temp" }' -ErrorAction stop -WarningAction SilentlyContinue| Out-Null
                # step 2: push file
                    Write-Host "   -> Copying file..."-ForegroundColor DarkGray -NoNewline
                    Copy-VMGuestFile -Source $sourcePath -Destination "C:\temp\" -VM $vm -GuestCredential $creds -LocalToGuest -ErrorAction stop -WarningAction SilentlyContinue| Out-Null
                    Write-Host "   [Success]" -ForegroundColor Green
            } catch { Write-Host "[!] Error: ($($_.Exception.Message))" -ForegroundColor Red}
        } else {
            Write-Host "   -> $targetVMName is missing or powered off." -ForegroundColor DarkGray
        }
    }
}

function Function_PullFileFromVM {Write-Host "[!] Work In Progress..."-ForegroundColor Red}

function Function_BroadcastMessage {
    cls
    Write-Host "--- INSTRUCTOR TASK: Send Message to Student Workstation ---" -ForegroundColor Cyan
    Write-Host "Targeting: Physical Client in Classroom (STUWS01-STUWS23" -ForegroundColor Yellow

    $suiteArray = Get-TargetSuites
    if (-not $suiteArray) {return}
    $message = Read-Host "`nEnter the message to send to the students"
    if ([string]::IsNullOrWhiteSpace($message)) {return}
    Write-Host "`nBroadcasting Message..." -ForegroundColor Yellow

    foreach ($i in $suiteArray) {
        $suiteNum = "{0:D2}" -f $i
        $targetClient = "STUWS$suiteNum"

        Write-Host "   -> Sending to $targetClient..." -NoNewline
        if (Test-Connection -ComputerName $targetClient -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            try {
                Invoke-Command -ComputerName $targetClient -ScriptBlock { msg console /w $using:message} -ErrorAction Stop
                Write-Host "   Student has Acknowledged the message." -ForegroundColor Green
            } catch {write-host "   [!] Error: WinRM or Permission Error"}
        } else {write-host "   [!] Error: Workstation offline or unreachable"}
    }
}

# ----------------------------------------------------------------------------
# MAIN EXECUTION LOOP
# ----------------------------------------------------------------------------

Write-Host "Connecting to vCenter ($vCenterServer)..." -ForegroundColor Cyan
Connect-VIServer -Server $vCenterServer
Set-PowerCLIConfiguration -WebOperationTimeoutSeconds -1 -InvalidCertificateAction Ignore -Confirm:$false

$menuActive = $true
while ($menuActive) {
    Show-MainMenu
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        '1' { 
            cls
            Function_TakeSnapshot
            Pause 
        }
        '2' { 
            cls
            Function_RemoveClones
            Pause 
        }
        '3' { 
            cls
            Function_DeployClones
            Pause 
        }
        '4' { 
            cls
            Function_StaggeredBoot
            Pause 
        }
        '5' { 
            cls
            Invoke-OneTimeMenu 
        }
        '6' { 
            cls
            Invoke-InstructorMenu 
        }
        'R'{ 
            Write-Host "Refreshing connection to vCenter ($vCenterServer)..." -ForegroundColor DarkCyan
            Disconnect-VIServer -Server $vCenterServer -confirm:$false -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Connect-VIServer -Server $vCenterServer
            Set-PowerCLIConfiguration -WebOperationTimeoutSeconds -1 -InvalidCertificateAction Ignore -Confirm:$false
        }
        'D' { 
            cls
            Invoke-DebugMenu
        }
        { @('q','Q') -contains $_ } { 
            $menuActive = $false
            Write-Host "`nExiting Script..." -ForegroundColor Cyan
            Disconnect-VIServer -Confirm:$false
        }
        default { 
            Write-Host "[!] ERROR: Invalid selection." -ForegroundColor Red
            Start-Sleep 1 
        }
    }
}