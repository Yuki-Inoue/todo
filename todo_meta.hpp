#ifndef YUKI_INOUE_TODO
#define YUKI_INOUE_TODO


#include <sqlite3.h>
#include <string>
#include <boost/date_time/posix_time/posix_time.hpp>


#define TODO_DEFINE_TAG(tag_name)				\
  struct todo_##tag_name##_tag {				\
    static const std::string name_;				\
  };								\
  const std::string todo_##tag_name##_tag::name_ = #tag_name;


TODO_DEFINE_TAG(example)




struct NilClass {};

template <class T>
class Type2Type {
  typedef T type;
};

class RowNotFound {};

template <class Tag, class Value, class Tail>
struct SQLRow : public Tail {
  Value value_;
};

template <class SQLTbl>
struct SQLRowObject {
  typename SQLTbl::row_type row_;
  SQLTbl tbl_; // required on update
public:
  SQLRowObject() {}
  explicit SQLRowObject(const SQLTbl &tbl) : tbl_(tbl) {}
};

template <class TableTag, class SQLRow>
struct SQLTable {
  typedef SQLRow row_type;
  sqlite3 *db_;
public:
  SQLTable() : db_(NULL) {}
  explicit SQLTable(sqlite3 *db) : db_(db) {}
};

template <class TableTag, class SQLRow>
std::string name(const SQLTable<TableTag, SQLRow> &){
  return TableTag::name_;
}



template <class SQLR, class Tag>
struct CalcGetValue {
};

template <class Tag1, class Tag2, class Value, class Tail>
struct CalcGetValue<SQLRow<Tag1,Value,Tail>, Tag2>{
  typedef typename CalcGetValue<Tail,Tag2>::type type;
};

template <class Tag, class Value, class Tail>
struct CalcGetValue<SQLRow<Tag, Value, Tail>,Tag> {
  typedef Value type;
};





template <class TT, class SQLR, class Tag>
typename CalcGetValue<SQLR, Tag>::type get(const SQLRowObject<SQLTable<TT, SQLR> > &obj, Tag tag){
  return get(obj.row_, tag);
}

template <class Tag1, class Tag2, class Value, class Tail>
typename CalcGetValue<SQLRow<Tag1,Value,Tail>, Tag2>::type get(const SQLRow<Tag1, Value, Tail> &row, Tag2 tag2){
  return get(*static_cast<const Tail *>(&row), tag2);
}

template <class Tag, class Value, class Tail>
Value get(const SQLRow<Tag, Value, Tail> &row, Tag){
  return row.value_;
}

template <class Tag, class Value, class Tail>
std::string params_sql(const SQLRow<Tag, Value, Tail> &row){
  const std::string tagv = Tag::name_;
  return tagv + " = :" + tagv + ", " + params_sql(*static_cast<Tail *>(row));
}

template <class Tag, class Value>
std::string params_sql(const SQLRow<Tag, Value, NilClass> &row){
  const std::string tagv = Tag::name_;
  return tagv + " = :" + tagv + " ";
}


template <class SQLRow>
std::string update_sql(const SQLRowObject<SQLRow> &obj){
  return
    "UPDATE " + obj.tbl_name_
    + "SET " + params_sql(obj.row_)
    + "WHERE id = :id;";
}

template <class T, class V, class Tail>
int bind_tail(sqlite3_stmt *stmt, const SQLRow<T,V,Tail> &obj){
  return bind_params(stmt, *static_cast<Tail *>(obj));
}

template <class Tag, class Value, class Tail>
int bind_params(sqlite3_stmt *stmt, const SQLRow<Tag, Value, Tail> &obj){
  return bind_params(stmt, sqlite3_bind_parameter_index(stmt, Tag::name_), obj);
}

template <class Tag, class Tail>
int bind_params(sqlite3_stmt *stmt, int i, const SQLRow<Tag, int, Tail> &obj){
  sqlite3_bind_int(stmt, i, obj.value_);
  return bind_tail(stmt, obj);
}

template <class Tag, class Tail>
int bind_params(sqlite3_stmt *stmt, int i, const SQLRow<Tag, double, Tail> &obj){
  sqlite3_bind_double(stmt, i, obj.value_);
  return bind_tail(stmt, obj);
}

