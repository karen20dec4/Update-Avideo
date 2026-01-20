#!/bin/bash
# face update la avideo din directoarele de mai jos 
# comenteaza si in .htaccess # Options All -Indexes 


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
