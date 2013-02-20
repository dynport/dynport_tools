require 'spec_helper'
require "logger"
    
class LoggerWithTrace < Logger
  def log_trace
  end
end

describe "DynportTools::LogTracer" do
  let(:logger) { Logger.new("/dev/null") }

  before do
    DynportTools::LogTracer.setup(logger)
  end

  it "adds filters to all methods" do
    logger.should respond_to(:log_trace)
  end
  
  it "does not call class_eval when already responding to log_trace" do
    logger = LoggerWithTrace.new("/dev/null")
    logger.class.should_not_receive(:class_eval)
    DynportTools::LogTracer.setup(logger)
  end
  
  it "catches all messages with a specific pattern" do
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
