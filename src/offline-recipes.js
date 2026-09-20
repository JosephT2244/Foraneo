// A lightweight, deterministic local search index — not a language model.
// Keep the equivalent Dart service and the shared fixtures in sync.
const aliases = [
  ["aceite de oliva", ["aceite de oliva"]],
  [
    "leche de avena",
    ["leche de avena", "bebida de avena", "bebida vegetal de avena"],
  ],
  ["leche de coco", ["leche de coco", "bebida de coco"]],
  [
    "crema de cacahuate",
    ["crema de cacahuate", "mantequilla de cacahuate", "crema de mani"],
  ],
  [
    "concentrado de tomate",
    ["concentrado de tomate", "pasta de tomate", "pure concentrado de tomate"],
  ],
  ["caldo de verduras", ["caldo de verduras", "caldo vegetal"]],
  [
    "salsa de soya",
    ["salsa de soya", "salsa de soja", "salsa soya", "salsa soja", "tamari"],
  ],
  ["queso parmesano", ["queso parmesano", "parmesano", "parmigiano"]],
  [
    "semilla de calabaza",
    ["semillas de calabaza", "semilla de calabaza", "pepitas"],
  ],
  ["tortilla de harina", ["tortillas de harina", "tortilla de harina"]],
  ["tortilla de maiz", ["tortillas de maiz", "tortilla de maiz"]],
  ["tostada de maiz", ["tostadas de maiz", "tostada de maiz", "tostadas"]],
  ["fecula de maiz", ["fecula de maiz", "almidon de maiz", "maicena"]],
  ["frijol blanco", ["frijoles blancos", "frijol blanco", "alubias", "alubia"]],
  [
    "yogur natural",
    [
      "yogur natural",
      "yogurt natural",
      "yoghurt natural",
      "yogur griego natural",
    ],
  ],
  ["pan integral", ["pan integral"]],
  [
    "pasta",
    [
      "pasta",
      "fusilli",
      "espagueti",
      "espaguetis",
      "spaghetti",
      "macarrones",
      "penne",
    ],
  ],
  ["fideo", ["fideos", "fideo", "noodles"]],
  ["tomate", ["tomates", "tomate", "jitomates", "jitomate"]],
  [
    "calabacita",
    ["calabacitas", "calabacita", "calabacin", "calabacines", "zucchini"],
  ],
  ["brocoli", ["brocoli", "brocolis"]],
  ["champiñon", ["champinones", "champinon"]],
  ["pimiento", ["pimientos", "pimiento", "pimenton rojo fresco"]],
  ["zanahoria", ["zanahorias", "zanahoria"]],
  ["garbanzo", ["garbanzos", "garbanzo"]],
  ["lenteja", ["lentejas", "lenteja"]],
  ["pollo", ["pollo", "pechuga de pollo"]],
  ["tofu", ["tofu"]],
  ["arroz", ["arroz"]],
  ["quinoa", ["quinoa", "quinua"]],
  ["cuscus", ["cuscus", "couscous"]],
  ["avena", ["avena"]],
  ["huevo", ["huevos", "huevo"]],
  ["papa", ["papas", "papa", "patatas", "patata"]],
  ["cebollin", ["cebollin", "cebolleta"]],
  ["cebolla", ["cebollas", "cebolla"]],
  ["ajo", ["ajos", "ajo"]],
  ["aguacate", ["aguacates", "aguacate", "palta"]],
  ["lechuga", ["lechugas", "lechuga"]],
  ["espinaca", ["espinacas", "espinaca"]],
  ["limon", ["limones", "limon"]],
  ["platano", ["platanos", "platano", "banana", "banano"]],
  ["manzana", ["manzanas", "manzana"]],
  ["fresa", ["fresas", "fresa", "frutillas", "frutilla"]],
  ["mango", ["mangos", "mango"]],
  ["nuez", ["nueces", "nuez"]],
  ["chia", ["chia"]],
  ["canela", ["canela"]],
  ["albahaca", ["albahaca"]],
  ["perejil", ["perejil"]],
  ["cilantro", ["cilantro"]],
  ["oregano", ["oregano"]],
  ["comino", ["comino"]],
  ["pimenton", ["pimenton", "paprika"]],
  ["chipotle", ["chipotle"]],
  ["jengibre", ["jengibre"]],
  ["curry", ["curry"]],
  ["tahini", ["tahini", "tahin", "pasta de ajonjoli"]],
  ["ajonjoli", ["ajonjoli", "sesamo"]],
  ["miel", ["miel"]],
  ["sal", ["sal"]],
  ["agua", ["agua"]],
];
const fold = (value) =>
  String(value ?? "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
const phraseAliases = aliases
  .flatMap(([key, words]) => words.map((word) => [fold(word), fold(key)]))
  .sort((a, b) => b[0].length - a[0].length);
const stopWords = new Set(
  "a al algo con como cocinar cocina compra de del el en la las lo los me mi mis para por que quiero receta recetas recomienda recomiendame rica rico ricas ricos tengo una unas uno unos un y sin g gr gramos kg kilogramo kilogramos ml l litro litros taza tazas cucharada cucharadas cucharadita cucharaditas pieza piezas paquete paquetes fresco fresca frescos frescas natural naturales integral mediano mediana medianos medianas aproximadamente sin azucar de forma".split(
    " ",
  ),
);
const canonicalWord = (value) =>
  ({
    cenar: "cena",
    desayunar: "desayuno",
    almuerzo: "comida",
    italiana: "mediterranea",
    italiano: "mediterranea",
    asiatico: "asiatica",
    chino: "china",
    oriental: "asiatica",
  })[value] || value;

export function normalizeIngredient(value) {
  const name = typeof value === "object" && value !== null ? value.name : value;
  const text = fold(name).replace(/\b(?:sin|no contiene) huevos?\b/g, "");
  if (!text) return "";
  // Longest phrase wins: oat milk is not oats; tomato paste is not pasta.
  for (const [phrase, key] of phraseAliases)
    if (` ${text} `.includes(` ${phrase} `)) return key;
  return text
    .split(" ")
    .filter((word) => word && !/^\d+$/.test(word) && !stopWords.has(word))
    .join(" ");
}

export function ingredientMatches(ingredient, product) {
  const a = normalizeIngredient(ingredient),
    b = normalizeIngredient(product);
  return Boolean(a && b && a === b);
}

function availablePantry(pantry) {
  return (Array.isArray(pantry) ? pantry : [])
    .filter((product) => {
      if (typeof product === "string") return product.trim();
      return (
        product &&
        typeof product.name === "string" &&
        Number(product.stock ?? 1) > 0 &&
        (!product.category ||
          ["comida", "alimentos", "food"].includes(fold(product.category)))
      );
    })
    .map(normalizeIngredient)
    .filter(Boolean);
}

export function missingIngredients(recipe, pantry = []) {
  const available = new Set(availablePantry(pantry));
  available.add("agua"); // Potable cooking water is not an automatic grocery item.
  const seen = new Set();
  return (Array.isArray(recipe?.ingredients) ? recipe.ingredients : []).filter(
    (ingredient, index) => {
      const key = normalizeIngredient(
        recipe.ingredientKeys?.[index] || ingredient,
      );
      if (!key || available.has(key) || seen.has(key)) return false;
      seen.add(key);
      return true;
    },
  );
}

export function recipeRestrictionReason(recipe) {
  if (!recipe || typeof recipe !== "object")
    return "La receta no tiene un formato válido.";
  // Huevo, carnes y arroz forman parte del recetario sin restricciones.
  // Conservamos este contrato para las recetas guardadas de versiones previas.
  return null;
}

export const isRecipeAllowed = (recipe) =>
  recipeRestrictionReason(recipe) === null;

const welcomeRecipes = [
  {
    id: "bienvenida-avena",
    baseId: "bienvenida-avena",
    title: "Avena cremosa con fruta",
    description:
      "Desayuno rápido y cálido para comenzar a organizar tu cocina.",
    ingredients: [
      "80 g de avena",
      "300 ml de leche",
      "1 plátano",
      "5 g de canela",
    ],
    ingredientKeys: ["avena", "leche", "platano", "canela"],
    steps: [
      "Hierve la leche a fuego medio en una olla pequeña.",
      "Añade la avena y cocina 5 minutos, moviendo hasta que espese.",
      "Sirve con el plátano en rebanadas y canela.",
    ],
    minutes: "10 min",
    time: 10,
    servings: 2,
    category: "desayuno",
    tag: "Desayuno",
    cuisine: "casera",
    image: "photos/avena.jpg",
    difficulty: "Fácil",
    equipment: ["olla pequeña", "cuchara"],
    allergens: [],
    notes: ["Ajusta la fruta a lo que tengas en casa."],
    source: "Recetario original Foráneo · bienvenida",
    sourceUrl: "",
    videoUrl: "",
  },
  {
    id: "bienvenida-pasta",
    baseId: "bienvenida-pasta",
    title: "Pasta de tomate y albahaca",
    description: "Una comida sencilla, completa y reconfortante.",
    ingredients: [
      "180 g de pasta seca",
      "300 g de tomate",
      "10 ml de aceite vegetal",
      "10 g de albahaca",
      "3 g de sal",
    ],
    ingredientKeys: ["pasta", "tomate", "aceite", "albahaca", "sal"],
    steps: [
      "Cuece la pasta según el tiempo indicado en el empaque y reserva media taza de agua de cocción.",
      "Sofríe el tomate picado con aceite 6 minutos.",
      "Integra la pasta, albahaca y un poco de agua de cocción; mezcla y sirve.",
    ],
    minutes: "25 min",
    time: 25,
    servings: 2,
    category: "comida",
    tag: "Cocina casera",
    cuisine: "italiana",
    image: "photos/pasta.jpg",
    difficulty: "Fácil",
    equipment: ["olla", "sartén", "colador"],
    allergens: ["gluten"],
    notes: ["Revisa el empaque de la pasta para alérgenos."],
    source: "Recetario original Foráneo · bienvenida",
    sourceUrl: "",
    videoUrl: "",
  },
  {
    id: "bienvenida-tacos",
    baseId: "bienvenida-tacos",
    title: "Tacos de pollo y aguacate",
    description:
      "Cena práctica con ingredientes que suelen estar en la despensa.",
    ingredients: [
      "8 tortillas de maíz",
      "250 g de pollo cocido",
      "1 aguacate",
      "100 g de tomate",
      "3 g de sal",
    ],
    ingredientKeys: ["tortilla de maiz", "pollo", "aguacate", "tomate", "sal"],
    steps: [
      "Calienta el pollo cocido hasta que esté completamente caliente.",
      "Calienta las tortillas en un comal seco.",
      "Rellena con pollo, aguacate y tomate; sazona y sirve.",
    ],
    minutes: "20 min",
    time: 20,
    servings: 2,
    category: "cena",
    tag: "Cocina mexicana",
    cuisine: "mexicana",
    image: "photos/tacos.jpg",
    difficulty: "Fácil",
    equipment: ["comal o sartén", "tabla", "cuchillo"],
    allergens: [],
    notes: ["Refrigera los sobrantes antes de dos horas."],
    source: "Recetario original Foráneo · bienvenida",
    sourceUrl: "",
    videoUrl: "",
  },
];
let localRecipes = welcomeRecipes;
let searchIndex;
let loadingCatalog;
const loadedBuckets = new Map();

// Used by the test suite and by any future preloaded/offline shell. Normal
// application startup deliberately leaves this uncalled until Cocina opens.
export function primeLocalRecipes(recipes) {
  if (!Array.isArray(recipes)) throw new TypeError("El recetario debe ser una lista.");
  localRecipes = recipes.filter(isRecipeAllowed);
  searchIndex = undefined;
  return getLocalRecipes();
}

export async function loadLocalRecipes(baseUrl = "/") {
  if (loadingCatalog) return loadingCatalog;
  loadingCatalog = fetch(`${baseUrl}recipes/index.json`, {
    cache: "force-cache",
  })
    .then((response) => {
      if (!response.ok) throw new Error("No pudimos abrir el recetario local.");
      return response.json();
    })
    .then((recipes) => {
      if (!Array.isArray(recipes))
        throw new Error("El recetario local tiene un formato inválido.");
      // Preserve the immediate, complete welcome recipes used before this
      // index arrives, so saved favourites and menu items never disappear.
      return primeLocalRecipes([...welcomeRecipes, ...recipes]);
    })
    .catch((error) => {
      loadingCatalog = undefined;
      throw error;
    });
  return loadingCatalog;
}

export async function loadRecipeDetails(id, baseUrl = "/") {
  const recipe = localRecipes.find((value) => value.id === id);
  if (!recipe || Array.isArray(recipe.steps)) return recipe;
  const bucket = String(
    recipe.detailBucket || recipe.baseId || recipe.id,
  ).replace(/[^a-z0-9-]/gi, "-");
  let request = loadedBuckets.get(bucket);
  if (!request) {
    request = fetch(
      `${baseUrl}recipes/chunks/${encodeURIComponent(bucket)}.json`,
      { cache: "force-cache" },
    ).then((response) => {
      if (!response.ok)
        throw new Error("No pudimos abrir los detalles de esta receta.");
      return response.json();
    });
    loadedBuckets.set(bucket, request);
  }
  const details = await request;
  if (!Array.isArray(details))
    throw new Error("Los detalles de la receta tienen un formato inválido.");
  for (const full of details) {
    const index = localRecipes.findIndex((value) => value.id === full.id);
    if (index >= 0) localRecipes[index] = full;
  }
  searchIndex = undefined;
  return localRecipes.find((value) => value.id === id);
}

export function getLocalRecipes() {
  return localRecipes.slice(); // Consumers can sort without reordering the index.
}

function queryWords(query) {
  let text = ` ${fold(query)} `;
  for (const [phrase, key] of phraseAliases)
    text = text.split(` ${phrase} `).join(` ${key} `);
  return [
    ...new Set(
      text
        .trim()
        .split(" ")
        .filter((word) => word && !stopWords.has(word) && !/^\d+$/.test(word))
        .map(canonicalWord),
    ),
  ];
}

// Support explicit ingredient exclusions without pretending to understand
// arbitrary dietary/medical requests. Keep this parser aligned with Dart.
function parseRecipeQuery(query) {
  const excludedIngredients = new Set();
  const text = fold(String(query).replace(/[,;]/g, " ni "));
  const positive = text.replace(
    /\b(?:sin|no quiero|evita|evitar|excluye)\s+(.+?)(?=\s+(?:con|para|sin|no quiero|evita|evitar|excluye)\b|$)/g,
    (_, clause) => {
      for (const ingredient of clause.split(/\s+(?:ni|y|o)\s+/)) {
        const key = normalizeIngredient(ingredient);
        if (key) excludedIngredients.add(key);
      }
      return " ";
    },
  );
  return { tokens: queryWords(positive), excludedIngredients };
}

function indexFor(recipe, index) {
  const keys = [
    ...new Set(
      (recipe.ingredientKeys || recipe.ingredients || [])
        .map(normalizeIngredient)
        .filter((key) => key && key !== "agua"),
    ),
  ];
  const searchable = new Set(
    queryWords(
      `${recipe.title} ${recipe.category} ${recipe.cuisine} ${recipe.tag} ${keys.join(" ")}`,
    ),
  );
  return { recipe, index, keys, searchable };
}

export function recommendLocalRecipes({
  query = "",
  pantry = [],
  limit = 12,
  offset = 0,
  exclude = [],
} = {}) {
  searchIndex ??= getLocalRecipes().map(indexFor);
  const { tokens: queryTokens, excludedIngredients } = parseRecipeQuery(query);
  // A user-entered unknown search never silently returns unrelated recipes.
  if (
    String(query).trim() &&
    queryTokens.length === 0 &&
    excludedIngredients.size === 0
  )
    return [];
  const available = new Set(availablePantry(pantry));
  const excluded = new Set(Array.isArray(exclude) ? exclude : []);
  const ranked = searchIndex
    .filter(
      (entry) =>
        !excluded.has(entry.recipe.id) &&
        !excluded.has(entry.recipe.title) &&
        !entry.keys.some((key) => excludedIngredients.has(key)),
    )
    .map((entry) => {
      const hits = queryTokens.filter((word) =>
        entry.searchable.has(word),
      ).length;
      const owned = entry.keys.filter((key) => available.has(key)).length;
      const score =
        hits * 10000 +
        Math.round((owned / Math.max(entry.keys.length, 1)) * 1000) +
        owned * 10;
      return { ...entry, hits, score };
    })
    .filter((entry) => !queryTokens.length || entry.hits > 0)
    .sort((a, b) => b.score - a.score || a.index - b.index);
  // Round-robin the equally relevant bases so the first page is not 12 near-duplicates.
  const groups = new Map();
  for (const entry of ranked) {
    const key = `${entry.hits}:${entry.recipe.baseId || entry.recipe.id}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(entry);
  }
  const diversified = [];
  const tiers = [...new Set(ranked.map((entry) => entry.hits))].sort(
    (a, b) => b - a,
  );
  for (const tier of tiers) {
    const queues = [...groups.values()].filter(
      (group) => group[0].hits === tier,
    );
    for (let round = 0; queues.some((group) => group.length > round); round++) {
      const candidates = queues
        .filter((group) => group.length > round)
        .map((group) => group[round]);
      candidates.sort((a, b) => b.score - a.score || a.index - b.index);
      diversified.push(...candidates.map((entry) => entry.recipe));
    }
  }
  const start = Number.isFinite(Number(offset))
    ? Math.max(0, Math.floor(Number(offset)))
    : 0;
  const count = Number.isFinite(Number(limit))
    ? Math.max(0, Math.min(200, Math.floor(Number(limit))))
    : 12;
  return diversified.slice(start, start + count);
}
