package com.oneb.anikin

import android.app.PictureInPictureParams
import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Rational
import com.oneb.anikin.extensions.AniyomiExtensionsPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private var playbackChannel: MethodChannel? = null
	private var pendingUpdate: PendingUpdate? = null

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		if (isTelevisionDevice()) {
			requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
		}
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		AniyomiExtensionsPlugin.registerWith(
			applicationContext,
			flutterEngine.dartExecutor.binaryMessenger,
		)
		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"com.oneb.anikin/device",
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"isTelevision" -> result.success(isTelevisionDevice())
				else -> result.notImplemented()
			}
		}
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
		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"com.oneb.anikin/app_update",
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"downloadAndInstall" -> {
					val url = call.argument<String>("url")
					val fileName = call.argument<String>("fileName")
					val version = call.argument<String>("version")
					if (url.isNullOrBlank() ||
						fileName.isNullOrBlank() ||
						version.isNullOrBlank()
					) {
						result.error(
							"invalid_update",
							"The update download is missing required details.",
							null,
						)
						return@setMethodCallHandler
					}
					startUpdate(PendingUpdate(url, fileName, version, result))
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun isTelevisionDevice(): Boolean {
		val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
		return uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
			packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
	}

	@Suppress("DEPRECATION")
	private fun startUpdate(update: PendingUpdate) {
		if (requiresInstallPermission()) {
			if (pendingUpdate != null) {
				update.result.error(
					"install_permission_pending",
					"An Android install-permission request is already open.",
					null,
				)
				return
			}

			pendingUpdate = update
			val settingsIntent = Intent(
				Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
				Uri.parse("package:$packageName"),
			)
			try {
				startActivityForResult(settingsIntent, installPermissionRequestCode)
			} catch (error: Exception) {
				pendingUpdate = null
				update.result.error(
					"install_settings_unavailable",
					"Android could not open the Install unknown apps settings.",
					null,
				)
			}
			return
		}

		enqueueUpdate(update)
	}

	private fun requiresInstallPermission(): Boolean =
		Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
			!packageManager.canRequestPackageInstalls()

	private fun enqueueUpdate(update: PendingUpdate) {
		try {
			update.result.success(
				AppUpdateDownloader.enqueue(
					applicationContext,
					update.url,
					update.fileName,
					update.version,
				),
			)
		} catch (error: Exception) {
			update.result.error(
				"update_download_failed",
				error.message ?: "Android could not start the update download.",
				null,
			)
		}
	}

	@Suppress("DEPRECATION")
	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)
		if (requestCode != installPermissionRequestCode) {
			return
		}

		val update = pendingUpdate ?: return
		pendingUpdate = null
		if (requiresInstallPermission()) {
			update.result.error(
				"install_permission_denied",
				"Allow Anikin to install unknown apps, then try the update again.",
				null,
			)
			return
		}
		enqueueUpdate(update)
	}

	override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
		super.onPictureInPictureModeChanged(isInPictureInPictureMode)
		playbackChannel?.invokeMethod(
			"pictureInPictureModeChanged",
			isInPictureInPictureMode,
		)
	}

	private data class PendingUpdate(
		val url: String,
		val fileName: String,
		val version: String,
		val result: MethodChannel.Result,
	)

	private companion object {
		const val installPermissionRequestCode = 4_081
	}
}
