#!/bin/bash
# ============================================================================
# AVIDEO Update Script - Automatic File & Database Updates
# ============================================================================
# This script updates AVIDEO software in multiple directories and optionally
# updates the database after file updates.
#
# Features:
# - Updates AVIDEO files via git pull
# - Comments out 'Options All -Indexes' in .htaccess
# - Progress bar with real-time status indicators
# - Detailed error tracking and reporting
# - Optional automatic database updates
#
# ============================================================================
# DATABASE UPDATE CONFIGURATION
# ============================================================================
# To enable automatic database updates, set ENABLE_DB_UPDATE="yes" below
# and configure one of the two available methods:
#
# METHOD 1 - HTTP (Recommended):
#   - Calls the web interface update.php for each domain
#   - Configure DOMAIN_BASE_URLS with your domain URLs
#   - Example:
#       ENABLE_DB_UPDATE="yes"
#       DB_UPDATE_METHOD="http"
#       DOMAIN_BASE_URLS["/home/teentwerk/public_html"]="https://example.com"
#       ADMIN_USER="admin"
#       ADMIN_PASS="password"
#
# METHOD 2 - Direct SQL:
#   - Runs SQL files from updatedb directory directly
#   - Automatically reads DB credentials from videos/configuration.php
#     (looks for $mysqlUser, $mysqlPass, $mysqlDatabase variables)
#   - Or set DB_USER, DB_PASS, and DB_NAMES manually
#   - Example:
#       ENABLE_DB_UPDATE="yes"
#       DB_UPDATE_METHOD="sql"
#       # Leave empty to auto-extract from configuration.php
#       DB_USER=""
#       DB_PASS=""
#       # Or set manually:
#       DB_USER="root"
#       DB_PASS="password"
#       DB_NAMES["/home/teentwerk/public_html"]="avideo_db"
#
# WARNING: Always backup your database before enabling automatic updates!
# ============================================================================


# Culori pentru terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # reset

DIRECTOARE=(
	"/home/teentwerk/public_html"
	"/home/teentwerk/domains/sexotube.us/public_html"
	"/home/teentwerk/domains/sextubeteen.com/public_html"
	"/home/teentwerk/domains/sitevideosex.com/public_html"
	"/home/teentwerk/domains/xlovehub.com/public_html"


	"/home/excitube/public_html"
	"/home/excitube/domains/8teentube.us/public_html"
	"/home/excitube/domains/evasexycam.com/public_html"
	
	
	"/home/direct2sensation/public_html"
	"/home/direct2sensation/domains/boudoirlive.net/public_html"
	"/home/direct2sensation/domains/erotiquex.com/public_html"
	"/home/direct2sensation/domains/fillelive.com/public_html"
	"/home/direct2sensation/domains/hotchatsexe.com/public_html"
	"/home/direct2sensation/domains/hotchatsexy.com/public_html"
	"/home/direct2sensation/domains/hotlivesexy.com/public_html"
	"/home/direct2sensation/domains/paris-live-show.com/public_html"
#	"/home/direct2sensation/domains/venuslivecam.com/public_html"
	
)

LOG_FILE="update_avideo.log"
SUCCESS_COUNT=0
FAIL_COUNT=0
WARNING_COUNT=0

# Arrays to track domain status
declare -a SUCCESS_DOMAINS
declare -a WARNING_DOMAINS
declare -a ERROR_DOMAINS
declare -A DOMAIN_ERRORS

# ============================================================================
# DATABASE UPDATE CONFIGURATION
# ============================================================================
# Enable automatic database updates after file updates (yes/no)
ENABLE_DB_UPDATE="no"

# Database update method: "http" or "sql"
# - "http": Calls the web interface update.php (requires ADMIN_USER/ADMIN_PASS or AUTH_TOKEN)
# - "sql": Runs SQL files directly from updatedb directory (requires DB_USER/DB_PASS/DB_NAME)
DB_UPDATE_METHOD="http"

# HTTP Method Configuration (for method="http")
# Base URL for each domain (will append /view/update.php or your custom path)
# Example: DOMAIN_BASE_URLS["/home/teentwerk/public_html"]="https://example.com"
declare -A DOMAIN_BASE_URLS

