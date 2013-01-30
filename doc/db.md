Title: Qcode Database API
CSS: default.css

# Qcode Database API

part of [Qcode Documentation](../index.html)

* * *

### SELECT statements
* [db_1row]
* [db_0or1row] and
* [db_foreach].
* [db_select_table].

### INSERT, UPDATE and other DML statements
* [db_dml]

### Database Transactions
* [db_trans]

### Sequences
* [db_seq]

### Bind Variables and Quoting
* [db_qry_parse]
* [db_quote]

### SQL Shortcuts

* [sql_set]
* [sql_insert]
* [sql_sort]

### SQL WHERE helpers

* [sql_where]
* [sql_where_cols_start]
* [sql_where_col_starts]
* [sql_where_like]
* [sql_where_in]
* [sql_where_in_not]

---

## Examples
Lets say we have a table users
<pre class="tcl example">
% CREATE table users (
    user_id integer primary key,
    name varchar(50),
    email varchar(100),
    password varchar(50)
);
        NOTICE:  CREATE TABLE / PRIMARY KEY will create implicit index "users_pkey" for table "users"
        CREATE TABLE
% 
% insert into users (user_id,name,email,password) values (1,'Jimmy','jimmy@tarbuck.com','buz99');
% insert into users (user_id,name,email,password) values (2,'Des','des@oconner.com','conner23');
</pre>

### Getting Data Out
The Database API sets local variables with names corresponding to the column names in the query.

<pre class="tcl example">
% db_1row {select name,email from users where user_id=1}
% set name
Jimmy
% set email
jimmy@foo.com
</pre>

### Bind Variables
Bind Variables are designed to prevent ["SQL Injection Attacks"](SqlInjection) and escape strings ready for the database.

Bind Variables are denoted by a colon followed by the name of the variable to be substituted e.g. `:foo or :bar`.The syntax is similar to ACS and http://www.openacs.org. Postgresql's psql program also uses this notation for substitution but without escaping values.

The work is done by [db_qry_parse] but it should not be neccessary to call this proc directly.

<pre class="tcl example">
% set user_id 1
% set qry {select name from users where user_id=:user_id}
% db_qry_parse $qry
select name from users where user_id=1
</pre>

The procs [db_1row], [db_0or1row], [db_foreach],  [db_select_table] and [db_dml] all parse queries for bind variables before executing the query.

For example:-
<pre class="tcl example">
% set user_id 1
% db_1row {select name from users where user_id=:user_id}
% set name
Jimmy
</pre>

### Getting Data In
Lets say we have a sequence called user_id_seq to generate user_id numbers and we have a new user to add to the users table.

The shortcut [sql_insert] provides a concise way of constructing an INSERT [db_dml] statement.

<pre class="tcl example">
% set user_id [db_seq user_id_seq]
% set name Bob
% set email bob@monkhouse.com
% set password joker
%
% set qry "insert into users [sql_insert user_id name email password]"
insert into users (user_id,name,email,password) values (:user_id,:name,:email,:password)
%
% # So we can write
% db_dml "insert into users [sql_insert user_id name email password]"
</pre>

### Updates

Another useful shortcut for update statements is [sql_set]
Lets say we want to update user # 3  
<pre class="tcl example">
% set user_id 3
% set name "Bob Monkhouse"
% set email "\"Bob Monkhouse\" <bob@monkhouse.com>"
%
% set qry "update users set [sql_set name email] where user_id=:user_id"
update users set name=:name,email=:email where user_id=3
% 
% # Shortcut form can be handed to db_dml
% db_dml "update users set [sql_set name email] where user_id=:user_id"
</pre>

***

Qcode Software Limited <http://www.qcode.co.uk>

[db_1row]: qc/db_1row.html
[db_0or1row]: qc/db_0or1row.html 
[db_foreach]: qc/db_foreach.html
[db_select_table]: qc/db_select_table.html
[db_dml]: qc/db_dml.html
[db_trans]: qc/db_trans.html 
[db_seq]: qc/db_seq.html 
[db_qry_parse]: qc/db_qry_parse.html 
[db_quote]: qc/db_quote.html 
[sql_set]: qc/sql_set.html 
[sql_insert]: qc/sql_insert.html 
[sql_sort]: qc/sql_sort.html 
[sql_where]: qc/sql_where.html 
[sql_where_cols_start]: qc/sql_where_cols_start.html 
[sql_where_col_starts]: qc/sql_where_col_starts.html 
[sql_where_like]: qc/sql_where_like.html 
[sql_where_in]: qc/sql_where_in.html 
[sql_where_in_not]: qc/sql_where_in_not.html 