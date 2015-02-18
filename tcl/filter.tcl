namespace eval qc {
    namespace export filter_validate filter_authenticate filter_http_request_validate filter_file_alias_path file_alias_path_exists file_alias_path_new file_alias_path2file_id file_alias_path_update file_alias_path_delete filter_handler_exists
}

proc qc::filter_validate {event {error_handler qc::error_handler}} {
    #| Matches the URL to a handler and validates the form data if the method is a type of POST.
    # Default to qc::error_handler
    if {$error_handler eq ""} {
        set error_handler qc::error_handler
    }
    ::try {
        set url_path [qc::conn_path]
        set method [string toupper [qc::conn_method]]
        # Check if this request is registered and a handler exists to validate against.
        if { [qc::registered $method $url_path] && [qc::handlers exists $method $url_path] } {
            # Validate to data model
            qc::handlers validate2model $method $url_path
            # Custom validation
            if {[qc::handlers validation exists $method $url_path]} {
                qc::handlers validation call $method $url_path
            }
            
            # Let the client know if there's a problem
            if {[qc::conn_open] && $method ni [list GET HEAD] && [qc::response status get] eq "invalid"} {
                qc::return_response
                return "filter_return"
            } elseif { [qc::conn_open] && [qc::response status get] eq "invalid" } {
                # GET request failed validation
                error "Couldn't validate the path \"$url_path\"" {} BAD_REQUEST                
            }
        }

        # Validation successful
        return "filter_ok"
    } on error [list error_message options] {
        $error_handler $error_message $options
        return "filter_return"
    }    
}

proc qc::filter_authenticate {event {error_handler qc::error_handler}} {
    #| Checks if session and authentication token are valid.
    # Default to qc::error_handler
    if {$error_handler eq ""} {
        set error_handler qc::error_handler
    }
    set url_path [qc::conn_path]
    set method [string toupper [qc::conn_method]]
    ::try {
        # Check if this request is registered.
        if { [qc::registered $method $url_path] } {
            if {[qc::cookie_exists session_id] && [qc::session_valid [qc::session_id]]} {
                qc::session_update [qc::session_id]
            } elseif {$method ni [list "GET" "HEAD"] && [qc::cookie_exists session_id] && ! [qc::session_valid [qc::session_id]]} {
                # User is trying to POST with an invalid session
                if {[qc::session_exists [qc::session_id]] && [qc::session_user_id [qc::session_id]] != -1} {
                    # Normal user - redirect to login page.
                    qc::response action redirect "/user/login"
                    qc::return_response
                    return "filter_return"
                } else {
                    error "Session invalid. Please refresh the page." {} "SESSION INVALID"
                }
            } else {
                # Implicitly log in as anonymous user.
                global current_user_id session_id
                set current_user_id [qc::anonymous_user_id]
                set session_id [qc::anonymous_session_id]
                qc::cookie_set session_id $session_id
            }

            # Any non-GET/HEAD methods require authentication to prevent cross site request forgery.
            if {$method ni [list "GET" "HEAD"]} {
                set form_dict [qc::form2dict]
                if {[dict exists $form_dict _authenticity_token]} {
                    set authenticity_token [dict get $form_dict _authenticity_token]
                    if {[qc::session_authenticity_token [qc::session_id]] ne $authenticity_token} {
                        error "Authenticity token was invalid." {} AUTH
                    }
                } else {
                    error "Authenticity token was not found." {} AUTH
                }
            }
            
            # Roll the anonymous session after 1 hour.
            if {[qc::auth] == [qc::anonymous_user_id]} {
                qc::cookie_set session_id [qc::anonymous_session_id]
            }
        }
    } on error [list error_message options] {
        $error_handler $error_message $options
        return "filter_return"
    }
    return "filter_ok"
}

proc qc::filter_http_request_validate {event {error_handler "qc::error_handler"}} {
    #| Check that request string and connection url are both valid.
    qc::setif error_handler "" "qc::error_handler"
    ::try {
        set request [ns_conn request]
        set url [qc::conn_path]
        if { ![qc::conn_request_is_valid $request] } {
            ns_returnbadrequest "\"$request\" is not a valid request."
            return filter_return
        }
        if { ![qc::is uri $url] } {
            return [ns_returnbadrequest "\"$url\" is not a valid URL."]
            return filter_return
        }
        return filter_ok
    } on error {error_message options} {
        $error_handler $error_message [dict get $options -errorinfo] [dict get $options -errorcode]
        return filter_return
    }
}

