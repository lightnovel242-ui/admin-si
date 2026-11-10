# État du SI au 10/11/2026

Relevés des scripts d'audit le 10/11 au matin : **SRV-DC01 OK 11 / KO 0**,
**SRV-WEB01 OK 12 / KO 0**, **SRV-ADM01 OK 14 / KO 0**.

## SRV-DC01 · 10.10.0.10 · Windows Server 2025
- AD DS `pme.lan` (NetBIOS PME), OU PME › Utilisateurs, Groupes, Serveurs.
- Groupes GG_Admins_Linux, GG_Utilisateurs, DL_Commun_Modification (méthode AGDLP) ;
  comptes a.martin, b.durand.
- DNS (zone pme.lan, enregistrements srv-web01 et srv-adm01), DHCP 10.10.0.100-200 autorisé dans l'AD.
- Partage `Commun` sur `E:\Partages\Commun` (volume miroir), quota FSRM 500 Mo, avertissement à 85 %.
- `GPO_MAJ_WindowsUpdate` liée à l'OU Domain Controllers : installation des mises à jour le dimanche à 3h.
- windows_exporter (9182), démarrage automatique, pare-feu ouvert à 10.10.0.30 seulement.

## SRV-WEB01 · 10.10.0.20 · Debian 13
- Joint au domaine (sssd), nginx, SSH par clé.
- `/var` et `/home` sur LVM (vg_data), RAID 1 `md0` sur `/srv/partage`, quota b.durand 100/120 Mo.
- Configuré par `site.yml` : rôles commun, ssh, durcissement.
- node_exporter (9100) ; ufw : 22, 80 ouverts, 9100 depuis 10.10.0.30.
- Sauvegarde planifiée tous les jours à 2h (`sauvegarde.timer`), archives dans `/var/backups/sauvegarde/`.

## SRV-ADM01 · 10.10.0.30 · Debian 13
- Ansible (dossier `ansible/` de ce dépôt), apt-cacher-ng (3142), Prometheus (9090), Grafana (3000), node_exporter (9100).
- Configuré par `site.yml` : rôles commun, ssh, durcissement.
- ufw : 22 ouvert ; 9090, 3000, 3142, 514 depuis 10.10.0.0/24 ; 9100 depuis 10.10.0.30.

## Ce qui marche
- `site.yml` passe sans erreur sur SRV-WEB01 et SRV-ADM01 ; deuxième passage **changed=0**.
- Compte `audit` sur les deux Debian : seule la clé de l'intervenant
  (empreinte `SHA256:Lqk7gAWm…`), sudo sans mot de passe.
- SSH : `permitrootlogin no`, `maxauthtries 3`, configuration validée par `sshd -t` avant écriture.
- ufw actif (refus par défaut), fail2ban actif (jail sshd), mises à jour de sécurité automatiques.
- Pipeline GitHub Actions vert (ansible-lint + syntax-check) à chaque push.
- Aucun secret en clair : le mot de passe des comptes AD est demandé par `Read-Host -AsSecureString`.
- Scripts PowerShell de `windows/` relançables sans erreur.
- Prometheus : les trois serveurs sont UP ; trois règles d'alerte chargées.
- Alerte `ServeurInjoignable` testée le 10/11 : Pending 11:33:51, Firing ~11:34:51, résolue ~11:37
  (`docs/supervision.md`).
- Tableau de bord Grafana « Parc PME » : disponibilité, processeur, mémoire, disques.
- Lynis sur SRV-WEB01 : **68 avant → 71 après** les rôles (`docs/securite/`).
- Sauvegarde planifiée de SRV-WEB01 et restauration d'un fichier supprimé testée le 10/11
  (`docs/procedures/restauration.md`).

## Ce qui ne marche pas / limites
- **Lynis +3 seulement** : nos rôles couvrent SSH, pare-feu, fail2ban et mises à jour. Les autres
  suggestions de Lynis (mot de passe GRUB, auditd, durcissement du noyau, partitions
  supplémentaires) sont hors du périmètre demandé.
- **`PasswordAuthentication yes`** reste actif : les comptes de l'annuaire (sssd) se connectent
  par mot de passe. fail2ban et `MaxAuthTries 3` limitent le risque de force brute.
- **Sauvegarde locale** : les archives sont sur le même serveur (volume `lv_var`, distinct du RAID).
  Elle protège d'une suppression ou d'une erreur, pas de la perte du serveur. En production :
  copie hors machine (règle 3-2-1).
- **SRV-ADM01 n'a que 1 Go de RAM** (1,5 Go recommandés pour Prometheus + Grafana) : le swap est
  utilisé ; cause probable de l'incident apt-cacher-ng.
- Prometheus, Grafana et la sauvegarde ne sont **pas déployés par un rôle Ansible** (bonus non fait).

## Ce qui reste fait à la main
- Promotion du contrôleur de domaine, rôles DHCP, volume miroir Storage Spaces `E:`.
- Installation de Prometheus et Grafana ; configuration copiée dans `supervision/` ;
  tableau de bord Grafana créé dans l'interface (non exporté).
- Sauvegarde de SRV-WEB01 : script et timer posés à la main le 10/11 (copies dans `sauvegarde/`).
- `ConnectProto: v4` ajouté dans `/etc/apt-cacher-ng/acng.conf` sur SRV-ADM01.
- Les règles ufw des TP sont encore présentes en doublon des règles posées par Ansible
  (ex. `3000,9090/tcp` combinée sur SRV-ADM01) : sans effet, à nettoyer.

## Incidents et écarts du 10/11
| Incident | Cause | Correction |
|---|---|---|
| `site.yml` en échec sur « Paquets de base » | apt-cacher-ng renvoyait `503 Cannot allocate memory` : pas de sortie IPv6 dans le lab, RAM limitée | redémarrage du service + `ConnectProto: v4` (manuel) |
| Clé de SRV-ADM01 autorisée sur le compte audit | `vars.yml` contenait la clé sysadmin ; `state: present` n'enlève pas les autres clés | clé de l'intervenant + `exclusive: true` |
| Ports 9100/9090/3000/3142/514 ouverts seulement à la main | rôle durcissement limité à 22 et 80 | règles déclarées dans `ufw_regles` |
| SRV-DC01 DOWN dans Prometheus | service windows_exporter arrêté | redémarré, démarrage automatique, script `windows_exporter.ps1` |
| `[KO] pas de GPO dont le nom évoque les mises à jour` | le contrôle cherche « jour\|update\|wsus » dans le nom ; « MAJ » ne correspond pas | GPO renommée `GPO_MAJ_Windows` → `GPO_MAJ_WindowsUpdate` (même GUID, même lien) ; script mis à jour |
| Aucune sauvegarde planifiée sur SRV-WEB01 | perdue ou non faite au TP 2 | recréée le 10/11 (script + timer systemd), restauration testée |
| `docs/securite/lynis-apres.txt` vidé | redirection d'une commande en échec vers le fichier | restauré depuis Git, puis audit refait (71) |
