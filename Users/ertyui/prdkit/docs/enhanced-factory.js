/* ============================================================
   PRDKit — Enhanced File Factory + AI Streaming + Smart Actions
   Overrides renderExportTab() with gradient file cards,
   streaming AI revision, one-click smart actions, auto-suggest.
   ============================================================ */

(function () {
  'use strict';

  // ─── File Metadata ───
  var FILE_META = {
    prompt:    { label: 'Super Prompt',    desc: 'Prompt siap pakai untuk AI coding tools',          icon: 'prompt',    color: '#a78bfa' },
    prd:       { label: 'PRD Document',     desc: 'Product Requirements Document lengkap',            icon: 'prd',       color: '#60a5fa' },
    readme:    { label: 'README.md',        desc: 'Dokumentasi proyek untuk repository',              icon: 'readme',    color: '#fbbf24' },
    summary:   { label: 'Ringkasan',        desc: 'Ringkasan eksekutif untuk stakeholder',           icon: 'ringkasan', color: 'var(--accent)' },
    ringkasan: { label: 'Ringkasan',        desc: 'Ringkasan eksekutif untuk stakeholder',           icon: 'ringkasan', color: 'var(--accent)' },
  };

  function escapeHtml(text) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(text));
    return div.innerHTML;
  }

  function formatSize(bytes) {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / 1048576).toFixed(1) + ' MB';
  }

  function formatFileName(id) {
    if (id === 'prompt') return 'prompt.md';
    if (id === 'prd') return 'prd.md';
    if (id === 'readme') return 'README.md';
    if (id === 'summary' || id === 'ringkasan') return 'ringkasan.md';
    if (id.startsWith('engine-')) return id.replace('engine-', '') + '.json';
    if (id === 'metadata') return 'project-metadata.json';
    return id + '.md';
  }

  function getFileIconClass(id) {
    if (id === 'prompt') return 'prompt';
    if (id === 'prd') return 'prd';
    if (id === 'readme') return 'readme';
    if (id === 'summary' || id === 'ringkasan') return 'ringkasan';
    if (id.startsWith('engine-') || id === 'metadata') return 'engine';
    return 'archive';
  }

  function getFileIcon(id) {
    var cls = getFileIconClass(id);
    var map = { prompt: '&lt;/&gt;', prd: 'PRD', readme: 'MD', ringkasan: '&#9998;', engine: '{ }', archive: '&#128230;' };
    return map[cls] || '&#128196;';
  }

  var ICON_SVG = {
    eye: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>',
    copy: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>',
    download: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>',
    close: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>',
    refresh: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>',
    check: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>',
    zap: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>',
    lightbulb: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 18h6"/><path d="M10 22h4"/><path d="M15.09 14c.18-.98.65-1.74 1.41-2.5A4.65 4.65 0 0 0 18 8 6 6 0 0 0 6 8c0 1 .23 2.23 1.5 3.5A4.61 4.61 0 0 1 8.91 14"/></svg>',
  };

  // ─── Streaming AI ───
  // Reads SSE from Cloudflare Worker, token by token.
  const WORKER_CHAT_URL = (typeof API_URL !== 'undefined' ? API_URL : 'https://prdkit-ai-proxy.halugoods-indonesia.workers.dev') + '/api/chat';

  window.streamingCallAI = function(messages, opts) {
    opts = opts || {};
    var onToken = opts.onToken || function(){};
    var onComplete = opts.onComplete || function(){};
    var onError = opts.onError || function(){};

    var provider = (typeof state !== 'undefined' && state.aiProvider) ? state.aiProvider : 'sumopod';
    var model = (typeof state !== 'undefined' && state.aiModel) ? state.aiModel : 'deepseek-v4-flash';
    var baseUrl = (typeof state !== 'undefined' && state.baseUrl) ? state.baseUrl : '';

    var apiKey = (typeof KEY_STORE !== 'undefined') ? KEY_STORE.get() : '';

    var body = {
      messages: [
        { role: 'system', content: 'Jawab dalam Bahasa Indonesia yang alami dan mudah dipahami. Gunakan istilah teknis Inggris jika diperlukan, tetapi penjelasan harus dalam Bahasa Indonesia.' },
        { role: 'system', content: 'Output langsung hasilnya tanpa menjelaskan proses atau perubahan yang kamu buat.' }
      ].concat(messages),
      model: model,
      stream: true,
      temperature: 0.7,
      max_tokens: 8192,
      config: { provider: provider, model: model, baseUrl: baseUrl },
    };
    if (apiKey) body.config.apiKey = apiKey;

    var fullText = '';
    var aborted = false;

    window._abortStream = function() { aborted = true; };

    fetch(WORKER_CHAT_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(body),
    }).then(function(response) {
      if (!response.ok) {
        return response.text().then(function(err) { onError('Server error: ' + err); });
      }
      var reader = response.body.getReader();
      var decoder = new TextDecoder();
      var buffer = '';

      function read() {
        reader.read().then(function(result) {
          if (aborted) { reader.cancel(); return; }
          if (result.done) {
            // Flush remaining buffer
            if (buffer.trim()) parseLine(buffer.trim());
            onComplete(fullText);
            return;
          }
          buffer += decoder.decode(result.value, { stream: true });
          var lines = buffer.split('\n');
          buffer = lines.pop() || '';
          for (var i = 0; i < lines.length; i++) {
            parseLine(lines[i].trim());
          }
          read();
        }).catch(function(err) {
          onError('Stream read error: ' + err.message);
        });
      }

      function parseLine(line) {
        if (!line || !line.startsWith('data: ')) return;
        var data = line.slice(6).trim();
        if (data === '[DONE]') return;
        try {
          var parsed = JSON.parse(data);
          var content = parsed.choices && parsed.choices[0] && parsed.choices[0].delta && parsed.choices[0].delta.content;
          if (content) {
            fullText += content;
            onToken(content, fullText);
          }
        } catch(e) { /* skip malformed json */ }
      }

      read();

    }).catch(function(err) {
      onError('Fetch error: ' + (err.message || 'Connection failed'));
    });
  };

  // ─── Smart Action Presets ───
  var SMART_ACTIONS = [
    { label: 'Tambah API', icon: 'zap', prompt: 'Tambahkan dokumentasi endpoint API lengkap untuk setiap fitur: metode HTTP, path, request/response schema, contoh payload. Output blueprint revisi LENGKAP dalam Bahasa Indonesia.' },
    { label: 'Perbaiki Struktur', icon: 'lightbulb', prompt: 'Perbaiki struktur dokumen PRD agar lebih rapi dan mudah dibaca. Gunakan heading hierarchy yang jelas, tambahkan table of contents, kelompokkan informasi terkait. Output blueprint revisi LENGKAP dalam Bahasa Indonesia.' },
    { label: 'Deployment', icon: 'download', prompt: 'Tambahkan section deployment guide: platform target, environment variables, build steps, CI/CD pipeline, database migration strategy. Output blueprint revisi LENGKAP dalam Bahasa Indonesia.' },
    { label: 'Testing', icon: 'check', prompt: 'Tambahkan testing strategy: unit test, integration test, E2E test, tools yang digunakan, coverage target. Output blueprint revisi LENGKAP dalam Bahasa Indonesia.' },
    { label: 'Keamanan', icon: 'eye', prompt: 'Tambahkan security checklist: authentication, authorization, data encryption, input validation, rate limiting, CORS, secrets management. Output blueprint revisi LENGKAP dalam Bahasa Indonesia.' },
  ];

  // ─── Override renderExportTab — Design Opus Taste ───
  var ICONS = {
    prompt: '&lt;/&gt;',
    prd: 'PRD',
    readme: 'MD',
    summary: '&#9998;',
    ringkasan: '&#9998;',
  };

  var originalRenderExport = window.renderExportTab || function(){};
  window.renderExportTab = function() {
    var container = document.getElementById('resultTabExport');
    if (!container) return;

    var artifacts = (typeof state !== 'undefined' && state.artifacts) ? state.artifacts : [];
    if (!artifacts.length) {
      container.innerHTML = '<div class="result-empty"><div class="result-empty-icon">' + ICON_SVG.copy + '</div><div class="result-empty-title">Belum ada data</div><div class="result-empty-desc">Generate blueprint dulu untuk mengekspor.</div></div>';
      if (typeof showToast === 'function') showToast('Belum ada artifacts untuk diekspor', 'info');
      return;
    }

    var html = '<div class="result-page">';

    // ── Header ──
    var productName = state.productName || 'Blueprint';
    html += '<div class="result-header-wrap">';
    html += '  <div class="result-badge"><span class="ping"></span>BLUEPRINT</div>';
    html += '  <div class="result-header-title">' + escapeHtml(productName) + '</div>';
    html += '  <div class="result-header-desc">Dokumen teknis siap pakai — salin, download, atau revisi.</div>';
    html += '</div>';

    // ── Actions ──
    html += '<div class="result-actions-strip">';
    html += '  <button class="btn-cta primary" onclick="enhancedCopyAll()">' + ICON_SVG.copy + ' Copy All</button>';
    html += '  <button class="btn-cta" onclick="enhancedDownloadAll()">' + ICON_SVG.download + ' Download All ZIP</button>';
    html += '</div>';

    // ── File Cards ──
    html += '<div class="file-factory-grid">';

    var priority = { prompt: 1, prd: 2, readme: 3, summary: 4, ringkasan: 4 };
    var sorted = artifacts.slice().sort(function (a, b) {
      var pa = priority[a.id] || 99;
      var pb = priority[b.id] || 99;
      if (pa !== pb) return pa - pb;
      return a.id.localeCompare(b.id);
    });

    sorted.forEach(function (a) {
      if (a.id === 'metadata') return;

      var meta = FILE_META[a.id] || { label: a.label || a.id, desc: 'File artifact', color: 'var(--accent)' };
      var iconContent = ICONS[a.id] || '&#128196;';
      var size = a.content ? new Blob([a.content]).size : 0;
      var fileName = formatFileName(a.id);
      var safeId = a.id.replace(/'/g, "\\'");
      var accentColor = meta.color;

      html += '<div class="file-card-ambient" onclick="openFilePreview(\'' + safeId + '\')">';
      html += '  <div class="file-card-ambient-inner" style="--card-accent:' + accentColor + '">';

      // Top: icon + info + size
      html += '    <div class="file-card-top">';
      html += '      <div class="icon-wrap-file">' + iconContent + '</div>';
      html += '      <div class="file-card-info">';
      html += '        <div class="file-card-title">' + escapeHtml(meta.label) + '</div>';
      html += '        <div class="file-card-desc">' + escapeHtml(meta.desc) + '</div>';
      html += '      </div>';
      html += '      <span class="file-card-size">' + formatSize(size) + '</span>';
      html += '    </div>';

      // Actions: filename + buttons
      html += '    <div class="file-card-actions">';
      html += '      <span class="file-card-filename">' + fileName + '</span>';
      html += '      <div class="file-card-btns">';
      html += '        <button class="btn-icon-file" onclick="event.stopPropagation();openFilePreview(\'' + safeId + '\')" title="Preview">' + ICON_SVG.eye + '</button>';
      html += '        <button class="btn-icon-file" onclick="event.stopPropagation();copyFileContent(\'' + safeId + '\')" title="Salin">' + ICON_SVG.copy + '</button>';
      html += '        <button class="btn-icon-file" onclick="event.stopPropagation();downloadFileById(\'' + safeId + '\')" title="Download">' + ICON_SVG.download + '</button>';
      html += '        <span class="file-chat-toggle" onclick="event.stopPropagation();toggleFileChat(\'' + safeId + '\')">💬 Revisi</span>';
      html += '      </div>';
      html += '    </div>';

      // Per-file chat
      html += '    <div class="file-chat-panel" id="fileChat-' + safeId + '">';
      html += '      <div class="file-chat-messages"></div>';
      html += '      <div class="file-chat-input-row">';
      html += '        <input class="file-chat-input" placeholder="Instruksi revisi file ini..." onkeydown="if(event.key===\'Enter\')sendFileChat(\'' + safeId + '\')">';
      html += '        <button class="file-chat-send" onclick="sendFileChat(\'' + safeId + '\')">Kirim</button>';
      html += '      </div>';
      html += '    </div>';

      html += '  </div>';
      html += '</div>';
    });

    html += '</div>'; // .file-factory-grid

    // ── Toolkit: Smart Actions + Revision ──
    html += '<div class="result-toolkit">';

    // Toolkit header
    html += '  <div class="toolkit-header">';
    html += '    <div class="icon-wrap-file" style="--card-accent:var(--accent)">' + ICON_SVG.zap + '</div>';
    html += '    <div class="toolkit-header-info">';
    html += '      <div class="toolkit-title">Toolkit</div>';
    html += '      <div class="toolkit-desc">Enhance cepat atau revisi dengan AI</div>';
    html += '    </div>';
    html += '  </div>';

    // Smart Action chips
    html += '  <div class="smart-chips">';
    SMART_ACTIONS.forEach(function(a) {
      html += '    <span class="chip-action" onclick="runSmartAction(\'' + a.label + '\')" title="' + escapeHtml(a.prompt.substring(0, 80)) + '...">' + (ICON_SVG[a.icon] || '') + ' ' + a.label + '</span>';
    });
    html += '  </div>';

    // Revision — glass card
    html += '  <div class="glass-card">';
    html += '    <div class="glass-card-inner">';

    // Revision header
    html += '      <div class="toolkit-header" style="margin-bottom:14px">';
    html += '        <div class="icon-wrap-file" style="width:32px;height:32px;font-size:12px;border-radius:10px;--card-accent:var(--accent)">' + ICON_SVG.refresh + '</div>';
    html += '        <div class="toolkit-header-info">';
    html += '          <div class="toolkit-title" style="font-size:13px">AI Revisi <span style="font-size:9px;color:var(--accent);font-weight:400;opacity:0.7">streaming</span></div>';
    html += '          <div class="toolkit-desc">Instruksi revisi dikirim ke AI, hasil muncul realtime</div>';
    html += '        </div>';
    html += '      </div>';

    html += '      <textarea class="revision-textarea" id="revisionInput" placeholder="Contoh: Tambah fitur notifikasi email, ganti database ke Supabase, atau ubah arsitektur jadi microservices..." oninput="toggleRevisionBtn()"></textarea>';

    html += '      <div class="revision-actions-row">';
    html += '        <button class="btn-cta" onclick="processRevision()" id="revisionBtn" disabled style="padding:8px 18px;font-size:11px">' + ICON_SVG.refresh + ' Proses Revisi</button>';
    html += '        <button class="btn-cta" onclick="cancelStreaming()" id="cancelStreamBtn" style="display:none;padding:8px 18px;font-size:11px">' + ICON_SVG.close + ' Batal</button>';
    html += '        <span id="streamStatus" style="font-size:11px;color:rgba(255,255,255,0.35);display:none">Menulis...</span>';
    html += '      </div>';

    html += '      <div id="streamingOutput" class="streaming-output" style="display:none">';
    html += '        <div class="streaming-output-header">';
    html += '          <span id="streamFileName" style="font-size:11px;font-weight:600;color:var(--text)">Revisi</span>';
    html += '          <span class="streaming-dot"></span>';
    html += '        </div>';
    html += '        <div id="streamContent" class="streaming-content"></div>';
    html += '      </div>';

    html += '      <div id="revisionActions" style="display:none;gap:8px;margin-top:10px">';
    html += '        <button class="btn-cta primary" onclick="applyRevision()" style="padding:8px 18px;font-size:11px">' + ICON_SVG.check + ' Terapkan</button>';
    html += '        <button class="btn-cta" onclick="discardRevision()" style="padding:8px 18px;font-size:11px">' + ICON_SVG.close + ' Discard</button>';
    html += '      </div>';

    html += '    </div>'; // .glass-card-inner
    html += '  </div>'; // .glass-card

    html += '</div>'; // .result-toolkit

    // ── Version History ──
    if (state.versions && state.versions.length > 1) {
      html += '<div class="version-section">';
      html += '  <div class="toolkit-header" style="margin-bottom:14px">';
      html += '    <div class="icon-wrap-file" style="width:32px;height:32px;font-size:12px;border-radius:10px;--card-accent:#60A5FA">' + ICON_SVG.refresh + '</div>';
      html += '    <div class="toolkit-header-info">';
      html += '      <div class="toolkit-title" style="font-size:13px">Version History</div>';
      html += '      <div class="toolkit-desc">Klik versi untuk melihat blueprint sebelumnya</div>';
      html += '    </div>';
      html += '  </div>';
      html += '  <div class="version-pills">';
      state.versions.forEach(function(v, i) {
        html += '    <span class="version-btn' + (i === state.currentVersion ? ' active' : '') + '" onclick="switchVersion(' + i + ')">' + v.version + '</span>';
      });
      html += '  </div>';
      html += '</div>';
    }

    html += '</div>'; // .result-page
    container.innerHTML = html;
  };
  window.toggleRevisionBtn = function() {
    var btn = document.getElementById('revisionBtn');
    var input = document.getElementById('revisionInput');
    if (btn && input) {
      btn.disabled = !input.value.trim();
    }
  };

  // ─── Streaming Revision State ───
  var _revisionState = {
    fullText: '',
    inProgress: false,
  };

  // ─── Process Revision (Streaming) ───
  window.processRevision = function() {
    var input = document.getElementById('revisionInput');
    if (!input || !input.value.trim()) {
      if (typeof showToast === 'function') showToast('Tulis instruksi revisi dulu', 'warning');
      return;
    }

    var instructions = input.value.trim();
    var btn = document.getElementById('revisionBtn');
    var cancelBtn = document.getElementById('cancelStreamBtn');
    var statusEl = document.getElementById('streamStatus');
    var outputArea = document.getElementById('streamingOutput');
    var contentArea = document.getElementById('streamContent');
    var actionsRow = document.getElementById('revisionActions');

    _revisionState.inProgress = true;
    _revisionState.fullText = '';

    // UI: show streaming area, hide actions
    btn.style.display = 'none';
    cancelBtn.style.display = 'inline-flex';
    statusEl.style.display = 'inline';
    statusEl.textContent = 'Menulis...';
    outputArea.style.display = 'block';
    contentArea.innerHTML = '<span style="color:var(--text-muted);font-style:italic">Menghasilkan revisi...</span>';
    actionsRow.style.display = 'none';

    // Get current PRD content as base
    var prdArtifact = (state.artifacts || []).find(function(a) { return a.id === 'prd'; });
    var baseContent = prdArtifact ? prdArtifact.content : '';
    var productName = state.productName || 'Produk';

    var revisionPrompt = [
      'Kamu adalah technical product manager senior.',
      '',
      '=== KONTEKS ===',
      'Produk: ' + productName,
      '',
      '=== BLUEPRINT SAAT INI ===',
      baseContent,
      '',
      '=== INSTRUKSI REVISI ===',
      instructions,
      '',
      '=== TUGAS ===',
      'Hasilkan blueprint REVISI LENGKAP berdasarkan instruksi di atas.',
      'Output dalam Bahasa Indonesia. Format markdown.',
      'JANGAN jelaskan perubahannya — langsung output blueprint yang sudah direvisi.',
      'JANGAN tambahkan disclaimer atau catatan di awal/akhir — langsung isi dokumen.',
    ].join('\n');

    window.streamingCallAI(
      [{ role: 'user', content: revisionPrompt }],
      {
        onToken: function(token, fullText) {
          if (contentArea.querySelector('.streaming-placeholder')) {
            contentArea.innerHTML = '';
          }
          // Auto-scroll to bottom
          var isNearBottom = contentArea.scrollHeight - contentArea.scrollTop - contentArea.clientHeight < 100;
          contentArea.innerHTML = '<pre class="streaming-pre">' + escapeHtml(fullText) + '</pre>';
          if (isNearBottom) {
            contentArea.scrollTop = contentArea.scrollHeight;
          }
          _revisionState.fullText = fullText;
        },
        onComplete: function(fullText) {
          _revisionState.inProgress = false;
          _revisionState.fullText = fullText;
          cancelBtn.style.display = 'none';
          statusEl.style.display = 'none';

          if (fullText && fullText.length > 50) {
            contentArea.innerHTML = '<pre class="streaming-pre streaming-done">' + escapeHtml(fullText) + '</pre>';
            actionsRow.style.display = 'flex';
            if (typeof showToast === 'function') showToast('Revisi selesai! Klik Terapkan untuk menyimpan.', 'success');
          } else {
            contentArea.innerHTML = '<div style="color:var(--text-muted);padding:12px">Hasil revisi terlalu pendek. Coba dengan instruksi yang lebih detail.</div>';
            btn.style.display = 'inline-flex';
            if (typeof showToast === 'function') showToast('Hasil revisi kurang memadai, coba lagi', 'error');
          }
        },
        onError: function(err) {
          _revisionState.inProgress = false;
          cancelBtn.style.display = 'none';
          statusEl.style.display = 'none';
          contentArea.innerHTML = '<div style="color:#ef4444;padding:12px">Gagal: ' + escapeHtml(err) + '</div>';
          btn.style.display = 'inline-flex';
          btn.disabled = false;
          if (typeof showToast === 'function') showToast('Gagal memproses revisi', 'error');
        }
      }
    );
  };

  // ─── Cancel Streaming ───
  window.cancelStreaming = function() {
    if (window._abortStream) window._abortStream();
    _revisionState.inProgress = false;

    var btn = document.getElementById('revisionBtn');
    var cancelBtn = document.getElementById('cancelStreamBtn');
    var statusEl = document.getElementById('streamStatus');
    var actionsRow = document.getElementById('revisionActions');
    var outputArea = document.getElementById('streamingOutput');

    cancelBtn.style.display = 'none';
    statusEl.style.display = 'none';
    actionsRow.style.display = 'none';
    outputArea.style.display = 'none';
    btn.style.display = 'inline-flex';
    btn.disabled = false;

    if (typeof showToast === 'function') showToast('Revisi dibatalkan', 'info');
  };

  // ─── Apply Revision ───
  window.applyRevision = function() {
    var text = _revisionState.fullText;
    if (!text || text.length < 50) {
      if (typeof showToast === 'function') showToast('Tidak ada konten revisi untuk diterapkan', 'error');
      return;
    }

    // Find or create PRD artifact
    var prdArtifact = (state.artifacts || []).find(function(a) { return a.id === 'prd'; });
    if (prdArtifact) {
      // Save current state as version before overwriting
      if (state.versions) {
        var versionNum = 'v' + (state.versions.length + 1) + '.0';
        state.versions.push({
          version: versionNum,
          artifacts: JSON.parse(JSON.stringify(state.artifacts)),
          timestamp: new Date().toISOString(),
        });
        state.currentVersion = state.versions.length - 1;
      }

      // Update PRD content
      prdArtifact.content = text;

      // Save state
      if (typeof saveState === 'function') saveState();
      if (typeof saveProject === 'function') saveProject();

      // Reset UI
      var actionsRow = document.getElementById('revisionActions');
      var outputArea = document.getElementById('streamingOutput');
      var btn = document.getElementById('revisionBtn');
      var input = document.getElementById('revisionInput');

      actionsRow.style.display = 'none';
      outputArea.style.display = 'none';
      btn.style.display = 'inline-flex';
      btn.disabled = true;
      if (input) input.value = '';

      // Refresh the tab
      if (typeof renderExportTab === 'function') renderExportTab();
      if (typeof showToast === 'function') showToast('Revisi berhasil diterapkan!', 'success');
    } else {
      if (typeof showToast === 'function') showToast('PRD artifact tidak ditemukan', 'error');
    }
  };

  // ─── Discard Revision ───
  window.discardRevision = function() {
    _revisionState.fullText = '';
    var actionsRow = document.getElementById('revisionActions');
    var outputArea = document.getElementById('streamingOutput');
    var btn = document.getElementById('revisionBtn');
    var input = document.getElementById('revisionInput');

    actionsRow.style.display = 'none';
    outputArea.style.display = 'none';
    btn.style.display = 'inline-flex';
    btn.disabled = true;
    if (input) input.value = '';

    if (typeof showToast === 'function') showToast('Revisi dibatalkan', 'info');
  };

  // ─── Smart Action Runner ───
  window.runSmartAction = function(label) {
    var action = SMART_ACTIONS.find(function(a) { return a.label === label; });
    if (!action) return;

    var input = document.getElementById('revisionInput');
    if (!input) return;

    input.value = action.prompt;

    // Auto-trigger processing with small delay so UI updates
    setTimeout(function() {
      if (typeof processRevision === 'function') processRevision();
    }, 100);
  };

  // ─── Preview Modal ───
  window.openFilePreview = function(artifactId) {
    var a = (state.artifacts || []).find(function(x) { return x.id === artifactId; });
    if (!a) {
      if (typeof showToast === 'function') showToast('File tidak ditemukan', 'error');
      return;
    }

    var existing = document.querySelector('.preview-overlay-enhanced');
    if (existing) existing.remove();

    var overlay = document.createElement('div');
    overlay.className = 'preview-overlay-enhanced';
    overlay.onclick = function(e) {
      if (e.target === overlay) closeFilePreview();
    };

    var fileName = formatFileName(a.id);
    var ext = fileName.endsWith('.json') ? 'JSON' : 'Markdown';

    overlay.innerHTML =
      '<div class="preview-modal-enhanced">' +
        '<div class="preview-modal-header">' +
          '<div style="display:flex;align-items:center;gap:10px">' +
            '<span style="font-weight:600;font-size:14px;color:var(--text)">' + escapeHtml(fileName) + '</span>' +
            '<span class="badge badge-blue" style="font-size:10px">' + ext + '</span>' +
          '</div>' +
          '<div class="preview-modal-actions">' +
            '<button class="btn-icon" onclick="copyCurrentPreview()" title="Salin">' + ICON_SVG.copy + ' Salin</button>' +
            '<button class="btn-icon" onclick="downloadCurrentPreview()" title="Download">' + ICON_SVG.download + '</button>' +
            '<button class="btn-icon" onclick="closeFilePreview()">' + ICON_SVG.close + '</button>' +
          '</div>' +
        '</div>' +
        '<div class="preview-modal-body">' +
          '<pre>' + escapeHtml(a.content) + '</pre>' +
        '</div>' +
      '</div>';

    document.body.appendChild(overlay);
    window._previewArtifact = a;

    window._previewCloseHandler = function(e) {
      if (e.key === 'Escape') closeFilePreview();
    };
    document.addEventListener('keydown', window._previewCloseHandler);
  };

  window.closeFilePreview = function() {
    var overlay = document.querySelector('.preview-overlay-enhanced');
    if (overlay) overlay.remove();
    window._previewArtifact = null;
    if (window._previewCloseHandler) {
      document.removeEventListener('keydown', window._previewCloseHandler);
    }
  };

  window.copyCurrentPreview = function() {
    var a = window._previewArtifact;
    if (!a || !a.content) return;
    navigator.clipboard.writeText(a.content).then(function() {
      if (typeof showToast === 'function') showToast('Tersalin ke clipboard!', 'success');
    }).catch(function() {
      if (typeof showToast === 'function') showToast('Gagal menyalin', 'error');
    });
  };

  window.downloadCurrentPreview = function() {
    var a = window._previewArtifact;
    if (!a || !a.content) return;
    var name = formatFileName(a.id);
    var mime = name.endsWith('.json') ? 'application/json' : 'text/markdown';
    if (typeof downloadFile === 'function') {
      downloadFile(a.content, name, mime);
      if (typeof showToast === 'function') showToast('Downloaded ' + name, 'success');
    }
  };

  // ─── File Actions ───
  window.copyFileContent = function(artifactId) {
    var a = (state.artifacts || []).find(function(x) { return x.id === artifactId; });
    if (!a || !a.content) return;
    navigator.clipboard.writeText(a.content).then(function() {
      if (typeof showToast === 'function') showToast('Tersalin ke clipboard!', 'success');
    });
  };

  window.downloadFileById = function(artifactId) {
    var a = (state.artifacts || []).find(function(x) { return x.id === artifactId; });
    if (!a || !a.content) return;
    var name = formatFileName(a.id);
    var mime = name.endsWith('.json') ? 'application/json' : 'text/markdown';
    if (typeof downloadFile === 'function') {
      downloadFile(a.content, name, mime);
      if (typeof showToast === 'function') showToast('Downloaded ' + name, 'success');
    }
  };

  // ─── Bulk Actions ───
  window.enhancedCopyAll = function() {
    var artifacts = state.artifacts || [];
    var text = artifacts.map(function(a) {
      return '=== ' + (a.label || a.id) + ' ===\n' + (a.content || '');
    }).join('\n\n---\n\n');
    navigator.clipboard.writeText(text).then(function() {
      if (typeof showToast === 'function') showToast('Semua file tersalin ke clipboard!', 'success');
    });
  };

  window.enhancedDownloadAll = function() {
    if (typeof downloadAllZip === 'function') {
      downloadAllZip();
    } else if (typeof downloadAll === 'function') {
      downloadAll();
    } else {
      var artifacts = state.artifacts || [];
      var hasDownloadFile = typeof downloadFile === 'function';
      artifacts.forEach(function(a) {
        if (!a.content) return;
        var name = formatFileName(a.id);
        var mime = name.endsWith('.json') ? 'application/json' : 'text/markdown';
        if (hasDownloadFile) downloadFile(a.content, name, mime);
      });
      if (typeof showToast === 'function') showToast('Downloading all files...', 'info');
    }
  };

  // ─── Fix: Reset survey mode when entering wizard ───
  // Prevents stale localStorage state from skipping the mode picker
  var origInitWizard = window.initWizard;
  window.initWizard = function() {
    if (typeof state !== 'undefined') {
      state.savedQuestions = [];
      state.surveyMode = '';
      state.surveyQ = 0;
    }
    if (typeof _surveyQuestions !== 'undefined') _surveyQuestions = [];
    return origInitWizard ? origInitWizard.apply(this, arguments) : undefined;
  };

  // ─── Override: Dynamic Island step indicator ───
  var origUpdateWizSteps = window.updateWizSteps;
  window.updateWizSteps = function() {
    document.querySelectorAll('#page-wizard .step-dynamic').forEach(function(el, idx) {
      var stepNum = idx + 1;
      el.classList.toggle('active', stepNum === wizardStep);
      el.classList.toggle('visited', stepNum < wizardStep);
    });
  };

  // ─── Override: Survey Input — pure text field + clickable recs with + format ───
  // NO type-specific chips (yn/multi/single) — only text input + recommendation chips
  window.renderSurveyInput = function(q) {
    var placeholder = q.hint || q.placeholder || 'Ketik jawaban...';
    var recs = q.recommendations || [];
    var answer = (typeof state !== 'undefined' && state.answers) ? state.answers[q.id] : '';

    var textVal = typeof answer === 'string' ? escapeHtml(answer) : '';
    var html = '';

    // ── Text input field ──
    html += '<input type="text" class="survey-input" placeholder="' + escapeHtml(placeholder) + '" value="' + textVal + '" oninput="saveAnswer(\'' + q.id + '\',this.value)">';

    // ── Recommendation chips — clickable, append with + format ──
    if (recs.length > 0) {
      html += '<div style="margin-top:6px;display:flex;flex-wrap:wrap;gap:4px">';
      recs.forEach(function(r) {
        var safeR = escapeHtml(r).replace(/'/g, "\\'");
        html += '<span class="chip text-[10px] cursor-pointer" style="border-color:rgba(0,224,143,0.15)" onclick="clickSurveyRec(\'' + q.id + '\',\'' + safeR + '\')">' + escapeHtml(r) + '</span>';
      });
      html += '</div>';
    }

    return html;
  };

  // ─── Override: clickSurveyRec — always append to text field with + format ───
  window.clickSurveyRec = function(qId, value) {
    if (!value) return;
    var activePage = document.querySelector('.page.active');
    var surveyContainer = activePage ? activePage.querySelector('#surveyContainer') : document.getElementById('surveyContainer');
    if (!surveyContainer) return;

    // Find the text input for this question
    var input = surveyContainer.querySelector('input[oninput*="' + qId + '"]') ||
                surveyContainer.querySelector('input');
    if (!input) return;

    var current = input.value || '';
    // Check if already added
    var existing = current.split(',').map(function(s) { return s.trim(); });
    if (existing.indexOf(value) < 0) {
      input.value = (current ? current + ', ' : '') + value;
      if (typeof saveAnswer === 'function') saveAnswer(qId, input.value);
    }
  };

  // ─── Per-file revision chat ───
  var _fileChats = {}; // { fileId: [{ role, content }] }

  window.toggleFileChat = function(fileId) {
    var panel = document.getElementById('fileChat-' + fileId);
    if (panel) {
      panel.classList.toggle('open');
      if (panel.classList.contains('open')) {
        panel.querySelector('.file-chat-input')?.focus();
      }
    }
  };

  window.sendFileChat = function(fileId) {
    var panel = document.getElementById('fileChat-' + fileId);
    if (!panel) return;
    var input = panel.querySelector('.file-chat-input');
    if (!input || !input.value.trim()) return;

    var msg = input.value.trim();
    input.value = '';

    // Show user message
    var msgsDiv = panel.querySelector('.file-chat-messages');
    msgsDiv.innerHTML += '<div class="file-chat-msg user">' + escapeHtml(msg) + '</div>';
    msgsDiv.scrollTop = msgsDiv.scrollHeight;

    // Build context from this file
    var artifact = (state.artifacts || []).find(function(a) { return a.id === fileId; });
    var context = artifact ? artifact.content : '';

    // Save chat history
    if (!_fileChats[fileId]) _fileChats[fileId] = [];
    _fileChats[fileId].push({ role: 'user', content: msg });

    // Show "thinking..."
    var thinkingId = 'thinking-' + fileId + '-' + Date.now();
    msgsDiv.innerHTML += '<div class="file-chat-msg ai" id="' + thinkingId + '"><em>Menulis...</em></div>';
    msgsDiv.scrollTop = msgsDiv.scrollHeight;

    // Call AI with context
    var chatHistory = _fileChats[fileId] || [];
    var systemMsg = 'Kamu adalah asisten yang membantu merevisi file "' + formatFileName(fileId) + '".';
    systemMsg += ' Konten file saat ini:\n\n' + context;
    systemMsg += '\n\nBerdasarkan instruksi user, hasilkan konten revisi untuk file ini saja. Output langsung konten revisinya.';

    var aiMessages = [{ role: 'system', content: systemMsg }];
    chatHistory.forEach(function(m) {
      aiMessages.push({ role: m.role, content: m.content });
    });

    window.streamingCallAI(aiMessages, {
      onToken: function(token, fullText) {
        var el = document.getElementById(thinkingId);
        if (el) {
          el.innerHTML = '<pre style="margin:0;font-size:11px;white-space:pre-wrap;color:var(--text)">' + escapeHtml(fullText) + '</pre>';
          msgsDiv.scrollTop = msgsDiv.scrollHeight;
        }
      },
      onComplete: function(fullText) {
        _fileChats[fileId].push({ role: 'assistant', content: fullText });
        // Add apply button
        var el = document.getElementById(thinkingId);
        if (el) {
          el.innerHTML = '<pre style="margin:0;font-size:11px;white-space:pre-wrap;color:var(--text)">' + escapeHtml(fullText) + '</pre>' +
            '<div style="margin-top:4px"><button class="btn btn-ghost btn-xs" onclick="applyFileRevision(\'' + fileId + '\')" style="font-size:10px">✓ Terapkan ke file</button></div>';
        }
        if (typeof showToast === 'function') showToast('Revisi selesai untuk ' + formatFileName(fileId), 'success');
      },
      onError: function(err) {
        var el = document.getElementById(thinkingId);
        if (el) el.innerHTML = '<span style="color:#ef4444">Error: ' + escapeHtml(err) + '</span>';
      }
    });
  };

  window.applyFileRevision = function(fileId) {
    var chat = _fileChats[fileId];
    if (!chat || chat.length === 0) return;
    var lastAssistant = null;
    for (var i = chat.length - 1; i >= 0; i--) {
      if (chat[i].role === 'assistant') { lastAssistant = chat[i].content; break; }
    }
    if (!lastAssistant) return;

    // Update artifact
    var artifact = (state.artifacts || []).find(function(a) { return a.id === fileId; });
    if (artifact) {
      // Save version before modifying
      if (state.versions) {
        state.versions.push({
          version: 'v' + (state.versions.length + 1) + '.0',
          artifacts: JSON.parse(JSON.stringify(state.artifacts)),
          timestamp: new Date().toISOString(),
        });
        state.currentVersion = state.versions.length - 1;
      }
      artifact.content = lastAssistant;
      if (typeof saveState === 'function') saveState();
      if (typeof saveProject === 'function') saveProject();
      if (typeof renderExportTab === 'function') renderExportTab();
      if (typeof showToast === 'function') showToast('File ' + formatFileName(fileId) + ' telah diperbarui!', 'success');
    }
  };

  // ─── Apply File Revision (from per-file chat) ───
  // ─── Result Page: no tabs, pure export with TC3 design ───
  // Override switchResultTab: always show export content, hide tab bar
  var origSwitchResultTab = window.switchResultTab;
  window.switchResultTab = function(tab) {
    // Always hide tab bar
    var tabsBar = document.getElementById('resultTabs');
    if (tabsBar) tabsBar.style.display = 'none';

    // Show export container, hide all others
    var tabs = ['overview', 'artifacts', 'documents', 'visual', 'export'];
    tabs.forEach(function(t) {
      var el = document.getElementById('resultTab' + t.charAt(0).toUpperCase() + t.slice(1));
      if (el) el.style.display = t === 'export' ? 'block' : 'none';
    });
    // Always render export
    if (typeof renderExportTab === 'function') renderExportTab();
  };

  // Override initResult: hide tabs, show export directly
  var origInitResult = window.initResult;
  window.initResult = function() {
    var result = origInitResult ? origInitResult.apply(this, arguments) : undefined;
    // After original loads everything, show export only
    setTimeout(function() {
      if (typeof switchResultTab === 'function') {
        switchResultTab('export');
      }
    }, 50);
    return result;
  };

  console.log('PRDKit TC3 Enhanced — Survey, Result, File Factory v3 ✓');

})();
