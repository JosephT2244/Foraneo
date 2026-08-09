import './styles.css';
import {
  categoryMeta,
  defaultPlanner,
  initialProducts,
  initialRecipes,
  initialTasks
} from './data.js';
import {
  PRICE_TIERS,
  evaluateComparablePrice,
  evaluatePrice
} from './price-rules.js';

const app = document.querySelector('#app');
const STORAGE_KEY = 'foraneo-v2';
const LEGACY_STORAGE_KEYS = ['casa-en-calma-v1'];
const DAYS = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];
const MEALS = ['desayuno', 'comida', 'cena'];

const pageMeta = {
  inicio: { title: 'Buenos días, Joseph', subtitle: 'Tu hogar está a un vistazo de distancia.' },
  despensa: { title: 'Tu despensa', subtitle: 'Todo lo que tienes, organizado con cariño.' },
  compras: { title: 'Compras inteligentes', subtitle: 'Decide con calma antes de llenar el carrito.' },
  cocina: { title: 'Cocina contigo', subtitle: 'Ideas ricas con lo que ya está en casa.' },
  agenda: { title: 'Tu agenda', subtitle: 'Una semana ligera empieza por aquí.' }
};

const navItems = [
  { id: 'inicio', label: 'Inicio', icon: '⌂' },
  { id: 'despensa', label: 'Despensa', icon: '▦' },
  { id: 'compras', label: 'Compras', icon: '⌑' },
  { id: 'cocina', label: 'Cocina', icon: '♨' },
  { id: 'agenda', label: 'Agenda', icon: '✓' }
];

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function createDefaultState() {
  return {
    products: clone(initialProducts),
    recipes: clone(initialRecipes),
    tasks: clone(initialTasks),
    planner: clone(defaultPlanner),
    shopping: [],
    notifications: [],
    widgets: {
      urgent: true,
      low: true,
      meal: true,
      tasks: true
    },
    activePage: 'inicio',
    selectedCategory: 'todos',
    inventoryQuery: '',
    taskFilter: 'today',
    modal: null,
    notificationOpen: false,
    pricePreview: null,
    scanResult: null,
    toast: null
  };
}

function loadState() {
  const fallback = createDefaultState();
  try {
    const raw = localStorage.getItem(STORAGE_KEY) || LEGACY_STORAGE_KEYS.map(function (key) {
      return localStorage.getItem(key);
    }).find(Boolean);
    if (!raw) return fallback;
    const saved = JSON.parse(raw);
    return Object.assign(fallback, saved, {
      products: Array.isArray(saved.products) ? saved.products : fallback.products,
      recipes: Array.isArray(saved.recipes) ? saved.recipes : fallback.recipes,
      tasks: Array.isArray(saved.tasks) ? saved.tasks : fallback.tasks,
      shopping: Array.isArray(saved.shopping) ? saved.shopping : fallback.shopping,
      notifications: Array.isArray(saved.notifications) ? saved.notifications : fallback.notifications,
      planner: saved.planner || fallback.planner,
      widgets: Object.assign({}, fallback.widgets, saved.widgets || {}),
      activePage: 'inicio',
      selectedCategory: 'todos',
      inventoryQuery: '',
      taskFilter: 'today',
      modal: null,
      notificationOpen: false,
      pricePreview: null,
      scanResult: null,
      toast: null
    });
  } catch (error) {
    return fallback;
  }
}

let state = loadState();

function persist() {
  const saved = {
    products: state.products,
    recipes: state.recipes,
    tasks: state.tasks,
    planner: state.planner,
    shopping: state.shopping,
    notifications: state.notifications,
    widgets: state.widgets
  };
  localStorage.setItem(STORAGE_KEY, JSON.stringify(saved));
}

function escapeHtml(value) {
  return String(value == null ? '' : value).replace(/[&<>"']/g, function (character) {
    return {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#039;'
    }[character];
  });
}

function escapeAttr(value) {
  return escapeHtml(value);
}

function normalize(value) {
  return String(value || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim();
}

function formatMoney(value) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2
  }).format(Number(value || 0));
}

function formatNumber(value) {
  const number = Number(value || 0);
  return Number.isInteger(number) ? String(number) : number.toFixed(1).replace('.0', '');
}

function categoryLabel(category) {
  return categoryMeta[category] || categoryMeta.otros;
}

function productStatus(product) {
  if (Number(product.stock) <= 0) return 'urgent';
  if (Number(product.stock) <= Number(product.lowAt || 0)) return 'low';
  return 'stocked';
}

const statusMeta = {
  urgent: { label: 'Compra urgente', icon: '!', note: 'Ya se terminó', className: 'status-urgent' },
  low: { label: 'Por comprar', icon: '↘', note: 'Queda poco', className: 'status-low' },
  stocked: { label: 'En casa', icon: '✓', note: 'Todo en orden', className: 'status-stocked' }
};

function alertId(product, status) {
  return 'stock-' + status + '-' + product.id;
}

function syncInventoryNotifications() {
  state.products.forEach(function (product) {
    const status = productStatus(product);
    const statuses = ['urgent', 'low'];
    statuses.forEach(function (name) {
      const id = alertId(product, name);
      const shouldKeep = name === status;
      const index = state.notifications.findIndex(function (notification) {
        return notification.id === id;
      });
      if (!shouldKeep && index >= 0) state.notifications.splice(index, 1);
      if (shouldKeep && index < 0) {
        state.notifications.unshift({
          id: id,
          type: name,
          read: false,
          title: name === 'urgent' ? product.name + ' se terminó' : product.name + ' está por terminarse',
          body: name === 'urgent'
            ? 'Pásalo a compra urgente para no olvidarlo.'
            : 'Queda poco. Ya está en tu lista de compras.',
          time: 'Ahora'
        });
      }
    });
  });
}

function commit(message, tone) {
  syncInventoryNotifications();
  persist();
  if (message) {
    state.toast = {
      message: message,
      tone: tone || 'success'
    };
    window.clearTimeout(commit.toastTimer);
    commit.toastTimer = window.setTimeout(function () {
      state.toast = null;
      render();
    }, 3000);
  }
  render();
}

function getProduct(id) {
  return state.products.find(function (product) {
    return product.id === id;
  });
}

function getRecipe(id) {
  return state.recipes.find(function (recipe) {
    return recipe.id === id;
  });
}

function safeRecipe(recipe) {
  const text = normalize(
    recipe.title + ' ' + recipe.description + ' ' + (recipe.ingredients || []).join(' ')
  );
  const blockedEgg = /(huevo revuelto|huevos revueltos|scrambled|omelette|omelet|frittata|tortilla de huevo)/.test(text);
  const hasEgg = /huevo/.test(text);
  const allowedEgg = /(huevo cocido|huevo duro|huevo hervido|huevo poche|huevo poché)/.test(text);
  const hasRice = /arroz/.test(text);
  const allowedRice = /(chino|china|asiatic|wok|fried rice)/.test(text);
  return !blockedEgg && (!hasEgg || allowedEgg) && (!hasRice || allowedRice);
}

function productMatchesIngredient(product, ingredient) {
  if (Number(product.stock) <= 0) return false;
  const productText = normalize(product.name + ' ' + product.description);
  const ingredientText = normalize(ingredient);
  if (productText.includes(ingredientText) || ingredientText.includes(normalize(product.name))) return true;
  const synonyms = {
    tomate: ['jitomate'],
    papa: ['patata'],
    platano: ['banana'],
    limon: ['limon amarillo'],
    huevo: ['huevos'],
    leche: ['bebida vegetal']
  };
  return Object.keys(synonyms).some(function (key) {
    const words = [key].concat(synonyms[key]);
    return words.some(function (word) {
      return ingredientText.includes(word) && productText.includes(word);
    });
  });
}