# Authentication method: "basic" or "session"
AUTH_METHOD="basic"
ADMIN_USER=""
ADMIN_PASS=""
# Or use session token if available
AUTH_TOKEN=""

# SQL Method Configuration (for method="sql")
# Database credentials can be read from configuration file or set here
DB_USER=""
DB_PASS=""
# Database names for each directory (if different per domain)
declare -A DB_NAMES
# Example: DB_NAMES["/home/teentwerk/public_html"]="avideo_db1"

# Path to configuration file containing DB credentials (optional)
# The script will try to read from videos/configuration.php if this is empty
CONFIG_FILE=""

# ============================================================================
# DATABASE UPDATE FUNCTIONS
# ============================================================================

# Helper function to extract value from PHP configuration file
extract_php_config_value() {
    local config_file=$1
    local var_name=$2
    
    # Extract value from PHP variable (supports both single and double quotes)
    # Format: $variableName = 'value'; or $variableName = "value";
    grep -oP "\\\$$var_name\s*=\s*'\K[^']*" "$config_file" 2>/dev/null || \
    grep -oP "\\\$$var_name\s*=\s*\"\K[^\"]*" "$config_file" 2>/dev/null
}

# Function to extract database credentials from AVideo configuration.php
extract_db_credentials() {
    local target_dir=$1
    local config_file="$target_dir/videos/configuration.php"
    
    {
        echo ""
        echo "=== EXTRACTING DB CREDENTIALS ==="
        echo "Target directory: $target_dir"
        echo "Configuration file: $config_file"
    } >> "$LOG_FILE"
    
    if [ ! -f "$config_file" ]; then
        {
            echo "❌ Configuration file not found: $config_file"
            echo "=== EXTRACTION FAILED ==="
        } >> "$LOG_FILE"
        return 1
    fi
    
    {
        echo "✔️ Configuration file exists"
        echo ""
        echo "Attempting to extract MySQL variables..."
    } >> "$LOG_FILE"
    
    # Extract database credentials from PHP configuration file
    # Variable names: $mysqlUser, $mysqlPass, $mysqlDatabase
    local extracted_user=$(extract_php_config_value "$config_file" "mysqlUser")
    local extracted_pass=$(extract_php_config_value "$config_file" "mysqlPass")
    local extracted_db=$(extract_php_config_value "$config_file" "mysqlDatabase")
    local extracted_host=$(extract_php_config_value "$config_file" "mysqlHost")
    
    {
        echo "Extraction results:"
        echo "  mysqlHost:     ${extracted_host:-[NOT FOUND]}"
        echo "  mysqlUser:     ${extracted_user:-[NOT FOUND]}"
        echo "  mysqlPass:     ${extracted_pass:+[FOUND - hidden for security]}"
        [ -z "$extracted_pass" ] && echo "  mysqlPass:     [NOT FOUND]"
        echo "  mysqlDatabase: ${extracted_db:-[NOT FOUND]}"
        echo ""
    } >> "$LOG_FILE"
    
    # Debug: Show first 50 lines of config file to help diagnose issues
    if [ -z "$extracted_user" ] || [ -z "$extracted_pass" ] || [ -z "$extracted_db" ]; then
        {
            echo "⚠️ Some values not found. Showing lines containing 'mysql' from config file:"
            grep -in "mysql" "$config_file" 2>/dev/null | head -20 || echo "  No lines containing 'mysql' found in file"
            echo ""
        } >> "$LOG_FILE"
    fi
    
    # Use extracted values if not already set globally
    if [ -z "$DB_USER" ] && [ -n "$extracted_user" ]; then
        DB_USER="$extracted_user"
        {
            echo "✔️ Set DB_USER from config: $DB_USER"
        } >> "$LOG_FILE"
    elif [ -n "$DB_USER" ]; then
        {
            echo "ℹ️ Using globally configured DB_USER: $DB_USER"
        } >> "$LOG_FILE"
    fi
    
    if [ -z "$DB_PASS" ] && [ -n "$extracted_pass" ]; then
        DB_PASS="$extracted_pass"
        {
            echo "✔️ Set DB_PASS from config (hidden)"
        } >> "$LOG_FILE"
    elif [ -n "$DB_PASS" ]; then
        {
            echo "ℹ️ Using globally configured DB_PASS"
        } >> "$LOG_FILE"
    fi
    
    # Set database name for this directory
    if [ -n "$extracted_db" ]; then
        DB_NAMES["$target_dir"]="$extracted_db"
        {
            echo "✔️ Set database name for $target_dir: $extracted_db"
            echo "=== EXTRACTION SUCCESSFUL ==="
        } >> "$LOG_FILE"
        return 0
    fi
    
    {
        echo "❌ Could not extract database name from configuration"
        echo "=== EXTRACTION FAILED ==="
    } >> "$LOG_FILE"
    return 1
}

