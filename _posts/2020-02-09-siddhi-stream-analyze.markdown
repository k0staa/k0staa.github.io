---
title:  "Analyzing data stream with Siddhi and Spring Boot 2"
excerpt: "How to create simple data analyzing application in Siddhi and use it with Spring Boot 2 app"
header:
  overlay_image: /assets/images/post_teaser.jpeg
  overlay_filter: 0.5 # same as adding an opacity of 0.5 to a black background
  caption: "Photo credit: [Markus Spiske](http://freeforcommercialuse.net)"
date:   2020-02-09 14:52:00 +0200
tags: spring-boot kotlin siddhi 
---
Analyzing a data stream to look up patterns is a popular thing this days. [Siddhi](https://siddhi.io/) is a very interesting and one of the easiest tools. 
The Siddhi package consists of an engine as well as a graphic editor. The engine can be used both as a embedded library and as a separately launched docker container. In Spring applications I recommend the latter option because I don't see a sensible way to use the library (unless we run the applications as `CommandLineRunner`)
To start with, let's create a simple application that will receive a POST request with a message and send it to the RabbitMQ queue and will receive information about alarms from another queue.
I use Kotlin everywhere to have some extra fun.

This is root project `build.gradle` file:
~~~
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

buildscript {
    repositories {
        jcenter()
    }
    dependencies {
        classpath("se.transmode.gradle:gradle-docker:1.2")
    }
}

plugins {
    java
    id("org.springframework.boot") version "2.2.4.RELEASE"
    id("io.spring.dependency-management") version "1.0.9.RELEASE"
    kotlin("jvm") version "1.3.61"
    kotlin("plugin.spring") version "1.3.61"
    application
    groovy
}
apply(plugin = "docker")

group = "pl.codeaddict"
version = "0.0.1-SNAPSHOT"
java.sourceCompatibility = JavaVersion.VERSION_1_8

repositories {
    mavenCentral()
    jcenter()
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-amqp")
    implementation("org.springframework.boot:spring-boot-starter-webflux")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-reactor")
    testImplementation("org.springframework.boot:spring-boot-starter-test") {
        exclude(group = "org.junit.vintage", module = "junit-vintage-engine")
    }
    testImplementation("io.projectreactor:reactor-test")
    testImplementation("org.springframework.amqp:spring-rabbit-test")
}

tasks.withType<Test> {
    useJUnitPlatform()
}

tasks.withType<KotlinCompile> {
    kotlinOptions {
        freeCompilerArgs = listOf("-Xjsr305=strict")
        jvmTarget = "1.8"
    }
}

application {
    mainClassName = "pl.codeaddict.siddhidemoclient.SiddhidemoclientApplicationKt"
}

configure<se.transmode.gradle.plugins.docker.DockerPluginExtension> {
    maintainer = "Michal Kostewicz <m.kostewicz84@gmail.com>"
    baseImage = "adoptopenjdk/openjdk8:alpine-slim"
}

tasks.register("copyJar",Copy::class){
    dependsOn("build")
    from(file("$buildDir/libs/siddhidemoclient-0.0.1-SNAPSHOT.jar"))
    into(file("$buildDir/docker"))
}

tasks.register("appDocker" ,se.transmode.gradle.plugins.docker.DockerTask::class) {
    dependsOn("copyJar")
    addFile("siddhidemoclient-0.0.1-SNAPSHOT.jar", "/")
    entryPoint(listOf("java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "/siddhidemoclient-0.0.1-SNAPSHOT.jar"))
}

~~~
Some things definitely need to be explained. 

First of all, I'm using the `se.transmode.gradle:gradle-docker:1.2` plugin that allows me to build a docker image for the application. That's why I created few custom code blocks: `configure`, `copyJar` task, `appDocker` task.  

Secondly, I'm using `spring-boot-starter-webflux` but to tell the truth it's not needed in this example and you can easily replace it with `spring-boot-starter-web`.

And the last important thing, I set the Kotlin code compilation to byte code compatible with Java 8 using `jvmTarget = "1.8"`.

In the application I added a simple configuration of the RabbitMQ messages queue:

~~~java
import org.springframework.amqp.core.Queue
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration

@Configuration
class RabbitMQConfig {
    @Value("\${siddhidemo.rabbitmq.messageQueue}")
    val messageQueue: String? = null

    @Bean
    fun queue(): Queue {
        return Queue(messageQueue, false);
    }
}
~~~
The class is very simple. As you can see, the queue name is parameterized in `application.yml`.
Now a simple service whose task is to send messages to a configured queue:
~~~java
import org.springframework.amqp.core.Queue
import org.springframework.amqp.rabbit.core.RabbitTemplate
import org.springframework.stereotype.Service


@Service
class RabbitMQSenderService(
        private val rabbitTemplate: RabbitTemplate,
        private val queue: Queue) {

    fun send(message: String) {
        rabbitTemplate.convertAndSend(queue.name, message);
        println(" [x] Sent '$message'");
    }
}
~~~
Let's move to the first controller whose task is to capture a POST request with a message and send to RabbitMQ through the service:
~~~java
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RestController

@RestController
class MessageQueueController(
        private val rabbitMQSender: RabbitMQSenderService) {

    @PostMapping(value = ["/messages"])
    fun addMessageToQueue(@RequestBody msg: String): String {
        rabbitMQSender.send(msg);
        return "Message sent to the RabbitMQ Successfully";
    }
}
~~~
And now the last part of the application, i.e. the service listening for the alarm queue and writing incoming messages to the console:
~~~java
import org.springframework.amqp.rabbit.annotation.Exchange
import org.springframework.amqp.rabbit.annotation.Queue
import org.springframework.amqp.rabbit.annotation.QueueBinding
import org.springframework.amqp.rabbit.annotation.RabbitListener
import org.springframework.stereotype.Component

@Component
class RabbitMQAlarmReceiver {

    @RabbitListener(bindings = [QueueBinding(value = Queue(value = "\${siddhidemo.rabbitmq.alertsQueue}", durable = "true"),
            exchange = Exchange(value = "\${siddhidemo.rabbitmq.alertsExchange}", durable = "false", ignoreDeclarationExceptions = "true"),
            key = ["\${siddhidemo.rabbitmq.alertsRoutingKey}"])]
    )
    fun receiver(`in`: String) {
        println(" [x] Received '$`in`'")
    }
}
~~~
Warning! Siddhi self doesn't have (or at least I didn't find anything like that) the possibility of creating queues, exchanges and binding them. This should be done either through the RabbitMQ configuration or, as in this class above, through the configurations in the application, except that the application must have appropriate privileges in RabbitMQ. In the configuration located in the annotation `@RabbitListener` we configure the queue, exchange, routing key and bind the whole thing together.

Let's have quick look at `application.yml`:
~~~yaml
siddhidemo.rabbitmq:
  messageQueue: 'messages'
  alertsQueue: 'alerts'
  alertsRoutingKey: 'alerts'
  alertsExchange: 'direct_alerts'
spring:
  rabbitmq:
    host: siddhi-demo-rabbit-mq
    port: 5672
    username: guest
    password: guest

logging.level.root: DEBUG
~~~
I don't think anything about the configuration should be discussed. It is worth mentioning that the RabbitMQ host name is prepared for the docker-compose configuration which I prepared in my project (see my [GitHub project](https://github.com/k0staa/Code-Addict-Repos/tree/master/siddhi-demo))

Ok, now it's time to create logic on the Siddhi side. In Siddhi we define the so-called applications in which we define the logic of stream analysis. We save the application in separate files with the extension `.siddhi`. Our example looks like that:
~~~
@App:name('SIMPLE_ALERT_FILTER')

@info(name = 'stream from messages queue')
@source(type ='rabbitmq',
uri = 'amqp://guest:guest@siddhi-demo-rabbit-mq:5672',
routing.key= 'messages',
exchange.name= 'direct',
queue.name= 'messages',
@map(type='json'))
define stream MessageStream (msg string);

@sink(type = 'log')
@sink(type ='rabbitmq',
uri = 'amqp://guest:guest@siddhi-demo-rabbit-mq:5672',
routing.key= 'alerts',
exchange.name= 'direct_alerts',
queue.name= 'alerts',
@map(type='json'))
define stream AlertStream (msg string, msg_count long);

@info(name = 'count messages that equals alert in batches in 30 seconds window')
from MessageStream#window.timeBatch(30 sec, 0, true)
select msg, count() as msg_count
group by msg
having msg_count > 3 and msg == "alert"
insert into AlertStream;
~~~
Let's discuss the code step by step. 

The first element is `@App`. This is the name of our application. It must be the same as the file name.

Next is the [source](https://siddhi.io/en/v5.1/docs/examples/source-and-sink/)  definition. So the source of our stream. In our case, source is the `messages` queue in RabbitMQ. The `@Info` element is optional and can be used to describe code elements. `@map` element is used to define how to convert the incoming event, there are few built-in types but in our case I use JSON because the sent event is in the form of JSON (I will write example message below).

Next is the [sink](https://siddhi.io/en/v5.1/docs/examples/source-and-sink/) definition. As the name suggests, it is a place where something flows down. In our case, it is a separate `alerts` queue to which the events specified in the query flow. As you can see there are two `@sink` definitions, one of which is simply used to log events to the console. 

The last fragment is the query itself, which checks whether in the message stream (`MessageStream`) for a 30-second time window there are more than 3 messages with the `alert` content and if so it inserts them to `AlertStream` (which is our sink).

To run the application you need docker images with Siddhi and RabbitMQ, I prepared [docker-compose in my GitHub repo](https://github.com/k0staa/Code-Addict-Repos/blob/master/siddhi-demo/docker/docker-compose.yml). If you cloned my project you just need to run:
~~~
./gradlew appDocker
cd /docker && docker-comose up
~~~
or just run `./gradlew bootRun` but check RabbitMQ configuration in `application.yml`.


Ok, let's try our code. To send a message to the application, you can use the `curl` or import the following code into Postman:
~~~
curl --location --request POST 'localhost:8080/messages' \
--header 'Content-Type: text/plain' \
--data-raw '{"msg": "just message"}'
~~~
Let's send any message other than `alert`(like the one above) and after some while send `alert` message more than three times duirng 30 second time window. When you look at application logs `docker logs siddhi-demo-app`, you should see that alert receiver print message:
~~~
 [x] Received '{"event":{"msg":"alert","msg_count":4}}'
~~~


This is it! You can find all the source code in my repository [GitHub account](https://github.com/k0staa/Code-Addict-Repos/tree/master/siddhi-demo). 
Have fun and thanks for reading!
