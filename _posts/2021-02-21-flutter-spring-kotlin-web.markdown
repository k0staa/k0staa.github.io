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
I wanted to play with several technologies in this project. First thing I wanted to see is how to do the authentication configuration in the Flutter application. I focused only on Flutter For Web although the project should be able to run on other platforms too. I used Keycloak as the authentication and authorization server. Keycloak can be safely treated as a swiss army knife when it comes to authorization and authentication. The last topic is the method of authorization using the JWT token in the application that will be used as an API (or resource server). I'm using Kotlin, Spring Boot, Web Flux, and the Spring Boot Oauth2 Resource Server starter library. All the source code can be found in my repository [GitHub account](https://github.com/k0staa/Code-Addict-Repos/tree/master/flutter-spring-kotlin-web). 

The entire project can be run using `docker-compose`:

```yaml
version: "3.7"
services:
  flutter-kotlin-api:
    container_name: flutter-kotlin-api
    image: flutter-kotlin-api
    environment:
      - SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK_SET_URI=http://flutter-kotlin-keycloak:8080/auth/realms/kotlin-flutter-demo-realm/protocol/openid-connect/certs
    ports: 
      - "8080:8080"
  flutter-kotlin-gui:
    container_name: flutter-kotlin-gui
    image: flutter-kotlin-gui
    ports: 
      - "80:80"
  flutter-kotlin-keycloak:
    container_name: flutter-kotlin-keycloak
    image: jboss/keycloak:12.0.3
    environment:
      - KEYCLOAK_USER=admin 
      - KEYCLOAK_PASSWORD=admin 
      - KEYCLOAK_IMPORT=/tmp/realm-export.json
    ports:
      - "8081:8080"
    volumes:
      - ./keycloak-docker/realm-export.json:/tmp/realm-export.json

```
but let's discuss the components of the project :wink:
### Keycloak
Keycloak is an open source software product that allow single sign-on with identity and access management. For the purpose of this application it will serve as an authentication/authorization server. The entire authentication and authorization process will consist of the following steps:
 1. The user who want to access `/secured` endpoint need to first log in using login page.
 2. Username and password is authenticated using Keycloak API
 3. After successfull logging in, Keycloak returns the JWT token.
 4. User can now attempt to enter `/secured` endpoint using a JWT token.
 5. The API server checks the signature of the JWT token with the public endpoint in Keycloak and authorize the action. 
