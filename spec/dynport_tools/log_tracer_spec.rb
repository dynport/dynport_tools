require 'spec_helper'
require "logger"

describe "DynportTools::LogTracer" do
  let(:clazz) { Class.new(Logger) }
  let(:logger) { clazz.new("/dev/null") }
  
  it "adds filters to all methods" do
    DynportTools::LogTracer.setup(logger)
    logger.should respond_to(:log_trace)
  end
  
  it "calls class_eval once" do
    clazz.should_receive(:class_eval)
    DynportTools::LogTracer.setup(logger)
  end
  
  it "does not call class_eval when already responding to log_trace" do
    logger.should_receive(:respond_to?).with(:log_trace).and_return true
    clazz.should_not_receive(:class_eval)
    DynportTools::LogTracer.setup(logger)
  end
  
  it "catches all messages with a specific pattern" do
    DynportTools::LogTracer.setup(logger)
    messages = []
    logger.register_tracer(/rgne/) do |message, trace|
      messages << message
    end
    logger.info("hello")
    logger.info("rgne1")
    logger.info("world")
    logger.info("rgne2")
    messages.should == %w(rgne1 rgne2)
  end
end
