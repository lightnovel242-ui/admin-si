Ticket 1 : <texte du ticket affiché par le script>
Symptôme constaté : le site http://10.10.0.20/ ne répond plus pour tous les utilisateurs, depuis 14:56 le 09/11.
Ressources : <sorties de df -h, free -h, uptime : rien d'anormal si c'est le cas>
Service : nginx.service en état failed (ExecStartPre : nginx -t, code 1).[emerg] unknown directive "gzip_type" in /etc/nginx/sites-enabled/default:22nginx: configuration file /etc/nginx/nginx.conf test failed
Changement : le dossier /etc/nginx/sites-available a été modifié le 09/11 à 14:56, heure de l'arrêt de nginx ; trouvé avec ls -lt /etc/nginx. sites-enabled/default est un lien vers sites-available/default.
Cause : une faute de frappe dans sites-available/default (gzip_type au lieu de gzip_types) empêche nginx de valider sa configuration et donc de démarrer.
Correction immédiate : sudo nano /etc/nginx/sites-available/default (gzip_type -> gzip_types), sudo nginx -t, sudo systemctl start nginx, curl -I http://localhost -> 200.
Correction durable : toujours lancer nginx -t avant tout reload ; gérer la config nginx par un rôle Ansible avec le module template et validate: nginx -t -c %s, pour qu'une config invalide ne soit jamais déployée.
Détection : alerte Prometheus sur l'indisponibilité du service nginx (unité systemd en échec via node_exporter) ou sonde HTTP du site en échec pendant 2 minutes.
