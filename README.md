# Asiste — asistente de voz para programar alarmas y eventos

App Flutter para Android. Botón de micrófono grande → hablas → si falta un
dato (hora, fecha, si se repite a diario, etc.) Asiste te lo pregunta en
voz y te escucha → guarda el evento en un calendario simple → a la hora
programada suena y **lee el evento en voz alta**, incluso con la pantalla
apagada o bloqueada, hasta que tocas "Aceptar".

## Cómo está armado (resumen rápido)

- **Reconocimiento de voz y voz hablada**: motores nativos de Android
  (`speech_to_text` y `flutter_tts`), gratis, no consumen tus créditos de
  Gemini.
- **"Inteligencia" (entender qué programar, preguntar lo que falta)**:
  Gemini API (`gemini-2.5-flash` por defecto, cambiable en
  `lib/utils/constants.dart`). Cada turno de la conversación se manda como
  historial completo y Gemini responde siempre en JSON estricto.
- **Hasta 3 API keys con failover automático**: se guardan cifradas
  (`flutter_secure_storage`) en Ajustes. `GeminiService` prueba la
  clave 1; si responde 429/403 (sin cuota), prueba la 2, luego la 3.
- **Alarmas**: `flutter_local_notifications` con alarmas exactas,
  `fullScreenIntent` y categoría `alarm`. El `AndroidManifest.xml` declara
  explícitamente los receivers de alarmas y la actividad principal usa
  `showWhenLocked`/`turnScreenOn` para poder encender la pantalla y mostrar
  la alarma cuando el teléfono está bloqueado.
- **Calendario**: `table_calendar`, resalta con un punto los días con
  eventos y el día seleccionado.

Este proyecto se generó **sin poder compilarlo** (este entorno no tiene el
SDK de Flutter ni acceso a pub.dev), así que revísalo con calma y
avísame si algo no compila tal cual — lo más probable es alguna firma de
método que cambió de versión en uno de los plugins.

## Cómo ponerlo a andar

### Opción A — GitHub Actions (no necesitas instalar Flutter en tu PC)

1. Crea un repositorio nuevo en GitHub y sube el contenido de este zip tal
   cual (`pubspec.yaml`, `lib/`, `android_overlay/`,
   `.github/workflows/build-apk.yml`, `README.md`). No hace falta que
   subas la carpeta `android/` ni `android/app/build.gradle.snippet.txt`
   — el flujo de trabajo genera todo eso solo, en cada compilación.
2. Ve a la pestaña **Actions** del repo. Si no arrancó solo al hacer push,
   entra al workflow "Compilar APK de Asiste" y dale a **Run workflow**.
3. Espera a que termine (unos 5-10 minutos la primera vez). Si algún
   paquete resulta incompatible, va a fallar justo en el paso "Instalar
   dependencias" o en "Compilar APK" — copia el error de ahí y lo
   resolvemos.
4. Al terminar en verde, entra a esa ejecución → **Artifacts** →
   descarga `asiste-apk`. Adentro está `app-release.apk`.
5. Pasa el APK a tu celular (por cable, Drive, lo que uses) e instálalo
   manualmente (Android te va a pedir permitir "orígenes desconocidos" la
   primera vez).

Esta vía es más confiable que compilar a ciegas: el runner de GitHub sí
tiene acceso real a pub.dev, así que instala las versiones vigentes de
verdad de cada paquete (yo solo puse rangos de versión `^` como punto de
partida, sin poder comprobarlos desde aquí).

### Opción B — Compilar en tu propia PC

1. Instala Flutter (si no lo tienes): https://docs.flutter.dev/get-started/install
2. Crea el proyecto base (esto genera todo el andamiaje nativo de Android
   con tu versión instalada de Flutter, incluyendo el `gradle-wrapper`
   binario que yo no puedo generar aquí):
   ```
   flutter create --platforms=android --org com.tuempresa asiste
   ```
3. Copia dentro de esa carpeta (reemplazando lo que ya existe):
   - `pubspec.yaml`
   - toda la carpeta `lib/`
   - `android_overlay/AndroidManifest.xml` → pégalo en
     `android/app/src/main/AndroidManifest.xml`
4. Abre `android/app/build.gradle` (o `build.gradle.kts`) y agrega lo que
   indica `android/app/build.gradle.snippet.txt` (desugaring, necesario
   para que compile `flutter_local_notifications`).
