# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "stud/interval"
require "socket" # for Socket.gethostname

require "logstash/event"
require "rubygems"
require 'jms-2.0.jar'
require 'tibjms.jar'
require 'tibjmsadmin.jar'
require 'tibcrypt.jar'

# Generate a repeating message.
#
# This plugin is intented only as an example.

class LogStash::Inputs::Tibems < LogStash::Inputs::Base
  config_name "tibems"

  # If undefined, Logstash will complain, even if codec is unused.
  default :codec, "json"

  # The message string to use in the event.

  config :user, :validate => :string, :required => true
  config :password , :validate => :string, :required => true
  config :queueName, :validate => :string, :required => true
  config :initialContextFactory, :validate => :string, :required => true
  config :providerUrl, :validate => :string, :required => true
  config :queueConnectionFactory, :validate => :string, :requierd => true

  def initialize(*args)
    require "java"
    super(*args)
  end # def initialize

  public
  def register
    @logger.info("opening connection to EMS server.", :providerUrl => @providerUrl);

    env = Hashtable.new
    env.put javax.naming.Context.INITIAL_CONTEXT_FACTORY,@initialContextFactory
    env.put javax.naming.Context.PROVIDER_URL,@providerUrl
    env.put javax.naming.Context.SECURITY_PRINCIPAL,@user
    env.put javax.naming.Context.SECURITY_CREDENTIALS,@password

    begin
      jndiContext = javax.naming.InitialContext.new(env) ;
      env = jndiContext.getEnvironment();
      connectionFactory = jndiContext.lookup(@queueConnectionFactory);
      @connection = connectionFactory.createQueueConnection(@user,@password);
      @session = @connection.createQueueSession(false,@ackMode);
      @queue = @session.createQueue(@queueName);
      @receiver = @session.createReceiver(@queue);
      @connection.start();
    rescue Exception => e
      @logger.error("Error initalizing jms input", :exception => e, :backtrace => e.backtrace)
      raise
    end
      @logger.info("Connection established");
  end # def register



  def run(queue)

    @thread = Thread.current

    begin
      while !@interrupted do
        msg = @receiver.receive()
        @logger.debug("Received message", :message => msg)
        @logger.debug("Received JMS message", :CorrelationID => msg.getJMSCorrelationID())
        @logger.debug("Received JMS message", :DeliveryMode => msg.getJMSDeliveryMode())
        @logger.debug("Received JMS message", :MessageID => msg.getJMSMessageID())
        @logger.debug("Received JMS message", :JMSPriority => msg.getJMSPriority())
        @logger.debug("Received JMS message", :JMSDestination => msg.getJMSDestination())
        @logger.debug("Received JMS message", :JMSType =>  msg.getJMSType())

        @logger.debug("Received JMS message", :JMSReplyTo => msg.getJMSReplyTo())
        @logger.debug("Received JMS message", :JMSPriority => msg.getJMSPriority())
        @logger.debug("Received JMS message", :JMSRedelivered => msg.getJMSRedelivered())
        @logger.debug("Received JMS message", :JMSExpiration => msg.getJMSExpiration())

        if msg.java_kind_of?(javax.jms.TextMessage)
          @logger.debug("Received Text message", :body => msg.getText())

          @codec.decode(msg.getText())
          do |event|
            decorate(event)
            event.timestamp = Time.at(msg.getJMSTimestamp()/1000)
            event["JMSCorrelationID"] = msg.getJMSCorrelationID()
            event["JMSMessageID"] = msg.getJMSMessageID()
            event["JMSDestination"] = msg.getJMSDestination().toString()
            event["messageType"] = "TextMessage"
            output_queue << event
          end
        elsif msg.java_kind_of?(javax.jms.MapMessage)
          @logger.debug("Received Map message", :body => msg.getString("_cl.msg"))
          @codec.decode(msg.getString("_cl.msg"))
          do |event|
            decorate(event)
            time = Time.at(msg.getJMSTimestamp()/1000)
            event.timestamp = time
            m = msg.getJMSTimestamp()%1000
            event["timestampFormated"] = time.strftime("%Y-%m-%d %H:%M:%S")+","+m.to_s
            event["JMSTimestamp"] = msg.getJMSTimestamp()

            event["JMSCorrelationID"] = msg.getJMSCorrelationID()
            event["JMSMessageID"] = msg.getJMSMessageID()
            event["JMSDestination"] =msg.getJMSDestination().toString()
            event["messageType"] = "MapMessage"

            event["globalInstanceId"] = msg.getString("_cl.globalInstanceId")
            event["severity"] = msg.getString("_cl.severity")
            event["expirationTimeInDB"] = msg.getString("_cl.expirationTimeInDB")
            event["contextId"] =  msg.getString("_cl.contextId")
            event["physicalCompId.scheme"] =  msg.getString("_cl.physicalCompId.scheme")
            event["priority"] = msg.getString("_cl.priority")
            event["creationTimes"] =  msg.getString("_cl.creationTimes")
            event["reportingCompId.scheme"] = msg.getString("_cl.reportingCompId.scheme")
            event["reportingCompId.hierarchyname"] =  msg.getString("_cl.reportingCompId.hierarchyname")
            event["logicalCompId.scheme"] = msg.getString("_cl.logicalCompId.scheme")
            event["physicalCompId.matrix.node"] = msg.getString("_cl.physicalCompId.matrix.node")
            event["ApplicationName"] = msg.getString("_cl.logicalCompId.matrix.application")
            event["correlationId"] =  msg.getString("_cl.correlationId")
            event["logicalCompId.matrix.operation"] = msg.getString("_cl.logicalCompId.matrix.operation")
            event["physicalCompId.matrix.env"] =  msg.getString("_cl.physicalCompId.matrix.env")
            event["msgId"] =  msg.getString("_cl.msgId")
            event["nanoTime"] = msg.getString("_cl.nanoTime")
            event["reportingCompId.value"] =  msg.getString("_cl.reportingCompId.value")
            event["locationId"] = msg.getString("_cl.locationId")

            output_queue << event
          end
        else
          @logger.debug("JMS message type not supported!")
        end
        msg.acknowledge() if [2, 23, 23].include? @ackMode
      end # loop
      rescue Exception => e
      @logger.error("Error when receiving message", :exception => e, :backtrace => e.backtrace)
    end
  end # ond of run procedure

  def teardown
    @interrupted = true
    @receiver.close()
    @session.close()
    @connection.close()
    finished
    @thread.raise(Interrupted)
  end # def teardown

  def stop
    # nothing to do in this case so it is not necessary to define stop
    # examples of common "stop" tasks:
    #  * close sockets (unblocking blocking reads/accepts)
    #  * cleanup temporary files
    #  * terminate spawned threads
  end
end # class LogStash::Inputs::Tibems
