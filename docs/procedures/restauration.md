# Procédure : restaurer un fichier depuis la sauvegarde de SRV-WEB01

## En bref
| | |
|---|---|
| **Ce qui est sauvegardé** | `/srv/partage` (partage de fichiers, RAID 1), `/etc/nginx`, `/var/www` |
| **Où** | `/var/backups/sauvegarde/web01-AAAA-MM-JJ-HHMM.tar.gz` sur SRV-WEB01 |
| **Quand** | tous les jours à 2h (timer systemd `sauvegarde.timer`) ; rattrapée au démarrage si le serveur était éteint (`Persistent=true`) |
| **Combien de temps** | 7 jours, les archives plus anciennes sont supprimées automatiquement |
| **Script** | `/usr/local/sbin/sauvegarde.sh` (copie dans `sauvegarde/` du dépôt) |
| **Il faut** | un compte avec sudo sur SRV-WEB01 (ex. `sysadmin`) |

Durée de la procédure : environ 5 minutes.

## Étape 1 · Se connecter et vérifier que la sauvegarde fonctionne
```bash
ssh sysadmin@10.10.0.20
systemctl list-timers sauvegarde.timer --no-pager          # prochaine et dernière exécution
sudo journalctl -u sauvegarde.service -n 5 --no-pager      # doit afficher « Sauvegarde OK : ... »
```
Si le journal montre une erreur, ne pas continuer : signaler l'incident (la sauvegarde ne
tourne pas).

## Étape 2 · Choisir l'archive
Prendre la plus récente **antérieure** à la suppression ou à la modification du fichier
(le nom de l'archive contient la date et l'heure).
```bash
ls -lt /var/backups/sauvegarde/
A=/var/backups/sauvegarde/web01-AAAA-MM-JJ-HHMM.tar.gz      # remplacer par le nom choisi
```
Pour prendre simplement la plus récente :
```bash
A=$(ls -t /var/backups/sauvegarde/web01-*.tar.gz | head -1); echo "$A"
```

## Étape 3 · Vérifier que le fichier est dans l'archive
Les chemins sont enregistrés **sans le `/` du début** : `srv/partage/...`, et non `/srv/partage/...`.
```bash
sudo tar -tzf "$A" | grep NOM_DU_FICHIER
```
Rien ne s'affiche ? Le fichier n'est pas dans cette archive : essayer une archive plus ancienne.

## Étape 4 · Extraire dans un dossier temporaire
On n'extrait **jamais directement en place** : on contrôle d'abord le fichier, sans risquer
d'écraser une version plus récente ou un autre fichier.
```bash
sudo mkdir -p /tmp/restau
sudo tar -xzf "$A" -C /tmp/restau srv/partage/NOM_DU_FICHIER
sudo ls -l /tmp/restau/srv/partage/
sudo cat /tmp/restau/srv/partage/NOM_DU_FICHIER            # contenu attendu ?
```

## Étape 5 · Remettre le fichier en place
`cp -a` conserve le propriétaire, les droits et les dates d'origine.
```bash
sudo cp -a /tmp/restau/srv/partage/NOM_DU_FICHIER /srv/partage/
ls -l /srv/partage/NOM_DU_FICHIER
```

## Étape 6 · Nettoyer
```bash
sudo rm -rf /tmp/restau
```

## Exemple réel du 10/11/2026
Fichier de test créé dans le partage, sauvegardé, supprimé, puis restauré :
```
$ echo "fichier important $(date)" | sudo tee /srv/partage/rapport.txt
fichier important mar. 10 nov. 2026 11:40:55 CET

$ sudo systemctl start sauvegarde.service

$ sudo rm /srv/partage/rapport.txt && ls /srv/partage/
avant.txt  lost+found  pendant.txt                        ← rapport.txt a disparu

$ A=$(ls -t /var/backups/sauvegarde/web01-*.tar.gz | head -1); echo "$A"
/var/backups/sauvegarde/web01-2026-11-10-1140.tar.gz

$ sudo tar -tzf "$A" | grep rapport.txt
srv/partage/rapport.txt                                   ← présent dans l'archive

$ sudo mkdir -p /tmp/restau && sudo tar -xzf "$A" -C /tmp/restau srv/partage/rapport.txt

$ sudo cp -a /tmp/restau/srv/partage/rapport.txt /srv/partage/ && cat /srv/partage/rapport.txt
fichier important mar. 10 nov. 2026 11:40:55 CET          ← contenu identique

$ sudo rm -rf /tmp/restau
```
**Résultat** : fichier restauré à l'identique.

## Problèmes courants
| Symptôme | Cause | Solution |
|---|---|---|
| `journalctl` affiche « No entries » | journal lu sans sudo | `sudo journalctl -u sauvegarde.service` |
| `tar: srv/partage/x : introuvable dans l'archive` | chemin écrit avec le `/` initial, ou mauvaise archive | chemin sans `/` initial ; vérifier avec `tar -tzf` |
| `/var/backups/sauvegarde/` vide | le timer n'a jamais tourné | `sudo systemctl start sauvegarde.service`, puis lire le journal |

## Limites
La sauvegarde est **sur le même serveur** (volume `lv_var`, distinct du RAID `/srv/partage`).
Elle protège d'une suppression ou d'une erreur de manipulation, **pas** de la perte complète de
SRV-WEB01. En production : une copie hors machine, vers SRV-ADM01 ou un NAS (règle 3-2-1 :
3 copies, 2 supports, 1 hors site).