template <class Tag, class Tail>
int bind_params(sqlite3_stmt *stmt, int i, const SQLRow<Tag, bool, Tail> &obji){
  sqlite3_bind_int(stmt, i, obji.value_);
  return bind_tail(stmt, obji);
}

template <class Tag, class Tail>
int bind_params(sqlite3_stmt *stmt, int i, const SQLRow<Tag, std::string, Tail> &obj){
  sqlite3_bind_text(stmt, i, obj.value_.c_str(), -1, SQLITE_TRANSIENT);
  return bind_tail(stmt, obj);
}

template <class Tag, class Tail>
int bind_params(sqlite3_stmt *stmt, int i, const SQLRow<Tag, boost::posix_time::ptime, Tail> &obj){
  std::string str = to_simple_string(obj.value_);
  sqlite3_bind_text(stmt, i, str.c_str(), -1, SQLITE_TRANSIENT);
  return bind_tail(stmt, obj);
}

inline int bind_params(sqlite3_stmt *, NilClass){
  return SQLITE_OK;
}


template <class SQLRow>
void update(const SQLRowObject<SQLRow> &obj){
  sqlite3_stmt *stmt;
  sqlite3_prepare_v2(obj.db_, update_sql(obj).c_str(), -1, &stmt, NULL);
  bind_params(stmt, obj.row_);
  sqlite3_step(stmt);
  sqlite3_finalize(stmt);
}

template <class TblTag, class SQLR>
sqlite3_stmt *prepare_find(const SQLTable<TblTag, SQLR> &tbl, std::string where_clause = ""){
  const std::string sql = "SELECT * FROM " + TblTag::name_ + " " + where_clause + ";";
  sqlite3_stmt *stmt;

  if(sqlite3_prepare_v2(tbl.db_, sql.c_str(), -1, &stmt, NULL) != SQLITE_OK)
    throw ("error preparing: " + sql);
  return stmt;
}

inline void reader(NilClass &, sqlite3_stmt *, int){}

template <class T, class V, class Tl>
void read_tail(SQLRow<T,V,Tl> &row, sqlite3_stmt *stmt, int i){
  reader(*static_cast<Tl *>(&row), stmt, i+1);
}

template <class T, class Tail>
void reader(SQLRow<T,int,Tail> &row, sqlite3_stmt *resulting_stmt, int i = 0){
  row.value_ = sqlite3_column_int(resulting_stmt, i);
  read_tail(row, resulting_stmt, i);
}

template <class T, class Tail>
void reader(SQLRow<T,bool,Tail> &row, sqlite3_stmt *resulting_stmt, int i = 0){
  row.value_ = sqlite3_column_int(resulting_stmt, i);
  read_tail(row, resulting_stmt, i);
}

template <class T, class Tail>
void reader(SQLRow<T,double,Tail> &row, sqlite3_stmt *resulting_stmt, int i = 0){
  row.value_ = sqlite3_column_double(resulting_stmt, i);
  read_tail(row, resulting_stmt, i);
}

template <class T, class Tail>
void reader(SQLRow<T,std::string,Tail> &row, sqlite3_stmt *resulting_stmt, int i = 0){
  const char *text = reinterpret_cast<const char *>(sqlite3_column_text(resulting_stmt, i));
  row.value_ = text == NULL ? "" : text;
  read_tail(row, resulting_stmt, i);
}

template <class T, class Tail>
void reader(SQLRow<T,boost::posix_time::ptime,Tail> &row, sqlite3_stmt *resulting_stmt, int i = 0){
  const char *text =reinterpret_cast<const char *>(sqlite3_column_text(resulting_stmt, i));
  row.value_ = text == NULL ? boost::posix_time::ptime(boost::posix_time::not_a_date_time) : boost::posix_time::time_from_string(text);
  read_tail(row, resulting_stmt, i);
}


template <class SQLTbl, class OutputIterator>
void find_objects(sqlite3_stmt *select_stmt, OutputIterator it, const SQLTbl &){
  SQLRowObject<SQLTbl> obj;
  while(sqlite3_step(select_stmt) == SQLITE_ROW){
    reader(obj.row_, select_stmt);
    *it = obj;
  }
}

template <class SQLTbl, class OutputIterator>
void find_all(const SQLTbl &tbl, OutputIterator it){
  sqlite3_stmt *stmt = prepare_find(tbl);
  find_objects(stmt, it, tbl);
  sqlite3_finalize(stmt);
}


#endif
