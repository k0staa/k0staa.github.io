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

### Description of both projects
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
First of all, remember that if you want to build a native application in Quarkus, you must use Quarkus extensions. The list of extensions is available [here](https://quarkus.io/extensions/), and I think there are so many of them that they can meet a lot of developers' needs. So I used the Quarkus extensions that were required to create a simple application that provides REST API and connects to the database. For the latter, I used the simplest `agroal` library which provide JDBC connection pool and allows very simple communication with the database.

To create project configuration you can also use an [initilizer](https://code.quarkus.io/) similar to the one offered by Spring to create the project configuration.
Another important thing is `isEnableHttpUrlHandler` option, you need to set it to `true` if you creating web application and http url handler should be enabled in native build. 
As you can see I used the `allopen` plugin which sets the compilation so that all classes are not final if they have specific annotations (set in `allOpen` code block). This allows to create proxy objects and is required by many libraries including Quarkus.

Let's have look on Spring Boot project `build.gradle.kts` file:
~~~
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
	id("org.springframework.boot") version "2.2.6.RELEASE"
	id("io.spring.dependency-management") version "1.0.9.RELEASE"
	kotlin("jvm") version "1.3.71"
	kotlin("plugin.spring") version "1.3.71"
}

group = "pl.codeaddict"
version = "1.0.0-SNAPSHOT"

repositories {
	mavenCentral()
}

dependencies {
	implementation("org.springframework.boot:spring-boot-starter")
	implementation("org.springframework.boot:spring-boot-starter-web")
	implementation("org.springframework.boot:spring-boot-starter-data-jdbc")
	runtimeOnly("com.h2database:h2:1.4.200")

	implementation("org.jetbrains.kotlin:kotlin-reflect")
	implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")

	testImplementation("org.springframework.boot:spring-boot-starter-test") {
		exclude(group = "org.junit.vintage", module = "junit-vintage-engine")
	}
	testImplementation("io.rest-assured:rest-assured")

}

tasks.withType<Test> {
	useJUnitPlatform()
}

java {
	sourceCompatibility = JavaVersion.VERSION_11
	targetCompatibility = JavaVersion.VERSION_11
}

val compileKotlin: KotlinCompile by tasks
compileKotlin.kotlinOptions {
	jvmTarget = "11"
	freeCompilerArgs = listOf("-Xjsr305=strict")
}

val compileTestKotlin: KotlinCompile by tasks
compileTestKotlin.kotlinOptions {
	jvmTarget = "11"
}
~~~
As you can see in above file I used very similar libraries so that the projects differ as little as possible. So access to the database will be done through the JDBC template.

Ok, time to show API controller (Quarkus project):

~~~java
import javax.ws.rs.*
import javax.ws.rs.core.MediaType

@Path("/api")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
class ApiResource(private val service: ApiResourceService) {

    @GET
    @Path("/{data}")
    fun apiGet(@PathParam("data") data: String): DataObject {
        return service.readDataObject(data)
                .orElseThrow { RuntimeException("No data object with data: $data") }
    }

    @POST
    fun apiPost(dataObject: DataObject): Int {
        return service.storeDataObject(dataObject)
    }
}

~~~
I don't think there is much to explain here. In Quarkus we use JAX-RS annotations to configure controllers. I created two endpoints, one for returning data from DB and one for saving new data in DB.

API controller in Spring Boot is very similar:

~~~java
import org.springframework.http.MediaType
import org.springframework.web.bind.annotation.*

@RestController
class ApiResource(private val service: ApiResourceService) {

    @GetMapping(path = ["/api/{name}"], produces = [MediaType.APPLICATION_JSON_VALUE])
    fun apiGet(@PathVariable name: String): DataObject {
        return service.readDataObject(name)
                .orElseThrow { RuntimeException("No data object with name: $name") }
    }

    @PostMapping(path = ["/api"], consumes = [MediaType.APPLICATION_JSON_VALUE], produces = [MediaType.APPLICATION_JSON_VALUE])
    fun apiPost(@RequestBody dataObject: DataObject): Int {
        return service.storeDataObject(dataObject)
    }
}
~~~

Time for servce in Quarkus project:

~~~java
import io.agroal.api.AgroalDataSource
import java.sql.ResultSet
import java.sql.Statement
import java.util.*
import javax.inject.Singleton


@Singleton
open class ApiResourceService(private val dataSource: AgroalDataSource) {

    fun readDataObject(data: String): Optional<DataObject> {
        val sql = "SELECT * FROM DATA_OBJECTS WHERE DATA = '$data'"
        val statement = getConnectionStatement()
        val results: ResultSet = statement.executeQuery(sql)
        var dataResult: DataObject? = null
        while (results.next()) {
            val resultData: String = results.getString("DATA")
            dataResult = DataObject(resultData)
            break
        }

        return Optional.ofNullable(dataResult)
    }

    fun storeDataObject(data: DataObject): Int {
        val statement = getConnectionStatement()
        statement.execute("DROP TABLE DATA_OBJECTS IF EXISTS")
        statement.execute("CREATE TABLE DATA_OBJECTS(" +
                "ID INT, DATA VARCHAR(100))")

        return statement.executeUpdate("INSERT INTO DATA_OBJECTS(DATA) VALUES ('${data.data}')")
    }

    private fun getConnectionStatement(): Statement {
        return dataSource.connection.createStatement()
    }


~~~
**One important thing worth mention**. Quarkus gives us hot reload when we use `./gradlew quarkusDev` without any additional requirements.It's cool feature. Unfortunately, when we use Kotlin we can encounter many problems with the initialization/injection of beans. For example, the annotation `@ApplicationScope` which can be found in many Quarkus examples, makes the `dataSource` object not initializing. When we use this annotation and we change something in the `ApiResourceService` class and hot reload occurs `dataSource` object will be null. I used the `@Singleton` annotation here, but its limitations should be taken into account (check [StackOverflow question](https://stackoverflow.com/questions/26832051/singleton-vs-applicationscope/27848417)) or do not use the Kotlin with Quarkus :disappointed: (Kotlin is still marked as beta on Quarku initializr site).

Let's see same service but for Spring Boot project:
~~~java
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Service
import java.sql.ResultSet
import java.util.*


@Service
open class ApiResourceService(private val jdbcTemplate: JdbcTemplate) {

    fun readDataObject(data: String): Optional<DataObject> {
        val sql = "SELECT * FROM DATA_OBJECTS WHERE DATA = ?"

        return Optional.ofNullable(jdbcTemplate.queryForObject(sql, arrayOf<Any>(data)) { rs: ResultSet, _: Int ->
            DataObject(rs.getString("DATA"))
        })
    }

    fun storeDataObject(dataObject: DataObject): Int {
        jdbcTemplate.execute("DROP TABLE DATA_OBJECTS IF EXISTS")
        jdbcTemplate.execute("CREATE TABLE DATA_OBJECTS(" +
                "ID INT, DATA VARCHAR(100))")
        return jdbcTemplate.update("INSERT INTO DATA_OBJECTS(DATA) VALUES (?)", dataObject.data)
    }
}
~~~

In both project I use same entity model:
~~~java
data class DataObject (val data: String = "")
~~~
Last but not least, properties files. First Quarkus:
~~~
quarkus.datasource.db-kind=h2
quarkus.datasource.username=sa

quarkus.datasource.jdbc.url=jdbc:h2:tcp://localhost:1521/test
quarkus.datasource.jdbc.min-size=4
quarkus.datasource.jdbc.max-size=16
~~~
It's worth to mention that Quarkus use one property file for every profiles (configuration entries for each profile are marked with prefix), so I thinking that it can be quite messy sometimes. In the first versions it was not possible to use the YAML file but now it is possible after adding the appropriate extension.
Spring Boot property file:
~~~
spring.datasource.url=jdbc:h2:tcp://localhost:1521/test
spring.datasource.username=sa
spring.datasource.password=
spring.datasource.hikari.minimumIdle=4
spring.datasource.hikari.maximumPoolSize=16

~~~

### Running the applications
We can proceed to running the application. Let's start by running the H2 database in a separate docker container. We can do it using the prepared `docker-compose.yml` configuration which can be found in the root project directory. Just use below command:
~~~
docker-compose up -d h2
~~~
...this will start H2 database. Now we have few options when it comes to running Quarkus project:
- Start in JVM (dev mode) - just run `./gradlew quarkusDev`. This mode is made for development and it has **hot reload** turn on by default.
- Build the application uber-JAR and run so that it use JVM. You can build uber JAR using `./gradlew clean build -x test -Dquarkus.package.uber-jar=true` command and run builded JAR with `java -jar ./build/QuarkusSimpleAPI-1.0.0-SNAPSHOT-runner.jar`. I ommited tests because the only ones that I created are integration tests and applciation need to be up and running before. 
- Native build (using Docker) - I prepared docker configuration in order to simplify build process. You can use `./build_native.sh` script from QuarkusSimpleAPI project dir and then `./run_native.sh` script.
- Native (without docker). You need to install GrallVM and run `./gradlew clean build -Dquarkus.package.type=native` and you can run `QuarkusSimpleAPI-1.0.0-SNAPSHOT-runner` as normal application.

With Spring Boot project we have two options. You can simply run `./gradlew bootRun` or build JAR using `./gradlew build` command and then run it using: `java -jar ./build/SpringSimpleAPI-1.0.0-SNAPSHOT.jar`

**To run everything** you can use `docker-compose up` command in project root directory. It runs Quarkus app both in native and JVM mode, Spring Boot app and H2 in separate container.

**Remember** to setup connection address to H2 database in both projects property file. If you run projects not as docker containers please change `quarkus-vs-spring-h2` addres to `localhost`. 

If you run the applications, you will immediately see the difference in the start time of each version. But it's time to run deep dive into preformance tests :smirk:.
### Testing performance

1. To start with, the basic thing. Application launch time.
- Test conditions: I run applications one at a time in docker containers with the H2 container already running. Number of attempts: 
- Results:
- Plot: 


This is it! You can find all the source code in my repository [GitHub account](https://github.com/k0staa/Code-Addict-Repos/tree/master/). 
Have fun and thanks for reading!
