module Enumerable 
  def forkoff options = {}, &block
    options = { 'processes' => Integer(options) } unless Hash === options
    n = Integer( options['processes'] || options[:processes] || Forkoff.default['processes'] )
    strategy = options['strategy'] || options[:strategy] || 'pipe'
    q = SizedQueue.new(n)
    results = Array.new(n){ [] }

    #
    # consumers
    #
      consumers = []

      n.times do |i|
        thread =
          Thread.new do
            Thread.current.abort_on_exception = true

            loop do
              value = q.pop
              break if value == Forkoff.done
              args, index = value

              result =
                case strategy.to_s.strip.downcase
                  when 'pipe'
                    Forkoff.pipe_result(*args, &block)
                  when 'file'
                    Forkoff.file_result(*args, &block)
                  else
                    raise ArgumentError, "strategy=#{ strategy.class }(#{ strategy.inspect })"
                end          

              results[i].push( [result, index] )
            end

            results[i].push( Forkoff.done )
          end

        consumers << thread
      end

    #
    # producers
    #
      producer = 
        Thread.new do
          Thread.current.abort_on_exception = true
          each_with_index do |args, i|
            q.push( [args, i] )
          end
          n.times do |i|
            q.push( Forkoff.done )
          end
        end

    #
    # wait for all consumers to complete
    #
      consumers.each do |t|
        t.value
      end

    #
    # gather results
    #
      returned = []

      results.each do |set|
        set.each do |value|
          break if value == Forkoff.done
          result, index = value
          returned[index] = result
        end
      end

      returned
  end

  alias_method 'forkoff!', 'forkoff'
end