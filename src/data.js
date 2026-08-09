export const categoryMeta = {
  comida: { label: 'Comida', emoji: '🥕', color: 'sage' },
  higiene: { label: 'Higiene', emoji: '🫧', color: 'peach' },
  cocina: { label: 'Cocina', emoji: '🍳', color: 'mustard' },
  bano: { label: 'Baño', emoji: '🛁', color: 'sky' },
  lavado: { label: 'Lavado', emoji: '🧺', color: 'lilac' },
  tecnologia: { label: 'Tecnología', emoji: '🔌', color: 'slate' },
  otros: { label: 'Otros', emoji: '✦', color: 'rose' }
};

export const initialProducts = [
  {
    id: 'pasta-fusilli',
    name: 'Pasta fusilli',
    description: 'Pasta de trigo durum para comidas rápidas y ensaladas.',
    category: 'comida',
    content: '250 g',
    contentValue: 250,
    contentUnit: 'g',
    usualPrice: 20,
    stock: 1,
    lowAt: 1,
    photo: 'https://images.unsplash.com/photo-1556761223-4c4282c73f77?auto=format&fit=crop&w=800&q=85',
    lastPurchase: '2026-08-04'
  },
  {
    id: 'leche-avena',
    name: 'Leche de avena',
    description: 'Bebida vegetal sin azúcar, ideal para desayuno.',
    category: 'comida',
    content: '1 L',
    contentValue: 1,
    contentUnit: 'L',
    usualPrice: 38,
    stock: 0,
    lowAt: 1,
    photo: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=800&q=85',
    lastPurchase: '2026-07-29'
  },
  {
    id: 'avena',
    name: 'Avena integral',
    description: 'Avena en hojuelas para desayunos y snacks.',
    category: 'comida',
    content: '500 g',
    contentValue: 500,
    contentUnit: 'g',
    usualPrice: 49,
    stock: 2,
    lowAt: 1,
    photo: 'https://images.unsplash.com/photo-1517673132405-a56a62b18caf?auto=format&fit=crop&w=800&q=85',
    lastPurchase: '2026-08-02'
  },
  {
    id: 'tomate',
    name: 'Tomate',
    description: 'Tomate saladet fresco para salsas y ensaladas.',
    category: 'comida',
    content: '1 kg',
    contentValue: 1,
    contentUnit: 'kg',
    usualPrice: 32,
    stock: 0.5,
    lowAt: 1,
    photo: 'https://images.unsplash.com/photo-1546470427-e5ac89cd5e22?auto=format&fit=crop&w=800&q=85',
    lastPurchase: '2026-08-03'
  },
  {
    id: 'jabon',
    name: 'Jabón de manos',
    description: 'Jabón líquido con aroma fresco.',
    category: 'higiene',
    content: '250 ml',
    contentValue: 250,
    contentUnit: 'ml',
    usualPrice: 55,
    stock: 0,
    lowAt: 1,
    photo: 'https://images.unsplash.com/photo-1584305574647-0cc949a2bb9f?auto=format&fit=crop&w=800&q=85',
    lastPurchase: '2026-07-18'
  },
  {
    id: 'detergente',
    name: 'Detergente líquido',
    description: 'Detergente para ropa, aroma lavanda.',
    category: 'lavado',
    content: '900 ml',
    contentValue: 900,
    contentUnit: 'ml',
    usualPrice: 129,
    stock: 1,
    lowAt: 1,
    photo: 'https://images.unsplash.com/photo-1583947582886-f40ec95dd752?auto=format&fit=crop&w=800&q=85',
    lastPurchase: '2026-07-25'
  },
  {
    id: 'papel',
    name: 'Papel higiénico',
    description: 'Paquete de papel higiénico suave.',
    category: 'bano',
    content: '4 rollos',
    contentValue: 4,
    contentUnit: 'rollos',
    usualPrice: 74,
    stock: 1,
    lowAt: 1,
    photo: 'https://images.unsplash.com/photo-1584556813191-407b0ad78dc7?auto=format&fit=crop&w=800&q=85',
    lastPurchase: '2026-08-01'
  },
  {
    id: 'pilas',
    name: 'Pilas recargables',
    description: 'Pilas AA para controles y dispositivos.',
    category: 'tecnologia',
    content: '4 piezas',
    contentValue: 4,
    contentUnit: 'piezas',
    usualPrice: 325,
    stock: 1,
    lowAt: 0,
    photo: 'https://images.unsplash.com/photo-1626471801523-3de2bdcf2084?auto=format&fit=crop&w=800&q=85',
    lastPurchase: '2026-06-12'
  }
];

