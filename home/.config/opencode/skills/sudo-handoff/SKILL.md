---
name: sudo-handoff
description: "Use whenever a task needs root privileges and sudo cannot run non-interactively (password prompt, no TTY, EACCES/permission denied, root-owned configs, systemctl, apt/dpkg, ufw/firewalld/nft/iptables, mount, nmcli system connections, writes under /etc, /var or /usr, dmesg, privileged network or USB work). Instead of only printing commands, always create an executable helper script under /tmp containing the full command sequence, split into read-only preflight, mutating apply and verify, logging every command and its exit code to a logfile the agent reads afterwards. Tell the user the exact sudo invocation and the log path. Also use when a command just failed with permission denied. Do NOT use when the command already works as the current user, when sudo -n succeeds, or for interactive tools that cannot be scripted (passwd, visudo, editors, mysql -p) - print those commands and explain instead."
compatibility: opencode
---

# Rolle

Du uebergibst privilegierte Arbeit als ausfuehrbares Script, nicht als
Copy-Paste-Block. Der User fuehrt genau einen Befehl aus; die Ausgabe landet in
einem Log, das du danach selbst liest. Damit entfaellt beides: das Kopieren der
Befehle und das Zurueckkopieren der Ausgabe.

# Wann dieser Skill greift

- Ein Schritt braucht root, und `sudo -n` schlaegt fehl (Passwort noetig).
- Ein Befehl scheitert mit `Permission denied` / `EACCES`, oder eine Datei ist
  root-owned und read-only.
- Typische Faelle: `systemctl`, `apt`/`dpkg`, `ufw`/`firewalld`/`nft`/`iptables`,
  `mount`, `nmcli` auf System-Connections, Schreiben unter `/etc`, `/var`,
  `/usr`, `dmesg`, `journalctl` ohne passende Gruppe, Netzwerk-/USB-Setup.
- Die eigene Umgebung hat fuer einen privilegierten Schritt keine Shell.

Nicht anwenden, wenn der Befehl als aktueller User bereits laeuft, wenn
`sudo -n true` erfolgreich ist, oder bei interaktiven Werkzeugen, die sich nicht
sinnvoll skripten lassen (`passwd`, `visudo`, Editoren, `mysql -p`): dort den
Befehl nennen, erklaeren, warum kein Script sinnvoll ist, und den User machen
lassen.

# Grundsaetze

1. **Chat ist die Anleitung, das Script ist das Artefakt.** Beides zeigen, aber
   nur einmal pflegen: die im Chat gezeigten Befehle muessen exakt denen im
   Script entsprechen. Kein Chat-Befehl, der im Script fehlt, und umgekehrt.
2. **Ein Script pro Aufgabe**, nicht pro Befehl. Read-only-Vorpruefung,
   Aenderung und Verifikation gehoeren zusammen.
3. **Ohne Log kein Handoff.** Das Script muss seine Ausgabe so schreiben, dass
   du sie anschliessend ohne Rueckfrage lesen kannst.
4. **Keine Secrets im Script.** Es laeuft als root und bleibt auf der Platte.

# Ablauf

## 1. Privileg pruefen

```bash
sudo -n true 2>/dev/null && echo "sudo-ok" || echo "sudo-needs-password"
```

Bei `sudo-ok` normal ausfuehren, kein Script noetig. Sonst weiter mit Schritt 2.

## 2. Script aus dem Template erzeugen

```bash
cp ~/.config/opencode/skills/sudo-handoff/assets/sudo-script-template.sh \
   /tmp/opencode-<slug>-<UTCstamp>.sh
```

- `<slug>`: 2-4 Woerter, kebab-case, aufgabenbezogen (`nm-shared-dhcp`,
  `fix-apt-lock`). Keine Secrets, keine personenbezogenen Daten im Dateinamen.
- `<UTCstamp>`: `date -u +%Y%m%dT%H%M%SZ`.
- Wiederholung derselben Aufgabe: `-r2`, `-r3` anhaengen, alte Datei behalten.

