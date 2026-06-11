# Synthese - Projet conteneurisation B2

**Sujet:** mise en place d'une infrastructure conteneurisee avec serveurs web, base de donnees, sauvegardes securisees, resilience et tests de panne.  
**Date:** 21/05/2026

## 1. Architecture mise en place

L'infrastructure est deployee avec Docker Compose et contient les services suivants:

| Service | Role | Technologie |
|---|---|---|
| `web1` | Premier serveur web | Nginx |
| `web2` | Deuxieme serveur web | Nginx |
| `db` | Base de donnees applicative | PostgreSQL |
| `lb` | Repartition de charge / reverse proxy | Nginx |
| `backup` | Serveur dedie aux sauvegardes | SSH + Restic |
| `backup-client` | Execution automatique des sauvegardes | Restic + cron |

Les deux serveurs web affichent des pages differentes: `Serveur Web 1` et `Serveur Web 2`. Ils peuvent aussi interroger la base PostgreSQL grace au script `/usr/local/bin/check_db.sh` present dans chaque conteneur web.

La base `appdb` contient une table `messages` avec quelques lignes de test. Les serveurs web peuvent interroger cette table avec une commande `psql`, ce qui valide l'interaction minimale entre le web et la base de donnees.

## 2. Strategie de sauvegarde

La strategie de sauvegarde repose sur Restic. Les donnees sauvegardees sont:

- les fichiers HTML du serveur `web1`;
- les fichiers HTML du serveur `web2`;
- un dump logique de la base PostgreSQL au format `appdb.dump`;
- un fichier `backup_time.txt` permettant d'identifier la date de la sauvegarde.

Les sauvegardes sont envoyees vers le serveur `backup` avec le backend SFTP de Restic:

```text
sftp:backup@backup:/backups/restic-repo
```

Une sauvegarde automatique est planifiee toutes les 5 minutes avec cron:

```cron
*/5 * * * * /usr/local/bin/backup_all.sh >> /var/log/backup.log 2>&1
```

Une sauvegarde manuelle peut aussi etre lancee avec:

```bash
bash scripts/backup_now.sh
```

## 3. Securisation des sauvegardes

Plusieurs mesures de securite sont appliquees:

| Mesure | Description |
|---|---|
| Chiffrement | Restic chiffre nativement les snapshots avec `RESTIC_PASSWORD`. |
| Transport securise | Les sauvegardes sont transferees par SSH/SFTP. |
| Authentification | Le serveur de sauvegarde accepte uniquement une cle SSH. |
| Acces limite | Seul l'utilisateur `backup` est autorise a se connecter. |
| Durcissement SSH | Connexion root et authentification par mot de passe desactivees. |
| Permissions | Le repertoire `/backups` est protege par des droits restrictifs. |

Dans un contexte de production, le mot de passe Restic devrait etre stocke dans un gestionnaire de secrets, et les sauvegardes devraient aussi etre repliquees hors site.

## 4. Mecanisme de resilience choisi

Le mecanisme de resilience choisi est un load balancer Nginx en reverse proxy. Le service `lb` expose le port `8080` sur la machine hote et distribue les requetes entre `web1` et `web2`.

Configuration logique:

```text
Client -> Load balancer Nginx -> web1 / web2
```

Le load balancer utilise un groupe upstream Nginx:

```nginx
upstream web_backend {
  server web1:80 max_fails=1 fail_timeout=5s;
  server web2:80 max_fails=1 fail_timeout=5s;
}
```

Si un serveur web tombe, le load balancer continue de servir l'application avec l'autre serveur web disponible.

## 5. Tests de panne

### Scenario 1 - Panne du serveur web `web1`

Commande utilisee:

```bash
bash scripts/incident_stop_web1.sh
```

Actions du script:

1. arret du conteneur `web1`;
2. interrogation du load balancer;
3. calcul du RTO en millisecondes;
4. verification que le service reste disponible via `web2`;
5. redemarrage automatique de `web1`, sauf si `KEEP_DOWN=yes` est defini.

Resultat attendu:

| Indicateur | Resultat |
|---|---|
| Disponibilite | Le service reste disponible via `web2`. |
| RTO | Quelques secondes ou moins selon la machine hote. |
| RPO | 0, car aucune donnee n'est perdue et aucune restauration n'est necessaire. |

### Scenario 2 - Panne de la base PostgreSQL

Commande utilisee:

```bash
bash scripts/incident_stop_db.sh
```

Resultat attendu:

| Indicateur | Resultat |
|---|---|
| Front web | Les pages statiques restent accessibles. |
| Acces SQL | Les requetes vers PostgreSQL echouent tant que la base est arretee. |
| RPO | Maximum 5 minutes avec le cron fourni, ou moins si une sauvegarde manuelle vient d'etre lancee. |

Ce scenario montre la limite du choix effectue: la resilience web est assuree, mais la haute disponibilite de la base necessiterait une replication PostgreSQL.

## 6. Restauration complete

La restauration des fichiers depuis le dernier snapshot se fait avec:

```bash
bash scripts/restore_latest.sh
```

Le contenu restaure est place dans:

```text
/restore/latest
```

Pour restaurer aussi la base PostgreSQL depuis le dump Restic:

```bash
docker compose exec -e CONFIRM_DB_RESTORE=yes backup-client /usr/local/bin/restore_latest.sh
```

Cette commande effectue un `pg_restore` du dump `appdb.dump` dans la base `appdb`.

## 7. RTO et RPO

| Element | Definition | Valeur dans ce projet |
|---|---|---|
| RTO web | Temps de retour du service web apres panne d'un serveur | Mesure par `incident_stop_web1.sh`; attendu: quelques secondes ou moins |
| RPO web | Donnees web perdues apres panne d'un serveur | 0 dans le scenario de panne `web1` |
| RTO base | Temps necessaire pour retrouver la base apres panne | Temps de redemarrage ou de restauration PostgreSQL |
| RPO base | Donnees perdues depuis la derniere sauvegarde | 5 minutes maximum avec le cron fourni |

## 8. Propositions d'amelioration

Les ameliorations possibles sont:

1. mettre en place une replication PostgreSQL primaire-secondaire pour supprimer le point de defaillance unique sur la base;
2. ajouter une supervision avec Prometheus et Grafana;
3. ajouter des alertes avec Alertmanager ou un outil equivalent;
4. centraliser les logs avec Loki, ELK ou OpenSearch;
5. externaliser les sauvegardes vers un stockage hors site;
6. utiliser des sauvegardes immuables pour mieux resister aux ransomwares;
7. automatiser le deploiement avec Ansible ou Terraform;
8. stocker les secrets dans Vault, Docker secrets ou un gestionnaire de secrets cloud;
9. ajouter des tests automatiques dans une pipeline CI/CD;
10. documenter une procedure de PRA plus complete avec objectifs RTO/RPO valides par metier.

## 9. Conclusion

Le projet met en place une infrastructure conteneurisee complete avec deux serveurs web, une base PostgreSQL, un load balancer Nginx, une sauvegarde chiffree Restic via SSH et des scripts de simulation de panne. Le choix de resilience couvre la couche web: si un serveur web tombe, le service reste disponible grace au second serveur. Les sauvegardes permettent de restaurer les fichiers web et la base de donnees avec un RPO theorique de 5 minutes.
