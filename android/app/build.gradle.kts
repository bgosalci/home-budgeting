import groovy.json.JsonSlurper
import java.io.File
import java.util.Base64

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "com.homebudgeting"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.homebudgeting"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.14"
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    val generatedResDir = layout.buildDirectory.dir("generated/res/appIcon")
    sourceSets["main"].res.srcDir(generatedResDir)
}

val repoRoot = rootProject.projectDir.parentFile!!
val manifestFile = File(repoRoot, "tools/app-icon-manifest.json")
val iconOutput = layout.buildDirectory.file("generated/res/appIcon/drawable-nodpi/ic_launcher_foreground.png")

val restoreAppIcon by tasks.registering {
    inputs.file(manifestFile)
    outputs.file(iconOutput)

    doLast {
        val manifest = JsonSlurper().parse(manifestFile) as Map<*, *>
        val base64 = manifest["assets/hb-pie_bottom-left-1024x1024.png"] as? String
            ?: error("App icon base64 entry missing from tools/app-icon-manifest.json")

        val outputFile = iconOutput.get().asFile
        outputFile.parentFile.mkdirs()
        outputFile.writeBytes(Base64.getDecoder().decode(base64))
    }
}

tasks.named("preBuild").configure {
    dependsOn(restoreAppIcon)
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.09.02"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material3:material3-window-size-class")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.navigation:navigation-compose:2.8.4")
    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    testImplementation("junit:junit:4.13.2")
    androidTestImplementation(platform("androidx.compose:compose-bom:2024.09.02"))
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
