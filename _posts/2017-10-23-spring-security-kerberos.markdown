---
title:  "Single Sign On (SSO) on Spring Boot application running on Linux machine using Kerberos authentification on Microsoft Active Directory."
excerpt: "How to configure Active Directory and Linux to perform authentication using Spring Security Kerberos. Step by step instructions and possible problems."
header:
  overlay_image: /assets/images/post_teaser.jpeg
  overlay_filter: 0.5 # same as adding an opacity of 0.5 to a black background
  caption: "Photo credit: [Markus Spiske](http://freeforcommercialuse.net)"
date:   2017-07-18 20:29:53 +0200
tags: spring security ldap active-directory spring-boot
---

Let's say we have web application running in intranet on some simple server container which is running on Linux machine (I'm using CentOS 7.4 in this example) and we want to have our users logged in if they are already logged in 
their Windows machines. Better to picture this:




There is a Spring documentation about this topic (https://docs.spring.io/spring-security-kerberos/docs/1.0.2.BUILD-SNAPSHOT/reference/htmlsingle/) but I was forced to take few steps during configuration which are not described and I encountered many problems which I want to share with you.
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
First I creating user account in Active Directory which will be used by application to authenticate. To do this you need click **Start**, point to **Programs**, point to **Administrative Tools**, and then click **Active Directory Users and Computers** (you can follow this instructions https://msdn.microsoft.com/en-us/library/aa545262(v=cs.70).aspx). 
In my example username is `tomcat`. I set a password to newly created user and I unchecked option which force user to change his password on first logon. After creating the user, execute the following terminal commands (I used PowerShell):

~~~ sh
setspn -A HTTP/applicationhost@YOURDOMAIN.COM tomcat
~~~

where applicationhost@YOURDOMAIN.COM is the address and domain where our application resides. This is an important point and it is important that this is consistent with the address of our application and subsequent configuration steps. NOTE: You can not use IP, it must be a host/domain name of application server computer.
In case of when an application server computer does not have a domain yet, we can assign it itself on any machine which is connecting to it by editing `hosts` file. On Windows it's `C:\Windows\System32\drivers\etc\hosts` file. On Linux system it's `/etc/hosts`. Another command is to create the necessary file which contains Kerberos keys:

~~~ sh
ktpass /out c:\tomcat.keytab /mapuser tomcat@YOURDOMAIN.COM /princ HTTP/applicationhost@YOURDOMAIN.COM /pass TomcatUserFunnyPassword /ptype KRB5_NT_PRINCIPAL /crypto All
~~~

where `tomcat@YOURDOMAIN.COM` is the user that we created at the beginning, `YOURDOMAIN.COM` is the domain in which this user was created in, `/princ HTTP/applicationhost@YOURDOMAIN.COM` must match what we provide in the first command. The password (string after `/pass`) must match the `tomcat` user's password that we set up when we create it in the first place.
If command end up successfull it will generate a file (`c:\tomcat.keytab`) that must be placed in a folder already available from the application (from the application server), I will explain that in next section.

## Step two - preparing the application server side (Linux system)
In case the application server is on Windows it is sufficient to configure the path in the application configuration to the `tomcat.keytab` file (described in the section below), and that should suffice. However, if your application is on Linux sometimes you need more system configuration. This was the case with my CentOS 7.4 system. Anyway you should first try to configure application security config and try it without taking the following steps but If that fails please follow this steps:
 > First, copy the `tomcat.keytab` file created in accordance with the instructions from the first section to the `/opt/tomcat.keytab` directory (or whatever else you set up later in the application configuration),
 > You also need to install a package that will allow you to properly log in to Active Directory using Kerberos and created `tomcat.keytab` file: `yum install cyrus-sasl-gssapi` ,
 > To the `/etc/hosts` file I added a domain name corresponding to the IP of the Active Directory server: `192.168.1.201 activedirectoryserverhostname` ,
 > (Required for manual connection testing only) To run the connection tests from the terminal level, install the package: yum install krb5-workstation
 > (Required for manual connection testing only) I have replaced the default Kerberos configuration file found in `/etc/krb5.conf` as follows:
~~~ sh
[libdefaults]
default_realm = SWDP.PL
default_keytab_name = /opt/tomcat.keytab
forwardable=true

[realms]
SWDP.PL = {
  kdc = srvpcsivm566.SWDP.PL:88
}

[domain_realm]
swdp.pl=SWDP.PL
.swdp.pl=SWDP.PL
~~~ 
 >(Required for manual connection testing only) To test connection to AD server, you need to load the keytab file with the command: `kinit -kt /opt/tomcat.keytab HTTP/applicationhost@YOURDOMAIN.COM`, then you can check with `klist` command that key is properly loaded. Executing the `klist` command should write something like this:
 
~~~ sh
Default principal: HTTP/applicationhost@YOURDOMAIN.COM
 
Valid starting       Expires              Service principal
10/23/2017 15:48:31  10/24/2017 01:48:31  krbtgt/YOURDOMAIN.COM@YOURDOMAIN.COM
        renew until 10/24/2017 15:48:31
~~~ 

 >(Required for manual connection testing) Once the keys have been loaded, you can perform a trial connection, for example: `ldapwhoami -Y GSS-SPNEGO -v -h activedirectoryserverhostname -v` or `ldapsearch -Y GSS-SPNEGO -H ldap://activedirectoryserverhostname -b "dc = SWDP, dc = en ". Commands should end successfully, of course, the address activedirectoryserverhostname is the host name of the Active Directory server obtained from hosts file or dns server.
 
## Step three - Spring Security configruation
Below is the configuration of Spring Security. Pay attention to the comments because there are the most important information:

~~~ java
@Slf4j //Lombok annotation for logging
@Configuration
@EnableWebMvcSecurity
public class WebSecurityConfiguration extends WebSecurityConfigurerAdapter {

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
            .exceptionHandling()
                .authenticationEntryPoint(spnegoEntryPoint())
                .and()
            .authorizeRequests()
                .antMatchers("/", "/home").permitAll()
                .anyRequest().authenticated()
                .and()
            .formLogin()
                .loginPage("/login").permitAll()
                .and()
            .logout()
                .permitAll()
                .and()
            .addFilterBefore(
                    spnegoAuthenticationProcessingFilter(authenticationManagerBean()),
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
        return new SpnegoEntryPoint("/login");
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
        ticketValidator.setServicePrincipal("HTTP/srvpcsivm565@SWDP.PL");         //W  tym miejscu musi być zgodnie z instrukcją z pierwszego punktu tego wiki
        FileSystemResource fs = new FileSystemResource("/opt/tomcat.keytab");    //Scieżka do pliku tomcat.keytab
        log.info("Initializing Kerberos KEYTAB file path:" + keytabFilePath);
        Assert.notNull(fs.exists(), "*.keytab key must exist. Without that security is useless.");
        ticketValidator.setKeyTabLocation(fs);
        ticketValidator.setDebug(true);                                        //Debug możemy wyłaczyć po skonfigurowaniu.
        return ticketValidator;
    }

    @Bean
    public DummyUserDetailsService dummyUserDetailsService() {
        return new DummyUserDetailsService();
    }
}
~~~ 

Below is a simple class needed to load detailed user data. The class is mock only, but we can try to read information about user groups from Active Directory or database.
~~~ java
@Slf4j //adnotacja Lombok
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
That's it! You should be now automatically logged in to your application using Active Directory. Thanks for reading!
