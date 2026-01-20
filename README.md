# AVIDEO Update Script

Acest script automatizează procesul de actualizare AVIDEO pentru multiple domenii/directoare.

## Funcționalități

### Actualizare Fișiere
- ✅ Actualizare automată fișiere prin `git pull`
- ✅ Restaurare `.htaccess` înaintea update-ului
- ✅ Comentare automată linie `Options All -Indexes` în `.htaccess`
- ✅ Bară de progres în timp real
- ✅ Indicatori de status pentru fiecare domeniu (✅ success, ⚠️ warning, ❌ error)
- ✅ Raport final structurat cu statistici

### Actualizare Bază de Date (NOUA FUNCȚIONALITATE)
- ✅ Actualizare automată bază de date după update fișiere
- ✅ Două metode disponibile: HTTP și SQL direct
- ✅ Tracking erori și warnings pentru update-uri DB
- ✅ Extragere automată credențiale din `videos/configuration.php`

## Configurare

### 1. Configurare Directoare

Editați variabila `DIRECTOARE` din script cu path-urile către instalările AVIDEO:

```bash
DIRECTOARE=(
    "/home/teentwerk/public_html"
    "/home/teentwerk/domains/sexotube.us/public_html"
    # ... alte directoare
)
```

### 2. Configurare Update Bază de Date (Opțional)

#### Metoda 1: HTTP (Recomandată)

Această metodă apelează interfața web `update.php` pentru fiecare domeniu.

```bash
# Activare update bază de date
ENABLE_DB_UPDATE="yes"
DB_UPDATE_METHOD="http"

# Configurare URL-uri domenii
DOMAIN_BASE_URLS["/home/teentwerk/public_html"]="https://example.com"
DOMAIN_BASE_URLS["/home/teentwerk/domains/sexotube.us/public_html"]="https://sexotube.us"

# Autentificare (dacă este necesară)
AUTH_METHOD="basic"
ADMIN_USER="admin"
ADMIN_PASS="parola_sigura"
```

**Avantaje:**
- Folosește mecanismul oficial AVIDEO de update
- Nu necesită acces direct la baza de date
- Mai sigur pentru producție

#### Metoda 2: SQL Direct

Această metodă rulează direct fișierele `.sql` din directorul `updatedb`.

```bash
# Activare update bază de date
ENABLE_DB_UPDATE="yes"
DB_UPDATE_METHOD="sql"

# Opțiunea 1: Lasă gol și credențialele vor fi extrase automat din videos/configuration.php
# Scriptul va căuta variabilele: $mysqlUser, $mysqlPass, $mysqlDatabase
DB_USER=""
DB_PASS=""
declare -A DB_NAMES

# Opțiunea 2: Setează manual credențiale și baze de date
DB_USER="root"
DB_PASS="parola_mysql"
DB_NAMES["/home/teentwerk/public_html"]="avideo_db1"
DB_NAMES["/home/teentwerk/domains/sexotube.us/public_html"]="avideo_db2"
```

**Exemplu configurație în videos/configuration.php:**
```php
$mysqlHost = 'localhost';
$mysqlPort = '3306';
$mysqlUser = 'your_mysql_user';
$mysqlPass = 'your_secure_password_here';
$mysqlDatabase = 'your_database_name';
```

**Avantaje:**
- Mai rapid
- Nu necesită acces web
- Extrage automat credențialele din `videos/configuration.php` dacă nu sunt setate manual

**Notă:** Scriptul va rula automat toate fișierele `updateDb.v*.sql` în ordine secvențială (v1.0, v1.1, v2.0, etc).

## Utilizare

### Rulare Script

```bash
# Fă scriptul executabil (doar prima dată)
chmod +x update_avideo.sh

# Rulează scriptul
./update_avideo.sh
```

### Output Exemplu

```
╔═══════════════════════════════════════════════════════════╗
║           AVIDEO Update Script - Starting                 ║
╚═══════════════════════════════════════════════════════════╝

Progress: [████████████░░░░] 60% (3/5)

[✅] teentwerk/public_html - Success
[❌] sextubeteen.com/public_html - git pull failed
[⚠️] sitevideosex.com/public_html - .htaccess missing

╔═══════════════════════════════════════════════════════════╗
║                    FINAL SUMMARY                          ║
╚═══════════════════════════════════════════════════════════╝

✅ SUCCESS (2 domains - 40%):
   • teentwerk/public_html
   
⚠️ WARNINGS (1 domains - 20%):
   • sitevideosex.com/public_html - .htaccess missing
   
❌ ERRORS (1 domains - 20%):
   • sextubeteen.com/public_html - git pull failed
```

## Log File

Toate detaliile sunt salvate în `update_avideo.log`:
- Timestampuri pentru fiecare operațiune
- Output complet `git pull`
- Detalii erori și warnings
- Rezultate update bază de date (dacă este activat)

## Securitate

⚠️ **IMPORTANT:**

1. **Backup**: Întotdeauna fă backup la baza de date înainte de a activa update-ul automat!
   ```bash
   mysqldump -u root -p database_name > backup_$(date +%Y%m%d).sql
   ```

2. **Credențiale**: Nu include credențiale în script dacă este versionat în Git!
   - Folosește fișiere de configurare externe
   - Sau setează variabilele de mediu

3. **Testare**: Testează întâi pe un mediu de staging!

4. **Permisiuni**: Asigură-te că scriptul are permisiunile corecte:
   ```bash
   chmod 700 update_avideo.sh  # Doar owner poate citi/scrie/executa
   ```

## Troubleshooting

### Eroare: "Directory not found"
- Verifică că path-urile din `DIRECTOARE` sunt corecte
- Verifică permisiunile de acces

### Eroare: "git pull failed"
- Verifică că directorul este un repository git valid
- Verifică conflicte: `cd /path/to/dir && git status`
- Rulează manual: `git fetch --all && git reset --hard origin/master`

### Eroare: "Database update failed"
- Verifică credențialele MySQL
- Verifică că directorul `updatedb` există
- Verifică că utilizatorul MySQL are permisiuni suficiente
- Verifică log-ul pentru detalii: `tail -100 update_avideo.log`

### Warning: ".htaccess missing"
- Normal dacă instalația nu folosește `.htaccess`
- Nu împiedică update-ul să continue

## Automatizare cu Cron

Pentru a rula scriptul automat (ex: zilnic la 3 AM):

```bash
# Editează crontab
crontab -e

# Adaugă linia:
0 3 * * * /path/to/update_avideo.sh >> /var/log/avideo_cron.log 2>&1
```

## Contribuții

Pull requests și sugestii sunt binevenite!

## Licență

Vezi fișierul LICENSE pentru detalii.
