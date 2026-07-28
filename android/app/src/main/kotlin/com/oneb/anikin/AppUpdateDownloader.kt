package com.oneb.anikin

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Environment
import android.util.Log
import android.widget.Toast
import androidx.core.content.ContextCompat
import java.util.concurrent.ConcurrentHashMap

object AppUpdateDownloader {
	private const val apkMimeType = "application/vnd.android.package-archive"
	private const val logTag = "AnikinUpdate"
	private val invalidFileNameCharacter = Regex("[^A-Za-z0-9._-]")
	private val activeDownloads = ConcurrentHashMap<String, Long>()
	private val completionReceivers = ConcurrentHashMap<Long, BroadcastReceiver>()

	fun enqueue(
		context: Context,
		url: String,
		requestedFileName: String,
		version: String,
	): Long {
		activeDownloads[url]?.let { return it }

		val downloadUri = Uri.parse(url)
		require(
			downloadUri.scheme.equals("https", ignoreCase = true) &&
				!downloadUri.host.isNullOrBlank(),
		) {
			"Update downloads require a valid HTTPS URL."
		}

		val appContext = context.applicationContext
		val downloadManager =
			appContext.getSystemService(Context.DOWNLOAD_SERVICE) as? DownloadManager
				?: error("Android DownloadManager is unavailable.")
		val safeVersion = version
			.replace(invalidFileNameCharacter, "_")
			.trim('_')
			.take(48)
			.ifEmpty { "update" }
		val safeRequestedName = requestedFileName
			.substringAfterLast('/')
			.substringAfterLast('\\')
			.replace(invalidFileNameCharacter, "_")
			.takeLast(128)
		val apkFileName = if (safeRequestedName.endsWith(".apk", ignoreCase = true)) {
			safeRequestedName
		} else {
			"Anikin-$safeVersion.apk"
		}
		val destination = "updates/${System.currentTimeMillis()}-$apkFileName"

		val request = DownloadManager.Request(downloadUri)
			.setMimeType(apkMimeType)
			.setTitle("Anikin $version")
			.setDescription(appContext.getString(R.string.update_download_description))
			.setDestinationInExternalFilesDir(
				appContext,
				Environment.DIRECTORY_DOWNLOADS,
				destination,
			)
			.setAllowedNetworkTypes(
				DownloadManager.Request.NETWORK_WIFI or
					DownloadManager.Request.NETWORK_MOBILE,
			)
			.setAllowedOverRoaming(true)
			.setNotificationVisibility(
				DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
			)
			.addRequestHeader("User-Agent", "Anikin/$version")

		val downloadId = downloadManager.enqueue(request)
		check(downloadId >= 0) { "Android could not enqueue the update download." }

		val receiver = object : BroadcastReceiver() {
			override fun onReceive(receiverContext: Context, intent: Intent) {
				if (intent.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) {
					return
				}
				val completedId = intent.getLongExtra(
					DownloadManager.EXTRA_DOWNLOAD_ID,
					-1L,
				)
				if (completedId != downloadId) {
					return
				}

				activeDownloads.remove(url, downloadId)
				completionReceivers.remove(downloadId)
				runCatching { appContext.unregisterReceiver(this) }

				val outcome = queryOutcome(downloadManager, downloadId)
				if (outcome?.status != DownloadManager.STATUS_SUCCESSFUL) {
					Log.e(
						logTag,
						"Update download $downloadId failed with reason ${outcome?.reason}.",
					)
					Toast.makeText(
						appContext,
						R.string.update_download_failed,
						Toast.LENGTH_LONG,
					).show()
					return
				}

				val apkUri = downloadManager.getUriForDownloadedFile(downloadId)
				if (apkUri == null) {
					Log.e(logTag, "No URI was returned for update download $downloadId.")
					Toast.makeText(
						appContext,
						R.string.update_download_failed,
						Toast.LENGTH_LONG,
					).show()
					return
				}
				openInstaller(appContext, apkUri)
			}
		}

		try {
			completionReceivers[downloadId] = receiver
			activeDownloads[url] = downloadId
			ContextCompat.registerReceiver(
				appContext,
				receiver,
				IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE),
				ContextCompat.RECEIVER_EXPORTED,
			)
		} catch (error: Exception) {
			completionReceivers.remove(downloadId)
			activeDownloads.remove(url, downloadId)
			downloadManager.remove(downloadId)
			throw error
		}

		return downloadId
	}

	private fun queryOutcome(
		downloadManager: DownloadManager,
		downloadId: Long,
	): DownloadOutcome? {
		return downloadManager.query(
			DownloadManager.Query().setFilterById(downloadId),
		).use { cursor ->
			if (!cursor.moveToFirst()) {
				return@use null
			}
			DownloadOutcome(
				status = cursor.getInt(
					cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS),
				),
				reason = cursor.getInt(
					cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON),
				),
			)
		}
	}

	private fun openInstaller(context: Context, apkUri: Uri) {
		val installIntent = Intent(Intent.ACTION_VIEW).apply {
			setDataAndType(apkUri, apkMimeType)
			addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
			addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
		}
		try {
			context.startActivity(installIntent)
		} catch (error: Exception) {
			Log.e(logTag, "Unable to open the Android package installer.", error)
			Toast.makeText(
				context,
				R.string.update_installer_unavailable,
				Toast.LENGTH_LONG,
			).show()
		}
	}

	private data class DownloadOutcome(val status: Int, val reason: Int)
}
