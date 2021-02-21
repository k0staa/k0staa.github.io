---
title:  "How to write the first Kotlin code in Java project"
excerpt: "Adding Kotlin to an existing multi-module Java project"
header:
  overlay_image: /assets/images/post_teaser.jpeg
  overlay_filter: 0.5 # same as adding an opacity of 0.5 to a black background
  caption: "Photo credit: [Markus Spiske](http://freeforcommercialuse.net)"
date:   2021-02-21 17:20:00 +0200
tags: kotlin keycloak flutter webflux spring spring-boot security 
---
I wanted to play with several technologies in this project. First thing I wanted to see is how to do the authentication configuration in the Flutter application. I focused only on Flutter For Web although the project should be able to run on other platforms. I used Keycloak as the authentication server. Keycloak can be safely treated as a Swiss Army knife when it comes to authentication. The last topic is the method of authorization using the JWT token in the application which is the API of this project. I'm using Kotlin, Spring Boot, Web Flux, and the Spring Boot Oauth2 Resource Server library in this application.

### Keycloak

### Flutter application

### Spring Boot API application

Project root configuration:

```kotlin
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
	id("org.springframework.boot") version "2.4.2"
	id("io.spring.dependency-management") version "1.0.11.RELEASE"
	id("com.google.cloud.tools.jib") version "2.7.1"

	kotlin("jvm") version "1.4.21"
	kotlin("plugin.spring") version "1.4.21"
}

group = "pl.codeaddict"
version = "0.0.1-SNAPSHOT"
java.sourceCompatibility = JavaVersion.VERSION_11

repositories {
	mavenCentral()
}

dependencies {
	implementation("org.springframework.boot:spring-boot-starter-webflux")
	implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
	implementation("io.projectreactor.kotlin:reactor-kotlin-extensions")
	implementation("org.jetbrains.kotlin:kotlin-reflect")
	implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
	implementation("org.jetbrains.kotlinx:kotlinx-coroutines-reactor")
	implementation("org.springframework.boot:spring-boot-starter-oauth2-resource-server")

	testImplementation("org.springframework.boot:spring-boot-starter-test")
	testImplementation("io.projectreactor:reactor-test")
}

tasks.withType<KotlinCompile> {
	kotlinOptions {
		freeCompilerArgs = listOf("-Xjsr305=strict")
		jvmTarget = "11"
	}
}

tasks.withType<Test> {
	useJUnitPlatform()
}

jib {
	from {
		image = "gcr.io/distroless/java-debian10:11"
	}
	to {
		image = "flutter-kotlin-api"
	}
	container {
		jvmFlags = listOf("-Duser.timezone=UTC")
		ports = listOf("8080")
		creationTime = "USE_CURRENT_TIMESTAMP"
	}
}

```
### Summary
This is it! You can find all the source code in my repository [GitHub account](https://github.com/k0staa/Code-Addict-Repos/tree/master/flutter-spring-kotlin-web). 
Have fun and thanks for reading!