5. Instala las dependencias:
   ```
   cd asiste
   flutter pub get
   ```
6. Conecta un celular Android real por USB (depuración USB activada) y
   corre:
   ```
   flutter run --release
   ```
   Te recomiendo un celular físico, no un emulador: el micrófono y el
   comportamiento de alarma con pantalla apagada no se prueban bien en
   emuladores.

## Conseguir tus API keys gratis de Gemini

Entra a https://aistudio.google.com/apikey con tu cuenta de Google y crea
una clave (puedes crear varias, incluso en distintas cuentas, para tener
más cuota gratuita en total). Pégalas en Asiste → ⚙️ Ajustes.

## Permisos que hay que aceptar en el teléfono

La primera vez que abras la app te va a pedir:
- **Micrófono** (para escucharte).
- **Notificaciones**.
- **Alarmas y recordatorios**: en Android 12/13 esto no se puede pedir
  con un simple diálogo, hay que activarlo a mano en Ajustes del sistema
  → Apps → Asiste → Alarmas y recordatorios. La app te avisa si falta.

## Muy importante: ahorro de batería del fabricante

En Xiaomi, Huawei, Oppo, Samsung, etc. es muy común que el sistema mate
apps en segundo plano de forma agresiva y las alarmas no suenen. Después
de instalar Asiste, entra a Ajustes → Batería → Asiste y desactiva la
optimización de batería / "autoinicio" para esta app. Esto no lo puede
resolver código, es una configuración que cada usuario debe hacer una
vez.

## Estructura del proyecto

```
lib/
  main.dart                     Arranque, rutas, detecta si la app se
                                 abrió por una alarma
  theme/app_theme.dart          Colores y tipografía
  models/
    asiste_event.dart           Un evento/alarma
    gemini_turn_result.dart     Respuesta estructurada de Gemini
  services/
    gemini_service.dart         Llama a Gemini, rota entre las API keys
    secure_settings_service.dart Guarda las API keys cifradas
    speech_service.dart         Reconocimiento de voz
    tts_service.dart            Texto a voz
    notification_service.dart   Programa y dispara las alarmas
    events_repository.dart      Guarda los eventos, avisa a la UI
  screens/
    home_screen.dart            Pantalla del micrófono grande
    settings_screen.dart        Las 3 API keys
    calendar_screen.dart        Calendario con días resaltados
    event_form_screen.dart      Alta/edición manual de un evento
    alarm_ring_screen.dart      Pantalla que suena leyendo el evento
  widgets/
    mic_button.dart
    conversation_bubble.dart
```

## Ideas para seguir mejorando (no incluidas todavía)

- Editar/eliminar eventos por voz ("cancela la alarma de las 8").
- Un ícono propio de la app (por defecto queda el de Flutter).
- Historial de conversación visible y desplazable, no solo el último
  intercambio.


## Solución para alarmas en Xiaomi/Redmi

La alarma usa ahora `AndroidScheduleMode.alarmClock`, `SCHEDULE_EXACT_ALARM`,
pantalla completa y un sonido incluido dentro de la APK. Esto evita depender
del sonido configurado por el sistema Xiaomi y hace que Android trate la tarea
como una alarma exacta.

En un Redmi/Xiaomi, además de aceptar los permisos de Asiste, revisa:

1. Ajustes → Apps → Asiste → Notificaciones: permitir notificaciones y sonido.
2. Ajustes → Apps → Asiste → Alarmas y recordatorios: permitir.
3. Ajustes → Apps → Asiste → Inicio automático: activar.
4. Ajustes → Batería → Asiste: seleccionar **Sin restricciones** o desactivar
   la optimización de batería para Asiste.
5. No pongas Asiste en las aplicaciones restringidas/limpiadas automáticamente
   por el optimizador de batería de Xiaomi.

El plugin de notificaciones advierte oficialmente que algunos fabricantes,
incluido Xiaomi, pueden impedir notificaciones programadas cuando una app queda
en segundo plano. Por eso estos ajustes del sistema son especialmente
importantes en un Redmi. 

La app también verifica después de programar que Android haya dejado la alarma
como pendiente. Si no puede hacerlo, muestra el error en pantalla en vez de
fallar silenciosamente.