function recipeCoverage(recipe) {
  const available = [];
  const missing = [];
  (recipe.ingredients || []).forEach(function (ingredient) {
    const found = state.products.some(function (product) {
      return productMatchesIngredient(product, ingredient);
    });
    if (found) available.push(ingredient);
    else missing.push(ingredient);
  });
  return {
    available: available,
    missing: missing,
    score: recipe.ingredients && recipe.ingredients.length
      ? Math.round((available.length / recipe.ingredients.length) * 100)
      : 0
  };
}

function recommendedRecipes() {
  return state.recipes
    .filter(safeRecipe)
    .map(function (recipe) {
      return Object.assign({}, recipe, { coverage: recipeCoverage(recipe) });
    })
    .sort(function (a, b) {
      return b.coverage.score - a.coverage.score;
    });
}

function dayKeyForToday() {
  const day = new Date().getDay();
  return DAYS[day === 0 ? 6 : day - 1];
}

function todayMeals() {
  const mealIds = state.planner[dayKeyForToday()] || {};
  const picked = MEALS.map(function (meal) {
    return getRecipe(mealIds[meal]);
  }).filter(Boolean);
  return picked.length ? picked : recommendedRecipes().slice(0, 2);
}

function shoppingEntries(kind) {
  const derived = state.products
    .filter(function (product) {
      const status = productStatus(product);
      return kind === 'urgent' ? status === 'urgent' : status === 'low';
    })
    .map(function (product) {
      return {
        id: 'inventory-' + product.id,
        productId: product.id,
        name: product.name,
        detail: product.content,
        image: product.photo,
        source: 'inventario',
        kind: kind
      };
    });

  const manual = state.shopping.filter(function (entry) {
    return kind === 'urgent' ? entry.kind === 'urgent' : entry.kind !== 'urgent';
  });
  return derived.concat(manual);
}

function unreadNotifications() {
  return state.notifications.filter(function (notification) {
    return !notification.read;
  }).length;
}

function statusPill(status) {
  const meta = statusMeta[status];
  return '<span class="status-pill ' + meta.className + '"><b>' + meta.icon + '</b>' +
    escapeHtml(meta.label) + '</span>';
}

function renderSidebar() {
  return '<aside class="sidebar">' +
    '<a class="brand" href="#" data-action="navigate" data-page="inicio" aria-label="Ir al inicio">' +
      '<span class="brand-mark">⌂</span>' +
      '<span><strong>Foráneo</strong><em>mi hogar</em></span>' +
    '</a>' +
    '<nav class="side-nav" aria-label="Navegación principal">' +
      navItems.map(function (item) {
        const active = item.id === state.activePage ? ' active' : '';
        return '<button class="nav-link' + active + '" data-action="navigate" data-page="' + item.id + '">' +
          '<span class="nav-icon">' + item.icon + '</span><span>' + item.label + '</span>' +
        '</button>';
      }).join('') +
    '</nav>' +
    '<div class="sidebar-foot">' +
      '<div class="home-note"><span>☼</span><p><b>Modo hogar</b><br/>Todo bajo control</p></div>' +
      '<button class="text-button" data-action="open-widgets">◫ Configurar widgets</button>' +
    '</div>' +
  '</aside>';
}

function renderTopbar() {
  const meta = pageMeta[state.activePage];
  return '<header class="topbar">' +
    '<div><p class="eyebrow">Sábado, 8 de agosto</p><h1>' + meta.title + '</h1><p class="page-subtitle">' + meta.subtitle + '</p></div>' +
    '<div class="top-actions">' +
      '<button class="round-button notification-button" data-action="toggle-notifications" aria-label="Abrir notificaciones">♧' +
        (unreadNotifications() ? '<span class="notification-count">' + unreadNotifications() + '</span>' : '') +
      '</button>' +
      '<button class="profile-button" data-action="open-widgets"><span class="profile-avatar">J</span><span class="profile-copy"><b>Joseph</b><small>Mi hogar</small></span></button>' +
    '</div>' +
  '</header>';
}

function renderMobileNav() {
  return '<nav class="mobile-nav" aria-label="Navegación móvil">' +
    navItems.map(function (item) {
      const active = item.id === state.activePage ? ' active' : '';
      return '<button class="mobile-nav-link' + active + '" data-action="navigate" data-page="' + item.id + '">' +
        '<span>' + item.icon + '</span><small>' + item.label + '</small></button>';
    }).join('') +
  '</nav>';
}

function renderStat(icon, number, label, tone) {
  return '<article class="stat-card ' + (tone || '') + '">' +
    '<span class="stat-icon">' + icon + '</span>' +
    '<div><strong>' + number + '</strong><span>' + label + '</span></div>' +
  '</article>';
}

function renderShoppingPreview(entries, urgent) {
  if (!entries.length) {
    return '<div class="empty-compact"><span>☼</span><p>' + (urgent ? 'No hay urgencias. ¡Qué gusto!' : 'Nada pendiente por comprar.') + '</p></div>';
  }
  return '<div class="mini-list">' + entries.slice(0, 3).map(function (entry) {
    return '<div class="mini-list-row"><img src="' + escapeAttr(entry.image || '') + '" alt="" /><div><b>' +
      escapeHtml(entry.name) + '</b><small>' + escapeHtml(entry.detail || entry.source) + '</small></div>' +
      '<button class="icon-action" data-action="navigate" data-page="compras" aria-label="Ver compras">→</button></div>';
  }).join('') + '</div>';
}

function renderDashboard() {
  const urgent = shoppingEntries('urgent');
  const low = shoppingEntries('low');
  const openTasks = state.tasks.filter(function (task) { return !task.completed; });
  const meal = todayMeals()[0];
  const lowProducts = state.products.filter(function (product) {
    return productStatus(product) === 'low';
  });

  return '<section class="dashboard-page page-enter">' +
    '<section class="welcome-hero">' +
      '<div class="hero-copy"><span class="kicker">✦ Tu espacio para vivir mejor</span>' +
        '<h2>Un hogar cuidado<br/>se siente <i>ligero.</i></h2>' +
        '<p>Organiza lo que tienes, compra con inteligencia y deja que las pequeñas cosas estén en su lugar.</p>' +
        '<div class="hero-actions"><button class="primary-button" data-action="open-product-modal">＋ Añadir a casa</button>' +
        '<button class="soft-button" data-action="navigate" data-page="cocina">Ver ideas de cocina <span>→</span></button></div>' +
      '</div>' +
      '<div class="hero-scene">' +
        '<img src="https://images.unsplash.com/photo-1494438639946-1ebd1d20bf85?auto=format&fit=crop&w=1400&q=90" alt="Cocina luminosa y acogedora" />' +
        '<div class="scene-card scene-card-top"><span>✦</span><p><b>' + state.products.filter(function (p) { return productStatus(p) === 'stocked'; }).length + ' cosas</b><br/>en buena forma</p></div>' +
        '<div class="scene-card scene-card-bottom"><span>♨</span><p><b>' + (meal ? escapeHtml(meal.title) : 'Una idea rica') + '</b><br/>para disfrutar hoy</p></div>' +
      '</div>' +
    '</section>' +
    '<section class="stat-grid">' +
      renderStat('!', urgent.length, 'compras urgentes', urgent.length ? 'urgent-stat' : 'sage-stat') +
      renderStat('↘', low.length, 'por reponer', low.length ? 'warning-stat' : 'sage-stat') +
      renderStat('☼', Math.max(0, state.products.length - urgent.length - low.length), 'productos en orden', 'sage-stat') +
      renderStat('✓', openTasks.length, 'pendientes de hoy', 'lilac-stat') +
    '</section>' +
    '<section class="dashboard-grid">' +
      '<article class="content-card urgent-card"><div class="card-heading"><div><span class="label-icon danger">!</span><p class="eyebrow">Atención ahora</p><h3>Compra urgente</h3></div><button class="arrow-link" data-action="navigate" data-page="compras">Ver todo →</button></div>' +
      renderShoppingPreview(urgent, true) + '</article>' +
      '<article class="content-card meal-card"><div class="card-heading"><div><span class="label-icon peach">♨</span><p class="eyebrow">En tu semana</p><h3>¿Qué cocinamos?</h3></div><button class="arrow-link" data-action="navigate" data-page="cocina">Explorar →</button></div>' +
      (meal ? '<div class="featured-meal"><img src="' + escapeAttr(meal.image) + '" alt="" /><div><span class="recipe-tag">' + escapeHtml(meal.tag) + '</span><h4>' + escapeHtml(meal.title) + '</h4><p>' + escapeHtml(meal.time) + ' · ' + meal.servings + ' porciones</p><button class="tiny-button" data-action="open-recipe-details" data-id="' + meal.id + '">Ver receta</button></div></div>' : '<div class="empty-compact"><span>♨</span><p>Planea tu primera comida de la semana.</p></div>') +
      '</article>' +
      '<article class="content-card stock-card"><div class="card-heading"><div><span class="label-icon sage">⌂</span><p class="eyebrow">Un vistazo</p><h3>Se está terminando</h3></div><button class="arrow-link" data-action="navigate" data-page="despensa">Despensa →</button></div>' +
      (lowProducts.length ? '<div class="low-product-strip">' + lowProducts.slice(0, 3).map(function (product) {
        return '<div class="low-product"><img src="' + escapeAttr(product.photo) + '" alt="" /><span>' + escapeHtml(product.name) + '</span><b>' + formatNumber(product.stock) + '</b></div>';
      }).join('') + '</div>' : '<div class="empty-compact"><span>☼</span><p>Tu despensa está al día.</p></div>') +
      '</article>' +
    '</section>' +
    renderWidgetsPreview() +
  '</section>';
}

