# Guía de Flavors (Entornos de la Aplicación)

Este proyecto está configurado para manejar múltiples entornos (Flavors) permitiendo tener diferentes versiones de la aplicación instaladas simultáneamente en un mismo dispositivo, cada una con su propia configuración, ícono, nombre y URL de API.

Actualmente existen dos entornos configurados:
1. **Producción (Prod)**
2. **Desarrollo (Dev)**

---

## 1. Comandos para Ejecutar (Modo Debug)

Para ejecutar la aplicación en un emulador o dispositivo físico conectado por USB/Wireless, no se debe usar el botón de "Play" estándar sin configuración previa. Utiliza los siguientes comandos en la terminal:

**Para Clini Core Prod (Producción):**
```bash
flutter run --flavor app_prod -t lib/main_app_prod.dart
```

**Para Clini Core Dev (Desarrollo):**
```bash
flutter run --flavor app_dev -t lib/main_app_dev.dart
```

---

## 2. Comandos para Compilar (Instalables)

### Generar APK
Ideal para distribución interna, pruebas directas o QA. 

**Para Clini Core Prod (Producción):**
```bash
flutter build apk --flavor app_prod -t lib/main_app_prod.dart
```
*📌 Ruta del archivo generado:* `build/app/outputs/flutter-apk/app-app_prod-release.apk`

**Para Clini Core Dev (Desarrollo):**
```bash
flutter build apk --flavor app_dev -t lib/main_app_dev.dart
```
*📌 Ruta del archivo generado:* `build/app/outputs/flutter-apk/app-app_dev-release.apk`

### Generar AppBundle (.aab)
Obligatorio si vas a publicar la aplicación en la **Google Play Store**.

**Para Clini Core Prod (Producción):**
```bash
flutter build appbundle --flavor app_prod -t lib/main_app_prod.dart
```
*📌 Ruta del archivo generado:* `build/app/outputs/bundle/app_prodRelease/app-app_prod-release.aab`

---

## 3. ¿Cómo funciona esta configuración?

La separación de entornos está sustentada en tres pilares:

1. **Variables de entorno (`.env.*`)**
   - `.env.app_prod` y `.env.app_dev` contienen las variables específicas (como `API_BASE_URL`).
   - Estos archivos están registrados en el `pubspec.yaml` para que Flutter los empaquete.

2. **Puntos de entrada en Dart**
   - Existen dos archivos `main`: `lib/main_app_prod.dart` y `lib/main_app_dev.dart`.
   - La única diferencia entre ellos es cuál archivo `.env` cargan a través del paquete `flutter_dotenv`.

3. **Configuración Nativa (Android)**
   - En `android/app/build.gradle.kts` se definieron `productFlavors` (`app_prod` y `app_dev`).
   - Cada flavor tiene un `applicationId` diferente (ej. `*.prod` y `*.dev`), lo que permite que el SO Android las identifique como apps distintas.
   - Cada flavor inyecta una variable `appName` en el `AndroidManifest.xml` para que el nombre de la app cambie automáticamente según la versión que se esté compilando.
