# frozen_string_literal: true

#
# Copyright 2026- Thomas Tych
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fluent/plugin/input'

require 'procfs_rb'
require 'procfs_rb/proc_fs/parser/net_tcp_parser'

module Fluent
  module Plugin
    class SyscheckSocketsInput < Fluent::Plugin::Input
      NAME = 'syscheck_sockets'
      Fluent::Plugin.register_input(NAME, self)

      helpers :event_emitter, :timer

      INTERVAL = 300

      DEFAULT_LIST = false
      DEFAULT_FIRST_RUN_WAIT_INTERVAL = true

      desc 'The tag of the event is emitted on'
      config_param :tag, :string
      desc 'interval for probe execution'
      config_param :interval, :time, default: INTERVAL
      desc 'Wait interval for first execution'
      config_param :first_run_wait_interval, :bool, default: DEFAULT_FIRST_RUN_WAIT_INTERVAL

      desc 'List sockets'
      config_param :list_sockets, :bool, default: DEFAULT_LIST

      def configure(conf)
        super

        raise Fluent::ConfigError, 'tag should not be empty' if tag.nil? || tag.empty?
      end

      def start
        super

        timer_execute(:run_check_first, 1, repeat: false, &method(:run_check)) unless first_run_wait_interval
        timer_execute(:run_check, interval, repeat: true, &method(:run_check))
      end

      def run_check
        run_check_tcp4
      end

      def run_check_tcp4
        tcp4_content = read_file_content('/proc/net/tcp')
        parser = ProcFS::Parser::NetTcpParser.new
        tcp4_info = parser.parse(tcp4_content)

        emit_list_sockets(tcp4_info) if list_sockets
      end

      def emit_list_sockets(sockets)
        log.debug "#{NAME}: emit list_sockets"

        event_time = Fluent::EventTime.from_time(sockets.timestamp)
        sockets.each do |socket|
          router.emit(
            tag,
            event_time,
            socket.to_h
              .merge('timestamp' => sockets.timestamp.iso8601(3))
          )
        end
      end

      private

      def read_file_content(path)
        File.read(path)
      rescue Errno::ENOENT => e
        log.error "#{NAME}: can't read \"#{path}\" content: #{e}"
      end
    end
  end
end
