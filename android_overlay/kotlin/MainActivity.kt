package com.asiste.app

import android.util.Log
import com.rementia.openwakeword.lib.WakeWordEngine
import com.rementia.openwakeword.lib.model.DetectionMode
import com.rementia.openwakeword.lib.model.WakeWordModel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * Fase 1a de la función "Alexa": el motor de detección (openWakeWord,
 * 100% en el dispositivo, sin nube) corre SOLO mientras esta pantalla
 * está abierta y en primer plano. Todavía no hay servicio en segundo
 * plano ni pantalla de bloqueo — eso es la Fase 1b, una vez que esto
 * quede probado y funcionando de forma confiable.
 *
 * Puente con Dart: MethodChannel "asiste/wakeword".
 *   - Dart -> nativo: "start" (arranca el motor), "stop" (lo detiene y
 *     libera el micrófono — imprescindible antes de usar speech_to_text,
 *     porque Android solo permite un AudioRecord activo a la vez).
 *   - nativo -> Dart: invoca "onWakeWordDetected" cuando escucha "Alexa".
 */
class MainActivity : FlutterActivity() {
    private val channelName = "asiste/wakeword"
    private var methodChannel: MethodChannel? = null
    private var engine: WakeWordEngine? = null
    private val scope = CoroutineScope(Dispatchers.Default + Job())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startEngine()
                    result.success(null)
                }
                "stop" -> {
                    stopEngine()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startEngine() {
        if (engine != null) return
        try {
            val model = WakeWordModel(name = "Alexa", modelPath = "wakeword/alexa.onnx", threshold = 0.5f)
            val newEngine = WakeWordEngine(
                context = applicationContext,
                models = listOf(model),
                detectionMode = DetectionMode.SINGLE_BEST,
            )
            engine = newEngine
            newEngine.start()
            scope.launch {
                newEngine.detections.collect {
                    runOnUiThread {
                        methodChannel?.invokeMethod("onWakeWordDetected", null)
                    }
                }
            }
        } catch (e: Exception) {
            // No tiramos la app abajo por esto: si el motor no arranca (por
            // ejemplo, sin permiso de micrófono todavía), simplemente la
            // palabra de activación no funcionará hasta el siguiente intento.
            Log.e("Asiste", "No se pudo iniciar el motor de wake word", e)
        }
    }

    private fun stopEngine() {
        engine?.release()
        engine = null
    }

    override fun onDestroy() {
        stopEngine()
        super.onDestroy()
    }
}
