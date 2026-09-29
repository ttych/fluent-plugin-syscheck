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

require 'fluent/plugin/input'

# rubocop:disable-next Metrics/AbcSize, Metrics/ClassLength, Metrics/MethodLength
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

      ENABLED_FS_TYPES = nil
      DISABLED_FS_TYPES = %w[
        binfmt_misc
        bpf
        cgroup
        cgroup2
        configfs
        debugfs
        devpts
        devtmpfs
        efivarfs
        fusectl
        hugetlbfs
        mqueue
        proc
        pstore
        rpc_pipefs
        securityfs
        squashfs
        sysfs
        tracefs
      ].freeze

      desc 'Enabled FS types'
      config_param :enabled_fs_types, :array, value_type: :string, default: ENABLED_FS_TYPES
      desc 'Disabled FS types'
      config_param :disabled_fs_types, :array, value_type: :string, default: DISABLED_FS_TYPES

      ENABLED_PATHS = nil
      DISABLED_PATHS = [].freeze

      desc 'Enabled Paths'
      config_param :enabled_paths, :array, value_type: :regexp, default: ENABLED_PATHS
      desc 'Disabled Paths'
      config_param :disabled_paths, :array, value_type: :regexp, default: DISABLED_PATHS

      ERROR_ONLY = true

      desc 'Error event only'
      config_param :error_only, :bool, default: ERROR_ONLY

      def configure(conf)
        super

        raise Fluent::ConfigError, 'tag should not be empty' if tag.nil? || tag.empty?
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
          next unless enabled_fs_type?(fstype)
          next if disabled_fs_type?(fstype)
          next unless enabled_path?(mountpoint)
          next if disabled_path?(mountpoint)

          SysMount.new(device: device, mountpoint: mountpoint, fstype: fstype)
        end.compact
      end

      def enabled_fs_type?(fstype)
        return true unless enabled_fs_types

        enabled_fs_types.include?(fstype)
      end

      def disabled_fs_type?(fstype)
        disabled_fs_types&.include?(fstype)
      end

      def enabled_path?(path)
        return true unless enabled_paths

        enabled_paths.any? { |path_pattern| path_pattern.match?(path) }
      end

      def disabled_path?(path)
        disabled_paths.any? { |path_pattern| path_pattern.match?(path) }
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
