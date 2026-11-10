# GPO-MAJ-Windows.ps1 — TP 3 partie 1, étape 3
# GPO d'installation planifiée des mises à jour Windows : option 4, dimanche à 3h,
# liée à l'OU Domain Controllers (seul serveur Windows du lab).
# Idempotent : la GPO et son lien ne sont créés que s'ils n'existent pas ; Set-GPRegistryValue écrase la valeur.
# Nom renommé le 10/11 (anciennement GPO_MAJ_Windows) : voir ETAT.md.
$ErrorActionPreference = 'Stop'
$nom = 'GPO_MAJ_WindowsUpdate'
$ou  = (Get-ADDomain).DomainControllersContainer

if (-not (Get-GPO -Name $nom -ErrorAction SilentlyContinue)) {
    New-GPO -Name $nom -Comment "Installation planifiée des mises à jour : dimanche 3h" | Out-Null
    Write-Host "GPO $nom créée"
}
if (-not ((Get-GPInheritance -Target $ou).GpoLinks | Where-Object DisplayName -eq $nom)) {
    New-GPLink -Name $nom -Target $ou | Out-Null
    Write-Host "GPO $nom liée à $ou"
}

$cle = 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU'
Set-GPRegistryValue -Name $nom -Key $cle -ValueName NoAutoUpdate         -Type DWord -Value 0 | Out-Null  # mises à jour actives
Set-GPRegistryValue -Name $nom -Key $cle -ValueName AUOptions            -Type DWord -Value 4 | Out-Null  # téléchargement et installation planifiée
Set-GPRegistryValue -Name $nom -Key $cle -ValueName ScheduledInstallDay  -Type DWord -Value 1 | Out-Null  # 1 = dimanche
Set-GPRegistryValue -Name $nom -Key $cle -ValueName ScheduledInstallTime -Type DWord -Value 3 | Out-Null  # 3h

gpupdate /force | Out-Null
(Get-GPInheritance -Target $ou).GpoLinks | Select-Object DisplayName, Enabled | Format-Table -AutoSize
Write-Host "$nom : OK"
