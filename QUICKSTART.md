# Quick Start Guide - Database Update Configuration

## Configurare Rapidă

### Pasul 1: Alege Metoda de Update

```bash
# În update_avideo.sh, găsește secțiunea:
# ============================================================================
# DATABASE UPDATE CONFIGURATION
# ============================================================================

# Activează update-ul automat:
ENABLE_DB_UPDATE="yes"
```

### Pasul 2A: Configurare Metoda HTTP (Recomandată)

```bash
DB_UPDATE_METHOD="http"

# Adaugă URL-urile pentru fiecare domeniu
DOMAIN_BASE_URLS["/home/teentwerk/public_html"]="https://example.com"
DOMAIN_BASE_URLS["/home/teentwerk/domains/sexotube.us/public_html"]="https://sexotube.us"
# ... continuă pentru toate domeniile

# Dacă ai autentificare activată:
AUTH_METHOD="basic"
ADMIN_USER="admin"
ADMIN_PASS="parola_ta"
```

**SAU**

### Pasul 2B: Configurare Metoda SQL

```bash
DB_UPDATE_METHOD="sql"

# Opțiune 1: Setează credențialele manual
DB_USER="root"
DB_PASS="parola_mysql"
DB_NAMES["/home/teentwerk/public_html"]="avideo_db1"
DB_NAMES["/home/teentwerk/domains/sexotube.us/public_html"]="avideo_db2"

# Opțiune 2: Lasă gol și scriptul va citi din videos/configuration.php
# Scriptul va extrage: $mysqlUser, $mysqlPass, $mysqlDatabase
# Exemplu în configuration.php:
#   $mysqlUser = 'your_mysql_user';
#   $mysqlPass = 'your_secure_password_here';
#   $mysqlDatabase = 'your_database_name';
```

## Exemplu Complet de Configurare

### Exemplu 1: HTTP pentru 3 domenii

```bash
#!/bin/bash
# ... (restul scriptului)

DIRECTOARE=(
    "/home/user1/public_html"
    "/home/user2/public_html"
    "/home/user3/public_html"
)

# Activare update DB
ENABLE_DB_UPDATE="yes"
DB_UPDATE_METHOD="http"

# Configure URLs
DOMAIN_BASE_URLS["/home/user1/public_html"]="https://site1.com"
DOMAIN_BASE_URLS["/home/user2/public_html"]="https://site2.com"
DOMAIN_BASE_URLS["/home/user3/public_html"]="https://site3.com"

# Authentication
AUTH_METHOD="basic"
ADMIN_USER="admin"
ADMIN_PASS="secure_password_here"
```

### Exemplu 2: SQL Direct cu auto-detect credentials

```bash
#!/bin/bash
# ... (restul scriptului)

DIRECTOARE=(
    "/home/user1/public_html"
    "/home/user2/public_html"
)

# Activare update DB
ENABLE_DB_UPDATE="yes"
DB_UPDATE_METHOD="sql"

# Lasă gol - credențialele vor fi extrase din videos/configuration.php
DB_USER=""
DB_PASS=""
# Lasă gol - numele DB vor fi extrase din videos/configuration.php
declare -A DB_NAMES
```

### Exemplu 3: SQL Direct cu credențiale manuale

```bash
#!/bin/bash
# ... (restul scriptului)

DIRECTOARE=(
    "/home/user1/public_html"
    "/home/user2/public_html"
)

# Activare update DB
ENABLE_DB_UPDATE="yes"
DB_UPDATE_METHOD="sql"

# Credențiale MySQL
DB_USER="root"
DB_PASS="mysql_root_password"

# Baze de date
DB_NAMES["/home/user1/public_html"]="avideo_site1"
DB_NAMES["/home/user2/public_html"]="avideo_site2"
```

## Testare

### Test 1: Verifică sintaxa scriptului

```bash
bash -n update_avideo.sh
```

### Test 2: Rulează pe un singur domeniu (pentru testare)

```bash
# Comentează toate directoarele din DIRECTOARE exceptând unul
DIRECTOARE=(
    "/home/user1/public_html"
    # "/home/user2/public_html"  # comentat pentru testare
    # "/home/user3/public_html"  # comentat pentru testare
)

# Rulează scriptul
./update_avideo.sh
```

### Test 3: Verifică log-ul

```bash
# Vezi ultimele linii din log
tail -50 update_avideo.log

# Caută erori specifice
grep -i "error\|failed" update_avideo.log
grep -i "database update" update_avideo.log
```

## Troubleshooting Rapid

### Eroare: "Could not extract database credentials"

**Soluție:**
```bash
# Verifică dacă fișierul de configurare există
ls -la /home/user1/public_html/videos/configuration.php

# SAU setează manual credențialele:
DB_USER="root"
DB_PASS="password"
DB_NAMES["/home/user1/public_html"]="database_name"
```

### Eroare: "Failed to update database via HTTP"

**Soluție:**
```bash
# Testează manual URL-ul
curl -I https://site1.com/view/update.php

# Verifică autentificarea
curl -u admin:password https://site1.com/view/update.php
```

### Warning: "Database already up to date"

**Normal!** Înseamnă că nu sunt update-uri noi de aplicat.

## Backup Înainte de Update

**IMPORTANT**: Întotdeauna fă backup!

```bash
#!/bin/bash
# Script simplu de backup

DATE=$(date +%Y%m%d_%H%M%S)

# Backup bază de date
mysqldump -u root -p database_name > backup_db_${DATE}.sql

# Backup fișiere
tar -czf backup_files_${DATE}.tar.gz /home/user1/public_html

echo "Backup complet: backup_db_${DATE}.sql și backup_files_${DATE}.tar.gz"
```

## Automatizare cu Cron

```bash
# Editează crontab
crontab -e

# Adaugă pentru rulare zilnică la 3 AM cu backup
0 3 * * * /usr/local/bin/backup_script.sh && /home/user/update_avideo.sh >> /var/log/avideo_update.log 2>&1
```

## Securitate

### Nu include credențiale în Git!

Creează un fișier separat pentru credențiale:

**credentials.conf**
```bash
DB_USER="root"
DB_PASS="password"
ADMIN_USER="admin"
ADMIN_PASS="password"
```

**În update_avideo.sh**
```bash
# Încarcă credențialele
if [ -f ./credentials.conf ]; then
    source ./credentials.conf
fi
```

**În .gitignore**
```
credentials.conf
*.log
```

## Monitorizare

### Script de monitorizare status

```bash
#!/bin/bash
# check_update_status.sh

if grep -q "❌" update_avideo.log; then
    echo "ALERT: Update-uri eșuate detectate!"
    grep "❌" update_avideo.log | tail -10
    exit 1
else
    echo "OK: Toate update-urile au reușit"
    exit 0
fi
```

## Suport

Pentru întrebări sau probleme:
1. Verifică README.md pentru documentație completă
2. Verifică update_avideo.log pentru detalii erori
3. Creează un issue pe GitHub cu:
   - Output complet din terminal
   - Ultimele 100 linii din update_avideo.log
   - Versiune AVIDEO
