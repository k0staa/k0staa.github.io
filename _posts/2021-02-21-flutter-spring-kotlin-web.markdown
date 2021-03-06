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
The entire project can be run with `docker-compose`. Configuration:
```yaml




```
### Keycloak
Keycloak is an open source software product to allow single sign-on with identity and access management. For the purpose of this application it will serve as an authentication server. The entire authentication and authorization process will be as follows:
 1. The user trying to enter the secured endpoint will be redirected to the Keycloak login page.
 2. After logging in, Keycloak returns the JWT token
 3. Attempting to get data from a secured pointpoint (API)
 4. The server checks the signature of the JWT token with the public endpoint in Keycloak and authenticates the action. 
In the project repository I prepared the docker-compose configuration with Keycloak and its configuration. Configuration is imported at container startup (see `realm-export.json`), the file contains the configuration of the entire realm, including client, role and user (username -> `user` , password -> `password`).

If you want to do Keycloak configuration manually you can read it e.g. [here](https://www.baeldung.com/spring-boot-keycloak#keycloakserver)

IMPORTANT -> Web Origins must be -> * this is CORS!!!
### Flutter application
Flutter is quite a new framework, and an even newer part of it is dedicated to web development.
To start playing with Flutter, install it on your system according to the instructions on [this page](https://flutter.dev/docs/get-started/install). And to add web support, follow the instruction on [this page](https://flutter.dev/docs/get-started/web). Currently, Flutter version> 2.0 already supports web development in stable version (until recently in beta version). If you are uisng Flutter in version below 2.0 you need to issue following commands before creating a flutter project:
```sh
 flutter channel beta
 flutter upgrade
 flutter config --enable-web
```
Running `flutter channel beta` replaces your current version of Flutter with the beta version which supports web development (Flutter < 2.0). 

Then all you have to do is run `flutter create myapp` and we have the Flutter For Web application ready.
In order not to have to install Flutter on my system and be able to easily transfer the project to another computer, I added the `Dockerfile_dev` file to the project with the appropriate Flutter configuration, thanks to which I can use the Visual Studio Code Remote - Containers extension. This extension lets you use a Docker container as a full-featured development environment. You can read more about it on [this page](https://code.visualstudio.com/docs/remote/containers). The mentioned `Dockerfile_dev` file looks like this:
```sh
FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive

ENV FLUTTER_WEB_PORT="8090"
ENV FLUTTER_DEBUG_PORT="42000"

# Prerequisites
RUN apt-get update && apt-get install -y unzip xz-utils git openssh-client curl && apt-get upgrade -y 

# Install flutter beta
RUN curl -L https://storage.googleapis.com/flutter_infra/releases/stable/linux/flutter_linux_2.0.1-stable.tar.xz | tar -C /opt -xJ

ENV PATH="$PATH":"/opt/flutter/.pub-cache/bin:/opt/flutter/bin"

# Enable web capabilities
RUN flutter upgrade
RUN flutter update-packages
```
As you can see, there is nothing unusual here, we download FLutter and configure it so that we can create web projects.
It is also necessary to configure the extension. It is located in the file `.devcontainer/devcontainer`:
```json
{
	"name": "Flutter",
	"dockerFile": "../Dockerfile_dev",
	"extensions": [
		"dart-code.dart-code",
		"dart-code.flutter",
		"k--kato.intellij-idea-keybindings"
	],
	"runArgs": [],
	"postCreateCommand": "flutter pub get"
}
```
We indicate in it the Dockerfile that we want to use and needed VS Code extensions which we will also use during development. There is also `postCreateCommand` which runs `flutter pub get` command (install packages) after container is created. There are many more configuration options - take a look at the documentation on the page I mentioned above.
To run the docker configuration using the extension, click the green icon in the lower left corner of VS Code:
![VS_Code_remote_containers_img]({{ site.url }}/assets/images/vs_code_remote_containers.png)  
There is no difference when developing with Visual Studio Code Remote - Containers extension. If, for example, we want to run the Flutter application in debug mode, all we have to do is install the Dart Debug Extension in Chrome and run the application using following launch command: 
```sh
flutter run -d web-server --web-port $FLUTTER_WEB_PORT
```
If you want to debug please use the added launch configuration:
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "flutter-dart DEBUG",
            "request": "launch",
            "type": "dart",
            "program": "lib/main.dart",
            "args": [
                "-d",
                "web-server",
                "--web-port",
                "$FLUTTER_WEB_PORT",
                "--web-enable-expression-evaluation"
            ]
        }
    ]
}
```

Sometimes VS Code shows you errors in the code, click on the Remote-Containers extension icon and click on `Reopen ...` this should help (you can also ignore them when you want to just run the application). 

### Spring Boot API application
The application acting as the project API is written with Kotlin and Spring Boot 2 using the Spring WebFlux module. The application has two endpoints:
```kotlin
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.CrossOrigin
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController
import reactor.core.publisher.Mono

