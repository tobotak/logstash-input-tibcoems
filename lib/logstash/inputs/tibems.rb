#encoding: utf-8
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
  config :ackMode, :validate => :string, :requierd => true

  def initialize(*args)
    require "java"
    super(*args)
  end # def initialize

  public
  def register
    @logger.info("opening connection to EMS server.", :providerUrl => @providerUrl);
    begin
      @connection = javax.jms.Connection;
      @session = javax.jms.Session;
      @queue = javax.jms.queue;
      @receiver = javax.jms.MessageConsumer;
      if @ackMode == "AUTO"
        @ack = javax.jms.Session.AUTO_ACKNOWLEDGE; # value 1
      elsif @ackMode == "CLIENT"
        @ack = javax.jms.Session.CLIENT_ACKNOWLEDGE; # value 2
      elsif @ackMode == "DUPS_OK"
        @ack = javax.jms.Session.DUPS_OK_ACKNOWLEDGE; # value 3
      elsif @ackMode == "EXPLICIT_CLIENT"
        @ack = com.tibco.tibjms.Tibjms.EXPLICIT_CLIENT_ACKNOWLEDGE; # value 23
      elsif @ackMode == "EXPLICIT_CLIENT_DUPS_OK"
        @ack = com.tibco.tibjms.Tibjms.EXPLICIT_CLIENT_DUPS_OK_ACKNOWLEDGE; # value 24
      elsif @ackMode == "NO"
        @ack = com.tibco.tibjms.Tibjms.NO_ACKNOWLEDGE; # value 22
      else
        System.err.println("Unrecognized -ackmode: ", :ackmode => @ackMode)
      end # end of if
      @logger.debug("========== factory definited")
      @factory = com.tibco.tibjms.TibjmsConnectionFactory.new(@providerUrl);
      @logger.debug("========== factory initialized")
      @logger.debug("========== initailizating connection with:", :user => @user, :password => @password)
      @connection = @factory.createConnection(@user,@password);
      @logger.debug("========== connection created ", @connection)
      @session = @connection.createSession(false,@ack);
      @logger.debug("========== session created")
      @queue = @session.createQueue(@queueName);
      @logger.debug("========== queue ref created", :queuename => @queue.getQueueName())
      @receiver = @session.createConsumer(@queue);
      @logger.debug("========== receiver created")
      @connection.start();
      @logger.debug("========= connection ID:", :clientID => @connection.getClientID())
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
        @logger.info("Received message", :messageI => msg)
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
        @logger.debug("Received JMS message", :JMSTimestamp=> msg.getJMSTimestamp())

        if msg.java_kind_of?(javax.jms.TextMessage)
          @logger.debug("Received Text message", :body => msg.getText())
          event = event = LogStash::Event.new()
          event.set("@timestamp", LogStash::Timestamp.at(msg.getJMSTimestamp() / 1000, (msg.getJMSTimestamp() % 1000) * 1000))
          @codec.decode(msg.getText()) do |event|
            event.set("JMSCorrelationID", msg.getJMSCorrelationID())
            event.set("JMSMessageID", msg.getJMSMessageID())
            event.set("JMSDestination", msg.getJMSDestination().toString())
            event.set("messageType", "TextMessage")
            event.set("messageBody", msg.getText())
            event.set("timestamp", msg.getJMSTimestamp())
            decorate(event)
            queue << event
          end
        else
          @logger.error("JMS message type not supported!")
        end
        msg.acknowledge() if [2, 23, 24].include? @ack
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
