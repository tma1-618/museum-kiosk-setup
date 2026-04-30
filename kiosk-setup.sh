#!/bin/bash
# ============================================================
# MSI AIO Múzeumi Kiosk — Automatikus telepítő script
# Futtatás: sudo bash kiosk-setup.sh
# Feltétel: friss Ubuntu 22.04 LTS minimal install
# ============================================================

set -e

echo "=== Kiosk telepítő indul ==="
echo ""

# ------------------------------------------------------------
# Jelszó bekérése
# ------------------------------------------------------------
read -s -p "Adja meg a kiosk és mnm felhasználó jelszavát: " KIOSK_PASS
echo ""
read -s -p "Jelszó megerősítése: " KIOSK_PASS2
echo ""

if [ "$KIOSK_PASS" != "$KIOSK_PASS2" ]; then
    echo "HIBA: A két jelszó nem egyezik. Indítsd újra a scriptet."
    exit 1
fi

echo ""

# ------------------------------------------------------------
# 1. Rendszerfrissítés és csomagok
# ------------------------------------------------------------
echo "[1/8] Csomagok telepítése..."
apt update && apt upgrade -y
apt install --no-install-recommends openbox chromium-browser xorg xinit unclutter nginx -y

# ------------------------------------------------------------
# 2. Felhasználók jelszavának beállítása
# ------------------------------------------------------------
echo "[2/8] Felhasználók beállítása..."
echo "mnm:$KIOSK_PASS" | chpasswd

if ! id "kiosk" &>/dev/null; then
    useradd -m -s /bin/bash kiosk
fi
echo "kiosk:$KIOSK_PASS" | chpasswd

# ------------------------------------------------------------
# 3. /opt/kiosk mappa
# ------------------------------------------------------------
echo "[3/8] /opt/kiosk mappa létrehozása..."
mkdir -p /opt/kiosk
chown -R kiosk:kiosk /opt/kiosk
chmod -R 755 /opt/kiosk

# ------------------------------------------------------------
# 4. GDM autologin
# ------------------------------------------------------------
echo "[4/8] GDM autologin beállítása..."
cat > /etc/gdm3/custom.conf << 'EOF'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=kiosk
EOF

# ------------------------------------------------------------
# 5. AccountsService — Openbox session
# ------------------------------------------------------------
echo "[5/8] Session beállítása (Openbox)..."
cat > /var/lib/AccountsService/users/kiosk << 'EOF'
[User]
Session=openbox
XSession=openbox
SystemAccount=false
EOF

# ------------------------------------------------------------
# 6. Kiosk felhasználó konfigurációs fájljai
# ------------------------------------------------------------
echo "[6/8] Kiosk felhasználó konfigurációja..."

cat > /home/kiosk/.xinitrc << 'EOF'
#!/bin/bash
xset s off
xset -dpms
xset s noblank
unclutter -idle 0.1 -root &
exec openbox-session
EOF

cat > /home/kiosk/.bash_profile << 'EOF'
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  startx
fi
EOF

mkdir -p /home/kiosk/.config/openbox
cat > /home/kiosk/.config/openbox/autostart << 'EOF'
chromium-browser \
  --kiosk \
  --no-first-run \
  --disable-translate \
  --disable-infobars \
  --disable-suggestions-service \
  --disable-save-password-bubble \
  --touch-events=enabled \
  --disable-pinch \
  --overscroll-history-navigation=0 \
  http://localhost/index.html &
EOF

chown -R kiosk:kiosk /home/kiosk/.xinitrc
chown -R kiosk:kiosk /home/kiosk/.bash_profile
chown -R kiosk:kiosk /home/kiosk/.config
chmod +x /home/kiosk/.xinitrc

# ------------------------------------------------------------
# 7. Nginx
# ------------------------------------------------------------
echo "[7/8] Nginx konfigurálása..."
cat > /etc/nginx/sites-available/kiosk << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /opt/kiosk;
    index index.html;
}
EOF

ln -sf /etc/nginx/sites-available/kiosk /etc/nginx/sites-enabled/kiosk
rm -f /etc/nginx/sites-enabled/default
systemctl enable nginx
systemctl restart nginx

# ------------------------------------------------------------
# 8. Systemd watchdog
# ------------------------------------------------------------
echo "[8/8] Watchdog service beállítása..."
cat > /etc/systemd/system/kiosk-watchdog.service << 'EOF'
[Unit]
Description=Kiosk Chromium watchdog
After=graphical.target

[Service]
User=kiosk
Environment=DISPLAY=:0
Restart=always
RestartSec=3
ExecStart=/usr/bin/chromium-browser \
  --kiosk \
  --no-first-run \
  --disable-translate \
  --disable-infobars \
  --touch-events=enabled \
  --disable-pinch \
  http://localhost/index.html

[Install]
WantedBy=graphical.target
EOF

systemctl enable kiosk-watchdog

# ------------------------------------------------------------
# Ellenőrzés
# ------------------------------------------------------------
echo ""
echo "=== Telepítés kész ==="
echo ""
echo "Nginx ellenőrzés:"
curl -s -o /dev/null -w "HTTP státusz: %{http_code}\n" http://localhost/ || echo "FIGYELEM: nginx nem válaszol — másold be a tartalmat az /opt/kiosk/ mappába."
echo ""
echo "Következő lépések:"
echo "  1. Másold az installáció fájljait az /opt/kiosk/ mappába:"
echo "     sudo chown -R kiosk:kiosk /opt/kiosk/"
echo "  2. sudo reboot"
echo ""
