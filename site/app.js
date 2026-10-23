/* iClip showcase — vanilla JS, no dependencies. */
(function () {
  'use strict';

  var $ = function (selector, root) { return (root || document).querySelector(selector); };
  var $$ = function (selector, root) { return Array.prototype.slice.call((root || document).querySelectorAll(selector)); };

  var esc = function (value) {
    return String(value).replace(/[&<>"']/g, function (character) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[character];
    });
  };

  var icon = function (name, className) {
    return '<svg class="ico ' + (className || '') + '" aria-hidden="true"><use href="#i-' + name + '"/></svg>';
  };

  var basename = function (path) {
    var parts = String(path).split('/');
    return parts[parts.length - 1] || path;
  };

  var clone = function (value) {
    return JSON.parse(JSON.stringify(value));
  };

  // Use the visitor's local clock for every demo menu bar.
  var clockTimer;
  function syncDemoClocks() {
    clearTimeout(clockTimer);
    var now = new Date();
    var weekday = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][now.getDay()];
    var hours = String(now.getHours()).padStart(2, '0');
    var minutes = String(now.getMinutes()).padStart(2, '0');
    $$('.menubar-clock').forEach(function (clock) {
      clock.textContent = weekday + ' ' + hours + ':' + minutes;
    });
    clockTimer = setTimeout(syncDemoClocks, 60000 - (now.getSeconds() * 1000 + now.getMilliseconds()));
  }
  syncDemoClocks();
  document.addEventListener('visibilitychange', function () {
    if (!document.hidden) syncDemoClocks();
  });
  window.addEventListener('focus', syncDemoClocks);

  /* ---------------------------------------------------------
     Demo data — shaped like iClip's ClipboardEntry.
     --------------------------------------------------------- */

  var SEED = [
    {
      id: 'entry-1',
      kind: 'text',
      pinned: true,
      age: '刚刚',
      order: 100,
      text: '周五 14:00 设计评审\n• 面板改成 Liquid Glass\n• 置顶项不参与清理\n• 回车直接粘贴到前台 App'
    },
    {
      id: 'entry-2',
      kind: 'text',
      pinned: false,
      age: '2 分钟前',
      order: 96,
      text: 'https://github.com/GamerNoTitle/iClip'
    },
    {
      id: 'entry-3',
      kind: 'image',
      pinned: false,
      age: '4 分钟前',
      order: 92,
      text: '图片'
    },
    {
      id: 'entry-4',
      kind: 'files',
      pinned: false,
      age: '6 分钟前',
      order: 88,
      text: '/Users/you/Desktop/设计稿.fig\n/Users/you/Desktop/图标.sketch',
      files: ['/Users/you/Desktop/设计稿.fig', '/Users/you/Desktop/图标.sketch']
    },
    {
      id: 'entry-5',
      kind: 'text',
      pinned: false,
      age: '9 分钟前',
      order: 84,
      text: 'sudo xcode-select -s /Applications/Xcode.app'
    },
    {
      id: 'entry-6',
      kind: 'text',
      pinned: false,
      age: '12 分钟前',
      order: 80,
      text: '把复杂留给自己，把简单留给用户。'
    }
  ];

  var NOTE_EMPTY = '<p class="note-empty">选择面板里的条目，或按 <kbd>↵</kbd>，粘贴会出现在这里。</p>';

  /* ---------------------------------------------------------
     Clipboard panel (recreated from Views.swift)
     --------------------------------------------------------- */

  function ClipPanel(mount, options) {
    options = options || {};
    this.mount = mount;
    this.readonly = options.readonly === true;
    this.onSettings = options.onSettings || null;
    this.initialEntries = clone(options.entries || SEED);
    this.entries = clone(this.initialEntries);
    this.query = '';
    this.selectedId = null;
    this.toastTimer = null;

    var panel = document.createElement('div');
    panel.className = 'clip-panel';
    panel.dataset.readonly = String(this.readonly);
    panel.setAttribute('role', 'region');
    panel.setAttribute('aria-label', this.readonly ? 'iClip 剪贴板面板预览' : 'iClip 剪贴板交互演示');
    if (this.readonly) {
      panel.setAttribute('aria-hidden', 'true');
    } else {
      panel.tabIndex = 0;
    }

    var headActions = this.readonly
      ? '<span class="shortcut-badge">⌃⇧V</span><span class="clip-icon-button" aria-hidden="true">' + icon('gear') + '</span>'
      : '<span class="shortcut-badge">⌃⇧V</span><button type="button" class="clip-icon-button" data-action="settings" aria-label="打开设置截图" title="设置">' + icon('gear') + '</button>';

    var search = this.readonly
      ? '<div class="clip-search clip-search--static">' + icon('search') + '<span>搜索剪贴板</span></div>'
      : '<label class="clip-search">' + icon('search') + '<input type="text" placeholder="搜索剪贴板" aria-label="搜索剪贴板" autocomplete="off" spellcheck="false"></label>';

    panel.innerHTML =
      '<header class="clip-head">' +
        '<div class="clip-title"><img class="clip-app-icon" src="assets/icon-64.png" alt="" width="21" height="21"><span>iClip</span></div>' +
        '<div class="clip-head-actions">' + headActions + '</div>' +
      '</header>' +
      search +
      '<div class="clip-divider"></div>' +
      '<div class="clip-list" data-list role="list" aria-label="剪贴板历史"></div>' +
      '<div class="clip-divider"></div>' +
      '<footer class="clip-foot"><span>↑↓ 选择 · 回车粘贴 · Esc 关闭</span><span data-count aria-live="polite">0 条</span></footer>';

    mount.appendChild(panel);
    this.el = panel;
    this.list = $('[data-list]', panel);
    this.count = $('[data-count]', panel);
    this.input = $('input', panel);

    this.selectedId = this.visibleEntries()[0] ? this.visibleEntries()[0].id : null;
    this.renderList();

    if (!this.readonly) {
      this.bind();
    }
  }

  ClipPanel.prototype.sortedEntries = function () {
    return this.entries.slice().sort(function (a, b) {
      if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
      return b.order - a.order;
    });
  };

  ClipPanel.prototype.visibleEntries = function () {
    var query = this.query.trim().toLowerCase();
    if (!query) return this.sortedEntries();
    return this.sortedEntries().filter(function (entry) {
      var haystack = entry.text + ' ' + (entry.files || []).join(' ');
      return haystack.toLowerCase().indexOf(query) !== -1;
    });
  };

  ClipPanel.prototype.metaRight = function (entry) {
    if (entry.kind === 'image') return '图片';
    if (entry.kind === 'files') return (entry.files || []).length + ' 个文件';
    return entry.text.length + ' 字符';
  };

  ClipPanel.prototype.entryContent = function (entry) {
    if (entry.kind === 'image') {
      return '<div class="entry-thumb" role="img" aria-label="图片缩略图"></div>';
    }
    if (entry.kind === 'files') {
      var names = (entry.files || []).map(function (path) {
        return esc(basename(path));
      }).join('<br>');
      return '<div class="entry-text" title="' + esc(entry.text) + '"><span class="kind-badge">文件</span>' + names + '</div>';
    }
    return '<div class="entry-text">' + esc(entry.text).replace(/\n/g, '<br>') + '</div>';
  };

  ClipPanel.prototype.entryHTML = function (entry) {
    var selected = entry.id === this.selectedId;
    var main = this.readonly
      ? '<div class="entry-main">' + this.entryContent(entry) + this.metaHTML(entry) + '</div>'
      : '<button type="button" class="entry-main" data-action="paste" data-id="' + entry.id + '">' + this.entryContent(entry) + this.metaHTML(entry) + '</button>';

    var pinButton = this.readonly
      ? '<span class="entry-action entry-action--pin" aria-hidden="true">' + icon(entry.pinned ? 'pin-fill' : 'pin') + '</span>'
      : '<button type="button" class="entry-action entry-action--pin" data-action="pin" data-id="' + entry.id + '" title="' + (entry.pinned ? '取消置顶' : '永久置顶') + '" aria-label="' + (entry.pinned ? '取消置顶' : '永久置顶') + '">' + icon(entry.pinned ? 'pin-fill' : 'pin') + '</button>';

    var deleteButton = this.readonly
      ? '<span class="entry-action entry-action--delete" aria-hidden="true">' + icon('x') + '</span>'
      : '<button type="button" class="entry-action entry-action--delete" data-action="delete" data-id="' + entry.id + '" title="删除" aria-label="删除这条记录">' + icon('x') + '</button>';

    return '<div class="clip-entry' + (selected ? ' is-selected' : '') + '" data-entry-id="' + entry.id + '" role="listitem"' + (selected ? ' aria-current="true"' : '') + '>' +
      main +
      '<div class="entry-actions">' + pinButton + deleteButton + '</div>' +
    '</div>';
  };

  ClipPanel.prototype.metaHTML = function (entry) {
    return '<div class="entry-meta">' +
      (entry.pinned ? icon('pin-fill', 'meta-pin') : '') +
      '<span>' + esc(entry.age) + '</span>' +
      '<span class="meta-spacer"></span>' +
      '<span>' + this.metaRight(entry) + '</span>' +
    '</div>';
  };

  ClipPanel.prototype.renderList = function () {
    var visible = this.visibleEntries();
    if (!visible.some(function (entry) { return entry.id === this.selectedId; }, this)) {
      this.selectedId = visible.length ? visible[0].id : null;
    }

    if (!visible.length) {
      this.list.innerHTML = '<div class="clip-empty">' + icon('search') +
        '<p>没有匹配的内容</p><small>换个关键词试试</small></div>';
    } else {
      this.list.innerHTML = visible.map(this.entryHTML, this).join('');
    }
    this.count.textContent = visible.length + ' 条';
  };

  ClipPanel.prototype.renderWithFlip = function () {
    var before = {};
    $$('[data-entry-id]', this.list).forEach(function (element) {
      before[element.dataset.entryId] = element.getBoundingClientRect().top;
    });
    this.renderList();
    $$('[data-entry-id]', this.list).forEach(function (element) {
      var previousTop = before[element.dataset.entryId];
      if (previousTop === undefined) return;
      var delta = previousTop - element.getBoundingClientRect().top;
      if (Math.abs(delta) < 1) return;
      element.style.transition = 'none';
      element.style.transform = 'translateY(' + delta + 'px)';
      requestAnimationFrame(function () {
        element.style.transition = 'transform .28s cubic-bezier(.2,.8,.2,1)';
        element.style.transform = '';
      });
      element.addEventListener('transitionend', function () {
        element.style.transition = '';
        element.style.transform = '';
      }, { once: true });
    });
  };

  ClipPanel.prototype.move = function (delta) {
    var visible = this.visibleEntries();
    if (!visible.length) return;
    var index = visible.findIndex(function (entry) { return entry.id === this.selectedId; }, this);
    if (index < 0) index = 0;
    var next = visible[Math.min(Math.max(index + delta, 0), visible.length - 1)];
    this.selectedId = next.id;
    this.renderList();
    var selected = $('[data-entry-id="' + next.id + '"]', this.list);
    if (selected && selected.scrollIntoView) selected.scrollIntoView({ block: 'nearest' });
  };

  ClipPanel.prototype.markSelection = function () {
    $$('[data-entry-id]', this.list).forEach(function (element) {
      var selected = element.dataset.entryId === this.selectedId;
      element.classList.toggle('is-selected', selected);
      if (selected) element.setAttribute('aria-current', 'true');
      else element.removeAttribute('aria-current');
    }, this);
  };

  ClipPanel.prototype.paste = function (entry) {
    if (this.readonly || !entry) return;
    this.selectedId = entry.id;
    this.markSelection();

    var noteContent = $('[data-note-content]');
    var noteMeta = $('[data-note-meta]');
    var noteWindow = $('#noteWindow');
    if (!noteContent) return;

    if (entry.kind === 'image') {
      noteContent.innerHTML = '<div class="note-image"></div>';
    } else if (entry.kind === 'files') {
      noteContent.innerHTML = '<div class="note-files">' + (entry.files || []).map(function (path) {
        return '<span class="note-file">' + icon('file') + esc(basename(path)) + '</span>';
      }).join('') + '</div>';
    } else {
      noteContent.innerHTML = '<div class="note-pasted">' + esc(entry.text) + '</div>';
    }

    if (noteMeta) {
      noteMeta.textContent = (entry.pinned ? '置顶内容' : '来自 iClip') + ' · 刚刚';
    }
    if (noteWindow) {
      noteWindow.classList.remove('is-pulsing');
      void noteWindow.offsetWidth;
      noteWindow.classList.add('is-pulsing');
    }
    this.showToast('已粘贴到「备忘录」');
  };

  ClipPanel.prototype.showToast = function (message) {
    var toast = $('[data-toast]');
    if (!toast) return;
    toast.innerHTML = icon('check') + '<span>' + esc(message) + '</span>';
    toast.classList.add('is-visible');
    clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(function () {
      toast.classList.remove('is-visible');
    }, 1900);
  };

  ClipPanel.prototype.reset = function () {
    this.entries = clone(this.initialEntries);
    this.query = '';
    if (this.input) this.input.value = '';
    this.selectedId = this.visibleEntries()[0] ? this.visibleEntries()[0].id : null;
    this.renderList();
    var noteContent = $('[data-note-content]');
    var noteMeta = $('[data-note-meta]');
    if (noteContent) noteContent.innerHTML = NOTE_EMPTY;
    if (noteMeta) noteMeta.textContent = '等待第一次粘贴';
    this.showToast('演示已重置');
  };

  ClipPanel.prototype.clearUnpinned = function () {
    var before = this.entries.length;
    this.entries = this.entries.filter(function (entry) { return entry.pinned; });
    var removed = before - this.entries.length;
    this.selectedId = null;
    this.renderList();
    return removed;
  };

  ClipPanel.prototype.bind = function () {
    var self = this;

    this.el.addEventListener('click', function (event) {
      var action = event.target.closest('[data-action]');
      if (!action || !self.el.contains(action)) return;
      var id = action.getAttribute('data-id');
      var entry = self.entries.find(function (item) { return item.id === id; });

      if (action.dataset.action === 'settings') {
        if (self.onSettings) self.onSettings();
        return;
      }
      if (!entry) return;

      if (action.dataset.action === 'pin') {
        event.preventDefault();
        entry.pinned = !entry.pinned;
        self.selectedId = entry.id;
        self.renderWithFlip();
        var pinAgain = $('[data-action="pin"][data-id="' + entry.id + '"]', self.el);
        if (pinAgain) pinAgain.focus({ preventScroll: true });
      } else if (action.dataset.action === 'delete') {
        event.preventDefault();
        self.entries = self.entries.filter(function (item) { return item.id !== entry.id; });
        self.renderList();
        self.el.focus({ preventScroll: true });
      } else if (action.dataset.action === 'paste') {
        self.paste(entry);
      }
    });

    if (this.input) {
      this.input.addEventListener('input', function (event) {
        self.query = event.target.value;
        self.selectedId = null;
        self.renderList();
      });
    }

    this.el.addEventListener('keydown', function (event) {
      if (event.key === 'ArrowDown') {
        event.preventDefault();
        self.move(1);
      } else if (event.key === 'ArrowUp') {
        event.preventDefault();
        self.move(-1);
      } else if (event.key === 'Enter') {
        if (event.isComposing) return;
        event.preventDefault();
        var visible = self.visibleEntries();
        var entry = visible.find(function (item) { return item.id === self.selectedId; }) || visible[0];
        if (entry) self.paste(entry);
      } else if (event.key === 'Escape') {
        if (self.query) {
          event.preventDefault();
          self.query = '';
          if (self.input) self.input.value = '';
          self.selectedId = null;
          self.renderList();
        } else if (self.input) {
          self.input.blur();
        }
      }
    });

    this.el.addEventListener('pointerdown', function (event) {
      if (event.target.closest('button, input')) return;
      self.el.focus({ preventScroll: true });
    });
  };

  /* ---------------------------------------------------------
     Screenshots, lightbox, theme, copy, reveal
     --------------------------------------------------------- */

  var lightbox = $('#lightbox');
  var lightboxImage = $('[data-lightbox-img]');
  var lightboxCaption = $('#lightbox figcaption');

  function openLightbox(source, alt, caption) {
    if (!lightbox || !lightboxImage) return;
    lightboxImage.src = source;
    lightboxImage.alt = alt || '';
    lightboxCaption.textContent = caption || '';
    if (typeof lightbox.showModal === 'function') {
      if (!lightbox.open) lightbox.showModal();
    } else {
      lightbox.setAttribute('open', '');
    }
  }

  function closeLightbox() {
    if (!lightbox) return;
    if (typeof lightbox.close === 'function' && lightbox.open) lightbox.close();
    else lightbox.removeAttribute('open');
  }

  if (lightbox) {
    lightbox.addEventListener('click', function (event) {
      if (event.target === lightbox) closeLightbox();
    });
    $$('[data-lightbox-close]').forEach(function (button) {
      button.addEventListener('click', closeLightbox);
    });
  }

  var pageToast = $('[data-page-toast]');
  var pageToastTimer = null;
  function showPageToast(message) {
    if (!pageToast) return;
    pageToast.textContent = message;
    pageToast.classList.add('is-visible');
    clearTimeout(pageToastTimer);
    pageToastTimer = setTimeout(function () {
      pageToast.classList.remove('is-visible');
    }, 1800);
  }

  function fallbackCopy(text) {
    var area = document.createElement('textarea');
    area.value = text;
    area.setAttribute('readonly', '');
    area.style.position = 'fixed';
    area.style.opacity = '0';
    area.style.pointerEvents = 'none';
    document.body.appendChild(area);
    area.select();
    var ok = false;
    try { ok = document.execCommand('copy'); } catch (error) { ok = false; }
    document.body.removeChild(area);
    return ok;
  }

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text).then(function () { return true; }).catch(function () {
        return fallbackCopy(text);
      });
    }
    return Promise.resolve(fallbackCopy(text));
  }

  function selectCopySource(button) {
    var scope = button.closest('.copy-path') || button.closest('.terminal') || button.closest('.code-card') || button.parentElement;
    var source = scope && scope.querySelector('code, pre');
    if (!source || !window.getSelection) return false;
    var range = document.createRange();
    range.selectNodeContents(source);
    var selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    return true;
  }

  $$('[data-copy]').forEach(function (button) {
    button.addEventListener('click', function () {
      var text = button.getAttribute('data-copy');
      copyText(text).then(function (ok) {
        if (!ok) {
          var selected = selectCopySource(button);
          showPageToast(selected ? '已选中，按 ⌘C 复制' : '复制失败，请手动选择');
          return;
        }
        var label = button.querySelector('span');
        var previous = label ? label.textContent : '';
        if (label) label.textContent = '已复制';
        showPageToast('已复制到剪贴板');
        setTimeout(function () {
          if (label) label.textContent = previous;
        }, 1500);
      });
    });
  });

  // real screenshots -> lightbox
  $$('[data-lightbox-src]').forEach(function (button) {
    button.addEventListener('click', function () {
      openLightbox(
        button.getAttribute('data-lightbox-src'),
        button.getAttribute('data-lightbox-alt'),
        button.getAttribute('data-lightbox-caption')
      );
    });
  });

  // theme
  var themeButtons = $$('[data-theme-mode]');
  var systemDark = window.matchMedia('(prefers-color-scheme: dark)');
  var themeColorMeta = document.querySelector('meta[name="theme-color"]');
  var currentThemeMode = document.documentElement.dataset.themeMode || 'auto';

  function applyTheme(mode, persist) {
    currentThemeMode = mode;
    var dark = mode === 'dark' || (mode === 'auto' && systemDark.matches);
    document.documentElement.dataset.theme = dark ? 'dark' : 'light';
    document.documentElement.dataset.themeMode = mode;
    themeButtons.forEach(function (button) {
      button.setAttribute('aria-pressed', String(button.getAttribute('data-theme-mode') === mode));
    });
    $$('[data-appearance]').forEach(function (button) {
      var active = button.getAttribute('data-appearance') === mode;
      button.classList.toggle('is-on', active);
      button.setAttribute('aria-pressed', String(active));
    });
    if (themeColorMeta) themeColorMeta.setAttribute('content', dark ? '#0a0b0d' : '#f5f5f7');
    if (persist) {
      try { localStorage.setItem('iclip-theme', mode); } catch (error) { /* private mode */ }
    }
  }

  themeButtons.forEach(function (button) {
    button.addEventListener('click', function () {
      applyTheme(button.getAttribute('data-theme-mode'), true);
    });
  });
  $$('[data-appearance]').forEach(function (button) {
    button.addEventListener('click', function () {
      applyTheme(button.getAttribute('data-appearance'), true);
    });
  });
  applyTheme(currentThemeMode, false);
  var onSystemThemeChange = function () {
    if (currentThemeMode === 'auto') applyTheme('auto', false);
  };
  if (typeof systemDark.addEventListener === 'function') systemDark.addEventListener('change', onSystemThemeChange);
  else if (typeof systemDark.addListener === 'function') systemDark.addListener(onSystemThemeChange);

  // reveal on scroll
  var revealElements = $$('.reveal');
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (!reduceMotion && 'IntersectionObserver' in window) {
    var revealObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-in');
        revealObserver.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -6% 0px', threshold: 0.06 });
    revealElements.forEach(function (element) { revealObserver.observe(element); });
  } else {
    revealElements.forEach(function (element) { element.classList.add('is-in'); });
  }

  // nav state
  var navWrap = $('.nav-wrap');
  var onScroll = function () {
    if (navWrap) navWrap.classList.toggle('is-scrolled', window.scrollY > 8);
  };
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  var navLinks = $$('[data-nav]');
  if (navLinks.length && 'IntersectionObserver' in window) {
    var sectionObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        navLinks.forEach(function (link) {
          link.classList.toggle('is-active', link.getAttribute('href') === '#' + entry.target.id);
        });
      });
    }, { rootMargin: '-42% 0px -52% 0px' });
    navLinks.forEach(function (link) {
      var section = document.querySelector(link.getAttribute('href'));
      if (section) sectionObserver.observe(section);
    });
  }

  // panels
  var heroMount = $('[data-panel="hero"]');
  if (heroMount) new ClipPanel(heroMount, { readonly: true, entries: SEED.slice(0, 4) });

  var demoMount = $('[data-panel="demo"]');
  var demoPanel = null;
  if (demoMount) {
    demoPanel = new ClipPanel(demoMount, {
      readonly: false,
      onSettings: function () {
        openLightbox('assets/settings-light.png', 'iClip 设置窗口截图', '设置窗口 · 分组表单 · 权限状态实时刷新');
      }
    });
  }

  var resetButton = $('[data-demo-reset]');
  if (resetButton && demoPanel) {
    resetButton.addEventListener('click', function () { demoPanel.reset(); });
  }

  /* ---------------------------------------------------------
     SwiftUI settings recreation
     --------------------------------------------------------- */

  var limit = 1000;
  var limitValue = $('[data-limit-value]');
  function renderLimit() {
    if (limitValue) limitValue.textContent = limit === 0 ? '不限' : String(limit);
  }
  $$('[data-limit-step]').forEach(function (button) {
    button.addEventListener('click', function () {
      limit = Math.max(0, Math.min(5000, limit + Number(button.getAttribute('data-limit-step'))));
      renderLimit();
    });
  });

  $$('[data-toggle]').forEach(function (button) {
    button.addEventListener('click', function () {
      var on = !button.classList.contains('is-on');
      button.classList.toggle('is-on', on);
      button.setAttribute('aria-checked', String(on));
      var label = button.getAttribute('aria-label') || '设置';
      showPageToast('演示：' + label + (on ? '已开启' : '已关闭'));
    });
  });

  var clearDialog = $('#clearDialog');
  var clearHistoryButton = $('[data-clear-history]');
  function closeClearDialog() {
    if (!clearDialog) return;
    if (typeof clearDialog.close === 'function' && clearDialog.open) clearDialog.close();
    else clearDialog.removeAttribute('open');
  }
  if (clearHistoryButton && clearDialog) {
    clearHistoryButton.addEventListener('click', function () {
      if (typeof clearDialog.showModal === 'function') {
        if (!clearDialog.open) clearDialog.showModal();
      } else {
        clearDialog.setAttribute('open', '');
      }
    });
    var clearCancel = $('[data-clear-cancel]');
    var clearConfirm = $('[data-clear-confirm]');
    if (clearCancel) clearCancel.addEventListener('click', closeClearDialog);
    if (clearConfirm) {
      clearConfirm.addEventListener('click', function () {
        var removed = demoPanel ? demoPanel.clearUnpinned() : 0;
        closeClearDialog();
        showPageToast(removed ? '已清除 ' + removed + ' 条演示历史' : '没有可清除的演示历史');
      });
    }
    clearDialog.addEventListener('click', function (event) {
      if (event.target === clearDialog) closeClearDialog();
    });
  }

  // shortcut recorder
  var shortcutButton = $('[data-shortcut-recorder]');
  var shortcutReset = $('[data-shortcut-reset]');
  var shortcutNote = $('[data-shortcut-note]');
  var shortcutNoteDefault = shortcutNote ? shortcutNote.textContent : '';
  var shortcutValue = '⌃⇧V';
  var recordingShortcut = false;
  var shortcutKeyHandler = null;
  var shortcutNoteTimer = null;

  function resetShortcutNote() {
    if (!shortcutNote) return;
    shortcutNote.textContent = shortcutNoteDefault;
    shortcutNote.classList.remove('is-error');
  }

  function renderShortcut() {
    if (shortcutButton) shortcutButton.textContent = shortcutValue;
    $$('.shortcut-badge').forEach(function (badge) { badge.textContent = shortcutValue; });
  }

  function stopShortcutRecording() {
    recordingShortcut = false;
    if (shortcutButton) shortcutButton.classList.remove('is-recording');
    if (shortcutKeyHandler) {
      window.removeEventListener('keydown', shortcutKeyHandler, true);
      shortcutKeyHandler = null;
    }
    renderShortcut();
  }

  function cancelShortcutRecording() {
    stopShortcutRecording();
    resetShortcutNote();
  }

  if (shortcutButton) {
    shortcutButton.addEventListener('click', function () {
      if (recordingShortcut) return;
      clearTimeout(shortcutNoteTimer);
      recordingShortcut = true;
      shortcutButton.classList.add('is-recording');
      shortcutButton.textContent = '请按组合键…';
      if (shortcutNote) {
        shortcutNote.textContent = '按下组合键，Esc 取消。';
        shortcutNote.classList.remove('is-error');
      }
      shortcutKeyHandler = function (event) {
        if (!recordingShortcut) return;
        if (['Control', 'Alt', 'Shift', 'Meta'].indexOf(event.key) !== -1) {
          event.preventDefault();
          return;
        }
        event.preventDefault();
        event.stopPropagation();
        if (event.key === 'Escape' || event.key === 'Tab') {
          cancelShortcutRecording();
          return;
        }
        var mods = '';
        if (event.ctrlKey) mods += '⌃';
        if (event.altKey) mods += '⌥';
        if (event.shiftKey) mods += '⇧';
        if (event.metaKey) mods += '⌘';
        var key = event.key;
        if (key === ' ') key = 'Space';
        else if (key.length === 1) key = key.toUpperCase();
        else {
          var names = {
            ArrowUp: '↑', ArrowDown: '↓', ArrowLeft: '←', ArrowRight: '→',
            Enter: '↩', Backspace: '⌫', Delete: '⌦', Escape: 'Esc'
          };
          key = names[key] || key;
        }
        if (!event.ctrlKey && !event.altKey && !event.metaKey) {
          stopShortcutRecording();
          if (shortcutNote) {
            shortcutNote.textContent = '组合键必须包含 Control、Option 或 Command。';
            shortcutNote.classList.add('is-error');
          }
          clearTimeout(shortcutNoteTimer);
          shortcutNoteTimer = setTimeout(resetShortcutNote, 2200);
          return;
        }
        shortcutValue = mods + key;
        stopShortcutRecording();
        if (shortcutNote) {
          shortcutNote.textContent = '已更新为 ' + shortcutValue + '（演示）';
          shortcutNote.classList.remove('is-error');
        }
        clearTimeout(shortcutNoteTimer);
        shortcutNoteTimer = setTimeout(resetShortcutNote, 2200);
        showPageToast('快捷键已更新（演示）');
        shortcutButton.focus();
      };
      window.addEventListener('keydown', shortcutKeyHandler, true);
      shortcutButton.focus();
    });
    shortcutButton.addEventListener('blur', function () {
      if (recordingShortcut) cancelShortcutRecording();
    });
  }

  if (shortcutReset) {
    shortcutReset.addEventListener('click', function () {
      if (recordingShortcut) stopShortcutRecording();
      shortcutValue = '⌃⇧V';
      renderShortcut();
      resetShortcutNote();
      showPageToast('快捷键已还原为 ⌃⇧V');
    });
  }

  // code copy
  var codeCopy = $('[data-copy-code]');
  var settingsCode = $('#settingsCode');
  if (codeCopy && settingsCode) {
    codeCopy.addEventListener('click', function () {
      var text = settingsCode.innerText;
      copyText(text).then(function (ok) {
        if (!ok) {
          var selected = selectCopySource(codeCopy);
          showPageToast(selected ? '已选中，按 ⌘C 复制' : '复制失败，请手动选择');
          return;
        }
        var label = codeCopy.querySelector('span');
        var previous = label ? label.textContent : '';
        if (label) label.textContent = '已复制';
        showPageToast('SwiftUI 代码已复制');
        setTimeout(function () {
          if (label) label.textContent = previous;
        }, 1500);
      });
    });
  }
})();
