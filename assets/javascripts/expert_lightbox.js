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
  function filenameFor(a, fromPath) {
    var img = a.querySelector('img');
    var candidates = [
      fromPath,
      a.getAttribute('data-filename'),
      img ? img.getAttribute('alt') : null,
      a.getAttribute('title'),
      (a.textContent || '').trim()
    ];
    for (var i = 0; i < candidates.length; i++) {
      var c = candidates[i];
      if (c && HAS_EXT.test(c)) { return c; }
    }
    return null;
  }

  // Returns {id, name, type} for a previewable anchor, or null to leave the click alone.
  function describe(a) {
    var href = a.getAttribute('href');
    if (!href || a.hasAttribute('download') || a.hasAttribute('data-no-lightbox')) { return null; }

    var u;
    try { u = new URL(a.href, window.location.href); } catch (e) { return null; }
    if (u.origin !== window.location.origin) { return null; }

    var parsed = parseAttachmentPath(u.pathname);
    if (!parsed) { return null; }

    var name = filenameFor(a, parsed.name);
    var type = null;
    if (name && PDF_EXT.test(name)) {
      type = 'pdf';
    } else if (name && IMAGE_EXT.test(name)) {
      type = 'image';
    } else if (!name && a.querySelector('img')) {
      // No filename anywhere, but the link renders an image - safe to show as one.
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
    var links = document.querySelectorAll('a[href*="/attachments/"]');
    for (var i = 0; i < links.length; i++) {
      var d = describe(links[i]);
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

  document.addEventListener('click', function (e) {
    // Leave modified clicks to the browser: they mean "new tab/window/save as".
    if (e.defaultPrevented || e.button !== 0) { return; }
    if (e.ctrlKey || e.metaKey || e.shiftKey || e.altKey) { return; }

    var a = e.target.closest ? e.target.closest('a[href]') : null;
    if (!a || a.target === '_blank') { return; }

    var target = describe(a);
    if (!target) { return; }

    // No <dialog> support (pre-2022 browsers): fall through to normal navigation.
    if (typeof HTMLDialogElement === 'undefined' || !HTMLDialogElement.prototype.showModal) { return; }

    e.preventDefault();
    open(target, a);
  }, false);
}());
