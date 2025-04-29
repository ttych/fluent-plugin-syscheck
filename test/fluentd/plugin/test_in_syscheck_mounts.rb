# frozen_string_literal: true

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
  end

  sub_test_case 'configuration' do
    test 'defaults' do
      driver = create_driver
      input = driver.instance

      assert_equal Fluent::Plugin::SyscheckMountsInput::INTERVAL, input.interval
      assert_equal Fluent::Plugin::SyscheckMountsInput::TIMEOUT, input.timeout
      assert_equal nil, input.enabled_fs_types
      assert_equal nil, input.disabled_fs_types
    end
  end

  test 'failure' do
    true
  end

  private

  def create_driver(conf = TEST_FLUENTD_CONF)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::SyscheckMountsInput).configure(conf)
  end
end