In prepared `docker-compose` configuration you can saw section with Keycloak and its configuration. Configuration is imported at container startup (see `realm-export.json`), the file contains the configuration of the entire realm, including client, role and user (username -> `user` , password -> `password`). If you want to view the Keycloak configuration, you can do it by entering the [administrator console](http://localhost:8081/auth/admin). Keycloak administrator username and password are configured in `docker-compose`:
```yaml
...
environment:
      - KEYCLOAK_USER=admin 
      - KEYCLOAK_PASSWORD=admin
...
```
In the Keycloak configuration the most important thing for us is the configuration of the client. Go to `Clients` and choose` login-app` from the list. The imported configuration should look like this:
![Keycloak_client_config1_img]({{ site.url }}/assets/images/keycloak_client1.png) 
![Keycloak_client_config2_img]({{ site.url }}/assets/images/keycloak_client2.png) 
Note the configuration of `Valid Redirect URIs` and` Web Origins`. The first is important when we use the Keycloak login page to authenticate the user(I am not discussing this approach in this post). The second indicates domains that can request Keycloak API (CORS). If the application that is our GUI is running on the same domain as the keycloak then you do not need to configure anything here. Otherwise, enter a specific domain name. The current value of `*` (which means that every domain had access) is not safe and may only be used for development purposes :fire:

Entering `Roles` we can also see one added `user` role:
![Keycloak_role_config_img]({{ site.url }}/assets/images/keycloak_roles.png) 


If you want to get more information about Keycloak configuration read about it e.g. [Keycloak docs](https://www.keycloak.org/docs/latest/securing_apps/) , [Baeldung blog](https://www.baeldung.com/spring-boot-keycloak#keycloakserver)

### Flutter application
Flutter is quite a new framework, and an even newer part of it is dedicated to web development.
To start playing with Flutter, install it on your system according to the instructions on [this page](https://flutter.dev/docs/get-started/install). And to add web support, follow the instruction on [this page](https://flutter.dev/docs/get-started/web). Currently, Flutter 2 already supports web development in `stable` version (until recently only in `beta`). If you are using Flutter in version below 2 you need to issue following commands before creating a flutter project:
```sh
 flutter channel beta
 flutter upgrade
 flutter config --enable-web
```
Running `flutter channel beta` replaces your current version of Flutter with the `beta` version which supports web development. 

Then all you have to do is run `flutter create myapp` to create application scaffold.
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
As you can see, there is nothing unusual here, we download FLutter and update packages.
It is also necessary to configure the VS Code extension. It is located in the file `.devcontainer/devcontainer`:
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
There is no difference when developing with Visual Studio Code Remote - Containers extension. If, for example, we want to run the Flutter application in debug mode, all we have to do is install the Dart Debug Extension in Chrome. To run the application use following launch command: 

```sh
flutter run -d web-server --web-port $FLUTTER_WEB_PORT
```

`FLUTTER_WEB_PORT` is set to 8090 in `Dockerfile_dev` so if you use VS Code extension then your application will start using this port. 

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

In the directory with flutter project I have also included the `Dockerfile` configuration which allows you to build and run the builded project:
```
# Stage 1 : build production code
FROM ubuntu:20.04 AS build
ARG DEBIAN_FRONTEND=noninteractive
## Prerequisites
RUN apt-get update && apt-get install -y unzip xz-utils git openssh-client curl && apt-get upgrade -y 

## Install flutter beta
RUN curl -L https://storage.googleapis.com/flutter_infra/releases/stable/linux/flutter_linux_2.0.1-stable.tar.xz | tar -C /opt -xJ
ENV PATH="$PATH":"/opt/flutter/.pub-cache/bin:/opt/flutter/bin"

COPY . /app
WORKDIR /app/

RUN flutter build web

## Stage 2 : create the docker final image
FROM nginx:alpine
WORKDIR /usr/share/nginx/html
COPY --from=build /app/build/web ./
COPY nginx/nginx.conf /etc/nginx/nginx.conf
```

This is multistage configuration. First part prepares Flutter environment and build application and then second part is Nginx server with basic configuration used to run this build. To build a project image simply run following command:

```
docker build -t flutter-kotlin-gui .
```

### Spring Boot API application
The application acting as the project API is written with Kotlin and Spring Boot 2 using the Spring WebFlux module. The application has two endpoints:
```kotlin
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController
import reactor.core.publisher.Mono

@RestController
class ApiController {

    @PreAuthorize("permitAll()")
    @GetMapping("/not-secured")
    fun getNonSecuredMessage() = Mono.just(ApiResponse("Server return non secured message"))

    @PreAuthorize("hasRole('USER')")
    @GetMapping("/secured")
    fun getSecuredMessage() = Mono.just(ApiResponse("Server return SECURED message"))
}
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
import org.springframework.web.cors.reactive.CorsWebFilter

import org.springframework.web.cors.CorsConfiguration
import org.springframework.web.cors.reactive.UrlBasedCorsConfigurationSource


/**
 * For Reactive web applications (WebFlux)
 **/
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

I also added a simplified CORS filter configuration that allows you to connect from any foreign domain (`*`). Of course, this settung is not recommended and should be adjusted in production environment :fire: :
```kotlin
import org.springframework.context.annotation.Configuration
import org.springframework.web.reactive.config.CorsRegistry
import org.springframework.web.reactive.config.EnableWebFlux
import org.springframework.web.reactive.config.WebFluxConfigurer


@Configuration
@EnableWebFlux
class CorsGlobalConfiguration : WebFluxConfigurer {
    override fun addCorsMappings(corsRegistry: CorsRegistry) {
        corsRegistry.addMapping("/**")
            .allowedOrigins("*")
            .allowedMethods("PUT", "GET", "POST")
            .maxAge(3600)
    }
}
```

I've also pushed some sample configuration for a project that does not use WebFlux (`pl.codeaddict.flutterapi.config.nonreactive` package) to repository.

In addition to the above classes, there are two more in the API project. First one serves as an endpoints response:
```kotlin
data class ApiResponse(val message: String
```

And the second one is just the main class for this application:
```kotlin
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class FlutterApiApplication

fun main(args: Array<String>) {
	runApplication<FlutterApiApplication>(*args)
}
```

Ok, lets have a look at `application.yml`:
```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          jwk-set-uri: http://localhost:8081/auth/realms/kotlin-flutter-demo-realm/protocol/openid-connect/certs

logging:
  level:
    org.springframework:
      security: INFO
```
The first part is quite important. We are configuring the endpoint url that allows us to check the signature of the JWT token. Keycloak provides such an endpoint. The configuration for this is also added in `docker-compose.yml` file. Second part of the configuration is there to setup logging level in case of any troubles with security. 

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
There is probably nothing special here except maybe `jib` plugin that allows to easily build a docker image with the application.

You can run application using Spring Boot plugin:
```sh
./gradlew bootRun
```
or build docker image using `jib`:
```sh
 ./gradlew jibDockerBuild
```
The project requires Java version >= 11.

### Running whole project
If you build all the docker images following the instructions in the above sections, you can run all parts of the project (API, GUI, Keycloak) with one command issued in the root of the project:
```
docker-compose up
```

The application graphic interface should look like this:
![app_interface_1_img]({{ site.url }}/assets/images/app_interface_1.png)  
There are two buttons in the middle. One runs the endpoint `/secured` and the second is for`/not-secured` endpoint. In the upper right corner you can see the `username`, which if the user is not logged in is `null` (yes, I know it's ugly :wink: ). There is an icon next to the `username` that leads to the login page.

![app_interface_3_img]({{ site.url }}/assets/images/app_interface_2.png)  
If you click on the icon next to the `username`, you will be taken to the login page. You can login using the user data added in Keycloak in our imported realm configuration (username -> `user` , password -> `password`).

![app_interface_3_img]({{ site.url }}/assets/images/app_interface_3.png)  

After logging in successfully, you will be redirected back to the home page where you can try out if `/secured` endpoint is accessible.

As an extra, in the `curl-scripts` directory, I created some useful curl scripts that calls to the secured and insecure API. Thanks to them, you can check the authentication in application and Keycloak API operation. There is also a script that refreshes ACCESS TOKEN using REFRESH TOKEN (I did not implement it in the application), so you can play around fit it.

#### What is missing in this project
Certainly many things :smiley: . But it wasn't my goal to implement everything. I think the most important shortcomings are:
- user after clicking on endpoint `/secured` should be probably automatically taken to login page.
- JWT token expires after some time (can be set in Keycloak), and should be refreshed using refresh token.
- the token is stored in local storage, it is not an ideal solution in terms of security.

### Summary
This is it! You can find all the source code in my repository [GitHub account](https://github.com/k0staa/Code-Addict-Repos/tree/master/flutter-spring-kotlin-web). 
Have fun and thanks for reading!

