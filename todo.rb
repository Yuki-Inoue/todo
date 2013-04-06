require "rubygems"
require "active_record"

require "period_map"

ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => File.expand_path("~/Dropbox/Todo/todo_ruby.sqlite3"),
  :timeout => 5000
)

=begin
begin
  ActiveRecord::Migration.create_table :todos do |t|
    t.column :name       , :string, :null => false
    t.column :todo_id    , :int
    t.column :planned    , :float, :default => 0
    t.column :finished   , :int, :default => 0
    t.column :start      , :datetime
    t.column :end        , :datetime
    t.column :importance , :int
    t.column :learned    , :string
    t.column :hook       , :string
    t.column :repeat_type, :int
    t.column :repeat_step, :int
    t.column :divided    , :boolean
  end
rescue
end

begin
  ActiveRecord::Migration.create_table :works do |t|
    t.column :todo_id    , :int
    t.column :expr       , :string
    t.column :start      , :datetime
    t.column :end        , :datetime
    t.column :memo       , :string
  end
rescue
end

begin
  ActiveRecord::Migration.create_table :todo_memos do |t|
    t.column :todo_id    , :int
    t.column :content       , :string
  end
rescue
end


begin
  ActiveRecord::Migration.create_table :ftos_relations, :id => false do |t|
    t.column :finish_id    , :int
    t.column :start_id    , :int
  end
rescue
end

=end



$infty = 1.0/0.0


def nextyear(time)
  return nil unless time
  y = time.year
  m = time.month
  d = time.day
  Time.local(y+1, m, d)
end

def nextmonth(time)
  return nil unless time
  y = time.year
  m = time.month
  d = time.day
  m += 1
  if m > 12 then
    y += 1
    m = 1
  end
  Time.local(y,m,d)
end

def nextday(time)
  return nil unless time
  y = time.year
  m = time.month
  d = time.day
  d += 1
  if d > 31 then
    nextmonth(Time.local(y,m,1))
  else
    Time.local(y,m,d)
  end
end