# Function to update database via HTTP (calls update.php)
update_database_http() {
    local target_dir=$1
    local base_url="${DOMAIN_BASE_URLS[$target_dir]}"
    
    if [ -z "$base_url" ]; then
        {
            echo "⚠️ No base URL configured for $target_dir, skipping DB update"
        } >> "$LOG_FILE"
        return 1
    fi
    
    local update_url="$base_url/view/update.php"
    
    {
        echo "- Updating database via HTTP: $update_url"
    } >> "$LOG_FILE"
    
    # Make HTTP request to trigger database update
    if [ "$AUTH_METHOD" = "basic" ] && [ -n "$ADMIN_USER" ] && [ -n "$ADMIN_PASS" ]; then
        if curl -s -f -u "$ADMIN_USER:$ADMIN_PASS" "$update_url" >> "$LOG_FILE" 2>&1; then
            {
                echo "✔️ Database updated successfully via HTTP"
            } >> "$LOG_FILE"
            return 0
        fi
    elif [ -n "$AUTH_TOKEN" ]; then
        if curl -s -f -H "Authorization: Bearer $AUTH_TOKEN" "$update_url" >> "$LOG_FILE" 2>&1; then
            {
                echo "✔️ Database updated successfully via HTTP"
            } >> "$LOG_FILE"
            return 0
        fi
    else
        if curl -s -f "$update_url" >> "$LOG_FILE" 2>&1; then
            {
                echo "✔️ Database updated successfully via HTTP"
            } >> "$LOG_FILE"
            return 0
        fi
    fi
    
    {
        echo "❌ Failed to update database via HTTP"
    } >> "$LOG_FILE"
    return 1
}

