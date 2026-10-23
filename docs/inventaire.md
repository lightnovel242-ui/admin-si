Inventaire du SI — PME.LAN
Réseau
Domaine : pme.lan (NetBIOS : PME)
Réseau : 10.10.0.0/24
Passerelle : 10.10.0.2
Plage DHCP : 10.10.0.100 à 10.10.0.200

Serveurs
| Nom       | OS                      | IP fixe     | Rôles              | RAM  | vCPU | Disque |
|-----------|-------------------------|-------------|--------------------|------|------|--------|
| SRV-DC01  | Windows Server 2025     | 10.10.0.10  | AD DS, DNS, DHCP   | 4 Go | 2    | 40 Go  |
| SRV-WEB01 | Debian 13 minimale      | 10.10.0.20  | Web, joint domaine | 1 Go | 1    | 20 Go  |

Comptes de l'annuaire
| Compte    | Groupe            | Rôle                  |
|-----------|-------------------|-----------------------|
| a.martin  | GG_Admins_Linux   | Administratrice Linux |
| b.durand  | GG_Utilisateurs   | Utilisateur standard  |
