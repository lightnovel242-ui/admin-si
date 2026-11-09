# Ticket 3 : SSH indisponible sur SRV-WEB01

**Détection** : alerte Prometheus `ServiceArrete` (ssh.service sur
srv-web01), passée en Firing à [HH:MM] ; panne à [HH:MM] ; constat à [HH:MM].

**Symptôme constaté** : nouvelle connexion `ssh sysadmin@10.10.0.20`
refusée / sans réponse [recopiez le message exact].

**Ressources** : [df -h, free -h, uptime : rien d'anormal ?]

**Service** : ssh.service en état failed depuis [HH:MM]
(`systemctl status ssh`).

**Diagnostic** : `journalctl -u ssh -b -n 20` : [message exact].
`sudo sshd -t` a d'abord répondu « Missing privilege separation
directory: /run/sshd » (dossier créé au démarrage du service, donc absent
puisque le service est arrêté) ; après `mkdir -p /run/sshd`, le test a
désigné [fichier et ligne].

**Changement** : le fichier [/etc/ssh/sshd_config.d/xxx.conf], le plus
récent d'après `ls -lt /etc/ssh/sshd_config.d/`, a été modifié à [HH:MM].

**Cause** : valeur `non` (français) au lieu de `no` pour `PermitRootLogin` :
sshd refuse une valeur inconnue et ne démarre pas.

**Correction immédiate** : `non` -> `no` (durcissement conservé),
`sudo sshd -t`, `sudo systemctl restart ssh`, nouvelle connexion testée,
alerte repassée à Inactive à [HH:MM].

**Correction durable** : configuration SSH gérée par un rôle Ansible avec
`validate: sshd -t -f %s`, pour qu'une configuration invalide ne soit
jamais écrite ; règle : garder une session ouverte avant tout changement SSH.
