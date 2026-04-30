# MSI AIO Múzeumi Kiosk — Telepítési útmutató

**Hardver:** MSI PRO H610 AP222T (érintőképernyős AIO)  
**Cél:** Ubuntu 22.04 LTS + Openbox + Chromium kiosk, nginx-szel kiszolgálva

---

## Automatikus telepítés (ajánlott)

A `kiosk-setup.sh` script elvégzi az összes lépést. Friss Ubuntu 22.04 LTS minimal install után:

```bash
sudo bash kiosk-setup.sh
```

A script futás elején bekéri a jelszót (kétszer, megerősítéssel) — ez lesz az `mnm` és a `kiosk` felhasználó közös jelszava. Hardcoded jelszó nincs a fájlban.

Ezután csak két manuális lépés marad:
1. Az installáció fájljainak másolása az `/opt/kiosk/` mappába
2. `sudo reboot`

---

## Manuális telepítés (lépésről lépésre)

### 1. Ubuntu 22.04 LTS telepítése

- Bootolj pendrive-ról
- Telepítési típus: **Minimal installation**
- Harmadik féltől származó driverek: **pipa be**
- Particionálás: **Erase disk and install Ubuntu**
- Locale: `en_US.UTF-8`
- Felhasználónév: `mnm`
- **Ne** kapcsold be a titkosítást

---

### 2. Rendszerfrissítés és szükséges csomagok

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install --no-install-recommends openbox chromium-browser xorg xinit unclutter nginx -y
```

---

### 3. Kiosk felhasználó létrehozása

```bash
sudo adduser kiosk
```

Adj meg jelszót, a többi kérdésre Enter.

---

### 4. /opt/kiosk mappa és jogosultságok

```bash
sudo mkdir -p /opt/kiosk
sudo chown -R kiosk:kiosk /opt/kiosk
sudo chmod -R 755 /opt/kiosk
```

---

### 5. GDM autologin beállítása

```bash
sudo nano /etc/gdm3/custom.conf
```

```ini
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=kiosk
```

---

### 6. Kiosk felhasználó session beállítása (Openbox)

```bash
sudo nano /var/lib/AccountsService/users/kiosk
```

```ini
[User]
Session=openbox
XSession=openbox
SystemAccount=false
```

---

### 7. Kiosk felhasználó konfigurációs fájljai

Váltj a kiosk felhasználóra:

```bash
sudo -u kiosk -i
```

**.xinitrc**

```bash
nano ~/.xinitrc
```

```bash
#!/bin/bash
xset s off
xset -dpms
xset s noblank
unclutter -idle 0.1 -root &
exec openbox-session
```

**.bash_profile**

```bash
nano ~/.bash_profile
```

```bash
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  startx
fi
```

**Openbox autostart**

```bash
mkdir -p ~/.config/openbox
nano ~/.config/openbox/autostart
```

```bash
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
```

Lépj vissza az admin felhasználóra:

```bash
exit
```

---

### 8. Nginx konfigurálása

```bash
sudo nano /etc/nginx/sites-available/kiosk
```

```nginx
server {
    listen 80;
    server_name localhost;
    root /opt/kiosk;
    index index.html;
}
```

```bash
sudo ln -s /etc/nginx/sites-available/kiosk /etc/nginx/sites-enabled/kiosk
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl enable nginx
sudo systemctl start nginx
```

Ellenőrzés:

```bash
curl http://localhost/
```

---

### 9. Systemd watchdog

```bash
sudo nano /etc/systemd/system/kiosk-watchdog.service
```

```ini
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
```

```bash
sudo systemctl enable kiosk-watchdog
```

---

### 10. Tartalom másolása és újraindítás

```bash
sudo cp -r /media/pendrive/kiosk/* /opt/kiosk/
sudo chown -R kiosk:kiosk /opt/kiosk/
sudo reboot
```

---

## Image készítése klónozáshoz

Ha az installáció tesztelve és rendben van:

1. Bootolj Clonezilla live pendrive-ról
2. **device-to-image** mód
3. Mentési célhely: külső HDD vagy hálózati megosztás
4. A klónozáskor: **image-to-device** mód, célgépenként ismételve

> **Megjegyzés:** Ha a célgép diszke nagyobb, klónozás után futtasd: `sudo resize2fs /dev/sda1`

---

## Gyors referencia — fontosabb elérési utak

| Fájl / könyvtár | Szerepe |
|---|---|
| `/opt/kiosk/` | Az installáció fájljai |
| `/home/kiosk/.config/openbox/autostart` | Chromium indítási paraméterek |
| `/home/kiosk/.xinitrc` | X szerver beállítások |
| `/etc/gdm3/custom.conf` | Autologin |
| `/etc/nginx/sites-available/kiosk` | Nginx konfig |
| `/var/lib/AccountsService/users/kiosk` | Session típus (Openbox) |
| `/etc/systemd/system/kiosk-watchdog.service` | Watchdog service |
