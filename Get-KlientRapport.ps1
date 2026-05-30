#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Klientrapport-script til elev-klienter (Windows 11)
.DESCRIPTION
    Kørsel: iwr -useb https://raw.githubusercontent.com/tpbillund/sde-klient-audit/main/Get-KlientRapport.ps1 | iex
    Eller lokalt: .\Get-KlientRapport.ps1
#>

# ===============================================================================
# OUTPUT-SYSTEM - skærm MED farver, fil med REN tekst
# ===============================================================================

$script:RapportBuffer = [System.Collections.Generic.List[string]]::new()

function Out-Linje {
    param(
        [string]$Tekst,
        [string]$Farve = "White",
        [switch]$IngenBuffer
    )
    Write-Host $Tekst -ForegroundColor $Farve
    if (-not $IngenBuffer) { $script:RapportBuffer.Add($Tekst) }
}

function Write-Header {
    param([string]$Titel)
    $linje = "#" * 62
    Out-Linje "" -IngenBuffer
    $script:RapportBuffer.Add("")
    Out-Linje $linje          "Cyan"
    Out-Linje "#  $Titel"     "White"
    Out-Linje $linje          "Cyan"
}

function Write-SubHeader {
    param([string]$Titel)
    Out-Linje "" -IngenBuffer
    $script:RapportBuffer.Add("")
    Out-Linje "  -- $Titel --" "Yellow"
}

function Write-Ok      { param([string]$B) Out-Linje "  [OK]  $B" "Green"    }
function Write-Advarsel{ param([string]$B) Out-Linje "  [!]   $B" "Red"      }
function Write-Springer{ param([string]$B) Out-Linje "  [-]   $B" "DarkGray" }
function Write-Info    { param([string]$B) Out-Linje "        $B" "Gray"     }
function Write-Seperator { Out-Linje "  $("-" * 56)" "DarkGray" }

function Write-Item {
    param([string]$Label, [string]$Værdi)
    Out-Linje "        $($Label.PadRight(25)) : $Værdi" "White"
}

function Write-StatusLinje {
    param([string]$Navn, [string]$Status, [bool]$Ok)
    $farve  = if ($Ok) { "Green" } else { "Red" }
    $marker = if ($Ok) { "[OK]" } else { "[!] " }
    Write-Host "        $($Navn.PadRight(35)) $Status" -ForegroundColor $farve
    $script:RapportBuffer.Add("        $($Navn.PadRight(35)) $marker $Status")
}

# ===============================================================================
# SEKTIONER
# ===============================================================================

function Get-SystemInfo {
    Write-Header "SYSTEMINFO"

    $cs   = Get-CimInstance Win32_ComputerSystem
    $os   = Get-CimInstance Win32_OperatingSystem
    $bios = Get-CimInstance Win32_BIOS
    $disk = Get-PSDrive C | Select-Object Used, Free
    $cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1

    Write-Item "Computernavn"       $cs.Name
    Write-Item "Domæne / Workgroup" $cs.Domain
    Write-Item "Bruger (logget på)" $cs.UserName
    Write-Item "OS"                 $os.Caption
    Write-Item "OS Build"           $os.BuildNumber
    Write-Item "OS Arkitektur"      $os.OSArchitecture
    Write-Item "CPU"                $cpu.Name
    Write-Item "RAM (GB)"           ([math]::Round($cs.TotalPhysicalMemory / 1GB, 1))
    Write-Item "Disk C: Brugt"      "$([math]::Round($disk.Used / 1GB, 1)) GB"
    Write-Item "Disk C: Fri"        "$([math]::Round($disk.Free / 1GB, 1)) GB"
    Write-Item "BIOS Version"       $bios.SMBIOSBIOSVersion
    Write-Item "Sidst bootet"       $os.LastBootUpTime.ToString('dd-MM-yyyy HH:mm')
}

function Get-NetværkInfo {
    Write-Header "NETVÆRK"

    $adaptere = Get-CimInstance Win32_NetworkAdapterConfiguration |
                Where-Object { $_.IPEnabled }

    foreach ($n in $adaptere) {
        Out-Linje "        $($n.Description)" "White"
        Write-Item "  IPv4 Adresse"    ($n.IPAddress -join ", ")
        Write-Item "  Subnet Mask"     ($n.IPSubnet -join ", ")
        Write-Item "  Gateway"         ($n.DefaultIPGateway -join ", ")
        Write-Item "  DNS Servere"     ($n.DNSServerSearchOrder -join ", ")
        Write-Item "  DHCP Aktiveret"  $n.DHCPEnabled
        if ($n.DHCPEnabled -and $n.DHCPServer) {
            Write-Item "  DHCP Server"    $n.DHCPServer
            Write-Item "  Lease udløber" $n.DHCPLeaseExpires
        }
        Write-Item "  MAC Adresse"     $n.MACAddress
        Write-Seperator
    }

    # Test forbindelse til gateway og DNS
    Write-SubHeader "Forbindelsestest"
    foreach ($n in $adaptere) {
        if ($n.DefaultIPGateway) {
            $gw = $n.DefaultIPGateway[0]
            $ping = Test-Connection -ComputerName $gw -Count 1 -Quiet -ErrorAction SilentlyContinue
            Write-StatusLinje -Navn "Ping til gateway ($gw)" -Status $(if ($ping) {"OK"} else {"Fejl"}) -Ok $ping
        }
        if ($n.DNSServerSearchOrder) {
            $dns = $n.DNSServerSearchOrder[0]
            $pingDns = Test-Connection -ComputerName $dns -Count 1 -Quiet -ErrorAction SilentlyContinue
            Write-StatusLinje -Navn "Ping til DNS ($dns)" -Status $(if ($pingDns) {"OK"} else {"Fejl"}) -Ok $pingDns
        }
    }

    # Test internetforbindelse
    $internet = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
    Write-StatusLinje -Navn "Internetforbindelse (8.8.8.8)" -Status $(if ($internet) {"OK"} else {"Ingen forbindelse"}) -Ok $internet
}

