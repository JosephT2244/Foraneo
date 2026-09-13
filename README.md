# Foráneo

Foráneo organiza la vida diaria desde una interfaz cálida: inventario con fotos, comparación de precios, lista de compras urgente, recetas con IA y agenda semanal.

## Qué incluye

- Inventario por categorías: comida, higiene, cocina, baño, lavar, tecnología y hogar.
- Fotografías cargadas desde el dispositivo y datos de contenido, cantidad y precio habitual.
- Reglas de compra configuradas por costo habitual. Un precio fuera de margen se marca en rojo; una oportunidad se destaca para comprar.
- Alertas de existencias: agotado pasa a Compra urgente y poca existencia pasa a Por comprar.
- Cocina IA que pide recetas al servidor seguro, respeta las restricciones de huevo y arroz, y permite pasar faltantes a compras.
- Agenda para hoy y la semana.
- Web instalable como PWA y aplicación Flutter para Android, iOS, web, Windows, macOS y Linux.

## Abrir la versión web local

1. Instala las dependencias:

    npm install

2. Para usar todas las funciones locales, crea el archivo de entorno a partir del ejemplo y coloca tu propia clave:

    Copy-Item .env.example .env

3. Inicia la web y el servidor de recetas:

    npm run dev:all

Abre http://localhost:5173. Si sólo quieres probar la interfaz sin IA, usa:

    npm run dev

## IA de recetas

La clave de OpenAI vive solamente en el servidor de Node. Nunca la pegues en el navegador, la app Flutter ni los secretos públicos de GitHub Pages.

El servicio escucha en http://localhost:8787/api/recipes y toma estas variables desde .env:

    OPENAI_API_KEY=tu_clave
    OPENAI_MODEL=gpt-5.6-luna
    ALLOWED_ORIGINS=http://localhost:5173,http://127.0.0.1:5173

Para producción, despliega la carpeta server en un host de Node con HTTPS y configura allí las mismas variables. Después añade en GitHub una variable de Actions llamada RECIPES_API_URL con la URL HTTPS terminada en /api/recipes; el workflow la incorporará al siguiente build estático. La página continuará funcionando sin esa variable, pero mostrará recetas locales de respaldo en vez de usar la IA.

## Aplicación Flutter

La versión nativa está en foraneo_flutter. Instálala y ejecútala así:

    cd foraneo_flutter
    flutter pub get
    flutter run

Para conectar recetas reales, usa una URL HTTPS del servidor:

    flutter run --dart-define=RECIPES_API_URL=https://tu-servidor.example/api/recipes

Para un emulador Android local, usa http://10.0.2.2:8787/api/recipes. En un teléfono físico usa la IP LAN de la computadora o un backend HTTPS.

## Pruebas y build

Web:

    npm test
    npm run build

Flutter:

    cd foraneo_flutter
    flutter analyze
    flutter test
    flutter build web

## GitHub Pages

El repositorio incluye el workflow .github/workflows/deploy-pages.yml. Al enviar la rama main, publica la web estática en:

https://josepht2244.github.io/Foraneo/

En Settings > Pages del repositorio, selecciona GitHub Actions como fuente si GitHub no lo activa automáticamente. El workflow no expone claves y no puede alojar el servidor de IA: GitHub Pages sólo sirve archivos estáticos.

## Márgenes de precio

| Precio habitual | Oportunidad | Máximo autorizado |
| --- | ---: | ---: |
| Hasta $40 | -15% | +10% |
| De $41 a $100 | -15% | +8% |
| De $101 a $200 | -15% | +4% |
| De $201 a $500 | -10% | +3% |
| De $501 a $1,000 | -10% | +2% |
| Más de $1,000 | -10% | +1% |

El intervalo entre oportunidad y máximo se autoriza en verde. Si supera el máximo se rechaza en rojo.
