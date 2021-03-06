$VERBOSE = true
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__) if $0 == __FILE__
require 'rubygems'
require 'minitest/autorun'
require 'proco'

class MTBaseSub
  include Proco::MT::Base

  def initialize
    super
  end

  def ok dur
    a = false
    t = Thread.new { sleep dur; a = :ok; self.signal }
    do_when(proc { a }) do
      a
    end.tap { t.join }
  end

  def not_ok
    # Proc.new instead of proc (1.8 compat)
    do_when(Proc.new { return :return }) do
      :anything
    end
  end
end

class TestMTBase < MiniTest::Unit::TestCase
  def test_mt_base
    t = MTBaseSub.new
    st = Time.now
    assert_equal :ok, t.ok(0.1)
    assert Time.now - st >= 0.1 # FIXME

    assert_equal :return, t.not_ok
  end
end

