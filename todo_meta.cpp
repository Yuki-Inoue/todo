#include "todo_meta.hpp"


/*
CREATE TABLE todos (id integer primary key autoincrement not null, name varchar(255) not null, planned float default 0, finished int default 0, start datetime, end datetime, importance integer default 0, learned varchar(255), hook string, todo_id int, routine_id int, divided boolean);
*/

TODO_DEFINE_TAG(id)
TODO_DEFINE_TAG(name)
TODO_DEFINE_TAG(planned)
TODO_DEFINE_TAG(finished)
TODO_DEFINE_TAG(start)
TODO_DEFINE_TAG(end)
TODO_DEFINE_TAG(importance)
TODO_DEFINE_TAG(learned)
TODO_DEFINE_TAG(hook)
TODO_DEFINE_TAG(todo_id)
TODO_DEFINE_TAG(routine_id)
TODO_DEFINE_TAG(divided)
TODO_DEFINE_TAG(todo)

typedef SQLRow<
  todo_id_tag, int, SQLRow
  <todo_name_tag, std::string, SQLRow
   <todo_planned_tag, double, SQLRow
    <todo_finished_tag, int, SQLRow
     <todo_start_tag, boost::posix_time::ptime, SQLRow
      <todo_end_tag, boost::posix_time::ptime, SQLRow
       <todo_importance_tag, int, SQLRow
	<todo_learned_tag, std::string, SQLRow
	 <todo_hook_tag, std::string, SQLRow
	  <todo_todo_id_tag, int, SQLRow
	   <todo_routine_id_tag, int, SQLRow
	    <todo_divided_tag, bool, NilClass> > > > > > > > > > >
  > todo_row;

typedef SQLTable<todo_todo_tag, todo_row> todo_table;
typedef SQLRowObject<todo_table> todo;


#include <boost/foreach.hpp>
#define foreach BOOST_FOREACH


int main(){ // for test dump

  const string home = getenv("HOME");
  const string full_path = home + "/" + "Dropbox/Todo/todo_ruby.sqlite3";

  sqlite3 *db;
  sqlite3_open(full_path.c_str(), &db);

  todo_table todos(db);


  std::deque<todo> v;
  find_all(todos, std::back_inserter(v));

  foreach(const todo &t, v){
    cout << get(t, Type2Type<todo_name_tag>()) << endl;
  }
}
