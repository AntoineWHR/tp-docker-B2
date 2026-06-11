# Projet conteneurisation B2

Ce depot contient une infrastructure Docker Compose complete pour le projet:

- deux serveurs web Nginx distincts: `web1` et `web2`;
- une base PostgreSQL avec une table de donnees;
- un load balancer Nginx en reverse proxy;
- un serveur de sauvegarde SSH dedie;
- un client de sauvegarde Restic avec cron automatique;
- des scripts de test de panne, de sauvegarde et de restauration.

## 1. Prerequis

Sur la machine hote:

- Docker;
- Docker Compose v2 (`docker compose`);
- Bash;
- `curl`;
- `ssh-keygen`.

## 2. Demarrage rapide

```bash
cd conteneurisation-b2
cp .env.example .env
bash scripts/start.sh
```

L'application est disponible sur:

```text
http://localhost:8080
```

Le port `8080` pointe vers le load balancer Nginx. Le serveur de sauvegarde expose aussi SSH sur le port hote `2222` pour verification manuelle si besoin.

## 3. Architecture

```text
                   http://localhost:8080
                            |
                            v
                    +----------------+
                    | Load balancer  |
                    | Nginx reverse  |
                    | proxy          |
                    +-------+--------+
                            |
              +-------------+-------------+
              |                           |
              v                           v
       +-------------+             +-------------+
       | Web 1       |             | Web 2       |
       | Nginx       |             | Nginx       |
       +------+------+             +------+------+
              |                           |
              +-------------+-------------+
                            |
                            v
                    +---------------+
                    | PostgreSQL    |
                    | appdb         |
                    +---------------+

       +------------------+      SSH/SFTP      +------------------+
       | Backup client    | -----------------> | Backup server    |
       | Restic + cron    |                    | SSH + Restic     |
       +------------------+                    +------------------+
```

## 4. Verification des serveurs web

Afficher plusieurs reponses du load balancer:

```bash
bash scripts/status.sh
```

En relancant plusieurs fois ou en rafraichissant `http://localhost:8080`, on voit les pages `Serveur Web 1` et `Serveur Web 2`.

## 5. Verification de l'acces base depuis les serveurs web

Chaque conteneur web contient un client PostgreSQL et un script de verification:

```bash
bash scripts/check_db_from_web.sh
```

Le script execute une requete SQL depuis `web1`, puis depuis `web2`, vers la table `messages`.

## 6. Sauvegardes Restic

Le serveur `backup` recoit les sauvegardes via SSH/SFTP. Le depot Restic est chiffre par le mot de passe `RESTIC_PASSWORD` defini dans `.env`.

Une sauvegarde automatique est planifiee toutes les 5 minutes par cron dans le conteneur `backup-client`:

```cron
*/5 * * * * /usr/local/bin/backup_all.sh >> /var/log/backup.log 2>&1
```

Lancer une sauvegarde manuelle:

```bash
bash scripts/backup_now.sh
```

Les donnees sauvegardees sont:

- `/data/web1`, contenu du serveur web 1;
- `/data/web2`, contenu du serveur web 2;
- un dump logique PostgreSQL au format custom: `appdb.dump`;
- un fichier `backup_time.txt` indiquant l'heure de la sauvegarde.

## 7. Securisation des sauvegardes

Mesures mises en place:

- chiffrement natif Restic du depot de sauvegarde;
- transfert par SSH/SFTP;
- authentification par cle SSH uniquement;
- `PasswordAuthentication no` dans le serveur SSH;
- `PermitRootLogin no`;
- acces limite a l'utilisateur `backup`;
- repertoire `/backups` avec permissions restrictives.

La cle SSH de test est generee localement par:

```bash
bash scripts/setup_ssh_keys.sh
```

Pour un vrai environnement, il faut remplacer cette cle de demonstration par une cle geree par l'administrateur et stocker `RESTIC_PASSWORD` dans un coffre de secrets.

## 8. Test de resilience web

Le projet choisit l'approche load balancer Nginx. Pour simuler la panne d'un serveur web:

```bash
bash scripts/incident_stop_web1.sh
```

Le script:

1. arrete `web1`;
2. interroge `http://localhost:8080` jusqu'au retour du service;
3. affiche le RTO mesure en millisecondes;
4. redemarre `web1`, sauf si `KEEP_DOWN=yes` est fourni.

Exemple pour laisser `web1` arrete:

```bash
KEEP_DOWN=yes bash scripts/incident_stop_web1.sh
```

Puis redemarrer manuellement:

```bash
docker compose start web1
```

## 9. Test de panne base de donnees

```bash
bash scripts/incident_stop_db.sh
```

Ce test montre que les pages web statiques peuvent rester disponibles, mais que les requetes SQL echouent tant que PostgreSQL est arrete. La haute disponibilite de la base n'est pas implementee ici, car le mecanisme de resilience choisi pour le sujet est le load balancing web.

## 10. Restauration

Restaurer le dernier snapshot dans le volume `/restore/latest` du conteneur `backup-client`:

```bash
bash scripts/restore_latest.sh
```

Importer aussi le dump restaure dans PostgreSQL:

```bash
docker compose exec -e CONFIRM_DB_RESTORE=yes backup-client /usr/local/bin/restore_latest.sh
```

Cette commande est volontairement separee, car elle peut remplacer des donnees existantes dans la base.

## 11. Mesure RTO / RPO

| Scenario | Mesure | Resultat attendu |
|---|---:|---|
| Arret de `web1` | RTO | Service disponible via `web2` en quelques secondes ou moins selon la machine |
| Arret de `web1` | RPO | 0, car les pages restent disponibles et aucune restauration n'est requise |
| Arret de `db` | RTO | Le front statique reste disponible, mais l'acces SQL est interrompu |
| Arret de `db` | RPO | Maximum 5 minutes avec le cron fourni, ou moins apres une sauvegarde manuelle |
| Restauration complete | RTO | Temps de restauration Restic + import PostgreSQL |

## 12. Commandes utiles

```bash
# Voir les conteneurs
docker compose ps

# Voir les logs du load balancer
docker compose logs -f lb

# Voir les logs de sauvegarde
docker compose exec backup-client tail -f /var/log/backup.log

# Lister les snapshots Restic
bash scripts/backup_now.sh

# Arreter tout et supprimer les volumes
bash scripts/clean.sh
```

## 13. Nettoyage

```bash
bash scripts/clean.sh
```

Cette commande supprime les conteneurs, les volumes Docker et les cles SSH de demonstration.