Danach ausschliesslich die drei Funktionskoerper `preflight()`, `apply()` und
`verify()` fuellen. Das Geruest (Logging, Guards, Zaehler, Summary) bleibt
unveraendert.

## 3. Script validieren (ohne root moeglich)

```bash
bash -n /tmp/opencode-<slug>-<stamp>.sh
shellcheck -S warning /tmp/opencode-<slug>-<stamp>.sh
chmod 0700 /tmp/opencode-<slug>-<stamp>.sh
test -x /tmp/opencode-<slug>-<stamp>.sh && echo executable
```

Ein Script, das `bash -n` nicht besteht, wird nicht uebergeben. Shellcheck-
Findings beheben oder im Chat begruenden.

## 4. Uebergabe an den User

Format (kurz halten, keine komplette Script-Wiedergabe):

```text
Script  : /tmp/opencode-<slug>-<stamp>.sh
Ausfuehren: sudo /tmp/opencode-<slug>-<stamp>.sh
Nur pruefen: sudo /tmp/opencode-<slug>-<stamp>.sh --check
Log     : /tmp/opencode-<slug>-<stamp>.log
Wirkung : read-only | mutating: <was genau>
Rollback: <Befehl> | nicht noetig
Dauer   : ~<n> s
```

Danach die Befehle kompakt auflisten, gruppiert nach `PREFLIGHT`, `APPLY`,
`VERIFY`. Bei mutating zusaetzlich in einem Satz das Risiko nennen (was sich
aendert, was unberuehrt bleibt, was bei Abbruch passiert).

Wenn `/tmp` mit `noexec` gemountet ist, lautet der Aufruf
`sudo bash /tmp/opencode-<slug>-<stamp>.sh`; das im Handoff als Fallback
erwaehnen.

## 5. Log auswerten

Sobald der User meldet, dass das Script gelaufen ist ("done", "fertig",
"gelaufen", "hier ist nichts passiert"): das Log sofort mit `read` oeffnen, ohne
nach einem Paste zu fragen.

- `SUMMARY`-Zeile und Exit-Code zuerst berichten.
- Jede Zeile mit `[FAIL rc=` einzeln erklaeren.
- `[SKIP]` bedeutet: bewusste Sperre, nicht Fehler.
- Fehlt das Log, wurde das Script nicht ausgefuehrt - das sagen, nicht raten.
- Danach entscheiden: Aufgabe erledigt, oder Nachfolge-Script `-r2`.

## 6. Aufraeumen

Nach erfolgreicher Auswertung und ohne geplanten zweiten Lauf: Script und Log
loeschen und das kurz erwaehnen. Bei Fehlern beides behalten; das naechste
Script als `-r2` erzeugen, damit die Historie nachvollziehbar bleibt.

# Script-Anforderungen

- Shebang `#!/usr/bin/env bash`, `set -u`, `umask 077`. Bewusst **kein**
  `set -e` (ein Fehler soll die restlichen Checks nicht verschlucken) und
  **kein** `pipefail` (Pipelines auf `head`/`grep -q` wuerden SIGPIPE als
  Fehler melden). Die Begruendung steht im Template-Header.
- Kein `sudo` im Script - es laeuft bereits als root. Fuer Schritte, die als
  aufrufender User laufen muessen:
  `run soft "..." -- runuser -u "$SUDO_USER" -- <cmd>`.
- `run crit "<desc>" -- <cmd>` fuer Schritte, von denen spaetere abhaengen;
  `run soft ...` fuer alles andere.
- `require_cmd` vor externen Werkzeugen aufrufen, nicht blind vertrauen.
- Read-only-`preflight` zuerst, dann `apply`, dann `verify` mit dem erwarteten
  Wert als Kommentar.
- `confirm_destructive "<was>"` als `if`-Bedingung um irreversible Schritte
  legen; Freigabe erfolgt ueber `sudo CONFIRM=yes /tmp/...`.
- Config-Dateien vor Aenderung sichern:
  `cp -a -- <file> <file>.bak-$(date +%Y%m%d%H%M%S)`.
