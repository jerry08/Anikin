package com.oneb.anikin

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.os.Build
import android.util.Rational
import com.oneb.anikin.extensions.AniyomiExtensionsPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private var playbackChannel: MethodChannel? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		AniyomiExtensionsPlugin.registerWith(
			applicationContext,
			flutterEngine.dartExecutor.binaryMessenger,
		)
		playbackChannel = MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"com.oneb.anikin/playback",
		).also { channel ->
			channel.setMethodCallHandler { call, result ->
				when (call.method) {
					"isPictureInPictureSupported" -> result.success(
						Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
							packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE),
					)
					"enterPictureInPicture" -> {
						if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
							result.success(false)
							return@setMethodCallHandler
						}
						val width = (call.argument<Int>("width") ?: 16).coerceAtLeast(1)
						val height = (call.argument<Int>("height") ?: 9).coerceAtLeast(1)
						val params = PictureInPictureParams.Builder()
							.setAspectRatio(Rational(width, height))
							.build()
						result.success(enterPictureInPictureMode(params))
					}
					else -> result.notImplemented()
				}
			}
		}
	}

	override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
		super.onPictureInPictureModeChanged(isInPictureInPictureMode)
		playbackChannel?.invokeMethod(
			"pictureInPictureModeChanged",
			isInPictureInPictureMode,
		)
	}
}
