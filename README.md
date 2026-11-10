# admin-si — Industrialiser le SI de la PME

Projet de synthèse · Bachelor 3 Cybersécurité · Administration Systèmes Linux/Windows
Intervenant : Moussa Sakho · Groupes : [Lucas Fleury Kodo Ouattara Henri Louis Emmanuel Ilann Nedelec]

## Le projet

La PME dispose de trois serveurs construits à la main pendant les TP. Pour répondre aux
exigences de l'assureur, ce dépôt :

1. **écrit la configuration en code** et permet de la rejouer : Ansible pour les serveurs
   Linux, PowerShell pour le serveur Windows ;
2. **contrôle automatiquement chaque modification** : pipeline GitHub Actions
   (`ansible-lint` puis `ansible-playbook --syntax-check`) à chaque push ;
3. **détecte les pannes avant les utilisateurs** (Prometheus + Grafana + règles d'alerte)
   et **prouve** que les serveurs sont durcis (Lynis avant/après) et sauvegardés
   (sauvegarde planifiée + restauration testée).

L'état réel du SI (ce qui marche, ce qui reste manuel, les incidents) est dans [`ETAT.md`](ETAT.md).

## Schéma du SI

```
                     Réseau 10.10.0.0/24 — domaine pme.lan
                       passerelle / NAT VMware : 10.10.0.2

 ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
 │ SRV-DC01         │    │ SRV-WEB01        │    │ SRV-ADM01        │
 │ 10.10.0.10       │    │ 10.10.0.20       │    │ 10.10.0.30       │
 │ Windows Srv 2025 │    │ Debian 13        │    │ Debian 13        │
 │                  │    │                  │    │                  │
 │ AD DS (pme.lan)  │    │ Joint au domaine │    │ Ansible          │
 │ DNS, DHCP        │    │ nginx :80        │    │ apt-cacher-ng    │
 │ Partage Commun   │    │ RAID 1 /srv/     │    │   :3142          │
 │  (E:, quota      │    │  partage         │    │ Prometheus :9090 │
 │   FSRM 500 Mo)   │    │ Quotas /home     │    │ Grafana :3000    │
 │ GPO MAJ Windows  │    │ Sauvegarde       │    │                  │
 │ windows_exporter │    │  planifiée       │    │ node_exporter    │
 │   :9182          │    │ node_exporter    │    │   :9100          │
 │                  │    │   :9100          │    │                  │
 └────────▲─────────┘    └────────▲─────────┘    └────────┬─────────┘
          │                       │                       │
          │      SSH (compte ansible) ◄───────────────────┤ Ansible
          └───────────────────────┴───────────────────────┘ Prometheus lit
                         métriques toutes les 15 s           les exporteurs
```

| Serveur | Configuré par | Supervisé par |
|---|---|---|
| SRV-DC01 | Scripts PowerShell de `windows/` | windows_exporter (9182) |
| SRV-WEB01 | Ansible `site.yml` (connexion SSH, compte local `ansible`) | node_exporter (9100) |
| SRV-ADM01 | Ansible `site.yml` (connexion locale, compte `sysadmin`) | node_exporter (9100) |

## Arborescence du dépôt

```
admin-si/
├── README.md                     ce fichier
├── ETAT.md                       état réel du SI, écarts, incidents
├── .github/workflows/ci.yml      pipeline : ansible-lint + syntax-check
├── ansible/
│   ├── ansible.cfg
│   ├── site.yml                  configure SRV-WEB01 et SRV-ADM01
│   ├── maj.yml                   mise à jour des Debian (TP 3)
│   ├── proxy-apt.yml             apt passe par le cache de SRV-ADM01 (TP 3)
│   ├── exporteurs.yml            node_exporter (TP 3)
│   ├── inventaire/hosts.ini
│   ├── group_vars/all/vars.yml   clé du compte audit, règles de pare-feu
│   └── roles/
│       ├── commun/               paquets de base, fuseau, compte audit
│       ├── ssh/                  pas de root, 3 essais, config validée
│       └── durcissement/         ufw, fail2ban, mises à jour auto
├── windows/                      scripts PowerShell de SRV-DC01
├── supervision/                  prometheus.yml, règles d'alerte pme.yml
├── sauvegarde/                   script et timer systemd de SRV-WEB01
└── docs/
    ├── supervision.md            composants, alertes, preuve de déclenchement
    ├── procedures/restauration.md
    ├── securite/                 Lynis avant / après
    ├── diagnostic/               fiches des pannes des TP
    └── img/                      captures
```

## Ce que font les rôles Ansible

| Rôle | Mesures | Pourquoi |
|---|---|---|
| `commun` | paquets de base, fuseau Europe/Paris, compte local `audit` avec **uniquement** la clé de l'intervenant (`exclusive: true`), sudo sans mot de passe (fichier validé par `visudo -cf`) | même socle partout ; compte d'audit traçable et sans accès parasite |
| `ssh` | `PermitRootLogin no`, `MaxAuthTries 3`, configuration validée par `sshd -t -f %s` avant d'être écrite | une configuration invalide n'est jamais appliquée : pas de serveur verrouillé |
| `durcissement` | ufw (refus par défaut, ports déclarés par serveur dans `ufw_regles`), fail2ban (jail sshd), mises à jour de sécurité automatiques | moindre privilège : SSH/HTTP ouverts, métriques lisibles par Prometheus seulement, outils d'admin depuis le LAN seulement |

Règles de pare-feu (`group_vars/all/vars.yml`) :

| Serveur | Port | Source |
|---|---|---|
| SRV-WEB01 | 22, 80 | tous |
| SRV-WEB01 | 9100 | 10.10.0.30 |
| SRV-ADM01 | 22 | tous |
| SRV-ADM01 | 9090, 3000, 3142, 514 | 10.10.0.0/24 |
| SRV-ADM01 | 9100 | 10.10.0.30 |

## Rejouer la configuration, dans l'ordre

### 0. Démarrage
SRV-DC01 **en premier** (DNS, DHCP, heure), attendre son écran de connexion, puis SRV-WEB01, puis SRV-ADM01.

### 1. SRV-DC01 (PowerShell administrateur, dossier `windows/`)
Chaque script vérifie l'existant avant d'agir : relancé, il ne casse rien.
```powershell
powershell -ExecutionPolicy Bypass -File .\New-StructureAD.ps1    # OU, groupes, comptes (mot de passe demandé)
powershell -ExecutionPolicy Bypass -File .\Partage-Commun.ps1     # groupe DL, NTFS, partage SMB, quota FSRM
powershell -ExecutionPolicy Bypass -File .\GPO-MAJ-Windows.ps1    # GPO_MAJ_WindowsUpdate, dimanche 3h
```
Prérequis faits à la main : promotion du contrôleur de domaine, rôles DHCP, volume miroir `E:`.

### 2. Prérequis Linux (une fois)
SRV-ADM01 installé avec Ansible et git ; sur SRV-WEB01, un compte local `ansible` avec la clé
publique de SRV-ADM01 et sudo sans mot de passe (fiche TP 3, étape 1.4).

### 3. SRV-ADM01, dossier `ansible/`
```bash
ansible linux -m ping                          # srv-web01 et srv-adm01 : « pong »
ansible-playbook proxy-apt.yml -K              # apt passe par le cache
ansible-playbook exporteurs.yml -K             # node_exporter sur les deux Debian
ansible-playbook site.yml -K --check --diff    # ce qui changerait
ansible-playbook site.yml -K                   # on applique
ansible-playbook site.yml -K                   # deuxième passage : changed=0 attendu
ansible-playbook maj.yml -K                    # mises à jour (au besoin)
```
`-K` : SRV-ADM01 est géré en connexion locale avec `sysadmin`, sudo demande son mot de passe.

> **Règle de survie SSH** : avant tout playbook qui touche sshd ou ufw, garder une session SSH
> ouverte à côté et lancer `--check --diff` d'abord.

### 4. Supervision (SRV-ADM01)
```bash
sudo cp supervision/prometheus.yml /etc/prometheus/
sudo mkdir -p /etc/prometheus/rules && sudo cp supervision/pme.yml /etc/prometheus/rules/
promtool check config /etc/prometheus/prometheus.yml
sudo systemctl restart prometheus
```
Grafana : source de données `http://localhost:9090`, tableau de bord « Parc PME ». Détails dans [`docs/supervision.md`](docs/supervision.md).

### 5. Sauvegarde (SRV-WEB01)
```bash
sudo install -m 750 sauvegarde/sauvegarde.sh /usr/local/sbin/
sudo cp sauvegarde/sauvegarde.service sauvegarde/sauvegarde.timer /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now sauvegarde.timer
```
Restaurer un fichier : [`docs/procedures/restauration.md`](docs/procedures/restauration.md).

## Contrôle automatique
Le pipeline [`.github/workflows/ci.yml`](.github/workflows/ci.yml) tourne sur les machines de
GitHub à chaque push : installation d'Ansible, `ansible-lint --profile basic`, puis
`ansible-playbook -i inventaire/hosts.ini site.yml --syntax-check`. Le résultat est visible
dans l'onglet **Actions**. Le lab n'est pas nécessaire.

## Sources
- Fiches TP 1, 2, 3 et sujet du projet de synthèse (M. Sakho) : commandes de base, playbooks
  `maj.yml`, `proxy-apt.yml`, `exporteurs.yml`, configuration Prometheus, script `New-StructureAD.ps1`.
- Documentation officielle : Ansible (modules `ufw`, `authorized_key`, `template`, `copy`),
  Prometheus (règles d'alerte), Grafana, systemd (`systemd.timer`).
- Les scripts `Partage-Commun.ps1`, `GPO-MAJ-Windows.ps1`, la boucle
  `ufw_regles` du rôle durcissement, l'option `exclusive` du compte audit et le script de
  sauvegarde ont été écrits avec l'aide de Claude (Anthropic), puis relus, testés sur le lab
  et compris par les deux membres du binôme.
EOFcd ~/admin-si
cat > README.md << 'EOF'
# admin-si — Industrialiser le SI de la PME

Projet de synthèse · Bachelor 3 Cybersécurité · Administration Systèmes Linux/Windows
Intervenant : Moussa Sakho · Binôme : [À COMPLÉTER : Prénom Nom (compte GitHub), Prénom Nom (compte GitHub)]

## Le projet

La PME dispose de trois serveurs construits à la main pendant les TP. Pour répondre aux
exigences de l'assureur, ce dépôt :

1. **écrit la configuration en code** et permet de la rejouer : Ansible pour les serveurs
   Linux, PowerShell pour le serveur Windows ;
2. **contrôle automatiquement chaque modification** : pipeline GitHub Actions
   (`ansible-lint` puis `ansible-playbook --syntax-check`) à chaque push ;
3. **détecte les pannes avant les utilisateurs** (Prometheus + Grafana + règles d'alerte)
   et **prouve** que les serveurs sont durcis (Lynis avant/après) et sauvegardés
   (sauvegarde planifiée + restauration testée).

L'état réel du SI (ce qui marche, ce qui reste manuel, les incidents) est dans [`ETAT.md`](ETAT.md).

## Schéma du SI

```
                     Réseau 10.10.0.0/24 — domaine pme.lan
                       passerelle / NAT VMware : 10.10.0.2

 ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
 │ SRV-DC01         │    │ SRV-WEB01        │    │ SRV-ADM01        │
 │ 10.10.0.10       │    │ 10.10.0.20       │    │ 10.10.0.30       │
 │ Windows Srv 2025 │    │ Debian 13        │    │ Debian 13        │
 │                  │    │                  │    │                  │
 │ AD DS (pme.lan)  │    │ Joint au domaine │    │ Ansible          │
 │ DNS, DHCP        │    │ nginx :80        │    │ apt-cacher-ng    │
 │ Partage Commun   │    │ RAID 1 /srv/     │    │   :3142          │
 │  (E:, quota      │    │  partage         │    │ Prometheus :9090 │
 │   FSRM 500 Mo)   │    │ Quotas /home     │    │ Grafana :3000    │
 │ GPO MAJ Windows  │    │ Sauvegarde       │    │                  │
 │ windows_exporter │    │  planifiée       │    │ node_exporter    │
 │   :9182          │    │ node_exporter    │    │   :9100          │
 │                  │    │   :9100          │    │                  │
 └────────▲─────────┘    └────────▲─────────┘    └────────┬─────────┘
          │                       │                       │
          │      SSH (compte ansible) ◄───────────────────┤ Ansible
          └───────────────────────┴───────────────────────┘ Prometheus lit
                         métriques toutes les 15 s           les exporteurs
```

| Serveur | Configuré par | Supervisé par |
|---|---|---|
| SRV-DC01 | Scripts PowerShell de `windows/` | windows_exporter (9182) |
| SRV-WEB01 | Ansible `site.yml` (connexion SSH, compte local `ansible`) | node_exporter (9100) |
| SRV-ADM01 | Ansible `site.yml` (connexion locale, compte `sysadmin`) | node_exporter (9100) |

## Arborescence du dépôt

```
admin-si/
├── README.md                     ce fichier
├── ETAT.md                       état réel du SI, écarts, incidents
├── .github/workflows/ci.yml      pipeline : ansible-lint + syntax-check
├── ansible/
│   ├── ansible.cfg
│   ├── site.yml                  configure SRV-WEB01 et SRV-ADM01
│   ├── maj.yml                   mise à jour des Debian (TP 3)
│   ├── proxy-apt.yml             apt passe par le cache de SRV-ADM01 (TP 3)
│   ├── exporteurs.yml            node_exporter (TP 3)
│   ├── inventaire/hosts.ini
│   ├── group_vars/all/vars.yml   clé du compte audit, règles de pare-feu
│   └── roles/
│       ├── commun/               paquets de base, fuseau, compte audit
│       ├── ssh/                  pas de root, 3 essais, config validée
│       └── durcissement/         ufw, fail2ban, mises à jour auto
├── windows/                      scripts PowerShell de SRV-DC01
├── supervision/                  prometheus.yml, règles d'alerte pme.yml
├── sauvegarde/                   script et timer systemd de SRV-WEB01
└── docs/
    ├── supervision.md            composants, alertes, preuve de déclenchement
    ├── procedures/restauration.md
    ├── securite/                 Lynis avant / après
    ├── diagnostic/               fiches des pannes des TP
    └── img/                      captures
```

## Ce que font les rôles Ansible

| Rôle | Mesures | Pourquoi |
|---|---|---|
| `commun` | paquets de base, fuseau Europe/Paris, compte local `audit` avec **uniquement** la clé de l'intervenant (`exclusive: true`), sudo sans mot de passe (fichier validé par `visudo -cf`) | même socle partout ; compte d'audit traçable et sans accès parasite |
| `ssh` | `PermitRootLogin no`, `MaxAuthTries 3`, configuration validée par `sshd -t -f %s` avant d'être écrite | une configuration invalide n'est jamais appliquée : pas de serveur verrouillé |
| `durcissement` | ufw (refus par défaut, ports déclarés par serveur dans `ufw_regles`), fail2ban (jail sshd), mises à jour de sécurité automatiques | moindre privilège : SSH/HTTP ouverts, métriques lisibles par Prometheus seulement, outils d'admin depuis le LAN seulement |

Règles de pare-feu (`group_vars/all/vars.yml`) :

| Serveur | Port | Source |
|---|---|---|
| SRV-WEB01 | 22, 80 | tous |
| SRV-WEB01 | 9100 | 10.10.0.30 |
| SRV-ADM01 | 22 | tous |
| SRV-ADM01 | 9090, 3000, 3142, 514 | 10.10.0.0/24 |
| SRV-ADM01 | 9100 | 10.10.0.30 |

## Rejouer la configuration, dans l'ordre

### 0. Démarrage
SRV-DC01 **en premier** (DNS, DHCP, heure), attendre son écran de connexion, puis SRV-WEB01, puis SRV-ADM01.

### 1. SRV-DC01 (PowerShell administrateur, dossier `windows/`)
Chaque script vérifie l'existant avant d'agir : relancé, il ne casse rien.
```powershell
powershell -ExecutionPolicy Bypass -File .\New-StructureAD.ps1    # OU, groupes, comptes (mot de passe demandé)
powershell -ExecutionPolicy Bypass -File .\Partage-Commun.ps1     # groupe DL, NTFS, partage SMB, quota FSRM
powershell -ExecutionPolicy Bypass -File .\GPO-MAJ-Windows.ps1    # GPO_MAJ_WindowsUpdate, dimanche 3h
powershell -ExecutionPolicy Bypass -File .\windows_exporter.ps1   # exporteur + règle pare-feu 9182
```
Prérequis faits à la main : promotion du contrôleur de domaine, rôles DHCP, volume miroir `E:`.

### 2. Prérequis Linux (une fois)
SRV-ADM01 installé avec Ansible et git ; sur SRV-WEB01, un compte local `ansible` avec la clé
publique de SRV-ADM01 et sudo sans mot de passe (fiche TP 3, étape 1.4).

### 3. SRV-ADM01, dossier `ansible/`
```bash
ansible linux -m ping                          # srv-web01 et srv-adm01 : « pong »
ansible-playbook proxy-apt.yml -K              # apt passe par le cache
ansible-playbook exporteurs.yml -K             # node_exporter sur les deux Debian
ansible-playbook site.yml -K --check --diff    # ce qui changerait
ansible-playbook site.yml -K                   # on applique
ansible-playbook site.yml -K                   # deuxième passage : changed=0 attendu
ansible-playbook maj.yml -K                    # mises à jour (au besoin)
```
`-K` : SRV-ADM01 est géré en connexion locale avec `sysadmin`, sudo demande son mot de passe.

> **Règle de survie SSH** : avant tout playbook qui touche sshd ou ufw, garder une session SSH
> ouverte à côté et lancer `--check --diff` d'abord.

### 4. Supervision (SRV-ADM01)
```bash
sudo cp supervision/prometheus.yml /etc/prometheus/
sudo mkdir -p /etc/prometheus/rules && sudo cp supervision/pme.yml /etc/prometheus/rules/
promtool check config /etc/prometheus/prometheus.yml
sudo systemctl restart prometheus
```
Grafana : source de données `http://localhost:9090`, tableau de bord « Parc PME ». Détails dans [`docs/supervision.md`](docs/supervision.md).

### 5. Sauvegarde (SRV-WEB01)
```bash
sudo install -m 750 sauvegarde/sauvegarde.sh /usr/local/sbin/
sudo cp sauvegarde/sauvegarde.service sauvegarde/sauvegarde.timer /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now sauvegarde.timer
```
Restaurer un fichier : [`docs/procedures/restauration.md`](docs/procedures/restauration.md).

## Contrôle automatique
Le pipeline [`.github/workflows/ci.yml`](.github/workflows/ci.yml) tourne sur les machines de
GitHub à chaque push : installation d'Ansible, `ansible-lint --profile basic`, puis
`ansible-playbook -i inventaire/hosts.ini site.yml --syntax-check`. Le résultat est visible
dans l'onglet **Actions**. Le lab n'est pas nécessaire.

## Sources
- Fiches TP 1, 2, 3 et sujet du projet de synthèse (M. Sakho) : commandes de base, playbooks
  `maj.yml`, `proxy-apt.yml`, `exporteurs.yml`, configuration Prometheus, script `New-StructureAD.ps1`.
- Documentation officielle : Ansible (modules `ufw`, `authorized_key`, `template`, `copy`),
  Prometheus (règles d'alerte), Grafana, systemd (`systemd.timer`).
- Les scripts `Partage-Commun.ps1`, `GPO-MAJ-Windows.ps1`, `windows_exporter.ps1`, la boucle
  `ufw_regles` du rôle durcissement, l'option `exclusive` du compte audit et le script de
  sauvegarde ont été écrits avec l'aide de Claude (Anthropic), puis relus, testés sur le lab
  et compris par les deux membres du binôme.