proc qc::filter_file_alias_paths {event http_method {error_handler qc::error_handler}} {
    #| Preauth filter that handles file aliases
    qc::setif error_handler "" qc::error_handler
    ::try {
        set url_path [qc::conn_path]
        if { [qc::file_alias_path_exists [string trimright $url_path /]] } {
            # URL is an alias for a file
            set alias_path [string trimright $url_path /]
            set alias_file [ns_pagepath]$alias_path
            set file_id [qc::file_alias_path2file_id $alias_path]
            
            qc::db_trans {
                # Obtain db lock to prevent simultaneous requests trying to create a sym link at the same time
                qc::db_0or1row {select file_id from file where file_id=:file_id for update} {
                    return [ns_returnnotfound]
                }
                
                # Create disk cache for target file (if it doesn't exist) and get it's canonical url
                set target_path [dict get [qc::file_data [ns_pagepath]/file $file_id] url]
                set target_file [ns_pagepath]$target_path
                
                if  { ! [file exists $alias_file] } {
                    # Alias sym link doesn't exist - create it now
                    file mkdir [file dirname $alias_file]
                    file link $alias_file $target_file
                }  elseif { [file type $alias_file] eq "link" && [file type [file link $alias_file]] eq "file" && [file link $alias_file] ne $target_file } {
                    # Alias sym link exists but does not point to the correct target file - update sym link
                    file delete $alias_file
                    file mkdir [file dirname $alias_file]
                    file link $alias_file $target_file
                } 
            }

            # Register fastpath for alias_path
            ns_register_fastpath $http_method $alias_path
        }
        return filter_ok
    } on error {error_message options} {
        $error_handler $error_message [dict get $options -errorinfo] [dict get $options -errorcode]
        return filter_return
    }
}     

proc qc::file_alias_path_exists {url_path} {
    #| Check if this url path is an alias for a file
    qc::db_0or1row {
        select 
        file_id
        from file_alias_path
        where 
        url_path=:url_path
    } {
        return false
    } {
        return true
    }
}

proc qc::file_alias_path2file_id {url_path} {
    #| Convert alias_path to file_id
    qc::db_1row {
        select 
        file_id
        from file_alias_path
        where 
        url_path=:url_path
    } 
    return $file_id
}

proc qc::file_alias_path_new {url_path file_id} {
    #| Create new file_alias_path record and it's corresponding sym link
    qc::db_trans {
        qc::db_dml {lock table file_alias_path in exclusive mode}
        qc::db_dml "insert into file_alias_path [qc::sql_insert url_path file_id]"
        # Create disk cache for target file (if it doesn't exist) and get it's canonical url
        set target_path [dict get [qc::file_data [ns_pagepath]/file $file_id] url]
        set target_file [ns_pagepath]$target_path
        # Create sym link
        set alias_file [ns_pagepath]$url_path
        if { ![file exists $alias_file] } {
            # file doesn't exist - create sym link
            file mkdir [file dirname $alias_file]
            file link $alias_file $target_file
        } elseif { [file type $alias_file] ne "link" } {
            # file exists but is not a sym link - error as we can't create/update sym link
            error "Unable to create sym link \"$alias_file\" as a regular file at this file location already exists"
        } elseif { [file type [file link $alias_file]] ne "file"} {
            # sym link exists but doesn't point to a file -  error as we can't create/update sym link
            error "Unable to update sym link \"$alias_file\" as the current link target is not a regular file"
        } elseif { [file type [file link $alias_file]] eq "file" && [file link $alias_file] ne $target_file} {
            # sym link exists but doesn't point to the correct file - remove sym link and create a new one
            file delete $alias_file
            file mkdir [file dirname $alias_file]
            file link $alias_file $target_file
        } else {
            # sym link exists and already points to the correct file - nothing to do
        }
    }
}

proc qc::file_alias_path_update {url_path file_id} {
    #| Update an exisiting file alias_path record and it's corresponding sym link
    qc::db_trans {
        qc::db_1row {select url_path from file_alias_path where url_path=:url_path for update}
        qc::db_dml "update file_alias_path set [qc::sql_set file_id] where url_path=:url_path"
        # Create disk cache for target file (if it doesn't exist) and get it's canonical url
        set target_path [dict get [qc::file_data [ns_pagepath]/file $file_id] url]
        set target_file [ns_pagepath]$target_path
        # Update sym link
        set alias_file [ns_pagepath]$url_path
        if { ![file exists $alias_file] } {
            # file doesn't exist - create sym link
            file mkdir [file dirname $alias_file]
            file link $alias_file $target_file
        } elseif { [file type $alias_file] ne "link" } {
            # file exists but is not a sym link - error as we can't create/update sym link
            error "Unable to create sym link \"$alias_file\" as a regular file at this file location already exists"
        } elseif { [file type [file link $alias_file]] ne "file"} {
            # sym link exists but doesn't point to a file -  error as we can't create/update sym link
            error "Unable to update sym link \"$alias_file\" as the current link target is not a regular file"
        } elseif { [file type [file link $alias_file]] eq "file" && [file link $alias_file] ne $target_file} {
            # sym link exists but doesn't point to the correct file - remove sym link and create a new one
            file delete $alias_file
            file mkdir [file dirname $alias_file]
            file link $alias_file $target_file
        } else {
            # sym link exists and already points to the correct file - nothing to do
        }
    }
}

proc qc::file_alias_path_delete {url_path} {
    #| Delete a file alias_path record and it's corresponding sym link
    qc::db_trans {
        qc::db_1row {select url_path from file_alias_path where url_path=:url_path for update}
        qc::db_dml "delete from file_alias_path where url_path=:url_path"
        # remove sym link
        set alias_file [ns_pagepath]$url_path
        if { [file exists $alias_file] && [file type $alias_file] eq "link" && [file type [file link $alias_file]] eq "file" } {
            file delete $alias_file
        }
    }
}