export const initialRecipes = [
  {
    id: 'pasta-tomate',
    title: 'Pasta cremosa de tomate',
    description: 'Una comida reconfortante de despensa lista en poco tiempo.',
    image: 'https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?auto=format&fit=crop&w=900&q=85',
    time: '25 min',
    servings: 2,
    tag: 'Favorita de casa',
    ingredients: ['Pasta fusilli', 'Tomate', 'Aceite de oliva', 'Ajo', 'Queso'],
    steps: [
      'Hierve la pasta en agua con sal hasta que quede al dente.',
      'Sofríe ajo picado con aceite de oliva y agrega tomate en cubos.',
      'Mezcla la pasta con la salsa, termina con queso y sirve caliente.'
    ],
    videoUrl: 'https://www.youtube.com/results?search_query=pasta+cremosa+de+tomate',
    cuisine: 'italiana'
  },
  {
    id: 'avena-fruta',
    title: 'Avena nocturna con fruta',
    description: 'Desayuno frío, suave y práctico para preparar desde la noche.',
    image: 'https://images.unsplash.com/photo-1517673400267-0251440c45dc?auto=format&fit=crop&w=900&q=85',
    time: '10 min + reposo',
    servings: 1,
    tag: 'Desayuno',
    ingredients: ['Avena integral', 'Leche de avena', 'Plátano', 'Canela'],
    steps: [
      'Mezcla avena y leche de avena en un frasco.',
      'Agrega canela, tapa y deja reposar en refrigeración.',
      'Termina con plátano en rebanadas antes de comer.'
    ],
    videoUrl: 'https://www.youtube.com/results?search_query=avena+nocturna+con+fruta',
    cuisine: 'internacional'
  },
  {
    id: 'tostada-atun',
    title: 'Tostadas de atún y aguacate',
    description: 'Cena ligera con vegetales crujientes y limón.',
    image: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=900&q=85',
    time: '15 min',
    servings: 2,
    tag: 'Rápida',
    ingredients: ['Tostadas', 'Atún', 'Aguacate', 'Tomate', 'Limón'],
    steps: [
      'Escurre el atún y mézclalo con limón.',
      'Corta tomate y aguacate en cubos pequeños.',
      'Monta cada tostada y sirve al momento.'
    ],
    videoUrl: 'https://www.youtube.com/results?search_query=tostadas+de+atun+y+aguacate',
    cuisine: 'mexicana'
  },
  {
    id: 'arroz-chino',
    title: 'Arroz frito chino con verduras',
    description: 'Arroz permitido: una preparación asiática con verduras salteadas.',
    image: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=900&q=85',
    time: '30 min',
    servings: 3,
    tag: 'Cocina asiática',
    ingredients: ['Arroz', 'Zanahoria', 'Chícharos', 'Salsa de soya', 'Cebollín'],
    steps: [
      'Cuece el arroz con anticipación y déjalo enfriar.',
      'Saltea las verduras a fuego alto con un poco de aceite.',
      'Incorpora el arroz y salsa de soya, mezclando hasta dorar.'
    ],
    videoUrl: 'https://www.youtube.com/results?search_query=arroz+frito+chino+verduras',
    cuisine: 'china'
  },
  {
    id: 'ensalada-huevo-cocido',
    title: 'Ensalada tibia con huevo cocido',
    description: 'Un plato fresco que usa huevo cocido, una preparación admitida.',
    image: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=900&q=85',
    time: '20 min',
    servings: 2,
    tag: 'Ligera',
    ingredients: ['Huevo cocido', 'Lechuga', 'Tomate', 'Papa', 'Limón'],
    steps: [
      'Hierve los huevos durante nueve minutos y enfríalos.',
      'Cuece la papa en cubos hasta que esté suave.',
      'Mezcla con lechuga, tomate, limón y el huevo en cuartos.'
    ],
    videoUrl: 'https://www.youtube.com/results?search_query=ensalada+con+huevo+cocido',
    cuisine: 'internacional'
  }
];

export const initialTasks = [
  {
    id: 'task-1',
    title: 'Regar las plantas',
    notes: 'Por la tarde, cuando baje el sol.',
    when: 'today',
    priority: 'media',
    completed: false
  },
  {
    id: 'task-2',
    title: 'Lavar ropa clara',
    notes: 'Separar toallas.',
    when: 'today',
    priority: 'alta',
    completed: false
  },
  {
    id: 'task-3',
    title: 'Cambiar sábanas',
    notes: '',
    when: 'week',
    priority: 'baja',
    completed: false
  },
  {
    id: 'task-4',
    title: 'Llamar al técnico del agua',
    notes: '',
    when: 'week',
    priority: 'alta',
    completed: true
  }
];

export const defaultPlanner = {
  lunes: { desayuno: 'avena-fruta', comida: 'pasta-tomate', cena: '' },
  martes: { desayuno: '', comida: 'tostada-atun', cena: '' },
  miercoles: { desayuno: 'avena-fruta', comida: '', cena: '' },
  jueves: { desayuno: '', comida: 'arroz-chino', cena: '' },
  viernes: { desayuno: '', comida: '', cena: 'ensalada-huevo-cocido' },
  sabado: { desayuno: '', comida: '', cena: '' },
  domingo: { desayuno: '', comida: '', cena: '' }
};
