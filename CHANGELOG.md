# Changelog – redmine_expert_lightbox

> 🇬🇧 English version · [Deutsche Version](CHANGELOG.de.md)
>
> EN is authoritative — release notes are generated from this file.

## [1.1.1] 2026-09-13

### Fixed
- **Inline wiki images open the lightbox.** Redmine renders `!image.png!` (and CommonMark's
  `![](image.png)`) as a bare `<img>` inside a paragraph with no wrapping link — in both text
  formats — and the click listener only ever looked at `a[href]`. Clicking an inline image
  therefore did nothing, although the README and the code comments both listed inline wiki
  images as covered. Detection now also accepts an `<img>` whose `src` is an attachment URL,
  and such images join the page's gallery like any other attachment.
- **Inline wiki images are reachable by keyboard.** They are bare `<img>` elements, so they
  had no way to be focused or activated; the plugin now marks the ones it will handle
  `tabindex="0"` with `aria-haspopup="dialog"`, and `Enter` or `Space` opens them. Focus
  still returns to the image on close.
- An opt-out on a link (`download`, `data-no-lightbox`) now also covers the image inside it,
  which the gallery would otherwise have picked up on its own.
- An attachment image wrapped in an unrelated link is previewable again: the click handler
  falls back to the image when the surrounding anchor is not an attachment link.
- Clicking the picture inside the open dialog no longer tries to re-open the dialog.

## [1.1.0] 2026-09-11

### Added
- **Click zones on the left and right edge of the picture** step through the gallery, the way
  common image galleries do. They are invisible until hovered, when a soft gradient and a large
  `‹` / `›` chevron fade in; on touch devices, which have no hover, the chevrons stay visible.
  Images only — over a PDF the zones would swallow the embedded viewer's own scrolling and
  toolbar clicks, so there the top bar buttons remain the way to navigate.
- **Horizontal swipe navigation** on touch and pen: swiping left shows the next attachment,
  swiping right the previous one. Mostly-vertical drags still scroll, and mouse drags are left
  alone. Built on Pointer Events, so no separate touch code path.
- **`LICENSE` file (GPL-2.0-or-later)** — the plugin is now explicitly licensed under the GNU
  General Public License v2 or later, matching Redmine itself. Adds a copyright/license header to
  `init.rb` and expands the **License** section in `README.md` / `README.de.md`. No third-party
  components are bundled.

## [1.0.0] 2026-07-27 (1)

### Added
- **Modal preview for image and PDF attachments**, replacing the no-longer-compatible
  `redmine_x_lightbox2`. Supports Redmine 5.1 through 7.0.
- **Gallery navigation**: all previewable attachments on a page are collected in
  document order (deduped by attachment id); `←` / `→` step through them.
- **`ExpertLightboxController#inline`** (`/expert_lightbox/inline/:id/:filename`) serves
  previewable attachments with `Content-Disposition: inline` so PDFs can render in an
  `<iframe>`. Extension allowlist + `X-Content-Type-Options: nosniff`; visibility is
  checked with core's `Attachment#visible?`.
- English and German locales for the dialog's labels.

### Notes on the implementation
- **No view override and no `AttachmentsController` patch.** Detection is a single
  delegated click listener keyed on attachment *URL* shape, so nothing depends on
  core's attachment markup, CSS classes or icon fonts — the two things that broke the
  previous plugin on Redmine 6/7.
- **No third-party dependencies**: vanilla JS with a native `<dialog>`, no jQuery, no
  Fancybox, no build step. Browsers without `<dialog>` support fall back to normal
  navigation.
- Assets are loaded on every page via `view_layouts_base_html_head` rather than a
  per-controller allowlist; the script is inert until a matching link is clicked.