## Bug real encontrado: R8/ProGuard rompía la programación de alarmas

En un build de **release** (el que produce `flutter build apk --release`,
usado por el workflow de GitHub Actions), Android minifica el código con
R8. `flutter_local_notifications` guarda su lista de alarmas programadas
como JSON usando Gson, y R8 —si no se le dice lo contrario— borra la
información genérica que Gson necesita para leer/escribir esa caché.
El síntoma exacto: la app guarda el evento pero la alarma nunca se
programa, y el error real (visible en el formulario manual de evento) es:

```
PlatformException(error, TypeToken must be created with a type argument:
new TypeToken<...>() {}; When using code shrinkers (ProGuard, R8, ...)
make sure that generic signatures are preserved., ...)
```

Esto **no tiene nada que ver** con los permisos de "Alarmas y
recordatorios" ni con el fabricante del teléfono (Xiaomi, Samsung, etc.):
pasa en cualquier build de release, de cualquier marca, si faltan las
reglas de ProGuard. Es fácil no detectarlo porque en modo debug
(`flutter run`) nunca ocurre — solo aparece en el APK final que instala
el usuario.

**Arreglo:** se agregó `android_overlay/proguard-rules.pro` con las
reglas que pide oficialmente `flutter_local_notifications`/Gson, y el
workflow de GitHub Actions ahora lo copia a `android/app/proguard-rules.pro`
y lo conecta al `buildTypes.release` antes de compilar. Si compilas a mano
(Opción B), sigue las instrucciones agregadas al final de
`android/app/build.gradle.snippet.txt`.

**Segunda vuelta:** al activar la minificación también habíamos activado
`shrinkResources`, que borró del APK el archivo `res/raw/alarm.wav` por no
detectar que se usa (se referencia por nombre de texto desde Dart, no
desde código nativo) — el síntoma cambió a `invalid_sound, The resource
alarm could not be found`. Se corrigió dejando `shrinkResources`/
`isShrinkResources` en `false` tanto en el workflow como en las
instrucciones manuales.

## Palabra de activación "Alexa" (Fase 1a — experimental)

La app puede escuchar la palabra "Alexa" y arrancar sola una conversación
(dice "¿Sí?" y empieza a escuchar), usando **openWakeWord**: un motor de
detección 100% en el dispositivo (no manda audio a ningún servidor),
gratuito y sin cuenta/clave de ningún proveedor (a diferencia de
Picovoice Porcupine, que dejó de tener capa gratuita permanente en junio
de 2026).

**Alcance actual (Fase 1a):** el motor solo corre mientras la app está
**abierta y en primer plano**. Todavía NO funciona con la pantalla
apagada o la app en segundo plano — eso es la Fase 1b, pendiente, que
agrega un servicio en segundo plano y abre la app encima de la pantalla
de bloqueo (reutilizando el mismo mecanismo que ya usan las alarmas).

**Cómo se integró:**
- Modelos: `alexa_v0.1.onnx` (el detector de la palabra) +
  `melspectrogram.onnx` + `embedding_model.onnx` (el preprocesamiento de
  audio que usa cualquier modelo de openWakeWord), descargados desde las
  releases oficiales de `dscripka/openWakeWord` e incluidos en
  `android_overlay/assets/`.
- Librería Android: `xyz.rementia:openwakeword` (Kotlin, Apache 2.0,
  Maven Central), en `MainActivity.kt`.
- Puente con Flutter: `MethodChannel` "asiste/wakeword" — nativo avisa a
  Dart cuando escucha "Alexa" (`lib/services/wake_word_service.dart`).

**Limitación importante de Android, no de esta app:** el teléfono solo
permite un micrófono (`AudioRecord`) activo a la vez. Por eso, justo
antes de usar el reconocimiento de voz normal (`speech_to_text`), la app
apaga el motor de "Alexa", y lo vuelve a prender apenas termina de
escucharte — así que hay un par de segundos, después de cada frase que le
dices, en que "Alexa" todavía no está escuchando de nuevo (el motor
necesita volver a "calentar" su buffer de audio). Es normal, no es un
bug.

Si "Alexa" tarda en detectar o da falsos positivos, se puede ajustar el
`threshold` (0.5 por defecto, más bajo = más sensible) en
`android_overlay/kotlin/MainActivity.kt`.
