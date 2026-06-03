pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Apply version-checked KGP → built-in Kotlin patches before Flutter loads plugin Gradle projects.
run {
    val repoRoot = file("..").canonicalFile
    val lockFile = repoRoot.resolve("pubspec.lock")
    val manifestFile = repoRoot.resolve("scripts/kgp-patches/manifest.json")
    if (!lockFile.exists() || !manifestFile.exists()) {
        return@run
    }

    val pubCacheRoot =
        System.getenv("PUB_CACHE")?.let { file(it) }
            ?: System.getenv("LOCALAPPDATA")?.let { file(it).resolve("Pub/Cache") }
            ?: file(System.getProperty("user.home")).resolve(".pub-cache")
    val pubHosted = pubCacheRoot.resolve("hosted/pub.dev")

    @Suppress("UNCHECKED_CAST")
    val manifest =
        groovy.json.JsonSlurper().parse(manifestFile) as List<Map<String, String>>

    fun lockedVersion(packageName: String): String {
        val pattern =
            Regex(
                """  ${Regex.escape(packageName)}:\r?\n(?:.*?\r?\n)*?    version: "(.+?)"""",
                RegexOption.MULTILINE,
            )
        return pattern.find(lockFile.readText())?.groupValues?.get(1)
            ?: error("Could not read locked version for '$packageName' from pubspec.lock")
    }

    for (entry in manifest) {
        val packageName = entry.getValue("package")
        val patchFile = entry.getValue("patchFile")
        val targetRel = entry.getValue("target")
        val version = lockedVersion(packageName)
        val expectedVersion = patchFile.removeSuffix("-build.gradle").substringAfter("-")
        check(version == expectedVersion) {
            "Locked version for '$packageName' is '$version' but patch expects '$expectedVersion'. " +
                "Update scripts/kgp-patches/ before building."
        }

        val patchSource = repoRoot.resolve("scripts/kgp-patches/$patchFile")
        val pluginDir = pubHosted.resolve("$packageName-$version")
        val patchTarget = pluginDir.resolve(targetRel)

        check(patchSource.exists()) { "Patch file missing: $patchSource" }
        check(pluginDir.isDirectory) {
            "Plugin not found in pub cache: $pluginDir (run flutter pub get)"
        }

        patchSource.copyTo(patchTarget, overwrite = true)
        println("Patched: $patchTarget")
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
}

include(":app")
