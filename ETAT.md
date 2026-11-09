État du SI au 23/10/2026
SRV-DC01 · 10.10.0.10 · Windows Server 2025
Rôles : AD DS (pme.lan), DNS, DHCP (10.10.0.100-200), FSRM
Partage Commun (E:, miroir), quota 500 Mo, GPO_MAJ_Windows
Comptes : a.martin, b.durand ; groupes GG_Admins_Linux, GG_Utilisateurs,
DL_Commun_Modification
SRV-WEB01 · 10.10.0.20 · Debian 13
Joint au domaine (sssd), nginx, SSH par clé, ufw (22, 80)
vg_data : /var et /home ; RAID 1 md0 sur /srv/partage ; quota b.durand 100/120 Mo
Compte ansible (clé de SRV-ADM01), apt par le cache, rsyslog vers SRV-ADM01
SRV-ADM01 · 10.10.0.30 · Debian 13
Ansible (ansible/ dans ce dépôt), apt-cacher-ng (3142), collecteur rsyslog (514), ufw
Points ouverts
ce qui ne marche pas encore, ce qui est fait à la main et devrait être automatisé
