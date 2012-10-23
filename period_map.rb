require 'period_block'

# consistency:
#   @maps, if adjacent blocks shares a common border,
#          then its values must be different.
#   always shares a border. That way the algorithm is a little easier to implement.
#   when empty, only 1 element in map, -infty to infty valued 0.
#       としたい所ではあるが、 Time.infty は存在しない。よって、
#       最初と最後はないものとして扱うことにする。間は稠密。




class DensityOverflow < Exception
  def initialize(obj = nil)
    @obj = obj
  end
  def getObj
    @obj
  end
end


## 色々考えた結果, -infty infty initialized の方針で。
class PeriodMap

  include Enumerable

  def initialize()
    @maps = [PeriodBlock.new(MyTime.new(-$infty),MyTime.new($infty),0)]
  end

  def dump
    @maps.each{ |block| block.dump }
  end

  def dump_perday
    @maps.each{ |block| block.dump_perday }
  end

  def each
    @maps.each { |block| yield block }
  end

  def reverse_each
    @maps.reverse_each { |block| yield block }
  end

  # s,t は MyTime(defined in mytime.rb) のインスタンスだとする
  # val は amount of seconds. (s) という単位。not (s/s)
  def add(s,t,val,log = nil)

=begin
    puts "add (s:#{s}, t:#{t}, val:#{val})"
    puts "dst:"
    puts @maps
=end
    # find the map_indices whose value intersecting with [s,t)
    i = 0
    i += 1 while @maps[i].end <= s
    # maps[i].end > s
    j = i
    mapval = @maps[j]
    while mapval && mapval.start < t
      j += 1
      mapval = @maps[j]
    end
    intersection = i..(j-1) # always some range (I think)
    # the intersecting range. the edges may not completely intersect.

    #calculate min_indices and rest_indices
    indices = intersection.sort_by { |i| @maps[i].density }
    min_density = @maps[indices.first].density
    i = 1
    while i < indices.length &&
        @maps[indices[i]].density <= min_density
      i += 1
    end
    min_indices_ordered = indices.slice!(0...i)
    rest_indices_ordered = indices
    second_min_index = rest_indices_ordered.first
    second_min_density = second_min_index ? @maps[second_min_index].density : 1.0

=begin
    print "min_indices_ordered : "
    p min_indices_ordered
    print "rest_indices_ordered : "
    p rest_indices_ordered
    print "second_min_index : "
    p second_min_index
    print "second_min_density : "
    p second_min_density
    print "intersection : "
    p intersection
=end

    ###finished until here. I think.

    # はしっこの分割(if necessary)
    ## はしっこの分割は、はしっこに add するときのみ必要になる。
    ### first_block_insert が nil じゃなかったら、全ての計算の終わりに add.
    i = intersection.first
    first_block = @maps[i]
    first_block_insert = nil
=begin
    print "first_block : "
    puts first_block
    print "first_block.start : "
    puts first_block.start
    print "s : "
    puts s
=end
    if min_indices_ordered.include?(intersection.first) &&
        first_block.start < s
      # puts "first_block.start < s"
      block1,block2 = first_block.divide(s)
      @maps[i] = block2
      first_block_insert = block1
    end
    j = intersection.end
    tail_block = @maps[j]
    if min_indices_ordered.include?(j) &&
        tail_block.end > t
      block1,block2 = tail_block.divide(t)
      @maps[j] = block2
      @maps.insert(j,block1)
    end

=begin
    puts "divided:"
    puts @maps
=end


    # 主計算
    # 空スペースの計算
    total_span = min_indices_ordered.reduce(0) { |sum,i|
      sum + @maps[i].length
    }
    diff_density = second_min_density - min_density
    if diff_density <= 0
      raise DensityOverflow.new(log)
    end
    space = diff_density * total_span

=begin
    print "diff_density : "
    p diff_density
    print "space : "
    p space
    print "first_block_insert : "
    p first_block_insert
=end


    # 空スペースに収まるかどうかで分岐
    remain = val - space
    remain = remain > 0 && remain
=begin
    print "remain : "
    p remain
    print "(t-s) : "
    p (t-s)
=end

    setting_density = remain ? second_min_density : val*1.0 / total_span + min_density
    adding_density = setting_density - min_density
=begin
    print "setting_density : "
    p setting_density
=end
    min_indices_ordered.each { |i|
      @maps[i].setDensity(setting_density, log && [adding_density,log])
    }

    # first_block_insert
    @maps.insert(intersection.first, first_block_insert) if first_block_insert

    if remain
      self.add(s,t,remain,log)
    end

=begin
    puts "ending add"
    puts
=end

  end

end
