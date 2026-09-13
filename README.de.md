> 🇩🇪 Deutsche Version · [English version](README.md)

# Redmine expert Lightbox

[![CI](https://github.com/expertZentrale/redmine_expert_lightbox/actions/workflows/ci.yml/badge.svg)](https://github.com/expertZentrale/redmine_expert_lightbox/actions/workflows/ci.yml) [![Docker image smoke test](https://github.com/expertZentrale/redmine_expert_lightbox/actions/workflows/docker-image.yml/badge.svg)](https://github.com/expertZentrale/redmine_expert_lightbox/actions/workflows/docker-image.yml)

Bild- und PDF-Anhänge in einem Modal-Dialog ansehen, statt die Seite zu verlassen oder
die Datei herunterzuladen. Läuft auf **Redmine 5.1, 6.0, 6.1 und 7.0**.

Ersetzt `redmine_x_lightbox2` (ein Fork von `paginagmbh/redmine_lightbox2`), das unter
Redmine 6/7 nicht mehr funktionierte: es überschrieb die Core-View
`app/views/attachments/_links.html.erb` und setzte auf die `icon-*`-Icon-Font-Klassen,
die in Redmine 7 entfernt wurden.


## Screenshots

Alle Screenshots zeigen ein Demoprojekt mit synthetischen Daten, erzeugt von
`scripts/seed_screenshot_demo.rb`.

### Bilder und PDFs

![Ein Bildanhang im Dialog über der Ticketseite, mit dem Zähler „1 / 4“ und den
Schaltflächen für Zurück und Weiter in der Kopfzeile](docs/screenshots/de/01-image-modal.png)

Ein PDF öffnet sich im eingebauten Betrachter des Browsers, samt Werkzeugleiste und
Seitenvorschau. Die Klickflächen am Rand entfallen dort, damit sie dem Betrachter keine
Klicks wegnehmen.

![Ein PDF im eingebauten Betrachter des Browsers innerhalb des Dialogs, mit Werkzeugleiste
und Seitenvorschau](docs/screenshots/de/03-pdf.png)

### Galerie

Alle anzeigbaren Anhänge einer Seite bilden in Dokumentreihenfolge eine Galerie. Die
Klickflächen sind unsichtbar, bis man mit der Maus darüberfährt, und bleiben auf
Touchgeräten, die kein Hover kennen, dauerhaft sichtbar.

![Der dritte von vier Anhängen, mit der rechten Klickfläche, die beim Überfahren
erscheint](docs/screenshots/de/02-gallery.png)

### Überall, wo Anhänge vorkommen

Die Erkennung greift allein an der Form der Anhang-URLs an, es gibt also keine Liste
erlaubter Controller zu pflegen — eingebettete Wiki-Bilder eingeschlossen, die ein reines
`<img>` ohne umschließenden Link sind.

![Ein eingebettetes Wiki-Bild, geöffnet ohne die Seite zu verlassen, die es
illustriert](docs/screenshots/de/04-wiki.png)

## Funktion

Ein Klick auf einen Bild- oder PDF-Anhang öffnet ihn im Modal:

- **Bilder** werden passend zum Viewport skaliert.
- **PDFs** werden im eingebauten PDF-Viewer des Browsers angezeigt.
- **Alles andere** verhält sich unverändert — das Plugin greift nicht ein.

Mehrere Anhänge auf derselben Seite bilden eine Galerie. Blättern lässt sich mit
`←` / `→`, über die Schaltflächen `‹` / `›` in der Kopfzeile, per Klick auf den linken oder
rechten Bildrand (beim Überfahren blendet dort ein Pfeil ein) oder per Wischgeste auf
Touch-Geräten. Die Randflächen gibt es nur bei Bildern — über einem PDF würden sie die Klicks
des eingebetteten Viewers abfangen. `Esc` oder ein Klick auf den Hintergrund schließt den
Dialog, der Fokus kehrt zum angeklickten Link zurück. Strg/Cmd-/Mittelklick öffnet den Anhang
weiterhin in einem neuen Tab.

Abgedeckt sind u. a. Ticket-Anhänge, Historien-Einträge samt Vorschaubildern,
Inline-Wiki-Bilder (`!bild.png!`), die Module Dateien und Dokumente, News und
Foren-Beiträge — dazu jede Seite eines Fremd-Plugins, die auf Anhänge verlinkt, denn es
gibt keine Allowlist pro Controller.

## Umsetzung

Drei kleine Bausteine, bewusst so gewählt, dass sie Redmine-Major-Upgrades überstehen:

1. **Ein delegierter Click-Listener** (`assets/javascripts/expert_lightbox.js`, reines
   JavaScript, kein jQuery, keine Fremdbibliothek, kein Build-Schritt). Er wertet nur
   die Form der Anhang-*URLs* aus (`/attachments/<id>`,
   `/attachments/download/<id>/<name>`, `/attachments/thumbnail/<id>`), die über viele
   Redmine-Hauptversionen stabil ist — nicht das Markup, die CSS-Klassen oder die Icons
   des Core.
2. **Ein natives `<dialog>`** für das Modal; Esc-Behandlung, Fokus-Falle und
   Hintergrund kommen damit vom Browser. Browser ohne `<dialog>`-Unterstützung bleiben
   beim normalen Navigieren.
3. **`ExpertLightboxController#inline`** (`/expert_lightbox/inline/:id/:filename`) —
   nur für PDFs nötig, weil der Core-Download-Pfad für Nicht-Bilder
   `Content-Disposition: attachment` erzwingt und ein erzwungener Download nicht im
   `<iframe>` dargestellt werden kann.

Es gibt **keine überschriebene View und keinen Patch am `AttachmentsController`** —
genau das hatte das Vorgänger-Plugin zerlegt und würde hier mit `redmine_contacts`
kollidieren.

### Sicherheit

`ExpertLightboxController#inline` liefert eine Datei nur dann inline aus, wenn ihre
Endung auf einer festen Allowlist steht (`png`, `gif`, `jpg`, `jpeg`, `bmp`, `webp`,
`avif`, `pdf`); gesendet wird `X-Content-Type-Options: nosniff` und ein Content-Type
aus dieser Allowlist statt aus den Metadaten der hochgeladenen Datei. Alles andere
ergibt 404 — der Endpunkt kann also nicht dazu benutzt werden, eine hochgeladene
`.html`- oder `.svg`-Datei inline auf der Redmine-Origin auszuliefern. Die Sichtbarkeit
prüft der Core selbst über `Attachment#visible?`; der Endpunkt gewährt damit keinen
Zugriff, den `/attachments/download` nicht auch gewähren würde.

## Installation

```bash
cd /pfad/zu/redmine/plugins
git clone https://github.com/expertZentrale/redmine_expert_lightbox.git
# Redmine neu starten
```

Keine Migrationen, keine Einstellungen, keine Berechtigungen — das Plugin ist aktiv,
sobald es geladen ist.

## Tests

MiniTest, benötigt eine Redmine-Umgebung:

```bash
bundle exec rake redmine:plugins:test NAME=redmine_expert_lightbox RAILS_ENV=test
```

## Lizenz

Copyright (C) 2026 Dennis Buehring

**GNU General Public License, Version 2 oder (nach Ihrer Wahl) jede spätere Version** — also
dieselbe Lizenz, die auch Redmine nutzt. Den vollständigen Text finden Sie in [`LICENSE`](LICENSE).
Die Weitergabe erfolgt OHNE JEDE GEWÄHRLEISTUNG.

Es werden keine Komponenten von Drittanbietern mitgeliefert — die Lightbox ist reines Vanilla-JS/CSS,
ohne jQuery, ohne externe Bibliotheken und ohne CDN-Aufruf zur Laufzeit.
