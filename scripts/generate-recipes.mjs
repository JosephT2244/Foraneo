/**
 * Foráneo's original, deterministic offline cookbook. No recipes are scraped.
 * These are 48 savoury cooking bases with explicit, compatible protein and
 * vegetable variants, plus breakfasts and hard-boiled-egg salads. They are not
 * 1,000 independently chef-tested recipes or output from an on-device LLM.
 * Every variant materialises its own complete ingredient list and instructions.
 * Food-safety facts checked 2026-09-13 against:
 * https://www.foodsafety.gov/food-safety-charts/safe-minimum-internal-temperatures
 * https://www.gov.uk/government/publications/home-food-fact-checker/home-food-fact-checker
 * https://www.fsis.usda.gov/food-safety/safe-food-handling-and-preparation/food-safety-basics/leftovers-and-food-safety
 * Run: node scripts/generate-recipes.mjs
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = new URL('../', import.meta.url);
const item = (text, key) => ({ text, key });
const familyImages = { pasta: 'pasta', cuscus: 'ensalada', quinoa: 'ensalada', tacos: 'tacos', wraps: 'tacos', tostadas: 'tacos', papas: 'ensalada', sopa: 'pasta', ensalada: 'ensalada', 'fideos-asiaticos': 'pasta', 'arroz-asiatico': 'arroz', guiso: 'ensalada' };
const proteins = [
  { id: 'pollo', name: 'pollo', ingredient: item('250 g de pechuga de pollo cruda, sin piel ni hueso', 'pollo'),
    prep: 'Con una tabla distinta de la de las verduras, corta el pollo en cubos de 2 cm. No lo laves: limpia después la tabla, el cuchillo y tus manos.',
    cook: 'Calienta 10 ml del aceite en una sartén a fuego medio-alto. Añade el pollo en una sola capa y cocina 10–12 minutos, girándolo varias veces. Comprueba con un termómetro que el centro de los trozos alcance 74 °C; prolonga la cocción si hace falta. Reserva en un plato limpio.',
    allergens: [] },
  { id: 'tofu', name: 'tofu dorado', ingredient: item('250 g de tofu firme, escurrido', 'tofu'),
    prep: 'Envuelve el tofu en papel de cocina limpio, presiona suavemente para retirar líquido y córtalo en cubos de 2 cm. No necesitas congelarlo ni marinarlo.',
    cook: 'Calienta 10 ml del aceite en una sartén antiadherente a fuego medio-alto. Dora el tofu 8–10 minutos, girándolo cada 2 minutos hasta que varias caras estén doradas; reserva en un plato limpio.',
    allergens: ['soya'] },
  { id: 'garbanzos', name: 'garbanzos', ingredient: item('240 g de garbanzos ya cocidos de conserva, peso escurrido', 'garbanzo'),
    prep: 'Abre la conserva de garbanzos, escúrrela en un colador, enjuaga bajo agua potable y mide 240 g. Esta receta no usa garbanzos secos ni crudos.',
    cook: 'Calienta 10 ml del aceite en una sartén a fuego medio. Incorpora los garbanzos cocidos y saltea 4 minutos, moviendo suavemente, hasta que estén calientes. Reserva en un plato limpio.',
    allergens: [] },
  { id: 'alubias', name: 'frijoles blancos', ingredient: item('240 g de frijoles blancos ya cocidos de conserva, peso escurrido', 'frijol blanco'),
    prep: 'Escurre y enjuaga los frijoles blancos de conserva; mide 240 g y deja que se escurra el exceso de agua. Deben estar completamente cocidos: no sustituyas por frijoles secos.',
    cook: 'Calienta 10 ml del aceite en una sartén a fuego medio. Añade los frijoles blancos y caliéntalos durante 3–4 minutos, girando la sartén para no deshacerlos; reserva en un plato limpio.',
    allergens: [] },
  { id: 'lentejas', name: 'lentejas', ingredient: item('240 g de lentejas ya cocidas de conserva, peso escurrido', 'lenteja'),
    prep: 'Escurre las lentejas de conserva en un colador de malla fina, enjuágalas con cuidado y mide 240 g. Deben estar tiernas pero conservar su forma.',
    cook: 'Calienta 10 ml del aceite en una sartén a fuego medio-bajo. Incorpora las lentejas cocidas y calienta 3 minutos, doblándolas con una espátula sin aplastarlas; reserva en un plato limpio.',
    allergens: [] },
];
const vegetables = [
  { id: 'calabacita', name: 'calabacita', ingredient: item('250 g de calabacita', 'calabacita'),
    prep: 'Lava la calabacita, retira los extremos y córtala en medias lunas de 1 cm; conserva la piel.',
    cook: 'Añade la calabacita a la cebolla y cocina a fuego medio-alto 6–8 minutos, moviendo cada minuto: debe quedar tierna y ligeramente dorada, sin convertirse en puré.' },
  { id: 'brocoli', name: 'brócoli', ingredient: item('250 g de brócoli', 'brocoli'),
    prep: 'Lava el brócoli, separa floretes de unos 2 cm y rebana fino el tallo tierno para que todo se cocine de manera uniforme.',
    cook: 'Añade el brócoli y los 40 ml de agua para verduras a la cebolla. Tapa y cocina a fuego medio 5 minutos; destapa y saltea 2 minutos más, hasta que el tallo se atraviese con un tenedor.' },
  { id: 'zanahoria', name: 'zanahoria', ingredient: item('250 g de zanahoria', 'zanahoria'),
    prep: 'Lava y pela las zanahorias; corta rodajas de 3 mm de grosor, procurando que tengan tamaños parecidos.',
    cook: 'Incorpora las zanahorias y los 40 ml de agua para verduras a la cebolla. Tapa 6 minutos a fuego medio, destapa y cocina 3 minutos más: deben quedar tiernas pero no deshacerse.' },
  { id: 'champiñones', name: 'champiñones', ingredient: item('250 g de champiñones frescos', 'champiñon'),
    prep: 'Limpia los champiñones bajo un chorro breve de agua, sécalos y córtalos en láminas gruesas de 5 mm.',
    cook: 'Añade los champiñones a la cebolla, distribúyelos en una capa y cocina a fuego medio-alto 7–9 minutos. Remueve cada 2 minutos hasta que se evapore el líquido y empiecen a dorarse.' },
  { id: 'pimiento', name: 'pimiento', ingredient: item('250 g de pimiento rojo', 'pimiento'),
    prep: 'Lava el pimiento, retira tallo, semillas y membranas blancas; corta tiras de 5 mm y luego trozos de unos 3 cm.',
    cook: 'Añade el pimiento a la cebolla y cocina 7–9 minutos a fuego medio, moviendo cada minuto, hasta que las tiras estén flexibles y presenten algunas zonas doradas.' },
];

const sauces = {
  tomate: { name: 'en salsa de tomate y orégano', ingredients: [item('200 g de tomate triturado natural', 'tomate'), item('5 g de ajo (1 diente mediano)', 'ajo'), item('1 g de orégano seco', 'oregano'), item('60 ml de agua para la salsa', 'agua')],
    step: 'Pica finamente el ajo. En un cazo mezcla el tomate triturado, el ajo, el orégano y los 60 ml de agua de la salsa. Lleva a hervor suave y cocina destapado 8 minutos, removiendo cada 2 minutos; la salsa debe espesar sin secarse.', allergens: [] },
  limon: { name: 'con limón y perejil', ingredients: [item('30 g de tahini (pasta de ajonjolí)', 'tahini'), item('20 ml de jugo de limón', 'limon'), item('10 g de perejil fresco', 'perejil'), item('50 ml de agua para la salsa', 'agua')],
    step: 'Lava y pica el perejil. Mezcla el tahini con el jugo de limón; agrega los 50 ml de agua de la salsa poco a poco, batiendo con un tenedor hasta obtener una crema fluida. Incorpora todo el perejil y reserva sin calentar.', allergens: ['ajonjolí'] },
  yogur: { name: 'con yogur y cilantro', ingredients: [item('120 g de yogur natural sin azúcar', 'yogur natural'), item('15 ml de jugo de limón', 'limon'), item('8 g de cilantro fresco', 'cilantro'), item('1 g de comino molido', 'comino')],
    step: 'Lava, seca y pica el cilantro. Mezcla el yogur natural, el jugo de limón, el cilantro y el comino en un tazón hasta que no haya grumos. Mantén esta salsa en el refrigerador y agrégala al servir; no la hiervas.', allergens: ['leche'] },
  comino: { name: 'con comino y pimentón', ingredients: [item('40 g de concentrado de tomate', 'concentrado de tomate'), item('2 g de comino molido', 'comino'), item('2 g de pimentón dulce', 'pimenton'), item('100 ml de agua para la salsa', 'agua')],
    step: 'En un cazo mezcla el concentrado de tomate, el comino, el pimentón y los 100 ml de agua de la salsa. Cocina a fuego bajo durante 4 minutos, removiendo, hasta obtener una salsa homogénea y ligeramente espesa.', allergens: [] },
  pesto: { name: 'con albahaca y nuez', ingredients: [item('15 g de albahaca fresca', 'albahaca'), item('25 g de nuez sin cáscara', 'nuez'), item('20 g de queso parmesano rallado', 'queso parmesano'), item('15 ml de jugo de limón', 'limon'), item('50 ml de agua para la salsa', 'agua')],
    step: 'Lava y seca la albahaca. Pica muy finos la albahaca y las nueces o tritúralas junto con el parmesano, el jugo de limón y los 50 ml de agua de la salsa. Debe quedar una pasta ligera; resérvala para incorporarla al final, sin hervir.', allergens: ['nuez', 'leche'] },
  chipotle: { name: 'con chipotle suave', ingredients: [item('150 g de tomate triturado natural', 'tomate'), item('5 g de chile chipotle adobado', 'chipotle'), item('3 g de ajo (medio diente mediano)', 'ajo'), item('40 ml de agua para la salsa', 'agua')],
    step: 'Pica muy finos el chipotle y el ajo. Mézclalos en un cazo con el tomate y los 40 ml de agua de la salsa; cocina a fuego bajo 7 minutos, removiendo. La cantidad de chipotle produce un picor suave; no añadas más sin probar primero.', allergens: [] },
  soya: { name: 'con soya y jengibre', ingredients: [item('20 ml de salsa de soya reducida en sodio', 'salsa de soya'), item('8 g de jengibre fresco', 'jengibre'), item('10 ml de jugo de limón', 'limon'), item('60 ml de agua para la salsa', 'agua'), item('4 g de fécula de maíz', 'fecula de maiz')],
    step: 'Pela y ralla el jengibre. En un cazo frío disuelve la fécula en los 60 ml de agua; añade soya, limón y jengibre. Calienta a fuego medio removiendo durante 2–3 minutos, hasta que la mezcla hierva suavemente y cubra el dorso de una cuchara.', allergens: ['soya', 'trigo según la marca'] },
  sesamo: { name: 'con ajonjolí y cítricos', ingredients: [item('25 g de tahini (pasta de ajonjolí)', 'tahini'), item('15 ml de salsa de soya reducida en sodio', 'salsa de soya'), item('20 ml de jugo de limón', 'limon'), item('60 ml de agua para la salsa', 'agua'), item('5 g de ajonjolí tostado', 'ajonjoli')],
    step: 'Bate el tahini con la salsa de soya y el jugo de limón. Añade los 60 ml de agua gradualmente hasta que la salsa sea vertible; integra el ajonjolí tostado. Reserva para añadir después de apagar el fuego.', allergens: ['ajonjolí', 'soya', 'trigo según la marca'] },
  cacahuate: { name: 'con cacahuate y jengibre', ingredients: [item('35 g de crema de cacahuate sin azúcar', 'crema de cacahuate'), item('15 ml de salsa de soya reducida en sodio', 'salsa de soya'), item('5 g de jengibre fresco', 'jengibre'), item('15 ml de jugo de limón', 'limon'), item('80 ml de agua para la salsa', 'agua')],
    step: 'Pela y ralla el jengibre. En un cazo mezcla crema de cacahuate, soya, jengibre, jugo de limón y los 80 ml de agua. Calienta a fuego bajo 3 minutos y bate hasta que esté lisa; no dejes que hierva fuerte ni se pegue.', allergens: ['cacahuate', 'soya', 'trigo según la marca'] },
  curry: { name: 'con coco y curry suave', ingredients: [item('150 ml de leche de coco sin azúcar', 'leche de coco'), item('3 g de curry en polvo suave', 'curry'), item('5 g de jengibre fresco', 'jengibre'), item('10 ml de jugo de limón', 'limon')],
    step: 'Pela y ralla el jengibre. Calienta leche de coco, curry y jengibre en un cazo a fuego bajo durante 5 minutos, removiendo sin dejar hervir con fuerza. Apaga el fuego y agrega el jugo de limón.', allergens: ['revisar mezcla de curry'] },
};

const families = [
  { id: 'pasta', name: 'Pasta', category: 'comida', cuisine: 'mediterranea', time: 35, sauces: ['tomate', 'pesto', 'limon', 'yogur'],
    ingredients: [item('160 g de pasta corta seca sin huevo', 'pasta'), item('1500 ml de agua para cocer la pasta', 'agua')],
    start: 'Pon a hervir los 1500 ml de agua en una olla. Agrega la pasta y cocina el tiempo indicado por su fabricante, normalmente 8–12 minutos, removiendo al principio. Prueba una pieza: debe estar tierna con el centro ligeramente firme. Escurre sin enjuagar.',
    finish: 'Devuelve la pasta escurrida a la olla fuera del fuego. Añade la proteína y las verduras calientes; incorpora toda la salsa y mezcla durante 30 segundos, con cuidado de no romper las piezas. Divide en dos platos y sirve enseguida.',
    tools: ['olla', 'colador', 'sartén', 'cazo', 'tabla y cuchillo'], allergens: ['trigo'] },
  { id: 'cuscus', name: 'Cuscús', category: 'comida', cuisine: 'mediterranea', time: 30, sauces: ['tomate', 'limon', 'comino', 'yogur'],
    ingredients: [item('150 g de cuscús instantáneo de trigo', 'cuscus'), item('180 ml de agua para hidratar el cuscús (o la cantidad indicada en su envase)', 'agua')],
    start: 'Hierve el agua destinada al cuscús y viértela sobre el cuscús en un tazón resistente al calor; comprueba antes la proporción del envase y ajústala si difiere. Tapa 5 minutos, o el tiempo de su fabricante. Separa después los granos con un tenedor.',
    finish: 'Reparte el cuscús hidratado entre dos platos hondos. Coloca encima la proteína y las verduras calientes y distribuye toda la salsa. Mezcla suavemente al comer para conservar los granos sueltos.',
    tools: ['cazo', 'tazón con tapa', 'tenedor', 'sartén', 'tabla y cuchillo'], allergens: ['trigo'] },
  { id: 'quinoa', name: 'Bowl de quinoa', category: 'comida', cuisine: 'internacional', time: 40, sauces: ['limon', 'pesto', 'comino', 'sesamo'],
    ingredients: [item('140 g de quinoa cruda', 'quinoa'), item('300 ml de agua para cocer la quinoa', 'agua')],
    start: 'Enjuaga la quinoa en un colador fino. Ponla en una olla con los 300 ml de agua; cuando hierva, tapa y baja al mínimo durante unos 15 minutos, hasta que absorba el líquido. Apaga y deja reposar tapada 5 minutos; separa con un tenedor.',
    finish: 'Reparte la quinoa en dos tazones. Acomoda encima la proteína y las verduras; vierte la salsa de manera uniforme. Sirve tibio y mezcla solamente al momento de comer para conservar las texturas.',
    tools: ['olla con tapa', 'colador fino', 'sartén', 'cazo', 'tabla y cuchillo'], allergens: [] },
  { id: 'tacos', name: 'Tacos', category: 'comida', cuisine: 'mexicana', time: 30, sauces: ['tomate', 'chipotle', 'comino', 'yogur'],
    ingredients: [item('6 tortillas de maíz pequeñas (aproximadamente 150 g)', 'tortilla de maiz')],
    start: 'Cuenta 6 tortillas pequeñas de maíz. Justo antes de servir, caliéntalas en un comal seco a fuego medio, 20–30 segundos por lado, hasta que se doblen sin romperse. Consérvalas tapadas en un paño limpio.',
    finish: 'Corta la proteína y las verduras ya cocidas en bocados si quedaron demasiado grandes. Reparte el relleno en las 6 tortillas calientes y añade la salsa por encima. Sirve 3 tacos por persona y come al momento.',
    tools: ['comal', 'sartén', 'cazo', 'tabla y cuchillo'], allergens: [] },
  { id: 'wraps', name: 'Wraps', category: 'cena', cuisine: 'internacional', time: 30, sauces: ['limon', 'chipotle', 'yogur', 'pesto'],
    ingredients: [item('2 tortillas de harina grandes (aproximadamente 120 g)', 'tortilla de harina'), item('60 g de lechuga', 'lechuga')],
    start: 'Lava las hojas de lechuga bajo agua potable y sécalas muy bien. Calienta las tortillas de harina en una sartén seca a fuego medio, 20 segundos por lado, solo hasta que estén flexibles; mantenlas tapadas.',
    finish: 'Deja entibiar la proteína y las verduras 2 minutos. Extiende las tortillas, reparte la lechuga y el relleno dejando libres 3 cm en los bordes; cubre con la salsa. Dobla los lados hacia dentro, enrolla desde abajo y corta cada wrap por la mitad.',
    tools: ['sartén', 'cazo', 'tabla y cuchillo'], allergens: ['trigo'] },
  { id: 'tostadas', name: 'Tostadas', category: 'cena', cuisine: 'mexicana', time: 30, sauces: ['tomate', 'chipotle', 'comino', 'limon'],
    ingredients: [item('6 tostadas de maíz horneadas (aproximadamente 90 g)', 'tostada de maiz'), item('100 g de aguacate, pulpa sin cáscara ni hueso', 'aguacate')],
    start: 'Coloca las tostadas de maíz horneadas en dos platos. Abre el aguacate, retira el hueso con una cuchara, mide la pulpa y machácala con un tenedor. Reserva hasta el montaje para que la tostada no se humedezca.',
    finish: 'Extiende el aguacate machacado sobre las 6 tostadas. Reparte la proteína y las verduras con una cuchara, escurriendo cualquier líquido sobrante de la sartén. Añade la salsa justo antes de comer; sirve 3 tostadas por persona.',
    tools: ['sartén', 'cazo', 'tenedor', 'tabla y cuchillo'], allergens: [] },
  { id: 'papas', name: 'Papas rellenas', category: 'comida', cuisine: 'internacional', time: 65, sauces: ['tomate', 'comino', 'yogur', 'pesto'],
    ingredients: [item('2 papas medianas (aproximadamente 500 g en total)', 'papa')],
    start: 'Precalienta el horno a 200 °C. Lava las papas con un cepillo, sécalas y pincha cada una 5 veces con un tenedor. Hornéalas en una charola durante 45–55 minutos, hasta que un cuchillo entre al centro sin resistencia; las papas grandes pueden tardar más.',
    finish: 'Con guantes de cocina, abre cada papa caliente a lo largo sin cortar la base. Esponja el interior con un tenedor, reparte la proteína y las verduras entre ambas y termina con toda la salsa. Sirve una papa rellena por persona.',
    tools: ['horno', 'charola', 'guantes de cocina', 'sartén', 'cazo', 'tabla y cuchillo'], allergens: [] },
  { id: 'sopa', name: 'Sopa casera', category: 'comida', cuisine: 'internacional', time: 40, sauces: ['tomate', 'comino', 'curry', 'soya'],
    ingredients: [item('500 ml de caldo de verduras bajo en sodio', 'caldo de verduras'), item('120 g de pan integral para acompañar', 'pan integral')],
    start: 'Vierte el caldo en una olla con capacidad de al menos 2 litros y calienta a fuego bajo hasta que aparezcan burbujas pequeñas. Mantén tapado mientras preparas los demás componentes; no añadas sal adicional al caldo.',
    finish: 'Añade al caldo la proteína ya cocida, las verduras y toda la salsa. Cocina a hervor suave 5 minutos, removiendo con cuidado. Reparte la sopa en dos tazones y sirve con 60 g de pan integral por persona.',
    tools: ['olla de 2 litros', 'sartén', 'cazo', 'cucharón', 'tabla y cuchillo'], allergens: ['trigo'] },
  { id: 'ensalada', name: 'Ensalada tibia', category: 'cena', cuisine: 'internacional', time: 30, sauces: ['limon', 'pesto', 'yogur', 'sesamo'],
    ingredients: [item('100 g de espinaca fresca', 'espinaca'), item('120 g de pan integral para acompañar', 'pan integral')],
    start: 'Lava la espinaca bajo agua potable, retira hojas dañadas y sécala bien. Reparte las hojas en dos platos amplios. Corta el pan en rebanadas; puedes tostarlo en una sartén seca durante 1 minuto por lado.',
    finish: 'Deja reposar el relleno caliente durante 2 minutos. Coloca proteína y verduras sobre la espinaca, vierte la salsa y mezcla con dos cucharas sin aplastar las hojas. Sirve inmediatamente con el pan; esta ensalada se come tibia, no recalentada.',
    tools: ['sartén', 'cazo', 'ensaladera', 'tabla y cuchillo'], allergens: ['trigo'] },
  { id: 'fideos-asiaticos', name: 'Fideos asiáticos', category: 'comida', cuisine: 'asiatica', time: 35, sauces: ['soya', 'sesamo', 'cacahuate', 'curry'],
    ingredients: [item('160 g de fideos secos de trigo sin huevo', 'fideo'), item('1500 ml de agua para cocer los fideos', 'agua'), item('15 g de cebollín', 'cebollin')],
    start: 'Pon a hervir los 1500 ml de agua. Cuece los fideos según su envase, generalmente 4–7 minutos; escúrrelos en cuanto estén flexibles y tiernos. Lava el cebollín, corta rodajas finas y reserva para el final.',
    finish: 'Añade los fideos escurridos a la sartén con las verduras y la proteína; mezcla a fuego medio 1 minuto. Apaga el fuego, agrega la salsa y mezcla con pinzas hasta cubrir. Reparte en dos tazones y termina con todo el cebollín.',
    tools: ['olla', 'colador', 'sartén amplia', 'cazo', 'pinzas', 'tabla y cuchillo'], allergens: ['trigo'] },
  { id: 'arroz-asiatico', name: 'Arroz al wok asiático', category: 'comida', cuisine: 'china', time: 40, sauces: ['soya', 'sesamo', 'cacahuate', 'curry'],
    ingredients: [item('140 g de arroz de grano largo crudo', 'arroz'), item('280 ml de agua para cocer el arroz (ajusta según su envase)', 'agua'), item('15 g de cebollín', 'cebollin')],
    start: 'Enjuaga el arroz en un colador y ponlo en una olla con el agua indicada; sigue la proporción y el tiempo de su envase si difieren. Lleva a hervor, tapa y cocina al mínimo unos 15 minutos; apaga y reposa 5 minutos. Úsalo recién cocido en el salteado, sin enfriarlo sobre la encimera. Pica el cebollín lavado.',
    finish: 'Incorpora el arroz recién cocido a la sartén amplia con la proteína y las verduras. Saltea a fuego medio-alto 3 minutos, deshaciendo los grumos con la espátula. Apaga, mezcla la salsa y reparte en dos tazones con el cebollín. Es una preparación al wok de inspiración asiática, no arroz de guarnición tradicional.',
    tools: ['olla con tapa', 'colador', 'wok o sartén amplia', 'cazo', 'espátula', 'tabla y cuchillo'], allergens: [] },
  { id: 'guiso', name: 'Guiso de despensa', category: 'comida', cuisine: 'internacional', time: 45, sauces: ['tomate', 'comino', 'chipotle', 'curry'],
    ingredients: [item('300 g de papa', 'papa'), item('350 ml de caldo de verduras bajo en sodio', 'caldo de verduras')],
    start: 'Lava y pela las papas, córtalas en cubos de 1.5 cm y colócalas en una olla con el caldo. Tapa y cocina a fuego medio-bajo 12–15 minutos, removiendo dos veces, hasta que un tenedor atraviese los cubos sin resistencia.',
    finish: 'Agrega a la olla de las papas la proteína cocida, las verduras y toda la salsa. Cocina destapado a fuego bajo 5 minutos, removiendo para evitar que se pegue. Aplasta 2–3 cubos de papa contra la pared de la olla para espesar y reparte en dos platos hondos.',
    tools: ['olla con tapa', 'sartén', 'cazo', 'tabla y cuchillo'], allergens: [] },
];

const recipes = [];
for (const family of families) for (const sauceId of family.sauces) {
  const sauce = sauces[sauceId];
  const baseId = `${family.id}-${sauceId}`;
  for (const protein of proteins) for (const vegetable of vegetables) {
    const common = [item('20 ml de aceite de oliva (10 ml para la proteína y 10 ml para las verduras)', 'aceite de oliva'), item('50 g de cebolla', 'cebolla'), item('1 g de sal fina (aproximadamente 1/6 de cucharadita)', 'sal')];
    if (['brocoli', 'zanahoria'].includes(vegetable.id)) common.push(item('40 ml de agua para las verduras', 'agua'));
    const ingredients = [...family.ingredients, protein.ingredient, vegetable.ingredient, ...common, ...sauce.ingredients];
    const title = `${family.name} de ${protein.name} y ${vegetable.name} ${sauce.name}`;
    const safety = family.id === 'arroz-asiatico'
      ? 'Sirve el arroz inmediatamente. Si sobra, divídelo en recipientes poco profundos y refrigera idealmente antes de 1 hora, sin esperar a que enfríe por completo; consume en 24 horas. Recalienta una sola vez hasta 74 °C en todo el plato. Nunca dejes arroz cocido enfriando durante horas.'
      : 'Sirve al terminar. Refrigera los sobrantes en recipientes poco profundos antes de 2 horas (antes de 1 hora si el ambiente supera 32 °C); conserva el refrigerador a 4 °C o menos y consume en 3 días. Recalienta la parte cocida hasta 74 °C; guarda aparte las salsas frías y las hojas frescas.';
    recipes.push({ id: `local-${baseId}-${protein.id}-${vegetable.id}`, baseId, baseTitle: `${family.name} ${sauce.name}`, title,
      description: `Una variación original de Foráneo para 2 personas: ${protein.name}, ${vegetable.name} y una salsa medida, con cantidades completas y una preparación guiada. Los tiempos son aproximados; verifica siempre la cocción.`,
      ingredients: ingredients.map(i => i.text), ingredientKeys: ingredients.map(i => i.key),
      steps: ['Antes de empezar, lee toda la receta, reúne los utensilios y mide cada ingrediente. Lávate las manos; lava las verduras bajo agua potable y mantén separados los alimentos crudos de los ya listos para comer.', family.start,
        `Prepara la verdura: ${vegetable.prep} Pela y corta los 50 g de cebolla en cubitos de 5 mm.`, protein.prep, sauce.step, protein.cook,
        'En la misma sartén vacía, calienta los otros 10 ml de aceite a fuego medio. Añade la cebolla picada y cocina 3 minutos, removiendo, hasta que esté translúcida y no quemada.',
        `${vegetable.cook} Agrega el gramo de sal medido y remueve.`,
        'Devuelve la proteína cocida a la sartén con las verduras y mezcla a fuego medio durante 1 minuto. Apaga el fuego mientras preparas el montaje final.', family.finish, safety],
      time: family.time + 15, minutes: `${family.time + 15} min aprox.`, servings: 2, category: family.category, tag: family.cuisine === 'china' || family.cuisine === 'asiatica' ? 'Cocina asiática' : family.category === 'cena' ? 'Cena en casa' : 'Comida de despensa', cuisine: family.cuisine,
      image: `photos/${familyImages[family.id]}.jpg`, imageCaption: 'Fotografía ilustrativa de la familia de platos; el resultado cambia según la variante.',
      family: family.id, difficulty: 'Fácil', equipment: family.tools,
      allergens: [...new Set([...family.allergens, ...protein.allergens, ...sauce.allergens])],
      source: 'Recetario original Foráneo · variante de una base culinaria', sourceUrl: '', videoUrl: '',
      notes: ['Las cantidades corresponden a 2 porciones; multiplica todos los ingredientes por el mismo factor para ajustar las raciones.', 'El tiempo total orientativo contempla preparar la salsa y las verduras mientras se cuece la base. Si sigues todos los pasos uno tras otro, reserva 15 minutos adicionales.', 'Las legumbres de conserva se pesan después de escurrir. Revisa las etiquetas si tienes alergias; no hay garantía de ausencia de trazas.', 'La coincidencia con tu despensa comprueba nombres, no garantiza que tengas cantidad suficiente. Comprueba las cantidades antes de cocinar.'],
    });
  }
}

const fruits = [
  { id: 'platano', name: 'plátano', ingredient: item('160 g de plátano pelado (aproximadamente 2 pequeños)', 'platano'), prep: 'Pela el plátano y córtalo en rodajas de 5 mm justo antes de servir.' },
  { id: 'manzana', name: 'manzana', ingredient: item('180 g de manzana, sin corazón', 'manzana'), prep: 'Lava la manzana, quita el corazón y córtala en cubitos de 5 mm; conserva la piel si te gusta.' },
  { id: 'fresa', name: 'fresa', ingredient: item('180 g de fresas', 'fresa'), prep: 'Lava las fresas bajo agua potable, retira las hojas, seca y córtalas en cuartos.' },
  { id: 'mango', name: 'mango', ingredient: item('180 g de mango, pulpa sin piel ni hueso', 'mango'), prep: 'Lava el mango entero antes de cortarlo, pela y separa 180 g de pulpa; córtala en cubos pequeños.' },
];
const breakfasts = [
  { id: 'avena-caliente', name: 'Avena cremosa', time: 15, minutes: '15 min',
    ingredients: [item('80 g de avena en hojuelas', 'avena'), item('400 ml de leche de avena sin azúcar', 'leche de avena'), item('1 g de canela molida', 'canela'), item('20 g de nuez picada', 'nuez')],
    method: ['Vierte los 400 ml de leche de avena en un cazo y calienta a fuego medio hasta que salga vapor, sin que se desborde.', 'Agrega la avena y la canela. Baja el fuego y cocina 6–8 minutos, removiendo cada 30 segundos con una cuchara para que no se pegue al fondo.', 'Comprueba la textura: los copos deben estar suaves y la mezcla cremosa. Apaga el fuego y deja reposar 2 minutos; espesará un poco más.', 'Divide la avena entre dos tazones, distribuye toda la fruta por encima y termina con 10 g de nuez por porción. Deja entibiar antes de comer.'], allergens: ['avena: comprobar gluten', 'nuez'], equipment: ['cazo', 'cuchara', 'tabla y cuchillo'] },
  { id: 'avena-nocturna', name: 'Avena nocturna', time: 10, minutes: '10 min + 8 h en refrigeración',
    ingredients: [item('80 g de avena en hojuelas', 'avena'), item('280 ml de leche de avena sin azúcar', 'leche de avena'), item('120 g de yogur natural sin azúcar', 'yogur natural'), item('10 g de semillas de chía', 'chia'), item('1 g de canela molida', 'canela')],
    method: ['En un tazón mezcla la avena, leche de avena, yogur, chía y canela. Remueve 1 minuto para que no queden grupos de semillas secas.', 'Reparte la mezcla en dos recipientes limpios con tapa, dejando espacio para la fruta. Tapa y refrigera a 4 °C o menos durante 8 horas; no dejes reposar en la encimera.', 'Al día siguiente mezcla con una cuchara limpia: los copos deben estar hidratados y la textura espesa, sin zonas secas.', 'Prepara la fruta justo antes de comer, repártela sobre las dos porciones y sirve frío. No es necesario cocinar ni usar licuadora.'], allergens: ['leche', 'avena: comprobar gluten'], equipment: ['tazón', '2 recipientes con tapa', 'refrigerador', 'tabla y cuchillo'] },
  { id: 'yogur-crujiente', name: 'Yogur crujiente', time: 15, minutes: '15 min',
    ingredients: [item('300 g de yogur natural sin azúcar', 'yogur natural'), item('50 g de avena en hojuelas', 'avena'), item('20 g de semillas de calabaza peladas', 'semilla de calabaza'), item('10 g de miel', 'miel'), item('1 g de canela molida', 'canela')],
    method: ['Pon una sartén limpia y seca a fuego medio-bajo. Añade la avena y las semillas de calabaza; tuesta 4–5 minutos, moviendo continuamente hasta que desprendan aroma, sin oscurecerlas demasiado.', 'Apaga el fuego, añade la canela, mezcla y extiende en un plato limpio para que se enfríe 5 minutos. No mezcles los cereales calientes con el yogur.', 'Reparte el yogur en dos tazones; añade la fruta preparada y 5 g de miel en cada uno.', 'Justo antes de comer añade la mitad de la mezcla tostada a cada tazón para que conserve su textura crujiente. Sirve inmediatamente.'], allergens: ['leche', 'avena: comprobar gluten'], equipment: ['sartén', 'espátula', '2 tazones', 'tabla y cuchillo'] },
  { id: 'tostada-dulce', name: 'Tostadas dulces', time: 10, minutes: '10 min',
    ingredients: [item('4 rebanadas de pan integral (aproximadamente 120 g)', 'pan integral'), item('40 g de crema de cacahuate sin azúcar', 'crema de cacahuate'), item('1 g de canela molida', 'canela')],
    method: ['Tuesta el pan en una tostadora o en sartén seca a fuego medio durante 1–2 minutos por lado, hasta que la superficie esté crujiente.', 'Coloca las rebanadas sobre una rejilla o plato, sin apilarlas, para que no se humedezcan con su propio vapor.', 'Extiende 10 g de crema de cacahuate sobre cada rebanada tibia, cubriendo la superficie sin llegar completamente al borde.', 'Reparte la fruta sobre las 4 tostadas y espolvorea la canela. Sirve 2 por persona; añade la fruta solo al momento de comer.'], allergens: ['trigo', 'cacahuate'], equipment: ['tostadora o sartén', 'cuchillo para untar', 'tabla y cuchillo'] },
  { id: 'chia-cremosa', name: 'Vasitos de chía', time: 20, minutes: '20 min + 6 h en refrigeración',
    ingredients: [item('40 g de semillas de chía', 'chia'), item('320 ml de leche de avena sin azúcar', 'leche de avena'), item('100 g de yogur natural sin azúcar', 'yogur natural'), item('10 g de miel', 'miel'), item('1 g de canela molida', 'canela')],
    method: ['Mezcla la leche de avena, el yogur, la miel y la canela con un batidor o tenedor hasta que la mezcla sea uniforme.', 'Agrega toda la chía y remueve 1 minuto. Espera 10 minutos y vuelve a mezclar bien para deshacer los grupos de semillas que se hayan formado.', 'Reparte en dos frascos limpios con tapa y refrigera a 4 °C o menos durante al menos 6 horas. Las semillas deben formar un gel; nunca comas la chía seca directamente.', 'Al servir, remueve cada vasito, comprueba que todas las semillas estén hidratadas y reparte la fruta recién preparada encima. Come frío.'], allergens: ['leche', 'avena: comprobar gluten'], equipment: ['tazón', 'tenedor', '2 frascos con tapa', 'refrigerador', 'tabla y cuchillo'] },
];
for (const base of breakfasts) for (const fruit of fruits) {
  const ingredients = [...base.ingredients, fruit.ingredient];
  recipes.push({ id: `local-${base.id}-${fruit.id}`, baseId: base.id, baseTitle: base.name, title: `${base.name} con ${fruit.name}`,
    description: 'Desayuno original y medido para 2 personas. Preparación sencilla, sin huevo y con fruta; incluye reposos y conservación cuando corresponden.', ingredients: ingredients.map(i => i.text), ingredientKeys: ingredients.map(i => i.key),
    steps: ['Lávate las manos, limpia la superficie de trabajo y mide todos los ingredientes para las 2 porciones. Mantén los lácteos o las bebidas vegetales refrigerados hasta usarlos.', ['avena-nocturna', 'chia-cremosa'].includes(base.id) ? `Reserva la fruta entera para prepararla justo al servir, después del reposo: ${fruit.prep}` : fruit.prep, ...base.method,
      'Si no vas a comerlo de inmediato, tapa y refrigera a 4 °C o menos; consume en 2 días. Conserva aparte el pan y las coberturas crujientes y agrega la fruta cortada al servir.'], time: base.time, minutes: base.minutes, servings: 2, category: 'desayuno', tag: 'Desayuno tranquilo', cuisine: 'internacional', family: 'desayuno', image: 'photos/avena.jpg', imageCaption: 'Fotografía ilustrativa de desayunos; el resultado varía según los ingredientes.', difficulty: 'Fácil', equipment: base.equipment, allergens: base.allergens, source: 'Recetario original Foráneo · variante de una base culinaria', sourceUrl: '', videoUrl: '', notes: ['Las cantidades son para 2 porciones. Revisa etiquetas y alérgenos, especialmente en bebidas vegetales, pan y cremas de frutos secos.'] });
}

for (const vegetable of vegetables) {
  const ingredients = [item('4 huevos medianos con cáscara', 'huevo'), item('1000 ml de agua para hervir los huevos', 'agua'), item('500 ml de agua fría para enfriarlos', 'agua'), item('200 g de papa', 'papa'), item('600 ml de agua para cocer la papa', 'agua'), vegetable.ingredient, item('80 g de lechuga', 'lechuga'), item('15 ml de aceite de oliva', 'aceite de oliva'), item('20 ml de jugo de limón', 'limon'), item('1 g de sal fina', 'sal')];
  recipes.push({ id: `local-huevo-duro-${vegetable.id}`, baseId: 'ensalada-huevo-duro', baseTitle: 'Ensalada de huevo duro', title: `Ensalada de huevo duro con papa y ${vegetable.name}`,
    description: 'Una ensalada completa para 2 personas con huevo únicamente hervido, de clara y yema firmes. Incluye tiempos de cocción, cantidades y conservación.',
    ingredients: ingredients.map(i => i.text), ingredientKeys: ingredients.map(i => i.key),
    steps: ['Lávate las manos y limpia la tabla. Lava la lechuga y las verduras bajo agua potable. Mide todos los ingredientes; usa una olla pequeña para los huevos y otra para la papa.',
      'Pon los huevos en una capa en la olla y cubre con los 1000 ml de agua, ajustando solo si hace falta para cubrirlos 2 cm. Lleva a hervor suave y cocina 11–12 minutos. La clara y la yema deben quedar completamente firmes, nunca líquidas.',
      'Pasa los huevos a un tazón con los 500 ml de agua fría durante 5 minutos; cambia el agua si se templa. Pela con las manos limpias y corta en cuartos. Si una yema no quedó firme, no la uses sin terminar su cocción.',
      vegetable.prep,
      'Pela la papa y córtala en cubos de 1.5 cm. Ponla en la segunda olla con los 600 ml de agua y lleva a hervor suave. Cocina 4 minutos sin escurrir: completarás su cocción junto con la verdura en el siguiente paso.',
      `Con la papa todavía hirviendo, coloca ${vegetable.name} en una cesta de vapor sobre esa olla y cocina 8–12 minutos más. Sin cesta, añade la verdura directamente al agua de la papa y cocina 8 minutos más. Comprueba ambas con un tenedor: deben estar tiernas; retira primero la que esté lista y prolonga la otra si hace falta. Solo entonces escurre y deja entibiar 5 minutos.`,
      'Seca muy bien la lechuga y repártela entre dos platos. Mezcla en un tazón los 15 ml de aceite, los 20 ml de limón y el gramo de sal con un tenedor durante 30 segundos.',
      'Coloca la papa y la verdura tibias sobre las hojas; reparte 2 huevos por persona y vierte el aderezo medido. Sirve al momento, sin calentar de nuevo la lechuga.',
      'Refrigera los componentes por separado antes de 2 horas, a 4 °C o menos. Consume esta ensalada preparada en 2 días y añade la lechuga y el aderezo justo antes de comer.'],
    time: 45, minutes: '45 min aprox.', servings: 2, category: 'cena', tag: 'Solo huevo hervido', cuisine: 'internacional', family: 'ensalada', image: 'photos/ensalada.jpg', imageCaption: 'Fotografía ilustrativa de ensalada; no representa exactamente esta variante.', difficulty: 'Fácil', equipment: ['2 ollas', 'colador o cesta de vapor', 'tazón', 'tabla y cuchillo'], allergens: ['huevo'], source: 'Recetario original Foráneo · variante de una base culinaria', sourceUrl: '', videoUrl: '', notes: ['No sustituir por preparaciones de huevo diferentes: esta receta contempla únicamente huevo duro.'] });
}

for (const folder of ['public/recipes', 'foraneo_flutter/assets/recipes']) {
  const target = new URL(`${folder}/`, root);
  mkdirSync(target, { recursive: true });
  writeFileSync(new URL('catalog.json', target), JSON.stringify(recipes), 'utf8');
}
const stats = { recipeCount: recipes.length, baseCount: new Set(recipes.map(r => r.baseId)).size, bytes: Buffer.byteLength(JSON.stringify(recipes)), source: 'Recetas originales Foráneo. Variantes deterministas de bases culinarias; no son resultados de IA ni recetas extraídas de sitios externos.' };
console.log(JSON.stringify({ ...stats, output: fileURLToPath(new URL('public/recipes/catalog.json', root)) }, null, 2));
