# Changelog – redmine_expert_lightbox

> 🇩🇪 Deutsche Version · [English version](CHANGELOG.md)
>
> Maßgeblich ist die englische Fassung; diese Datei ist der deutsche Spiegel.

## [Unreleased]

### Hinzugefügt
- **Klickflächen am linken und rechten Bildrand** blättern durch die Galerie, so wie man es von
  gängigen Bildergalerien kennt. Sie sind unsichtbar, bis man mit der Maus darüberfährt – dann
  blenden ein sanfter Verlauf und ein großes `‹` / `›` ein; auf Touch-Geräten, die kein Hover
  kennen, bleiben die Pfeile dauerhaft sichtbar. Nur bei Bildern – über einem PDF würden die
  Flächen das Scrollen und die Werkzeugleiste des eingebetteten Viewers abfangen, dort bleiben
  die Schaltflächen in der Kopfzeile der Weg zum Blättern.
- **Wischgesten** auf Touch und Stift: Wischen nach links zeigt den nächsten Anhang, nach rechts
  den vorherigen. Überwiegend senkrechte Bewegungen scrollen weiterhin, Mausbewegungen bleiben
  unberührt. Umgesetzt mit Pointer Events, also ohne separaten Touch-Codepfad.
- **`LICENSE`-Datei (GPL-2.0-or-later)** – das Plugin steht nun ausdrücklich unter der GNU General
  Public License v2 oder später, also unter derselben Lizenz wie Redmine selbst. Ergänzt einen
  Copyright-/Lizenz-Header in `init.rb` und erweitert den Abschnitt **Lizenz** in `README.md` /
  `README.de.md`. Es werden keine Komponenten von Drittanbietern mitgeliefert.

## [1.0.0] 2026-07-27 (1)

### Hinzugefügt
- **Modal-Vorschau für Bild- und PDF-Anhänge** als Ersatz für das nicht mehr
  kompatible `redmine_x_lightbox2`. Unterstützt Redmine 5.1 bis 7.0.
- **Galerie-Navigation**: alle vorschaufähigen Anhänge einer Seite werden in
  Dokumentreihenfolge gesammelt (dedupliziert nach Anhang-ID); `←` / `→` blättern.
- **`ExpertLightboxController#inline`** (`/expert_lightbox/inline/:id/:filename`)
  liefert vorschaufähige Anhänge mit `Content-Disposition: inline` aus, damit PDFs im
  `<iframe>` dargestellt werden können. Endungs-Allowlist +
  `X-Content-Type-Options: nosniff`; die Sichtbarkeit prüft `Attachment#visible?`.
- Deutsche und englische Locales für die Beschriftungen des Dialogs.

### Hinweise zur Umsetzung
- **Keine überschriebene View, kein `AttachmentsController`-Patch.** Erkannt wird über
  einen einzelnen delegierten Click-Listener anhand der Form der Anhang-*URLs* — damit
  hängt nichts am Markup, an CSS-Klassen oder Icon-Fonts des Core, also genau an den
  beiden Punkten, an denen das Vorgänger-Plugin unter Redmine 6/7 zerbrochen ist.
- **Keine Fremdabhängigkeiten**: reines JavaScript mit nativem `<dialog>`, kein jQuery,
  kein Fancybox, kein Build-Schritt. Browser ohne `<dialog>`-Unterstützung navigieren
  wie gewohnt.
- Die Assets werden über `view_layouts_base_html_head` auf jeder Seite geladen statt
  über eine Allowlist pro Controller; das Skript bleibt untätig, bis ein passender Link
  angeklickt wird.
