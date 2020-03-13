# frozen_string_literal: true

require 'daybreak'
require 'sinatra/base'

# We are extending the Sinatra module
module Sinatra
  # This module is for Sinatra helper methods
  module BMSHelpers
    require 'active_support'
    require 'active_support/core_ext/numeric/conversions'
    require 'active_support/core_ext/string/inflections'

    ActiveSupport::Inflector.inflections(:en) do |inflect|
      inflect.acronym 'BMS'
      inflect.acronym 'CPU'
      inflect.acronym 'URI'
      inflect.acronym 'URIs'
      inflect.acronym 'URL'
      inflect.acronym 'URLs'
      inflect.acronym 'RAM'
    end

    def get_result(timestamp)
      db = Daybreak::DB.new '/tmp/bms.db'
      begin
        db[timestamp]
      ensure
        db.close
      end
    end

    def results
      db = Daybreak::DB.new '/tmp/bms.db'
      begin
        db[:runs].reverse
      ensure
        db.close
      end
    end

    def worker_pid
      File.read('/tmp/bms_worker.pid')
    rescue FileNotFoundException
      nil
    end

    def worker_running?
      pid = worker_pid
      if pid
        begin
          Process.getpgid(pid)
          true
        rescue Errno::ESRCH
          false
        end
      else
        false
      end
    end

    def display_heading(name)
      name = name.to_s
      name.slice!(/_percent$/)
      name.titleize
    end

    def display_value(name, value)
      name = name.to_s
      method_name = "display_#{value.class.name.downcase}"
      if respond_to? method_name
        send(method_name, name, value)
      else
        send(:display_string, name, value)
      end
    end

    def display_array(name, value, delimiter = ', ')
      display_string(name, value.join(delimiter))
    end

    def display_string(_name, value)
      value.to_s
    end

    def display_number(name, value)
      if name.end_with?('_percent')
        value.to_s(:percentage, precision: 0)
      else
        value
      end
    end
    alias display_integer display_number
    alias display_float   display_number
  end
  # Sinatra::BMS_Helpers

  helpers BMSHelpers
end
# Sinatra
