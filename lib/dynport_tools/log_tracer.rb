class DynportTools::LogTracer
  REMOVE_COLOR = /\e.*?\dm/
  FILTER_BACKTRACE = /\/(gems|ruby)\//
  LOGGER_METHODS = %w(unknown fatal error warn info debug)
  
  def self.setup(logger)
    return if logger.respond_to?(:log_trace)
    logger.class.class_eval do
      LOGGER_METHODS.each do |meth|
        alias_method :"#{meth}_without_log_tracer", meth

        def register_tracer(re_or_messahge, &block)
          tracers[re_or_messahge] = block
        end

        def tracers
          @tracers ||= Hash.new
        end

        def log_trace(message)
          self.tracers.each do |re_or_string, block|
            filtered_backtrace = filter_backtrace(caller)
            if filtered_backtrace.any? && (re_or_string.is_a?(String) ? message.include?(re_or_string) : message.match(re_or_string))
              block.call(message.gsub(REMOVE_COLOR, "").strip, filtered_backtrace)
            end
          end
        end

        def filter_backtrace(trace)
          trace.reject { |t| t.match(FILTER_BACKTRACE) }
        end

        eval <<-EOM, nil, __FILE__, __LINE__ + 1
          def #{meth}(message = nil)
            log_trace(message)
            #{meth}_without_log_tracer(message)
          end
        EOM
      end
    end
  end
end
