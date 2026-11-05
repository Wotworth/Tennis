plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.roborazzi)
    alias(libs.plugins.ksp)
    alias(libs.plugins.room)
}

// PLT-02: versionName is 0.<phase>.<run>; versionCode is the build workflow's run number.
val phase = 2
val buildNumber = (System.getenv("VERSION_CODE") ?: "1").toInt()
val buildDate = System.getenv("BUILD_DATE") ?: "local build"

// PLT-03: release signing comes only from the CI secrets. There is no debug-key fallback;
// without the secrets the release APK is left unsigned.
val releaseKeyFile: String? = System.getenv("KEYSTORE_FILE")
val releaseKeyPassword: String? = System.getenv("KEYSTORE_PASSWORD")
val releaseKeyAlias: String? = System.getenv("KEY_ALIAS")

android {
    namespace = "io.github.wotworth.tennis"
    compileSdk = 37

    defaultConfig {
        // PLT-01: the launcher's and the Zune player's prefix plus ".tennis". Never change it.
        applicationId = "io.github.wotworth.tennis"
        minSdk = 34
        targetSdk = 37
        versionCode = buildNumber
        versionName = "0.$phase.$buildNumber"
        buildConfigField("String", "BUILD_DATE", "\"$buildDate\"")
    }

    signingConfigs {
        if (releaseKeyFile != null && releaseKeyPassword != null && releaseKeyAlias != null) {
            create("upload") {
                storeFile = file(releaseKeyFile)
                storePassword = releaseKeyPassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeType = "pkcs12"
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.findByName("upload")
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    // Room's exported schemas, for the migration test (DAT-04). Debug only.
    sourceSets.getByName("debug").assets.directories.add("$projectDir/schemas")

    testOptions {
        unitTests.isIncludeAndroidResources = true
        unitTests.all {
            it.maxParallelForks = (Runtime.getRuntime().availableProcessors() / 2).coerceAtLeast(1)
            it.systemProperty("robolectric.pixelCopyRenderMode", "hardware")
            it.jvmArgs("--add-opens=java.base/java.io=ALL-UNNAMED", "--add-exports=java.base/jdk.internal.access=ALL-UNNAMED")
            // Cloud sessions only: fetch Robolectric's Android runtime from a Maven Central mirror.
            System.getenv("ROBOLECTRIC_REPO_URL")?.let { url -> it.systemProperty("robolectric.dependency.repo.url", url) }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

room {
    schemaDirectory("$projectDir/schemas")
}

roborazzi {
    outputDir.set(file("build/outputs/roborazzi"))
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.health.connect)
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)
    implementation(libs.work.runtime)

    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.junit)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.androidx.test.junit)
    testImplementation(libs.espresso.core)
    testImplementation(libs.robolectric)
    testImplementation(libs.room.testing)
    testImplementation(libs.work.testing)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)
    testImplementation(libs.compose.ui.test.junit4)
    debugImplementation(libs.compose.ui.test.manifest)
}
