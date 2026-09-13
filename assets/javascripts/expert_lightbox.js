/*
 * expert Lightbox - modal preview for image and PDF attachments.
 *
 * Works on Redmine 5.1 - 7.x because it makes no assumption about core's attachment
 * markup: it only keys on the shape of attachment URLs, which have been stable for
 * many major versions. No view override, no injected buttons, no icon classes, no
 * jQuery, no third-party library - just one delegated click listener and a native
 * <dialog>.
 *
 * Configuration (URL templates + translated labels) arrives via the JSON island
 * #expert-lightbox-config written by the view hook, so this file stays static.
 */
(function () {
  'use strict';

  var IMAGE_EXT = /\.(png|jpe?g|gif|bmp|webp|avif|svg)$/i;
  var PDF_EXT = /\.pdf$/i;
  var HAS_EXT = /\.[a-z0-9]{2,5}$/i;
  var SWIPE_MIN = 45; // px of horizontal travel before a drag counts as a swipe

  var cfg = readConfig();
  if (!cfg) { return; }

  var dlg = null;      // the <dialog>, built lazily on first open
  var els = null;      // cached child elements of the dialog
  var items = [];      // gallery: [{id, name, type}]
  var index = 0;
  var opener = null;   // anchor that opened the dialog, for focus restore

  function readConfig() {
    var el = document.getElementById('expert-lightbox-config');
    if (!el) { return null; }
    try { return JSON.parse(el.textContent); } catch (e) { return null; }
  }

  function url(template, id, name) {
    return template.replace('__ID__', id).replace('__NAME__', encodeURIComponent(name || 'file'));
  }

  /*
   * Recognise the attachment URLs core emits:
   *   /attachments/<id>                      (inline wiki images, journal detail links)
   *   /attachments/<id>/<filename>
   *   /attachments/download/<id>/<filename>  (attachment lists, "Download" links)
   *   /attachments/thumbnail/<id>(/<size>)   (thumbnail grids)
   * Returns {id, name} or null. `name` is only set when the URL itself carries a
   * filename - for the thumbnail route the trailing segment is a pixel size.
   */
  function parseAttachmentPath(path) {
    if (cfg.root && path.indexOf(cfg.root) === 0) { path = path.slice(cfg.root.length); }
    var m = /^\/attachments\/(download\/|thumbnail\/)?(\d+)(?:\/([^\/]+))?\/?$/.exec(path);
    if (!m) { return null; }
    return { id: m[2], name: (m[1] === 'thumbnail/' ? null : decodeURIComponent(m[3] || '')) };
  }

  // Filename is needed for the type decision, and core's bare /attachments/<id> links
  // do not carry one. Try every place Redmine happens to put it, most reliable first.
  // `el` is an anchor or - for an inline wiki image - the <img> itself, which has no
  // descendants to search and no text content.
  function filenameFor(el, fromPath) {
    var isImg = el.tagName === 'IMG';
    var img = isImg ? el : el.querySelector('img');
    var candidates = [
      fromPath,
      el.getAttribute('data-filename'),
      img ? img.getAttribute('alt') : null,
      el.getAttribute('title'),
      isImg ? null : (el.textContent || '').trim()
    ];
    for (var i = 0; i < candidates.length; i++) {
      var c = candidates[i];
      if (c && HAS_EXT.test(c)) { return c; }
    }
    return null;
  }

  /*
   * Returns {id, name, type} for a previewable element, or null to leave the click
   * alone. `el` is an anchor, or a bare <img> whose src is an attachment URL.
   *
   * The <img> case is what covers inline wiki images. Redmine renders `!name.png!`
   * (and CommonMark's `![](name.png)`) as an <img> inside a <p> with no wrapping
   * link at all - in both text formats - so an anchor-only listener never sees them.
   */
  function describe(el) {
    var isImg = el.tagName === 'IMG';
    var raw = isImg ? el.getAttribute('src') : el.getAttribute('href');
    if (!raw || el.hasAttribute('data-no-lightbox')) { return null; }
    // `download` means the author wants the file saved, not previewed. Anchors only:
    // it is a valid, unrelated attribute name on nothing else here.
    if (!isImg && el.hasAttribute('download')) { return null; }
    // An opt-out on the anchor has to cover the image inside it, or collect()
    // would pick the <img> up on its own and put an explicitly excluded
    // attachment back into the gallery.
    if (isImg) {
      var wrapper = el.closest ? el.closest('a[href]') : null;
      if (wrapper && (wrapper.hasAttribute('download') || wrapper.hasAttribute('data-no-lightbox'))) {
        return null;
      }
      // The dialog renders the current item as an <img> with the same URL shape.
      // Collecting or re-opening it would fight with the dialog itself.
      if (dlg && dlg.contains(el)) { return null; }
    }

    var u;
    try { u = new URL(isImg ? el.src : el.href, window.location.href); } catch (e) { return null; }
    if (u.origin !== window.location.origin) { return null; }

    var parsed = parseAttachmentPath(u.pathname);
    if (!parsed) { return null; }

    var name = filenameFor(el, parsed.name);
    var type = null;
    if (name && PDF_EXT.test(name)) {
      type = 'pdf';
    } else if (name && IMAGE_EXT.test(name)) {
      type = 'image';
    } else if (!name && (isImg || el.querySelector('img'))) {
      // No filename anywhere, but it renders an image - safe to show as one. Covers
      // the thumbnail route, whose trailing segment is a pixel size, not a name.
      type = 'image';
    }
    if (!type) { return null; }

    return { id: parsed.id, name: name || ('attachment-' + parsed.id), type: type };
  }

  // All previewable attachments on the page, in document order, deduped by id - this
  // reproduces the gallery grouping the old plugin got from Fancybox's rel attribute.
  function collect() {
    var seen = {};
    var out = [];
    // Anchors and bare inline images alike. An <img> inside an anchor is described
    // twice, but querySelectorAll returns document order, so the anchor comes first
    // and the dedupe by id keeps that one.
    var nodes = document.querySelectorAll('a[href*="/attachments/"], img[src*="/attachments/"]');
    for (var i = 0; i < nodes.length; i++) {
      var d = describe(nodes[i]);
      if (d && !seen[d.id]) { seen[d.id] = true; out.push(d); }
    }
    return out;
  }

  function button(cls, label, text) {
    var b = document.createElement('button');
    b.type = 'button';
    b.className = cls;
    b.title = label;
    b.setAttribute('aria-label', label);
    b.textContent = text;
    return b;
  }

  function build() {
    var L = cfg.labels;
    dlg = document.createElement('dialog');
    dlg.id = 'expert-lightbox';
    dlg.className = 'expert-lightbox';
    dlg.setAttribute('aria-label', L.dialog);

    var bar = document.createElement('div');
    bar.className = 'elb-bar';

    var caption = document.createElement('span');
    caption.className = 'elb-caption';

    var counter = document.createElement('span');
    counter.className = 'elb-counter';

    var actions = document.createElement('span');
    actions.className = 'elb-actions';

    var prev = button('elb-btn elb-prev', L.prev, '‹');
    var next = button('elb-btn elb-next', L.next, '›');
    var download = document.createElement('a');
    download.className = 'elb-btn elb-download';
    download.title = L.download;
    download.setAttribute('aria-label', L.download);
    download.setAttribute('download', '');
    download.textContent = '⤓';
    var close = button('elb-btn elb-close', L.close, '×');

    actions.appendChild(prev);
    actions.appendChild(next);
    actions.appendChild(download);
    actions.appendChild(close);
    bar.appendChild(caption);
    bar.appendChild(counter);
    bar.appendChild(actions);

    var stage = document.createElement('div');
    stage.className = 'elb-stage';

    // The stage is the positioning context; only .elb-content is emptied per item, so the
    // edge zones survive render() and are built exactly once.
    var content = document.createElement('div');
    content.className = 'elb-content';

    // Click zones over the left/right edge of the picture, the way image galleries do it.
    // Not tab stops: the bar buttons already expose prev/next to keyboard and AT users.
    var zprev = button('elb-zone elb-zone-prev', L.prev, '‹');
    var znext = button('elb-zone elb-zone-next', L.next, '›');
    zprev.tabIndex = -1;
    znext.tabIndex = -1;

    stage.appendChild(content);
    stage.appendChild(zprev);
    stage.appendChild(znext);

    dlg.appendChild(bar);
    dlg.appendChild(stage);
    document.body.appendChild(dlg);

    els = { caption: caption, counter: counter, content: content, download: download,
            prev: prev, next: next, zprev: zprev, znext: znext };

    prev.addEventListener('click', function () { step(-1); });
    next.addEventListener('click', function () { step(1); });
    zprev.addEventListener('click', function () { step(-1); });
    znext.addEventListener('click', function () { step(1); });
    close.addEventListener('click', function () { dlg.close(); });

    // Click on the backdrop (the dialog element itself, outside its children) closes.
    dlg.addEventListener('click', function (e) { if (e.target === dlg) { dlg.close(); } });

    dlg.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowLeft') { e.preventDefault(); step(-1); }
      else if (e.key === 'ArrowRight') { e.preventDefault(); step(1); }
    });

    // Horizontal swipe on touch/pen. Pointer Events rather than touch events so one code
    // path covers both; mouse drags are ignored so text/image dragging keeps working.
    var sx = 0, sy = 0, swiping = false;

    content.addEventListener('pointerdown', function (e) {
      if (e.pointerType === 'mouse' || !e.isPrimary) { return; }
      sx = e.clientX; sy = e.clientY; swiping = true;
    });
    content.addEventListener('pointerup', function (e) {
      if (!swiping) { return; }
      swiping = false;
      var dx = e.clientX - sx;
      var dy = e.clientY - sy;
      // Horizontal intent only: a mostly-vertical drag is the user scrolling.
      if (Math.abs(dx) < SWIPE_MIN || Math.abs(dx) <= Math.abs(dy)) { return; }
      step(dx < 0 ? 1 : -1);
    });
    content.addEventListener('pointercancel', function () { swiping = false; });

    // Empty the stage so a PDF iframe stops loading / rendering once hidden.
    dlg.addEventListener('close', function () {
      els.content.textContent = '';
      if (opener && document.contains(opener)) { opener.focus(); }
      opener = null;
    });
  }

  function step(delta) {
    if (items.length < 2) { return; }
    index = (index + delta + items.length) % items.length;
    render();
  }

  function render() {
    var item = items[index];
    var multi = items.length > 1;

    els.content.textContent = '';
    if (item.type === 'pdf') {
      var frame = document.createElement('iframe');
      frame.className = 'elb-pdf';
      frame.title = item.name;
      frame.src = url(cfg.inlineUrl, item.id, item.name) + '#view=FitH';
      els.content.appendChild(frame);
    } else {
      var img = document.createElement('img');
      img.className = 'elb-img';
      img.alt = item.name;
      img.src = url(cfg.downloadUrl, item.id, item.name);
      els.content.appendChild(img);
    }

    els.caption.textContent = item.name;
    els.counter.textContent = multi ? (index + 1) + ' / ' + items.length : '';
    els.prev.hidden = !multi;
    els.next.hidden = !multi;
    // No edge zones over a PDF: they would swallow the embedded viewer's own scrolling
    // and toolbar clicks. The bar buttons remain the way to step past a PDF.
    var zoned = multi && item.type !== 'pdf';
    els.zprev.hidden = !zoned;
    els.znext.hidden = !zoned;
    els.download.href = url(cfg.downloadUrl, item.id, item.name);
  }

  function open(target, anchor) {
    if (!dlg) { build(); }
    items = collect();

    index = -1;
    for (var i = 0; i < items.length; i++) {
      if (items[i].id === target.id) { index = i; break; }
    }
    // The clicked link is always previewable; if collect() missed it (detached DOM,
    // duplicate id already consumed) fall back to showing just this one.
    if (index < 0) { items = [target]; index = 0; }

    opener = anchor;
    render();
    dlg.showModal();
  }

  /*
   * A bare inline <img> is mouse-clickable but nothing else: it cannot be tabbed
   * to and has no activation behaviour, so the feature would be unreachable by
   * keyboard and `opener.focus()` would silently do nothing on close.
   *
   * Marking it focusable is the least invasive fix available from a plugin that
   * refuses to override core's views. The image keeps its `img` role - swapping
   * in role="button" would cost screen-reader users the fact that it IS an
   * image - and gains aria-haspopup="dialog", which is what actually happens.
   */
  function enhanceImages(root) {
    var imgs = (root || document).querySelectorAll('img[src*="/attachments/"]');
    for (var i = 0; i < imgs.length; i++) {
      var img = imgs[i];
      if (img.hasAttribute('data-elb-key')) { continue; }
      if (img.closest && img.closest('a[href]')) { continue; }   // already focusable
      if (dlg && dlg.contains(img)) { continue; }
      if (!describe(img)) { continue; }
      img.setAttribute('data-elb-key', '1');
      img.setAttribute('tabindex', '0');
      img.setAttribute('aria-haspopup', 'dialog');
      if (!img.getAttribute('title')) { img.setAttribute('title', cfg.labels.dialog); }
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { enhanceImages(); });
  } else {
    enhanceImages();
  }

  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Enter' && e.key !== ' ' && e.key !== 'Spacebar') { return; }
    var el = e.target;
    if (!el || el.tagName !== 'IMG' || !el.hasAttribute('data-elb-key')) { return; }
    if (dlg && dlg.contains(el)) { return; }
    var target = describe(el);
    if (!target) { return; }
    if (typeof HTMLDialogElement === 'undefined' || !HTMLDialogElement.prototype.showModal) { return; }
    e.preventDefault();
    open(target, el);
  }, false);

  document.addEventListener('click', function (e) {
    // Leave modified clicks to the browser: they mean "new tab/window/save as".
    if (e.defaultPrevented || e.button !== 0) { return; }
    if (e.ctrlKey || e.metaKey || e.shiftKey || e.altKey) { return; }

    if (!e.target.closest) { return; }
    // Clicks inside the open dialog belong to the dialog: its own <img> matches
    // the attachment URL shape, and re-entering open() would call showModal() on
    // an already-open dialog.
    if (dlg && dlg.contains(e.target)) { return; }

    var a = e.target.closest('a[href]');
    if (a && a.target === '_blank') { return; }

    // Prefer the anchor, but fall back to the image when the anchor is not an
    // attachment link of ours - an attachment image wrapped in some unrelated
    // link would otherwise never be previewable.
    var el = null;
    var target = null;
    if (a) {
      target = describe(a);
      if (target) { el = a; }
    }
    if (!target && e.target.tagName === 'IMG') {
      target = describe(e.target);
      if (target) { el = e.target; }
    }
    if (!target) { return; }

    // No <dialog> support (pre-2022 browsers): fall through to normal navigation.
    if (typeof HTMLDialogElement === 'undefined' || !HTMLDialogElement.prototype.showModal) { return; }

    e.preventDefault();
    open(target, el);
  }, false);
}());