class Todo < ActiveRecord::Base
  has_many :works
  has_many :todos
  has_many :todo_memos
  belongs_to :todo

  has_and_belongs_to_many :ftos_finish, :join_table => "ftos_relations", :class_name => "Todo", :foreign_key => "start_id", :association_foreign_key => "finish_id"
  has_and_belongs_to_many :ftos_start, :join_table => "ftos_relations", :class_name => "Todo", :foreign_key => "finish_id", :association_foreign_key => "start_id"

  include Comparable

  def repeat
    return unless self.repeat_type && self.repeat_type > 0
    # the regular STEP
    if self.repeat_type == 1
      newtodo = self.clone
      newtodo.start = self.start + self.repeat_step
      newtodo.end = self.end + self.repeat_step
      newtodo.save
    # the interval of STEP
    elsif self.repeat_type == 2
      newtodo = self.clone
      newtodo.start = Time.new + self.repeat_step
      newtodo.end = self.end && self.start &&
        newtodo.start + (self.end - self.start)
      newtodo.save
    # every month
    elsif self.repeat_type == 3
      newtodo = self.clone
      newtodo.start = nextmonth(self.start)
      newtodo.end = nextmonth(self.end)
      newtodo.save
    # every year
    elsif self.repeat_type == 4
      newtodo = self.clone
      newtodo.start = nextyear(self.start)
      newtodo.end = nextyear(self.end)
      newtodo.save
    end
    newtodo
  end


  def time_compare_start(time)
    selfnil = !self.start
    timenil = !time
    selfnil && timenil ? 0 :
      selfnil ? -1 : timenil ? 1 :
      self.start <=> time
  end

  def time_compare_end(time)
    selfnil = !self.end
    timenil = !time
    selfnil && timenil ? 0 :
      selfnil ? 1 : timenil ? -1 :
      self.end <=> time
  end

  def <=>(other)
    r = self.importance <=> other.importance
    r != 0 ? r :
      self.end != other.end ? (!self.end ? -1 :
                               !other.end ? 1 :
                               other.end <=> self.end) :
      self.start == other.start ? 0 :
      !self.start ? 1 : !other.start ? -1 :
      other.start <=> self.start
  end


  def getFinished
    unless divided
      self.finished
    else
      return 0.0 if self.todos.any? { |todo| todo.estimate == 0 }
      work_hours = self.works.inject(0) { |sum,w| sum + w.hours }
      children_estimate = self.todos.inject(0) { |sum,t| sum + t.estimate }
      children_actual = self.todos.inject(0) { |sum,t| sum + t.actual }
      (children_actual + work_hours) / (children_estimate + work_hours) * 100
    end
  end


  # first importance, and then density
  def density_compare(other, time = Time.new)
    r = self.importance <=> other.importance
    r != 0 ? r :
      self.separate_density(time) <=>
      other.separate_density(time)
  end

  def actual
    sum = 0
    self.works.each{ |w| sum += w.hours }
    self.todos.each{ |t| sum += t.actual }
    sum
  end

  def estimate
    self.getFinished == 0 ?
    self.planned :
      self.actual / (self.getFinished / 100.0)
  end

  def remain
    self.estimate - self.actual
  end

  # on some cases, this value can be less than 0.
  # see separate_density
  def separate_remain
    self.divided ? 0 :
      self.todos.inject(self.estimate - self.actual){ |remain,t|
      remain - t.remain
    }
  end

  # on some cases, where user don't set finished and there begin actual, etc,
  # the separate_density may be less than 0.
  def separate_density(time = Time.new)
    start = self.start
    endtime = self.end
    length = endtime && endtime - (start ? [start, time].max : time)
    (!length || length <= 0) ? 0.0 :
      self.separate_remain / length
  end

  def full_name
    parent = self.todo
    (parent ? parent.full_name+":" : "") + self.name
  end

  def dump(prefix = "")
    print prefix
    print "#{sprintf("%5.1f",self.actual)}/"
    print "#{sprintf("%5.1f",self.estimate)}/"
    print "#{sprintf("%5.1f",self.planned)}| "
    print "#{sprintf("%3d",self.id)}| "
    print "FIN:: " if self.finished?
    print "Not Started:: " if self.start && self.start > Time.new
    print "I#{self.importance.to_s} " if self.importance != 0
    print "S #{self.start.strftime("%Y/%m/%d %X")}:: " if self.start && self.start > Time.now
    print "F #{self.end.strftime("%Y/%m/%d %X")}:: " if self.end
    puts self.full_name
    self.todo_memos.each{ |memo|
      puts (prefix + "                        * #{memo.content}")
    }
    nil
  end

  def focus(prefix = "", omit_finished = true)
    self.dump prefix
    newprefix = "    " + prefix
    viewing_children = self.todos
    if prefix.length == 0
      if omit_finished
        viewing_children =
          viewing_children.
          find_all{ |t| !t.finished? }
      end
      viewing_children.
        each{ |t| t.focus(newprefix) }
    end
    nil
  end

  def finished?
    self.getFinished >= 100
  end

  def set_finished_and_save(howmuch)
    self.finished = howmuch
    self.save
  end

  def finish(howmuch = 100)
    if howmuch >= 100
      ret = self.repeat
      self.todos.each { |t| t.finish howmuch }
      if self.actual == 0 && !self.learned && self.todos.empty?
        self.destroy
      else
        set_finished_and_save howmuch
      end
      ret
    else
      set_finished_and_save howmuch
    end
  end

  def endpropagate(timeend)
    if self.time_compare_end(timeend) > 0
      self.end = timeend
      self.save
      self.todos.each { |t| t.endpropagate timeend }
    end
  end

  def setend(timeend)
    flag = self.time_compare_end(timeend) > 0
    previous = self.end
    self.end = timeend
    self.save
    self.todos.each { |t|
      t.endpropagate timeend
    } if flag
    self
  end


  def Todo.dump_sub(label, arr, prefix)
    if !arr.empty?
      puts label
      arr.each { |t| t.dump prefix }
      puts
    end
  end

  def inhibitors
    direct_inhibitor = self.todos.select {|child| !child.finished? }
    direct_inhibitor.
      concat(self.ftos_finish.select {|fin| !fin.finished? })
    ret = []
    direct_inhibitor.each {|todo|
      leaves = todo.inhibitors
      if leaves.empty?
        ret << todo
      else
        ret.concat leaves
      end
    }
    ret
  end

  def Todo.map_dump(map)
    map.reverse_each{ |block|
      block.dump_perday
      block.log.each{ |x|
        d,t = x
        str = "#{sprintf("%5.2f",d*24)}: #{sprintf("%3d",t.id)}| I#{t.importance} #{t.full_name}"
        leaves = t.inhibitors
        block_str = leaves.map {|todo| todo.name }
        if block_str.empty?
          if t.hook
            block_str << t.hook
          else
            block_str = nil
          end
        end
        str = "(" + str + ")" if block_str
        print ("  " + str)
        print (" => " + block_str.join(", ")) if block_str
        puts ""
        t.todo_memos.each { |memo|
          puts ("              * " + memo.content)
        }
      }
      puts
    }
  end

  def Todo.dump(todos, prefix = "", seedonly = false)
    current = Time.now
    todos = todos.sort

    finished, rest = todos.
      partition { |t| t.finished? }


    faraway, rest = rest.
      partition{ |t| t.start && t.start >= current + $week }

    in1week, rest = rest.partition { |t| t.start && t.start > current }
    hooked, rest = rest.partition { |t| t.hook }
    started, childed =
      rest.partition { |x|
      x.todos == [] || (x.todos.inject(true) { |a,b| a && b.finished? })
    }

    Todo.dump_sub("Finished::", finished, prefix)
    Todo.dump_sub("Not started(Far away)::",faraway,prefix)
    Todo.dump_sub("Started::", started ,prefix)

    if seedonly
      seeds = childed.select { |parent| !parent.todo_id }
      Todo.dump_sub("Seeds::",seeds,prefix)
    else
      Todo.dump_sub("Childed::", childed, prefix)
    end

    if !hooked.empty?
      puts "Hooked::"
      hooked.
        each { |x|
        x.dump prefix
        puts (prefix +" => #{x.hook}")
      }
      puts
    end

    if !in1week.empty?
      puts "Starting in 1 week::"
      in1week.
        each { |x|
        x.dump prefix
      }
    end
    nil
  end

  def Todo.density_dump(threshold=0)
    map = PeriodMap.new
    current = Time.new
    sorted = Todo.
      find(:all, :conditions =>
           ["finished < ? and importance >= ?",100,threshold]).sort!
    hasdensity, nodensity = sorted.
      # by this find_all, all those finite ranged todos will be selected
      partition{ |todo| todo.separate_density > 0 }


    nodensity_notstarted, nodensity = nodensity.
      partition{ |todo| todo.start && todo.start > current + $week }

    Todo.dump(nodensity_notstarted)

    begin
      hasdensity.
        # make it ordered in the big order of density
        sort! { |a,b| b.density_compare(a)}.
        each{ |t|
=begin
        puts "<<<<<< adding following >>>>>>>>"
        t.dump
        puts "<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>"
=end
        start = t.start
        map.add(MyTime.new(!start ? current :
                           [start, current].max ),
                MyTime.new(t.end || $infty),
                t.separate_remain * 3600, t) }
    rescue DensityOverflow => exp
      puts "todoid(#{exp.getObj.id}) has overflowed!!"
      Todo.map_dump(map)
      raise
    end

    Todo.map_dump(map)

    puts
    puts "no densities::"
    nodensity, wait_finish = nodensity.partition { |todo|
      ftos_fs = todo.ftos_finish
      ftos_fs.empty? || ftos_fs.all? { |ftos_f| ftos_f.finished? }
    }
    Todo.dump(nodensity,"",true)

    puts "wait finish::"
    Todo.dump(wait_finish)

    nil
  end


  def Todo.dump_all
    Todo.all.each { |x| x.dump }
    nil
  end

  def Todo.learned
    Todo.find(:all, :conditions => ["learned is not NULL"]).each{ |x|
      print "#{sprintf("%3d",x.id)}| "
      print "#{sprintf("%.1f",x.actual)}/"
      print "#{sprintf("%.1f",x.estimate)}/"
      print "#{sprintf("%.1f",x.planned)}| "
      print "#{x.name}| "
      puts x.learned
    }
    nil
  end

  def Todo.ofTodo(t = $t, name = nil)
    childname = name || "child of " + t.name
    newt =
      Todo.new(:name => childname, :importance => t.importance,
               :todo_id => t.id, :end => t.end)
    newt.save
    $t = t
    newt
  end

  def Todo.ofTodoid(id, name = nil)
    Todo.ofTodo(Todo.find(id), name)
  end

