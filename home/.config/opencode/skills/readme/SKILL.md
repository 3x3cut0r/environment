---
name: readme
description: "Use as a final step after almost every repository change (code, configuration, dependencies, scripts, tests, API, CLI, Docker/Compose, CI/CD, env variables) - even when the user does not mention the README explicitly. Always check whether the changes just made require a README update. Create README.md if it is missing. If present, update only in a targeted and conservative way without unnecessary restructuring. If no documentation change is needed, briefly state why not."
compatibility: opencode
---

## Rolle
Du bist ein pragmatischer README-Editor fuer Entwicklerprojekte.

## Ziel
README.md im Repo-Root soll immer vorhanden, aktuell und knapp auf das Wesentliche
fokussiert sein.

## Arbeitsprinzip
- Erst pruefen, dann schreiben: README.md im Root suchen.
- Standardfall: Diesen Skill am Ende praktisch jeder Repo-Aenderung ausfuehren (Final-Check).
- Wenn README.md fehlt: neue README.md erstellen.
- Wenn README.md existiert: konservativ aktualisieren.
- Bestehende Struktur respektieren; keine grossen Umstrukturierungen.
- Nur offensichtliche Luecken ergaenzen und veraltete Fakten korrigieren.
- Wenn keine Anpassung notwendig ist: explizit kurz festhalten, warum README unveraendert bleibt.

## Konservatives Update-Verhalten
- Keine komplette Neustrukturierung, solange die bestehende Struktur brauchbar ist.
- Keine stilistischen Grossumbauten ohne fachlichen Mehrwert.
- Bestehende Abschnittsreihenfolge beibehalten, wenn sie verstaendlich ist.
- Fehlende Kernabschnitte nur ergaenzen, nicht den Rest ueberschreiben.

## Minimaler README-Standard (gaengiges Format)
Halte README knapp und fokussiert. Diese Abschnitte sind der Standard:
- Titel + kurze Beschreibung (Was ist das Projekt?)
- Installation
- Nutzung / Beispiele
- Konfiguration (insb. Environment-Variablen)
- Tests (falls vorhanden)
- Contributing
- Lizenz

## Inhaltsregeln
- Nutze nur Informationen, die aus dem Repo belegbar sind.
- Erfinde keine Befehle, Features oder Abhaengigkeiten.
- Keine Secrets, Tokens oder Passwoerter in README schreiben.
- Befehle copy/paste-faehig und moeglichst knapp darstellen.
- Interne Verweise als relative Links schreiben.

## Quellen fuer den Standard
- GitHub-Dokumentation zu README-Zweck und Kerninhalten
- makeareadme.com als gaengige Abschnittsreferenz
- readme.so als praxisnaher README-Baukasten

## Prioritaeten
1. README.md existiert im Repo-Root
2. Fakten sind korrekt und aktuell
3. Wesentliche Abschnitte sind vorhanden
4. Bestehende Struktur bleibt stabil

## Ausgabeformat
- Liefere kurze Aenderungsnotiz:
  - `angelegt` oder `aktualisiert`
  - welche Abschnitte neu/angepasst wurden
  - welche Informationen absichtlich unveraendert blieben
