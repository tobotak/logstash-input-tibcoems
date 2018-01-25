## An lgostash input plugin for TIBCO Enterprise Message Service





### About



Plugin was created to receive messages from TIBCO EMS queue.

Messages are receive from queue, translate to json and put to logstash event in separate fields.



Plugin is in initial version and need a lot of changes





### Dependencies



* rubygems

* jms-2.0.jar

* tibjms.jar

* tibcrypt.jar





### Build



To build this plugin need insert tibco ems jars to lib folder.



Need to have installed rubygems and run gem buld

`ub@ubuntu:/opt/git-repos/logstash-input-tibems$ gem build logstash-input-tibems.gemspec`





### Instalation



Instalation can be done by ./logstash-Plugin

`./logstash-plugin install /opt/git-repos/logstash-input-tibems/logstash-input-tibems-0.1.0.gem`





### Configuration



to configure this plugin need to create json config files



Input section fields



  `input {

      tibems {

          type => "test"

          user => "admin"

          password => ""

          queueName => "temp"

          codec => "json"

          ackMode => "AUTO"

          initialContextFactory => "com.tibco.tibjms.naming.TibjmsInitialContextFactory"

          providerUrl => "tcp://127.0.0.1:7222"

          queueConnectionFactory => "GenericConnectionFactory"

        }

  }`



Filter section

First parse xml from message field and put it to jsonMessage var

Next parse jsonMessage variable to json fields and put them to event



`filter {

  xml {

    force_array => "false"

    remove_namespaces => "true"

    source => "message"

    target => "jsonMessage"

  }

  json {

    source => "jsonMessage"

  }

}`







### Running



To run this plugin



`./logstash -f tibems.json`







### License



Apache v2, See LICENSE file
