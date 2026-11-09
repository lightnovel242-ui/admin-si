<#
.SYNOPSIS
    Crée la structure AD du lab pme.lan : OU, groupes, utilisateurs et appartenances.

.DESCRIPTION
    Script idempotent : il peut être relancé autant de fois que nécessaire.
    Ce qui existe déjà est signalé [EXISTE] et laissé tel quel ; seul ce qui
    manque est créé [CREE]. Les appartenances aux groupes sont complétées.

    Structure créée :
        OU=PME
          OU=Utilisateurs   a.martin (Alice Martin), b.durand (Bob Durand)
          OU=Groupes        GG_Admins_Linux (a.martin), GG_Utilisateurs (a.martin, b.durand)
          OU=Serveurs       (accueillera le compte ordinateur de SRV-WEB01)

.EXAMPLE
    .\New-StructureAD.ps1

.NOTES
    Lab Bachelor 3 Cybersécurité - SRV-DC01 (Windows Server 2025).
    À lancer dans une console PowerShell ouverte en administrateur du domaine.
#>
[CmdletBinding()]
param()

Import-Module ActiveDirectory -ErrorAction Stop

$domaineDN = (Get-ADDomain).DistinguishedName      # DC=pme,DC=lan
$domaineDNS = (Get-ADDomain).DNSRoot               # pme.lan
$racine = "OU=PME,$domaineDN"

# --- Données du lab (à adapter ici seulement) -------------------------------------
$ous = @('Utilisateurs', 'Groupes', 'Serveurs')

$groupes = @('GG_Admins_Linux', 'GG_Utilisateurs')

$utilisateurs = @(
    @{ Sam = 'a.martin'; Prenom = 'Alice'; Nom = 'Martin'; Groupes = @('GG_Admins_Linux', 'GG_Utilisateurs') },
    @{ Sam = 'b.durand'; Prenom = 'Bob';   Nom = 'Durand'; Groupes = @('GG_Utilisateurs') }
)

function Ecrire([string]$etat, [string]$texte) {
    $couleur = switch ($etat) { 'CREE' { 'Green' } 'EXISTE' { 'DarkGray' } 'AJOUT' { 'Cyan' } default { 'Red' } }
    Write-Host ("[{0,-6}] {1}" -f $etat, $texte) -ForegroundColor $couleur
}

# --- 1. Unités d'organisation --------------------------------------------------------
if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$racine'" -ErrorAction SilentlyContinue) {
    Ecrire 'EXISTE' "OU $racine"
} else {
    New-ADOrganizationalUnit -Name 'PME' -Path $domaineDN
    Ecrire 'CREE' "OU $racine"
}

foreach ($ou in $ous) {
    $dn = "OU=$ou,$racine"
    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue) {
        Ecrire 'EXISTE' "OU $dn"
    } else {
        New-ADOrganizationalUnit -Name $ou -Path $racine
        Ecrire 'CREE' "OU $dn"
    }
}

# --- 2. Groupes ------------------------------------------------------------------------
foreach ($g in $groupes) {
    if (Get-ADGroup -Filter "Name -eq '$g'" -ErrorAction SilentlyContinue) {
        Ecrire 'EXISTE' "Groupe $g"
    } else {
        New-ADGroup -Name $g -GroupScope Global -GroupCategory Security -Path "OU=Groupes,$racine"
        Ecrire 'CREE' "Groupe $g"
    }
}

# --- 3. Utilisateurs (mot de passe demandé seulement s'il y a un compte à créer) -------
$aCreer = $utilisateurs | Where-Object { -not (Get-ADUser -Filter "SamAccountName -eq '$($_.Sam)'" -ErrorAction SilentlyContinue) }
if ($aCreer) {
    $motDePasse = Read-Host -AsSecureString 'Mot de passe des comptes du lab (8 car. min., majuscule, chiffre, symbole)'
}

foreach ($u in $utilisateurs) {
    if (Get-ADUser -Filter "SamAccountName -eq '$($u.Sam)'" -ErrorAction SilentlyContinue) {
        Ecrire 'EXISTE' "Utilisateur $($u.Sam)"
    } else {
        try {
            New-ADUser -Name "$($u.Prenom) $($u.Nom)" -GivenName $u.Prenom -Surname $u.Nom `
                -SamAccountName $u.Sam -UserPrincipalName "$($u.Sam)@$domaineDNS" `
                -Path "OU=Utilisateurs,$racine" -AccountPassword $motDePasse -Enabled $true -ErrorAction Stop
            Ecrire 'CREE' "Utilisateur $($u.Sam) ($($u.Prenom) $($u.Nom))"
        } catch {
            Ecrire 'ECHEC' "Utilisateur $($u.Sam) : $($_.Exception.Message)"
            continue
        }
    }

    # Appartenances : on ajoute seulement celles qui manquent
    foreach ($g in $u.Groupes) {
        $membres = Get-ADGroupMember -Identity $g | Select-Object -ExpandProperty SamAccountName
        if ($membres -contains $u.Sam) {
            Ecrire 'EXISTE' "  $($u.Sam) est déjà membre de $g"
        } else {
            Add-ADGroupMember -Identity $g -Members $u.Sam
            Ecrire 'AJOUT' "  $($u.Sam) ajouté à $g"
        }
    }
}

# --- 4. Bilan -----------------------------------------------------------------------------
Write-Host ''
Write-Host 'Unités d''organisation :' -ForegroundColor Cyan
Get-ADOrganizationalUnit -Filter * -SearchBase $racine | Select-Object Name, DistinguishedName | Format-Table -AutoSize

Write-Host 'Utilisateurs :' -ForegroundColor Cyan
Get-ADUser -Filter * -SearchBase $racine | Select-Object Name, SamAccountName, UserPrincipalName, Enabled | Format-Table -AutoSize

Write-Host 'Groupes et membres :' -ForegroundColor Cyan
foreach ($g in $groupes) {
    $liste = (Get-ADGroupMember -Identity $g | Select-Object -ExpandProperty SamAccountName) -join ', '
    Write-Host ("  {0,-18} : {1}" -f $g, $liste)
}
