# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/inputs/kafka"
require 'jruby-kafka'

class LogStash::Inputs::TestKafka < LogStash::Inputs::Kafka
  milestone 1
  private
  def queue_event(msg, output_queue)
    super(msg, output_queue)
    # need to raise exception here to stop the infinite loop
    raise LogStash::ShutdownSignal
  end
end


class TestKafkaGroup < Kafka::Group
  def run(a_num_threads, a_queue)
    a_queue << 'Kafka message'
  end
end

describe 'inputs/kafka' do
  let (:kafka_config) {{'topic_id' => 'test'}}
  let (:decorated_kafka_config) {{'topic_id' => 'test', 'decorate_events' => true}}

  it "should register" do
    input = LogStash::Plugin.lookup("input", "kafka").new(kafka_config)
    expect {input.register}.to_not raise_error
  end

  it 'should populate kafka config with default values' do
    kafka = LogStash::Inputs::TestKafka.new(kafka_config)
    insist {kafka.zk_connect} == 'localhost:2181'
    insist {kafka.topic_id} == 'test'
    insist {kafka.group_id} == 'logstash'
    !insist { kafka.reset_beginning }
  end

  it 'should retrieve event from kafka' do
    kafka = LogStash::Inputs::TestKafka.new(kafka_config, TestKafkaGroup)
    kafka.register

    logstash_queue = Queue.new
    kafka.run logstash_queue
    e = logstash_queue.pop
    insist { e['message'] } == 'Kafka message'
    # no metadata by default
    insist { e['kafka'] } == nil
  end

  it 'should retrieve a decorated event from kafka' do
    kafka = LogStash::Inputs::TestKafka.new(decorated_kafka_config, TestKafkaGroup)
    kafka.register

    logstash_queue = Queue.new
    kafka.run logstash_queue
    e = logstash_queue.pop
    insist { e['message'] } == 'Kafka message'
    # no metadata by default
    insist { e['kafka']['topic'] } == 'test'
    insist { e['kafka']['consumer_group'] } == 'logstash'
    insist { e['kafka']['msg_size'] } == 13
  end

end