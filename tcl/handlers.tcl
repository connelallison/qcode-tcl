namespace eval qc::handlers {

    namespace export call exists validate2model validation
    namespace ensemble create

    proc call {method path} {
        #| Call the registered handler that matches the given path and method.
        set method [string toupper $method]
        set pattern [qc::path_best_match $path [get $method]]
        # Add in path variables to form data.
        set form [dict merge [qc::form2dict] [qc::path_variables $path $pattern]]
        # Cast to model
        set dict [qc::cast_values2model {*}[data $form $method $pattern]]
        # Call handler
        return [qc::call_with [proc_name $method $pattern] {*}$dict]
    }

    proc exists {method path} {
        #| Check if a handler exists for the given path and method.
        return [qc::path_matches $path [get [string toupper $method]]]
    }

    proc validate2model {method path} {
        #| Validates the args of the handler registered for the given path and method.
        set method [string toupper $method]
        set pattern [qc::path_best_match $path [get $method]]
        # Add in path variables to form data.
        set form [dict merge [qc::form2dict] [qc::path_variables $path $pattern]]
        # Validate the data.
        return [qc::validate2model [data $form $method $pattern]]
    }

    ##################################################
    #
    # Private procs
    #
    ##################################################

    proc get {{method ""}} {
        #| Get all patterns.
        #| If method has been given then return only patterns that match the given method.
        set temp {}
        if { $method eq "" && [nsv_exists handlers] } {
            dict for {method handlers} [nsv_get handlers] {
                lappend temp {*}[dict keys $handlers]
            }
        } elseif { $method ne "" && [qc::nsv_dict exists handlers [string toupper $method]] } {
            lappend temp {*}[dict keys [qc::nsv_dict get handlers [string toupper $method]]]
        }
        return $temp
    }
    
    proc proc_name {method pattern} {
        #| Get the proc name for the handler identified by $method $pattern.
        return [qc::nsv_dict get handlers $method $pattern proc_name]
    }

    proc args {method pattern} {
        #| Get all arguments for the given handler identified by $method $pattern.
        return [qc::nsv_dict get handlers $method $pattern args]
    }

    proc default {method pattern arg} {
        #| Get the default value of the given arg for the handler identified by $method $pattern.
        return [qc::nsv_dict get handlers $method $pattern defaults $arg]
    }

    proc default_exists {method pattern arg} {
        #| Check if a default argument exists for the given argument for handler identified by $method $pattern.
        return [qc::nsv_dict exists handlers $method $pattern defaults $arg]
    }

    proc data {form method pattern} {
        #| Returns a dictionary of data for the handler identified by $method $pattern.
        set method [string toupper $method]
        set args [args $method $pattern]
        set result {}
        foreach arg $args {
            if { [dict exists $form $arg] } {
                lappend result $arg [dict get $form $arg]
                continue
            }
            
            if { [regexp {^[^.]+\.([^.]+)$} $arg -> column] && [dict exists $form $column] } {
                # e.g. use form variable "firstname" for arg "users.firstname" but only if unambiguous
                # Check if $column or <qualifier>.$column appears anywhere else in the args
                set matches 0
                foreach temp $args {
                    if { $temp eq $column || [string match "?*.$column" $temp] } {
                        incr matches
                    }
                }
                
                if { $matches == 1 } {
                    # Only matched itself therefore it's safe to use unqualified name.
                    lappend result $arg [dict get $form $column]
                    continue
                }
            }
            
            if { [default_exists $method $pattern $arg] } {
                lappend result $arg [default $method $pattern $arg]
                continue
            }
            
            # arg wasn't optional and didn't appear in form
            return -code error "No matching arg value for \"$arg\" in form."
        }
        return $result
    }


    ##################################################
    #
    # qc::handlers validation
    #
    ##################################################
    
    namespace eval validation {

        namespace export call exists
        namespace ensemble create

        proc call {method path} {
            #| Calls the registered handler that matches the given method and path.
            set method [string toupper $method]
            set pattern [qc::path_best_match $path [get $method]]
            # Add in path variables to form data.
            set form [dict merge [qc::form2dict] [qc::path_variables $path $pattern]]
            # Grab relevant arg data from form.
            set dict [data $form $method $pattern]
            # Call the validation handler.
            return [qc::call_with [proc_name $method $pattern] {*}$dict]
        }

        proc exists {method path} {
            #| Checks if a validation handler exists for the given path and method.
            return [qc::path_matches $path [get [string toupper $method]]]
        }

        ##################################################
        #
        # qc::handlers validation
        # Private procs
        #
        ##################################################

        proc get {{method ""}} {
            #| Get all the validation handler paths.
            #| If method has been given then return only handlers that match method.
            set temp {}
            if { $method eq "" && [qc::nsv_dict exists handlers VALIDATE] } {
                dict for {method handlers} [qc::nsv_dict get handlers VALIDATE] {
                    lappend temp {*}[dict keys $handlers]
                }
            } elseif { $method ne "" && [qc::nsv_dict exists handlers VALIDATE [string toupper $method]] } {
                lappend temp {*}[dict keys [qc::nsv_dict get handlers VALIDATE [string toupper $method]]]
            }
            return $temp
        }
        
        proc proc_name {method pattern} {
            #| Get the validation proc_name for the handler identified by $method $pattern.
            return [qc::nsv_dict get handlers VALIDATE $method $pattern proc_name]
        }

        proc args {method pattern} {
            #| Get all arguments for the handler identified by $method $pattern.
            return [qc::nsv_dict get handlers VALIDATE $method $pattern args]
        }

        proc default {method pattern arg} {
            #| Get the default value of the given arg for the handler identified by $method $pattern.
            return [qc::nsv_dict get handlers VALIDATE $method $pattern defaults $arg]
        }

        proc default_exists {method pattern arg} {
            #| Check if a default argument exists for the given argument for handler identified by $method $pattern.
            return [qc::nsv_dict exists handlers VALIDATE $method $pattern defaults $arg]
        }

        proc data {form method pattern} {
            #| Returns a dictionary of args for the handler identified by $method $pattern.
            set method [string toupper $method]
            set args [args $method $pattern]
            set result {}
            foreach arg $args {
                if { [dict exists $form $arg] } {
                    lappend result $arg [dict get $form $arg]
                } elseif { [regexp {^[^.]+\.([^.]+)$} $arg -> column] && [dict exists $form $column] } {
                    # e.g. use form variable "firstname" for arg "users.firstname"
                    lappend result $arg [dict get $form $column]
                } elseif { [default_exists $method $pattern $arg] } {
                    lappend result $arg [default $method $pattern $arg]
                } else {
                    # arg wasn't optional and didn't appear in form
                    return -code error "No matching arg value for \"$arg\" in form." 
                }
            }
            return $result
        }
    }
}