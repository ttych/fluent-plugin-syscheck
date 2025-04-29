# frozen_string_literal: true

require 'tmpdir'

require 'helper'
require 'fluent/plugin/in_syscheck_mounts'

class SyscheckInputTest < Test::Unit::TestCase
  TEST_TIME = '2025-04-03T02:01:00.123Z'
  TEST_FLUENT_TIME = Fluent::EventTime.parse(TEST_TIME)
  TEST_TAG = 'test_tag'
  TEST_FLUENTD_CONF = %(
    tag #{TEST_TAG}
  ).freeze

  setup do
    Fluent::Test.setup

    Fluent::EventTime.stubs(:now).returns(TEST_FLUENT_TIME)
  end

  sub_test_case 'configuration' do
    test 'defaults' do
      driver = create_driver
      input = driver.instance

      assert_equal Fluent::Plugin::SyscheckMountsInput::INTERVAL, input.interval
      assert_equal Fluent::Plugin::SyscheckMountsInput::TIMEOUT, input.timeout

      assert_equal nil, input.enabled_fs_types
      assert_equal Fluent::Plugin::SyscheckMountsInput::DISABLED_FS_TYPE, input.disabled_fs_types

      assert_equal Fluent::Plugin::SyscheckMountsInput::ERROR_ONLY, input.error_only
    end
  end

  sub_test_case 'mountpoint healthy' do
    test 'event emitted' do
      fluentd_conf = %(
        #{TEST_FLUENTD_CONF}
        error_only false
      )
      driver = create_driver(fluentd_conf)
      input = driver.instance

      test_sys_mount = nil
      Dir.mktmpdir('mount_test') do |tmpdir|
        test_sys_mount = create_sys_mount(mountpoint: tmpdir)
        input.expects(:system_mounts).returns([test_sys_mount])

        input.check
      end

      emitted_events = driver.events
      expected_events = [
        [TEST_TAG,
         TEST_FLUENT_TIME,
         {
           'device' => test_sys_mount.device,
           'mountpoint' => test_sys_mount.mountpoint,
           'fstype' => test_sys_mount.fstype,
           'mountpoint_healthy' => true
         }]
      ]

      assert_equal 1, emitted_events.size
      assert_equal expected_events, emitted_events
    end
  end

  private

  def create_driver(conf = TEST_FLUENTD_CONF)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::SyscheckMountsInput).configure(conf)
  end

  def create_sys_mount(device: 'test_device', mountpoint: 'test_mountpoint', fstype: 'test_fstype')
    @test_sys_mount = Fluent::Plugin::SyscheckMountsInput::SysMount.new(
      device: device,
      mountpoint: mountpoint,
      fstype: fstype
    )
  end
end
