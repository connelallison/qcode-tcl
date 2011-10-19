package provide qcode 1.1
package require doc
namespace eval qc {}
proc qc::sql_where { args } {
    #| Construct part of SQL WHERE clause using varNames
    #| in a pass-by-name list or a dict.
    #| Any empty values or non-existent variables are ignored
    set dict [args2dict $args]
    set list {}
    foreach {name value} $dict {
	if { [ne $value ""] } {
	    if { [string equal $value NULL] } {
		lappend list "$name IS NULL"
	    } elseif { [string equal $value "NOT NULL"] } {
		lappend list "$name IS NOT NULL"
	    } else {
		lappend list "$name=[db_quote $value]"
	    }
	}
    }
    if { [llength $list]==0 } {
	return true
    } else {
	return [join $list " and "]
    }
}

doc sql_where {
    Parent db
    Usage {sql_where varName1 ?varName2 varName3 ...?}
    Description {
	Construct a SQL <i>WHERE</i> clause based on local TCL variables.<br>
	Don't use the variable if it does not exist or its value is the empty string.<br>
	Return <code>true</code> if all variables are empty or non-existent.
    }
    Examples {
	% set email jimmy@tarbuck.com
	% sql_where email
	email='jimmy@tarbuck.com'
	% 
	% set name Jimmy
	% set qry "select * from users where [sql_where name email]"
	select * from users where name='Jimmy' and email='jimmy@tarbuck.com'
	%
	% set product_code ""
	set qry "select * from products where [sql_where product_code category] LIMIT 100"
	select * from products where true LIMIT 100
    }
}

proc qc::sql_where_like { args } {
    #| Construct part of SQL WHERE clause using varNames
    #| in a pass-by-name list or a dict.
    #| Any empty values or non-existent variables are ignored
    set dict [args2dict $args]
    set list {}
    foreach {name value} $dict {
	if { [info exists value] && [ne $value ""] } {
	    foreach word [split $value] {
		lappend list "$name ~~* [db_quote "%$word%"]"
	    }
	}
    }
    if { [llength $list]==0 } {
	return true
    } else {
	return [join $list " and "]
    }
}

doc sql_where_like {
    Parent db
    Usage {sql_where_like ?varName1 varName2 varName3 ...?}
    Description {
	Construct part of a SQL WHERE clause using Postgresql's LIKE operator
    }
    Examples {
	% set name Jimmy
	% set qry "select * from users where [sql_where_like name]"
	select * from users where name ~~* '%Jimmy%'
	%
	% set name "Jimmy Tarbuck"
	% set qry "select * from users where [sql_where_like users.name]"
	select * from users where users.name ~~* '%Jimmy%' and users.name ~~* '%Tarbuck%'
    }
}

proc qc::sql_where_cols_start { args } {
    #| Construct part of SQL WHERE clause using varNames
    #| corresponding to column names with a regexp matching the
    #| start of the col value.
    #| Any empty values or non-existent variables are ignored
    set dict [args2dict $args]
    set list {}
    foreach {name value} $dict {
	if { [info exists value] && [ne $value ""] } {
	    lappend list "$name ~ [db_quote "^[db_escape_regexp $value]"]"
	}
    }
    if { [llength $list]==0 } {
	return true
    } else {
	return [join $list " and "]
    }
}

doc sql_where_cols_start {
    Parent db
    Usage {sql_where_cols_start ?varName1 varName2 varName3 ...?}
    Description {
	Construct a SQL <i>WHERE</i> clause based on local variables.<br>
	Ignore any empty values or non-existent variables.
	Return <code>true</code> if all variables are empty or non-existent.
    }
    Examples {
	% set email jim
	% sql_where_cols_start email
	email ~ '^jim'
	% 
	% set name J
	% set qry "select * from users where [sql_where_cols_start name email]"
	select * from users where name ~ '^J' and email ~ '^jim'
    }
}

proc qc::sql_where_cols_start_nocase { args } {
    #| Construct part of SQL WHERE clause using varNames
    #| corresponding to column names with a regexp matching the
    #| start of the col value.
    #| Any empty values or non-existent variables are ignored
    set dict [args2dict $args]
    set list {}
    foreach {name value} $dict {
	if { [info exists value] && [ne $value ""] } {
	    lappend list "$name ~* [db_quote "^[db_escape_regexp $value]"]"
	}
    }
    if { [llength $list]==0 } {
	return true
    } else {
	return [join $list " and "]
    }
}

