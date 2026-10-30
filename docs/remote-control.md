# Android remote (KDE Connect)

1. Install **KDE Connect** on the phone:
   [Google Play](https://play.google.com/store/apps/details?id=org.kde.kdeconnect_tp) ·
   [F-Droid](https://f-droid.org/packages/org.kde.kdeconnect_tp/)
2. Put the phone and LibreKiosk on the same network.
3. Open the app, tap the LibreKiosk device, **Request pairing**; accept on the TV (notification from the
   KDE Connect tray icon).
4. Use **Remote input** (touchpad + keyboard, also sends text to Brave) and **Multimedia control**.

Voice dictation: use the microphone key of the Android keyboard while in Remote input.
Disable with `kdeconnect.enabled: false`. If a firewall is added, allow TCP/UDP 1714–1764.
