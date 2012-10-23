class MyTime


  protected
  attr_reader :infinite, :time
  include Comparable

  def infinite_string
    @infinite > 0 ? "+infty" : "-infty"
  end


  public
  def <=>(other)
    selfinf = self.infinite
    otherinf = other.infinite
    selfinf && otherinf ? selfinf <=> otherinf :
      selfinf ||
      (otherinf ? -otherinf :
       @time <=> other.time)
  end

  # time = nil で、 Time.new, time = inf/-inf で infinity を設定
  def initialize(time = nil)
    @infinite = time.respond_to?(:infinite?) && time.infinite?
    @time = time || Time.new unless @infinite
  end

  def year
    @time && @time.year
  end

  def month
    @time && @time.month
  end

  def day
    @time && @time.day
  end

  def strftime(str)
    @time ? (@time.strftime str) :
      infinite_string
  end

  def infinite?
    @infinite
  end

  def to_s
    !@infinite ? @time.to_s :
      infinite_string
  end

  def to_inf
    if @infinite
      @infinite > 0 ? $infty : -$infty
    end
  end

  def -(other)
    selfinf = self.to_inf
    otherinf = other.to_inf
    selfinf && otherinf ? selfinf - otherinf :
      selfinf ||
      (otherinf ? -otherinf :
       @time - other.time)
  end

  def printr(t)
    to = "  〜  "
    fulldate = "%Y-%m-%d"
    timeform = "%H:%M"
    fullform = fulldate + " " + timeform
    sinf = self.infinite?
    tinf = t.infinite?
    print((sinf ? self.infinite_string :
           self.time.strftime(fullform)) +
          to +
          (tinf ? t.infinite_string :
           t.time.
           strftime(sinf ? fullform :
                    (self.time.year == t.year ? "" : "%Y-") +
                    (self.month == t.month &&
                     self.day == t.day ? "" : "%m-%d ") +
                    timeform)))
  end


end