=begin
  def Todo.averageWork
    Todo.
      find(:all, :conditions =>
           ["finished = ? and (start is NULL or start < ?)",
            false, Time.now]).
  end
=end

=begin
  def Todo.dump_each_importance(i, asc = true)
    Todo.
      find(:all,
           :conditions => ["finished = ? and importance = ?", false, i]).
      each { |x| x.dump }
  end
=end

end


class Work < ActiveRecord::Base
  belongs_to :todo

  include Comparable

  def <=>(other)
    self.end <=> other.end
  end


  def Work.ofTodo(plan = nil)
    w = Work.start
    (plan || $t).works << w
    $w = w
    w
  end
  def Work.ofTodoid(id)
    Work.ofTodo(Todo.find(id))
  end

  def hours
    !self.start ? 0 :
      ((self.end || Time.new) - self.start) / 3600.0
  end

  def full_format_expr
    "For ##{sprintf("%3d",self.todo_id)}: " +
      (self.start.nil? ? "" :
       "S #{self.start.strftime("%Y/%m/%d %X")} ") +
      (self.end.nil? ? "" :
       "F #{self.end.strftime("%Y/%m/%d %X")} ") +
      ":: " +
      Todo.find(self.todo_id).name
  end

  def Work.start
    w = Work.new(:start => Time.new)
    w.save
    w
  end

  def Work.singleton(name)
    t = Todo.new(:name => name)
    t.save
    Work.ofTodo(t)
  end

  def dump
    MyTime.new(self.start).printr MyTime.new(self.end)
    print "  "
    print (self.hours == 0 ? "| " : "#{sprintf("%.1f",self.hours)}h | ")
    print "#{self.id}: #{Todo.find(self.todo_id).full_name}"
    puts (self.memo ? " / #{self.memo}" : "")
  end

  def Work.dump_free_work
    Work.find(:all,
              :order => "start",
              :conditions => ["todo_id IS NULL"]).
      each do |x| x.dump end
    nil
  end


  def Work.dump(lim = 15)
    Work.all(:order => "start desc",:limit => lim).each {|x| x.dump }
    nil
  end

  def finish
    self.end = Time.new
    self.save
  end

