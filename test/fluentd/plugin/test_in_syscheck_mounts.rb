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
      assert_equal Fluent::Plugin::SyscheckMountsInput::DISABLED_FS_TYPES, input.disabled_fs_types

      assert_equal nil, input.enabled_paths
      assert_equal [], input.disabled_paths

      assert_equal Fluent::Plugin::SyscheckMountsInput::ERROR_ONLY, input.error_only
    end
  end

  sub_test_case 'mountpoints' do
    test 'without filtering' do
      fluentd_conf = %(
        tag test
        disabled_fs_types []
      )
      proc_mounts = [
        "/dev/sda / ext4 rw,relatime 0 0\n",
        "tmpfs /run tmpfs rw,nosuid,nodev 0 0\n",
        "devpts /dev/pts devpts rw 0 0\n"
      ]
      File.expects(:readlines).with('/proc/mounts').returns(proc_mounts)

      driver = create_driver(fluentd_conf)
      input = driver.instance

      mounts = input.system_mounts

      expected_mounts = [
        { 'device' => '/dev/sda',
          'mountpoint' => '/',
          'fstype' => 'ext4' },
        { 'device' => 'tmpfs',
          'mountpoint' => '/run',
          'fstype' => 'tmpfs' },
        { 'device' => 'devpts',
          'mountpoint' => '/dev/pts',
          'fstype' => 'devpts' }
      ]
      assert_equal expected_mounts, mounts.map(&:to_h)
    end

    test 'enabled_fs_types' do
      fluentd_conf = %(
        tag test
        enabled_fs_types ext4,vfat
        disabled_fs_types []
      )
      proc_mounts = [
        "/dev/sda / ext4 rw,relatime 0 0\n",
        "/dev/sdb /boot/efi vfat rw,relatime 0 0\n",
        "tmpfs /run tmpfs rw,nosuid,nodev 0 0\n",
        "devpts /dev/pts devpts rw 0 0\n"
      ]
      File.expects(:readlines).with('/proc/mounts').returns(proc_mounts)

      driver = create_driver(fluentd_conf)
      input = driver.instance

      mounts = input.system_mounts

      expected_mounts = [
        { 'device' => '/dev/sda',
          'mountpoint' => '/',
          'fstype' => 'ext4' },
        {            'device' => '/dev/sdb',
                     'mountpoint' => '/boot/efi',
                     'fstype' => 'vfat' }
      ]
      assert_equal expected_mounts, mounts.map(&:to_h)
    end

    test 'disabled_fs_types' do
      fluentd_conf = %(
        tag test
        disabled_fs_types devpts,vfat
      )
      proc_mounts = [
        "/dev/sda / ext4 rw,relatime 0 0\n",
        "/dev/sdb /boot/efi vfat rw,relatime 0 0\n",
        "tmpfs /run tmpfs rw,nosuid,nodev 0 0\n",
        "devpts /dev/pts devpts rw 0 0\n"
      ]
      File.expects(:readlines).with('/proc/mounts').returns(proc_mounts)

      driver = create_driver(fluentd_conf)
      input = driver.instance

      mounts = input.system_mounts

      expected_mounts = [
        { 'device' => '/dev/sda',
          'mountpoint' => '/',
          'fstype' => 'ext4' },
        {            'device' => 'tmpfs',
                     'mountpoint' => '/run',
                     'fstype' => 'tmpfs' }
      ]
      assert_equal expected_mounts, mounts.map(&:to_h)
    end

    test 'enabled_paths' do
      fluentd_conf = %(
        tag test
        disabled_fs_types []
        enabled_paths /^/$/, /^/boot/
      )
      proc_mounts = [
        "/dev/sda / ext4 rw,relatime 0 0\n",
        "/dev/sdb /boot/efi vfat rw,relatime 0 0\n",
        "tmpfs /run tmpfs rw,nosuid,nodev 0 0\n",
        "devpts /dev/pts devpts rw 0 0\n"
      ]
      File.expects(:readlines).with('/proc/mounts').returns(proc_mounts)

      driver = create_driver(fluentd_conf)
      input = driver.instance

      mounts = input.system_mounts

      expected_mounts = [
        { 'device' => '/dev/sda',
          'mountpoint' => '/',
          'fstype' => 'ext4' },
        {            'device' => '/dev/sdb',
                     'mountpoint' => '/boot/efi',
                     'fstype' => 'vfat' }
      ]
      assert_equal expected_mounts, mounts.map(&:to_h)
    end

    test 'disabled_paths' do
      fluentd_conf = %(
        tag test
        disabled_fs_types []
        disabled_paths /^/run/, /^/dev/
      )
      proc_mounts = [
        "/dev/sda / ext4 rw,relatime 0 0\n",
        "/dev/sdb /boot/efi vfat rw,relatime 0 0\n",
        "tmpfs /run tmpfs rw,nosuid,nodev 0 0\n",
        "devpts /dev/pts devpts rw 0 0\n"
      ]
      File.expects(:readlines).with('/proc/mounts').returns(proc_mounts)

      driver = create_driver(fluentd_conf)
      input = driver.instance

      mounts = input.system_mounts

      expected_mounts = [
        { 'device' => '/dev/sda',
          'mountpoint' => '/',
          'fstype' => 'ext4' },
        {            'device' => '/dev/sdb',
                     'mountpoint' => '/boot/efi',
                     'fstype' => 'vfat' }
      ]
      assert_equal expected_mounts, mounts.map(&:to_h)
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
