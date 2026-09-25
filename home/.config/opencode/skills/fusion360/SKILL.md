---
name: fusion360
description: "Nutze diesen Skill immer bei Autodesk-Fusion-360-Arbeiten ueber den offiziellen Fusion-Desktop-MCP-Server (Port 27182): Modell-Inspektion, Geometrie-Erstellung (Skizzen, Extrusionen, Boolesche Operationen, Patterns), Elektronik-Daten, Dokument-Operationen sowie Troubleshooting bei Verbindungsabbruechen oder eingefrorenem Server. Triggere bei allen Fusion-, CAD- und MCP-Themen rund um Autodesk Fusion."
compatibility: opencode
---

# Rolle
Du arbeitest mit dem offiziellen Autodesk Fusion MCP Server (Desktop, lokal in Fusion
integriert, Standard-Endpoint `http://127.0.0.1:27182/mcp`). Der Server ist
action-fokussiert und stellt KEINE granularen CAD-Tools bereit: Geometrie-Erstellung
erfolgt ausschliesslich ueber `fusion_mcp_execute` mit Fusion-API-Python-Scripts.
Das ist der offiziell vorgesehene Weg (nicht "selbst programmieren um den MCP herum").

# Verfuegbare Tools (Stand: dynamisch - bei Verbindung pruefen)
- `fusion_mcp_read` (queryType: `apiDocumentation`, `licensing`, `screenshot`,
  `document`, `projects`, `activeCommand`)
- `fusion_mcp_execute` (featureType: `script` - Fusion-API-Python mit readOnly-Flag,
  zudem `document`, `purchase`, `editImage`, `generatePowerpoint`, `previewImage`)
- `fusion_mcp_update` (nur `undo` / `redo`)
- `fusion_mcp_electronics_read` (Schematic/Board/Library, benoetigt Electronics-Dokument)

# Verbindlicher Workflow
1. **Doku zuerst:** Vor jedem Skript-Entwurf `fusion_mcp_read` mit
   `queryType: "apiDocumentation"` ziehen und die benoetigten API-Objekte pruefen.
   KEIN Trial-and-Error-Skripten ohne Doku-Lookup.
2. **Ist-Zustand pruefen:** Vor jeder Mutation Zustand read-only ermitteln
   (Body-Anzahl, Namen, BBox, Volumen, Timeline-Features, ungespeicherte Aenderungen).
   Macht Aenderungen idempotent und wiederholbar.
3. **Ein Task pro Anfrage/Session** (offizielle Best Practice). Pro Mutationsschritt
   ein Script; keine Sammel-Scripts mit vielen Operationen.
4. **Nach jeder Mutation verifizieren:** read-only Script mit erwarteten Werten
   (Body-Anzahl, BBox, Volumen-Toleranz +/-10%).
5. **Undo-Kette sauber halten:** Bei Fehlversuchen sofort `fusion_mcp_update` (undo)
   ausfuehren, Skript korrigieren, erneut ausfuehren. Niemals kaputte Zwischenzustaende
   stehen lassen.
6. **Dokument speichern:** Erst nach vollstaendiger Verifikation speichern
   (`fusion_mcp_execute`, featureType `document`). Vor grossen Mutationen Rollback-Punkt
   schaffen (speichern), wenn der User nichts anderes sagt.

# Einheiten und API-Konventionen
- Fusion-interne Einheiten sind **cm**, Modelle/Doku oft **mm** -> Faktor 10 beachten.
- Body-Kollektion des Root-Components: `bRepBodies` (nicht `bodies`) in dieser
  API-Version.
- Extrusion nach unten: negative Distanz, z. B. `ValueInput.createByReal(-0.4)` fuer
  -4 mm.
- `readOnly:true`-Scripts werden vom Server erzwungen read-only ausgefuehrt; fuer
  Mutationen `readOnly:false` setzen.

# Stolperfallen (aus Praxis-Sessions, als Checkliste)
- **Skizzen-Profil-Partitionierung:** Ueberlappende Rechtecke in einer Skizze werden
  von Fusion in Zell-Profile partitioniert (z. B. 11 Streben-Rechtecke -> 99 Profile,
  Extrusion fuellt die ganze Flaeche statt der Streben-Vereinigung). Loesung:
  Aussenkontur + Luecken-Rechtecke zeichnen und das correcte (groesste) Profil
  extrudieren, oder Profilflaechen vor Extrusion pruefen.
- **Koinzidente Flaechen beim Combine:** Target- und Tool-Bodies mit bündigen Flaechen
  (z. B. beide bei Z=0) koennen Join-Fehler verursachen. Fallback: Tool-Body per
  MoveFeature +0.5 mm ueberlappen lassen, dann erneut kombinieren.
- **Session-Keep-Alive ~5 s:** Bei `RemoteDisconnected`/Session-Timeout die MCP-Session
  neu initialisieren und idempotent wiederholen (zustand vorher read-only pruefen).
- **Server-Freeze moeglich:** Port lauscht weiter, aber Verbindungen werden sofort
  geschlossen. Remedien: Preferences > General > API > Fusion MCP Server togglen
  oder Fusion sauber neu starten. Vorher ungespeicherte Aenderungen sichern!
- **Port-Abweichung:** Fusion kann einen ephemeralen Port statt 27182 waehlen ->
  Disconnect direkt nach initialize. Port in Preferences > General > API pruefen.
- **Timeline-abhaengige Attribute:** `sketch.referencePlane` auf einer BRepFace ist
  erst nach Timeline-Rollback lesbar. Rollback nur wenn explizit erlaubt/noetig.
- **Kamera/Ansicht:** Nur aendern wenn noetig; Screenshots via
  `fusion_mcp_read` queryType `screenshot` (Base64-PNG dekodieren und als Datei sichern).

# Troubleshooting
1. Verbindung sofort zu: Fusion laeuft? Dokument offen? Port korrekt (27182)?
2. Tools leer: Server in Preferences togglen (off/on), Client neu verbinden.
3. Script schlaegt fehl: API-Namen gegen `apiDocumentation` pruefen
   (z. B. bRepBodies), Undo ausfuehren, korrigieren, erneut ausfuehren.
4. Offizielle Troubleshooting-Seite:
   https://help.autodesk.com/view/fusion360/ENU/?guid=ADSKMCP_FusionDesktopMcp_troubleshooting_html

# Offizielle Quellen
- Uebersicht: https://help.autodesk.com/view/fusion360/ENU/?guid=FMCP-OVERVIEW
- Desktop-Server: https://help.autodesk.com/view/ADSKMCP/ENU/?guid=ADSKMCP_FusionDesktopMcp_autodesk_fusion_mcp_server_html
- Best Practices / Limitationen: https://help.autodesk.com/view/fusion360/ENU/?guid=AA_Limitations
- Verbindung verwalten: https://help.autodesk.com/view/ADSKMCP/ENU/?guid=ADSKMCP_CommonContent_managing_your_mcp_connection_html
