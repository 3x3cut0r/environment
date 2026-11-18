---
name: code-comments
description: "Use when writing or reviewing comments in source code, scripts, and configuration files. Enforces that a comment describes the code itself (purpose, contract, invariant, general rationale) instead of the task, ticket, bug, or fix that produced it. Trigger on adding inline comments, explaining a change or workaround, documenting a magic value, or reviewing a diff for comment quality. Do NOT use for README files, user documentation, commit messages, or changelogs - those may reference a change, but comments must not."
compatibility: opencode
---

# Rolle
Kommentare im Code sind dauerhafte Dokumentation des Codes, nicht der Sitzung,
in der er entstanden ist. Sie muessen auch dann noch stimmen, wenn die aktuelle
Aufgabe erledigt ist, wenn ein anderer Fehler auftritt oder wenn der Code
anders verwendet wird.

# Grundregel
Ein Kommentar beschreibt, was der Code tut und warum er so aussieht - als
Eigenschaft des Systems. Er beschreibt nicht den Anlass, die Aufgabe oder den
Fix.

Nicht die Aufgabe ist die Begruendung, sondern der allgemeine technische
Zusammenhang. Konkret:

- Statt "Route, damit Donar erreichbar ist" -> "Route fuer externe Kommunikation".
- Statt "Forwarding, damit der Kunde X funktioniert" -> "Forwarding fuer Traffic
  zwischen den Namespaces".
- Statt "Warten, weil der Test sonst sporadisch fehlschlug" -> "Warten, bis der
  Dienst seinen Port geoeffnet hat".

# Verboten: aufgabenbezogene Kommentare
- Bezug auf Ticket, Issue oder Auftrag: "fixes #4711", "for ticket", "as
  requested", "per task", "siehe Aufgabe".
- Bezug auf den Anlass: "damit <Symptom> geht", "weil <Feature> nicht lief",
  "workaround for the <X> bug", "fix for <Fehler>".
- Bezug auf den Zeitpunkt der Aenderung: "neu", "jetzt", "aktuell", "bisher",
  "temporaer", "changed", "no longer".
- Rechtfertigung gegenueber dem Reviewer: "this is needed because ...",
  "must be here, otherwise ...", "do not remove".
- Ein einzelner Anwendungsfall als Begruendung, obwohl der Code allgemein gilt.
  Das Beispiel erklaert dann eine Situation, nicht die Regel.
- Nacherzaehlung der Entstehung: "route added so that X reaches Y",
  "second attempt, first one failed".

# Erlaubt: allgemeine Kommentare
- Zweck des Blocks in einem Satz: "default route for external traffic".
- Invariante oder Vertrag: "caller must hold the lock", "returns 0 on success",
  "address must be unique per namespace".
- Nicht offensichtliche technische Entscheidung: warum `replace` statt `add`,
  warum eine Reihenfolge eingehalten wird, warum eine Umgebungsvariable
  erhalten bleibt.
- Verweis auf das Gegenstueck: "removes the route created by setup-netns.sh".
- Bedeutung von Konstanten, Einheiten, Adressbereichen und Formaten, wenn sie
  nicht aus dem Code hervorgeht.

# Wann gar kein Kommentar
- Der Befehl ist selbsterklaerend (z. B. `ip link set <dev> up`).
- Der Kommentar wuerde den Code nur in Prosa wiederholen ("increment counter").
- Die Begruendung ist eine Aenderungshistorie - sie gehoert in Commit-Message,
  Merge Request oder Dokumentation.
- Auskommentierter Code wird geloescht, nicht kommentiert.

# Formulierung
- Praesens, Aussage ohne Ich/Wir und ohne Adressat.
- Keine Meta-Sprache ("note that", "TODO: changed in this fix").
- Sprache wie in der umgebenden Datei; in englischen Dateien englisch.
- So kurz wie moeglich: eine Zeile, wenn die Aussage passt; ein Block nur, wenn
  die Begruendung ihn braucht.
- Keine Wiederholung des Codes, sondern die fehlende Information.

# Pruefkriterien
Ein Kommentar ist in Ordnung, wenn alle drei Fragen mit "ja" beantwortet sind:

1. Bleibt er gueltig, wenn die aktuelle Aufgabe laengst abgeschlossen ist?
2. Stimmt er auch dann noch, wenn ein anderer Ausloeser denselben Code trifft?
3. Erklaert er die Sache (Route, Dienst, Vertrag, Format) und nicht einen
   Einzelfall?

Bei "nein": allgemeiner formulieren oder streichen.

# Beispiele

| Aufgabenbezogen | Allgemein |
|---|---|
| `# wait, otherwise the login test fails` | `# wait until the service has opened its port` |
| `# added for ticket 4711` | kein Kommentar |
| `# route so that client X reaches Y` | `# default route for external traffic` |
| `# keep this, the customer needs it` | `# config is read at startup only, so restart is required` |
