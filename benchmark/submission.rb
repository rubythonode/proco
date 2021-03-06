#!/usr/bin/env ruby

$VERBOSE = true
require 'rubygems'
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'proco'
require 'benchmark'
require 'parallelize'
require 'thread'
require 'logger'

logger = Logger.new($stdout)
times = 1_000_000

if celluloid = false
  require 'celluloid'
  class Cell
    include Celluloid

    def push
      Proco::Future.new
    end
  end
end

result = Benchmark.bm(40) do |x|
  x.report('celluloid') do
    c = Cell.new
    f = nil
    times.times do |i|
      print '.' if i % 1000 == 0
      c.push!
    end
    c.future.push.value
  end if celluloid

  x.report('simple loop') do
    times.times do |i|
      Proco::Future.new
    end
  end

  x.report('Default Proco') do
    proco = Proco.new
    proco.start do |item|
      nil
    end

    times.times do |i|
      print '.' if i % 1000 == 0
      proco.submit! i
    end
    proco.exit
  end

  x.report('SizedQueue push and pop') do
    q = SizedQueue.new 1000
    times.times do |i|
      q.push Proco::Future.new
      q.pop
    end
  end

  x.report('SizedQueue push and pop (threads)') do
    q = SizedQueue.new 1000
    t1 = Thread.new do
      times.times do |i|
        q.push Proco::Future.new
      end
      q.push nil
    end
    t2 = Thread.new do
      while q.pop
      end
    end

    t1.join
    t2.join
  end

  x.report('Mutex synchronization') do
    m = Mutex.new
    a = []
    times.times do |i|
      m.synchronize do
        a << Proco::Future.new
      end
      m.synchronize do
        a.shift
      end
    end
  end

  x.report('Proco queue') do
    q = Proco::Queue::SingleQueue.new 1000
    times.times do |i|
      q.push i
      q.take
    end
  end

  x.report('Proco queue (thread)') do
    q = Proco::Queue::SingleQueue.new 1000
    t1 = Thread.new do
      times.times do |i|
        print '.' if i % 1000 == 0
        q.push i
      end
      q.invalidate
    end

    t2 = Thread.new do
      while true
        f, i = q.take
        break unless f
      end
    end

    t1.join
    t2.join
  end

  [1, 4, 16].each do |queues|
    [1, 2, 4].each do |threads|
      x.report("q: #{queues}, t: #{threads}") do
        proco = Proco.queues(queues).logger(logger).threads(threads).new
        proco.start do |items|
          nil
        end
        threads = 1
        parallelize(threads) do
          (times / threads).times do |i|
            print '.' if i % 1000 == 0
            proco.submit! i
          end
        end
        proco.kill
      end
    end
  end
end

data = Hash[ result.map { |r| [r.label, r.real] } ]
mlen = data.keys.map(&:length).max
mval = data.values.max
width = 40
data.each do |k, v|
  puts k.ljust(mlen) + ' : ' + '*' * (width * (v / mval)).to_i
end

