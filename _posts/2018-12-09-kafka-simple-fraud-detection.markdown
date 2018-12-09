---
title:  "Using Kafka Streams to search for suspicious traffic in log stream. "
excerpt: "Searching for strange traffic in the log stream using Kafka streams. Joining of data streams and saving it in MongoDB. Data streaming from MongoDB with the help of Spring WebFlux. Everything written in Kotlin."
header:
  overlay_image: /assets/images/post_teaser.jpeg
  overlay_filter: 0.5 # same as adding an opacity of 0.5 to a black background
  caption: "Photo credit: [Markus Spiske](http://freeforcommercialuse.net)"
date:   2018-06-10 12:35:00 +0200
tags: kafka streams kotlin webflux docker
---

Detection of various anomalies in the data stream is a very common business need these days. Applications are often used by many users and thus generate a large amount of data.

As part of the entertainment, I decided to create a tool that will detect specific requests (let's assume that they are potentially dangerous) in the log stream, and also combine different types of logs in the time window to provide more data. The application will save such search results in a MongoDB database, and also enable the display of this data through the REST controller. As I have never written anything in the Kotlin, I decided that the project will be written in this language.

The Kafka and MongoDB instances are both needed to run the project, so for ease of use I have put the appropriate configurations for `docker-compose` in the `docker` directory. Just enter the directory and run `docker-compose up`.

This time I use Gradle as building tool. This is my `gradle.build` file:

~~~ 
buildscript {
	ext {
		kotlinVersion = '1.2.51'
		springBootVersion = '2.0.6.RELEASE'
	}
	repositories {
		mavenCentral()
	}
	dependencies {
		classpath("org.springframework.boot:spring-boot-gradle-plugin:${springBootVersion}")
		classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:${kotlinVersion}")
		classpath("org.jetbrains.kotlin:kotlin-allopen:${kotlinVersion}")
	}
}

apply plugin: 'kotlin'
apply plugin: 'kotlin-spring'
apply plugin: 'eclipse'
apply plugin: 'org.springframework.boot'
apply plugin: 'io.spring.dependency-management'

group = 'pl.codeaddict'
version = '0.0.1-SNAPSHOT'
sourceCompatibility = 1.8
compileKotlin {
	kotlinOptions {
		freeCompilerArgs = ["-Xjsr305=strict"]
		jvmTarget = "1.8"
	}
}
compileTestKotlin {
	kotlinOptions {
		freeCompilerArgs = ["-Xjsr305=strict"]
		jvmTarget = "1.8"
	}
}

repositories {
	mavenCentral()
}

dependencies {
	implementation('org.springframework.boot:spring-boot-starter-data-mongodb-reactive')
	implementation('org.springframework.boot:spring-boot-starter-webflux')
	implementation('org.springframework.kafka:spring-kafka')
	implementation('io.projectreactor.kafka:reactor-kafka')
	implementation('com.fasterxml.jackson.module:jackson-module-kotlin')
	implementation('org.apache.kafka:kafka-streams')
	implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
	implementation("org.jetbrains.kotlin:kotlin-reflect")
	testImplementation('org.springframework.boot:spring-boot-starter-test')
	testImplementation('io.projectreactor:reactor-test')
}

~~~

As you can see I use Spring Boot 2.0.6 RELEASE version and I added MongoDB, Spring WebFlux, Kafka and Kafka reactor libraries. Kafka reactor library is only needed when you want to use reactive streams with Kafka (simple example use is `KafkaReciever` in `KafkaDemoController`).

The application itself consists mainly of configuration, producer and streams processing. For the needs of the application, I had to create a log producer, but it should be assumed that in the actual application the producer will be some other application or several applications at once which sends data directly or indirectly to Kafka.

I will omit the producer's configuration (whole project is on my GitHub. Link at the bottom of the page). Let's take a look at the configurations of the consumer and Kafka streams:

~~~ kotlin

@Configuration
class KafkaConsumerConfig {
    @Value("\${delivery-stats.stream.threads:1}")
    private val threads: Int = 1

    @Value("\${delivery-stats.kafka.replication-factor:1}")
    private val replicationFactor: Int = 1

    @Value("\${messaging.kafka-dp.brokers.url:localhost:9092}")
    private val brokersUrl: String? = null

    @Bean
    fun consumerProps(): HashMap<String, Any> {
        val props = HashMap<String, Any>()
        props[ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG] = brokersUrl as String
        props[ConsumerConfig.GROUP_ID_CONFIG] = "fraudDetectionGroup"
        props[ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG] = StringDeserializer::class.java
        props[JsonDeserializer.VALUE_DEFAULT_TYPE] = FraudData::class.java
        props[ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG] = JsonDeserializer(FraudData::class.java).javaClass
        return props
    }

    @Bean
    fun kafkaConsumer(): KafkaConsumer<String, FraudData> {
        val consumer: KafkaConsumer<String, FraudData> = KafkaConsumer(consumerProps())
        consumer.subscribe(arrayListOf(Topics.FRAUD.name))
        return consumer
    }

    @Bean
    fun kafkaReceiver(): KafkaReceiver<String,FraudData> {
        val receiverOptions: ReceiverOptions<String, FraudData> = ReceiverOptions.create(consumerProps())
        receiverOptions.subscription(Collections.singleton(Topics.FRAUD.name))
        return KafkaReceiver.create(receiverOptions)
    }

    @Bean(name = arrayOf(KafkaStreamsDefaultConfiguration.DEFAULT_STREAMS_CONFIG_BEAN_NAME))
    fun kStreamsConfigs(): StreamsConfig {
        val props = HashMap<String, Any>()
        props[StreamsConfig.APPLICATION_ID_CONFIG] = "test-streams"
        props[StreamsConfig.BOOTSTRAP_SERVERS_CONFIG] = brokersUrl as String
        props[StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG] = Serdes.String().javaClass
        props[StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG] = JsonSerde(ProxyData::class.java).javaClass
        props[JsonDeserializer.DEFAULT_KEY_TYPE] = String::class.java
        props[JsonDeserializer.DEFAULT_VALUE_TYPE] = ProxyData::class.java
        return StreamsConfig(props)
    }
}

~~~

The `consumerProps()` method is required by `KafkaConsumer` and `KafkaReveiver` which both have the same task - to read Kafka's topics, but the latter does it in a reactive way. 
The configuration of the `KafkaConsumer` and `KafkaReceiver` (`fun kafkaConsumer()`, `fun kafkaReceiver()`) it is left for testing purposes only because I do not send detected data to another topic (you can change that in `KafkaStreamConsumer` class). I left it if someone wanted to play with this and send data detected by the application to another Kafka topic and then pull it with the `KafkaConsumer` or `KafkaReciver`. 
The most important in this class is the stream configuration which you can find in `kStreamsConfig()` method. You can really add a lot of parameters there but in my case these are only the most important, i.e. `BOOTSTRAP_SERVERS_CONFIG` which is address of Kafka running on my local docker. The `DEFAULT_KEY_*` and `DEFAULT_VALUE_*` parameters mean the default data types that the stream operates on but it can be configured also later when connecting to different topics.

Let's take a look at the producer whose only task is to send up to two topics the standard logs for a given topic, and from time to time a row with suspicious data:

~~~ kotlin
@Service
class KafkaMessageProducer {
    private val PROXY_LOG: String = "{\"rt\": 1504812385296, \"src\": \"192.168.100.252\"," +
            " \"dst\": \"192.168.100.180\",\"request\": \"http://example.com/lorem/ipsum/A!sCDn\"}"
    private val PROXY_STRANGE: String = "{\"rt\": 1504812385296, \"src\": \"192.168.100.174\"," +
            " \"dst\": \"192.168.100.252\",\"request\": \"http://strange.com\"}"
    private val DHCP_LOG: String = "{\"rt\": 1504785607870, \"smac\": \"AB:E9:24:26:6C:1C\"," +
            " \"shost\":\"station6.workstation.bank.pl\",\"src\": \"192.168.100.252\"}"
    private val DHCP_STRANGE: String = "{\"rt\": 1504785607870, \"smac\": \"AB:E9:24:26:6C:1X\", " +
            "\"shost\":\"station666.workstation.bank.pl\", \"src\": \"192.168.100.174\"}"

    @Autowired
    private val kafkaTemplate: KafkaTemplate<String, String>? = null

    fun sendMessage(msg: String, topic: String) {
        kafkaTemplate!!.send(topic, msg)
    }

    @Scheduled(fixedRate = 5000)
    fun sendDhcpLogMessage() {
        sendMessage(DHCP_LOG, Topics.DHCP.name)
    }

    @Scheduled(fixedRate = 10000)
    fun sendStrangeDhcpLogMessage() {
        sendMessage(DHCP_STRANGE, Topics.DHCP.name)
    }

    @Scheduled(fixedRate = 10000)
    fun sendStrangeProxyLogMessage() {
        sendMessage(PROXY_STRANGE, Topics.PROXY.name)
    }

    @Scheduled(fixedRate = 5000)
    fun sendProxyLogMessage() {
        sendMessage(PROXY_LOG, Topics.PROXY.name)
    }
}

~~~

I think the code in this case is rather simple and does not require any detailed explanation.
We can probably go to the main part of the application that handles the data stream from the topics to which the producer sends:

~~~ kotlin

@Service
class KafkaStreamConsumer {
    @Autowired
    var mongoTemplate: MongoTemplate? = null

    @Bean("kafkaStreamProcessing")
    fun startProcessing(builder: StreamsBuilder): KStream<String, ProxyData>? {
        val dhcpStream = builder.stream(Topics.DHCP.name, Consumed.with(Serdes.String(),
                JsonSerde(DhcpData::class.java)))
                .map<String, DhcpData>(DhcpKeyValueMapper())

        val proxyStream = builder.stream(Topics.PROXY.name, Consumed.with(Serdes.String(),
                JsonSerde(ProxyData::class.java)))
                .map<String, ProxyData>(ProxyKeyValueMapper())
        val timeNow = LocalDateTime.now().format(DateTimeFormatter.ISO_DATE_TIME)
        val innerJoin = proxyStream.join(dhcpStream, { proxy, dhcp -> FraudData(dhcp, proxy, timeNow) },
                JoinWindows.of(5000)
                , Serdes.String(), JsonSerde(ProxyData::class.java), JsonSerde(DhcpData::class.java))
                .filter({ _, value -> value.proxyData!!.request == "http://strange.com" })

        innerJoin.foreach { key, value ->  mongoTemplate!!.save(value)}

        // I use mongoDB in this example but you can push result to another Kafka topic.
        //innerJoin.to(Topics.FRAUD.name)
        return proxyStream
    }

    class ProxyKeyValueMapper : KeyValueMapper<String, ProxyData, KeyValue<String, ProxyData>> {
        override fun apply(key: String?, value: ProxyData): KeyValue<String, ProxyData> {
            return KeyValue<String, ProxyData>(value.src, value)
        }
    }

    class DhcpKeyValueMapper : KeyValueMapper<String, DhcpData, KeyValue<String, DhcpData>> {
        override fun apply(key: String?, value: DhcpData): KeyValue<String, DhcpData> {
            return KeyValue<String, DhcpData>(value.src, value)
        }
    }
}

~~~

In the `startProcessing()` method, we first create two streams (`dhcpStream` and `proxyStream`), and then combine them into one stream working in the time window (5000 ms) which has `FraudData` type and finally is filtered out using request address. In this simple case, suspicious data has the request address "http://strange.com". The `join` method links streams with their keys which in this case are source machine IP addresse (see` ProxyKeyValueMapper` and `DhcpKeyValueMapper` which maps data pulled from topic to key, value map). Finally, the data is saved in mongoDB.

The data stored in mongoDB as suspicious can be seen by calling adrees [http://localhost:8080/mongo/frauds/stream](http://localhost:8080/mongo/frauds/stream). The controller supporting this request is shown below. It works with HTML 5 Server-Sent events technology:

~~~ ktolin
@RestController
class KafkaDemoController {
    @Autowired
    val kafkaStreamConsumer: KafkaConsumer<String, FraudData>? = null
    @Autowired
    val kafkaReactorReceiver: KafkaReceiver<String, FraudData>? = null
    @Autowired
    val fraudDataRepository: FraudDataRepository? = null
    @Autowired
    var mongoTemplate: MongoTemplate? = null

    /*Just for testing. Polling data straight from Kafka is probably not a good idea.*/
    @GetMapping("/kafka/poll")
    fun streamConsumer(): String? {
        return kafkaStreamConsumer?.poll(100)
                ?.map { record -> record.value() }?.joinToString(separator = "\n\n")
    }

    @GetMapping("/kafka-reactor/frauds/stream", produces = arrayOf(MediaType.TEXT_EVENT_STREAM_VALUE))
    fun streamReceiver(): Flux<FraudData>? {
        return kafkaReactorReceiver?.receiveAtmostOnce()?.map { record -> record.value() }
    }


    @GetMapping(value = "/mongo/frauds/all")
    fun dataFromMongo(): Flux<FraudData> {
        return fraudDataRepository!!.findAll()
    }

    @GetMapping(value = "/mongo/frauds/stream", produces = arrayOf(MediaType.TEXT_EVENT_STREAM_VALUE))
    @ResponseBody
    fun streamFromMongo(): Flux<FraudData> {
        return fraudDataRepository!!.findWithTailableCursorBy()
                .delayElements(Duration.ofMillis(2500))
    }
}

~~~

If you want to use `streamReceiver()` controller please switch from writing data to mongoDB to send it to the another specific topic (see `KafkaStreamConsumer` and my previous mention of it).


This is it! You can find all the source code in my repository [GitHub account](https://github.com/k0staa/Code-Addict-Repos/tree/master/kafka-demo). 

Have fun and thanks for reading!

