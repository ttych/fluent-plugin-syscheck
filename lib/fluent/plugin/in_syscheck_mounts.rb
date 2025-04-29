# frozen_string_literal: true

#
# Copyright 2025- Thomas Tych
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

require 'ostruct'

require 'fluent/plugin/input'

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength
module Fluent
  module Plugin
    class SyscheckMountsInput < Fluent::Plugin::Input
      NAME = 'syscheck_mounts'
      Fluent::Plugin.register_input(NAME, self)

      helpers :event_emitter, :timer

      INTERVAL = 300
      TIMEOUT = 5

      desc 'The tag of the event is emitted on'
      config_param :tag, :string
      desc 'interval for probe execution'
      config_param :interval, :time, default: INTERVAL
      desc 'The timeout in second for the check execution'
      config_param :timeout, :time, default: TIMEOUT

      ENABLED_FS_TYPE = nil
      DISABLED_FS_TYPE = %w[sysfs proc devpts bpf devtmpfs debugfs tracefs binfmt_misc
                            efivarfs cgroup cgroup2 securityfs configfs fusectl mqueue
                            pstore hugetlbfs].freeze

      desc 'Enabled FS types'
      config_param :enabled_fs_types, :array, value_type: :string, default: ENABLED_FS_TYPE
      desc 'Disabled FS types'
      config_param :disabled_fs_types, :array, value_type: :string, default: DISABLED_FS_TYPE

      ERROR_ONLY = true

      desc 'Error event only'
      config_param :error_only, :bool, default: ERROR_ONLY

      def configure(conf)
        super

        raise Fluent::ConfigError, 'tag should not be empty' if tag.empty?

        true
      end

      def start
        super

        timer_execute(:check_first, 1, repeat: false, &method(:check)) if interval > 60
        timer_execute(:check, interval, repeat: true, &method(:check))
      end

      def check
        check_mounts
      end

      def check_mounts
        system_mounts.each do |mount|
          status = stat_async(mount)
          emit_mount_status(mount, status)
        end
      end

      def system_mounts
        File.readlines('/proc/mounts').map do |mount_line|
          device, mountpoint, fstype, _rest = mount_line.split
          next if enabled_fs_types && !enabled_fs_types.include?(fstype)
          next if disabled_fs_types&.include?(fstype)

          SysMount.new(device: device, mountpoint: mountpoint, fstype: fstype)
        end.compact
      end

      def stat_async(mount)
        reader, writer = IO.pipe

        pid = fork do
          reader.close
          File.stat(mount.mountpoint)
          writer.puts 'ok'
        rescue StandardError => e
          writer.puts e.message
        ensure
          writer.close
          exit! 0
        end

        writer.close
        result = nil
        begin
          if reader.wait_readable(timeout)
            result = reader.gets.strip
          else
            result = 'timeout'
            Process.kill('KILL', pid) rescue nil
          end
        ensure
          reader.close rescue nil
          Process.wait(pid) rescue nil
        end
        SysMountStatus.new(result)
      end



      def emit_mount_status(mount, status)
        log.debug "#{mount.mountpoint} (#{mount.fstype}): status - #{status}"

        return if error_only && status.success?

        router.emit(
          tag,
          Fluent::Engine.now,
          mount.to_h.merge(status.to_h)
        )
      end

      class SysMount
        attr_reader :device, :mountpoint, :fstype

        def initialize(device:, mountpoint:, fstype:)
          @device = device
          @mountpoint = mountpoint
          @fstype = fstype
        end

        def to_h
          {
            'device' => device,
            'mountpoint' => mountpoint,
            'fstype' => fstype
          }
        end
      end

      class SysMountStatus
        OK_STATUS_MSG = 'ok'

        def initialize(initial_msg)
          @initial_msg = initial_msg
        end

        def success?
          @initial_msg == OK_STATUS_MSG
        end

        def error
          return if success?

          @initial_msg
        end

        def to_h
          {
            'mountpoint_healthy' => success?,
            'mountpoint_error' => error
          }.compact
        end
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength
