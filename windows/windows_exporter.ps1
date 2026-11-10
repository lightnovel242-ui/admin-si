# windows_exporter.ps1 — TP 3 partie 2, étape 1.2
# Installe windows_exporter (port 9182), démarrage automatique, pare-feu ouvert à SRV-ADM01 seulement.
# Idempotent : installation et règle créées seulement si absentes ; relancé, il ne casse rien.
$ErrorActionPreference = 'Stop'
if (-not (Get-Service windows_exporter -ErrorAction SilentlyContinue)) {
    $msi = "$env:TEMP\windows_exporter.msi"
    if (-not (Test-Path $msi)) {
        # Sans accès GitHub depuis la VM : télécharger le .msi sur le PC et le copier dans $env:TEMP
        $r   = Invoke-RestMethod https://api.github.com/repos/prometheus-community/windows_exporter/releases/latest
        $url = ($r.assets | Where-Object name -like '*amd64.msi').browser_download_url
        Invoke-WebRequest $url -OutFile $msi
    }
    # On refuse la règle de pare-feu ouverte à tous proposée par l'installateur
    Start-Process msiexec -Wait -ArgumentList "/i", $msi, "ADD_FIREWALL_EXCEPTION=no", "/qn"
}
Set-Service windows_exporter -StartupType Automatic
Start-Service windows_exporter
if (-not (Get-NetFirewallRule -DisplayName "windows_exporter depuis SRV-ADM01" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "windows_exporter depuis SRV-ADM01" -Direction Inbound -Protocol TCP -LocalPort 9182 -RemoteAddress 10.10.0.30 -Action Allow | Out-Null
}
Write-Host "windows_exporter : $((Get-Service windows_exporter).Status)"
