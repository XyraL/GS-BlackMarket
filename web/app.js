


const root = document.getElementById('root');
const tablet = document.getElementById('tablet');
const toastEl = document.getElementById('toast');

const state = {
  theme: 'neon',
  motion: true,
  glow: true,
  noise: true,

  logged: false,
  alias: null,
  username: null,

  vendor: 'all',
  category: 'all',
  weaponSub: null,
  chip: null,
  search: '',
  sort: 'featured',
  maxPrice: 5000,

  
  
  pageSize: 6,
  page: 1,
  totalFiltered: 0,

  cart: {},
  orders: [],
  selectedOrder: null,

  _authMode: 'login',

  boot: {
    cfg: null,
    vendors: [],
    catalog: [],
    categories: [],
    payments: ['cash', 'bank'],
  },
};




function $(id){ return document.getElementById(id); }
function money(n){ return `$${Math.floor(n||0).toLocaleString()}`; }

function clamp(n,a,b){ return Math.max(a, Math.min(b, n)); }

function statusKey(s){
  return String(s||'PENDING').trim().toUpperCase().replace(/[\s\-]+/g,'_').replace(/_+/g,'_');
}

function statusClass(s){
  const k = statusKey(s);
  if (k === 'READY') return 'status-ready';
  if (k === 'EN_ROUTE' || k === 'ENROUTE') return 'status-en_route';
  if (k === 'CLAIMED') return 'status-claimed';
  return 'status-pending';
}

function computeCatalogMaxPrice(){
  const list = Array.isArray(state.boot.catalog) ? state.boot.catalog : [];
  let mx = 0;
  for (const it of list) mx = Math.max(mx, Number(it.price||0));
  return mx;
}

function syncPriceSlider(){
  const range = $('priceRange');
  const pv = $('priceVal');
  if (!range) return;

  const cfgMax = Number(state.boot?.cfg?.ui?.maxPrice || state.boot?.cfg?.cfg?.ui?.maxPrice || 0);
  const mx = cfgMax > 0 ? cfgMax : Math.ceil(computeCatalogMaxPrice() * 1.25);
  const safeMax = Math.max(5000, mx || 5000);

  range.max = String(safeMax);

  
  if (!state.maxPrice || state.maxPrice < safeMax * 0.25) state.maxPrice = safeMax;

  range.value = String(clamp(state.maxPrice, 0, safeMax));
  state.maxPrice = Number(range.value);
  if (pv) pv.textContent = (Number(range.max||0) && state.maxPrice >= Number(range.max||0)) ? 'No Limit' : money(state.maxPrice);
}

function resolveIcon(icon){
  if (!icon) return '';
  const s = String(icon);
  if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('nui://') || s.startsWith('data:')) return s;
  const base = state.boot?.cfg?.iconBase || '';
  if (base) {
    const b = String(base).replace(/\/$/,'');
    const p = s.replace(/^\
    return `${b}/${p}`;
  }
  return s;
}

function iconGlyph(icon){
  const k = String(icon||'').toLowerCase();
  const map = {
    lock: '🔒',
    wrench: '🛠️',
    drill: '🌀',
    phone: '📱',
    radio: '📡',
    plus: '➕',
    kit: '🧰',
    ammo: '🧨',
    parts: '⚙️',
    tool: '🛠️',
    chip: '💠',
    med: '🩺',
    bolt: '⚡',
    gun: "🔫",
    pistol: "🔫",
    smg: "🔫",
    rifle: "🎯",
    shotgun: "💥",
    armor: "🛡️",
    knife: "🗡️",
    bat: "🏏",
  };
  return map[k] || '⬡';
}

function resolveItemImage(itemName, explicitIcon){
  
  const explicit = resolveIcon(explicitIcon);
  if (explicit && (explicit.startsWith('http') || explicit.startsWith('nui://') || explicit.startsWith('data:'))) return explicit;

  const base = state.boot?.cfg?.images?.base;
  if (!base || !itemName) return '';
  const b = String(base).replace(/\/$/, '') + '/';
  return `${b}${String(itemName)}.png`;
}


function showToast(text){
  toastEl.textContent = text;
  toastEl.classList.remove('hidden');
  clearTimeout(showToast._t);
  showToast._t = setTimeout(()=>toastEl.classList.add('hidden'), 2200);
}

function setTheme(theme){
  state.theme = theme;
  if (theme === 'neon') {
    document.documentElement.removeAttribute('data-theme');
  } else {
    document.documentElement.setAttribute('data-theme', theme);
  }
}

function setToggles(){
  document.documentElement.style.setProperty('--motion', state.motion ? '1' : '0');
  document.documentElement.style.setProperty('--glow', state.glow ? '1' : '0');
  document.documentElement.style.setProperty('--noise', state.noise ? '1' : '0');
}

function setAuthLocked(locked){
  tablet.classList.toggle('auth-only', locked);
  $('authOverlay').style.display = locked ? 'grid' : 'none';
}

function titleCase(s){
  s = String(s||'');
  if (!s) return s;
  return s.replace(/[_-]+/g,' ').replace(/\b\w/g, m => m.toUpperCase());
}

function isFiveM(){
  return typeof GetParentResourceName === 'function';
}

