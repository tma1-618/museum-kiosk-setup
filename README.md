# Museum Kiosk Setup

Automated setup script for Ubuntu-based interactive museum kiosk systems with touchscreen support.

## Overview

This project provides a minimal, stable kiosk stack for museum interactive installations running on x86 hardware. The setup replaces a full desktop environment with a lean, purpose-built configuration that boots directly into a fullscreen Chromium browser.

**Stack:**
- Ubuntu 22.04 LTS (minimal install)
- Openbox (window manager)
- Chromium (kiosk mode)
- nginx (local web server)
- systemd watchdog (auto-restart on crash)

## Requirements

- Hardware: x86 touchscreen AIO (tested on MSI PRO H610 AP222T)
- OS: Fresh Ubuntu 22.04 LTS minimal install
- The interactive content must be a self-contained HTML/CSS/JS application

## Usage

```bash
sudo bash kiosk-setup.sh
```

The script will:
1. Ask for a password (used for both `mnm` and `kiosk` users)
2. Install all required packages
3. Configure autologin, Openbox session, and Chromium kiosk mode
4. Set up nginx to serve content from `/opt/kiosk/`
5. Enable a systemd watchdog service

After the script finishes, copy your content into `/opt/kiosk/` and reboot:

```bash
sudo chown -R kiosk:kiosk /opt/kiosk/
sudo reboot
```

## Content Structure

Place your interactive content in `/opt/kiosk/`. The entry point must be `index.html`.

```
/opt/kiosk/
  index.html
  css/
  js/
  assets/
```

## Touch Event Notes

This setup is optimized for touch input. If your HTML application uses drag interactions, use the **Pointer Events API** with `setPointerCapture` instead of the HTML5 Drag & Drop API or separate mouse/touch event listeners:

```javascript
element.addEventListener('pointerdown', onDragStart)
element.addEventListener('pointermove', onDragMove)
element.addEventListener('pointerup', onDragEnd)
element.setPointerCapture(e.pointerId)
```

## Cloning to Multiple Machines

Once tested, use Clonezilla to create a disk image and deploy to additional machines:

1. Boot from Clonezilla live USB
2. **device-to-image** — save the image
3. **image-to-device** — restore to each target machine

> If the target disk is larger, run `sudo resize2fs /dev/sda1` after cloning.

## Files

| File | Description |
|---|---|
| `kiosk-setup.sh` | Automated setup script |
| `README.md` | This file (English) |
| `README.hu.md` | Full documentation in Hungarian |

## License

MIT
