# Partage-Commun.ps1 — TP 2 partie 2, étape 10 (points 2 à 4)
# Groupe de domaine local (AGDLP), dossier, droits NTFS, partage SMB, quota FSRM 500 Mo.
# Idempotent : chaque objet n'est créé que s'il n'existe pas déjà ; relancé, il ne casse rien.
# Prérequis : volume E: (miroir Storage Spaces, créé à la main) et structure AD (New-StructureAD.ps1).
$ErrorActionPreference = 'Stop'
$chemin = 'E:\Partages\Commun'

# 1. Groupe de domaine local qui porte le droit sur la ressource
if (-not (Get-ADGroup -Filter "Name -eq 'DL_Commun_Modification'")) {
    New-ADGroup -Name DL_Commun_Modification -GroupScope DomainLocal -GroupCategory Security -Path "OU=Groupes,OU=PME,DC=pme,DC=lan"
    Write-Host "Groupe DL_Commun_Modification créé"
}
# Déjà membre : aucune erreur
Add-ADGroupMember -Identity DL_Commun_Modification -Members GG_Utilisateurs

# 2. Dossier et droits NTFS (/grant:r remplace les droits : relancer donne le même résultat)
New-Item -ItemType Directory -Path $chemin -Force | Out-Null
icacls $chemin /inheritance:r /grant:r "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" "PME\DL_Commun_Modification:(OI)(CI)M" | Out-Null

# 3. Partage SMB (nom du groupe Administrateurs retrouvé par son SID, indépendant de la langue)
if (-not (Get-SmbShare -Name Commun -ErrorAction SilentlyContinue)) {
    $admins = ([Security.Principal.SecurityIdentifier]'S-1-5-32-544').Translate([Security.Principal.NTAccount]).Value
    New-SmbShare -Name Commun -Path $chemin -FullAccess $admins -ChangeAccess "PME\DL_Commun_Modification" -FolderEnumerationMode AccessBased | Out-Null
    Write-Host "Partage Commun créé"
}

# 4. Quota FSRM : 500 Mo, événement d'avertissement à 85 %
if (-not (Get-WindowsFeature FS-Resource-Manager).Installed) {
    Install-WindowsFeature FS-Resource-Manager -IncludeManagementTools | Out-Null
}
if (-not (Get-FsrmQuota -Path $chemin -ErrorAction SilentlyContinue)) {
    $action = New-FsrmAction -Type Event -EventType Warning -Body "Le partage Commun a atteint 85 % de son quota."
    $seuil  = New-FsrmQuotaThreshold -Percentage 85 -Action $action
    New-FsrmQuota -Path $chemin -Size 500MB -Threshold $seuil -Description "Partage Commun de la PME" | Out-Null
    Write-Host "Quota FSRM créé"
}

Get-SmbShareAccess -Name Commun | Format-Table -AutoSize
Get-FsrmQuota -Path $chemin | Select-Object Path, @{n='LimiteMo';e={$_.Size/1MB}}
Write-Host "Partage Commun : OK"
