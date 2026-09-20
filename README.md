# Foráneo · 2.0

Tu hogar, a tu ritmo. Despensa, compras, cocina y agenda en español, con diseño
adaptable, modo oscuro y datos locales.

**Web:** https://josepht2244.github.io/Foraneo/

**Instalables:** https://github.com/JosephT2244/Foraneo/releases/latest

## Qué puedes hacer

- Registrar productos con foto de galería o cámara móvil, presentación, precio,
  existencias y umbral mínimo; editar, consumir, reponer y eliminar.
- Separar compras urgentes (agotados) de próximas compras (pocas existencias).
- Comparar precios normalizados por cantidad y unidad, no sólo por empaque.
- Consultar **1,225 variantes de 54 recetas base originales**, con ingredientes
  cuantificados, instrucciones detalladas y recomendaciones por despensa.
- Agregar recetas propias, enviar ingredientes faltantes a compras y planear
  desayuno, comida y cena para cada día.
- Organizar pendientes en un calendario y plan semanal, completar tareas y abrir
  un formulario de Google Calendar con el evento preparado.
- Crear un perfil local con usuario y contraseña, cifrar sus datos y hacer
  respaldos. También puedes usar modo invitado.
- Elegir apariencia clara, oscura o del sistema y configurar avisos/widgets.

## Cocina sin API ni modelo pesado

No se usa una API de IA, clave, suscripción ni servidor de recetas. Es un
**recetario local con búsqueda y puntuación por ingredientes**, no IA generativa.
Las variantes comparten técnicas base y cambian ingredientes de manera
estructurada. No son 1,225 platos independientes revisados por un chef.

Se excluyen huevos revueltos y preparaciones similares; se admite huevo duro.
El arroz se limita a preparaciones asiáticas. Revisa siempre etiquetas, alergias,
estado de los alimentos y cocción. Las fotos son ilustrativas; no se inventa un
video específico: un botón de búsqueda abre YouTube cuando hay conexión.

El catálogo se distribuye con la aplicación. Las fotos decorativas y el logo
también están incluidos; las fotos que tomas no se suben a un servicio.
Consulta [atribuciones](public/photos/ATTRIBUTION.md).

## Compatibilidad real

| Función | Web/PWA | Android APK | Windows |
| --- | --- | --- | --- |
| Despensa, compras, recetas, agenda y tema | Sí | Sí | Sí |
| Cámara | Selector de cámara según navegador | Cámara del sistema | Galería/archivo |
| Sin conexión | Después de la primera carga y caché | Desde la instalación | Desde la instalación |
| Notificaciones del sistema | Con permiso; app abierta para detectar avisos | Avisos y alarmas locales persistentes | Avisos; app abierta para programados |
| Widgets de pantalla de inicio | No; acceso directo PWA | Hogar, compras, agenda y cocina | No |

En Android, los widgets se agregan manteniendo presionada la pantalla de inicio
o desde Ajustes de Foráneo si el launcher permite fijarlos. Se actualizan al
guardar cambios y muestran la última actualización. El sistema puede retrasar
alarmas por batería/Doze. Forzar la detención de una app impide sus alarmas hasta
que se vuelva a abrir. No se solicita permiso de alarmas exactas.

Las carpetas iOS/macOS/Linux conservan el proyecto Flutter, pero esta entrega
distribuye Android y Windows. No se afirma que exista un instalable de iPhone
ni widgets de iOS; necesitan desarrollo/firma y pruebas con herramientas Apple.

## Privacidad y cuentas

El perfil es **local**, no una cuenta en la nube. La contraseña deriva una clave
con PBKDF2 y los datos se cifran con AES-GCM; no se guarda la contraseña. No hay
recuperación por correo ni sincronización entre dispositivos. Guarda un respaldo
antes de borrar datos del navegador o desinstalar.

El modo invitado y los respaldos sin cifrar contienen datos legibles. Los textos
de notificaciones y widgets se comparten con el sistema operativo cuando se
habilitan y quedan fuera del cifrado del perfil. No publiques tus respaldos.
El código no contiene analytics ni claves privadas. Enlaces a Calendar, YouTube
o GitHub sólo requieren internet cuando eliges abrir esos servicios.

Google Calendar recibe un **evento preparado para que lo guardes**: no hay
OAuth, importación de tus calendarios ni sincronización bidireccional. Los datos
de cada versión permanecen en su propio dispositivo/navegador.

## Desarrollo web

Requiere Node.js 22 o superior.

```powershell
npm ci
npm run dev
```

Abre http://localhost:5173. No necesitas `.env`, servidor API ni claves.

```powershell
npm test
npm run build
# Para reproducir la ruta de GitHub Pages:
$env:VITE_BASE_PATH = '/Foraneo/'
npm run build
```

`npm run recipes:generate` regenera el catálogo compartido. Los JSON generados se
versionan. `scripts/prepare-assets.mjs` es una utilidad opcional del mantenedor
para descargar las fotos con licencia; la app no la ejecuta ni necesita hacerlo.

## Flutter y distribución

Verificado con Flutter 3.47.4/Dart 3.13.3, Android SDK/JDK de Android
Studio y Visual Studio con Desarrollo para escritorio en C++ para Windows.

```powershell
cd foraneo_flutter
flutter pub get
flutter analyze
flutter test
flutter run
```

Desde la raíz, `scripts/create-signing-key.ps1` crea una llave Android únicamente
si todavía no existe. Conserva privadamente `foraneo_flutter/android/key.properties`
y `foraneo_flutter/android/foraneo-release.jks`: **no se suben a GitHub**. Todas las
actualizaciones del APK deben usar esa misma llave; nunca la regeneres a ciegas.

```powershell
cd foraneo_flutter
flutter build apk --release
flutter build windows --release
```

`scripts/package-release.ps1` requiere Inno Setup y empaqueta los builds en
`artifacts/`: APK, carpeta portable con DLL y datos, ZIP e instalador
`foraneo.exe`. Si falta Inno Setup, se detiene sin modificar los instalables
anteriores. No copies sólo el pequeño ejecutable Flutter: necesita su carpeta.
El instalador no tiene certificado comercial Authenticode; Windows puede mostrar
editor desconocido. El APK sí está firmado con la llave de publicación del autor.

## Publicación

`.github/workflows/deploy-pages.yml` ejecuta pruebas y construye/publica `dist/`
cuando se envía `main`. La fuente de GitHub Pages debe ser **GitHub Actions**.
No se despliega Flutter web encima de la web Vite: son dos frontends del proyecto.

La evidencia de pruebas y las limitaciones verificadas se documentan en
[Verificación de la entrega](docs/VERIFICACION.md).

## Márgenes de precio

El tramo se elige por el precio habitual de la presentación de referencia.

| Referencia habitual | Oferta especial desde | Rechazar desde |
| --- | ---: | ---: |
| Hasta $40 | −15% | +10% |
| Más de $40 a $100 | −15% | +8% |
| Más de $100 a $200 | −15% | +4% |
| Más de $200 a $500 | −10% | +3% |
| Más de $500 a $1,000 | −10% | +2% |
| Más de $1,000 | −10% | +1% |

Los límites son inclusivos: exactamente +10% en el primer tramo ya es rojo;
exactamente −15% ya es oferta. El intervalo restante se autoriza en verde. El
intervalo no especificado originalmente ($1,000–$2,000) usa el margen conservador
de +1%, igual que el tramo superior.

<small>by Joseph Ubaldo Trejo Hernandez</small>
