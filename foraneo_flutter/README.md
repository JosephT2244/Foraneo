# Foráneo Flutter · 2.0

Aplicación nativa para Android y Windows. Las carpetas de otras plataformas
conservan el proyecto Flutter, pero esta entrega no publica ni certifica
instalables de iOS, macOS o Linux. GitHub Pages publica la web Vite de la raíz,
no este cliente Flutter.

## Inicio rápido

Verificado con Flutter 3.47.4/Dart 3.13.3.

```powershell
flutter pub get
flutter run
```

El inventario, las fotos, las recetas y los pendientes se guardan localmente.
El catálogo incluido contiene 1,225 variantes de 54 recetas base originales,
con ingredientes cuantificados e instrucciones. La recomendación es búsqueda
y puntuación local por ingredientes, **no IA generativa**. No requiere API,
clave, suscripción, servidor Node ni descarga de un modelo.

El perfil con contraseña cifra los datos locales; no es una cuenta en la nube
y no sincroniza dispositivos. Los respaldos sin cifrar y los resúmenes que se
comparten con notificaciones/widgets quedan fuera del cifrado del perfil.

## Funciones de plataforma

- Android: cámara del sistema, avisos y alarmas locales persistentes y cuatro
  widgets de pantalla de inicio. El permiso de notificaciones, el launcher y
  las restricciones de batería influyen en su disponibilidad y puntualidad.
- Windows: selector de imágenes y avisos del sistema; la app debe seguir
  abierta para ejecutar recordatorios programados. No hay widgets de Windows.
- Google Calendar abre un evento preparado para que el usuario lo guarde; no
  hay sincronización OAuth. YouTube abre una búsqueda, no un video verificado.

## Verificación y compilación

```powershell
flutter analyze
flutter test
flutter build apk --release
flutter build windows --release
```

Android requiere SDK/JDK y la llave privada de publicación configurada en
`android/key.properties`; Windows requiere Visual Studio con C++. No publiques
la llave ni copies sólo el ejecutable Flutter: Windows necesita sus DLL y datos.

Consulta el [README principal](../README.md) para firma, empaquetado, márgenes
de precios, privacidad y despliegue, y la [verificación](../docs/VERIFICACION.md)
para conocer qué se probó y qué sigue dependiendo del dispositivo real.

<small>by Joseph Ubaldo Trejo Hernandez</small>
