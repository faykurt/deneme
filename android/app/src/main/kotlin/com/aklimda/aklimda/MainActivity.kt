package com.aklimda.aklimda

import android.content.ContentUris
import android.content.ContentValues
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Etkinliğe özel renk (Samsung Takvim'deki renk yuvarlağı): okuma ve yazma.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aklimda/etkinlik_rengi")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "oku" -> {
                            val idler = call.argument<List<String>>("idler") ?: emptyList()
                            val harita = HashMap<String, Int>()
                            for (parca in idler.chunked(400)) {
                                val yer = parca.joinToString(",") { "?" }
                                val imlec = contentResolver.query(
                                    CalendarContract.Events.CONTENT_URI,
                                    arrayOf(CalendarContract.Events._ID, CalendarContract.Events.EVENT_COLOR),
                                    "${CalendarContract.Events._ID} IN ($yer)",
                                    parca.toTypedArray(),
                                    null
                                )
                                imlec?.use { c ->
                                    while (c.moveToNext()) {
                                        if (!c.isNull(1)) harita[c.getLong(0).toString()] = c.getInt(1)
                                    }
                                }
                            }
                            result.success(harita)
                        }
                        "ayarla" -> {
                            val id = call.argument<String>("id")!!.toLong()
                            val renk = call.argument<Number>("renk")
                            val degerler = ContentValues()
                            if (renk == null) {
                                degerler.putNull(CalendarContract.Events.EVENT_COLOR)
                            } else {
                                degerler.put(CalendarContract.Events.EVENT_COLOR, renk.toInt())
                            }
                            val n = contentResolver.update(
                                ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, id),
                                degerler, null, null
                            )
                            result.success(n > 0)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("takvim_renk", e.message, null)
                }
            }
    }
}
