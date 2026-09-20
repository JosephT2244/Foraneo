# Verificación de Foráneo 2.0

Registro de comprobaciones realizadas el **19 de septiembre de 2026** sobre
el árbol de trabajo de la entrega 2.0. No constituye una garantía de ausencia
total de errores ni una certificación de todos los teléfonos o navegadores.

## Web: comprobaciones ejecutadas

Entorno local: Windows, Node.js 24.15.0, npm 11.12.1 y Vite 7.3.6. El flujo de
GitHub Actions usa Node.js 22.

| Comprobación | Resultado |
| --- | --- |
| `npm test` | 30 pruebas aprobadas; 0 fallos, omitidas o canceladas |
| `VITE_BASE_PATH=/Foraneo/ npm run build` | Compilación de producción completada; rutas de recursos bajo `/Foraneo/` |
| `npm audit --json` | 0 vulnerabilidades reportadas en las dependencias instaladas |
| Catálogo web y Flutter | Ambos archivos JSON tienen el mismo SHA-256 |

Las pruebas cubren reglas inclusivas de precios y normalización por empaque;
catálogo, restricciones alimentarias y búsqueda; faltantes de despensa;
cifrado y contraseña incorrecta; guardados concurrentes; fechas y exportación
de calendario; restauración/validación de respaldos y caché sin conexión.

La regresión de formularios comprueba alta y edición de productos, compras,
recetas y pendientes usando el manejador real de envío. En particular, evita
que un campo llamado `id` o `name` oculte propiedades del formulario y provoque
guardados silenciosamente omitidos. No sustituye una prueba completa de cámara,
permisos o navegación en un teléfono físico.

El build produjo `index-DN-fxls2.js` (5,455.42 kB; 139.66 kB gzip) y
`index-SCazrsUo.css` (39.26 kB; 8.84 kB gzip). Vite advierte que el JavaScript
supera 500 kB sin comprimir porque incluye el recetario. La compilación termina
correctamente; el coste de análisis y memoria sigue requiriendo observación en
teléfonos de gama baja, aunque no se descarga un modelo de IA.

SHA-256 compartido por `public/recipes/catalog.json` y
`foraneo_flutter/assets/recipes/catalog.json`:

```text
4141960226c7c5cf059537fcff03dab5939174aff28560d8cbf84d25e80cbdcc
```

## Artefactos nativos existentes y comprobados

Los builds de publicación se recompilaron y empaquetaron el **20 de septiembre
de 2026** con Flutter 3.47.4/Dart 3.13.3. Se recalcularon los tres hashes y
coinciden con `artifacts/SHA256SUMS.txt`.

| Archivo | Tamaño exacto |
| --- | ---: |
| `foraneo.apk` | 59,339,037 bytes |
| `foraneo.exe` — instalador Windows | 13,964,951 bytes |
| `foraneo-windows-portable.zip` | 16,245,956 bytes |

```text
28de18b2aeb4304e53ead38787e33ddd9fea06cbdd5d45bd800c967185996cf9  foraneo.apk
10aedc3fe74ff2eadf0bd5ea9f6c9704cdf3c70ebe80ce002e8ce95d83f48cfa  foraneo.exe
42e58978b8542f89afdd59f12f8d0799a8f6787b4dae07b5b503fc8fc06c3df0  foraneo-windows-portable.zip
```

El ejecutable interno de Flutter es distinto del instalador y necesita toda
la carpeta portable, incluidas DLL, datos y recursos. La existencia y el hash
de un instalable no prueban por sí solos su funcionamiento en todos los
dispositivos. El APK se instaló y abrió en un emulador aislado Android 15/API
35; sus cuatro proveedores de widgets quedaron registrados. También se
comprobó visualmente el inicio de la app Windows desde la carpeta portable.
Esto no sustituye las pruebas en dispositivos físicos.

## Alcance y límites reales

- El recetario es local: 1,225 variantes estructuradas de 54 bases originales,
  no 1,225 platos independientes ni un modelo generativo. No usa una API de IA.
- Los perfiles y los datos son locales. No hay recuperación por correo ni
  sincronización en la nube. Los respaldos sin cifrar deben protegerse.
- Android implementa widgets nativos y recordatorios persistentes. La entrega
  de avisos requiere permiso y depende de batería/Doze; no solicita alarmas
  exactas. La app detenida a la fuerza no recibe alarmas hasta volver a abrirla.
- Web y Windows necesitan la app abierta para detectar o ejecutar avisos
  programados. La PWA es instalable, pero no ofrece widgets nativos.
- El calendario externo es un formulario de Google Calendar prellenado para
  guardado manual, no sincronización automática. YouTube se ofrece como búsqueda.
- La web funciona sin conexión después de la primera carga/caché exitosa.
  Cámara, instalación PWA y notificaciones varían por navegador y permisos.
- No se distribuye una versión firmada de iPhone. Windows puede avisar de
  editor desconocido porque el instalador no tiene certificado Authenticode.
- Estas comprobaciones locales no prueban que GitHub Pages o los descargables
  públicos ya estén publicados; la publicación exige verificar el despliegue
  y la release remotos por separado.

Consulta el [README](../README.md) para uso, compilación, privacidad y las
instrucciones de empaquetado reproducible.