end


class TodoMemo < ActiveRecord::Base
  belongs_to :todo

  def TodoMemo.ofTodo(content,todo = nil)
    todo = todo.nil? ? $t : todo
    memo = TodoMemo.new(:content => content)
    todo.todo_memos << memo
    memo
  end

  def TodoMemo.ofTodoid(content,id)
    TodoMemo.ofTodo(Todo.find(id),content)
  end
end

def newtodo(name, importance = 0, endtime = nil)
  t = Todo.new(:name => name, :importance => importance, :end => endtime)
  t.save
  $t = t
  t
end

def newwork
  w = Work.ofTodo($t)
  $w = w
  w
end

def todoid(id)
  $t = Todo.find(id)
end

def incr(amount = 1)
  $t.importance += amount
  $t.save
  $t
end

def decr(amount = 1)
  $t.importance -= amount
  $t.save
  $t
end

$w = Work.last
$t = Todo.find($w.todo_id)

def tdump
  Todo.dump(Todo.find(:all, :conditions => ["finished < ?",100]))
end

def wdump(lim = 15)
  Work.dump lim
end

def memo(str, todo=nil)
  TodoMemo.ofTodo(str,todo)
end

def unhook(todo=nil)
  $t = todo if !todo.nil?
  $t.hook = nil
  $t.save
  $t