proc qc::sql_where_col_starts { col_name args } {
    #| Construct part of SQL WHERE clause with a regexp matching 
    #| any given values to the start of the col value.
    #| Any empty values or non-existent variables are ignored
    set list {}
    foreach value $args {
	if { [ne $value ""] } {
	    lappend list "$col_name ~ [db_quote "^[db_escape_regexp $value]"]"
	}
    }
    if { [llength $list]==0 } {
	return true
    } else {
	return [join $list " or "]
    }
}

doc sql_where_col_starts {
    Parent db
    Usage {sql_where_col_starts colName value1 ?value2 value3...?}
    Description {
	Construct a SQL <i>WHERE</i> clause matching the start of the column value.
    }
    Examples {
	% sql_where_col_starts email jim
	email ~ '^jim'
	% 
	% sql_where_col_starts name Jim Mac
	name ~ '^Jim' or name ~ '^Mac'
    }
}

proc qc::sql_where_col_starts_nocase { col_name args } {
    #| Construct part of SQL WHERE clause with a regexp matching 
    #| any given values to the start of the col value.
    #| Any empty values or non-existent variables are ignored
    set list {}
    foreach value $args {
	if { [ne $value ""] } {
	    lappend list "$col_name ~* [db_quote "^[db_escape_regexp $value]"]"
	}
    }
    if { [llength $list]==0 } {
	return true
    } else {
	return [join $list " or "]
    }
}

proc qc::sql_where_col_starts_not { col_name args } {
    #| Negation of sql_where_col_starts
    #| Any empty values or non-existent variables are ignored
    set list {}
    foreach value $args {
	if { [ne $value ""] } {
	    lappend list "$col_name !~ [db_quote "^[db_escape_regexp $value]"]"
	}
    }
    if { [llength $list]==0 } {
	return true
    } else {
	return [join $list " and "]
    }
}

proc qc::sql_where_combo { col_name value } {
    if { [ne $value ""] } {
	return "$col_name ~* [db_quote "^[db_escape_regexp $value]"]"
    } else {
	return true
    }
}

proc qc::sql_where_compare { args } {
    # list of varNames
    # assume operator is stored in names variable named varName_op
    set list {}
    foreach name $args {
	if { ![regexp {^([^.]+)\.([^.]+)$} $name sql_name relation var_name] } {
	    set sql_name $name
	    set var_name $name
	}
	upcopy 1 $var_name value
	upcopy 1 "${var_name}_op" operator
	if { [info exists value] && [info exists operator] && [ne $value ""] } {
	    # check operator
	    if { ![in [list < = > <> <= >=] $operator] } { error "Unknown operator $operator" }
	    if { [eq $value NULL] && [eq $operator =] } {
		lappend list "$sql_name IS NULL"
	    } else {
		lappend list "${sql_name}${operator}[db_quote $value]"
	    }
	}
    }
    if { [llength $list]==0 } {
	return true
    } else {
	return [join $list " and "]
    }
}

proc qc::sql_where_compare_set { name operator value } {
    if { [ne $value ""] } {
	# check operator
	if { ![in [list < = > <> <= >=] $operator] } { error "Unknown operator $operator" }
	if { [eq $value NULL] && [eq $operator =] } {
	    return "$name IS NULL"
	} else {
	    return "${name}${operator}[db_quote $value]"
	}
    } else {
	return true
    }
}

proc qc::sql_where_or { args } {
    #| Any empty values or non-existent variables are ignored
    set dict [args2dict $args]
    set list {}
    foreach {name value} $dict {
	if { [ne $value ""] } {
	    if { [string equal $value NULL] } {
		lappend list "$name IS NULL"
	    } elseif { [string equal $value "NOT NULL"] } {
		lappend list "$name IS NOT NULL"
	    } else {
		lappend list "$name=[db_quote $value]"
	    }
	}
    }
    if { [llength $list]==0 } {
	return true
    } else {
	return [join $list " or "]
    }
}

proc qc::sql_where_word_in { args } {
    #| Construct part of SQL WHERE clause using varNames
    #| in a pass-by-name list or a dict.
    #| Any empty values or non-existent variables are ignored
    set dict [args2dict $args]
    set list {}
    foreach {name value} $dict {
	if { [info exists value] && [ne $value ""] } {
	    foreach word [split $value] {
		lappend list "$name ~ [db_quote "( |^)[db_escape_regexp $word]( |$)"]"
	    }
	}
    }
    if { [llength $list]==0 } {
	return true
    } else {
	return [join $list " and "]
    }
}

doc sql_where_word_in {
    Parent db
    Usage {sql_where_word_in ?varName1 varName2 varName3 ...?}
    Description {
	Construct part of a SQL WHERE clause to find a word in a string
    }
    Examples {
	% set name Jimmy
	% set qry "select * from users where [sql_where_word_in name $name]"
	select * from users where name ~ '(^| )Jimmy($| )'
    }
}
