import { categoryMeta } from './data.js';
import { localDate, weekDates } from './agenda.js';

const text = (value, max = 2000) => String(value ?? '').slice(0, max);
const number = (value, fallback = 0) => Number.isFinite(Number(value)) ? Math.max(0, Number(value)) : fallback;
export const validDate = value => /^\d{4}-\d{2}-\d{2}$/.test(value || '') && Number.isFinite(new Date(value + 'T12:00:00').getTime()) && localDate(new Date(value + 'T12:00:00')) === value;
export function safePhoto(value) {
  const str = text(value, 2000000);
  if (/^data:image\/(jpeg|png|webp);base64,[a-z0-9+/=]+$/i.test(str)) return str;
  if (/^(photos\/|\.\/photos\/)/.test(str) && !str.includes('..')) return str;
  if (/^https:\/\//i.test(str)) return str;
  return '';
}
export function validateState(value) {
  if (!value || typeof value !== 'object' || !Array.isArray(value.products) || !Array.isArray(value.tasks) || !Array.isArray(value.recipes) || !Array.isArray(value.shopping)) throw new Error('El archivo no es un respaldo de Foráneo compatible.');
  if ([value.products, value.tasks, value.recipes, value.shopping].some(list => list.length > 10000)) throw new Error('El respaldo contiene demasiados registros.');
  const unique = list => { const ids = new Set(); return list.filter(item => { if (ids.has(item.id)) return false; ids.add(item.id); return true; }); };
  const id = item => text(item.id || crypto.randomUUID(), 100);
  const products = unique(value.products.filter(item => item && typeof item === 'object').map(item => ({
    id: id(item), name: text(item.name, 150), description: text(item.description), category: Object.hasOwn(categoryMeta, item.category) ? item.category : 'otros',
    contentValue: number(item.contentValue, 1) || 1, contentUnit: ['g','kg','ml','L','piezas','rollos','paquetes'].includes(item.contentUnit) ? item.contentUnit : 'piezas',
    usualPrice: number(item.usualPrice), stock: number(item.stock), lowAt: number(item.lowAt), photo: safePhoto(item.photo), lastPurchase: text(item.lastPurchase, 10)
  })));
  const recipes = unique([...value.recipes, ...(Array.isArray(value.aiRecipes) ? value.aiRecipes : [])].filter(item => item && Array.isArray(item.ingredients) && Array.isArray(item.steps)).map(item => ({
    id: id(item), title: text(item.title, 180), description: text(item.description), ingredients: item.ingredients.slice(0,100).map(v=>text(v,300)),
    steps: item.steps.slice(0,100).map(v=>text(v,3000)), time: text(item.time,40), servings: number(item.servings,2)||2, tag: text(item.tag,100),
    image: safePhoto(item.image), videoUrl: /^https:\/\/(www\.)?(youtube\.com|youtu\.be)\//.test(item.videoUrl||'') ? item.videoUrl : '', cuisine: text(item.cuisine,80)
  })));
  const tasks = unique(value.tasks.filter(item=>item&&typeof item==='object').map(item=>({id:id(item),title:text(item.title,200),notes:text(item.notes),date: validDate(item.date) ? item.date : item.when==='week' ? weekDates()[6] : localDate(),time:/^([01]\d|2[0-3]):[0-5]\d$/.test(item.time||'')?item.time:'09:00',priority:['alta','media','baja'].includes(item.priority)?item.priority:'media',completed:Boolean(item.completed),reminded:Boolean(item.reminded)})));
  const shopping = unique(value.shopping.filter(item=>item&&typeof item==='object').map(item=>({id:id(item),name:text(item.name,180),detail:text(item.detail),kind:item.kind==='urgent'?'urgent':'low',image:safePhoto(item.image),price:number(item.price),source:text(item.source,80)})));
  const mealPlans = {};
  if(value.mealPlans && typeof value.mealPlans==='object') Object.entries(value.mealPlans).slice(0,2000).forEach(([date,meals])=>{if(validDate(date)&&meals&&typeof meals==='object') mealPlans[date]=Object.fromEntries(['desayuno','comida','cena'].map(key=>[key,text(meals[key],100)]));});
  if(!Object.keys(mealPlans).length && value.planner) ['lunes','martes','miercoles','jueves','viernes','sabado','domingo'].forEach((day,index)=>{ if(value.planner[day]) mealPlans[weekDates()[index]]=Object.fromEntries(['desayuno','comida','cena'].map(key=>[key,text(value.planner[day][key],100)])); });
  return {products,recipes,tasks,shopping,mealPlans,favorites:Array.isArray(value.favorites)?value.favorites.slice(0,10000).map(v=>text(v,100)):[],settings:{theme:['light','dark','system'].includes(value.settings?.theme)?value.settings.theme:'system',notifications:Boolean(value.settings?.notifications),displayName:text(value.settings?.displayName||'Joseph',80)},notifications:Array.isArray(value.notifications)?value.notifications.slice(0,100).filter(n=>n&&typeof n==='object').map(n=>({id:id(n),title:text(n.title,200),body:text(n.body,500),read:Boolean(n.read),time:text(n.time,50)})):[]};
}