function renderWidgetsPreview() {
  const active = Object.keys(state.widgets).filter(function (key) { return state.widgets[key]; }).length;
  return '<section class="widget-preview"><div><p class="eyebrow">Para tu pantalla de inicio</p><h3>Tus widgets esenciales</h3><p>Elige qué quieres tener siempre a la mano.</p></div>' +
    '<div class="widget-mini-row">' +
      (state.widgets.urgent ? '<button data-action="navigate" data-page="compras" class="mini-widget urgent-widget">!<span>Urgencias</span></button>' : '') +
      (state.widgets.low ? '<button data-action="navigate" data-page="despensa" class="mini-widget low-widget">↘<span>Por comprar</span></button>' : '') +
      (state.widgets.meal ? '<button data-action="navigate" data-page="cocina" class="mini-widget meal-widget">♨<span>Comida de hoy</span></button>' : '') +
      (state.widgets.tasks ? '<button data-action="navigate" data-page="agenda" class="mini-widget task-widget">✓<span>Tareas</span></button>' : '') +
    '</div><button class="soft-button" data-action="open-widgets">' + active + ' activos · Personalizar</button></section>';
}

function renderCategoryChips() {
  const categories = [{ id: 'todos', label: 'Todo', emoji: '✦' }]
    .concat(Object.keys(categoryMeta).map(function (key) {
      return { id: key, label: categoryMeta[key].label, emoji: categoryMeta[key].emoji };
    }));
  return '<div class="chip-row" role="tablist">' + categories.map(function (category) {
    const selected = state.selectedCategory === category.id ? ' selected' : '';
    return '<button class="filter-chip' + selected + '" data-action="filter-category" data-category="' + category.id + '">' +
      '<span>' + category.emoji + '</span>' + category.label + '</button>';
  }).join('') + '</div>';
}

function renderProductCard(product) {
  const status = productStatus(product);
  const meta = statusMeta[status];
  const progress = status === 'urgent' ? 0 : Math.min(100, Math.max(12, Number(product.stock) / Math.max(Number(product.lowAt || 1) * 3, 1) * 100));
  return '<article class="product-card ' + (status !== 'stocked' ? 'needs-attention' : '') + '">' +
    '<div class="product-image-wrap"><img src="' + escapeAttr(product.photo) + '" alt="Foto de ' + escapeAttr(product.name) + '" />' +
      '<span class="category-badge">' + categoryLabel(product.category).emoji + ' ' + categoryLabel(product.category).label + '</span>' +
      '<button class="product-more" data-action="open-product-details" data-id="' + product.id + '" aria-label="Ver detalles">•••</button></div>' +
    '<div class="product-card-body"><div class="product-title-line"><div><h3>' + escapeHtml(product.name) + '</h3><p>' + escapeHtml(product.content) + '</p></div>' + statusPill(status) + '</div>' +
    '<p class="product-description">' + escapeHtml(product.description) + '</p>' +
    '<div class="stock-meter"><div class="meter-label"><span>' + meta.note + '</span><b>' + formatNumber(product.stock) + ' en casa</b></div><div class="meter-track"><i class="' + status + '" style="width:' + progress + '%"></i></div></div>' +
    '<div class="product-footer"><div><small>Precio usual</small><b>' + formatMoney(product.usualPrice) + '</b></div><div class="product-actions">' +
      '<button class="small-round" data-action="consume" data-id="' + product.id + '" aria-label="Descontar uno">−</button>' +
      '<button class="small-round plus" data-action="restock" data-id="' + product.id + '" aria-label="Agregar uno">＋</button>' +
    '</div></div></div>' +
  '</article>';
}

function renderInventory() {
  const filtered = state.products.filter(function (product) {
    const categoryMatches = state.selectedCategory === 'todos' || product.category === state.selectedCategory;
    const query = normalize(state.inventoryQuery);
    const queryMatches = !query || normalize(product.name + ' ' + product.description).includes(query);
    return categoryMatches && queryMatches;
  });
  const activeCount = state.products.filter(function (product) {
    return productStatus(product) === 'stocked';
  }).length;

  return '<section class="page-section page-enter">' +
    '<div class="section-title-row"><div><p class="eyebrow">Tu casa, organizada</p><h2>Productos e inventario</h2><p>Registra la foto, contenido y precio de cada cosa que entra a casa.</p></div>' +
      '<button class="primary-button" data-action="open-product-modal">＋ Añadir producto</button></div>' +
    '<section class="inventory-summary">' +
      '<div><span>⌂</span><p><b>' + activeCount + ' productos</b><br/>en buen nivel</p></div>' +
      '<div><span>↘</span><p><b>' + shoppingEntries('low').length + ' por reponer</b><br/>ya están anotados</p></div>' +
      '<div><span>!</span><p><b>' + shoppingEntries('urgent').length + ' urgentes</b><br/>no los dejes pasar</p></div>' +
    '</section>' +
    '<div class="inventory-controls">' + renderCategoryChips() +
      '<form id="inventory-search" class="search-field"><span>⌕</span><input name="query" value="' + escapeAttr(state.inventoryQuery) + '" placeholder="Buscar en casa" /><button type="submit">Buscar</button></form></div>' +
    (filtered.length ? '<div class="product-grid">' + filtered.map(renderProductCard).join('') + '</div>' :
      '<div class="empty-state"><span>⌕</span><h3>No encontramos ese producto</h3><p>Prueba con otro nombre o agrega uno nuevo.</p></div>') +
  '</section>';
}

function renderDecision(decision, product) {
  if (!decision) {
    return '<div class="price-result price-idle"><span>◌</span><div><b>Escribe el precio de hoy</b><p>Te diremos si conviene comprarlo antes de decidir.</p></div></div>';
  }
  const classMap = {
    deal: 'decision-deal',
    approved: 'decision-approved',
    avoid: 'decision-avoid',
    'needs-content': 'decision-neutral',
    'needs-reference': 'decision-neutral'
  };
  const iconMap = {
    deal: '✦',
    approved: '✓',
    avoid: '!',
    'needs-content': '?',
    'needs-reference': '?'
  };
  const normalized = decision.comparablePrice != null && Math.abs(decision.comparablePrice - state.pricePreview.price) > 0.005
    ? '<small>Equivale a ' + formatMoney(decision.comparablePrice) + ' por ' + escapeHtml(product.content) + '.</small>'
    : '';
  const canRegister = decision.decision !== 'needs-content' && decision.decision !== 'needs-reference';
  const buttonLabel = decision.decision === 'avoid' ? 'Registrar de todos modos' : 'Registrar compra';
  return '<div class="price-result ' + classMap[decision.decision] + '"><span class="decision-icon">' + iconMap[decision.decision] + '</span><div><b>' +
    escapeHtml(decision.label) + '</b><p>' + escapeHtml(decision.message) + '</p>' + normalized +
    (canRegister ? '<button class="decision-button" data-action="register-purchase">＋ ' + buttonLabel + '</button>' : '') +
  '</div></div>';
}

