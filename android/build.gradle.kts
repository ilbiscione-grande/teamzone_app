// Top-level build.gradle.kts

buildscript {
  repositories {
    google()
    mavenCentral()
  }
  dependencies {
    // Lägg Android Gradle-plugin på classpath med den version Flutter använder (8.7.0)
    classpath("com.android.tools.build:gradle:8.7.0")
    // Lägg Google services-plugin på classpath
    classpath("com.google.gms:google-services:4.4.2")
  }
}

plugins {
  // Ta bort alla versioner här – bara apply false
  id("com.android.application") apply false
  id("com.android.library") apply false
  id("com.google.gms.google-services") apply false
  id("org.jetbrains.kotlin.android") apply false
}

allprojects {
  repositories {
    google()
    mavenCentral()
  }
}

// Flytta byggmappar om du vill
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
  val newSubprojectBuildDir = newBuildDir.dir(project.name)
  project.layout.buildDirectory.value(newSubprojectBuildDir)
  evaluationDependsOn(":app")
}

// Clean-task
tasks.register<Delete>("clean") {
  delete(rootProject.layout.buildDirectory)
}
