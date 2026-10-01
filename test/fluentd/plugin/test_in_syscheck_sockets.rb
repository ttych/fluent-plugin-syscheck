# frozen_string_literal: true

require 'helper'

require 'fluent/plugin/in_syscheck_sockets'

class SyscheckSocketsInputTest < Test::Unit::TestCase
  TEST_TIME = '2026-01-01T02:01:00.123Z'
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
      assert_equal true, input.first_run_wait_interval
      assert_equal false, input.list_sockets
    end
  end

  private

  def create_driver(conf = TEST_FLUENTD_CONF)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::SyscheckSocketsInput).configure(conf)
  end
end