# Function to update database via SQL files
update_database_sql() {
    local target_dir=$1
    local updatedb_dir="$target_dir/updatedb"
    
    {
        echo ""
        echo "=== SQL DATABASE UPDATE ==="
        echo "Target directory: $target_dir"
        echo "updatedb directory: $updatedb_dir"
    } >> "$LOG_FILE"
    
    if [ ! -d "$updatedb_dir" ]; then
        {
            echo "⚠️ updatedb directory not found in $target_dir"
            echo "=== SQL UPDATE SKIPPED ==="
        } >> "$LOG_FILE"
        return 1
    fi
    
    {
        echo "✔️ updatedb directory exists"
    } >> "$LOG_FILE"
    
    # Extract DB credentials if not set
    {
        echo ""
        echo "Checking database credentials..."
        echo "Current DB_USER: ${DB_USER:-[not set]}"
        echo "Current DB_PASS: ${DB_PASS:+[set - hidden]}"
        [ -z "$DB_PASS" ] && echo "Current DB_PASS: [not set]"
    } >> "$LOG_FILE"
    
    if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
        {
            echo "Credentials not set globally, attempting extraction..."
        } >> "$LOG_FILE"
        
        if ! extract_db_credentials "$target_dir"; then
            {
                echo "❌ Could not extract database credentials from configuration"
                echo "=== SQL UPDATE FAILED ==="
            } >> "$LOG_FILE"
            return 1
        fi
    else
        {
            echo "✔️ Using globally configured credentials"
        } >> "$LOG_FILE"
        
        # Still need to get database name from config
        local config_file="$target_dir/videos/configuration.php"
        if [ -f "$config_file" ]; then
            local extracted_db=$(extract_php_config_value "$config_file" "mysqlDatabase")
            if [ -n "$extracted_db" ]; then
                DB_NAMES["$target_dir"]="$extracted_db"
                {
                    echo "✔️ Extracted database name: $extracted_db"
                } >> "$LOG_FILE"
            fi
        fi
    fi
    
    local db_name="${DB_NAMES[$target_dir]}"
    {
        echo ""
        echo "Final credentials check:"
        echo "  DB_USER: ${DB_USER:-[NOT SET]}"
        echo "  DB_PASS: ${DB_PASS:+[SET - hidden]}"
        [ -z "$DB_PASS" ] && echo "  DB_PASS: [NOT SET]"
        echo "  DB_NAME: ${db_name:-[NOT SET]}"
    } >> "$LOG_FILE"
    
    if [ -z "$db_name" ]; then
        {
            echo ""
            echo "❌ Database name not configured for $target_dir"
            echo "   DB_NAMES array contents:"
            for key in "${!DB_NAMES[@]}"; do
                echo "     [$key] = ${DB_NAMES[$key]}"
            done
            echo "=== SQL UPDATE FAILED ==="
        } >> "$LOG_FILE"
        return 1
    fi
    
    {
        echo ""
        echo "✔️ All credentials available"
        echo "Starting SQL update process..."
        echo "- Database: $db_name"
        echo "- User: $DB_USER"
        echo "- updatedb directory: $updatedb_dir"
    } >> "$LOG_FILE"
    
    # Get current database version
    local current_version=$(MYSQL_PWD="$DB_PASS" mysql -u"$DB_USER" -s -N -e \
        "SELECT version FROM configurations WHERE id=1 LIMIT 1;" "$db_name" 2>/dev/null)
    
    {
        echo "- Current database version: ${current_version:-unknown}"
        echo ""
    } >> "$LOG_FILE"
    
    # Function to compare versions
    # Returns 0 if $1 > $2, 1 otherwise
    version_gt() {
        local ver1=$1
        local ver2=$2
        
        # If current version is unknown, skip all updates for safety
        if [ -z "$ver2" ] || [ "$ver2" = "unknown" ]; then
            return 1
        fi
        
        # Compare versions using sort -V
        test "$(printf '%s\n' "$ver1" "$ver2" | sort -V | head -n1)" != "$ver1"
    }
    
    # Find and run SQL update files in order
    local update_count=0
    local error_count=0
    local skipped_count=0
    
    shopt -s nullglob
    local sql_files=("$updatedb_dir"/updateDb.v*.sql)
    shopt -u nullglob
    
    # Sort files by version number
    IFS=$'\n' sql_files=($(sort -V <<<"${sql_files[*]}"))
    unset IFS
    
    {
        echo "Checking which updates need to be applied..."
        echo "Total SQL files found: ${#sql_files[@]}"
        echo ""
    } >> "$LOG_FILE"
    
    for sql_file in "${sql_files[@]}"; do
        local filename=$(basename "$sql_file")
        
        # Extract version from filename (e.g., updateDb.v2.5.sql -> 2.5)
        local file_version=$(echo "$filename" | grep -oP 'v\K[0-9.]+' | head -1)
        
        {
            echo "  - Checking: $filename (version $file_version)"
        } >> "$LOG_FILE"
        
        # Skip if current version is unknown (safety measure)
        if [ -z "$current_version" ] || [ "$current_version" = "unknown" ]; then
            {
                echo "    ⚠️ SKIPPED: Current database version is unknown - skipping all updates for safety"
                echo "    ℹ️ Please verify database version manually before running updates"
            } >> "$LOG_FILE"
            ((skipped_count++))
            continue
        fi
        
        # Skip if this update is older or equal to current version
        if ! version_gt "$file_version" "$current_version"; then
            {
                echo "    ⏭️  SKIPPED: Version $file_version <= current version $current_version (already applied)"
            } >> "$LOG_FILE"
            ((skipped_count++))
            continue
        fi
        
        {
            echo "    ▶️  APPLYING: Version $file_version > current version $current_version"
        } >> "$LOG_FILE"
        
        if MYSQL_PWD="$DB_PASS" mysql -u"$DB_USER" "$db_name" < "$sql_file" >> "$LOG_FILE" 2>&1; then
            ((update_count++))
            {
                echo "    ✔️ Applied successfully"
            } >> "$LOG_FILE"
        else
            ((error_count++))
            {
                echo "    ❌ Failed to apply - check error above"
            } >> "$LOG_FILE"
        fi
    done
    
    {
        echo ""
        echo "Update summary:"
        echo "  - Total files checked: ${#sql_files[@]}"
        echo "  - Skipped (already applied): $skipped_count"
        echo "  - Applied successfully: $update_count"
        echo "  - Failed: $error_count"
    } >> "$LOG_FILE"
    
    if [ $update_count -gt 0 ]; then
        {
            echo ""
            echo "✔️ Database updated: $update_count new updates applied"
        } >> "$LOG_FILE"
        return 0
    elif [ $error_count -gt 0 ]; then
        {
            echo ""
            echo "⚠️ Database update completed with errors: $error_count updates failed"
        } >> "$LOG_FILE"
        return 1
    else
        {
            echo ""
            echo "✔️ Database already up to date (no new updates to apply)"
        } >> "$LOG_FILE"
        return 0
    fi
}

