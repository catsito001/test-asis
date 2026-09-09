# flutter_local_notifications guarda su caché de alarmas programadas como
# JSON (usando Gson) para poder restaurarlas si el teléfono se reinicia.
# Sin estas reglas, R8 elimina la información genérica que Gson necesita
# en tiempo de ejecución, y CUALQUIER llamada del plugin que lea o borre
# esa caché (por ejemplo, el cancel() que se hace antes de reprogramar una
# alarma) revienta con:
#   java.lang.IllegalStateException: TypeToken must be created with a
#   type argument...
# Esto solo pasa en builds de "release" con minificación activada; en
# "debug"/"flutter run" nunca se nota, por eso es tan fácil pasarlo por
# alto.

-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

-keepattributes Signature
-keepattributes *Annotation*

# Conserva las clases del propio plugin de notificaciones/alarmas.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
