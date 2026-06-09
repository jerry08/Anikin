package eu.kanade.tachiyomi.util

import kotlinx.serialization.json.Json
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.get

val defaultJson: Json = Injekt.get()