function renderShoppingEntry(entry, urgent) {
  const product = entry.productId ? getProduct(entry.productId) : null;
  const itemImage = entry.image || (product && product.photo) || 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=400&q=75';
  const label = urgent ? 'Urgente' : entry.source === 'receta' ? 'De receta' : 'Por comprar';
  return '<article class="shopping-item ' + (urgent ? 'is-urgent' : '') + '"><img src="' + escapeAttr(itemImage) + '" alt="" /><div class="shopping-item-info"><div><span class="source-tag">' + escapeHtml(label) + '</span><h4>' + escapeHtml(entry.name) + '</h4></div><p>' + escapeHtml(entry.detail || 'Añadido manualmente') + '</p></div>' +
    (product ? '<button class="small-round plus" data-action="restock" data-id="' + product.id + '" aria-label="Registrar compra de ' + escapeAttr(product.name) + '">✓</button>' :
      '<button class="small-round" data-action="remove-shopping" data-id="' + entry.id + '" aria-label="Quitar de compras">×</button>') +
  '</article>';
}

function renderPriceRules() {
  return '<details class="price-rules"><summary><span>⌁</span> Ver tus reglas de precio <small>Se comparan con el precio usual</small></summary>' +
    '<div class="rule-table"><div class="rule-head"><span>Precio usual</span><span>Oferta</span><span>Evitar</span></div>' +
    PRICE_TIERS.map(function (tier) {
      return '<div class="rule-row"><span>' + tier.label + '</span><b>−' + tier.discountPercent + '%</b><b>+' + tier.increasePercent + '%</b></div>';
    }).join('') +
    '</div><p class="rule-note">Para paquetes de otro tamaño, la app normaliza el precio a la cantidad habitual antes de recomendarte.</p></details>';
}

function renderShopping() {
  const urgent = shoppingEntries('urgent');
  const low = shoppingEntries('low');
  const selectedProduct = state.pricePreview ? getProduct(state.pricePreview.productId) : state.products[0];
  const preview = state.pricePreview && selectedProduct ? state.pricePreview.result : null;

  return '<section class="page-section page-enter">' +
    '<div class="section-title-row"><div><p class="eyebrow">Compra con intención</p><h2>Tu lista inteligente</h2><p>El semáforo usa tus límites personales y también reconoce paquetes de distinto tamaño.</p></div>' +
      '<button class="soft-button" data-action="activate-notifications">♧ Activar alertas</button></div>' +
    '<section class="price-checker">' +
      '<div class="checker-copy"><span class="checker-icon">⌁</span><p class="eyebrow">Antes de ponerlo al carrito</p><h3>¿Conviene este precio?</h3><p>Compara un producto y decide sin dudas.</p></div>' +
      '<form id="price-check-form" class="price-check-form"><label>Producto<select name="productId">' +
        state.products.map(function (product) {
          const selected = selectedProduct && product.id === selectedProduct.id ? ' selected' : '';
          return '<option value="' + product.id + '"' + selected + '>' + escapeHtml(product.name) + ' · usual ' + formatMoney(product.usualPrice) + '</option>';
        }).join('') +
      '</select></label><label>Precio que ves<input required min="0" step="0.01" name="price" type="number" value="' + (state.pricePreview ? state.pricePreview.price : '') + '" placeholder="$0.00" /></label>' +
      '<div class="same-row"><label>Contenido nuevo<input required min="0.01" step="0.01" name="contentValue" type="number" value="' + (state.pricePreview ? state.pricePreview.contentValue : (selectedProduct ? selectedProduct.contentValue : '')) + '" /></label><label>Unidad<select name="contentUnit">' +
        ['g', 'kg', 'ml', 'L', 'piezas', 'rollos'].map(function (unit) {
          const choice = state.pricePreview ? state.pricePreview.contentUnit : (selectedProduct ? selectedProduct.contentUnit : 'g');
          return '<option value="' + unit + '"' + (choice === unit ? ' selected' : '') + '>' + unit + '</option>';
        }).join('') +
      '</select></label></div><button class="primary-button" type="button" data-action="check-price">Revisar precio →</button></form>' +
      '<div class="checker-result">' + renderDecision(preview, selectedProduct || state.products[0]) + '</div>' +
    '</section>' +
    renderPriceRules() +
    '<div class="shopping-columns">' +
      '<section class="shopping-section"><div class="list-heading"><div><span class="label-icon danger">!</span><h3>Compra urgente</h3></div><span>' + urgent.length + ' artículos</span></div>' +
        (urgent.length ? '<div class="shopping-list">' + urgent.map(function (entry) { return renderShoppingEntry(entry, true); }).join('') + '</div>' : '<div class="empty-state small"><span>☼</span><h3>Todo cubierto por ahora</h3><p>No hay productos agotados.</p></div>') +
      '</section>' +
      '<section class="shopping-section"><div class="list-heading"><div><span class="label-icon mustard">↘</span><h3>Por comprar</h3></div><span>' + low.length + ' artículos</span></div>' +
        (low.length ? '<div class="shopping-list">' + low.map(function (entry) { return renderShoppingEntry(entry, false); }).join('') + '</div>' : '<div class="empty-state small"><span>✦</span><h3>Lista despejada</h3><p>Añade ideas cuando las necesites.</p></div>') +
        '<form id="manual-shopping-form" class="add-inline-form"><input name="name" required placeholder="Agregar algo a la lista…" /><input name="detail" placeholder="Cantidad o nota" /><button class="small-round plus" type="submit">＋</button></form>' +
      '</section>' +
    '</div>' +
  '</section>';
}

function renderRecipeCard(recipe) {
  const coverage = recipe.coverage || recipeCoverage(recipe);
  const readiness = coverage.score >= 80 ? 'ready' : coverage.score >= 45 ? 'almost' : 'needs';
  const readinessLabel = readiness === 'ready' ? 'Casi lista' : readiness === 'almost' ? 'Te faltan ' + coverage.missing.length : 'Para otra compra';
  return '<article class="recipe-card"><div class="recipe-image"><img src="' + escapeAttr(recipe.image) + '" alt="Foto de ' + escapeAttr(recipe.title) + '" /><span class="recipe-tag">' + escapeHtml(recipe.tag || 'Receta propia') + '</span><span class="readiness ' + readiness + '">' + readinessLabel + '</span></div>' +
    '<div class="recipe-body"><div class="recipe-meta"><span>◷ ' + escapeHtml(recipe.time || '20 min') + '</span><span>◌ ' + (recipe.servings || 2) + ' porciones</span></div><h3>' + escapeHtml(recipe.title) + '</h3><p>' + escapeHtml(recipe.description) + '</p>' +
    '<div class="ingredient-dots"><span class="available-dot">● ' + coverage.available.length + ' en casa</span><span class="missing-dot">● ' + coverage.missing.length + ' faltan</span></div>' +
    '<div class="recipe-actions"><button class="soft-button compact" data-action="open-recipe-details" data-id="' + recipe.id + '">Ver receta</button>' +
      (coverage.missing.length ? '<button class="text-button compact" data-action="add-missing" data-id="' + recipe.id + '">Añadir faltantes ＋</button>' : '<button class="text-button compact" data-action="plan-recipe" data-id="' + recipe.id + '">Planear ＋</button>') +
    '</div></div></article>';
}

