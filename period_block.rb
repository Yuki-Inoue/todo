require 'mytime'

# 値を density で保持
# -> 分割しやすい。
# PeriodBlock は mytime, mytime, density をコンストラクタにとるとする。
class PeriodBlock
  attr_reader :start, :end, :density, :log

  def dump
    puts "#{@start} ~ #{@end} : #{@density}"
  end

  def dump_perday
    @start.printr @end
    puts "  :  #{@density*24}"
  end

  def initialize(s,t,density,log = [])
    @start = s
    @end = t
    @density = density
    @log = log
  end

  def setDensity(d,log = nil)
    @log << log if log
    @density = d
  end

  # c は mytime
  def divide(c)
    [PeriodBlock.new(@start,c,density,log),
     PeriodBlock.new(c,@end,density,log.clone)]
  end

=begin
  def PeriodBlock.ofValue(s,t,val)
    PeriodBlock.
      new(s,t, (val*1.0) / (t - s))
  end
=end

  def length
    @end - @start
  end

  def to_s
    "#<PeriodBlock @start=#{@start} @end=#{@end} @density=#{@density} @log=#{@log.size}}>"
  end

end


