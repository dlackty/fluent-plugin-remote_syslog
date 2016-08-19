require "fluent/mixin/config_placeholders"
require "fluent/mixin/plaintextformatter"
require 'fluent/mixin/rewrite_tag_name'

module Fluent
  class RemoteSyslogOutput < Fluent::Output
    Fluent::Plugin.register_output("remote_syslog", self)

    config_param :hostname, :string, :default => ""

    include Fluent::Mixin::PlainTextFormatter
    include Fluent::Mixin::ConfigPlaceholders
    include Fluent::HandleTagNameMixin
    include Fluent::Mixin::RewriteTagName

    config_param :host, :string
    config_param :port, :integer, :default => 25

    config_param :facility, :string, :default => "user"
    config_param :severity, :string, :default => "notice"
    config_param :tag, :string, :default => "fluentd"

    def initialize
      super
      require "remote_syslog_logger"
      @loggers = {}
    end

    def shutdown
      super
      @loggers.values.each(&:close)
    end

    def emit(tag, es, chain)
      chain.next
      es.each do |time, record|
        record.each_pair do |k, v|
          if v.is_a?(String)
            v.force_encoding("ISO-8859-1").encode("UTF-8")
          end
        end

        tag = rewrite_tag!(tag.dup)
        @loggers[tag] ||= RemoteSyslogLogger::UdpSender.new(@host,
          @port,
          facility: @facility,
          severity: @severity,
          program: tag,
          local_hostname: @hostname)

        @loggers[tag].transmit format(tag, time, record)
      end
    end
  end
end