function Get-DomainStatus {
    Write-Header "DOMAIN-TILKNYTNING"

    $cs = Get-CimInstance Win32_ComputerSystem

    if ($cs.PartOfDomain) {
        Write-Ok "Maskinen er medlem af et domæne"
        Write-Item "Domæne"         $cs.Domain
        Write-Seperator

        # Tjek om AD-modulet er tilgængeligt
        if (Get-Module -ListAvailable -Name ActiveDirectory) {
            Import-Module ActiveDirectory -ErrorAction SilentlyContinue
            try {
                $bruger = Get-ADComputer $env:COMPUTERNAME -Properties * -ErrorAction SilentlyContinue
                if ($bruger) {
                    Write-Item "AD Computerobjekt"  $bruger.DistinguishedName
                    Write-Item "OS (AD)"             $bruger.OperatingSystem
                    Write-Item "Oprettet i AD"       $bruger.Created.ToString('dd-MM-yyyy HH:mm')
                    Write-Item "Sidst logon (AD)"    $(if ($bruger.LastLogonDate) { $bruger.LastLogonDate.ToString('dd-MM-yyyy HH:mm') } else { "Ukendt" })
                }
            } catch {
                Write-Springer "Kunne ikke hente AD-computerinfo (kræver domæneadgang)."
            }
        }

        # Aktuel indlogget bruger i AD
        Write-SubHeader "Aktuel bruger"
        try {
            $brugerNavn = $env:USERNAME
            Write-Item "Brugernavn"  $brugerNavn
            Write-Item "Domæne"      $env:USERDOMAIN

            if (Get-Module -ListAvailable -Name ActiveDirectory) {
                $adBruger = Get-ADUser $brugerNavn -Properties DisplayName, EmailAddress,
                             HomeDirectory, ProfilePath, MemberOf, LastLogonDate `
                             -ErrorAction SilentlyContinue
                if ($adBruger) {
                    if ($adBruger.DisplayName)  { Write-Item "Navn"         $adBruger.DisplayName }
                    if ($adBruger.EmailAddress) { Write-Item "Email"        $adBruger.EmailAddress }
                    if ($adBruger.HomeDirectory){ Write-Item "Home Folder"  $adBruger.HomeDirectory }
                    if ($adBruger.ProfilePath)  { Write-Item "Profile Path" $adBruger.ProfilePath }
                    if ($adBruger.LastLogonDate){
                        $dage = (New-TimeSpan -Start $adBruger.LastLogonDate -End (Get-Date)).Days
                        Write-Item "Sidst logon" "$($adBruger.LastLogonDate.ToString('dd-MM-yyyy HH:mm'))  ($dage dag(e) siden)"
                    }
                    $grupper = ($adBruger.MemberOf | ForEach-Object {
                        ($_ -split ",")[0] -replace "CN=", ""
                    }) -join ", "
                    if ($grupper) { Write-Item "AD Grupper" $grupper }
                }
            }
        } catch {
            Write-Springer "Kunne ikke hente brugerinfo fra AD."
        }

        # GPO'er anvendt på maskinen
        Write-SubHeader "Anvendte GPO'er (gpresult)"
        try {
            $gpresult = gpresult /r /scope computer 2>&1
            $gpoLinjer = $gpresult | Where-Object { $_ -match "^\s{4,6}\S" -and $_ -notmatch "ERROR|WARNING|RSOP" }
            if ($gpoLinjer) {
                foreach ($l in $gpoLinjer) { Write-Info $l.Trim() }
            } else {
                Write-Springer "Ingen GPO'er fundet via gpresult."
            }
        } catch {
            Write-Springer "Kunne ikke køre gpresult."
        }

    } else {
        Write-Springer "Maskinen er ikke medlem af et domæne - kører i Workgroup: $($cs.Domain)"
        Write-Info "         Domæne-sektionen springes over."
    }
}

function Get-DrevOgShares {
    Write-Header "DREV OG NETVÆRKSDREV"

    # Lokale drev
    Write-SubHeader "Lokale drev"
    $drev = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -notlike "\\*" }
    foreach ($d in $drev) {
        $brugt = if ($d.Used) { "$([math]::Round($d.Used / 1GB, 1)) GB brugt" } else { "-" }
        $fri   = if ($d.Free) { "$([math]::Round($d.Free / 1GB, 1)) GB fri" } else { "-" }
        Out-Linje "        [$($d.Name):] $brugt  /  $fri  - $($d.Root)" "White"
    }

    # Netværksdrev (mappede)
    Write-SubHeader "Mappede netværksdrev"
    $netDrev = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -like "\\*" }
    if ($netDrev) {
        foreach ($nd in $netDrev) {
            Out-Linje "        [$($nd.Name):] -> $($nd.Root)" "White"
        }
    } else {
        Write-Springer "Ingen mappede netværksdrev fundet."
    }

    # Printers
    Write-SubHeader "Printere"
    try {
        $printere = @(Get-Printer -ErrorAction SilentlyContinue)
        if ($printere.Count -eq 0) {
            Write-Springer "Ingen printere installeret."
        } else {
            foreach ($p in $printere) {
                $default = if ($p.Default) { " [DEFAULT]" } else { "" }
                Out-Linje "        $($p.Name)$default" "White"
                Write-Info "         Type  : $($p.DriverName)"
                Write-Info "         Port  : $($p.PortName)"
            }
        }
    } catch {
        Write-Springer "Kunne ikke hente printerinfo."
    }
}

function Get-InstalleretSoftware {
    Write-Header "INSTALLERET SOFTWARE"

    try {
        $software = @(
            Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" `
                -ErrorAction SilentlyContinue
            Get-ItemProperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
                -ErrorAction SilentlyContinue
        ) | Where-Object { $_.DisplayName } |
            Select-Object DisplayName, DisplayVersion, Publisher |
            Sort-Object DisplayName |
            Get-Unique -AsString

        Write-Ok "Installerede programmer: $($software.Count)"
        Write-Seperator
        foreach ($s in $software) {
            $navn    = $s.DisplayName.PadRight(45)
            $version = if ($s.DisplayVersion) { $s.DisplayVersion } else { "-" }
            Write-Info "$navn $version"
        }
    } catch {
        Write-Springer "Kunne ikke hente software-liste."
    }
}

function Get-TjenesterRapport {
    Write-Header "RELEVANTE WINDOWS-TJENESTER"

    $tjenester = @(
        @{ Navn = "Winmgmt";           Vis = "Windows Management (WMI)"      },
        @{ Navn = "Netlogon";          Vis = "Netlogon"                       },
        @{ Navn = "W32Time";           Vis = "Windows Time"                   },
        @{ Navn = "Dnscache";          Vis = "DNS Client"                     },
        @{ Navn = "Dhcp";              Vis = "DHCP Client"                    },
        @{ Navn = "LanmanWorkstation"; Vis = "Workstation"                    },
        @{ Navn = "LanmanServer";      Vis = "Server"                         },
        @{ Navn = "wuauserv";          Vis = "Windows Update"                 },
        @{ Navn = "mpssvc";            Vis = "Windows Firewall"               },
        @{ Navn = "RemoteRegistry";    Vis = "Remote Registry"                },
        @{ Navn = "TermService";       Vis = "Remote Desktop (RDP)"           }
    )

    Write-Seperator
    foreach ($t in $tjenester) {
        $svc = Get-Service -Name $t.Navn -ErrorAction SilentlyContinue
        if ($svc) {
            $ok = ($svc.Status -eq "Running")
            Write-StatusLinje -Navn $t.Vis -Status $svc.Status.ToString() -Ok $ok
        } else {
            Write-Host "        $($t.Vis.PadRight(35)) Ikke installeret" -ForegroundColor DarkGray
            $script:RapportBuffer.Add("        $($t.Vis.PadRight(35)) [-]  Ikke installeret")
        }
    }
}

function Get-FirewallRapport {
    Write-Header "FIREWALL STATUS"

    try {
        $profiles = @(Get-NetFirewallProfile -ErrorAction SilentlyContinue)
        foreach ($p in $profiles) {
            $ok     = [bool]$p.Enabled
            $status = if ($ok) { "AKTIV" } else { "DEAKTIVERET" }
            $marker = if ($ok) { "[OK]" } else { "[!] " }
            Write-Host "        $($p.Name.PadRight(15)) $status" -ForegroundColor $(if ($ok) {"Green"} else {"Red"})
            $script:RapportBuffer.Add("        $($p.Name.PadRight(15)) $marker $status")
        }
    } catch {
        Write-Springer "Kunne ikke hente firewall-info."
    }
}

function Get-WindowsUpdate {
    Write-Header "WINDOWS UPDATE STATUS"

    try {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $pendingUpdates = $updateSearcher.Search("IsInstalled=0 and Type='Software'")

        if ($pendingUpdates.Updates.Count -eq 0) {
            Write-Ok "Systemet er opdateret - ingen afventende opdateringer."
        } else {
            Write-Advarsel "Afventende opdateringer: $($pendingUpdates.Updates.Count)"
            Write-Seperator
            foreach ($u in $pendingUpdates.Updates | Select-Object -First 10) {
                Write-Info $u.Title
            }
            if ($pendingUpdates.Updates.Count -gt 10) {
                Write-Info "... og $($pendingUpdates.Updates.Count - 10) flere."
            }
        }
    } catch {
        Write-Springer "Kunne ikke hente Windows Update-status."
    }

    # Seneste installerede opdateringer
    Write-SubHeader "Seneste installerede opdateringer (top 5)"
    try {
        $hotfixes = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5
        foreach ($h in $hotfixes) {
            $dato = if ($h.InstalledOn) { $h.InstalledOn.ToString('dd-MM-yyyy') } else { "Ukendt" }
            Write-Info "$($h.HotFixID.PadRight(15)) $dato  -  $($h.Description)"
        }
    } catch {
        Write-Springer "Kunne ikke hente hotfix-historik."
    }
}

function Get-LokaleKonti {
    Write-Header "LOKALE KONTI"

    try {
        $lokBrugere = @(Get-LocalUser -ErrorAction SilentlyContinue | Sort-Object Name)
        Write-Ok "Lokale brugere: $($lokBrugere.Count)"
        Write-Seperator
        foreach ($lu in $lokBrugere) {
            $statusTekst = if ($lu.Enabled) { "[AKTIV]  " } else { "[DEAKTIV]" }
            $statusFarve = if ($lu.Enabled) { "White" } else { "DarkGray" }
            $sidstLogon  = if ($lu.LastLogon) { $lu.LastLogon.ToString('dd-MM-yyyy HH:mm') } else { "Aldrig" }
            Out-Linje "        $statusTekst $($lu.Name.PadRight(25)) Sidst logon: $sidstLogon" $statusFarve
        }
    } catch {
        Write-Springer "Kunne ikke hente lokale brugere."
    }

    try {
        Write-SubHeader "Lokale Grupper"
        $lokGrupper = @(Get-LocalGroup -ErrorAction SilentlyContinue | Sort-Object Name)
        foreach ($lg in $lokGrupper) {
            $members = try {
                (Get-LocalGroupMember $lg.Name -ErrorAction SilentlyContinue |
                 Select-Object -ExpandProperty Name) -join ", "
            } catch { "-" }
            Write-Info "$($lg.Name.PadRight(30)) <- $members"
        }
    } catch {
        Write-Springer "Kunne ikke hente lokale grupper."
    }
}

# --- Filnavn ------------------------------------------------------------------

function Gem-Rapport {
    $filnavn = "$($env:COMPUTERNAME)_KlientRapport.txt"
    $sti     = "$env:USERPROFILE\Desktop\$filnavn"
    try {
        $script:RapportBuffer | Out-File -FilePath $sti -Encoding utf8BOM
        Write-Host ""
        Write-Host "  Rapport gemt: $sti" -ForegroundColor Green
        $script:RapportBuffer.Add("Rapport gemt: $sti")
    } catch {
        Write-Advarsel "Kunne ikke gemme rapport: $_"
    }
}

# ===============================================================================
# HOVED
# ===============================================================================

Clear-Host

$velkomst = @(
    "",
    "  ##################################################",
    "  #                                                #",
    "  #       KLIENT-RAPPORT  -  ELEV MASKINE          #",
    "  #     Syddansk Erhvervsskole Vejle               #",
    "  #              IT & Data                         #",
    "  #                                                #",
    "  ##################################################",
    "",
    "  Dato    : $(Get-Date -Format 'dd-MM-yyyy HH:mm')",
    "  Maskine : $env:COMPUTERNAME",
    "  Bruger  : $env:USERNAME",
    ""
)
foreach ($l in $velkomst) {
    Write-Host $l -ForegroundColor Cyan
    $script:RapportBuffer.Add($l)
}

Get-SystemInfo
Get-NetværkInfo
Get-DomainStatus
Get-DrevOgShares
Get-InstalleretSoftware
Get-TjenesterRapport
Get-FirewallRapport
Get-WindowsUpdate
Get-LokaleKonti

$slut = @(
    "",
    "  ##################################################",
    "  #           RAPPORT AFSLUTTET                   #",
    "  ##################################################",
    ""
)
foreach ($l in $slut) {
    Write-Host $l -ForegroundColor Cyan
    $script:RapportBuffer.Add($l)
}

$gem = Read-Host "  Vil du gemme rapporten som .txt fil på skrivebordet? (J/N)"
if ($gem -match "^[JjYy]") {
    Gem-Rapport
}