# Main database update function
update_database() {
    local target_dir=$1
    
    if [ "$ENABLE_DB_UPDATE" != "yes" ]; then
        return 0
    fi
    
    {
        echo ""
        echo "=== DATABASE UPDATE ==="
    } >> "$LOG_FILE"
    
    if [ "$DB_UPDATE_METHOD" = "http" ]; then
        update_database_http "$target_dir"
        return $?
    elif [ "$DB_UPDATE_METHOD" = "sql" ]; then
        update_database_sql "$target_dir"
        return $?
    else
        {
            echo "❌ Invalid DB_UPDATE_METHOD: $DB_UPDATE_METHOD"
        } >> "$LOG_FILE"
        return 1
    fi
}

# Function to draw progress bar
draw_progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}Progress: [${NC}"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "${CYAN}] %3d%% (%d/%d)${NC}" "$percentage" "$current" "$total"
}

# Function to print domain status line
print_domain_status() {
    local status=$1
    local domain=$2
    local message=$3
    local short_domain="${domain#/home/}"
    
    case $status in
        "success")
            echo -e "[${GREEN}✅${NC}] ${short_domain} - ${GREEN}Success${NC}"
            ;;
        "error")
            echo -e "[${RED}❌${NC}] ${short_domain} - ${RED}${message}${NC}"
            ;;
        "warning")
            echo -e "[${YELLOW}⚠️${NC}] ${short_domain} - ${YELLOW}${message}${NC}"
            ;;
    esac
}

# Function to print box header
print_box_header() {
    local title=$1
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    printf "${BLUE}║${NC} %-57s ${BLUE}║${NC}\n" "$title"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
}

# Start logging
{
    echo "================================================="
    echo "Data: $(date +"%d %B %H:%M")"
    echo "Pornim update pentru ${#DIRECTOARE[@]} directoare..."
    echo "================================================="
    echo ""
} > "$LOG_FILE"

# Clear screen and show header
clear
print_box_header "AVIDEO Update Script - Starting"
echo ""

