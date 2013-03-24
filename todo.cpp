
#include <sqlite3.h>
#include <string>
#include <iostream>
#include <vector>
#include <exception>

#include <boost/format.hpp>

#define ID 0
#define NAME 1
#define PLANNED 2
#define FINISHED 3
#define START 4
#define END 5
#define IMPORTANCE 6

class sqlerror : public std::exception {
    std::string msg_;
public:
    template <class T>
    explicit sqlerror(T &&sql)
    : msg_(static_cast<std::string>("SQL prepare: ") + std::forward<T>(sql)) {}
    const char *what() const noexcept override {
        return msg_.c_str();
    }
};

struct Todo {
    int id;
    std::string name;
    double planned;
    int finished;

    friend std::ostream &operator<<(std::ostream &os, const Todo &todo){
        os << boost::format("%5.1f/%5.1f|%4d| %s")
        % todo.finished % todo.planned % todo.id % todo.name << std::endl;
    }
};


class Todos {
    sqlite3_stmt *select_stmt_ = nullptr;
    sqlite3_stmt *select_all_stmt_ = nullptr;
    void prepare_select(sqlite3 *db){
        int ret = sqlite3_prepare_v2
        (db, "SELECT * FROM todos WHERE id = ?", -1, &select_stmt_, nullptr);
        if ( ret != SQLITE_OK)
            throw sqlerror("failed to prepare Todos::select");
    }
    void prepare_select_all(sqlite3 *db) {
        if (sqlite3_prepare_v2
            (db, "SELECT * FROM todos",
             -1, &select_all_stmt_, nullptr)
            != SQLITE_OK)
            throw sqlerror("failed to prepare Todos::select_all");
    }
public:
    Todos(){}
    Todos (const Todos &) = delete;
    explicit Todos (sqlite3 *db) {
        prepare_for_db(db);
    }
    ~Todos() {
        finalize();
    }
    void prepare_for_db (sqlite3 *db){
        finalize();
        prepare_select(db);
        prepare_select_all(db);
    }
    void finalize() {
        sqlite3_finalize(select_all_stmt_);
        sqlite3_finalize(select_stmt_);
        select_all_stmt_ = nullptr;
        select_stmt_ = nullptr;
    }
    std::vector<int> find_all() const {
        std::vector<int> ret;
        while (sqlite3_step(select_all_stmt_) == SQLITE_ROW) {
            ret.push_back
            (sqlite3_column_int(select_all_stmt_,ID));
        }
        sqlite3_reset(select_all_stmt_);
        return ret;
    }
    Todo find(int i) const {
        if ( sqlite3_bind_int(select_stmt_, 1, i) != SQLITE_OK )
            throw sqlerror("bind failed");
        if ( sqlite3_step(select_stmt_) != SQLITE_ROW ){
            sqlite3_reset(select_stmt_);
            throw sqlerror("invalid_arg");
        }
        int id = sqlite3_column_int (select_stmt_, ID);
        std::string str = reinterpret_cast<const char *>(sqlite3_column_text(select_stmt_, NAME));
        double planned = sqlite3_column_double(select_stmt_, PLANNED);
        int finished = sqlite3_column_int(select_stmt_, FINISHED);
        sqlite3_reset(select_stmt_);
        return Todo { id, str, planned, finished };
    }
};

class GPD {
    sqlite3 *db_ = nullptr;
public:
    Todos todos;
    GPD (const GPD &) = delete;
    explicit GPD(const std::string &filename) {
        if ( sqlite3_open(filename.c_str(), &db_) != SQLITE_OK)
            throw sqlerror("GPD");
        todos.prepare_for_db(db_);
    }
    GPD &operator=(const GPD &) = delete;
    ~GPD() {
        todos.finalize();
        sqlite3_close(db_);
    }
};

bool tdump(GPD &gpd) {
    for ( int todo : gpd.todos.find_all() )
        std::cout << gpd.todos.find(todo);
    return true;
}

bool quit(GPD &) { return false; }

#include "../cpplib/commandmap.hpp"

class MainCommands : public CommandMap<bool (*)(GPD &)>{
    MainCommands(){
        map_["tdump"] = tdump;
        map_["q"] = quit;
    }
public:
    static const MainCommands &instance(){
        static MainCommands inst;
        return inst;
    }
};

int main(int argc, char **argv){
    if (argc < 2) {
        std::cout << boost::format("usage: %1$s <gpd.sqlite3>") % argv[0] << std::endl;
        return 0;
    }

    try {
        GPD gpd(argv[1]);
        while (MainCommands::instance().query()(gpd));
    } catch (const std::exception &e){
        std::cout << "ERROR: " << e.what() << std::endl;
    }
}