function renderScanResult() {
  if (!state.scanResult) return '';
  const result = state.scanResult;
  return '<div class="ai-result"><span class="ai-sparkle">✦</span><div><p class="eyebrow">AromIA te propone</p><h4>' + escapeHtml(result.headline) + '</h4><p>' + escapeHtml(result.description) + '</p>' +
    (result.recipes.length ? '<div class="ai-recipe-pills">' + result.recipes.map(function (recipe) {
      return '<button data-action="open-recipe-details" data-id="' + recipe.id + '">' + escapeHtml(recipe.title) + ' →</button>';
    }).join('') + '</div>' : '') +
  '</div></div>';
}

function renderPlanner() {
  const recipes = state.recipes.filter(safeRecipe);
  return '<section class="planner-section"><div class="planner-heading"><div><p class="eyebrow">Tu mesa, sin improvisar</p><h3>Plan de la semana</h3></div><span class="planner-note">✦ Solo recetas compatibles con tus preferencias</span></div>' +
    '<div class="planner-grid"><div class="planner-corner">Comida</div>' + DAYS.map(function (day) {
      return '<div class="planner-day">' + day.slice(0, 3) + '</div>';
    }).join('') +
    MEALS.map(function (meal) {
      return '<div class="meal-label">' + meal + '</div>' + DAYS.map(function (day) {
        const chosen = state.planner[day] && state.planner[day][meal];
        return '<label class="meal-slot"><select data-planner-day="' + day + '" data-planner-meal="' + meal + '" aria-label="' + meal + ' del ' + day + '">' +
          '<option value="">—</option>' + recipes.map(function (recipe) {
            return '<option value="' + recipe.id + '"' + (chosen === recipe.id ? ' selected' : '') + '>' + escapeHtml(recipe.title) + '</option>';
          }).join('') + '</select></label>';
      }).join('');
    }).join('') +
    '</div></section>';
}

function renderKitchen() {
  const recipes = recommendedRecipes();
  return '<section class="page-section page-enter">' +
    '<div class="section-title-row"><div><p class="eyebrow">Cocina con lo que tienes</p><h2>Ideas para hoy</h2><p>AromIA considera tu despensa y omite preparaciones de huevo o arroz que no te gustan.</p></div>' +
      '<button class="primary-button" data-action="open-recipe-modal">＋ Crear receta</button></div>' +
    '<section class="ai-scanner"><div class="scanner-art"><img src="https://images.unsplash.com/photo-1556910103-1c02745aae4d?auto=format&fit=crop&w=900&q=85" alt="Ingredientes frescos sobre una mesa" /><span>✦</span></div><div class="scanner-copy"><p class="eyebrow">AromIA · asistente de cocina</p><h3>Cuéntame qué alimento tienes</h3><p>Analizo su nombre y descripción para proponerte combinaciones que sí quieres comer.</p><form id="food-scan-form"><input name="name" required placeholder="Ej. pasta fusilli" /><textarea name="description" placeholder="Descripción opcional del producto"></textarea><button class="soft-button" type="submit">Analizar ingrediente →</button></form></div></section>' +
    renderScanResult() +
    '<div class="recipe-section-title"><div><h3>Lo mejor para tu despensa</h3><p>Ordenado por los ingredientes que ya están contigo.</p></div><span class="safe-filter">✓ Filtros de preferencias activos</span></div>' +
    '<div class="recipe-grid">' + recipes.map(renderRecipeCard).join('') + '</div>' +
    renderPlanner() +
  '</section>';
}

function renderTask(task) {
  return '<article class="task-item ' + (task.completed ? 'completed' : '') + '">' +
    '<button class="task-check" data-action="toggle-task" data-id="' + task.id + '" aria-label="' + (task.completed ? 'Reabrir' : 'Completar') + ' tarea">' + (task.completed ? '✓' : '') + '</button>' +
    '<div class="task-copy"><h4>' + escapeHtml(task.title) + '</h4>' + (task.notes ? '<p>' + escapeHtml(task.notes) + '</p>' : '') + '</div>' +
    '<span class="priority priority-' + task.priority + '">' + escapeHtml(task.priority) + '</span>' +
  '</article>';
}

function renderAgenda() {
  const today = state.tasks.filter(function (task) { return task.when === 'today'; });
  const week = state.tasks.filter(function (task) { return task.when === 'week'; });
  const shown = state.taskFilter === 'today' ? today : state.taskFilter === 'week' ? week : state.tasks;
  const complete = state.tasks.filter(function (task) { return task.completed; }).length;
  return '<section class="page-section page-enter">' +
    '<div class="section-title-row"><div><p class="eyebrow">Con espacio para respirar</p><h2>Tu día y tu semana</h2><p>Deja los pendientes aquí y celebra cada cosa que sí hiciste.</p></div><button class="primary-button" data-action="focus-add-task">＋ Nueva tarea</button></div>' +
    '<section class="agenda-hero"><div><span class="day-stamp">SÁB<br/><b>08</b></span><div><p class="eyebrow">Hoy</p><h3>Una cosa a la vez.</h3><p>Tienes ' + today.filter(function (task) { return !task.completed; }).length + ' pendientes para hoy. Vas bien.</p></div></div><div class="agenda-progress"><span>' + complete + '/' + state.tasks.length + '</span><small>completadas</small><div><i style="width:' + (state.tasks.length ? Math.round((complete / state.tasks.length) * 100) : 0) + '%"></i></div></div></section>' +
    '<div class="agenda-layout"><section class="task-panel"><div class="task-tabs"><button class="' + (state.taskFilter === 'today' ? 'active' : '') + '" data-action="filter-tasks" data-filter="today">Hoy <span>' + today.length + '</span></button><button class="' + (state.taskFilter === 'week' ? 'active' : '') + '" data-action="filter-tasks" data-filter="week">Semana <span>' + week.length + '</span></button><button class="' + (state.taskFilter === 'all' ? 'active' : '') + '" data-action="filter-tasks" data-filter="all">Todo</button></div>' +
      '<div class="task-list">' + (shown.length ? shown.map(renderTask).join('') : '<div class="empty-state small"><span>☼</span><h3>Espacio libre</h3><p>No hay tareas en esta vista.</p></div>') + '</div>' +
      '<form id="task-form" class="task-form"><input id="task-title-input" name="title" required placeholder="¿Qué quieres hacer?" /><select name="when"><option value="today">Hoy</option><option value="week">Esta semana</option></select><select name="priority"><option value="media">Prioridad media</option><option value="alta">Prioridad alta</option><option value="baja">Prioridad baja</option></select><button type="submit">＋</button></form>' +
    '</section><aside class="ritual-card"><span>☼</span><p class="eyebrow">Pequeño ritual</p><h3>Haz una pausa.</h3><p>Antes de terminar el día, abre una ventana, toma agua y elige una sola cosa amable para mañana.</p><button class="soft-button compact" data-action="navigate" data-page="cocina">Planear una comida →</button></aside></div>' +
  '</section>';
}

function renderPage() {
  if (state.activePage === 'despensa') return renderInventory();
  if (state.activePage === 'compras') return renderShopping();
  if (state.activePage === 'cocina') return renderKitchen();
  if (state.activePage === 'agenda') return renderAgenda();
  return renderDashboard();
}

