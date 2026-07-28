plugins {
    // Add the dependency for the Google services Gradle plugin
    id("com.google.gms.google-services") version "4.4.0" apply false
}

// Keep Flutter outputs under ../build so the Flutter tool can locate APKs/ABIs easily.
buildDir = file("../build")

allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication {
                create<BasicAuthentication>("basic")
            }
            credentials {
                username = "mapbox"
                val mapboxToken: String = run {
                    val props = java.util.Properties()
                    val localProps = file("local.properties")
                    if (localProps.exists()) {
                        localProps.inputStream().use { props.load(it) }
                    }
                    props.getProperty("MAPBOX_DOWNLOADS_TOKEN") ?: System.getenv("MAPBOX_DOWNLOADS_TOKEN") ?: ""
                }
                password = mapboxToken
            }
        }
    }
}

subprojects {
    // Place module build dirs under the shared ../build folder and ensure :app is evaluated first.
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
