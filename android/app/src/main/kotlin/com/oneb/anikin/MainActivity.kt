package com.oneb.anikin

import com.oneb.anikin.extensions.AniyomiExtensionsPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		AniyomiExtensionsPlugin.registerWith(
			applicationContext,
			flutterEngine.dartExecutor.binaryMessenger,
		)
	}
}