function renderProductModal(product) {
  const item = product || {
    name: '',
    description: '',
    category: 'comida',
    contentValue: '',
    contentUnit: 'g',
    usualPrice: '',
    stock: 1,
    lowAt: 1,
    photo: ''
  };
  return '<div class="modal-backdrop"><section class="modal-card product-modal" role="dialog" aria-modal="true" aria-labelledby="product-modal-title"><button class="modal-close" data-action="close-modal" aria-label="Cerrar">×</button><p class="eyebrow">Un nuevo lugar en casa</p><h2 id="product-modal-title">' + (product ? 'Editar producto' : 'Añadir producto') + '</h2><p class="modal-description">Guarda los detalles para que las compras futuras se comparen solas.</p>' +
    '<form id="product-form"><input type="hidden" name="id" value="' + escapeAttr(product ? product.id : '') + '" /><div class="photo-upload"><img id="photo-preview" src="' + escapeAttr(item.photo || 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=600&q=75') + '" alt="Vista previa" /><label for="product-photo"><span>＋</span> Cargar foto<input id="product-photo" name="photoFile" type="file" accept="image/*" /></label><input name="photoUrl" value="' + escapeAttr(item.photo) + '" placeholder="o pega una URL de foto" /></div>' +
    '<div class="form-grid"><label>Nombre<input required name="name" value="' + escapeAttr(item.name) + '" placeholder="Ej. Pasta fusilli" /></label><label>Categoría<select name="category">' +
      Object.keys(categoryMeta).map(function (key) { return '<option value="' + key + '"' + (item.category === key ? ' selected' : '') + '>' + categoryMeta[key].emoji + ' ' + categoryMeta[key].label + '</option>'; }).join('') +
    '</select></label><label class="full-span">Descripción<textarea name="description" placeholder="¿Para qué lo usas?">' + escapeHtml(item.description) + '</textarea></label><label>Cuánto trae<input required min="0.01" step="0.01" name="contentValue" type="number" value="' + escapeAttr(item.contentValue) + '" placeholder="250" /></label><label>Unidad<select name="contentUnit">' + ['g', 'kg', 'ml', 'L', 'piezas', 'rollos'].map(function (unit) { return '<option value="' + unit + '"' + (item.contentUnit === unit ? ' selected' : '') + '>' + unit + '</option>'; }).join('') + '</select></label><label>Precio usual<input required min="0" step="0.01" name="usualPrice" type="number" value="' + escapeAttr(item.usualPrice) + '" placeholder="$0.00" /></label><label>Cuánto tienes<input required min="0" step="0.1" name="stock" type="number" value="' + escapeAttr(item.stock) + '" /></label><label>Avísame cuando queden<input required min="0" step="0.1" name="lowAt" type="number" value="' + escapeAttr(item.lowAt) + '" /></label></div><div class="modal-actions"><button type="button" class="soft-button" data-action="close-modal">Cancelar</button><button type="button" class="primary-button" data-action="save-product">Guardar en casa →</button></div></form></section></div>';
}

function renderRecipeModal() {
  return '<div class="modal-backdrop"><section class="modal-card recipe-modal" role="dialog" aria-modal="true" aria-labelledby="recipe-modal-title"><button class="modal-close" data-action="close-modal" aria-label="Cerrar">×</button><p class="eyebrow">Tu cocina, tus reglas</p><h2 id="recipe-modal-title">Guardar una receta</h2><p class="modal-description">Las recetas se revisan automáticamente para respetar tus preferencias.</p><form id="recipe-form"><div class="form-grid"><label>Nombre<input required name="title" placeholder="Ej. Ensalada de verano" /></label><label>Tiempo<input required name="time" placeholder="20 min" /></label><label>Porciones<input required min="1" name="servings" type="number" value="2" /></label><label>Tipo de cocina<input name="cuisine" placeholder="mexicana, china…" /></label><label class="full-span">Descripción<textarea required name="description" placeholder="Una breve descripción rica y clara"></textarea></label><label class="full-span">Ingredientes <small>separados por coma</small><textarea required name="ingredients" placeholder="Tomate, aguacate, limón"></textarea></label><label class="full-span">Pasos <small>un paso por línea</small><textarea required name="steps" placeholder="Corta los vegetales&#10;Mezcla y sirve"></textarea></label><label>Foto <input name="image" type="url" placeholder="https://…" /></label><label>Video de YouTube <input name="videoUrl" type="url" placeholder="https://youtube.com/…" /></label></div><div class="modal-actions"><button type="button" class="soft-button" data-action="close-modal">Cancelar</button><button type="submit" class="primary-button">Guardar receta →</button></div></form></section></div>';
}

function renderRecipeDetailModal(recipe) {
  const coverage = recipeCoverage(recipe);
  return '<div class="modal-backdrop"><section class="modal-card recipe-detail-modal" role="dialog" aria-modal="true" aria-labelledby="recipe-detail-title"><button class="modal-close" data-action="close-modal" aria-label="Cerrar">×</button><img class="detail-recipe-image" src="' + escapeAttr(recipe.image) + '" alt="Foto de ' + escapeAttr(recipe.title) + '" /><div class="detail-recipe-copy"><span class="recipe-tag">' + escapeHtml(recipe.tag || 'Receta') + '</span><h2 id="recipe-detail-title">' + escapeHtml(recipe.title) + '</h2><p>' + escapeHtml(recipe.description) + '</p><div class="detail-meta"><span>◷ ' + escapeHtml(recipe.time) + '</span><span>◌ ' + recipe.servings + ' porciones</span></div><div class="recipe-detail-columns"><div><h4>Ingredientes</h4><ul class="ingredients-list">' + recipe.ingredients.map(function (ingredient) {
    const inHome = coverage.available.includes(ingredient);
    return '<li class="' + (inHome ? 'has-it' : 'need-it') + '">' + (inHome ? '✓' : '＋') + ' ' + escapeHtml(ingredient) + '</li>';
  }).join('') + '</ul></div><div><h4>Preparación</h4><ol class="steps-list">' + recipe.steps.map(function (step) {
    return '<li>' + escapeHtml(step) + '</li>';
  }).join('') + '</ol></div></div><div class="modal-actions"><button class="soft-button" data-action="add-missing" data-id="' + recipe.id + '">＋ Añadir faltantes</button>' + (recipe.videoUrl ? '<a class="primary-button video-link" href="' + escapeAttr(recipe.videoUrl) + '" target="_blank" rel="noreferrer">▶ Ver video</a>' : '') + '</div></div></section></div>';
}

function renderProductDetailModal(product) {
  const status = productStatus(product);
  const category = categoryLabel(product.category);
  return '<div class="modal-backdrop"><section class="modal-card product-detail-modal" role="dialog" aria-modal="true" aria-labelledby="product-detail-title"><button class="modal-close" data-action="close-modal" aria-label="Cerrar">×</button><img class="detail-product-image" src="' + escapeAttr(product.photo) + '" alt="Foto de ' + escapeAttr(product.name) + '" /><div class="detail-product-copy"><span class="category-badge">' + category.emoji + ' ' + category.label + '</span><h2 id="product-detail-title">' + escapeHtml(product.name) + '</h2><p>' + escapeHtml(product.description) + '</p>' + statusPill(status) + '<div class="detail-stats"><div><small>Contenido</small><b>' + escapeHtml(product.content) + '</b></div><div><small>Precio usual</small><b>' + formatMoney(product.usualPrice) + '</b></div><div><small>En casa</small><b>' + formatNumber(product.stock) + '</b></div></div><div class="modal-actions"><button class="soft-button" data-action="edit-product" data-id="' + product.id + '">Editar</button><button class="primary-button" data-action="navigate-price" data-id="' + product.id + '">Comparar precio →</button></div></div></section></div>';
}

function renderWidgetsModal() {
  const choices = [
    { key: 'urgent', icon: '!', title: 'Compras urgentes', text: 'Lo agotado primero.' },
    { key: 'low', icon: '↘', title: 'Por terminarse', text: 'Lo que pronto necesitarás.' },
    { key: 'meal', icon: '♨', title: 'Comida de hoy', text: 'Tu siguiente receta.' },
    { key: 'tasks', icon: '✓', title: 'Tareas de hoy', text: 'Tu foco del día.' }
  ];
  return '<div class="modal-backdrop"><section class="modal-card widgets-modal" role="dialog" aria-modal="true" aria-labelledby="widgets-modal-title"><button class="modal-close" data-action="close-modal" aria-label="Cerrar">×</button><p class="eyebrow">A tu manera</p><h2 id="widgets-modal-title">Elige tus widgets</h2><p class="modal-description">Estas tarjetas están listas para tu inicio. En dispositivos instalados, usa “Añadir a pantalla de inicio” para tener Foráneo siempre cerca.</p><form id="widgets-form"><div class="widget-choice-list">' + choices.map(function (choice) {
    return '<label class="widget-choice"><input type="checkbox" name="' + choice.key + '"' + (state.widgets[choice.key] ? ' checked' : '') + ' /><span class="widget-choice-icon">' + choice.icon + '</span><span><b>' + choice.title + '</b><small>' + choice.text + '</small></span><i></i></label>';
  }).join('') + '</div><div class="modal-actions"><button type="button" class="soft-button" data-action="close-modal">Ahora no</button><button type="submit" class="primary-button">Guardar widgets →</button></div></form></section></div>';
}

function renderModal() {
  if (!state.modal) return '';
  if (state.modal.type === 'product') return renderProductModal(state.modal.productId ? getProduct(state.modal.productId) : null);
  if (state.modal.type === 'recipe') return renderRecipeModal();
  if (state.modal.type === 'recipe-detail') return renderRecipeDetailModal(getRecipe(state.modal.recipeId));
  if (state.modal.type === 'product-detail') return renderProductDetailModal(getProduct(state.modal.productId));
  if (state.modal.type === 'widgets') return renderWidgetsModal();
  return '';
}

function renderNotifications() {
  if (!state.notificationOpen) return '';
  const notifications = state.notifications.slice(0, 6);
  return '<aside class="notification-panel"><div class="notification-panel-head"><div><p class="eyebrow">Al día contigo</p><h3>Notificaciones</h3></div><button data-action="mark-notifications-read">Marcar leídas</button></div>' +
    (notifications.length ? notifications.map(function (notification) {
      return '<article class="notification-item ' + (notification.read ? '' : 'unread') + '"><span class="' + notification.type + '">' + (notification.type === 'urgent' ? '!' : '↘') + '</span><div><b>' + escapeHtml(notification.title) + '</b><p>' + escapeHtml(notification.body) + '</p><small>' + escapeHtml(notification.time) + '</small></div></article>';
    }).join('') : '<div class="empty-compact"><span>☼</span><p>Nada pendiente por avisarte.</p></div>') +
    '<button class="notification-footer" data-action="activate-notifications">♧ Activar alertas del dispositivo</button></aside>';
}

function renderToast() {
  return state.toast ? '<div class="toast ' + state.toast.tone + '"><span>' + (state.toast.tone === 'danger' ? '!' : '✓') + '</span>' + escapeHtml(state.toast.message) + '</div>' : '';
}

function render() {
  const shell = '<div class="app-shell">' + renderSidebar() + '<main class="main-content">' + renderTopbar() + '<div class="page-content">' + renderPage() + '</div></main>' + renderMobileNav() + renderNotifications() + renderModal() + renderToast() + '</div>';
  app.innerHTML = shell;
}

function openModal(type, data) {
  state.modal = Object.assign({ type: type }, data || {});
  render();
}

function closeModal() {
  state.modal = null;
  render();
}

function setPage(page) {
  state.activePage = page;
  state.modal = null;
  state.notificationOpen = false;
  render();
}

function addMissingIngredients(recipe) {
  const coverage = recipeCoverage(recipe);
  let added = 0;
  coverage.missing.forEach(function (ingredient) {
    const existsManual = state.shopping.some(function (entry) {
      return normalize(entry.name) === normalize(ingredient);
    });
    const existsProduct = state.products.some(function (product) {
      return normalize(product.name) === normalize(ingredient) && productStatus(product) !== 'stocked';
    });
    if (!existsManual && !existsProduct) {
      state.shopping.unshift({
        id: 'manual-' + Date.now() + '-' + added,
        name: ingredient,
        detail: 'Para ' + recipe.title,
        source: 'receta',
        kind: 'low',
        image: ''
      });
      added += 1;
    }
  });
  state.modal = null;
  commit(added ? added + ' ingrediente(s) se añadieron a compras.' : 'Ya tenías anotado todo lo que falta.');
}

function analyzeFood(name, description) {
  const query = normalize(name + ' ' + description);
  const matching = recommendedRecipes().filter(function (recipe) {
    const recipeText = normalize(recipe.title + ' ' + recipe.description + ' ' + recipe.ingredients.join(' '));
    const words = query.split(/\s+/).filter(function (word) { return word.length > 3; });
    return words.some(function (word) { return recipeText.includes(word); });
  }).slice(0, 3);
  const fallback = recommendedRecipes().slice(0, 3);
  const foodName = name.trim() || 'este ingrediente';
  return {
    headline: matching.length ? 'Con ' + foodName + ' podrías preparar esto' : 'Ideas compatibles con tu despensa',
    description: matching.length
      ? 'Encontré opciones que aprovechan ' + foodName + ' y respetan tus filtros de cocina.'
      : 'No encontré una coincidencia directa; estas opciones son las más cercanas a lo que tienes.',
    recipes: matching.length ? matching : fallback
  };
}

function fileToDataUrl(file) {
  return new Promise(function (resolve, reject) {
    const reader = new FileReader();
    reader.onload = function () { resolve(reader.result); };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

function readForm(form) {
  return {
    get: function (name) {
      const field = form.elements.namedItem(name);
      if (!field) return null;
      if (field.type === 'file') return field.files && field.files[0] ? field.files[0] : null;
      if (field.type === 'checkbox') return field.checked ? 'on' : null;
      return field.value;
    }
  };
}

function checkPrice(form) {
  const data = readForm(form);
  const product = getProduct(data.get('productId'));
  if (!product) return;
  const preview = {
    productId: product.id,
    price: Number(data.get('price')),
    contentValue: Number(data.get('contentValue')),
    contentUnit: String(data.get('contentUnit'))
  };
  preview.result = evaluateComparablePrice({
    usualPrice: product.usualPrice,
    usualContentValue: product.contentValue,
    usualContentUnit: product.contentUnit,
    proposedPrice: preview.price,
    proposedContentValue: preview.contentValue,
    proposedContentUnit: preview.contentUnit
  });
  state.pricePreview = preview;
  render();
}

async function saveProduct(form) {
  const data = readForm(form);
  const existing = getProduct(data.get('id'));
  const file = data.get('photoFile');
  let photo = String(data.get('photoUrl') || '').trim();
  if (file && file.size) photo = await fileToDataUrl(file);
  if (!photo) photo = 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=600&q=75';
  const value = {
    id: existing ? existing.id : 'product-' + Date.now(),
    name: String(data.get('name') || '').trim(),
    description: String(data.get('description') || '').trim(),
    category: String(data.get('category') || 'otros'),
    contentValue: Number(data.get('contentValue')),
    contentUnit: String(data.get('contentUnit')),
    content: String(data.get('contentValue')) + ' ' + String(data.get('contentUnit')),
    usualPrice: Number(data.get('usualPrice')),
    stock: Number(data.get('stock')),
    lowAt: Number(data.get('lowAt')),
    photo: photo,
    lastPurchase: new Date().toISOString().slice(0, 10)
  };
  if (existing) Object.assign(existing, value);
  else state.products.unshift(value);
  state.modal = null;
  commit(existing ? 'Producto actualizado.' : value.name + ' ya está guardado en tu casa.');
}

async function requestNotifications() {
  if (!('Notification' in window)) {
    commit('Tu navegador no admite notificaciones, pero las alertas dentro de la app siguen activas.', 'danger');
    return;
  }
  const permission = await Notification.requestPermission();
  if (permission === 'granted') {
    new Notification('Foráneo', { body: 'Las alertas importantes ya pueden acompañarte.' });
    commit('Alertas del dispositivo activadas.');
  } else {
    commit('Las alertas siguen disponibles dentro de Foráneo.', 'danger');
  }
}

app.addEventListener('click', async function (event) {
  const target = event.target.closest('[data-action]');
  if (!target) return;
  const action = target.dataset.action;

  if (action === 'navigate') {
    event.preventDefault();
    setPage(target.dataset.page);
  } else if (action === 'open-product-modal') {
    openModal('product');
  } else if (action === 'close-modal') {
    closeModal();
  } else if (action === 'open-recipe-modal') {
    openModal('recipe');
  } else if (action === 'open-widgets') {
    openModal('widgets');
  } else if (action === 'check-price') {
    const priceForm = target.closest('#price-check-form');
    if (priceForm) checkPrice(priceForm);
  } else if (action === 'save-product') {
    const productForm = target.closest('#product-form');
    if (productForm) await saveProduct(productForm);
  } else if (action === 'open-product-details') {
    openModal('product-detail', { productId: target.dataset.id });
  } else if (action === 'open-recipe-details') {
    openModal('recipe-detail', { recipeId: target.dataset.id });
  } else if (action === 'edit-product') {
    openModal('product', { productId: target.dataset.id });
  } else if (action === 'navigate-price') {
    state.pricePreview = { productId: target.dataset.id, price: '', contentValue: getProduct(target.dataset.id).contentValue, contentUnit: getProduct(target.dataset.id).contentUnit, result: null };
    setPage('compras');
  } else if (action === 'filter-category') {
    state.selectedCategory = target.dataset.category;
    render();
  } else if (action === 'consume') {
    const product = getProduct(target.dataset.id);
    if (product) {
      product.stock = Math.max(0, Number(product.stock) - 1);
      commit(product.name + (product.stock ? ' se descontó del inventario.' : ' se terminó y pasó a compra urgente.'), product.stock ? 'success' : 'danger');
    }
  } else if (action === 'restock') {
    const product = getProduct(target.dataset.id);
    if (product) {
      product.stock = Number(product.stock) + 1;
      product.lastPurchase = new Date().toISOString().slice(0, 10);
      commit(product.name + ' volvió a estar en casa.');
    }
  } else if (action === 'remove-shopping') {
    state.shopping = state.shopping.filter(function (entry) { return entry.id !== target.dataset.id; });
    commit('Se quitó de tu lista de compras.');
  } else if (action === 'toggle-notifications') {
    state.notificationOpen = !state.notificationOpen;
    if (state.notificationOpen) {
      state.notifications.forEach(function (notification) { notification.read = true; });
      persist();
    }
    render();
  } else if (action === 'mark-notifications-read') {
    state.notifications.forEach(function (notification) { notification.read = true; });
    persist();
    render();
  } else if (action === 'activate-notifications') {
    await requestNotifications();
  } else if (action === 'add-missing') {
    const recipe = getRecipe(target.dataset.id);
    if (recipe) addMissingIngredients(recipe);
  } else if (action === 'plan-recipe') {
    const recipe = getRecipe(target.dataset.id);
    if (recipe) {
      state.planner[dayKeyForToday()].cena = recipe.id;
      commit(recipe.title + ' quedó planeada para la cena.');
    }
  } else if (action === 'toggle-task') {
    const task = state.tasks.find(function (item) { return item.id === target.dataset.id; });
    if (task) {
      task.completed = !task.completed;
      commit(task.completed ? '¡Tarea completada!' : 'La tarea volvió a pendientes.');
    }
  } else if (action === 'filter-tasks') {
    state.taskFilter = target.dataset.filter;
    render();
  } else if (action === 'focus-add-task') {
    const field = document.querySelector('#task-title-input');
    if (field) field.focus();
  } else if (action === 'register-purchase') {
    const preview = state.pricePreview;
    const product = preview ? getProduct(preview.productId) : null;
    if (product) {
      product.stock = Number(product.stock) + 1;
      product.lastPurchase = new Date().toISOString().slice(0, 10);
      state.pricePreview = null;
      commit('Compra de ' + product.name + ' registrada. Ya actualicé tu inventario.');
    }
  }
});

app.addEventListener('change', function (event) {
  const target = event.target;
  if (target.matches('[data-planner-day]')) {
    const day = target.dataset.plannerDay;
    const meal = target.dataset.plannerMeal;
    state.planner[day][meal] = target.value;
    commit(target.value ? 'Tu menú semanal se actualizó.' : 'Espacio de menú liberado.');
  }
  if (target.id === 'product-photo' && target.files && target.files[0]) {
    const preview = document.querySelector('#photo-preview');
    if (preview) preview.src = URL.createObjectURL(target.files[0]);
  }
});

app.addEventListener('submit', async function (event) {
  const form = event.target;
  if (!form || !form.id) return;
  event.preventDefault();

  if (form.id === 'inventory-search') {
    state.inventoryQuery = readForm(form).get('query') || '';
    render();
    return;
  }

  if (form.id === 'price-check-form') {
    checkPrice(form);
    return;
  }

  if (form.id === 'manual-shopping-form') {
    const data = readForm(form);
    const name = String(data.get('name') || '').trim();
    const exists = state.shopping.some(function (item) {
      return normalize(item.name) === normalize(name);
    });
    if (name && !exists) {
      state.shopping.unshift({
        id: 'manual-' + Date.now(),
        name: name,
        detail: String(data.get('detail') || '').trim(),
        source: 'manual',
        kind: 'low',
        image: ''
      });
      commit(name + ' se añadió a tu lista.');
    } else {
      commit('Ese artículo ya está anotado.', 'danger');
    }
    return;
  }

  if (form.id === 'product-form') {
    await saveProduct(form);
    return;
  }

  if (form.id === 'recipe-form') {
    const data = readForm(form);
    const recipe = {
      id: 'recipe-' + Date.now(),
      title: String(data.get('title') || '').trim(),
      description: String(data.get('description') || '').trim(),
      image: String(data.get('image') || '').trim() || 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&w=900&q=85',
      time: String(data.get('time') || '').trim(),
      servings: Number(data.get('servings')) || 2,
      tag: 'Receta propia',
      ingredients: String(data.get('ingredients') || '').split(',').map(function (item) { return item.trim(); }).filter(Boolean),
      steps: String(data.get('steps') || '').split(/\r?\n/).map(function (item) { return item.trim(); }).filter(Boolean),
      videoUrl: String(data.get('videoUrl') || '').trim(),
      cuisine: String(data.get('cuisine') || '').trim()
    };
    if (!safeRecipe(recipe)) {
      commit('Esta receta no cumple tus filtros de huevo o arroz. Ajusta la preparación antes de guardarla.', 'danger');
      return;
    }
    state.recipes.unshift(recipe);
    state.modal = null;
    commit('Tu receta quedó guardada y lista para planear.');
    return;
  }

  if (form.id === 'task-form') {
    const data = readForm(form);
    const title = String(data.get('title') || '').trim();
    if (title) {
      state.tasks.unshift({
        id: 'task-' + Date.now(),
        title: title,
        notes: '',
        when: String(data.get('when')),
        priority: String(data.get('priority')),
        completed: false
      });
      commit('Pendiente añadido a tu agenda.');
    }
    return;
  }

  if (form.id === 'food-scan-form') {
    const data = readForm(form);
    state.scanResult = analyzeFood(String(data.get('name') || ''), String(data.get('description') || ''));
    render();
    return;
  }

  if (form.id === 'widgets-form') {
    const data = readForm(form);
    Object.keys(state.widgets).forEach(function (key) {
      state.widgets[key] = data.get(key) === 'on';
    });
    state.modal = null;
    commit('Tus widgets quedaron personalizados.');
  }
});

syncInventoryNotifications();
persist();
render();

if ('serviceWorker' in navigator) {
  window.addEventListener('load', function () {
    navigator.serviceWorker.register('/sw.js').catch(function () {});
  });
}
