Journal d'installation — TP1
SRV-DC01 — Windows Server 2025
Étape 1 — IP fixe et nom
IP configurée en 10.10.0.10/24, passerelle 10.10.0.2
DNS pointé sur 127.0.0.1 (lui-même)
Machine renommée SRV-DC01 et redémarrée

Étape 2 — Promotion en contrôleur de domaine
Rôles AD DS et DNS installés
Forêt pme.lan créée, NetBIOS : PME
Redirecteur DNS 8.8.8.8 ajouté pour l'accès Internet

Étape 3 — DHCP
Rôle DHCP installé
Étendue LAN-PME créée : 10.10.0.100 à 10.10.0.200
Options : routeur 10.10.0.2, DNS 10.10.0.10, domaine pme.lan

Étape 4 — Structure AD
Script New-StructureAD.ps1 exécuté
OU créées : PME > Utilisateurs, Groupes, Serveurs
Groupes : GG_Admins_Linux, GG_Utilisateurs
Comptes : a.martin, b.durand

---

SRV-WEB01 — Debian 13
Étape 5 — Installation
Installation minimale, sans bureau
Utilisateur : sysadmin
SSH activé dès l'installation

Étape 6 — IP fixe
IP configurée en 10.10.0.20/24
DNS : 10.10.0.10 (SRV-DC01)
hostname -f = srv-web01.pme.lan

Étape 7 — Jonction au domaine
Paquets realmd, sssd, krb5-user installés
Jonction à pme.lan avec realm join
a.martin dans sudoers via GG_Admins_Linux

Étape 8 — SSH par clé
Clé ed25519 générée sur le PC hôte
Clé publique déposée dans ~/.ssh/authorized_keys de sysadmin
PermitRootLogin désactivé

Étape 9 — Service web et pare-feu
Nginx installé et activé au démarrage
Page personnalisée : SRV-WEB01 - pme.lan
UFW activé : SSH et HTTP autorisés, tout le reste refusé