async function nui(name, data){
  
  if (!isFiveM()) return null;
  try {
    const res = await fetch(`https://${GetParentResourceName()}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {})
    });
    return await res.json();
  } catch (e) {
    return null;
  }
}




function applyThemeFromCfg(cfg){
  const t = cfg?.ui?.theme;
  if (!t) return;
  
}

function hydrateFromBoot(boot){
  
  state.boot.cfg = boot?.cfg || null;

  
  const v = (boot?.cfg?.vendors || []).filter(x=>x && x.enabled);
  state.boot.vendors = [{ id:'all', label:'All' }, ...v.map(x=>({ id:x.id, label:x.label }))];

  
  state.boot.catalog = Array.isArray(boot?.catalog) ? boot.catalog : [];
  syncPriceSlider();

  
  const cats = new Set();
  for (const it of state.boot.catalog) cats.add(it.category);
  const catList = [{ id:'all', label:'All' }];
  [...cats].filter(Boolean).sort().forEach(c=>catList.push({ id:c, label:titleCase(c) }));
  state.boot.categories = catList;

  
  const allowed = boot?.cfg?.cfg?.paymentAllowed || boot?.cfg?.payment?.allowed; 
  state.boot.payments = Array.isArray(boot?.cfg?.cfg?.allowed) ? boot.cfg.cfg.allowed : state.boot.payments;

  
  const acct = boot?.state;
  if (acct?.exists && acct.alias) {
    login(acct.alias, acct.username);
  } else {
    logout(true);
  }

  applyThemeFromCfg(boot?.cfg);
}

function hydrateMock(){
  
  state.boot.vendors = [
    { id:'all', label:'All' },
    { id:'tools', label:'Tools & Utilities' },
    { id:'electronics', label:'Electronics' },
    { id:'medical', label:'Medical' },
    { id:'parts', label:'Weapon Parts / Ammo' },
  ];

  state.boot.catalog = [
    { name:'lockpick', label:'Lockpick', price:250, vendor:'tools', category:'tools', icon:'lock' },
    { name:'advancedlockpick', label:'Advanced Lockpick', price:850, vendor:'tools', category:'tools', icon:'lock' },
    { name:'repairkit', label:'Repair Kit', price:450, vendor:'tools', category:'tools', icon:'wrench' },
    { name:'drill', label:'Compact Drill', price:1200, vendor:'tools', category:'tools', icon:'drill' },
    { name:'phone', label:'Burner Phone', price:300, vendor:'electronics', category:'electronics', icon:'phone' },
    { name:'radio', label:'Encrypted Radio', price:950, vendor:'electronics', category:'electronics', icon:'radio' },
    { name:'bandage', label:'Bandage', price:120, vendor:'medical', category:'medical', icon:'plus' },
    { name:'firstaid', label:'First Aid Kit', price:500, vendor:'medical', category:'medical', icon:'kit' },
    { name:'ammo-9', label:'9mm Ammo Box', price:750, vendor:'parts', category:'parts', icon:'ammo' },
    { name:'weapon_part', label:'Weapon Parts', price:1800, vendor:'parts', category:'parts', icon:'parts' },
  ];

  syncPriceSlider();

  const cats = new Set(state.boot.catalog.map(x=>x.category));
  state.boot.categories = [{ id:'all', label:'All' }, ...[...cats].map(c=>({ id:c, label:titleCase(c) }))];

  logout(true);
}




function populateVendorSelect(){
  const sel = $('vendorSel');
  if (!sel) return; 
  sel.innerHTML = '';
  for (const v of state.boot.vendors) {
    const opt = document.createElement('option');
    opt.value = v.id;
    opt.textContent = `Vendor: ${v.label}`;
    sel.appendChild(opt);
  }
  sel.value = state.vendor;
}

function populatePaySelect(){
  const build = (sel)=>{
    if (!sel) return;
    const current = sel.value || 'cash';
    sel.innerHTML = '';

    const pm = (state.boot.cfg?.cfg?.payment?.allowed) || (state.boot.cfg?.ui?.payment?.allowed) || null;
    const list = Array.isArray(pm) ? pm : ['cash','bank'];

    list.forEach(m=>{
      const opt = document.createElement('option');
      opt.value = m;
      opt.textContent = m.toUpperCase();
      sel.appendChild(opt);
    });

    if ([...sel.options].some(o=>o.value===current)) sel.value = current;
  };

  build($('paySel'));
  build($('paySel2'));
}



const heroState = { index: 0, timer: null, started: false };

function heroSet(nextIndex, opts = {}){
  const slides = Array.from(document.querySelectorAll('.heroSlide'));
  const dots   = Array.from(document.querySelectorAll('.heroDot'));
  if (!slides.length) return;

  heroState.index = (nextIndex + slides.length) % slides.length;

  slides.forEach((s,i)=>s.classList.toggle('active', i === heroState.index));
  dots.forEach((d,i)=>d.classList.toggle('active', i === heroState.index));

  if (opts.restart !== false) {
    if (heroState.timer) clearInterval(heroState.timer);
    heroState.timer = setInterval(()=>heroSet(heroState.index + 1, { restart:false }), 5200);
  }
}

function initHero(){
  const hero = document.getElementById('hero');
  if (!hero || heroState.started) return;
  heroState.started = true;

  const slides = Array.from(hero.querySelectorAll('.heroSlide'));
  const dotsBox = document.getElementById('heroDots');
  if (dotsBox && slides.length) {
    dotsBox.innerHTML = '';
    slides.forEach((_, i)=>{
      const d = document.createElement('button');
      d.type = 'button';
      d.className = 'heroDot' + (i===0 ? ' active' : '');
      d.onclick = ()=>heroSet(i);
      dotsBox.appendChild(d);
    });
  }

  const prev = document.getElementById('heroPrev');
  const next = document.getElementById('heroNext');
  if (prev) prev.onclick = ()=>heroSet(heroState.index - 1);
  if (next) next.onclick = ()=>heroSet(heroState.index + 1);

  
  let downX = null;
  let dragging = false;

  const onDown = (e)=>{
    dragging = true;
    downX = (e.touches && e.touches[0]) ? e.touches[0].clientX : e.clientX;
  };
  const onMove = (e)=>{
    if (!dragging || downX === null) return;
    const x = (e.touches && e.touches[0]) ? e.touches[0].clientX : e.clientX;
    const dx = x - downX;
    if (Math.abs(dx) > 60) {
      dragging = false;
      downX = null;
      heroSet(heroState.index + (dx < 0 ? 1 : -1));
    }
  };
  const onUp = ()=>{ dragging = false; downX = null; };

  hero.addEventListener('mousedown', onDown);
  hero.addEventListener('mousemove', onMove);
  window.addEventListener('mouseup', onUp);

  hero.addEventListener('touchstart', onDown, { passive:true });
  hero.addEventListener('touchmove', onMove, { passive:true });
  hero.addEventListener('touchend', onUp, { passive:true });

  heroSet(0);
}


function mainCategoryForItem(it){
  const c = String(it?.category || '').toLowerCase();
  if (['pistols','rifles','shotguns','smgs','melee'].includes(c)) return 'weapons';
  if (c === 'ammo') return 'ammo';
  if (c === 'electronics') return 'electronics';
  if (c === 'medical') return 'medical';
  if (c === 'tools') return 'tools';
  
  return 'tools';
}

function renderWeaponSubs(){
  const row = $('weaponSubRow');
  if (!row) return;

  const show = (state.category === 'weapons');
  
  row.style.display = show ? 'flex' : 'none';
  if (!show) {
    row.innerHTML = '';
    state.weaponSub = null;
    return;
  }

  const subs = [
    { id:'pistols', label:'Pistols' },
    { id:'rifles', label:'Rifles' },
    { id:'shotguns', label:'Shotguns' },
    { id:'smgs', label:'SMGs' },
    { id:'melee', label:'Melee' },
    { id:'all', label:'All Weapons' },
  ];

  row.innerHTML = '';
  subs.forEach(s=>{
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'subChip' + ((state.weaponSub || 'all') === s.id ? ' active' : '');
    b.innerHTML = `<span class="dot"></span><span>${escapeHtml(s.label)}</span>`;
    b.onclick = ()=>{
      state.weaponSub = (s.id === 'all') ? null : s.id;
      Array.from(row.querySelectorAll('.subChip')).forEach(x=>x.classList.remove('active'));
      b.classList.add('active');
      renderGrid();
    };
    row.appendChild(b);
  });
}

function renderCategoryTiles(){
  const box = $('categoryTiles');
  if (!box) return;

  const meta = {
    all:         { ico: '⬢', sub:'Browse everything' },
    weapons:     { ico: '🔫', sub:'Pistols, rifles, more' },
    electronics: { ico: '📡', sub:'Signal-safe gear' },
    medical:     { ico: '🧪', sub:'Heals + kits' },
    ammo:        { ico: '🧨', sub:'Boxes + mags' },
    tools:       { ico: '🧰', sub:'Utility + entry' },
  };

  const mainCats = [
    { id:'all', label:'All' },
    { id:'weapons', label:'Weapons' },
    { id:'electronics', label:'Electronics' },
    { id:'medical', label:'Medical' },
    { id:'ammo', label:'Ammo' },
    { id:'tools', label:'Tools' },
  ];

  box.innerHTML = '';
  mainCats.forEach(c=>{
    const m = meta[c.id] || { ico:'⬡', sub:'Explore' };
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'catTile' + (state.category === c.id ? ' active' : '');
    btn.innerHTML = `
      <div class="catIcon">${m.ico}</div>
      <div class="catLabel">
        <div class="t">${escapeHtml(c.label)}</div>
        <div class="s">${escapeHtml(m.sub)}</div>
      </div>
    `;
    btn.onclick = ()=>{
      state.category = c.id;
      const crumb = $('crumbCat');
      if (crumb) crumb.textContent = c.label;
      
      if (c.id !== 'weapons') state.weaponSub = null;
      renderAll();
    };
    box.appendChild(btn);
  });

  renderWeaponSubs();
}


function renderCats(){  }


function matchesQuickChip(p){
  if (!state.chip) return true;
  const price = Number(p.price||0);
  if (state.chip === 'cheap') return price <= 500;
  if (state.chip === 'premium') return price >= 1500;
  
  return true;
}

function renderGrid(){
  const grid = $('productGrid');
  if (!grid) return;

  let list = [...state.boot.catalog];

  if (state.category !== 'all') {
    list = list.filter(p=>mainCategoryForItem(p) === state.category);
    if (state.category === 'weapons' && state.weaponSub) {
      list = list.filter(p=>String(p.category||'').toLowerCase() === String(state.weaponSub).toLowerCase());
    }
  }

  if (state.search) {
    const s = state.search.toLowerCase();
    list = list.filter(p =>
      String(p.label||'').toLowerCase().includes(s) ||
      String(p.name||'').toLowerCase().includes(s) ||
      String(p.category||'').toLowerCase().includes(s)
    );
  }

  list = list.filter(p=>Number(p.price||0) <= state.maxPrice);
  list = list.filter(matchesQuickChip);

  if (state.sort === 'priceAsc') list.sort((a,b)=>Number(a.price||0)-Number(b.price||0));
  if (state.sort === 'priceDesc') list.sort((a,b)=>Number(b.price||0)-Number(a.price||0));
  if (state.sort === 'nameAsc') list.sort((a,b)=>String(a.label||'').localeCompare(String(b.label||'')));

  state.totalFiltered = list.length;

  
  const v = state.boot.vendors.find(x=>x.id===state.vendor);
  if ($('crumbVendor')) $('crumbVendor').textContent = v ? v.label : 'All Vendors';
  const c = state.boot.categories.find(x=>x.id===state.category);
  if ($('crumbCat')) $('crumbCat').textContent = c ? c.label : 'All';

  
  
  const pageSize = 6;
  state.pageSize = 6;
  const totalPages = Math.max(1, Math.ceil(list.length / pageSize));
  state.page = clamp(Number(state.page||1), 1, totalPages);

  const start = (state.page - 1) * pageSize;
  const end = start + pageSize;
  const slice = list.slice(start, end);

  grid.innerHTML = '';
  for (const p of slice) {
    const imgSrc = resolveItemImage(p.name, p.icon);
    const card = document.createElement('div');
    card.className = 'pCard';
    card.innerHTML = `
      <div class="pImg">
        ${imgSrc ? `<img src="${imgSrc}" alt="" onerror="this.style.display='none'"/>` : ''}
      </div>
      <div class="pBody">
        <div class="pName">${escapeHtml(p.label || p.name)}</div>
        <div class="pMeta"><span>${escapeHtml(mainCategoryForItem(p))}</span><span>${money(p.price)}</span></div>
        <div class="pActions">
          <button class="btn primary" data-act="add">Add</button>
          <button class="btn ghost" data-act="add5">+5</button>
        </div>
      </div>
    `;
    card.querySelector('[data-act="add"]').onclick = ()=>addToCart(p,1);
    card.querySelector('[data-act="add5"]').onclick = ()=>addToCart(p,5);
    grid.appendChild(card);
  }

  renderPager(state.page, totalPages);
}

function renderPager(currentPage, totalPages){
  const info = $('pageInfo');
  const nums = $('pageNums');
  const prev = $('pagePrev');
  const next = $('pageNext');
  if (info) info.textContent = `Page ${currentPage} of ${totalPages}`;
  if (prev) prev.disabled = currentPage <= 1;
  if (next) next.disabled = currentPage >= totalPages;
  if (!nums) return;

  nums.innerHTML = '';

  const addButton = (p, label)=>{
    const b = document.createElement('button');
    b.className = 'pageBtn' + (p === currentPage ? ' active' : '');
    b.type = 'button';
    b.textContent = String(label ?? p);
    b.onclick = ()=>{
      state.page = p;
      renderGrid();
      const grid = $('productGrid');
      if (grid) grid.scrollTop = 0;
    };
    nums.appendChild(b);
  };

  const windowSize = 7;
  let start = Math.max(1, currentPage - Math.floor(windowSize/2));
  let end = Math.min(totalPages, start + windowSize - 1);
  start = Math.max(1, end - windowSize + 1);

  if (start > 1) {
    addButton(1, '1');
    if (start > 2) {
      const dots = document.createElement('div');
      dots.className = 'pageInfo';
      dots.textContent = '…';
      nums.appendChild(dots);
    }
  }

  for (let p = start; p <= end; p++) addButton(p);

  if (end < totalPages) {
    if (end < totalPages - 1) {
      const dots = document.createElement('div');
      dots.className = 'pageInfo';
      dots.textContent = '…';
      nums.appendChild(dots);
    }
    addButton(totalPages, String(totalPages));
  }
}

function escapeHtml(str){
  return String(str ?? '').replace(/[&<>"']/g, s => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[s]));
}

function addToCart(p, qty){
  if (!state.cart[p.name]) state.cart[p.name] = { name:p.name, label:p.label || p.name, price:Number(p.price||0), qty:0 };
  state.cart[p.name].qty = Math.min(999, state.cart[p.name].qty + qty);
  renderCart();
  showToast(`Added ${p.label || p.name}`);

  // Visual feedback (orders cart panel)
  const cartEl = document.querySelector('.ordersRight .panelCard');
  if (cartEl) {
    cartEl.classList.add('pulse');
    setTimeout(()=>cartEl.classList.remove('pulse'), 380);
  }
}

function subFromCart(name, qty){
  if (!state.cart[name]) return;
  state.cart[name].qty -= qty;
  if (state.cart[name].qty <= 0) delete state.cart[name];
  renderCart();
}

function clearCart(){
  state.cart = {};
  renderCart();
  showToast('Cart cleared');
}

function renderCart(){
  const box = $('cartList');
  if (box) box.innerHTML = '';

  const items = Object.values(state.cart);

  if (box) {
    for (const it of items) {
      const row = document.createElement('div');
      row.className = 'cartItem';
      row.innerHTML = `
        <div class="cLeft">
          <div class="cName">${escapeHtml(it.label)}</div>
          <div class="cMeta">${escapeHtml(it.name)} • ${money(it.price)} ea</div>
        </div>
        <div class="qty">
          <button class="qBtn">-</button>
          <div class="qVal">${it.qty}</div>
          <button class="qBtn">+</button>
        </div>
      `;
      const [subBtn, addBtn] = row.querySelectorAll('.qBtn');
      subBtn.onclick = ()=>subFromCart(it.name,1);
      addBtn.onclick = ()=>addToCart(it,1);
      box.appendChild(row);
    }
  }

  const subtotal = items.reduce((a,it)=>a + it.price*it.qty, 0);
  const delivery = subtotal ? Math.min(2500, Math.max(150, Math.floor(subtotal * 0.05))) : 0;
  const total = subtotal + delivery;

  if ($('tSubtotal')) $('tSubtotal').textContent = money(subtotal);
  if ($('tDelivery')) $('tDelivery').textContent = money(delivery);
  if ($('tTotal')) $('tTotal').textContent = money(total);

  const mBox = $('cartMirror');
  if (mBox) {
    mBox.innerHTML = '';
    for (const it of items) {
      const row = document.createElement('div');
      row.className = 'cartItem';
      row.innerHTML = `
        <div class="cLeft">
          <div class="cName">${escapeHtml(it.label)}</div>
          <div class="cMeta">${escapeHtml(it.name)} • ${money(it.price)} ea</div>
        </div>
        <div class="qty">
          <button class="qBtn">-</button>
          <div class="qVal">${it.qty}</div>
          <button class="qBtn">+</button>
        </div>
      `;
      const [subBtn, addBtn] = row.querySelectorAll('.qBtn');
      subBtn.onclick = ()=>subFromCart(it.name,1);
      addBtn.onclick = ()=>addToCart(it,1);
      mBox.appendChild(row);
    }
  }

  if ($('tSubtotal2')) $('tSubtotal2').textContent = money(subtotal);
  if ($('tDelivery2')) $('tDelivery2').textContent = money(delivery);
  if ($('tTotal2')) $('tTotal2').textContent = money(total);

  const hint2 = $('cartHint2');
  if (hint2) hint2.textContent = state.logged ? 'Ready for delivery.' : 'Login required.';

  const cnt = items.reduce((a,it)=>a + Number(it.qty||0), 0);
  const hc = $('homeCartCount');
  if (hc) hc.textContent = `${cnt} item${cnt===1?'':'s'}`;

  const shopBtn = $('shopToOrders');
  if (shopBtn) shopBtn.textContent = `Cart • ${cnt}`;
}

function switchView(view){
  state.view = view;

  // Tabs active state
  document.querySelectorAll('.navBtn').forEach(b=>b.classList.toggle('active', b.dataset.view===view));

  // Hard-hide all views to prevent any accidental stacking (CSS + inline)
  document.querySelectorAll('.view').forEach(v=>{
    v.classList.remove('active');
    v.style.display = 'none';
  });

  const active = document.getElementById(`view-${view}`);
  if (active) {
    active.classList.add('active');
    // IMPORTANT:
    // Shop relies on a flex column layout so its inner grid can scroll
    // (overflow:auto) and the pager stays visible. Forcing display:block here
    // overrides CSS (#view-shop.active {display:flex}) and kills scrollbars.
    active.style.display = (view === 'shop') ? 'flex' : 'block';
    // reset scroll for the active pane (and common inner scrollers)
    try { active.scrollTop = 0; } catch(e) {}
    try {
      const inner = active.querySelector('.productGrid,.ordersList,.cartList');
      if (inner) inner.scrollTop = 0;
    } catch(e) {}
  }

  // Light refresh per view
  if (view === 'home') {
    renderHomeOrdersMini();
    const hoc = $('homeOrdersCount');
    if (hoc) hoc.textContent = String((state.orders||[]).length);
    renderCart();
  }

  if (view === 'orders') {
    (async ()=>{
      const list = await nui('bm_listOrders', {});
      if (list) setOrders(list);
    })();
    renderCart();
  }

  if (view === 'shop') {
    renderCart();
  }
}

function setAuthMode(mode){
  state._authMode = mode;
  document.querySelectorAll('.authTab').forEach(t=>t.classList.toggle('active', t.dataset.auth===mode));
  $('createAliasField').style.display = (mode==='create') ? 'grid' : 'none';
  $('authSubmit').textContent = (mode==='create') ? 'Create Alias' : 'Login';
  $('authMsg').textContent = '';
}

function login(alias, username){
  state.logged = true;
  state.alias = alias;
  state.username = username || null;

  $('aliasName').textContent = `@${alias}`;
  $('aliasHint').textContent = 'Drops will route under this alias.';
  $('profileAlias').textContent = `@${alias}`;
  const pu = $('profileUser');
  if (pu) pu.textContent = username || '—';
  const ha = $('homeAlias');
  if (ha) ha.textContent = `@${alias}`;
  const sa = $('shopAlias');
  if (sa) sa.textContent = `@${alias}`;
  const hint1 = $('cartHint');
  if (hint1) hint1.textContent = 'Ready for delivery.';
  const hint2 = $('cartHint2');
  if (hint2) hint2.textContent = 'Ready for delivery.';
  const note = $('homeNote');
  if (note) note.textContent = 'Clear skies. You can dispatch deliveries.';

  setAuthLocked(false);
}

function logout(silent){
  state.logged = false;
  state.alias = null;
  state.username = null;

  $('aliasName').textContent = 'Not logged in';
  $('aliasHint').textContent = 'Create an account to receive drops.';
  $('profileAlias').textContent = '@—';
  const pu = $('profileUser');
  if (pu) pu.textContent = '—';
  const ha = $('homeAlias');
  if (ha) ha.textContent = '@—';
  const sa = $('shopAlias');
  if (sa) sa.textContent = '@—';
  const hint1 = $('cartHint');
  if (hint1) hint1.textContent = 'Login required.';
  const hint2 = $('cartHint2');
  if (hint2) hint2.textContent = 'Login required.';
  const note = $('homeNote');
  if (note) note.textContent = 'Log in to dispatch real deliveries.';

  setAuthLocked(true);
  if (!silent) showToast('Logged out.');
}

function renderAll(){
  populateVendorSelect();
  populatePaySelect();
  renderCategoryTiles();
  renderGrid();
  renderCart();
}

// Legacy category-strip renderer (removed). Kept as a no-op so older code paths
// never crash if they still reference it.
function renderCats(){ /* no-op (category tiles are the single source of truth) */ }


function clearOrderDetail(){
  _stopEtaTicker();
  const ids = ['odTitle','odSub','odBadge','odItems','odHint'];
  for (const id of ids){
    const el = $(id);
    if (el) el.textContent = (id==='odTitle' ? 'Order' : '—');
  }
  const mp = $('mapPreview');
  if (mp) { mp.style.opacity = '0.65'; mp.innerHTML = ''; }
  const tl = $('odTimeline');
  if (tl) tl.classList.add('timelineScroll');
  if (tl) tl.innerHTML = '';
  state.selectedOrder = null;
}


let _etaTicker = null;
function _formatEta(ms){
  const s = Math.max(0, Math.ceil(ms/1000));
  const m = Math.floor(s/60);
  const r = s%60;
  return `${m}:${String(r).padStart(2,'0')}`;
}
function _getEtaTarget(o){
  if (!o) return null;
  const st = String(o.status||'').toLowerCase();
  if (st==='ready' || st==='claimed' || st==='canceled' || st==='cancelled') return null;
  const eta = o.eta_ready_at || o.eta_dispatch_at || null;
  if (!eta) return null;
  const t = Date.parse(String(eta));
  if (Number.isNaN(t)) return null;
  return t;
}
function _startEtaTicker(){
  if (_etaTicker) return;
  _etaTicker = setInterval(()=>{
    const o = state.selectedOrder;
    const sub = $('odSub');
    if (!o || !sub) return;
    const target = _getEtaTarget(o);
    if (!target) return;
    const ms = target - Date.now();
    sub.textContent = `Estimated time: ~${_formatEta(ms)}`;
  }, 1000);
}
function _stopEtaTicker(){
  if (_etaTicker){ clearInterval(_etaTicker); _etaTicker = null; }
}
// ------------------------------
// Orders (light UI hook for later)
// ------------------------------
function setOrders(list){
  // Only show active orders in the Orders view. Claimed/canceled orders are hidden
  // (they can be surfaced later in a dedicated History view if desired).
  const raw = Array.isArray(list) ? list : [];
  state.orders = raw.filter(o => {
    const s = String(o.status || '').toLowerCase();

// If the currently selected order is no longer active (canceled/claimed),
// clear the detail panel to avoid "stuck" middle view.
if (state.selectedOrder) {
  const sid = String(state.selectedOrder.id);
  const still = state.orders.some(x => String(x.id) === sid);
  if (!still) clearOrderDetail();
}

    return s !== 'claimed' && s !== 'canceled' && s !== 'cancelled';
  });
  const box = $('ordersList');
  box.innerHTML = '';

  // Home KPI
  const hoc = $('homeOrdersCount');
  if (hoc) hoc.textContent = String(state.orders.length);

  if (state.orders.length === 0) {
    const empty = document.createElement('div');
    empty.className = 'orderRow';
    empty.style.opacity = '0.75';
    empty.textContent = 'No active orders.';
    box.appendChild(empty);
    renderHomeOrdersMini();
    return;
  }

  for (const o of state.orders) {
    const status = statusKey(o.status || 'PENDING');
    const sClass = statusClass(status);
    const when = o.created_at ? String(o.created_at).replace('T',' ').slice(0,19) : '';
    const row = document.createElement('div');
    row.className = 'orderRow ' + sClass;
    row.innerHTML = `
      <div class="oTop">
        <div class="oId">Order #${escapeHtml(o.id)}</div>
        <div class="oStatus badgeMini ${sClass}">${escapeHtml(status)}</div>
      </div>
      <div class="oMeta"><span>${money(o.total || 0)} • ${escapeHtml((o.payment_method || '').toUpperCase())}</span><span>${escapeHtml(when || '—')}</span></div>
    `;
    row.onclick = ()=>selectOrder(o, row);
    box.appendChild(row);
  }

  renderHomeOrdersMini();
}

function renderHomeOrdersMini(){
  const host = $('homeOrdersMini');
  if (!host) return;
  host.innerHTML = '';

  const list = (state.orders || []).slice(0, 6);
  if (list.length === 0) {
    host.innerHTML = `<div class="oMini"><div class="l"><div class="t">No active orders</div><div class="s">Place an order in Shop to generate a drop.</div></div><div class="b">—</div></div>`;
    return;
  }

  for (const o of list) {
    const status = String(o.status || 'PENDING').toUpperCase();
    const when = o.created_at ? String(o.created_at).replace('T',' ').slice(0,16) : '';
    const el = document.createElement('div');
    el.className = 'oMini';
    el.innerHTML = `
      <div class="l">
        <div class="t">Order #${escapeHtml(o.id)} • ${escapeHtml(status)}</div>
        <div class="s">${escapeHtml(when || '—')}</div>
      </div>
      <div class="b">${money(o.total || 0)}</div>
    `;
    el.onclick = ()=>{ switchView('orders'); selectOrder(o); };
    host.appendChild(el);
  }
}

function selectOrder(o, rowEl){
  state.selectedOrder = o;

  // highlight selection
  const list = $('ordersList');
  if (list) {
    Array.from(list.children).forEach(ch => ch.classList && ch.classList.remove('active'));
  }
  if (rowEl && rowEl.classList) rowEl.classList.add('active');

  const status = statusKey(o.status || 'PENDING');
  const sClass = statusClass(status);
  $('odTitle').textContent = `Order #${o.id}`;
  $('odSub').textContent = `Status: ${status}`;
  const ob = $('odBadge');
  if (ob) { ob.textContent = status; ob.className = 'badge ' + sClass; }

  const items = safeJson(o.items_json, []);
  // Render items as a newline-separated list
  $('odItems').textContent = items.map(i=>`${i.qty}x ${i.name}`).join('\n') || '—';

  const drop = safeJson(o.drop_json, null);
  const hint = drop?.label ? `${drop.label} (pool: ${drop.pool || 'mixed'})` : 'No drop assigned yet.';
  $('odHint').textContent = hint;

  // ETA countdown (if provided by server/db)
  try {
    const target = _getEtaTarget(o);
    if (target) {
      const sub = $('odSub');
      if (sub) sub.textContent = `Estimated time: ~${_formatEta(target - Date.now())}`;
      _startEtaTicker();
    } else {
      _stopEtaTicker();
    }
  } catch(e) { _stopEtaTicker(); }
// Map preview text
  const mp = $('mapPreview');
  if (mp) {
    mp.style.opacity = '1';
    mp.innerHTML = `
      <div style="position:absolute;left:14px;top:14px;font-weight:950;">${escapeHtml(drop?.label || 'Dispatch Zone')}</div>
      <div style="position:absolute;left:14px;top:44px;color:rgba(255,255,255,.65);font-size:12px;max-width:70%;">${escapeHtml(drop?.hint || 'Use Ping Area for a more precise hint.')}</div>
    `;
  }

  // Timeline (simple status ladder)
  const steps = [
    { key:'PENDING',    label:'Order Placed' },
    { key:'PAID',       label:'Payment Verified' },
    { key:'PROCESSING', label:'Processing' },
    { key:'DISPATCHED', label:'Courier Dispatched' },
    { key:'EN_ROUTE',   label:'En Route' },
    { key:'READY',      label:'Drop Ready' },
    { key:'CLAIMED',    label:'Claimed' },
  ];

  const rank = { PENDING:0, PAID:1, PROCESSING:2, DISPATCHED:3, EN_ROUTE:4, READY:5, CLAIMED:6 };
  const r = rank[status] ?? 0;

  const tl = $('timeline');
  if (tl) {
    tl.innerHTML = '';
    steps.forEach((s, i)=>{
      const node = document.createElement('div');
      node.className = 'tStep' + (i <= r ? ' done' : '');
      node.innerHTML = `
        <div class="l"><div class="tDot"></div><div class="tLabel">${escapeHtml(s.label)}</div></div>
        <div class="tRight">${i <= r ? '✓' : '…'}</div>
      `;
      tl.appendChild(node);
    });
  }

  // Cancel button: allowed until picked up (any non-claimed status).
  const cbtn = $('odCancel');
  if (cbtn) {
    const lower = String(o.status || '').toLowerCase();
    const canCancel = lower && lower !== 'claimed' && lower !== 'canceled';
    cbtn.style.display = canCancel ? 'inline-flex' : 'none';
  }

  // Ping Area: only available once a drop is assigned (dispatched/en_route/ready) and coords exist.
  const pbtn = $('odPing');
  if (pbtn) {
    const lower = String(o.status || '').trim().toLowerCase().replace(/[\s\-]+/g,'_').replace(/_+/g,'_');
    const hasCoords = !!(drop && (drop.x || drop.coords?.x) && (drop.y || drop.coords?.y));
    const canPing = hasCoords && (lower === 'dispatched' || lower === 'en_route' || lower === 'ready');
    pbtn.style.display = canPing ? 'inline-flex' : 'none';

    // Visual badge on the map preview should match the actual ping availability.
    const mp = $('mapPreview');
    // ping badge handled by button visibility
  }
}

function safeJson(v, fallback){
  try {
    if (typeof v === 'object') return v;
    return JSON.parse(v);
  } catch(e){
    return fallback;
  }
}


// ------------------------------
// Checkout Modal + Order placement
// ------------------------------
function computeTotals(){
  const items = Object.values(state.cart);
  const subtotal = items.reduce((a,it)=>a + Number(it.price||0)*Number(it.qty||0), 0);
  const delivery = subtotal ? Math.min(2500, Math.max(150, Math.floor(subtotal * 0.05))) : 0;
  const total = subtotal + delivery;
  return { subtotal, delivery, total, items };
}

function openCheckoutModal(){
  if (!state.logged) return showToast('Login first.');
  if (Object.keys(state.cart).length === 0) return showToast('Cart is empty.');

  const m = $('checkoutModal');
  if (!m) return;

  const { subtotal, delivery, total, items } = computeTotals();

  $('checkoutItems').innerHTML = items.map(it=>`
    <div class="sumItem">
      <div class="l">
        <div class="n">${escapeHtml(it.label)}</div>
        <div class="m">${escapeHtml(it.name)} • ${it.qty}x</div>
      </div>
      <div class="m">${money(Number(it.price||0) * Number(it.qty||0))}</div>
    </div>
  `).join('');

  $('mSubtotal').textContent = money(subtotal);
  $('mDelivery').textContent = money(delivery);
  $('mTotal').textContent = money(total);

  m.classList.remove('hidden');
}

function closeCheckoutModal(){
  const m = $('checkoutModal');
  if (!m) return;
  m.classList.add('hidden');
}

async function placeOrder(){
  const payload = {
    paymentMethod: (($('paySel2') || $('paySel'))?.value) || 'cash',
    items: Object.values(state.cart).map(it=>({ name: it.name, qty: it.qty })),
  };

  const res = await nui('bm_createOrder', payload);
  if (!res) {
    // Preview
    showToast('Order placed (preview).');
    clearCart();
    closeCheckoutModal();
    switchView('orders');
    return;
  }

  if (res.ok) {
    showToast('Order placed. Dispatching…');
    clearCart();
    closeCheckoutModal();
    switchView('orders');
    const list = await nui('bm_listOrders', {});
    if (list) setOrders(list);
  } else {
    showToast(res.err || 'Order failed.');
  }
}


// ------------------------------
// UI bindings
// ------------------------------
function bindUI(){
  $('closeBtn').onclick = async ()=>{
    await nui('bm_close', {});
    root.classList.add('hidden');
  };

  $('themeBtn').onclick = ()=>{
    const next = ({neon:'ember', ember:'toxic', toxic:'royal', royal:'neon'})[state.theme] || 'neon';
    setTheme(next);
    showToast(`Theme: ${next}`);
  };

  // Theme swatches (Profile)
  document.querySelectorAll('.themeSwatch').forEach(btn=>{
    btn.onclick = ()=>{
      const t = btn.dataset.theme || 'neon';
      setTheme(t);
      showToast(`Theme: ${t}`);
    };
  });

  // UI toggles (Profile)
  const glow = $('tglGlow');
  const motion = $('tglMotion');
  const noise = $('tglNoise');
  const applyFX = ()=>{
    document.documentElement.style.setProperty('--glow', glow && glow.checked ? '1' : '0');
    document.documentElement.style.setProperty('--motion', motion && motion.checked ? '1' : '0');
    document.documentElement.style.setProperty('--noise', noise && noise.checked ? '1' : '0');
    localStorage.setItem('gsbm_fx', JSON.stringify({ glow: !!(glow&&glow.checked), motion: !!(motion&&motion.checked), noise: !!(noise&&noise.checked) }));
  };
  if (glow) glow.onchange = applyFX;
  if (motion) motion.onchange = applyFX;
  if (noise) noise.onchange = applyFX;
  try {
    const fx = JSON.parse(localStorage.getItem('gsbm_fx')||'null');
    if (fx && glow && motion && noise) {
      glow.checked = !!fx.glow; motion.checked = !!fx.motion; noise.checked = !!fx.noise;
    }
  } catch(e) {}
  applyFX();

  document.querySelectorAll('.navBtn').forEach(b=>{
    b.onclick = async ()=>{
      const v = b.dataset.view;
      switchView(v);
      if (v === 'orders') {
        const list = await nui('bm_listOrders', {});
        if (list) setOrders(list);
      }
    };
  });

  document.querySelectorAll('.chip').forEach(c=>{
    c.onclick = ()=>{
      const key = c.dataset.chip;
      state.chip = (state.chip === key) ? null : key;
      document.querySelectorAll('.chip').forEach(x=>x.classList.toggle('active', x.dataset.chip===state.chip));
      renderGrid();
    };
  });

  // Search bar removed (by design). Keep state.search empty.
  const si = $('searchInput');
  if (si) si.oninput = (e)=>{ state.search = e.target.value.trim(); renderGrid(); };
  else state.search = '';
  const sortSel = $('sortSel');
  if (sortSel) sortSel.onchange = (e)=>{ state.sort = e.target.value; renderGrid(); };
  else state.sort = state.sort || 'featured';
  state.vendor = 'all';

  const priceRange = $('priceRange');
  const pv = $('priceVal');
  if (priceRange) {
    priceRange.oninput = ()=>{
      const v = Number(priceRange.value||0);
      state.maxPrice = (Number.isFinite(v) ? v : state.maxPrice);
      // Live label update
      const max = Number(priceRange.max||0);
      if (pv) pv.textContent = (max && state.maxPrice >= max) ? 'No Limit' : money(state.maxPrice);
      renderGrid();
    };
  } else {
    state.maxPrice = 99999999;
  }

  const goOrders = $('goOrders');
  if (goOrders) {
    goOrders.onclick = async ()=>{
      switchView('orders');
      document.querySelectorAll('.navBtn').forEach(x=>x.classList.toggle('active', x.dataset.view==='orders'));
      const list = await nui('bm_listOrders', {});
      if (list) setOrders(list);
    };
  }

  const c1 = $('clearCart');
  if (c1) c1.onclick = clearCart;
  const clear2 = $('clearCart2');
  if (clear2) clear2.onclick = clearCart;

  // Home CTAs
  const homeToShop = $('homeToShop');
  if (homeToShop) homeToShop.onclick = ()=>switchView('shop');
  const homeToOrders = $('homeToOrders');
  if (homeToOrders) homeToOrders.onclick = async ()=>{
    switchView('orders');
    const list = await nui('bm_listOrders', {});
    if (list) setOrders(list);
  };
  const homeRefresh = $('homeRefreshOrders');
  if (homeRefresh) homeRefresh.onclick = async ()=>{
    const list = await nui('bm_listOrders', {});
    if (list) setOrders(list);
    renderHomeOrdersMini();
  };

  const qaTools = $('qaTools');
  if (qaTools) qaTools.onclick = ()=>{ switchView('shop'); state.category='tools'; state.weaponSub=null; renderCategoryTiles(); renderGrid(); };
  const qaWeapons = $('qaWeapons');
  if (qaWeapons) qaWeapons.onclick = ()=>{ switchView('shop'); state.category='weapons'; state.weaponSub=null; renderCategoryTiles(); renderWeaponSub(); renderGrid(); };
  const qaAmmo = $('qaAmmo');
  if (qaAmmo) qaAmmo.onclick = ()=>{ switchView('shop'); state.category='ammo'; state.weaponSub=null; renderCategoryTiles(); renderGrid(); };
  const qaCheckout = $('qaCheckout');
  if (qaCheckout) qaCheckout.onclick = ()=>{ switchView('shop'); openCheckoutModal(); };

  // Checkout modal bindings
  const cm = $('checkoutModal');
  if (cm) {
    cm.querySelectorAll('[data-act="close"]').forEach(x=>x.onclick = closeCheckoutModal);
  }
  const cClose = $('checkoutClose');
  if (cClose) cClose.onclick = closeCheckoutModal;
  const cCancel = $('checkoutCancel');
  if (cCancel) cCancel.onclick = closeCheckoutModal;
  const cConfirm = $('checkoutConfirm');
  if (cConfirm) cConfirm.onclick = placeOrder;

  const cb1 = $('checkoutBtn');
  if (cb1) cb1.onclick = ()=>{
    openCheckoutModal();
  };

  const checkoutBtn2 = $('checkoutBtn2');
  if (checkoutBtn2) checkoutBtn2.onclick = ()=>openCheckoutModal();

  // Keep payment method in sync between checkout selects (modal + orders).
  // Some layouts only render one of these selects, so this must be null-safe.
  const paySel  = $('paySel');
  const paySel2 = $('paySel2');
  const syncPay = (src, dst)=>{ if (src && dst) dst.value = src.value; };
  if (paySel && paySel2) {
    paySel.addEventListener('change', ()=>syncPay(paySel, paySel2));
    paySel2.addEventListener('change', ()=>syncPay(paySel2, paySel));
  }

  // Orders actions
  const pingBtn = $('odPing');
  if (pingBtn) {
    pingBtn.onclick = async ()=>{
      if (!state.selectedOrder) return showToast('Select an order first.');
      const res = await nui('bm_pingArea', { orderId: state.selectedOrder.id });
      if (res && res.ok) {
        showToast('Area ping sent.');
      }
    };
  }

  const cancelBtn = $('odCancel');
  if (cancelBtn) {
    cancelBtn.onclick = async ()=>{
      if (!state.selectedOrder) return showToast('Select an order first.');
      const st = String(state.selectedOrder.status || '').toLowerCase();
      if (st === 'claimed' || st === 'canceled') return;
      const res = await nui('bm_cancelOrder', { orderId: state.selectedOrder.id });
      if (res && res.ok) {
        showToast('Order canceled. Refund issued.');

        // Refresh list + clear selection so UI/blips don't linger.
        state.selectedOrder = null;
        clearOrderDetail();
        const list = await nui('bm_listOrders', {});
        if (list) setOrders(list);
      } else {
        showToast(res?.err || 'Cancel failed.');
      }
    };
  }

  const copyBtn = $('odCopy');
  if (copyBtn) {
    copyBtn.onclick = async ()=>{
      if (!state.selectedOrder) return showToast('Select an order first.');
      const drop = safeJson(state.selectedOrder.drop_json, null);
      const code = drop && drop.code ? String(drop.code) : '';
      if (!code) return showToast('No code available yet.');
      try {
        await navigator.clipboard.writeText(code);
        showToast('Code copied.');
      } catch(e) {
        // fallback
        const t = document.createElement('textarea');
        t.value = code;
        document.body.appendChild(t);
        t.select();
        document.execCommand('copy');
        document.body.removeChild(t);
        showToast('Code copied.');
      }
    };
  }


  // Auth
  document.querySelectorAll('.authTab').forEach(t=>{
    t.onclick = ()=>setAuthMode(t.dataset.auth);
  });

  $('authSubmit').onclick = async ()=>{
    const mode = state._authMode;
    const username = $('authUser').value.trim();
    const password = $('authPass').value.trim();
    const alias = $('authAlias').value.trim();

    $('authMsg').textContent = '';

    if (mode === 'login') {
      if (!username || !password) return $('authMsg').textContent = 'Enter username + password.';

      const res = await nui('bm_login', { username, password });
      if (!res) {
        login('PreviewGhost', username);
        showToast('Preview login.');
        return;
      }

      if (res.ok) {
        login(res.alias || res.account?.alias || 'Alias', username);
        showToast('Access granted.');
      } else {
        $('authMsg').textContent = res.err || 'Login failed.';
      }
      return;
    }

    // create
    if (!username || !password || !alias) return $('authMsg').textContent = 'Fill username, password, and alias.';

    const res = await nui('bm_register', { username, password, alias });
    if (!res) {
      login(alias, username);
      showToast('Preview account created.');
      return;
    }

    if (res.ok) {
      login(res.alias || alias, username);
      showToast('Account created.');
    } else {
      $('authMsg').textContent = res.err || 'Register failed.';
    }
  };

  $('authSkip').onclick = ()=>{
    login('PreviewGhost', null);
    showToast('Preview mode.');
  };

  $('logoutBtn').onclick = ()=>logout(false);

  // Profile actions
  const saveAlias = $('saveAlias');
  if (saveAlias) saveAlias.onclick = async ()=>{
    const alias = $('newAlias').value.trim();
    const msg = $('profileMsg');
    if (msg) msg.textContent = '';
    if (!alias) { if (msg) msg.textContent = 'Enter a new alias.'; return; }
    const res = await nui('bm_changeAlias', { alias });
    if (!res) { if (msg) msg.textContent = 'Preview mode: alias changed locally.'; login(alias, state.username); return; }
    if (res.ok) { login(res.alias || alias, state.username); if (msg) msg.textContent = 'Alias updated.'; }
    else { if (msg) msg.textContent = res.err || 'Alias update failed.'; }
  };

  const changePass = $('changePass');
  if (changePass) changePass.onclick = async ()=>{
    const cur = $('pwCurrent').value.trim();
    const n1 = $('pwNew').value.trim();
    const n2 = $('pwNew2').value.trim();
    const msg = $('securityMsg');
    if (msg) msg.textContent = '';
    if (!cur || !n1 || !n2) { if (msg) msg.textContent = 'Fill all password fields.'; return; }
    if (n1 !== n2) { if (msg) msg.textContent = 'New passwords do not match.'; return; }
    const res = await nui('bm_changePassword', { currentPassword: cur, newPassword: n1 });
    if (!res) { if (msg) msg.textContent = 'Preview mode: password change simulated.'; return; }
    if (res.ok) { if (msg) msg.textContent = 'Password updated.'; $('pwCurrent').value=''; $('pwNew').value=''; $('pwNew2').value=''; }
    else { if (msg) msg.textContent = res.err || 'Password change failed.'; }
  };

  // Profile toggles
  $('tglGlow').onchange = e=>{ state.glow = e.target.checked; setToggles(); };
  $('tglMotion').onchange = e=>{ state.motion = e.target.checked; setToggles(); };
  $('tglNoise').onchange = e=>{ state.noise = e.target.checked; setToggles(); };

  // Shop: go to Orders (cart)
  const sto = $('shopToOrders');
  if (sto) sto.onclick = ()=>switchView('orders');

  // Paging controls
  const prev = $('pagePrev');
  const next = $('pageNext');
  if (prev) prev.onclick = ()=>{ state.page = Math.max(1, Number(state.page||1) - 1); renderGrid(); const g=$('productGrid'); if(g) g.scrollTop=0; };
  if (next) next.onclick = ()=>{ state.page = Number(state.page||1) + 1; renderGrid(); const g=$('productGrid'); if(g) g.scrollTop=0; };

  // Lazy-load on scroll (auto-advances pages; does NOT append all items)
  const grid = $('productGrid');
  if (grid && !grid._lazyHooked) {
    grid._lazyHooked = true;
    grid.addEventListener('scroll', ()=>{
      const nearBottom = (grid.scrollTop + grid.clientHeight) >= (grid.scrollHeight - 120);
      if (!nearBottom) return;

      // determine total pages using current filtered count
      const pageSize = 6;
      const totalPages = Math.max(1, Math.ceil(Number(state.totalFiltered||0) / pageSize));

      const cur = clamp(Number(state.page||1), 1, totalPages);
      if (cur >= totalPages) return;

      // Disable auto-advance for categories where it feels like "scroll = page flip".
      // All + Weapons were already problematic (melee jump). Tools also needs to stay stable.
      if (state.category === 'all' || state.category === 'weapons' || state.category === 'tools') return;

      state.page = cur + 1;
      renderGrid();
      // jump to top so next page content is immediately visible
      grid.scrollTop = 0;
    });
  }

  document.querySelectorAll('.themeSwatch').forEach(b=>{
    b.onclick = ()=>{ setTheme(b.dataset.theme); showToast(`Theme: ${b.dataset.theme}`); };
  });
}

// ------------------------------
// Open / Close
// ------------------------------
async function openUI(){
  root.classList.remove('hidden');

  setTheme('neon');
  setToggles();

  // defaults
  state.vendor = 'all';
  state.category = 'all';
  state.chip = null;
  state.search = '';
  state.sort = 'featured';
  state.page = 1; // reset paging
  syncPriceSlider();

  $('crumbVendor').textContent = 'All Vendors';
  $('crumbCat').textContent = 'All';

  // boot
  const boot = await nui('bm_getBoot', {});
  if (boot) {
    hydrateFromBoot(boot);
  } else {
    hydrateMock();
  }

  setAuthMode('login');
  renderAll();
  initHero();
  switchView('home');
}

// ------------------------------
// Init
// ------------------------------
bindUI();

// ------------------------------
// Cinematic Audio (NUI)
// - Generates a controllable static bed with WebAudio (no files required).
// ------------------------------
let audioCtx = null;
let noiseNode = null;
let noiseGain = null;
let decryptGain = null;
let decryptTimer = null;
let burstTimer = null;

let audioInitPromise = null;

function ensureAudio(){
  if (audioCtx) return;
  const Ctx = window.AudioContext || window.webkitAudioContext;
  if (!Ctx) return;
  audioCtx = new Ctx();

  noiseGain = audioCtx.createGain();
  noiseGain.gain.value = 0.0;

  decryptGain = audioCtx.createGain();
  decryptGain.gain.value = 0.0;

  const connectOut = (src)=>{
    src.connect(noiseGain);
    src.connect(decryptGain);
    noiseGain.connect(audioCtx.destination);
    decryptGain.connect(audioCtx.destination);
    noiseNode = src;
  };

  // Prefer AudioWorklet (modern, no deprecation warnings). Fallback to ScriptProcessor if not available.
  if (audioCtx.audioWorklet && window.AudioWorkletNode) {
    const workletCode = `
      class WhiteNoiseProcessor extends AudioWorkletProcessor {
        process(inputs, outputs, parameters) {
          const output = outputs[0];
          for (let ch = 0; ch < output.length; ch++) {
            const out = output[ch];
            for (let i = 0; i < out.length; i++) {
              out[i] = (Math.random() * 2 - 1);
            }
          }
          return true;
        }
      }
      registerProcessor('white-noise', WhiteNoiseProcessor);
    `;
    const blob = new Blob([workletCode], { type: 'application/javascript' });
    const url = URL.createObjectURL(blob);

    audioInitPromise = audioCtx.audioWorklet.addModule(url).then(()=>{
      try { URL.revokeObjectURL(url); } catch(e){}
      const node = new AudioWorkletNode(audioCtx, 'white-noise', { numberOfInputs: 0, numberOfOutputs: 1, outputChannelCount: [1] });
      connectOut(node);
    }).catch(()=>{
      try { URL.revokeObjectURL(url); } catch(e){}
      // Fallback if AudioWorklet fails
      const bufferSize = 2048;
      const node = audioCtx.createScriptProcessor(bufferSize, 1, 1);
      node.onaudioprocess = (e)=>{
        const out = e.outputBuffer.getChannelData(0);
        for (let i=0;i<out.length;i++) out[i] = (Math.random() * 2 - 1);
      };
      connectOut(node);
    });
  } else {
    // Legacy fallback
    const bufferSize = 2048;
    const node = audioCtx.createScriptProcessor(bufferSize, 1, 1);
    node.onaudioprocess = (e)=>{
      const out = e.outputBuffer.getChannelData(0);
      for (let i=0;i<out.length;i++) out[i] = (Math.random() * 2 - 1);
    };
    connectOut(node);
  }
}

function setNoiseVolume(vol){
  ensureAudio();
  if (!audioCtx || !noiseGain) return;
  const apply = ()=>{
    if (audioCtx.state === 'suspended') audioCtx.resume().catch(()=>{});
    noiseGain.gain.value = Math.max(0, Math.min(0.35, Number(vol || 0)));
  };
  if (audioInitPromise) audioInitPromise.then(apply).catch(apply);
  else apply();
}

function playDecryptBed(ms){
  ensureAudio();
  if (!audioCtx || !decryptGain) return;
  if (audioCtx.state === 'suspended') audioCtx.resume().catch(()=>{});
  decryptGain.gain.value = 0.28;
  clearTimeout(decryptTimer);
  decryptTimer = setTimeout(()=>{ decryptGain.gain.value = 0.0; }, Math.max(250, Number(ms||0)));
}

function playBurstChirp(){
  // A quick digital chirp that reads as "data burst".
  ensureAudio();
  if (!audioCtx) return;
  if (audioCtx.state === 'suspended') audioCtx.resume().catch(()=>{});

  try {
    const o1 = audioCtx.createOscillator();
    const o2 = audioCtx.createOscillator();
    const g = audioCtx.createGain();
    g.gain.value = 0.0;

    o1.type = 'square';
    o2.type = 'sawtooth';
    o1.frequency.value = 520;
    o2.frequency.value = 880;

    o1.connect(g);
    o2.connect(g);
    g.connect(audioCtx.destination);

    const t0 = audioCtx.currentTime;
    g.gain.setValueAtTime(0.0, t0);
    g.gain.linearRampToValueAtTime(0.16, t0 + 0.03);
    g.gain.exponentialRampToValueAtTime(0.001, t0 + 0.22);

    // Frequency sweep
    o1.frequency.setValueAtTime(520, t0);
    o1.frequency.linearRampToValueAtTime(980, t0 + 0.18);
    o2.frequency.setValueAtTime(880, t0);
    o2.frequency.linearRampToValueAtTime(440, t0 + 0.18);

    o1.start(t0);
    o2.start(t0);
    o1.stop(t0 + 0.24);
    o2.stop(t0 + 0.24);
  } catch (e) {
    // ignore
  }

  // brief static kick
  if (decryptGain) {
    decryptGain.gain.value = 0.22;
    clearTimeout(burstTimer);
    burstTimer = setTimeout(()=>{ if (decryptGain) decryptGain.gain.value = 0.0; }, 220);
  }
}

// ------------------------------
// Decrypt Overlay
// ------------------------------
const decryptEl = document.getElementById('decrypt');
const decryptFill = document.getElementById('decryptFill');
const decryptPct = document.getElementById('decryptPct');
const decryptTitle = document.getElementById('decryptTitle');
let decryptAnim = null;

// Success burst overlay
const burstEl = document.getElementById('burst');
let burstAnim = null;

function showBurst(){
  if (!burstEl) return;
  burstEl.classList.remove('hidden');
  playBurstChirp();
  clearTimeout(burstAnim);
  burstAnim = setTimeout(()=>burstEl.classList.add('hidden'), 540);
}

function showDecrypt(ms){
  if (!decryptEl) return;
  decryptEl.classList.remove('hidden');
  const start = performance.now();
  const dur = Math.max(250, Number(ms||0));
  if (decryptAnim) cancelAnimationFrame(decryptAnim);

  const tick = (t)=>{
    const p = Math.max(0, Math.min(1, (t - start) / dur));
    const pct = Math.floor(p * 100);
    if (decryptFill) decryptFill.style.width = pct + '%';
    if (decryptPct) decryptPct.textContent = pct + '%';
    if (p < 1) decryptAnim = requestAnimationFrame(tick);
  };
  decryptAnim = requestAnimationFrame(tick);
}

function setDecryptTitle(text){
  if (!decryptTitle) return;
  decryptTitle.textContent = String(text || 'DECRYPTING COURIER SIGNAL…');
}

function hideDecrypt(){
  if (!decryptEl) return;
  decryptEl.classList.add('hidden');
  if (decryptFill) decryptFill.style.width = '0%';
  if (decryptPct) decryptPct.textContent = '0%';
  if (decryptAnim) cancelAnimationFrame(decryptAnim);
  decryptAnim = null;
}

// Listen for FiveM NUI open/close + toasts
window.addEventListener('message', (e)=>{
  const msg = e.data || {};
  if (msg.type === 'open') openUI();
  if (msg.type === 'close') root.classList.add('hidden');
  if (msg.type === 'toast' && msg.text) showToast(String(msg.text));

  // Cinematic: static bed while tracking
  if (msg.type === 'signal_audio') {
    setNoiseVolume(msg.on ? (msg.vol || 0) : 0);
  }

  // Cinematic: courier decrypt overlay + loud static layer
  if (msg.type === 'decrypt_overlay') {
    if (msg.on) showDecrypt(msg.ms || 3500);
    else hideDecrypt();
  }

  // Multi-stage courier protocol: update title + restart bar per phase
  if (msg.type === 'hack_phase') {
    setDecryptTitle(msg.title || 'DECRYPTING COURIER SIGNAL…');
    showDecrypt(msg.ms || 2500);
    if (msg.sub && decryptEl) {
      // optional subline swap (kept subtle)
      // (we avoid DOM lookups each frame; only set on phase messages)
      const sub = decryptEl.querySelector('.decryptSub');
      if (sub) sub.textContent = String(msg.sub);
    }
  }

  if (msg.type === 'hack_end') {
    // restore defaults
    setDecryptTitle('DECRYPTING COURIER SIGNAL…');
    const sub = decryptEl ? decryptEl.querySelector('.decryptSub') : null;
    if (sub) sub.textContent = 'Hold steady. Noise is expected.';
    hideDecrypt();
  }
  if (msg.type === 'decrypt_audio') {
    if (msg.on) playDecryptBed(msg.ms || 3500);
    else if (decryptGain) decryptGain.gain.value = 0.0;
  }

  // Cinematic: decrypt success data burst
  if (msg.type === 'decrypt_success') {
    showBurst();
  }

  // Live order status updates (client events)
  if (msg.type === 'order_update' && msg.orderId) {
    // Always refresh orders from the server when an update arrives.
    // This prevents the details panel getting stuck on an old status
    // if the order object in state is stale.
    nui('bm_listOrders', {}).then((list)=>{
      if (!list) return;
      setOrders(list);

      // If we had an order selected, re-select the latest copy from the refreshed list.
      if (state.selectedOrder) {
        const found = (Array.isArray(list) ? list : []).find(o => Number(o.id) === Number(state.selectedOrder.id));
        if (found) {
          // If it was claimed, clear the selection so the details panel doesn't linger.
          if (String(found.status || '').toLowerCase() === 'claimed') {
            state.selectedOrder = null;
            $('odTitle').textContent = 'Select an order';
            $('odSub').textContent = 'Orders update live as your courier moves.';
            $('odBadge').textContent = '';
            $('odItems').textContent = '—';
            $('odHint').textContent = '—';
          } else {
            selectOrder(found);
          }
        }
      }
    });
  }
});

// Prevent "nothing shows" if you open page directly in browser
// (No automatic open in FiveM, but in a normal browser you can press F12 and run: openUI())
window.openUI = openUI;