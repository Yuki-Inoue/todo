#include "active_record.hpp"


/*
CREATE TABLE todos (id integer primary key autoincrement not null, name varchar(255) not null, planned float default 0, finished int default 0, start datetime, end datetime, importance integer default 0, learned varchar(255), hook string, todo_id int, routine_id int, divided boolean);
*/

ACTIVE_RECORD_DEFINE_TAG(name)
ACTIVE_RECORD_DEFINE_TAG(planned)
ACTIVE_RECORD_DEFINE_TAG(finished)
ACTIVE_RECORD_DEFINE_TAG(start)
ACTIVE_RECORD_DEFINE_TAG(end)
ACTIVE_RECORD_DEFINE_TAG(importance)
ACTIVE_RECORD_DEFINE_TAG(learned)
ACTIVE_RECORD_DEFINE_TAG(hook)
ACTIVE_RECORD_DEFINE_TAG(todo_id)
ACTIVE_RECORD_DEFINE_TAG(routine_id)
ACTIVE_RECORD_DEFINE_TAG(divided)
ACTIVE_RECORD_DEFINE_TAG(todos)

typedef SQLRow<
  id_tag, int, SQLRow
  <name_tag, std::string, SQLRow
   <planned_tag, double, SQLRow
    <finished_tag, int, SQLRow
     <start_tag, boost::posix_time::ptime, SQLRow
      <end_tag, boost::posix_time::ptime, SQLRow
       <importance_tag, int, SQLRow
	<learned_tag, std::string, SQLRow
	 <hook_tag, std::string, SQLRow
	  <todo_id_tag, int, SQLRow
	   <routine_id_tag, int, SQLRow
	    <divided_tag, bool, NilClass> > > > > > > > > > >
  > todo_row;

typedef SQLTable<todos_tag, todo_row> todo_table;
typedef SQLRowObject<todo_table> todo;



#include <boost/format.hpp>
#include <boost/foreach.hpp>
#define foreach BOOST_FOREACH

inline double planned(const todo &t){
  return get(t, planned_tag());
}

void dump(const todo &todo){
  std::cout
    << boost::format("%3d| %5.1f/%5.1f/%5.1f| ")
    % get(todo, id_tag())
    % 0.0 % 0.0 % planned(todo)
    << get(todo, name_tag()) << std::endl;
}




int main(){ // for test dump

  using namespace std;

  const string home = getenv("HOME");
  const string full_path = home + "/" + "Dropbox/Todo/todo_ruby.sqlite3";

  sqlite3 *db;
  if( sqlite3_open(full_path.c_str(), &db) != SQLITE_OK ){
    cout << "error!" << '\n'
	 << sqlite3_errmsg(db) << endl;
    return 1;
  }

  todo_table todos(db);

  std::deque<todo> v;
  try{
    find_all(todos, std::back_inserter(v));
  }
  catch(const std::string &str){
    cout << "err:: " << str << endl;
  }
  catch(exception &e){
    cout << e.what() << endl;
  }

  cout << "found: " << v.size() << endl;

  foreach(const todo &t, v)
    dump(t);

  sqlite3_close(db);
}
