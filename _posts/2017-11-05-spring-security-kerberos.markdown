---
title:  "SSO in Spring Boot using Kerberos authentication in Microsoft Active Directory"
excerpt: "How to configure Active Directory and Linux to perform single sign on authentication using Spring Security with Kerberos protocol. Step by step instructions and possible problems."
header:
  overlay_image: /assets/images/post_teaser.jpeg
  overlay_filter: 0.5 # same as adding an opacity of 0.5 to a black background
  caption: "Photo credit: [Markus Spiske](http://freeforcommercialuse.net)"
date:   2017-11-05 17:23:00 +0200
tags: spring security ldap active-directory spring-boot sso
---

Let's say we have web application running in intranet on some simple server container which is running on Linux machine (I'm using CentOS 7.4 in this example) and we want to have our users logged in if they are already logged in
their Windows machines. Better to picture this:

![Network and hardware architecture used in this post ]({{ site.url }}/assets/images/kerberos.png)



There is a Spring documentation about this topic ([https://docs.spring.io](https://docs.spring.io/spring-security-kerberos/docs/1.0.2.BUILD-SNAPSHOT/reference/htmlsingle/)) but I was forced to take few steps during configuration which are not described and I encountered few problems which I want to share with you. **At the beginning, I assume that computers must obviously be visible to each other in the network!**
When creating an example configuration I used JDK 8 and the following dependencies:
~~~ xml
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>1.5.3.RELEASE</version>
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
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-ldap</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.security.kerberos</groupId>
            <artifactId>spring-security-kerberos-web</artifactId>
            <version>1.0.1.RELEASE</version>
        </dependency>
		<!--Lombok dependency it's used only to allow logging annotations in this example-->
       <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
        </dependency>
    </dependencies>
~~~

## Step one - Windows Domain Server
The steps that must be taken at this point must be performed when logged on to a Windows server running Active Directory service containing user data of our application.
First I created user account in Active Directory which will be used by application to authenticate. To do this you need click **Start**, point to **Programs**, point to **Administrative Tools**, and then click **Active Directory Users and Computers** (you can follow instructions from [MSDN](https://msdn.microsoft.com/en-us/library/aa545262(v=cs.70).aspx)).
In my case example username is `tomcat`. I set a password to newly created user and I unchecked option which force user to change his password on first logon. After creating the user, open terminal and execute the following commands:

~~~ sh
setspn -A HTTP/applicationhost@YOURDOMAIN.COM tomcat
~~~

...where `applicationhost@YOURDOMAIN.COM` is the address (host name) and domain where our application resides and `tomcat` is user that you created in previous step. This is an important point and it is important that this is consistent with the address of our application and subsequent configuration steps. **NOTE: You can not use IP, it must be a host/domain name of application server computer**.
In case of when our web application does not have a domain name yet (in DNS), we should at least assign host name to server IP on any machine which is connecting to it by editing `hosts` file. On Windows it's `C:\Windows\System32\drivers\etc\hosts` file. On Linux system it's `/etc/hosts` file. Another command is used to create the necessary file which contains Kerberos keys:

~~~ sh
ktpass /out c:\tomcat.keytab /mapuser tomcat@YOURDOMAIN.COM /princ HTTP/applicationhost@YOURDOMAIN.COM /pass TomcatUserFunnyPassword /ptype KRB5_NT_PRINCIPAL /crypto All
~~~

where `tomcat@YOURDOMAIN.COM` is the user that we created at the beginning, `YOURDOMAIN.COM` is the domain in which this user was created in, `/princ HTTP/applicationhost@YOURDOMAIN.COM` must match what we provide in the first command. The password (string after `/pass`) must match the `tomcat` user's password that we set up when we create it in the first place.
If command end up successfull it will generate a file (`c:\tomcat.keytab`) that must be placed in a folder already available from the application (from the application server), I will explain that in next section.

## Step two - preparing the application server side (Linux system)
In case the application server is on Windows it is sufficient to just copy `tomcat.keytab` file created in accordance with the instructions from the first step to path available by the server (eg.: `c:\`) and configure the path in the application configuration (as described in Step Three), and that should suffice.
However, if your application is on Linux sometimes you need to tweak your system configuration. This was the case with my CentOS 7.4 system. Anyway you should first try to copy the `tomcat.keytab` file to the `/opt/tomcat.keytab` directory (or whatever else you set up later in the application configuration) and configure application security config (as described in step three) and try it without taking extra steps described below and only If that fails please follow them.

As I wrote, if the steps above fail you should follow steps below. Some steps labeled ,,Required for manual connection'' are not required, however, they could help detect a potential error:
  - Install a package that allow to log in to Active Directory using Kerberos: `yum install cyrus-sasl-gssapi` ,
  - If the AD server does not have a DNS name in the network then edit `/etc/hosts` file and add the line with host name corresponding to the IP of the Active Directory server: `192.168.1.201 activedirectoryserverhostname` (in my case server has IP `192.168.1.201`) ,
  - (Required for manual connection) To run the connection tests from the terminal level, install the package: `yum install krb5-workstation`
  - (Required for manual connection) Replace the default Kerberos configuration file found in `/etc/krb5.conf` as follows:

~~~ sh
[libdefaults]
default_realm = YOURDOMAIN.COM
default_keytab_name = /opt/tomcat.keytab
forwardable=true

[realms]
SWDP.PL = {
  kdc = applicationhost.YOURDOMAIN.COM:88
}

[domain_realm]
swdp.pl=YOURDOMAIN.COM
.swdp.pl=YOURDOMAIN.COM
~~~

   - (Required for manual connection) To test connection to AD server, you need to load the keytab file with the command: `kinit -kt /opt/tomcat.keytab HTTP/applicationhost@YOURDOMAIN.COM`, then you can check with `klist` command that key is properly loaded. Executing the `klist` command should write something like this:

~~~ sh
Default principal: HTTP/applicationhost@YOURDOMAIN.COM

Valid starting       Expires              Service principal
10/23/2017 15:48:31  10/24/2017 01:48:31  krbtgt/YOURDOMAIN.COM@YOURDOMAIN.COM
        renew until 10/24/2017 15:48:31
~~~

   - (Required for manual connection) Once the keys have been loaded, you can perform a trial connection, for example:

~~~ sh
ldapwhoami -Y GSS-SPNEGO -v -h activedirectoryserverhostname -v

# OR

ldapsearch -Y GSS-SPNEGO -H ldap://activedirectoryserverhostname -b "dc = YOURDOMAIN, dc = com "
~~~

 Commands should end successfully. The address `activedirectoryserverhostname` is the host name of the Active Directory server obtained from hosts file or DNS server.

## Step three - Spring Security configruation
__UPDATED 2018-09-02__ Below is the configuration of Spring Security. Pay attention to the comments because there are the most important information:

~~~ java
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.FileSystemResource;
import org.springframework.security.config.annotation.authentication.builders.AuthenticationManagerBuilder;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.WebSecurityConfigurerAdapter;
import org.springframework.security.config.annotation.web.servlet.configuration.EnableWebMvcSecurity;
import org.springframework.security.kerberos.authentication.KerberosAuthenticationProvider;
import org.springframework.security.kerberos.authentication.KerberosServiceAuthenticationProvider;
import org.springframework.security.kerberos.authentication.sun.SunJaasKerberosClient;
import org.springframework.security.kerberos.authentication.sun.SunJaasKerberosTicketValidator;
import org.springframework.security.kerberos.web.authentication.SpnegoAuthenticationProcessingFilter;
import org.springframework.security.kerberos.web.authentication.SpnegoEntryPoint;
import org.springframework.security.web.authentication.www.BasicAuthenticationFilter;
import org.springframework.util.Assert;

@Slf4j //Lombok annotation for logging
@Configuration
@EnableWebMvcSecurity
public class WebSecurityConfiguration extends WebSecurityConfigurerAdapter {

    @Value("${security.keytab.file}")
    private String keytabFilePath;

    @Value("${security.service.principal}")
    private String servicePrincipal;


    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
                .exceptionHandling()
                .authenticationEntryPoint(spnegoEntryPoint())
                .and()
                .authorizeRequests()
                .anyRequest().authenticated()
                .and()
                .formLogin()
                .and()
                .logout()
                .permitAll()
                .and()
                .addFilterBefore(
                        spnegoAuthenticationProcessingFilter(),
                        BasicAuthenticationFilter.class);
    }

    @Override
    public void configure(AuthenticationManagerBuilder auth) throws Exception {
        auth
                .authenticationProvider(kerberosAuthenticationProvider())
                .authenticationProvider(kerberosServiceAuthenticationProvider());
    }

    @Bean
    public KerberosAuthenticationProvider kerberosAuthenticationProvider() {
        KerberosAuthenticationProvider provider =
                new KerberosAuthenticationProvider();
        SunJaasKerberosClient client = new SunJaasKerberosClient();
        client.setDebug(true);
        provider.setKerberosClient(client);
        provider.setUserDetailsService(dummyUserDetailsService());
        return provider;
    }

    @Bean
    public SpnegoEntryPoint spnegoEntryPoint() {
        return new SpnegoEntryPoint("/");
    }

    @Bean
    public SpnegoAuthenticationProcessingFilter spnegoAuthenticationProcessingFilter() {
        SpnegoAuthenticationProcessingFilter filter =
                new SpnegoAuthenticationProcessingFilter();
        try {
            filter.setAuthenticationManager(authenticationManagerBean());
        } catch (Exception e) {
            log.error("Failed to set AuthenticationManager on SpnegoAuthenticationProcessingFilter.", e);
        }
        return filter;
    }

    @Bean
    public KerberosServiceAuthenticationProvider kerberosServiceAuthenticationProvider() {
        KerberosServiceAuthenticationProvider provider =
                new KerberosServiceAuthenticationProvider();
        provider.setTicketValidator(sunJaasKerberosTicketValidator());
        provider.setUserDetailsService(dummyUserDetailsService());
        return provider;
    }

    @Bean
    public SunJaasKerberosTicketValidator sunJaasKerberosTicketValidator() {
        SunJaasKerberosTicketValidator ticketValidator =
                new SunJaasKerberosTicketValidator();
        ticketValidator.setServicePrincipal(servicePrincipal); //At this point, it must be according to what we were given in the
        // commands from the first step.
        FileSystemResource fs = new FileSystemResource(keytabFilePath); //Path to file tomcat.keytab
        log.info("Initializing Kerberos KEYTAB file path:" + fs.getFilename() + " for principal: " + servicePrincipal + "file exist: " + fs.exists());
        Assert.notNull(fs.exists(), "*.keytab key must exist. Without that security is useless.");
        ticketValidator.setKeyTabLocation(fs);
        ticketValidator.setDebug(true); //Turn off when it will works properly,
        return ticketValidator;
    }

    @Bean
    public DummyUserDetailsService dummyUserDetailsService() {
        return new DummyUserDetailsService();
    }
}
~~~
__UPDATED 2018-09-02__
The `application.properties` file with the parameters used in `WebSecurityConfiguration.class`:

~~~ bash
security.basic.enabled=false
security.keytab.file=/opt/tomcat.keytab
security.service.principal=HTTP/applicationhost@YOURDOMAIN.COM
server.port = 8080
~~~

Below is a simple class needed to load detailed user data. The class is mock but you can use it and then extend. In real life example we would be probably reading information about user groups from Active Directory or database.
~~~ java
@Slf4j //Lombok annotation for logging
public class DummyUserDetailsService implements UserDetailsService {

    @Override
    public UserDetails loadUserByUsername(String username)
            throws UsernameNotFoundException {
        log.info(username);
        return new User(username, "notUsed", true, true, true, true,
                AuthorityUtils.createAuthorityList("ROLE_USER", "ROLE_ADMIN"));
    }
}
~~~

## Troubleshooting
The protocol is quite irritating on some issues, and it is very important to go through these steps carefully to properly prepare the authentication. Here are some errors you might encounter:
1. Please note that the `tomcat.keytab` file was loaded during the initialization of the security configuration because its failure causes errors where the messages do not tell us much.
2. Excessive time difference (greater than 5 minutes) between the server on which the application is running and the AD server may cause an error:
~~~ java
 Failure unspecified at GSS-API level (Mechanism level: Clock skew too great (37)) .
~~~
The solution may be to synchronize the machine time on which the application server is running with the AD server (for example using [NTP](https://en.wikipedia.org/wiki/Network_Time_Protocol)).
3. Please note that the host / domain address on which the application is running is consistent with the configuration and whether or not it is actually used when accessing the application (and not IP for example).
4. Be sure to install the `cyrus-sasl-gsasapi` package because when it's missing Kerberos communicate lack of authentication managers.

## Summary
That's it! You should be now automatically logged in to your application using Active Directory. Thanks for reading!

## UPDATE 2018-09-02
Many people have asked me so I've added a simple project to [GitHub](https://github.com/k0staa/Code-Addict-Repos/tree/master/active-directory)