TOTAL_DIRS=${#DIRECTOARE[@]}
CURRENT_DIR=0

for TARGET_DIR in "${DIRECTOARE[@]}"; do
    ((CURRENT_DIR++))
    draw_progress_bar $CURRENT_DIR $TOTAL_DIRS
    echo ""
    echo ""
    
    HAS_ERROR=0
    HAS_WARNING=0
    ERROR_MSG=""
    
    {
        echo "--------------------------------------------------"
        echo "Procesăm ($CURRENT_DIR/$TOTAL_DIRS): $TARGET_DIR"
        echo "--------------------------------------------------"
    } >> "$LOG_FILE"

    if [ ! -d "$TARGET_DIR" ]; then
        ERROR_MSG="Directory not found"
        HAS_ERROR=1
        {
            echo "❌ Eroare: Directorul $TARGET_DIR nu există!"
            echo -e "\a"
        } >> "$LOG_FILE" 2>&1
        ERROR_DOMAINS+=("$TARGET_DIR")
        DOMAIN_ERRORS["$TARGET_DIR"]="$ERROR_MSG"
        ((FAIL_COUNT++))
        print_domain_status "error" "$TARGET_DIR" "$ERROR_MSG"
        continue
    fi

    if ! cd "$TARGET_DIR"; then
        ERROR_MSG="Cannot access directory"
        HAS_ERROR=1
        {
            echo "❌ Eroare: Nu pot intra în $TARGET_DIR"
            echo -e "\a"
        } >> "$LOG_FILE" 2>&1
        ERROR_DOMAINS+=("$TARGET_DIR")
        DOMAIN_ERRORS["$TARGET_DIR"]="$ERROR_MSG"
        ((FAIL_COUNT++))
        print_domain_status "error" "$TARGET_DIR" "$ERROR_MSG"
        continue
    fi

    {
        echo "- Restaurăm .htaccess..."
    } >> "$LOG_FILE"
    
    if git ls-files --error-unmatch .htaccess >/dev/null 2>&1; then
        if ! git checkout -- .htaccess >> "$LOG_FILE" 2>&1; then
            HAS_WARNING=1
            ERROR_MSG="git checkout .htaccess failed"
            {
                echo "⚠️ Eroare la git checkout .htaccess"
                echo -e "\a"
            } >> "$LOG_FILE"
        fi
    else
        HAS_WARNING=1
        if [ -z "$ERROR_MSG" ]; then
            ERROR_MSG=".htaccess not tracked by git"
        fi
        {
            echo "⚠️ .htaccess nu este urmărit de git. Sărim peste restore."
        } >> "$LOG_FILE"
    fi

    {
        echo "- Executăm git pull..."
    } >> "$LOG_FILE"
    
    if ! git pull >> "$LOG_FILE" 2>&1; then
        ERROR_MSG="git pull failed"
        HAS_ERROR=1
        {
            echo "❌ Eroare la git pull în $TARGET_DIR"
            echo -e "\a"
        } >> "$LOG_FILE"
    fi

    HTACCESS="$TARGET_DIR/.htaccess"
    if [ -f "$HTACCESS" ]; then
        {
            echo "- Comentăm linia 'Options All -Indexes' în .htaccess..."
        } >> "$LOG_FILE"
        
        if sed -i 's/^\([[:space:]]*\)Options All -Indexes/\1# Options All -Indexes/' "$HTACCESS" >> "$LOG_FILE" 2>&1; then
            {
                echo "✔️ Linia comentată cu succes."
            } >> "$LOG_FILE"
        else
            HAS_WARNING=1
            if [ -z "$ERROR_MSG" ]; then
                ERROR_MSG="Failed to comment .htaccess line"
            fi
            {
                echo "❌ Eroare la comentarea liniei în .htaccess"
                echo -e "\a"
            } >> "$LOG_FILE"
        fi
    else
        HAS_WARNING=1
        if [ -z "$ERROR_MSG" ]; then
            ERROR_MSG=".htaccess missing"
        fi
        {
            echo "⚠️ .htaccess nu există în $TARGET_DIR"
        } >> "$LOG_FILE"
    fi

    # Database update (if enabled)
    if [ "$ENABLE_DB_UPDATE" = "yes" ] && [ $HAS_ERROR -eq 0 ]; then
        {
            echo ""
            echo "=== DATABASE UPDATE ==="
        } >> "$LOG_FILE"
        
        if ! update_database "$TARGET_DIR"; then
            HAS_WARNING=1
            if [ -z "$ERROR_MSG" ]; then
                ERROR_MSG="Database update failed or incomplete"
            else
                ERROR_MSG="$ERROR_MSG, DB update failed"
            fi
        else
            {
                echo "=== DATABASE UPDATE COMPLETE ==="
            } >> "$LOG_FILE"
        fi
    fi

    # Determine final status
    if [ $HAS_ERROR -eq 1 ]; then
        ERROR_DOMAINS+=("$TARGET_DIR")
        DOMAIN_ERRORS["$TARGET_DIR"]="$ERROR_MSG"
        ((FAIL_COUNT++))
        print_domain_status "error" "$TARGET_DIR" "$ERROR_MSG"
        {
            echo "❌ Update EȘUAT pentru: $TARGET_DIR - $ERROR_MSG"
        } >> "$LOG_FILE"
    elif [ $HAS_WARNING -eq 1 ]; then
        WARNING_DOMAINS+=("$TARGET_DIR")
        DOMAIN_ERRORS["$TARGET_DIR"]="$ERROR_MSG"
        ((WARNING_COUNT++))
        print_domain_status "warning" "$TARGET_DIR" "$ERROR_MSG"
        {
            echo "⚠️ Update cu avertizări pentru: $TARGET_DIR - $ERROR_MSG"
        } >> "$LOG_FILE"
    else
        SUCCESS_DOMAINS+=("$TARGET_DIR")
        ((SUCCESS_COUNT++))
        print_domain_status "success" "$TARGET_DIR" ""
        {
            echo "✔️ Update complet pentru: $TARGET_DIR"
        } >> "$LOG_FILE"
    fi
    
    echo ""
done

# Final progress bar
draw_progress_bar $TOTAL_DIRS $TOTAL_DIRS
echo ""
echo ""

# Print final summary to console
echo ""
print_box_header "FINAL SUMMARY"
echo ""

if [ ${#SUCCESS_DOMAINS[@]} -gt 0 ]; then
    echo -e "${GREEN}${BOLD}✅ SUCCESS${NC} ${GREEN}(${SUCCESS_COUNT} domains - $((SUCCESS_COUNT * 100 / TOTAL_DIRS))%):${NC}"
    for domain in "${SUCCESS_DOMAINS[@]}"; do
        echo -e "   ${GREEN}•${NC} ${domain#/home/}"
    done
    echo ""
fi

if [ ${#WARNING_DOMAINS[@]} -gt 0 ]; then
    echo -e "${YELLOW}${BOLD}⚠️  WARNINGS${NC} ${YELLOW}(${WARNING_COUNT} domains - $((WARNING_COUNT * 100 / TOTAL_DIRS))%):${NC}"
    for domain in "${WARNING_DOMAINS[@]}"; do
        echo -e "   ${YELLOW}•${NC} ${domain#/home/} - ${DOMAIN_ERRORS[$domain]}"
    done
    echo ""
fi

if [ ${#ERROR_DOMAINS[@]} -gt 0 ]; then
    echo -e "${RED}${BOLD}❌ ERRORS${NC} ${RED}(${FAIL_COUNT} domains - $((FAIL_COUNT * 100 / TOTAL_DIRS))%):${NC}"
    for domain in "${ERROR_DOMAINS[@]}"; do
        echo -e "   ${RED}•${NC} ${domain#/home/} - ${DOMAIN_ERRORS[$domain]}"
    done
    echo ""
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Total: ${GREEN}${SUCCESS_COUNT} success${NC} | ${YELLOW}${WARNING_COUNT} warnings${NC} | ${RED}${FAIL_COUNT} errors${NC}"
echo -e "${CYAN}Detailed log: ${BOLD}${LOG_FILE}${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Write final summary to log file
{
    echo ""
    echo "================================================="
    echo "              FINAL SUMMARY"
    echo "================================================="
    echo ""
    echo "✔️ Directoare procesate cu succes: $SUCCESS_COUNT ($((SUCCESS_COUNT * 100 / TOTAL_DIRS))%)"
    if [ ${#SUCCESS_DOMAINS[@]} -gt 0 ]; then
        for domain in "${SUCCESS_DOMAINS[@]}"; do
            echo "   • $domain"
        done
    fi
    echo ""
    
    if [ ${#WARNING_DOMAINS[@]} -gt 0 ]; then
        echo "⚠️ Directoare cu avertizări: $WARNING_COUNT ($((WARNING_COUNT * 100 / TOTAL_DIRS))%)"
        for domain in "${WARNING_DOMAINS[@]}"; do
            echo "   • $domain - ${DOMAIN_ERRORS[$domain]}"
        done
        echo ""
    fi
    
    if [ ${#ERROR_DOMAINS[@]} -gt 0 ]; then
        echo "❌ Directoare cu erori: $FAIL_COUNT ($((FAIL_COUNT * 100 / TOTAL_DIRS))%)"
        for domain in "${ERROR_DOMAINS[@]}"; do
            echo "   • $domain - ${DOMAIN_ERRORS[$domain]}"
        done
        echo ""
    fi
    
    echo "================================================="
    echo ""
} >> "$LOG_FILE"
