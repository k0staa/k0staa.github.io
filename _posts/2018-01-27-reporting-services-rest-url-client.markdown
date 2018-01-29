---
title:  "Microsoft Reporting Services URL client using Spring Boot 1.5 RestTemplate with NTLM authentication."
excerpt: "How to download report from Microsoft Reporting Services using URL request. Configuring Spring RestTemplate with NTLM authentication."
header:
  overlay_image: /assets/images/post_teaser.jpeg
  overlay_filter: 0.5 # same as adding an opacity of 0.5 to a black background
  caption: "Photo credit: [Markus Spiske](http://freeforcommercialuse.net)"
date:   2018-01-27 10:00:00 +0200
tags: spring spring-boot reporting-services rest
---
  Reporting Services is a Microsoft technology and it is very difficult to find valuable instructions for connecting to an application written in Java. If we write applications in Java, there are two ways to integrate it with Reporting Services:
 - First using a URL query.
 - Second using SOAP Web Service (I will explain this method in future post).

In this post I will describe first (simpler) method. Using this method, you can connect to almost every version of Reporting Services but it must be configured beforehand (in particular, [Web Service URL Configuration](https://docs.microsoft.com/en-us/sql/reporting-services/install-windows/configure-a-url-ssrs-configuration-manager)). 

To create an application I use Spring Boot version 1.5 and Apache HTTP Components library to configure the appropriate HTTP client with NTLM authentication (default authentication in Reporting Services)

I have my application builded with Maven. This is the whole `pom.xml` file:
~~~ xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
	<modelVersion>4.0.0</modelVersion>

	<groupId>com.example</groupId>
	<artifactId>reporting-services</artifactId>
	<version>0.0.1-SNAPSHOT</version>
	<packaging>jar</packaging>

	<name>reporting-services</name>
	<description>Demo project for Spring Boot</description>

	<parent>
		<groupId>org.springframework.boot</groupId>
		<artifactId>spring-boot-starter-parent</artifactId>
		<version>1.5.9.RELEASE</version>
		<relativePath/> <!-- lookup parent from repository -->
	</parent>

	<properties>
		<project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
		<project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
		<java.version>1.8</java.version>
	</properties>

	<dependencies>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-web</artifactId>
		</dependency>

		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-test</artifactId>
			<scope>test</scope>
		</dependency>

		<dependency>
			<groupId>org.apache.httpcomponents</groupId>
			<artifactId>httpclient</artifactId>
			<version>4.5.3</version>
		</dependency>

		<dependency>
			<groupId>org.projectlombok</groupId>
			<artifactId>lombok</artifactId>
			<version>1.16.20</version>
			<scope>provided</scope>
		</dependency>
	</dependencies>

	<build>
		<plugins>
			<plugin>
				<groupId>org.springframework.boot</groupId>
				<artifactId>spring-boot-maven-plugin</artifactId>
			</plugin>
		</plugins>
	</build>
    
</project>

~~~

As you can see I added just `org.apache.httpcomponents.httpclient` and `org.projectlombok.lombok` (you can omit the lombok because I used it to simplify logging).
Now let's create REST Template configuration (with NTLM authentication configuration):
~~~ java
import org.apache.http.auth.AuthScope;
import org.apache.http.auth.NTCredentials;
import org.apache.http.client.CredentialsProvider;
import org.apache.http.impl.client.BasicCredentialsProvider;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClientBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;

@Configuration
public class ReportingServicesHTTPClientConfiguration {

    @Bean
    public RestTemplate restTemplate() {
        RestTemplate template = new RestTemplate();
        HttpComponentsClientHttpRequestFactory requestFactory = new
                HttpComponentsClientHttpRequestFactory(httpClient());
        template.setRequestFactory(requestFactory);

        return template;
    }

    @Bean
    public CloseableHttpClient httpClient() {
        String user = "UserName";
        String password = "userPass";
        String domain = "USER_DOMAIN";
        CredentialsProvider credentialsProvider = new BasicCredentialsProvider();
        credentialsProvider.setCredentials(AuthScope.ANY,
                new NTCredentials(user, password, null, domain));

        CloseableHttpClient httpclient = HttpClientBuilder
                .create()
                .setDefaultCredentialsProvider(credentialsProvider)
                .build();
        return httpclient;
    }
}
~~~
Configuration is quite simple. The most important element is to configure NTLM authentication. I noticed that the 3rd parameter of the NTCredentials class is unnecessary, but look at the documentation of the class because maybe in your case it should be set.

Now we can create simple client to make connection to Reporting Services.
~~~ java
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

@Component
public class ReportingServicesClient {
    private static String FORMAT_URL_PART = "&rs:Format=";
    private static String REPORTING_SERVICES_URL =
            "http://ReportingServicesDomainOrUrl/ConfiguredUrl?";
    @Autowired
    private RestTemplate restTemplate;


    public byte[] getReport(String reportName, String reportFormat) {
        HttpEntity<String> requestEntity = new HttpEntity<>(null, null);
        String reportURL = REPORTING_SERVICES_URL + reportName + FORMAT_URL_PART + reportFormat;
        ResponseEntity<byte[]> responseEntity = restTemplate.exchange(reportURL, HttpMethod.GET,
                requestEntity, byte[].class);
        return responseEntity.getBody();
    }
}

~~~
As shown on listing the only required thing here is to setup proper reporting Services URL (configured in Reporting Services configuration). I pass report name and report format parameters to method which return report as byte array.

I create simple unit test to test client connection.
~~~ java
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.junit4.SpringRunner;

import static org.junit.Assert.*;

@RunWith(SpringRunner.class)
@SpringBootTest
public class ReportingServicesClientTest {
    @Autowired
    private ReportingServicesClient reportingServicesClient;

    @Test
    public void getReport_givenSimpleReportName_returnReportByteArray() throws Exception {
        //given
        String reportNamePath = "/RaportTestowy/Departments";
        String reportFormat = "PDF";

        //when
        byte[] reportByteArray = reportingServicesClient.getReport(reportNamePath, reportFormat);

        //then
        assertTrue(reportByteArray.length > 0);
    }
}
~~~
You can find whole project in my [GitHub account](https://github.com/k0staa/Code-Addict-Repos/tree/master/reporting-services)
 This is it! You should now be able to send requests to Reporting Services and receive reports. Thanks for reading!