- `timeout 10` fuer Netzwerk-, Download- und Ping-Schritte, damit der Lauf nicht
  haengt. Bei laenger laufenden Aenderungen (apt-upgrade, grosse Kopien) den
  User auf `tmux`/`nohup` hinweisen und das Log nennen.
- Absolute Pfade verwenden. Beachte: unter `sudo` ist `$HOME` = `/root`; niemals
  ungepruefte `~`-Pfade des Users im Script verwenden.
- Keine `rm -rf`, keine Globs beim Loeschen, kein `find -delete`, kein
  `sed -i` auf unbekannte Dateien.
- Keine `env`-/`printenv`-Dumps, kein `cat` von Keys, Tokens oder Credentials.
- Idempotent, wo es geht. Wenn nicht idempotent: im Header vermerken und
  Rollback angeben.
- Header-Kommentar vollstaendig fuellen: Purpose, Impact, Rollback, Usage.
- Kommentare und Ausgaben englisch, ASCII.

# Namens- und Logkonvention

| Element | Regel |
|---|---|
| Script | `/tmp/opencode-<slug>-<YYYYmmddTHHMMSSZ>.sh`, Modus `0700` |
| Log | gleicher Basename mit `.log`, Modus `0600` |
| Owner | aufrufender User (`SUDO_USER`), auch wenn root schreibt |
| Secrets | nie im Script, nie im Dateinamen |

Das Template setzt Besitzer und Rechte des Logs selbst: es legt das Log als
root an, uebergibt es sofort an `SUDO_USER` und finalisiert die Rechte nach dem
`tee`-Lauf. Genau deshalb kannst du das Log ohne `sudo` lesen.

# Sicherheitsregeln

- Das Script laeuft als root: kurz, reviewbar, keine unnoetigen Downloads oder
  Fremdquellen.
- Nur die betroffenen Dienste/Interfaces anfassen. Beispiel: ein DHCP-Script
  darf niemals auf `eno1`, `vmnet8` oder `docker0` lauschen - solche
  Einschraenkungen gehoeren explizit in den Script-Kommentar und in `verify`.
- Keine Credentials. Wenn ein Secret noetig ist: `read -rs` im Script, niemals
  echoen, oder den User den Wert selbst eingeben lassen.
- Vor `apply` sagen, ob ein Rollback existiert. Wenn nicht: das ausdruecklich
  als Risiko benennen.

# Beispiel: Befehle fuellen

```bash
preflight() {
  section "PREFLIGHT (read-only)"
  require_cmd nmcli ip
  run soft "current device state" -- nmcli -f DEVICE,STATE,CONNECTION device status
  run soft "expected: 192.168.77.0/24 is unused" -- ip -4 route show
}

apply() {
  section "APPLY (mutating)"
  run crit "create shared profile" -- nmcli connection add \
    type ethernet ifname enx00116b73a4c8 con-name usb-lan-share \
    ipv4.method shared ipv4.addresses 192.168.77.1/24 ipv6.method ignore
}

verify() {
  section "VERIFY"
  run soft "expect 192.168.77.1/24" -- ip -4 addr show enx00116b73a4c8
  run soft "expect ip_forward=1" -- sysctl net.ipv4.ip_forward
  run soft "expect no wildcard DHCP listener" -- ss -lunp 'sport = :67'
}
```

# Anti-Muster

- Nur einen Codeblock mit `sudo ...` in den Chat schreiben und auf Paste hoffen.
- Den User nach der Log-Ausgabe fragen, obwohl das Log auf der Platte liegt.
- Ein Script ohne Log, ohne Exit-Code-Behandlung oder ohne Summary abgeben.
- `sudo`-Aufrufe im Script, oder `$HOME` des Users unter `sudo` verwenden.
- Secrets, Tokens oder private Schluessel in Script oder Log schreiben.
- Interaktive Tools erzwingen wollen (`passwd`, `visudo`, `nano`) oder `apt`
  ohne `DEBIAN_FRONTEND=noninteractive` starten.
- Ein mutierendes Script als "harmlos" verkaufen, ohne Rollback und ohne
  Nennung der betroffenen Dienste.
