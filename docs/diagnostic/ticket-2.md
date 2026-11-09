Ticket 2 : <texte du ticket affiché par le script>
Symptôme constaté : le playbook Ansible échoue sur SRV-WEB01 depuis ~14:56 le 09/11 (<tâche en échec et message d'erreur>).
Ressources : df -h : /var à 100 % (3,9 Go utilisés sur 3,9 Go, 0 disponible), / à 9 %, /home à 1 %. du -xh -d1 /var : /var/cache = 3,6 Go, dont /var/cache/man = 3,5 Go (/var/cache/apt = 96 Mo, normal).
Service : <extrait du message d'erreur du playbook, 3 lignes maximum>
Changement : un fichier caché .index-cache.db de 3,4 Go, propriétaire root, a été créé dans /var/cache/man le 09/11 à 14:56:47. Trouvé en descendant avec du -xh -d1 puis ls -la --time-style=full-iso (les fichiers cachés n'apparaissent qu'avec -a). file : data ; lsof +D : aucun processus ne l'utilise.
Cause : un fichier caché de 3,4 Go dans /var/cache/man a rempli le volume /var (3,9 Go), ce qui empêche toute écriture et fait échouer le playbook.
Correction immédiate : sudo rm /var/cache/man/.index-cache.db, df -h /var (<nouveau pourcentage>), puis relance de ansible-playbook maj.yml -K (OK).
Correction durable : /var est un volume LVM de 3,9 Go seulement : l'agrandir (lvextend -r) ; surveiller la taille des caches ; limiter les écritures dans /var/cache aux comptes de service.
Détection : alerte Prometheus sur l'espace libre de /var (par exemple moins de 15 % pendant 5 minutes), qui aurait prévenu avant l'échec du playbook.
