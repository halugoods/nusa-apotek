/* =============================
   PRDKit   Application Logic
   Polished & Maintainable SPA
   ============================= */

//     SPA Hash Router    
const PAGES = ['home', 'setup', 'wizard', 'result'];
let currentPage = 'home';
let techPref = 'gratis'; // 'gratis' or 'advanced'

// Alias: navigate() → router.navigate()
const navigate = (page) => window.location.hash = page;

class PRDKitRouter {
  constructor() {
    this.init = false;
    window.addEventListener('hashchange', () => this.resolve());
    // On first load, resolve after DOM is ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.resolve());
    } else {
      this.resolve();
    }
  }

  resolve() {
    const hash = window.location.hash.slice(1) || 'home';
    const [page, qs] = hash.split('?');
    const params = qs ? Object.fromEntries(new URLSearchParams(qs)) : {};

    if (!PAGES.includes(page)) {
      window.location.hash = 'home';
      return;
    }

    this.showPage(page, params);

    if (!this.init) {
      this.init = true;
      // First resolve   also do page-specific init
      if (page === 'wizard' && typeof initWizard === 'function') {
        setTimeout(() => { initWizard(); }, 50);
      }
      if (page === 'setup' && typeof initSetup === 'function') {
        setTimeout(() => { initSetup(); renderTechGrids(); renderExtras(); renderSurvey(); }, 50);
      }
      if (page === 'result' && typeof initResult === 'function') {
        setTimeout(() => { initResult(); }, 50);
      }
    }
  }

  showPage(page, params) {
    // Hide all pages
    PAGES.forEach(p => {
      const el = document.getElementById('page-' + p);
      if (el) {
        el.classList.remove('active', 'exit', 'page-enter');
        el.style.display = 'none';
      }
    });

    // Show target
    const next = document.getElementById('page-' + page);
    if (next) {
      next.style.display = '';
      next.classList.add('active');
      void next.offsetWidth;
      next.classList.add('page-enter');
    }
    currentPage = page;

    // Page-specific init (skip on initial load   done in resolve)
    if (this.init) {
      if (page === 'home') {
        if (typeof renderRecentProjects === 'function') {
          setTimeout(renderRecentProjects, 100);
        }
      }
      if (page === 'wizard' && typeof initWizard === 'function') {
        initWizard();
      }
      if (page === 'setup') {
        if (typeof initSetup === 'function') initSetup();
        renderTechGrids();
        renderExtras();
        renderSurvey();
        checkProviderStatus();
        setTimeout(showRandomTip, 200);
      }
      if (page === 'result') {
        if (typeof initResult === 'function') initResult();
        setTimeout(showFeedback, 2000);
      }
    }
  }
}

// Instantiate router
const router = new PRDKitRouter();

// Legacy navigateTo   now delegates to hash change
function navigateTo(page) {
  if (!PAGES.includes(page)) return;
  window.location.hash = page;
}

async function expandIdeaWithAI() {
  const textarea = document.getElementById('ideaText');
  if (!textarea) return;
  const idea = (textarea.value || '').trim();
  if (idea.length < 20) {
    showToast('Isi ide dulu, biar bisa dikembangkan.', 'info');
    return;
  }
  const productName = (document.getElementById('productName')?.value || state.productName || '').trim();
  const productType = state.productType || 'web';
  const prompt = [
    'Kamu adalah product strategist senior yang menulis brief yang siap diimplementasikan.',
    'Perluas ide berikut tanpa menambah fitur yang tidak perlu.',
    'Balas dalam JSON valid dengan keys: title, expandedIdea, scope, nonGoals, users, flows, risks, assumptions.',
    'Aturan anti-slop:',
    '- fokus pada kebutuhan nyata user, bukan jargon',
    '- jangan membuat fitur generik yang tidak relevan',
    '- sebutkan batasan dan asumsi secara eksplisit',
    '- output harus singkat tapi tajam',
    '',
    'Nama produk: ' + (productName || '-'),
    'Tipe produk: ' + productType,
    'Ide awal: ' + idea,
  ].join('\n');

  // Rainbow glow while expanding idea
  toggleCardProcessing(textarea, true);

  const btn = document.getElementById('expandBtn');
  const prev = btn ? btn.innerHTML : '';
  if (btn) {
    btn.disabled = true;
    btn.classList.add('btn-loading');
    btn.innerHTML = 'Mengembangkan';
  }

  try {
    let result = null;
    if (typeof callAI === 'function') {
      result = await callAI([
        { role: 'system', content: 'Return only JSON.' },
        { role: 'user', content: prompt },
      ]);
    }
    const jsonMatch = result ? result.match(/\{[\s\S]*\}/) : null;
    const parsed = jsonMatch ? JSON.parse(jsonMatch[0]) : null;
    const expanded = parsed?.expandedIdea || parsed?.scope || parsed?.title || '';
    if (expanded) {
      textarea.value = `${idea}\n\n${expanded}`.trim();
      updateIdeaCounter();
      if (parsed?.title && document.getElementById('productName')) {
        document.getElementById('productName').value = parsed.title;
        state.productName = parsed.title;
      }
      showToast('Ide berhasil dikembangkan.', 'success');
      return;
    }
    throw new Error('AI did not return usable output');
  } catch (err) {
    const fallback = [
      'Masalah utama yang diselesaikan:',
      '- ',
      '',
      'Siapa yang memakai:',
      '- ',
      '',
      'Flow inti:',
      '1. User masuk dan membuat entri utama.',
      '2. Sistem memvalidasi input dan menyimpan data.',
      '3. User melihat status, riwayat, atau hasilnya.',
      '',
      'Batasan MVP:',
      '- Fokus hanya pada flow inti.',
      '- Hindari fitur tambahan yang tidak mendukung tujuan utama.',
    ].join('\n');
    textarea.value = `${idea}\n\n${fallback}`.trim();
    updateIdeaCounter();
    showToast('AI belum tersedia, ide diisi dengan struktur brief.', 'info');
  } finally {
    toggleCardProcessing(textarea, false);
    if (btn) {
      btn.disabled = false;
      btn.classList.remove('btn-loading');
      btn.innerHTML = prev || ''+iconSvg('zap',12)+' Kembangkan dengan AI';
    }
  }
}

//     Saved Provider Selection    
/**
 * @param {string} name - Icon key
 * @param {number} [size=16] - SVG size in pixels
 * @returns {string} SVG markup
 */
function iconSvg(name, size = 16) {
  const base = `<svg width=\"${size}\" height=\"${size}\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.5\" stroke-linecap=\"round\" stroke-linejoin=\"round\">`;
  const close = '</svg>';
  const icons = {
    file: '<path d=\"M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z\"/><polyline points=\"14 2 14 8 20 8\"/><line x1=\"16\" y1=\"13\" x2=\"8\" y2=\"13\"/><line x1=\"16\" y1=\"17\" x2=\"8\" y2=\"17\"/>',
    fileText: '<path d=\"M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z\"/><polyline points=\"14 2 14 8 20 8\"/><line x1=\"16\" y1=\"13\" x2=\"8\" y2=\"13\"/><line x1=\"16\" y1=\"17\" x2=\"8\" y2=\"17\"/><polyline points=\"10 9 9 9 8 9\"/>',
    database: '<ellipse cx=\"12\" cy=\"5\" rx=\"9\" ry=\"3\"/><path d=\"M21 12c0 1.66-4 3-9 3s-9-1.34-9-3\"/><path d=\"M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5\"/>',
    code: '<polyline points=\"16 18 22 12 16 6\"/><polyline points=\"8 6 2 12 8 18\"/>',
    diagram: '<rect x=\"3\" y=\"3\" width=\"18\" height=\"18\" rx=\"2\" ry=\"2\"/><line x1=\"3\" y1=\"9\" x2=\"21\" y2=\"9\"/><line x1=\"9\" y1=\"21\" x2=\"9\" y2=\"9\"/>',
    palette: '<circle cx=\"13.5\" cy=\"6.5\" r=\".5\"/><circle cx=\"17.5\" cy=\"10.5\" r=\".5\"/><circle cx=\"8.5\" cy=\"7.5\" r=\".5\"/><circle cx=\"6.5\" cy=\"12.5\" r=\".5\"/><path d=\"M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.93 0 1.5-.67 1.5-1.5 0-.39-.15-.74-.39-1.01-.23-.26-.38-.61-.38-1 0-.83.67-1.5 1.5-1.5H16c3.31 0 6-2.69 6-6 0-5.5-4.5-10-10-10z\"/>',
    check: '<polyline points=\"20 6 9 17 4 12\"/>',
    arrowRight: '<line x1=\"5\" y1=\"12\" x2=\"19\" y2=\"12\"/><polyline points=\"12 5 19 12 12 19\"/>',
    arrowLeft: '<line x1=\"19\" y1=\"12\" x2=\"5\" y2=\"12\"/><polyline points=\"12 19 5 12 12 5\"/>',
    star: '<polygon points=\"12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2\"/>',
    refresh: '<polyline points=\"23 4 23 10 17 10\"/><polyline points=\"1 20 1 14 7 14\"/><path d=\"M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15\"/>',
    download: '<path d=\\"M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4\\"/><polyline points=\\"7 10 12 15 17 10\\"/><line x1=\\"12\\" y1=\\"15\\" x2=\\"12\\" y2=\\"3\\"/>',
    trash: '<polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
    box: '<path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>',
    grid: '<rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/>',
    lock: '<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
    activity: '<polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/>',
    checkSquare: '<polyline points="9 11 12 14 22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>',
    folder: '<path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/>',
    share2: '<circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/>',
    checkCircle: '<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>',
    layers: '<polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/>',
    target: '<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/>',
    messageCircle: '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>',
    zap: '<polygon points="13 2 3 14 12 14 11 22 21 10 12 10"/>',
    trendingUp: '<polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/>',
    lightbulb: '<path d="M9 18h6"/><path d="M10 22h4"/><path d="M12 2a7 7 0 0 0-3 13.3V18h6v-2.7A7 7 0 0 0 12 2z"/>',
    send: '<line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/>',
    bot: '<path d="M12 8V4m0 0L9 1m3 3l3-1M4 16V8a2 2 0 012-2h12a2 2 0 012 2v8M4 16h16M4 16l-2 4m18-4l2 4"/><circle cx="8" cy="12" r="1"/><circle cx="16" cy="12" r="1"/>',
    x: '<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>',
    monitor: '<rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/>',
    server: '<rect x="2" y="2" width="20" height="5" rx="1"/><rect x="2" y="9.5" width="20" height="5" rx="1"/><rect x="2" y="17" width="20" height="5" rx="1"/>',
    cloud: '<path d="M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9z"/>',
    smartphone: '<rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/>',
    messageSquare: '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>',
  };
  return base + (icons[name] || '') + close;
}

//     State    
const state = {
  step: 1,
  surveyQ: 0,
  surveyTotal: 6,
  mode: 'panduan',          // 'panduan' | 'studio'
  productName: '',
  idea: '',
  productType: 'web',
  productRef: '',
  tech: {},
  extras: [],
  answers: {},
  artifacts: [],
  currentArtifact: 0,
  versions: [],
  currentVersion: 0,
  chatHistory: [],
  aiAccessMode: 'byok',
  aiProvider: 'sumopod',
  aiModel: 'deepseek-v4-flash',
  baseUrl: '',
  user: null,               // current logged-in user { id, email, name, avatarUrl, hasApiKey }
};

const API_URL = 'https://prdkit-ai-proxy.halugoods-indonesia.workers.dev';
const LS_KEY = 'prdkit_state';
const LS_VERSION = 2; // bump to reset stale state
const MAX_HISTORY = 10;

//     API Key Security Module    
// Keys are stored obfuscated in localStorage, NOT in state object.
// This is defense-in-depth, not encryption.
// Browser limitations: DevTools, extensions, malware can still access.
const KEY_STORE = {
  _key: '',

  set(key) {
    this._key = key || '';
    // Store obfuscated (reverse + base64   NOT encryption, just not plaintext)
    try {
      if (key) {
        const obf = btoa(key.split('').reverse().join(''));
        localStorage.setItem('prdkit_key_obf', obf);
      } else {
        localStorage.removeItem('prdkit_key_obf');
      }
    } catch(e) { /* silent */ }
    // Clear from state if present
    if (state.apiKey) {
      state.apiKey = '';
      try { saveState(); } catch(e) { /* silent */ }
    }
  },

  get() { return this._key; },

  restore() {
    try {
      const obf = localStorage.getItem('prdkit_key_obf');
      if (obf) {
        this._key = atob(obf).split('').reverse().join('');
      }
    } catch(e) { this._key = ''; }
  },

  has() { return !!this._key; },

  display() {
    if (!this._key) return '';
    return this._key.substring(0, 4) + '••••••' + this._key.slice(-4);
  },

  toggleMask() {
    const el = document.getElementById('apiKeyInput');
    if (!el) return;
    if (el.type === 'password') {
      el.type = 'text';
      el.value = this._key;
    } else {
      el.type = 'password';
      el.value = this.display();
    }
  },

  safeCopy() {
    if (!this._key) return;
    navigator.clipboard.writeText(this._key).then(() => {
      showToast('API Key copied! Hapus dari clipboard setelah digunakan.', 'warning');
    });
  },

  clear() {
    this._key = '';
    try { localStorage.removeItem('prdkit_key_obf'); } catch(e) { /* silent */ }
  },
};

// Restore key on load
KEY_STORE.restore();

//     First Visit    
const ONBOARDING_KEY = 'prdkit_onboarded';

function isFirstVisit() {
  try { return !localStorage.getItem(ONBOARDING_KEY); } catch(e) { return false; }
}

function dismissOnboarding() {
  try { localStorage.setItem(ONBOARDING_KEY, '1'); } catch(e) { /* silent */ }
}

//     AI Config (persisted via Worker + localStorage)    
const WORKER_CONFIG_URL = API_URL + '/api/config';
const WORKER_CHAT_URL = API_URL + '/api/chat';

async function loadAIConfig() {
  try {
    const ls = localStorage.getItem('prdkit_ai_config');
    if (ls) {
      try { Object.assign(state, JSON.parse(ls)); } catch(e) {}
    }
    // Load from Worker (D1)   with credentials so cookies are sent
    const res = await fetch(WORKER_CONFIG_URL, { credentials: 'include' });
    if (res.ok) {
      const cfg = await res.json();
      // New format: activeProvider, activeModel, providers[]
      if (cfg.activeProvider) state.aiProvider = cfg.activeProvider;
      if (cfg.activeModel) state.aiModel = cfg.activeModel;
      // Fallback to legacy format
      if (!cfg.activeProvider && cfg.provider) state.aiProvider = cfg.provider;
      if (!cfg.activeModel && cfg.model) state.aiModel = cfg.model;
      if (cfg.apiKeyMasked) state._keyMasked = cfg.apiKeyMasked;
      if (cfg.hasApiKey) state._hasKey = true;
      // Update user state from config response
      if (cfg.user) {
        state.user = cfg.user;
        // Use actual API key from D1 (per-user), not localStorage
        if (cfg.apiKey) {
          KEY_STORE.set(cfg.apiKey);
        } else {
          KEY_STORE.set('');
        }
        // Remove apiKey from localStorage
        try {
          const ls = JSON.parse(localStorage.getItem('prdkit_state') || '{}');
          delete ls.apiKey;
          localStorage.setItem('prdkit_state', JSON.stringify(ls));
        } catch(e) {}
        // If user doesn't have their own API key AND no cfg.apiKey, show unconfigured
        if (!cfg.user.hasApiKey && !cfg.apiKey) {
          state.aiProvider = null;
          state.aiModel = null;
        }
      } else {
        state.user = null;
        // When not logged in, still populate from D1 (global defaults)
      }
      // Track saved providers from D1
      if (cfg.providers && Array.isArray(cfg.providers)) {
        savedProviders = cfg.providers;
      }
      // Update UI based on auth state
      if (typeof updateUserUI === 'function') updateUserUI();
    } else {
      // If config fails, still try auth check
      if (typeof checkAuth === 'function') checkAuth();
    }
  } catch(e) {
    console.warn('Could not load AI config from Worker, using local:', e);
  }
  // Always persist state to localStorage after load
  persistAIConfig();
  if (typeof updateAIConfigUI === 'function') updateAIConfigUI();
}

async function saveAIConfigToWorker(config) {
  try {
    // Find provider type from PROVIDER_LIST
    const providerMatch = PROVIDER_LIST.find(p => p.name === config.provider);
    const providerType = providerMatch?.type || config.providerType || 'openai';

    const res = await fetch(WORKER_CONFIG_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({
        activeProvider: config.provider,
        activeModel: config.model,
        apiKey: config.apiKey,
        baseUrl: config.baseUrl,
        providerType: providerType,
      }),
    });

    if (res.ok) {
      const data = await res.json();
      console.log('Config saved:', data);
      if (!data.savedWithUserId) {
        console.warn('⚠︀ Config saved GLOBALLY (no user auth)');
      }
    } else {
      console.error('Save config failed:', await res.text());
    }
  } catch(e) {
    console.warn('Could not save AI config to Worker:', e);
  }
  persistAIConfig();
}

function persistAIConfig() {
  localStorage.setItem('prdkit_ai_config', JSON.stringify({
    aiProvider: state.aiProvider,
    aiModel: state.aiModel,
    baseUrl: state.baseUrl,
  }));
}

//     Auth: Google OAuth    

const AUTH_BASE = API_URL;
const IS_LOCAL_PREVIEW = window.location.protocol === 'file:' || ['localhost', '127.0.0.1', '::1'].includes(window.location.hostname);

function showLocalPreview() {
  const authGate = document.getElementById('authGate');
  const mainApp = document.getElementById('mainApp');
  const topNavLoginBtn = document.getElementById('topNavLoginBtn');
  const topNavUserMenu = document.getElementById('topNavUserMenu');

  state.user = {
    id: 'local-preview',
    email: 'local@preview',
    name: 'Local Preview',
    avatarUrl: '',
    hasApiKey: false,
  };

  if (authGate) authGate.style.display = 'none';
  if (mainApp) mainApp.style.display = 'block';
  document.body.classList.add('auth-active');
  if (topNavLoginBtn) topNavLoginBtn.style.display = 'none';
  if (topNavUserMenu) topNavUserMenu.style.display = 'none';
  if (typeof updateAIConfigUI === 'function') updateAIConfigUI();
}

// Check login status on page load
async function checkAuth() {
  if (IS_LOCAL_PREVIEW) {
    showLocalPreview();
    return;
  }

  const authGate = document.getElementById('authGate');
  const mainApp = document.getElementById('mainApp');
  const topNavLoginBtn = document.getElementById('topNavLoginBtn');
  const topNavUserMenu = document.getElementById('topNavUserMenu');
  
  try {
    const res = await fetch(AUTH_BASE + '/auth/me', { credentials: 'include' });
    if (res.ok) {
      const data = await res.json();
      state.user = data.user;
    } else {
      state.user = null;
    }
  } catch(e) {
    state.user = null;
  }
  
  if (state.user) {
    // Show main app, hide auth gate
    if (authGate) authGate.style.display = 'none';
    if (mainApp) mainApp.style.display = 'block';
    document.body.classList.add('auth-active');
    
    // Enable buttons
    const createBtn = document.getElementById('createBlueprintBtn');
    const settingsBtn = document.getElementById('modelSettingsBtn');
    if (createBtn) createBtn.disabled = false;
    if (settingsBtn) settingsBtn.disabled = false;
    
    // Show user menu, hide login button in top nav
    if (topNavLoginBtn) topNavLoginBtn.style.display = 'none';
    if (topNavUserMenu) topNavUserMenu.style.display = 'flex';
    
    // Fill user info
    updateUserUI();
  } else {
    // Show auth gate, hide main app
    if (authGate) authGate.style.display = 'flex';
    if (mainApp) mainApp.style.display = 'none';
    document.body.classList.remove('auth-active');
    
    // Show login button in top nav
    if (topNavLoginBtn) topNavLoginBtn.style.display = 'inline-flex';
    if (topNavUserMenu) topNavUserMenu.style.display = 'none';
  }
  
  if (typeof updateAIConfigUI === 'function') updateAIConfigUI();
}

// Redirect to Google OAuth
function loginWithGoogle() {
  if (IS_LOCAL_PREVIEW) {
    showToast('Mode lokal aktif. Login Google dinonaktifkan di preview ini.', 'info');
    return;
  }
  window.location.href = AUTH_BASE + '/auth/google';
}

// Logout
async function logout() {
  try {
    await fetch(AUTH_BASE + '/auth/logout', {
      method: 'POST',
      credentials: 'include',
    });
  } catch(e) {
    console.warn('Logout error:', e);
  }
  state.user = null;
  // Clear stored API key from localStorage to prevent cross-user leak
  KEY_STORE.clear();
  updateUserUI();
  const toast = document.getElementById('toast') || createToast('Logged out.', 'success');
}

// Update UI to reflect auth state
function updateUserUI() {
  const topNavLoginBtn = document.getElementById('topNavLoginBtn');
  const topNavUserMenu = document.getElementById('topNavUserMenu');
  const topNavAvatar = document.getElementById('topNavAvatar');
  const topNavUserName = document.getElementById('topNavUserName');

  if (state.user) {
    if (topNavLoginBtn) topNavLoginBtn.style.display = 'none';
    if (topNavUserMenu) topNavUserMenu.style.display = 'flex';

    if (state.user.avatarUrl && topNavAvatar) {
      topNavAvatar.src = state.user.avatarUrl;
      topNavAvatar.style.display = 'block';
    }

    if (topNavUserName) topNavUserName.textContent = state.user.name || '';
  } else {
    if (topNavLoginBtn) topNavLoginBtn.style.display = 'inline-flex';
    if (topNavUserMenu) topNavUserMenu.style.display = 'none';
  }
}

//     Saved Provider Selection    


//     Tech Options Data    
const TECH_OPTIONS = {
  frontend: [
    ['ai-pilih', 'Biarkan AI pilih', false],
    ['nextjs', 'Next.js', true],
    ['react', 'React', true],
    ['vite', 'Vite', true],
    ['tanstack', 'TanStack Start', true],
    ['astro', 'Astro', true],
    ['vue', 'Vue', true],
    ['sveltekit', 'SvelteKit', true],
    ['flutter', 'Flutter', false],
    ['expo', 'Expo (React Native)', false],
    ['electron', 'Electron', false],
  ],
  backend: [
    ['ai-pilih', 'Biarkan AI pilih', false],
    ['node', 'Node.js', true],
    ['hono', 'Hono', true],
    ['nestjs', 'NestJS', true],
    ['express', 'Express', true],
    ['fastapi', 'FastAPI', true],
    ['supabase', 'Supabase', true],
    ['laravel', 'Laravel', true],
    ['rails', 'Rails', false],
    ['go', 'Go', false],
    ['firebase', 'Firebase', true],
  ],
  database: [
    ['ai-pilih', 'Biarkan AI pilih', false],
    ['postgres', 'PostgreSQL', true],
    ['sqlite', 'SQLite', true],
    ['mysql', 'MySQL', true],
    ['mongodb', 'MongoDB', true],
    ['supabase-postgres', 'Supabase Postgres', true],
    ['turso', 'Turso', true],
    ['redis', 'Redis', false],
  ],
  deployment: [
    ['ai-pilih', 'Biarkan AI pilih', false],
    ['vercel', 'Vercel', true],
    ['netlify', 'Netlify', true],
    ['cloudflare', 'Cloudflare Pages', true],
    ['railway', 'Railway', true],
    ['render', 'Render', true],
    ['fly', 'Fly.io', false],
    ['aws', 'AWS', false],
  ],
};

const EXTRA_OPTIONS = [
  ['auth', 'Login & role'],
  ['payment', 'Payment / subscription'],
  ['storage', 'Upload file'],
  ['admin', 'Admin dashboard'],
  ['realtime', 'Realtime updates'],
  ['notification', 'Email / push notification'],
  ['analytics', 'Analytics & events'],
  ['ai', 'AI feature'],
  ['mobile', 'Mobile-first'],
  ['import-export', 'Import / export data'],
  ['whatsapp', 'WhatsApp integration'],
];

const EXAMPLE_IDEAS = [
  'Aplikasi inventory gudang untuk admin tunggal, ada stok masuk keluar, batch, rak, dan low stock alert.',
  'CRM sederhana untuk agency kecil, bisa tracking leads, follow-up, invoice, dan reminder WhatsApp.',
  'SaaS habit tracker untuk creator, ada streak, leaderboard kecil, subscription, dan AI weekly insight.',
];

const ARTIFACT_ICONS = {
  prompt: 'fileText',
  prd: 'fileText',
  summary: 'fileText',
  readme: 'fileText',
  'chunk-product': 'box',
  'chunk-datamodel': 'database',
  'chunk-modules': 'grid',
  'chunk-security': 'lock',
  'chunk-flows': 'activity',
  'chunk-implementation': 'code',
  tasks: 'checkSquare',
  structure: 'folder',
  domain: 'box',
  relations: 'share2',
  modules: 'grid',
  validation: 'checkCircle',
  architecture: 'layers',
  security: 'lock',
  documentation: 'fileText',
  metadata: 'fileText',
};

//     Init    
document.addEventListener('DOMContentLoaded', () => {
  loadState();
  applyTheme();
  loadAIConfig(); // Load AI config from Worker + localStorage (includes user state)
  checkAuth();    // Verify auth state
  loadHomeStats();
  // Tap glow   only on touch devices; desktop stays normal hover
  if ('ontouchstart' in window || navigator.maxTouchPoints > 0) {
    var _tapGlowCard = null;
    function _activateTapGlow(card) {
      if (_tapGlowCard === card) return;
      if (_tapGlowCard) _tapGlowCard.classList.remove('tap-glow');
      _tapGlowCard = card;
      if (card) card.classList.add('tap-glow');
    }
    document.addEventListener('touchstart', function(ev) {
      var card = ev.target.closest('.card, .cat-card, .sub-card');
      if (card && !card.classList.contains('ai-processing')) _activateTapGlow(card);
    }, { passive: true });
  }
  // Show onboarding if first visit
  setTimeout(() => {
    if (isFirstVisit()) {
      const card = document.getElementById('onboardingCard');
      if (card) card.style.display = 'flex';
    }
  }, 500);
});

async function loadHomeStats() {
  const prdEl = document.getElementById('statTotalPrds');
  const userEl = document.getElementById('statTotalUsers');
  if (!prdEl || !userEl) return;
  try {
    const res = await fetch(API_URL + '/api/stats', { credentials: 'include', cache: 'no-store' });
    if (!res.ok) return;
    const data = await res.json();
    prdEl.textContent = Number(data.totalPrds || data.totalProjects || 0).toLocaleString('id-ID');
    userEl.textContent = Number(data.totalUsers || 0).toLocaleString('id-ID');
  } catch (e) {
    console.warn('Failed to load home stats:', e);
  }
}

//     Business Categories    
const CATEGORIES = [
  { name: 'Products', icon: 'package', sub: ['Fashion & Clothing', 'Shoes & Bags', 'Beauty & Skincare', 'Electronics', 'Mobile Phones & Accessories', 'Home & Living', 'Kitchen Equipment', 'Baby & Kids', 'Toys', 'Books & Stationery', 'Automotive', 'Spare Parts', 'Agriculture', 'Livestock', 'Pet Supplies', 'Raw Materials', 'Wholesale', 'Others'] },
  { name: 'Food & Beverage', icon: 'utensilsCrossed', sub: ['Restaurant', 'Cafe', 'Coffee Shop', 'Bakery', 'Dessert', 'Frozen Food', 'Street Food', 'Catering', 'Juice & Smoothies', 'Seafood', 'Rice Bowl', 'Dimsum', 'Beverage Store', 'Others'] },
  { name: 'Services', icon: 'wrench', sub: ['Digital Agency', 'Software House', 'Freelancer', 'Consultant', 'Accounting', 'Legal', 'Barbershop', 'Salon', 'Spa', 'Laundry', 'Car Wash', 'Workshop & Repair', 'Photography', 'Videography', 'Event Organizer', 'Cleaning Service', 'Education Services', 'Others'] },
  { name: 'Digital Products', icon: 'monitor', sub: ['SaaS', 'AI Product', 'E-book', 'Template', 'Prompt Library', 'Membership', 'Online Course', 'Newsletter', 'Plugin', 'Others'] },
  { name: 'Healthcare', icon: 'stethoscope', sub: ['Clinic', 'Pharmacy', 'Laboratory', 'Therapy', 'Psychology', 'Telemedicine', 'Others'] },
  { name: 'Education', icon: 'graduationCap', sub: ['School', 'Tutoring', 'Course', 'Bootcamp', 'Training', 'LMS', 'Others'] },
  { name: 'Property', icon: 'house', sub: ['Boarding House', 'Rental House', 'Apartment', 'Villa', 'Homestay', 'Hotel', 'Property Management', 'Others'] },
  { name: 'Event & Ticketing', icon: 'ticket', sub: ['Seminar', 'Workshop', 'Webinar', 'Concert', 'Gathering', 'Conference', 'Others'] },
  { name: 'Manufacturing', icon: 'factory', sub: ['Food Production', 'Beverage Production', 'Garment', 'Furniture', 'Craft', 'Factory', 'Others'] },
  { name: 'Distribution & Wholesale', icon: 'truck', sub: ['Distributor', 'Supplier', 'Agent', 'Reseller', 'Wholesale Store', 'Others'] },
  { name: 'Logistics', icon: 'package', sub: ['Courier', 'Delivery Service', 'Fleet Management', 'Warehouse', 'Expedition', 'Others'] },
  { name: 'Marketplace', icon: 'store', sub: ['Multi Vendor Marketplace', 'E-Commerce', 'B2B Marketplace', 'Rental Marketplace', 'Service Marketplace', 'Others'] },
  { name: 'Finance', icon: 'wallet', sub: ['Fintech', 'E-Wallet', 'Lending', 'Cooperative', 'Accounting System', 'Billing System', 'Others'] },
  { name: 'Subscription & Membership', icon: 'badgeCheck', sub: ['Gym', 'Loyalty Program', 'Premium Membership', 'Subscription Service', 'Community Membership', 'Others'] },
  { name: 'Media & Content', icon: 'newspaper', sub: ['Blog', 'News Portal', 'Podcast', 'Video Platform', 'Streaming Platform', 'Creator Economy', 'Others'] },
  { name: 'Travel & Hospitality', icon: 'plane', sub: ['Travel Agency', 'Tour Operator', 'Hotel Booking', 'Vacation Rental', 'Ticketing', 'Others'] },
  { name: 'On-Demand Services', icon: 'zap', sub: ['Ride Hailing', 'Food Delivery', 'Courier', 'Home Service', 'Beauty Service', 'Healthcare Service', 'Super App', 'Others'] },
  { name: 'Community & Organization', icon: 'users', sub: ['Community', 'Foundation', 'Cooperative', 'NGO', 'Religious Organization', 'Association', 'Others'] }
];

//     State Persistence    
function saveState() {
  try {
    localStorage.setItem(LS_KEY, JSON.stringify(state));
  } catch {
    // silently fail in incognito / quota exceeded
  }
}

//     Saved Provider Selection    


function loadState() {
  try {
    const saved = localStorage.getItem(LS_KEY);
    if (saved) {
      const parsed = JSON.parse(saved);
      // Version bump → nuke old auto-filled tech/extras
      if (parsed._lsVersion !== LS_VERSION) {
        parsed.tech = {};
        parsed.extras = [];
        parsed._lsVersion = LS_VERSION;
      }
      Object.assign(state, parsed);
    }
  } catch {
    // ignore corrupted data
  }
}

//     Saved Provider Selection    


//     Toast Notifications    
function showToast(msg, type) {
  var container = document.getElementById('toastContainer');
  if (!container) return;
  var el = document.createElement('div');
  el.className = 'toast' + (type === 'success' ? ' success' : '') + (type === 'error' ? ' error' : '') + (type === 'info' ? ' info' : '') + (type === 'warning' ? ' warning' : '');
  el.innerHTML = '<span class="toast-icon">' + (type === 'success' ? '&#10003;' : type === 'error' ? '&#10005;' : type === 'warning' ? '&#9888;' : '&#8505;') + '</span><span class="toast-msg">' + msg + '</span>';
  container.appendChild(el);
  setTimeout(function() { el.style.animation = 'toastOut 0.2s forwards'; setTimeout(function() { el.remove(); }, 250); }, 2500);
}

//     First-Time Experience Utils    

function checkProviderStatus() {
  const hasProvider = state.aiProvider && state.aiModel;
  const el = document.getElementById('apiStatus');
  if (!el) return;
  el.style.display = hasProvider ? 'none' : 'flex';
}

//     Analytics (top level   always accessible)    
// These are referenced from generateBlueprint and must be globally available.
window._analyticsEvents = [];

function trackEvent(name, data) {
  try {
    const raw = localStorage.getItem('prdkit_analytics');
    let events = {};
    try { events = raw ? JSON.parse(raw) : {}; } catch(e) { events = {}; }
    events[name] = events[name] || [];
    events[name].push({ ...data, ts: Date.now(), sid: window._sid || '' });
    if (events[name].length > 500) events[name] = events[name].slice(-500);
    localStorage.setItem('prdkit_analytics', JSON.stringify(events));
  } catch(e) { /* analytics never breaks app */ }
}

function trackUnknownDomain(input, domain, confidence) {
  if (confidence >= 0.5) return;
  try {
    const raw = localStorage.getItem('prdkit_unknown');
    let list = [];
    try { list = raw ? JSON.parse(raw) : []; } catch(e) { list = []; }
    list.push({ id: 'ud_' + Date.now().toString(36), userInput: input, detectedDomain: domain, confidence, timestamp: new Date().toISOString(), reviewed: false });
    if (list.length > 100) list = list.slice(-100);
    localStorage.setItem('prdkit_unknown', JSON.stringify(list));
  } catch(e) { /* silent */ }
}

function showRandomTip() {
  const el = document.getElementById('tipBar');
  if (!el) return;
  const tip = TIPS[Math.floor(Math.random() * TIPS.length)];
  document.getElementById('tipText').textContent = tip;
  el.style.display = 'flex';
}

function dismissTip() {
  const el = document.getElementById('tipBar');
  if (el) el.style.display = 'none';
}

const TIPS = [
  '💡 Tips: Jelaskan model bisnis Anda dengan detail agar AI menghasilkan blueprint yang lebih akurat.',
  '💡 Tips: Sebutkan target pengguna (customer, merchant, admin) agar entity dan role tergenerate otomatis.',
  '💡 Tips: Tambahkan informasi monetisasi agar AI bisa generate API payment yang sesuai.',
  '💡 Tips: Jelaskan workflow utama agar business flow di prompt lebih relevan.',
  '💡 Tips: Setup AI Provider dulu (Settings) sebelum generate blueprint.',
  '💡 Tips: Hasil generate bisa di-copy langsung ke Claude Code, Cursor, atau ChatGPT.',
];

function showRandomTip() {
  const el = document.getElementById('tipText');
  if (!el) return;
  const tip = TIPS[Math.floor(Math.random() * TIPS.length)];
  el.textContent = tip;
  const bar = document.getElementById('tipBar');
  if (bar) bar.style.display = 'flex';
}

function dismissTip() {
  const el = document.getElementById('tipBar');
  if (el) el.style.display = 'none';
}

//     Adaptive Survey    
const SURVEY_DEPTH = {
  habit:5, gym:5, membership:5, photography:5, digital_product:5, forum:5,
  laundry:10, cafe:10, bakery:10, salon:10, barbershop:8, cleaning_service:8,
  field_service:10, car_rental:10, bengkel:10, poultry:8, farm:10, livestock:10,
  membership_community:10, event_management:10, maintenance:8, veterinary:10,
  delivery:15, booking:15, pos:15, inventory:15, restaurant:15, hotel:15,
  catering:12, workshop:12, fleet:15, courier:15, trucking:15, contractor:15,
  course_platform:15, coworking:12, dealer:15, property:15, education:15, healthcare:18,
  crm:25, commerce:20, finance:25, invoicing:20, expense:20, budgeting:20,
  attendance:20, recruitment:20, employee_management:20, performance_management:20,
  accounting:25, payroll:25, erp:30, manufacturing:40,
};

const SURVEY_GROUPS = {
  base: [
    { id:'model', q:'Model bisnis produk ini?', t:'multi', opts:['B2C langsung ke konsumen','B2B enterprise','Marketplace','Hybrid B2B+B2C','Subscription'] },
    { id:'target', q:'Siapa target pengguna utama?', t:'text', hint:'contoh: UMKM makanan, agen properti, customer individu' },
    { id:'main_outcome', q:'Apa outcome utama yang ingin dicapai?', t:'text', hint:'contoh: user bisa pesan laundry tanpa telepon' },
  ],
  operations: [
    { id:'has_delivery', q:'Apakah ada pengiriman fisik?', t:'yn', if:{model:['B2C','Marketplace','Hybrid B2B+B2C']} },
    { id:'has_driver', q:'Pakai driver/kurir sendiri?', t:'yn', if:{has_delivery:'Ya'} },
    { id:'tracking', q:'Butuh real-time tracking?', t:'yn', if:{has_delivery:'Ya'} },
    { id:'has_location', q:'Ada lokasi fisik (toko/kantor)?', t:'yn', if:{model:['B2C','B2B','Marketplace']} },
    { id:'branches', q:'Jumlah cabang?', t:'mc', opts:['1 lokasi','2-5 cabang','6-20 cabang','20+ cabang'], if:{has_location:'Ya'} },
    { id:'has_driver_management', q:'Butuh manajemen driver/kurir?', t:'yn', if:{has_driver:'Ya'} },
  ],
  technology: [
    { id:'platform', q:'Platform utama?', t:'mx', opts:['Website','Android','iOS','WhatsApp','Mobile-first Web'] },
    { id:'has_payment', q:'Butuh payment integration?', t:'yn' },
    { id:'payment_gateway', q:'Payment gateway?', t:'mx', opts:['Midtrans','Xendit','Stripe','Manual/Tunai','QRIS'], if:{has_payment:'Ya'} },
    { id:'has_auth', q:'Butuh login/register?', t:'mc', opts:['Ya, wajib login','Ya, optional','Tidak perlu'] },
    { id:'has_whatsapp', q:'Integrasi WhatsApp?', t:'yn' },
  ],
  monetization: [
    { id:'revenue', q:'Model pendapatan?', t:'mx', opts:['Per-transaksi','Subscription','Komisi','Iklan','Freemium'] },
    { id:'has_trial', q:'Ada free trial?', t:'yn', if:{revenue:'Subscription'} },
    { id:'scale_target', q:'Target skala awal?', t:'mc', opts:['< 100 user','100-500 user','500-2000 user','2000-10000 user'] },
    { id:'team_size', q:'Ukuran tim developer?', t:'mc', opts:['Solo founder','2-3 orang','4-8 orang','9+ orang'] },
  ],
};

const SURVEY_GROUP_LABELS = {
  base: 'Business',
  operations: 'Operations',
  technology: 'Technology',
  monetization: 'Monetization & Scale',
};

//     Survey Recommendations    
const RECOMMENDATIONS = {
  delivery: {
    model: { values: { 'B2C langsung ke konsumen': 0.95, Marketplace: 0.70 }, max: 2 },
    has_delivery: { values: { Ya: 0.98, Tidak: 0.02 }, max: 1 },
    has_driver: { values: { Ya: 0.85, Tidak: 0.15 }, max: 1 },
    tracking: { values: { Ya: 0.90, Tidak: 0.10 }, max: 1 },
    platform: { values: { WhatsApp: 0.90, Website: 0.80, Android: 0.70, 'Mobile-first Web': 0.65 }, max: 3 },
    has_payment: { values: { Ya: 0.95, Tidak: 0.05 }, max: 1 },
    revenue: { values: { 'Per-transaksi': 0.85, Subscription: 0.40 }, max: 2 },
  },
  laundry: {
    has_delivery: { values: { Ya: 0.95, Tidak: 0.05 }, max: 1 },
    has_driver: { values: { Ya: 0.60, Tidak: 0.40 }, max: 1 },
    platform: { values: { WhatsApp: 0.95, Website: 0.60, Android: 0.50 }, max: 3 },
    has_payment: { values: { Ya: 0.90, Tidak: 0.10 }, max: 1 },
    revenue: { values: { 'Per-transaksi': 0.90, Subscription: 0.30 }, max: 2 },
  },
  pos: {
    has_location: { values: { Ya: 0.98, Tidak: 0.02 }, max: 1 },
    branches: { values: { '1 lokasi': 0.70, '2-5 cabang': 0.25 }, max: 1 },
    has_payment: { values: { Ya: 0.95, Tidak: 0.05 }, max: 1 },
    platform: { values: { Android: 0.85, Website: 0.50 }, max: 2 },
  },
  erp: {
    model: { values: { 'B2B enterprise': 0.90, Hybrid: 0.60 }, max: 1 },
    has_auth: { values: { 'Ya, wajib login': 0.95 }, max: 1 },
    has_location: { values: { Tidak: 0.80, Ya: 0.20 }, max: 1 },
    branches: { values: { '20+ cabang': 0.50, '6-20 cabang': 0.30 }, max: 1 },
    platform: { values: { Website: 0.95, 'Mobile-first Web': 0.50 }, max: 2 },
    revenue: { values: { Subscription: 0.80, 'Per-transaksi': 0.30 }, max: 2 },
  },
  restaurant: {
    has_delivery: { values: { Ya: 0.80, Tidak: 0.20 }, max: 1 },
    has_location: { values: { Ya: 0.95, Tidak: 0.05 }, max: 1 },
    platform: { values: { Website: 0.80, WhatsApp: 0.85, Android: 0.50 }, max: 3 },
  },
  crm: {
    model: { values: { 'B2B enterprise': 0.85, 'B2C langsung ke konsumen': 0.30 }, max: 2 },
    has_auth: { values: { 'Ya, wajib login': 0.95 }, max: 1 },
    platform: { values: { Website: 0.95, 'Mobile-first Web': 0.60 }, max: 2 },
    revenue: { values: { Subscription: 0.85, 'Per-transaksi': 0.30 }, max: 2 },
  },
  gym: {
    has_location: { values: { Ya: 0.95, Tidak: 0.05 }, max: 1 },
    revenue: { values: { Subscription: 0.95, 'Per-transaksi': 0.20 }, max: 2 },
    platform: { values: { Android: 0.80, Website: 0.50, iOS: 0.60 }, max: 2 },
  },
  booking: {
    has_location: { values: { Tidak: 0.70, Ya: 0.30 }, max: 1 },
    has_payment: { values: { Ya: 0.95, Tidak: 0.05 }, max: 1 },
    platform: { values: { Website: 0.90, Android: 0.60 }, max: 2 },
  },
};

function getRecommendations(domain, questionId) {
  const domainRecs = RECOMMENDATIONS[domain];
  if (!domainRecs) return [];
  const qRecs = domainRecs[questionId];
  if (!qRecs) return [];
  return Object.entries(qRecs.values)
    .map(([value, confidence]) => ({ value, confidence }))
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, qRecs.max || 3);
}

let _surveyMode = 'smart';
let _surveyQuestions = [];

function buildSurveyQuestions(domain, mode) {
  const depth = SURVEY_DEPTH[domain] || 10;
  const groups = ['base'];
  if (mode !== 'quick') groups.push('operations', 'technology');
  groups.push('monetization');

  const questions = [];
  const answers = {};

  for (const g of groups) {
    for (const q of SURVEY_GROUPS[g] || []) {
      // Check branching condition
      if (q.if) {
        let pass = false;
        for (const [depId, depVal] of Object.entries(q.if)) {
          const a = answers[depId];
          if (Array.isArray(depVal)) {
            if (depVal.includes(a)) pass = true;
          } else {
            if (a === depVal) pass = true;
          }
        }
        if (!pass) continue;
      }
      questions.push({ ...q, group: g });
      if (questions.length >= depth) break;
    }
    if (questions.length >= depth) break;
  }

  return questions.slice(0, depth);
}

//     AI Survey Generator    
// Replaces static SURVEY_GROUPS with AI-generated adaptive questions
async function generateSurveyQuestions(mode) {
  // Build full context from Steps 1 & 2
  const productName = state.productName || '';
  const idea = state.idea || '';
  const type = state.productType || selectedType || 'Web App';
  var domain = 'generic';
  if (typeof getDomain === 'function') { var d = getDomain(); if (d && d.primary) domain = d.primary; }
  const catParts = [];
  if (state.productCategoryParent) catParts.push(state.productCategoryParent);
  if (state.productCategory) catParts.push(state.productCategory);
  const catStr = catParts.length ? catParts.join(' → ') : '-';

  // Tech context
  var techStr = '-';
  if (window._aiTechRec) {
    var t = window._aiTechRec;
    techStr = 'Frontend: ' + (t.frontend?.rec || '-') + ', Backend: ' + (t.backend?.rec || '-');
  } else if (state.tech) {
    var techParts = [];
    for (var tk in state.tech) {
      if (state.tech[tk] && state.tech[tk] !== 'ai-pilih') techParts.push(tk + ': ' + state.tech[tk]);
    }
    techStr = techParts.join(', ') || '-';
  }
  var extrasStr = (state.extras && state.extras.length) ? state.extras.join(', ') : '-';

  // Count questions based on mode
  var qCount = { cepat: '4-6', standar: '8-12', mendalam: '12-20' }[mode] || '8-12';

  // Mode description
  var modeDesc = {
    cepat: 'Buat 4-6 PERTANYAAN PALING KRUSIAL aja. Prioritaskan pertanyaan multi/single/yn (cepat dijawab). Fokus ke model bisnis, operasional inti, dan monetisasi.',
    standar: 'Buat 8-12 PERTANYAAN yg mencakup SEMUA aspek: model bisnis, operasional, teknologi, dan monetisasi. Balance antara text dan multi/single/yn.',
    mendalam: 'Buat 12-20+ PERTANYAAN yng menggali DETAIL. Banyak pertanyaan "bagaimana" dan "kenapa". Include UX flow, skala, kompetitor, dan risk assessment.'
  }[mode] || 'Buat 8-12 pertanyaan.';

  var prompt = [
    'Kamu adalah product analyst yang bantu founder Indonesia',
    'memvalidasi dan memperdalam pemahaman produk.',
    '',
    '=== KONTEKS PRODUK ===',
    'Nama: ' + productName,
    'Kategori: ' + catStr,
    'Tipe: ' + type,
    'Domain: ' + domain,
    'Ide: ' + (idea || '-'),
    'Tech: ' + techStr,
    'Extra features: ' + extrasStr,
    '',
    '=== TUGAS ===',
    modeDesc,
    '',
    '⚠︀ PENTING: Buat ' + qCount + ' pertanyaan (jangan kurang, jangan lebih).',
    'Hitung dengan teliti jumlah array sebelum return.',
    '',
    'Contoh: untuk ' + qCount + ' pertanyaan, return array dengan ' + qCount + ' object.',
    '',
    'Aturan:',
    '- Pertanyaan HARUS SPESIFIK untuk domain ' + domain + '   jangan generic',
    '- Jangan tanya hal yang udah terjawab dari konteks di atas',
    '- Variasi tipe: text (buka), yn (ya/tidak), multi (pilih beberapa), single (pilih satu)',
    '- Urut: base/modal bisnis → operational → technical → monetisasi/scale',
    '- Jika domain ' + domain + ' memiliki karakteristik khusus, tanyakan hal spesifik',
    '',
    'Untuk SETIAP pertanyaan, berikan 3 REKOMENDASI JAWABAN yang paling umum.',
    'Rekomendasi harus SPESIFIK untuk domain ' + domain + ', jangan generik.',
    'Untuk tipe multi/single, rekomendasi adalah option yang paling mungkin dipilih.',
    'Untuk tipe text, rekomendasi adalah 3 jawaban contoh yang umum.',
    '',
    'Output HANYA JSON array:',
    '[{',
    '  "id": "q1",',
    '  "question": "Pertanyaan...",',
    '  "type": "text|yn|multi|single",',
    '  "options": ["Opsi1","Opsi2","Opsi3"],  // untuk multi/single, null untuk text/yn',
    '  "recommendations": ["Rekomendasi 1","Rekomendasi 2","Rekomendasi 3"],',
    '  "recommendReason": "Alasan kenapa rekomendasi ini cocok untuk produk ini"',
    '}]'
  ].join('\n');

  try {
    var result = await callAI([
      { role: 'system', content: 'Kamu adalah asisten analis produk Indonesia. Return HANYA JSON array. Jangan markdown.' },
      { role: 'user', content: prompt }
    ]);

    if (!result) throw new Error('No result');

    var jsonMatch = result.match(/\[[\s\S]*\]/);
    if (!jsonMatch) throw new Error('No JSON found');

    var questions = JSON.parse(jsonMatch[0]);
    if (!Array.isArray(questions) || questions.length === 0) throw new Error('Empty questions');

    // Normalize question fields
    _surveyQuestions = questions.map(function(q) {
      return {
        id: q.id || 'q' + Math.random().toString(36).substr(2, 5),
        question: q.question || q.q || '',
        type: q.type || q.t || 'text',
        options: q.options || q.opts || [],
        recommendations: q.recommendations || [],
        recommendReason: q.recommendReason || ''
      };
    });

    state.surveyTotal = _surveyQuestions.length;
    state.surveyQ = 0;
    state.answers = state.answers || {};
    state.savedQuestions = _surveyQuestions; // persist for page refresh
    if (typeof saveState === 'function') saveState();

    return _surveyQuestions;

  } catch(e) {
    console.warn('AI survey generation failed:', e);
    // Fallback: generate static questions based on mode   not just 4 generic ones
    var fallbackCount = { cepat: 5, standar: 10, mendalam: 15 }[mode] || 10;
    _surveyQuestions = [];
    var allFallback = [
      { id: 'model', question: 'Model bisnis produk ini?', type: 'multi', options: ['B2C langsung ke konsumen', 'B2B enterprise', 'Marketplace', 'Hybrid B2B+B2C', 'Subscription'], recommendations: ['B2C langsung ke konsumen', 'Marketplace', 'Subscription'] },
      { id: 'target', question: 'Siapa target pengguna utama?', type: 'text', options: [], recommendations: ['UMKM', 'Perusahaan', 'Individu'] },
      { id: 'main_outcome', question: 'Apa outcome utama yang ingin dicapai user?', type: 'text', options: [], recommendations: [] },
      { id: 'platform', question: 'Platform utama?', type: 'multi', options: ['Website', 'Android', 'iOS', 'WhatsApp', 'Mobile-first Web'], recommendations: ['Website', 'WhatsApp', 'Mobile-first Web'] },
      { id: 'has_payment', question: 'Butuh payment integration?', type: 'yn', options: ['Ya', 'Tidak'], recommendations: ['Ya'] },
      { id: 'has_delivery', question: 'Apakah ada pengiriman fisik?', type: 'yn', options: ['Ya', 'Tidak'], recommendations: [] },
      { id: 'has_location', question: 'Ada lokasi fisik (toko/kantor)?', type: 'yn', options: ['Ya', 'Tidak'], recommendations: [] },
      { id: 'branches', question: 'Jumlah cabang?', type: 'single', options: ['1 lokasi', '2-5 cabang', '6-20 cabang', '20+ cabang'], recommendations: ['1 lokasi', '2-5 cabang'] },
      { id: 'has_auth', question: 'Butuh login/register?', type: 'single', options: ['Ya, wajib login', 'Ya, optional', 'Tidak perlu'], recommendations: ['Ya, wajib login', 'Ya, optional'] },
      { id: 'has_whatsapp', question: 'Integrasi WhatsApp?', type: 'yn', options: ['Ya', 'Tidak'], recommendations: ['Ya'] },
      { id: 'revenue', question: 'Model pendapatan?', type: 'multi', options: ['Per-transaksi', 'Subscription', 'Komisi', 'Iklan', 'Freemium'], recommendations: ['Per-transaksi', 'Subscription'] },
      { id: 'scale_target', question: 'Target skala awal?', type: 'single', options: ['< 100 user', '100-500 user', '500-2000 user', '2000-10000 user'], recommendations: ['100-500 user', '500-2000 user'] },
      { id: 'team_size', question: 'Ukuran tim developer?', type: 'single', options: ['Solo founder', '2-3 orang', '4-8 orang', '9+ orang'], recommendations: ['Solo founder', '2-3 orang'] },
      { id: 'has_tracking', question: 'Butuh real-time tracking/status?', type: 'yn', options: ['Ya', 'Tidak'], recommendations: [] },
      { id: 'has_ai', question: 'Ada fitur AI?', type: 'yn', options: ['Ya', 'Tidak'], recommendations: [] },
      { id: 'competitors', question: 'Siapa kompetitor utama?', type: 'text', options: [], recommendations: [] },
      { id: 'deadline', question: 'Target rilis MVP?', type: 'single', options: ['1 bulan', '2-3 bulan', '3-6 bulan', '>6 bulan'], recommendations: ['2-3 bulan', '3-6 bulan'] },
      { id: 'existing_system', question: 'Udah punya sistem eksisting?', type: 'yn', options: ['Ya', 'Tidak'], recommendations: [] },
    ];
    // Pick the first N based on mode, plus all YN questions for variety
    var base = allFallback.slice(0, Math.min(fallbackCount, allFallback.length));
    // Add more YN questions if we need to reach count
    var extraYNs = allFallback.filter(function(q) { return q.type === 'yn'; });
    while (base.length < fallbackCount && extraYNs.length > 0) {
      var candidate = extraYNs.shift();
      if (base.indexOf(candidate) < 0) base.push(candidate);
    }
    _surveyQuestions = base.slice(0, fallbackCount);
    state.surveyTotal = _surveyQuestions.length;
    state.surveyQ = 0;
    state.savedQuestions = _surveyQuestions; // persist even fallback questions
    if (typeof saveState === 'function') saveState();
    return _surveyQuestions;
  }
}

// Mode selector   triggered when user clicks a mode card in Step 3
function selectSurveyMode(mode) {
  // Toggle: if same mode, deselect
  if (state.surveyMode === mode) {
    state.surveyMode = '';
    state.answers = {};
    state.savedQuestions = [];
    if (typeof saveState === 'function') saveState();
    renderWizStep();
    return;
  }
  state.surveyMode = mode;
  // Clear old answers & questions when switching mode
  state.answers = {};
  state.savedQuestions = [];
  if (typeof saveState === 'function') saveState();

  // Rainbow glow on survey card while AI generates questions
  var surveyCard = document.querySelector('#page-wizard .card');
  if (surveyCard) surveyCard.classList.add('ai-processing');

  // Show loading, then generate questions
  var loading = document.getElementById('surveyLoading');
  if (loading) loading.style.display = 'block';

  generateSurveyQuestions(mode).then(function() {
    // Re-render Step 3 to show survey questions (card replacement removes glow)
    renderWizStep();
  });
}

// Survey recommendation chip click   appends to text input
function clickSurveyRec(qId, value) {
  if (!value) return;
  // Find the input for this question
  var activePage = document.querySelector('.page.active');
  var surveyContainer = activePage ? activePage.querySelector('#surveyContainer') : document.getElementById('surveyContainer');
  if (!surveyContainer) return;

  // Check if it's a text input or multi/single
  var question = _surveyQuestions.find(function(q) { return q.id === qId; });
  if (!question) return;

  if (question.type === 'text' || question.type === 't') {
    // Append to text input with comma separator
    var input = surveyContainer.querySelector('input[oninput*="' + qId + '"]') ||
                surveyContainer.querySelector('input');
    if (input) {
      var current = input.value || '';
      var existing = current.split(',').map(function(s) { return s.trim(); });
      if (existing.indexOf(value) < 0) {
        input.value = (current ? current + ', ' : '') + value;
        // Trigger save
        if (typeof saveAnswer === 'function') saveAnswer(qId, input.value);
      }
    }
  } else if (question.type === 'yn') {
    // YN: set the value directly
    if (typeof setSurveySingle === 'function') {
      var chips = surveyContainer.querySelectorAll('.chip');
      for (var i = 0; i < chips.length; i++) {
        if (chips[i].textContent.trim() === value) {
          chips[i].click();
          break;
        }
      }
      if (typeof saveAnswer === 'function') saveAnswer(qId, value);
    }
  } else {
    // Multi/single: toggle the chip
    var chips = surveyContainer.querySelectorAll('.chip');
    for (var i = 0; i < chips.length; i++) {
      if (chips[i].textContent.trim() === value) {
        chips[i].click();
        break;
      }
    }
  }
}

function initSurvey(domain) {
  const conf = getDomain().confidence;
  if (conf < 0.5) _surveyMode = 'quick';
  else if (conf > 0.9) _surveyMode = 'smart';
  _surveyQuestions = buildSurveyQuestions(domain, _surveyMode);
  state.surveyTotal = _surveyQuestions.length;
  state.surveyQ = 0;
  state.answers = {};
  saveState();
}

function fillExampleIdea(idea) {
  navigate('setup');
  // After setup loads, fill the idea
  setTimeout(() => {
    if (typeof state !== 'undefined') {
      state.idea = idea;
      saveState();
    }
    const input = document.getElementById('productName');
    if (input) {
      // Extract a product name from the idea
      const match = idea.match(/(?:Aplikasi|Sistem|Manajemen)\s+(.+?)(?:\s|$)/i);
      if (match) {
        input.value = match[1].charAt(0).toUpperCase() + match[1].slice(1);
      } else {
        input.value = idea.substring(0, 40);
      }
      // Trigger input event
      input.dispatchEvent(new Event('input', { bubbles: true }));
    }
    showToast('Ide terisi! Lanjutkan ke wizard.', 'success');
  }, 300);
}

//     (OLD Wizard system removed   NEW system lives in index.html)    

//     Step 1: Ide    
function updateIdeaCounter() {
  const textarea = document.getElementById('ideaText');
  const len = textarea.value.length;
  document.getElementById('ideaCount').textContent = len.toLocaleString();
  const counter = document.querySelector('.form-counter');
  counter?.classList.toggle('warn', len >= 9000);
  counter?.classList.toggle('over', len > 10000);
  const expandRow = document.getElementById('expandRow');
  expandRow.style.display = len >= 20 ? 'flex' : 'none';
  state.idea = textarea.value;
  saveState();
}

function checkIdeaLength() {
  const t = document.getElementById('ideaText');
  if (t) updateIdeaCounter();
}

function fillExample(idx) {
  const idea = EXAMPLE_IDEAS[idx];
  document.getElementById('ideaText').value = idea;
  document.getElementById('productName').value = idea.split(' ').slice(0, 3).join(' ');
  updateIdeaCounter();
  showToast('Contoh ide diterapkan!', 'success');
}

//     Saved Provider Selection    

//     Step 2: Teknologi    
function renderTechGrids() {
  ['frontend', 'backend', 'database', 'deployment'].forEach(cat => {
    const grid = document.getElementById(`${cat}Grid`);
    if (!grid) return;
    grid.innerHTML = TECH_OPTIONS[cat]
      .map(([val, label, free]) => {
        const selected = state.tech[cat] === val ? ' selected' : '';
        return `<div class=\"tech-card${selected}\" data-cat=\"${cat}\" data-val=\"${val}\" onclick=\"selectTech(this,'${cat}')\">
          <div class=\"tech-label\">${label}</div>
          ${free ? `<span class=\"tech-free\">Gratis ${iconSvg('check', 10)}</span>` : ''}
          ${selected ? `<span class=\"tech-check\">${iconSvg('check', 14)}</span>` : ''}
        </div>`;
      })
      .join('');
    updateTechHeaderSelected(cat);
  });
}

function updateTechHeaderSelected(cat) {
  const btn = document.getElementById(`${cat}Btn`);
  if (!btn) return;
  const val = state.tech[cat] || 'ai-pilih';
  if (val === 'ai-pilih') {
    btn.innerHTML = 'Pilih ▶';
  } else {
    const options = TECH_OPTIONS[cat] || [];
    const found = options.find(o => o[0] === val);
    btn.innerHTML = (found ? found[1] : val) + ' ✓';
  }
}

function selectTech(el, cat) {
  document.querySelectorAll(`#${cat}Grid .tech-card`).forEach(c => c.classList.remove('selected'));
  el.classList.add('selected');
  state.tech[cat] = el.dataset.val;
  renderTechGrids();
  saveState();
}

function toggleCategory(header) {
  const body = header.nextElementSibling;
  body.classList.toggle('closed');
  const btn = header.querySelector('.cat-btn');
  if (body.classList.contains('closed')) {
    if (btn) btn.innerHTML = 'Pilih \u25B6';
  } else {
    if (btn) btn.innerHTML = 'Tutup \u25BC';
  }
}

function renderExtras() {
  const container = document.getElementById('extraChips');
  if (!container) return;
  container.innerHTML = EXTRA_OPTIONS
    .map(([val, label]) => {
      const sel = state.extras.includes(val) ? ' selected' : '';
      return `<span class=\"chip${sel}\" data-val=\"${val}\" onclick=\"toggleChip(this)\">${label}</span>`;
    })
    .join('');
}

function toggleChip(el) {
  const val = el.dataset.val;
  const idx = state.extras.indexOf(val);
  if (idx >= 0) {
    state.extras.splice(idx, 1);
    el.classList.remove('selected');
  } else {
    state.extras.push(val);
    el.classList.add('selected');
  }
  saveState();
}

//     Step 3: Survey    
function getCachedSurveyQuestions() {
  // Safe version: returns cached questions without calling getDomain()
  // Prevents potential recursion during page re-render
  return _surveyQuestions;
}

function getSurveyQuestions() {
  // Adaptive survey: initialize from detected domain
  const domain = getDomain().primary;
  if (!_surveyQuestions.length || state.surveyTotal === 0) {
    _surveyQuestions = buildSurveyQuestions(domain, _surveyMode);
    state.surveyTotal = _surveyQuestions.length;
    state.surveyQ = 0;
    state.savedQuestions = _surveyQuestions; // persist for page refresh
    saveState();
  }
  return _surveyQuestions;
}

function renderSurvey() {
  const qs = getCachedSurveyQuestions();
  state.surveyTotal = qs.length;
  var activePage = document.querySelector('.page.active');
  var container = activePage ? activePage.querySelector('#surveyContainer') : document.getElementById('surveyContainer');
  if (!container) return;
  const groupLabel = qs[state.surveyQ] && qs[state.surveyQ].group ? (SURVEY_GROUP_LABELS[qs[state.surveyQ].group] || '') : '';
  const pct = qs.length > 0 ? ((state.surveyQ + 1) / qs.length * 100) : 0;
  container.innerHTML = `
    <div class="survey-progress-header">
      <span class="survey-progress-text">Question ${state.surveyQ + 1} of ${qs.length}</span>
      ${groupLabel ? `<span class="survey-group-label">${groupLabel}</span>` : ''}
    </div>
    <div class="survey-progress">
      <div class="survey-bar" id="surveyBar" style="width:${pct}%"></div>
    </div>
    ${qs.map((q, i) => {
      const hidden = i !== state.surveyQ ? ' style="display:none;"' : '';
      const qText = q.q || q.question || '';
      return `<div class="survey-question" data-q="${i}"${hidden}>
        <div class="survey-q-text">${qText}</div>
        ${renderSurveyInput(q)}
        <div class="survey-recs-container" data-q="${q.id}"></div>
        <div class="survey-q-nav">
          <button class="survey-nav-btn" id="surveyPrevBtn" onclick="prevSurvey()"${i === 0 ? ' style="visibility:hidden"' : ''}>Sebelumnya</button>
          <button class="survey-nav-btn accent" id="surveyNextBtn" onclick="nextSurvey()">${i === qs.length - 1 ? 'Lanjut ke Teknologi →' : 'Selanjutnya →'}</button>
        </div>
      </div>`;
    }).join('')}
  `;
  updateSurveyProgress();
  // Trigger AI recommendations
  if (typeof loadSurveyRecommendations === 'function') {
    setTimeout(loadSurveyRecommendations, 100);
  }
}

//     Saved Provider Selection    


function renderSurveyInput(q) {
  // Normalize adaptive question fields
  const type = q.t || q.type || 'text';
  const opts = q.opts || q.options || [];
  const placeholder = q.hint || q.placeholder || 'Ketik jawaban...';
  const recs = q.recommendations || [];
  const recReason = q.recommendReason || '';

  if (type === 'text') {
    const val = typeof state !== 'undefined' && state.answers ? escapeHtml(state.answers[q.id] || '') : '';
    let html = `<input type="text" class="form-input survey-input" placeholder="${placeholder}" value="${val}" oninput="saveAnswer('${q.id}',this.value)">`;
    // Show recommendation chips below text input
    if (recs.length > 0) {
      html += '<div class="flex flex-wrap gap-1.5 mt-2">' +
        recs.map(function(r, ri) {
          return '<span class="chip text-[10px] cursor-pointer" style="background:rgba(0,224,143,0.06);border-color:rgba(0,224,143,0.15)" onclick="clickSurveyRec(\'' + q.id + '\',\'' + escapeHtml(r).replace(/'/g, "\\'") + '\')" title="' + escapeHtml(recReason) + '">+' + escapeHtml(r) + '</span>';
        }).join('') +
        '</div>';
    }
    return html;
  }
  if (type === 'yn') {
    const selected = (typeof state !== 'undefined' && state.answers) ? (state.answers[q.id] || '') : '';
    const opts = ['Ya', 'Tidak'];
    return `<div class="survey-multi">${opts.map(o => {
      const sel = selected === o ? ' selected' : '';
      return `<span class="chip${sel}" onclick="setSurveySingle('${q.id}','${escapeHtml(o)}',this)">${o}</span>`;
    }).join('')}</div>`;
  }
  if (type === 'multi' || type === 'mx') {
    const selected = (typeof state !== 'undefined' && state.answers) ? (state.answers[q.id] || []) : [];
    return `<div class="survey-multi">${opts.map(o => {
      const sel = selected.includes(o) ? ' selected' : '';
      return `<span class="chip${sel}" onclick="toggleSurveyMulti('${q.id}','${escapeHtml(o)}',this)">${o}</span>`;
    }).join('')}</div>`;
  }
  if (type === 'single' || type === 'mc') {
    const selected = (typeof state !== 'undefined' && state.answers) ? (state.answers[q.id] || '') : '';
    return `<div class="survey-multi">${opts.map(o => {
      const sel = selected === o ? ' selected' : '';
      return `<span class="chip${sel}" onclick="setSurveySingle('${q.id}','${escapeHtml(o)}',this)">${o}</span>`;
    }).join('')}</div>`;
  }
  return '';
}

function saveAnswer(id, val) {
  state.answers[id] = val;
  saveState();
}

function toggleSurveyMulti(id, val, el) {
  if (!state.answers[id]) state.answers[id] = [];
  const arr = state.answers[id];
  const idx = arr.indexOf(val);
  if (idx >= 0) {
    arr.splice(idx, 1);
    el.classList.remove('selected');
  } else {
    arr.push(val);
    el.classList.add('selected');
  }
  saveState();
}

function setSurveySingle(id, val, el) {
  state.answers[id] = val;
  const parent = el.closest('.survey-multi');
  if (parent) {
    parent.querySelectorAll('.chip').forEach(c => c.classList.remove('selected'));
  }
  el.classList.add('selected');
  saveState();
}

function showSurveyQuestion(n) {
  state.surveyQ = n;
  document.querySelectorAll('.survey-question').forEach(el => {
    el.style.display = parseInt(el.dataset.q, 10) === n ? 'block' : 'none';
  });
  updateSurveyProgress();
  updateSurveyNav();
  const prevBtn = document.getElementById('surveyPrevBtn');
  if (prevBtn) prevBtn.style.visibility = n === 0 ? 'hidden' : 'visible';
}

function nextSurvey() {
  const total = state.surveyTotal;
  if (state.surveyQ < total - 1) {
    showSurveyQuestion(state.surveyQ + 1);
    // Sync wizard nav button text
    var navBtn = document.querySelector('.wizard-nav .btn-primary');
    if (navBtn) navBtn.textContent = 'Lanjut →';
  } else {
    // Survey done   go to teknologi step
    goWizardStep(3);
  }
}

function surveyGoNext() {
  if (typeof nextSurvey === 'function') nextSurvey();
}

//     Saved Provider Selection    


function prevSurvey() {
  if (state.surveyQ > 0) showSurveyQuestion(state.surveyQ - 1);
}

function updateSurveyProgress() {
  const total = state.surveyTotal;
  const pct = total > 0 ? ((state.surveyQ + 1) / total * 100) : 0;
  const bar = document.getElementById('surveyBar');
  if (bar) bar.style.width = `${pct}%`;
}

function updateSurveyNav() {
  const btn = document.getElementById('surveyNextBtn');
  if (!btn) return;
  btn.innerHTML = state.surveyQ >= state.surveyTotal - 1
    ? 'Lanjut ke Teknologi →'
    : `Lanjut ${iconSvg('arrowRight', 14)}`;
}

//     Domain Detection (Hybrid AI + Keyword)    
function hasTerm(text, terms) {
  const lower = text.toLowerCase();
  return terms.some((term) => lower.includes(term));
}

//     DOMAIN PACKS    
// Comprehensive domain knowledge base for entity generation
const DOMAIN_PACKS = {
  delivery: {
    name: 'Delivery / Pesan Antar',
    actors: ['Merchant', 'Customer', 'Driver', 'Admin'],
    entities: {
      Order: {
        fields: {
          orderNumber: 'string @unique',
          customerId: 'string',
          merchantId: 'string',
          driverId: 'string?',
          status: 'DeliveryStatus @default(PENDING)',
          subtotal: 'Float',
          deliveryFee: 'Float',
          total: 'Float',
          notes: 'string?',
          deliveryAddress: 'string',
          latitude: 'Float?',
          longitude: 'Float?',
          scheduledAt: 'DateTime?',
          paidAt: 'DateTime?',
          deliveredAt: 'DateTime?',
          cancelledAt: 'DateTime?',
          createdAt: 'DateTime @default(now())',
          updatedAt: 'DateTime @updatedAt',
        },
        enums: { DeliveryStatus: ['PENDING', 'CONFIRMED', 'ASSIGNED', 'ON_THE_WAY', 'DELIVERED', 'CANCELLED'] },
        indexes: ['status', 'driverId', 'customerId', 'createdAt'],
        relations: {
          belongsTo: ['Customer', 'Merchant', 'Driver'],
          hasMany: ['OrderItem', 'Tracking', 'Payment'],
        }
      },
      OrderItem: {
        fields: {
          orderId: 'string',
          name: 'string',
          quantity: 'Int',
          price: 'Float',
          subtotal: 'Float',
          notes: 'string?',
        },
        relations: { belongsTo: ['Order'] }
      },
      Customer: {
        fields: {
          name: 'string',
          phone: 'string @unique',
          address: 'string?',
          latitude: 'Float?',
          longitude: 'Float?',
          totalOrders: 'Int @default(0)',
          lastOrderAt: 'DateTime?',
          createdAt: 'DateTime @default(now())',
        },
        indexes: ['phone'],
        relations: { hasMany: ['Order'] }
      },
      Merchant: {
        fields: {
          name: 'string',
          phone: 'string @unique',
          businessName: 'string',
          address: 'string',
          latitude: 'Float?',
          longitude: 'Float?',
          isActive: 'Boolean @default(true)',
          createdAt: 'DateTime @default(now())',
        },
        indexes: ['phone', 'isActive'],
        relations: { hasMany: ['Order', 'Product'] }
      },
      Driver: {
        fields: {
          name: 'string',
          phone: 'string @unique',
          vehicleType: 'string',
          vehiclePlate: 'string',
          isAvailable: 'Boolean @default(true)',
          currentLatitude: 'Float?',
          currentLongitude: 'Float?',
          totalDeliveries: 'Int @default(0)',
          rating: 'Float @default(5.0)',
          createdAt: 'DateTime @default(now())',
        },
        indexes: ['phone', 'isAvailable'],
        relations: { hasMany: ['Delivery'] }
      },
      Delivery: {
        fields: {
          orderId: 'string @unique',
          driverId: 'string',
          status: 'DeliveryStatus @default(ASSIGNED)',
          pickupTime: 'DateTime?',
          dropoffTime: 'DateTime?',
          distance: 'Float?',
          notes: 'string?',
          customerSignature: 'string?',
        },
        relations: { belongsTo: ['Order', 'Driver'] }
      },
      Tracking: {
        fields: {
          orderId: 'string',
          status: 'string',
          latitude: 'Float?',
          longitude: 'Float?',
          note: 'string?',
          timestamp: 'DateTime @default(now())',
        },
        indexes: ['orderId', 'timestamp'],
        relations: { belongsTo: ['Order'] }
      },
      Payment: {
        fields: {
          orderId: 'string @unique',
          method: 'PaymentMethod',
          amount: 'Float',
          status: 'PaymentStatus @default(PENDING)',
          paidAt: 'DateTime?',
          externalRef: 'string?',
          createdAt: 'DateTime @default(now())',
        },
        enums: { PaymentMethod: ['CASH', 'TRANSFER', 'EWALLET', 'COD'], PaymentStatus: ['PENDING', 'CONFIRMED', 'FAILED', 'REFUNDED'] },
        indexes: ['orderId', 'status'],
        relations: { belongsTo: ['Order'] }
      },
      Area: {
        fields: {
          name: 'string @unique',
          isActive: 'Boolean @default(true)',
          deliveryFee: 'Float @default(0)',
          minOrder: 'Float @default(0)',
        },
        relations: { hasMany: ['Merchant'] }
      },
      Vehicle: {
        fields: { type: 'string @unique', icon: 'string?', maxLoad: 'Float?' },
        relations: { hasMany: ['Driver'] }
      },
      Product: {
        fields: {
          merchantId: 'string',
          name: 'string',
          price: 'Float',
          image: 'string?',
          isAvailable: 'Boolean @default(true)',
          category: 'string?',
          createdAt: 'DateTime @default(now())',
        },
        indexes: ['merchantId', 'isAvailable'],
        relations: { belongsTo: ['Merchant'], hasMany: ['OrderItem'] }
      }
    },
    flows: [
      'Merchant menerima order via WhatsApp   staff create order di sistem',
      'System assigns driver terdekat yang available   driver dapat notifikasi',
      'Driver accept → status berubah ke ON_THE_WAY   customer lihat tracking realtime',
      'Driver sampai lokasi → marked DELIVERED   customer konfirmasi',
      'Payment diverifikasi   order complete   merchant dan driver dapat ringkasan',
    ],
    endpoints: [
      'POST   /api/orders                          { customerId, merchantId, items[], deliveryAddress }',
      'GET    /api/orders                           ?status=&date=&merchantId=&customerId=&page=&limit=',
      'GET    /api/orders/:id',
      'POST   /api/orders/:id/assign-driver         { driverId }',
      'GET    /api/drivers/available                ?areaId=',
      'PATCH  /api/drivers/:id/location             { latitude, longitude }',
      'POST   /api/deliveries/:id/track             { latitude, longitude, status }',
      'PATCH  /api/deliveries/:id/complete          { signature? }',
      'POST   /api/payments                         { orderId, method, amount }',
      'GET    /api/merchants/:id/summary            ?dateFrom=&dateTo=',
      'GET    /api/areas',
    ],
    metrics: ['Orders per day', 'Average delivery time (menit)', 'Delivery success rate %', 'Driver utilization %', 'Revenue per merchant'],
    genericFeatures: ['Manajemen Order', 'Tracking Realtime', 'Assign Driver Otomatis', 'Riwayat Pengiriman', 'Laporan Merchant'],
  },

  inventory: {
    name: 'Inventory / Stok Gudang',
    actors: ['Owner', 'Staff Gudang', 'Staff Purchasing', 'Supplier'],
    entities: {
      Product: {
        fields: {
          sku: 'string @unique',
          name: 'string',
          category: 'string?',
          unit: 'string',
          price: 'Float',
          minStock: 'Int @default(5)',
          currentStock: 'Int @default(0)',
          isActive: 'Boolean @default(true)',
          createdAt: 'DateTime @default(now())',
          updatedAt: 'DateTime @updatedAt',
        },
        indexes: ['sku', 'category', 'isActive'],
        relations: { hasMany: ['StockMovement', 'Batch'], belongsTo: ['Category'] }
      },
      Category: {
        fields: { name: 'string @unique', description: 'string?' },
        relations: { hasMany: ['Product'] }
      },
      Batch: {
        fields: {
          productId: 'string',
          batchNumber: 'string',
          quantity: 'Int',
          remainingQty: 'Int',
          expiryDate: 'DateTime?',
          receivedAt: 'DateTime @default(now())',
          supplierId: 'string?',
        },
        indexes: ['productId', 'batchNumber', 'expiryDate'],
        relations: { belongsTo: ['Product', 'Supplier'] }
      },
      StockMovement: {
        fields: {
          productId: 'string',
          batchId: 'string?',
          type: 'MovementType',
          quantity: 'Int @default(0)',
          referenceType: 'string?',
          referenceId: 'string?',
          note: 'string?',
          staffId: 'string',
          createdAt: 'DateTime @default(now())',
        },
        enums: { MovementType: ['IN', 'OUT', 'ADJUSTMENT', 'RETURN', 'TRANSFER'] },
        indexes: ['productId', 'type', 'createdAt', 'batchId'],
        relations: { belongsTo: ['Product', 'Batch'] }
      },
      Supplier: {
        fields: {
          name: 'string',
          phone: 'string?',
          email: 'string?',
          address: 'string?',
          isActive: 'Boolean @default(true)',
          paymentTerms: 'string?',
          createdAt: 'DateTime @default(now())',
        },
        relations: { hasMany: ['Batch', 'PurchaseOrder'] }
      },
      Location: {
        fields: { name: 'string @unique', code: 'string?', description: 'string?' },
        relations: { hasMany: ['Product'] }
      },
      PurchaseOrder: {
        fields: {
          orderNumber: 'string @unique',
          supplierId: 'string',
          status: 'POStatus @default(DRAFT)',
          totalAmount: 'Float',
          notes: 'string?',
          expectedDate: 'DateTime?',
          receivedAt: 'DateTime?',
          createdAt: 'DateTime @default(now())',
        },
        enums: { POStatus: ['DRAFT', 'SENT', 'PARTIAL', 'COMPLETED', 'CANCELLED'] },
        indexes: ['supplierId', 'status'],
        relations: { belongsTo: ['Supplier'] }
      },
      Alert: {
        fields: {
          productId: 'string',
          type: 'AlertType',
          message: 'string',
          isRead: 'Boolean @default(false)',
          createdAt: 'DateTime @default(now())',
        },
        enums: { AlertType: ['LOW_STOCK', 'EXPIRY', 'OVERSTOCK'] },
        relations: { belongsTo: ['Product'] }
      }
    },
    flows: [
      'Staff gudang menerima barang baru   catat batch, lokasi rak, dan quantity',
      'Sistem validasi SKU unik   jika produk baru, buat master produk dulu',
      'Stok otomatis bertambah   jika melebihi batas, tidak perlu alert',
      'Staff mengeluarkan stok   validasi qty tersedia   jika kurang, error + sisa qty',
      'Sistem cek low stock setiap transaksi keluar   jika di bawah min, create alert',
      'Owner lihat dashboard: total stok, nilai inventory, slow-moving items',
    ],
    endpoints: [
      'GET    /api/products                       ?category=&search=&page=&limit=',
      'POST   /api/products                       { sku, name, category, unit, price, minStock }',
      'GET    /api/products/:id',
      'PATCH  /api/products/:id',
      'POST   /api/stock/in                       { productId, batchNumber, quantity, expiryDate?, supplierId?, locationId? }',
      'POST   /api/stock/out                      { productId, batchId?, quantity, referenceType?, referenceId?, note? }',
      'GET    /api/stock/movements                 ?productId=&type=&dateFrom=&dateTo=&page=&limit=',
      'GET    /api/alerts                          ?type=&isRead=',
      'PATCH  /api/alerts/:id/read',
      'POST   /api/purchase-orders                  { supplierId, items[], expectedDate? }',
      'GET    /api/suppliers',
      'GET    /api/dashboard/summary               ?period=',
    ],
    metrics: ['Stock turnover ratio', 'Out of stock count', 'Total inventory value', 'Slow-moving items %', 'Stock accuracy %'],
    genericFeatures: ['Manajemen Produk & SKU', 'Stok Masuk/Keluar', 'Low Stock Alert', 'Batch & Expiry Tracking', 'Laporan Stok'],
  },

  crm: {
    name: 'CRM / Sales Pipeline',
    actors: ['Sales', 'Sales Manager', 'Customer', 'Admin'],
    entities: {
      Lead: {
        fields: {
          name: 'string',
          company: 'string?',
          phone: 'string?',
          email: 'string?',
          source: 'LeadSource @default(REFERRAL)',
          status: 'LeadStatus @default(NEW)',
          score: 'Int @default(0)',
          assignedTo: 'string?',
          notes: 'string?',
          lastContactedAt: 'DateTime?',
          convertedAt: 'DateTime?',
          createdAt: 'DateTime @default(now())',
          updatedAt: 'DateTime @updatedAt',
        },
        enums: { LeadSource: ['REFERRAL', 'WEBSITE', 'COLD_CALL', 'SOCIAL_MEDIA', 'EVENT', 'OTHER'], LeadStatus: ['NEW', 'CONTACTED', 'QUALIFIED', 'PROPOSAL', 'NEGOTIATION', 'WON', 'LOST'] },
        indexes: ['status', 'assignedTo', 'source'],
        relations: { belongsTo: ['User'], hasMany: ['Activity', 'Deal'] }
      },
      Contact: {
        fields: {
          name: 'string',
          phone: 'string?',
          email: 'string?',
          company: 'string?',
          position: 'string?',
          notes: 'string?',
          createdAt: 'DateTime @default(now())',
        },
        relations: { belongsTo: ['Company'], hasMany: ['Activity'] }
      },
      Company: {
        fields: { name: 'string @unique', industry: 'string?', size: 'string?', website: 'string?', notes: 'string?' },
        relations: { hasMany: ['Contact', 'Deal'] }
      },
      Deal: {
        fields: {
          leadId: 'string?',
          contactId: 'string?',
          companyId: 'string?',
          name: 'string',
          value: 'Float',
          stage: 'DealStage @default(QUALIFIED)',
          probability: 'Int @default(10)',
          expectedCloseDate: 'DateTime?',
          assignedTo: 'string',
          notes: 'string?',
          closedAt: 'DateTime?',
          createdAt: 'DateTime @default(now())',
        },
        enums: { DealStage: ['QUALIFIED', 'PROPOSAL', 'NEGOTIATION', 'CLOSED_WON', 'CLOSED_LOST'] },
        indexes: ['stage', 'assignedTo', 'expectedCloseDate'],
        relations: { belongsTo: ['Lead', 'Contact', 'Company', 'User'] }
      },
      Activity: {
        fields: {
          leadId: 'string?',
          contactId: 'string?',
          dealId: 'string?',
          type: 'ActivityType',
          subject: 'string',
          description: 'string?',
          dueDate: 'DateTime?',
          completedAt: 'DateTime?',
          createdBy: 'string',
          createdAt: 'DateTime @default(now())',
        },
        enums: { ActivityType: ['CALL', 'EMAIL', 'MEETING', 'TASK', 'NOTE'] },
        indexes: ['leadId', 'type', 'dueDate', 'createdBy'],
        relations: { belongsTo: ['Lead', 'Contact', 'Deal', 'User'] }
      },
      Pipeline: {
        fields: { name: 'string', stages: 'string (JSON)', isDefault: 'Boolean @default(false)' },
        relations: { hasMany: ['Deal'] }
      },
      Invoice: {
        fields: {
          dealId: 'string',
          invoiceNumber: 'string @unique',
          amount: 'Float',
          status: 'InvoiceStatus @default(DRAFT)',
          dueDate: 'DateTime',
          paidAt: 'DateTime?',
          notes: 'string?',
          createdAt: 'DateTime @default(now())',
        },
        enums: { InvoiceStatus: ['DRAFT', 'SENT', 'PAID', 'OVERDUE', 'CANCELLED'] },
        relations: { belongsTo: ['Deal'] }
      }
    },
    flows: [
      'Sales mendapat lead baru   create lead dengan source dan score awal',
      'Sales melakukan follow-up   catat activity (call/email/meeting)   update status',
      'Lead qualified → create deal dengan value dan expected close date',
      'Deal berjalan melalui pipeline stages   update probability setiap stage',
      'Deal WON → generate invoice   kirim ke customer   tunggu payment',
      'Manager lihat dashboard pipeline: total value, conversion rate, aktivitas tim',
    ],
    endpoints: [
      'GET    /api/leads                          ?status=&source=&assignedTo=&search=&page=&limit=',
      'POST   /api/leads                          { name, company, phone, email, source, notes }',
      'PATCH  /api/leads/:id/status                { status }',
      'GET    /api/deals                           ?stage=&assignedTo=&page=&limit=',
      'POST   /api/deals                           { leadId?, contactId?, name, value, stage, expectedCloseDate }',
      'PATCH  /api/deals/:id/stage                 { stage }',
      'GET    /api/activities                       ?leadId=&type=&dueDate=&completed=',
      'POST   /api/activities                       { leadId?, contactId?, type, subject, description, dueDate }',
      'GET    /api/pipeline/summary',
      'POST   /api/invoices                         { dealId, amount, dueDate }',
    ],
    metrics: ['Lead conversion rate %', 'Pipeline value (Rp)', 'Average deal size', 'Response time (jam)', 'Win rate %'],
    genericFeatures: ['Manajemen Lead', 'Sales Pipeline', 'Aktivitas Follow-up', 'Invoice', 'Dashboard Pipeline'],
  },

  booking: {
    name: 'Booking / Reservasi',
    actors: ['Customer', 'Staff', 'Admin', 'Owner'],
    entities: {
      Service: {
        fields: { name: 'string', description: 'string?', duration: 'Int', price: 'Float', maxCapacity: 'Int @default(1)', isActive: 'Boolean @default(true)', category: 'string?' },
        indexes: ['isActive', 'category'],
        relations: { hasMany: ['Appointment'] }
      },
      Appointment: {
        fields: { customerId: 'string', serviceId: 'string', staffId: 'string?', date: 'DateTime', startTime: 'DateTime', endTime: 'DateTime', status: 'BookingStatus @default(PENDING)', notes: 'string?', reminderSent: 'Boolean @default(false)', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        enums: { BookingStatus: ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW'] },
        indexes: ['date', 'staffId', 'status', 'customerId'],
        relations: { belongsTo: ['Customer', 'Service', 'Staff'] }
      },
      Customer: {
        fields: { name: 'string', phone: 'string @unique', email: 'string?', totalVisits: 'Int @default(0)', lastVisitAt: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['phone'],
        relations: { hasMany: ['Appointment'] }
      },
      Staff: {
        fields: { name: 'string', phone: 'string?', role: 'string', isActive: 'Boolean @default(true)', workingHours: 'string (JSON)?', maxAppointmentsPerDay: 'Int @default(8)' },
        relations: { hasMany: ['Appointment'] }
      },
      Availability: {
        fields: { staffId: 'string?', date: 'DateTime', startTime: 'DateTime', endTime: 'DateTime', isBooked: 'Boolean @default(false)' },
        indexes: ['staffId', 'date', 'isBooked'],
        relations: { belongsTo: ['Staff'] }
      }
    },
    flows: [
      'Customer melihat katalog layanan dan memilih slot tersedia berdasarkan tanggal',
      'Sistem menampilkan slot yang available   customer pilih waktu',
      'Booking dibuat dengan status PENDING   slot diblokir 15 menit',
      'Staff/admin konfirmasi booking   status jadi CONFIRMED   customer dapat notif',
      'H-1: sistem kirim reminder otomatis   jika no response, booking bisa dibatalkan',
      'Selesai layanan   staff mark COMPLETED   customer bisa rating',
    ],
    endpoints: [
      'GET    /api/services                        ?category=&isActive=',
      'GET    /api/availability                     ?serviceId=&staffId=&date=',
      'POST   /api/appointments                     { customerId, serviceId, staffId?, date, startTime, notes? }',
      'GET    /api/appointments                     ?date=&staffId=&status=&page=&limit=',
      'PATCH  /api/appointments/:id/status           { status }',
      'PATCH  /api/appointments/:id/reschedule       { newDate, newStartTime }',
      'GET    /api/staff',
      'GET    /api/dashboard/summary',
      'POST   /api/reminders/send                   { appointmentId }',
    ],
    metrics: ['Booking conversion rate %', 'No-show rate %', 'Slot utilization %', 'Average booking value', 'Customer retention rate'],
    genericFeatures: ['Katalog Layanan', 'Kalender Slot', 'Booking Online', 'Reminder Otomatis', 'Manajemen Staff'],
  },

  finance: {
    name: 'Finance / Accounting',
    actors: ['Owner', 'Finance Admin', 'Accountant', 'Auditor'],
    entities: {
      Transaction: {
        fields: { type: 'TransactionType', amount: 'Float', categoryId: 'string', description: 'string?', date: 'DateTime', reference: 'string?', paymentMethod: 'string?', isReconciled: 'Boolean @default(false)', receipt: 'string?', createdBy: 'string', createdAt: 'DateTime @default(now())' },
        enums: { TransactionType: ['INCOME', 'EXPENSE', 'TRANSFER'] },
        indexes: ['date', 'type', 'categoryId', 'createdBy'],
        relations: { belongsTo: ['Category', 'Account'] }
      },
      Category: {
        fields: { name: 'string @unique', type: 'TransactionType', description: 'string?', icon: 'string?', budget: 'Float @default(0)' },
        relations: { hasMany: ['Transaction'] }
      },
      Account: {
        fields: { name: 'string', type: 'AccountType', balance: 'Float @default(0)', currency: 'string @default("IDR")', isActive: 'Boolean @default(true)' },
        enums: { AccountType: ['CASH', 'BANK', 'EWALLET', 'CREDIT'] },
        relations: { hasMany: ['Transaction'] }
      },
      Invoice: {
        fields: { invoiceNumber: 'string @unique', customerName: 'string', items: 'string (JSON)', subtotal: 'Float', tax: 'Float @default(0)', total: 'Float', status: 'InvoiceStatus @default(DRAFT)', dueDate: 'DateTime', paidAt: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { InvoiceStatus: ['DRAFT', 'SENT', 'PAID', 'OVERDUE', 'CANCELLED'] },
        indexes: ['status', 'dueDate'],
      },
      Report: {
        fields: { period: 'string', type: 'ReportType', data: 'string (JSON)', generatedAt: 'DateTime @default(now())' },
        enums: { ReportType: ['MONTHLY', 'YEARLY', 'CUSTOM'] }
      }
    },
    flows: [
      'User mencatat transaksi baru   pilih tipe (income/expense), kategori, nominal, tanggal',
      'Sistem update saldo account otomatis   validasi nominal > 0',
      'Jika expense melebihi budget kategori   sistem beri alert',
      'Akhir bulan   sistem generate ringkasan cashflow + laporan laba rugi sederhana',
      'User dapat export laporan ke CSV/PDF dengan rentang tanggal',
      'Auditor dapat merekonsiliasi transaksi   tandai isReconciled = true',
    ],
    endpoints: [
      'POST   /api/transactions                   { type, amount, categoryId, description, date, paymentMethod }',
      'GET    /api/transactions                    ?type=&dateFrom=&dateTo=&categoryId=&page=&limit=',
      'GET    /api/transactions/:id',
      'PATCH  /api/transactions/:id',
      'GET    /api/categories',
      'POST   /api/categories                     { name, type, budget? }',
      'GET    /api/reports/cashflow                ?dateFrom=&dateTo=',
      'GET    /api/reports/profit-loss             ?dateFrom=&dateTo=',
      'POST   /api/invoices                        { customerName, items[], dueDate }',
      'GET    /api/invoices                        ?status=&page=&limit=',
      'GET    /api/dashboard/summary               ?period=',
      'GET    /api/export/csv                      ?dateFrom=&dateTo=&type=',
    ],
    metrics: ['Monthly revenue', 'Monthly expense', 'Net profit margin %', 'Budget adherence %', 'Outstanding invoices'],
    genericFeatures: ['Catat Transaksi', 'Kategori & Budget', 'Laporan Cashflow', 'Manajemen Invoice', 'Export CSV'],
  },

  commerce: {
    name: 'E-Commerce / Marketplace',
    actors: ['Buyer', 'Seller', 'Admin', 'Support'],
    entities: {
      Product: {
        fields: { sellerId: 'string', name: 'string', description: 'string?', price: 'Float', comparePrice: 'Float?', stock: 'Int @default(0)', category: 'string?', images: 'string (JSON)', isActive: 'Boolean @default(true)', weight: 'Float?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        indexes: ['sellerId', 'category', 'isActive', 'createdAt'],
        relations: { belongsTo: ['Seller'], hasMany: ['OrderItem', 'Review'] }
      },
      Order: {
        fields: { orderNumber: 'string @unique', buyerId: 'string', sellerId: 'string', status: 'OrderStatus @default(PENDING)', subtotal: 'Float', shippingFee: 'Float @default(0)', discount: 'Float @default(0)', total: 'Float', shippingAddress: 'string', notes: 'string?', paidAt: 'DateTime?', shippedAt: 'DateTime?', deliveredAt: 'DateTime?', cancelledAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { OrderStatus: ['PENDING', 'CONFIRMED', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED', 'REFUNDED'] },
        indexes: ['buyerId', 'sellerId', 'status', 'createdAt'],
        relations: { belongsTo: ['Buyer', 'Seller'], hasMany: ['OrderItem', 'Payment'] }
      },
      OrderItem: {
        fields: { orderId: 'string', productId: 'string', name: 'string', quantity: 'Int', price: 'Float', subtotal: 'Float', notes: 'string?' },
        relations: { belongsTo: ['Order', 'Product'] }
      },
      Buyer: {
        fields: { name: 'string', email: 'string @unique', phone: 'string?', shippingAddress: 'string?', totalOrders: 'Int @default(0)', createdAt: 'DateTime @default(now())' },
      },
      Seller: {
        fields: { name: 'string', storeName: 'string @unique', email: 'string @unique', phone: 'string?', description: 'string?', logo: 'string?', isActive: 'Boolean @default(true)', rating: 'Float @default(5.0)', totalProducts: 'Int @default(0)', totalOrders: 'Int @default(0)', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Product', 'Order'] }
      },
      Cart: {
        fields: { buyerId: 'string @unique', items: 'string (JSON)', updatedAt: 'DateTime @updatedAt' },
        relations: { belongsTo: ['Buyer'] }
      },
      Review: {
        fields: { productId: 'string', buyerId: 'string', rating: 'Int', comment: 'string?', images: 'string (JSON)?', createdAt: 'DateTime @default(now())' },
        indexes: ['productId', 'buyerId'],
        relations: { belongsTo: ['Product', 'Buyer'] }
      },
      Shipment: {
        fields: { orderId: 'string @unique', courier: 'string', trackingNumber: 'string?', status: 'string @default("PENDING")', estimatedDelivery: 'DateTime?', shippedAt: 'DateTime?', deliveredAt: 'DateTime?' },
        relations: { belongsTo: ['Order'] }
      },
      Payment: {
        fields: { orderId: 'string @unique', method: 'string', amount: 'Float', status: 'string @default("PENDING")', externalRef: 'string?', paidAt: 'DateTime?' },
        relations: { belongsTo: ['Order'] }
      }
    },
    flows: [
      'Buyer browsing katalog   filter by kategori, search, sort by harga/terbaru',
      'Buyer add to cart   bisa ubah quantity   validasi stok',
      'Checkout   pilih alamat pengiriman   pilih metode pembayaran   submit order',
      'Sistem validasi stok   kurangi stock   buat order dengan status PENDING',
      'Seller terima notifikasi   process order   update status ke SHIPPED + input resi',
      'Buyer terima barang   konfirmasi   rating & review produk',
    ],
    endpoints: [
      'GET    /api/products                        ?category=&search=&sellerId=&sort=&page=&limit=',
      'POST   /api/cart                            { productId, quantity }',
      'GET    /api/cart',
      'POST   /api/orders                          { items[], shippingAddress, paymentMethod }',
      'GET    /api/orders                           ?status=&page=&limit=',
      'GET    /api/orders/:id',
      'PATCH  /api/orders/:id/status                { status }',
      'POST   /api/orders/:id/payment               { method, amount }',
      'POST   /api/shipments                        { orderId, courier, trackingNumber }',
      'GET    /api/sellers/:id/products',
      'POST   /api/reviews                          { productId, rating, comment }',
      'GET    /api/dashboard/seller-summary',
    ],
    metrics: ['GMV (Gross Merchandise Value)', 'Order conversion rate %', 'Average order value', 'Seller retention', 'Product return rate %'],
    genericFeatures: ['Katalog Produk', 'Cart & Checkout', 'Manajemen Order', 'Pembayaran & Pengiriman', 'Rating & Review'],
  },

  habit: {
    name: 'Habit Tracker / Self-Improvement',
    actors: ['User', 'Coach', 'Admin'],
    entities: {
      Habit: {
        fields: { userId: 'string', name: 'string', description: 'string?', frequency: 'Frequency', targetPerWeek: 'Int @default(7)', color: 'string?', icon: 'string?', isArchived: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        enums: { Frequency: ['DAILY', 'WEEKLY', 'MONTHLY'] },
        indexes: ['userId', 'isArchived'],
        relations: { belongsTo: ['User'], hasMany: ['CheckIn', 'Streak'] }
      },
      CheckIn: {
        fields: { habitId: 'string', date: 'DateTime', value: 'Float?', note: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['habitId', 'date'],
        relations: { belongsTo: ['Habit'] }
      },
      Streak: {
        fields: { habitId: 'string', currentStreak: 'Int @default(0)', longestStreak: 'Int @default(0)', lastCheckInDate: 'DateTime?', isActive: 'Boolean @default(true)' },
        relations: { belongsTo: ['Habit'] }
      },
      Goal: {
        fields: { userId: 'string', habitId: 'string?', title: 'string', target: 'string', deadline: 'DateTime?', isCompleted: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['User', 'Habit'] }
      },
      Insight: {
        fields: { userId: 'string', habitId: 'string?', type: 'InsightType', message: 'string', generatedAt: 'DateTime @default(now())' },
        enums: { InsightType: ['WEEKLY_SUMMARY', 'STREAK_MILESTONE', 'CONSISTENCY_DROP', 'ACHIEVEMENT'] },
      }
    },
    flows: [
      'User membuat habit baru   tentukan nama, frekuensi (harian/mingguan), dan target per minggu',
      'Setiap hari   user check-in dengan satu tap   sistem catat timestamp dan update streak',
      'Jika user melewatkan 1 hari (harian)   streak terputus   streak saat ini disimpan sebagai best attempt',
      'Akhir minggu   sistem generate insight: konsistensi, streak, dibanding minggu sebelumnya',
      'User lihat progress calendar   hijau (selesai), abu-abu (terlewat), angka streak',
    ],
    endpoints: [
      'POST   /api/habits                          { name, frequency, targetPerWeek, color?, icon? }',
      'GET    /api/habits                           ?isArchived=',
      'PATCH  /api/habits/:id',
      'POST   /api/checkins                         { habitId, value?, note? }',
      'GET    /api/checkins/:habitId                 ?dateFrom=&dateTo=',
      'GET    /api/streaks/:habitId',
      'GET    /api/insights                          ?period=',
      'GET    /api/dashboard/calendar                ?month=&year=',
    ],
    metrics: ['Weekly completion rate %', 'Active streaks', 'User retention (D7/D30)', 'Habits per user', 'Consistency score'],
    genericFeatures: ['Buat Habit', 'Daily Check-in', 'Streak & Progress', 'Insight Mingguan', 'Kalender Progress'],
  },

  laundry: {
    name: 'Laundry / Binatu',
    actors: ['Customer', 'Staff', 'Owner', 'Driver'],
    entities: {
      Order: { fields: { orderNumber: 'string @unique', customerId: 'string', items: 'string (JSON)', totalWeight: 'Float', totalPrice: 'Float', status: 'LaundryStatus @default(PENDING)', pickupAddress: 'string?', deliveryAddress: 'string?', pickupAt: 'DateTime?', deliveryAt: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' }, enums: { LaundryStatus: ['PENDING', 'WASHING', 'DRYING', 'IRONING', 'PACKING', 'READY', 'DELIVERED', 'COMPLETED', 'CANCELLED'] }, indexes: ['customerId', 'status'], relations: { belongsTo: ['Customer'], hasMany: ['Payment'] } },
      Customer: { fields: { name: 'string', phone: 'string @unique', address: 'string?', totalOrders: 'Int @default(0)', createdAt: 'DateTime @default(now())' } },
      LaundryItem: { fields: { orderId: 'string', name: 'string', quantity: 'Int', price: 'Float', notes: 'string?' }, relations: { belongsTo: ['Order'] } },
      Payment: { fields: { orderId: 'string @unique', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Order'] } },
    },
    flows: ['Customer datang ke toko atau order via WhatsApp   staff catat order', 'Staff menimbang dan mencatat item laundry   sistem generate total harga', 'Laundry masuk ke proses: washing → drying → ironing → packing', 'Customer dapat tracking status laundry via WhatsApp atau website', 'Selesai   customer bayar dan ambil laundry (atau diantar driver)', 'Dashboard owner: order hari ini, pendapatan, status processing'],
    endpoints: ['POST   /api/orders                          { customerId, items, totalWeight, notes }', 'GET    /api/orders                           ?status=&date=&page=&limit=', 'PATCH  /api/orders/:id/status                 { status }', 'GET    /api/orders/:id', 'POST   /api/payments                         { orderId, method, amount }', 'GET    /api/dashboard/summary'],
    metrics: ['Orders per day', 'Processing time (avg hours)', 'Revenue per day', 'Customer retention %'],
    genericFeatures: ['Manajemen Order', 'Tracking Status Laundry', 'Manajemen Customer', 'Laporan Pendapatan'],
  },

  pos: {
    name: 'POS / Kasir',
    actors: ['Cashier', 'Manager', 'Owner'],
    entities: {
      Product: { fields: { name: 'string', barcode: 'string @unique', price: 'Float', cost: 'Float', stock: 'Int @default(0)', category: 'string?', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' }, indexes: ['barcode', 'category'], relations: { belongsTo: ['Category'], hasMany: ['SaleItem'] } },
      Category: { fields: { name: 'string @unique' } },
      Sale: { fields: { receiptNumber: 'string @unique', cashierId: 'string', items: 'string (JSON)', subtotal: 'Float', discount: 'Float @default(0)', tax: 'Float @default(0)', total: 'Float', paymentMethod: 'string', amountPaid: 'Float', changeAmount: 'Float', status: 'string @default("COMPLETED")', createdAt: 'DateTime @default(now())' } },
      SaleItem: { fields: { saleId: 'string', productId: 'string', name: 'string', quantity: 'Int', price: 'Float', subtotal: 'Float' }, relations: { belongsTo: ['Sale', 'Product'] } },
      Customer: { fields: { name: 'string', phone: 'string?', totalPoints: 'Int @default(0)', createdAt: 'DateTime @default(now())' } },
    },
    flows: ['Customer belanja   cashier scan barcode produk', 'Sistem menampilkan nama produk dan harga   cashier input quantity', 'Checkout   sistem hitung total, cashier input nominal bayar', 'Sistem hitung kembalian   cetak struk (thermal printer)', 'Stok otomatis berkurang   jika stok minimal, muncul notifikasi', 'Akhir shift   cashier tutup kasir, sistem hitung total penjualan shift'],
    endpoints: ['GET    /api/products                        ?category=&search=&page=&limit=', 'POST   /api/sales                            { items[], paymentMethod, amountPaid }', 'GET    /api/sales                            ?date=&cashierId=&page=&limit=', 'GET    /api/sales/:id', 'GET    /api/dashboard/summary                 ?period=', 'POST   /api/cashier/open                      { openingBalance }', 'POST   /api/cashier/close                     { closingNote? }'],
    metrics: ['Transactions per day', 'Average transaction value', 'Cashier accuracy %', 'Stock alerts per day'],
    genericFeatures: ['Kasir & Transaksi', 'Manajemen Produk', 'Laporan Penjualan', 'Manajemen Stok'],
  },

  erp: {
    name: 'ERP / Enterprise Resource Planning',
    actors: ['Admin', 'Manager', 'Finance', 'Staff'],
    entities: {
      Department: { fields: { name: 'string @unique', code: 'string?', headId: 'string?' } },
      Employee: { fields: { name: 'string', employeeId: 'string @unique', email: 'string?', phone: 'string?', departmentId: 'string', position: 'string', salary: 'Float', hireDate: 'DateTime', isActive: 'Boolean @default(true)' }, indexes: ['departmentId', 'isActive'], relations: { belongsTo: ['Department'] } },
      Leave: { fields: { employeeId: 'string', type: 'LeaveType', startDate: 'DateTime', endDate: 'DateTime', reason: 'string?', status: 'LeaveStatus @default(PENDING)', approvedBy: 'string?', createdAt: 'DateTime @default(now())' }, enums: { LeaveType: ['ANNUAL', 'SICK', 'MATERNITY', 'UNPAID'], LeaveStatus: ['PENDING', 'APPROVED', 'REJECTED'] }, indexes: ['employeeId', 'status'], relations: { belongsTo: ['Employee'] } },
      Asset: { fields: { name: 'string', code: 'string @unique', category: 'string', purchaseDate: 'DateTime?', purchasePrice: 'Float', location: 'string?', status: 'AssetStatus @default(ACTIVE)', assignedTo: 'string?' }, enums: { AssetStatus: ['ACTIVE', 'MAINTENANCE', 'RETIRED'] } },
      Budget: { fields: { departmentId: 'string', fiscalYear: 'Int', amount: 'Float', spent: 'Float @default(0)', remaining: 'Float @default(0)' }, relations: { belongsTo: ['Department'] } },
      Task: { fields: { title: 'string', description: 'string?', assigneeId: 'string', departmentId: 'string', priority: 'TaskPriority @default(MEDIUM)', status: 'TaskStatus @default(TODO)', dueDate: 'DateTime?', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, enums: { TaskPriority: ['LOW', 'MEDIUM', 'HIGH', 'URGENT'], TaskStatus: ['TODO', 'IN_PROGRESS', 'REVIEW', 'DONE'] }, relations: { belongsTo: ['Employee', 'Department'] } },
    },
    flows: ['Admin mendaftarkan department dan employee baru', 'Employee mengajukan leave   manager approve/reject', 'Finance mengelola budget per department   tracking pengeluaran', 'Manager assign task ke employee   employee update status', 'Asset dicatat dan dilacak lokasinya   maintenance dijadwalkan', 'Dashboard executive: summary per department, budget utilization, headcount'],
    endpoints: ['GET    /api/employees                       ?departmentId=&isActive=', 'POST   /api/leaves                            { employeeId, type, startDate, endDate }', 'PATCH  /api/leaves/:id/status                  { status, approvedBy }', 'GET    /api/budgets                           ?departmentId=&fiscalYear=', 'POST   /api/tasks                             { title, assigneeId, priority, dueDate }', 'PATCH  /api/tasks/:id/status                   { status }', 'GET    /api/assets                            ?category=&status=', 'GET    /api/dashboard/executive-summary'],
    metrics: ['Employee count per department', 'Leave utilization %', 'Budget adherence %', 'Task completion rate'],
    genericFeatures: ['Manajemen Employee', 'Manajemen Leave', 'Budget & Finance', 'Task Management', 'Asset Management'],
  },

  manufacturing: {
    name: 'Manufacturing / Produksi',
    actors: ['Production Manager', 'Operator', 'QC Staff', 'Warehouse Staff'],
    entities: {
      ProductionOrder: { fields: { orderNumber: 'string @unique', productName: 'string', quantity: 'Int', producedQty: 'Int @default(0)', rejectedQty: 'Int @default(0)', status: 'ProductionStatus @default(PLANNED)', startDate: 'DateTime?', endDate: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { ProductionStatus: ['PLANNED', 'IN_PRODUCTION', 'QC', 'COMPLETED', 'REJECTED'] } },
      Product: { fields: { name: 'string', sku: 'string @unique', materials: 'string (JSON)', productionCost: 'Float', sellingPrice: 'Float', createdAt: 'DateTime @default(now())' } },
      Material: { fields: { name: 'string', sku: 'string @unique', unit: 'string', stock: 'Int @default(0)', minStock: 'Int @default(0)', createdAt: 'DateTime @default(now())' } },
      MaterialConsumption: { fields: { productionOrderId: 'string', materialId: 'string', quantityUsed: 'Int', wasteQty: 'Int @default(0)', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['ProductionOrder', 'Material'] } },
      QCResult: { fields: { productionOrderId: 'string', inspectedBy: 'string', totalInspected: 'Int', passedQty: 'Int', failedQty: 'Int', notes: 'string?', inspectedAt: 'DateTime @default(now())' }, relations: { belongsTo: ['ProductionOrder'] } },
    },
    flows: ['Production Manager membuat production order   tentukan produk, quantity, deadline', 'Operator memulai produksi   sistem mencatat start time', 'Material diambil dari gudang   sistem kurangi stok material', 'Produksi selesai   QC menginspeksi hasil: pass/reject', 'Produk jadi masuk gudang   stok produk jadi bertambah', 'Dashboard: order aktif, produksi hari ini, reject rate'],
    endpoints: ['POST   /api/production-orders                { productName, quantity, startDate }', 'PATCH  /api/production-orders/:id/status       { status }', 'POST   /api/material-consumptions              { productionOrderId, materialId, quantityUsed }', 'POST   /api/qc-results                         { productionOrderId, inspectedBy, passedQty, failedQty }', 'GET    /api/materials                          ?search=&page=&limit=', 'GET    /api/dashboard/production-summary'],
    metrics: ['Production order completion rate', 'Reject rate %', 'Material utilization %', 'On-time delivery %'],
    genericFeatures: ['Production Order', 'Material Management', 'Quality Control', 'Production Dashboard'],
  },

  healthcare: {
    name: 'Healthcare / Klinik',
    actors: ['Doctor', 'Nurse', 'Patient', 'Admin', 'Receptionist'],
    entities: {
      Patient: { fields: { name: 'string', phone: 'string @unique', email: 'string?', dateOfBirth: 'DateTime', gender: 'string', address: 'string?', bloodType: 'string?', allergies: 'string?', createdAt: 'DateTime @default(now())' } },
      Appointment: { fields: { patientId: 'string', doctorId: 'string', date: 'DateTime', startTime: 'DateTime', endTime: 'DateTime', status: 'AppointmentStatus @default(SCHEDULED)', reason: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { AppointmentStatus: ['SCHEDULED', 'CHECKED_IN', 'IN_CONSULTATION', 'COMPLETED', 'CANCELLED', 'NO_SHOW'] }, indexes: ['patientId', 'doctorId', 'date'], relations: { belongsTo: ['Patient'] } },
      MedicalRecord: { fields: { patientId: 'string', doctorId: 'string', appointmentId: 'string?', diagnosis: 'string', prescription: 'string?', notes: 'string?', followUpDate: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Patient'] } },
      Doctor: { fields: { name: 'string', specialization: 'string', phone: 'string?', schedule: 'string (JSON)?', isActive: 'Boolean @default(true)' } },
      Payment: { fields: { patientId: 'string', appointmentId: 'string?', amount: 'Float', type: 'PaymentType', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, enums: { PaymentType: ['CONSULTATION', 'MEDICATION', 'LAB', 'OTHER'] }, relations: { belongsTo: ['Patient', 'Appointment'] } },
    },
    flows: ['Pasien daftar (online/offline)   receptionist create appointment', 'Pasien check-in   sistem notifikasi dokter', 'Dokter panggil pasien   consultation   diagnosis   resep', 'Pasien bayar di kasir   sistem generate invoice', 'Medical record tersimpan   bisa diakses untuk follow-up', 'Dashboard: pasien hari ini, pendapatan, jadwal dokter'],
    endpoints: ['POST   /api/appointments                     { patientId, doctorId, date, startTime, reason }', 'GET    /api/appointments                      ?date=&doctorId=&status=', 'PATCH  /api/appointments/:id/status            { status }', 'POST   /api/medical-records                   { patientId, doctorId, diagnosis, prescription }', 'GET    /api/patients/:id/history', 'POST   /api/payments                          { patientId, appointmentId, amount, type }', 'GET    /api/dashboard/clinic-summary'],
    metrics: ['Patients per day', 'Average consultation time', 'No-show rate %', 'Revenue per day'],
    genericFeatures: ['Manajemen Appointment', 'Medical Records', 'Antrian Pasien', 'Pembayaran Klinik'],
  },

  education: {
    name: 'Education / Pendidikan',
    actors: ['Student', 'Teacher', 'Admin', 'Parent'],
    entities: {
      Course: { fields: { name: 'string', code: 'string @unique', description: 'string?', price: 'Float', maxStudents: 'Int', duration: 'string', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' } },
      Lesson: { fields: { courseId: 'string', title: 'string', content: 'string?', order: 'Int', duration: 'Int', type: 'LessonType @default(VIDEO)' }, enums: { LessonType: ['VIDEO', 'QUIZ', 'ASSIGNMENT', 'READING'] }, relations: { belongsTo: ['Course'] } },
      Enrollment: { fields: { studentId: 'string', courseId: 'string', status: 'EnrollmentStatus @default(ACTIVE)', progress: 'Int @default(0)', enrolledAt: 'DateTime @default(now())', completedAt: 'DateTime?' }, enums: { EnrollmentStatus: ['ACTIVE', 'COMPLETED', 'DROPPED'] }, indexes: ['studentId', 'courseId'], relations: { belongsTo: ['Student', 'Course'] } },
      Student: { fields: { name: 'string', email: 'string @unique', phone: 'string?', parentId: 'string?', createdAt: 'DateTime @default(now())' } },
      Teacher: { fields: { name: 'string', email: 'string @unique', specialization: 'string?', isActive: 'Boolean @default(true)' } },
      Assignment: { fields: { lessonId: 'string', studentId: 'string', submission: 'string?', score: 'Int?', submittedAt: 'DateTime?', gradedAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Lesson', 'Student'] } },
    },
    flows: ['Admin membuat course dengan lesson dan materi', 'Student mendaftar course   enrollment aktif', 'Student mengakses lesson   sistem catat progress', 'Student submit assignment/quiz   sistem nilai otomatis atau manual', 'Course selesai   certificate generated', 'Teacher lihat dashboard: student progress, nilai, completion rate'],
    endpoints: ['GET    /api/courses                          ?status=&page=&limit=', 'POST   /api/enrollments                       { studentId, courseId }', 'GET    /api/lessons/:courseId', 'POST   /api/assignments                       { lessonId, studentId, submission }', 'PATCH  /api/assignments/:id/grade              { score }', 'GET    /api/students/:id/progress', 'GET    /api/dashboard/teacher-summary'],
    metrics: ['Active students per course', 'Completion rate %', 'Average score', 'Course revenue'],
    genericFeatures: ['Manajemen Course', 'Student Enrollment', 'Progress Tracking', 'Assignment & Grading'],
  },

  property: {
    name: 'Property / Properti',
    actors: ['Owner', 'Tenant', 'Agent', 'Admin'],
    entities: {
      Property: { fields: { name: 'string', type: 'PropertyType', address: 'string', price: 'Float', status: 'PropertyStatus @default(AVAILABLE)', description: 'string?', images: 'string (JSON)?', ownerId: 'string', createdAt: 'DateTime @default(now())' }, enums: { PropertyType: ['HOUSE', 'APARTMENT', 'VILLA', 'BOARDING_HOUSE', 'COMMERCIAL'], PropertyStatus: ['AVAILABLE', 'RENTED', 'SOLD', 'MAINTENANCE'] } },
      Unit: { fields: { propertyId: 'string', name: 'string', floor: 'Int?', price: 'Float', status: 'string @default("AVAILABLE")', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Property'] } },
      Tenant: { fields: { name: 'string', phone: 'string @unique', email: 'string?', idCard: 'string?', emergencyContact: 'string?', createdAt: 'DateTime @default(now())' } },
      Lease: { fields: { unitId: 'string', tenantId: 'string', startDate: 'DateTime', endDate: 'DateTime', monthlyRent: 'Float', deposit: 'Float', status: 'LeaseStatus @default(ACTIVE)' }, enums: { LeaseStatus: ['ACTIVE', 'EXPIRED', 'TERMINATED'] }, indexes: ['unitId', 'tenantId', 'status'], relations: { belongsTo: ['Unit', 'Tenant'] } },
      Payment: { fields: { leaseId: 'string', tenantId: 'string', amount: 'Float', period: 'string', paidAt: 'DateTime?', status: 'string @default("PENDING")', method: 'string?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Lease', 'Tenant'] } },
      Maintenance: { fields: { unitId: 'string', title: 'string', description: 'string', status: 'MaintenanceStatus @default(REPORTED)', cost: 'Float?', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, enums: { MaintenanceStatus: ['REPORTED', 'IN_PROGRESS', 'COMPLETED'] }, relations: { belongsTo: ['Unit'] } },
    },
    flows: ['Owner/Agent mendaftarkan properti dan unit', 'Tenant cari properti   lihat unit tersedia', 'Tenant pilih unit   buat lease agreement', 'Tenant bayar sewa bulanan   sistem catat payment', 'Maintenance request   owner assign tukang', 'Dashboard: occupancy rate, revenue, pending maintenance'],
    endpoints: ['GET    /api/properties                       ?type=&status=&priceMin=&priceMax=', 'POST   /api/leases                            { unitId, tenantId, startDate, endDate, monthlyRent }', 'GET    /api/leases                            ?status=&page=&limit=', 'POST   /api/payments                          { leaseId, tenantId, amount, period }', 'POST   /api/maintenance                       { unitId, title, description }', 'PATCH  /api/maintenance/:id/status             { status }', 'GET    /api/dashboard/property-summary'],
    metrics: ['Occupancy rate %', 'Revenue per property', 'Payment on-time %', 'Maintenance response time'],
    genericFeatures: ['Manajemen Properti', 'Manajemen Tenant', 'Lease Agreement', 'Payment Tracking', 'Maintenance Request'],
  },

  restaurant: {
    name: 'Restaurant / Restoran',
    actors: ['Customer', 'Chef', 'Waiter', 'Manager'],
    entities: {
      MenuItem: { fields: { name: 'string', description: 'string?', price: 'Float', category: 'string', image: 'string?', isAvailable: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' }, indexes: ['category'] },
      Order: { fields: { orderNumber: 'string @unique', customerId: 'string', waiterId: 'string', tableNumber: 'Int', status: 'OrderStatus @default(PENDING)', subtotal: 'Float', tax: 'Float', total: 'Float', notes: 'string?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' }, enums: { OrderStatus: ['PENDING', 'CONFIRMED', 'COOKING', 'SERVED', 'COMPLETED', 'CANCELLED'] }, indexes: ['status', 'customerId'], relations: { belongsTo: ['Customer'], hasMany: ['OrderItem', 'Payment'] } },
      Reservation: { fields: { customerId: 'string', date: 'DateTime', time: 'string', guestCount: 'Int', tableNumber: 'Int?', status: 'ReservationStatus @default(PENDING)', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { ReservationStatus: ['PENDING', 'CONFIRMED', 'SEATED', 'CANCELLED', 'NO_SHOW'] }, relations: { belongsTo: ['Customer'] } },
      KitchenTicket: { fields: { orderId: 'string @unique', items: 'string (JSON)', status: 'TicketStatus @default(PENDING)', startedAt: 'DateTime?', completedAt: 'DateTime?', notes: 'string?' }, enums: { TicketStatus: ['PENDING', 'COOKING', 'READY', 'SERVED'] }, relations: { belongsTo: ['Order'] } },
      Payment: { fields: { orderId: 'string @unique', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Order'] } },
      Customer: { fields: { name: 'string', phone: 'string?', email: 'string?', totalVisits: 'Int @default(0)', createdAt: 'DateTime @default(now())' } },
    },
    flows: ['Customer places order   Waiter takes order   Chef receives KitchenTicket and cooks', 'Waiter serves food to table', 'Customer requests bill   Waiter processes payment', 'Manager reviews daily sales and reservations', 'Dashboard: orders, revenue, top menu items, table occupancy'],
    endpoints: ['POST   /api/menu-items                       { name, price, category, description?, image? }', 'GET    /api/menu-items                       ?category=&isAvailable=&search=', 'POST   /api/orders                           { customerId, items[], tableNumber, notes? }', 'GET    /api/orders                           ?status=&date=&page=&limit=', 'PATCH  /api/orders/:id/status                 { status }', 'POST   /api/reservations                     { customerId, date, time, guestCount }', 'POST   /api/payments                         { orderId, method, amount }', 'GET    /api/dashboard/restaurant-summary'],
    metrics: ['Orders per day', 'Average ticket size', 'Table turnover rate', 'Revenue per day'],
    genericFeatures: ['Menu Management', 'Order Management', 'Reservation System', 'Kitchen Display', 'Payment Processing'],
  },

  cafe: {
    name: 'Cafe / Coffee Shop',
    actors: ['Customer', 'Barista', 'Cashier'],
    entities: {
      MenuItem: { fields: { name: 'string', description: 'string?', price: 'Float', category: 'string', isAvailable: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' }, indexes: ['category'] },
      Order: { fields: { orderNumber: 'string @unique', customerId: 'string', cashierId: 'string', items: 'string (JSON)', status: 'OrderStatus @default(PENDING)', subtotal: 'Float', total: 'Float', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { OrderStatus: ['PENDING', 'PREPARING', 'READY', 'COMPLETED', 'CANCELLED'] }, indexes: ['status', 'createdAt'] },
      Customer: { fields: { name: 'string', phone: 'string?', email: 'string?', totalPoints: 'Int @default(0)', createdAt: 'DateTime @default(now())' } },
      LoyaltyCard: { fields: { customerId: 'string @unique', points: 'Int @default(0)', tier: 'string @default("REGULAR")', totalVisits: 'Int @default(0)', lastVisit: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Customer'] } },
      Payment: { fields: { orderId: 'string @unique', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Order'] } },
    },
    flows: ['Customer arrives and orders at counter', 'Cashier takes order   system prints order to barista', 'Barista prepares drinks and food', 'Barista marks order as ready   customer picks up', 'Customer pays at cashier   loyalty points earned', 'Dashboard: daily sales, popular items, customer visits'],
    endpoints: ['POST   /api/menu-items                       { name, price, category, description? }', 'GET    /api/menu-items                       ?category=&isAvailable=', 'POST   /api/orders                           { customerId?, items[], notes? }', 'GET    /api/orders                           ?status=&date=&page=&limit=', 'PATCH  /api/orders/:id/status                 { status }', 'POST   /api/payments                         { orderId, method, amount }', 'GET    /api/loyalty/:customerId', 'GET    /api/dashboard/cafe-summary'],
    metrics: ['Items sold per day', 'Average order value', 'Customer retention rate', 'Peak hours analysis'],
    genericFeatures: ['Menu & Order Management', 'Barista Display', 'Loyalty Program', 'Sales Dashboard'],
  },

  bakery: {
    name: 'Bakery / Toko Roti',
    actors: ['Customer', 'Baker', 'Cashier'],
    entities: {
      Product: { fields: { name: 'string', description: 'string?', price: 'Float', category: 'string', stock: 'Int @default(0)', minStock: 'Int @default(5)', isAvailable: 'Boolean @default(true)', image: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['category', 'isAvailable'] },
      Order: { fields: { orderNumber: 'string @unique', customerId: 'string', items: 'string (JSON)', status: 'OrderStatus @default(PENDING)', total: 'Float', notes: 'string?', pickupDate: 'DateTime?', createdAt: 'DateTime @default(now())' }, enums: { OrderStatus: ['PENDING', 'BAKING', 'READY', 'PICKED_UP', 'CANCELLED'] }, indexes: ['status', 'pickupDate'] },
      ProductionBatch: { fields: { productId: 'string', bakerId: 'string', quantity: 'Int', producedQty: 'Int @default(0)', status: 'BatchStatus @default(PLANNED)', startTime: 'DateTime?', endTime: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { BatchStatus: ['PLANNED', 'IN_PROGRESS', 'COMPLETED', 'REJECTED'] }, indexes: ['status'] },
      Payment: { fields: { orderId: 'string @unique', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Order'] } },
    },
    flows: ['Baker plans production based on daily demand forecast', 'Baker produces goods in batches   system records production', 'Fresh products displayed on shelves with updated stock', 'Customer buys products   Cashier processes sale', 'System auto-generates restock alerts for low stock items', 'End of day   production vs sales report'],
    endpoints: ['POST   /api/products                          { name, price, category, stock, description? }', 'GET    /api/products                          ?category=&isAvailable=&search=', 'POST   /api/production-batches                 { productId, quantity, notes? }', 'PATCH  /api/production-batches/:id/status       { status }', 'POST   /api/orders                            { customerId?, items[], pickupDate? }', 'GET    /api/orders                            ?status=&date=&page=&limit=', 'POST   /api/payments                          { orderId, method, amount }', 'GET    /api/dashboard/bakery-summary'],
    metrics: ['Products sold per day', 'Production waste %', 'Stock turnover rate', 'Revenue per day'],
    genericFeatures: ['Produk & Stock Management', 'Production Planning', 'Order Management', 'Sales & Payment'],
  },

  catering: {
    name: 'Catering / Prasmanan',
    actors: ['Customer', 'Chef', 'Driver', 'Admin'],
    entities: {
      Package: { fields: { name: 'string', description: 'string?', price: 'Float', minPax: 'Int @default(10)', maxPax: 'Int @default(100)', category: 'string', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' }, indexes: ['category', 'isActive'] },
      Menu: { fields: { packageId: 'string', name: 'string', description: 'string?', isMain: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Package'] } },
      Order: { fields: { orderNumber: 'string @unique', customerId: 'string', packageId: 'string', eventDate: 'DateTime', eventType: 'string', paxCount: 'Int', location: 'string', status: 'CateringStatus @default(PENDING)', subtotal: 'Float', deliveryFee: 'Float', total: 'Float', notes: 'string?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' }, enums: { CateringStatus: ['PENDING', 'CONFIRMED', 'PREPARING', 'DELIVERING', 'COMPLETED', 'CANCELLED'] }, indexes: ['status', 'eventDate'], relations: { belongsTo: ['Customer', 'Package'] } },
      Delivery: { fields: { orderId: 'string @unique', driverId: 'string', departureTime: 'DateTime?', arrivalTime: 'DateTime?', status: 'DeliveryStatus @default(PENDING)', notes: 'string?' }, enums: { DeliveryStatus: ['PENDING', 'LOADING', 'ON_ROUTE', 'DELIVERED'] }, relations: { belongsTo: ['Order'] } },
      Payment: { fields: { orderId: 'string @unique', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Order'] } },
    },
    flows: ['Customer requests quote   Admin recommends package based on pax and event type', 'Customer selects package   Admin sends proposal and confirms order', 'Chef prepares menu items based on order specifications', 'Driver delivers to event location on schedule', 'Customer confirms receipt   Payment processed', 'Dashboard: upcoming events, revenue, menu popularity'],
    endpoints: ['GET    /api/packages                          ?category=&minPax=&maxPax=', 'POST   /api/orders                            { customerId, packageId, eventDate, paxCount, location }', 'GET    /api/orders                            ?status=&eventDate=&page=&limit=', 'PATCH  /api/orders/:id/status                  { status }', 'POST   /api/deliveries                         { orderId, driverId }', 'PATCH  /api/deliveries/:id/status              { status }', 'POST   /api/payments                          { orderId, method, amount }', 'GET    /api/dashboard/catering-summary'],
    metrics: ['Orders per month', 'Average order value', 'On-time delivery %', 'Menu popularity score'],
    genericFeatures: ['Package Management', 'Order & Event Management', 'Menu Planning', 'Delivery Tracking', 'Payment Processing'],
  },

  hotel: {
    name: 'Hotel / Penginapan',
    actors: ['Guest', 'Receptionist', 'Housekeeping', 'Manager'],
    entities: {
      Room: { fields: { roomNumber: 'string @unique', type: 'RoomType', floor: 'Int', price: 'Float', capacity: 'Int', status: 'RoomStatus @default(AVAILABLE)', amenities: 'string (JSON)?', description: 'string?', createdAt: 'DateTime @default(now())' }, enums: { RoomType: ['STANDARD', 'DELUXE', 'SUITE', 'FAMILY', 'VIP'], RoomStatus: ['AVAILABLE', 'OCCUPIED', 'MAINTENANCE', 'RESERVED'] }, indexes: ['status', 'type'] },
      Reservation: { fields: { guestId: 'string', roomId: 'string', checkIn: 'DateTime', checkOut: 'DateTime', status: 'ReservationStatus @default(CONFIRMED)', totalPrice: 'Float', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { ReservationStatus: ['PENDING', 'CONFIRMED', 'CHECKED_IN', 'CHECKED_OUT', 'CANCELLED', 'NO_SHOW'] }, indexes: ['guestId', 'roomId', 'status'], relations: { belongsTo: ['Guest', 'Room'] } },
      Guest: { fields: { name: 'string', email: 'string?', phone: 'string @unique', idCard: 'string?', address: 'string?', nationality: 'string?', totalStays: 'Int @default(0)', createdAt: 'DateTime @default(now())' } },
      Payment: { fields: { reservationId: 'string', guestId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Reservation', 'Guest'] } },
      HousekeepingTask: { fields: { roomId: 'string', assignedTo: 'string', taskType: 'TaskType', status: 'TaskStatus @default(PENDING)', scheduledAt: 'DateTime?', completedAt: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { TaskType: ['CLEANING', 'LINEN_CHANGE', 'MAINTENANCE', 'TURN_DOWN_SERVICE'], TaskStatus: ['PENDING', 'IN_PROGRESS', 'COMPLETED', 'SKIPPED'] }, indexes: ['roomId', 'status'], relations: { belongsTo: ['Room'] } },
    },
    flows: ['Guest makes reservation   Receptionist confirms booking and assigns room', 'Guest checks in   Receptionist verifies ID and collects payment', 'Guest stays   Housekeeping cleans room daily', 'Guest checks out   Receptionist processes final payment', 'Housekeeping inspects room and updates status to available', 'Manager reviews occupancy, revenue, and housekeeping efficiency'],
    endpoints: ['GET    /api/rooms                            ?type=&status=&capacity=&priceMin=&priceMax=', 'POST   /api/reservations                      { guestId, roomId, checkIn, checkOut }', 'GET    /api/reservations                      ?status=&date=&page=&limit=', 'PATCH  /api/reservations/:id/status            { status }', 'POST   /api/check-in                          { reservationId }', 'POST   /api/check-out                         { reservationId }', 'POST   /api/housekeeping-tasks                 { roomId, taskType, assignedTo }', 'GET    /api/dashboard/hotel-summary'],
    metrics: ['Occupancy rate %', 'Average daily rate (ADR)', 'Revenue per available room (RevPAR)', 'Guest satisfaction score'],
    genericFeatures: ['Room Management', 'Reservation System', 'Check-in/Check-out', 'Housekeeping Management', 'Payment & Billing'],
  },

  salon: {
    name: 'Salon / Kecantikan',
    actors: ['Customer', 'Stylist', 'Manager'],
    entities: {
      Service: { fields: { name: 'string', description: 'string?', price: 'Float', duration: 'Int', category: 'string', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' }, indexes: ['category', 'isActive'] },
      Appointment: { fields: { customerId: 'string', stylistId: 'string', services: 'string (JSON)', date: 'DateTime', startTime: 'DateTime', endTime: 'DateTime?', status: 'AppointmentStatus @default(SCHEDULED)', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { AppointmentStatus: ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW'] }, indexes: ['stylistId', 'date', 'status'], relations: { belongsTo: ['Customer', 'Stylist'] } },
      Customer: { fields: { name: 'string', phone: 'string @unique', email: 'string?', birthDate: 'DateTime?', totalVisits: 'Int @default(0)', totalSpent: 'Float @default(0)', notes: 'string?', createdAt: 'DateTime @default(now())' } },
      Stylist: { fields: { name: 'string', phone: 'string @unique', specialization: 'string', commissionRate: 'Float @default(0.3)', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' } },
      Payment: { fields: { appointmentId: 'string @unique', customerId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Appointment', 'Customer'] } },
    },
    flows: ['Customer books appointment   selects service and stylist', 'Customer arrives   Receptionist confirms appointment', 'Stylist performs service   system tracks time and materials', 'Customer pays at counter', 'Customer leaves review   system records for loyalty program', 'Manager reviews daily performance and stylist productivity'],
    endpoints: ['GET    /api/services                          ?category=&isActive=', 'POST   /api/appointments                      { customerId, stylistId, services[], date, startTime }', 'GET    /api/appointments                      ?stylistId=&date=&status=', 'PATCH  /api/appointments/:id/status            { status }', 'POST   /api/payments                          { appointmentId, method, amount }', 'GET    /api/customers/:id/history', 'GET    /api/dashboard/salon-summary'],
    metrics: ['Appointments per day', 'Stylist utilization %', 'Revenue per stylist', 'Customer retention rate'],
    genericFeatures: ['Service Management', 'Appointment Booking', 'Stylist Scheduling', 'Customer Management', 'Payment & Reports'],
  },

  barbershop: {
    name: 'Barbershop / Pangkas Rambut',
    actors: ['Customer', 'Barber', 'Owner'],
    entities: {
      Service: { fields: { name: 'string', price: 'Float', duration: 'Int', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' } },
      Appointment: { fields: { customerId: 'string?', barberId: 'string', serviceId: 'string', date: 'DateTime', startTime: 'DateTime', status: 'AppointmentStatus @default(SCHEDULED)', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { AppointmentStatus: ['SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] }, indexes: ['barberId', 'date'], relations: { belongsTo: ['Barber', 'Service'] } },
      Customer: { fields: { name: 'string', phone: 'string?', totalVisits: 'Int @default(0)', lastVisit: 'DateTime?', createdAt: 'DateTime @default(now())' } },
      Barber: { fields: { name: 'string', phone: 'string @unique', skills: 'string (JSON)?', commissionRate: 'Float @default(0.5)', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' } },
      Payment: { fields: { appointmentId: 'string @unique', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Appointment'] } },
    },
    flows: ['Customer walks in or books appointment online', 'Customer waits in queue   Barber calls next customer', 'Barber performs service (haircut, shave, etc.)', 'Customer pays at counter   cash or digital', 'Owner reviews daily earnings, barber performance, and walk-in vs booking ratio'],
    endpoints: ['GET    /api/services                          ?isActive=', 'POST   /api/appointments                      { customerId?, barberId, serviceId, date, startTime }', 'GET    /api/appointments                      ?barberId=&date=&status=', 'PATCH  /api/appointments/:id/status            { status }', 'POST   /api/walk-in                           { barberId, serviceId }', 'POST   /api/payments                          { appointmentId, method, amount }', 'GET    /api/dashboard/barbershop-summary'],
    metrics: ['Customers per day per barber', 'Average service time', 'Walk-in vs booking ratio', 'Revenue per barber'],
    genericFeatures: ['Service Catalog', 'Appointment & Queue', 'Barber Management', 'Payment & Commission'],
  },

  workshop: {
    name: 'Workshop / Bengkel Service',
    actors: ['Customer', 'Technician', 'Manager'],
    entities: {
      Service: { fields: { name: 'string', description: 'string?', price: 'Float', estimatedDuration: 'Int', category: 'string', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' }, indexes: ['category'] },
      WorkOrder: { fields: { orderNumber: 'string @unique', customerId: 'string', vehicleInfo: 'string', complaint: 'string', diagnosis: 'string?', status: 'WorkStatus @default(PENDING)', estimatedCost: 'Float?', totalCost: 'Float?', startTime: 'DateTime?', endTime: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { WorkStatus: ['PENDING', 'DIAGNOSING', 'ESTIMATED', 'APPROVED', 'IN_PROGRESS', 'COMPLETED', 'PICKED_UP', 'CANCELLED'] }, indexes: ['customerId', 'status'], relations: { belongsTo: ['Customer'] } },
      Customer: { fields: { name: 'string', phone: 'string @unique', email: 'string?', address: 'string?', totalOrders: 'Int @default(0)', createdAt: 'DateTime @default(now())' } },
      Vehicle: { fields: { customerId: 'string', plateNumber: 'string @unique', brand: 'string', model: 'string', year: 'Int?', vin: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['customerId'], relations: { belongsTo: ['Customer'] } },
      Payment: { fields: { workOrderId: 'string @unique', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['WorkOrder'] } },
    },
    flows: ['Customer datang   technician terima dan catat keluhan', 'Technician lakukan diagnosa   sistem buat estimasi biaya dan waktu', 'Customer setuju estimasi   work order approved', 'Technician kerjakan service   update status tiap tahap', 'Service selesai   customer bayar dan ambil kendaraan', 'Manager review: work order aktif, revenue, technician performance'],
    endpoints: ['GET    /api/services                          ?category=&isActive=', 'POST   /api/work-orders                        { customerId, vehicleInfo, complaint }', 'GET    /api/work-orders                        ?status=&date=&page=&limit=', 'PATCH  /api/work-orders/:id/status              { status }', 'PATCH  /api/work-orders/:id/estimate            { diagnosis, estimatedCost }', 'POST   /api/payments                           { workOrderId, method, amount }', 'GET    /api/customers/:id/vehicles', 'GET    /api/dashboard/workshop-summary'],
    metrics: ['Work orders per day', 'Average repair time', 'Estimate accuracy %', 'Revenue per technician'],
    genericFeatures: ['Work Order Management', 'Diagnosis & Estimate', 'Vehicle History', 'Technician Assignment', 'Payment & Reports'],
  },

  cleaning_service: {
    name: 'Cleaning Service / Jasa Kebersihan',
    actors: ['Customer', 'Cleaner', 'Admin'],
    entities: {
      Service: { fields: { name: 'string', description: 'string?', price: 'Float', duration: 'Int', unit: 'string @default("hour")', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' } },
      Order: { fields: { orderNumber: 'string @unique', customerId: 'string', serviceId: 'string', address: 'string', scheduledAt: 'DateTime', duration: 'Int', status: 'CleaningStatus @default(PENDING)', totalPrice: 'Float', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { CleaningStatus: ['PENDING', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] }, indexes: ['customerId', 'status', 'scheduledAt'], relations: { belongsTo: ['Customer', 'Service'] } },
      Customer: { fields: { name: 'string', phone: 'string @unique', email: 'string?', address: 'string?', totalOrders: 'Int @default(0)', createdAt: 'DateTime @default(now())' } },
      Cleaner: { fields: { name: 'string', phone: 'string @unique', rating: 'Float @default(5.0)', isAvailable: 'Boolean @default(true)', totalJobs: 'Int @default(0)', createdAt: 'DateTime @default(now())' } },
      Payment: { fields: { orderId: 'string @unique', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Order'] } },
    },
    flows: ['Customer orders cleaning service   selects service type and schedule', 'Admin assigns cleaner based on availability and location', 'Cleaner arrives at location   starts job with status update', 'Cleaner completes service   customer verifies quality', 'Customer pays   leaves rating and review', 'Admin reviews completed jobs and cleaner performance'],
    endpoints: ['GET    /api/services                          ?isActive=', 'POST   /api/orders                            { customerId, serviceId, address, scheduledAt }', 'GET    /api/orders                            ?status=&date=&page=&limit=', 'PATCH  /api/orders/:id/assign                  { cleanerId }', 'PATCH  /api/orders/:id/status                  { status }', 'POST   /api/payments                          { orderId, method, amount }', 'GET    /api/dashboard/cleaning-summary'],
    metrics: ['Orders per day', 'Cleaner utilization %', 'On-time arrival %', 'Customer rating average'],
    genericFeatures: ['Service Packages', 'Order Management', 'Cleaner Assignment', 'Customer Reviews', 'Payment Processing'],
  },

  field_service: {
    name: 'Field Service / Service Lapangan',
    actors: ['Customer', 'Technician', 'Dispatcher'],
    entities: {
      WorkOrder: { fields: { orderNumber: 'string @unique', customerId: 'string', title: 'string', description: 'string', address: 'string', latitude: 'Float?', longitude: 'Float?', status: 'FieldStatus @default(PENDING)', priority: 'Priority @default(MEDIUM)', scheduledAt: 'DateTime?', completedAt: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { FieldStatus: ['PENDING', 'DISPATCHED', 'EN_ROUTE', 'ON_SITE', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'], Priority: ['LOW', 'MEDIUM', 'HIGH', 'URGENT'] }, indexes: ['status', 'technicianId', 'priority'], relations: { belongsTo: ['Customer', 'Technician'] } },
      Customer: { fields: { name: 'string', phone: 'string @unique', email: 'string?', address: 'string', latitude: 'Float?', longitude: 'Float?', totalOrders: 'Int @default(0)', createdAt: 'DateTime @default(now())' } },
      Technician: { fields: { name: 'string', phone: 'string @unique', email: 'string?', skills: 'string (JSON)?', isAvailable: 'Boolean @default(true)', currentLat: 'Float?', currentLng: 'Float?', totalJobs: 'Int @default(0)', rating: 'Float @default(5.0)', createdAt: 'DateTime @default(now())' } },
      Schedule: { fields: { technicianId: 'string', date: 'DateTime', startTime: 'DateTime', endTime: 'DateTime?', isAvailable: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' }, indexes: ['technicianId', 'date'], relations: { belongsTo: ['Technician'] } },
      Payment: { fields: { workOrderId: 'string @unique', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['WorkOrder'] } },
    },
    flows: ['Customer submits service request with description and location', 'Dispatcher reviews and assigns technician based on skills and proximity', 'Technician receives notification   departs to customer location', 'Technician arrives on site   starts service', 'Technician completes service   customer signs off', 'Payment processed   customer rates service quality'],
    endpoints: ['POST   /api/work-orders                       { customerId, title, description, address }', 'GET    /api/work-orders                       ?status=&technicianId=&priority=&page=&limit=', 'PATCH  /api/work-orders/:id/assign             { technicianId }', 'PATCH  /api/work-orders/:id/status             { status, notes? }', 'POST   /api/schedules                         { technicianId, date, startTime, endTime }', 'GET    /api/technicians                       ?isAvailable=&skills=', 'POST   /api/payments                          { workOrderId, method, amount }', 'GET    /api/dashboard/field-service-summary'],
    metrics: ['Jobs completed per day', 'Average response time', 'First-time fix rate %', 'Technician utilization %'],
    genericFeatures: ['Work Order Management', 'Dispatch & Assignment', 'GPS Tracking', 'Schedule Management', 'Customer Portal'],
  },

  accounting: {
    name: 'Accounting / Akuntansi',
    actors: ['Accountant', 'Manager', 'Auditor'],
    entities: {
      Account: { fields: { code: 'string @unique', name: 'string', type: 'AccountType', normalBalance: 'string @default("DEBIT")', description: 'string?', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' }, enums: { AccountType: ['ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE'] }, indexes: ['type', 'isActive'] },
      JournalEntry: { fields: { entryNumber: 'string @unique', description: 'string', date: 'DateTime', status: 'string @default("POSTED")', postedAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, indexes: ['date', 'status'] },
      Ledger: { fields: { accountId: 'string', entryId: 'string', debit: 'Float @default(0)', credit: 'Float @default(0)', balance: 'Float', description: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['accountId', 'createdAt'], relations: { belongsTo: ['Account', 'JournalEntry'] } },
      Report: { fields: { name: 'string', type: 'ReportType', periodStart: 'DateTime', periodEnd: 'DateTime', data: 'string (JSON)', generatedAt: 'DateTime @default(now())' }, enums: { ReportType: ['BALANCE_SHEET', 'INCOME_STATEMENT', 'TRIAL_BALANCE', 'CASH_FLOW', 'LEDGER'] }, indexes: ['type', 'periodStart'] },
    },
    flows: ['Accountant records financial transactions as journal entries', 'System posts journal entries to respective ledger accounts', 'System runs trial balance to verify debits equal credits', 'Accountant generates financial statements (income, balance sheet)', 'Manager reviews reports   Auditor verifies accuracy', 'Month-end closing   system locks period and archives reports'],
    endpoints: ['GET    /api/accounts                          ?type=&isActive=', 'POST   /api/journal-entries                   { description, date, lines[{ accountId, debit, credit }] }', 'GET    /api/journal-entries                   ?dateFrom=&dateTo=&status=&page=&limit=', 'GET    /api/ledgers/:accountId                 ?dateFrom=&dateTo=', 'POST   /api/reports/generate                   { type, periodStart, periodEnd }', 'GET    /api/reports                           ?type=&page=&limit=', 'GET    /api/dashboard/accounting-summary'],
    metrics: ['Journal entries per month', 'Trial balance accuracy %', 'Report generation time', 'Period-end close time (days)'],
    genericFeatures: ['Chart of Accounts', 'Journal Entry', 'Ledger Management', 'Financial Reports', 'Period Closing'],
  },

  invoicing: {
    name: 'Invoicing / Faktur',
    actors: ['Finance', 'Customer', 'Admin'],
    entities: {
      Invoice: { fields: { invoiceNumber: 'string @unique', customerId: 'string', issueDate: 'DateTime', dueDate: 'DateTime', subtotal: 'Float', tax: 'Float @default(0)', discount: 'Float @default(0)', total: 'Float', status: 'InvoiceStatus @default(DRAFT)', notes: 'string?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' }, enums: { InvoiceStatus: ['DRAFT', 'SENT', 'OVERDUE', 'PAID', 'CANCELLED', 'WRITTEN_OFF'] }, indexes: ['customerId', 'status', 'dueDate'], relations: { belongsTo: ['Customer'] } },
      InvoiceItem: { fields: { invoiceId: 'string', description: 'string', quantity: 'Int', unitPrice: 'Float', total: 'Float', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Invoice'] } },
      Payment: { fields: { invoiceId: 'string', amount: 'Float', method: 'string', reference: 'string?', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, indexes: ['invoiceId'], relations: { belongsTo: ['Invoice'] } },
      Customer: { fields: { name: 'string', company: 'string?', email: 'string', phone: 'string?', address: 'string?', paymentTerms: 'Int @default(30)', createdAt: 'DateTime @default(now())' } },
    },
    flows: ['Finance creates invoice for customer   system generates invoice number', 'Invoice is sent to customer via email', 'System sends automated reminders as due date approaches', 'Customer makes payment   system records and reconciles', 'Finance marks invoice as paid   updates accounting', 'Admin generates aging report for overdue invoices'],
    endpoints: ['POST   /api/invoices                          { customerId, items[], issueDate, dueDate }', 'GET    /api/invoices                          ?status=&customerId=&dateFrom=&dateTo=&page=&limit=', 'PATCH  /api/invoices/:id/status                { status }', 'POST   /api/invoices/:id/send', 'POST   /api/invoices/:id/remind', 'POST   /api/payments                          { invoiceId, method, amount, reference? }', 'GET    /api/reports/aging                       ?asOf=', 'GET    /api/dashboard/invoice-summary'],
    metrics: ['Invoices generated per month', 'On-time payment rate %', 'Average days to pay', 'Outstanding receivables'],
    genericFeatures: ['Invoice Creation', 'Customer Management', 'Payment Tracking', 'Automated Reminders', 'Aging Reports'],
  },

  expense: {
    name: 'Expense / Pengeluaran',
    actors: ['Employee', 'Manager', 'Finance'],
    entities: {
      Expense: { fields: { employeeId: 'string', categoryId: 'string', amount: 'Float', description: 'string', date: 'DateTime', status: 'ExpenseStatus @default(PENDING)', receiptImage: 'string?', notes: 'string?', approvedById: 'string?', approvedAt: 'DateTime?', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, enums: { ExpenseStatus: ['DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'REIMBURSED'] }, indexes: ['employeeId', 'categoryId', 'status'], relations: { belongsTo: ['Employee', 'Category'] } },
      Category: { fields: { name: 'string @unique', description: 'string?', budgetLimit: 'Float?', isActive: 'Boolean @default(true)' } },
      Receipt: { fields: { expenseId: 'string @unique', imageUrl: 'string', ocrText: 'string?', vendorName: 'string?', amount: 'Float?', date: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Expense'] } },
      Approval: { fields: { expenseId: 'string', approverId: 'string', status: 'string @default("PENDING")', comment: 'string?', decidedAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, indexes: ['expenseId', 'approverId'], relations: { belongsTo: ['Expense'] } },
    },
    flows: ['Employee submits expense report with receipt image', 'Manager reviews and approves/rejects expense', 'Approved expense goes to Finance for reimbursement', 'Finance processes payment   marks as reimbursed', 'System categorizes expense for budgeting reports', 'Month-end   Finance exports expense report by category'],
    endpoints: ['POST   /api/expenses                          { categoryId, amount, description, date, receiptImage? }', 'GET    /api/expenses                          ?status=&employeeId=&categoryId=&dateFrom=&dateTo=&page=&limit=', 'PATCH  /api/expenses/:id/status                { status, comment? }', 'POST   /api/expenses/:id/receipt               { imageUrl }', 'GET    /api/categories', 'GET    /api/reports/expense-summary              ?period=', 'GET    /api/dashboard/expense-summary'],
    metrics: ['Total expenses per month', 'Average approval time', 'Reimbursement cycle time', 'Expense per category'],
    genericFeatures: ['Expense Submission', 'Receipt OCR & Upload', 'Approval Workflow', 'Category Management', 'Reimbursement Processing'],
  },

  payroll: {
    name: 'Payroll / Penggajian',
    actors: ['Employee', 'HR', 'Finance', 'Manager'],
    entities: {
      Employee: { fields: { name: 'string', employeeId: 'string @unique', email: 'string @unique', phone: 'string?', department: 'string', position: 'string', baseSalary: 'Float', bankAccount: 'string?', taxId: 'string?', joinDate: 'DateTime', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' } },
      Salary: { fields: { employeeId: 'string', baseSalary: 'Float', allowances: 'Float @default(0)', overtimeRate: 'Float @default(1.5)', effectiveDate: 'DateTime', createdAt: 'DateTime @default(now())' }, indexes: ['employeeId'], relations: { belongsTo: ['Employee'] } },
      Payslip: { fields: { employeeId: 'string', periodStart: 'DateTime', periodEnd: 'DateTime', basicPay: 'Float', allowances: 'Float @default(0)', overtimePay: 'Float @default(0)', deductions: 'Float @default(0)', tax: 'Float @default(0)', netPay: 'Float', status: 'string @default("DRAFT")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, indexes: ['employeeId', 'status', 'periodStart'], relations: { belongsTo: ['Employee'] } },
      Deduction: { fields: { employeeId: 'string', type: 'string', amount: 'Float', description: 'string?', isRecurring: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Employee'] } },
      Tax: { fields: { employeeId: 'string', taxYear: 'Int', taxCode: 'string', taxableIncome: 'Float', taxPaid: 'Float @default(0)', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Employee'] } },
    },
    flows: ['HR tracks employee attendance and overtime for the period', 'System calculates salary based on base pay, overtime, allowances, and deductions', 'HR reviews payslips and approves payroll run', 'Finance disburses salaries via bank transfer', 'System generates tax reports and payslip PDFs for employees', 'Year-end   HR generates annual tax summary'],
    endpoints: ['GET    /api/employees                         ?department=&isActive=', 'POST   /api/payroll/run                        { periodStart, periodEnd }', 'GET    /api/payslips                          ?employeeId=&periodStart=&periodEnd=', 'PATCH  /api/payslips/:id/approve', 'POST   /api/payroll/disburse                   { payslipIds[] }', 'GET    /api/deductions/:employeeId', 'GET    /api/reports/payroll-summary              ?period=', 'GET    /api/dashboard/payroll-summary'],
    metrics: ['Payroll processing time', 'Payroll accuracy %', 'Overtime cost % of payroll', 'Employee cost per department'],
    genericFeatures: ['Employee Master Data', 'Salary Calculation', 'Payslip Generation', 'Deductions & Tax', 'Disbursement'],
  },

  budgeting: {
    name: 'Budgeting / Anggaran',
    actors: ['Manager', 'Finance', 'Department Head'],
    entities: {
      Budget: { fields: { name: 'string', fiscalYear: 'Int', departmentId: 'string', totalAmount: 'Float', status: 'BudgetStatus @default(DRAFT)', notes: 'string?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' }, enums: { BudgetStatus: ['DRAFT', 'PENDING', 'APPROVED', 'ACTIVE', 'CLOSED'] }, indexes: ['fiscalYear', 'departmentId', 'status'], relations: { belongsTo: ['Department'] } },
      BudgetItem: { fields: { budgetId: 'string', name: 'string', category: 'string', plannedAmount: 'Float', actualAmount: 'Float @default(0)', remainingAmount: 'Float @default(0)', notes: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['budgetId', 'category'], relations: { belongsTo: ['Budget'] } },
      ActualSpend: { fields: { budgetItemId: 'string', amount: 'Float', description: 'string', date: 'DateTime', referenceId: 'string?', referenceType: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['budgetItemId', 'date'], relations: { belongsTo: ['BudgetItem'] } },
      Forecast: { fields: { budgetId: 'string', month: 'Int', year: 'Int', projectedRevenue: 'Float @default(0)', projectedExpense: 'Float @default(0)', confidence: 'Int @default(50)', notes: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['budgetId'], relations: { belongsTo: ['Budget'] } },
      Department: { fields: { name: 'string @unique', code: 'string @unique', headId: 'string?', budgetAllocation: 'Float @default(0)', createdAt: 'DateTime @default(now())' } },
    },
    flows: ['Department Head proposes annual budget with line items', 'Manager and Finance review and approve budget', 'Budget becomes active   departments can spend against it', 'Actual spending tracked against budget items in real-time', 'Quarterly review   Finance adjusts forecast based on actuals', 'Year-end   Budget closed, variance analysis report generated'],
    endpoints: ['POST   /api/budgets                           { name, fiscalYear, departmentId, totalAmount }', 'GET    /api/budgets                           ?fiscalYear=&departmentId=&status=', 'POST   /api/budgets/:id/items                  { name, category, plannedAmount }', 'PATCH  /api/budgets/:id/status                 { status }', 'POST   /api/actual-spends                     { budgetItemId, amount, description, date }', 'POST   /api/forecasts                         { budgetId, month, year, projectedRevenue, projectedExpense }', 'GET    /api/reports/variance                    ?budgetId=', 'GET    /api/dashboard/budget-summary'],
    metrics: ['Budget utilization %', 'Variance (planned vs actual)', 'Forecast accuracy %', 'Departments on budget %'],
    genericFeatures: ['Budget Planning', 'Line Item Tracking', 'Actual vs Budget', 'Forecasting', 'Variance Reports'],
  },

  attendance: {
    name: 'Attendance / Absensi',
    actors: ['Employee', 'Manager', 'HR'],
    entities: {
      Attendance: { fields: { employeeId: 'string', date: 'DateTime', checkIn: 'DateTime?', checkOut: 'DateTime?', status: 'AttendanceStatus @default(PRESENT)', workHours: 'Float @default(0)', overtimeHours: 'Float @default(0)', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { AttendanceStatus: ['PRESENT', 'LATE', 'HALF_DAY', 'ABSENT', 'ON_LEAVE', 'WORK_FROM_HOME'] }, indexes: ['employeeId', 'date', 'status'], relations: { belongsTo: ['Employee'] } },
      Leave: { fields: { employeeId: 'string', type: 'string', startDate: 'DateTime', endDate: 'DateTime', reason: 'string?', status: 'LeaveStatus @default(PENDING)', approvedBy: 'string?', approvedAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, enums: { LeaveStatus: ['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'] }, indexes: ['employeeId', 'status', 'startDate'], relations: { belongsTo: ['Employee'] } },
      Shift: { fields: { name: 'string', startTime: 'string', endTime: 'string', gracePeriod: 'Int @default(15)', isNightShift: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' } },
      Overtime: { fields: { employeeId: 'string', date: 'DateTime', startTime: 'DateTime', endTime: 'DateTime', hours: 'Float', rate: 'Float @default(1.5)', status: 'OvertimeStatus @default(PENDING)', approvedBy: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { OvertimeStatus: ['PENDING', 'APPROVED', 'REJECTED'] }, indexes: ['employeeId', 'date', 'status'], relations: { belongsTo: ['Employee'] } },
    },
    flows: ['Employee checks in at start of shift   system records timestamp', 'System tracks working hours and calculates overtime', 'Employee submits leave request   Manager approves/rejects', 'Employee checks out   system calculates total hours', 'HR reviews monthly attendance report', 'Payroll system uses attendance data for salary calculation'],
    endpoints: ['POST   /api/attendance/check-in               { employeeId }', 'POST   /api/attendance/check-out              { employeeId }', 'GET    /api/attendance                        ?employeeId=&dateFrom=&dateTo=&status=', 'POST   /api/leaves                            { employeeId, type, startDate, endDate, reason }', 'PATCH  /api/leaves/:id/status                  { status, approvedBy }', 'POST   /api/overtime                          { employeeId, date, startTime, endTime }', 'GET    /api/reports/attendance                  ?period=&departmentId=', 'GET    /api/dashboard/attendance-summary'],
    metrics: ['Attendance rate %', 'Average late minutes', 'Leave utilization %', 'Overtime hours per employee'],
    genericFeatures: ['Check-in/Check-out', 'Leave Management', 'Shift Scheduling', 'Overtime Tracking', 'Attendance Reports'],
  },

  recruitment: {
    name: 'Recruitment / Rekrutmen',
    actors: ['Candidate', 'HR', 'Manager', 'Interviewer'],
    entities: {
      JobPosting: { fields: { title: 'string', department: 'string', location: 'string', type: 'string', description: 'string', requirements: 'string (JSON)?', salaryMin: 'Float?', salaryMax: 'Float?', status: 'string @default("OPEN")', postedAt: 'DateTime?', closedAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, indexes: ['status', 'department'] },
      Application: { fields: { jobPostingId: 'string', candidateId: 'string', status: 'ApplicationStatus @default(SUBMITTED)', resumeUrl: 'string?', coverLetter: 'string?', score: 'Int?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { ApplicationStatus: ['SUBMITTED', 'SCREENING', 'SHORTLISTED', 'INTERVIEWED', 'OFFERED', 'HIRED', 'REJECTED'] }, indexes: ['jobPostingId', 'candidateId', 'status'], relations: { belongsTo: ['JobPosting', 'Candidate'] } },
      Interview: { fields: { applicationId: 'string', interviewerIds: 'string (JSON)', type: 'string', scheduledAt: 'DateTime', duration: 'Int', status: 'InterviewStatus @default(SCHEDULED)', feedback: 'string?', rating: 'Int?', createdAt: 'DateTime @default(now())' }, enums: { InterviewStatus: ['SCHEDULED', 'COMPLETED', 'CANCELLED', 'RESCHEDULED'] }, indexes: ['applicationId', 'status'], relations: { belongsTo: ['Application'] } },
      Offer: { fields: { applicationId: 'string @unique', baseSalary: 'Float', benefits: 'string (JSON)?', startDate: 'DateTime', expiryDate: 'DateTime', status: 'OfferStatus @default(PENDING)', notes: 'string?', sentAt: 'DateTime?', acceptedAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, enums: { OfferStatus: ['PENDING', 'ACCEPTED', 'DECLINED', 'EXPIRED', 'WITHDRAWN'] }, relations: { belongsTo: ['Application'] } },
      Candidate: { fields: { name: 'string', email: 'string @unique', phone: 'string?', currentCompany: 'string?', currentPosition: 'string?', yearsOfExperience: 'Int @default(0)', skills: 'string (JSON)?', createdAt: 'DateTime @default(now())' } },
    },
    flows: ['HR posts job opening on multiple platforms', 'Candidates apply   system collects resumes and cover letters', 'HR screens applications   shortlists qualified candidates', 'Interviewer schedules and conducts interviews', 'HR extends offer to selected candidate', 'Candidate accepts   onboarding process begins'],
    endpoints: ['POST   /api/job-postings                      { title, department, location, description, requirements }', 'GET    /api/job-postings                      ?status=&department=&page=&limit=', 'POST   /api/applications                      { jobPostingId, candidateId, resumeUrl? }', 'GET    /api/applications                      ?jobPostingId=&status=&page=&limit=', 'POST   /api/interviews                        { applicationId, interviewerIds[], type, scheduledAt }', 'PATCH  /api/applications/:id/status            { status }', 'POST   /api/offers                            { applicationId, baseSalary, startDate }', 'GET    /api/dashboard/recruitment-summary'],
    metrics: ['Time to hire (days)', 'Applicants per opening', 'Interview-to-offer ratio', 'Offer acceptance rate %'],
    genericFeatures: ['Job Posting', 'Application Tracking', 'Interview Scheduling', 'Offer Management', 'Candidate Database'],
  },

  employee_management: {
    name: 'Employee Management / Manajemen Karyawan',
    actors: ['Employee', 'Manager', 'HR', 'Admin'],
    entities: {
      Employee: { fields: { name: 'string', employeeId: 'string @unique', email: 'string @unique', phone: 'string?', departmentId: 'string', positionId: 'string', managerId: 'string?', joinDate: 'DateTime', status: 'EmployeeStatus @default(ACTIVE)', emergencyContact: 'string?', address: 'string?', createdAt: 'DateTime @default(now())' }, enums: { EmployeeStatus: ['ACTIVE', 'PROBATION', 'RESIGNED', 'TERMINATED', 'RETIRED'] }, indexes: ['departmentId', 'positionId', 'status'], relations: { belongsTo: ['Department', 'Position'] } },
      Department: { fields: { name: 'string @unique', code: 'string @unique', description: 'string?', headId: 'string?', createdAt: 'DateTime @default(now())' } },
      Position: { fields: { title: 'string', departmentId: 'string', level: 'Int @default(1)', salaryMin: 'Float?', salaryMax: 'Float?', description: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['departmentId'], relations: { belongsTo: ['Department'] } },
      Document: { fields: { employeeId: 'string', type: 'string', name: 'string', fileUrl: 'string', status: 'string @default("SUBMITTED")', expiryDate: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['employeeId', 'type'], relations: { belongsTo: ['Employee'] } },
    },
    flows: ['HR creates employee profile with personal and employment details', 'Employee is assigned to department and position', 'Employee uploads required documents (KTP, NPWP, BPJS, etc.)', 'Manager can initiate transfer or promotion for employee', 'HR processes resignation/termination   offboarding workflow', 'Dashboard: headcount, department distribution, document completeness'],
    endpoints: ['POST   /api/employees                          { name, email, departmentId, positionId, joinDate }', 'GET    /api/employees                          ?departmentId=&status=&page=&limit=', 'PATCH  /api/employees/:id                       { positionId, departmentId, status }', 'POST   /api/documents                           { employeeId, type, name, fileUrl }', 'GET    /api/documents/:employeeId', 'GET    /api/departments', 'GET    /api/positions                           ?departmentId=', 'GET    /api/dashboard/hr-summary'],
    metrics: ['Headcount by department', 'Employee turnover rate %', 'Document completion %', 'Average tenure'],
    genericFeatures: ['Employee Database', 'Department Structure', 'Position Management', 'Document Management', 'Onboarding/Offboarding'],
  },

  performance_management: {
    name: 'Performance Management / Manajemen Kinerja',
    actors: ['Employee', 'Manager', 'HR'],
    entities: {
      Review: { fields: { employeeId: 'string', reviewerId: 'string', period: 'string', year: 'Int', status: 'ReviewStatus @default(DRAFT)', overallRating: 'Int?', summary: 'string?', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, enums: { ReviewStatus: ['DRAFT', 'SUBMITTED', 'ACKNOWLEDGED', 'COMPLETED'] }, indexes: ['employeeId', 'reviewerId', 'year'], relations: { belongsTo: ['Employee'] } },
      Goal: { fields: { employeeId: 'string', title: 'string', description: 'string?', category: 'string', keyResult: 'string?', weight: 'Int @default(100)', progress: 'Int @default(0)', deadline: 'DateTime?', status: 'GoalStatus @default(ACTIVE)', createdAt: 'DateTime @default(now())' }, enums: { GoalStatus: ['ACTIVE', 'ACHIEVED', 'ON_TRACK', 'AT_RISK', 'BEHIND'] }, indexes: ['employeeId', 'status'], relations: { belongsTo: ['Employee'] } },
      Feedback: { fields: { fromId: 'string', toId: 'string', reviewId: 'string?', type: 'FeedbackType', message: 'string', isAnonymous: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' }, enums: { FeedbackType: ['PEER', 'MANAGER', 'SUBORDINATE', 'SELF', '360'] }, indexes: ['toId', 'reviewId'], relations: { belongsTo: ['Review'] } },
      Rating: { fields: { reviewId: 'string', category: 'string', score: 'Int', comment: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['reviewId'], relations: { belongsTo: ['Review'] } },
    },
    flows: ['Manager and employee set quarterly goals together', 'Employee works on goals   updates progress regularly', 'Mid-year check-in   Manager provides informal feedback', 'End of year   Manager completes performance review', 'Employee acknowledges review   discusses development plan', 'HR aggregates results for promotion and compensation decisions'],
    endpoints: ['POST   /api/goals                             { employeeId, title, category, weight, deadline }', 'GET    /api/goals                             ?employeeId=&status=', 'PATCH  /api/goals/:id/progress                 { progress }', 'POST   /api/reviews                           { employeeId, reviewerId, period, year }', 'PATCH  /api/reviews/:id/submit                 { overallRating, summary }', 'POST   /api/feedbacks                         { fromId, toId, type, message, isAnonymous? }', 'GET    /api/reports/performance                 ?employeeId=&year=', 'GET    /api/dashboard/performance-summary'],
    metrics: ['Goal completion rate %', 'Average review score', 'Feedback submissions per cycle', 'Goal progress distribution'],
    genericFeatures: ['Goal Setting', 'Progress Tracking', 'Performance Review', '360 Feedback', 'Rating & Reports'],
  },

  fleet: {
    name: 'Fleet Management / Manajemen Armada',
    actors: ['Fleet Manager', 'Driver', 'Admin'],
    entities: {
      Vehicle: { fields: { plateNumber: 'string @unique', brand: 'string', model: 'string', year: 'Int', type: 'VehicleType', status: 'VehicleStatus @default(AVAILABLE)', fuelType: 'string', capacity: 'Int', lastMaintenance: 'DateTime?', nextMaintenance: 'DateTime?', createdAt: 'DateTime @default(now())' }, enums: { VehicleType: ['SEDAN', 'SUV', 'MPV', 'TRUCK', 'VAN', 'BUS'], VehicleStatus: ['AVAILABLE', 'IN_USE', 'MAINTENANCE', 'RETIRED'] }, indexes: ['status', 'type'] },
      Driver: { fields: { name: 'string', employeeId: 'string @unique', phone: 'string @unique', licenseNumber: 'string @unique', licenseExpiry: 'DateTime?', isAvailable: 'Boolean @default(true)', rating: 'Float @default(5.0)', totalTrips: 'Int @default(0)', createdAt: 'DateTime @default(now())' } },
      Trip: { fields: { vehicleId: 'string', driverId: 'string', startTime: 'DateTime', endTime: 'DateTime?', startOdometer: 'Int', endOdometer: 'Int?', distance: 'Float?', purpose: 'string', source: 'string', destination: 'string', status: 'TripStatus @default(ACTIVE)', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { TripStatus: ['ACTIVE', 'COMPLETED', 'CANCELLED'] }, indexes: ['vehicleId', 'driverId', 'status'], relations: { belongsTo: ['Vehicle', 'Driver'] } },
      Maintenance: { fields: { vehicleId: 'string', type: 'string', description: 'string', odometer: 'Int?', cost: 'Float', vendor: 'string?', status: 'MaintStatus @default(SCHEDULED)', scheduledAt: 'DateTime', completedAt: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { MaintStatus: ['SCHEDULED', 'IN_PROGRESS', 'COMPLETED'] }, indexes: ['vehicleId', 'status'], relations: { belongsTo: ['Vehicle'] } },
      FuelLog: { fields: { vehicleId: 'string', driverId: 'string', amount: 'Float', cost: 'Float', odometer: 'Int', station: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['vehicleId', 'createdAt'], relations: { belongsTo: ['Vehicle', 'Driver'] } },
    },
    flows: ['Fleet Manager assigns vehicle and driver for a trip', 'Driver starts trip   system records odometer and time', 'GPS tracking monitors vehicle location during trip', 'Trip ends   driver logs end odometer and fuel usage', 'Scheduled maintenance alerts for upcoming service', 'Reports: fuel efficiency, maintenance costs, trip history'],
    endpoints: ['GET    /api/vehicles                          ?status=&type=', 'POST   /api/trips                             { vehicleId, driverId, purpose, source, destination }', 'PATCH  /api/trips/:id/end                      { endOdometer, endTime }', 'POST   /api/maintenance                       { vehicleId, type, description, scheduledAt }', 'PATCH  /api/maintenance/:id/status             { status }', 'POST   /api/fuel-logs                         { vehicleId, driverId, amount, cost, odometer }', 'GET    /api/dashboard/fleet-summary'],
    metrics: ['Fleet utilization %', 'Fuel efficiency (km/L)', 'Maintenance cost per vehicle', 'Trips per day'],
    genericFeatures: ['Vehicle Management', 'Driver Management', 'Trip Tracking', 'Maintenance Scheduling', 'Fuel Log'],
  },

  courier: {
    name: 'Courier / Ekspedisi',
    actors: ['Sender', 'Receiver', 'Courier', 'Admin'],
    entities: {
      Shipment: { fields: { trackingNumber: 'string @unique', senderId: 'string', receiverId: 'string', courierId: 'string?', origin: 'string', destination: 'string', weight: 'Float', dimensions: 'string?', type: 'ShipmentType', status: 'ShipmentStatus @default(PENDING)', estimatedDelivery: 'DateTime?', actualDelivery: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { ShipmentType: ['DOCUMENT', 'PARCEL', 'FRAGILE', 'PERISHABLE', 'ELECTRONICS'], ShipmentStatus: ['PENDING', 'PICKED_UP', 'SORTING', 'IN_TRANSIT', 'OUT_FOR_DELIVERY', 'DELIVERED', 'FAILED', 'RETURNED'] }, indexes: ['trackingNumber', 'senderId', 'receiverId', 'status'], relations: { belongsTo: ['Sender', 'Receiver', 'Courier'] } },
      Tracking: { fields: { shipmentId: 'string', location: 'string', status: 'string', description: 'string?', timestamp: 'DateTime @default(now())' }, indexes: ['shipmentId', 'timestamp'], relations: { belongsTo: ['Shipment'] } },
      Payment: { fields: { shipmentId: 'string @unique', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Shipment'] } },
      Courier: { fields: { name: 'string', phone: 'string @unique', email: 'string?', vehicleType: 'string', serviceArea: 'string (JSON)?', isAvailable: 'Boolean @default(true)', rating: 'Float @default(5.0)', totalDeliveries: 'Int @default(0)', createdAt: 'DateTime @default(now())' } },
    },
    flows: ['Sender creates shipment   system generates tracking number', 'Courier picks up package from sender location', 'Package arrives at sorting facility   scanned and sorted by destination', 'Package loaded for transit to destination city', 'Local courier picks up for last-mile delivery', 'Package delivered   receiver signs   status updated'],
    endpoints: ['POST   /api/shipments                         { senderId, receiverId, origin, destination, weight }', 'GET    /api/shipments/:tracking', 'GET    /api/shipments                         ?status=&senderId=&dateFrom=&dateTo=&page=&limit=', 'PATCH  /api/shipments/:id/status               { status, location? }', 'POST   /api/tracking                          { shipmentId, location, status, description? }', 'POST   /api/payments                          { shipmentId, method, amount }', 'GET    /api/dashboard/courier-summary'],
    metrics: ['Shipments per day', 'On-time delivery rate %', 'Average delivery time', 'Courier efficiency score'],
    genericFeatures: ['Shipment Creation', 'Real-time Tracking', 'Courier Assignment', 'Payment & COD', 'Delivery Reports'],
  },

  trucking: {
    name: 'Trucking / Angkutan Barang',
    actors: ['Shipper', 'Driver', 'Owner', 'Dispatcher'],
    entities: {
      Load: { fields: { loadNumber: 'string @unique', shipperId: 'string', description: 'string', weight: 'Float', volume: 'Float?', pickupLocation: 'string', deliveryLocation: 'string', pickupDate: 'DateTime', deliveryDate: 'DateTime', status: 'LoadStatus @default(PENDING)', rate: 'Float', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { LoadStatus: ['PENDING', 'ASSIGNED', 'LOADED', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED'] }, indexes: ['status', 'shipperId'], relations: { belongsTo: ['Shipper'] } },
      Truck: { fields: { plateNumber: 'string @unique', brand: 'string', model: 'string', year: 'Int', type: 'TruckType', capacity: 'Float', status: 'TruckStatus @default(AVAILABLE)', insuranceExpiry: 'DateTime?', createdAt: 'DateTime @default(now())' }, enums: { TruckType: ['BOX', 'WINGBOX', 'TRAILER', 'DUMP', 'TANKER'], TruckStatus: ['AVAILABLE', 'LOADED', 'IN_TRANSIT', 'MAINTENANCE'] }, indexes: ['status', 'type'] },
      Driver: { fields: { name: 'string', phone: 'string @unique', licenseNumber: 'string @unique', licenseType: 'string', isAvailable: 'Boolean @default(true)', rating: 'Float @default(5.0)', totalTrips: 'Int @default(0)', createdAt: 'DateTime @default(now())' } },
      Route: { fields: { name: 'string', origin: 'string', destination: 'string', distance: 'Float', estimatedDuration: 'Int', tollCost: 'Float @default(0)', fuelEstimate: 'Float @default(0)', createdAt: 'DateTime @default(now())' } },
      Delivery: { fields: { loadId: 'string', truckId: 'string', driverId: 'string', routeId: 'string?', departureTime: 'DateTime?', arrivalTime: 'DateTime?', status: 'DelStatus @default(PENDING)', odometerStart: 'Int?', odometerEnd: 'Int?', fuelUsed: 'Float?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { DelStatus: ['PENDING', 'LOADING', 'DEPARTED', 'IN_TRANSIT', 'DELIVERED'] }, indexes: ['loadId', 'truckId', 'status'], relations: { belongsTo: ['Load', 'Truck', 'Driver'] } },
    },
    flows: ['Shipper books trucking service for load', 'Dispatcher assigns truck and driver to the load', 'Driver loads cargo at pickup location', 'Driver departs   GPS tracking enabled', 'Driver delivers cargo at destination   receiver signs', 'Dispatch confirms delivery   payment processed'],
    endpoints: ['POST   /api/loads                            { shipperId, description, weight, pickupLocation, deliveryLocation }', 'GET    /api/loads                            ?status=&page=&limit=', 'PATCH  /api/loads/:id/assign                  { truckId, driverId }', 'POST   /api/deliveries                        { loadId, truckId, driverId, routeId? }', 'PATCH  /api/deliveries/:id/status              { status, odometerEnd?, fuelUsed? }', 'GET    /api/trucks                            ?status=&type=', 'GET    /api/drivers                           ?isAvailable=', 'GET    /api/dashboard/trucking-summary'],
    metrics: ['Loads per month', 'On-time delivery %', 'Fuel efficiency', 'Truck utilization %'],
    genericFeatures: ['Load Management', 'Dispatch System', 'GPS Tracking', 'Driver Management', 'Fuel & Cost Tracking'],
  },

  digital_product: {
    name: 'Digital Product / Produk Digital',
    actors: ['Creator', 'Customer', 'Admin'],
    entities: {
      Product: { fields: { name: 'string', description: 'string?', price: 'Float', type: 'ProductType', fileUrl: 'string?', previewUrl: 'string?', category: 'string', tags: 'string (JSON)?', downloadLimit: 'Int @default(0)', status: 'string @default("PUBLISHED")', salesCount: 'Int @default(0)', rating: 'Float @default(0)', createdAt: 'DateTime @default(now())' }, enums: { ProductType: ['EBOOK', 'TEMPLATE', 'SOFTWARE', 'DESIGN', 'AUDIO', 'VIDEO', 'FONT', 'ICON'] }, indexes: ['category', 'status', 'createdAt'] },
      Purchase: { fields: { productId: 'string', customerId: 'string', amount: 'Float', status: 'PurchaseStatus @default(PENDING)', downloadToken: 'string?', downloadCount: 'Int @default(0)', purchasedAt: 'DateTime @default(now())' }, enums: { PurchaseStatus: ['PENDING', 'COMPLETED', 'REFUNDED', 'CANCELLED'] }, indexes: ['productId', 'customerId', 'status'], relations: { belongsTo: ['Product', 'Customer'] } },
      License: { fields: { purchaseId: 'string @unique', licenseKey: 'string @unique', type: 'LicenseType', validUntil: 'DateTime?', maxActivations: 'Int @default(1)', currentActivations: 'Int @default(0)', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' }, enums: { LicenseType: ['STANDARD', 'EXTENDED', 'COMMERCIAL', 'LIFETIME'] }, relations: { belongsTo: ['Purchase'] } },
      Customer: { fields: { name: 'string', email: 'string @unique', phone: 'string?', totalPurchases: 'Int @default(0)', totalSpent: 'Float @default(0)', createdAt: 'DateTime @default(now())' } },
    },
    flows: ['Creator uploads digital product with description and pricing', 'Admin reviews and publishes product', 'Customer browses marketplace   searches by category', 'Customer purchases product   instant download access', 'Customer receives license key (if applicable)', 'Creator receives payment   dashboard shows sales analytics'],
    endpoints: ['POST   /api/products                          { name, price, type, fileUrl, category, description? }', 'GET    /api/products                          ?category=&search=&sort=&page=&limit=', 'POST   /api/purchases                         { productId, customerId }', 'GET    /api/purchases/:customerId', 'GET    /api/licenses/:purchaseId', 'POST   /api/products/:id/download              { purchaseId }', 'GET    /api/dashboard/creator-summary'],
    metrics: ['Products sold per month', 'Revenue per creator', 'Customer acquisition cost', 'Average rating'],
    genericFeatures: ['Product Catalog', 'Purchase & Checkout', 'Digital Delivery', 'License Management', 'Creator Dashboard'],
  },

  membership: {
    name: 'Membership / Keanggotaan',
    actors: ['Member', 'Admin', 'Manager'],
    entities: {
      MembershipTier: { fields: { name: 'string @unique', description: 'string?', price: 'Float', duration: 'Int', benefits: 'string (JSON)?', level: 'Int @default(1)', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' } },
      Member: { fields: { name: 'string', email: 'string @unique', phone: 'string?', tierId: 'string?', status: 'MemberStatus @default(ACTIVE)', startDate: 'DateTime?', endDate: 'DateTime?', autoRenew: 'Boolean @default(false)', totalPaid: 'Float @default(0)', createdAt: 'DateTime @default(now())' }, enums: { MemberStatus: ['ACTIVE', 'EXPIRED', 'CANCELLED', 'SUSPENDED'] }, indexes: ['tierId', 'status'], relations: { belongsTo: ['MembershipTier'] } },
      Payment: { fields: { memberId: 'string', tierId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', periodStart: 'DateTime', periodEnd: 'DateTime', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, indexes: ['memberId', 'status'], relations: { belongsTo: ['Member', 'MembershipTier'] } },
      Benefit: { fields: { tierId: 'string', name: 'string', description: 'string?', type: 'BenefitType', maxUsage: 'Int @default(0)', currentUsage: 'Int @default(0)', createdAt: 'DateTime @default(now())' }, enums: { BenefitType: ['DISCOUNT', 'ACCESS', 'CONTENT', 'EVENT', 'SUPPORT'] }, relations: { belongsTo: ['MembershipTier'] } },
    },
    flows: ['Guest browses membership tiers and benefits', 'Guest registers and selects a tier   payment processed', 'Member gets access to tier-specific benefits and content', 'System sends renewal reminders before expiry', 'Member can upgrade to higher tier or downgrade', 'Manager reviews member retention and revenue analytics'],
    endpoints: ['GET    /api/membership-tiers                  ?isActive=', 'POST   /api/members                          { name, email, tierId }', 'GET    /api/members                          ?status=&tierId=&page=&limit=', 'PATCH  /api/members/:id/tier                  { tierId }', 'POST   /api/membership-payments              { memberId, tierId, method, amount }', 'GET    /api/members/:id/benefits', 'GET    /api/dashboard/membership-summary'],
    metrics: ['Active members', 'Churn rate %', 'Monthly recurring revenue (MRR)', 'Member lifetime value (LTV)'],
    genericFeatures: ['Tier Management', 'Member Registration', 'Payment & Billing', 'Auto-renewal', 'Member Portal'],
  },

  course_platform: {
    name: 'Course Platform / Platform Belajar',
    actors: ['Instructor', 'Student', 'Admin'],
    entities: {
      Course: { fields: { title: 'string', description: 'string?', instructorId: 'string', price: 'Float', category: 'string', level: 'string @default("BEGINNER")', duration: 'Int', image: 'string?', status: 'CourseStatus @default(DRAFT)', rating: 'Float @default(0)', totalStudents: 'Int @default(0)', createdAt: 'DateTime @default(now())' }, enums: { CourseStatus: ['DRAFT', 'PUBLISHED', 'ARCHIVED'] }, indexes: ['instructorId', 'category', 'status'], relations: { belongsTo: ['Instructor'] } },
      Lesson: { fields: { courseId: 'string', title: 'string', content: 'string?', videoUrl: 'string?', duration: 'Int', order: 'Int', isFree: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' }, indexes: ['courseId', 'order'], relations: { belongsTo: ['Course'] } },
      Enrollment: { fields: { courseId: 'string', studentId: 'string', status: 'EnrollStatus @default(ACTIVE)', progress: 'Int @default(0)', enrolledAt: 'DateTime @default(now())', completedAt: 'DateTime?' }, enums: { EnrollStatus: ['ACTIVE', 'COMPLETED', 'DROPPED'] }, indexes: ['courseId', 'studentId'], relations: { belongsTo: ['Course', 'Student'] } },
      Review: { fields: { courseId: 'string', studentId: 'string', rating: 'Int', comment: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['courseId', 'studentId'], relations: { belongsTo: ['Course', 'Student'] } },
      Payment: { fields: { enrollmentId: 'string @unique', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Enrollment'] } },
    },
    flows: ['Instructor creates course with lessons and learning materials', 'Admin reviews and publishes course', 'Student browses and enrolls in course   payment processed', 'Student accesses lessons   progress tracked automatically', 'Student completes course   receives certificate', 'Student leaves review   instructor gets feedback'],
    endpoints: ['POST   /api/courses                           { title, instructorId, price, category, description? }', 'GET    /api/courses                           ?category=&level=&status=&page=&limit=', 'POST   /api/lessons                           { courseId, title, content?, videoUrl?, order }', 'POST   /api/enrollments                       { courseId, studentId }', 'GET    /api/enrollments/:studentId', 'PATCH  /api/enrollments/:id/progress            { progress }', 'POST   /api/reviews                           { courseId, studentId, rating, comment? }', 'POST   /api/courses/:id/certify                { studentId }', 'GET    /api/dashboard/instructor-summary'],
    metrics: ['Active students per course', 'Completion rate %', 'Average course rating', 'Course revenue'],
    genericFeatures: ['Course Creation', 'Enrollment System', 'Progress Tracking', 'Assessment & Grading', 'Certificate Generation'],
  },

  farm: {
    name: 'Farm / Pertanian',
    actors: ['Farmer', 'Worker', 'Buyer', 'Admin'],
    entities: {
      Field: { fields: { name: 'string', location: 'string', size: 'Float', unit: 'string @default("hectare")', soilType: 'string?', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' } },
      Crop: { fields: { fieldId: 'string', name: 'string', variety: 'string?', plantingDate: 'DateTime', estimatedHarvest: 'DateTime?', status: 'CropStatus @default(GROWING)', quantity: 'Int', unit: 'string', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { CropStatus: ['PLANTED', 'GROWING', 'HARVESTED', 'FAILED'] }, indexes: ['fieldId', 'status'], relations: { belongsTo: ['Field'] } },
      Harvest: { fields: { cropId: 'string', workerId: 'string', date: 'DateTime', quantity: 'Float', unit: 'string', quality: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['cropId', 'date'], relations: { belongsTo: ['Crop'] } },
      Inventory: { fields: { name: 'string', type: 'string', quantity: 'Float', unit: 'string', minStock: 'Float @default(0)', location: 'string?', expiryDate: 'DateTime?', createdAt: 'DateTime @default(now())' }, indexes: ['type'] },
      Sale: { fields: { buyerId: 'string', harvestId: 'string?', inventoryId: 'string?', quantity: 'Float', unit: 'string', price: 'Float', total: 'Float', date: 'DateTime', status: 'string @default("COMPLETED")', createdAt: 'DateTime @default(now())' }, indexes: ['buyerId', 'date'], relations: { belongsTo: ['Buyer'] } },
    },
    flows: ['Farmer plants crops in designated fields', 'Worker tends to crops   applies fertilizer and water', 'Crops mature   Farmer schedules harvest', 'Worker harvests crops   records yield and quality', 'Harvest is stored in inventory or sold to buyers', 'Dashboard: active crops, harvest yields, sales revenue'],
    endpoints: ['POST   /api/fields                            { name, location, size }', 'POST   /api/crops                             { fieldId, name, plantingDate, quantity }', 'GET    /api/crops                             ?fieldId=&status=', 'PATCH  /api/crops/:id/status                   { status }', 'POST   /api/harvests                          { cropId, workerId, date, quantity, quality? }', 'GET    /api/inventory                         ?type=', 'POST   /api/sales                             { buyerId, harvestId?, inventoryId?, quantity, price }', 'GET    /api/dashboard/farm-summary'],
    metrics: ['Yield per hectare', 'Crop success rate %', 'Revenue per season', 'Inventory turnover'],
    genericFeatures: ['Field Management', 'Crop Planning', 'Harvest Recording', 'Inventory Management', 'Sales & Buyers'],
  },

  livestock: {
    name: 'Livestock / Peternakan',
    actors: ['Farmer', 'Vet', 'Buyer'],
    entities: {
      Animal: { fields: { tagNumber: 'string @unique', type: 'string', breed: 'string?', birthDate: 'DateTime', gender: 'string', weight: 'Float', location: 'string?', status: 'AnimalStatus @default(ACTIVE)', purchasePrice: 'Float?', createdAt: 'DateTime @default(now())' }, enums: { AnimalStatus: ['ACTIVE', 'PREGNANT', 'SICK', 'SOLD', 'DECEASED'] }, indexes: ['type', 'status'] },
      Feeding: { fields: { animalId: 'string', feedType: 'string', quantity: 'Float', unit: 'string', time: 'DateTime', notes: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['animalId', 'time'], relations: { belongsTo: ['Animal'] } },
      HealthRecord: { fields: { animalId: 'string', vetId: 'string', type: 'HealthType', diagnosis: 'string', treatment: 'string?', medication: 'string?', cost: 'Float?', nextCheckup: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { HealthType: ['CHECKUP', 'VACCINATION', 'TREATMENT', 'SURGERY', 'BIRTH'] }, indexes: ['animalId', 'type'], relations: { belongsTo: ['Animal'] } },
      Breeding: { fields: { maleId: 'string', femaleId: 'string', matingDate: 'DateTime', status: 'BreedingStatus @default(MATED)', expectedBirth: 'DateTime?', birthDate: 'DateTime?', offspring: 'Int @default(0)', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { BreedingStatus: ['MATED', 'CONFIRMED', 'BIRTHED', 'FAILED'] }, indexes: ['maleId', 'femaleId'] },
      Sale: { fields: { animalId: 'string', buyerName: 'string', buyerPhone: 'string?', price: 'Float', weight: 'Float?', date: 'DateTime', notes: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['animalId', 'date'], relations: { belongsTo: ['Animal'] } },
    },
    flows: ['New animal registered with tag number and type', 'Farmer records daily feeding for each animal', 'Vet performs regular health checkups and vaccinations', 'Breeding program   male and female paired', 'Animal sold   Farmer records sale details', 'Dashboard: animal count, health status, breeding success'],
    endpoints: ['POST   /api/animals                           { tagNumber, type, breed?, birthDate, gender }', 'GET    /api/animals                           ?type=&status=', 'POST   /api/feedings                          { animalId, feedType, quantity, unit }', 'POST   /api/health-records                    { animalId, vetId, type, diagnosis, treatment? }', 'POST   /api/breedings                         { maleId, femaleId, matingDate }', 'POST   /api/sales                             { animalId, buyerName, price, date }', 'GET    /api/dashboard/livestock-summary'],
    metrics: ['Animal count by type', 'Average weight gain', 'Breeding success rate %', 'Mortality rate %'],
    genericFeatures: ['Animal Registry', 'Feeding Schedule', 'Health Records', 'Breeding Program', 'Sales Tracking'],
  },

  poultry: {
    name: 'Poultry / Peternakan Ayam',
    actors: ['Farmer', 'Worker', 'Buyer'],
    entities: {
      Flock: { fields: { name: 'string', type: 'PoultryType', quantity: 'Int', breed: 'string?', arrivalDate: 'DateTime', age: 'Int @default(1)', location: 'string?', status: 'FlockStatus @default(ACTIVE)', createdAt: 'DateTime @default(now())' }, enums: { PoultryType: ['BROILER', 'LAYER', 'NATIVE'], FlockStatus: ['ACTIVE', 'GROWING', 'PRODUCING', 'SOLD', 'DEPLETED'] }, indexes: ['type', 'status'] },
      DailyRecord: { fields: { flockId: 'string', date: 'DateTime', mortality: 'Int @default(0)', feedConsumed: 'Float', waterConsumed: 'Float', weightAvg: 'Float?', eggsCollected: 'Int @default(0)', temperature: 'Float?', humidity: 'Float?', notes: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['flockId', 'date'], relations: { belongsTo: ['Flock'] } },
      Feed: { fields: { name: 'string', type: 'string', stock: 'Float', unit: 'string', unitPrice: 'Float', minStock: 'Float', supplier: 'string?', createdAt: 'DateTime @default(now())' } },
      Vaccine: { fields: { flockId: 'string', name: 'string', date: 'DateTime', nextDue: 'DateTime?', batchNumber: 'string?', cost: 'Float', notes: 'string?', administeredBy: 'string', createdAt: 'DateTime @default(now())' }, indexes: ['flockId', 'date'], relations: { belongsTo: ['Flock'] } },
      Sale: { fields: { flockId: 'string', buyerName: 'string', quantity: 'Int', weightTotal: 'Float?', pricePerKg: 'Float', total: 'Float', date: 'DateTime', type: 'string @default("LIVE")', notes: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['flockId', 'date'], relations: { belongsTo: ['Flock'] } },
    },
    flows: ['Farmer receives new flock   registers with breed and quantity', 'Worker feeds and waters daily   records mortality and growth', 'Vaccination schedule followed for disease prevention', 'Daily egg collection recorded (for layers)', 'Birds reach market weight   sold to buyers', 'Dashboard: mortality rate, feed conversion, revenue per flock'],
    endpoints: ['POST   /api/flocks                            { name, type, quantity, breed?, arrivalDate }', 'GET    /api/flocks                            ?type=&status=', 'POST   /api/daily-records                     { flockId, date, mortality, feedConsumed, eggsCollected? }', 'POST   /api/vaccines                          { flockId, name, date, administeredBy }', 'POST   /api/sales                             { flockId, buyerName, quantity, pricePerKg }', 'GET    /api/dashboard/poultry-summary'],
    metrics: ['Mortality rate %', 'Feed conversion ratio (FCR)', 'Egg production rate %', 'Average market weight'],
    genericFeatures: ['Flock Management', 'Daily Records', 'Feed & Vaccine', 'Egg Collection', 'Sales & Revenue'],
  },

  bengkel: {
    name: 'Bengkel / Auto Repair',
    actors: ['Customer', 'Mechanic', 'Owner'],
    entities: {
      Vehicle: { fields: { customerId: 'string', plateNumber: 'string @unique', brand: 'string', model: 'string', year: 'Int?', mileage: 'Int @default(0)', fuelType: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['customerId'], relations: { belongsTo: ['Customer'] } },
      ServiceOrder: { fields: { orderNumber: 'string @unique', customerId: 'string', vehicleId: 'string', complaint: 'string', diagnosis: 'string?', status: 'OrderStatus @default(PENDING)', estimatedCost: 'Float?', totalCost: 'Float?', startTime: 'DateTime?', endTime: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { OrderStatus: ['PENDING', 'DIAGNOSING', 'ESTIMATED', 'APPROVED', 'REPAIRING', 'COMPLETED', 'PICKED_UP', 'CANCELLED'] }, indexes: ['customerId', 'vehicleId', 'status'], relations: { belongsTo: ['Customer', 'Vehicle'] } },
      ServiceItem: { fields: { serviceOrderId: 'string', name: 'string', type: 'string @default("LABOR")', quantity: 'Int @default(1)', price: 'Float', total: 'Float', notes: 'string?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['ServiceOrder'] } },
      SparePart: { fields: { name: 'string', sku: 'string @unique', brand: 'string?', price: 'Float', stock: 'Int @default(0)', minStock: 'Int @default(5)', supplier: 'string?', createdAt: 'DateTime @default(now())' } },
      Payment: { fields: { serviceOrderId: 'string @unique', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['ServiceOrder'] } },
    },
    flows: ['Customer datang   Mekanik terima kendaraan dan catat keluhan', 'Mekanik diagnosa masalah   buat estimasi biaya dan waktu', 'Customer setuju estimasi   Service order approved', 'Mekanik kerjakan perbaikan   catat spare part digunakan', 'Service selesai   Customer bayar dan ambil kendaraan', 'Owner review: revenue, spare part stok, mekanik performance'],
    endpoints: ['POST   /api/service-orders                    { customerId, vehicleId, complaint }', 'GET    /api/service-orders                    ?status=&date=&page=&limit=', 'PATCH  /api/service-orders/:id/diagnose        { diagnosis, estimatedCost }', 'PATCH  /api/service-orders/:id/status          { status }', 'POST   /api/service-items                     { serviceOrderId, name, type, quantity, price }', 'GET    /api/spare-parts                       ?search=', 'POST   /api/payments                          { serviceOrderId, method, amount }', 'GET    /api/dashboard/bengkel-summary'],
    metrics: ['Service orders per day', 'Average repair cost', 'Spare part turnover', 'Mechanic utilization %'],
    genericFeatures: ['Service Order', 'Diagnosis & Estimate', 'Spare Part Inventory', 'Customer Vehicle History', 'Payment & Reports'],
  },

  car_rental: {
    name: 'Car Rental / Rental Mobil',
    actors: ['Customer', 'Staff', 'Manager'],
    entities: {
      Vehicle: { fields: { plateNumber: 'string @unique', brand: 'string', model: 'string', year: 'Int', type: 'VehicleType', seats: 'Int', transmission: 'string', pricePerDay: 'Float', deposit: 'Float', status: 'VehicleStatus @default(AVAILABLE)', location: 'string?', image: 'string?', createdAt: 'DateTime @default(now())' }, enums: { VehicleType: ['ECONOMY', 'SUV', 'MPV', 'LUXURY', 'SPORT'], VehicleStatus: ['AVAILABLE', 'BOOKED', 'RENTED', 'MAINTENANCE'] }, indexes: ['status', 'type'] },
      Booking: { fields: { bookingNumber: 'string @unique', customerId: 'string', vehicleId: 'string', pickupDate: 'DateTime', returnDate: 'DateTime', totalDays: 'Int', totalPrice: 'Float', depositPaid: 'Float @default(0)', status: 'BookingStatus @default(PENDING)', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { BookingStatus: ['PENDING', 'CONFIRMED', 'ACTIVE', 'COMPLETED', 'CANCELLED'] }, indexes: ['customerId', 'vehicleId', 'status'], relations: { belongsTo: ['Customer', 'Vehicle'] } },
      Customer: { fields: { name: 'string', phone: 'string @unique', email: 'string?', idCard: 'string?', driversLicense: 'string?', address: 'string?', totalRentals: 'Int @default(0)', createdAt: 'DateTime @default(now())' } },
      Payment: { fields: { bookingId: 'string', amount: 'Float', type: 'PaymentType', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, enums: { PaymentType: ['DEPOSIT', 'FULL_PAYMENT', 'REFUND'] }, indexes: ['bookingId'], relations: { belongsTo: ['Booking'] } },
      Insurance: { fields: { bookingId: 'string @unique', type: 'string', provider: 'string', policyNumber: 'string', coverage: 'string (JSON)?', premium: 'Float', startDate: 'DateTime', endDate: 'DateTime', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Booking'] } },
    },
    flows: ['Customer browses available vehicles and pricing', 'Customer books vehicle for specific dates   Staff confirms', 'Customer picks up vehicle   Staff inspects and hands over keys', 'Customer returns vehicle   Staff inspects for damage', 'Payment processed   deposit refunded if no issues', 'Manager reviews fleet utilization and revenue'],
    endpoints: ['GET    /api/vehicles                          ?type=&status=&priceMin=&priceMax=', 'POST   /api/bookings                          { customerId, vehicleId, pickupDate, returnDate }', 'GET    /api/bookings                          ?status=&customerId=&page=&limit=', 'PATCH  /api/bookings/:id/status                { status }', 'POST   /api/pickup                            { bookingId }', 'POST   /api/return                            { bookingId, condition? }', 'POST   /api/payments                          { bookingId, amount, type, method }', 'GET    /api/dashboard/rental-summary'],
    metrics: ['Fleet utilization %', 'Average rental duration', 'Revenue per vehicle', 'Customer repeat rate'],
    genericFeatures: ['Vehicle Fleet', 'Booking System', 'Pick-up/Return', 'Payment & Deposit', 'Insurance Management'],
  },

  dealer: {
    name: 'Dealer / Showroom Mobil',
    actors: ['Customer', 'Sales', 'Manager'],
    entities: {
      Vehicle: { fields: { vin: 'string @unique', brand: 'string', model: 'string', year: 'Int', color: 'string', price: 'Float', mileage: 'Int @default(0)', type: 'VehicleType', status: 'VehicleStatus @default(AVAILABLE)', location: 'string?', images: 'string (JSON)?', description: 'string?', createdAt: 'DateTime @default(now())' }, enums: { VehicleType: ['NEW', 'USED', 'CERTIFIED_PRE_OWNED'], VehicleStatus: ['AVAILABLE', 'RESERVED', 'SOLD', 'IN_TRANSIT'] }, indexes: ['status', 'type', 'brand'] },
      Customer: { fields: { name: 'string', phone: 'string @unique', email: 'string?', address: 'string?', idCard: 'string?', totalPurchases: 'Int @default(0)', createdAt: 'DateTime @default(now())' } },
      Sale: { fields: { invoiceNumber: 'string @unique', vehicleId: 'string @unique', customerId: 'string', salesId: 'string', salePrice: 'Float', tradeInValue: 'Float @default(0)', discount: 'Float @default(0)', tax: 'Float', total: 'Float', status: 'SaleStatus @default(PENDING)', saleDate: 'DateTime', deliveryDate: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { SaleStatus: ['PENDING', 'FINANCING', 'COMPLETED', 'CANCELLED'] }, indexes: ['customerId', 'salesId', 'status'], relations: { belongsTo: ['Vehicle', 'Customer'] } },
      TradeIn: { fields: { saleId: 'string @unique', customerId: 'string', brand: 'string', model: 'string', year: 'Int', mileage: 'Int', condition: 'string', appraisedValue: 'Float', finalValue: 'Float', status: 'string @default("APPRAISED")', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Sale', 'Customer'] } },
      Financing: { fields: { saleId: 'string @unique', customerId: 'string', lender: 'string', loanAmount: 'Float', downPayment: 'Float', interestRate: 'Float', termMonths: 'Int', monthlyPayment: 'Float', status: 'FinanceStatus @default(PENDING)', approvedAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, enums: { FinanceStatus: ['PENDING', 'APPROVED', 'REJECTED', 'ACTIVE', 'PAID'] }, relations: { belongsTo: ['Sale', 'Customer'] } },
    },
    flows: ['Customer browses inventory and test drives vehicle', 'Salesperson negotiates price and trade-in value', 'Customer applies for financing (if needed)', 'Customer signs sales agreement and pays', 'Vehicle delivery scheduled and completed', 'Manager reviews sales pipeline and inventory aging'],
    endpoints: ['GET    /api/vehicles                          ?type=&status=&brand=&priceMin=&priceMax=', 'POST   /api/test-drives                       { customerId, vehicleId, date }', 'POST   /api/sales                            { vehicleId, customerId, salesId, salePrice }', 'GET    /api/sales                            ?status=&dateFrom=&dateTo=&page=&limit=', 'POST   /api/trade-ins                         { saleId, customerId, brand, model, year, mileage }', 'POST   /api/financing                         { saleId, customerId, lender, loanAmount, downPayment }', 'PATCH  /api/sales/:id/status                  { status }', 'GET    /api/dashboard/dealer-summary'],
    metrics: ['Vehicles sold per month', 'Average days to sell', 'Gross profit per vehicle', 'Finance approval rate %'],
    genericFeatures: ['Inventory Management', 'Customer Management', 'Sales Processing', 'Trade-in Appraisal', 'Financing & Delivery'],
  },

  contractor: {
    name: 'Contractor / Kontraktor',
    actors: ['Client', 'Contractor', 'Architect', 'Worker'],
    entities: {
      Project: { fields: { name: 'string', clientId: 'string', architectId: 'string?', description: 'string?', location: 'string', budget: 'Float', status: 'ProjStatus @default(PLANNING)', startDate: 'DateTime?', endDate: 'DateTime?', createdAt: 'DateTime @default(now())' }, enums: { ProjStatus: ['PLANNING', 'IN_PROGRESS', 'ON_HOLD', 'COMPLETED', 'CANCELLED'] }, indexes: ['clientId', 'status'], relations: { belongsTo: ['Client'] } },
      Task: { fields: { projectId: 'string', name: 'string', description: 'string?', assignedWorkerId: 'string?', startDate: 'DateTime?', endDate: 'DateTime?', status: 'TaskStatus @default(TODO)', priority: 'Priority @default(MEDIUM)', cost: 'Float?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { TaskStatus: ['TODO', 'IN_PROGRESS', 'REVIEW', 'COMPLETED'], Priority: ['LOW', 'MEDIUM', 'HIGH', 'URGENT'] }, indexes: ['projectId', 'status'], relations: { belongsTo: ['Project'] } },
      Material: { fields: { projectId: 'string', name: 'string', quantity: 'Float', unit: 'string', unitPrice: 'Float', totalCost: 'Float', supplier: 'string?', status: 'MatStatus @default(ORDERED)', deliveredAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, enums: { MatStatus: ['ORDERED', 'DELIVERED', 'INSTALLED', 'RETURNED'] }, indexes: ['projectId'], relations: { belongsTo: ['Project'] } },
      Worker: { fields: { name: 'string', phone: 'string @unique', skill: 'string', dailyRate: 'Float', isAvailable: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' } },
      Timesheet: { fields: { projectId: 'string', workerId: 'string', date: 'DateTime', hoursWorked: 'Float', overtime: 'Float @default(0)', description: 'string?', approvedById: 'string?', status: 'string @default("PENDING")', createdAt: 'DateTime @default(now())' }, indexes: ['projectId', 'workerId', 'date'], relations: { belongsTo: ['Project', 'Worker'] } },
    },
    flows: ['Client and Contractor sign contract   project created', 'Architect provides design and specifications', 'Contractor creates task breakdown and assigns workers', 'Materials ordered and delivered to site', 'Workers complete tasks   progress updated daily', 'Project completed   final inspection and handover'],
    endpoints: ['POST   /api/projects                          { name, clientId, description, location, budget }', 'GET    /api/projects                          ?status=&clientId=&page=&limit=', 'PATCH  /api/projects/:id/status                { status }', 'POST   /api/tasks                             { projectId, name, assignedWorkerId?, priority? }', 'PATCH  /api/tasks/:id/status                   { status }', 'POST   /api/materials                         { projectId, name, quantity, unitPrice, supplier? }', 'POST   /api/timesheets                        { projectId, workerId, date, hoursWorked }', 'GET    /api/dashboard/contractor-summary'],
    metrics: ['Active projects', 'On-time completion %', 'Budget variance %', 'Worker productivity'],
    genericFeatures: ['Project Management', 'Task Assignment', 'Material Procurement', 'Worker Timesheet', 'Progress Tracking'],
  },

  maintenance: {
    name: 'Maintenance / Pemeliharaan',
    actors: ['Tenant', 'Technician', 'Manager'],
    entities: {
      Request: { fields: { requestNumber: 'string @unique', tenantId: 'string', title: 'string', description: 'string', priority: 'Priority @default(MEDIUM)', location: 'string', area: 'string?', status: 'ReqStatus @default(PENDING)', createdAt: 'DateTime @default(now())' }, enums: { Priority: ['LOW', 'MEDIUM', 'HIGH', 'URGENT'], ReqStatus: ['PENDING', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'] }, indexes: ['tenantId', 'status', 'priority'], relations: { belongsTo: ['Tenant'] } },
      WorkOrder: { fields: { requestId: 'string @unique', technicianId: 'string', scheduledAt: 'DateTime?', startedAt: 'DateTime?', completedAt: 'DateTime?', status: 'WOStatus @default(PENDING)', cost: 'Float?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { WOStatus: ['PENDING', 'SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] }, indexes: ['technicianId', 'status'], relations: { belongsTo: ['Request', 'Technician'] } },
      Asset: { fields: { name: 'string', code: 'string @unique', type: 'string', location: 'string', purchaseDate: 'DateTime?', warrantyExpiry: 'DateTime?', status: 'AssetStatus @default(OPERATIONAL)', lastMaintenance: 'DateTime?', nextMaintenance: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { AssetStatus: ['OPERATIONAL', 'UNDER_MAINTENANCE', 'BROKEN', 'RETIRED'] }, indexes: ['type', 'status'] },
      Schedule: { fields: { assetId: 'string', technicianId: 'string', type: 'ScheduleType', description: 'string', frequency: 'string', scheduledDate: 'DateTime', completedDate: 'DateTime?', status: 'SchedStatus @default(SCHEDULED)', createdAt: 'DateTime @default(now())' }, enums: { ScheduleType: ['ROUTINE', 'PREVENTIVE', 'CORRECTIVE', 'EMERGENCY'], SchedStatus: ['SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'SKIPPED'] }, indexes: ['assetId', 'status', 'scheduledDate'], relations: { belongsTo: ['Asset'] } },
      SparePart: { fields: { name: 'string', sku: 'string @unique', stock: 'Int @default(0)', minStock: 'Int @default(5)', unitPrice: 'Float', supplier: 'string?', createdAt: 'DateTime @default(now())' } },
    },
    flows: ['Tenant reports maintenance issue with description and priority', 'Manager reviews and creates work order   assigns technician', 'Technician schedules visit and performs repair', 'Technician marks work order as completed with notes', 'Tenant confirms issue resolved   work order closed', 'Manager reviews response time and recurring issues'],
    endpoints: ['POST   /api/requests                          { tenantId, title, description, priority, location }', 'GET    /api/requests                          ?status=&priority=&page=&limit=', 'POST   /api/work-orders                       { requestId, technicianId, scheduledAt? }', 'PATCH  /api/work-orders/:id/status             { status, notes? }', 'POST   /api/schedules                         { assetId, type, description, frequency, scheduledDate }', 'GET    /api/assets                            ?type=&status=', 'GET    /api/dashboard/maintenance-summary'],
    metrics: ['Requests per month', 'Average response time', 'First-time fix rate %', 'Scheduled maintenance compliance %'],
    genericFeatures: ['Request Management', 'Work Order System', 'Asset Management', 'Maintenance Schedule', 'Spare Parts Inventory'],
  },

  event_management: {
    name: 'Event Management / Manajemen Acara',
    actors: ['Organizer', 'Attendee', 'Speaker', 'Sponsor'],
    entities: {
      Event: { fields: { title: 'string', description: 'string?', category: 'string', type: 'EventType', startDate: 'DateTime', endDate: 'DateTime', location: 'string', maxAttendees: 'Int @default(100)', ticketPrice: 'Float @default(0)', status: 'EventStatus @default(DRAFT)', image: 'string?', organizerId: 'string', createdAt: 'DateTime @default(now())' }, enums: { EventType: ['CONFERENCE', 'WORKSHOP', 'SEMINAR', 'WEBINAR', 'NETWORKING'], EventStatus: ['DRAFT', 'PUBLISHED', 'ONGOING', 'COMPLETED', 'CANCELLED'] }, indexes: ['organizerId', 'category', 'status', 'startDate'], relations: { belongsTo: ['Organizer'] } },
      Ticket: { fields: { eventId: 'string', name: 'string', price: 'Float', quantity: 'Int', sold: 'Int @default(0)', benefits: 'string (JSON)?', salesStart: 'DateTime?', salesEnd: 'DateTime?', createdAt: 'DateTime @default(now())' }, indexes: ['eventId'], relations: { belongsTo: ['Event'] } },
      Attendee: { fields: { name: 'string', email: 'string', phone: 'string?', ticketId: 'string', eventId: 'string', checkInStatus: 'string @default("NOT_CHECKED_IN")', checkedInAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, indexes: ['eventId', 'ticketId'], relations: { belongsTo: ['Event', 'Ticket'] } },
      Speaker: { fields: { name: 'string', email: 'string @unique', bio: 'string?', photo: 'string?', expertise: 'string (JSON)?', socialLinks: 'string (JSON)?', createdAt: 'DateTime @default(now())' } },
      Payment: { fields: { attendeeId: 'string @unique', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Attendee'] } },
    },
    flows: ['Organizer creates event with details and ticket tiers', 'Event published   attendees can register and purchase tickets', 'Speaker confirmed for sessions   schedule published', 'Attendee checks in at venue   badge printed', 'Event executes   sessions, networking, activities', 'Post-event   feedback collected, attendance report generated'],
    endpoints: ['POST   /api/events                            { title, category, startDate, endDate, location }', 'GET    /api/events                            ?category=&status=&dateFrom=&page=&limit=', 'POST   /api/tickets                           { eventId, name, price, quantity }', 'POST   /api/register                          { eventId, ticketId, name, email }', 'PATCH  /api/attendees/:id/check-in             { attendeeId }', 'POST   /api/payments                          { attendeeId, method, amount }', 'GET    /api/dashboard/event-summary'],
    metrics: ['Tickets sold', 'Check-in rate %', 'Attendee satisfaction', 'Revenue per event'],
    genericFeatures: ['Event Creation', 'Ticket Management', 'Registration System', 'Check-in & Badge', 'Speaker Management'],
  },

  forum: {
    name: 'Forum / Diskusi',
    actors: ['User', 'Moderator', 'Admin'],
    entities: {
      Category: { fields: { name: 'string @unique', description: 'string?', icon: 'string?', order: 'Int @default(0)', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' } },
      Thread: { fields: { categoryId: 'string', userId: 'string', title: 'string', content: 'string', tags: 'string (JSON)?', isPinned: 'Boolean @default(false)', isLocked: 'Boolean @default(false)', viewCount: 'Int @default(0)', replyCount: 'Int @default(0)', lastActivityAt: 'DateTime @default(now())', createdAt: 'DateTime @default(now())' }, indexes: ['categoryId', 'userId', 'lastActivityAt'], relations: { belongsTo: ['Category', 'User'] } },
      Post: { fields: { threadId: 'string', userId: 'string', content: 'string', isEdited: 'Boolean @default(false)', editedAt: 'DateTime?', isSolution: 'Boolean @default(false)', upvotes: 'Int @default(0)', createdAt: 'DateTime @default(now())' }, indexes: ['threadId', 'userId', 'createdAt'], relations: { belongsTo: ['Thread', 'User'] } },
      User: { fields: { username: 'string @unique', email: 'string @unique', passwordHash: 'string', displayName: 'string?', avatar: 'string?', role: 'UserRole @default(MEMBER)', reputation: 'Int @default(0)', postCount: 'Int @default(0)', createdAt: 'DateTime @default(now())' }, enums: { UserRole: ['MEMBER', 'MODERATOR', 'ADMIN'] } },
      Vote: { fields: { postId: 'string', userId: 'string', type: 'VoteType @default(UP)', createdAt: 'DateTime @default(now())' }, enums: { VoteType: ['UP', 'DOWN'] }, indexes: ['postId', 'userId'], relations: { belongsTo: ['Post', 'User'] } },
    },
    flows: ['User browses categories and threads', 'User creates new thread with title and content', 'Other users reply with posts and discussions', 'Users can upvote/downvote helpful posts', 'Moderator reviews reports   pins, locks, or deletes content', 'Admin manages categories and user roles'],
    endpoints: ['GET    /api/categories', 'POST   /api/threads                          { categoryId, title, content, tags? }', 'GET    /api/threads                          ?categoryId=&search=&sort=&page=&limit=', 'GET    /api/threads/:id                       ?includePosts=', 'POST   /api/posts                            { threadId, content }', 'POST   /api/votes                            { postId, type }', 'PATCH  /api/threads/:id/status                { isPinned?, isLocked? }', 'GET    /api/dashboard/forum-summary'],
    metrics: ['Active users', 'Threads per day', 'Average replies per thread', 'User retention rate'],
    genericFeatures: ['Category Management', 'Thread Creation', 'Discussion System', 'Voting & Reputation', 'Moderation Tools'],
  },

  membership_community: {
    name: 'Membership Community / Komunitas Berbayar',
    actors: ['Member', 'Admin', 'Moderator'],
    entities: {
      Member: { fields: { name: 'string', email: 'string @unique', phone: 'string?', planId: 'string?', status: 'MemberStatus @default(ACTIVE)', joinedAt: 'DateTime @default(now())', expiresAt: 'DateTime?', autoRenew: 'Boolean @default(false)', totalPaid: 'Float @default(0)', createdAt: 'DateTime @default(now())' }, enums: { MemberStatus: ['ACTIVE', 'EXPIRED', 'CANCELLED', 'BANNED'] }, indexes: ['planId', 'status'], relations: { belongsTo: ['MembershipPlan'] } },
      MembershipPlan: { fields: { name: 'string @unique', description: 'string?', price: 'Float', durationDays: 'Int', features: 'string (JSON)?', level: 'Int @default(1)', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' } },
      Payment: { fields: { memberId: 'string', planId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', periodStart: 'DateTime', periodEnd: 'DateTime', createdAt: 'DateTime @default(now())' }, indexes: ['memberId', 'status'], relations: { belongsTo: ['Member', 'MembershipPlan'] } },
      Post: { fields: { memberId: 'string', title: 'string', content: 'string', category: 'string?', tags: 'string (JSON)?', isPinned: 'Boolean @default(false)', isMemberOnly: 'Boolean @default(true)', viewCount: 'Int @default(0)', likeCount: 'Int @default(0)', commentCount: 'Int @default(0)', createdAt: 'DateTime @default(now())' }, indexes: ['memberId', 'category', 'createdAt'], relations: { belongsTo: ['Member'] } },
      Event: { fields: { title: 'string', description: 'string?', type: 'string', startDate: 'DateTime', endDate: 'DateTime', maxAttendees: 'Int?', isMemberOnly: 'Boolean @default(true)', status: 'string @default("UPCOMING")', createdAt: 'DateTime @default(now())' }, indexes: ['startDate', 'status'] },
    },
    flows: ['User browses membership plans and benefits', 'User registers and subscribes to a plan', 'Member gets access to exclusive content and events', 'Member participates in community discussions and events', 'System handles auto-renewal and expiry notifications', 'Admin manages members, content, and engagement'],
    endpoints: ['GET    /api/membership-plans                  ?isActive=', 'POST   /api/members                          { name, email, planId }', 'GET    /api/members                          ?status=&planId=&page=&limit=', 'POST   /api/community-payments               { memberId, planId, method, amount }', 'POST   /api/community-posts                   { title, content, category?, isMemberOnly? }', 'GET    /api/community-posts                   ?category=&page=&limit=', 'POST   /api/community-events                  { title, startDate, endDate, description? }', 'GET    /api/dashboard/community-summary'],
    metrics: ['Active members', 'Churn rate %', 'Monthly recurring revenue', 'Engagement rate (posts/event attendance)'],
    genericFeatures: ['Membership Plans', 'Member Management', 'Exclusive Content', 'Community Events', 'Payment & Billing'],
  },

  photography: {
    name: 'Photography / Fotografi',
    actors: ['Photographer', 'Client', 'Admin'],
    entities: {
      Package: { fields: { name: 'string', description: 'string?', price: 'Float', duration: 'string', deliverables: 'string (JSON)?', category: 'string', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' }, indexes: ['category', 'isActive'] },
      Booking: { fields: { bookingNumber: 'string @unique', clientId: 'string', packageId: 'string', photographerId: 'string', date: 'DateTime', location: 'string', status: 'BookingStatus @default(PENDING)', totalPrice: 'Float', deposit: 'Float @default(0)', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { BookingStatus: ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] }, indexes: ['clientId', 'photographerId', 'date', 'status'], relations: { belongsTo: ['Client', 'Package'] } },
      Session: { fields: { bookingId: 'string @unique', startTime: 'DateTime', endTime: 'DateTime?', location: 'string', status: 'SessionStatus @default(SCHEDULED)', photosTaken: 'Int @default(0)', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { SessionStatus: ['SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] }, relations: { belongsTo: ['Booking'] } },
      Gallery: { fields: { bookingId: 'string', name: 'string', photos: 'string (JSON)?', isPublic: 'Boolean @default(false)', shareLink: 'string?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Booking'] } },
      Payment: { fields: { bookingId: 'string', amount: 'Float', type: 'string', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, indexes: ['bookingId'], relations: { belongsTo: ['Booking'] } },
    },
    flows: ['Client browses photography packages and pricing', 'Client books a session   selects package and date', 'Photographer shoots on scheduled date', 'Photographer edits photos and uploads to gallery', 'Client reviews gallery and approves final delivery', 'Payment processed   Client receives high-res files'],
    endpoints: ['GET    /api/packages                          ?category=&isActive=', 'POST   /api/bookings                          { clientId, packageId, date, location }', 'GET    /api/bookings                          ?status=&dateFrom=&page=&limit=', 'PATCH  /api/bookings/:id/status                { status }', 'POST   /api/sessions                          { bookingId, startTime, location }', 'POST   /api/galleries                         { bookingId, name, photos[] }', 'POST   /api/payments                          { bookingId, amount, method, type }', 'GET    /api/dashboard/photography-summary'],
    metrics: ['Bookings per month', 'Revenue per session', 'Client satisfaction rate', 'Average delivery time'],
    genericFeatures: ['Package Management', 'Booking System', 'Session Scheduling', 'Gallery Delivery', 'Payment Processing'],
  },

  veterinary: {
    name: 'Veterinary / Klinik Hewan',
    actors: ['PetOwner', 'Vet', 'Receptionist'],
    entities: {
      Pet: { fields: { name: 'string', ownerId: 'string', species: 'string', breed: 'string?', dateOfBirth: 'DateTime?', gender: 'string', weight: 'Float?', color: 'string?', microchipId: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['ownerId', 'species'], relations: { belongsTo: ['PetOwner'] } },
      Appointment: { fields: { petId: 'string', vetId: 'string', date: 'DateTime', time: 'string', reason: 'string', status: 'ApptStatus @default(SCHEDULED)', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { ApptStatus: ['SCHEDULED', 'CHECKED_IN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW'] }, indexes: ['petId', 'vetId', 'date', 'status'], relations: { belongsTo: ['Pet'] } },
      MedicalRecord: { fields: { petId: 'string', vetId: 'string', appointmentId: 'string?', diagnosis: 'string', treatment: 'string?', symptoms: 'string?', notes: 'string?', followUpDate: 'DateTime?', createdAt: 'DateTime @default(now())' }, indexes: ['petId', 'createdAt'], relations: { belongsTo: ['Pet'] } },
      Prescription: { fields: { medicalRecordId: 'string', medication: 'string', dosage: 'string', frequency: 'string', duration: 'string', notes: 'string?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['MedicalRecord'] } },
      Payment: { fields: { appointmentId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, indexes: ['appointmentId'], relations: { belongsTo: ['Appointment'] } },
    },
    flows: ['PetOwner registers pet and books appointment', 'Receptionist checks in pet on arrival', 'Vet examines pet   diagnosis and treatment plan', 'Vet prescribes medication if needed', 'PetOwner pays at reception', 'Follow-up scheduled if necessary'],
    endpoints: ['POST   /api/pets                             { name, ownerId, species, breed?, dateOfBirth? }', 'GET    /api/pets                             ?ownerId=&species=', 'POST   /api/appointments                     { petId, vetId, date, time, reason }', 'GET    /api/appointments                     ?date=&vetId=&status=', 'PATCH  /api/appointments/:id/status           { status }', 'POST   /api/medical-records                  { petId, vetId, diagnosis, treatment?, symptoms? }', 'POST   /api/prescriptions                    { medicalRecordId, medication, dosage, frequency }', 'POST   /api/payments                         { appointmentId, method, amount }', 'GET    /api/dashboard/vet-summary'],
    metrics: ['Patients per day', 'Average consultation time', 'Prescription rate', 'Follow-up compliance %'],
    genericFeatures: ['Pet Registration', 'Appointment Management', 'Medical Records', 'Prescription System', 'Payment & Billing'],
  },

  gym: {
    name: 'Gym / Fitness Center',
    actors: ['Member', 'Trainer', 'Admin'],
    entities: {
      Membership: { fields: { memberId: 'string @unique', type: 'MembershipType', startDate: 'DateTime', endDate: 'DateTime', price: 'Float', status: 'MembStatus @default(ACTIVE)', autoRenew: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' }, enums: { MembershipType: ['MONTHLY', 'QUARTERLY', 'YEARLY', 'LIFETIME'], MembStatus: ['ACTIVE', 'EXPIRED', 'CANCELLED', 'FROZEN'] }, relations: { belongsTo: ['Member'] } },
      Member: { fields: { name: 'string', email: 'string @unique', phone: 'string?', dateOfBirth: 'DateTime?', gender: 'string?', emergencyContact: 'string?', healthNotes: 'string?', photo: 'string?', createdAt: 'DateTime @default(now())' } },
      Class: { fields: { name: 'string', description: 'string?', trainerId: 'string', schedule: 'string (JSON)?', capacity: 'Int @default(20)', duration: 'Int', difficulty: 'string @default("BEGINNER")', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' }, indexes: ['trainerId', 'isActive'], relations: { belongsTo: ['Trainer'] } },
      Attendance: { fields: { memberId: 'string', date: 'DateTime', checkIn: 'DateTime', checkOut: 'DateTime?', type: 'string @default("REGULAR")', classId: 'string?', createdAt: 'DateTime @default(now())' }, indexes: ['memberId', 'date', 'classId'], relations: { belongsTo: ['Member'] } },
      Payment: { fields: { memberId: 'string', membershipId: 'string?', amount: 'Float', method: 'string', type: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, indexes: ['memberId', 'status'], relations: { belongsTo: ['Member'] } },
    },
    flows: ['Guest registers as member   selects membership plan', 'Member attends gym   checks in at reception', 'Member joins fitness classes with trainers', 'System tracks attendance and workout frequency', 'Membership renewal   payment processed', 'Admin reviews member retention and class attendance'],
    endpoints: ['GET    /api/memberships                       ?type=&isActive=', 'POST   /api/members                          { name, email, phone? }', 'POST   /api/memberships                      { memberId, type }', 'GET    /api/members                          ?status=&page=&limit=', 'POST   /api/attendance/check-in               { memberId, classId? }', 'POST   /api/attendance/check-out              { memberId }', 'POST   /api/classes                          { name, trainerId, schedule, capacity, duration }', 'POST   /api/payments                         { memberId, amount, method, type }', 'GET    /api/dashboard/gym-summary'],
    metrics: ['Active members', 'Daily check-ins', 'Class attendance rate', 'Member retention rate', 'Monthly recurring revenue'],
    genericFeatures: ['Member Management', 'Membership Plans', 'Class Scheduling', 'Attendance Tracking', 'Payment & Renewal'],
  },

  coworking: {
    name: 'Coworking / Kantor Bersama',
    actors: ['Member', 'Staff', 'Admin'],
    entities: {
      Space: { fields: { name: 'string', type: 'SpaceType', description: 'string?', capacity: 'Int', pricePerHour: 'Float?', pricePerDay: 'Float?', pricePerMonth: 'Float?', amenities: 'string (JSON)?', status: 'SpaceStatus @default(AVAILABLE)', location: 'string?', image: 'string?', createdAt: 'DateTime @default(now())' }, enums: { SpaceType: ['HOT_DESK', 'FIXED_DESK', 'PRIVATE_OFFICE', 'MEETING_ROOM', 'EVENT_SPACE'], SpaceStatus: ['AVAILABLE', 'BOOKED', 'OCCUPIED', 'MAINTENANCE'] }, indexes: ['type', 'status'] },
      Booking: { fields: { bookingNumber: 'string @unique', memberId: 'string', spaceId: 'string', startTime: 'DateTime', endTime: 'DateTime', totalPrice: 'Float', status: 'BookStatus @default(PENDING)', purpose: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())' }, enums: { BookStatus: ['PENDING', 'CONFIRMED', 'CHECKED_IN', 'COMPLETED', 'CANCELLED'] }, indexes: ['memberId', 'spaceId', 'startTime', 'status'], relations: { belongsTo: ['Member', 'Space'] } },
      Member: { fields: { name: 'string', email: 'string @unique', phone: 'string?', company: 'string?', plan: 'string @default("CASUAL")', totalVisits: 'Int @default(0)', totalSpent: 'Float @default(0)', createdAt: 'DateTime @default(now())' } },
      Plan: { fields: { name: 'string @unique', description: 'string?', price: 'Float', duration: 'string', hoursIncluded: 'Int?', features: 'string (JSON)?', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' } },
      Payment: { fields: { bookingId: 'string?', memberId: 'string', planId: 'string?', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Booking', 'Member'] } },
    },
    flows: ['Guest browses available spaces and pricing plans', 'Member books a space (desk/room) for specific time', 'Member checks in   Staff confirms booking', 'Member uses the space with amenities', 'Member checks out   Staff inspects if needed', 'Payment processed   member leaves review'],
    endpoints: ['GET    /api/spaces                           ?type=&status=&capacity=&minPrice=&maxPrice=', 'POST   /api/bookings                         { memberId, spaceId, startTime, endTime }', 'GET    /api/bookings                         ?memberId=&status=&date=&page=&limit=', 'PATCH  /api/bookings/:id/status               { status }', 'POST   /api/check-in                         { bookingId }', 'POST   /api/check-out                        { bookingId }', 'POST   /api/payments                         { memberId, bookingId?, planId?, amount, method }', 'GET    /api/dashboard/coworking-summary'],
    metrics: ['Space utilization %', 'Average booking duration', 'Revenue per space', 'Member retention rate', 'Peak hours occupancy'],
    genericFeatures: ['Space Management', 'Booking System', 'Member Management', 'Plan & Pricing', 'Check-in/Check-out'],
  },

  pharmacy: {
    name: 'Pharmacy / Apotek',
    actors: ['Pharmacist', 'Customer', 'Admin'],
    entities: {
      Medicine: {
        fields: { name: 'string', sku: 'string @unique', category: 'string', price: 'Float', requiresPrescription: 'Boolean @default(false)', expiryDate: 'DateTime?', stock: 'Int @default(0)', minStock: 'Int @default(10)' },
        indexes: ['sku', 'category', 'stock'],
        relations: { hasMany: ['Prescription', 'Stock'] }
      },
      Prescription: {
        fields: { customerId: 'string', pharmacistId: 'string', medicineId: 'string', dosage: 'string', quantity: 'Int', status: 'RxStatus @default(PENDING)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { RxStatus: ['PENDING', 'FILLED', 'DISPENSED', 'CANCELLED'] },
        indexes: ['customerId', 'status'],
        relations: { belongsTo: ['Customer', 'Medicine'], hasMany: ['Sale'] }
      },
      Stock: {
        fields: { medicineId: 'string', batchNumber: 'string', quantity: 'Int', expiryDate: 'DateTime?', receivedAt: 'DateTime @default(now())' },
        indexes: ['medicineId', 'batchNumber'],
        relations: { belongsTo: ['Medicine', 'Supplier'] }
      },
      Supplier: {
        fields: { name: 'string', contact: 'string', phone: 'string', email: 'string?', address: 'string?', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Stock'] }
      },
      Sale: {
        fields: { prescriptionId: 'string?', customerId: 'string', medicineId: 'string', quantity: 'Int', totalPrice: 'Float', paymentMethod: 'string', soldAt: 'DateTime @default(now())' },
        indexes: ['customerId', 'soldAt'],
        relations: { belongsTo: ['Medicine', 'Customer'] }
      },
    },
    flows: ['Pharmacist checks stock levels for medicines', 'Customer brings prescription   pharmacist validates', 'Pharmacist dispenses medicine   stock decremented', 'Sale recorded   payment processed', 'Admin reconciles daily sales and stock adjustments'],
    endpoints: ['GET    /api/medicines                        ?category=&requiresPrescription=&search=&page=&limit=', 'POST   /api/medicines                        { name, sku, category, price, requiresPrescription, minStock }', 'GET    /api/prescriptions                     ?status=&customerId=&page=&limit=', 'POST   /api/prescriptions                     { customerId, medicineId, dosage, quantity }', 'PATCH  /api/prescriptions/:id/status           { status }', 'POST   /api/sales                             { prescriptionId?, customerId, medicineId, quantity, totalPrice, paymentMethod }', 'GET    /api/dashboard/pharmacy-summary'],
    metrics: ['Daily revenue', 'Prescriptions filled', 'Stock expiring soon', 'Medicine turnover rate', 'Customer visits'],
    genericFeatures: ['Manajemen Obat', 'Resep Obat', 'Inventory Stok', 'Penjualan', 'Laporan Apotek'],
  },

  laboratory: {
    name: 'Laboratory / Lab Kesehatan',
    actors: ['LabTech', 'Patient', 'Doctor', 'Admin'],
    entities: {
      Test: {
        fields: { name: 'string @unique', category: 'string', description: 'string?', price: 'Float', preparation: 'string?', turnaroundHours: 'Int', isActive: 'Boolean @default(true)' },
        indexes: ['category', 'isActive'],
        relations: { hasMany: ['Sample', 'Result'] }
      },
      Sample: {
        fields: { patientId: 'string', testId: 'string', labTechId: 'string', collectionDate: 'DateTime', sampleType: 'string', status: 'SampleStatus @default(COLLECTED)', notes: 'string?', receivedAt: 'DateTime?' },
        enums: { SampleStatus: ['COLLECTED', 'RECEIVED', 'PROCESSING', 'ANALYZED', 'REJECTED'] },
        indexes: ['patientId', 'testId', 'status'],
        relations: { belongsTo: ['Patient', 'Test', 'LabTech'] }
      },
      Result: {
        fields: { sampleId: 'string', testId: 'string', value: 'string', unit: 'string?', referenceRange: 'string?', isAbnormal: 'Boolean @default(false)', interpretation: 'string?', verifiedBy: 'string?', verifiedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['sampleId', 'testId', 'isAbnormal'],
        relations: { belongsTo: ['Sample', 'Test'] }
      },
      Patient: {
        fields: { name: 'string', phone: 'string @unique', email: 'string?', dateOfBirth: 'DateTime?', gender: 'string?', address: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Sample'] }
      },
      Appointment: {
        fields: { patientId: 'string', testId: 'string', appointmentDate: 'DateTime', status: 'ApptStatus @default(SCHEDULED)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ApptStatus: ['SCHEDULED', 'CHECKED_IN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['patientId', 'appointmentDate', 'status'],
        relations: { belongsTo: ['Patient', 'Test'] }
      },
    },
    flows: ['Patient registers for lab test   selects test panel', 'LabTech collects sample from patient at scheduled time', 'Sample is processed and analyzed in the lab', 'Results are verified and published for doctor review', 'Doctor interprets results and shares with patient'],
    endpoints: ['GET    /api/tests                            ?category=&isActive=&search=', 'POST   /api/appointments                     { patientId, testId, appointmentDate }', 'POST   /api/samples                          { patientId, testId, labTechId, sampleType }', 'GET    /api/samples                          ?patientId=&status=&dateFrom=', 'PATCH  /api/samples/:id/status                { status }', 'POST   /api/results                          { sampleId, testId, value, unit?, referenceRange? }', 'GET    /api/results/:patientId', 'GET    /api/dashboard/lab-summary'],
    metrics: ['Tests per day', 'Sample processing time', 'Abnormal result rate', 'Patient turnaround time', 'Revenue per test'],
    genericFeatures: ['Manajemen Test Lab', 'Sample Tracking', 'Hasil & Analisa', 'Jadwal Appointment', 'Laporan Lab'],
  },

  telemedicine: {
    name: 'Telemedicine / Konsultasi Online',
    actors: ['Doctor', 'Patient', 'Admin'],
    entities: {
      Consultation: {
        fields: { patientId: 'string', doctorId: 'string', appointmentId: 'string', startTime: 'DateTime', endTime: 'DateTime?', status: 'ConsStatus @default(SCHEDULED)', type: 'string @default("VIDEO")', notes: 'string?', summary: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ConsStatus: ['SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'MISSED'] },
        indexes: ['patientId', 'doctorId', 'startTime', 'status'],
        relations: { belongsTo: ['Patient', 'Doctor', 'Appointment'] }
      },
      Prescription: {
        fields: { consultationId: 'string', medicine: 'string', dosage: 'string', frequency: 'string', duration: 'string', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['consultationId'],
        relations: { belongsTo: ['Consultation'] }
      },
      Appointment: {
        fields: { patientId: 'string', doctorId: 'string', scheduledAt: 'DateTime', duration: 'Int @default(30)', status: 'ApptStatus @default(PENDING)', reason: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ApptStatus: ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['patientId', 'doctorId', 'scheduledAt', 'status'],
        relations: { belongsTo: ['Patient', 'Doctor'] }
      },
      Payment: {
        fields: { consultationId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['consultationId', 'status'],
        relations: { belongsTo: ['Consultation'] }
      },
      MedicalRecord: {
        fields: { patientId: 'string', consultationId: 'string', diagnosis: 'string?', symptoms: 'string?', treatment: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['patientId'],
        relations: { belongsTo: ['Patient', 'Consultation'] }
      },
    },
    flows: ['Patient books an appointment with a doctor online', 'Doctor accepts consultation   video/chat session begins', 'Doctor diagnoses patient and writes prescription', 'Prescription sent to patient   payment processed', 'Follow-up scheduled if needed   medical record updated'],
    endpoints: ['GET    /api/doctors                          ?specialty=&isAvailable=&rating=', 'POST   /api/appointments                     { patientId, doctorId, scheduledAt, reason }', 'GET    /api/appointments                     ?patientId=&status=&page=&limit=', 'POST   /api/consultations                    { patientId, doctorId, appointmentId, type }', 'PATCH  /api/consultations/:id/status          { status }', 'POST   /api/prescriptions                    { consultationId, medicine, dosage, frequency, duration }', 'POST   /api/payments                         { consultationId, amount, method }', 'GET    /api/medical-records/:patientId'],
    metrics: ['Consultations per day', 'Average response time', 'Patient satisfaction', 'Prescription rate', 'Revenue per consultation'],
    genericFeatures: ['Konsultasi Online', 'Jadwal Dokter', 'Resep Digital', 'Pembayaran', 'Rekam Medis'],
  },

  tutoring: {
    name: 'Tutoring / Bimbel',
    actors: ['Tutor', 'Student', 'Parent', 'Admin'],
    entities: {
      Session: {
        fields: { tutorId: 'string', studentId: 'string', subjectId: 'string', date: 'DateTime', startTime: 'DateTime', endTime: 'DateTime', status: 'SessStatus @default(SCHEDULED)', topic: 'string?', notes: 'string?', rating: 'Int?', createdAt: 'DateTime @default(now())' },
        enums: { SessStatus: ['SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['tutorId', 'studentId', 'date', 'status'],
        relations: { belongsTo: ['Tutor', 'Student', 'Subject'] }
      },
      Subject: {
        fields: { name: 'string @unique', level: 'string', description: 'string?', pricePerHour: 'Float', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Session'] }
      },
      Student: {
        fields: { name: 'string', parentId: 'string?', email: 'string?', phone: 'string?', grade: 'string?', school: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Parent'], hasMany: ['Session'] }
      },
      Payment: {
        fields: { sessionId: 'string?', studentId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', period: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['studentId', 'status'],
        relations: { belongsTo: ['Student'] }
      },
      Schedule: {
        fields: { tutorId: 'string', dayOfWeek: 'string', startTime: 'string', endTime: 'string', isRecurring: 'Boolean @default(true)' },
        indexes: ['tutorId', 'dayOfWeek'],
        relations: { belongsTo: ['Tutor'] }
      },
    },
    flows: ['Parent registers student and selects subjects', 'Student books tutoring session with a tutor', 'Tutor conducts the session   teaches and assigns homework', 'Student completes homework   tutor reviews and gives feedback', 'Admin generates monthly report and processes payments'],
    endpoints: ['GET    /api/subjects                         ?level=&isActive=', 'POST   /api/sessions                         { tutorId, studentId, subjectId, date, startTime, endTime }', 'GET    /api/sessions                         ?studentId=&tutorId=&status=&dateFrom=&page=&limit=', 'PATCH  /api/sessions/:id/status               { status }', 'POST   /api/homework                         { sessionId, title, description, dueDate }', 'POST   /api/payments                         { studentId, amount, method, period }', 'GET    /api/dashboard/tutoring-summary'],
    metrics: ['Sessions per week', 'Student satisfaction', 'Tutor utilization rate', 'Revenue per month', 'Homework completion rate'],
    genericFeatures: ['Manajemen Bimbel', 'Jadwal Tutor', 'Sesi Belajar', 'Pembayaran SPP', 'Laporan Progress'],
  },

  bootcamp: {
    name: 'Bootcamp / Pelatihan Intensif',
    actors: ['Mentor', 'Student', 'Admin'],
    entities: {
      Program: {
        fields: { name: 'string @unique', description: 'string?', duration: 'string', price: 'Float', maxStudents: 'Int', startDate: 'DateTime', endDate: 'DateTime', status: 'ProgStatus @default(DRAFT)', curriculum: 'string (JSON)?', isActive: 'Boolean @default(true)' },
        enums: { ProgStatus: ['DRAFT', 'OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['status', 'startDate'],
        relations: { hasMany: ['Module', 'Submission'] }
      },
      Module: {
        fields: { programId: 'string', title: 'string', description: 'string?', order: 'Int', duration: 'Int', materials: 'string (JSON)?', createdAt: 'DateTime @default(now())' },
        indexes: ['programId', 'order'],
        relations: { belongsTo: ['Program'], hasMany: ['Assignment'] }
      },
      Assignment: {
        fields: { moduleId: 'string', title: 'string', description: 'string?', dueDate: 'DateTime', maxScore: 'Int @default(100)', type: 'string @default("CODING")' },
        relations: { belongsTo: ['Module'], hasMany: ['Submission'] }
      },
      Submission: {
        fields: { assignmentId: 'string', studentId: 'string', fileUrl: 'string?', notes: 'string?', score: 'Int?', feedback: 'string?', status: 'SubStatus @default(PENDING)', submittedAt: 'DateTime @default(now())', gradedAt: 'DateTime?' },
        enums: { SubStatus: ['PENDING', 'SUBMITTED', 'GRADED', 'RESUBMIT'] },
        indexes: ['assignmentId', 'studentId', 'status'],
        relations: { belongsTo: ['Assignment', 'Student'] }
      },
      Review: {
        fields: { submissionId: 'string', mentorId: 'string', score: 'Int', feedback: 'string?', reviewedAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Submission', 'Mentor'] }
      },
    },
    flows: ['Student enrolls in a bootcamp program', 'Student progresses through modules sequentially', 'Student works on projects and assignments', 'Mentor reviews submissions and provides feedback', 'Student graduates upon completing all requirements'],
    endpoints: ['GET    /api/programs                         ?status=&isActive=&page=&limit=', 'POST   /api/programs                         { name, description, duration, price, maxStudents, startDate, endDate }', 'GET    /api/modules/:programId', 'POST   /api/assignments                      { moduleId, title, description, dueDate, maxScore }', 'POST   /api/submissions                      { assignmentId, studentId, fileUrl?, notes? }', 'PATCH  /api/submissions/:id/grade             { score, feedback }', 'GET    /api/dashboard/bootcamp-summary'],
    metrics: ['Enrollment rate', 'Module completion %', 'Graduation rate', 'Average score', 'Student satisfaction'],
    genericFeatures: ['Manajemen Program', 'Modul & Assignment', 'Submission Grading', 'Progress Student', 'Graduation'],
  },

  school_management: {
    name: 'School Management / Manajemen Sekolah',
    actors: ['Teacher', 'Student', 'Parent', 'Admin'],
    entities: {
      Class: {
        fields: { name: 'string', grade: 'string', section: 'string?', academicYear: 'string', teacherId: 'string', room: 'string?', capacity: 'Int @default(30)', createdAt: 'DateTime @default(now())' },
        indexes: ['grade', 'teacherId', 'academicYear'],
        relations: { belongsTo: ['Teacher'], hasMany: ['Student', 'Schedule'] }
      },
      Student: {
        fields: { name: 'string', nisn: 'string @unique', classId: 'string', dateOfBirth: 'DateTime?', gender: 'string?', address: 'string?', parentPhone: 'string?', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' },
        indexes: ['nisn', 'classId', 'status'],
        relations: { belongsTo: ['Class'], hasMany: ['Grade', 'Attendance'] }
      },
      Teacher: {
        fields: { name: 'string', nip: 'string @unique', email: 'string?', phone: 'string?', specialization: 'string?', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Class', 'Schedule'] }
      },
      Schedule: {
        fields: { classId: 'string', teacherId: 'string', subject: 'string', dayOfWeek: 'string', startTime: 'string', endTime: 'string', room: 'string?' },
        indexes: ['classId', 'teacherId', 'dayOfWeek'],
        relations: { belongsTo: ['Class', 'Teacher'] }
      },
      Grade: {
        fields: { studentId: 'string', classId: 'string', subject: 'string', semester: 'string', score: 'Float', grade: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['studentId', 'classId', 'semester'],
        relations: { belongsTo: ['Student', 'Class'] }
      },
      Attendance: {
        fields: { studentId: 'string', classId: 'string', date: 'DateTime', status: 'AttStatus @default(PRESENT)', notes: 'string?', recordedBy: 'string' },
        enums: { AttStatus: ['PRESENT', 'ABSENT', 'SICK', 'PERMIT', 'LATE'] },
        indexes: ['studentId', 'classId', 'date'],
        relations: { belongsTo: ['Student', 'Class'] }
      },
    },
    flows: ['Admin enrolls new students and assigns to classes', 'Teacher creates class schedule and records attendance', 'Teacher teaches lessons and assigns grades', 'Students receive report cards each semester', 'Admin generates academic reports and statistics'],
    endpoints: ['GET    /api/classes                          ?grade=&academicYear=&teacherId=', 'POST   /api/students                         { name, nisn, classId, dateOfBirth?, address? }', 'GET    /api/students                         ?classId=&status=&search=&page=&limit=', 'POST   /api/attendance                       { studentId, classId, date, status, notes? }', 'POST   /api/grades                           { studentId, classId, subject, semester, score }', 'GET    /api/grades/:studentId                 ?semester=', 'GET    /api/dashboard/school-summary'],
    metrics: ['Total students', 'Attendance rate', 'Average grade per class', 'Teacher workload', 'Graduation rate'],
    genericFeatures: ['Manajemen Kelas', 'Data Siswa', 'Absensi', 'Penilaian & Rapor', 'Jadwal Pelajaran'],
  },

  lms: {
    name: 'LMS / Learning Management',
    actors: ['Instructor', 'Learner', 'Admin'],
    entities: {
      Course: {
        fields: { title: 'string', description: 'string?', category: 'string?', level: 'string @default("BEGINNER")', price: 'Float @default(0)', thumbnail: 'string?', status: 'CourseStatus @default(DRAFT)', instructorId: 'string', duration: 'Int', createdAt: 'DateTime @default(now())' },
        enums: { CourseStatus: ['DRAFT', 'PUBLISHED', 'ARCHIVED'] },
        indexes: ['instructorId', 'category', 'status'],
        relations: { belongsTo: ['Instructor'], hasMany: ['Lesson', 'Quiz'] }
      },
      Lesson: {
        fields: { courseId: 'string', title: 'string', content: 'string (HTML)?', videoUrl: 'string?', order: 'Int', duration: 'Int', isFree: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        indexes: ['courseId', 'order'],
        relations: { belongsTo: ['Course'] }
      },
      Quiz: {
        fields: { courseId: 'string', title: 'string', description: 'string?', passingScore: 'Int @default(70)', maxAttempts: 'Int @default(3)', timeLimit: 'Int?', status: 'string @default("ACTIVE")' },
        indexes: ['courseId'],
        relations: { belongsTo: ['Course'], hasMany: ['Progress'] }
      },
      Progress: {
        fields: { learnerId: 'string', courseId: 'string', lessonId: 'string?', quizId: 'string?', score: 'Int?', completed: 'Boolean @default(false)', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['learnerId', 'courseId', 'completed'],
        relations: { belongsTo: ['Learner', 'Course'] }
      },
      Certificate: {
        fields: { learnerId: 'string', courseId: 'string', certificateNumber: 'string @unique', issuedAt: 'DateTime @default(now())', expiresAt: 'DateTime?', metadata: 'string (JSON)?' },
        indexes: ['learnerId', 'courseId'],
        relations: { belongsTo: ['Learner', 'Course'] }
      },
    },
    flows: ['Instructor creates and publishes a course with lessons', 'Learner browses courses and enrolls', 'Learner progresses through lessons sequentially', 'Learner takes quizzes to assess understanding', 'Learner earns certificate upon course completion'],
    endpoints: ['GET    /api/courses                          ?category=&level=&status=&search=&page=&limit=', 'POST   /api/courses                          { title, description?, category?, level, price, instructorId }', 'GET    /api/courses/:id/lessons', 'POST   /api/lessons                          { courseId, title, content?, videoUrl?, order, duration }', 'POST   /api/quizzes                          { courseId, title, description?, passingScore, maxAttempts }', 'POST   /api/progress                         { learnerId, courseId, lessonId?, quizId?, score? }', 'POST   /api/certificates                     { learnerId, courseId }', 'GET    /api/dashboard/lms-summary'],
    metrics: ['Total enrollments', 'Course completion rate', 'Average quiz score', 'Certificate issued', 'Revenue per course'],
    genericFeatures: ['Course Management', 'Lesson Delivery', 'Quiz & Assessment', 'Progress Tracking', 'Certification'],
  },

  personal_finance: {
    name: 'Personal Finance / Keuangan Pribadi',
    actors: ['User', 'Admin'],
    entities: {
      Transaction: {
        fields: { userId: 'string', categoryId: 'string', type: 'string @default("EXPENSE")', amount: 'Float', description: 'string?', date: 'DateTime', isRecurring: 'Boolean @default(false)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['userId', 'categoryId', 'date', 'type'],
        relations: { belongsTo: ['User', 'Category'] }
      },
      Category: {
        fields: { name: 'string', type: 'string', icon: 'string?', color: 'string?', budget: 'Float?', isActive: 'Boolean @default(true)' },
        indexes: ['type', 'isActive'],
        relations: { hasMany: ['Transaction'] }
      },
      Budget: {
        fields: { userId: 'string', categoryId: 'string', amount: 'Float', period: 'string @default("MONTHLY")', startDate: 'DateTime', endDate: 'DateTime?', spent: 'Float @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['userId', 'categoryId', 'period'],
        relations: { belongsTo: ['User', 'Category'] }
      },
      Account: {
        fields: { userId: 'string', name: 'string', type: 'string @default("CASH")', balance: 'Float @default(0)', currency: 'string @default("IDR")', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['userId', 'type'],
        relations: { belongsTo: ['User'] }
      },
      Goal: {
        fields: { userId: 'string', name: 'string', targetAmount: 'Float', currentAmount: 'Float @default(0)', deadline: 'DateTime?', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' },
        indexes: ['userId', 'status'],
        relations: { belongsTo: ['User'] }
      },
    },
    flows: ['User records daily income and expenses', 'System categorizes transactions automatically', 'User sets budgets per category for the month', 'User tracks spending against budgets', 'System generates monthly financial reports'],
    endpoints: ['GET    /api/transactions                      ?type=&categoryId=&dateFrom=&dateTo=&page=&limit=', 'POST   /api/transactions                      { userId, categoryId, type, amount, description?, date }', 'GET    /api/categories                        ?type=&isActive=', 'POST   /api/budgets                           { userId, categoryId, amount, period }', 'POST   /api/goals                            { userId, name, targetAmount, deadline? }', 'GET    /api/dashboard/finance-summary', 'GET    /api/reports/monthly                   ?month=&year='],
    metrics: ['Monthly savings rate', 'Budget adherence %', 'Net worth growth', 'Category spending breakdown', 'Goal progress %'],
    genericFeatures: ['Pencatatan Transaksi', 'Kategori & Budget', 'Laporan Keuangan', 'Target Tabungan', 'Dashboard Keuangan'],
  },

  cooperative: {
    name: 'Cooperative / Koperasi',
    actors: ['Member', 'Treasurer', 'Admin'],
    entities: {
      Member: {
        fields: { name: 'string', memberNumber: 'string @unique', phone: 'string', email: 'string?', address: 'string?', joinDate: 'DateTime', status: 'string @default("ACTIVE")', savingsBalance: 'Float @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['memberNumber', 'status'],
        relations: { hasMany: ['Savings', 'Loan'] }
      },
      Savings: {
        fields: { memberId: 'string', amount: 'Float', type: 'SavingsType @default(MANDATORY)', depositDate: 'DateTime', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { SavingsType: ['MANDATORY', 'VOLUNTARY', 'SPECIAL'] },
        indexes: ['memberId', 'depositDate'],
        relations: { belongsTo: ['Member'] }
      },
      Loan: {
        fields: { memberId: 'string', amount: 'Float', interestRate: 'Float', tenor: 'Int', remainingBalance: 'Float', status: 'LoanStatus @default(PENDING)', purpose: 'string?', approvedBy: 'string?', approvedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { LoanStatus: ['PENDING', 'APPROVED', 'ACTIVE', 'PAID', 'DEFAULTED'] },
        indexes: ['memberId', 'status'],
        relations: { belongsTo: ['Member'], hasMany: ['Installment'] }
      },
      Installment: {
        fields: { loanId: 'string', amount: 'Float', dueDate: 'DateTime', paidAt: 'DateTime?', status: 'string @default("PENDING")', lateFee: 'Float @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['loanId', 'status', 'dueDate'],
        relations: { belongsTo: ['Loan'] }
      },
      Dividend: {
        fields: { memberId: 'string', year: 'Int', amount: 'Float', status: 'string @default("PENDING")', distributedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['memberId', 'year'],
        relations: { belongsTo: ['Member'] }
      },
    },
    flows: ['New member registers and starts saving', 'Member applies for a loan with amount and tenor', 'Treasurer reviews and approves loan', 'Member repays loan in monthly installments', 'Annual dividend calculated and distributed to members'],
    endpoints: ['GET    /api/members                          ?status=&search=&page=&limit=', 'POST   /api/members                          { name, phone, email?, address? }', 'POST   /api/savings                          { memberId, amount, type }', 'POST   /api/loans                            { memberId, amount, interestRate, tenor, purpose }', 'GET    /api/loans                            ?status=&memberId=&page=&limit=', 'POST   /api/installments                     { loanId, amount }', 'POST   /api/dividends                        { memberId, year, amount }', 'GET    /api/dashboard/cooperative-summary'],
    metrics: ['Total savings', 'Loan disbursed', 'Repayment rate', 'Active members', 'Dividend payout'],
    genericFeatures: ['Manajemen Anggota', 'Simpanan', 'Pinjaman & Angsuran', 'SHU / Dividen', 'Laporan Koperasi'],
  },

  insurance: {
    name: 'Insurance / Asuransi',
    actors: ['Client', 'Agent', 'Adjuster', 'Admin'],
    entities: {
      Policy: {
        fields: { policyNumber: 'string @unique', clientId: 'string', agentId: 'string', type: 'PolicyType', premium: 'Float', coverageAmount: 'Float', startDate: 'DateTime', endDate: 'DateTime', status: 'PolStatus @default(ACTIVE)', terms: 'string (JSON)?', createdAt: 'DateTime @default(now())' },
        enums: { PolicyType: ['HEALTH', 'LIFE', 'AUTO', 'HOME', 'TRAVEL', 'BUSINESS'], PolStatus: ['ACTIVE', 'EXPIRED', 'CANCELLED', 'LAPSED'] },
        indexes: ['policyNumber', 'clientId', 'agentId', 'status'],
        relations: { belongsTo: ['Client', 'Agent'], hasMany: ['Premium', 'Claim'] }
      },
      Premium: {
        fields: { policyId: 'string', amount: 'Float', dueDate: 'DateTime', paidAt: 'DateTime?', status: 'string @default("PENDING")', paymentMethod: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['policyId', 'dueDate', 'status'],
        relations: { belongsTo: ['Policy'] }
      },
      Claim: {
        fields: { policyId: 'string', clientId: 'string', adjusterId: 'string?', incidentDate: 'DateTime', amount: 'Float', description: 'string', status: 'ClaimStatus @default(SUBMITTED)', documents: 'string (JSON)?', approvedAmount: 'Float?', settledAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { ClaimStatus: ['SUBMITTED', 'IN_REVIEW', 'APPROVED', 'REJECTED', 'SETTLED'] },
        indexes: ['policyId', 'clientId', 'status'],
        relations: { belongsTo: ['Policy', 'Client'] }
      },
      Payment: {
        fields: { policyId: 'string?', claimId: 'string?', amount: 'Float', type: 'string', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Policy'] }
      },
      Client: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', dateOfBirth: 'DateTime?', address: 'string?', idNumber: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Policy', 'Claim'] }
      },
    },
    flows: ['Client requests a quote   agent assesses risk', 'Agent submits application   policy is issued', 'Client pays premium   policy becomes active', 'Client files a claim   adjuster investigates', 'Claim is approved or rejected   settlement processed'],
    endpoints: ['GET    /api/policies                         ?status=&type=&clientId=&agentId=&page=&limit=', 'POST   /api/policies                         { clientId, agentId, type, premium, coverageAmount, startDate, endDate }', 'GET    /api/premiums                          ?policyId=&status=&dueDate=', 'PATCH  /api/premiums/:id/pay                  { paidAt, paymentMethod }', 'POST   /api/claims                            { policyId, clientId, incidentDate, amount, description }', 'GET    /api/claims                            ?status=&policyId=&page=&limit=', 'PATCH  /api/claims/:id/status                 { status, approvedAmount? }', 'GET    /api/dashboard/insurance-summary'],
    metrics: ['Active policies', 'Premium collection rate', 'Claim ratio', 'Average settlement time', 'Policy renewal rate'],
    genericFeatures: ['Manajemen Polis', 'Premi & Pembayaran', 'Klaim & Adjuster', 'Underwriting', 'Laporan Asuransi'],
  },

  warehouse: {
    name: 'Warehouse / Gudang',
    actors: ['Manager', 'Staff', 'Admin'],
    entities: {
      Product: {
        fields: { name: 'string', sku: 'string @unique', category: 'string', unit: 'string', weight: 'Float?', dimensions: 'string?', isHazardous: 'Boolean @default(false)', minStock: 'Int @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['sku', 'category'],
        relations: { hasMany: ['Bin', 'StockMovement'] }
      },
      Bin: {
        fields: { code: 'string @unique', zone: 'string', aisle: 'string', rack: 'string', level: 'string', capacity: 'Int', currentLoad: 'Int @default(0)', productId: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['code', 'zone', 'productId'],
        relations: { belongsTo: ['Product'] }
      },
      StockMovement: {
        fields: { productId: 'string', binId: 'string?', type: 'MovementType', quantity: 'Int', referenceNumber: 'string?', staffId: 'string', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { MovementType: ['INBOUND', 'OUTBOUND', 'TRANSFER', 'ADJUSTMENT'] },
        indexes: ['productId', 'type', 'createdAt'],
        relations: { belongsTo: ['Product', 'Bin'] }
      },
      Receiving: {
        fields: { productId: 'string', binId: 'string', supplierName: 'string', quantity: 'Int', receivedBy: 'string', purchaseOrder: 'string?', receivedAt: 'DateTime @default(now())', notes: 'string?' },
        indexes: ['productId', 'receivedAt'],
        relations: { belongsTo: ['Product', 'Bin'] }
      },
      Shipping: {
        fields: { productId: 'string', binId: 'string', destination: 'string', quantity: 'Int', shippedBy: 'string', trackingNumber: 'string?', shippedAt: 'DateTime @default(now())', notes: 'string?' },
        indexes: ['productId', 'shippedAt'],
        relations: { belongsTo: ['Product', 'Bin'] }
      },
    },
    flows: ['Staff receives incoming goods and assigns bin locations', 'Products are stored in designated bin locations', 'Staff picks items from bins when orders come in', 'Items are packed for shipping', 'Manager reviews stock levels and generates reports'],
    endpoints: ['GET    /api/products                         ?category=&search=&page=&limit=', 'POST   /api/receiving                        { productId, binId, supplierName, quantity, purchaseOrder? }', 'POST   /api/stock-movements                  { productId, binId?, type, quantity, notes? }', 'GET    /api/stock-movements                  ?productId=&type=&dateFrom=&dateTo=', 'POST   /api/shipping                         { productId, binId, destination, quantity, trackingNumber? }', 'GET    /api/bins                             ?zone=&productId=', 'GET    /api/dashboard/warehouse-summary'],
    metrics: ['Inventory accuracy %', 'Bin utilization %', 'Order picking time', 'Receiving throughput', 'Stock turnover rate'],
    genericFeatures: ['Manajemen Produk', 'Bin & Lokasi', 'Stok Masuk/Keluar', 'Picking & Packing', 'Laporan Gudang'],
  },

  cold_chain: {
    name: 'Cold Chain / Rantai Dingin',
    actors: ['Operator', 'Manager', 'Admin'],
    entities: {
      Shipment: {
        fields: { trackingNumber: 'string @unique', productId: 'string', vehicleId: 'string', origin: 'string', destination: 'string', departureTime: 'DateTime', estimatedArrival: 'DateTime', status: 'ShipStatus @default(LOADING)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ShipStatus: ['LOADING', 'IN_TRANSIT', 'DELIVERED', 'DELAYED', 'CANCELLED'] },
        indexes: ['trackingNumber', 'vehicleId', 'status'],
        relations: { belongsTo: ['Product', 'Vehicle'], hasMany: ['TemperatureLog'] }
      },
      Sensor: {
        fields: { code: 'string @unique', vehicleId: 'string?', location: 'string', type: 'string @default("TEMPERATURE")', unit: 'string @default("CELSIUS")', minThreshold: 'Float', maxThreshold: 'Float', isActive: 'Boolean @default(true)', lastReading: 'Float?', lastReadAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['code', 'vehicleId', 'isActive'],
        relations: { belongsTo: ['Vehicle'], hasMany: ['TemperatureLog'] }
      },
      TemperatureLog: {
        fields: { sensorId: 'string', shipmentId: 'string', temperature: 'Float', humidity: 'Float?', recordedAt: 'DateTime @default(now())' },
        indexes: ['sensorId', 'shipmentId', 'recordedAt'],
        relations: { belongsTo: ['Sensor', 'Shipment'] }
      },
      Product: {
        fields: { name: 'string', sku: 'string @unique', category: 'string', minTemp: 'Float', maxTemp: 'Float', unit: 'string', createdAt: 'DateTime @default(now())' },
        indexes: ['sku', 'category'],
        relations: { hasMany: ['Shipment'] }
      },
      Vehicle: {
        fields: { plateNumber: 'string @unique', type: 'string', capacity: 'Float', isActive: 'Boolean @default(true)', lastMaintenance: 'DateTime?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Shipment', 'Sensor'] }
      },
    },
    flows: ['Operator loads temperature-sensitive products into vehicle', 'Sensors begin monitoring temperature during transit', 'System alerts if temperature exceeds thresholds', 'Shipment delivered   temperature logs verified', 'Manager reviews chain integrity report'],
    endpoints: ['POST   /api/shipments                        { productId, vehicleId, origin, destination, departureTime }', 'GET    /api/shipments                        ?status=&vehicleId=&dateFrom=&page=&limit=', 'PATCH  /api/shipments/:id/status              { status }', 'POST   /api/sensors                          { code, vehicleId?, type, minThreshold, maxThreshold }', 'POST   /api/temperature-logs                 { sensorId, shipmentId, temperature, humidity? }', 'GET    /api/temperature-logs/:shipmentId', 'GET    /api/dashboard/coldchain-summary'],
    metrics: ['Temperature breach rate', 'On-time delivery %', 'Sensor uptime', 'Average transit temperature', 'Product spoilage rate'],
    genericFeatures: ['Manajemen Pengiriman', 'Sensor Monitoring', 'Temperature Logs', 'Alert System', 'Cold Chain Report'],
  },

  freight: {
    name: 'Freight / Pengiriman Barang',
    actors: ['Shipper', 'Carrier', 'Admin'],
    entities: {
      Shipment: {
        fields: { trackingNumber: 'string @unique', shipperId: 'string', carrierId: 'string', origin: 'string', destination: 'string', weight: 'Float', volume: 'Float?', declaredValue: 'Float?', status: 'ShipStatus @default(QUOTED)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ShipStatus: ['QUOTED', 'BOOKED', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED'] },
        indexes: ['trackingNumber', 'shipperId', 'carrierId', 'status'],
        relations: { belongsTo: ['Shipper', 'Carrier'], hasMany: ['Tracking', 'Payment'] }
      },
      Quote: {
        fields: { shipperId: 'string', origin: 'string', destination: 'string', weight: 'Float', volume: 'Float?', estimatedCost: 'Float', validUntil: 'DateTime', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' },
        indexes: ['shipperId', 'status'],
        relations: { belongsTo: ['Shipper'] }
      },
      Tracking: {
        fields: { shipmentId: 'string', location: 'string', status: 'string', description: 'string?', timestamp: 'DateTime @default(now())' },
        indexes: ['shipmentId', 'timestamp'],
        relations: { belongsTo: ['Shipment'] }
      },
      Payment: {
        fields: { shipmentId: 'string', shipperId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['shipmentId', 'status'],
        relations: { belongsTo: ['Shipment', 'Shipper'] }
      },
      Document: {
        fields: { shipmentId: 'string', type: 'string', fileUrl: 'string', uploadedAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Shipment'] }
      },
    },
    flows: ['Shipper requests a freight quote with weight and destination', 'Carrier provides pricing   shipper books shipment', 'Carrier picks up cargo from shipper', 'Cargo is in transit   tracking events recorded', 'Cargo delivered   payment processed and documents finalized'],
    endpoints: ['POST   /api/quotes                           { shipperId, origin, destination, weight, volume? }', 'GET    /api/quotes                           ?shipperId=&status=', 'POST   /api/shipments                        { shipperId, carrierId, origin, destination, weight, volume? }', 'GET    /api/shipments                        ?status=&carrierId=&page=&limit=', 'PATCH  /api/shipments/:id/status              { status }', 'POST   /api/tracking                         { shipmentId, location, status, description? }', 'POST   /api/payments                         { shipmentId, shipperId, amount, method }', 'GET    /api/dashboard/freight-summary'],
    metrics: ['Shipments per month', 'On-time delivery rate', 'Average transit time', 'Revenue per shipment', 'Customer satisfaction'],
    genericFeatures: ['Manajemen Pengiriman', 'Quote & Booking', 'Tracking Real-time', 'Pembayaran', 'Laporan Freight'],
  },

  homestay: {
    name: 'Homestay / Penginapan Rumah',
    actors: ['Host', 'Guest', 'Admin'],
    entities: {
      Property: {
        fields: { hostId: 'string', name: 'string', description: 'string?', address: 'string', city: 'string', maxGuests: 'Int', pricePerNight: 'Float', amenities: 'string (JSON)?', status: 'PropStatus @default(ACTIVE)', createdAt: 'DateTime @default(now())' },
        enums: { PropStatus: ['ACTIVE', 'INACTIVE', 'MAINTENANCE'] },
        indexes: ['hostId', 'city', 'status'],
        relations: { belongsTo: ['Host'], hasMany: ['Room', 'Booking', 'Review'] }
      },
      Room: {
        fields: { propertyId: 'string', name: 'string', capacity: 'Int', pricePerNight: 'Float', isAvailable: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['propertyId', 'isAvailable'],
        relations: { belongsTo: ['Property'] }
      },
      Booking: {
        fields: { propertyId: 'string', roomId: 'string?', guestId: 'string', checkIn: 'DateTime', checkOut: 'DateTime', guests: 'Int', totalPrice: 'Float', status: 'BookStatus @default(PENDING)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { BookStatus: ['PENDING', 'CONFIRMED', 'CHECKED_IN', 'CHECKED_OUT', 'CANCELLED'] },
        indexes: ['propertyId', 'guestId', 'checkIn', 'status'],
        relations: { belongsTo: ['Property', 'Guest', 'Room'] }
      },
      Guest: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', idNumber: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Booking', 'Review'] }
      },
      Payment: {
        fields: { bookingId: 'string', guestId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['bookingId', 'status'],
        relations: { belongsTo: ['Booking', 'Guest'] }
      },
      Review: {
        fields: { propertyId: 'string', guestId: 'string', bookingId: 'string', rating: 'Int', comment: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['propertyId', 'guestId'],
        relations: { belongsTo: ['Property', 'Guest'] }
      },
    },
    flows: ['Host lists property with photos and pricing', 'Guest searches and books a property for specific dates', 'Guest checks in   host welcomes and provides keys', 'Guest stays and enjoys amenities', 'Guest checks out   host inspects property', 'Payment released to host   guest leaves review'],
    endpoints: ['GET    /api/properties                       ?city=&maxGuests=&minPrice=&maxPrice=&page=&limit=', 'POST   /api/properties                       { hostId, name, description?, address, city, maxGuests, pricePerNight }', 'POST   /api/bookings                         { propertyId, roomId?, guestId, checkIn, checkOut, guests }', 'GET    /api/bookings                         ?guestId=&status=&page=&limit=', 'PATCH  /api/bookings/:id/status               { status }', 'POST   /api/payments                         { bookingId, guestId, amount, method }', 'POST   /api/reviews                          { propertyId, guestId, bookingId, rating, comment? }', 'GET    /api/dashboard/homestay-summary'],
    metrics: ['Occupancy rate', 'Average stay duration', 'Revenue per property', 'Guest satisfaction', 'Booking conversion rate'],
    genericFeatures: ['Manajemen Properti', 'Booking System', 'Check-in/Check-out', 'Payment & Payout', 'Reviews & Rating'],
  },

  villa_rental: {
    name: 'Villa Rental / Sewa Villa',
    actors: ['Owner', 'Guest', 'Admin'],
    entities: {
      Villa: {
        fields: { ownerId: 'string', name: 'string', description: 'string?', location: 'string', city: 'string', maxGuests: 'Int', bedrooms: 'Int', bathrooms: 'Int', pricePerNight: 'Float', cleaningFee: 'Float @default(0)', amenities: 'string (JSON)?', status: 'VillaStatus @default(ACTIVE)', images: 'string (JSON)?', createdAt: 'DateTime @default(now())' },
        enums: { VillaStatus: ['ACTIVE', 'INACTIVE', 'BOOKED', 'MAINTENANCE'] },
        indexes: ['ownerId', 'city', 'status'],
        relations: { belongsTo: ['Owner'], hasMany: ['Booking', 'Amenity'] }
      },
      Booking: {
        fields: { villaId: 'string', guestId: 'string', checkIn: 'DateTime', checkOut: 'DateTime', guests: 'Int', totalPrice: 'Float', status: 'BookStatus @default(PENDING)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { BookStatus: ['PENDING', 'CONFIRMED', 'CHECKED_IN', 'CHECKED_OUT', 'CANCELLED'] },
        indexes: ['villaId', 'guestId', 'checkIn', 'status'],
        relations: { belongsTo: ['Villa', 'Guest'] }
      },
      Guest: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', idNumber: 'string?', idPhoto: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Booking'] }
      },
      Payment: {
        fields: { bookingId: 'string', guestId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', depositAmount: 'Float @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['bookingId', 'status'],
        relations: { belongsTo: ['Booking', 'Guest'] }
      },
      Amenity: {
        fields: { villaId: 'string', name: 'string', description: 'string?', isIncluded: 'Boolean @default(true)', price: 'Float?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Villa'] }
      },
    },
    flows: ['Guest searches for villas by location and dates', 'Guest books a villa   payment required for confirmation', 'Guest pays deposit   booking is confirmed', 'Guest checks in and enjoys the villa', 'Guest checks out   owner inspects property', 'Remaining payment processed   guest reviews'],
    endpoints: ['GET    /api/villas                           ?city=&maxGuests=&minPrice=&maxPrice=&page=&limit=', 'POST   /api/villas                           { ownerId, name, description?, location, city, maxGuests, bedrooms, bathrooms, pricePerNight }', 'POST   /api/bookings                         { villaId, guestId, checkIn, checkOut, guests }', 'GET    /api/bookings                         ?villaId=&status=&dateFrom=&page=&limit=', 'PATCH  /api/bookings/:id/status               { status }', 'POST   /api/payments                         { bookingId, guestId, amount, method, depositAmount? }', 'GET    /api/dashboard/villa-summary'],
    metrics: ['Occupancy rate', 'Average booking value', 'Revenue per villa', 'Guest satisfaction', 'Booking lead time'],
    genericFeatures: ['Manajemen Villa', 'Booking System', 'Payment & Deposit', 'Check-in/Check-out', 'Reviews'],
  },

  guest_house: {
    name: 'Guest House / Losmen',
    actors: ['Receptionist', 'Guest', 'Admin'],
    entities: {
      Room: {
        fields: { roomNumber: 'string @unique', type: 'RoomType', pricePerNight: 'Float', capacity: 'Int', isAvailable: 'Boolean @default(true)', floor: 'Int?', amenities: 'string (JSON)?', status: 'string @default("AVAILABLE")', createdAt: 'DateTime @default(now())' },
        enums: { RoomType: ['STANDARD', 'DELUXE', 'SUITE', 'FAMILY'] },
        indexes: ['roomNumber', 'type', 'isAvailable'],
        relations: { hasMany: ['Reservation'] }
      },
      Reservation: {
        fields: { guestId: 'string', roomId: 'string', checkIn: 'DateTime', checkOut: 'DateTime', guests: 'Int', totalPrice: 'Float', status: 'ResStatus @default(PENDING)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ResStatus: ['PENDING', 'CONFIRMED', 'CHECKED_IN', 'CHECKED_OUT', 'CANCELLED'] },
        indexes: ['guestId', 'roomId', 'checkIn', 'status'],
        relations: { belongsTo: ['Guest', 'Room'] }
      },
      Guest: {
        fields: { name: 'string', email: 'string?', phone: 'string', idNumber: 'string?', address: 'string?', isReturning: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Reservation'] }
      },
      Payment: {
        fields: { reservationId: 'string', guestId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['reservationId', 'status'],
        relations: { belongsTo: ['Reservation', 'Guest'] }
      },
      Service: {
        fields: { name: 'string', description: 'string?', price: 'Float', category: 'string', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Reservation'] }
      },
    },
    flows: ['Guest searches room availability and makes reservation', 'Receptionist confirms reservation and checks guest in', 'Guest stays and can request additional services', 'Guest checks out   receptionist processes payment', 'Payment settled and guest record updated'],
    endpoints: ['GET    /api/rooms                            ?type=&isAvailable=&capacity=&page=&limit=', 'POST   /api/reservations                     { guestId, roomId, checkIn, checkOut, guests }', 'GET    /api/reservations                     ?guestId=&status=&dateFrom=&page=&limit=', 'PATCH  /api/reservations/:id/status           { status }', 'POST   /api/payments                         { reservationId, guestId, amount, method }', 'GET    /api/dashboard/guesthouse-summary'],
    metrics: ['Occupancy rate', 'Average stay length', 'Revenue per room', 'Guest return rate', 'Booking conversion'],
    genericFeatures: ['Manajemen Kamar', 'Reservasi', 'Check-in/Check-out', 'Pembayaran', 'Layanan Tambahan'],
  },

  resort: {
    name: 'Resort / Resort Wisata',
    actors: ['Receptionist', 'Guest', 'Staff', 'Manager'],
    entities: {
      Room: {
        fields: { roomNumber: 'string @unique', type: 'RoomType', pricePerNight: 'Float', capacity: 'Int', maxAdults: 'Int', maxChildren: 'Int', isAvailable: 'Boolean @default(true)', view: 'string?', amenities: 'string (JSON)?', status: 'string @default("AVAILABLE")', createdAt: 'DateTime @default(now())' },
        enums: { RoomType: ['STANDARD', 'DELUXE', 'SUITE', 'VILLA', 'PENTHOUSE'] },
        indexes: ['roomNumber', 'type', 'isAvailable'],
        relations: { hasMany: ['Reservation'] }
      },
      Reservation: {
        fields: { guestId: 'string', roomId: 'string', checkIn: 'DateTime', checkOut: 'DateTime', adults: 'Int', children: 'Int', totalPrice: 'Float', status: 'ResStatus @default(PENDING)', specialRequests: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ResStatus: ['PENDING', 'CONFIRMED', 'CHECKED_IN', 'CHECKED_OUT', 'CANCELLED'] },
        indexes: ['guestId', 'roomId', 'checkIn', 'status'],
        relations: { belongsTo: ['Guest', 'Room'], hasMany: ['Payment', 'Activity'] }
      },
      Guest: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', nationality: 'string?', idNumber: 'string?', idPhoto: 'string?', isVIP: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Reservation', 'Review'] }
      },
      Activity: {
        fields: { reservationId: 'string?', guestId: 'string', name: 'string', description: 'string?', date: 'DateTime', time: 'string', duration: 'Int', price: 'Float @default(0)', capacity: 'Int', bookedCount: 'Int @default(0)', status: 'string @default("AVAILABLE")' },
        indexes: ['reservationId', 'date'],
        relations: { belongsTo: ['Reservation'] }
      },
      Payment: {
        fields: { reservationId: 'string', guestId: 'string', amount: 'Float', method: 'string', type: 'string @default("ROOM")', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['reservationId', 'status'],
        relations: { belongsTo: ['Reservation', 'Guest'] }
      },
      Spa: {
        fields: { name: 'string', description: 'string?', duration: 'Int', price: 'Float', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Reservation'] }
      },
    },
    flows: ['Guest books a room for specific dates', 'Guest arrives   receptionist checks in and assigns room', 'Guest enjoys resort activities and spa', 'Staff provides housekeeping and room service', 'Guest checks out   all charges are settled', 'Guest provides feedback and review'],
    endpoints: ['GET    /api/rooms                            ?type=&isAvailable=&capacity=&page=&limit=', 'POST   /api/reservations                     { guestId, roomId, checkIn, checkOut, adults, children }', 'GET    /api/reservations                     ?status=&dateFrom=&page=&limit=', 'PATCH  /api/reservations/:id/status           { status }', 'POST   /api/activities                       { reservationId?, guestId, name, date, time, duration, price }', 'POST   /api/spa/bookings                     { reservationId?, guestId, spaId, date, time }', 'POST   /api/payments                         { reservationId, guestId, amount, method, type }', 'GET    /api/dashboard/resort-summary'],
    metrics: ['Occupancy rate', 'ADR (Average Daily Rate)', 'RevPAR', 'Guest satisfaction', 'Activity participation rate'],
    genericFeatures: ['Manajemen Kamar', 'Reservasi Tamu', 'Activities & Spa', 'Housekeeping', 'Billing & Payment'],
  },

  help_desk: {
    name: 'Help Desk / Layanan Pelanggan',
    actors: ['Agent', 'Customer', 'Admin'],
    entities: {
      Ticket: {
        fields: { ticketNumber: 'string @unique', customerId: 'string', agentId: 'string?', categoryId: 'string', subject: 'string', description: 'string', priority: 'PriorityType @default(MEDIUM)', status: 'TicketStatus @default(OPEN)', slaDeadline: 'DateTime?', resolvedAt: 'DateTime?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        enums: { PriorityType: ['LOW', 'MEDIUM', 'HIGH', 'URGENT'], TicketStatus: ['OPEN', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'REOPENED'] },
        indexes: ['ticketNumber', 'customerId', 'agentId', 'status', 'priority'],
        relations: { belongsTo: ['Customer', 'Agent', 'Category'], hasMany: ['Response'] }
      },
      Customer: {
        fields: { name: 'string', email: 'string @unique', phone: 'string?', company: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Ticket'] }
      },
      Response: {
        fields: { ticketId: 'string', userId: 'string', message: 'string', attachments: 'string (JSON)?', isInternal: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        indexes: ['ticketId', 'createdAt'],
        relations: { belongsTo: ['Ticket'] }
      },
      Category: {
        fields: { name: 'string @unique', description: 'string?', slaHours: 'Int @default(24)', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Ticket'] }
      },
      SLA: {
        fields: { ticketId: 'string', priority: 'string', deadline: 'DateTime', breached: 'Boolean @default(false)', breachedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['ticketId', 'breached'],
        relations: { belongsTo: ['Ticket'] }
      },
    },
    flows: ['Customer submits a support ticket with issue details', 'System assigns ticket to available agent based on category', 'Agent responds to customer and works on resolution', 'Agent marks ticket as resolved   customer confirms', 'Ticket is closed   satisfaction survey sent'],
    endpoints: ['GET    /api/tickets                          ?status=&priority=&agentId=&customerId=&page=&limit=', 'POST   /api/tickets                          { customerId, categoryId, subject, description, priority? }', 'PATCH  /api/tickets/:id/assign               { agentId }', 'PATCH  /api/tickets/:id/status                { status }', 'POST   /api/responses                        { ticketId, userId, message, isInternal? }', 'GET    /api/categories                       ?isActive=', 'GET    /api/dashboard/helpdesk-summary'],
    metrics: ['Tickets resolved per day', 'Average response time', 'SLA compliance %', 'Customer satisfaction score', 'First response time'],
    genericFeatures: ['Ticket Management', 'Auto-assignment', 'SLA Tracking', 'Knowledge Base', 'Customer Satisfaction'],
  },

  loyalty_program: {
    name: 'Loyalty Program / Program Loyalitas',
    actors: ['Member', 'Merchant', 'Admin'],
    entities: {
      Member: {
        fields: { name: 'string', email: 'string @unique', phone: 'string?', totalPoints: 'Int @default(0)', lifetimePoints: 'Int @default(0)', tierId: 'string?', joinDate: 'DateTime', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' },
        indexes: ['email', 'tierId', 'status'],
        relations: { belongsTo: ['Tier'], hasMany: ['Points', 'Redemption'] }
      },
      Points: {
        fields: { memberId: 'string', merchantId: 'string?', amount: 'Int', type: 'string @default("EARNED")', source: 'string', expiresAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['memberId', 'type', 'expiresAt'],
        relations: { belongsTo: ['Member', 'Merchant'] }
      },
      Reward: {
        fields: { name: 'string', description: 'string?', pointsRequired: 'Int', merchantId: 'string?', category: 'string', stock: 'Int @default(0)', isActive: 'Boolean @default(true)', expiresAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['merchantId', 'category', 'isActive'],
        relations: { belongsTo: ['Merchant'], hasMany: ['Redemption'] }
      },
      Redemption: {
        fields: { memberId: 'string', rewardId: 'string', pointsSpent: 'Int', status: 'string @default("PENDING")', redeemedAt: 'DateTime @default(now())', fulfilledAt: 'DateTime?' },
        indexes: ['memberId', 'status'],
        relations: { belongsTo: ['Member', 'Reward'] }
      },
      Tier: {
        fields: { name: 'string @unique', minPoints: 'Int @default(0)', multiplier: 'Float @default(1)', benefits: 'string (JSON)?', color: 'string?', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Member'] }
      },
    },
    flows: ['Customer registers as loyalty member', 'Member earns points through purchases and activities', 'Member browses and redeems rewards with points', 'Member may advance to higher tier with more benefits', 'System checks for point expiration and sends reminders'],
    endpoints: ['POST   /api/members                          { name, email, phone? }', 'GET    /api/members                          ?tier=&status=&search=&page=&limit=', 'POST   /api/points                           { memberId, amount, source }', 'GET    /api/rewards                          ?category=&merchantId=&isActive=', 'POST   /api/redeem                           { memberId, rewardId }', 'GET    /api/tiers                            ?isActive=', 'GET    /api/dashboard/loyalty-summary'],
    metrics: ['Active members', 'Points earned per month', 'Redemption rate', 'Tier upgrade rate', 'Member retention %'],
    genericFeatures: ['Member Management', 'Points System', 'Rewards Catalog', 'Tier Management', 'Analytics'],
  },

  sales_pipeline: {
    name: 'Sales Pipeline / Pipeline Penjualan',
    actors: ['Sales', 'Manager', 'Admin'],
    entities: {
      Lead: {
        fields: { name: 'string', company: 'string?', email: 'string?', phone: 'string', source: 'string', score: 'Int @default(0)', status: 'LeadStatus @default(NEW)', assignedTo: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        enums: { LeadStatus: ['NEW', 'CONTACTED', 'QUALIFIED', 'DISQUALIFIED', 'CONVERTED'] },
        indexes: ['status', 'assignedTo', 'score'],
        relations: { belongsTo: ['Sales'], hasMany: ['Activity'] }
      },
      Deal: {
        fields: { leadId: 'string?', contactId: 'string?', name: 'string', value: 'Float', stage: 'DealStage', probability: 'Int @default(10)', expectedCloseDate: 'DateTime?', status: 'string @default("OPEN")', notes: 'string?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        enums: { DealStage: ['PROSPECTING', 'QUALIFICATION', 'PROPOSAL', 'NEGOTIATION', 'CLOSED_WON', 'CLOSED_LOST'] },
        indexes: ['stage', 'salesId', 'value'],
        relations: { belongsTo: ['Sales'], hasMany: ['Activity'] }
      },
      Activity: {
        fields: { leadId: 'string?', dealId: 'string?', type: 'ActivityType', subject: 'string', description: 'string?', dueDate: 'DateTime?', completed: 'Boolean @default(false)', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { ActivityType: ['CALL', 'EMAIL', 'MEETING', 'DEMO', 'TASK'] },
        indexes: ['leadId', 'dealId', 'type', 'dueDate'],
        relations: { belongsTo: ['Lead', 'Deal'] }
      },
      Pipeline: {
        fields: { name: 'string @unique', stages: 'string (JSON)?', isDefault: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Deal'] }
      },
      Forecast: {
        fields: { period: 'string', totalValue: 'Float', weightedValue: 'Float', dealsCount: 'Int', confidence: 'Float @default(0)', generatedAt: 'DateTime @default(now())' },
        indexes: ['period']
      },
    },
    flows: ['Sales generates leads from multiple sources', 'Sales qualifies leads through discovery calls', 'Sales creates proposals and sends to prospects', 'Sales negotiates terms and handles objections', 'Deal is won   contract signed and handoff to delivery'],
    endpoints: ['GET    /api/leads                           ?status=&source=&assignedTo=&search=&page=&limit=', 'POST   /api/leads                           { name, company?, email?, phone, source, notes? }', 'PATCH  /api/leads/:id/status                 { status }', 'GET    /api/deals                            ?stage=&salesId=&page=&limit=', 'POST   /api/deals                            { leadId?, name, value, stage, probability, expectedCloseDate? }', 'PATCH  /api/deals/:id/stage                  { stage }', 'POST   /api/activities                       { leadId?, dealId?, type, subject, description?, dueDate? }', 'GET    /api/forecast                         ?period='],
    metrics: ['Lead conversion rate', 'Pipeline value (Rp)', 'Average deal size', 'Win rate %', 'Sales cycle length'],
    genericFeatures: ['Lead Management', 'Sales Pipeline', 'Aktivitas Follow-up', 'Forecasting', 'Dashboard Sales'],
  },

  project_management: {
    name: 'Project Management / Manajemen Proyek',
    actors: ['Manager', 'Member', 'Admin'],
    entities: {
      Project: {
        fields: { name: 'string', description: 'string?', startDate: 'DateTime', endDate: 'DateTime?', status: 'ProjStatus @default(PLANNING)', priority: 'string @default("MEDIUM")', budget: 'Float?', managerId: 'string', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        enums: { ProjStatus: ['PLANNING', 'IN_PROGRESS', 'ON_HOLD', 'COMPLETED', 'CANCELLED'] },
        indexes: ['managerId', 'status', 'priority'],
        relations: { belongsTo: ['Manager'], hasMany: ['Task', 'Milestone', 'Timesheet', 'Document'] }
      },
      Task: {
        fields: { projectId: 'string', title: 'string', description: 'string?', assigneeId: 'string?', priority: 'string @default("MEDIUM")', status: 'TaskStatus @default(TODO)', dueDate: 'DateTime?', estimatedHours: 'Float?', actualHours: 'Float @default(0)', createdAt: 'DateTime @default(now())' },
        enums: { TaskStatus: ['TODO', 'IN_PROGRESS', 'IN_REVIEW', 'DONE', 'CANCELLED'] },
        indexes: ['projectId', 'assigneeId', 'status'],
        relations: { belongsTo: ['Project', 'Member'] }
      },
      Milestone: {
        fields: { projectId: 'string', name: 'string', description: 'string?', dueDate: 'DateTime', status: 'string @default("PENDING")', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['projectId', 'status'],
        relations: { belongsTo: ['Project'] }
      },
      Timesheet: {
        fields: { projectId: 'string', memberId: 'string', date: 'DateTime', hours: 'Float', description: 'string?', billable: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['projectId', 'memberId', 'date'],
        relations: { belongsTo: ['Project', 'Member'] }
      },
      Document: {
        fields: { projectId: 'string', title: 'string', fileUrl: 'string', fileType: 'string', uploadedBy: 'string', createdAt: 'DateTime @default(now())' },
        indexes: ['projectId'],
        relations: { belongsTo: ['Project'] }
      },
    },
    flows: ['Manager creates project with timeline and team', 'Manager assigns tasks to team members', 'Members update task progress and log hours', 'Manager reviews timesheets and task completion', 'Project completed   deliverables archived and report generated'],
    endpoints: ['GET    /api/projects                         ?status=&managerId=&page=&limit=', 'POST   /api/projects                         { name, description?, startDate, endDate?, budget?, managerId }', 'GET    /api/tasks                            ?projectId=&assigneeId=&status=&page=&limit=', 'POST   /api/tasks                            { projectId, title, description?, assigneeId?, dueDate? }', 'PATCH  /api/tasks/:id/status                  { status }', 'POST   /api/timesheets                       { projectId, memberId, date, hours, description? }', 'POST   /api/milestones                       { projectId, name, dueDate }', 'GET    /api/dashboard/project-summary'],
    metrics: ['Project completion rate', 'Task completion %', 'Budget adherence', 'Team utilization', 'On-time delivery rate'],
    genericFeatures: ['Manajemen Proyek', 'Task Board', 'Timesheet', 'Milestone Tracking', 'Laporan Proyek'],
  },

  task_management: {
    name: 'Task Management / Manajemen Tugas',
    actors: ['User', 'Admin'],
    entities: {
      Task: {
        fields: { userId: 'string', listId: 'string?', title: 'string', description: 'string?', priority: 'string @default("MEDIUM")', status: 'TaskStatus @default(TODO)', dueDate: 'DateTime?', estimatedMinutes: 'Int?', isRecurring: 'Boolean @default(false)', recurrenceRule: 'string?', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        enums: { TaskStatus: ['TODO', 'IN_PROGRESS', 'DONE', 'ARCHIVED'] },
        indexes: ['userId', 'listId', 'status', 'priority', 'dueDate'],
        relations: { belongsTo: ['User', 'List'], hasMany: ['Label', 'Comment', 'Attachment'] }
      },
      List: {
        fields: { userId: 'string', name: 'string', color: 'string?', icon: 'string?', isDefault: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        indexes: ['userId'],
        relations: { belongsTo: ['User'], hasMany: ['Task'] }
      },
      Label: {
        fields: { name: 'string', color: 'string', userId: 'string' },
        indexes: ['userId'],
        relations: { belongsTo: ['User'] }
      },
      Comment: {
        fields: { taskId: 'string', userId: 'string', content: 'string', createdAt: 'DateTime @default(now())' },
        indexes: ['taskId'],
        relations: { belongsTo: ['Task', 'User'] }
      },
      Attachment: {
        fields: { taskId: 'string', fileName: 'string', fileUrl: 'string', fileSize: 'Int?', uploadedAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Task'] }
      },
    },
    flows: ['User creates a task with title and due date', 'User organizes tasks into lists and adds labels', 'User works on tasks and marks progress', 'User reviews completed tasks and archives', 'Old completed tasks are archived automatically'],
    endpoints: ['GET    /api/lists                            ?userId=', 'POST   /api/lists                            { userId, name, color?, icon? }', 'GET    /api/tasks                            ?listId=&status=&priority=&dueDate=&page=&limit=', 'POST   /api/tasks                            { userId, listId?, title, description?, priority?, dueDate? }', 'PATCH  /api/tasks/:id/status                  { status }', 'POST   /api/comments                         { taskId, userId, content }', 'GET    /api/dashboard/task-summary'],
    metrics: ['Tasks completed per day', ['Tasks completed per day', 'Task completion rate'], 'Average completion time', 'Tasks by priority', 'Overdue task rate'],
    genericFeatures: ['Task Management', 'Lists & Labels', 'Priorities & Due Dates', 'Comments', 'Productivity Analytics'],
  },

  note_taking: {
    name: 'Note Taking / Catatan',
    actors: ['User'],
    entities: {
      Notebook: {
        fields: { name: 'string @unique', description: 'string?', color: 'string?', icon: 'string?', isDefault: 'Boolean @default(false)', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        relations: { hasMany: ['Note'] }
      },
      Note: {
        fields: { notebookId: 'string', title: 'string', content: 'string (HTML)?', isPinned: 'Boolean @default(false)', isArchived: 'Boolean @default(false)', tags: 'string (JSON)?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        indexes: ['notebookId', 'isPinned', 'isArchived', 'updatedAt'],
        relations: { belongsTo: ['Notebook'], hasMany: ['Tag', 'Attachment'] }
      },
      Tag: {
        fields: { name: 'string @unique', color: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Note'] }
      },
      Attachment: {
        fields: { noteId: 'string', fileName: 'string', fileUrl: 'string', fileType: 'string', fileSize: 'Int?', uploadedAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Note'] }
      },
    },
    flows: ['User creates a notebook for organizing notes', 'User writes a note with rich text content', 'User organizes notes with tags and pinning', 'User searches and filters notes by keywords', 'User shares notes with others or archives old notes'],
    endpoints: ['GET    /api/notebooks                        ?isDefault=', 'POST   /api/notebooks                        { name, description?, color?, icon? }', 'GET    /api/notes                            ?notebookId=&tag=&search=&page=&limit=', 'POST   /api/notes                            { notebookId, title, content?, isPinned? }', 'PATCH  /api/notes/:id                         { title?, content?, isPinned?, isArchived? }', 'GET    /api/notes/search                     ?q='],
    metrics: ['Notes created per day', 'Active notebooks', 'Average note length', 'Search usage frequency', 'Tags per note'],
    genericFeatures: ['Notebook Organization', 'Rich Text Notes', 'Tags & Pinning', 'Search & Filter', 'Sharing & Export'],
  },

  okr_tracking: {
    name: 'OKR Tracking / Manajemen OKR',
    actors: ['User', 'Manager', 'Admin'],
    entities: {
      Objective: {
        fields: { title: 'string', description: 'string?', ownerId: 'string', period: 'string', status: 'ObjStatus @default(DRAFT)', progress: 'Int @default(0)', weight: 'Int @default(1)', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        enums: { ObjStatus: ['DRAFT', 'ACTIVE', 'ACHIEVED', 'CANCELLED'] },
        indexes: ['ownerId', 'period', 'status'],
        relations: { belongsTo: ['User'], hasMany: ['KeyResult'] }
      },
      KeyResult: {
        fields: { objectiveId: 'string', title: 'string', description: 'string?', type: 'string @default("PERCENTAGE")', startValue: 'Float @default(0)', currentValue: 'Float @default(0)', targetValue: 'Float', unit: 'string?', status: 'string @default("NOT_STARTED")', ownerId: 'string', createdAt: 'DateTime @default(now())' },
        indexes: ['objectiveId', 'ownerId', 'status'],
        relations: { belongsTo: ['Objective', 'User'] }
      },
      Initiative: {
        fields: { keyResultId: 'string', title: 'string', description: 'string?', ownerId: 'string', status: 'string @default("TODO")', dueDate: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['keyResultId', 'ownerId', 'status'],
        relations: { belongsTo: ['KeyResult', 'User'] }
      },
      CheckIn: {
        fields: { keyResultId: 'string', userId: 'string', previousValue: 'Float', currentValue: 'Float', confidence: 'Int?', comment: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['keyResultId', 'createdAt'],
        relations: { belongsTo: ['KeyResult', 'User'] }
      },
      Score: {
        fields: { objectiveId: 'string', period: 'string', overallProgress: 'Float @default(0)', keyResultsCount: 'Int', achievedCount: 'Int', calculatedAt: 'DateTime @default(now())' },
        indexes: ['objectiveId', 'period'],
        relations: { belongsTo: ['Objective'] }
      },
    },
    flows: ['Manager sets quarterly objectives and key results', 'Teams align their OKRs with company objectives', 'Users track progress with weekly check-ins', 'Manager reviews progress during mid-quarter', 'Scores calculated at end of quarter   results documented'],
    endpoints: ['GET    /api/objectives                       ?period=&ownerId=&status=&page=&limit=', 'POST   /api/objectives                       { title, description?, ownerId, period }', 'POST   /api/key-results                     { objectiveId, title, type, targetValue, startValue?, ownerId }', 'PATCH  /api/key-results/:id/progress          { currentValue }', 'POST   /api/check-ins                        { keyResultId, userId, previousValue, currentValue, confidence?, comment? }', 'GET    /api/dashboard/okr-summary             ?period='],
    metrics: ['OKR completion rate', 'Key result progress', 'Check-in frequency', 'Confidence trend', 'Period-over-period growth'],
    genericFeatures: ['Objective Management', 'Key Results Tracking', 'Check-ins', 'Progress Dashboard', 'Quarterly Review'],
  },

  content_subscription: {
    name: 'Content Subscription / Langganan Konten',
    actors: ['Creator', 'Subscriber', 'Admin'],
    entities: {
      Content: {
        fields: { creatorId: 'string', title: 'string', description: 'string?', type: 'string @default("POST")', body: 'string (HTML)?', mediaUrl: 'string?', planId: 'string?', isExclusive: 'Boolean @default(false)', status: 'string @default("DRAFT")', publishedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['creatorId', 'planId', 'status', 'publishedAt'],
        relations: { belongsTo: ['Creator', 'Plan'] }
      },
      Plan: {
        fields: { creatorId: 'string', name: 'string', description: 'string?', price: 'Float', billingPeriod: 'string @default("MONTHLY")', features: 'string (JSON)?', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['creatorId', 'isActive'],
        relations: { belongsTo: ['Creator'], hasMany: ['Content', 'Subscription'] }
      },
      Subscription: {
        fields: { subscriberId: 'string', creatorId: 'string', planId: 'string', startDate: 'DateTime', endDate: 'DateTime', status: 'SubStatus @default(ACTIVE)', autoRenew: 'Boolean @default(true)', cancelledAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { SubStatus: ['ACTIVE', 'CANCELLED', 'EXPIRED', 'PAUSED'] },
        indexes: ['subscriberId', 'creatorId', 'planId', 'status'],
        relations: { belongsTo: ['Subscriber', 'Creator', 'Plan'] }
      },
      Payment: {
        fields: { subscriptionId: 'string', subscriberId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['subscriptionId', 'status'],
        relations: { belongsTo: ['Subscription', 'Subscriber'] }
      },
      Analytics: {
        fields: { creatorId: 'string', period: 'string', subscribers: 'Int', revenue: 'Float', views: 'Int', engagement: 'Float?', calculatedAt: 'DateTime @default(now())' },
        indexes: ['creatorId', 'period']
      },
    },
    flows: ['Creator publishes exclusive content for subscribers', 'Subscriber signs up for a paid subscription plan', 'Subscriber gains access to exclusive content', 'Creator gets paid   subscription revenue analytics', 'Creator analyzes subscriber growth and revenue trends'],
    endpoints: ['GET    /api/plans                            ?creatorId=&isActive=', 'POST   /api/plans                            { creatorId, name, description?, price, billingPeriod }', 'GET    /api/content                          ?creatorId=&planId=&status=&page=&limit=', 'POST   /api/subscriptions                    { subscriberId, creatorId, planId }', 'GET    /api/subscriptions                    ?subscriberId=&status=', 'PATCH  /api/subscriptions/:id/status          { status }', 'POST   /api/payments                         { subscriptionId, subscriberId, amount, method }', 'GET    /api/dashboard/subscription-summary'],
    metrics: ['Subscriber count', 'Monthly recurring revenue', 'Churn rate', 'Content engagement', 'Revenue per subscriber'],
    genericFeatures: ['Content Management', 'Subscription Plans', 'Member Access', 'Payment Processing', 'Creator Analytics'],
  },

  podcast_platform: {
    name: 'Podcast Platform / Platform Podcast',
    actors: ['Host', 'Listener', 'Admin'],
    entities: {
      Podcast: {
        fields: { hostId: 'string', title: 'string', description: 'string?', coverArt: 'string?', category: 'string', language: 'string @default("id")', isExplicit: 'Boolean @default(false)', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        indexes: ['hostId', 'category', 'status'],
        relations: { belongsTo: ['Host'], hasMany: ['Episode', 'Subscription'] }
      },
      Episode: {
        fields: { podcastId: 'string', title: 'string', description: 'string?', audioUrl: 'string', duration: 'Int', episodeNumber: 'Int', season: 'Int @default(1)', status: 'string @default("DRAFT")', publishedAt: 'DateTime?', listenCount: 'Int @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['podcastId', 'episodeNumber', 'status', 'publishedAt'],
        relations: { belongsTo: ['Podcast'] }
      },
      Subscription: {
        fields: { listenerId: 'string', podcastId: 'string', subscribedAt: 'DateTime @default(now())' },
        indexes: ['listenerId', 'podcastId'],
        relations: { belongsTo: ['Listener', 'Podcast'] }
      },
      Analytics: {
        fields: { podcastId: 'string', episodeId: 'string?', period: 'string', listens: 'Int', uniqueListeners: 'Int', avgListenDuration: 'Float?', completionRate: 'Float?', calculatedAt: 'DateTime @default(now())' },
        indexes: ['podcastId', 'episodeId', 'period']
      },
      Payment: {
        fields: { podcastId: 'string', hostId: 'string', amount: 'Float', type: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['podcastId', 'status'],
        relations: { belongsTo: ['Podcast', 'Host'] }
      },
    },
    flows: ['Host records and uploads a new episode', 'Episode is published to subscribers', 'Listeners subscribe and stream episodes', 'Host monetizes through ads or listener support', 'Host reviews analytics on listener engagement'],
    endpoints: ['GET    /api/podcasts                         ?category=&language=&status=&page=&limit=', 'POST   /api/podcasts                         { hostId, title, description?, category, coverArt? }', 'POST   /api/episodes                         { podcastId, title, audioUrl, duration, description? }', 'GET    /api/episodes/:podcastId               ?status=&page=&limit=', 'POST   /api/subscriptions                    { listenerId, podcastId }', 'GET    /api/analytics/:podcastId              ?period=', 'GET    /api/dashboard/podcast-summary'],
    metrics: ['Total subscribers', 'Episode downloads', 'Avg listen duration', 'Completion rate', 'Monetization revenue'],
    genericFeatures: ['Podcast Management', 'Episode Publishing', 'Subscriber Base', 'Monetization', 'Analytics Dashboard'],
  },

  template_marketplace: {
    name: 'Template Marketplace / Marketplace Template',
    actors: ['Creator', 'Buyer', 'Admin'],
    entities: {
      Template: {
        fields: { creatorId: 'string', title: 'string', description: 'string?', categoryId: 'string', price: 'Float @default(0)', fileUrl: 'string', previewUrl: 'string?', format: 'string', tags: 'string (JSON)?', downloadCount: 'Int @default(0)', status: 'string @default("PENDING")', createdAt: 'DateTime @default(now())' },
        indexes: ['creatorId', 'categoryId', 'status', 'price'],
        relations: { belongsTo: ['Creator', 'Category'], hasMany: ['Purchase', 'Review'] }
      },
      Category: {
        fields: { name: 'string @unique', description: 'string?', icon: 'string?', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Template'] }
      },
      Purchase: {
        fields: { buyerId: 'string', templateId: 'string', price: 'Float', status: 'string @default("PENDING")', purchasedAt: 'DateTime @default(now())' },
        indexes: ['buyerId', 'templateId'],
        relations: { belongsTo: ['Buyer', 'Template'] }
      },
      Review: {
        fields: { templateId: 'string', buyerId: 'string', rating: 'Int', comment: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['templateId', 'buyerId'],
        relations: { belongsTo: ['Template', 'Buyer'] }
      },
      Payout: {
        fields: { creatorId: 'string', amount: 'Float', period: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['creatorId', 'status'],
        relations: { belongsTo: ['Creator'] }
      },
    },
    flows: ['Creator uploads a template with preview and details', 'Template is reviewed and listed in marketplace', 'Buyer browses categories and purchases template', 'Buyer downloads template after payment', 'Creator receives payout based on sales'],
    endpoints: ['GET    /api/templates                        ?categoryId=&format=&minPrice=&maxPrice=&search=&page=&limit=', 'POST   /api/templates                        { creatorId, title, description?, categoryId, price, fileUrl, format }', 'GET    /api/categories                       ?isActive=', 'POST   /api/purchases                        { buyerId, templateId }', 'GET    /api/purchases/:buyerId', 'POST   /api/reviews                          { templateId, buyerId, rating, comment? }', 'GET    /api/dashboard/template-summary'],
    metrics: ['Templates sold', 'Revenue per creator', 'Average rating', 'Download count', 'Category distribution'],
    genericFeatures: ['Template Management', 'Category Browse', 'Purchase & Download', 'Creator Payouts', 'Rating & Reviews'],
  },

  legal: {
    name: 'Legal / Law Firm Ops',
    actors: ['Client', 'Lawyer', 'Paralegal', 'Admin'],
    entities: {
      CaseFile: { fields: { caseNumber: 'string @unique', clientId: 'string', lawyerId: 'string?', title: 'string', status: 'string @default("OPEN")', priority: 'string @default("MEDIUM")', openedAt: 'DateTime @default(now())', closedAt: 'DateTime?' }, indexes: ['caseNumber', 'status'], relations: { belongsTo: ['Client', 'Lawyer'], hasMany: ['Document', 'Task'] } },
      Document: { fields: { caseId: 'string', title: 'string', type: 'string', fileUrl: 'string', version: 'Int @default(1)', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['CaseFile'] } },
      Task: { fields: { caseId: 'string', title: 'string', status: 'string @default("TODO")', dueDate: 'DateTime?', assigneeId: 'string?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['CaseFile'] } },
      Client: { fields: { name: 'string', email: 'string?', phone: 'string?', company: 'string?', createdAt: 'DateTime @default(now())' }, relations: { hasMany: ['CaseFile'] } },
      Lawyer: { fields: { name: 'string', email: 'string?', specialization: 'string?', isActive: 'Boolean @default(true)' }, relations: { hasMany: ['CaseFile'] } },
    },
    flows: ['Client submit legal request   admin create case file', 'Lawyer review case dan assign task', 'Paralegal upload evidence dan supporting documents', 'Lawyer update status sampai closure', 'Client receive progress update dan final outcome'],
    endpoints: ['POST   /api/cases                          { clientId, title, priority }', 'GET    /api/cases                           ?status=&lawyerId=&page=&limit=', 'PATCH  /api/cases/:id                       { status, lawyerId }', 'POST   /api/cases/:id/documents              { title, type, fileUrl }', 'POST   /api/cases/:id/tasks                  { title, dueDate, assigneeId }', 'GET    /api/dashboard/legal-summary'],
    metrics: ['Open cases', 'Case resolution time', 'Documents uploaded', 'Tasks completed on time'],
    genericFeatures: ['Case Tracking', 'Document Management', 'Task Assignment', 'Progress Updates'],
  },

  document_management: {
    name: 'Document Management / Records',
    actors: ['User', 'Reviewer', 'Admin'],
    entities: {
      Folder: { fields: { name: 'string', parentId: 'string?', ownerId: 'string', createdAt: 'DateTime @default(now())' }, relations: { hasMany: ['Document'] } },
      Document: { fields: { folderId: 'string?', title: 'string', fileUrl: 'string', mimeType: 'string', version: 'Int @default(1)', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Folder'] } },
      AuditLog: { fields: { documentId: 'string', action: 'string', actorId: 'string', note: 'string?', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Document'] } },
    },
    flows: ['User upload dokumen ke folder tertentu', 'Reviewer memberi status, catatan, atau approval', 'User mencari dokumen via filter dan keyword', 'System menyimpan version history dan audit log', 'Admin mengatur akses dan retention policy'],
    endpoints: ['POST   /api/folders                         { name, parentId? }', 'POST   /api/documents                       { folderId?, title, fileUrl, mimeType }', 'GET    /api/documents                       ?search=&folderId=&status=&page=&limit=', 'PATCH  /api/documents/:id                   { title?, status? }', 'GET    /api/documents/:id/audit', 'GET    /api/dashboard/documents-summary'],
    metrics: ['Documents stored', 'Search success rate', 'Approval turnaround', 'Active users'],
    genericFeatures: ['Foldering', 'Versioning', 'Audit log', 'Access control'],
  },

  ticketing: {
    name: 'Ticketing / Issue Tracking',
    actors: ['Customer', 'Agent', 'Team Lead', 'Admin'],
    entities: {
      Ticket: { fields: { ticketNumber: 'string @unique', customerId: 'string', assigneeId: 'string?', title: 'string', category: 'string?', priority: 'string @default("MEDIUM")', status: 'string @default("OPEN")', createdAt: 'DateTime @default(now())', closedAt: 'DateTime?' }, relations: { hasMany: ['Comment', 'Attachment'] } },
      Comment: { fields: { ticketId: 'string', authorId: 'string', body: 'string', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Ticket'] } },
      Attachment: { fields: { ticketId: 'string', fileUrl: 'string', fileName: 'string', createdAt: 'DateTime @default(now())' }, relations: { belongsTo: ['Ticket'] } },
    },
    flows: ['Customer buat ticket baru dengan kategori dan urgency', 'System assign ticket ke agent yang tepat', 'Agent respon, minta info tambahan, atau resolve issue', 'Team lead pantau SLA dan eskalasi ticket lambat', 'Ticket ditutup setelah customer konfirmasi selesai'],
    endpoints: ['POST   /api/tickets                        { title, category, priority, description }', 'GET    /api/tickets                         ?status=&priority=&assigneeId=&page=&limit=', 'PATCH  /api/tickets/:id                     { status, assigneeId }', 'POST   /api/tickets/:id/comments            { body }', 'POST   /api/tickets/:id/attachments         { fileUrl, fileName }', 'GET    /api/dashboard/support-summary'],
    metrics: ['First response time', 'Resolution time', 'Open tickets', 'SLA compliance'],
    genericFeatures: ['Ticket inbox', 'Assignment', 'SLA monitor', 'Conversation thread'],
  },

  fishery: {
    name: 'Fishery / Perikanan',
    actors: ['Farmer', 'Worker', 'Buyer', 'Admin'],
    entities: {
      Pond: {
        fields: { code: 'string @unique', name: 'string', area: 'Float', depth: 'Float?', waterType: 'string @default("FRESHWATER")', fishType: 'string', capacity: 'Int', status: 'string @default("ACTIVE")', location: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['code', 'status'],
        relations: { hasMany: ['Fish', 'Feed'] }
      },
      Fish: {
        fields: { pondId: 'string', batchNumber: 'string', species: 'string', quantity: 'Int', avgWeight: 'Float', stockingDate: 'DateTime', status: 'string @default("GROWING")', createdAt: 'DateTime @default(now())' },
        indexes: ['pondId', 'batchNumber', 'status'],
        relations: { belongsTo: ['Pond'], hasMany: ['Harvest'] }
      },
      Feed: {
        fields: { pondId: 'string', feedType: 'string', quantity: 'Float', unit: 'string @default("KG")', cost: 'Float', date: 'DateTime', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['pondId', 'date'],
        relations: { belongsTo: ['Pond'] }
      },
      Harvest: {
        fields: { pondId: 'string', fishId: 'string', quantity: 'Int', totalWeight: 'Float', harvestDate: 'DateTime', status: 'string @default("COMPLETED")', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['pondId', 'harvestDate'],
        relations: { belongsTo: ['Pond', 'Fish'], hasMany: ['Sale'] }
      },
      Sale: {
        fields: { harvestId: 'string', buyerId: 'string', quantity: 'Int', weight: 'Float', pricePerKg: 'Float', totalPrice: 'Float', saleDate: 'DateTime', createdAt: 'DateTime @default(now())' },
        indexes: ['harvestId', 'buyerId', 'saleDate'],
        relations: { belongsTo: ['Harvest', 'Buyer'] }
      },
      Inventory: {
        fields: { productName: 'string', quantity: 'Float', unit: 'string', minStock: 'Float @default(0)', updatedAt: 'DateTime @default(now())' }
      },
    },
    flows: ['Farmer stocks ponds with fish fry', 'Worker provides feed according to schedule', 'Farmer monitors fish growth and pond conditions', 'Fish are harvested when reaching target weight', 'Harvested fish sold to buyers at market price'],
    endpoints: ['GET    /api/ponds                            ?status=&fishType=', 'POST   /api/ponds                            { code, name, area, waterType, fishType, capacity }', 'POST   /api/fish                            { pondId, batchNumber, species, quantity, avgWeight }', 'POST   /api/feed                            { pondId, feedType, quantity, unit, cost }', 'POST   /api/harvest                         { pondId, fishId, quantity, totalWeight }', 'POST   /api/sales                           { harvestId, buyerId, quantity, weight, pricePerKg }', 'GET    /api/dashboard/fishery-summary'],
    metrics: ['Fish survival rate', 'Feed conversion ratio', 'Harvest weight per pond', 'Revenue per cycle', 'Average selling price'],
    genericFeatures: ['Manajemen Kolam', 'Pakan & Perawatan', 'Panen & Hasil', 'Penjualan Ikan', 'Laporan Perikanan'],
  },

  plantation: {
    name: 'Plantation / Perkebunan',
    actors: ['Farmer', 'Worker', 'Buyer', 'Admin'],
    entities: {
      Field: {
        fields: { code: 'string @unique', name: 'string', area: 'Float', location: 'string', soilType: 'string?', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' },
        indexes: ['code', 'status'],
        relations: { hasMany: ['Crop', 'Planting'] }
      },
      Crop: {
        fields: { name: 'string', variety: 'string?', growingPeriod: 'Int', expectedYield: 'Float', unit: 'string @default("KG")', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Planting', 'Harvest'] }
      },
      Planting: {
        fields: { fieldId: 'string', cropId: 'string', plantDate: 'DateTime', quantity: 'Int', spacing: 'string?', status: 'string @default("GROWING")', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['fieldId', 'cropId', 'status'],
        relations: { belongsTo: ['Field', 'Crop'], hasMany: ['Harvest'] }
      },
      Harvest: {
        fields: { plantingId: 'string', fieldId: 'string', cropId: 'string', quantity: 'Float', unit: 'string', quality: 'string?', harvestDate: 'DateTime', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['plantingId', 'harvestDate'],
        relations: { belongsTo: ['Planting', 'Field', 'Crop'], hasMany: ['Sale'] }
      },
      Sale: {
        fields: { harvestId: 'string', buyerId: 'string', quantity: 'Float', pricePerUnit: 'Float', totalPrice: 'Float', saleDate: 'DateTime', createdAt: 'DateTime @default(now())' },
        indexes: ['harvestId', 'buyerId', 'saleDate'],
        relations: { belongsTo: ['Harvest', 'Buyer'] }
      },
      Inventory: {
        fields: { productName: 'string', quantity: 'Float', unit: 'string', minStock: 'Float @default(0)', updatedAt: 'DateTime @default(now())' }
      },
    },
    flows: ['Farmer prepares land and plants crops', 'Worker maintains crops   watering, fertilizing, pest control', 'Crops grow and are monitored for readiness', 'Harvest is collected and sorted by quality', 'Produce is processed and sold to buyers'],
    endpoints: ['GET    /api/fields                           ?status=&location=', 'POST   /api/fields                           { code, name, area, location, soilType? }', 'POST   /api/plantings                       { fieldId, cropId, plantDate, quantity }', 'POST   /api/harvests                        { plantingId, fieldId, cropId, quantity, unit, quality? }', 'GET    /api/harvests                         ?fieldId=&dateFrom=&dateTo=', 'POST   /api/sales                           { harvestId, buyerId, quantity, pricePerUnit }', 'GET    /api/dashboard/plantation-summary'],
    metrics: ['Yield per hectare', ['Yield per hectare', 'Crop survival rate'], 'Harvest cycle time', 'Revenue per field', 'Crop quality distribution'],
    genericFeatures: ['Manajemen Lahan', 'Tanam & Perawatan', 'Panen & Sortir', 'Penjualan Hasil', 'Laporan Perkebunan'],
  },

  greenhouse: {
    name: 'Greenhouse / Rumah Kaca',
    actors: ['Farmer', 'Tech', 'Admin'],
    entities: {
      Crop: {
        fields: { name: 'string', variety: 'string?', growingPeriod: 'Int', expectedYield: 'Float', unit: 'string @default("KG")', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Harvest'] }
      },
      Sensor: {
        fields: { code: 'string @unique', type: 'SensorType', unit: 'string', location: 'string', minThreshold: 'Float', maxThreshold: 'Float', isActive: 'Boolean @default(true)', lastReading: 'Float?', lastReadAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { SensorType: ['TEMPERATURE', 'HUMIDITY', 'SOIL_MOISTURE', 'LIGHT', 'CO2', 'PH'] },
        indexes: ['code', 'type', 'isActive'],
        relations: { hasMany: ['EnvironmentLog'] }
      },
      EnvironmentLog: {
        fields: { sensorId: 'string', reading: 'Float', recordedAt: 'DateTime @default(now())' },
        indexes: ['sensorId', 'recordedAt'],
        relations: { belongsTo: ['Sensor'] }
      },
      Harvest: {
        fields: { cropId: 'string', quantity: 'Float', unit: 'string', quality: 'string?', harvestDate: 'DateTime', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['cropId', 'harvestDate'],
        relations: { belongsTo: ['Crop'], hasMany: ['Sale'] }
      },
      Sale: {
        fields: { harvestId: 'string', buyerId: 'string', quantity: 'Float', pricePerUnit: 'Float', totalPrice: 'Float', saleDate: 'DateTime', createdAt: 'DateTime @default(now())' },
        indexes: ['harvestId', 'saleDate'],
        relations: { belongsTo: ['Harvest', 'Buyer'] }
      },
    },
    flows: ['Farmer plants crops in greenhouse beds', 'Sensors monitor temperature, humidity and soil moisture', 'System adjusts environment automatically or alerts tech', 'Crops are harvested at peak quality', 'Produce is sold fresh to buyers'],
    endpoints: ['GET    /api/sensors                          ?type=&isActive=', 'POST   /api/sensors                          { code, type, unit, location, minThreshold, maxThreshold }', 'GET    /api/environment-logs                 ?sensorId=&dateFrom=&dateTo=', 'POST   /api/harvests                         { cropId, quantity, unit, quality? }', 'POST   /api/sales                           { harvestId, buyerId, quantity, pricePerUnit }', 'GET    /api/dashboard/greenhouse-summary'],
    metrics: ['Yield per sq meter', ['Yield per sq meter', 'Environment stability %'], 'Energy efficiency', 'Crop cycle time', 'Sensor uptime'],
    genericFeatures: ['Crop Management', 'Sensor Monitoring', 'Environment Control', 'Harvest Tracking', 'Sales & Yield'],
  },

  car_wash: {
    name: 'Car Wash / Cuci Mobil',
    actors: ['Customer', 'Worker', 'Owner'],
    entities: {
      Service: {
        fields: { name: 'string @unique', description: 'string?', price: 'Float', duration: 'Int', category: 'string @default("EXTERIOR")', isActive: 'Boolean @default(true)' },
        indexes: ['category', 'isActive'],
        relations: { hasMany: ['Order'] }
      },
      Order: {
        fields: { customerId: 'string', vehicleId: 'string', serviceId: 'string', workerId: 'string?', status: 'OrderStatus @default(PENDING)', queueNumber: 'Int?', notes: 'string?', startedAt: 'DateTime?', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { OrderStatus: ['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['customerId', 'vehicleId', 'workerId', 'status'],
        relations: { belongsTo: ['Customer', 'Vehicle', 'Service', 'Worker'] }
      },
      Vehicle: {
        fields: { plateNumber: 'string @unique', customerId: 'string', brand: 'string', model: 'string', color: 'string?', year: 'Int?', createdAt: 'DateTime @default(now())' },
        indexes: ['plateNumber', 'customerId'],
        relations: { belongsTo: ['Customer'], hasMany: ['Order'] }
      },
      Customer: {
        fields: { name: 'string', phone: 'string @unique', email: 'string?', totalVisits: 'Int @default(0)', isMember: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Order', 'Vehicle'] }
      },
      Payment: {
        fields: { orderId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Order'] }
      },
      Package: {
        fields: { name: 'string @unique', description: 'string?', services: 'string (JSON)?', price: 'Float', visits: 'Int @default(1)', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Order'] }
      },
    },
    flows: ['Customer arrives at car wash', 'Customer selects service package', 'Worker washes the car   interior and exterior', 'Car is dried and quality checked', 'Customer pays and leaves'],
    endpoints: ['GET    /api/services                         ?category=&isActive=', 'POST   /api/orders                           { customerId, vehicleId, serviceId, notes? }', 'GET    /api/orders                           ?status=&dateFrom=&page=&limit=', 'PATCH  /api/orders/:id/status                 { status }', 'POST   /api/payments                         { orderId, amount, method }', 'GET    /api/dashboard/carwash-summary'],
    metrics: ['Cars washed per day', 'Average service time', 'Revenue per day', 'Customer return rate', 'Package upsell rate'],
    genericFeatures: ['Manajemen Antrian', 'Layanan Cuci', 'Pembayaran', 'Member Management', 'Laporan Harian'],
  },

  motorcycle_workshop: {
    name: 'Motorcycle Workshop / Bengkel Motor',
    actors: ['Customer', 'Mechanic', 'Owner'],
    entities: {
      Vehicle: {
        fields: { plateNumber: 'string @unique', customerId: 'string', brand: 'string', model: 'string', year: 'Int?', mileage: 'Int?', createdAt: 'DateTime @default(now())' },
        indexes: ['plateNumber', 'customerId'],
        relations: { belongsTo: ['Customer'], hasMany: ['ServiceOrder'] }
      },
      ServiceOrder: {
        fields: { customerId: 'string', vehicleId: 'string', mechanicId: 'string?', complaint: 'string', diagnosis: 'string?', estimateAmount: 'Float?', status: 'OrderStatus @default(PENDING)', startedAt: 'DateTime?', completedAt: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { OrderStatus: ['PENDING', 'DIAGNOSED', 'ESTIMATED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['customerId', 'vehicleId', 'mechanicId', 'status'],
        relations: { belongsTo: ['Customer', 'Vehicle', 'Mechanic'], hasMany: ['SparePart'] }
      },
      SparePart: {
        fields: { name: 'string', serviceOrderId: 'string?', stock: 'Int @default(0)', price: 'Float', supplier: 'string?', isOriginal: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['serviceOrderId'],
        relations: { belongsTo: ['ServiceOrder'] }
      },
      Customer: {
        fields: { name: 'string', phone: 'string @unique', email: 'string?', totalVisits: 'Int @default(0)', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Vehicle', 'ServiceOrder'] }
      },
      Payment: {
        fields: { serviceOrderId: 'string', totalAmount: 'Float', partsCost: 'Float @default(0)', serviceCost: 'Float @default(0)', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['ServiceOrder'] }
      },
    },
    flows: ['Customer brings motorcycle with a problem', 'Mechanic diagnoses the issue and provides estimate', 'Customer approves estimate   repair begins', 'Mechanic repairs and replaces parts as needed', 'Customer pays and picks up motorcycle'],
    endpoints: ['POST   /api/service-orders                   { customerId, vehicleId, complaint }', 'GET    /api/service-orders                   ?status=&customerId=&dateFrom=&page=&limit=', 'PATCH  /api/service-orders/:id/diagnose       { diagnosis, estimateAmount }', 'PATCH  /api/service-orders/:id/status         { status }', 'POST   /api/spare-parts                      { serviceOrderId, name, price, isOriginal? }', 'POST   /api/payments                         { serviceOrderId, totalAmount, partsCost, serviceCost, method }', 'GET    /api/dashboard/workshop-summary'],
    metrics: ['Orders per day', 'Average repair time', 'Parts vs labor ratio', 'Customer retention', 'Estimate accuracy'],
    genericFeatures: ['Manajemen Antrian', 'Diagnosa & Estimasi', 'Reparasi Motor', 'Spare Part', 'Pembayaran'],
  },

  tire_shop: {
    name: 'Tire Shop / Toko Ban',
    actors: ['Customer', 'Technician', 'Owner'],
    entities: {
      Product: {
        fields: { name: 'string', brand: 'string', size: 'string', type: 'string @default("RADIAL")', price: 'Float', stock: 'Int @default(0)', minStock: 'Int @default(5)', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['brand', 'size', 'type'],
        relations: { hasMany: ['ServiceOrder'] }
      },
      Vehicle: {
        fields: { plateNumber: 'string @unique', customerId: 'string', brand: 'string', model: 'string', year: 'Int?', tireSize: 'string', createdAt: 'DateTime @default(now())' },
        indexes: ['plateNumber', 'customerId'],
        relations: { belongsTo: ['Customer'], hasMany: ['ServiceOrder'] }
      },
      ServiceOrder: {
        fields: { customerId: 'string', vehicleId: 'string', technicianId: 'string?', serviceType: 'string @default("REPLACE")', status: 'OrderStatus @default(PENDING)', notes: 'string?', startedAt: 'DateTime?', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { OrderStatus: ['PENDING', 'INSPECTED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['customerId', 'vehicleId', 'technicianId', 'status'],
        relations: { belongsTo: ['Customer', 'Vehicle', 'Technician'] }
      },
      Customer: {
        fields: { name: 'string', phone: 'string @unique', email: 'string?', totalVisits: 'Int @default(0)', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Vehicle', 'ServiceOrder'] }
      },
      Payment: {
        fields: { serviceOrderId: 'string', totalAmount: 'Float', productCost: 'Float @default(0)', serviceCost: 'Float @default(0)', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['ServiceOrder'] }
      },
    },
    flows: ['Customer arrives for tire inspection', 'Technician inspects tires   checks tread depth and pressure', 'Technician replaces worn tires with new ones', 'Tires are balanced and aligned', 'Customer pays and drives away'],
    endpoints: ['GET    /api/products                         ?brand=&size=&type=&isActive=', 'POST   /api/products                         { name, brand, size, type, price, stock }', 'POST   /api/service-orders                   { customerId, vehicleId, serviceType? }', 'GET    /api/service-orders                   ?status=&customerId=&page=&limit=', 'PATCH  /api/service-orders/:id/status         { status }', 'POST   /api/payments                         { serviceOrderId, totalAmount, productCost, serviceCost, method }', 'GET    /api/dashboard/tireshop-summary'],
    metrics: ['Tires sold per day', 'Average service time', 'Revenue per customer', 'Stock turnover rate', ['Stock turnover rate', 'Tire brand popularity']],
    genericFeatures: ['Manajemen Produk', 'Service Order', 'Penggantian Ban', 'Spooring & Balancing', 'Pembayaran'],
  },

  rental_management: {
    name: 'Rental Management / Manajemen Sewa',
    actors: ['Owner', 'Tenant', 'Manager', 'Admin'],
    entities: {
      Property: {
        fields: { code: 'string @unique', name: 'string', address: 'string', type: 'string @default("APARTMENT")', city: 'string', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['code', 'city'],
        relations: { hasMany: ['Unit', 'Lease'] }
      },
      Unit: {
        fields: { propertyId: 'string', unitNumber: 'string @unique', floor: 'Int?', bedrooms: 'Int', bathrooms: 'Int', area: 'Float?', monthlyRent: 'Float', depositAmount: 'Float', isOccupied: 'Boolean @default(false)', status: 'string @default("AVAILABLE")', createdAt: 'DateTime @default(now())' },
        indexes: ['propertyId', 'unitNumber', 'isOccupied', 'status'],
        relations: { belongsTo: ['Property'], hasMany: ['Lease', 'Maintenance'] }
      },
      Tenant: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', idNumber: 'string?', emergencyContact: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Lease', 'Payment'] }
      },
      Lease: {
        fields: { unitId: 'string', tenantId: 'string', startDate: 'DateTime', endDate: 'DateTime', monthlyRent: 'Float', depositAmount: 'Float @default(0)', status: 'LeaseStatus @default(ACTIVE)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { LeaseStatus: ['ACTIVE', 'EXPIRED', 'TERMINATED', 'RENEWED'] },
        indexes: ['unitId', 'tenantId', 'status'],
        relations: { belongsTo: ['Unit', 'Tenant'] }
      },
      Payment: {
        fields: { leaseId: 'string', tenantId: 'string', amount: 'Float', type: 'string @default("RENT")', period: 'string', dueDate: 'DateTime', paidAt: 'DateTime?', status: 'string @default("PENDING")', lateFee: 'Float @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['leaseId', 'tenantId', 'period', 'status'],
        relations: { belongsTo: ['Lease', 'Tenant'] }
      },
      Maintenance: {
        fields: { unitId: 'string', tenantId: 'string', issue: 'string', priority: 'string @default("MEDIUM")', status: 'string @default("REPORTED")', assignedTo: 'string?', scheduledAt: 'DateTime?', completedAt: 'DateTime?', cost: 'Float?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['unitId', 'tenantId', 'status', 'priority'],
        relations: { belongsTo: ['Unit', 'Tenant'] }
      },
    },
    flows: ['Owner lists property and units for rent', 'Tenant signs a lease agreement for a unit', 'Owner collects monthly rent payments', 'Tenant submits maintenance requests as needed', 'Lease is renewed or terminated at end of term'],
    endpoints: ['GET    /api/properties                       ?city=&isActive=', 'POST   /api/properties                       { code, name, address, type, city }', 'GET    /api/units                            ?propertyId=&status=&minPrice=&maxPrice=', 'POST   /api/leases                           { unitId, tenantId, startDate, endDate, monthlyRent }', 'GET    /api/payments                         ?leaseId=&status=&period=&page=&limit=', 'POST   /api/maintenance                      { unitId, tenantId, issue, priority }', 'PATCH  /api/maintenance/:id/status            { status }', 'GET    /api/dashboard/rental-summary'],
    metrics: ['Occupancy rate', ['Occupancy rate', 'Rent collection rate'], 'Average rent per unit', 'Maintenance response time', 'Tenant retention rate'],
    genericFeatures: ['Manajemen Properti', 'Unit & Sewa', 'Pembayaran Sewa', 'Maintenance', 'Laporan Penyewaan'],
  },

  real_estate_agency: {
    name: 'Real Estate Agency / Agen Properti',
    actors: ['Agent', 'Client', 'Buyer', 'Admin'],
    entities: {
      Property: {
        fields: { listingId: 'string', agentId: 'string', title: 'string', description: 'string?', address: 'string', city: 'string', price: 'Float', type: 'string @default("HOUSE")', bedrooms: 'Int?', bathrooms: 'Int?', landArea: 'Float?', buildingArea: 'Float?', images: 'string (JSON)?', status: 'string @default("FOR_SALE")', createdAt: 'DateTime @default(now())' },
        indexes: ['listingId', 'agentId', 'city', 'price', 'status'],
        relations: { belongsTo: ['Agent'], hasMany: ['Showing', 'Offer'] }
      },
      Listing: {
        fields: { propertyId: 'string', agentId: 'string', price: 'Float', commission: 'Float?', status: 'string @default("ACTIVE")', expiresAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['propertyId', 'agentId', 'status'],
        relations: { belongsTo: ['Property', 'Agent'] }
      },
      Client: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', type: 'string @default("BUYER")', budget: 'Float?', preferences: 'string (JSON)?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Showing', 'Offer'] }
      },
      Showing: {
        fields: { propertyId: 'string', agentId: 'string', clientId: 'string', scheduledAt: 'DateTime', status: 'string @default("SCHEDULED")', feedback: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['propertyId', 'agentId', 'clientId', 'scheduledAt'],
        relations: { belongsTo: ['Property', 'Agent', 'Client'] }
      },
      Offer: {
        fields: { propertyId: 'string', clientId: 'string', agentId: 'string', offeredPrice: 'Float', status: 'OfferStatus @default(SUBMITTED)', notes: 'string?', respondedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { OfferStatus: ['SUBMITTED', 'NEGOTIATING', 'ACCEPTED', 'REJECTED', 'WITHDRAWN'] },
        indexes: ['propertyId', 'clientId', 'status'],
        relations: { belongsTo: ['Property', 'Client', 'Agent'] }
      },
      Commission: {
        fields: { listingId: 'string', agentId: 'string', amount: 'Float', percentage: 'Float', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Listing', 'Agent'] }
      },
    },
    flows: ['Agent lists a property with photos and details', 'Client schedules a property showing', 'Agent shows the property to interested buyers', 'Buyer submits an offer   agent negotiates', 'Deal closes   agent receives commission'],
    endpoints: ['GET    /api/properties                       ?city=&type=&minPrice=&maxPrice=&status=&page=&limit=', 'POST   /api/properties                       { agentId, title, description?, address, city, price, type }', 'POST   /api/showings                        { propertyId, agentId, clientId, scheduledAt }', 'POST   /api/offers                           { propertyId, clientId, agentId, offeredPrice }', 'PATCH  /api/offers/:id/status                { status }', 'GET    /api/commissions                      ?agentId=&status=', 'GET    /api/dashboard/realestate-summary'],
    metrics: ['Listings per agent', 'Showing conversion rate', 'Average days on market', 'Commission per deal', 'Offer-to-close ratio'],
    genericFeatures: ['Property Listings', 'Showing Management', 'Offer & Negotiation', 'Commission Tracking', 'Client Management'],
  },

  strata_management: {
    name: 'Strata Management / Manajemen Apartemen',
    actors: ['Manager', 'Owner', 'Committee', 'Admin'],
    entities: {
      Unit: {
        fields: { unitNumber: 'string @unique', floor: 'Int', type: 'string', area: 'Float?', ownerId: 'string', monthlyFee: 'Float', parkingSlots: 'Int @default(1)', isRented: 'Boolean @default(false)', status: 'string @default("OCCUPIED")', createdAt: 'DateTime @default(now())' },
        indexes: ['unitNumber', 'ownerId', 'status'],
        relations: { belongsTo: ['Owner'], hasMany: ['Fee', 'Maintenance'] }
      },
      Owner: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', idNumber: 'string?', address: 'string?', isCommittee: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Unit'] }
      },
      Fee: {
        fields: { unitId: 'string', period: 'string', amount: 'Float', dueDate: 'DateTime', paidAt: 'DateTime?', status: 'string @default("PENDING")', lateFee: 'Float @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['unitId', 'period', 'status'],
        relations: { belongsTo: ['Unit'] }
      },
      Maintenance: {
        fields: { unitId: 'string', reportedBy: 'string', issue: 'string', area: 'string @default("UNIT")', priority: 'string @default("MEDIUM")', status: 'string @default("REPORTED")', estimatedCost: 'Float?', actualCost: 'Float?', vendor: 'string?', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['unitId', 'status', 'priority'],
        relations: { belongsTo: ['Unit'] }
      },
      Meeting: {
        fields: { title: 'string', date: 'DateTime', agenda: 'string?', minutes: 'string?', attendees: 'string (JSON)?', status: 'string @default("SCHEDULED")', createdAt: 'DateTime @default(now())' },
        indexes: ['date', 'status']
      },
    },
    flows: ['Manager collects monthly maintenance fees from owners', 'Manager schedules maintenance for common areas', 'Committee holds meetings to discuss building matters', 'Manager generates financial reports', 'Budget is planned and approved for next period'],
    endpoints: ['GET    /api/units                            ?status=&floor=', 'POST   /api/units                            { unitNumber, floor, type, ownerId, monthlyFee }', 'GET    /api/fees                             ?unitId=&period=&status=&page=&limit=', 'POST   /api/maintenance                      { unitId, issue, priority, area? }', 'POST   /api/meetings                         { title, date, agenda? }', 'GET    /api/dashboard/strata-summary'],
    metrics: ['Fee collection rate', ['Fee collection rate', 'Maintenance turnaround'], 'Meeting attendance', 'Budget variance', 'Owner satisfaction'],
    genericFeatures: ['Manajemen Unit', ['Manajemen Unit', 'Iuran Bulanan'], 'Maintenance & Perbaikan', 'Rapat & Notulen', 'Laporan Keuangan'],
  },

  sports_club: {
    name: 'Sports Club / Klub Olahraga',
    actors: ['Member', 'Coach', 'Admin'],
    entities: {
      Member: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', dateOfBirth: 'DateTime?', emergencyContact: 'string?', medicalNotes: 'string?', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Membership', 'Session', 'Attendance'] }
      },
      Membership: {
        fields: { memberId: 'string', type: 'MembType', startDate: 'DateTime', endDate: 'DateTime', price: 'Float', status: 'string @default("ACTIVE")', autoRenew: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        enums: { MembType: ['MONTHLY', 'QUARTERLY', 'YEARLY', 'TRIAL'] },
        indexes: ['memberId', 'status'],
        relations: { belongsTo: ['Member'] }
      },
      Session: {
        fields: { coachId: 'string', sport: 'string', date: 'DateTime', startTime: 'DateTime', endTime: 'DateTime', location: 'string', capacity: 'Int', participants: 'Int @default(0)', status: 'string @default("SCHEDULED")', createdAt: 'DateTime @default(now())' },
        indexes: ['coachId', 'date', 'sport'],
        relations: { belongsTo: ['Coach'], hasMany: ['Attendance'] }
      },
      Attendance: {
        fields: { memberId: 'string', sessionId: 'string', checkIn: 'DateTime', checkOut: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['memberId', 'sessionId'],
        relations: { belongsTo: ['Member', 'Session'] }
      },
      Payment: {
        fields: { memberId: 'string', membershipId: 'string?', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['memberId', 'status'],
        relations: { belongsTo: ['Member'] }
      },
    },
    flows: ['Member registers and selects a membership plan', 'Coach schedules training sessions', 'Member attends sessions and checks in', 'Attendance is tracked for each session', 'Membership is renewed periodically'],
    endpoints: ['GET    /api/members                          ?status=&search=&page=&limit=', 'POST   /api/members                          { name, email, phone, dateOfBirth? }', 'POST   /api/memberships                     { memberId, type, startDate, endDate, price }', 'POST   /api/sessions                        { coachId, sport, date, startTime, endTime, capacity }', 'POST   /api/attendance                      { memberId, sessionId }', 'POST   /api/payments                        { memberId, amount, method }', 'GET    /api/dashboard/sportsclub-summary'],
    metrics: ['Active members', 'Session attendance rate', 'Membership retention', 'Revenue per member', 'Session utilization'],
    genericFeatures: ['Member Management', 'Membership Plans', 'Session Scheduling', 'Attendance Tracking', 'Payment & Renewal'],
  },

  volunteer_platform: {
    name: 'Volunteer Platform / Platform Relawan',
    actors: ['Volunteer', 'Organizer', 'Admin'],
    entities: {
      Project: {
        fields: { organizerId: 'string', title: 'string', description: 'string?', category: 'string', location: 'string', startDate: 'DateTime', endDate: 'DateTime?', volunteersNeeded: 'Int', status: 'ProjStatus @default(DRAFT)', createdAt: 'DateTime @default(now())' },
        enums: { ProjStatus: ['DRAFT', 'OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['organizerId', 'category', 'status', 'startDate'],
        relations: { belongsTo: ['Organizer'], hasMany: ['Shift'] }
      },
      Volunteer: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', skills: 'string (JSON)?', availability: 'string?', totalHours: 'Float @default(0)', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Shift', 'Hours'] }
      },
      Shift: {
        fields: { projectId: 'string', volunteerId: 'string?', date: 'DateTime', startTime: 'DateTime', endTime: 'DateTime', slotsNeeded: 'Int', slotsFilled: 'Int @default(0)', status: 'string @default("OPEN")', createdAt: 'DateTime @default(now())' },
        indexes: ['projectId', 'volunteerId', 'date'],
        relations: { belongsTo: ['Project', 'Volunteer'] }
      },
      Hours: {
        fields: { volunteerId: 'string', projectId: 'string', shiftId: 'string', hoursWorked: 'Float', verifiedBy: 'string?', verifiedAt: 'DateTime?', status: 'string @default("PENDING")', createdAt: 'DateTime @default(now())' },
        indexes: ['volunteerId', 'projectId', 'status'],
        relations: { belongsTo: ['Volunteer', 'Project', 'Shift'] }
      },
      Impact: {
        fields: { projectId: 'string', totalVolunteers: 'Int', totalHours: 'Float', beneficiaries: 'Int?', outcome: 'string?', calculatedAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Project'] }
      },
    },
    flows: ['Organizer posts a volunteer project with shifts', 'Volunteer browses and applies for open shifts', 'Volunteer serves during assigned shifts', 'Hours are verified by organizer', 'Impact report generated after project completion'],
    endpoints: ['GET    /api/projects                         ?category=&status=&location=&page=&limit=', 'POST   /api/projects                         { organizerId, title, description?, category, location, startDate, endDate?, volunteersNeeded }', 'POST   /api/shifts                           { projectId, date, startTime, endTime, slotsNeeded }', 'POST   /api/apply                            { volunteerId, shiftId }', 'POST   /api/hours                            { volunteerId, projectId, shiftId, hoursWorked }', 'PATCH  /api/hours/:id/verify                 { verifiedBy }', 'GET    /api/dashboard/volunteer-summary'],
    metrics: ['Volunteers recruited', 'Total hours served', 'Project completion rate', 'Volunteer retention', 'Community impact'],
    genericFeatures: ['Project Management', 'Shift Scheduling', 'Volunteer Matching', 'Hours Tracking', 'Impact Report'],
  },

  alumni_network: {
    name: 'Alumni Network / Jaringan Alumni',
    actors: ['Alumni', 'Admin'],
    entities: {
      Member: {
        fields: { name: 'string', email: 'string @unique', phone: 'string?', graduationYear: 'Int', major: 'string', faculty: 'string', company: 'string?', position: 'string?', location: 'string?', photo: 'string?', linkedInUrl: 'string?', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['email', 'graduationYear', 'major', 'faculty'],
        relations: { hasMany: ['Event', 'Job', 'Donation'] }
      },
      Event: {
        fields: { organizerId: 'string', title: 'string', description: 'string?', date: 'DateTime', location: 'string', type: 'string @default("SOCIAL")', maxAttendees: 'Int?', status: 'string @default("UPCOMING")', createdAt: 'DateTime @default(now())' },
        indexes: ['organizerId', 'date', 'type', 'status'],
        relations: { belongsTo: ['Member'] }
      },
      Job: {
        fields: { memberId: 'string', company: 'string', title: 'string', description: 'string?', location: 'string?', type: 'string @default("FULL_TIME")', salary: 'string?', isActive: 'Boolean @default(true)', postedAt: 'DateTime @default(now())' },
        indexes: ['memberId', 'company', 'isActive'],
        relations: { belongsTo: ['Member'] }
      },
      Donation: {
        fields: { memberId: 'string', amount: 'Float', campaign: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['memberId', 'campaign'],
        relations: { belongsTo: ['Member'] }
      },
      Directory: {
        fields: { memberId: 'string', isPublic: 'Boolean @default(true)', updatedAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Member'] }
      },
    },
    flows: ['Alumni registers and updates personal profile', 'Alumni connects with other alumni in directory', 'Alumni creates or joins alumni events', 'Alumni posts job opportunities for fellow alumni', 'Alumni contributes donations to alma mater'],
    endpoints: ['GET    /api/members                          ?graduationYear=&major=&faculty=&search=&page=&limit=', 'POST   /api/members                          { name, email, phone?, graduationYear, major, faculty }', 'PATCH  /api/members/:id                       { company?, position?, photo?, linkedInUrl? }', 'GET    /api/events                            ?type=&status=&dateFrom=&page=&limit=', 'POST   /api/events                            { organizerId, title, description?, date, location, type }', 'POST   /api/jobs                             { memberId, company, title, description?, type }', 'POST   /api/donations                        { memberId, amount, campaign }', 'GET    /api/dashboard/alumni-summary'],
    metrics: ['Registered alumni', 'Event attendance', 'Job postings filled', 'Donation amount', 'Alumni engagement rate'],
    genericFeatures: ['Alumni Registry', 'Directory & Networking', 'Event Management', 'Job Board', 'Donations & Giving'],
  },

  spa: {
    name: 'Spa / Spa & Wellness',
    actors: ['Customer', 'Therapist', 'Admin'],
    entities: {
      Service: {
        fields: { name: 'string @unique', description: 'string?', duration: 'Int', price: 'Float', category: 'string', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['category', 'isActive'],
        relations: { hasMany: ['Appointment'] }
      },
      Appointment: {
        fields: { customerId: 'string', therapistId: 'string?', serviceId: 'string', date: 'DateTime', startTime: 'DateTime', endTime: 'DateTime', status: 'ApptStatus @default(PENDING)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ApptStatus: ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['customerId', 'therapistId', 'date', 'status'],
        relations: { belongsTo: ['Customer', 'Therapist', 'Service'] }
      },
      Therapist: {
        fields: { name: 'string', phone: 'string @unique', email: 'string?', specialization: 'string?', isActive: 'Boolean @default(true)', workingHours: 'string (JSON)?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Appointment'] }
      },
      Product: {
        fields: { name: 'string', description: 'string?', price: 'Float', stock: 'Int @default(0)', category: 'string', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Payment'] }
      },
      Payment: {
        fields: { appointmentId: 'string', customerId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['appointmentId', 'status'],
        relations: { belongsTo: ['Appointment', 'Customer'] }
      },
    },
    flows: ['Customer books a spa service with preferred therapist', 'Customer arrives and checks in for appointment', 'Therapist provides the spa treatment', 'Customer pays after service is completed', 'Customer leaves a review for future guests'],
    endpoints: ['GET    /api/services                         ?category=&isActive=', 'POST   /api/appointments                    { customerId, therapistId?, serviceId, date, startTime }', 'GET    /api/appointments                    ?customerId=&status=&dateFrom=&page=&limit=', 'PATCH  /api/appointments/:id/status          { status }', 'POST   /api/payments                        { appointmentId, customerId, amount, method }', 'GET    /api/dashboard/spa-summary'],
    metrics: ['Appointments per day', 'Therapist utilization', 'Revenue per service', 'Customer satisfaction', 'Booking lead time'],
    genericFeatures: ['Manajemen Layanan', 'Booking & Jadwal', 'Therapist Management', 'Pembayaran', 'Rating & Review'],
  },

  tailoring: {
    name: 'Tailoring / Penjahit',
    actors: ['Customer', 'Tailor', 'Admin'],
    entities: {
      Order: {
        fields: { orderNumber: 'string @unique', customerId: 'string', tailorId: 'string', type: 'string @default("CUSTOM")', description: 'string', status: 'OrderStatus @default(PENDING)', totalPrice: 'Float', depositAmount: 'Float @default(0)', dueDate: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        enums: { OrderStatus: ['PENDING', 'MEASURED', 'CUTTING', 'SEWING', 'FITTING', 'COMPLETED', 'DELIVERED', 'CANCELLED'] },
        indexes: ['orderNumber', 'customerId', 'tailorId', 'status'],
        relations: { belongsTo: ['Customer', 'Tailor'], hasMany: ['Measurement', 'Garment', 'Payment'] }
      },
      Measurement: {
        fields: { orderId: 'string', customerId: 'string', chest: 'Float?', waist: 'Float?', hips: 'Float?', shoulders: 'Float?', armLength: 'Float?', legLength: 'Float?', neck: 'Float?', notes: 'string?', recordedAt: 'DateTime @default(now())' },
        indexes: ['orderId', 'customerId'],
        relations: { belongsTo: ['Order', 'Customer'] }
      },
      Fabric: {
        fields: { name: 'string', color: 'string', pattern: 'string?', pricePerMeter: 'Float', stock: 'Float @default(0)', supplier: 'string?', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['name', 'color']
      },
      Garment: {
        fields: { orderId: 'string', name: 'string', fabricId: 'string?', quantity: 'Int @default(1)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Order'] }
      },
      Payment: {
        fields: { orderId: 'string', customerId: 'string', amount: 'Float', type: 'string @default("DEPOSIT")', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['orderId', 'type', 'status'],
        relations: { belongsTo: ['Order', 'Customer'] }
      },
    },
    flows: ['Customer consults with tailor about desired garment', 'Tailor takes customer measurements', 'Tailor cuts fabric and sews the garment', 'Customer comes for fitting   adjustments made', 'Garment is completed and delivered to customer'],
    endpoints: ['POST   /api/orders                          { customerId, tailorId, type, description, dueDate? }', 'GET    /api/orders                           ?status=&customerId=&page=&limit=', 'PATCH  /api/orders/:id/status                { status }', 'POST   /api/measurements                    { orderId, customerId, chest?, waist?, shoulders? }', 'POST   /api/payments                        { orderId, customerId, amount, type, method }', 'GET    /api/dashboard/tailoring-summary'],
    metrics: ['Orders per month', 'Average completion time', 'Customer satisfaction', 'Revenue per order', 'Repeat customer rate'],
    genericFeatures: ['Manajemen Order', 'Pengukuran', 'Produksi Jahit', 'Fitting', 'Pembayaran'],
  },

  laundry_delivery: {
    name: 'Laundry Delivery / Laundry Antar Jemput',
    actors: ['Customer', 'Driver', 'Staff', 'Admin'],
    entities: {
      Order: {
        fields: { orderNumber: 'string @unique', customerId: 'string', driverId: 'string?', status: 'OrderStatus @default(PENDING)', totalWeight: 'Float @default(0)', totalPrice: 'Float @default(0)', pickupAddress: 'string', deliveryAddress: 'string', pickupTime: 'DateTime?', deliveryTime: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { OrderStatus: ['PENDING', 'PICKED_UP', 'WASHING', 'DRYING', 'IRONING', 'PACKING', 'DELIVERING', 'DELIVERED', 'CANCELLED'] },
        indexes: ['orderNumber', 'customerId', 'driverId', 'status'],
        relations: { belongsTo: ['Customer', 'Driver'], hasMany: ['Item', 'Payment', 'Tracking'] }
      },
      Item: {
        fields: { orderId: 'string', name: 'string', quantity: 'Int', weight: 'Float?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['orderId'],
        relations: { belongsTo: ['Order'] }
      },
      Driver: {
        fields: { name: 'string', phone: 'string @unique', vehicle: 'string', isAvailable: 'Boolean @default(true)', currentLat: 'Float?', currentLng: 'Float?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Order'] }
      },
      Tracking: {
        fields: { orderId: 'string', driverId: 'string?', status: 'string', location: 'string?', timestamp: 'DateTime @default(now())' },
        indexes: ['orderId', 'timestamp'],
        relations: { belongsTo: ['Order', 'Driver'] }
      },
      Payment: {
        fields: { orderId: 'string', customerId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['orderId', 'status'],
        relations: { belongsTo: ['Order', 'Customer'] }
      },
    },
    flows: ['Customer orders laundry pickup via app', 'Driver picks up laundry from customer address', 'Staff washes, dries, and irons the laundry', 'Driver delivers clean laundry back to customer', 'Customer pays for the service'],
    endpoints: ['POST   /api/orders                          { customerId, pickupAddress, deliveryAddress, notes? }', 'GET    /api/orders                           ?status=&customerId=&page=&limit=', 'PATCH  /api/orders/:id/status                { status }', 'POST   /api/items                           { orderId, name, quantity, weight?, notes? }', 'PATCH  /api/orders/:id/assign-driver         { driverId }', 'POST   /api/tracking                        { orderId, driverId?, status, location? }', 'POST   /api/payments                        { orderId, customerId, amount, method }', 'GET    /api/dashboard/laundry-summary'],
    metrics: ['Orders per day', ['Orders per day', 'Average processing time'], 'Driver utilization', 'Customer satisfaction', 'Average order value'],
    genericFeatures: ['Order Management', 'Pickup & Delivery', 'Laundry Processing', 'Driver Tracking', 'Payment Collection'],
  },

  grocery: {
    name: 'Grocery / Toko Sembako',
    actors: ['Customer', 'Cashier', 'Manager'],
    entities: {
      Product: {
        fields: { name: 'string', barcode: 'string @unique', categoryId: 'string', unit: 'string', price: 'Float', stock: 'Int @default(0)', minStock: 'Int @default(10)', isActive: 'Boolean @default(true)', expiryDate: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['barcode', 'categoryId', 'stock'],
        relations: { belongsTo: ['Category'], hasMany: ['Stock', 'Sale'] }
      },
      Category: {
        fields: { name: 'string @unique', description: 'string?', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Product'] }
      },
      Stock: {
        fields: { productId: 'string', supplierId: 'string', quantity: 'Int', purchasePrice: 'Float', batchNumber: 'string?', receivedAt: 'DateTime @default(now())' },
        indexes: ['productId', 'supplierId'],
        relations: { belongsTo: ['Product', 'Supplier'] }
      },
      Sale: {
        fields: { productId: 'string', customerId: 'string?', quantity: 'Int', pricePerUnit: 'Float', totalPrice: 'Float', cashierId: 'string', soldAt: 'DateTime @default(now())' },
        indexes: ['productId', 'cashierId', 'soldAt'],
        relations: { belongsTo: ['Product', 'Cashier'] }
      },
      Supplier: {
        fields: { name: 'string', contact: 'string', phone: 'string', email: 'string?', address: 'string?', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Stock'] }
      },
    },
    flows: ['Manager stocks products from suppliers', 'Products are displayed with prices', 'Cashier scans items and processes sale', 'Stock is automatically decremented after sale', 'Manager reorders when stock runs low'],
    endpoints: ['GET    /api/products                         ?categoryId=&search=&isActive=&page=&limit=', 'POST   /api/products                         { name, barcode, categoryId, unit, price, minStock }', 'POST   /api/stock                           { productId, supplierId, quantity, purchasePrice }', 'POST   /api/sales                           { productId, quantity, pricePerUnit, totalPrice, cashierId }', 'GET    /api/sales                           ?dateFrom=&dateTo=&cashierId=&page=&limit=', 'POST   /api/suppliers                       { name, contact, phone }', 'GET    /api/dashboard/grocery-summary'],
    metrics: ['Daily sales', 'Stock turnover rate', 'Expired product loss', 'Gross margin %', 'Supplier reliability'],
    genericFeatures: ['Manajemen Produk', 'Stok & Supplier', 'POS Kasir', 'Penjualan Harian', 'Laporan Laba'],
  },

  convenience_store: {
    name: 'Convenience Store / Toko Kelontong',
    actors: ['Cashier', 'Manager', 'Owner'],
    entities: {
      Product: {
        fields: { name: 'string', barcode: 'string @unique', category: 'string', unit: 'string', price: 'Float', stock: 'Int @default(0)', minStock: 'Int @default(5)', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['barcode', 'category', 'stock'],
        relations: { hasMany: ['Sale', 'Stock'] }
      },
      Sale: {
        fields: { productId: 'string', quantity: 'Int', pricePerUnit: 'Float', totalPrice: 'Float', cashierId: 'string', paymentMethod: 'string', soldAt: 'DateTime @default(now())' },
        indexes: ['cashierId', 'soldAt'],
        relations: { belongsTo: ['Product', 'Cashier'] }
      },
      Supplier: {
        fields: { name: 'string', contact: 'string', phone: 'string', email: 'string?', address: 'string?', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Stock'] }
      },
      Stock: {
        fields: { productId: 'string', supplierId: 'string', quantity: 'Int', purchasePrice: 'Float', receivedAt: 'DateTime @default(now())' },
        indexes: ['productId', 'supplierId'],
        relations: { belongsTo: ['Product', 'Supplier'] }
      },
      Shift: {
        fields: { cashierId: 'string', startTime: 'DateTime', endTime: 'DateTime?', totalSales: 'Float @default(0)', status: 'string @default("ACTIVE")', notes: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Cashier'], hasMany: ['Sale'] }
      },
    },
    flows: ['Cashier starts shift and opens register', 'Customer buys items   cashier scans and processes payment', 'Cashier handles cash or digital payment', 'Stock is updated after each sale', 'Manager reconciles sales and reorders stock'],
    endpoints: ['GET    /api/products                         ?category=&search=&isActive=&page=&limit=', 'POST   /api/sales                           { productId, quantity, pricePerUnit, totalPrice, cashierId, paymentMethod }', 'GET    /api/sales                           ?dateFrom=&dateTo=&cashierId=&page=&limit=', 'POST   /api/stock                           { productId, supplierId, quantity, purchasePrice }', 'POST   /api/shifts                          { cashierId }', 'PATCH  /api/shifts/:id/close                { totalSales, notes? }', 'GET    /api/dashboard/convenience-summary'],
    metrics: ['Daily transactions', 'Average transaction value', 'Stock turnover', 'Cashier performance', 'Gross margin'],
    genericFeatures: ['Manajemen Produk', ['Manajemen Produk', 'POS Kasir'], 'Shift Management', 'Stok & Supplier', 'Laporan Harian'],
  },

  pharmacy_retail: {
    name: 'Pharmacy Retail / Apotek Retail',
    actors: ['Pharmacist', 'Cashier', 'Manager'],
    entities: {
      Medicine: {
        fields: { name: 'string', sku: 'string @unique', category: 'string', price: 'Float', requiresPrescription: 'Boolean @default(false)', stock: 'Int @default(0)', minStock: 'Int @default(10)', expiryDate: 'DateTime?', manufacturer: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['sku', 'category', 'stock'],
        relations: { hasMany: ['Prescription', 'Sale', 'Stock'] }
      },
      Prescription: {
        fields: { customerName: 'string', doctorName: 'string?', medicineId: 'string', dosage: 'string', quantity: 'Int', pharmacistId: 'string', status: 'string @default("PENDING")', notes: 'string?', filledAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['medicineId', 'status'],
        relations: { belongsTo: ['Medicine', 'Pharmacist'] }
      },
      Sale: {
        fields: { medicineId: 'string', prescriptionId: 'string?', customerName: 'string?', quantity: 'Int', totalPrice: 'Float', paymentMethod: 'string', cashierId: 'string', soldAt: 'DateTime @default(now())' },
        indexes: ['medicineId', 'cashierId', 'soldAt'],
        relations: { belongsTo: ['Medicine', 'Cashier'] }
      },
      Supplier: {
        fields: { name: 'string', contact: 'string', phone: 'string', email: 'string?', address: 'string?', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Stock'] }
      },
      Stock: {
        fields: { medicineId: 'string', supplierId: 'string', batchNumber: 'string', quantity: 'Int', purchasePrice: 'Float', receivedAt: 'DateTime @default(now())' },
        indexes: ['medicineId', 'supplierId'],
        relations: { belongsTo: ['Medicine', 'Supplier'] }
      },
    },
    flows: ['Pharmacist receives medicine shipment from supplier', 'Customer brings prescription   pharmacist verifies', 'Pharmacist dispenses medicine   cashier processes sale', 'Stock is updated after each transaction', 'Manager reorders when stock reaches minimum level'],
    endpoints: ['GET    /api/medicines                        ?category=&requiresPrescription=&search=&page=&limit=', 'POST   /api/medicines                        { name, sku, category, price, requiresPrescription, minStock }', 'POST   /api/prescriptions                    { customerName, doctorName?, medicineId, dosage, quantity, pharmacistId }', 'POST   /api/sales                           { medicineId, prescriptionId?, customerName?, quantity, totalPrice, paymentMethod, cashierId }', 'POST   /api/stock                           { medicineId, supplierId, batchNumber, quantity, purchasePrice }', 'GET    /api/dashboard/pharmacy-retail-summary'],
    metrics: ['Daily revenue', 'Prescriptions filled', 'Stock turnover', 'Expired stock loss', 'Customer transactions'],
    genericFeatures: ['Manajemen Obat', 'Resep & Dispensing', 'POS Retail', 'Stok & Supplier', 'Laporan Apotek'],
  },

  generic: {
    name: 'Generic / Lainnya',
    actors: ['Pengguna', 'Admin', 'Pemilik'],
    entities: {
      // Only 3 minimal entities   everything else generated by AI
      Project: {
        fields: { name: 'string', description: 'string?', status: 'string @default("active")', ownerId: 'string', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
      },
      Item: {
        fields: { projectId: 'string', name: 'string', description: 'string?', status: 'string @default("active")', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
      },
      Activity: {
        fields: { itemId: 'string', type: 'string', description: 'string?', userId: 'string', createdAt: 'DateTime @default(now())' },
      },
    },
    flows: [
      'User login   melihat dashboard ringkasan',
      'User dapat membuat item baru   form dengan field yang tervalidasi',
      'User dapat melihat daftar item   search, filter, sort, pagination',
      'User dapat mengedit item   simpan perubahan',
      'User dapat menghapus/archive item   soft delete',
    ],
    endpoints: [
      'POST   /api/items                           { name, description?, projectId }',
      'GET    /api/items                            ?search=&page=&limit=&sort=',
      'GET    /api/items/:id',
      'PATCH  /api/items/:id                        { name?, description?, status? }',
      'DELETE /api/items/:id',
      'GET    /api/dashboard/summary',
    ],
    metrics: ['User activation', 'Items created', 'Workflow completion'],
    genericFeatures: ['Dashboard Ringkasan', 'Manajemen Data', 'Pencarian & Filter', 'Laporan Aktivitas'],
  },
};

// Keyword → domain scoring map
const DOMAIN_KEYWORDS = {
  inventory: ['inventory', 'stok', 'gudang', 'warehouse', 'persediaan', 'barang masuk', 'barang keluar', 'supply chain', 'logistik'],
  crm: ['crm', 'lead', 'sales', 'pipeline', 'customer', 'prospek', 'follow up', 'penjualan', 'deals'],
  habit: ['habit', 'tracker', 'streak', 'kebiasaan', 'check in', 'daily routine', 'self improvement', 'target harian'],
  booking: ['booking', 'jadwal', 'appointment', 'reservasi', 'reschedule', 'janji', 'service booking', 'slot'],
  finance: ['finance', 'invoice', 'expense', 'pengeluaran', 'pemasukan', 'keuangan', 'accounting', 'budget', 'cashflow', 'laporan keuangan'],
  commerce: ['marketplace', 'toko', 'ecommerce', 'shop', 'jual beli', 'belanja', 'online shop', 'cart', 'checkout', 'catalog', 'katalog produk'],
  delivery: ['delivery', 'pesan antar', 'kurir', 'driver', 'gojek', 'grab', 'antar', 'pengiriman', 'paket', 'order delivery', 'food delivery', 'laundry', 'binatu', 'cuci'],
  pos: ['pos', 'kasir', 'toko', 'point of sale', 'scan barcode'],
  erp: ['erp', 'enterprise', 'hrd', 'sdm', 'kantor', 'perusahaan', 'department', 'employee', 'karyawan'],
  manufacturing: ['manufacturing', 'produksi', 'pabrik', 'factory', 'manufacture', 'production order'],
  healthcare: ['healthcare', 'klinik', 'dokter', 'pasien', 'rumah sakit', 'hospital', 'clinic', 'medical'],
  education: ['education', 'sekolah', 'course', 'kelas', 'belajar', 'learning', 'school', 'tutoring', 'student'],
  property: ['property', 'properti', 'sewa', 'kontrakan', 'apartment', 'boarding house', 'real estate', 'tenant'],
  // New domains
  restaurant: ['restaurant', 'restoran', 'makan', 'warung', 'rumah makan', 'food', 'menu'],
  cafe: ['cafe', 'kopi', 'coffee', 'minuman', 'coffee shop'],
  bakery: ['bakery', 'roti', 'kue', 'cake', 'bakery', 'toko roti'],
  catering: ['catering', 'prasmanan', 'buffet', 'katering'],
  hotel: ['hotel', 'penginapan', 'inn', 'lodging', 'resort'],
  salon: ['salon', 'kecantikan', 'beauty', 'hair', 'hair salon'],
  barbershop: ['barbershop', 'pangkas', 'cukur', 'barber'],
  workshop: ['workshop', 'bengkel', 'service', 'perbaikan', 'repair shop'],
  cleaning_service: ['cleaning', 'kebersihan', 'cuci', 'cleaner', 'house cleaning'],
  field_service: ['field service', 'teknisi', 'service', 'perbaikan rumah', 'home service'],
  accounting: ['accounting', 'akuntansi', 'pembukuan', 'neraca', 'jurnal'],
  invoicing: ['invoicing', 'invoice', 'faktur', 'tagihan', 'penagihan'],
  expense: ['expense', 'pengeluaran', 'reimbursement', 'biaya'],
  payroll: ['payroll', 'gaji', 'upah', 'salary', 'penggajian'],
  budgeting: ['budgeting', 'anggaran', 'budget', 'perencanaan keuangan'],
  attendance: ['attendance', 'absensi', 'kehadiran', 'check in', 'check out'],
  recruitment: ['recruitment', 'rekrutmen', 'hiring', 'lamaran', 'lowongan'],
  employee_management: ['employee', 'karyawan', 'pegawai', 'hrd', 'sdm', 'manajemen karyawan'],
  performance_management: ['performance', 'kinerja', 'review karyawan', 'penilaian'],
  fleet: ['fleet', 'armada', 'kendaraan', 'vehicle fleet'],
  courier: ['courier', 'kurir', 'paket', 'ekspedisi', 'pengiriman'],
  trucking: ['trucking', 'truk', 'logistik', 'angkutan barang'],
  digital_product: ['digital product', 'produk digital', 'ebook', 'template digital'],
  membership: ['membership', 'keanggotaan', 'subscription', 'berlangganan'],
  course_platform: ['course', 'kelas online', 'platform belajar', 'e-learning', 'online course'],
  farm: ['farm', 'pertanian', 'kebun', 'ladang', 'tanaman'],
  livestock: ['livestock', 'peternakan', 'hewan ternak', 'ternak'],
  poultry: ['poultry', 'ayam', 'peternakan ayam', 'broiler'],
  bengkel: ['bengkel', 'montir', 'service mobil', 'bengkel mobil', 'bengkel motor'],
  car_rental: ['car rental', 'rental mobil', 'sewa mobil', 'rent car'],
  dealer: ['dealer', 'showroom', 'penjualan mobil', 'mobil baru'],
  contractor: ['contractor', 'kontraktor', 'konstruksi', 'pembangunan'],
  maintenance: ['maintenance', 'pemeliharaan', 'perawatan', 'perbaikan gedung'],
  event_management: ['event', 'acara', 'seminar', 'workshop event', 'konferensi'],
  forum: ['forum', 'diskusi', 'komunitas', 'thread', 'diskusi online'],
  membership_community: ['membership community', 'komunitas', 'klub', 'komunitas berbayar'],
  photography: ['photography', 'fotografi', 'foto', 'photographer', 'sesi foto'],
  veterinary: ['veterinary', 'hewan', 'dokter hewan', 'pet', 'pet shop', 'klinik hewan'],
  gym: ['gym', 'fitness', 'olahraga', 'pusat kebugaran', 'fitnes'],
  coworking: ['coworking', 'co-working', 'kantor bersama', 'shared office', 'ruang kerja'],
  pharmacy: ['pharmacy', 'apotek', 'obat', 'medicine', 'resep', 'prescription', 'drugstore', 'farmasi'],
  laboratory: ['laboratory', 'lab', 'laboratorium', 'test lab', 'sample', 'hasil lab', 'medical check'],
  telemedicine: ['telemedicine', 'telehealth', 'dokter online', 'konsultasi online', 'teleconsultation', 'video call dokter'],
  tutoring: ['tutoring', 'les', 'bimbel', 'privat', 'tutor', 'bimbingan belajar', 'les private'],
  bootcamp: ['bootcamp', 'coding bootcamp', 'pelatihan intensif', 'programming course', 'intensive training'],
  school_management: ['school', 'sekolah', 'madrasah', 'siswa', 'guru', 'kelas', 'rapor', 'akademik'],
  lms: ['lms', 'learning management', 'e-learning', 'moodle', 'kelas online', 'platform belajar'],
  personal_finance: ['personal finance', 'keuangan pribadi', 'budget', 'anggaran', 'pengeluaran', 'pemasukan'],
  cooperative: ['cooperative', 'koperasi', 'simpan pinjam', 'anggota koperasi', 'shu'],
  insurance: ['insurance', 'asuransi', 'polis', 'premi', 'klaim', 'adjuster'],
  warehouse: ['warehouse', 'gudang', 'bin', 'stock movement', 'receiving', 'shipping', 'inventory gudang'],
  cold_chain: ['cold chain', 'rantai dingin', 'suhu', 'temperature', 'sensor suhu', 'cold storage'],
  freight: ['freight', 'kargo', 'pengiriman barang', 'logistik', 'shipping cargo', 'freight forwarding'],
  homestay: ['homestay', 'penginapan', 'guest house', 'sewa rumah', 'home stay', 'inap'],
  villa_rental: ['villa', 'sewa villa', 'villa rental', 'liburan', 'holiday villa', 'villa'],
  guest_house: ['guest house', 'losmen', 'penginapan murah', 'inn', 'lodging'],
  resort: ['resort', 'resort wisata', 'hotel resort', 'liburan resort', 'penginapan mewah', 'vacation resort'],
  help_desk: ['help desk', 'ticket', 'support ticket', 'customer support', 'helpdesk', 'layanan pelanggan'],
  loyalty_program: ['loyalty program', 'poin', 'reward', 'member point', 'loyalitas', 'program loyalitas'],
  sales_pipeline: ['sales pipeline', 'pipeline sales', 'deal', 'lead management', 'prospek', 'sales tracking'],
  project_management: ['project management', 'manajemen proyek', 'project', 'gantt', 'timeline proyek', 'task project'],
  task_management: ['task management', 'todo', 'to-do', 'tugas', 'task', 'productivity', 'manajemen tugas'],
  note_taking: ['note taking', 'catatan', 'notebook', 'notes', 'mencatat', 'note app'],
  okr_tracking: ['okr', 'objective', 'key result', 'kpi', 'target', 'kinerja', 'performance tracking'],
  content_subscription: ['content subscription', 'langganan konten', 'creator', 'subscriber', 'premium content'],
  podcast_platform: ['podcast', 'podcast platform', 'episode', 'host podcast', 'podcaster', 'audio streaming'],
  template_marketplace: ['template marketplace', 'template', 'marketplace template', 'jual template', 'download template'],
  legal: ['legal', 'hukum', 'law firm', 'advokat', 'pengacara', 'case management', 'contract', 'kontrak'],
  document_management: ['document management', 'dokumen', 'arsip', 'file management', 'records', 'surat menyurat'],
  ticketing: ['ticketing', 'support ticket', 'help desk', 'case ticket', 'issue tracking', 'incident'],
  content_management: ['content management', 'cms', 'editorial', 'artikel', 'publikasi', 'media management'],
  newsroom: ['newsroom', 'berita', 'portal berita', 'jurnalisme', 'redaksi'],
  government_service: ['government', 'pemerintah', 'layanan publik', 'disdukcapil', 'dinas', 'surat izin'],
  nonprofit: ['nonprofit', 'yayasan', 'donasi', 'sosial', 'charity', 'organisasi nirlaba'],
  travel_agency: ['travel', 'travel agency', 'tour', 'trip', 'paket wisata', 'tourism'],
  procurement: ['procurement', 'pengadaan', 'purchase request', 'supplier request', 'vendor management'],
  creator_tools: ['creator', 'content creator', 'creator tools', 'asset library', 'studio', 'workspace creator'],
  analytics: ['analytics', 'dashboard analytics', 'insight', 'reporting', 'data dashboard', 'metrics'],
  contract_management: ['contract management', 'kontrak', 'agreement', 'perjanjian', 'legal ops'],
  hris: ['hris', 'human resources', 'human resource', 'employee database', 'sdm system'],
  fishery: ['fishery', 'perikanan', 'ikan', 'tambak', 'kolam ikan', 'budidaya ikan', 'nelayan'],
  plantation: ['plantation', 'perkebunan', 'kebun', 'sawah', 'tanaman', 'crop', 'lahan'],
  greenhouse: ['greenhouse', 'rumah kaca', 'hidroponik', 'hydroponic', 'sensor greenhouse'],
  car_wash: ['car wash', 'cuci mobil', 'cuci kendaraan', 'car detailing', 'automotive wash'],
  motorcycle_workshop: ['motorcycle workshop', 'bengkel motor', 'service motor', 'tune up motor', 'sparepart motor'],
  tire_shop: ['tire shop', 'ban', 'toko ban', 'ganti ban', 'spooring', 'balancing ban'],
  rental_management: ['rental management', 'manajemen sewa', 'sewa properti', 'rental unit', 'tenant management'],
  real_estate_agency: ['real estate', 'properti', 'agen properti', 'jual rumah', 'real estate agent', 'listing properti'],
  strata_management: ['strata management', 'apartment management', 'manajemen apartemen', 'ipp', 'spp apartemen'],
  sports_club: ['sports club', 'klub olahraga', 'futsal', 'badminton', 'tenis', 'olahraga', 'gym club'],
  volunteer_platform: ['volunteer', 'relawan', 'sukarelawan', 'volunteering', 'kerja bakti', 'social project'],
  alumni_network: ['alumni', 'alumni network', 'jaringan alumni', 'alumni sekolah', 'alumni universitas'],
  spa: ['spa', 'wellness', 'massage', 'pijat', 'beauty spa', 'perawatan tubuh'],
  tailoring: ['tailoring', 'penjahit', 'jahit', 'custom suit', 'kostum', 'tailor'],
  laundry_delivery: ['laundry', 'laundry delivery', 'cuci sepatu', 'laundry antar', 'binatu', 'cuci'],
  grocery: ['grocery', 'sembako', 'toko kelontong', 'bahan pokok', 'sembako murah', 'grosir'],
  convenience_store: ['convenience store', 'toko kelontong', 'minimarket', 'warung', 'retail kecil'],
  pharmacy_retail: ['pharmacy retail', 'apotek retail', 'obat bebas', 'toko obat', 'drugstore']

};

function getDomain() {
  const idea = (state.idea || '').toLowerCase().trim();
  if (!idea) return { primary: 'generic', secondary: [], confidence: 0 };

  // Phase 1: Keyword scoring   calculate match strength for ALL domains
  const scores = {};
  const maxPossible = {};
  let bestScore = 0;

  for (const [domain, terms] of Object.entries(DOMAIN_KEYWORDS)) {
    let score = 0;
    let totalPossible = 0;
    for (const term of terms) {
      totalPossible += term.length;
      if (idea.includes(term)) {
        // Longer terms = more specific → higher weight
        score += term.length;
      }
    }
    scores[domain] = score;
    maxPossible[domain] = totalPossible;
    if (score > bestScore) {
      bestScore = score;
    }
  }

  // Determine primary domain
  let primary = 'generic';
  for (const [domain, score] of Object.entries(scores)) {
    if (score > (scores[primary] || 0)) {
      primary = domain;
    }
  }

  // If no keyword match, try AI fallback
  if (bestScore === 0) {
    if (idea.length > 15 && window.aiDomainDetector) {
      try {
        const aiResult = window.aiDomainDetector(idea);
        if (aiResult && aiResult.domain && DOMAIN_PACKS[aiResult.domain]) {
          return {
            primary: aiResult.domain,
            secondary: [],
            confidence: 0.6,
          };
        }
      } catch (e) {
        console.warn('AI domain detection failed, using keyword fallback:', e);
      }
    }
    return { primary: 'generic', secondary: [], confidence: 0 };
  }

  // Calculate confidence for best domain
  const bestConfidence = maxPossible[primary] > 0
    ? scores[primary] / maxPossible[primary]
    : 0;

  // Secondary domains: score > 30% of best score
  const threshold = bestScore * 0.3;
  const secondary = Object.entries(scores)
    .filter(([domain, score]) => score > threshold && domain !== primary)
    .map(([domain]) => domain);

  return {
    primary,
    secondary,
    confidence: parseFloat(bestConfidence.toFixed(2)),
  };
}

function getDomainDefaults(domain) {
  // Normalize: map 'learning' to 'generic' (no longer a dedicated pack)
  const normalized = domain === 'learning' ? 'generic' : domain;
  const pack = DOMAIN_PACKS[normalized] || DOMAIN_PACKS.generic;

  return {
    users: pack.actors.join(', '),
    entities: Object.keys(pack.entities).map(name => name.toLowerCase() + 's'),
    features: pack.genericFeatures,
    metric: pack.metrics[0] || 'User engagement',
  };
}

function getAnswer(id, fallback = '') {
  const value = state.answers[id];
  if (Array.isArray(value)) return value.length ? value.join(', ') : fallback;
  if (value && value !== '__skipped') return value;
  // Compatibility: map old question IDs to new adaptive IDs
  const idMap = {
    'target-user': 'target',
    'main-outcome': 'main_outcome',
    'success-metric': 'metric',
    'scale': 'scale_target',
    'monetization': 'revenue',
  };
  const mappedId = idMap[id];
  if (mappedId) {
    const mappedValue = state.answers[mappedId];
    if (Array.isArray(mappedValue)) return mappedValue.length ? mappedValue.join(', ') : fallback;
    if (mappedValue && mappedValue !== '__skipped') return mappedValue;
  }
  return fallback;
}

function getSelectedMvp(defaults) {
  const selected = state.answers['mvp-scope'];
  if (Array.isArray(selected) && selected.length) return selected;
  return defaults.features;
}

function buildTechStack() {
  // If all tech are 'ai-pilih', use domain-aware defaults
  const allAi = Object.values(state.tech).every(v => v === 'ai-pilih');
  if (allAi) {
    const domainInfo = getDomain();
    const domain = domainInfo.primary;
    if (state.extras.includes('mobile')) {
      return {
        frontend: 'Expo (React Native)',
        backend: 'Node.js + Hono',
        database: 'PostgreSQL',
        deployment: 'Vercel + Expo EAS',
      };
    }
    if (['inventory', 'crm', 'finance'].includes(domain)) {
      return {
        frontend: 'Next.js',
        backend: 'Next.js API routes atau Hono',
        database: 'PostgreSQL',
        deployment: 'Vercel',
      };
    }
    return {
      frontend: 'React + Vite',
      backend: 'Node.js + Hono',
      database: 'PostgreSQL',
      deployment: 'Railway atau Render',
    };
  }
  return {
    frontend: getTechLabel('frontend'),
    backend: getTechLabel('backend'),
    database: getTechLabel('database'),
    deployment: getTechLabel('deployment'),
  };
}

function buildFeatureRows(features) {
  return features
    .map((feature, index) => {
      const priority = index < 3 ? 'P0' : 'P1';
      return `| ${priority} | ${feature} | User bisa menyelesaikan flow utama tanpa bantuan manual. | Data tersimpan, tervalidasi, dan muncul di dashboard/log. |`;
    })
    .join('\\n');
}

function buildEntityDiagram(domainPack) {
  if (!domainPack || !domainPack.entities) return '';

  const blocks = [];
  const relations = [];

  for (const [entityName, entityDef] of Object.entries(domainPack.entities)) {
    const fields = [];
    // Always add id
    fields.push('    String id PK');

    // Add entity-specific fields
    for (const [fieldName, fieldType] of Object.entries(entityDef.fields || {})) {
      const cleanType = fieldType
        .replace(/ @.*$/, '')     // Strip @default, @unique, @id
        .replace(/\?$/, '');       // Strip optional marker
      const isRequired = !fieldType.includes('?');
      fields.push(`    ${cleanType} ${fieldName}${isRequired ? '' : '?'}`);
    }

    // Add enums as comments
    const enumLines = [];
    if (entityDef.enums) {
      for (const [enumName, enumValues] of Object.entries(entityDef.enums)) {
        enumLines.push(`    // enum ${enumName}: ${enumValues.join(' | ')}`);
      }
    }

    // Build entity block with all fields
    const entityBlock = [
      `  ${entityName} {`,
      ...fields,
      ...enumLines,
      `  }`,
    ].join('\\n');
    blocks.push(entityBlock);

    // Collect relations   belongsTo
    if (entityDef.relations && entityDef.relations.belongsTo) {
      for (const parent of entityDef.relations.belongsTo) {
        relations.push(`  ${entityName} }o--|| ${parent} : "belongs to"`);
      }
    }
  }

  // Also collect hasMany relations (reverse of belongsTo)
  for (const [entityName, entityDef] of Object.entries(domainPack.entities)) {
    if (entityDef.relations && entityDef.relations.hasMany) {
      for (const child of entityDef.relations.hasMany) {
        relations.push(`  ${entityName} ||--o{ ${child} : "has many"`);
      }
    }
  }

  // Build proper mermaid ERD
  const dedupedRels = [...new Set(relations)];
  return `${blocks.join('\n\n')}\n\n${dedupedRels.join('\n')}`;
}

function normalizeTitle(text) {
  const cleaned = text
    .replace(/["']/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  const appMatch = cleaned.match(/(?:aplikasi|app|platform|tools?|saas)\s+([^,.]{3,54})/i);
  if (appMatch) return titleCase(appMatch[1]);
  return titleCase(cleaned.split(/[,.]/)[0].slice(0, 52) || 'Produk Digital');
}

function titleCase(text) {
  return String(text)
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 8)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
}

//     Inline Pipeline Runner (fallback if createArtifacts not yet initialized)    
function runPipelineInline() {
  const artifacts = {};
  const domainInfo = getDomain();
  const pack = DOMAIN_PACKS[domainInfo.primary] || DOMAIN_PACKS.generic;
  artifacts.domain = {
    primaryDomain: domainInfo.primary,
    secondaryDomains: domainInfo.secondary,
    confidence: domainInfo.confidence,
    domainName: pack.name,
    actors: pack.actors || [],
    entities: Object.entries(pack.entities || {}).map(([name, def]) => ({
      name, fields: Object.entries(def.fields || {}).map(([n, t]) => ({name:n, type:t})),
      enums: def.enums || {}, relations: def.relations || {}, indexes: def.indexes || [],
    })),
  };
  engineArtifacts = artifacts;
  window.engineArtifacts = artifacts;
  return artifacts;
}

//     Step 4: Blueprint    
async function generateBlueprint() {
  window._genStart = Date.now();
  window._sid = window._sid || 's_' + Date.now().toString(36);
  try {
    showToast('Menggenerate blueprint...', 'info');
    const domainInfo = getDomain();
    // Run the engine pipeline for structured data
    const blueprintArtifacts = (typeof runCorePipeline === 'function' ? runCorePipeline() : runPipelineInline());
    if (!blueprintArtifacts || !blueprintArtifacts.domain) {
      showToast('Gagal mendeteksi domain. Periksa input Anda.', 'error');
      return;
    }
    createArtifacts(blueprintArtifacts);

    //     AI Enhancement: Generate PRD with AI    
    // Rainbow glow on generate card
    var genCard = document.querySelector('#wizardContent .card');
    if (genCard) genCard.classList.add('ai-processing');

    try {
      // Build prompt from accumulated context
      const productName = state.productName || '-';
      const idea = state.idea || '-';
      const type = state.productType || selectedType || 'Web App';
      const domain = domainInfo.primary || 'generic';
      const catParts = [];
      if (state.productCategoryParent) catParts.push(state.productCategoryParent);
      if (state.productCategory) catParts.push(state.productCategory);
      const catStr = catParts.join(' → ') || '-';

      var techStr = '';
      if (window._aiTechRec) {
        var t = window._aiTechRec;
        techStr = '\nTech Stack:\n';
        var layers = ['frontend','backend','database','deployment'];
        for (var ti = 0; ti < layers.length; ti++) {
          var lr = t[layers[ti]];
          if (lr && lr.rec) techStr += '- ' + layers[ti] + ': ' + lr.rec + ' (alt: ' + (lr.alt || '-') + ')   ' + (lr.reason || '') + '\n';
        }
        if (t.extras && t.extras.length) {
          techStr += '- Extras: ' + t.extras.map(function(e) { return e.name; }).join(', ') + '\n';
          techStr += '- Alasan extras: ' + t.extras.map(function(e) { return e.reason || ''; }).join(', ') + '\n';
        }
      } else {
        techStr = '\nTech: Frontend=' + (state.tech?.frontend || 'N/A') + ', Backend=' + (state.tech?.backend || 'N/A') + ', DB=' + (state.tech?.database || 'N/A') + ', Deploy=' + (state.tech?.deployment || 'N/A') + '\n';
      }

      var surveyStr = '';
      if (state.answers && Object.keys(state.answers).length > 0) {
        surveyStr = '\nSurvey Answers:\n';
        for (var sk in state.answers) {
          var sq = _surveyQuestions.find(function(q) { return q.id === sk; });
          var qText = sq ? sq.question : sk;
          surveyStr += '- ' + qText + ': ' + (Array.isArray(state.answers[sk]) ? state.answers[sk].join(', ') : state.answers[sk]) + '\n';
        }
      }

      const prompt = [
        'Kamu adalah technical product manager senior yang bikin',
        'BLUEPRINT SIAP IMPLEMENTASI untuk tim developer Indonesia.',
        '',
        '=== KONTEKS LENGKAP PRODUK ===',
        'Nama: ' + productName,
        'Kategori: ' + catStr,
        'Tipe: ' + type,
        'Domain: ' + domain,
        'Ide: ' + idea,
        techStr,
        surveyStr,
        '',
        '=== TUGAS ===',
        'Bikin blueprint LENGKAP dalam Bahasa Indonesia.',
        '',
        'Struktur blueprint:',
        '## 1. Ringkasan Eksekutif',
        '2-3 kalimat gambaran produk, target user, dan value proposition.',
        '',
        '## 2. Domain & Aktor',
        'Domain: ' + domain + '. Siapa aja yg pake sistem ini, peran mereka.',
        '',
        '## 3. Entitas & Database',
        'Entitas utama + field penting + relasi antar entitas (1:1, 1:N, N:M).',
        '',
        '## 4. Modul & Fitur',
        'Modul-modul utama, fitur per modul, prioritas (MVP / v2).',
        '',
        '## 5. User Flows',
        'Alur lengkap per aktor   step-by-step dari awal sampai selesai.',
        '',
        '## 6. API Design',
        'Endpoint REST utama: method, path, deskripsi singkat.',
        '',
        '## 7. Security & Authorization',
        'Role, akses per modul, metode auth.',
        '',
        '## 8. Build Plan',
        'Sprint 1/2/3 (realistis untuk tim 1-3 developer). Deliverables per sprint.',
        '',
        'Aturan:',
        '- SEMUA KONTEN SPESIFIK untuk domain ' + domain + '   jangan generic',
        '- Jangan copy-paste dari template, bikin original sesuai konteks',
        '- Realistis untuk startup Indonesia dengan budget terbatas',
        '- Output markdown (JANGAN JSON)',
        '- Bahasa Indonesia natural (boleh campur Inggris untuk istilah teknis)'
      ].join('\n');

      const result = await callAI([
        { role: 'system', content: 'Kamu adalah TPM senior Indonesia yang bikin blueprint teknis. Jawab dalam Bahasa Indonesia. Output markdown.' },
        { role: 'user', content: prompt }
      ]);

      if (result && result.length > 100) {
        // Replace the PRD artifact with AI-generated content
        var prdIndex = state.artifacts.findIndex(function(a) { return a.id === 'prd'; });
        if (prdIndex >= 0) {
          state.artifacts[prdIndex].content = result;
          state.artifacts[prdIndex].label = 'AI Blueprint';
        }
      }
    } catch(aiErr) {
      console.warn('AI blueprint generation failed, using pipeline result:', aiErr);
      // Fallback   pipeline's createArtifacts already built the PRD
    } finally {
      if (genCard) genCard.classList.remove('ai-processing');
    }

    navigate('result');

    // Auto-save to localStorage
    try {
      const savedId = saveProject();
      state._projectId = savedId || state._projectId;
      saveState();
    } catch(e) { /* silent */ }

    // Track
    trackEvent('generation_completed', {
      domain: domainInfo.primary,
      confidence: domainInfo.confidence,
      success: true,
      idea: (state.idea || '').substring(0, 100),
    });
    trackUnknownDomain(state.idea, domainInfo.primary, domainInfo.confidence);

    try { await saveProjectToHistory(); } catch(e) { /* silent */ }
  } catch(e) {
    showToast('Gagal generate: ' + (e.message || 'Unknown error'), 'error');
    trackEvent('generation_completed', { domain: 'error', success: false, error: e.message });
    console.error('Generate failed:', e);
  }
  // Close loading overlay
  var _lo = document.getElementById('loadOverlay');
  if (_lo) _lo.classList.remove('open');
  // Remove rainbow glow
  document.querySelectorAll('#wizardContent .card').forEach(function(c) { c.classList.remove('ai-processing'); });
}

function formatAnswer(val) {
  if (Array.isArray(val)) return val.join(', ');
  return val || '-';
}

function dedupFeatures(features) {
    if (!features || !features.length) return [];

    const normalized = features.map(f => ({ original: f, lower: f.toLowerCase().trim() }));

    const groups = [
      { pattern: /^(notif|notification|push\s*notif|email\s*notif|alert|pemberitahuan)/i, target: 'Notification System', priority: 4 },
      { pattern: /^(role|permission|otorisasi|hak\s*akses|user\s*management|manajemen\s*user)/i, target: 'Role Management', priority: 3 },
      { pattern: /^(report|laporan|export|dashboard|ringkasan|summary|analytics|analitik)/i, target: 'Report & Analytics', priority: 3 },
      { pattern: /^(search|cari|filter|pencarian|sort|pagination)/i, target: 'Search & Filter', priority: 2 },
      { pattern: /^(import|upload|unggah)/i, target: 'Import/Export', priority: 2 },
      { pattern: /^(payment|pembayaran|billing|invoice|tagihan)/i, target: 'Payment & Billing', priority: 3 },
      { pattern: /^(login|register|auth|autentikasi|sign\s*up|sign\s*in)/i, target: 'Authentication', priority: 2 },
      { pattern: /^(setting|pengaturan|config|konfigurasi|preferensi|preference)/i, target: 'Settings', priority: 2 },
      { pattern: /^(activity|aktivitas|audit|log|riwayat|history)/i, target: 'Activity Log', priority: 2 },
    ];

    const matched = new Map();
    const unmatched = [];

    for (const item of normalized) {
      let found = false;
      for (const g of groups) {
        if (g.pattern.test(item.lower)) {
          if (!matched.has(g.target) || item.original.length > matched.get(g.target).source.original.length) {
            matched.set(g.target, { priority: g.priority, source: item });
          }
          found = true;
          break;
        }
      }
      if (!found) {
        const entityMatch = item.lower.match(/^(manajemen\s+|management\s+of\s+)?(.+?)(\s+management|\s+manajemen)?$/);
        if (entityMatch && entityMatch[2] && !['crud', 'data', 'item'].includes(entityMatch[2])) {
          const target = entityMatch[1] ? `${entityMatch[2].charAt(0).toUpperCase() + entityMatch[2].slice(1)} Management` : item.original;
          matched.set(target, { priority: 2, source: item });
        } else {
          unmatched.push(item);
        }
      }
    }

    const groupedResult = [...matched.entries()]
      .sort((a, b) => b[1].priority - a[1].priority)
      .map(([target]) => target);

    const unmatchedResult = unmatched.map(u => u.original);

    return [...groupedResult, ...unmatchedResult];
  }

  //     ENGINE FLAGS    
  const ENGINE_FLAGS = {
    domain: true,
    relationships: true,
    modules: true,
    validation: true,
    architecture: true,
    security: true,
    documentation: true,
    stateMachine: true,
    events: true,
    pages: false,
    uiFlows: true,
    tests: false,
    deployment: false,
    observability: false,
    aiAgents: false,
    costPricing: false,
    execution: false,
    migration: false,
    evolution: false,
  };

  // (Analytics functions are already defined at top level   see lines ~651)

  function getAnalytics() {
    try {
      const raw = localStorage.getItem('prdkit_analytics');
      return raw ? JSON.parse(raw) : {};
    } catch(e) { return {}; }
  }

  function getUnknownDomains() {
    try {
      const raw = localStorage.getItem('prdkit_unknown');
      return raw ? JSON.parse(raw) : [];
    } catch(e) { return []; }
  }

  function getFeedbackStats() {
    const data = getAnalytics();
    const fb = data.feedback_submitted || [];
    return {
      total: fb.length,
      avgRating: fb.length ? (fb.reduce((s, f) => s + (f.rating || 0), 0) / fb.length) : 0,
      categories: fb.reduce((acc, f) => { (f.categories || []).forEach(c => { acc[c] = (acc[c] || 0) + 1; }); return acc; }, {}),
    };
  }

  //     Project History (localStorage)    
  const HISTORY_KEY = 'prdkit_projects';

  function saveProject() {
    try {
      const list = loadProjects();
      const entry = {
        id: 'p_' + Date.now().toString(36),
        name: state.productName || 'Untitled',
        idea: (state.idea || '').substring(0, 200),
        domain: (engineArtifacts && engineArtifacts.domain) ? engineArtifacts.domain.primaryDomain : '',
        confidence: (engineArtifacts && engineArtifacts.domain) ? engineArtifacts.domain.confidence : 0,
        timestamp: new Date().toISOString(),
        state: JSON.stringify(state),
      };
      // Don't duplicate if same project
      const existingIdx = list.findIndex(p => p.name === entry.name && p.idea === entry.idea);
      if (existingIdx >= 0) list.splice(existingIdx, 1);
      list.unshift(entry);
      if (list.length > 50) list.length = 50;
      localStorage.setItem(HISTORY_KEY, JSON.stringify(list));
      return entry.id;
    } catch(e) { return null; }
  }

  function loadProjects() {
    try {
      const raw = localStorage.getItem(HISTORY_KEY);
      return raw ? JSON.parse(raw) : [];
    } catch(e) { return []; }
  }

  function deleteProject(id) {
    try {
      const list = loadProjects().filter(p => p.id !== id);
      localStorage.setItem(HISTORY_KEY, JSON.stringify(list));
    } catch(e) { /* silent */ }
  }

  function restoreProject(id) {
    try {
      const list = loadProjects();
      const proj = list.find(p => p.id === id);
      if (!proj || !proj.state) return false;
      Object.assign(state, JSON.parse(proj.state));
      saveState();
      return true;
    } catch(e) { return false; }
  }

  function openProject(id) {
    if (restoreProject(id)) {
      navigate('result');
      showToast('Project dipulihkan!', 'success');
    } else {
      showToast('Gagal memulihkan project.', 'error');
    }
  }

  //     ARTIFACT STORAGE    
  let engineArtifacts = {};

  //     V1 DOMAIN ENGINE    
  function runDomainEngine() {
    const domainInfo = getDomain();
    const pack = DOMAIN_PACKS[domainInfo.primary] || DOMAIN_PACKS.generic;
    const entities = Object.entries(pack.entities).map(([name, def]) => ({
      name,
      fields: Object.entries(def.fields || {}).map(([fName, fType]) => ({ name: fName, type: fType })),
      enums: def.enums || {},
      relations: def.relations || {},
      indexes: def.indexes || [],
    }));
    return {
      primaryDomain: domainInfo.primary,
      secondaryDomains: domainInfo.secondary,
      confidence: domainInfo.confidence,
      domainName: pack.name || domainInfo.primary,
      actors: pack.actors || [],
      entities,
      generatedAt: new Date().toISOString(),
    };
  }

  //     V2 RELATIONSHIP ENGINE    
  function runRelationshipEngine(domain) {
    const relations = [];
    for (const entityName of Object.keys(domain.entities || {})) {
      const entityRelations = {};
      const entityKey = entityName;
      // Access DOMAIN_PACKS to find relations for this entity
      const rawRelations = null;
      const domainPack = DOMAIN_PACKS[domain.primaryDomain];
      if (domainPack) {
        const raw = domainPack.entities[entityName]?.relations;
        if (raw) {
          entityRelations.belongsTo = (raw.belongsTo || []).map(parent => ({
            from: entityName,
            to: parent,
            type: 'belongsTo',
            cardinality: 'N:1',
            ownership: 'reference',
            onDelete: 'restrict',
          }));
          entityRelations.hasMany = (raw.hasMany || []).map(child => ({
            from: entityName,
            to: child,
            type: 'hasMany',
            cardinality: '1:N',
            ownership: entityName === child ? 'composition' : 'reference',
            onDelete: entityName === child ? 'cascade' : 'restrict',
          }));
          entityRelations.hasOne = (raw.hasOne || []).map(child => ({
            from: entityName,
            to: child,
            type: 'hasOne',
            cardinality: '1:1',
            ownership: 'composition',
            onDelete: 'cascade',
          }));
        }
      }
      relations.push({ entity: entityName, relations: entityRelations });
    }
    return { relations, generatedAt: new Date().toISOString() };
  }

  //     V5 MODULE ENGINE    
  function runModuleEngine(domain) {
    const domainName = domain.primaryDomain;
    const moduleDefs = {
      delivery: [
        { name: 'Order Management', slug: 'orders', entities: ['Order', 'OrderItem'], capabilities: ['Create Order', 'Manage Orders', 'Order History'], dependencies: [] },
        { name: 'Driver Management', slug: 'drivers', entities: ['Driver', 'Vehicle'], capabilities: ['Assign Drivers', 'Driver Tracking'], dependencies: ['Order Management'] },
        { name: 'Payments', slug: 'payments', entities: ['Payment'], capabilities: ['Payment Processing', 'Payment Reports'], dependencies: ['Order Management'] },
      ],
      inventory: [
        { name: 'Product Management', slug: 'products', entities: ['Product', 'Category', 'Batch'], capabilities: ['Manage Products', 'Track Batches'], dependencies: [] },
        { name: 'Stock Management', slug: 'stock', entities: ['StockMovement', 'Alert'], capabilities: ['Stock In/Out', 'Low Stock Alerts'], dependencies: ['Product Management'] },
        { name: 'Supplier Management', slug: 'suppliers', entities: ['Supplier', 'PurchaseOrder'], capabilities: ['Manage Suppliers', 'Purchase Orders'], dependencies: [] },
      ],
      crm: [
        { name: 'Lead Management', slug: 'leads', entities: ['Lead', 'Activity'], capabilities: ['Manage Leads', 'Track Activities'], dependencies: [] },
        { name: 'Pipeline Management', slug: 'pipeline', entities: ['Deal', 'Pipeline'], capabilities: ['Manage Pipeline', 'Track Deals'], dependencies: ['Lead Management'] },
        { name: 'Customer Management', slug: 'customers', entities: ['Contact', 'Company'], capabilities: ['Manage Contacts', 'Manage Companies'], dependencies: [] },
      ],
      booking: [
        { name: 'Reservation Management', slug: 'reservations', entities: ['Appointment', 'Availability'], capabilities: ['Manage Bookings', 'Check Availability'], dependencies: [] },
        { name: 'Service Management', slug: 'services', entities: ['Service', 'Staff'], capabilities: ['Manage Services', 'Manage Staff'], dependencies: [] },
      ],
      finance: [
        { name: 'Transaction Management', slug: 'transactions', entities: ['Transaction', 'Category'], capabilities: ['Record Transactions', 'Manage Categories'], dependencies: [] },
        { name: 'Invoicing', slug: 'invoices', entities: ['Invoice', 'Report'], capabilities: ['Create Invoices', 'Generate Reports'], dependencies: ['Transaction Management'] },
      ],
      commerce: [
        { name: 'Product Catalog', slug: 'catalog', entities: ['Product', 'Review'], capabilities: ['Browse Catalog', 'Manage Reviews'], dependencies: [] },
        { name: 'Order Management', slug: 'orders', entities: ['Order', 'OrderItem', 'Cart'], capabilities: ['Manage Orders', 'Manage Cart'], dependencies: ['Product Catalog'] },
        { name: 'Fulfillment', slug: 'fulfillment', entities: ['Shipment', 'Payment'], capabilities: ['Manage Shipping', 'Process Payments'], dependencies: ['Order Management'] },
      ],
      habit: [
        { name: 'Habit Tracking', slug: 'habits', entities: ['Habit', 'CheckIn', 'Streak'], capabilities: ['Create Habits', 'Daily Check-in', 'View Streaks'], dependencies: [] },
        { name: 'Insights', slug: 'insights', entities: ['Insight', 'Goal'], capabilities: ['View Insights', 'Set Goals'], dependencies: ['Habit Tracking'] },
      ],
      laundry: [
        { name: 'Order Management', slug: 'orders', entities: ['Order', 'LaundryItem'], capabilities: ['Create Orders', 'Track Status', 'Manage Items'], dependencies: [] },
        { name: 'Payments', slug: 'payments', entities: ['Payment'], capabilities: ['Process Payments', 'Payment History'], dependencies: ['Order Management'] },
      ],
      pos: [
        { name: 'Sales', slug: 'sales', entities: ['Sale', 'SaleItem'], capabilities: ['Process Sales', 'Print Receipts'], dependencies: [] },
        { name: 'Product Management', slug: 'products', entities: ['Product', 'Category'], capabilities: ['Manage Products', 'Track Stock'], dependencies: [] },
      ],
      erp: [
        { name: 'HR Management', slug: 'hr', entities: ['Employee', 'Department', 'Leave'], capabilities: ['Manage Employees', 'Manage Leave', 'Departments'], dependencies: [] },
        { name: 'Finance', slug: 'finance', entities: ['Budget'], capabilities: ['Manage Budgets', 'Track Spending'], dependencies: [] },
        { name: 'Task Management', slug: 'tasks', entities: ['Task'], capabilities: ['Assign Tasks', 'Track Progress'], dependencies: [] },
        { name: 'Asset Management', slug: 'assets', entities: ['Asset'], capabilities: ['Track Assets', 'Maintenance'], dependencies: [] },
      ],
      manufacturing: [
        { name: 'Production', slug: 'production', entities: ['ProductionOrder', 'MaterialConsumption'], capabilities: ['Manage Production Orders', 'Track Materials'], dependencies: [] },
        { name: 'Quality Control', slug: 'qc', entities: ['QCResult'], capabilities: ['Inspect Products', 'Track Quality'], dependencies: ['Production'] },
        { name: 'Inventory', slug: 'inventory', entities: ['Product', 'Material'], capabilities: ['Manage Materials', 'Manage Finished Goods'], dependencies: ['Production'] },
      ],
      healthcare: [
        { name: 'Appointment Management', slug: 'appointments', entities: ['Appointment'], capabilities: ['Schedule Appointments', 'Check-in', 'Manage Slots'], dependencies: [] },
        { name: 'Medical Records', slug: 'records', entities: ['MedicalRecord'], capabilities: ['Record Diagnoses', 'Prescriptions'], dependencies: ['Appointment Management'] },
        { name: 'Billing', slug: 'billing', entities: ['Payment'], capabilities: ['Process Payments', 'Generate Invoices'], dependencies: ['Appointment Management'] },
      ],
      education: [
        { name: 'Course Management', slug: 'courses', entities: ['Course', 'Lesson'], capabilities: ['Manage Courses', 'Manage Lessons'], dependencies: [] },
        { name: 'Enrollment', slug: 'enrollments', entities: ['Enrollment', 'Student'], capabilities: ['Manage Enrollments', 'Track Progress'], dependencies: ['Course Management'] },
        { name: 'Grading', slug: 'grading', entities: ['Assignment'], capabilities: ['Submit Assignments', 'Grade'], dependencies: ['Enrollment'] },
      ],
      property: [
        { name: 'Property Management', slug: 'properties', entities: ['Property', 'Unit'], capabilities: ['Manage Properties', 'Manage Units'], dependencies: [] },
        { name: 'Lease Management', slug: 'leases', entities: ['Lease', 'Tenant'], capabilities: ['Manage Leases', 'Manage Tenants'], dependencies: ['Property Management'] },
        { name: 'Billing', slug: 'billing', entities: ['Payment', 'Maintenance'], capabilities: ['Process Payments', 'Track Maintenance'], dependencies: ['Lease Management'] },
      ],
    };

    const modules = moduleDefs[domainName] || [
      { name: 'Data Management', slug: 'data', entities: ['Item', 'Activity'], capabilities: ['Manage Data', 'View Activity'], dependencies: [] },
      { name: 'Settings', slug: 'settings', entities: ['User'], capabilities: ['Manage Settings'], dependencies: [] },
    ];

    return { modules, generatedAt: new Date().toISOString() };
  }

  //     V8 VALIDATION ENGINE    
  function runValidationEngine(domain, relations) {
    const rules = [];
    for (const entity of (domain.entities || [])) {
      for (const field of (entity.fields || [])) {
        const rule = { entity: entity.name, field: field.name, type: field.type, rules: [] };
        if (field.name.endsWith('Id')) rule.rules.push({ type: 'required', message: `${field.name} wajib diisi` });
        if (field.name === 'email') rule.rules.push({ type: 'email', message: 'Format email tidak valid' });
        if (field.name === 'phone') rule.rules.push({ type: 'pattern', pattern: '^(\\+62|08)[0-9]{8,13}$', message: 'Format nomor telepon tidak valid' });
        if (field.type.includes('Float') || field.type.includes('Int')) rule.rules.push({ type: 'min', value: 0, message: 'Nilai harus lebih dari 0' });
        rule.rules.push({ type: 'required', message: `${field.name} wajib diisi` });
        rules.push(rule);
      }
    }
    return { fieldRules: rules, generatedAt: new Date().toISOString() };
  }

  //     V10 ARCHITECTURE ENGINE    
  function runArchitectureEngine(domain) {
    const patterns = {
      delivery: { pattern: 'Modular Monolith + Events', layers: ['api', 'service', 'repository', 'event'], services: 3, reasoning: 'Domain events needed for dispatch, tracking, payment. Team-friendly complexity.' },
      inventory: { pattern: 'Modular Monolith', layers: ['api', 'service', 'repository'], services: 2, reasoning: 'Standard CRUD with batch processing. Monolith sufficient.' },
      crm: { pattern: 'Modular Monolith + Events', layers: ['api', 'service', 'repository', 'event'], services: 3, reasoning: 'Pipeline changes need events for notifications. Modular for team scaling.' },
      booking: { pattern: 'Modular Monolith', layers: ['api', 'service', 'repository'], services: 2, reasoning: 'Calendar-based CRUD. Monolith sufficient for most scales.' },
      finance: { pattern: 'Modular Monolith', layers: ['api', 'service', 'repository'], services: 2, reasoning: 'Transactional integrity important. Single database, modular code.' },
      commerce: { pattern: 'Event-Driven Monolith', layers: ['api', 'service', 'repository', 'event', 'queue'], services: 4, reasoning: 'Stock sync, payment, shipping need async processing.' },
      habit: { pattern: 'Simple Monolith', layers: ['api', 'service', 'repository'], services: 1, reasoning: 'Low complexity, single purpose. Simplicity first.' },
      laundry: { pattern: 'Simple Monolith', layers: ['api', 'service', 'repository'], services: 2, reasoning: 'Order tracking workflow. Simple status-machine CRUD.' },
      pos: { pattern: 'Simple Monolith', layers: ['api', 'service', 'repository'], services: 2, reasoning: 'Transaction-heavy but simple data model. Monolith works.' },
      erp: { pattern: 'Modular Monolith', layers: ['api', 'service', 'repository'], services: 3, reasoning: 'Multiple domains (HR, finance, task). Modular code separation.' },
      manufacturing: { pattern: 'Modular Monolith + Events', layers: ['api', 'service', 'repository', 'event'], services: 3, reasoning: 'Production lifecycle events needed for material tracking and QC.' },
      healthcare: { pattern: 'Modular Monolith', layers: ['api', 'service', 'repository'], services: 3, reasoning: 'Patient data integrity critical. Modular by department.' },
      education: { pattern: 'Modular Monolith', layers: ['api', 'service', 'repository'], services: 2, reasoning: 'Course-Enrollment-Lesson hierarchy. Clean domain separation.' },
      property: { pattern: 'Simple Monolith', layers: ['api', 'service', 'repository'], services: 2, reasoning: 'Lease and payment tracking. Standard CRUD with status management.' },
    };
    const arch = patterns[domain.primaryDomain] || { pattern: 'Simple Monolith', layers: ['api', 'service', 'repository'], services: 1, reasoning: 'Start simple. Evolve when needed.' };
    return { ...arch, generatedAt: new Date().toISOString() };
  }

  //     V13 SECURITY ENGINE    
  function runSecurityEngine(domain, modules) {
    const roles = (domain.actors || []).map(actor => ({
      name: actor,
      permissions: ['read'],
      scopes: [],
    }));
    const adminRole = roles.find(r => r.name.toLowerCase().includes('admin'));
    if (adminRole) adminRole.permissions = ['read', 'write', 'delete', 'admin'];

    const policies = (modules.modules || []).map(mod => ({
      module: mod.name,
      read: ['admin', (domain.actors || [])[0]?.toLowerCase() || 'user'].filter(Boolean),
      write: ['admin'],
      delete: ['admin'],
    }));

    return { roles, policies, authType: 'jwt', mfa: 'optional', generatedAt: new Date().toISOString() };
  }

  //     V16 DOCUMENTATION ENGINE    
  function runDocumentationEngine(domain, relations, modules, validation, architecture, security) {
    const docs = {
      overview: `# ${domain.domainName}\n\nDomain: ${domain.primaryDomain}\nConfidence: ${(domain.confidence * 100).toFixed(0)}%\nActors: ${domain.actors.join(', ')}\n\n## Entities\n${domain.entities.map(e => `- ${e.name}: ${e.fields.length} fields, ${Object.keys(e.enums || {}).length} enums`).join('\n')}`,
      architecture: `# Architecture\n\nPattern: ${architecture.pattern}\nLayers: ${architecture.layers.join(', ')}\nServices: ${architecture.services}\n\n## Reasoning\n${architecture.reasoning}`,
      entities: `# Entity Definitions\n\n${domain.entities.map(e => `## ${e.name}\n${e.fields.map(f => `- ${f.name}: ${f.type}`).join('\n')}`).join('\n\n')}`,
      modules: `# Modules\n\n${(modules.modules || []).map(m => `## ${m.name}\n- Slug: ${m.slug}\n- Entities: ${(m.entities || []).join(', ')}\n- Capabilities: ${(m.capabilities || []).join(', ')}`).join('\n\n')}`,
      security: `# Security\n\n## Roles\n${security.roles.map(r => `- ${r.name}: ${r.permissions.join(', ')}`).join('\n')}\n\n## Policies\n${security.policies.map(p => `- ${p.module}: read(${p.read.join(',')}), write(${p.write.join(',')})`).join('\n')}`,
      generatedAt: new Date().toISOString(),
      };
      return docs;
      }

      //     V3 STATE MACHINE ENGINE    
      function runStateMachineEngine(domain) {
      // Extract state machines from entity enums that look like lifecycle statuses
      const lifecycleEntities = ['Order', 'Delivery', 'Reservation', 'Appointment', 'Deal', 'Task', 'PurchaseOrder',
        'ProductionOrder', 'Expense', 'Leave', 'Invoice', 'Payment', 'Shipment', 'Ticket', 'WorkOrder',
        'Booking', 'Lease', 'Maintenance', 'Attendance', 'Recruitment', 'Application'];
      const pack = DOMAIN_PACKS[domain.primaryDomain];
      if (!pack) return { stateMachines: [] };

      const stateMachines = [];
      for (const [entityName, entityDef] of Object.entries(pack.entities)) {
        const isLifecycle = lifecycleEntities.some(le => entityName.toLowerCase().includes(le.toLowerCase()));
        if (!isLifecycle) continue;

        // Find status enum
        const statusEnum = Object.entries(entityDef.enums || {}).find(([name]) =>
          name.toLowerCase().includes('status') || name.toLowerCase().includes('state'));
        if (!statusEnum) continue;

        const states = statusEnum[1];
        // Generate transitions: each state → next state (forward flow)
        const transitions = [];
        const terminalStates = [];
        const cancellations = ['CANCELLED', 'CANCELED', 'CANCELLED', 'REJECTED', 'REFUNDED', 'DELETED', 'ARCHIVED'];
        const terminalKeywords = ['COMPLETED', 'DONE', 'FINISHED', 'CLOSED', 'WON', 'LOST', 'GRADUATED', 'EXPIRED', 'TERMINATED'];

        for (let i = 0; i < states.length; i++) {
          const s = states[i];
          if (terminalKeywords.includes(s) || cancellations.includes(s)) {
            terminalStates.push(s);
          }
          // Forward transition
          if (i < states.length - 1 && !terminalKeywords.includes(states[i])) {
            transitions.push({ from: s, to: states[i + 1] });
          }
          // Cancellation from any non-terminal state
          if (cancellations.includes(s) && i > 0) {
            transitions.push({ from: states[0], to: s, note: 'Cancellation' });
          }
        }

        stateMachines.push({
          entity: entityName,
          states,
          transitions,
          terminalStates,
        });
      }

      return { stateMachines, generatedAt: new Date().toISOString() };
      }

      //     V7 UI FLOW ENGINE    
      function runUIFlowEngine(domain) {
      const pack = DOMAIN_PACKS[domain.primaryDomain];
      if (!pack) return { journeys: [] };

      // Generate actor journeys from domain flows
      const journeys = pack.actors.map(actor => {
        // Build a journey from the domain flows, attributed to this actor
        const relevantFlows = pack.flows.filter(f =>
          f.toLowerCase().includes(actor.toLowerCase()) ||
          ['admin', 'staff', 'user', 'customer'].some(generic =>
            actor.toLowerCase() === generic.toLowerCase() && f.toLowerCase().includes('admin' ? 'admin' : '')));
        return {
          actor,
          steps: relevantFlows.length > 0
            ? relevantFlows.slice(0, 5).map(f => ({ action: f.split(' ')[0]?.trim() || f, description: f }))
            : [{ action: 'Menggunakan sistem', description: `${actor} menggunakan sistem` }],
        };
      });

      return { journeys, generatedAt: new Date().toISOString() };
      }

      //     V4 EVENT ENGINE    
      function runEventEngine(domain) {
        const pack = DOMAIN_PACKS[domain.primaryDomain];
        if (!pack) return { events: [] };

        // Map common event patterns from entity names + flows
        const events = [];
        for (const entityName of Object.keys(pack.entities || {})) {
          const base = entityName;
          // Generate lifecycle events
          const eventPatterns = [
            { name: base + 'Created', desc: base + ' created', fields: [base.toLowerCase() + 'Id'] },
            { name: base + 'Updated', desc: base + ' updated', fields: [base.toLowerCase() + 'Id'] },
          ];

          // If entity has status enum, add transition events
          const hasStatus = Object.values(pack.entities[entityName]?.enums || {}).some(e =>
            e.some(v => ['PENDING', 'ACTIVE', 'DRAFT'].includes(v)));
          if (hasStatus) {
            eventPatterns.push({ name: base + 'Completed', desc: base + ' lifecycle completed', fields: [base.toLowerCase() + 'Id', 'completedAt'], priority: 'high' });
          }

          events.push(...eventPatterns);
        }

        // Add domain-level events from flows
        const flowEvents = [
          { name: 'PaymentReceived', producer: 'Payment', payload: { orderId: 'string', amount: 'float', method: 'string' }, consumers: ['Order', 'Notification'], priority: 'high' },
          { name: 'PaymentFailed', producer: 'Payment', payload: { orderId: 'string', reason: 'string' }, consumers: ['Order', 'Notification'], priority: 'high' },
          { name: 'NotificationSent', producer: 'Notification', payload: { recipientId: 'string', channel: 'string', type: 'string' }, consumers: ['Analytics'], priority: 'low' },
        ];

        // Only add domain events if they match the entities
        const entityNamesLower = Object.keys(pack.entities).map(e => e.toLowerCase());
        flowEvents.forEach(fe => {
          const producerEntity = Object.keys(pack.entities).find(e =>
            e.toLowerCase().includes(fe.producer.toLowerCase()));
          if (producerEntity) {
            events.push({
              name: fe.name,
              producer: producerEntity,
              payload: fe.payload,
              consumers: fe.consumers,
              priority: fe.priority,
            });
          }
        });

        return { events, generatedAt: new Date().toISOString() };
      }

      //     CORE PIPELINE    
  function runCorePipeline() {
    const artifacts = {};
    if (ENGINE_FLAGS.domain) artifacts.domain = runDomainEngine();
    if (ENGINE_FLAGS.relationships && artifacts.domain) artifacts.relations = runRelationshipEngine(artifacts.domain);
    if (ENGINE_FLAGS.modules && artifacts.domain) artifacts.modules = runModuleEngine(artifacts.domain);
    if (ENGINE_FLAGS.validation && artifacts.domain && artifacts.relations) artifacts.validation = runValidationEngine(artifacts.domain, artifacts.relations);
    if (ENGINE_FLAGS.architecture && artifacts.domain) artifacts.architecture = runArchitectureEngine(artifacts.domain);
    if (ENGINE_FLAGS.security && artifacts.domain && artifacts.modules) artifacts.security = runSecurityEngine(artifacts.domain, artifacts.modules);
    if (ENGINE_FLAGS.documentation) artifacts.documentation = runDocumentationEngine(
      artifacts.domain || runDomainEngine(),
      artifacts.relations || {},
      artifacts.modules || runModuleEngine(runDomainEngine()),
      artifacts.validation || {},
      artifacts.architecture || runArchitectureEngine(runDomainEngine()),
      artifacts.security || {}
    );
    if (ENGINE_FLAGS.stateMachine && artifacts.domain) artifacts.stateMachine = runStateMachineEngine(artifacts.domain);
    if (ENGINE_FLAGS.uiFlows && artifacts.domain) artifacts.uiFlows = runUIFlowEngine(artifacts.domain);
    if (ENGINE_FLAGS.events && artifacts.domain) artifacts.events = runEventEngine(artifacts.domain);
    engineArtifacts = artifacts;
    window.engineArtifacts = artifacts;
    return artifacts;
  }

  // Expose engine pipeline globally
  window.runCorePipeline = runCorePipeline;

  function createArtifacts(engineArtifactsFromPipeline) {
    // Store engine artifacts globally
    if (engineArtifactsFromPipeline) {
      engineArtifacts = engineArtifactsFromPipeline;
    }

    const domainInfo = getDomain();
    const domain = domainInfo.primary;
    const pack = DOMAIN_PACKS[domain] || DOMAIN_PACKS.generic;
    const secondaryPacks = domainInfo.secondary.map(d => DOMAIN_PACKS[d]).filter(Boolean);

    const productName = state.productName.trim() || normalizeTitle(state.idea);
    const tech = buildTechStack();
    const targetUser = getAnswer('target-user', pack.actors.join(', '));
    const mainOutcome = getAnswer('main-outcome', 'user bisa menyelesaikan workflow utama dengan cepat, jelas, dan minim error');
    const features = dedupFeatures(getSelectedMvp(pack));
    const metric = getAnswer('success-metric', pack.metrics[0] || 'User engagement');
    const scale = getAnswer('scale', '100-1.000 user');
    const monetization = getAnswer('monetization', 'Belum diputuskan');
    const reference = getAnswer('reference', 'Belum ada referensi spesifik.');
    const roles = getAnswer('roles', state.extras.includes('auth') ? pack.actors.join(', ') : 'Admin tunggal');
    const payment = getAnswer('payment-flow', state.extras.includes('payment') ? 'Subscription bulanan dengan webhook payment' : 'Tidak masuk MVP');
    const aiBehavior = getAnswer('ai-usage', state.extras.includes('ai') ? 'AI membantu rekomendasi, tetapi keputusan final tetap di tangan user.' : 'Tidak ada AI khusus di MVP.');
    const entityNames = Object.keys(pack.entities);
    const targetUser2 = getAnswer('target-user', pack.actors.join(', '));
    const ideaText = state.idea.trim();
    const roleList = roles.split(',').map(r => r.trim());

    function buildActorDesc(actor, dom) {
      const ds = {
        delivery: { Merchant: 'Pemilik usaha yang menerima order dari customer', Customer: 'Pelanggan yang memesan layanan delivery', Driver: 'Kurir yang mengantar pesanan', Admin: 'Operator sistem yang mengelola merchant, driver, dan area' },
        inventory: { Owner: 'Pemilik bisnis yang melihat ringkasan stok dan laporan', 'Staff Gudang': 'Staff yang mencatat stok masuk/keluar', 'Staff Purchasing': 'Staff yang membuat PO ke supplier', Supplier: 'Pihak eksternal yang memasok barang' },
        crm: { Sales: 'Sales yang mengelola lead dan deal pipeline', 'Sales Manager': 'Manager yang mengawasi performa sales', Customer: 'Prospek atau pelanggan di pipeline', Admin: 'Administrator sistem CRM' },
          booking: { Customer: 'Pelanggan yang melakukan reservasi', Staff: 'Staff yang melayani customer dan mengelola jadwal', Admin: 'Admin yang mengatur layanan dan staff', Owner: 'Pemilik bisnis yang melihat laporan booking' },
          finance: { Owner: 'Pemilik bisnis yang melihat laporan keuangan', 'Finance Admin': 'Admin yang mencatat transaksi harian', Accountant: 'Akuntan yang melakukan rekonsiliasi', Auditor: 'Auditor yang memverifikasi laporan keuangan' },
          commerce: { Buyer: 'Pembeli yang browsing dan checkout produk', Seller: 'Penjual yang mengelola toko dan produk', Admin: 'Admin marketplace yang mengawasi transaksi', Support: 'Customer support yang menangani komplain' },
          habit: { User: 'Pengguna yang mencatat kebiasaan harian', Coach: 'Pelatih yang memonitor progress user', Admin: 'Administrator platform' },
          laundry: { Customer: 'Pelanggan yang menggunakan jasa laundry', Staff: 'Staff yang mencatat dan memproses order laundry', Owner: 'Pemilik bisnis laundry yang melihat laporan', Driver: 'Kurir yang mengantar laundry ke customer' },
          pos: { Cashier: 'Kasir yang melayani transaksi di toko', Manager: 'Manager yang mengawasi operasional toko', Owner: 'Pemilik bisnis yang melihat laporan penjualan' },
          erp: { Admin: 'Administrator sistem yang mengelola master data', Manager: 'Manager yang menyetujui leave dan task', Finance: 'Finance yang mengelola budget dan pengeluaran', Staff: 'Karyawan yang mengajukan leave dan mengerjakan task' },
          manufacturing: { 'Production Manager': 'Manager yang membuat dan memonitor production order', Operator: 'Operator yang menjalankan produksi di lantai', 'QC Staff': 'Staff quality control yang menginspeksi hasil produksi', 'Warehouse Staff': 'Staff gudang yang mengelola material dan produk jadi' },
          healthcare: { Doctor: 'Dokter yang melakukan konsultasi dan diagnosis', Nurse: 'Perawat yang membantu dokter dan merawat pasien', Patient: 'Pasien yang berobat ke klinik', Admin: 'Admin yang mengelola data klinik', Receptionist: 'Resepsionis yang mengatur jadwal appointment' },
          education: { Student: 'Siswa yang mengikuti course dan mengerjakan assignment', Teacher: 'Guru yang mengajar dan menilai assignment', Admin: 'Admin yang mengelola course dan enrollment', Parent: 'Orang tua yang memonitor progress anak' },
          property: { Owner: 'Pemilik properti yang menyewakan unit', Tenant: 'Penyewa yang tinggal di unit properti', Agent: 'Agen properti yang membantu pemasaran', Admin: 'Admin yang mengelola data properti dan lease' },
      };
      return (ds[dom] && ds[dom][actor]) || `${actor} yang menggunakan sistem`;
    }

    const actorsTable = pack.actors.map(a => `| ${a} | ${buildActorDesc(a, domain)} |`).join('\n');
    const flowsSection = pack.flows.map((f, i) => `${i + 1}. ${f}`).join('\n');
    const endpointsTable = pack.endpoints.map(e => {
      const parts = e.trim().split(/\s{2,}/);
      if (parts.length >= 2) {
        const [method, endpoint, ...descParts] = parts;
        return `| ${method} | ${endpoint} | ${descParts.join(' ') || '-'} |`;
      }
      return '';
    }).filter(Boolean).join('\n');
    const metricsList = pack.metrics.map(m => `- ${m}`).join('\n');

    // Build entity models
    const entityModels = entityNames.map(en => {
      const ed = pack.entities[en];
      if (!ed) return '';
      const lines = ['  id String @id @default(uuid())'];
      for (const [fn, ft] of Object.entries(ed.fields || {})) {
        const opt = ft.includes('?') ? '?' : '';
        const pt = ft.replace(/ @.*$/, '').replace(/\?$/, '');
        const annots = ft.match(/@[\w()]+/g) || [];
        const annotStr = annots.length ? ' ' + annots.join(' ') : '';
        lines.push(`  ${fn} ${pt}${opt}${annotStr}`);
      }
      return `### ${en}\n\`\`\`prisma\n${lines.join('\n')}\n\`\`\``;
    }).filter(Boolean).join('\n\n');

    // Build enums
    let enumBlock = '';
    for (const [en, ed] of Object.entries(pack.entities)) {
      if (ed.enums) {
        for (const [enumName, enumValues] of Object.entries(ed.enums)) {
          enumBlock += `enum ${enumName} {\n  ${enumValues.join('\n  ')}\n}\n\n`;
        }
      }
    }

    // Domain-specific business rules
    const domainHints = {
      delivery: ['User dapat membuat order baru dengan memilih merchant, item, dan alamat pengiriman', 'Sistem harus memvalidasi alamat pengiriman dan ketersediaan driver', 'Driver dapat melihat order yang ditugaskan dan mengupdate status pengiriman', 'Sistem mencatat timestamp setiap perubahan status delivery', 'Order yang sudah diassign tidak bisa dibatalkan oleh customer tanpa konfirmasi merchant', 'Validasi: alamat pengiriman wajib diisi dan minimal 10 karakter', 'Error message: "Tidak ada driver tersedia di area Anda saat ini"', 'Edge case: driver sedang dalam perjalanan dan order dibatalkan oleh system'],
      inventory: ['User dapat menambah produk baru dengan SKU, nama, satuan, dan harga', 'Sistem harus memvalidasi SKU unik sebelum menyimpan produk', 'Stok masuk dicatat dengan nomor batch, tanggal kedaluwarsa, dan lokasi rak', 'Stok keluar divalidasi terhadap jumlah tersedia, dan gagal jika stok tidak mencukupi', 'Low stock alert muncul ketika stok di bawah batas minimum yang ditentukan', 'Validasi: jumlah stok tidak boleh negatif', 'Error message: "Stok tidak mencukupi. Tersedia: {qty}"', 'Edge case: dua admin melakukan stok keluar bersamaan   pakai optimistic lock atau queue'],
      crm: ['User dapat membuat lead baru dengan nama, perusahaan, dan nomor kontak', 'Sistem harus mencatat sumber lead (referral, website, cold call)', 'Lead dapat dipindahkan antar status pipeline (new -> contacted -> qualified -> deal)', 'Sistem mencatat timestamp setiap perubahan status lead', 'User dapat menambahkan follow-up activity (call, email, meeting) ke lead', 'Validasi: nomor telepon minimal 10 digit', 'Error message: "Nomor telepon tidak valid. Minimal 10 digit"', 'Edge case: lead dihapus oleh admin saat sales sedang mengedit   tampilkan notifikasi'],
      habit: ['User dapat membuat habit baru dengan nama, frekuensi (harian/mingguan), dan target', 'Daily check-in selesai dengan satu tap   mencatat timestamp dan streak otomatis', 'Streak terputus jika user melewatkan 1 hari untuk habit harian', 'Progress calendar menunjukkan hari hijau (selesai), abu-abu (terlewat), dan streak saat ini', 'Sistem mengirim insight mingguan berdasarkan pola check-in 7 hari terakhir', 'Validasi: nama habit tidak boleh kosong, maks 100 karakter', 'Error message: "Nama habit wajib diisi"', 'Edge case: user check-in jam 23:59 dan 00:01   treat berdasarkan timezone user'],
      booking: ['User dapat melihat slot tersedia berdasarkan layanan dan tanggal yang dipilih', 'Booking memblokir slot selama 15 menit (pending) sebelum dikonfirmasi', 'Sistem harus mencegah double-booking pada slot yang sama', 'User dapat reschedule booking maksimal 24 jam sebelum jadwal', 'Sistem mengirim reminder 1 jam sebelum jadwal via notifikasi', 'Validasi: waktu booking harus di masa depan, tidak boleh di masa lalu', 'Error message: "Slot sudah di booking. Pilih waktu lain"', 'Edge case: admin menghapus layanan yang memiliki booking aktif   arsipkan booking'],
      finance: ['User dapat mencatat pemasukan dan pengeluaran dengan kategori, nominal, dan tanggal', 'Sistem harus menghitung saldo otomatis berdasarkan semua transaksi', 'Ringkasan cashflow bulanan: total pemasukan, total pengeluaran, selisih', 'User dapat membuat invoice sederhana dengan generate nomor otomatis', 'Export laporan ke CSV dengan rentang tanggal yang dipilih', 'Validasi: nominal harus lebih dari 0', 'Error message: "Nominal harus lebih dari 0"', 'Edge case: transaksi di masa depan (pre-order)   treat sebagai pending'],
      commerce: ['User dapat melihat katalog produk dengan gambar, harga, dan stok', 'User dapat menambahkan produk ke cart dan mengubah quantity', 'Checkout memvalidasi stok dan menghitung total otomatis (termasuk ongkir jika ada)', 'Sistem mengurangi stok setelah pembayaran berhasil dikonfirmasi', 'User dapat melihat status order: pending, diproses, dikirim, selesai', 'Validasi: quantity tidak boleh melebihi stok tersedia', 'Error message: "Stok tidak mencukupi untuk {produk}"', 'Edge case: 2 user checkout produk yang sama di saat bersamaan   pesanan pertama yang di approve'],
      restaurant: ['Customer order menu → waiter mengambil order → kitchen prepares → serves → payment', 'Waiter harus mencatat order dengan benar dan mengkonfirmasi ke customer', 'Kitchen menerima order dan mempersiapkan sesuai request', 'Served ke meja customer setelah selesai dimasak', 'Payment dilakukan setelah customer selesai makan', 'Validasi: menu item harus tersedia', 'Error message: "Menu tidak tersedia"', 'Edge case: customer cancel setelah cooking starts   full price masih dikenakan'],
      cafe: ['Customer order di counter → barista membuat minuman → customer pick up → payment', 'Barista harus mengkonfirmasi order sebelum memulai proses', 'Customer mengambil minuman di pick-up area setelah notifikasi', 'Payment dilakukan saat order', 'Sistem mencatat antrian order untuk pick-up', 'Validasi: minimal order Rp 5,000', 'Error message: "Minimal order Rp 5.000"', 'Edge case: customer claims wrong order   verifikasi receipt'],
      bakery: ['Baker bakes in batches → display produk → customer buys → payment', 'Produk ditampilkan di display case dengan harga dan label', 'Customer memilih produk dan melakukan pembayaran', 'Sistem mengurangi stock setelah payment sukses', 'Stock opname dilakukan setiap akhir hari', 'Validasi: stock harus > 0', 'Error message: "Produk habis"', 'Edge case: unsold items di akhir hari   diskon atau donasi'],
      catering: ['Customer memilih package → confirm menu → cook on schedule → deliver → payment', 'Customer harus memilih package menu yang tersedia', 'Konfirmasi menu dilakukan H-1 sebelum event', 'Masakan dipersiapkan sesuai jadwal delivery', 'Delivery dilakukan ke alamat customer', 'Validasi: order harus 24h sebelum event', 'Error message: "Minimal order H-1"', 'Edge case: delivery address salah   kontak customer segera'],
      hotel: ['Guest reserves room → check-in → stay → housekeeping → check-out → payment', 'Reservasi mengunci kamar untuk tanggal tertentu', 'Check-in memverifikasi identitas guest', 'Housekeeping membersihkan kamar setiap hari', 'Check-out menghitung total biaya menginap', 'Validasi: check-out harus setelah check-in', 'Error message: "Check-out harus setelah check-in"', 'Edge case: guest extends stay   cek availability dan adjust rate'],
      salon: ['Customer books service → arrives → stylist serves → payment → review', 'Booking memblokir slot waktu stylist', 'Customer check-in saat tiba di salon', 'Stylist memberikan layanan sesuai booking', 'Review diberikan setelah service selesai', 'Validasi: appointment harus di masa future', 'Error message: "Slot tidak tersedia"', 'Edge case: stylist calls in sick   reassign atau reschedule'],
      barbershop: ['Customer walks in atau books → queue → barber serves → payment', 'Customer check-in untuk masuk antrian', 'Barber memanggil customer berdasarkan antrian', 'Layanan diberikan sesuai permintaan customer', 'Payment dilakukan setelah selesai', 'Validasi: customer harus check in first', 'Error message: "Antrian penuh"', 'Edge case: customer wants service beyond menu   inform price first'],
      workshop: ['Customer brings vehicle → diagnose → estimate → repair → payment', 'Teknisi mendiagnosa masalah kendaraan', 'Estimasi biaya diberikan sebelum repair', 'Repair dilakukan setelah disetujui customer', 'Payment dilakukan setelah repair selesai', 'Validasi: spare part harus in stock', 'Error message: "Spare part tidak tersedia"', 'Edge case: repair takes longer dari estimasi   notifikasi customer'],
      cleaning_service: ['Customer orders → assign cleaner → clean → verify → payment', 'Customer memilih paket cleaning dan jadwal', 'Cleaner ditugaskan berdasarkan area dan availability', 'Cleaning dilakukan sesuai standar operasional', 'Customer verifikasi hasil cleaning', 'Validasi: address harus di service area', 'Error message: "Area belum terjangkau"', 'Edge case: cleaner tidak datang   reassign atau refund'],
      field_service: ['Customer requests → dispatcher assigns → technician arrives → service → complete', 'Dispatcher menugaskan technician berdasarkan skill dan lokasi', 'Technician melakukan service di lokasi customer', 'Service completion dicatat di sistem', 'Customer sign off setelah service selesai', 'Validasi: technician harus certified', 'Error message: "Teknisi tidak tersedia"', 'Edge case: parts needed tapi tidak di inventory   order first'],
      accounting: ['Accountant records transactions → journal → ledger → trial balance → report', 'Setiap transaksi dicatat di jurnal umum', 'Posting ke ledger sesuai akun yang tepat', 'Trial balance dibuat untuk verifikasi keseimbangan', 'Laporan keuangan dihasilkan secara periodik', 'Validasi: debit = credit', 'Error message: "Debit dan credit tidak balance"', 'Edge case: previous period needs correction   gunakan reversing entry'],
      invoicing: ['Create invoice → send to customer → remind if overdue → receive payment → reconcile', 'Invoice dibuat dengan nomor unik dan detail transaksi', 'Invoice dikirim ke customer via email', 'Reminder otomatis dikirim jika overdue', 'Payment diterima dan direkonsiliasi', 'Validasi: invoice amount > 0', 'Error message: "Amount invoice harus lebih dari 0"', 'Edge case: customer disputes invoice   flag for review'],
      expense: ['Employee submits → manager approves → finance reimburses → categorize → report', 'Employee mengajukan expense report dengan bukti', 'Manager mereview dan approve/reject', 'Finance melakukan reimbursment ke employee', 'Expense dikategorikan untuk laporan', 'Validasi: receipt required untuk > 100k', 'Error message: "Bukti transaksi wajib untuk nominal di atas Rp 100.000"', 'Edge case: expense exceeds department budget   need director approval'],
      payroll: ['Collect attendance → calculate salary → deductions → approve → disburse → report', 'Attendance dikumpulkan untuk periode tertentu', 'Salary dihitung berdasarkan kehadiran dan komponen gaji', 'Deductions dipotong sesuai ketentuan', 'Payroll disetujui dan didisburse', 'Validasi: salary harus > minimum wage', 'Error message: "Gaji tidak boleh di bawah UMR"', 'Edge case: employee joins mid-month   prorate salary'],
      budgeting: ['Department proposes → finance reviews → approved → track spending → adjust → report', 'Department mengajukan proposal anggaran', 'Finance mereview dan menyetujui', 'Pengeluaran di-track terhadap anggaran', 'Adjustment dilakukan jika diperlukan', 'Validasi: total budget harus match company target', 'Error message: "Total melebihi anggaran perusahaan"', 'Edge case: emergency spending   gunakan contingency fund'],
      attendance: ['Employee checks in → tracks hours → approves leave → calculate overtime → report', 'Check-in mencatat waktu kedatangan', 'Check-out mencatat waktu pulang', 'Leave diapprove oleh manager', 'Overtime dihitung otomatis', 'Validasi: check-in time harus recorded', 'Error message: "Absensi gagal. Hubungi HR"', 'Edge case: employee lupa check-out   auto-calculate atau manual input'],
      recruitment: ['HR posts job → candidates apply → screen → interview → offer → hire', 'Job vacancy dipublikasikan di portal', 'Kandidat mengirimkan aplikasi', 'HR melakukan screening awal', 'Interview dijadwalkan untuk kandidat terpilih', 'Offer diberikan ke kandidat terbaik', 'Validasi: candidate harus meet minimum qualifications', 'Error message: "Kandidat tidak memenuhi kualifikasi"', 'Edge case: offer rejected   move ke second candidate'],
      employee_management: ['HR creates employee record → assign department → manage documents → transfer → offboard', 'Employee record dibuat dengan data lengkap', 'Employee ditugaskan ke department', 'Dokumen karyawan dikelola di sistem', 'Transfer atau promosi dicatat', 'Offboarding dilakukan saat resign', 'Validasi: employee ID harus unique', 'Error message: "ID karyawan sudah terdaftar"', 'Edge case: employee resigns tanpa notice   process offboarding ASAP'],
      performance_management: ['Set goals → mid-year review → annual review → rating → feedback → improvement plan', 'Goals ditetapkan di awal periode', 'Mid-year review mengevaluasi progress', 'Annual review memberikan rating final', 'Feedback diberikan ke employee', 'Improvement plan dibuat jika perlu', 'Validasi: goals harus SMART', 'Error message: "Goal harus spesifik dan terukur"', 'Edge case: employee disagree dengan rating   escalation ke HR'],
      fleet: ['Fleet manager assigns vehicle → driver takes trip → track fuel → maintenance → report', 'Vehicle ditugaskan ke driver untuk trip', 'Driver mencatat trip details', 'Fuel consumption di-track', 'Maintenance dijadwalkan secara periodik', 'Validasi: driver harus memiliki valid license', 'Error message: "Driver tidak memiliki SIM valid"', 'Edge case: vehicle breaks down during trip   dispatch backup'],
      courier: ['Sender creates shipment → courier picks up → sort → transit → deliver → confirm', 'Shipment dibuat dengan detail pengirim dan penerima', 'Courier pick up paket dari pengirim', 'Paket di-sort di hub', 'Transit ke tujuan', 'Paket di-deliver dan dikonfirmasi', 'Validasi: address harus valid', 'Error message: "Alamat tidak valid"', 'Edge case: recipient tidak di rumah   reschedule delivery'],
      trucking: ['Shipper books load → dispatcher assigns truck → driver loads → transit → deliver → confirm', 'Load booking dibuat dengan detail barang', 'Dispatcher menugaskan truck dan driver', 'Driver melakukan loading barang', 'Transit ke tujuan pengiriman', 'Delivery dikonfirmasi oleh penerima', 'Validasi: load weight tidak boleh exceed capacity', 'Error message: "Berat melebihi kapasitas kendaraan"', 'Edge case: road closure   reroute dan notifikasi customer'],
      digital_product: ['Creator creates product → list in store → customer buys → delivers automatically → support', 'Digital product dibuat dengan file dan deskripsi', 'Product di-list di store', 'Customer membeli dan pembayaran diverifikasi', 'Product di-deliver otomatis ke customer', 'Support diberikan jika ada masalah', 'Validasi: file harus di bawah 2GB', 'Error message: "File terlalu besar. Maksimal 2GB"', 'Edge case: download link expires   allow regeneration'],
      membership: ['User registers → chooses tier → pays → accesses benefits → renews or downgrades', 'User mendaftar dengan data diri', 'User memilih membership tier', 'Payment dikonfirmasi sebelum akses diberikan', 'User mengakses benefits sesuai tier', 'Membership bisa diperpanjang atau di-downgrade', 'Validasi: payment harus confirmed sebelum access', 'Error message: "Pembayaran belum dikonfirmasi"', 'Edge case: payment fails tapi user sudah granted access   revoke until resolved'],
      course_platform: ['Instructor creates course → publish → student enrolls → learns → takes quiz → certificate', 'Course dibuat dengan materi dan quiz', 'Course di-publish setelah review', 'Student enroll ke course', 'Student mengakses lesson secara berurutan', 'Quiz diambil untuk evaluasi', 'Validasi: max students tidak boleh exceeded', 'Error message: "Kelas penuh"', 'Edge case: student wants refund setelah 50% progress   pro-rated refund'],
      farm: ['Farmer plants crop → maintains → harvests → stores → sells', 'Petani menanam sesuai musim dan jenis tanaman', 'Perawatan dilakukan secara rutin', 'Panen dilakukan saat tanaman siap', 'Hasil panen disimpan di gudang', 'Hasil panen dijual ke buyer', 'Validasi: planting season harus valid', 'Error message: "Bukan musim tanam yang tepat"', 'Edge case: crop failure karena weather   insurance claim process'],
      livestock: ['Farmer buys animal → feeds → health check → breeds → sells', 'Hewan dibeli dari supplier', 'Pakan diberikan sesuai jadwal', 'Health check dilakukan oleh dokter hewan', 'Pembibitan dilakukan untuk reproduksi', 'Hewan dijual saat siap', 'Validasi: animal harus vaccinated', 'Error message: "Hewan belum divaksinasi"', 'Edge case: disease outbreak   quarantine dan report'],
      poultry: ['Farmer gets chicks → raises → feeds → vaccinates → sells', 'DOC (Day Old Chick) dibeli dari hatchery', 'Pemeliharaan dilakukan di kandang', 'Pakan dan air diberikan secara teratur', 'Vaksinasi sesuai jadwal', 'Ayam dijual saat mencapai berat target', 'Validasi: coop temperature harus controlled', 'Error message: "Suhu kandang tidak sesuai"', 'Edge case: high mortality rate   investigate cause'],
      bengkel: ['Customer brings vehicle → mechanic diagnoses → give estimate → repair → payment', 'Customer datang dengan kendaraan bermasalah', 'Mekanik mendiagnosa kerusakan', 'Estimasi biaya dan waktu diberikan', 'Repair dilakukan setelah disetujui', 'Payment dilakukan setelah selesai', 'Validasi: spare part harus original atau approved alternative', 'Error message: "Spare part tidak tersedia"', 'Edge case: repair cost exceeds estimate   get customer approval first'],
      car_rental: ['Customer books car → pick up → rent period → return → inspection → payment', 'Customer booking mobil dengan durasi sewa', 'Pick up mobil di lokasi yang disepakati', 'Mobil digunakan selama periode sewa', 'Mobil dikembalikan dan diinspeksi', 'Payment dihitung berdasarkan durasi dan kondisi', 'Validasi: driver license harus valid', 'Error message: "SIM tidak valid"', 'Edge case: car returned damaged   charge sesuai policy'],
      dealer: ['Customer browses → test drive → negotiate → financing → deliver', 'Customer melihat unit yang tersedia', 'Test drive dijadwalkan', 'Negosiasi harga dilakukan', 'Financing diajukan jika perlu', 'Unit di-deliver setelah deal', 'Validasi: customer harus pass financing check', 'Error message: "Pembiayaan tidak disetujui"', 'Edge case: customer ingin return dalam 3 hari   apply return policy'],
      contractor: ['Client signs contract → plan → execute → monitor → complete → handover', 'Kontrak ditandatangani dengan scope kerja jelas', 'Perencanaan proyek dibuat', 'Eksekusi dilakukan sesuai jadwal', 'Progress di-monitor secara berkala', 'Handover dilakukan setelah selesai', 'Validasi: project budget harus approved', 'Error message: "Anggaran proyek belum disetujui"', 'Edge case: weather delays project   adjust timeline'],
      maintenance: ['Tenant reports issue → assign technician → schedule → fix → verify → close', 'Tenant melaporkan issue maintenance', 'Technician ditugaskan berdasarkan issue', 'Jadwal kunjungan ditentukan', 'Perbaikan dilakukan di lokasi', 'Tenant memverifikasi perbaikan selesai', 'Validasi: priority harus set', 'Error message: "Priority wajib diisi"', 'Edge case: issue not fixed setelah first visit   reschedule'],
      event_management: ['Organizer creates event → promote → tickets sell → check-in → execute → follow-up', 'Event dibuat dengan detail tanggal dan venue', 'Promosi dilakukan melalui berbagai channel', 'Tiket dijual online', 'Check-in dilakukan saat event', 'Event dilaksanakan sesuai rencana', 'Validasi: event date harus di future', 'Error message: "Tanggal event harus di masa depan"', 'Edge case: event cancelled   auto-refund semua tickets'],
      forum: ['User creates thread → others discuss → moderator reviews → votes → archive', 'Thread dibuat dengan judul dan konten', 'User lain berdiskusi di thread', 'Moderator mereview konten', 'Voting dilakukan untuk kualitas thread', 'Thread di-archive jika sudah tidak aktif', 'Validasi: title harus unique', 'Error message: "Judul thread sudah ada"', 'Edge case: spam detected   auto-hide dan notifikasi moderator'],
      membership_community: ['User applies → approved → pays dues → participates → renews', 'User mengajukan aplikasi membership', 'Admin meng-approve aplikasi', 'User membayar iuran', 'User berpartisipasi di komunitas', 'Membership diperpanjang secara periodik', 'Validasi: email harus unique', 'Error message: "Email sudah terdaftar"', 'Edge case: member violates code of conduct   warn, suspend, atau remove'],
      photography: ['Client books package → photographer shoots → edits → delivers → reviews', 'Client booking paket photography', 'Photographer melakukan sesi foto', 'Foto diedit dan dipilih', 'Hasil foto di-deliver ke client', 'Client memberikan review', 'Validasi: booking harus confirmed dengan deposit', 'Error message: "DP wajib dibayar untuk konfirmasi booking"', 'Edge case: client unhappy dengan results   offer reshoot atau partial refund'],
      veterinary: ['Pet owner registers pet → appointment → vet examines → diagnosis → treatment → follow-up', 'Pet didaftarkan dengan data lengkap', 'Appointment dibuat dengan jadwal', 'Vet memeriksa kondisi hewan', 'Diagnosis diberikan ke owner', 'Treatment dilakukan sesuai diagnosis', 'Validasi: pet harus registered', 'Error message: "Hewan belum terdaftar"', 'Edge case: emergency case   prioritize over scheduled appointments'],
      gym: ['Member registers → chooses plan → pays → attends classes → tracks progress → renews', 'Member mendaftar dengan data diri', 'Member memilih plan membership', 'Payment dilakukan untuk aktivasi', 'Member attend kelas sesuai jadwal', 'Progress di-track di sistem', 'Validasi: membership harus active', 'Error message: "Membership tidak aktif"', 'Edge case: class is full   put on waitlist'],
      coworking: ['Member browses spaces → books → checks in → uses → checks out → billed', 'Member melihat available spaces', 'Booking dibuat dengan durasi', 'Check-in saat tiba di lokasi', 'Member menggunakan fasilitas', 'Check-out dan billing dihitung', 'Validasi: booking harus minimal 1 jam', 'Error message: "Minimal booking 1 jam"', 'Edge case: member stays overtime   charge extra hour'],
      generic: ['User dapat membuat item baru dengan form yang tervalidasi', 'Sistem menampilkan daftar item dengan search, filter, sort, dan pagination', 'User dapat mengedit item yang sudah ada dan menyimpan perubahannya', 'User dapat mengarsipkan item (soft delete)   tidak hilang dari database', 'Dashboard menampilkan ringkasan: total item, item aktif, item terbaru', 'Validasi: field nama/email wajib diisi, field angka harus numerik', 'Error message: "Field {field} wajib diisi"', 'Edge case: user membuka 2 tab dan mengedit item yang sama   last write wins dengan konfirmasi'],
      laundry: ['Staff dapat membuat order laundry baru dengan mencatat customer, item, dan berat', 'Sistem menghitung total harga otomatis berdasarkan item dan berat', 'Status laundry diupdate setiap tahap: washing → drying → ironing → packing', 'Customer dapat melihat status laundry via link tracking', 'Payment dicatat setelah customer membayar   status order berubah', 'Validasi: berat laundry harus lebih dari 0', 'Error message: "Berat laundry minimal 0.5 kg"', 'Edge case: customer membatalkan order saat laundry sudah diproses   konfirmasi owner'],
      pos: ['Cashier dapat scan barcode produk untuk menambahkan ke transaksi', 'Sistem menampilkan nama produk dan harga otomatis setelah scan', 'Sistem menghitung total, diskon, pajak, dan kembalian dengan benar', 'Stok otomatis berkurang setelah transaksi selesai', 'Cashier dapat tutup kasir di akhir shift   sistem hitung total penjualan', 'Validasi: nominal bayar tidak boleh kurang dari total belanja', 'Error message: "Uang tidak mencukupi. Kurang Rp {amount}"', 'Edge case: barcode tidak terbaca   cashier bisa cari produk manual via search'],
      erp: ['Admin dapat mendaftarkan department dan employee baru dengan data lengkap', 'Employee dapat mengajukan leave dengan tipe dan tanggal yang jelas', 'Manager dapat approve/reject leave   sistem update status otomatis', 'Finance dapat mengatur budget per department dan tracking pengeluaran', 'Manager dapat assign task ke employee dengan deadline dan prioritas', 'Validasi: leave date end tidak boleh sebelum start', 'Error message: "Tanggal akhir cuti tidak boleh sebelum tanggal mulai"', 'Edge case: employee mengajukan leave di hari yang sama dengan employee lain   overlap detection'],
      manufacturing: ['Production Manager dapat membuat production order dengan produk dan quantity', 'Operator memulai produksi   sistem catat start time dan kurangi material', 'QC Staff menginspeksi hasil produksi   mencatat pass/fail quantity', 'Produk jadi masuk gudang   stok ditambahkan otomatis', 'Dashboard menampilkan order aktif, produksi hari ini, dan reject rate', 'Validasi: quantity harus lebih dari 0', 'Error message: "Quantity produksi harus lebih dari 0"', 'Edge case: material tidak mencukupi saat produksi dimulai   sistem beri alert dan hold order'],
      healthcare: ['Receptionist dapat membuat appointment untuk pasien dengan memilih dokter dan waktu', 'Pasien check-in   sistem update status dan notifikasi dokter', 'Dokter mencatat diagnosis dan resep   tersimpan di medical record', 'Pasien bayar di kasir   invoice digenerate otomatis', 'Dashboard menampilkan pasien hari ini, pendapatan, jadwal dokter', 'Validasi: appointment time harus di masa depan', 'Error message: "Slot dokter sudah penuh. Pilih waktu lain"', 'Edge case: pasien no-show   sistem tandai dan biaya consult tetap dikenakan'],
      education: ['Admin dapat membuat course dengan lesson, materi, dan harga', 'Student mendaftar course   enrollment aktif dan progress mulai 0%', 'Student mengakses lesson   sistem catat progress per lesson', 'Student submit assignment   teacher dapat memberi score', 'Dashboard teacher menampilkan student progress, nilai, completion rate', 'Validasi: maxStudents tidak boleh kurang dari jumlah enrolled', 'Error message: "Kelas sudah penuh. Maksimal {max} student"', 'Edge case: student mengumpulkan assignment setelah deadline   teacher bisa tetap menilai dengan penalti'],
      property: ['Owner/Agent dapat mendaftarkan properti dengan tipe, alamat, dan harga', 'Tenant dapat melihat properti dan unit yang tersedia', 'Tenant memilih unit   lease agreement dibuat dengan durasi sewa', 'Tenant bayar sewa bulanan   sistem catat payment dan update status', 'Maintenance request dibuat   owner assign dan track progress', 'Validasi: endDate lease harus setelah startDate', 'Error message: "Tanggal akhir sewa harus setelah tanggal mulai"', 'Edge case: tenant telat bayar sewa   sistem kirim reminder otomatis dan hitung denda'],
      pharmacy: ['Pharmacist dapat menambah obat baru dengan SKU, kategori, harga, dan stok awal', 'Sistem harus memvalidasi SKU unik sebelum menyimpan obat', 'Resep dari dokter divalidasi oleh apoteker sebelum dispensing', 'Stok otomatis berkurang saat obat dijual atau didispense', 'Low stock alert muncul ketika stok di bawah batas minimum', 'Validasi: dosis dan kuantitas resep harus masuk akal (tidak melebihi maksimum)', 'Error message: \"Stok tidak mencukupi. Tersedia: {qty}\"', 'Edge case: obat mendekati expired   beri peringatan saat dispensing'],
      laboratory: ['LabTech dapat menambah test baru dengan kategori, harga, dan persiapan', 'Sample harus dilabel dengan benar dan ditracking dari koleksi hingga hasil', 'Test dapat memiliki beberapa parameter hasil dengan reference range', 'Hasil abnormal otomatis ditandai untuk review dokter', 'Sistem mencatat timestamp setiap perubahan status sample', 'Validasi: sample harus sampai di lab sebelum hasil bisa dimasukkan', 'Error message: \"Sample tidak ditemukan\"', 'Edge case: sample rusak atau hilang   catat sebagai reject dan minta sample baru'],
      telemedicine: ['Dokter dapat mengatur jadwal ketersediaan untuk konsultasi online', 'Konsultasi dimulai tepat waktu sesuai jadwal booking', 'Sistem mencatat seluruh sesi konsultasi termasuk resep', 'Resep dikirim ke pasien secara digital setelah konsultasi', 'Riwayat medis pasien diperbarui setelah setiap konsultasi', 'Validasi: durasi konsultasi tidak boleh melebihi slot yang ditentukan', 'Error message: \"Dokter sedang tidak tersedia. Pilih jadwal lain\"', 'Edge case: koneksi terputus saat konsultasi   fitur reconnection otomatis'],
      tutoring: ['Tutor dapat menentukan tarif per jam dan jadwal mengajar', 'Sesi tutoring terjadwal mengikat antara tutor dan siswa', 'Sistem mencatat kehadiran dan durasi sesi', 'Pekerjaan rumah diberikan dan dinilai oleh tutor', 'Laporan perkembangan siswa dikirim ke orang tua secara periodik', 'Validasi: jadwal tutor tidak boleh bentrok', 'Error message: \"Jadwal tutor sudah terisi. Pilih waktu lain\"', 'Edge case: tutor tiba-tiba sakit   cari tutor pengganti atau reschedule'],
      bootcamp: ['Program bootcamp memiliki kurikulum terstruktur dengan modul berurutan', 'Mentor dapat membuat assignment dengan deadline dan kriteria penilaian', 'Siswa mengumpulkan tugas dan mentor memberikan skor serta feedback', 'Progress siswa terlihat di dashboard untuk monitoring', 'Sertifikat diberikan setelah semua modul selesai', 'Validasi: submission harus sebelum deadline', 'Error message: \"Pengumpulan sudah melewati deadline\"', 'Edge case: siswa tertinggal modul karena alasan khusus   beri perpanjangan waktu'],
      school_management: ['Admin dapat mendaftarkan siswa baru dan assign ke kelas', 'Absensi dicatat setiap hari untuk setiap siswa', 'Nilai dimasukkan per mata pelajaran per semester', 'Jadwal pelajaran diatur per kelas per hari', 'Rapor dihasilkan dari gabungan nilai dan absensi', 'Validasi: nomor induk siswa harus unik', 'Error message: \"NISN sudah terdaftar\"', 'Edge case: siswa pindah kelas di tengah semester   data tetap lengkap'],
      lms: ['Instructor dapat membuat course dengan lesson dan quiz', 'Learner dapat mengakses materi sesuai urutan yang ditentukan', 'Quiz menilai pemahaman dengan passing score tertentu', 'Progress disimpan per user per course dan lesson', 'Sertifikat diterbitkan setelah course selesai dengan passing grade', 'Validasi: learner harus menyelesaikan lesson sebelum quiz', 'Error message: \"Selesaikan semua lesson sebelum mengakses quiz\"', 'Edge case: learner ingin mengulang quiz   gunakan attempt terbaik'],
      personal_finance: ['User dapat mencatat transaksi pemasukan dan pengeluaran setiap hari', 'Transaksi otomatis dikategorikan berdasarkan jenis dan deskripsi', 'Budget ditentukan per kategori per periode (bulanan)', 'Sistem menampilkan perbandingan realisasi vs budget', 'Report bulanan menunjukkan ringkasan keuangan', 'Validasi: nominal transaksi harus lebih dari 0', 'Error message: \"Budget telah melebihi batas untuk kategori ini\"', 'Edge case: transaksi berulang bulanan   set recurrence pattern'],
      cooperative: ['Anggota baru mendaftar dan mulai menabung secara teratur', 'Pinjaman diajukan dengan jumlah, bunga, dan tenor tertentu', 'Setiap pinjaman diangsur secara bulanan dengan jadwal tetap', 'Sistem menghitung otomatis sisa pinjaman dan bunga berjalan', 'SHU/Dividen dibagikan tahunan berdasarkan simpanan dan transaksi', 'Validasi: jumlah pinjaman tidak boleh melebihi saldo simpanan * 3', 'Error message: \"Pinjaman melebihi batas maksimal\"', 'Edge case: anggota menunggak angsuran   sistem hitung denda otomatis'],
      insurance: ['Client mengajukan permohonan polis dengan data lengkap', 'Agent melakukan underwriting dan menentukan risiko', 'Premi dibayar sesuai jadwal   status polis menjadi aktif', 'Klaim diajukan dengan dokumen pendukung lengkap', 'Adjuster menyelidiki validitas klaim sebelum settlement', 'Validasi: premi harus dibayar sebelum polis bisa aktif', 'Error message: \"Dokumen klaim tidak lengkap\"', 'Edge case: klaim diajukan setelah polis expired   ditolak otomatis'],
      warehouse: ['Staff menerima barang dan mencatat di sistem dengan quantity dan bin', 'Barang disimpan di bin location yang sesuai dengan kategorinya', 'Picking barang dilakukan berdasarkan FIFO atau FEFO', 'Packing dan shipping dicatat dengan nomor referensi', 'Manager dapat melihat qty stok per produk dan per bin', 'Validasi: bin harus punya sisa kapasitas sebelum menempatkan barang', 'Error message: \"Bin sudah penuh. Pilih bin lain\"', 'Edge case: 2 staff melakukan picking barang yang sama   pakai locking system'],
      cold_chain: ['Operator memuat produk yang sensitif suhu ke dalam kendaraan', 'Sensor suhu aktif selama pengiriman dan mencatat secara real-time', 'Sistem mengirim alert jika suhu melebihi threshold yang ditentukan', 'Semua log suhu tersimpan untuk audit trail', 'Pengiriman diverifikasi setelah tiba dengan cek log suhu', 'Validasi: suhu harus dalam range yang ditentukan produk', 'Error message: \"Suhu melebihi batas aman\"', 'Edge case: sensor mati di tengah perjalanan   gunakan data dari sensor cadangan'],
      freight: ['Shipper meminta quote pengiriman dengan detail berat dan tujuan', 'Carrier memberikan harga   shipper konfirmasi booking', 'Carrier pickup barang dari shipper dan catat di sistem', 'Tracking event diperbarui di setiap tahap perjalanan', 'Barang diterima dan dikonfirmasi oleh penerima', 'Validasi: berat tidak boleh melebihi kapasitas kendaraan', 'Error message: \"Berat melebihi kapasitas maksimal\"', 'Edge case: cuaca buruk menyebabkan delay   update ETA dan notifikasi'],
      homestay: ['Host dapat mendaftarkan properti dengan detail dan harga', 'Guest mencari dan booking properti untuk tanggal tertentu', 'Booking mengunci kalender untuk tanggal yang dipilih', 'Check-in dan check-out dicatat oleh host', 'Pembayaran diproses setelah check-in atau sesuai kebijakan', 'Validasi: check-out harus setelah check-in', 'Error message: \"Tanggal sudah dibooking. Pilih tanggal lain\"', 'Edge case: guest tidak datang (no-show)   deposit tidak dikembalikan'],
      villa_rental: ['Owner dapat list villa dengan harga per malam dan fasilitas', 'Guest booking villa dan bayar deposit untuk konfirmasi', 'Sisa pembayaran dilakukan saat check-in', 'Owner inspeksi villa setelah guest check-out', 'Guest memberikan review setelah masa sewa selesai', 'Validasi: deposit minimal 50% dari total sewa', 'Error message: \"Deposit belum dibayar. Booking tidak dapat dikonfirmasi\"', 'Edge case: guest merusak properti   potong dari deposit sesuai kebijakan'],
      guest_house: ['Receptionist mencatat reservasi kamar untuk guest', 'Kamar dicek ketersediaannya sebelum booking dikonfirmasi', 'Guest check-in dan diberikan akses kamar', 'Guest dapat request layanan tambahan seperti laundry', 'Check-out dan pembayaran selesai dalam satu proses', 'Validasi: kamar harus available untuk tanggal tersebut', 'Error message: \"Kamar tidak tersedia untuk tanggal yang dipilih\"', 'Edge case: guest ingin extended stay   cek availability'],
      resort: ['Guest booking kamar resort untuk liburan', 'Resepsionis check-in dan assign kamar sesuai preferensi', 'Guest menikmati fasilitas resort: kolam renang, spa, aktivitas', 'Staff menyediakan housekeeping dan room service', 'Guest check-out   semua tagihan diselesaikan', 'Validasi: jumlah tamu tidak boleh melebihi kapasitas kamar', 'Error message: \"Kamar penuh untuk tanggal tersebut\"', 'Edge case: guest sakit selama menginap   bantuan medis dipanggil'],
      help_desk: ['Customer dapat membuat tiket dengan kategori dan prioritas', 'Sistem assign tiket ke agent berdasarkan beban kerja', 'Agent merespon dan mengupdate status tiket', 'SLA dipantau untuk setiap tiket berdasarkan prioritas', 'Tiket ditutup setelah customer konfirmasi resolusi', 'Validasi: subject dan deskripsi tidak boleh kosong', 'Error message: \"Tiket dengan subjek yang sama sudah ada\"', 'Edge case: customer reopen tiket yang sudah closed   tiket original diaktifkan kembali'],
      loyalty_program: ['Member dapat mendaftar ke program loyalitas dengan data diri', 'Poin diperoleh dari setiap transaksi atau aktivitas tertentu', 'Member dapat menukarkan poin dengan reward yang tersedia', 'Tier member meningkat berdasarkan total poin atau transaksi', 'Poin memiliki masa berlaku dan akan expired jika tidak digunakan', 'Validasi: poin member harus cukup untuk menukar reward', 'Error message: \"Poin tidak mencukupi. Dibutuhkan {points} poin\"', 'Edge case: reward habis   tampilkan "stok habis" dan beri notifikasi saat tersedia'],
      sales_pipeline: ['Sales membuat lead baru dari berbagai sumber', 'Lead dikualifikasi melalui serangkaian aktivitas follow-up', 'Lead yang qualified dikonversi menjadi deal dengan value', 'Deal bergerak melalui pipeline stages hingga closing', 'Manager melihat forecast revenue berdasarkan pipeline', 'Validasi: value deal harus lebih dari 0', 'Error message: \"Lead sudah terdaftar dengan email yang sama\"', 'Edge case: deal loss di stage akhir   catat reason untuk analysis'],
      project_management: ['Manager membuat project dan menetapkan timeline', 'Task di-assign ke anggota tim dengan deadline dan prioritas', 'Anggota tim mengupdate status task dan mencatat hours', 'Milestone menjadi checkpoint progress project', 'Project selesai   semua deliverables terdokumentasi', 'Validasi: endDate harus setelah startDate', 'Error message: \"Tanggal selesai harus setelah tanggal mulai\"', 'Edge case: resource tidak tersedia   reassign task atau adjust timeline'],
      task_management: ['User membuat task baru dengan judul dan prioritas', 'Task dikelompokkan dalam list yang terorganisir', 'User dapat menambahkan label dan deadline', 'Task diupdate statusnya dari todo ke done', 'Task yang sudah lama selesai diarsipkan otomatis', 'Validasi: judul task tidak boleh kosong', 'Error message: \"Task gagal dibuat. Coba lagi\"', 'Edge case: user membuat subtask   gunakan parent-child relationship'],
      note_taking: ['User dapat membuat notebook untuk mengorganisir catatan', 'Catatan dibuat dengan rich text editor', 'Tag digunakan untuk mengkategorikan catatan', 'Pencarian full-text untuk menemukan catatan dengan cepat', 'Catatan dapat diarsipkan atau dihapus (soft delete)', 'Validasi: judul catatan tidak boleh kosong', 'Error message: \"Gagal menyimpan catatan\"', 'Edge case: 2 user edit catatan yang sama di waktu bersamaan   merge conflict handling'],
      okr_tracking: ['User atau manager menetapkan objective untuk periode tertentu', 'Setiap objective memiliki 3-5 key results yang terukur', 'Key result memiliki baseline, target, dan progress saat ini', 'Check-in dilakukan mingguan untuk update progress', 'Di akhir periode, skor OKR dihitung berdasarkan pencapaian KR', 'Validasi: target value harus di atas start value', 'Error message: \"Key result harus memiliki target yang terukur\"', 'Edge case: objective di tengah periode berubah prioritas   archive dan buat baru'],
      content_subscription: ['Creator membuat konten premium untuk subscriber', 'Plan langganan dibuat dengan harga dan benefit berbeda', 'Subscriber memilih plan dan membayar berlangganan', 'Konten eksklusif hanya bisa diakses subscriber aktif', 'Creator melihat analytics subscriber dan revenue', 'Validasi: pembayaran harus berhasil sebelum akses konten diberikan', 'Error message: \"Langganan tidak aktif. Perbarui pembayaran\"', 'Edge case: pembayaran gagal setelah akses diberikan   revoke akses hingga pembayaran sukses'],
      podcast_platform: ['Host merekam dan mengupload episode podcast', 'Episode dipublikasikan ke feed subscribers', 'Listener berlangganan podcast dan mendapatkan notifikasi episode baru', 'Setiap episode memiliki statistik: listens, durasi rata-rata, completion rate', 'Host mendapat revenue dari iklan atau donasi pendengar', 'Validasi: file audio harus dalam format yang didukung (MP3, AAC)', 'Error message: \"Format audio tidak didukung\"', 'Edge case: episode mengandung konten sensitif   beri peringatan sebelum diputar'],
      template_marketplace: ['Creator upload template dengan file dan preview', 'Template direview oleh admin sebelum dipublikasikan', 'Buyer mencari template berdasarkan kategori dan format', 'Pembelian memberikan akses download unlimited', 'Creator mendapat payout berdasarkan penjualan', 'Validasi: file template harus di bawah 100MB', 'Error message: \"File terlalu besar. Maksimal 100MB\"', 'Edge case: buyer tidak puas dengan kualitas   ajukan refund dalam 7 hari'],
      fishery: ['Petani menyiapkan kolam dan menebar benih ikan', 'Pakan diberikan secara terjadwal dengan jumlah yang tepat', 'Pertumbuhan ikan dimonitor secara berkala', 'Ikan dipanen saat mencapai berat target', 'Hasil panen dijual ke buyer dengan harga pasar', 'Validasi: jumlah pakan tidak boleh melebihi kapasitas kolam', 'Error message: \"Kolam tidak siap untuk penebaran\"', 'Edge case: ikan mati massal   investigasi penyebab dan catat kerugian'],
      plantation: ['Petani mempersiapkan lahan dan menanam bibit', 'Perawatan dilakukan secara rutin: pemupukan, penyiraman, pengendalian hama', 'Tanaman dipantau pertumbuhannya hingga siap panen', 'Panen dilakukan pada waktu yang tepat untuk kualitas optimal', 'Hasil panen dijual atau diolah lebih lanjut', 'Validasi: musim tanam harus sesuai dengan jenis tanaman', 'Error message: \"Bukan musim tanam yang tepat\"', 'Edge case: gagal panen karena cuaca buruk   klaim asuransi pertanian'],
      greenhouse: ['Petani menanam tanaman di lingkungan rumah kaca yang terkontrol', 'Sensor memonitor suhu, kelembaban, dan pH secara real-time', 'Sistem secara otomatis mengatur ventilasi dan irigasi', 'Tanaman dipanen saat mencapai kualitas prima', 'Hasil panen dijual langsung ke konsumen atau restoran', 'Validasi: sensor harus dikalibrasi secara berkala', 'Error message: \"Sensor tidak merespon. Periksa koneksi\"', 'Edge case: listrik padam   backup generator otomatis menyala'],
      car_wash: ['Customer datang dan memilih paket cuci yang diinginkan', 'Worker mencatat pesanan dan mulai proses pencucian', 'Mobil dicuci sesuai prosedur: exterior, interior, vacuum', 'Mobil dikeringkan dan diperiksa kualitasnya', 'Customer membayar dan menerima struk', 'Validasi: nomor plat kendaraan harus diisi', 'Error message: \"Nomor plat tidak valid\"', 'Edge case: customer request tambahan setelah cuci dimulai   sesuaikan harga dan waktu'],
      motorcycle_workshop: ['Customer datang dengan keluhan pada motornya', 'Mekanik mendiagnosa masalah dan memberikan estimasi biaya', 'Customer menyetujui estimasi   perbaikan dimulai', 'Spare part yang rusak diganti dengan yang baru', 'Motor selesai diperbaiki dan customer bayar', 'Validasi: estimasi biaya harus disetujui customer sebelum repair', 'Error message: \"Spare part tidak tersedia. Pesan terlebih dahulu\"', 'Edge case: biaya perbaikan membengkak   konfirmasi ulang ke customer'],
      tire_shop: ['Customer datang untuk cek kondisi ban', 'Teknisi memeriksa tekanan udara dan kedalaman alur ban', 'Ban yang aus diganti dengan yang baru sesuai ukuran', 'Ban baru di balancing dan spooring', 'Customer bayar dan kendaraan siap digunakan', 'Validasi: ukuran ban harus sesuai dengan spesifikasi kendaraan', 'Error message: \"Ukuran ban tidak tersedia\"', 'Edge case: customer mau ganti hanya 2 ban   infokan pentingnya keseimbangan ban'],
      rental_management: ['Owner mendaftarkan properti dan unit yang tersedia', 'Tenant menandatangani perjanjian sewa untuk unit tertentu', 'Pembayaran sewa dilakukan bulanan dan dicatat sistem', 'Perbaikan diajukan oleh tenant dan ditindaklanjuti owner', 'Kontrak sewa diperpanjang atau diakhiri sesuai ketentuan', 'Validasi: endDate lease harus setelah startDate', 'Error message: \"Unit sudah disewa untuk periode tersebut\"', 'Edge case: tenant telat bayar 3 bulan berturut-turut   proses eviction sesuai kontrak'],
      real_estate_agency: ['Agent mendaftarkan properti dengan foto dan detail lengkap', 'Client booking jadwal untuk melihat properti', 'Agent menunjukkan properti dan menjelaskan kelebihan', 'Buyer mengajukan penawaran harga   agent negosiasi', 'Deal ditutup   komisi agent dibayarkan', 'Validasi: harga listing harus realistis berdasarkan analisa pasar', 'Error message: \"Harga properti di luar estimasi\"', 'Edge case: buyer mundur setelah deal   deal jadi batal dan listing diaktifkan kembali'],
      strata_management: ['Manager menagih iuran bulanan ke semua pemilik unit', 'Pembayaran iuran dicatat dan status diperbarui', 'Perbaikan fasilitas umum dijadwalkan dan dieksekusi', 'Rapat komite diadakan untuk membahas anggaran', 'Laporan keuangan disusun dan dipresentasikan', 'Validasi: iuran harus dibayar sebelum tanggal jatuh tempo', 'Error message: \"Iuran bulan {period} belum dibayar\"', 'Edge case: pemilik unit tidak membayar iuran selama 6 bulan   kirim somasi'],
      sports_club: ['Member mendaftar dan memilih paket membership', 'Coach menjadwalkan sesi latihan rutin', 'Member hadir latihan dan melakukan check-in', 'Kehadiran dan performa dicatat oleh coach', 'Membership diperpanjang secara otomatis atau manual', 'Validasi: member harus memiliki membership aktif untuk ikut sesi', 'Error message: \"Membership tidak aktif. Perpanjang dahulu\"', 'Edge case: sesi latihan penuh   member masuk waiting list'],
      volunteer_platform: ['Organizer mempublikasikan project dengan jadwal shift', 'Volunteer mendaftar untuk shift yang tersedia', 'Volunteer hadir dan melaksanakan tugas', 'Jam kerja diverifikasi oleh organizer', 'Dampak project diukur dan dilaporkan', 'Validasi: volunteer harus register sebelum mengisi shift', 'Error message: \"Shift sudah penuh\"', 'Edge case: volunteer tidak hadir   tandai sebagai no-show dan cari pengganti'],
      alumni_network: ['Alumni mendaftar dengan data akademik dan pekerjaan', 'Alumni dapat mencari dan terhubung dengan alumni lain', 'Event reuni atau networking diadakan secara berkala', 'Lowongan kerja diposting oleh alumni untuk alumni', 'Donasi dikumpulkan untuk kegiatan kampus', 'Validasi: email alumni harus domain institusi atau terverifikasi', 'Error message: \"Email tidak terverifikasi sebagai alumni\"', 'Edge case: alumni ingin hapus akun   soft delete dengan data retention'],
      spa: ['Customer booking layanan spa dengan therapist pilihan', 'Customer tiba dan check-in untuk perawatan', 'Therapist memberikan treatment sesuai paket yang dipilih', 'Customer membayar setelah perawatan selesai', 'Customer memberi rating dan review', 'Validasi: booking minimal 1 jam sebelum jadwal', 'Error message: \"Therapist tidak tersedia di jam tersebut\"', 'Edge case: customer alergi produk tertentu   catat di preferensi customer'],
      tailoring: ['Customer konsultasi desain dengan tailor', 'Tailor mengambil ukuran badan customer', 'Tailor memotong kain dan menjahit sesuai pola', 'Customer fitting dan request adjustment', 'Baju jadi dan diantar ke customer', 'Validasi: semua ukuran harus diisi sebelum mulai produksi', 'Error message: \"Ukuran belum lengkap\"', 'Edge case: customer berubah pikiran setelah pengukuran   charge tambahan untuk perubahan'],
      laundry_delivery: ['Customer order laundry dengan pick-up address', 'Driver menjemput laundry ke alamat customer', 'Staff mencuci, mengeringkan, dan menyetrika', 'Driver mengantar kembali ke alamat customer', 'Customer bayar saat terima paket', 'Validasi: berat minimal 1 kg', 'Error message: \"Berat laundry minimal 1 kg\"', 'Edge case: customer tidak ada di tempat saat delivery   reschedule atau titip tetangga'],
      grocery: ['Manager menambah produk baru dengan barcode dan harga', 'Stok barang diterima dari supplier dan dicatat', 'Kasir menscan barcode dan memproses pembayaran', 'Stok berkurang otomatis setelah penjualan', 'Reorder dilakukan saat stok minimum tercapai', 'Validasi: harga jual harus di atas harga beli', 'Error message: \"Barcode tidak ditemukan\"', 'Edge case: produk kadaluwarsa   mark sebagai expired dan jangan dijual'],
      convenience_store: ['Kasir memulai shift dan membuka kas register', 'Customer belanja dan membayar di kasir', 'Kasir scan produk dan menerima pembayaran', 'Stok diperbarui setelah setiap transaksi', 'Shift ditutup dan total penjualan direkonsiliasi', 'Validasi: nominal bayar tidak boleh kurang dari total', 'Error message: \"Uang tidak mencukupi\"', 'Edge case: customer ingin retur barang   validasi struk asli dan batas waktu'],
      pharmacy_retail: ['Apoteker menerima stok obat dari supplier', 'Customer membeli obat bebas atau dengan resep', 'Resep dari dokter divalidasi oleh apoteker', 'Obat didispense dan kasir memproses pembayaran', 'Stok diperbarui dan reorder jika mendekati minimum', 'Validasi: obat resep hanya bisa dibeli dengan resep asli', 'Error message: \"Resep dokter diperlukan untuk obat ini\"', 'Edge case: stok obat habis   catat permintaan customer dan pesan ke supplier']

    };
    const hints = domainHints[domain] || domainHints.generic;

    //    Build prompt   

    //    Engine Analysis Section   
    var confidenceNote = '';
    if (engineArtifacts && engineArtifacts.domain) {
      const conf = engineArtifacts.domain.confidence;
      if (conf >= 0.8) confidenceNote = '✓ High confidence domain. Use full domain specification below.';
      else if (conf >= 0.5) confidenceNote = '⚠ Medium confidence domain. Review entities and relationships for accuracy.';
      else confidenceNote = '✗ Low confidence domain. Verify domain before building. Consider reviewing entity definitions.';
    }
    const enginePromptLines = [];
    if (engineArtifacts && engineArtifacts.domain) {
      enginePromptLines.push('## Engine: Domain Analysis');
      enginePromptLines.push('');
      enginePromptLines.push('- Primary Domain: ' + engineArtifacts.domain.primaryDomain);
      enginePromptLines.push('- Confidence: ' + (engineArtifacts.domain.confidence * 100).toFixed(0) + '%');
      enginePromptLines.push('- Actors: ' + engineArtifacts.domain.actors.join(', '));
      enginePromptLines.push('- Entities: ' + engineArtifacts.domain.entities.map(e => e.name).join(', '));
      enginePromptLines.push('- Entity Count: ' + engineArtifacts.domain.entities.length);
      enginePromptLines.push('- ' + confidenceNote);
      enginePromptLines.push('');
    }
    if (engineArtifacts && engineArtifacts.relations) {
      enginePromptLines.push('## Engine: Relationship Analysis');
      enginePromptLines.push('');
      engineArtifacts.relations.relations.forEach(r => {
        if (r.relations.belongsTo && r.relations.belongsTo.length) {
          r.relations.belongsTo.forEach(b => enginePromptLines.push('- ' + r.entity + ' belongsTo ' + b.to + ' (' + b.cardinality + ')'));
        }
        if (r.relations.hasMany && r.relations.hasMany.length) {
          r.relations.hasMany.forEach(h => enginePromptLines.push('- ' + r.entity + ' hasMany ' + h.to + ' (' + h.cardinality + ')'));
        }
        if (r.relations.hasOne && r.relations.hasOne.length) {
          r.relations.hasOne.forEach(o => enginePromptLines.push('- ' + r.entity + ' hasOne ' + o.to + ' (' + o.cardinality + ')'));
        }
      });
      enginePromptLines.push('');
    }
    if (engineArtifacts && engineArtifacts.modules) {
      enginePromptLines.push('## Engine: Module Analysis');
      enginePromptLines.push('');
      engineArtifacts.modules.modules.forEach(m => {
        enginePromptLines.push('- **' + m.name + '** (' + m.slug + '): ' + m.capabilities.join(', '));
      });
      enginePromptLines.push('');
    }
    if (engineArtifacts && engineArtifacts.architecture) {
      enginePromptLines.push('## Engine: Architecture Analysis');
      enginePromptLines.push('');
      enginePromptLines.push('- Pattern: ' + engineArtifacts.architecture.pattern);
      enginePromptLines.push('- Layers: ' + engineArtifacts.architecture.layers.join(', '));
      enginePromptLines.push('- Services: ' + engineArtifacts.architecture.services);
      enginePromptLines.push('- Reasoning: ' + engineArtifacts.architecture.reasoning);
      enginePromptLines.push('');
    }
    if (engineArtifacts && engineArtifacts.security) {
      enginePromptLines.push('## Engine: Security Analysis');
      enginePromptLines.push('');
      enginePromptLines.push('- Auth Type: ' + engineArtifacts.security.authType);
      enginePromptLines.push('- MFA: ' + engineArtifacts.security.mfa);
      enginePromptLines.push('- Roles: ' + engineArtifacts.security.roles.map(r => r.name + ' (' + r.permissions.join(', ') + ')').join(', '));
      enginePromptLines.push('');
    }
    if (engineArtifacts && engineArtifacts.validation) {
      enginePromptLines.push('## Engine: Validation Analysis');
      enginePromptLines.push('');
      engineArtifacts.validation.fieldRules.slice(0, 15).forEach(v => {
        enginePromptLines.push('- ' + v.entity + '.' + v.field + ': ' + v.rules.map(r => r.type).join(', '));
      });
      if (engineArtifacts.validation.fieldRules.length > 15) {
        enginePromptLines.push('- ... and ' + (engineArtifacts.validation.fieldRules.length - 15) + ' more field rules');
      }
      enginePromptLines.push('');
    }
    if (engineArtifacts && engineArtifacts.stateMachine && engineArtifacts.stateMachine.stateMachines.length > 0) {
      enginePromptLines.push('## Engine: State Machines');
      enginePromptLines.push('');
      engineArtifacts.stateMachine.stateMachines.forEach(sm => {
        enginePromptLines.push('- **' + sm.entity + '**: ' + sm.states.join(' → '));
        if (sm.terminalStates.length) {
          enginePromptLines.push('  - Terminal: ' + sm.terminalStates.join(', '));
        }
      });
      enginePromptLines.push('');
    }
    if (engineArtifacts && engineArtifacts.uiFlows && engineArtifacts.uiFlows.journeys.length > 0) {
      enginePromptLines.push('## Engine: User Journeys');
      enginePromptLines.push('');
      engineArtifacts.uiFlows.journeys.forEach(j => {
        enginePromptLines.push('- **' + j.actor + '**:');
        j.steps.forEach(s => {
          enginePromptLines.push('  - ' + s.action);
        });
      });
      enginePromptLines.push('');
    }
    if (engineArtifacts && engineArtifacts.events && engineArtifacts.events.events.length > 0) {
      enginePromptLines.push('## Engine: Domain Events');
      enginePromptLines.push('');
      engineArtifacts.events.events.slice(0, 15).forEach(ev => {
        enginePromptLines.push('- **' + ev.name + '**: ' + (ev.desc || '') + (ev.producer ? ' (producer: ' + ev.producer + ')' : '') + (ev.priority ? ' [' + ev.priority + ']' : ''));
      });
      if (engineArtifacts.events.events.length > 15) {
        enginePromptLines.push('- ... and ' + (engineArtifacts.events.events.length - 15) + ' more events');
      }
      enginePromptLines.push('');
    }

    const engineSectionHeader = enginePromptLines.length > 0
      ? ['# Engine Analysis', '', ...enginePromptLines, '---', '']
      : [];

    const handoffRules = [
      '## 0. Handoff Intent',
      '',
      'This bundle is meant to be pasted into Codex, Claude Code, Cursor, or a similar coding agent.',
      'Treat it as an implementation brief, not a brainstorming doc.',
      'Optimize for a working product with minimal revision loops.',
      '',
      '### Operating Rules',
      '- Start with the actual app and the core workflow, not a landing page.',
      '- Respect the existing architecture unless it blocks delivery.',
      '- Prefer editing current files over inventing new abstractions.',
      '- Keep the UI clean, operational, and anti-slop.',
      '- Build the minimum complete flow first, then polish the edges.',
      '- If a feature has low user value or high implementation noise, omit it.',
      '- If anything is ambiguous, make the smallest reasonable assumption and state it clearly.',
      '- Do not add extra features just because they are common elsewhere.',
      '- Return changes file-by-file, with concrete implementation steps, not generic advice.',
      '',
      '### Anti-Slop Design Rules',
      '- Use restrained spacing, clear hierarchy, and compact surfaces.',
      '- Avoid decorative gradients, oversized hero layouts, and filler panels.',
      '- Every screen must have empty, loading, error, and success states where relevant.',
      '- Every form input must validate with explicit feedback.',
      '- Every result should reflect the user’s actual intent, not generic AI output.',
      '- Keep labels specific, short, and task-oriented.',
      '- Use icons only when they improve scanability and never as decoration.',
      '',
      '### Expected Output',
      '- A usable implementation plan or code changes that map directly to this PRD.',
      '- Files should be named and structured for easy application in a codebase.',
      '- Include notes only when they unblock implementation.',
      '- Prefer deterministic outputs: explicit routes, components, data shapes, and validation rules.',
      '- Do not invent placeholder screens or TODO stubs as the final answer.',
      '',
    ];

    const promptContent = [
      ...engineSectionHeader,
      ...handoffRules,
      '# 1. Project Overview',
      '',
      '- **Nama**: ' + productName,
      '- **Domain**: ' + domain + (domainInfo.confidence > 0 ? ' (confidence: ' + (domainInfo.confidence * 100).toFixed(0) + '%)' : '') + (domainInfo.secondary.length ? '   Related: ' + domainInfo.secondary.join(', ') : ''),
      '- **Ide**: ' + ideaText,
      '- **Tipe**: ' + (state.productType === 'web' ? 'Web App' : state.productType === 'mobile' ? 'Mobile App' : 'Hybrid Web + Mobile'),
      '- **Target User**: ' + targetUser,
      '- **Skala Awal**: ' + scale,
      '- **Monetisasi**: ' + monetization,
      '- **Mode Akses AI**: ' + (state.aiAccessMode === 'subscription' ? 'Subscription' : state.aiAccessMode === 'paygo' ? 'Pay as you go' : 'BYOK'),
      '- **Outcome Utama**: ' + mainOutcome,
      '',
      '## 2. Domain Analysis',
      '',
      '- **Primary Domain**: ' + (engineArtifacts && engineArtifacts.domain ? engineArtifacts.domain.domainName : pack.name),
      '- **Confidence**: ' + (engineArtifacts && engineArtifacts.domain ? (engineArtifacts.domain.confidence * 100).toFixed(0) + '%' : 'N/A'),
      (domainInfo.secondary.length ? '- **Secondary**: ' + domainInfo.secondary.join(', ') : ''),
      '- **Entity Count**: ' + entityNames.length + ' entities',
      '',
      '## 3. Actors',
      '',
      '| Actor | Description |',
      '|-------|-------------|',
      actorsTable,
      '',
      '## 4. Entities',
      '',
      entityModels,
      (enumBlock ? '\\n### Enums\\n```prisma\\n' + enumBlock.trim() + '\\n```\\n' : ''),
      '',
      '## 5. Relationships',
      '',
      (engineArtifacts && engineArtifacts.relations ? engineArtifacts.relations.relations.map(r => {
        const rels = [];
        if (r.relations.belongsTo) r.relations.belongsTo.forEach(b => rels.push('- ' + r.entity + ' belongsTo ' + b.to));
        if (r.relations.hasMany) r.relations.hasMany.forEach(h => rels.push('- ' + r.entity + ' hasMany ' + h.to));
        if (r.relations.hasOne) r.relations.hasOne.forEach(o => rels.push('- ' + r.entity + ' hasOne ' + o.to));
        return rels.join('\n');
      }).join('\n') : ''),
      '',
      '## 6. Modules',
      '',
      (engineArtifacts && engineArtifacts.modules ? engineArtifacts.modules.modules.map(m => {
        return '- **' + m.name + '**: ' + m.capabilities.join(', ');
      }).join('\n') : ''),
      '',
      '## User Flow',
      '',
      'Actors in this system: ' + pack.actors.join(', '),
      '',
      'Key flows:',
      flowsSection,
      '',
      '## Validation Rules',
      '',
      (engineArtifacts && engineArtifacts.validation && engineArtifacts.validation.fieldRules ? engineArtifacts.validation.fieldRules.slice(0, 25).map(v => {
        return '- ' + v.entity + '.' + v.field + ': ' + v.rules.map(r => r.message).join('; ');
      }).join('\\n') : pack.actors.map(a => '- Standard validation applies').join('\\n')),
      '',
      '## 8. Architecture Pattern',
      '',
      (engineArtifacts && engineArtifacts.architecture ? [
        '- **Pattern**: ' + engineArtifacts.architecture.pattern,
        '- **Layers**: ' + engineArtifacts.architecture.layers.join(', '),
        '- **Services**: ' + engineArtifacts.architecture.services,
        '- **Reasoning**: ' + engineArtifacts.architecture.reasoning,
      ].join('\n') : '- Simple Monolith'),
      '',
      '## 9. Security Model',
      '',
      (engineArtifacts && engineArtifacts.security ? [
        '- **Auth Type**: ' + engineArtifacts.security.authType,
        '- **MFA**: ' + engineArtifacts.security.mfa,
        '',
        '### Roles',
        engineArtifacts.security.roles.map(r => '- ' + r.name + ': ' + r.permissions.join(', ')).join('\n'),
        '',
        '### Access Policies',
        engineArtifacts.security.policies.map(p => '- ' + p.module + ': read(' + p.read.join(', ') + '), write(' + p.write.join(', ') + '), delete(' + p.delete.join(', ') + ')').join('\n'),
      ].join('\n') : '- Single role: all access'),
      '',
      '## 10. Technical Constraints',
      '',
      '- Frontend: ' + tech.frontend,
      '- Backend: ' + tech.backend,
      '- Database: ' + tech.database,
      '- Deployment: ' + tech.deployment,
      (state.extras.length > 0 ? '- Ekstra: ' + state.extras.map(e => { const f = EXTRA_OPTIONS.find(([k]) => k === e); return f ? f[1] : e; }).join(', ') : ''),
      '',
      '## 11. Folder Structure',
      '',
      '```',
      'backend/',
      '  src/',
      '    repositories/',
      '    services/',
      '    routes/',
      '    middleware/',
      '    validators/',
      '  prisma/',
      '    schema.prisma',
      'frontend/',
      '  pages/',
      '  components/',
      'db/',
      '  seed.sql',
      'tests/',
      'docker-compose.yml',
      'Dockerfile',
      '```',
      '',
      '## 12. Acceptance Criteria',
      '',
      features.map((feature, idx) => {
        const start = (idx * 8) % hints.length;
        const ac = hints.slice(start, start + Math.min(6, hints.length - start));
        return '### Fitur: ' + feature + '\\n' + ac.map((a, i) => '- [' + (i === 0 ? 'x' : ' ') + '] ' + a).join('\n');
      }).join('\\n\\n'),
      '',
      '## 13. Output Format',
      '',
      'Generate a complete project with this structure:',
      '```',
      'backend/',
      '  src/',
      '    repositories/',
      '    services/',
      '    routes/',
      '    middleware/',
      '    validators/',
      '  prisma/',
      '    schema.prisma',
      'frontend/',
      '  pages/',
      '  components/',
      'db/',
      '  seed.sql',
      'tests/',
      'docker-compose.yml',
      'Dockerfile',
      '```',
      '',
      'Generate files in this ORDER:',
      '1. prisma/schema.prisma   database schema first',
      '2. backend/   all backend code',
      '3. frontend/   all frontend code',
      '4. tests/   tests',
      '5. docker-compose.yml   deployment',
      '',
      '## 14. Priority Order',
      '',
      'Build in this priority order:',
      '',
      '**P0   Core (build first):**',
      '- Database schema (Prisma)',
      '- Entity repositories (CRUD)',
      '- Core services (business logic)',
      '- API routes (REST endpoints)',
      '- Basic UI (list, create, edit)',
      '',
      '**P1   Essential (build second):**',
      '- UI pages (detail, search, filter)',
      '- Validation and error handling',
      '- Auth integration',
      '',
      '**P2   Enhancement (build last):**',
      '- Advanced UI (dashboard, charts)',
      '- Export features',
      '- Additional polish',
      '',
      '## 15. Non-Goals',
      '',
      'DO NOT build unless explicitly requested:',
      '- Analytics / tracking systems',
      '- Notification system (email, push, SMS)',
      '- Microservices architecture (keep monolith)',
      '- Real-time features (WebSocket)',
      '- File upload / storage system',
      '- Payment gateway integration',
      '- Multi-language / i18n',
      '- Mobile apps (responsive web only)',
      '- Admin panel (unless specified)',
      '- Third-party integrations',
      '',
      '## Anti-SLOP UI Rules',
      '',
      '### DO NOT:',
      '- ‌ No gradient backgrounds or heavy drop-shadows',
      '- ‌ No stock images or illustrations',
      '- ‌ No rounded borders >12px',
      '- ‌ No marketing/landing pages',
      '- ‌ No "Under Construction" pages or placeholders',
      '- ‌ No unused components or dead code',
      '',
      '### MUST HAVE:',
      '- Spacing system: 4/8/12/16/20/24/32/48/64',
      '- Empty/loading/error/success states on all screens',
      '- Responsive: mobile, tablet, desktop',
      '- Validation on all inputs',
      '- Seed data with realistic values',
      '- Dark mode support via CSS variables',
      '',
      '## Error Messages (Top 5)',
      '',
      '| Scenario | Exact Message |',
      '|----------|--------------|',
      '| Validation failed | "Data tidak valid. Periksa kembali input Anda" |',
      '| Network timeout | "Koneksi terputus. Periksa Internet Anda" |',
      '| Resource not found | "Data tidak ditemukan" |',
      '| Insufficient permission | "Kamu tidak memiliki akses untuk aksi ini" |',
      '| Server error | "Terjadi kesalahan sistem. Tim kami sedang memperbaikinya" |',
    ].join('\n');

    //    PRD content   
    const prdContent = '# PRD - ' + productName + '\n\n' +
      '## 1. Executive Summary\n' +
      productName + ' adalah produk digital untuk ' + targetUser2 + '. Ide awal: "' + ideaText + '". Produk ini harus membantu user mencapai outcome utama: ' + mainOutcome + '.\n\n' +
      'Dokumen ini dibuat untuk handoff ke developer dan AI coding tools. Fokus MVP adalah membuat flow inti berjalan stabil, data model jelas, dan ruang lingkup tidak melebar sebelum validasi awal.\n\n' +
      '## 2. Problem, Goals, and Non-goals\n' +
      '### Problem\n' +
      '- User belum punya workflow yang rapi untuk menyelesaikan kebutuhan utama produk.\n' +
      '- Data dan keputusan penting berisiko tercecer di chat, spreadsheet, atau proses manual.\n' +
      '- Tim developer/AI coding tool butuh spesifikasi yang eksplisit agar implementasi tidak melenceng.\n\n' +
      '### Goals\n' +
      '- Mengubah ide menjadi aplikasi MVP yang bisa digunakan end-to-end.\n' +
      '- Memastikan fitur utama punya acceptance criteria yang dapat dites.\n' +
      '- Menyediakan struktur data, user flow, dan prioritas build yang jelas.\n' +
      '- Mendukung skala awal: ' + scale + '.\n\n' +
      '### Non-goals\n' +
      '- Tidak membangun semua fitur nice-to-have pada fase pertama.\n' +
      '- Tidak membuat sistem enterprise kompleks sebelum ada validasi penggunaan.\n' +
      '- Tidak mengunci stack terlalu awal jika pilihan "AI pilih" masih digunakan.\n\n' +
      '## 3. Target Users and Use Cases\n' +
      '| User | Kebutuhan | Skenario utama |\n' +
      '|------|-----------|----------------|\n' +
      pack.actors.map(a => '| ' + a + ' | ' + buildActorDesc(a, domain) + ' | Menjalankan workflow inti sesuai peran |').join('\n') + '\n\n' +
      'Catatan target user: ' + targetUser + '\n\n' +
      '## 4. MVP Scope\n' +
      '| Priority | Feature | User Story | Acceptance Criteria |\n' +
      '|----------|---------|------------|---------------------|\n' +
      buildFeatureRows(features) + '\n\n' +
      '### Optional / Phase 2\n' +
      (state.extras.length ? state.extras.map((item, idx) => { const found = EXTRA_OPTIONS.find(([key]) => key === item); return '' + (idx + 1) + '. ' + (found ? found[1] : item); }).join('\n') : '1. Integrasi tambahan setelah MVP tervalidasi.') + '\n\n' +
      '## 5. Detailed User Flow\n' +
      pack.flows.map((f, i) => '' + (i + 1) + '. ' + f).join('\n') + '\n\n' +
      '```mermaid\nsequenceDiagram\n' +
      '    participant ' + (pack.actors[0] || 'User') + ' as ' + (pack.actors[0] || 'User') + '\n' +
      '    participant UI as Frontend\n' +
      '    participant API as Backend API\n' +
      '    participant DB as Database\n\n' +
      '    ' + (pack.actors[0] || 'User') + '->>UI: Buka dashboard dan jalankan flow utama\n' +
      '    UI->>API: Kirim request terstruktur\n' +
      '    API->>API: Validasi input dan permission\n' +
      '    API->>DB: Simpan atau ambil data\n' +
      '    DB-->>API: Response data\n' +
      '    API-->>UI: Status sukses/gagal + payload\n' +
      '    UI-->>' + (pack.actors[0] || 'User') + ': Update tampilan dan feedback\n' +
      '```\n\n' +
      '## 6. Functional Requirements\n' +
      '### Core\n' +
      features.map((feature, index) => '' + (index + 1) + '. **' + feature + '**\n   - Input harus tervalidasi.\n   - State UI harus jelas: empty, loading, success, error.\n   - Perubahan data harus tercatat untuk audit atau riwayat.').join('\n') + '\n\n' +
      '### Authentication and Permission\n' +
      '- Role/access: ' + roles + '\n' +
      '- Auth masuk MVP: ' + (state.extras.includes('auth') ? 'Ya' : 'Opsional, bisa single-user pada MVP') + '\n' +
      '- Setiap endpoint mutasi wajib memeriksa permission.\n\n' +
      '### Payment\n' +
      '- Payment model: ' + payment + '\n' +
      '- Monetisasi awal: ' + monetization + '\n\n' +
      '### AI Behavior\n' +
      '- ' + aiBehavior + '\n\n' +
      '## 7. Data Model and Database Schema\n' +
      'Entitas utama:\n' +
      entityNames.map(e => '- `' + e + '`').join('\n') + '\n\n' +
      '```mermaid\nerDiagram\n' +
      buildEntityDiagram(pack) + '\n' +
      '```\n\n' +
      '## 8. API Contract Draft\n' +
      '| Method | Endpoint | Purpose | Notes |\n' +
      '|--------|----------|---------|-------|\n' +
      endpointsTable + '\n\n' +
      '## 9. UX and Screen Requirements\n' +
      '### Screens\n' +
      '- Dashboard: KPI, shortcut action, list item penting, empty state.\n' +
      '- Data List: search, filter, sort, pagination, bulk action opsional.\n' +
      '- Create/Edit Form: validasi inline, autosave opsional, submit state jelas.\n' +
      '- Detail View: ringkasan, metadata, activity log.\n' +
      '- Settings/Admin: role, konfigurasi, preferensi.\n\n' +
      '### UI Rules\n' +
      '- Layout harus padat, mudah dipindai, dan tidak terasa seperti landing page.\n' +
      '- Gunakan empty state yang memberi aksi langsung.\n' +
      '- Semua tombol destruktif perlu konfirmasi.\n' +
      '- Mobile harus tetap bisa menjalankan flow utama, walau desktop boleh diprioritaskan.\n' +
      '- Hindari section yang cuma berisi janji fitur tanpa fungsi nyata.\n\n' +
      '## 10.5 Implementation Priority\n' +
      '1. Setup and onboarding flow.\n' +
      '2. Wizard input and AI config.\n' +
      '3. Result generation and artifact management.\n' +
      '4. Export and handoff packaging.\n' +
      '5. Advanced polish and optional features.\n\n' +
      '## 10.6 Handoff Checklist\n' +
      '- Apakah user bisa selesai tanpa kebingungan?\n' +
      '- Apakah prompt output cukup tajam untuk coding tool?\n' +
      '- Apakah setiap fitur punya alasan bisnis atau operasional?\n' +
      '- Apakah ada elemen visual yang terasa filler?\n' +
      '- Apakah state kosong dan error sudah tertangani?\n\n' +
      '## 10. Analytics, Success Metrics, and Events\n' +
      'Metrik utama: ' + metric + '\n\n' +
      'Event minimal:\n' +
      '- `app_opened`\n- `dashboard_viewed`\n- `item_created`\n- `item_updated`\n- `filter_used`\n- `export_clicked`\n- `error_seen`\n\n' +
      '## 11. Edge Cases and Validation\n' +
      '- User submit form kosong atau data tidak valid.\n' +
      '- User kehilangan koneksi saat proses simpan.\n' +
      '- Data duplikat atau konflik update.\n' +
      '- Permission user berubah saat sesi masih aktif.\n' +
      '- Dataset kosong, terlalu besar, atau filter tidak menemukan hasil.\n' +
      '- Payment webhook terlambat atau gagal, jika payment aktif.\n\n' +
      '## 12. Technical Recommendation\n' +
      '| Layer | Recommendation |\n' +
      '|-------|----------------|\n' +
      '| Frontend | ' + tech.frontend + ' |\n' +
      '| Backend | ' + tech.backend + ' |\n' +
      '| Database | ' + tech.database + ' |\n' +
      '| Deployment | ' + tech.deployment + ' |\n\n' +
      'Tambahan teknis:\n' +
      '- Gunakan schema validation pada client dan server.\n' +
      '- Gunakan migration untuk database.\n' +
      '- Simpan activity log untuk perubahan data penting.\n' +
      '- Buat seed data agar testing flow cepat.\n' +
      '- Pastikan error message bisa dipahami user non-teknis.\n\n' +
      '## 13. Build Plan\n' +
      '### Phase 1 - Foundation\n' +
      '- Setup project, auth jika dibutuhkan, database schema, dan layout dasar.\n' +
      '- Buat dashboard kosong + navigation.\n\n' +
      '### Phase 2 - Core Workflow\n' +
      '- Implementasi fitur P0.\n' +
      '- Tambahkan validasi, loading state, error state, dan activity log.\n\n' +
      '### Phase 3 - Handoff Quality\n' +
      '- Tambahkan analytics event.\n' +
      '- Tambahkan export/reporting jika relevan.\n' +
      '- QA responsive, permission, dan edge cases.\n\n' +
      '### Phase 4 - Launch Prep\n' +
      '- Seed data, monitoring, backup, rate limit, dan checklist deploy.\n\n' +
      '## 14. Test Plan\n' +
      '- Unit test untuk utility dan validation.\n' +
      '- Integration test untuk API create/update/list.\n' +
      '- E2E test untuk flow utama dari dashboard sampai data tersimpan.\n' +
      '- Regression test untuk role/permission.\n' +
      '- Manual QA untuk empty, loading, error, dan long-content states.\n\n' +
      '## 15. AI Coding Handoff Prompt\n' +
      'Gunakan prompt ini di Cursor, Claude Code, Codex, V0, Lovable, atau Bolt. Prompt ini sudah disusun untuk mengurangi revisi dan memaksa output yang langsung bisa dieksekusi:\n\n' +
      '```text\n' +
      'Build an MVP for "' + productName + '" based on this PRD. Prioritize the P0 features first. Create a functional app, not a marketing page. Use a clean operational UI with dashboard, list, create/edit form, detail view, and settings/admin where relevant.\n\n' +
      'The goal is to produce implementation-ready work with minimal back-and-forth. Do not widen scope unless the PRD explicitly requires it. When something is unclear, make the smallest reasonable assumption and state it once.\n\n' +
      'Operating rules:\n' +
      '- Start from the user’s real workflow and preserve it end-to-end.\n' +
      '- Edit the existing codebase thoughtfully instead of inventing a parallel architecture.\n' +
      '- Keep the UI compact, readable, and free of filler.\n' +
      '- Avoid generic AI-looking patterns, decorative noise, and hidden complexity.\n' +
      '- Make validation, loading, empty, error, and success states first-class.\n\n' +
      'Recommended stack:\n' +
      '- Frontend: ' + tech.frontend + '\n' +
      '- Backend: ' + tech.backend + '\n' +
      '- Database: ' + tech.database + '\n' +
      '- Deployment: ' + tech.deployment + '\n\n' +
      'Core requirements:\n' +
      features.map(f => '- ' + f).join('\n') + '\n\n' +
      'Quality bar:\n' +
      '- Implement loading, empty, success, and error states.\n' +
      '- Validate all user inputs.\n' +
      '- Keep database schema explicit and migration-friendly.\n' +
      '- Add seed data and basic tests for the main workflow.\n' +
      '- Make the first screen the actual app experience.\n' +
      '```\n\n' +
      '## 16. Reference and Constraints\n' +
      '- Referensi/batasan: ' + reference + '\n' +
      '- Bahasa output UI disarankan: Bahasa Indonesia\n' +
      '- Jangan menambah fitur besar di luar scope MVP tanpa validasi baru.\n\n' +
      '## 17. Security & Compliance\n' +
      '- Authentication model and session management\n- Data encryption at rest and in transit\n- Input validation and sanitization\n- Role-based access control\n- Audit logging\n- Compliance requirements (GDPR, UU ITE, etc. based on domain)\n- API rate limiting\n- CORS and security headers\n- Environment variable management\n\n' +
      '## 18. Performance Requirements\n' +
      '- Response time targets (API <200ms, page load <2s)\n- Concurrent user estimates for MVP\n- Caching strategy (Redis, CDN, SWR)\n- Database query optimization\n- Lazy loading and code splitting for frontend\n- Image and asset optimization\n- Error budget and SLIs\n- Database indexing requirements\n\n' +
      '## 19. Error Handling & Recovery\n' +
      '- Graceful error states for empty/loading/failure\n- Global error boundary\n- Form validation errors display\n- Network error recovery\n- 404 and unauthorized handling\n- Graceful degradation for offline or slow connection\n- Data conflict resolution on concurrent edits\n- Rollback strategy for failed mutations\n- Automatic retry with exponential backoff for critical operations';

    //    Output Summary   
    const summaryContent = '# Ringkasan Output: ' + productName + '\n\n' +
      '## Cara Pakai\n' +
      '1. Buka `prompt.md` → Copy semua konten\n' +
      '2. Paste ke Claude Code / OpenAI Codex / Cursor\n' +
      '3. AI akan generate full project\n' +
      '4. Ikuti instruksi di akhir untuk menjalankan\n\n' +
      '## Domain: ' + domain + (domainInfo.confidence > 0 ? ' (confidence: ' + (domainInfo.confidence * 100).toFixed(0) + '%)' : '') + '\n' +
      '## Tech Stack\n' +
      '- Frontend: ' + tech.frontend + '\n' +
      '- Backend: ' + tech.backend + '\n' +
      '- Database: ' + tech.database + '\n' +
      '- Deployment: ' + tech.deployment + '\n' +
      (state.extras.length > 0 ? '## Ekstra: ' + state.extras.map(e => { const f = EXTRA_OPTIONS.find(([k]) => k === e); return f ? f[1] : e; }).join(', ') : '') + '\n\n' +
      '## Target User: ' + targetUser + '\n\n' +
      '## Estimasi\n' +
      '- Phase 1 (Foundation & Auth): ~1 sprint\n' +
      '- Phase 2 (Core Domain Flow): ~1-2 sprint\n' +
      '- Phase 3 (Advanced): ~1 sprint\n\n' +
      '## File Lain\n' +
      'Semua spesifikasi sudah di-include dalam `prompt.md`.\n' +
      'File ini hanya ringkasan.';

    //    README   
    const readmeContent = '# ' + productName + '\n\n' +
      'Generated by PRDKit.\n\n' +
      '## Quick Start\n' +
      '1. Open `prompt.md` and paste into your AI coding tool\n' +
      '2. The AI will generate the full project\n' +
      '3. Follow the instructions in the output\n\n' +
      '## Files\n' +
      '- `prompt.md`   Master prompt for AI tools (Claude Code, Codex, Cursor)\n' +
      '- `prd.md`   Full product requirements document (19 sections)\n' +
      '- `output-summary.md`   Quick overview\n\n' +
      '## Tech Stack\n' +
      '- Frontend: ' + tech.frontend + '\n' +
      '- Backend: ' + tech.backend + '\n' +
      '- Database: ' + tech.database + '\n' +
      '- Deployment: ' + tech.deployment + '\n\n' +
      '---\n\n' +
      'Generated on ' + new Date().toISOString().split('T')[0];

    //    Set artifacts   
    const engineJsonArtifacts = [];
    if (engineArtifacts) {
      const engineJsonMap = {
        domain: { label: 'Domain.json', ext: 'json' },
        relations: { label: 'Relations.json', ext: 'json' },
        modules: { label: 'Modules.json', ext: 'json' },
        validation: { label: 'Validation.json', ext: 'json' },
        architecture: { label: 'Architecture.json', ext: 'json' },
        security: { label: 'Security.json', ext: 'json' },
        documentation: { label: 'Documentation.json', ext: 'json' },
      };
      for (const [key, meta] of Object.entries(engineJsonMap)) {
        if (engineArtifacts[key]) {
          engineJsonArtifacts.push({
            id: 'engine-' + key,
            label: meta.label,
            ext: meta.ext,
            content: JSON.stringify(engineArtifacts[key], null, 2),
          });
        }
      }
    }
    const chunkedArtifacts = buildChunkedArtifacts(promptContent);
    const tasksMd = buildTasksMd();
    const structureMd = buildStructureMd();

    state.artifacts = [
      ...engineJsonArtifacts,
      { id: 'prompt', label: 'Prompt.md', ext: 'md', content: promptContent },
      ...chunkedArtifacts,
      { id: 'tasks', label: 'Tasks.md', ext: 'md', content: tasksMd },
      { id: 'structure', label: 'Structure.md', ext: 'md', content: structureMd },
      { id: 'prd', label: 'PRD', ext: 'md', content: prdContent },
      { id: 'summary', label: 'Summary', ext: 'md', content: summaryContent },
      { id: 'readme', label: 'README', ext: 'md', content: readmeContent },
      // Project metadata JSON
      {
        id: 'metadata',
        label: 'project-metadata.json',
        ext: 'json',
        content: JSON.stringify({
          name: state.productName || 'Untitled',
          domain: (engineArtifacts && engineArtifacts.domain) ? engineArtifacts.domain.primaryDomain : 'unknown',
          confidence: (engineArtifacts && engineArtifacts.domain) ? engineArtifacts.domain.confidence : 0,
          actors: (engineArtifacts && engineArtifacts.domain) ? engineArtifacts.domain.actors : [],
          entities: (engineArtifacts && engineArtifacts.domain) ? engineArtifacts.domain.entities.map(e => e.name) : [],
          createdAt: new Date().toISOString(),
          version: '1.0.0-beta',
          activeEngines: Object.entries(ENGINE_FLAGS).filter(([k,v]) => v).map(([k]) => k),
          artifactCount: state.artifacts ? state.artifacts.length : 0,
        }, null, 2),
      },
    ];

    state.productName = productName;
    state.currentArtifact = 0;
    const version = 'v1.0';
    state.versions = [{ id: Date.now().toString(), version, timestamp: new Date().toISOString() }];
    state.currentVersion = 0;
  }

  //     Chunked & Task Artifacts    
  function buildChunkedArtifacts(promptContent) {
    const chunkMap = { product: [], datamodel: [], modules: [], security: [], flows: [], implementation: [] };
    const currentSection = { name: 'product', lines: [] };
    const sectionHeaders = {
      '1. Project Overview': 'product',
      '2. Domain Analysis': 'product',
      '3. Actors': 'product',
      '4. Entities': 'datamodel',
      '5. Relationships': 'datamodel',
      '6. Modules': 'modules',
      'User Flow': 'flows',
      'Validation Rules': 'datamodel',
      '7. Validation Rules': 'datamodel',
      '8. Architecture Pattern': 'implementation',
      '9. Security Model': 'security',
      '10. Technical Constraints': 'implementation',
      '11. Folder Structure': 'implementation',
      '12. Acceptance Criteria': 'flows',
      '13. Output Format': 'implementation',
      '14. Priority Order': 'implementation',
      '15. Non-Goals': 'implementation',
      '16. User Flow': 'flows',
    };
    const sectionNames = {
      product: '01-Product',
      datamodel: '02-Data-Model',
      modules: '03-Modules',
      security: '04-Security',
      flows: '05-Flows',
      implementation: '06-Implementation',
    };

    // Split promptContent into lines and chunk based on section headers
    const lines = promptContent.split('\n');
    lines.forEach(line => {
      for (const [header, section] of Object.entries(sectionHeaders)) {
        if (line.includes('## ' + header) || line.includes('# ' + header)) {
          if (currentSection.lines.length > 0 && currentSection.name !== section) {
            chunkMap[currentSection.name].push(...currentSection.lines);
            currentSection.lines = [];
          }
          currentSection.name = section;
          break;
        }
      }
      currentSection.lines.push(line);
    });
    // Push last section
    if (currentSection.lines.length > 0) {
      chunkMap[currentSection.name].push(...currentSection.lines);
    }

    // Build chunked artifacts
    const chunkedArtifacts = Object.entries(chunkMap).map(([key, lines]) => ({
      id: 'chunk-' + key,
      label: sectionNames[key] + '.md',
      ext: 'md',
      content: lines.join('\n'),
    }));

    return chunkedArtifacts;
  }

  function buildTasksMd() {
    return [
      '# Implementation Tasks',
      '',
      '## P0   Core (build first)',
      '',
      '### T1: Database Schema',
      '- File: prisma/schema.prisma',
      '- Depends on: nothing',
      '- Output: Complete Prisma schema with all models, enums, and relations',
      '',
      '### T2: Backend Core',
      '- Files: src/repositories/, src/services/, src/routes/',
      '- Depends on: T1',
      '- Output: CRUD routes with validation, error handling, and auth middleware',
      '',
      '### T3: Frontend Core Pages',
      '- Files: frontend/pages/, frontend/components/',
      '- Depends on: T2',
      '- Output: Working UI with empty/loading/error/success states',
      '',
      '## P1   Essential (build second)',
      '',
      '### T4: Auth & Security',
      '- Files: src/middleware/auth.ts, src/middleware/rbac.ts',
      '- Depends on: T2',
      '- Output: JWT authentication, role-based access control',
      '',
      '### T5: Tests',
      '- Files: tests/',
      '- Depends on: T1, T2, T3',
      '- Output: Unit + integration tests for core flows',
      '',
      '## P2   Enhancement (build last)',
      '',
      '### T6: UI Polish',
      '- Files: frontend/',
      '- Depends on: T3',
      '- Output: Dashboard, advanced filtering, export features',
      '',
      '### T7: Deployment',
      '- Files: Dockerfile, docker-compose.yml, .github/workflows/',
      '- Depends on: T1, T2, T3',
      '- Output: CI/CD pipeline, container setup',
      '',
    ].join('\n');
  }

  function buildStructureMd() {
    return [
      '# Recommended Project Structure',
      '',
      '```',
      'backend/',
      '  src/',
      '    repositories/    # Data access layer',
      '    services/        # Business logic',
      '    routes/          # API endpoints',
      '    middleware/      # Auth, validation, error handling',
      '    validators/      # Input validation schemas',
      '  prisma/',
      '    schema.prisma    # Database schema',
      'frontend/',
      '  pages/             # Route pages',
      '  components/        # Reusable UI components',
      '  hooks/             # Custom React hooks',
      '  utils/             # Utility functions',
      'tests/',
      '  unit/',
      '  integration/',
      'docs/',
      'docker-compose.yml',
      'Dockerfile',
      '```',
      '',
      'Generate files in this ORDER:',
      '1. prisma/schema.prisma   database schema first',
      '2. backend/   all backend code',
      '3. frontend/   all frontend code',
      '4. tests/   tests',
      '5. docker-compose.yml   deployment',
      '',
    ].join('\n');
  }

function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

async function enrichWithAI() {
  // Only run if AI is available (callAI function exists)
  if (typeof callAI !== 'function') return;
  
  const prdIndex = state.artifacts.findIndex(a => a.id === 'prd');
  if (prdIndex < 0) return;
  
  const prd = state.artifacts[prdIndex].content;
  const domainInfo = getDomain();
  const domain = domainInfo.primary;
  const defaults = getDomainDefaults(domain);
  
  // Build enrichment prompt with full context
  const enrichmentPrompt = [
    'Kamu adalah AI PRD enrichment specialist untuk founder Indonesia.',
    'Tugasmu: memperkaya dokumen PRD berikut dengan konten yang lebih spesifik, realistis, dan implementatif.',
    'Jangan mengubah struktur atau format markdown yang sudah ada.',
    'HANYA perbaiki dan perkaya konten di BAGIAN INI:',
    '',
    '1. Bagian "Detailed User Flow"   tambahkan 1-2 skenario spesifik dan realistis sesuai domain produk',
    '2. Bagian "Edge Cases"   tambahkan 3-5 edge cases spesifik yang benar-benar terjadi di domain ini',
    '3. Bagian "Error Handling"   tambahkan error recovery strategy spesifik sesuai tech stack',
    '4. Bagian "Build Plan"   bagi menjadi sprint yang lebih realistis dengan deliverables konkret',
    '5. Bagian "API Contract"   tambahkan endpoint spesifik yang dibutuhkan domain ini',
    '',
    'Output HANYA potongan PRD yang direvisi, dengan format markdown yang sama.',
    'Setiap konten yang direvisi HARUS dibungkus dengan <AI-ENRICH> ... </AI-ENRICH>.',
    'Setiap blok <AI-ENRICH> HARUS diawali dengan heading section yang EXACT sama dengan PRD asli (misal: ## 5. Detailed User Flow).',
    'Heading tersebut akan digunakan untuk mencocokkan dan mengganti konten di section yang tepat.',
    '',
    `Domain: ${domain}`,
    `Tech Stack: ${JSON.stringify(buildTechStack())}`,
    `Extras: ${state.extras.join(', ')}`,
    '',
    `PRD saat ini:\n\n${prd}`,
  ].join('\n');
  
  try {
    showToast('Mengoptimalkan PRD dengan AI...', 'info');
    const response = await callAI([{ role: 'user', content: enrichmentPrompt }]);
    if (response) {
      // Extract enriched sections from response
      const enrichedBlocks = response.match(/<AI-ENRICH>([\s\S]*?)<\/AI-ENRICH>/g) || [];
      
      if (enrichedBlocks.length === 0) {
        showToast('AI tidak menghasilkan optimasi', 'info');
        return;
      }
      
      let replaced = 0;
      let html = state.artifacts[prdIndex].content;
      
      for (const block of enrichedBlocks) {
        // Extract content inside AI-ENRICH tags
        const sectionHtml = block.replace(/<\/?AI-ENRICH>/g, '').trim();
        
        // Extract section heading (e.g., "## 5. Detailed User Flow")
        const headingMatch = sectionHtml.match(/^##\s+(.+)$/m);
        if (headingMatch) {
          const headingText = headingMatch[1].trim();
          // Find matching section in PRD content.
          // Match heading + everything until next ## heading or end of string.
          const sectionRegex = new RegExp(
            `(^##\\s+${escapeRegex(headingText)}\\s*)\\n[\\s\\S]*?(?=\\n##\\s|$)`,
            'm'
          );
          if (sectionRegex.test(html)) {
            // Get the new content (everything after the heading in the AI block)
            const newContent = sectionHtml.replace(/^##\s+.*$/m, '').trim();
            // Replace section: keep heading intact, replace content below
            html = html.replace(sectionRegex, `$1\n${newContent}\n`);
            replaced++;
          }
        }
      }
      
      // If nothing could be matched, append at bottom (fallback)
      if (replaced === 0) {
        html += '\n\n---\n' + response;
      }
      
      state.artifacts[prdIndex].content = html;
      renderArtifacts();
      showToast(`${replaced} section berhasil dioptimalkan AI`, 'success');
    }
  } catch(e) {
    showToast('Gagal mengoptimalkan PRD', 'error');
  }
}

//     Saved Provider Selection    


// Start fresh project from home
function newProject() {
  if (!state.user) {
    showToast('Silakan login terlebih dahulu.', 'error');
    return;
  }
  resetState();
  navigate('setup');
}

// Reset project state (keep AI config)
function resetState() {
  state.step = 1;
  state.surveyQ = 0;
  state.surveyTotal = 6;
  state.surveyMode = '';
  state.productName = '';
  state.idea = '';
  state.productType = 'web';
  state.productRef = '';
  state.productCategory = '';
  state.productCatName = '';
  state.productCategoryParent = '';
  state.tech = {};
  state.extras = [];
  state.answers = {};
  state.artifacts = [];
  state.currentArtifact = 0;
  state.versions = [];
  state.currentVersion = 0;
  state.chatHistory = [];
  state.savedQuestions = [];
  _surveyQuestions = [];
  window.engineArtifacts = null;
  saveState();
}

function getTechLabel(cat) {
  const found = TECH_OPTIONS[cat]?.find(t => t[0] === state.tech[cat]);
  return found ? found[1] : 'AI pilih';
}

//     Artifact Rendering    
function renderArtifacts() {
  const tabs = document.getElementById('artifactTabs');
  if (tabs) {
    const engineArts = state.artifacts.filter(a => a.id.startsWith('engine-'));
    const regArts = engineArts.length ? state.artifacts.filter(a => !a.id.startsWith('engine-')) : state.artifacts;
    const onEngine = state._engineTabActive;

    // Group definitions   Workspace, Documents, Project (metadata), then Engine
    const workspaceIds = ['chunk-product','chunk-datamodel','chunk-modules','chunk-security','chunk-flows','chunk-implementation','tasks','structure'];
    const docIds = ['prompt','prd','summary','readme'];
    const metaId = 'metadata';

    const byId = id => regArts.filter(a => a.id === id);
    const tabHtml = (a) => {
      const idx = state.artifacts.indexOf(a);
      const active = !onEngine && state.currentArtifact === idx;
      return `<span class="result-tab${active ? ' active' : ''}" onclick="selectArtifact(${idx})">
        ${iconSvg(ARTIFACT_ICONS[a.id] || 'file', 12)} ${a.label}
      </span>`;
    };

    let html = '';

    //   Workspace group
    workspaceIds.forEach(id => { byId(id).forEach(a => { html += tabHtml(a); }); });

    //   Documents group
    docIds.forEach(id => { byId(id).forEach(a => { html += tabHtml(a); }); });

    //   Project / metadata
    byId(metaId).forEach(a => { html += tabHtml(a); });

    //   Other (unclassified) artifacts, if any
    const classified = new Set([...workspaceIds, ...docIds, metaId]);
    regArts.filter(a => !classified.has(a.id)).forEach(a => { html += tabHtml(a); });

    //   Engine tab (last, collapsed by default with count badge)
    if (engineArts.length) {
      html += `<span class="result-tab${onEngine ? ' active' : ''}" onclick="selectEngineTab()">
        ${iconSvg('box', 12)} Engine
        ${!onEngine ? '<span style="font-size:10px;color:var(--muted-dim);margin-left:2px;">(' + engineArts.length + ')</span>' : ''}
      </span>`;
    }

    tabs.innerHTML = html;
  }

  if (state._engineTabActive) {
    renderEngineCards();
  } else {
    showArtifact();
  }
  renderPreview();
}

function selectEngineTab() {
  state._engineTabActive = true;
  renderArtifacts();
}

function renderEngineCards() {
  const container = document.getElementById('artifactContent');
  if (!container) return;

  const engineArts = state.artifacts.filter(a => a.id.startsWith('engine-'));
  if (!engineArts.length) {
    container.innerHTML = '<p style="text-align:center;padding:40px;color:var(--muted-dim);">No engine artifacts available.</p>';
    return;
  }

  let html = '<div class="engine-cards-grid" style="display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:16px;padding:16px;">';
  engineArts.forEach(a => {
    const jsonData = a.content;
    const truncated = jsonData.length > 800 ? jsonData.substring(0, 800) + '\n...' : jsonData;
    const filename = (state.productName || 'blueprint') + '-' + a.id + '.' + a.ext;
    html += '<div class="engine-card" style="background:var(--card-bg,#fff);border:1px solid var(--border,#e0e0e0);border-radius:10px;overflow:hidden;display:flex;flex-direction:column;">';
    html += '<div style="display:flex;align-items:center;gap:8px;padding:12px 14px;border-bottom:1px solid var(--border,#e0e0e0);font-weight:600;font-size:13px;">';
    html += iconSvg('fileText', 15) + ' ' + a.label + '</div>';
    html += '<pre style="flex:1;padding:14px;font-size:11px;line-height:1.5;overflow:auto;max-height:200px;margin:0;background:var(--bg-subtle,#f8f8f8);white-space:pre-wrap;word-break:break-all;">' + escapeHtml(truncated) + '</pre>';
    html += '<div style="display:flex;gap:8px;padding:10px 14px;border-top:1px solid var(--border,#e0e0e0);">';
    html += '<button class="action-btn action-primary" style="flex:1;font-size:12px;" onclick="downloadFile(state.artifacts.find(x=>x.id===\'' + a.id + '\').content,\'' + filename + '\',\'application/json\');showToast(\'Downloaded ' + a.label + '\',\'success\');">';
    html += iconSvg('download', 12) + ' Download</button>';
    html += '<button class="action-btn" style="font-size:12px;" onclick="navigator.clipboard.writeText(state.artifacts.find(x=>x.id===\'' + a.id + '\').content).then(()=>showToast(\'Copied!\',\'success\'))">' + iconSvg('copy', 12) + ' Copy</button>';
    html += '</div></div>';
  });
  html += '</div>';
  container.innerHTML = html;
}

function showArtifact() {
  const a = state.artifacts[state.currentArtifact];
  if (!a) return;
  const container = document.getElementById('artifactContent');
  if (!container) return;

  if (window._viewMode === 'edit') {
    container.innerHTML = `<textarea class="artifact-edit" id="artifactEditArea">${escapeHtml(a.content)}</textarea>`;
  } else if (a.id === 'diagram') {
    container.innerHTML = `<div class="artifact-diagram"><pre style="text-align:left;display:inline-block;">${escapeHtml(a.content)}</pre></div>`;
  } else if (['tokens', 'schema', 'types'].includes(a.id)) {
    container.innerHTML = `<pre class="artifact-code">${escapeHtml(a.content)}</pre>`;
  } else {
    container.innerHTML = `<div class="artifact-md">${renderMarkdown(a.content)}</div>`;
  }
}

//     Saved Provider Selection    


function renderMarkdown(md) {
  // Simple yet safe markdown renderer
  let html = escapeHtml(md);
  // Headers
  html = html.replace(/^### (.+)$/gm, '<h3>$1</h3>');
  html = html.replace(/^## (.+)$/gm, '<h2>$1</h2>');
  html = html.replace(/^# (.+)$/gm, '<h1>$1</h1>');
  // Unordered lists
  html = html.replace(/^- (.+)$/gm, '<li>$1</li>');
  html = html.replace(/(<li>.*<\/li>\n?)+/g, '<ul>$&</ul>');
  // Paragraphs (double newlines)
  html = html.replace(/\n\n/g, '</p><p>');
  // Bold
  html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  html = `<p>${html}</p>`;
  return html;
}

function selectArtifact(i) {
  state.currentArtifact = i;
  state._engineTabActive = false;
  renderArtifacts();
}

//     View Mode: Preview vs Edit    
let _viewMode = 'preview';

function setViewMode(mode) {
  _viewMode = mode;
  const pBtn = document.getElementById('previewBtn');
  const eBtn = document.getElementById('editBtn');
  if (pBtn) pBtn.classList.toggle('active', mode === 'preview');
  if (eBtn) eBtn.classList.toggle('active', mode === 'edit');
  showArtifact();
}

function getCurrentArtifactContent() {
  const a = state.artifacts[state.currentArtifact];
  return a ? a.content : '';
}

function copyArtifact() {
  const content = getCurrentArtifactContent();
  if (!content) { showToast('No artifact content to copy.', 'error'); return; }
  navigator.clipboard.writeText(content).then(() => {
    showToast('Copied to clipboard!', 'success');
  }).catch(() => {
    showToast('Failed to copy.', 'error');
  });
}

function downloadArtifact() {
  const a = state.artifacts[state.currentArtifact];
  if (!a) { showToast('No artifact to download.', 'error'); return; }
  const name = state.productName || 'blueprint';
  const filename = `${name}-${a.id}.${a.ext || 'md'}`;
  downloadFile(a.content, filename, 'text/markdown');
  showToast(`Downloaded ${filename}`, 'success');
}

function printArtifact() {
  const content = getCurrentArtifactContent();
  if (!content) { showToast('No content to print.', 'error'); return; }
  const win = window.open('', '_blank');
  win.document.write(`<!DOCTYPE html><html><head><title>PRDKit Print</title><style>
    body { font-family: system-ui, sans-serif; line-height: 1.6; padding: 40px; max-width: 800px; margin: 0 auto; color: #111; }
    h1, h2, h3 { font-weight: 700; }
    pre { background: #f5f5f5; padding: 12px; border-radius: 6px; overflow-x: auto; font-size: 12px; }
  </style></head><body>${renderMarkdown(content)}</body></html>`);
  win.document.close();
  setTimeout(() => { win.focus(); win.print(); }, 300);
}

//     Preview Pane    
function renderPreview() {
  const container = document.getElementById('previewPaneContent');
  if (!container) return;
  const a = state.artifacts[state.currentArtifact];
  if (!a) {
    container.innerHTML = '<p style="color:var(--muted-dim);text-align:center;padding:20px 0;font-size:13px;">Preview will appear here</p>';
    return;
  }
  const nameEl = document.getElementById('previewPaneName');
  if (nameEl) nameEl.textContent = a.label;
  container.innerHTML = `<div class="artifact-md">${renderMarkdown(a.content)}</div>`;
}

function togglePreviewPane() {
  const pane = document.getElementById('resultPreviewPane');
  if (pane) pane.classList.toggle('open');
}

function openMobilePreview() {
  const pane = document.getElementById('resultPreviewPane');
  const overlay = document.getElementById('resultPreviewOverlay');
  if (pane) pane.classList.add('open');
  if (overlay) overlay.classList.add('open');
}

function closeMobilePreview() {
  const pane = document.getElementById('resultPreviewPane');
  const overlay = document.getElementById('resultPreviewOverlay');
  if (pane) pane.classList.remove('open');
  if (overlay) overlay.classList.remove('open');
}

//     Version Rendering    
function renderVersions() {
  const list = document.getElementById('versionList');
  if (!list) return;
  if (!state.versions || state.versions.length === 0) {
    list.innerHTML = '<span class="version-btn active">v1.0</span>';
    return;
  }
  list.innerHTML = state.versions
    .map((v, i) =>
      `<span class="version-btn${i === state.currentVersion ? ' active' : ''}" onclick="switchVersion(${i})">${v.version}</span>`
    )
    .join('');
}

function switchVersion(index) {
  state.currentVersion = index;
  const v = state.versions[index];
  if (v && v.artifacts) {
    state.artifacts = JSON.parse(JSON.stringify(v.artifacts));
    state.answers = JSON.parse(JSON.stringify(v.answers));
    state.currentArtifact = 0;
    renderArtifacts();
    renderVersions();
    saveState();
    showToast(`Beralih ke versi ${v.version}`, 'success');
  }
}

//     Saved Provider Selection    


//     Meta (kept for compatibility, renders into a hidden element if needed)    
function renderMeta() {
  // No separate meta section in new layout; kept as no-op for compatibility
}

//     History Sidebar    
function getRelativeTime(isoStr) {
  if (!isoStr) return '';
  const now = Date.now();
  const then = new Date(isoStr).getTime();
  const diff = now - then;
  const sec = Math.floor(diff / 1000);
  if (sec < 60) return 'Baru saja';
  const min = Math.floor(sec / 60);
  if (min < 60) return `${min} menit lalu`;
  const hour = Math.floor(min / 60);
  if (hour < 24) return `${hour} jam lalu`;
  const day = Math.floor(hour / 24);
  if (day < 7) return `${day} hari lalu`;
  const date = new Date(isoStr);
  return date.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
}

function toggleHistorySidebar() {
  const sidebar = document.getElementById('resultHistory');
  const overlay = document.getElementById('resultOverlay');
  if (sidebar) sidebar.classList.toggle('open');
  if (overlay) overlay.classList.toggle('open');
}

async function renderResultHistory() {
  const list = document.getElementById('historyList');
  if (!list) return;
  try {
    const history = await loadProjectHistory();
    if (!history || history.length === 0) {
      list.innerHTML = '<div style="padding:20px;text-align:center;font-size:12px;color:var(--muted-dim);">No projects yet</div>';
      return;
    }
    const currentId = state._projectId;
    list.innerHTML = history.map(p => {
      const active = p.id === currentId ? ' active' : '';
      const desc = p.model || '';
      const time = getRelativeTime(p.createdAt);
      return `<div class="history-item${active}" onclick="continueProjectHistory('${p.id}')">
        <div class="history-item-name">${escapeHtml(p.name || 'Untitled')}</div>
        <div class="history-item-desc">${escapeHtml(desc)}</div>
        <div class="history-item-time">${time}</div>
        <button class="history-item-del" onclick="event.stopPropagation();deleteProject('${p.id}')" title="Hapus">&#x2715;</button>
      </div>`;
    }).join('');
  } catch(e) {
    list.innerHTML = '<div style="padding:20px;text-align:center;font-size:12px;color:var(--muted-dim);">Failed to load history</div>';
  }
}

//     Saved Provider Selection    


async function continueProjectHistory(id) {
  await continueProject(id);
}



function generatePRD() {
  if (typeof createArtifacts === 'function') {
    createArtifacts();
    renderArtifacts();
    renderVersions();
    renderPreview();
    enrichWithAI().catch(e => { showToast('Gagal mengoptimalkan PRD', 'error'); });
    saveState();
    saveProjectToHistory();
    showToast('PRD regenerated!', 'success');
  } else {
    showToast('Generate function not available.', 'error');
  }
}

//     Saved Provider Selection    


//     Revision Chat    
async function sendRevision() {
  const input = document.getElementById('revisionInput');
  const msg = input.value.trim();
  if (!msg) return;
  input.value = '';

  const chat = document.getElementById('chatMessages');
  chat.innerHTML += `<div class=\"chat-msg user\">${escapeHtml(msg)}</div>`;

  try {
    const res = await callAI([
      {
        role: 'user',
        content: `Produk: ${document.getElementById('productName').value || 'MyApp'}\n\nUser minta revisi:\n${msg}\n\nJelaskan perubahan yang kamu buat. Jawab Bahasa Indonesia.`,
      },
    ]);
    if (res) {
      chat.innerHTML += `<div class=\"chat-msg ai\">${escapeHtml(res)}</div>`;
      // Create new version
      const ver = `v${state.versions.length + 1}.0`;
      state.versions.push({
        version: ver,
        artifacts: JSON.parse(JSON.stringify(state.artifacts)),
        prdl: '',
        answers: JSON.parse(JSON.stringify(state.answers)),
      });
      state.currentVersion = state.versions.length - 1;
      renderVersions();
      renderMeta();
      showToast(`Revisi disimpan sebagai ${ver}`, 'success');
    } else {
      chat.innerHTML += '<div class=\"chat-msg ai\">Maaf, terjadi kesalahan. Coba lagi.</div>';
    }
  } catch {
    chat.innerHTML += '<div class=\"chat-msg ai\">Maaf, terjadi kesalahan. Coba lagi.</div>';
  }
  chat.scrollTop = chat.scrollHeight;
  saveState();
  saveProjectToHistory();
}

//     Download    
function downloadAll() {
  const name = document.getElementById('productName').value || 'blueprint';
  const parts = state.artifacts.map(a => `=== ${a.label}${a.ext} ===\n${a.content}`);
  const zipContent = parts.join('\n\n');
  downloadFile(zipContent, `${name}-artifacts.txt`, 'text/plain');
  showToast('Download berhasil!', 'success');
}

function downloadZip() {
  downloadAll();
}

function downloadFile(content, name, type) {
  const blob = new Blob([content], { type: `${type};charset=utf-8` });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 100);
}



//     AI    

// Generate AI ideas in wizard page based on product name   NO static fallback
async function generateAIExampleIdeas() {
  console.log('generateAIExampleIdeas called');

  const wizIdeas = document.getElementById('wizExampleIdeas');
  if (!wizIdeas) {
    console.log('generateAIExampleIdeas: wizExampleIdeas not found');
    return;
  }

  const productName = state.productName || '';
  console.log('generateAIExampleIdeas: productName =', productName);

  // Show loading state + rainbow glow
  wizIdeas.innerHTML = '<span class="loading-ai"><span class="spinner-ring"></span><span class="text-[11px]" style="color:var(--text-muted)">Mencari inspirasi...</span></span>';
  toggleCardProcessing(wizIdeas, true);

  if (!productName || productName.length < 3) {
    wizIdeas.innerHTML = '<span class="text-[11px]" style="color:var(--text-muted)">Isi nama produk dulu untuk saran ide dari AI.</span>';
    toggleCardProcessing(wizIdeas, false);
    return;
  }

  try {
    const type = state.productType || selectedType || 'Web App';
    const catParent = state.productCategoryParent || state.productCatName || '';
    const catSub = state.productCategory || '';
    
    const prompt = [
      'Kamu adalah product strategist yang membantu founder Indonesia ' +
      'menemukan ide produk digital yang SPESIFIK dan REALISTIS.',
      '',
      '=== KONTEKS PRODUK ===',
      '- Nama produk: "' + productName + '"',
      '- Tipe produk: ' + type,
      catParent ? '- Kategori: ' + catParent : '',
      catSub ? '- Sub-kategori: ' + catSub : '',
      '',
      'Buat 3 IDE PRODUK DIGITAL yang SPESIFIK   aplikasi/platform/software',
      'utuh yang bisa dibangun untuk mengembangkan bisnis tersebut.',
      '',
      'Aturan:',
      '- Spesifik & beda satu sama lain (masing-masing punya value proposition unik)',
      '- REALISTIS untuk UKM/startup Indonesia   bisa dibangun tim 1-3 developer',
      '- Desc: value proposition + scope dalam 1-2 kalimat',
      '- Judul harus jelasin FUNGSI produknya, bukan cuma nama brand + kata keren',
      '',
      'Contoh BENAR untuk nama produk "Aplikasi Laundry":',
      '[{"title": "Aplikasi Order Laundry Multi Cabang", "desc": "Platform order laundry dengan tracking status real-time dan pilih cabang terdekat"}]',
      '',
      'Contoh SALAH   JANGAN:',
      '  "Laundry Surprise"   nama brand extension, BUKAN produk digital utuh',
      '  "Laundry Mystery Box"   ini bukan aplikasi/platform, cuma ide model bisnis',
      '  "Fitur Tracking Driver"   ini fitur, BUKAN produk utuh',
      '',
      'Respons HANYA JSON array:',
      '[{"title":"...","desc":"..."}]'
    ].filter(Boolean).join('\n');

    const result = await callAI([
      { role: 'system', content: 'Kamu adalah asisten produk digital untuk founder Indonesia. Return HANYA JSON array tanpa markdown.' },
      { role: 'user', content: prompt }
    ]);

    if (!result) throw new Error('No result');

    const jsonMatch = result.match(/\[[\s\S]*\]/);
    if (!jsonMatch) throw new Error('No JSON found');

    const ideas = JSON.parse(jsonMatch[0]);
    if (!Array.isArray(ideas) || ideas.length === 0) throw new Error('Empty ideas');

    window._aiIdeas = ideas;

    var chipsHtml = ideas.map(function(idea, i) {
      return '<span class="chip" onclick="previewAIExampleIdea(' + i + ')">' +
        escapeHtml(idea.title || 'Ide ' + (i+1)) +
        '</span>';
    }).join('');
    var reloadBtn = '<button class="btn-accent-soft text-[11px] ml-auto" onclick="generateAIExampleIdeas()" title="Cari ide lain" style="padding:4px 10px;flex-shrink:0;white-space:nowrap">'+iconSvg('refresh',12)+' Lainnya</button>';
    wizIdeas.innerHTML = chipsHtml + reloadBtn;

  } catch(e) {
    console.warn('AI examples failed:', e);
    // Graceful message   no scary errors, just gentle push to manual
    wizIdeas.innerHTML =
      '<div class="flex flex-col gap-2">' +
      '<span class="text-[11px]" style="color:var(--text-muted)">Koneksi AI terputus. Isi ide manual aja dulu yaa</span>' +
      '<button class="btn-accent-soft text-[11px] self-start" onclick="generateAIExampleIdeas()" style="padding:5px 12px">Coba Lagi</button>' +
      '</div>';
  } finally {
    toggleCardProcessing(wizIdeas, false);
  }
}

//     AI Processing UI Helper    
// Toggle rainbow glow on parent .card element while AI is processing
function toggleCardProcessing(el, busy) {
  if (!el) return;
  var card = typeof el === 'string' ? document.querySelector(el) : el.closest('.card');
  if (!card || !card.classList) return;
  card.classList.toggle('ai-processing', busy);
}

//     AI Tech Recommendation    
// Generate AI tech stack recommendation based on product context
async function generateAITechRecommendation() {
  const productName = state.productName || '';
  const idea = state.idea || '';
  const type = state.productType || selectedType || 'Web App';

  // Need at least a product name to give meaningful recommendation
  if (!productName) {
    return;
  }

  // Show loading in AI Recommendation card (NOT in tech selection)
  window._aiTechRec = null;
  window._aiTechRecLoading = true;
  if (typeof renderAITechContainer === 'function') renderAITechContainer();
  // Rainbow glow on AI Recommendation card (NOT tech selection)
  var aiRecCard = document.getElementById('aiTechRecContainer');
  if (aiRecCard) aiRecCard = aiRecCard.closest('.card');
  if (aiRecCard) aiRecCard.classList.add('ai-processing');

  const catParts = [];
  if (state.productCategoryParent) catParts.push(state.productCategoryParent);
  if (state.productCategory) catParts.push(state.productCategory);
  const categoryHint = catParts.length ? catParts.join(' → ') : '-';

  // Domain detection
  var domain = 'generic';
  if (typeof getDomain === 'function') {
    var d = getDomain();
    if (d && d.primary) domain = d.primary;
  }

  try {
    const prompt = [
      'Kamu adalah tech lead yang bantu startup Indonesia pilih tech stack',
      'yang PALING COCOK berdasarkan konteks produk.',
      '',
      'Konteks:',
      '- Nama produk: "' + productName + '"',
      '- Kategori: ' + categoryHint,
      '- Domain: ' + domain,
      '- Tipe: ' + type,
      '- Ide: ' + (idea || '-'),
      '',
      'Tugas: Rekomendasi 4 layer tech stack + 1-2 extra features PALING RELEVAN.',
      '',
      'Aturan:',
      '- Rekomendasi harus populer di Indonesia dan cocok untuk tim kecil',
      '- Tiap layer: 1 rekomendasi utama (rec) + 1 alternatif (alt)',
      '- reason harus SPESIFIK, relate ke domain/tipe produk (jangan generik)',
      '- Extra features pilih dari: Payment, WhatsApp, Auth, Storage, AI, Export/Report, Map, Notification, Multi-language, Admin Panel',
      '- Pilih extras yg PALING KRUSIAL untuk domain ' + domain,
      '',
      'Contoh reason bagus: "Next.js cocok untuk ' + type + ' karena SEO built-in dan ekosistem React yg besar di Indonesia"',
      'Contoh reason jelek: "Next.js bagus" (terlalu generik)',
      '',
      'Output HANYA JSON (tanpa markdown):',
      '{',
      '  "frontend": { "rec": "React Native", "alt": "Flutter", "reason": "..." },',
      '  "backend": { "rec": "Node.js+Express", "alt": "Go+Fiber", "reason": "..." },',
      '  "database": { "rec": "PostgreSQL", "alt": "SQLite", "reason": "..." },',
      '  "deployment": { "rec": "Vercel+Supabase", "alt": "DigitalOcean", "reason": "..." },',
      '  "extras": [{ "name": "WhatsApp", "reason": "karena..." }]',
      '}'
    ].join('\n');

    const result = await callAI([
      { role: 'system', content: 'Kamu adalah asisten tech lead Indonesia. Return HANYA JSON, tanpa markdown atau teks lain.' },
      { role: 'user', content: prompt }
    ]);

    if (!result) throw new Error('No result');

    var jsonMatch = result.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error('No JSON found');

    var rec = JSON.parse(jsonMatch[0]);
    window._aiTechRec = rec;
    window._pendingTech = window._pendingTech || {};

    // Map AI display names to TECH_OPTIONS IDs
    function techNameToId(cat, name) {
      if (!name) return 'ai-pilih';
      var opts = TECH_OPTIONS[cat] || [];
      var n = (name || '').toLowerCase().trim();
      // Exact match first
      for (var i = 0; i < opts.length; i++) {
        if (opts[i][1].toLowerCase() === n || opts[i][0].toLowerCase() === n) return opts[i][0];
      }
      // Partial match for combined names like "Node.js + Express"
      for (var i = 0; i < opts.length; i++) {
        if (n.indexOf(opts[i][1].toLowerCase()) >= 0 || opts[i][1].toLowerCase().indexOf(n) >= 0) return opts[i][0];
      }
      return 'ai-pilih';
    }

    // Don't auto-fill — user chooses manually from accordion cards
    window._aiTechRecLoading = false;

    var sc = document.getElementById('techSubcards');
    if (sc && typeof renderTechSubcardsHTML === 'function') {
      sc.innerHTML = renderTechSubcardsHTML();
    }
    if (typeof renderExtras === 'function') renderExtras();
    // Update AI rec panel in separate card
    if (typeof renderAITechContainer === 'function') renderAITechContainer();

  } catch(e) {
    console.warn('AI tech recommendation failed:', e);
    // Set empty rec so UI shows manual picks instead of infinite loading
    window._aiTechRec = {};
    window._aiTechRecLoading = false;
    var sc = document.getElementById('techSubcards');
    if (sc && typeof renderTechSubcardsHTML === 'function') {
      sc.innerHTML = renderTechSubcardsHTML();
    }
    if (typeof renderAITechContainer === 'function') renderAITechContainer();
  }
  // Remove processing glow
  var tc = document.querySelector('#page-wizard .card');
  if (tc) tc.classList.remove('ai-processing');
}

//     Saved Provider Selection    


function previewAIExampleIdea(idx) {
  const ideas = window._aiIdeas;
  if (!ideas || !ideas[idx]) return;
  const idea = ideas[idx];

  var container = document.getElementById('wizExampleIdeas');
  if (!container) return;

  // Check if already showing this idea   toggle off
  var existing = container.querySelector('.idea-detail');
  if (existing && existing.dataset.idx === String(idx)) {
    existing.remove();
    return;
  }

  // Remove any previous detail
  if (existing) existing.remove();

  var detail = document.createElement('div');
  detail.className = 'idea-detail';
  detail.dataset.idx = String(idx);
  detail.style.cssText = 'width:100%;margin-top:8px;padding:12px 14px;background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);border-radius:10px';

  detail.innerHTML =
    '<div style="margin-bottom:8px">' +
    '<strong style="font-size:13px;color:#fff">' + escapeHtml(idea.title || '') + '</strong>' +
    '</div>' +
    '<p style="font-size:12px;line-height:1.5;color:rgba(255,255,255,0.6);margin:0 0 12px">' + escapeHtml(idea.desc || '') + '</p>' +
    '<div style="display:flex;gap:8px">' +
    '<button onclick="applyAIExampleIdea(' + idx + ')" style="padding:6px 16px;background:linear-gradient(135deg,#A855F7,#7C3AED);color:#fff;border:none;border-radius:8px;font-size:12px;font-weight:600;cursor:pointer">Pakai Ide Ini</button>' +
    '<button onclick="this.closest(\'.idea-detail\').remove()" style="padding:6px 16px;background:rgba(255,255,255,0.06);color:rgba(255,255,255,0.5);border:1px solid rgba(255,255,255,0.06);border-radius:8px;font-size:12px;cursor:pointer">Tutup</button>' +
    '</div>';

  container.appendChild(detail);
}

function applyAIExampleIdea(idx) {
  const ideas = window._aiIdeas;
  if (!ideas || !ideas[idx]) return;

  const idea = ideas[idx];
  const ideaText = document.getElementById('ideaText');
  const ideaPreview = document.getElementById('ideaPreview');

  if (ideaText) {
    ideaText.value = (idea.title || '') + '   ' + (idea.desc || '');
    if (typeof updateIdeaCounter === 'function') updateIdeaCounter();
  }
  if (ideaPreview) ideaPreview.textContent = ideaText?.value || '';
  showToast('Ide diterapkan!', 'success');
}


//     AI Tech Apply    
// ─── Helpers for combo tech names ───
function splitRecParts(rec) {
  if (!rec) return [];
  return rec.split(/[+,]/).map(function(s) { return s.trim(); }).filter(function(s) { return s; });
}
function recPartIds(cat, rec) {
  return splitRecParts(rec).map(function(p) { return techNameToId(cat, p); }).filter(function(id) { return id && id !== 'ai-pilih'; });
}

// Apply a single AI tech recommendation to a category
function applyAITechRec(cat) {
  var aiRec = window._aiTechRec;
  if (!aiRec || !aiRec[cat] || !aiRec[cat].rec) return;
  var ids = recPartIds(cat, aiRec[cat].rec);
  if (!ids.length) return;
  state.tech[cat] = ids.join(',');
  if (typeof saveState === 'function') saveState();
  var sc = document.getElementById('techSubcards');
  if (sc) sc.innerHTML = renderTechSubcardsHTML();
  if (typeof renderExtras === 'function') renderExtras();
  if (typeof renderAITechContainer === 'function') renderAITechContainer();
  showToast('Rekomendasi AI diterapkan untuk ' + cat, 'success');
}

// Apply ALL AI tech recommendations at once
function applyAllAITechRec() {
  var aiRec = window._aiTechRec;
  if (!aiRec) return;
  var cats = ['frontend', 'backend', 'database', 'deployment'];
  var count = 0;
  cats.forEach(function(cat) {
    if (aiRec[cat] && aiRec[cat].rec) {
      var ids = recPartIds(cat, aiRec[cat].rec);
      if (ids.length) {
        state.tech[cat] = ids.join(',');
        count++;
      }
    }
  });
  if (typeof saveState === 'function') saveState();
  var sc = document.getElementById('techSubcards');
  if (sc) sc.innerHTML = renderTechSubcardsHTML();
  if (typeof renderExtras === 'function') renderExtras();
  showToast(count + ' rekomendasi AI diterapkan!', 'success');
}

async function callAI(messages) {
  const { aiProvider: provider, aiModel: model, baseUrl } = state;
  const apiKey = KEY_STORE.get();

  // Ensure AI replies in Bahasa Indonesia
  const langInstruction = { role: 'system', content: 'Jawab dalam Bahasa Indonesia yang alami dan mudah dipahami. Gunakan istilah teknis Inggris jika diperlukan, tetapi penjelasan harus dalam Bahasa Indonesia.' };
  const messagesWithLang = [langInstruction, ...messages];

  try {
    const body = {
      messages: messagesWithLang,
      model: model,
      temperature: 0.7,
      max_tokens: 4096,
      config: {
        provider: provider,
        model: model,
        baseUrl: baseUrl,
      },
    };

    // Include apiKey if user has set one locally (overrides Worker's saved key)
    if (apiKey) {
      body.config.apiKey = apiKey;
    }

    const response = await fetch(WORKER_CHAT_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const err = await response.text();
      console.error('AI proxy error:', err);
      showToast('Gagal menghubungi AI. Cek konfigurasi.', 'error');
      return null;
    }

    const data = await response.json();
    return data.choices?.[0]?.message?.content || '';
  } catch (e) {
    console.error('AI call failed:', e);
    showToast('Gagal menghubungi AI server.', 'error');
    return null;
  }
}

//     Saved Provider Selection    


//     Provider List    
const PROVIDER_LIST = [
  { name: 'Nous Portal', type: 'openai', baseUrl: 'https://api.nousresearch.com/v1', models: ['claude-sonnet-4', 'claude-haiku-4', 'claude-opus-4', 'gpt-5.2', 'gpt-5.1', 'gpt-5', 'deepseek-v4', 'grok-4', 'gemini-3-pro', 'o5', 'gemini-3-flash', 'nova-micro'] },
  { name: 'OpenRouter', type: 'openrouter', baseUrl: 'https://openrouter.ai/api/v1', models: [] },
  { name: 'NovitaAI', type: 'openai', baseUrl: 'https://api.novita.ai/v3/openai', models: [] },
  { name: 'LM Studio', type: 'openai', baseUrl: 'http://localhost:1234/v1', models: [] },
  { name: 'Anthropic', type: 'anthropic', baseUrl: 'https://api.anthropic.com/v1', models: ['claude-sonnet-4', 'claude-haiku-4', 'claude-opus-4'] },
  { name: 'OpenAI', type: 'openai', baseUrl: 'https://api.openai.com/v1', models: ['gpt-5.2', 'gpt-5.1', 'gpt-5', 'o5', 'o4-mini'] },
  { name: 'Qwen Cloud', type: 'openai', baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1', models: ['qwen-max-2026', 'qwen-plus', 'qwen-turbo'] },
  { name: 'xAI Grok', type: 'openai', baseUrl: 'https://api.x.ai/v1', models: ['grok-4', 'grok-3', 'grok-3-mini'] },
  { name: 'Xiaomi MiMo', type: 'openai', baseUrl: 'https://api.mimo.xiaomi.net/v1', models: ['MiMo-V2.5-pro', 'MiMo-V2.5-omni', 'MiMo-V2.5-flash'] },
  { name: 'Tencent TokenHub', type: 'openai', baseUrl: 'https://tokenhub.tencentmaas.com/v1', models: ['hy3-preview'] },
  { name: 'NVIDIA NIM', type: 'openai', baseUrl: 'https://integrate.api.nvidia.com/v1', models: ['nemotron-4'] },
  { name: 'GitHub Copilot', type: 'openai', baseUrl: 'https://api.githubcopilot.com/v1', models: [] },
  { name: 'Hugging Face', type: 'openai', baseUrl: 'https://api-inference.huggingface.co/v1', models: [] },
  { name: 'Google Gemini', type: 'gemini', baseUrl: 'https://generativelanguage.googleapis.com/v1beta', models: ['gemini-3-pro', 'gemini-3-flash', 'gemini-3-pro-exp'] },
  { name: 'DeepSeek', type: 'openai', baseUrl: 'https://api.deepseek.com/v1', models: ['deepseek-v4', 'deepseek-v3', 'deepseek-r1', 'deepseek-coder'] },
  { name: 'Z.AI / GLM', type: 'openai', baseUrl: 'https://open.bigmodel.cn/api/paas/v4', models: ['glm-5.2', 'glm-5'] },
  { name: 'Kimi / Moonshot', type: 'openai', baseUrl: 'https://api.moonshot.cn/v1', models: ['moonshot-v4'] },
  { name: 'StepFun', type: 'openai', baseUrl: 'https://api.stepfun.com/v1', models: ['step-2'] },
  { name: 'MiniMax', type: 'openai', baseUrl: 'https://api.minimax.chat/v1', models: ['MiniMax-M2.5'] },
  { name: 'Ollama Cloud', type: 'openai', baseUrl: 'https://api.ollama.com/v1', models: [] },
  { name: 'Arcee AI', type: 'openai', baseUrl: 'https://api.arcee.ai/v1', models: ['arcee-trinity'] },
  { name: 'GMI Cloud', type: 'openai', baseUrl: 'https://api.gmicloud.ai/v1', models: [] },
  { name: 'Kilo Code', type: 'openai', baseUrl: 'https://api.kilocode.ai/v1', models: [] },
  { name: 'OpenCode', type: 'openai', baseUrl: 'https://api.opencode.ai/v1', models: [] },
  { name: 'AWS Bedrock', type: 'custom', baseUrl: 'https://bedrock-runtime.{region}.amazonaws.com', models: [] },
  { name: 'Azure Foundry', type: 'openai', baseUrl: 'https://models.inference.ai.azure.com', models: [] },
  { name: 'Alibaba Cloud', type: 'openai', baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1', models: [] },
  { name: 'Ai.sumopod.com', type: 'sumopod', baseUrl: 'https://ai.sumopod.com/v1', models: ['deepseek-v4-flash', 'deepseek-v3', 'deepseek-r1', 'glm-5.2'] },
  { name: 'Custom Endpoint', type: 'custom', baseUrl: '', models: [] },
];

// Saved providers from D1 (per-user), used to show "saved" indicators
let savedProviders = [];

//     Settings Modal (Provider Selector UI)    
let selectedProvider = null;



function renderSavedProvidersDropdown() {
  const select = document.getElementById('savedProviderSelect');
  if (!select) return;
  const currentVal = select.value;
  select.innerHTML = '<option value="">  Pilih provider tersimpan  </option>';

  // Also populate custom dropdown
  const customPanel = document.getElementById('savedProviderDropdown');
  if (customPanel) {
    customPanel.innerHTML = '<div class="custom-dropdown-item empty" data-value="">  Pilih provider tersimpan  </div>';
  }

  savedProviders.forEach((sp) => {
    const opt = document.createElement('option');
    opt.value = sp.name;
    const model = sp.models?.[0] || sp.model || '';
    const label = sp.name + (model ? '   ' + model : '');
    opt.textContent = label;
    select.appendChild(opt);

    // Add to custom dropdown
    if (customPanel) {
      var item = document.createElement('div');
      item.className = 'custom-dropdown-item' + (sp.name === currentVal ? ' selected' : '');
      item.setAttribute('data-value', sp.name);
      item.textContent = label;
      item.onclick = function() {
        select.value = sp.name;
        select.dispatchEvent(new Event('change'));
        // Update visual
        var display = document.getElementById('savedProviderDisplay');
        if (display) { display.textContent = label; }
        var trigger = document.getElementById('savedProviderTrigger');
        if (trigger) trigger.classList.add('has-value');
        // Close
        if (customPanel) { customPanel.classList.remove('open'); customPanel.parentElement.querySelector('.custom-select-trigger')?.classList.remove('open'); }
        if (typeof _customDropdownOpen !== 'undefined') _customDropdownOpen = null;
        customPanel.querySelectorAll('.custom-dropdown-item').forEach(function(el) { el.classList.remove('selected'); });
        item.classList.add('selected');
        // Populate hidden fields for simpanPengaturan
        var delBtn = document.getElementById('deleteProviderBtn');
        if (delBtn) delBtn.disabled = false;
        if (typeof savedProviders !== 'undefined') {
          var sp_found = savedProviders.find(function(p) { return p.name === select.value; });
          if (sp_found) {
            var hName = document.getElementById('selectedProviderName');
            var hUrl = document.getElementById('settingsBaseUrl');
            var hKey = document.getElementById('settingsApiKeyInput');
            var hModel = document.getElementById('settingsAiModel');
            if (hName) hName.textContent = sp_found.name;
            if (hUrl) hUrl.value = sp_found.base_url || sp_found.baseUrl || '';
            if (hKey) hKey.value = sp_found.api_key || sp_found.apiKey || '';
            if (hModel) {
              var modelVal = sp_found.models?.[0] || sp_found.model || '';
              if (modelVal) {
                var exists = false;
                for (var mi = 0; mi < hModel.options.length; mi++) {
                  if (hModel.options[mi].value === modelVal) { exists = true; break; }
                }
                if (!exists) {
                  var optM = document.createElement('option');
                  optM.value = modelVal;
                  optM.text = modelVal;
                  hModel.appendChild(optM);
                }
                hModel.value = modelVal;
              }
            }
          }
        }
      };
      customPanel.appendChild(item);
    }
  });

  if (currentVal) {
    select.value = currentVal;
    // Sync custom dropdown display
    var display = document.getElementById('savedProviderDisplay');
    var trigger = document.getElementById('savedProviderTrigger');
    var selectedOpt = select.options[select.selectedIndex];
    if (display && selectedOpt) { display.textContent = selectedOpt.textContent; }
    if (trigger && selectedOpt) trigger.classList.add('has-value');
    if (customPanel) {
      customPanel.querySelectorAll('.custom-dropdown-item').forEach(function(el) {
        el.classList.toggle('selected', el.getAttribute('data-value') === currentVal);
      });
    }
  }

  // Show/hide noConfigMsg vs hasConfigView
  var noConfig = document.getElementById('noConfigMsg');
  var hasConfig = document.getElementById('hasConfigView');
  if (noConfig && hasConfig) {
    var hasOptions = select.options.length > 1;
    noConfig.style.display = hasOptions ? 'none' : 'block';
    hasConfig.style.display = hasOptions ? 'block' : 'none';
  }

  // Enable delete button
  const delBtn = document.getElementById('deleteProviderBtn');
  if (delBtn) delBtn.disabled = !select.value;

  // onchange handler   populate hidden fields for simpanPengaturan
  select.onchange = function() {
    const delBtn = document.getElementById('deleteProviderBtn');
    if (delBtn) delBtn.disabled = !this.value;
    if (this.value && typeof savedProviders !== 'undefined') {
      var sp = savedProviders.find(function(p) { return p.name === select.value; });
      if (sp) {
        var hName = document.getElementById('selectedProviderName');
        var hUrl = document.getElementById('settingsBaseUrl');
        var hKey = document.getElementById('settingsApiKeyInput');
        var hModel = document.getElementById('settingsAiModel');
        if (hName) hName.textContent = sp.name;
        if (hUrl) hUrl.value = sp.base_url || sp.baseUrl || '';
        if (hKey) hKey.value = sp.api_key || sp.apiKey || '';
        if (hModel) {
          var modelVal = sp.models?.[0] || sp.model || '';
          if (modelVal) {
            var exists = false;
            for (var mi = 0; mi < hModel.options.length; mi++) {
              if (hModel.options[mi].value === modelVal) { exists = true; break; }
            }
            if (!exists) {
              var optM = document.createElement('option');
              optM.value = modelVal;
              optM.text = modelVal;
              hModel.appendChild(optM);
            }
            hModel.value = modelVal;
          }
        }
      }
    }
  };
}

function loadSavedProvider() {
  // Legacy   hidden fields populated by select.onchange above.
  // Kept as safe stub to prevent ReferenceError if called from old code paths.
}

//     Saved Provider Selection    


//     Hapus Provider (D1-centric)    
async function hapusProvider() {
  const select = document.getElementById('savedProviderSelect');
  const name = select.value;
  if (!name) { showToast('Pilih provider yang mau dihapus.', 'error'); return; }
  if (!confirm(`Hapus provider "${name}"?`)) return;
  
  try {
    const res = await fetch(API_URL + '/api/providers', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ name }),
    });
    if (!res.ok) { showToast('Gagal hapus provider.', 'error'); return; }
    
    // Reload dari D1
    await loadSavedProvidersFromD1();
    
    // Jika yang dihapus adalah active_provider → reset
    if (typeof state !== 'undefined' && state.aiProvider === name) {
      state.aiProvider = '';
      state.aiModel = '';
      KEY_STORE.clear();
      state.baseUrl = '';
      saveState();
    }
    
    showToast(`"${name}" dihapus.`, 'success');
  } catch(e) {
    showToast('Gagal hapus provider: ' + e.message, 'error');
  }
}

function selectProvider(idx) {
  const provider = PROVIDER_LIST[idx];
  selectedProvider = provider;

  // Update UI
  document.getElementById('selectedProviderName').textContent = provider.name;
  document.getElementById('settingsBaseUrl').value = provider.baseUrl;

  // Keep model select hidden until API key is verified
  const modelGroup = document.getElementById('settingsModelGroup');
  if (modelGroup) modelGroup.style.display = 'none';
  const modelSelect = document.getElementById('settingsAiModel');
  modelSelect.innerHTML = '<option value="">Pilih model...</option>';

  // Reset verify button state
  const verifyBtn = document.getElementById('verifyApiKeyBtn');
  const verifyLabel = document.getElementById('verifyBtnLabel');
  if (verifyBtn) verifyBtn.disabled = false;
  if (verifyLabel) verifyLabel.textContent = 'Verify';

  // Highlight selected in list
  document.querySelectorAll('.provider-item').forEach(el => el.classList.remove('selected'));
  const items = document.querySelectorAll('.provider-item');
  if (items[idx]) items[idx].classList.add('selected');

  // Update state
  if (typeof state !== 'undefined') {
    state.aiProvider = provider.name;
    state.aiModel = '';
    state.baseUrl = provider.baseUrl;
  }

  // Scroll to see details
  const config = document.getElementById('selectedProviderConfig');
  if (config) config.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}


function saveCustomProvider() {
  const name = document.getElementById('customProviderName').value.trim();
  const baseUrl = document.getElementById('customProviderBaseUrl').value.trim();
  const model = document.getElementById('customProviderModel').value.trim();
  const apiKey = document.getElementById('customProviderApiKey').value.trim();

  if (!name || !baseUrl) {
    showToast('Nama dan Base URL harus diisi', 'error');
    return;
  }

  // Add to list
  const customProvider = { name, type: 'custom', baseUrl, models: [model].filter(Boolean), apiKey };
  PROVIDER_LIST.push(customProvider);

  if (typeof state !== 'undefined') {
    state.aiProvider = name;
    state.aiModel = model;
    state.baseUrl = baseUrl;
    KEY_STORE.set(apiKey);
    saveState();
  }

  renderSavedProvidersDropdown();
  showToast(`Provider "${name}" ditambahkan`, 'success');
}

function openSettings() {
  if (typeof state !== 'undefined' && !state.user) {
    showToast('Silakan login terlebih dahulu.', 'error');
    return;
  }
  var modal = document.getElementById('settingsModal');
  if (!modal) return;
  if (typeof loadSavedProvidersFromD1 === 'function') loadSavedProvidersFromD1();
  // Reset to initial view
  var initial = document.getElementById('settingsInitialView');
  var addSection = document.getElementById('addProviderSection');
  if (initial) initial.style.display = 'block';
  if (addSection) addSection.style.display = 'none';
  modal.classList.add('open');
}

function setAIAccessMode(mode) {
  if (!state) return;
  state.aiAccessMode = mode;
  saveState();
  if (typeof updateAIAccessModeUI === 'function') updateAIAccessModeUI();
  showToast(
    mode === 'byok' ? 'Mode BYOK aktif.' : mode === 'subscription' ? 'Mode subscription aktif.' : 'Mode pay as you go aktif.',
    'success'
  );
}

function updateAIAccessModeUI() {
  const modes = document.querySelectorAll('[data-ai-access-mode]');
  modes.forEach(el => {
    el.classList.toggle('selected', el.dataset.aiAccessMode === (state.aiAccessMode || 'byok'));
  });
}

function closeSettings() {
  var modal = document.getElementById('settingsModal');
  if (modal) modal.classList.remove('open');
  selectedProvider = null;
  // Reset to initial view
  var initial = document.getElementById('settingsInitialView');
  var addSection = document.getElementById('addProviderSection');
  if (initial) initial.style.display = 'block';
  if (addSection) addSection.style.display = 'none';
  if (typeof updateAIConfigUI === 'function') updateAIConfigUI();
}

//     Add Provider Form    


function hideAddProviderForm() {
  const form = document.getElementById('addProviderForm');
  const btn = document.getElementById('addProviderBtn');
  if (form) form.style.display = 'none';
  if (btn) btn.style.display = '';
  selectedProvider = null;
}

async function saveNewProvider() {
  const providerName = document.getElementById('selectedProviderName')?.textContent || selectedProvider?.name || 'Provider';
  const providerType = selectedProvider?.type || 'custom';
  const model = document.getElementById('settingsAiModel')?.value;
  const apiKey = document.getElementById('settingsApiKeyInput')?.value || '';
  const baseUrl = document.getElementById('settingsBaseUrl')?.value || '';
  
  if (!providerName) { showToast('Pilih provider terlebih dahulu.', 'error'); return; }
  if (!apiKey) { showToast('Masukkan API Key.', 'error'); return; }
  
  try {
    const res = await fetch(API_URL + '/api/providers', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({
        name: providerName,
        type: providerType,
        apiKey: apiKey,
        baseUrl: baseUrl || selectedProvider?.baseUrl || '',
        models: model ? [model] : [],
      }),
    });
    const data = await res.json();
    if (data.success) {
      showToast(`Provider "${providerName}" tersimpan!`, 'success');
      hideAddProviderForm();
      loadSavedProvidersFromD1();
      // Update state
      if (typeof state !== 'undefined') {
        state.aiProvider = providerName;
        state.aiModel = model || '';
        state.baseUrl = baseUrl || selectedProvider?.baseUrl || '';
        KEY_STORE.set(apiKey);
        saveState();
      }
    } else {
      showToast('Gagal simpan: ' + (data.error || 'Unknown'), 'error');
    }
  } catch (e) {
    showToast('Gagal simpan provider.', 'error');
  }
}

//     Saved Provider Selection    


//     Load Saved Providers from D1    
async function loadSavedProvidersFromD1() {
  try {
    const res = await fetch(API_URL + '/api/providers', {
      credentials: 'include',
    });
    const data = await res.json();
    if (Array.isArray(data.providers)) {
      savedProviders = data.providers;
    }
  } catch (e) {
    console.warn('Failed to load saved providers:', e);
  }
  renderSavedProvidersDropdown();
}

//     Delete Saved Provider from D1    
async function deleteSavedProviderFromDropdown() {
  const select = document.getElementById('savedProviderSelect');
  const name = select.value;
  if (!name) { showToast('Pilih provider yang mau dihapus.', 'error'); return; }
  if (!confirm(`Hapus provider "${name}"?`)) return;
  
  try {
    const res = await fetch(API_URL + '/api/providers', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ name: name }),
    });
    const data = await res.json();
    if (data.success) {
      showToast(`"${name}" dihapus.`, 'success');
      loadSavedProvidersFromD1();
    } else {
      showToast('Gagal hapus: ' + (data.error || 'Unknown'), 'error');
    }
  } catch (e) {
    showToast('Gagal hapus provider.', 'error');
  }
}

//     Saved Provider Selection    


function saveSettings() {
  const providerName = document.getElementById('selectedProviderName')?.textContent;
  const model = document.getElementById('settingsAiModel')?.value;
  const apiKey = document.getElementById('settingsApiKeyInput')?.value || '';
  const baseUrl = document.getElementById('settingsBaseUrl')?.value || '';

  if (!providerName || providerName === '...') {
    showToast('Pilih provider terlebih dahulu', 'error');
    return;
  }

  if (!model) {
    showToast('Pilih model terlebih dahulu', 'error');
    return;
  }

  // Update state
  if (typeof state !== 'undefined') {
    state.aiProvider = providerName;
    state.aiModel = model;
    state.baseUrl = baseUrl;
    KEY_STORE.set(apiKey);
    saveState();
  }

  closeSettings();

  // Save to Worker D1 for persistence across sessions
  if (typeof saveAIConfigToWorker === 'function') {
    saveAIConfigToWorker({
      provider: providerName,
      model: model,
      apiKey: apiKey || undefined,
      baseUrl: baseUrl || undefined,
    });
  }

  // Add to saved providers list
  const spKey = providerName + '|' + (model || 'default');
  if (!savedProviders.some(sp => sp.key === spKey)) {
    const provider = PROVIDER_LIST.find(p => p.name === providerName);
    savedProviders.push({
      key: spKey,
      name: providerName,
      model: model || '',
      type: provider?.type || 'custom',
      baseUrl: baseUrl || provider?.baseUrl || '',
      apiKey: apiKey || '',
    });
  } else {
    // Update existing entry
    const idx = savedProviders.findIndex(sp => sp.key === spKey);
    if (idx >= 0) {
      savedProviders[idx].apiKey = apiKey || savedProviders[idx].apiKey;
      savedProviders[idx].baseUrl = baseUrl || savedProviders[idx].baseUrl;
    }
  }

  renderSavedProvidersDropdown();
  renderProviderList();

  showToast(`AI: ${model} via ${providerName}`, 'success');
}

//     Delete saved provider from D1    
async function deleteSavedProvider(name) {
  if (!name) return;
  if (!confirm(`Hapus konfigurasi provider "${name}"?`)) return;

  try {
    const res = await fetch(AUTH_BASE + '/api/providers', {
      method: 'DELETE',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name }),
    });
    if (!res.ok) {
      const err = await res.json();
      showToast(err.error || 'Gagal menghapus provider', 'error');
      return;
    }
    // Remove from local savedProviders list
    savedProviders = savedProviders.filter(sp => sp.name !== name);
    // If this was the active provider, clear it from state
    if (typeof state !== 'undefined' && state.aiProvider === name) {
      state.aiProvider = null;
      state.aiModel = null;
      KEY_STORE.clear();
      persistAIConfig();
    }
    renderSavedProvidersDropdown();
    showToast(`Provider "${name}" dihapus`, 'success');
  } catch (e) {
    showToast('Gagal menghapus provider', 'error');
  }
}

//     Saved Provider Selection    


function toggleApiKeyVisibility() {
  const inp = document.getElementById('settingsApiKeyInput');
  if (inp) inp.type = inp.type === 'password' ? 'text' : 'password';
}

async function verifyApiKey() {
  const providerName = document.getElementById('selectedProviderName')?.textContent;
  const apiKey = document.getElementById('settingsApiKeyInput')?.value?.trim();
  const baseUrl = document.getElementById('settingsBaseUrl')?.value?.trim();
  const verifyBtn = document.getElementById('verifyApiKeyBtn');
  const verifyLabel = document.getElementById('verifyBtnLabel');

  if (!providerName || providerName === '...') {
    showToast('Pilih provider terlebih dahulu', 'error');
    return;
  }

  if (!apiKey) {
    showToast('Masukkan API Key terlebih dahulu', 'error');
    return;
  }

  if (!baseUrl) {
    showToast('Base URL tidak tersedia untuk provider ini', 'error');
    return;
  }

  // Find provider type
  const provider = PROVIDER_LIST.find(p => p.name === providerName);
  const type = provider?.type || 'custom';

  // Loading state
  if (verifyBtn) verifyBtn.disabled = true;
  if (verifyLabel) verifyLabel.textContent = 'Verifying...';

  try {
    const res = await fetch(AUTH_BASE + '/api/verify-key', {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ type, baseUrl, apiKey }),
    });

    const data = await res.json();

    if (!res.ok || data.error) {
      showToast(data.error || 'API Key tidak valid', 'error');
      if (verifyBtn) verifyBtn.disabled = false;
      if (verifyLabel) verifyLabel.textContent = 'Verify';
      return;
    }

    // Success   populate model dropdown
    const modelSelect = document.getElementById('settingsAiModel');
    const modelGroup = document.getElementById('settingsModelGroup');

    if (modelSelect) {
      modelSelect.innerHTML = '<option value="">Pilih model...</option>';
      if (data.models && Array.isArray(data.models)) {
        data.models.forEach(m => {
          const opt = document.createElement('option');
          opt.value = m;
          opt.textContent = m;
          modelSelect.appendChild(opt);
        });
      }
    }

    if (modelGroup) modelGroup.style.display = 'block';
    if (verifyLabel) verifyLabel.textContent = 'Verified';

    showToast('API Key valid! ' + (data.models?.length || 0) + ' model ditemukan.', 'success');
  } catch (e) {
    showToast('Gagal terhubung ke server. Coba lagi.', 'error');
    if (verifyBtn) verifyBtn.disabled = false;
    if (verifyLabel) verifyLabel.textContent = 'Verify';
  }
}

//     Saved Provider Selection    


//     Utils    
function escapeHtml(str) {
  if (typeof str !== 'string') return '';
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function debounce(fn, delay) {
  let timer;
  return function (...args) {
    clearTimeout(timer);
    timer = setTimeout(() => fn.apply(this, args), delay);
  };
}

//     Theme (subtle – ensures body class matches mode)    
function applyTheme() {
  document.body.dataset.mode = state.mode;
}

//     Project History (persisted via D1)    

const HISTORY_API = API_URL + '/api/history';

// Save current project to history
async function saveProjectToHistory() {
  try {
    const project = {
      id: state._projectId || (Date.now().toString(36) + Math.random().toString(36).slice(2, 6)),
      name: state.productName || document.getElementById('productName')?.value || 'Untitled',
      model: state.aiModel || '',
      tech: { ...state.tech },
      extras: [...state.extras],
      artifacts: JSON.parse(JSON.stringify(state.artifacts)),
      versions: JSON.parse(JSON.stringify(state.versions)),
      currentArtifact: state.currentArtifact,
      currentVersion: state.currentVersion,
      chatHistory: [...state.chatHistory],
      createdAt: new Date().toISOString(),
    };
    state._projectId = project.id;

    await fetch(HISTORY_API, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(project),
    });
    showToast('Project disimpan!', 'success');
  } catch {
    showToast('Gagal menyimpan project.', 'error');
  }
}

//     Saved Provider Selection    


// Load all saved projects
async function loadProjectHistory() {
  try {
    const res = await fetch(HISTORY_API, { credentials: 'include', cache: 'no-store' });
    if (!res.ok) return [];
    return await res.json();
  } catch(e) {
    console.warn('Failed to load history:', e);
    return [];
  }
}

//     Saved Provider Selection    


// Continue a project from history
async function continueProject(id) {
  const history = await loadProjectHistory();
  const project = history.find(p => p.id === id);
  if (!project) {
    showToast('Project tidak ditemukan.', 'error');
    return;
  }

  state._projectId = project.id;
  state.productName = project.name;
  state.tech = { ...project.tech };
  state.extras = [...project.extras];
  state.artifacts = JSON.parse(JSON.stringify(project.artifacts));
  state.versions = JSON.parse(JSON.stringify(project.versions));
  state.currentArtifact = project.currentArtifact || 0;
  state.currentVersion = project.currentVersion || 0;
  state.chatHistory = [...(project.chatHistory || [])];
  state.idea = '';
  state.answers = {};
  state.step = 1;

  saveState();
  navigateTo('result');
}

// Delete a project from history
async function deleteProject(id) {
  if (!confirm('Hapus project ini dari riwayat?')) return;
  try {
    await fetch(HISTORY_API, {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ id }),
    });
    if (typeof renderHistoryPanel === 'function') renderHistoryPanel();
    showToast('Project dihapus dari riwayat.', 'success');
  } catch(e) { showToast('Gagal menghapus project', 'error'); }
}

// ╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀
// NEW: History Panel (right slide-in)
// ╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀

function toggleHistory() {
  const panel = document.getElementById('historyPanel');
  const overlay = document.getElementById('historyPanelOverlay');
  if (!panel || !overlay) return;
  const isVisible = panel.style.display !== 'none';
  panel.style.display = isVisible ? 'none' : 'block';
  overlay.style.display = isVisible ? 'none' : 'block';
  if (!isVisible) {
    renderHistoryPanel();
  }
}

async function renderHistoryPanel() {
  const list = document.getElementById('historyPanelList');
  if (!list) return;
  try {
    const history = await loadProjectHistory();
    if (!history || history.length === 0) {
      list.innerHTML = '<div style="padding:32px;text-align:center;font-size:13px;color:var(--muted-dim);">Belum ada project tersimpan.</div>';
      return;
    }
    list.innerHTML = history.slice(0, 50).map(p => {
      const date = new Date(p.createdAt).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' });
      const model = p.model || '';
      const vCount = p.versions ? p.versions.length : 0;
      return `<div class="history-panel-item" onclick="continueProjectHistory('${p.id}')">
        <div class="history-panel-item-name">${escapeHtml(p.name || 'Untitled')}</div>
        <div class="history-panel-item-meta">
          ${model ? '<span>' + escapeHtml(model) + '</span>' : ''}
          <span>${vCount} versi</span>
          <span>${date}</span>
        </div>
        <button class="history-panel-item-del" onclick="event.stopPropagation();deleteProject('${p.id}')" title="Hapus">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
        </button>
      </div>`;
    }).join('');
  } catch(e) {
    list.innerHTML = '<div style="padding:32px;text-align:center;font-size:13px;color:var(--muted-dim);">Gagal memuat riwayat.</div>';
  }
}

// ╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀
// NEW: Result Page Tabs (Overview, Artifacts, Documents, Visual, Export)
// ╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀

// Track current result tab
let currentResultTab = 'overview';

function switchResultTab(tab) {
  currentResultTab = tab;
  // Update tab bar active state
  document.querySelectorAll('#resultTabs .result-tab-item').forEach(el => {
    el.classList.toggle('active', el.dataset.tab === tab);
  });
  // Show/hide tab content
  const tabs = ['overview', 'artifacts', 'documents', 'visual', 'export'];
  tabs.forEach(t => {
    const el = document.getElementById('resultTab' + t.charAt(0).toUpperCase() + t.slice(1));
    if (el) el.style.display = t === tab ? 'block' : 'none';
  });
  // Initialize tab content
  if (tab === 'overview') { renderResultOverview(); renderBusinessDNACard(); }
  if (tab === 'documents') renderDocumentsTab();
  if (tab === 'visual') renderVisualTab();
  if (tab === 'export') renderExportTab();
}

function renderResultOverview() {
  const container = document.getElementById('resultTabOverview');
  if (!container) return;

  const engineDomain = window.engineArtifacts && window.engineArtifacts.domain;
  const engineArch = window.engineArtifacts && window.engineArtifacts.architecture;
  const engineModule = window.engineArtifacts && window.engineArtifacts.modules;
  const engineRel = window.engineArtifacts && window.engineArtifacts.relations;
  const engineSec = window.engineArtifacts && window.engineArtifacts.security;
  const engineVal = window.engineArtifacts && window.engineArtifacts.validation;
  const engineFlows = window.engineArtifacts && window.engineArtifacts.uiFlows;
  const engineSM = window.engineArtifacts && window.engineArtifacts.stateMachine;

  if (!engineDomain) {
    container.innerHTML =
      '<div class="result-empty">' +
        '<div class="result-empty-icon">' + iconSvg('target', 32) + '</div>' +
        '<div class="result-empty-title">Belum Ada Analisis Engine</div>' +
        '<div class="result-empty-desc">Generate blueprint dulu dari wizard untuk melihat hasil analisis.</div>' +
        '<button class="btn-primary" onclick="navigate(\'wizard\')" style="margin-top:16px;border:none">' +
          iconSvg('zap', 14) + ' Buka Wizard' +
        '</button>' +
      '</div>';
    return;
  }

  //     DATA    
  const productName = state.productName || 'Blueprint';
  const domainName = engineDomain.domainName || engineDomain.primaryDomain || 'Unknown';
  const confidence = engineDomain.confidence || 0;
  const confidencePct = (confidence * 100).toFixed(0);
  const secondaryDomains = engineDomain.secondaryDomains || [];
  const actors = engineDomain.actors || [];
  const entities = engineDomain.entities || [];
  const entityCount = entities.length;

  let relCount = 0;
  const relations = (engineRel && engineRel.relations) || [];
  relations.forEach(function(r) {
    if (r.relations) {
      if (r.relations.belongsTo) relCount += r.relations.belongsTo.length;
      if (r.relations.hasMany) relCount += r.relations.hasMany.length;
      if (r.relations.hasOne) relCount += r.relations.hasOne.length;
    }
  });

  const modules = (engineModule && engineModule.modules) || [];
  const moduleCount = modules.length;
  const depCount = modules.reduce(function(sum, m) { return sum + (m.dependencies ? m.dependencies.length : 0); }, 0);
  const roleCount = engineSec && engineSec.roles ? engineSec.roles.length : 0;
  const stateMachines = (engineSM && engineSM.stateMachines) || [];
  const events = (window.engineArtifacts && window.engineArtifacts.events && window.engineArtifacts.events.events) || [];
  const journeys = (engineFlows && engineFlows.journeys) || [];
  const policies = (engineSec && engineSec.policies) || [];
  const fieldRules = (engineVal && engineVal.fieldRules) || [];
  const services = engineArch ? (engineArch.services || engineArch.serviceCount || 0) : 0;

  const archPattern = engineArch ? engineArch.pattern : ' ';
  const archLayers = engineArch && engineArch.layers ? engineArch.layers.join(', ') : ' ';
  const archReasoning = engineArch ? engineArch.reasoning : '';
  const authType = engineSec ? engineSec.authType : '';
  const mfa = engineSec ? engineSec.mfa : '';
  const roles = (engineSec && engineSec.roles) || [];

  const stagger = function(i) { return 'style="animation-delay:' + (0.10 + i * 0.06) + 's"'; };
  function tag(t, c) { return '<span class="' + c + '">' + escapeHtml(t) + '</span>'; }
  function ovIcon(n) { return '<div class="ov-icon">' + iconSvg(n, 16) + '</div>'; }

  //     BUILD HTML    
  var html = '';

  // ╀╀╀ HERO SECTION ╀╀╀
  html += '<div class="result-hero">' +
    '<div class="result-hero-inner">' +
      '<div class="result-hero-top">' +
        '<div class="result-hero-badges">' +
          '<span class="result-domain-badge">' + escapeHtml(domainName) + '</span>' +
          (secondaryDomains.length ? '<span class="result-domain-badge result-domain-secondary">+' + secondaryDomains.length + '</span>' : '') +
          '<span class="result-version-badge">v1.0</span>' +
        '</div>' +
        '<div class="result-hero-actions">' +
          '<button class="hero-action-btn" onclick="downloadAllMarkdown()" title="Download All">' + iconSvg('download', 14) + '</button>' +
          '<button class="hero-action-btn" onclick="downloadAllJson()" title="Download JSON">' + iconSvg('code', 14) + '</button>' +
          '<button class="hero-action-btn" onclick="window.print()" title="Print">' + iconSvg('file', 14) + '</button>' +
        '</div>' +
      '</div>' +
      '<div class="result-hero-title-row">' +
        '<div class="result-hero-icon">' + iconSvg('box', 28) + '</div>' +
        '<div class="result-hero-info">' +
          '<h1 class="result-hero-title">' + escapeHtml(productName) + '</h1>' +
          '<p class="result-hero-subtitle">' + escapeHtml(domainName) + ' • ' + entityCount + ' entitas • ' + moduleCount + ' modul</p>' +
        '</div>' +
      '</div>' +
      '<div class="result-hero-meta">' +
        '<div class="result-hero-meta-item">' + ovIcon('users') + '<span class="rhm-label">Aktor</span><span class="rhm-value">' + (actors.length ? escapeHtml(actors.join(', ')) : ' ') + '</span></div>' +
        (secondaryDomains.length ? '<div class="result-hero-meta-item">' + ovIcon('layers') + '<span class="rhm-label">Sekunder</span><span class="rhm-value">' + escapeHtml(secondaryDomains.join(', ')) + '</span></div>' : '') +
      '</div>' +
      '<div class="result-hero-confidence">' +
        '<div class="result-hero-confidence-label">' +
          '<span>Domain Confidence</span>' +
          '<span class="result-hero-confidence-value">' + confidencePct + '%</span>' +
        '</div>' +
        '<div class="result-hero-confidence-bar">' +
          '<div class="result-hero-confidence-fill" style="width:' + confidencePct + '%;background:linear-gradient(90deg,' + (confidence > 0.7 ? 'var(--accent)' : confidence > 0.4 ? '#F59E0B' : '#EF4444') + ',var(--accent))"></div>' +
        '</div>' +
      '</div>' +
    '</div>' +
  '</div>';

  // ╀╀╀ STATS DASHBOARD ╀╀╀
  var stats = [
    { icon: 'database', label: 'Entitas', value: entityCount, accent: '#A855F7' },
    { icon: 'share2', label: 'Relasi', value: relCount, accent: '#22C55E' },
    { icon: 'grid', label: 'Modul', value: moduleCount, accent: '#3B82F6' },
    { icon: 'lock', label: 'Role', value: roleCount, accent: '#F59E0B' },
    { icon: 'server', label: 'Layanan', value: services, accent: '#00E08F' },
    { icon: 'activity', label: 'Event', value: events.length, accent: '#EC4899' },
  ];

  html += '<div class="stats-bar">';
  stats.forEach(function(s, i) {
    var rawHtml = '<div class="stat-premium result-stagger-' + (i + 1) + '" ' + stagger(i) + ' style="--stat-accent:' + s.accent + '">' +
      '<div class="stat-premium-inner">' +
        '<div class="stat-premium-icon">' + iconSvg(s.icon, 18) + '</div>' +
        '<div class="stat-premium-value">' + s.value + '</div>' +
        '<div class="stat-premium-label">' + s.label + '</div>' +
        '<div class="stat-premium-bar"><div class="stat-premium-fill" style="width:' + Math.min(100, Math.max(5, s.value * 8)) + '%;background:' + s.accent + '"></div></div>' +
      '</div>' +
    '</div>';
    html += rawHtml;
  });
  html += '</div>';

  // ╀╀╀ INSIGHT GRID (Architecture, Security, Lifecycle, Events) ╀╀╀
  html += '<div class="section-title-premium"><span class="stp-label"><span class="stp-deco"></span>Analysis Insights<span class="stp-deco"></span></span></div>';
  html += '<div class="insight-grid">';

  // Architecture
  html += '<div class="insight-card" style="--insight-accent:#A855F7" ' + stagger(6) + '>' +
    '<div class="insight-header"><div class="insight-header-icon" style="background:rgba(168,85,247,0.12)">' + iconSvg('layers', 16) + '</div><span class="insight-header-label">Arsitektur</span></div>' +
    '<div class="insight-body">' +
      '<div class="insight-row"><span class="insight-row-label">Pola</span><span class="insight-tag">' + escapeHtml(archPattern) + '</span></div>' +
      '<div class="insight-row"><span class="insight-row-label">Lapisan</span><span class="insight-row-value">' + escapeHtml(archLayers) + '</span></div>' +
      '<div class="insight-row"><span class="insight-row-label">Layanan</span><span class="insight-row-value">' + services + '</span></div>' +
      '<div class="insight-score-bar"><div class="insight-score-fill" style="width:' + Math.min(100, services * 15 + 20) + '%"></div></div>' +
      (archReasoning ? '<div class="insight-reason">' + escapeHtml(archReasoning) + '</div>' : '') +
    '</div>' +
  '</div>';

  // Security
  html += '<div class="insight-card" style="--insight-accent:#3B82F6" ' + stagger(7) + '>' +
    '<div class="insight-header"><div class="insight-header-icon" style="background:rgba(59,130,246,0.12)">' + iconSvg('shield', 16) + '</div><span class="insight-header-label">Keamanan</span></div>' +
    '<div class="insight-body">' +
      '<div class="insight-row"><span class="insight-row-label">Autentikasi</span><span class="insight-tag">' + escapeHtml(authType || ' ') + '</span></div>' +
      '<div class="insight-row"><span class="insight-row-label">MFA</span><span class="insight-tag">' + escapeHtml(mfa || ' ') + '</span></div>' +
      (roles.length ? '<div class="insight-row"><span class="insight-row-label">Roles</span><span class="insight-row-value">' + roles.map(function(r) { return escapeHtml(r.name); }).join(', ') + '</span></div>' : '') +
      '<div class="insight-row" style="flex-wrap:wrap;gap:4px">' +
        (policies.length ? policies.slice(0, 4).map(function(p) {
          return '<span class="ov-chip">' + escapeHtml(p.module) + '</span>';
        }).join('') : '<span class="insight-row-value" style="color:var(--muted-dim)">Tidak ada kebijakan</span>') +
        (policies.length > 4 ? '<span class="ov-chip" style="opacity:0.5">+' + (policies.length - 4) + '</span>' : '') +
      '</div>' +
    '</div>' +
  '</div>';

  // Lifecycle / State Machines
  html += '<div class="insight-card" style="--insight-accent:#22C55E" ' + stagger(8) + '>' +
    '<div class="insight-header"><div class="insight-header-icon" style="background:rgba(34,197,94,0.12)">' + iconSvg('refreshCw', 16) + '</div><span class="insight-header-label">Siklus Hidup</span></div>' +
    '<div class="insight-body">';
  if (stateMachines.length) {
    stateMachines.slice(0, 3).forEach(function(sm) {
      html += '<div class="flow-track">' +
        '<div class="flow-track-label">' + escapeHtml(sm.entity) + '</div>' +
        '<div class="flow-track-steps">';
      sm.states.forEach(function(s, i) {
        var isTerminal = sm.terminalStates && sm.terminalStates.indexOf(s) >= 0;
        var dotColor = isTerminal ? '#22C55E' : i === 0 ? '#3B82F6' : '#F59E0B';
        html += '<div class="flow-step' + (i === 0 ? ' active' : '') + (isTerminal ? ' completed' : '') + '">' +
          '<div class="flow-step-dot" style="background:' + dotColor + '"></div>' +
          '<div class="flow-step-label">' + escapeHtml(s) + '</div>' +
        '</div>';
        if (i < sm.states.length - 1) html += '<div class="flow-step-line"></div>';
      });
      html += '</div></div>';
    });
    if (stateMachines.length > 3) html += '<div class="insight-more">+' + (stateMachines.length - 3) + ' lagi</div>';
  } else {
    html += '<div style="color:var(--muted-dim);font-size:12px;padding:8px 0">Tidak ada data siklus hidup</div>';
  }
  html += '</div></div>';

  // Events
  html += '<div class="insight-card" style="--insight-accent:#EC4899" ' + stagger(9) + '>' +
    '<div class="insight-header"><div class="insight-header-icon" style="background:rgba(236,72,153,0.12)">' + iconSvg('activity', 16) + '</div><span class="insight-header-label">Event' + (events.length ? ' <span style="font-weight:400;opacity:0.6">(' + events.length + ')</span>' : '') + '</span></div>' +
    '<div class="insight-body">';
  if (events.length) {
    // Sort by category if available, just show as badge cloud
    html += '<div style="display:flex;flex-wrap:wrap;gap:4px">';
    events.slice(0, 12).forEach(function(ev) {
      var name = ev.name || ev.event || ev;
      var cat = ev.category || '';
      html += '<span class="ov-chip ov-chip-event">' + escapeHtml(name) + (cat ? '<span style="opacity:0.5;margin-left:3px;font-size:9px">' + cat + '</span>' : '') + '</span>';
    });
    if (events.length > 12) html += '<span style="font-size:10px;color:var(--muted-dim);padding:4px 8px">+' + (events.length - 12) + ' more</span>';
    html += '</div>';
  } else {
    html += '<div style="color:var(--muted-dim);font-size:12px;padding:8px 0">Tidak ada data event</div>';
  }
  html += '</div></div>';

  html += '</div>'; // end insight-grid

  // ╀╀╀ UI FLOWS ╀╀╀
  if (journeys.length) {
    html += '<div class="section-title-premium"><span class="stp-label"><span class="stp-deco"></span>User Flow<span class="stp-deco"></span></span></div>';
    html += '<div class="insight-grid">';
    journeys.slice(0, 4).forEach(function(j, ji) {
      var steps = j.steps || j.pages || [];
      html += '<div class="insight-card" style="--insight-accent:#F59E0B" ' + stagger(10 + ji) + '>' +
        '<div class="insight-header"><div class="insight-header-icon" style="background:rgba(245,158,11,0.12)">' + iconSvg('eye', 16) + '</div><span class="insight-header-label">' + escapeHtml(j.actor || j.name || j.role || 'User') + '</span></div>' +
        '<div class="insight-body">' +
        '<div class="flow-visualizer">';
      steps.slice(0, 6).forEach(function(s, si) {
        var label = typeof s === 'string' ? s : (s.action || s.name || s.description || '');
        var pageName = s.page || '';
        html += '<div class="flow-step">' +
          '<div class="flow-step-dot" style="background:#F59E0B' + (si === 0 ? '' : ';opacity:0.4') + '"></div>' +
          '<div class="flow-step-label">' + escapeHtml(label) + '</div>' +
          (pageName ? '<div class="flow-step-desc">' + escapeHtml(pageName) + '</div>' : '') +
        '</div>';
        if (si < steps.length - 1 && si < 5) html += '<div class="flow-step-line" style="background:rgba(245,158,11,0.2)"></div>';
      });
      if (steps.length > 6) html += '<div style="font-size:10px;color:var(--muted-dim);margin-top:4px">+' + (steps.length - 6) + ' more steps</div>';
      html += '</div></div></div>';
    });
    html += '</div>';
  }

  // ╀╀╀ TECH STACK ╀╀╀
  html += '<div class="section-title-premium"><span class="stp-label"><span class="stp-deco"></span>Tech Stack<span class="stp-deco"></span></span></div>';
  var techData = [
    { cat: 'frontend', label: 'Frontend', icon: 'monitor', accent: '#3B82F6' },
    { cat: 'backend', label: 'Backend', icon: 'server', accent: '#22C55E' },
    { cat: 'database', label: 'Database', icon: 'database', accent: '#F59E0B' },
    { cat: 'deployment', label: 'Deployment', icon: 'upload', accent: '#A855F7' },
  ];
  html += '<div class="tech-stack-grid">';
  techData.forEach(function(td, ti) {
    var techVal = state.tech && state.tech[td.cat];
    var techName = techVal && techVal !== 'ai-pilih' ? getTechLabel(td.cat) : 'AI pilihkan';
    var aiRec = window._aiTechRec && window._aiTechRec[td.cat];
    var reason = aiRec && aiRec.reason ? aiRec.reason : '';
    html += '<div class="tech-layer-card" style="--tech-accent:' + td.accent + '" ' + stagger(14 + ti) + '>' +
      '<div class="tech-layer-header">' +
        '<div class="tech-layer-icon" style="color:' + td.accent + '">' + iconSvg(td.icon, 16) + '</div>' +
        '<span class="tech-layer-label">' + td.label + '</span>' +
      '</div>' +
      '<div class="tech-layer-value">' + escapeHtml(techName) + '</div>' +
      (reason ? '<div class="tech-layer-reason" title="' + escapeHtml(reason) + '">' + escapeHtml(reason.substring(0, 60)) + (reason.length > 60 ? '...' : '') + '</div>' : '') +
    '</div>';
  });
  html += '</div>';

  // ╀╀╀ ENTITIES ╀╀╀
  if (entities.length) {
    html += '<div class="section-title-premium"><span class="stp-label"><span class="stp-deco"></span>Entities <span style="font-weight:400;font-size:11px;opacity:0.5">(' + entityCount + ')</span><span class="stp-deco"></span></span></div>';
    html += '<div class="entity-grid">';
    entities.forEach(function(e, ei) {
      var fieldCount = (e.fields || []).length;
      var rels = e.relations || {};
      var relCountEnt = (rels.belongsTo || []).length + (rels.hasMany || []).length + (rels.hasOne || []).length;
      var typeColors = { User: '#3B82F6', Order: '#22C55E', Payment: '#F59E0B', Product: '#A855F7', default: '#6B7280' };
      var accent = typeColors[e.name] || typeColors.default;
      html += '<div class="entity-card" style="--entity-accent:' + accent + '" ' + stagger(18 + ei) + '>' +
        '<div class="entity-card-header">' +
          '<div class="entity-card-icon" style="background:rgba(' + (accent === '#3B82F6' ? '59,130,246' : accent === '#22C55E' ? '34,197,94' : accent === '#F59E0B' ? '245,158,11' : '168,85,247') + ',0.12)">' + iconSvg('database', 14) + '</div>' +
          '<div class="entity-card-info">' +
            '<div class="entity-card-name">' + escapeHtml(e.name) + '</div>' +
            '<div class="entity-card-type">' + escapeHtml(e.entityType || 'Entity') + '</div>' +
          '</div>' +
          '<span class="entity-card-badge">' + fieldCount + ' fields</span>' +
        '</div>' +
        '<div class="entity-card-stats">' +
          '<div class="entity-card-stat"><span class="ecs-value">' + fieldCount + '</span><span class="ecs-label">Fields</span></div>' +
          '<div class="entity-card-stat"><span class="ecs-value">' + relCountEnt + '</span><span class="ecs-label">Relations</span></div>' +
          '<div class="entity-card-stat"><span class="ecs-value">' + (e.indexes || []).length + '</span><span class="ecs-label">Indexes</span></div>' +
        '</div>' +
        '<div class="entity-card-fields">' +
          (e.fields || []).slice(0, 4).map(function(f) {
            return '<span class="entity-field-tag"><span class="eft-name">' + escapeHtml(f.name) + '</span><span class="eft-type">' + escapeHtml(f.type || 'string') + '</span></span>';
          }).join('') +
          (fieldCount > 4 ? '<span class="entity-field-more">+' + (fieldCount - 4) + '</span>' : '') +
        '</div>' +
      '</div>';
    });
    html += '</div>';
  }

  // ╀╀╀ MODULES ╀╀╀
  if (modules.length) {
    html += '<div class="section-title-premium"><span class="stp-label"><span class="stp-deco"></span>Modules <span style="font-weight:400;font-size:11px;opacity:0.5">(' + moduleCount + ')</span><span class="stp-deco"></span></span></div>';
    html += '<div class="module-grid">';
    modules.forEach(function(m, mi) {
      var status = m.dependencies && m.dependencies.length ? 'complete' : 'planned';
      html += '<div class="module-card" ' + stagger(22 + mi) + '>' +
        '<div class="module-card-header">' +
          '<span class="module-card-name">' + escapeHtml(m.name) + '</span>' +
          '<span class="module-card-badge module-badge-' + status + '">' + status + '</span>' +
        '</div>' +
        '<div class="module-card-entities">' +
          (m.entities || []).map(function(en) { return '<span class="module-entity-tag">' + escapeHtml(en) + '</span>'; }).join('') +
        '</div>' +
        '<div class="module-card-caps">' +
          (m.capabilities || []).slice(0, 3).map(function(cap) { return '<span class="module-cap-tag">' + escapeHtml(cap) + '</span>'; }).join('') +
          ((m.capabilities || []).length > 3 ? '<span class="module-cap-tag" style="opacity:0.5">+' + ((m.capabilities || []).length - 3) + '</span>' : '') +
        '</div>' +
        (m.dependencies && m.dependencies.length ? '<div class="module-card-deps">Depends on: ' + m.dependencies.map(function(d) { return '<span class="module-dep-tag">' + escapeHtml(d) + '</span>'; }).join('') + '</div>' : '') +
      '</div>';
    });
    html += '</div>';
  }

  // ╀╀╀ VALIDATION RULES ╀╀╀
  if (fieldRules.length) {
    html += '<div class="section-title-premium"><span class="stp-label"><span class="stp-deco"></span>Validation Rules <span style="font-weight:400;font-size:11px;opacity:0.5">(' + fieldRules.length + ')</span><span class="stp-deco"></span></span></div>';
    html += '<div class="insight-card" style="--insight-accent:#F59E0B" ' + stagger(26) + '>' +
      '<div class="insight-body">';
    fieldRules.slice(0, 10).forEach(function(rule) {
      var summary = (rule.rules || []).map(function(r) {
        if (r.type === 'pattern') return 'pattern';
        if (r.type === 'min') return 'min:' + r.value;
        if (r.type === 'max') return 'max:' + r.value;
        if (r.type === 'required') return 'required';
        return r.type || r.message || '';
      }).join(', ');
      html += '<div class="validation-row">' +
        '<span class="validation-row-field"><span class="ov-chip" style="background:rgba(255,255,255,0.04)">' + escapeHtml(rule.entity || '') + '</span>.' + escapeHtml(rule.field || '') + '</span>' +
        '<span class="validation-row-rules">' + escapeHtml(summary) + '</span>' +
      '</div>';
    });
    if (fieldRules.length > 10) html += '<div style="font-size:10px;color:var(--muted-dim);padding-top:8px;text-align:center">+' + (fieldRules.length - 10) + ' more rules</div>';
    html += '</div></div>';
  }

  // ╀╀╀ DOWNLOADS ╀╀╀
  html += '<div class="section-title-premium"><span class="stp-label"><span class="stp-deco"></span>Downloads<span class="stp-deco"></span></span></div>';
  html += '<div class="download-grid">';

  var downloads = [
    { icon: 'fileText', label: 'Dokumen PRD', desc: 'Markdown   product requirements document', color: '#22C55E', action: 'downloadWorkspace()' },
    { icon: 'code', label: 'JSON Engine', desc: 'JSON   full engine analysis data', color: '#3B82F6', action: 'downloadAllJson()' },
    { icon: 'fileText', label: 'All Markdown', desc: 'Gabungan semua dokumen', color: '#A855F7', action: 'downloadAllMarkdown()' },
    { icon: 'messageCircle', label: 'Revisi dengan AI', desc: 'Tanya atau minta perubahan', color: '#00E08F', action: 'openRevisionChat()' },
  ];
  downloads.forEach(function(d, di) {
    html += '<div class="download-card" ' + stagger(28 + di) + '>' +
      '<div class="download-card-icon" style="background:rgba(' + (d.color === '#22C55E' ? '34,197,94' : d.color === '#3B82F6' ? '59,130,246' : d.color === '#A855F7' ? '168,85,247' : '0,224,143') + ',0.10);color:' + d.color + '">' + iconSvg(d.icon, 22) + '</div>' +
      '<div class="download-card-info">' +
        '<div class="download-card-title">' + d.label + '</div>' +
        '<div class="download-card-desc">' + d.desc + '</div>' +
      '</div>' +
      '<button class="download-card-btn" onclick="' + d.action + '" style="color:' + d.color + ';border-color:' + d.color + '40;background:rgba(' + (d.color === '#22C55E' ? '34,197,94' : d.color === '#3B82F6' ? '59,130,246' : d.color === '#A855F7' ? '168,85,247' : '0,224,143') + ',0.08)">' + iconSvg('download', 14) + '</button>' +
    '</div>';
  });
  html += '</div>';

  container.innerHTML = html;
}



function renderDocumentsTab() {
  const container = document.getElementById('resultTabDocuments');
  if (!container) return;

  const docIds = [
    { id: 'prd', label: 'PRD', desc: 'Product Requirements Document', icon: 'fileText' },
    { id: 'readme', label: 'README', desc: 'Project overview & quick start', icon: 'fileText' },
    { id: 'prompt', label: 'Prompt', desc: 'AI coding handoff prompt', icon: 'bot' },
  ];

  const hasAny = docIds.some(d => state.artifacts.some(a => a.id === d.id));
  if (!hasAny) {
    container.innerHTML = '<p style="color:var(--muted-dim);text-align:center;padding:40px 0;font-size:14px;">No documents generated yet. Generate a blueprint first.</p>';
    return;
  }

  const productName = state.productName || 'blueprint';
  let html = '<div class="documents-grid">';

  docIds.forEach(doc => {
    const artifact = state.artifacts.find(a => a.id === doc.id);
    if (!artifact) return;
    const filename = productName + '-' + doc.id + '.md';
    html += `<div class="document-card">
      <div class="document-card-header">
        <span class="document-card-icon">${doc.icon}</span>
        <div class="document-card-info">
          <div class="document-card-name">${doc.label}</div>
          <div class="document-card-desc">${doc.desc}</div>
        </div>
      </div>
      <div class="document-card-preview">${renderMarkdown(artifact.content.substring(0, 600))}</div>
      <div class="document-card-actions">
        <button class="action-btn action-primary" onclick="downloadFile(state.artifacts.find(a=>a.id==='${doc.id}').content,'${filename}','text/markdown');showToast('Downloaded ${doc.label}','success')">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
          Download
        </button>
        <button class="action-btn" onclick="navigator.clipboard.writeText(state.artifacts.find(a=>a.id==='${doc.id}').content).then(()=>showToast('Copied ${doc.label}!','success'))">
          Copy
        </button>
      </div>
    </div>`;
  });

  html += '</div>';
  container.innerHTML = html;
}

function renderVisualTab() {
  const container = document.getElementById('resultTabVisual');
  if (!container) return;

  const engineDomain = window.engineArtifacts && window.engineArtifacts.domain;
  const engineArch = window.engineArtifacts && window.engineArtifacts.architecture;
  const engineRel = window.engineArtifacts && window.engineArtifacts.relations;
  const engineSM = window.engineArtifacts && window.engineArtifacts.stateMachine;
  const engineFlows = window.engineArtifacts && window.engineArtifacts.uiFlows;

  if (!engineDomain) {
    container.innerHTML = '<div class="result-empty"><div class="result-empty-icon">' + iconSvg('eye', 32) + '</div><div class="result-empty-title">Belum ada data visual</div><div class="result-empty-desc">Generate blueprint dulu.</div></div>';
    return;
  }

  const entities = engineDomain.entities || [];
  const relations = (engineRel && engineRel.relations) || [];
  const stateMachines = (engineSM && engineSM.stateMachines) || [];
  const journeys = (engineFlows && engineFlows.journeys) || [];

  var html = '<div class="result-page">';

  //    Entity Relationship Map   
  html += '<div class="section-title-premium"><span class="stp-label"><span class="stp-deco"></span>Entity Relationship Map<span class="stp-deco"></span></span></div>';
  html += '<div class="insight-card" style="--insight-accent:#A855F7">';
  html += '<div class="insight-body" style="padding:16px">';

  // Build simple text-based ER diagram
  relations.forEach(function(r) {
    html += '<div class="er-entity-group">';
    html += '<div class="er-entity-name" style="font-size:13px;font-weight:700;color:var(--text);margin-bottom:8px;padding:6px 10px;background:rgba(168,85,247,0.08);border-radius:8px;border-left:3px solid #A855F7">' + escapeHtml(r.entity) + '</div>';
    var rels = r.relations || {};
    ['belongsTo', 'hasMany', 'hasOne'].forEach(function(type) {
      var items = rels[type] || [];
      items.forEach(function(item) {
        var arrow = type === 'belongsTo' ? '(belongsTo)' : type === 'hasMany' ? '→ hasMany' : '  hasOne →';
        html += '<div class="er-relation-row" style="display:flex;align-items:center;gap:8px;padding:4px 12px;font-size:12px;color:var(--text-muted)">';
        html += '<span style="flex:1;font-weight:500;color:var(--text)">' + escapeHtml(r.entity) + '</span>';
        html += '<span class="er-arrow" style="color:' + (type === 'belongsTo' ? '#3B82F6' : type === 'hasMany' ? '#22C55E' : '#F59E0B') + ';font-size:11px">' + arrow + '</span>';
        html += '<span style="flex:1;font-weight:500;color:var(--text)">' + escapeHtml(item.to || item.entity || '') + '</span>';
        if (item.cardinality) html += '<span class="ov-chip" style="font-size:9px">' + item.cardinality + '</span>';
        html += '</div>';
      });
    });
    html += '</div>';
  });

  if (!relations.length && entities.length) {
    html += '<div style="color:var(--muted-dim);font-size:12px">' + entities.length + ' entitas terdeteksi, tidak ada relasi.</div>';
  } else if (!relations.length) {
    html += '<div style="color:var(--muted-dim);font-size:12px">Tidak ada data relasi.</div>';
  }
  html += '</div></div>';

  //    State Machine Visuals   
  if (stateMachines.length) {
    html += '<div class="section-title-premium" style="margin-top:24px"><span class="stp-label"><span class="stp-deco"></span>State Machines<span class="stp-deco"></span></span></div>';
    html += '<div class="insight-grid">';
    stateMachines.slice(0, 6).forEach(function(sm) {
      html += '<div class="insight-card" style="--insight-accent:#22C55E">';
      html += '<div class="insight-header"><div class="insight-header-icon" style="background:rgba(34,197,94,0.12)">' + iconSvg('refreshCw', 16) + '</div><span class="insight-header-label">' + escapeHtml(sm.entity) + '</span></div>';
      html += '<div class="insight-body"><div class="flow-visualizer">';
      sm.states.forEach(function(s, i) {
        var isTerminal = sm.terminalStates && sm.terminalStates.indexOf(s) >= 0;
        var dotColor = isTerminal ? '#22C55E' : i === 0 ? '#3B82F6' : '#F59E0B';
        html += '<div class="flow-step"><div class="flow-step-dot" style="background:' + dotColor + '"></div><div class="flow-step-label">' + escapeHtml(s) + '</div></div>';
        if (i < sm.states.length - 1) html += '<div class="flow-step-line"></div>';
      });
      html += '</div></div></div>';
    });
    html += '</div>';
  }

  //    User Flow Journeys   
  if (journeys.length) {
    html += '<div class="section-title-premium" style="margin-top:24px"><span class="stp-label"><span class="stp-deco"></span>User Journeys<span class="stp-deco"></span></span></div>';
    html += '<div class="insight-grid">';
    journeys.slice(0, 4).forEach(function(j) {
      var steps = j.steps || j.pages || [];
      var actor = j.actor || j.name || j.role || 'User';
      html += '<div class="insight-card" style="--insight-accent:#F59E0B">';
      html += '<div class="insight-header"><div class="insight-header-icon" style="background:rgba(245,158,11,0.12)">' + iconSvg('eye', 16) + '</div><span class="insight-header-label">' + escapeHtml(actor) + '</span></div>';
      html += '<div class="insight-body"><div class="flow-visualizer">';
      steps.slice(0, 8).forEach(function(s, si) {
        var label = typeof s === 'string' ? s : (s.action || s.name || s.description || '');
        html += '<div class="flow-step"><div class="flow-step-dot"></div><div class="flow-step-label">' + escapeHtml(label) + '</div></div>';
        if (si < steps.length - 1 && si < 7) html += '<div class="flow-step-line"></div>';
      });
      if (steps.length > 8) html += '<div style="font-size:10px;color:var(--muted-dim)">+' + (steps.length - 8) + ' more</div>';
      html += '</div></div></div>';
    });
    html += '</div>';
  }

  html += '</div>';
  container.innerHTML = html;
}

function renderExportTab() {
  const container = document.getElementById('resultTabExport');
  if (!container) return;

  const hasArtifacts = state.artifacts && state.artifacts.length > 0;
  if (!hasArtifacts) {
    container.innerHTML = '<div class="result-empty"><div class="result-empty-icon">' + iconSvg('download', 32) + '</div><div class="result-empty-title">Belum ada data</div><div class="result-empty-desc">Generate blueprint dulu untuk mengekspor.</div></div>';
    return;
  }

  var html = '<div class="result-page">';
  html += '<div class="section-title-premium"><span class="stp-label"><span class="stp-deco"></span>Export Options<span class="stp-deco"></span></span></div>';
  html += '<div class="download-grid">';

  var exports = [
    { icon: 'fileText', label: 'Full Workspace (.md)', desc: 'Semua dokumen + prompt dalam satu file markdown', color: '#22C55E', action: 'downloadAllMarkdown()' },
    { icon: 'code', label: 'Engine Data (.json)', desc: 'Semua analisis engine dalam format JSON', color: '#3B82F6', action: 'downloadAllJson()' },
    { icon: 'file', label: 'PRD Document', desc: 'Product Requirements Document (.md)', color: '#A855F7', action: "downloadFile(state.artifacts.find(a=>a.id==='prd').content, (state.productName||'blueprint')+'-prd.md', 'text/markdown');showToast('Downloaded PRD','success')" },
    { icon: 'file', label: 'README', desc: 'Project overview (.md)', color: '#F59E0B', action: "downloadFile(state.artifacts.find(a=>a.id==='readme').content, (state.productName||'blueprint')+'-readme.md', 'text/markdown');showToast('Downloaded README','success')" },
    { icon: 'bot', label: 'AI Prompt', desc: 'Coding handoff prompt (.md)', color: '#EC4899', action: "downloadFile(state.artifacts.find(a=>a.id==='prompt').content, (state.productName||'blueprint')+'-prompt.md', 'text/markdown');showToast('Downloaded Prompt','success')" },
    { icon: 'copy', label: 'Copy All to Clipboard', desc: 'Copy semua konten artifacts ke clipboard', color: '#00E08F', action: 'copyAllArtifacts()' },
  ];

  exports.forEach(function(ex) {
    var rgba = ex.color === '#22C55E' ? '34,197,94' : ex.color === '#3B82F6' ? '59,130,246' : ex.color === '#A855F7' ? '168,85,247' : ex.color === '#F59E0B' ? '245,158,11' : ex.color === '#EC4899' ? '236,72,153' : '0,224,143';
    html += '<div class="download-card">' +
      '<div class="download-card-icon" style="background:rgba(' + rgba + ',0.10);color:' + ex.color + '">' + iconSvg(ex.icon, 22) + '</div>' +
      '<div class="download-card-info">' +
        '<div class="download-card-title">' + ex.label + '</div>' +
        '<div class="download-card-desc">' + ex.desc + '</div>' +
      '</div>' +
      '<button class="download-card-btn" onclick="' + ex.action + '" style="color:' + ex.color + ';border-color:' + ex.color + '40;background:rgba(' + rgba + ',0.08)">' + iconSvg('download', 14) + '</button>' +
    '</div>';
  });

  html += '</div>';

  //    Version History   
  if (state.versions && state.versions.length > 0) {
    html += '<div class="section-title-premium" style="margin-top:24px"><span class="stp-label"><span class="stp-deco"></span>Version History<span class="stp-deco"></span></span></div>';
    html += '<div class="insight-card" style="--insight-accent:#3B82F6"><div class="insight-body"><div style="display:flex;gap:8px;flex-wrap:wrap">';
    state.versions.forEach(function(v, i) {
      var active = i === state.currentVersion ? ' style="background:var(--accent);color:#000;border-color:var(--accent)"' : '';
      html += '<span class="version-btn' + (i === state.currentVersion ? ' active' : '') + '" onclick="switchVersion(' + i + ')"' + active + '>' + v.version + '</span>';
    });
    html += '</div><div style="font-size:11px;color:var(--muted-dim);margin-top:8px">Klik versi untuk melihat artifact sebelumnya.</div></div></div>';
  }

  html += '</div>';
  container.innerHTML = html;
}

function copyAllArtifacts() {
  var text = state.artifacts.map(function(a) { return '=== ' + a.label + ' ===\n' + a.content; }).join('\n\n---\n\n');
  navigator.clipboard.writeText(text).then(function() {
    showToast('Copied all artifacts!', 'success');
  });
}

// ╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀
// NEW: Export Functions
// ╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀

function downloadAllZip() {
  downloadAll();
}

function downloadAllMarkdown() {
  const name = state.productName || 'blueprint';
  const parts = state.artifacts
    .filter(a => a.ext === 'md' || a.id === 'prd' || a.id === 'readme' || a.id === 'prompt')
    .map(a => `# ${a.label}\n\n${a.content}`);
  const combined = parts.join('\n\n---\n\n');
  if (!combined) {
    showToast('No markdown artifacts available.', 'error');
    return;
  }
  downloadFile(combined, `${name}-all-markdown.md`, 'text/markdown');
  showToast('Downloaded all markdown!', 'success');
}

function downloadAllJson() {
  const name = state.productName || 'blueprint';
  const engineArts = {};
  state.artifacts.filter(a => a.id.startsWith('engine-')).forEach(a => {
    try {
      engineArts[a.id.replace('engine-', '')] = JSON.parse(a.content);
    } catch(e) {
      engineArts[a.id.replace('engine-', '')] = a.content;
    }
  });
  const jsonContent = JSON.stringify(engineArts, null, 2);
  downloadFile(jsonContent, `${name}-engine-data.json`, 'application/json');
  showToast('Downloaded engine data as JSON!', 'success');
}

function downloadWorkspace() {
  const name = (state.productName || 'blueprint').replace(/[^a-z0-9]/gi, '_').toLowerCase();
  // Collect all non-engine artifacts (docs + prompt)
  const promptArts = state.artifacts.filter(a => a.ext === 'md' && !a.id.startsWith('engine-'));
  const engineArts = state.artifacts.filter(a => a.id.startsWith('engine-'));

  const parts = [];
  // Header
  parts.push('# PRDKit Workspace: ' + (state.productName || 'Untitled'));
  parts.push('> Generated: ' + new Date().toISOString().split('T')[0]);
  parts.push('> Domain: ' + ((window.engineArtifacts && window.engineArtifacts.domain) ? window.engineArtifacts.domain.primaryDomain : ' '));
  parts.push('');
  parts.push('---');
  parts.push('');

  // All markdown files
  promptArts.forEach(a => {
    parts.push('# ' + a.label);
    parts.push('');
    parts.push(a.content);
    parts.push('');
    parts.push('---');
    parts.push('');
  });

  // Engine JSON files
  parts.push('# Engine Artifacts');
  parts.push('');
  parts.push('Gunakan bagian ini untuk tool coding seperti Codex, Claude Code, atau Cursor bila kamu ingin output terstruktur dan minim revisi.');
  parts.push('');
  engineArts.forEach(a => {
    parts.push('## ' + a.label);
    parts.push('');
    parts.push('```json');
    parts.push(a.content);
    parts.push('```');
    parts.push('');
  });

  const content = parts.join('\n');
  downloadFile(content, name + '-workspace.md', 'text/markdown');
  showToast('Workspace downloaded!', 'success');
}

function copyPromptToClipboard() {
  const promptArtifact = state.artifacts.find(a => a.id === 'prompt');
  if (!promptArtifact) {
    showToast('No prompt artifact available.', 'error');
    return;
  }
  navigator.clipboard.writeText(promptArtifact.content).then(() => {
    showToast('Prompt copied to clipboard!', 'success');
  }).catch(() => {
    showToast('Failed to copy.', 'error');
  });
}

//     Provider Radio List (Hermes CLI Style)    
function renderProviderRadioList(filter) {
  const container = document.getElementById('providerRadioList');
  if (!container) return;
  
  const providers = PROVIDER_LIST.filter(p => {
    if (!filter) return true;
    const q = filter.toLowerCase();
    return p.name.toLowerCase().includes(q);
  });
  
  container.innerHTML = providers.map((p, idx) => {
    const selected = selectedProvider && selectedProvider.name === p.name;
    return `<div class="provider-radio-item${selected ? ' selected' : ''}" onclick="selectProviderRadio(${idx})">
      <div class="radio-circle"></div>
      <div class="radio-text">
        <div class="radio-name">${p.name}</div>
      </div>
    </div>`;
  }).join('');
}

//     Select Provider Radio    
function selectProviderRadio(idx) {
  const provider = PROVIDER_LIST[idx];
  if (!provider) return;
  selectedProvider = provider;
  
  // Re-render list to show selection
  const searchInput = document.getElementById('providerSearchInput');
  renderProviderRadioList(searchInput ? searchInput.value : '');
  
  // Enable continue button
  const btn = document.getElementById('continueBtn');
  if (btn) btn.disabled = false;
}

//     Filter Provider List    
function filterProviderList(value) {
  renderProviderRadioList(value);
}

//     Open Provider Selector    
function openProviderSelector() {
  const initialView = document.getElementById('settingsInitialView');
  const addSection = document.getElementById('addProviderSection');
  if (initialView) initialView.style.display = 'none';
  if (addSection) addSection.style.display = 'block';
  
  // Reset state
  selectedProvider = null;
  document.getElementById('providerDetailStep').style.display = 'none';
  document.getElementById('providerSelectorStep').style.display = 'block';
  document.getElementById('continueBtn').disabled = true;
  
  // Render provider list
  renderProviderRadioList('');
  
  // Focus search
  const searchInput = document.getElementById('providerSearchInput');
  if (searchInput) setTimeout(() => searchInput.focus(), 100);
}

//     Cancel Add Provider    
function cancelAddProvider() {
  const initialView = document.getElementById('settingsInitialView');
  const addSection = document.getElementById('addProviderSection');
  if (initialView) initialView.style.display = 'block';
  if (addSection) addSection.style.display = 'none';
  selectedProvider = null;
}

//     Continue to Detail Form    
function continueToDetailForm() {
  if (selectedProvider) {
    document.getElementById('detailBaseUrl').value = selectedProvider.baseUrl || '';
    var icons = {'anthropic':'🤖','openai':'🟢','openrouter':'🀀','gemini':'🀵','sumopod':'⚡'};
    document.getElementById('detailProviderIcon').textContent = icons[selectedProvider.type] || '🀌';
    document.getElementById('detailProviderDesc').textContent = (selectedProvider.type || 'custom') + ' · verify API Key untuk lihat model';
  }
  syncDetailToHidden();
  document.getElementById('providerSelectorStep').style.display = 'none';
  document.getElementById('providerDetailStep').style.display = 'block';
  document.getElementById('modelSelectionStep').style.display = 'none';
  // Back button: from Step 2 go to Step 1
  document.getElementById('addProviderBackBtn').onclick = function() {
    document.getElementById('providerDetailStep').style.display = 'none';
    document.getElementById('providerSelectorStep').style.display = 'block';
    document.getElementById('addProviderBackBtn').onclick = cancelAddProvider;
    document.getElementById('addProviderStepTitle').textContent = 'Tambah Provider';
  };
  document.getElementById('addProviderStepTitle').textContent = 'Detail Provider';
}

function syncDetailToHidden() {
  var hApiKey = document.getElementById('settingsApiKeyInput');
  var hBaseUrl = document.getElementById('settingsBaseUrl');
  if (hBaseUrl) hBaseUrl.value = document.getElementById('detailBaseUrl').value;
  if (hApiKey) hApiKey.value = document.getElementById('detailApiKey').value;
}

function backToDetailForm() {
  document.getElementById('modelSelectionStep').style.display = 'none';
  document.getElementById('providerDetailStep').style.display = 'block';
  document.getElementById('addProviderBackBtn').onclick = function() {
    document.getElementById('providerDetailStep').style.display = 'none';
    document.getElementById('providerSelectorStep').style.display = 'block';
    document.getElementById('addProviderBackBtn').onclick = cancelAddProvider;
    document.getElementById('addProviderStepTitle').textContent = 'Tambah Provider';
  };
  document.getElementById('addProviderStepTitle').textContent = 'Detail Provider';
}

//     Toggle API Key Visibility    
function toggleDetailApiKey() {
  const input = document.getElementById('detailApiKey');
  if (input) input.type = input.type === 'password' ? 'text' : 'password';
}

//     Verify API Key (Detail Form)    
async function detailVerifyKey() {
  var apiKey = document.getElementById('detailApiKey').value.trim();
  var baseUrl = document.getElementById('detailBaseUrl').value.trim();
  if (!apiKey) { showToast('Masukkan API Key dulu.', 'error'); return; }
  if (!baseUrl) { showToast('Base URL belum diisi.', 'error'); return; }

  var type = (typeof selectedProvider !== 'undefined' && selectedProvider) ? (selectedProvider.type || 'openai') : 'openai';
  var verifyBtn = document.getElementById('detailVerifyBtn');
  var verifyLabel = document.getElementById('detailVerifyLabel');
  if (verifyLabel) verifyLabel.textContent = 'Verifying...';
  if (verifyBtn) verifyBtn.disabled = true;
  var detailModelGroup = document.getElementById('detailModelGroup');
  if (detailModelGroup) detailModelGroup.style.display = 'none';

  try {
    var API_BASE = typeof API_URL !== 'undefined' ? API_URL : 'https://prdkit-ai-proxy.halugoods-indonesia.workers.dev';
    var res = await fetch(API_BASE + '/api/verify-key', {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ type: type, baseUrl: baseUrl, apiKey: apiKey }),
    });
    var data = await res.json();

    if (!res.ok || data.error || !data.success) {
      if (verifyLabel) verifyLabel.textContent = 'Verify';
      if (verifyBtn) verifyBtn.disabled = false;
      showToast(data.error || 'API Key tidak valid.', 'error');
      return;
    }

    // Success   populate model dropdown (native + custom)
    var dModel = document.getElementById('detailModelSelect');
    var models = data.models || [];
    var modelsToUse = models.length > 0 ? models : ((typeof selectedProvider !== 'undefined' && selectedProvider) ? (selectedProvider.defaultModels || selectedProvider.models || []) : []);
    if (dModel) {
      dModel.innerHTML = '<option value="">Pilih model...</option>';
      modelsToUse.forEach(function(m) {
        var opt = document.createElement('option');
        opt.value = m;
        opt.textContent = m;
        dModel.appendChild(opt);
      });
    }
    // Populate custom model dropdown + sync native select
    if (typeof populateCustomDropdown === 'function' && document.getElementById('detailModelDropdown')) {
      var modelItems = [{value:'', label:'Pilih model...'}];
      modelsToUse.forEach(function(m) { modelItems.push({value:m, label:m}); });
      populateCustomDropdown('detailModelDropdown', modelItems, '', 'detailModelTrigger', 'detailModelDisplay', function(val) {
        var hModel = document.getElementById('settingsAiModel');
        if (hModel) {
          hModel.innerHTML = '';
          var opt = document.createElement('option');
          opt.value = val;
          opt.textContent = val;
          hModel.appendChild(opt);
          hModel.value = val;
        }
        if (dModel) dModel.value = val;
      });
    }

    // Auto-advance ke Step 3: Pilih Model
    var provName = document.getElementById('detailProviderName');
    document.getElementById('verifiedProviderName').textContent = provName ? provName.textContent : ' ';
    document.getElementById('providerDetailStep').style.display = 'none';
    document.getElementById('modelSelectionStep').style.display = 'block';
    // Back button: from Step 3 go to Step 2
    document.getElementById('addProviderBackBtn').onclick = backToDetailForm;
    document.getElementById('addProviderStepTitle').textContent = 'Pilih Model';
    // Show valid state on verify button
    if (verifyLabel) { verifyLabel.textContent = 'Valid'; }
    if (verifyBtn) { verifyBtn.disabled = false; verifyBtn.classList.remove('btn-accent-soft'); verifyBtn.classList.add('btn-success'); verifyBtn.style.pointerEvents = 'none'; }
    showToast('API Key valid! ' + models.length + ' model ditemukan.', 'success');
  } catch (e) {
    if (verifyLabel) verifyLabel.textContent = 'Verify';
    if (verifyBtn) verifyBtn.disabled = false;
    showToast('Gagal verifikasi: ' + e.message, 'error');
  }
}

//     Toggle API Key Visibility    
function toggleDetailApiKey() {
  var inp = document.getElementById('detailApiKey');
  if (inp) inp.type = inp.type === 'password' ? 'text' : 'password';
}

//     Simpan Provider (Add new to D1)    
function simpanProvider() {
  // Sync ALL detail values to hidden fields for app.js saveNewProvider
  syncDetailToHidden();
  var dModel = document.getElementById('detailModelSelect');
  var hModel = document.getElementById('settingsAiModel');
  if (dModel && hModel) {
    hModel.innerHTML = '';
    for (var i = 0; i < dModel.options.length; i++) {
      var opt = document.createElement('option');
      opt.value = dModel.options[i].value;
      opt.text = dModel.options[i].text;
      hModel.appendChild(opt);
    }
    hModel.value = dModel.value;
    // Set display name: alias > provider name
    var alias = document.getElementById('detailAlias').value.trim();
    var hName = document.getElementById('selectedProviderName');
    if (hName) {
      hName.textContent = alias || (document.getElementById('detailProviderName')?.textContent || 'Provider');
    }
  }
  if (typeof saveNewProvider === 'function') {
    saveNewProvider();
    cancelAddProvider();
  } else {
    showToast('Fungsi simpan belum tersedia', 'error');
  }
}

//     Simpan Pengaturan (Set active provider from D1)    
async function simpanPengaturan() {
  console.log('[PRDKit] simpanPengaturan v2 (D1 direct)');
  var select = document.getElementById('savedProviderSelect');
  var name = select ? select.value : '';
  if (!name) { showToast('Pilih provider dari daftar.', 'error'); return; }

  try {
    var API_BASE = typeof API_URL !== 'undefined' ? API_URL : 'https://prdkit-ai-proxy.halugoodsindonesia.workers.dev';
    var res = await fetch(API_BASE + '/api/providers', { credentials: 'include' });
    var data = await res.json();
    var providers = data.providers || [];
    var sp = providers.find(function(p) { return p.name === name; });
    if (!sp) {
      showToast('Provider tidak ditemukan di database.', 'error');
      return;
    }

    // Extract model
    var model = '';
    if (sp.models && Array.isArray(sp.models) && sp.models.length > 0) {
      model = sp.models[0];
    } else if (sp.model) {
      model = sp.model;
    }
    if (!model) {
      showToast('Model tidak ditemukan untuk provider ini. Verify dulu ya.', 'error');
      return;
    }

    // Sync ke hidden DOM
    var hModel = document.getElementById('settingsAiModel');
    if (hModel) {
      hModel.innerHTML = '<option value="">Pilih model...</option>';
      var opt = document.createElement('option');
      opt.value = model; opt.text = model;
      hModel.appendChild(opt);
      hModel.value = model;
    }

    // Populate hidden fields
    var hName = document.getElementById('selectedProviderName');
    var hUrl = document.getElementById('settingsBaseUrl');
    var hKey = document.getElementById('settingsApiKeyInput');
    if (hName) hName.textContent = sp.name;
    if (hUrl) hUrl.value = sp.baseUrl || sp.base_url || '';
    if (hKey) hKey.value = sp.apiKey || sp.api_key || '';

    // Set state langsung
    if (typeof state !== 'undefined') {
      state.aiProvider = sp.name;
      state.aiModel = model;
      state.baseUrl = sp.baseUrl || sp.base_url || '';
      KEY_STORE.set(sp.apiKey || sp.api_key || '');
      saveState();
    }

    // Simpan ke Worker
    if (typeof saveAIConfigToWorker === 'function') {
      saveAIConfigToWorker({
        provider: sp.name,
        model: model,
        apiKey: sp.apiKey || sp.api_key || '',
        baseUrl: sp.baseUrl || sp.base_url || '',
      });
    }

    if (typeof closeSettings === 'function') closeSettings();
    showToast('Pengaturan tersimpan!', 'success');
  } catch(e) {
    showToast('Gagal set provider: ' + (e.message || e), 'error');
  }
}

//     Beta Feedback    
let _feedbackRating = 0;
let _feedbackCats = [];
let _feedbackShown = false;

function showFeedback() {
  if (_feedbackShown) return;
  _feedbackShown = true;
  const bar = document.getElementById('feedbackBar');
  if (bar) bar.style.display = 'block';
}

function submitFeedback() {
  const cats = document.querySelectorAll('.fb-cat.active');
  _feedbackCats = Array.from(cats).map(c => c.dataset.c);
  trackEvent('feedback_submitted', {
    rating: _feedbackRating,
    categories: _feedbackCats,
  });
  document.getElementById('feedbackStars').style.display = 'none';
  document.getElementById('feedbackCats').style.display = 'none';
  document.getElementById('feedbackSubmitBtn').style.display = 'none';
  document.getElementById('feedbackThankYou').style.display = 'block';
  setTimeout(() => {
    const bar = document.getElementById('feedbackBar');
    if (bar) bar.style.display = 'none';
  }, 3000);
}

// Wire up feedback stars on DOMContentLoaded
document.addEventListener('DOMContentLoaded', () => {
  document.addEventListener('click', (e) => {
    const star = e.target.closest('.fb-star');
    if (star) {
      _feedbackRating = parseInt(star.dataset.v);
      document.querySelectorAll('.fb-star').forEach(s => s.classList.toggle('active', parseInt(s.dataset.v) <= _feedbackRating));
      document.getElementById('feedbackCats').style.display = 'flex';
      document.getElementById('feedbackSubmitBtn').style.display = 'inline-block';
    }
    const cat = e.target.closest('.fb-cat');
    if (cat) {
      cat.classList.toggle('active');
    }
  });
});

function showBetaDashboard() {
  const data = getAnalytics();
  const gens = (data.generation_completed || []).filter(g => g.success);
  const fails = (data.generation_completed || []).filter(g => !g.success);
  const fb = data.feedback_submitted || [];
  const unknown = getUnknownDomains();

  const domainCounts = {};
  gens.forEach(g => { domainCounts[g.domain] = (domainCounts[g.domain] || 0) + 1; });
  const topDomains = Object.entries(domainCounts).sort((a, b) => b[1] - a[1]).slice(0, 10);

  const avgConf = gens.length ? (gens.reduce((s, g) => s + (g.confidence || 0), 0) / gens.length) : 0;

  console.log('╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╗');
  console.log('║    PRDKit Beta Dashboard     ║');
  console.log('╠╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╣');
  console.log(`║ Generations: ${gens.length} total, ${fails.length} failed`);
  console.log(`║ Feedback: ${fb.length} submissions`);
  console.log(`║ Unknown domains: ${unknown.length} pending`);
  console.log(`║ Avg confidence: ${(avgConf * 100).toFixed(0)}%`);
  console.log('╠╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╣');
  console.log('║ Top domains:');
  topDomains.forEach(([d, c]) => console.log(`║   ${d.padEnd(20)} ${c}`));
  console.log('╚╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀╀');
}

//     Revision Chat    
let revisionChatMessages = [];

function openRevisionChat() {
  const modal = document.getElementById('revisionChatModal');
  const overlay = document.getElementById('revisionChatOverlay');
  if (!modal || !overlay) return;

  // Inject modal content from JS (so iconSvg() works)
  if (!modal.hasChildNodes()) {
    modal.innerHTML = `
      <div class="revision-chat-header">
        <div class="revision-chat-header-left">
          <span class="revision-chat-avatar">${iconSvg('bot', 18)}</span>
          <div>
            <div class="revision-chat-title">Revisi dengan AI</div>
            <div class="revision-chat-subtitle">Tanya atau minta perubahan pada analisis engine</div>
          </div>
        </div>
        <button class="revision-chat-close" onclick="closeRevisionChat()">&times;</button>
      </div>
      <div class="revision-chat-body" id="revisionChatBody">
        <div class="revision-chat-welcome">
          <div class="revision-chat-welcome-icon">${iconSvg('messageCircle', 24)}</div>
          <div class="revision-chat-welcome-text">Tanyakan perubahan atau pertanyaan seputar hasil analisis blueprint ini. AI akan merespon berdasarkan konteks engine yang sudah dianalisis.</div>
        </div>
      </div>
      <div class="revision-chat-footer">
        <div class="revision-chat-input-wrap">
          <input class="revision-chat-input" id="revisionChatInput" type="text" placeholder="Ketik pesan..." autocomplete="off">
          <button class="revision-chat-send" id="revisionChatSend" onclick="sendRevisionMessage()">${iconSvg('send', 16)}</button>
        </div>
      </div>
    `;
  }

  modal.style.display = 'flex';
  overlay.style.display = 'block';

  // Focus input
  setTimeout(() => {
    const input = document.getElementById('revisionChatInput');
    if (input) input.focus();
  }, 300);
}

function closeRevisionChat() {
  const modal = document.getElementById('revisionChatModal');
  const overlay = document.getElementById('revisionChatOverlay');
  if (modal) modal.style.display = 'none';
  if (overlay) overlay.style.display = 'none';
}

async function sendRevisionMessage() {
  const input = document.getElementById('revisionChatInput');
  const sendBtn = document.getElementById('revisionChatSend');
  const body = document.getElementById('revisionChatBody');
  if (!input || !body) return;

  const text = input.value.trim();
  if (!text) return;

  // Clear input, disable send
  input.value = '';
  sendBtn.disabled = true;

  // Remove welcome
  const welcome = body.querySelector('.revision-chat-welcome');
  if (welcome) welcome.remove();

  // Append user message
  body.appendChild(createChatBubble('user', text));
  body.scrollTop = body.scrollHeight;

  // Build context prompt from engine artifacts
  const engineData = window.engineArtifacts || {};
  const contextPrompt = `Berikut adalah hasil analisis engine blueprint:\n\`\`\`json\n${JSON.stringify(engineData, null, 2).substring(0, 4000)}\n\`\`\`\n\nPertanyaan/revisi: ${text}\n\nJawab dalam Bahasa Indonesia. Berikan saran perubahan yang spesifik dan actionable.`;

  // Append typing indicator
  const typingEl = createChatBubble('assistant', 'Mengetik...');
  typingEl.classList.add('typing');
  typingEl.querySelector('.revision-chat-msg-bubble').textContent = 'Mengetik';
  body.appendChild(typingEl);
  body.scrollTop = body.scrollHeight;

  try {
    const response = await callAI([
      { role: 'system', content: 'Anda adalah asisten yang membantu merevisi hasil analisis engine blueprint produk. Jawab dalam Bahasa Indonesia yang alami dan mudah dipahami.' },
      { role: 'user', content: contextPrompt }
    ]);

    // Remove typing indicator
    typingEl.remove();

    if (response) {
      body.appendChild(createChatBubble('assistant', response));
    } else {
      body.appendChild(createChatBubble('assistant', 'Maaf, saya tidak bisa mendapatkan respons dari AI. Silakan coba lagi.'));
    }
  } catch (e) {
    typingEl.remove();
    body.appendChild(createChatBubble('assistant', 'Terjadi kesalahan: ' + e.message));
  }

  body.scrollTop = body.scrollHeight;
  sendBtn.disabled = false;

  // Re-focus input
  setTimeout(() => input.focus(), 100);
}

function createChatBubble(role, text) {
  const div = document.createElement('div');
  div.className = 'revision-chat-msg ' + role;
  div.innerHTML = `
    <div class="revision-chat-msg-avatar">${role === 'user' ? iconSvg('zap', 12) : iconSvg('bot', 12)}</div>
    <div class="revision-chat-msg-bubble">${escapeHtml(text)}</div>
  `;
  return div;
}

// Enter key to send
document.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && document.getElementById('revisionChatModal')?.style.display !== 'none') {
    const input = document.getElementById('revisionChatInput');
    if (input && document.activeElement === input) {
      e.preventDefault();
      sendRevisionMessage();
    }
  }
});

//     Business DNA    
// Cache the DNA result so it persists across tab switches
window.businessDNAResult = null;

function renderBusinessDNACard() {
  const container = document.getElementById('resultTabOverview');
  if (!container) return;

  // Don't duplicate
  if (document.getElementById('businessDNASection')) return;

  if (!window.engineArtifacts || !window.engineArtifacts.domain) return;

  var html = '<div id="businessDNASection">' +
    '<div class="section-title-premium"><span class="stp-label"><span class="stp-deco"></span>Business DNA<span class="stp-deco"></span></span></div>';

  if (window.businessDNAResult) {
    html += '<div class="insight-card" style="--insight-accent:#F59E0B"><div class="insight-header"><div class="insight-header-icon" style="background:rgba(245,158,11,0.12)">' + iconSvg('trendingUp', 16) + '</div><span class="insight-header-label">Analisis Model Bisnis</span></div><div class="insight-body" style="font-size:13px;line-height:1.7;white-space:pre-wrap">' + escapeHtml(window.businessDNAResult) + '</div></div>';
  } else {
    html += '<div class="insight-card" style="--insight-accent:#F59E0B"><div class="insight-body" style="display:flex;align-items:center;justify-content:space-between;gap:16px;padding:20px">' +
      '<div><div style="font-size:13px;font-weight:600;color:var(--text)">Analisis Model Bisnis</div><div style="font-size:11px;color:var(--muted-dim);margin-top:2px">AI akan menganalisis model bisnis dari data engine</div></div>' +
      '<button onclick="inferBusinessDNA()" style="display:flex;align-items:center;gap:8px;padding:10px 18px;border-radius:12px;background:rgba(245,158,11,0.10);border:1px solid rgba(245,158,11,0.2);color:#F59E0B;cursor:pointer;font-size:12px;font-weight:600;white-space:nowrap">' + iconSvg('zap', 14) + ' Generate</button>' +
    '</div></div>';
  }

  html += '</div>';
  container.insertAdjacentHTML('beforeend', html);
}

async function inferBusinessDNA() {
  const section = document.getElementById('businessDNASection');
  if (!section) return;

  // Find the button container and replace with loading
  const btnContainer = section.querySelector('.insight-body');
  if (!btnContainer) return;
  btnContainer.innerHTML = '<div style="display:flex;align-items:center;gap:10px;padding:16px;font-size:12px;color:var(--muted-dim)"><div class="spinner-ring" style="width:18px;height:18px"></div> Menganalisis model bisnis...</div>';

  const engineData = window.engineArtifacts || {};
  const prompt = `Analisis blueprint produk berikut dan identifikasi model bisnisnya.

Data engine:
\`\`\`json
${JSON.stringify(engineData, null, 2).substring(0, 5000)}
\`\`\`

Berikan analisis dalam Bahasa Indonesia dengan format:
**Model Bisnis**: [SaaS/Marketplace/Subscription/E-commerce/Enterprise/etc]
**Sumber Pendapatan**: [jelaskan]
**Target Pasar**: [siapa]
**Value Proposition**: [nilai utama]
**Monetisasi**: [bagaimana]
**Risiko**: [risiko utama]

Buat analisis yang spesifik berdasarkan data di atas, jangan generic.`;

  try {
    const response = await callAI([
      { role: 'system', content: 'Anda adalah analis bisnis yang mengidentifikasi model bisnis dari blueprint produk. Jawab dalam Bahasa Indonesia.' },
      { role: 'user', content: prompt }
    ]);

    if (response) {
      window.businessDNAResult = response;
      // Re-render the section
      const dnaSection = document.getElementById('businessDNASection');
      if (dnaSection) {
        dnaSection.innerHTML = '' +
          '<div class="section-title-premium"><span class="stp-label"><span class="stp-deco"></span>Business DNA<span class="stp-deco"></span></span></div>' +
          '<div class="insight-card" style="--insight-accent:#F59E0B"><div class="insight-header"><div class="insight-header-icon" style="background:rgba(245,158,11,0.12)">' + iconSvg('trendingUp', 16) + '</div><span class="insight-header-label">Analisis Model Bisnis</span></div><div class="insight-body" style="font-size:13px;line-height:1.7;white-space:pre-wrap">' + escapeHtml(response) + '</div></div>';
      }
    } else {
      btnContainer.innerHTML = '<div style="color:var(--muted-dim);font-size:12px;">Gagal mendapatkan analisis. Silakan coba lagi. <button onclick="inferBusinessDNA()" style="background:none;border:none;color:#F59E0B;cursor:pointer;font-weight:600;">Coba lagi</button></div>';
    }
  } catch (e) {
    btnContainer.innerHTML = '<div style="color:var(--muted-dim);font-size:12px;">Error: ' + escapeHtml(e.message) + '. <button onclick="inferBusinessDNA()" style="background:none;border:none;color:#F59E0B;cursor:pointer;font-weight:600;">Coba lagi</button></div>';
  }
}

// Add spinner animation
const styleSheet = document.createElement('style');
styleSheet.textContent = '@keyframes spin { to { transform: rotate(360deg); } }';
document.head.appendChild(styleSheet);

window.showBetaDashboard = showBetaDashboard;

  /* ========================================
     PRDKit   Page Logic & Scripts
     ======================================== */

  //     Wizard Page State    
  let wizardStep = 1;
  let wizardSurveyQ = 0;
  let wizardSurveyTotal = 6;
  let surveyRecommendations = {};
  let wizGenerating = false;

  //     Setup State    
  let selectedCategory = null;
  let selectedParent = null;
  let selectedType = 'Web App';

  //     Hash helpers    
  function getCurrentPage() {
    var hash = window.location.hash.replace('#', '') || 'home';
    if (typeof PAGES !== 'undefined' && PAGES.includes(hash)) return hash;
    return 'home';
  }

  //     Category Translation (English → Indonesian)    
  var CAT_INDONESIA = {
    'Products': 'Produk',
    'Food & Beverage': 'Makanan & Minuman',
    'Services': 'Jasa',
    'Digital Products': 'Produk Digital',
    'Healthcare': 'Kesehatan',
    'Education': 'Pendidikan',
    'Property': 'Properti',
    'Event & Ticketing': 'Event & Tiket',
    'Manufacturing': 'Manufaktur',
    'Distribution & Wholesale': 'Distribusi & Grosir',
    'Logistics': 'Logistik',
    'Marketplace': 'Marketplace',
    'Finance': 'Keuangan',
    'Subscription & Membership': 'Subscription & Member',
    'Media & Content': 'Media & Konten',
    'Travel & Hospitality': 'Travel & Hospitality',
    'On-Demand Services': 'Layanan On-Demand',
    'Community & Organization': 'Komunitas & Organisasi'
  };

  var SUB_INDONESIA = {
    'Fashion & Clothing': 'Fashion & Pakaian',
    'Shoes & Bags': 'Sepatu & Tas',
    'Beauty & Skincare': 'Kecantikan & Skincare',
    'Electronics': 'Elektronik',
    'Mobile Phones & Accessories': 'HP & Aksesoris',
    'Home & Living': 'Rumah & Living',
    'Kitchen Equipment': 'Peralatan Dapur',
    'Baby & Kids': 'Bayi & Anak',
    'Toys': 'Mainan',
    'Books & Stationery': 'Buku & Alat Tulis',
    'Automotive': 'Otomotif',
    'Spare Parts': 'Spare Part',
    'Agriculture': 'Pertanian',
    'Livestock': 'Peternakan',
    'Pet Supplies': 'Perlengkapan Hewan',
    'Raw Materials': 'Bahan Baku',
    'Wholesale': 'Grosir',
    'Others': 'Lainnya',
    'Restaurant': 'Restoran',
    'Cafe': 'Kafe',
    'Coffee Shop': 'Kopi',
    'Bakery': 'Bakery',
    'Dessert': 'Dessert',
    'Frozen Food': 'Makanan Beku',
    'Street Food': 'Street Food',
    'Catering': 'Katering',
    'Juice & Smoothies': 'Jus & Smoothie',
    'Seafood': 'Seafood',
    'Rice Bowl': 'Rice Bowl',
    'Dimsum': 'Dimsum',
    'Beverage Store': 'Toko Minuman',
    'Digital Agency': 'Digital Agency',
    'Software House': 'Software House',
    'Freelancer': 'Freelancer',
    'Consultant': 'Konsultan',
    'Accounting': 'Akuntansi',
    'Legal': 'Legal',
    'Barbershop': 'Barbershop',
    'Salon': 'Salon',
    'Spa': 'Spa',
    'Laundry': 'Laundry',
    'Car Wash': 'Cuci Mobil',
    'Workshop & Repair': 'Bengkel',
    'Photography': 'Fotografi',
    'Videography': 'Videografi',
    'Event Organizer': 'Event Organizer',
    'Cleaning Service': 'Cleaning Service',
    'Education Services': 'Jasa Pendidikan',
    'SaaS': 'SaaS',
    'AI Product': 'Produk AI',
    'E-book': 'E-book',
    'Template': 'Template',
    'Prompt Library': 'Prompt Library',
    'Membership': 'Membership',
    'Online Course': 'Kursus Online',
    'Newsletter': 'Newsletter',
    'Plugin': 'Plugin',
    'Clinic': 'Klinik',
    'Pharmacy': 'Apotek',
    'Laboratory': 'Laboratorium',
    'Therapy': 'Terapi',
    'Psychology': 'Psikologi',
    'Telemedicine': 'Telemedicine',
    'School': 'Sekolah',
    'Tutoring': 'Bimbingan Belajar',
    'Course': 'Kursus',
    'Bootcamp': 'Bootcamp',
    'Training': 'Pelatihan',
    'LMS': 'LMS',
    'Boarding House': 'Kost',
    'Rental House': 'Kontrakan',
    'Apartment': 'Apartemen',
    'Villa': 'Villa',
    'Homestay': 'Homestay',
    'Hotel': 'Hotel',
    'Property Management': 'Manajemen Properti',
    'Seminar': 'Seminar',
    'Workshop': 'Workshop',
    'Webinar': 'Webinar',
    'Concert': 'Konser',
    'Gathering': 'Gathering',
    'Conference': 'Konferensi',
    'Food Production': 'Produksi Makanan',
    'Beverage Production': 'Produksi Minuman',
    'Garment': 'Garmen',
    'Furniture': 'Furniture',
    'Craft': 'Kerajinan',
    'Factory': 'Pabrik',
    'Distributor': 'Distributor',
    'Supplier': 'Supplier',
    'Agent': 'Agen',
    'Reseller': 'Reseller',
    'Wholesale Store': 'Grosir',
    'Courier': 'Kurir',
    'Delivery Service': 'Delivery Service',
    'Fleet Management': 'Manajemen Armada',
    'Warehouse': 'Gudang',
    'Expedition': 'Ekspedisi',
    'Multi Vendor Marketplace': 'Multi Vendor',
    'E-Commerce': 'Toko Online',
    'B2B Marketplace': 'B2B Marketplace',
    'Rental Marketplace': 'Marketplace Rental',
    'Service Marketplace': 'Marketplace Jasa',
    'Fintech': 'Fintech',
    'E-Wallet': 'E-Wallet',
    'Lending': 'Peminjaman',
    'Cooperative': 'Koperasi',
    'Accounting System': 'Sistem Akuntansi',
    'Billing System': 'Sistem Billing',
    'Gym': 'Gym',
    'Loyalty Program': 'Loyalty Program',
    'Premium Membership': 'Premium Membership',
    'Subscription Service': 'Layanan Berlangganan',
    'Community Membership': 'Membership Komunitas',
    'Blog': 'Blog',
    'News Portal': 'Portal Berita',
    'Podcast': 'Podcast',
    'Video Platform': 'Platform Video',
    'Streaming Platform': 'Platform Streaming',
    'Creator Economy': 'Creator Economy',
    'Travel Agency': 'Agen Travel',
    'Tour Operator': 'Tour Operator',
    'Hotel Booking': 'Booking Hotel',
    'Vacation Rental': 'Sewa Villa',
    'Ticketing': 'Tiket',
    'Ride Hailing': 'Ride Hailing',
    'Food Delivery': 'Food Delivery',
    'Home Service': 'Home Service',
    'Beauty Service': 'Kecantikan',
    'Healthcare Service': 'Layanan Kesehatan',
    'Super App': 'Super App',
    'Community': 'Komunitas',
    'Foundation': 'Yayasan',
    'NGO': 'NGO',
    'Religious Organization': 'Organisasi Keagamaan',
    'Association': 'Asosiasi'
  };

  function id(str) { return CAT_INDONESIA[str] || SUB_INDONESIA[str] || str; }

  //     Tech Stack by Product Type    
  var TECH_BY_TYPE = {
    'Web App': [
      { tech: 'React + Next.js', desc: 'Full-stack React, cocok utk SaaS & dashboard', rec: 0.95 },
      { tech: 'Vue + Nuxt', desc: 'Vue-based full-stack, ringan & cepat', rec: 0.80 },
      { tech: 'SvelteKit', desc: 'Bundle size minimal, performa tinggi', rec: 0.70 },
      { tech: 'Laravel', desc: 'PHP monolith, cepat prototyping', rec: 0.75 },
      { tech: 'Django', desc: 'Python full-stack, cocok data-heavy', rec: 0.70 },
      { tech: 'Ruby on Rails', desc: 'Konvensi tinggi, produktif', rec: 0.60 },
      { tech: 'Remix', desc: 'Web standard, edge-ready', rec: 0.65 }
    ],
    'Mobile App': [
      { tech: 'Flutter', desc: 'Cross-platform, performa native, UI konsisten', rec: 0.95 },
      { tech: 'React Native', desc: 'Cross-platform, ekosistem JS', rec: 0.85 },
      { tech: 'Kotlin', desc: 'Native Android, performa maksimal', rec: 0.70 },
      { tech: 'Swift', desc: 'Native iOS, eksklusif Apple', rec: 0.65 },
      { tech: 'Ionic', desc: 'Hybrid web-based, cepat rilis', rec: 0.55 }
    ],
    'API / Backend': [
      { tech: 'Node.js + Express', desc: 'Ringan, event-driven, ekosistem besar', rec: 0.95 },
      { tech: 'Go', desc: 'Performa tinggi, cocok microservice', rec: 0.85 },
      { tech: 'Python + FastAPI', desc: 'Cepat dev, cocok AI/ML integration', rec: 0.80 },
      { tech: 'Rust + Actix', desc: 'Keamanan memori, performa ekstrim', rec: 0.55 },
      { tech: 'Java + Spring', desc: 'Enterprise-grade, stabil', rec: 0.60 },
      { tech: 'PHP + Laravel', desc: 'Mature, hosting murah', rec: 0.65 }
    ],
    'Desktop App': [
      { tech: 'Electron', desc: 'Cross-platform, pake web tech', rec: 0.90 },
      { tech: 'Tauri', desc: 'Ringan, Rust-based, lebih aman', rec: 0.80 },
      { tech: 'C# + .NET', desc: 'Windows native, mature ecosystem', rec: 0.70 },
      { tech: 'Python + Tkinter', desc: 'Cepat prototyping, cross-platform', rec: 0.55 },
      { tech: 'Java + Swing', desc: 'Cross-platform, mature', rec: 0.50 }
    ],
    'Landing Page': [
      { tech: 'Astro', desc: 'Zero JS by default, SEO optimal', rec: 0.95 },
      { tech: 'Next.js', desc: 'SSR/SSG fleksibel, ekosistem React', rec: 0.80 },
      { tech: 'Plain HTML + CSS', desc: 'Simple, cepat, ga pake framework', rec: 0.75 },
      { tech: 'WordPress', desc: 'CMS, cocok content-heavy', rec: 0.65 },
      { tech: 'Webflow', desc: 'Visual builder, no-code friendly', rec: 0.60 }
    ]
  };

  var TECH_DEFAULT = 'React + Next.js';
  var selectedTech = null;
  var techRecommended = false;

  //     Smart Tech Recommendation    
  function getTechRecommendation() {
    var type = selectedType || 'Web App';
    var cat = selectedCategory || '';
    var name = document.getElementById('productName')?.value?.trim() || '';
    var techs = TECH_BY_TYPE[type] || TECH_BY_TYPE['Web App'];
    if (!techs || techs.length === 0) return null;
    // Sort by recommendation score
    var sorted = techs.slice().sort(function(a, b) { return b.rec - a.rec; });
    var best = sorted[0];
    // Generate reason based on context
    var reasons = [];
    if (type === 'Mobile App') reasons.push('target mobile user');
    if (type === 'Web App') reasons.push('akses via browser');
    if (type === 'API / Backend') reasons.push('backend service');
    if (cat) reasons.push('industri ' + cat.toLowerCase());
    if (name) reasons.push('proyek ' + name);
    return {
      tech: best.tech,
      desc: best.desc,
      reason: 'Rekomendasi untuk ' + (reasons.length > 0 ? reasons.join(', ') : type) + '. ' + best.desc,
      score: best.rec
    };
  }

  function applyAIRecommendation() {
    var rec = getTechRecommendation();
    if (!rec) return;
    selectedTech = rec.tech;
    techRecommended = true;
    // Update UI chips
    var grid = document.getElementById('techGrid');
    if (grid) {
      grid.querySelectorAll('.chip').forEach(function(c) {
        c.classList.toggle('selected', c.dataset.tech === rec.tech);
      });
    }
    // Show toast
    showToast('AI merekomendasikan: ' + rec.tech, 'success');
    // Update AI suggestion card
    var aiChips = document.getElementById('aiChips');
    if (aiChips) {
      aiChips.innerHTML = '<span class="chip selected" style="color:var(--accent);background:var(--accent-soft);border-color:rgba(0,224,143,0.25);cursor:default">✅ ' + rec.tech + '</span><span class="text-[10px] ml-1" style="color:var(--text-muted)">' + rec.reason + '</span>';
    }
  }

  //     Setup Page    
  function initSetup() {
    // Clear stale state from previous sessions (localStorage)   setup always starts fresh
    if (typeof state !== 'undefined') {
      state.productName = '';
      state.idea = '';
      state.productCategory = '';
      state.productCatName = '';
      state.productCategoryParent = '';
      var inp = document.getElementById('productName');
      if (inp) inp.value = '';
    }
    renderCategory();
  }

  function renderCategory() {
    var grid = document.getElementById('categoryGrid');
    if (!grid) return;
    grid.innerHTML = '';
    if (typeof CATEGORIES === 'undefined') return;
    CATEGORIES.forEach(function(cat) {
      var card = document.createElement('div');
      card.className = 'cat-card' + (selectedParent === cat.name ? ' selected' : '');
      card.onclick = function() { selectParent(cat.name); };
      var displayName = id(cat.name);
      card.innerHTML = '<div class="cat-card-inner"><div class="cat-icon">' + (cat.icon ? svgIcon(cat.icon) : '📀') + '</div><div class="text-[11px] sm:text-[12px] font-semibold text-center" style="color:var(--text)">' + displayName + '</div></div>';
      grid.appendChild(card);
    });
  }

  function svgIcon(name) {
    var icons = {
      package: '<path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/><path d="M3.27 6.96 12 12l8.73-5.04"/><path d="M12 22V12"/>',
      utensilsCrossed: '<path d="M3 3v7c0 1.1.9 2 2 2h2"/><path d="M5 3v18"/><path d="M21 3v7c0 1.1-.9 2-2 2h-2"/><path d="M19 3v18"/><path d="m9 14 8-8"/><path d="M9 10.5 13.5 15"/><path d="M11.5 12.5 20 21"/>',
      wrench: '<path d="M14.7 6.3a4 4 0 0 0-5.6 5.6L3 18v3h3l6.1-6.1a4 4 0 0 0 5.6-5.6l-3 3-2.1-2.1 3.1-3.9Z"/>',
      monitor: '<rect x="3" y="4" width="18" height="14" rx="2"/><path d="M8 20h8"/><path d="M12 18v2"/>',
      stethoscope: '<path d="M6 3v7a6 6 0 0 0 12 0V3"/><path d="M18 10v2a4 4 0 0 1-8 0v-2"/><circle cx="6" cy="21" r="2"/><circle cx="18" cy="21" r="2"/><path d="M8 21h10"/>',
      graduationCap: '<path d="M22 10 12 5 2 10l10 5 10-5Z"/><path d="M6 12v4c0 1.1 2.7 2 6 2s6-.9 6-2v-4"/><path d="M2 10v6"/><path d="M22 10v6"/>',
      house: '<path d="M3 11.5 12 4l9 7.5"/><path d="M5 10.5V20h14v-9.5"/><path d="M9 20v-6h6v6"/>',
      ticket: '<path d="M3 9a2 2 0 0 0 2 2 2 2 0 0 1 0 4 2 2 0 0 0-2 2v2h18v-2a2 2 0 0 0-2-2 2 2 0 0 1 0-4 2 2 0 0 0 2-2V7H3Z"/>',
      factory: '<path d="M3 20h18V9l-6 3V9l-6 3V7L3 10v10Z"/><path d="M7 20v-6"/><path d="M11 20v-4"/>',
      truck: '<path d="M10 17H3V6h11v11H10Z"/><path d="M14 9h4l3 3v5h-2"/><circle cx="7" cy="18" r="2"/><circle cx="17" cy="18" r="2"/>',
      store: '<path d="M4 10h16"/><path d="M5 10 6 4h12l1 6"/><path d="M5 10v9h14v-9"/><path d="M9 19v-5h6v5"/>',
      wallet: '<path d="M4 7h14a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H4V7Z"/><path d="M16 11h4"/><circle cx="16" cy="15" r="1"/>',
      badgeCheck: '<path d="M12 2 9 4l-3 .5L5 8 2 10l1 3-1 3 3 2 .5 3 3 .5 2 3 2-3 3-.5.5-3 3-2-1-3 1-3-3-2-.5-3L15 4l-3-2Z"/><path d="m9 12 2 2 4-4"/>',
      newspaper: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 8h5"/><path d="M7 12h10"/><path d="M7 16h10"/>',
      plane: '<path d="M2 12 22 3l-5 19-4-8-8-4 7-1 0-4Z"/>',
      zap: '<path d="M13 2 4 14h7l-1 8 9-12h-7l1-8Z"/>',
      users: '<path d="M17 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2"/><circle cx="10" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
      folder: '<path d="M3 6a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6Z"/>'
    };
    return '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">' + (icons[name] || icons.folder) + '</svg>';
  }

  function selectParent(name) {
    if (selectedParent === name) { selectedParent = null; selectedCategory = null; }
    else { selectedParent = name; selectedCategory = null; }
    var grid = document.getElementById('categoryGrid');
    if (!grid) return;
    if (selectedParent) {
      grid.style.display = 'none';
      var subArea = document.getElementById('panelSubs');
      if (subArea) {
        subArea.classList.remove('hidden');
        document.getElementById('subCatTitle').textContent = id(selectedParent);
        var subs = [];
        if (typeof CATEGORIES !== 'undefined') {
          var parent = CATEGORIES.find(function(c) { return c.name === selectedParent; });
          if (parent) subs = parent.sub || [];
        }
        var subGrid = document.getElementById('subcategoryGrid');
        if (subGrid) {
          subGrid.innerHTML = '';
          subs.forEach(function(s) {
            var card = document.createElement('div');
            card.className = 'sub-card' + (selectedCategory === s ? ' selected' : '');
            var displaySub = id(s);
            card.innerHTML = '<div class="sub-card-inner"><div class="sub-dot"></div><div class="text-[11px] sm:text-[12px] font-semibold text-center leading-tight" style="color:var(--text)">' + displaySub + '</div></div>';
            card.onclick = function() {
              selectedCategory = s;
              subGrid.querySelectorAll('.sub-card').forEach(function(c) { c.classList.remove('selected'); });
              card.classList.add('selected');
            };
            subGrid.appendChild(card);
          });
        }
        document.getElementById('panelCategories').classList.add('hidden');
      }
      // Also set subcategoryArea for app.js compatibility
      var subAreaCompat = document.getElementById('subcategoryArea');
      if (subAreaCompat) {
        subAreaCompat.style.display = 'block';
        subAreaCompat.innerHTML = '<div style="padding:8px 0"><span style="color:var(--accent);font-size:12px">' + id(selectedParent) + ' ▸ ' + (selectedCategory ? id(selectedCategory) : 'pilih subkategori') + '</span></div>';
      }
    } else {
      grid.style.display = '';
      document.getElementById('panelSubs').classList.add('hidden');
      document.getElementById('panelCategories').classList.remove('hidden');
      document.getElementById('subcategoryArea').style.display = 'none';
    }
  }

  function backToParent() {
    selectedParent = null;
    selectedCategory = null;
    var grid = document.getElementById('categoryGrid');
    if (grid) grid.style.display = '';
    document.getElementById('panelSubs').classList.add('hidden');
    document.getElementById('panelCategories').classList.remove('hidden');
    document.getElementById('subcategoryArea').style.display = 'none';
  }

  function goToWizard() {
    var name = document.getElementById('productName').value.trim();
    if (!name) { document.getElementById('productName').focus(); return; }
    if (typeof state !== 'undefined') {
      state.productName = name;
      state.step = 1;
      state.productType = selectedType || 'Web App';
      state.productCategory = selectedCategory || '';
      state.productCategoryParent = selectedParent || '';
      state.productCatName = selectedParent || '';
      if (typeof saveState === 'function') saveState();
    }
    navigate('wizard');
  }

  function continueProject() {
    if (typeof state !== 'undefined' && state.versions && state.versions.length > 0) {
      navigate('result');
    } else {
      navigate('wizard');
    }
  }

  //     Category type chips    
  document.addEventListener('DOMContentLoaded', function() {
    var chips = document.querySelectorAll('#typeGrid .type-chip');
    chips.forEach(function(el) {
      el.addEventListener('click', function() {
        chips.forEach(function(c) { c.classList.remove('selected'); });
        el.classList.add('selected');
        selectedType = el.dataset.type;
      });
    });
  });

  //     Terminal tabs    
  document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('.terminal-tab').forEach(function(tab) {
      tab.addEventListener('click', function() {
        document.querySelectorAll('.terminal-tab').forEach(function(t) { t.classList.remove('active'); });
        tab.classList.add('active');
        var target = tab.dataset.tab;
        document.querySelectorAll('.terminal-panel').forEach(function(p) { p.classList.remove('active'); });
        var panel = document.getElementById('panel-' + target);
        if (panel) panel.classList.add('active');
      });
    });
  });

  //     Settings Modal    
  var _currentAIAccessMode = 'byok';

  function openSettings() {
    var modal = document.getElementById('settingsModal');
    if (!modal) return;
    selectedProvider = null;
    if (typeof loadSavedProvidersFromD1 === 'function') loadSavedProvidersFromD1();
    // Reset to initial view
    var initial = document.getElementById('settingsInitialView');
    var addSection = document.getElementById('addProviderSection');
    if (initial) initial.style.display = 'block';
    if (addSection) addSection.style.display = 'none';
    modal.classList.add('open');
  }

  function closeSettings() {
    var modal = document.getElementById('settingsModal');
    if (modal) modal.classList.remove('open');
    selectedProvider = null;
    var initial = document.getElementById('settingsInitialView');
    var addSection = document.getElementById('addProviderSection');
    if (initial) initial.style.display = 'block';
    if (addSection) addSection.style.display = 'none';
    if (typeof updateAIConfigUI === 'function') updateAIConfigUI();
  }

  //     Update AI Config Indicator on Home    
  if (typeof updateAIConfigUI !== 'function') {
    window.updateAIConfigUI = function() {
      var configured = !!(state && state.aiProvider && state.aiModel);
      var createBtn = document.getElementById('createBlueprintBtn');
      var modelBtn = document.getElementById('modelSettingsBtn');
      var indicator = document.getElementById('aiConfigIndicator');
      if (!createBtn || !modelBtn || !indicator) return;
      if (configured) {
        createBtn.disabled = false;
        modelBtn.classList.remove('warn-outline');
        indicator.className = 'ai-config-indicator success mb-3';
        indicator.innerHTML = '<span class="ai-config-icon">◀</span><div class="ai-config-text"><span onclick="openSettings()">' + state.aiModel + '</span></div>';
      } else {
        createBtn.disabled = true;
        modelBtn.classList.add('warn-outline');
        indicator.className = 'ai-config-indicator warn mb-3';
        indicator.innerHTML = '<span class="ai-config-icon">⚠</span><div class="ai-config-text"><span>AI models belum dikonfigurasi.</span><span class="ai-config-sub">Konfigurasikan model terlebih dahulu untuk mulai membuat blueprint.</span></div>';
      }
    };
  }

  //     Override renderSavedProvidersDropdown to handle noConfigMsg + populate hidden fields    
  var _origRenderDropdown = typeof renderSavedProvidersDropdown === 'function' ? renderSavedProvidersDropdown : null;
  renderSavedProvidersDropdown = function() {
    if (_origRenderDropdown) _origRenderDropdown();
    var select = document.getElementById('savedProviderSelect');
    var noConfig = document.getElementById('noConfigMsg');
    var hasConfig = document.getElementById('hasConfigView');
    if (!noConfig || !hasConfig) return;
    var hasOptions = select && select.options.length > 1;
    noConfig.style.display = hasOptions ? 'none' : 'block';
    hasConfig.style.display = hasOptions ? 'block' : 'none';

    // When user selects a saved provider → populate hidden fields for saveSettings()
    if (select) {
      select.onchange = function() {
        var delBtn = document.getElementById('deleteProviderBtn');
        if (delBtn) delBtn.disabled = !this.value;
        if (this.value && typeof savedProviders !== 'undefined') {
          var sp = savedProviders.find(function(p) { return p.name === select.value; });
          if (sp) {
            // Populate hidden fields that saveSettings() reads
            var hName = document.getElementById('selectedProviderName');
            var hUrl = document.getElementById('settingsBaseUrl');
            var hKey = document.getElementById('settingsApiKeyInput');
            var hModel = document.getElementById('settingsAiModel');
            if (hName) hName.textContent = sp.name;
            if (hUrl) hUrl.value = sp.base_url || sp.baseUrl || '';
            if (hKey) hKey.value = sp.api_key || sp.apiKey || '';
            if (hModel) {
              var modelVal = sp.models?.[0] || sp.model || '';
              if (modelVal) {
                // Add the model as an option if it doesn't exist
                var exists = false;
                for (var i = 0; i < hModel.options.length; i++) {
                  if (hModel.options[i].value === modelVal) { exists = true; break; }
                }
                if (!exists) {
                  var opt = document.createElement('option');
                  opt.value = modelVal;
                  opt.text = modelVal;
                  hModel.appendChild(opt);
                }
                hModel.value = modelVal;
              }
            }
          }
        }
      };
    }
  };

  function openProviderSelector() {
    document.getElementById('settingsInitialView').style.display = 'none';
    document.getElementById('addProviderSection').style.display = 'block';
    // Reset all steps: show Step 1, hide Step 2 & 3
    document.getElementById('providerSelectorStep').style.display = 'block';
    document.getElementById('providerDetailStep').style.display = 'none';
    document.getElementById('modelSelectionStep').style.display = 'none';
    // Reset back button to cancel (go to initial view)
    document.getElementById('addProviderBackBtn').onclick = cancelAddProvider;
    document.getElementById('addProviderStepTitle').textContent = 'Tambah Provider';
    // Reset form fields
    document.getElementById('detailApiKey').value = '';
    document.getElementById('detailAlias').value = '';
    document.getElementById('detailModelSelect').innerHTML = '<option value="">Pilih model...</option>';
    var searchInput = document.getElementById('providerSearchInput');
    if (searchInput) { searchInput.value = ''; searchInput.focus(); }
    if (typeof renderProviderList === 'function') renderProviderList();
  }

  function cancelAddProvider() {
    document.getElementById('addProviderSection').style.display = 'none';
    document.getElementById('settingsInitialView').style.display = 'block';
    if (typeof renderSavedProvidersDropdown === 'function') renderSavedProvidersDropdown();
  }

  function continueToDetailForm() {
    if (selectedProvider) {
      document.getElementById('detailBaseUrl').value = selectedProvider.baseUrl || '';
      // Set provider icon
      var icons = {'anthropic':'🤖','openai':'🟢','openrouter':'🀀','gemini':'🀵','sumopod':'⚡'};
      document.getElementById('detailProviderIcon').textContent = icons[selectedProvider.type] || '🀌';
      document.getElementById('detailProviderDesc').textContent = (selectedProvider.type || 'custom') + ' · verify API Key untuk lihat model';
    }
    syncDetailToHidden();
    document.getElementById('providerSelectorStep').style.display = 'none';
    document.getElementById('providerDetailStep').style.display = 'block';
    document.getElementById('modelSelectionStep').style.display = 'none';
    // Back button: from Step 2 go to Step 1
    document.getElementById('addProviderBackBtn').onclick = function() {
      document.getElementById('providerDetailStep').style.display = 'none';
      document.getElementById('providerSelectorStep').style.display = 'block';
      document.getElementById('addProviderBackBtn').onclick = cancelAddProvider;
      document.getElementById('addProviderStepTitle').textContent = 'Tambah Provider';
    };
    document.getElementById('addProviderStepTitle').textContent = 'Detail Provider';
  }

  function backToDetailForm() {
    document.getElementById('modelSelectionStep').style.display = 'none';
    document.getElementById('providerDetailStep').style.display = 'block';
    document.getElementById('addProviderBackBtn').onclick = function() {
      document.getElementById('providerDetailStep').style.display = 'none';
      document.getElementById('providerSelectorStep').style.display = 'block';
      document.getElementById('addProviderBackBtn').onclick = cancelAddProvider;
      document.getElementById('addProviderStepTitle').textContent = 'Tambah Provider';
    };
    document.getElementById('addProviderStepTitle').textContent = 'Detail Provider';
  }

  function syncDetailToHidden() {
    var hApiKey = document.getElementById('settingsApiKeyInput');
    var hBaseUrl = document.getElementById('settingsBaseUrl');
    if (hBaseUrl) hBaseUrl.value = document.getElementById('detailBaseUrl').value;
    if (hApiKey) hApiKey.value = document.getElementById('detailApiKey').value;
  }

  function hapusProvider() {
    var select = document.getElementById('savedProviderSelect');
    if (!select || select.value === '') return;
    if (typeof deleteSavedProviderFromDropdown === 'function') deleteSavedProviderFromDropdown();
  }

  window.simpanPengaturan = async function simpanPengaturanFn() {
    // Debug: confirm this version is running
    console.log('[PRDKit] simpanPengaturan v2 (D1 direct)');
    var select = document.getElementById('savedProviderSelect');
    var name = select ? select.value : '';
    if (!name) { if (typeof showToast === 'function') showToast('Pilih provider dari daftar.', 'error'); return; }

    // Langsung fetch dari D1   ga pake saveSettings() atau DOM sama sekali
    try {
      var API_BASE = typeof API_URL !== 'undefined' ? API_URL : 'https://prdkit-ai-proxy.halugoodsindonesia.workers.dev';
      console.log('[PRDKit] Fetching providers from', API_BASE);
      var res = await fetch(API_BASE + '/api/providers', { credentials: 'include' });
      var data = await res.json();
      console.log('[PRDKit] Providers data:', data);
      var providers = data.providers || [];
      var sp = providers.find(function(p) { return p.name === name; });
      console.log('[PRDKit] Found sp:', sp);
      if (!sp) {
        if (typeof showToast === 'function') showToast('Provider tidak ditemukan di database.', 'error');
        return;
      }

      // Extract model   handle berbagai format
      var model = '';
      if (sp.models && Array.isArray(sp.models) && sp.models.length > 0) {
        model = sp.models[0];
      } else if (sp.model) {
        model = sp.model;
      }
      console.log('[PRDKit] Extracted model:', model);
      if (!model) {
        if (typeof showToast === 'function') showToast('Model tidak ditemukan untuk provider ini. Verify dulu ya.', 'error');
        return;
      }

      // Sync ke hidden DOM
      var hModel = document.getElementById('settingsAiModel');
      if (hModel) {
        hModel.innerHTML = '<option value="">Pilih model...</option>';
        var opt = document.createElement('option');
        opt.value = model; opt.text = model;
        hModel.appendChild(opt);
        hModel.value = model;
      }

      // Populate hidden fields
      var hName = document.getElementById('selectedProviderName');
      var hUrl = document.getElementById('settingsBaseUrl');
      var hKey = document.getElementById('settingsApiKeyInput');
      if (hName) hName.textContent = sp.name;
      if (hUrl) hUrl.value = sp.baseUrl || sp.base_url || '';
      if (hKey) hKey.value = sp.apiKey || sp.api_key || '';

      // Set state langsung
      if (typeof state !== 'undefined') {
        state.aiProvider = sp.name;
        state.aiModel = model;
        state.baseUrl = sp.baseUrl || sp.base_url || '';
        KEY_STORE.set(sp.apiKey || sp.api_key || '');
        saveState();
      }

      // Simpan ke Worker
      if (typeof saveAIConfigToWorker === 'function') {
        saveAIConfigToWorker({
          provider: sp.name,
          model: model,
          apiKey: sp.apiKey || sp.api_key || '',
          baseUrl: sp.baseUrl || sp.base_url || '',
        });
      }

      if (typeof closeSettings === 'function') closeSettings();
      if (typeof showToast === 'function') showToast('Pengaturan tersimpan!', 'success');
    } catch(e) {
      if (typeof showToast === 'function') showToast('Gagal set provider: ' + (e.message || e), 'error');
    }
  }

  function simpanProvider() {
    // Sync ALL detail values to hidden fields for app.js saveNewProvider
    syncDetailToHidden();
    var dModel = document.getElementById('detailModelSelect');
    var hModel = document.getElementById('settingsAiModel');
    if (dModel && hModel) {
      hModel.innerHTML = '';
      for (var i = 0; i < dModel.options.length; i++) {
        var opt = document.createElement('option');
        opt.value = dModel.options[i].value;
        opt.text = dModel.options[i].text;
        hModel.appendChild(opt);
      }
      hModel.value = dModel.value;
      // Set display name: alias > provider name
      var alias = document.getElementById('detailAlias').value.trim();
      var hName = document.getElementById('selectedProviderName');
      if (hName) {
        hName.textContent = alias || (document.getElementById('detailProviderName')?.textContent || 'Provider');
      }
    }
    if (typeof saveNewProvider === 'function') {
      saveNewProvider();
      cancelAddProvider();
    } else {
      showToast('Fungsi simpan belum tersedia', 'error');
    }
  }

  function toggleDetailApiKey() {
    var inp = document.getElementById('detailApiKey');
    if (inp) inp.type = inp.type === 'password' ? 'text' : 'password';
  }

  //     Custom Dropdown    
  var _customDropdownOpen = null;

  function toggleCustomDropdown(id) {
    var panel = document.getElementById(id);
    if (!panel) return;
    if (_customDropdownOpen && _customDropdownOpen !== id) {
      var prev = document.getElementById(_customDropdownOpen);
      if (prev) { prev.classList.remove('open'); prev.parentElement.querySelector('.custom-select-trigger')?.classList.remove('open'); }
    }
    var isOpening = !panel.classList.contains('open');
    panel.classList.toggle('open', isOpening);
    var trigger = panel.parentElement.querySelector('.custom-select-trigger');
    if (trigger) trigger.classList.toggle('open', isOpening);
    _customDropdownOpen = isOpening ? id : null;
  }

  function selectCustomOption(triggerId, displayId, dropdownId, value, text) {
    var display = document.getElementById(displayId);
    var trigger = document.getElementById(triggerId);
    if (display) { display.textContent = text; }
    if (trigger) { trigger.classList.toggle('has-value', !!value); }
    // Close dropdown
    var panel = document.getElementById(dropdownId);
    if (panel) { panel.classList.remove('open'); panel.parentElement.querySelector('.custom-select-trigger')?.classList.remove('open'); }
    _customDropdownOpen = null;
    // Update items
    if (panel) {
      panel.querySelectorAll('.custom-dropdown-item').forEach(function(el) { el.classList.remove('selected'); });
      var sel = panel.querySelector('.custom-dropdown-item[data-value="' + value.replace(/"/g, '&quot;') + '"]');
      if (sel) sel.classList.add('selected');
    }
    return value;
  }

  function populateCustomDropdown(dropdownId, items, selectedValue, triggerId, displayId, onChange) {
    var panel = document.getElementById(dropdownId);
    if (!panel) return;
    panel.innerHTML = '';
    items.forEach(function(item) {
      var div = document.createElement('div');
      div.className = 'custom-dropdown-item' + (item.value === selectedValue ? ' selected' : '');
      div.setAttribute('data-value', item.value);
      div.textContent = item.label;
      div.onclick = function() {
        selectCustomOption(triggerId, displayId, dropdownId, item.value, item.label);
        if (typeof onChange === 'function') onChange(item.value, item.label);
      };
      panel.appendChild(div);
    });
    // Set current display
    var match = items.find(function(i) { return i.value === selectedValue; });
    if (match) {
      selectCustomOption(triggerId, displayId, dropdownId, match.value, match.label);
    }
  }

  // Close custom dropdown on outside click
  document.addEventListener('click', function(e) {
    if (_customDropdownOpen) {
      var panel = document.getElementById(_customDropdownOpen);
      if (panel && !panel.parentElement.contains(e.target)) {
        panel.classList.remove('open');
        panel.parentElement.querySelector('.custom-select-trigger')?.classList.remove('open');
        _customDropdownOpen = null;
      }
    }
  });

  async function detailVerifyKey() {
    var apiKey = document.getElementById('detailApiKey').value.trim();
    var baseUrl = document.getElementById('detailBaseUrl').value.trim();
    if (!apiKey) { showToast('Masukkan API Key dulu.', 'error'); return; }
    if (!baseUrl) { showToast('Base URL belum diisi.', 'error'); return; }

    var type = (typeof selectedProvider !== 'undefined' && selectedProvider) ? (selectedProvider.type || 'openai') : 'openai';
    var verifyBtn = document.getElementById('detailVerifyBtn');
    var verifyLabel = document.getElementById('detailVerifyLabel');
    if (verifyLabel) verifyLabel.textContent = 'Verifying...';
    if (verifyBtn) verifyBtn.disabled = true;
    var detailModelGroup = document.getElementById('detailModelGroup');
    if (detailModelGroup) detailModelGroup.style.display = 'none';

    try {
      var API_BASE = typeof API_URL !== 'undefined' ? API_URL : 'https://prdkit-ai-proxy.halugoods-indonesia.workers.dev';
      var res = await fetch(API_BASE + '/api/verify-key', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ type: type, baseUrl: baseUrl, apiKey: apiKey }),
      });
      var data = await res.json();

      if (!res.ok || data.error || !data.success) {
        if (verifyLabel) verifyLabel.textContent = 'Verify';
        if (verifyBtn) verifyBtn.disabled = false;
        showToast(data.error || 'API Key tidak valid.', 'error');
        return;
      }

      // Success   populate model dropdown (native + custom)
      var dModel = document.getElementById('detailModelSelect');
      var models = data.models || [];
      if (dModel) {
        dModel.innerHTML = '<option value="">Pilih model...</option>';
        var modelsToUse = models.length > 0 ? models : ((typeof selectedProvider !== 'undefined' && selectedProvider) ? (selectedProvider.defaultModels || selectedProvider.models || []) : []);
        modelsToUse.forEach(function(m) {
          var opt = document.createElement('option');
          opt.value = m;
          opt.textContent = m;
          dModel.appendChild(opt);
        });
      }
      // Populate custom model dropdown + sync native select
      if (typeof populateCustomDropdown === 'function' && document.getElementById('detailModelDropdown')) {
        var modelItems = [{value:'', label:'Pilih model...'}];
        modelsToUse.forEach(function(m) { modelItems.push({value:m, label:m}); });
        populateCustomDropdown('detailModelDropdown', modelItems, '', 'detailModelTrigger', 'detailModelDisplay', function(val) {
          var hModel = document.getElementById('settingsAiModel');
          if (hModel) {
            hModel.innerHTML = '';
            var opt = document.createElement('option');
            opt.value = val;
            opt.textContent = val;
            hModel.appendChild(opt);
            hModel.value = val;
          }
          // Also sync native select for simpanProvider
          if (dModel) dModel.value = val;
        });
      }

      // Auto-advance ke Step 3: Pilih Model
      var provName = document.getElementById('detailProviderName');
      document.getElementById('verifiedProviderName').textContent = provName ? provName.textContent : ' ';
      document.getElementById('providerDetailStep').style.display = 'none';
      document.getElementById('modelSelectionStep').style.display = 'block';
      // Back button: from Step 3 go to Step 2
      document.getElementById('addProviderBackBtn').onclick = backToDetailForm;
      document.getElementById('addProviderStepTitle').textContent = 'Pilih Model';
      // Show valid state on verify button
      if (verifyLabel) { verifyLabel.textContent = 'Valid'; }
      if (verifyBtn) { verifyBtn.disabled = false; verifyBtn.classList.remove('btn-accent-soft'); verifyBtn.classList.add('btn-success'); verifyBtn.style.pointerEvents = 'none'; }
      showToast('API Key valid! ' + models.length + ' model ditemukan.', 'success');
    } catch (e) {
      if (verifyLabel) verifyLabel.textContent = 'Verify';
      if (verifyBtn) verifyBtn.disabled = false;
      showToast('Gagal verifikasi: ' + e.message, 'error');
    }
  }

  //     Render Provider List (Step 1   searchable radio list)    
  var _selectedProviderIdx = -1;

  function renderProviderList(query) {
    var container = document.getElementById('providerRadioList');
    if (!container) return;
    if (typeof PROVIDER_LIST === 'undefined') { container.innerHTML = '<div style="padding:20px;text-align:center;color:var(--text-muted);font-size:12px">Memuat daftar provider...</div>'; return; }

    var filtered = PROVIDER_LIST;
    if (query && query.trim()) {
      var q = query.toLowerCase().trim();
      filtered = PROVIDER_LIST.filter(function(p) {
        return p.name.toLowerCase().includes(q) || (p.type && p.type.toLowerCase().includes(q));
      });
    }

    if (filtered.length === 0) {
      container.innerHTML = '<div style="padding:20px;text-align:center;color:var(--text-muted);font-size:12px">Provider tidak ditemukan</div>';
      document.getElementById('settingsContinueBtn').disabled = true;
      return;
    }

    container.innerHTML = '';
    filtered.forEach(function(p, i) {
      var idx = PROVIDER_LIST.indexOf(p);
      var isSelected = (idx === _selectedProviderIdx);
      var card = document.createElement('div');
      card.className = 'prov-radio-item' + (isSelected ? ' selected' : '');
      card.style.marginBottom = '6px';
      card.onclick = function() {
        // Deselect all
        container.querySelectorAll('.prov-radio-item').forEach(function(c) { c.classList.remove('selected'); });
        card.classList.add('selected');
        _selectedProviderIdx = idx;
        // Enable continue button
        var settingsBtn = document.getElementById('settingsContinueBtn');
        if (settingsBtn) settingsBtn.disabled = false;
        // Store selected provider info
        selectedProvider = p;
        // Update detail form with provider info
        document.getElementById('detailProviderName').textContent = p.name;
        document.getElementById('detailProviderDesc').textContent = (p.type || 'custom') + ' · verify API Key untuk lihat model';
        document.getElementById('detailBaseUrl').value = p.baseUrl || '';
        // Sync to hidden fields
        var hBaseUrl = document.getElementById('settingsBaseUrl');
        if (hBaseUrl) hBaseUrl.value = p.baseUrl || '';
        var hProviderName = document.getElementById('selectedProviderName');
        if (hProviderName) hProviderName.textContent = p.name;
      };
      var iconEl = p.type === 'anthropic' ? '🤖' : p.type === 'openai' ? '🟢' : p.type === 'openrouter' ? '🀀' : p.type === 'gemini' ? '🀵' : p.type === 'sumopod' ? '⚡' : '🀌';
      var subtitle = (p.type || 'custom') + (p.baseUrl ? '  ' + p.baseUrl.replace('https://','').split('/')[0] : '') + ' · verify utk model';
      card.innerHTML = '<div class="cat-card-inner" style="height:auto;padding:12px;flex-direction:row;justify-content:flex-start;gap:12px">' +
        '<div style="width:32px;height:32px;border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:13px;background:rgba(0,224,143,0.08);border:1px solid rgba(0,224,143,0.12);flex-shrink:0">' + iconEl + '</div>' +
        '<div style="flex:1;min-width:0"><div class="text-[12px] font-semibold" style="color:var(--text)">' + p.name + '</div>' +
        '<div class="text-[10px]" style="color:var(--text-muted)">' + subtitle + '</div></div>' +
        (isSelected ? '<div style="color:var(--accent);font-size:14px;flex-shrink:0">✓</div>' : '') +
        '</div>';
      container.appendChild(card);
    });
  }

  function filterProviderList(q) {
    renderProviderList(q || '');
  }

  //     Wizard Page    
  function initWizard() {
    wizardStep = 1;
    // Reset AI state -- user must click generate
    window._aiIdeas = null;
    window._aiTechRec = null;
    // Clear stale product data if not from setup (no category = not through setup page)
    if (state && !state.productCatName && !state.productCategory) {
      state.productName = '';
      state.idea = '';
    }
    // Fill context bar
    var ctx = document.getElementById('contextBar');
    if (ctx) {
      var parts = [];
      if (state && state.productName) parts.push('<span class="text-[12px] font-semibold" style="color:var(--text)">' + escapeHtml(state.productName) + '</span>');
      var type = state && state.productType ? state.productType : selectedType || 'Web App';
      if (type === 'web') type = 'Web App';
      else if (type === 'mobile') type = 'Mobile App';
      else if (type === 'api') type = 'API / Backend';
      parts.push('<span class="ctx-chip">' + escapeHtml(type) + '</span>');
      if (state && state.productCatName) parts.push('<span class="ctx-chip">' + escapeHtml(state.productCatName) + '</span>');
      if (state && state.productCategory) parts.push('<span class="ctx-chip">' + escapeHtml(state.productCategory) + '</span>');
      ctx.innerHTML = parts.join('');
    }
    // Restore or reset survey questions
    if (state) {
      if (state.savedQuestions && Array.isArray(state.savedQuestions) && state.savedQuestions.length > 0) {
        // Restore persisted questions   keep surveyMode so survey renders directly
        _surveyQuestions = state.savedQuestions;
        state.surveyTotal = _surveyQuestions.length;
      } else {
        // No saved questions   reset to mode picker
        state.surveyTotal = 0;
        state.surveyMode = '';
        _surveyQuestions = [];
      }
      state.surveyQ = 0;
    }
    updateWizSteps();
    renderWizStep();
  }

  function updateWizSteps() {
    document.querySelectorAll('#page-wizard .step').forEach(function(el, idx) {
      var stepNum = idx + 1;
      el.classList.toggle('active', stepNum === wizardStep);
      el.classList.toggle('visited', stepNum < wizardStep);
    });
  }

  function initModePickerGlow() {
    var surveyCard = document.getElementById('surveyCard');
    if (!surveyCard) return;
    var modePicker = document.getElementById('modePickerCards');
    if (!modePicker) return;
    modePicker.addEventListener('mouseenter', function() {
      surveyCard.classList.add('suppress-glow');
    });
    modePicker.addEventListener('mouseleave', function() {
      surveyCard.classList.remove('suppress-glow');
    });
  }

  function renderWizStep() {
    var container = document.getElementById('wizardContent');
    if (!container) return;
    if (typeof state !== 'undefined') { state.step = wizardStep; }
    if (wizardStep === 1) { container.innerHTML = renderStep1HTML(); }
    else if (wizardStep === 2) {
      container.innerHTML = renderStep3HTML();
      // Survey: render existing questions if available (NO auto-regenerate)
      if (state.surveyMode && _surveyQuestions && _surveyQuestions.length > 0) {
        setTimeout(function() {
          if (typeof renderSurvey === 'function') renderSurvey();
        }, 100);
      }
      setTimeout(function() {
        if (typeof initModePickerGlow === 'function') initModePickerGlow();
      }, 50);
    }
    else if (wizardStep === 3) {
      container.innerHTML = renderStep2HTML();
      var sc = document.getElementById('techSubcards');
      if (sc) sc.innerHTML = renderTechSubcardsHTML();
      setTimeout(function() {
        if (typeof renderExtras === 'function') renderExtras();
        // AI rec is triggered manually via button in separate card
        if (typeof renderAITechContainer === 'function') renderAITechContainer();
      }, 50);
    } else if (wizardStep === 4) {
      container.innerHTML = renderStep4HTML();
    }
  }

  function renderStep1HTML() {
    var idea = (typeof state !== 'undefined') ? (state.idea || '') : '';
    var name = (typeof state !== 'undefined') ? (state.productName || '') : '';
    var ptype = (typeof state !== 'undefined') ? (state.productType || selectedType || 'Web App') : (selectedType || 'Web App');
    if (typeof state !== 'undefined' && state.productName && !name) {
      state.productName = document.getElementById('productName') ? document.getElementById('productName').value : '';
    }
    // Get type for display
    var displayType = ptype;
    if (displayType === 'web') displayType = 'Web App';
    else if (displayType === 'mobile') displayType = 'Mobile App';
    else if (displayType === 'api') displayType = 'API / Backend';
    else if (displayType === 'desktop') displayType = 'Desktop App';
    // Build contoh ide content -- show generate button or existing ideas
    var exampleIdeasHtml = '';
    if (window._aiIdeas && window._aiIdeas.length) {
      exampleIdeasHtml = window._aiIdeas.map(function(idea, i) {
        return '<span class="chip" onclick="previewAIExampleIdea(' + i + ')">' +
          escapeHtml(idea.title || 'Ide ' + (i+1)) +
          '</span>';
      }).join('');
      exampleIdeasHtml += '<button class="btn-accent-soft text-[11px] ml-auto" onclick="generateAIExampleIdeas()" title="Cari ide lain" style="padding:4px 10px;flex-shrink:0;white-space:nowrap">'+iconSvg('refresh',12)+' Lainnya</button>';
    } else {
      exampleIdeasHtml = '<div class="flex items-center gap-2 w-full"><button class="btn-accent-soft text-[11px]" onclick="generateAIExampleIdeas()" style="padding:5px 12px">'+iconSvg('zap',12)+' Cari Ide dengan AI</button><span class="text-[10px]" style="color:var(--text-muted)">Dapatkan saran ide berdasarkan produkmu</span></div>';
    }

    return '<div class="stagger">' +

      // Card 1: Contoh Ide / AI recommendations   FIRST
      '<div class="stagger" style="animation-delay:0.05s"><div class="card" style="--accent:#3B82F6"><div class="card-inner !p-4 sm:!p-5">' +
      '<h3 class="text-[12px] font-semibold mb-2" style="color:var(--text-muted)">Contoh Ide</h3>' +
      '<p class="text-[10px] mb-2" style="color:var(--text-muted)">Inspirasi dari AI berdasarkan nama produkmu.</p>' +
      '<div id="wizExampleIdeas" class="flex flex-wrap gap-2 items-center">' + exampleIdeasHtml + '</div>' +
      '</div></div></div>' +

      // Card 2: Idea textarea + Kembangkan dengan AI   SECOND
      '<div class="stagger mt-4 sm:mt-5" style="animation-delay:0.12s"><div class="card" style="--accent:#A855F7"><div class="card-inner !p-4 sm:!p-6">' +
      '<h2 class="text-base sm:text-lg font-bold mb-1" style="color:var(--text)">Deskripsikan ide kamu</h2>' +
      '<p class="text-[11px] sm:text-[12px] mb-3 sm:mb-4" style="color:var(--text-muted)">Tulis ide kamu sendiri atau pilih dari contoh di atas.</p>' +
      '<input type="text" id="wizProductName" class="survey-input mb-3" placeholder="Nama produk" value="' + escapeHtml(name) + '" oninput="if(typeof state!==\'undefined\'){state.productName=this.value;var sp=document.getElementById(\'productName\');if(sp)sp.value=this.value;if(typeof saveState===\'function\')saveState()}">' +
      '<textarea id="ideaText" class="survey-input min-h-[100px] sm:min-h-[120px]" placeholder="Deskripsi ide kamu..." oninput="var c=document.getElementById(\'charCount\');if(c)c.textContent=this.value.length+\' karakter\';if(typeof state!==\'undefined\'){state.idea=this.value;if(typeof saveState===\'function\')saveState()}">' + escapeHtml(idea) + '</textarea>' +
      '<div class="flex flex-col sm:flex-row justify-between items-start sm:items-center mt-2 sm:mt-3 gap-2">' +
      '<span class="text-[11px]" style="color:var(--text-muted)" id="charCount">' + idea.length + ' karakter</span>' +
      '<button class="btn-accent-soft text-[11px]" id="expandBtn" onclick="expandIdeaWithAI()" style="padding:5px 12px">'+iconSvg('zap',12)+' Kembangkan dengan AI</button>' +
      '</div></div></div></div>' +

      '<div class="wizard-nav stagger mt-5" style="animation-delay:0.28s">' +
      '<div></div>' +
      '<button class="btn-primary rounded-xl font-semibold text-sm" onclick="goWizardStep(2)" style="border:none">Lanjut ke Survey →</button>' +
      '</div></div>';
  }

function fillWizIdea(nama, ideaText) {
    var t = document.getElementById('ideaText');
    var n = document.getElementById('wizProductName');
    var c = document.getElementById('charCount');
    if (t) t.value = ideaText;
    if (n) n.value = nama;
    if (c) c.textContent = (ideaText || '').length + ' karakter';
    if (typeof state !== 'undefined') {
      state.idea = ideaText || '';
      state.productName = nama || '';
      if (typeof saveState === 'function') saveState();
    }
  }

  //     Tech Selection    
  function selectTech(el) {
    var grid = document.getElementById('techGrid');
    if (grid) {
      grid.querySelectorAll('.chip').forEach(function(c) { c.classList.remove('selected'); });
    }
    el.classList.add('selected');
    selectedTech = el.dataset.tech;
    techRecommended = false;
    // Update AI suggestion
    var aiChips = document.getElementById('aiChips');
    if (aiChips) {
      var found = null;
      var type = (typeof state !== 'undefined' && state.productType) || selectedType || 'Web App';
      if (type === 'web') type = 'Web App';
      var techs = TECH_BY_TYPE[type] || TECH_BY_TYPE['Web App'];
      techs.forEach(function(t) { if (t.tech === selectedTech) found = t; });
      var desc = found ? found.desc : 'Dipilih manual';
      aiChips.innerHTML = '<span class="chip selected" style="color:var(--text-muted);background:rgba(255,255,255,0.04);border-color:var(--border);cursor:default">🀧 ' + escapeHtml(selectedTech) + '</span><span class="text-[10px] mt-1" style="color:var(--text-muted)">' + desc + '</span>';
    }
  }

  // Global techNameToId (hoisted from generateAITechRecommendation)
function techNameToId(cat, name) {
  if (!name) return 'ai-pilih';
  var opts = TECH_OPTIONS[cat] || [];
  var n = (name || '').toLowerCase().trim();
  for (var i = 0; i < opts.length; i++) {
    if (opts[i][1].toLowerCase() === n || opts[i][0].toLowerCase() === n) return opts[i][0];
  }
  return 'ai-pilih';
}

// Toggle tech accordion card   only one open at a time
function toggleTechAccordion(cat) {
  if (window._openTechCard === cat) {
    // Close it
    window._openTechCard = null;
  } else {
    // Open this one, close previous
    window._openTechCard = cat;
  }
  var sc = document.getElementById('techSubcards');
  if (sc) sc.innerHTML = renderTechSubcardsHTML();
}

// Select tech for a category   toggle multi-select
function selectTechSub(cat, val, el) {
  window._pendingTech = window._pendingTech || {};
  var current = window._pendingTech[cat] ? window._pendingTech[cat].split(',') : [];
  var idx = current.indexOf(val);
  if (idx >= 0) {
    current.splice(idx, 1); // deselect
  } else {
    current.push(val); // select
  }
  window._pendingTech[cat] = current.join(',');
  // Re-render subcards to show pending state
  var container = document.getElementById('techSubcards');
  if (container) {
    container.innerHTML = renderTechSubcardsHTML();
  }
  renderExtras();
}
// Confirm pending tech selection (supports multi-select)
function confirmTechSelection(cat) {
  window._pendingTech = window._pendingTech || {};
  var val = window._pendingTech[cat];
  if (!val) return;
  state.tech[cat] = val;
  if (typeof saveState === 'function') saveState();
  delete window._pendingTech[cat];
  // Close accordion after confirm
  if (window._openTechCard === cat) window._openTechCard = null;
  var container = document.getElementById('techSubcards');
  if (container) {
    container.innerHTML = renderTechSubcardsHTML();
  }
  if (typeof renderAITechContainer === 'function') renderAITechContainer();
}

// Cancel pending tech selection
function cancelTechSelection(cat) {
  window._pendingTech = window._pendingTech || {};
  delete window._pendingTech[cat];
  if (window._openTechCard === cat) window._openTechCard = null;
  var container = document.getElementById('techSubcards');
  if (container) {
    container.innerHTML = renderTechSubcardsHTML();
  }
}

// Edit already-confirmed tech selection (multi-select)
function editTechSelection(cat) {
  var current = state.tech[cat] || '';
  window._pendingTech = window._pendingTech || {};
  window._pendingTech[cat] = current; // pre-fill pending with current selections
  state.tech[cat] = '';
  if (typeof saveState === 'function') saveState();
  window._openTechCard = cat; // Open the accordion for editing
  var container = document.getElementById('techSubcards');
  if (container) {
    container.innerHTML = renderTechSubcardsHTML();
  }
}

// Re-render just the tech sub-cards (after selection)
function renderTechSubcardsHTML() {
  window._pendingTech = window._pendingTech || {};
  var aiRec = window._aiTechRec || null;
  var cats = [
    { id: 'frontend', icon: 'monitor', label: 'Frontend', accent: '#3B82F6' },
    { id: 'backend', icon: 'server', label: 'Backend', accent: '#22C55E' },
    { id: 'database', icon: 'database', label: 'Database', accent: '#F59E0B' },
    { id: 'deployment', icon: 'cloud', label: 'Deployment', accent: '#A855F7' },
  ];
  var html = '';

  // ═══ TECH ACCORDION CARDS ═══
  html += '<div class="tech-accordion">';
  cats.forEach(function(cat) {
    var confirmedVal = state.tech[cat.id] || 'ai-pilih';
    var pendingVal = window._pendingTech[cat.id] || null;
    var isConfirmed = confirmedVal !== 'ai-pilih';
    var isPending = !isConfirmed && pendingVal !== null;
    var activeVal = pendingVal || confirmedVal;
    var opts = TECH_OPTIONS[cat.id] || [];

    function findLabel(id) {
      var f = opts.find(function(o) { return o[0] === id; });
      return f ? f[1] : id;
    }

    // Determine if this card should be open
    var isOpen = window._openTechCard === cat.id;
    var accent = cat.accent;

    html += '<div class="tech-accord-card' +
      (isConfirmed ? ' locked' : '') +
      (isOpen ? ' open' : '') +
      '" style="--accord-accent:' + accent + '" data-cat="' + cat.id + '">' +
      '<div class="tech-accord-inner">' +

      //    Header (always visible)   
      '<div class="tech-accord-header"' +
      (isConfirmed ? '' : ' onclick="toggleTechAccordion(\'' + cat.id + '\')"') +
      '>' +
      '<span class="tech-accord-icon">' + iconSvg(cat.icon, 13) + '</span>' +
      '<span class="tech-accord-title">' + cat.label + '</span>';

    if (isConfirmed) {
      // Handle comma-separated multi-select
      var confirmedLabels = confirmedVal.split(',').map(function(id) { return findLabel(id); }).filter(Boolean);
      var confirmedLabel = escapeHtml(confirmedLabels.join(', '));
      html += '<span class="tech-accord-status selected">' + confirmedLabel + ' ' + iconSvg('check', 12) + '</span>';
      html += '<span class="tech-accord-edit" onclick="event.stopPropagation();editTechSelection(\'' + cat.id + '\')">Edit</span>';
    } else if (isPending) {
      var pendingIds = pendingVal.split(',');
      var pendingLabels = pendingIds.map(function(id) { return findLabel(id); }).filter(Boolean);
      html += '<span class="tech-accord-status pending">' + escapeHtml(pendingLabels.join(', ')) + '</span>';
    } else {
      html += '<span class="tech-accord-status selectable">Pilih</span>';
    }

    html += '</div>'; // end header

    //    Body (expandable)   
    html += '<div class="tech-accord-body">' +
      '<div class="tech-accord-body-inner">' +
      '<div class="tech-accord-options">';

    var optsList = opts.slice();

    var activeIds = typeof activeVal === 'string' ? activeVal.split(',') : [];
    optsList.forEach(function(opt) {
      // Skip the "Biarkan AI pilih" option
      if (opt[0] === 'ai-pilih') return;
      var sel = activeIds.indexOf(opt[0]) >= 0 ? ' selected' : '';
      var isAiRec = false;
      if (aiRec && aiRec[cat.id] && aiRec[cat.id].rec) {
        isAiRec = opt[1].toLowerCase() === aiRec[cat.id].rec.toLowerCase() || opt[0] === techNameToId(cat.id, aiRec[cat.id].rec);
      }
      html += '<span class="chip' + sel + '" onclick="selectTechSub(\'' + cat.id + "','" + opt[0] + "',this)\">" +
        escapeHtml(opt[1]) +
        (opt[2] ? ' <span class="tech-free">Gratis</span>' : '') +
        (isAiRec && !sel ? ' <span class="tech-free" style="background:rgba(168,85,247,0.10);color:#A855F7">AI</span>' : '') +
        '</span>';
    });

    html += '</div>'; // end options

    // Confirm/Cancel bar
    if (isPending) {
      html += '<div class="tech-accord-confirm">' +
        '<button class="btn-primary btn-sm" onclick="confirmTechSelection(\'' + cat.id + '\')" style="border:none">Konfirmasi Pilihan</button>' +
        '<button class="btn-ghost btn-sm" onclick="cancelTechSelection(\'' + cat.id + '\')">Batal</button>' +
        '</div>';
    }

    html += '</div></div>'; // end body-inner, body
    html += '</div></div>'; // end accord-inner, accord-card
  });
  html += '</div>'; // end tech-accordion

  return html;
}

// ═══ AI Tech Recommendation Panel (rendered in separate card) ═══
function renderAITechContainer() {
  var container = document.getElementById('aiTechRecContainer');
  if (!container) return;
  var aiRec = window._aiTechRec;
  var cats = [
    { id: 'frontend', icon: 'monitor', label: 'Frontend', accent: '#3B82F6' },
    { id: 'backend', icon: 'server', label: 'Backend', accent: '#22C55E' },
    { id: 'database', icon: 'database', label: 'Database', accent: '#F59E0B' },
    { id: 'deployment', icon: 'cloud', label: 'Deployment', accent: '#A855F7' },
  ];

  if (aiRec && aiRec.frontend && aiRec.frontend.rec) {
    var allApplied = true;
    var html = '<div class="ai-rec-items">';

    cats.forEach(function(cat) {
      var recData = aiRec[cat.id];
      if (!recData || !recData.rec) return;
      var appliedIds = state.tech[cat.id] ? state.tech[cat.id].split(',') : [];
      var neededIds = recPartIds(cat.id, recData.rec);
      var isApplied = neededIds.length > 0 && neededIds.every(function(id) { return appliedIds.indexOf(id) >= 0; });
      if (!isApplied) allApplied = false;
      var accent = cat.accent;
      var appliedClass = isApplied ? ' applied' : '';
      html += '<div class="ai-rec-item' + appliedClass + '" style="--rec-accent:' + accent + '">' +
        '<div class="ai-rec-item-icon" style="color:' + accent + '">' + iconSvg(cat.icon, 12) + '</div>' +
        '<div class="ai-rec-item-info">' +
        '<div class="ai-rec-item-cat">' + cat.label + '</div>' +
        '<div class="ai-rec-item-name">' + escapeHtml(recData.rec) + '</div>' +
        '<div class="ai-rec-item-reason">' + (recData.reason ? escapeHtml(recData.reason.substring(0, 120)) : '') + '</div>' +
        '</div>' +
        (isApplied
          ? '<span class="ai-rec-item-apply applied">' + iconSvg('check', 11) + ' Terpakai</span>'
          : '<button class="ai-rec-item-apply" onclick="applyAITechRec(\'' + cat.id + '\')">' + iconSvg('check', 11) + ' Terapkan</button>'
        ) +
        '</div>';
    });

    html += '</div>';
    html += '<div class="ai-rec-footer">' +
      '<button class="ai-rec-apply-all" onclick="applyAllAITechRec()"' + (allApplied ? ' disabled' : '') + '>' + iconSvg('zap', 12) + ' Terapkan Semua</button>' +
      '</div>';
    container.innerHTML = html;
  } else if (window._aiTechRecLoading) {
    // Still loading — inline kaya ide step (spinner kiri, teks kanan)
    container.innerHTML = '<span class="loading-ai">' +
      '<span class="spinner-ring"></span>' +
      '<span class="text-[11px]" style="color:var(--text-muted)">Mencari inspirasi...</span></span>';
  } else {
    // No rec yet — show generate button (null init or not loaded)
    container.innerHTML = '<button class="btn-accent-soft text-[11px]" onclick="generateAITechRecommendation()" style="padding:5px 12px">' + iconSvg('zap', 11) + ' Dapatkan Rekomendasi</button>';
  }
}

function renderStep2HTML() {
    if (typeof state !== 'undefined') {
      state.tech = {};  // always start fresh — user picks each time
      state.extras = [];
    }
    return '<div class="stagger">' +

      // Card 1: Tech Selection (main card)
      '<div class="stagger" style="animation-delay:0.05s"><div class="card" style="--accent:#3B82F6"><div class="card-inner !p-5 sm:!p-7">' +
      '<h2 class="text-lg sm:text-xl font-bold mb-1" style="color:var(--text)">Pilih Teknologi</h2>' +
      '<p class="text-[12px] sm:text-[13px] mb-4" style="color:var(--text-muted)">Pilih sendiri stack teknologi yang kamu kuasai atau ingin pelajari.</p>' +
      '<div id="techSubcards"></div>' +
      '<div class="mt-4"><h3 class="text-[12px] font-semibold mb-0.5" style="color:var(--text)">Extra Features</h3>' +
      '<p class="text-[9px] mb-2" style="color:var(--text-muted)">Fitur tambahan yang relevan dengan produkmu.</p>' +
      '<div class="flex flex-wrap gap-1.5" id="extraChips"></div></div>' +
      '</div></div></div>' +

      // Card 2: AI Recommendation — sama ukuran dg card Contoh Ide
      '<div class="stagger mt-2 sm:mt-3" style="animation-delay:0.18s"><div class="card" style="--accent:#A855F7"><div class="card-inner !p-4 sm:!p-5">' +
      '<h3 class="text-[12px] font-semibold mb-2" style="color:var(--text-muted)">Rekomendasi AI</h3>' +
      '<p class="text-[10px] mb-2" style="color:var(--text-muted)">Bantuan pilih stack teknologi dari AI berdasarkan ide &amp; survey kamu.</p>' +
      '<div id="aiTechRecContainer"></div>' +
      '</div></div></div>' +
      '<div class="wizard-nav mt-3">' +
      '<button class="btn-ghost rounded-xl font-semibold text-sm" onclick="goWizardStep(2)">Kembali</button>' +
      '<button class="btn-primary rounded-xl font-semibold text-sm" id="goStep4Btn" onclick="goStep4FromTech()" style="border:none">Lanjut ke Blueprint →</button>' +
      '</div>';
  }
function hexToRgb(hex) {
  var r = parseInt(hex.slice(1,3), 16);
  var g = parseInt(hex.slice(3,5), 16);
  var b = parseInt(hex.slice(5,7), 16);
  return r + ',' + g + ',' + b;
}


// Show mode picker again (toggle from inside survey)
function showModePicker() {
  state.surveyMode = '';
  if (typeof saveState === 'function') saveState();
  renderWizStep();
}


function renderModePickerHTML() {
    var modes = [
        { id: "quick", icon: "zap", label: "Cepat", phrase: "3-5 pertanyaan • hasil instan", color: "#F59E0B" },
        { id: "smart", icon: "layers", label: "Smart", phrase: "7-10 pertanyaan • hasil detail", color: "#34D399" },
        { id: "comprehensive", icon: "target", label: "Komprehensif", phrase: "15+ pertanyaan • hasil maksimal", color: "#A855F7" }
    ];
    return modes.map(function(m) {
        var selected = state.surveyMode === m.id ? " featured" : "";
        return '<div class="card' + selected + '" style="--accent:' + m.color + '" data-mode="' + m.id + '" onclick="selectSurveyMode(this.dataset.mode)">' +
            '<div class="card-inner">' +
            '<div>' +
            '<div class="icon-wrap">' + iconSvg(m.icon, 18) + '</div>' +
            '<div class="text-sm font-bold">' + m.label + '</div>' +
            '<div class="mode-phrase">' + m.phrase + '</div>' +
            '</div></div></div>';
    }).join("");
}

function renderStep3HTML() {
    // If no survey mode selected yet, show mode picker
        if (!state.surveyMode) {
      return '<div class="stagger"><div class="card" id="surveyCard" style="--accent:#22C55E"><div class="card-inner !p-4 sm:!p-6">' +
        '<h2 class="text-base sm:text-lg font-bold mb-1" style="color:var(--text)">Pilih Mode Survey</h2>' +
        '<p class="text-[11px] sm:text-[12px] mb-4" style="color:var(--text-muted)">Semakin detail, semakin akurat blueprint yang dihasilkan.</p>' +
        '<div id="modePickerCards">' + renderModePickerHTML() + '</div>' +
        '<div id="surveyLoading" class="mt-4 text-center" style="display:none">' +
        '<div class="loading-ai justify-center"><div class="spinner-ring"></div></div>' +
        '<div class="text-[12px] mt-2 animate-pulse" style="color:var(--text-muted)">Menggenerate pertanyaan...</div></div>' +
        '</div></div></div>' +
        '<div class="wizard-nav">' +
        '<button class="btn-ghost rounded-xl font-semibold text-sm" onclick="goWizardStep(1)">Kembali</button>' +
        '<div></div></div>';
    } else { // mode selected — show questions
    return '<div class="stagger"><div class="card" style="--accent:#22C55E"><div class="card-inner !p-4 sm:!p-6">' +
      '<h2 class="text-base sm:text-lg font-bold mb-1" style="color:var(--text)">Survey Adaptif</h2>' +
      '<p class="text-[11px] sm:text-[12px] mb-3 sm:mb-4" style="color:var(--text-muted)">Jawab pertanyaan berikut untuk memperkaya konteks AI.</p>' +
      '<div id="surveyContainer"></div>' +
      '</div></div></div>' +
      '<div class="wizard-nav">' +
      '<button class="btn-ghost rounded-xl font-semibold text-sm" onclick="goWizardStep(1)">Kembali</button>' +
      '<button class="btn-primary rounded-xl font-semibold text-sm" onclick="surveyGoNext()" style="border:none">Lanjut →</button>' +
      '</div>';
  }
}

//     Step 4: Result / Review    
function renderStep4HTML() {
    if (typeof state === 'undefined') return '<div class="text-center py-10" style="color:var(--text-muted)">Loading...</div>';
    var name = state.productName || 'Produk';
    var idea = state.idea || '';
    var ptype = state.productType || 'Web App';
    var displayType = ptype;
    if (displayType === 'web') displayType = 'Web App';
    else if (displayType === 'mobile') displayType = 'Mobile App';
    else if (displayType === 'api') displayType = 'API / Backend';
    else if (displayType === 'desktop') displayType = 'Desktop App';

    // Survey stats
    var totalQ = state.surveyTotal || 0;
    var answered = 0;
    if (state.answers && totalQ > 0) {
        for (var k in state.answers) { var v = state.answers[k]; if (v) { if (typeof v === 'string') { if (v.trim()) answered++; } else if (Array.isArray(v)) { if (v.length) answered++; } else { answered++; } } }
    }
    var pct = totalQ > 0 ? Math.round(answered / totalQ * 100) : 0;

    // Tech stack
    var tech = state.tech || {};
    var aiRec = window._aiTechRec || null;
    var layers = [
        { key: 'frontend', icon: 'monitor', label: 'Frontend', color: '#3B82F6' },
        { key: 'backend', icon: 'server', label: 'Backend', color: '#22C55E' },
        { key: 'database', icon: 'database', label: 'Database', color: '#F59E0B' },
        { key: 'deployment', icon: 'cloud', label: 'Deploy', color: '#A855F7' },
    ];

    function getTechLabel(cat, id) {
        if (!id || id === 'ai-pilih') return 'AI pilih';
        var opts = TECH_OPTIONS[cat] || [];
        var found = opts.find(function(o) { return o[0] === id; });
        return found ? found[1] : id;
    }

    // Extra features
    var extras = state.extras || [];
    var extraLabels = extras.map(function(e) {
        var found = EXTRA_OPTIONS.find(function(o) { return o[0] === e; });
        return found ? found[1] : e;
    });

    // Survey mode
    var modeLabels = { cepat: 'Cepat', standar: 'Standar', mendalam: 'Mendalam' };
    var modeColors = { cepat: '#22C55E', standar: '#3B82F6', mendalam: '#A855F7' };
    var modeId = state.surveyMode || 'standar';
    var modeLabel = modeLabels[modeId] || 'Standar';
    var modeColor = modeColors[modeId] || '#3B82F6';

    // Domain icon based on product type
    var typeIcons = { 'Web App': 'monitor', 'Mobile App': 'smartphone', 'API / Backend': 'server', 'Desktop App': 'code' };
    var typeIcon = typeIcons[displayType] || 'monitor';

    var html = '<div class="stagger">';

    //    Product Summary Card   
    html += '<div class="card" style="--accent:#A855F7"><div class="card-inner !p-4 sm:!p-6">' +
        '<div class="flex items-start gap-3 mb-3">' +
        '<div class="flex-shrink-0 w-11 h-11 rounded-2xl flex items-center justify-center text-base" style="background:rgba(168,85,247,0.12);border:1px solid rgba(168,85,247,0.25);color:#A855F7">' + iconSvg(typeIcon, 18) + '</div>' +
        '<div class="flex-1 min-w-0">' +
        '<h2 class="text-base sm:text-lg font-bold truncate" style="color:var(--text)">' + escapeHtml(name) + '</h2>' +
        '<div class="flex flex-wrap items-center gap-2 mt-1">' +
        '<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-semibold" style="background:rgba(59,130,246,0.10);border:1px solid rgba(59,130,246,0.2);color:#60A5FA">' + iconSvg(typeIcon, 9) + ' ' + escapeHtml(displayType) + '</span>' +
        '<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-semibold" style="background:rgba(' + hexToRgb(modeColor) + ',0.10);border:1px solid rgba(' + hexToRgb(modeColor) + ',0.2);color:' + modeColor + '">' + iconSvg('layers', 9) + ' ' + modeLabel + '</span>' +
        '</div></div></div>' +
        (idea ? '<p class="text-[12px] leading-relaxed mb-0" style="color:var(--text-muted)">' + escapeHtml(idea.length > 180 ? idea.slice(0, 180) + '...' : idea) + '</p>' : '') +
        '</div></div></div>';

    //    Survey Stats Card   
    html += '<div class="stagger mt-4 sm:mt-5" style="animation-delay:0.12s"><div class="card" style="--accent:#22C55E"><div class="card-inner !p-4 sm:!p-5">' +
        '<div class="flex items-center justify-between mb-2">' +
        '<h3 class="text-[13px] font-bold" style="color:var(--text)">' + iconSvg('target', 13) + ' Survey</h3>' +
        '<span class="text-[11px] font-semibold" style="color:' + (pct >= 100 ? '#22C55E' : '#F59E0B') + '">' + answered + '/' + totalQ + ' terjawab</span>' +
        '</div>' +
        '<div class="h-1.5 rounded-full overflow-hidden" style="background:rgba(255,255,255,0.06)">' +
        '<div class="h-full rounded-full transition-all duration-700" style="width:' + pct + '%;background:linear-gradient(90deg,#22C55E,#10B981)"></div>' +
        '</div>' +
        '<div class="flex items-center gap-2 mt-2">' +
        '<span class="text-[10px]" style="color:var(--text-muted)">Mode: </span>' +
        '<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold" style="background:rgba(' + hexToRgb(modeColor) + ',0.10);border:1px solid rgba(' + hexToRgb(modeColor) + ',0.2);color:' + modeColor + '">' + iconSvg('zap', 8) + ' ' + modeLabel + '</span>' +
        '</div></div></div></div>';

    //    Tech Stack Card   
    html += '<div class="stagger mt-4 sm:mt-5" style="animation-delay:0.20s"><div class="card" style="--accent:#3B82F6"><div class="card-inner !p-4 sm:!p-5">' +
        '<h3 class="text-[13px] font-bold mb-3" style="color:var(--text)">' + iconSvg('layers', 13) + ' Tech Stack</h3>' +
        '<div class="flex flex-col gap-2">';

    layers.forEach(function(l) {
        var val = tech[l.key] || 'ai-pilih';
        var label = getTechLabel(l.key, val);
        // Check if this is AI recommended
        var isAiRec = aiRec && aiRec[l.key] && aiRec[l.key].rec &&
            (val === 'ai-pilih' || label.toLowerCase() === aiRec[l.key].rec.toLowerCase());
        html += '<div class="flex items-center gap-2.5 py-1.5 px-3 rounded-xl" style="background:rgba(' + hexToRgb(l.color) + ',0.05)">' +
            '<span style="color:' + l.color + '">' + iconSvg(l.icon, 13) + '</span>' +
            '<span class="text-[11px] font-medium" style="color:var(--text-muted);min-width:58px">' + l.label + '</span>' +
            '<span class="text-[12px] font-semibold" style="color:var(--text)">' + escapeHtml(label) + '</span>' +
            (isAiRec ? '<span class="ml-auto flex items-center gap-1 text-[9px] font-semibold px-1.5 py-0.5 rounded-full" style="background:rgba(168,85,247,0.10);color:#A855F7">' + iconSvg('zap', 7) + ' AI</span>' : '') +
            '</div>';
    });

    // Extras
    if (extraLabels.length > 0) {
        html += '<div class="flex items-start gap-2.5 py-1.5 px-3 rounded-xl" style="background:rgba(236,72,153,0.05)">' +
            '<span style="color:#EC4899;margin-top:2px">' + iconSvg('code', 13) + '</span>' +
            '<span class="text-[11px] font-medium" style="color:var(--text-muted);min-width:58px">Ekstra</span>' +
            '<div class="flex flex-wrap gap-1.5">' +
            extraLabels.map(function(el) { return '<span class="text-[11px] px-2 py-0.5 rounded-full font-medium" style="background:rgba(236,72,153,0.08);border:1px solid rgba(236,72,153,0.15);color:#F472B6">' + escapeHtml(el) + '</span>'; }).join('') +
            '</div></div>';
    }

    html += '</div></div></div></div>';

    //    Action Buttons   
    html += '<div class="wizard-nav stagger mt-5" style="animation-delay:0.28s">' +
        '<button class="btn-ghost rounded-xl font-semibold text-sm" onclick="goWizardStep(3)">Kembali</button>' +
        '<button class="btn-primary rounded-xl font-semibold text-sm" onclick="generateFromWizard()" style="border:none">' + iconSvg('zap', 14) + ' Generate Blueprint</button>' +
        '</div></div>';

    return html;
}

function generateFromWizard() {
    if (typeof generateBlueprint === 'function') {
        generateBlueprint();
    } else {
        showToast('Fitur generate sedang disiapkan', 'info');
    }
}


function goStep4FromTech() {
    state.tech = state.tech || {};
    var cats = ['frontend', 'backend', 'database', 'deployment'];
    var allConfirmed = cats.every(function(c) { return state.tech[c] && state.tech[c] !== 'ai-pilih'; });
    if (!allConfirmed) {
      showToast('Pilih teknologi untuk semua kategori dulu (atau klik "Terapkan Semua" dari rekomendasi AI)', 'warning');
      return;
    }
    goWizardStep(4);
  }

  function goWizardStep(n) {
    if (n >= 1 && n <= 4) {
      wizardStep = n;
      updateWizSteps();
      renderWizStep();
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  }

  function generateBtnClick() {
    var apiKey = '';
    if (typeof KEY_STORE !== 'undefined') apiKey = KEY_STORE.get();
    if (!apiKey && typeof settings !== 'undefined' && settings.apiKey) apiKey = settings.apiKey;
    if (!apiKey) {
      var errEl = document.getElementById('step4Error');
      if (errEl) { errEl.style.display = 'block'; errEl.textContent = 'Atur API Key dulu di Pengaturan Model (halaman Home).'; }
      setTimeout(function() { if (errEl) errEl.style.display = 'none'; }, 4000);
      return;
    }

    //     Save all context to state    
    if (typeof state !== 'undefined') {
      var idea = document.getElementById('ideaText')?.value?.trim() || state.idea || '';
      var name = document.getElementById('wizProductName')?.value?.trim() || state.productName || '';
      state.idea = idea;
      state.productName = name;
      state.productType = selectedType || state.productType || 'Web App';
      state.productCategory = state.productCategory || selectedCategory || '';
      state.productCatName = state.productCatName || selectedParent || '';
      state.tech = state.tech || {};
      state.extras = state.extras || [];
      state.answers = state.answers || {};
      if (typeof saveState === 'function') saveState();
    }

    loadWizardOverlay();
    setTimeout(function() { doGenerate(); }, 500);
  }

  function loadWizardOverlay() {
    var overlay = document.getElementById('loadOverlay');
    if (overlay) overlay.classList.add('open');
    // Rainbow glow on all wizard cards during generation
    document.querySelectorAll('#wizardContent .card').forEach(function(c) { c.classList.add('ai-processing'); });
    var modelName = 'Claude 3.5 Sonnet';
    if (typeof settings !== 'undefined' && settings.model) modelName = settings.model.split('/').pop();
    var el = document.getElementById('loadingModel');
    if (el) el.textContent = 'Menggunakan ' + modelName;

    //     Lab Animation Sequence    
    // Phase 1: Three cards fly in (0-2s)
    // Phase 2: Flash combine (2-3.5s)
    // Phase 3: Beaker + progress (3.5s+)

    var p1 = document.getElementById('labPhase1');
    var p2 = document.getElementById('labPhase2');
    var p3 = document.getElementById('labPhase3');
    var pFill = document.getElementById('labBeakerLiquid');
    var progFill = document.getElementById('labProgressFill');
    var statusText = document.getElementById('labStatusText');

    // Phase 1→2: Cards combine
    setTimeout(function() {
      if (p1) p1.style.display = 'none';
      if (p2) p2.style.display = 'block';
    }, 2200);

    // Phase 2→3: Beaker appears
    setTimeout(function() {
      if (p2) p2.style.display = 'none';
      if (p3) p3.style.display = 'block';
      // Start filling the beaker
      if (pFill) pFill.style.height = '30%';
      if (progFill) progFill.style.width = '15%';
      if (statusText) statusText.textContent = 'Menganalisis data produk...';
    }, 3500);

    // Progress updates
    setTimeout(function() {
      if (pFill) pFill.style.height = '55%';
      if (progFill) progFill.style.width = '35%';
      if (statusText) statusText.textContent = 'Menyusun struktur blueprint...';
    }, 5000);

    setTimeout(function() {
      if (pFill) pFill.style.height = '75%';
      if (progFill) progFill.style.width = '60%';
      if (statusText) statusText.textContent = 'Mengoptimasi dengan AI...';
    }, 7000);

    setTimeout(function() {
      if (pFill) pFill.style.height = '90%';
      if (progFill) progFill.style.width = '85%';
      if (statusText) statusText.textContent = 'Finalisasi blueprint...';
    }, 9000);
  }

  function doGenerate() {
    if (typeof generateBlueprint === 'function') generateBlueprint();
    else {
      document.getElementById('loadOverlay')?.classList.remove('open');
      document.querySelectorAll('#wizardContent .card').forEach(function(c) { c.classList.remove('ai-processing'); });
      alert('Generate function not available');
    }
  }

  function retryGenerate() {
    document.getElementById('errorOverlay').classList.remove('open');
    generateBtnClick();
  }

  function closeErrorOverlay() {
    document.getElementById('errorOverlay').classList.remove('open');
    document.querySelectorAll('#wizardContent .card').forEach(function(c) { c.classList.remove('ai-processing'); });
  }

  //     Engine Artifacts Reconstruction    
  // Reconstruct window.engineArtifacts from saved state.artifacts on page load
  function reconstructEngineArtifacts() {
    if (window.engineArtifacts && window.engineArtifacts.domain) return; // already loaded
    if (!state.artifacts || !state.artifacts.length) return;
    var parsed = {};
    var engineKeys = ['domain', 'relations', 'modules', 'validation', 'architecture', 'security', 'documentation', 'stateMachine', 'uiFlows', 'events'];
    var anyFound = false;
    engineKeys.forEach(function(key) {
      var art = state.artifacts.find(function(a) { return a.id === 'engine-' + key; });
      if (art && art.content) {
        try { parsed[key] = JSON.parse(art.content); anyFound = true; } catch(e) {}
      }
    });
    if (anyFound) {
      window.engineArtifacts = parsed;
    }
  }

  //     Result page    
  function initResult() {
    reconstructEngineArtifacts();
    var pn = document.getElementById('resultProjectName');
    if (pn && typeof state !== 'undefined') pn.textContent = state.productName || 'Blueprint';
    var vn = document.getElementById('visualBlueprintName');
    if (vn && typeof state !== 'undefined') vn.textContent = state.productName || 'Project brief';
    // Ensure overview tab renders its content (renderResultOverview + businessDNA)
    if (typeof switchResultTab === 'function') switchResultTab('overview');
    if (typeof renderArtifacts === 'function') renderArtifacts();
    if (typeof renderVersions === 'function') renderVersions();
    if (typeof renderMeta === 'function') renderMeta();
    if (typeof renderPreview === 'function') renderPreview();
  }

  function closePreviewPane() {
    document.getElementById('resultPreviewPane').classList.remove('open');
    document.getElementById('resultPreviewOverlay').classList.remove('open');
  }

  //     Docs & Tutorial    
  function openDocs() { window.open('https://github.com/halugoods/prdkit', '_blank'); }
  function openTutorial() { window.open('https://github.com/halugoods/prdkit', '_blank'); }
  function showHome() { navigate('home'); window.scrollTo({ top: 0, behavior: 'smooth' }); }
  function closeDocs() {
    var modal = document.getElementById('docsModal');
    if (modal) modal.classList.remove('open');
    if (typeof updateAIConfigUI === 'function') updateAIConfigUI();
  }

  //     Toast    
  function showToast(msg, type) {
    var container = document.getElementById('toastContainer');
    if (!container) return;
    var el = document.createElement('div');
    el.className = 'toast' + (type === 'success' ? ' success' : '') + (type === 'error' ? ' error' : '') + (type === 'info' ? ' info' : '') + (type === 'warning' ? ' warning' : '');
    el.innerHTML = '<span class="toast-icon">' + (type === 'success' ? '✓' : type === 'error' ? '✕' : type === 'warning' ? '⚠' : 'ℹ') + '</span><span class="toast-msg">' + msg + '</span>';
    container.appendChild(el);
    setTimeout(function() { el.style.animation = 'toastOut 0.2s forwards'; setTimeout(function() { el.remove(); }, 250); }, 2500);
  }

  //     Survey    
  function loadSurveyRecommendations() {
    try {
      var qs = typeof getSurveyQuestions === 'function' ? getSurveyQuestions() : [];
      if (qs.length > 0) {
        surveyRecommendations = {};
        var recCont = document.getElementById('aiChips');
        if (recCont) recCont.innerHTML = '<span class="chip" style="color:var(--accent)">Saran siap   lanjut generate!</span>';
      }
    } catch(e) {}
  }

  //     Misc    
  function toggleHistory() {
    var panel = document.getElementById('historyPanel');
    var overlay = document.getElementById('historyPanelOverlay');
    if (panel && overlay) {
      var showing = panel.style.display !== 'none';
      panel.style.display = showing ? 'none' : 'block';
      overlay.style.display = showing ? 'none' : 'block';
    }
  }

  //     createToast fallback (for app.js logout)    
  function createToast(msg, type) {
    showToast(msg, type);
    return document.getElementById('toastContainer');
  }

  function escapeHtml(str) {
    if (typeof str !== 'string') return '';
    return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;');
  }

  //     Language Toggle    
  var currentLang = 'id';

  function switchLang(lang) {
    currentLang = lang;
    document.documentElement.setAttribute('data-lang', lang);
    document.querySelectorAll('.lang-btn').forEach(function(b) {
      b.classList.toggle('active', b.dataset.lang === lang);
    });
    // Toggle visible language spans
    document.querySelectorAll('[data-lang]').forEach(function(el) {
      if (el.classList.contains('lang-btn') || el.classList.contains('lang-toggle')) return;
      if (el.tagName === 'HTML') return;
      var elLang = el.getAttribute('data-lang');
      if (elLang === 'id' || elLang === 'en') {
        el.style.display = (elLang === lang) ? '' : 'none';
      }
    });
  }

  //     DOMContentLoaded    
  document.addEventListener('DOMContentLoaded', function() {
    if (typeof loadState === 'function') loadState();

    // Founder photo error handling
    var img = document.getElementById('founderPhoto');
    if (img) {
      img.onerror = function() { this.style.display = 'none'; var fi = document.getElementById('founderInitials'); if (fi) fi.style.display = 'flex'; };
      img.onload = function() { var fi = document.getElementById('founderInitials'); if (fi) fi.style.display = 'none'; };
    }

    // Escape key closes modals
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') {
        var settings = document.getElementById('settingsModal');
        if (settings && settings.classList.contains('open')) { if (typeof closeSettings === 'function') closeSettings(); }
        var docs = document.getElementById('docsModal');
        if (docs && docs.classList.contains('open')) { if (typeof closeDocs === 'function') closeDocs(); }
      }
    });
  });


