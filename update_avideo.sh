#!/bin/bash
# face update la avideo din directoarele de mai jos 
# comenteaza si in .htaccess # Options All -Indexes 


# Culori pentru terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

{
    echo "================================================="
    echo "Data: $(date +"%d %B %H:%M")"
    echo "Pornim update pentru ${#DIRECTOARE[@]} directoare..."

    for TARGET_DIR in "${DIRECTOARE[@]}"; do
        echo "--------------------------------------------------"
        echo "Procesăm: $TARGET_DIR"

        if [ ! -d "$TARGET_DIR" ]; then
            echo "❌ Eroare: Directorul $TARGET_DIR nu există!"
            echo -e "\a"
            ((FAIL_COUNT++))
            continue
        fi

        if ! cd "$TARGET_DIR"; then
            echo "❌ Eroare: Nu pot intra în $TARGET_DIR"
            echo -e "\a"
            ((FAIL_COUNT++))
            continue
        fi

        echo "- Restaurăm .htaccess..."
        if git ls-files --error-unmatch .htaccess >/dev/null 2>&1; then
            if ! git checkout -- .htaccess; then
                echo "⚠️ Eroare la git checkout .htaccess"
                echo -e "\a"
            fi
        else
            echo "⚠️ .htaccess nu este urmărit de git. Sărim peste restore."
        fi

        echo "- Executăm git pull..."
        if ! git pull; then
            echo "❌ Eroare la git pull în $TARGET_DIR"
            echo -e "\a"
        fi

        HTACCESS="$TARGET_DIR/.htaccess"
        if [ -f "$HTACCESS" ]; then
            echo "- Comentăm linia 'Options All -Indexes' în .htaccess..."
            if sed -i 's/^\([[:space:]]*\)Options All -Indexes/\1# Options All -Indexes/' "$HTACCESS"; then
                echo "✔️ Linia comentată cu succes."
            else
                echo "❌ Eroare la comentarea liniei în .htaccess"
                echo -e "\a"
            fi
        else
            echo "⚠️ .htaccess nu există în $TARGET_DIR"
        fi

        echo "- Update complet pentru: $TARGET_DIR"
        ((SUCCESS_COUNT++))
    done

    echo "================================================="
    echo "✔️ Directoare procesate cu succes: $SUCCESS_COUNT"
    echo "❌ Directoare cu erori: $FAIL_COUNT"
	echo ""
	echo ""
} >> "$LOG_FILE" 2>&1

# Afișăm sumarul și în terminal cu culori
echo -e "${GREEN}✔️ Directoare procesate cu succes: $SUCCESS_COUNT${NC} >>> pentru detalii vezi update_avideo.log"
echo -e "${RED}❌ Directoare cu erori: $FAIL_COUNT${NC}"