end

def hook(str, todo=nil)
  $t = todo if !todo.nil?
  $t.hook = str
  $t.save
  $t
end

def child(name, parent = $t)
  $t = Todo.ofTodo(parent, name)
end

def parent
  $t = Todo.find($t.todo_id)
end

def td(id = nil)
  todoid id if id
  $t.dump
end

def wd
  $w.dump
end

def tfinish(howmuch = 100)
  $t.finish(howmuch)
end

def wfinish
  $w.finish
  $t = Todo.find($w.todo_id)
  $w
end

def ddump(threshold=0)
  Todo.density_dump threshold
end

def setend(time)
  $t.setend time
end

def setstart(time)
  $t.start = time
  $t.save
  $t
end

def setwstart(time)
  $w.start = time
  $w.save
  $w
end

def setwend(time)
  $w.end = time
  $w.save
  $w
end

def setplanned(i)
  $t.planned = i
  $t.save
  $t
end

def focus
  $t.focus
end


def newplan(name, start, timeend, importance = 4)
  newtodo name, importance
  $t.start = start
  setend timeend
  setplanned ((timeend - start)/3600.0)
end

def unplanned
  Todo.find(:all, :conditions => ["finished <= 0"]).
    find_all{ |t| t.separate_remain < 0 }.
    each{ |t| t.dump }
  nil
end

def stash(howmuch)
  stash_start howmuch
  setend ($t.end + howmuch)
end

def stash_start(howmuch)
  setstart (($t.start || Time.new) + howmuch)
end


def learned
  Todo.learned
end

def search(query = nil)
  unless query
    print "search: "
    query = gets
    puts "searching for #{query}"
  end
  query = '%' + query + '%'
  todos = Todo.find(:all, :conditions =>["name like ?", query])
  if todos.size == 1
    $t = todos[0]
  end
  todos
end

def pfinish
  raise if $t.planned * $hour * 2 < $t.end - $t.start
  newwork
  start = $t.start
  $w.start = start
  $w.end = start + $t.planned * $hour
  $w.save
  tfinish
end


# start: start of the first class in range
# length: length of each class
# s,t : ranges for ith class
# parent: if any, make it the parent of these classes.
def class_plan(name, start, length, s, t, parent = nil)
  ans = []
  for i in s..t
    delta = i - s
    ith_start = start + delta * $week
    newplan(name + " ##{i}", ith_start, ith_start+length)
    parent.todos << $t if parent
    ans << $t
  end
  ans
end


def singleton(name, importance = 4)
  newtodo name, importance
  newwork
end


def rmmemo(i)
  $t.todo_memos[i].destroy
end

def divide
  $t.divided = true
  $t.save
  $t
end


$minute = 60
$hour = 60 * $minute
$day = 24 * $hour
$week = 7 * $day
$month = 30 * $day
$year = 365 * $day


def addbirthday(name, month, mday)
  name += " BM"
  newtodo name, 4
  current = Time.new
  candidate = Time.local(current.year, month, mday)
  candidate = nextyear(candidate) if candidate < current
  $t.start = candidate
  $t.end = nextday($t.start)
  $t.planned = 0.1
  $t.repeat_type = 4
  $t.save
  $t
end
