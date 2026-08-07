> 🇬🇧 English version · [Deutsche Version](README.de.md)

# Redmine expert Lightbox

Preview image and PDF attachments in a modal dialog instead of navigating away or
downloading them. Works on **Redmine 5.1, 6.0, 6.1 and 7.0**.

This replaces `redmine_x_lightbox2` (a fork of `paginagmbh/redmine_lightbox2`), which
stopped working on Redmine 6/7 because it overrode core's
`app/views/attachments/_links.html.erb` and relied on the `icon-*` font-icon classes
that Redmine 7 removed.

## What it does

Clicking an image or PDF attachment anywhere in Redmine opens it in a modal:

- **Images** are shown scaled to fit the viewport.
- **PDFs** are shown in the browser's built-in PDF viewer.
- **Everything else** behaves exactly as before — the plugin does not interfere.

Multiple attachments on the same page form a gallery. You can step through them with
`←` / `→`, with the `‹` / `›` buttons in the top bar, by clicking the left or right edge
of the picture (a chevron fades in when you hover there), or by swiping left/right on a
touch device. The edge zones are only shown for images — over a PDF they would swallow the
embedded viewer's own clicks. `Esc` or a click on the backdrop closes the dialog, and focus
returns to the link you clicked. Ctrl/Cmd/middle-click still opens the attachment in a new tab.

Covered surfaces include issue attachments, journal/history entries and their
thumbnails, inline wiki images (`!image.png!`), the Files and Documents modules, news
and forum messages — plus any third-party plugin page that links to attachments,
because there is no per-controller allowlist.

## How it works

Three small pieces, deliberately chosen to survive Redmine major upgrades:

1. **One delegated click listener** (`assets/javascripts/expert_lightbox.js`, vanilla
   JS, no jQuery, no third-party library, no build step). It keys only on the shape of
   attachment *URLs* (`/attachments/<id>`, `/attachments/download/<id>/<name>`,
   `/attachments/thumbnail/<id>`), which have been stable across many Redmine major
   versions — not on core's attachment markup, CSS classes or icons.
2. **A native `<dialog>`** for the modal, so Esc handling, focus trapping and the
   backdrop come from the browser. On browsers without `<dialog>` support the plugin
   stays inert and links navigate normally.
3. **`ExpertLightboxController#inline`** (`/expert_lightbox/inline/:id/:filename`) —
   needed only for PDFs, because core's download route forces
   `Content-Disposition: attachment` for non-images and a forced download cannot be
   rendered in an `<iframe>`.

There is **no view override and no patch to `AttachmentsController`**, which is what
broke the previous plugin and what would collide with `redmine_contacts` here.

### Security

`ExpertLightboxController#inline` serves a file inline only if its extension is in a
fixed allowlist (`png`, `gif`, `jpg`, `jpeg`, `bmp`, `webp`, `avif`, `pdf`) and sends
`X-Content-Type-Options: nosniff` with a Content-Type derived from that allowlist
rather than from the uploaded file's own metadata. Anything else returns 404, so the
endpoint cannot be used to serve an uploaded `.html` or `.svg` file inline on the
Redmine origin. Visibility is checked with core's `Attachment#visible?`, so the
endpoint grants no access that `/attachments/download` would not.

## Installation

```bash
cd /path/to/redmine/plugins
git clone https://github.com/expertZentrale/redmine_expert_lightbox.git
# restart Redmine
```

No migrations, no settings, no permissions — the plugin is active as soon as it loads.

## Tests

MiniTest, requires a Redmine environment:

```bash
bundle exec rake redmine:plugins:test NAME=redmine_expert_lightbox RAILS_ENV=test
```

## License

Copyright (C) 2026 Dennis Buehring

**GNU General Public License, version 2 or (at your option) any later version** — the same license
Redmine itself uses. See [`LICENSE`](LICENSE) for the full text. Distributed WITHOUT ANY WARRANTY.

No third-party components are bundled — the lightbox is plain vanilla JS/CSS, no jQuery, no external
libraries, and no CDN request at runtime.
