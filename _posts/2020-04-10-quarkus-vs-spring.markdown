---
title:  "Comparison of speed and demand for system resources application written using Spring Boot 2 and Quarkus"
excerpt: "Playing with Quarkus using Kotlin and comparison with same application written using Spring Boot 2"
header:
  overlay_image: /assets/images/post_teaser.jpeg
  overlay_filter: 0.5 # same as adding an opacity of 0.5 to a black background
  caption: "Photo credit: [Markus Spiske](http://freeforcommercialuse.net)"
date:   2020-02-09 14:52:00 +0200
tags: spring-boot kotlin siddhi 
---
Recently, I watched Quarkus presentations by @burrsutter. The topic interested me a lot because although on a daily basis I do not associate with systems that require running many instances of microservices, but as a developer I am always interested when someone says that something works faster and needs less resources. Burr in his presentation showed very quickly the comparison of Quarkus and Spring Boot, but I wanted to do it a little more accurately myself while playing with a new technology.
During Durr presentation, an important question was asked about comparing the Spring Boot application that is running on a "warmed up" JVM and thus could be faster than the native Quarkus application. Another issue is whether in the world of microservices we can assume that the instances will be "warmed up" but it is still an interesting comparison that I could try to do.

I use Kotlin in both apps and I will give additional thoughts on the use of Kotlin with Quarkus.

First I will show you the code of both applications and describe it a bit, and then we will go to comparison and performance testing.

This is Quarkus project `build.gradle.kts` file:
~~~
aimport io.quarkus.gradle.tasks.QuarkusNative
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

group = "pl.codeaddict"
version = "1.0.0-SNAPSHOT"

plugins {
    java
    id("io.quarkus") version "1.3.1.Final"
    kotlin("jvm") version "1.3.71"
    kotlin("plugin.allopen") version "1.3.71"
}

repositories {
    mavenCentral()
}

dependencies {
    implementation(kotlin("stdlib-jdk8"))

    implementation(enforcedPlatform("io.quarkus:quarkus-bom:1.3.1.Final"))
    implementation("io.quarkus:quarkus-kotlin")
    implementation("io.quarkus:quarkus-resteasy")
    implementation("io.quarkus:quarkus-resteasy-jackson")
    implementation("io.quarkus:quarkus-agroal")
    implementation("io.quarkus:quarkus-jdbc-h2")

    testImplementation("io.quarkus:quarkus-junit5")
    testImplementation("io.rest-assured:rest-assured")
}

tasks {
    named<QuarkusNative>("buildNative") {
        isEnableHttpUrlHandler = true
    }
}

allOpen {
    annotation("javax.ws.rs.Path")
    annotation("javax.enterprise.context.ApplicationScoped")
    annotation("io.quarkus.test.junit.QuarkusTest")
}

java {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}

val compileKotlin: KotlinCompile by tasks
compileKotlin.kotlinOptions {
    jvmTarget = "11"
}

val compileTestKotlin: KotlinCompile by tasks
compileTestKotlin.kotlinOptions {
    jvmTarget = "11"
}
~~~
Some things need to be explained. 
First of all, remember that if you want to build a native application in Quarkus, you must use Quarkus extensions. The list of extensions is available [here](https://quarkus.io/extensions/), and I think there are so many of them that they can meet a lot of developers' needs. You can also use an [initilizer](https://code.quarkus.io/) similar to the one offered by Spring to create the project configuration.
Another important thing is `isEnableHttpUrlHandler` option, you need to set it to `true` if you creating web application and http url handler should be enabled in native build. 

~~~java
~~~
Let's move to the first controller whose task is to capture a POST request with a message and send to RabbitMQ through the service:
~~~java
~~~
And now the last part of the application, i.e. the service listening for the alarm queue and writing incoming messages to the console:
~~~java
~~~

This is it! You can find all the source code in my repository [GitHub account](https://github.com/k0staa/Code-Addict-Repos/tree/master/siddhi-demo). 
Have fun and thanks for reading!
