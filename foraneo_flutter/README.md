# Foráneo Flutter

Cliente nativo de Foráneo para Android, iOS, web, Windows, macOS y Linux.

## Inicio rápido

    flutter pub get
    flutter run

El cliente guarda inventario, fotos y pendientes en el dispositivo. Para conectar la IA real de recetas no se usa una clave dentro de Flutter: se indica una URL HTTPS del servidor seguro.

    flutter run --dart-define=RECIPES_API_URL=https://tu-servidor.example/api/recipes

Para desarrollar con el servidor Node incluido en el repositorio principal:

    flutter run --dart-define=RECIPES_API_URL=http://localhost:8787/api/recipes

En emulador Android reemplaza localhost por 10.0.2.2. Para teléfono físico usa una URL HTTPS o la IP de tu red local.

## Verificación

    flutter analyze
    flutter test
    flutter build web

Consulta el README de la carpeta raíz para el servidor de IA, GitHub Pages y la configuración de producción.