@RestController
class ApiController {

    @CrossOrigin
    @PreAuthorize("permitAll()")
    @GetMapping("/not-secured")
    fun getNonSecuredMessage() = Mono.just(ApiResponse("Server return non secured message"))

    @CrossOrigin
    @PreAuthorize("hasRole('USER')")
    @GetMapping("/secured")
    fun getSecuredMessage() = Mono.just(ApiResponse("Server return SECURED message"))

```
As you can see one of them is secured and one permits all connections. 
Security configuration using JWT tokens for an application using WebFlux should looks as follows:
```kotlin
import org.slf4j.LoggerFactory
import org.springframework.context.annotation.Bean
import org.springframework.security.config.annotation.method.configuration.EnableReactiveMethodSecurity
import org.springframework.security.config.annotation.web.reactive.EnableWebFluxSecurity
import org.springframework.security.config.web.server.ServerHttpSecurity
import org.springframework.security.oauth2.server.resource.authentication.ReactiveJwtAuthenticationConverterAdapter
import org.springframework.security.web.server.SecurityWebFilterChain

@EnableWebFluxSecurity
@EnableReactiveMethodSecurity
class ReactiveSecurityConfig {

    private val log = LoggerFactory.getLogger(this.javaClass)

    @Bean
    fun springSecurityFilterChain(http: ServerHttpSecurity): SecurityWebFilterChain? {
        log.info("Customizing security configuration (reactive)")
        http
            .authorizeExchange { exchanges ->
                exchanges
                    .anyExchange().permitAll()
            }
            .oauth2ResourceServer { oauth2ResourceServer ->
                oauth2ResourceServer
                    .jwt { jwt ->
                        jwt.jwtAuthenticationConverter(
                            ReactiveJwtAuthenticationConverterAdapter(
                                KeycloakRealmRoleConverter()
                            )
                        )
                    }
            }
        return http.build()
    }
}
```
An important point is setting `jwt.jwtAuthenticationConverter(ReactiveJwtAuthenticationConverterAdapterKeycloakRealmRoleConverter())`. `KeycloakRealmRoleConverter` allows to extract roles from a JWT token:

```kotlin

import org.springframework.security.core.authority.SimpleGrantedAuthority
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter
import java.util.Collections.emptyList
import java.util.Collections.emptyMap

class KeycloakRealmRoleConverter : JwtAuthenticationConverter() {
    private val authorityPrefix = "ROLE_"

    override fun extractAuthorities(jwt: Jwt): Collection<SimpleGrantedAuthority> {
        val authorities = jwt.claims["realm_access"] as Map<String, List<String>>? ?: emptyMap()
        return authorities.getOrDefault("roles", emptyList())
            .map { roleName -> "$authorityPrefix${roleName.toUpperCase()}" }
            .map { role -> SimpleGrantedAuthority(role) }
    }
}

```
In the repository I also added a sample configuration for a project that does not use WebFlux (`pl.codeaddict.flutterapi.config.nonreactive` package).
In addition to the above classes, there are two more in the API project. First one serves as an endpoints response:
```kotlin
data class ApiResponse(val message: String
```
And the second one is just main one for this application:
```kotlin
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class FlutterApiApplication

fun main(args: Array<String>) {
	runApplication<FlutterApiApplication>(*args)
}
```

Last but not least project gradle configuration:

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
As you can see, I added a jib plugin that allows you to easily build a docker image with the application.

You can run API application using:
```sh
./gradlew bootRun
```
or build docker image using:
```sh
 ./gradlew jibDockerBuild
```
The project requires Java version >= 11.

### Running whole project
If you build all the images following the instructions in the above sections, you can run all parts of the project (API, GUI, Keycloak) with one command issued in the root of the project.

In the `curl-scripts` directory, I created some useful curl scripts that calls to the secured and insecure API. Thanks to them, you can check the API and Keycloak operation.
### Summary
This is it! You can find all the source code in my repository [GitHub account](https://github.com/k0staa/Code-Addict-Repos/tree/master/flutter-spring-kotlin-web). 
Have fun and thanks for reading!

