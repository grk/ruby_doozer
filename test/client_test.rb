# Allow test to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'ruby_doozer/client'

# NOTE:
# This test assumes that doozerd is running locally on the default port of 8046

# Register an appender if one is not already registered
if SemanticLogger::Logger.appenders.size == 0
  SemanticLogger::Logger.default_level = :trace
  SemanticLogger::Logger.appenders << SemanticLogger::Appender::File.new('test.log')
end

# Unit Test for RubyDoozer::Client
class ClientTest < Test::Unit::TestCase
  context RubyDoozer::Client do

    context "without server" do
      should "raise exception when cannot reach doozer server after 5 retries" do
        exception = assert_raise ResilientSocket::ConnectionFailure do
          RubyDoozer::Client.new(
            # Bad server address to test exception is raised
            :server                 => 'localhost:9999',
            :connect_retry_interval => 0.1,
            :connect_retry_count    => 5)
        end
        assert_match /After 5 connection attempts to host 'localhost:9999': Errno::ECONNREFUSED/, exception.message
      end

    end

    context "with client connection" do
      setup do
        @client = RubyDoozer::Client.new(:server => 'localhost:8046')
      end

      def teardown
        if @client
          @client.close
          @client.delete('/test/foo')
        end
      end

      should "return current revision" do
        assert @client.current_revision >= 0
      end

      ['/test/foo', '/test/with_underscores'].each do |path|

        should "successfully set and get data in #{path}" do
          new_revision = @client.set(path, 'value')
          result = @client.get(path)
          assert_equal 'value', result.value
          assert_equal new_revision, result.rev
        end

        should "successfully set and get data using array operators in #{path}" do
          @client[path] = 'value2'
          result = @client[path]
          assert_equal 'value2', result
        end
      end

      should "fetch directories in a path" do
        @path = '/'
        count = 0
        until @client.directory(@path, count).nil?
          count += 1
        end
        assert count > 0
      end

    end
  end
end