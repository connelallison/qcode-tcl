package provide qcode 2.0
package require doc
namespace eval qc {}

doc authorisation {
    Title Authorisation
    Url {/qc/wiki/AuthorisePage}
}

proc qc::authorise_token_create {args} {
    #| Create an authorisation token for this url
    args2vars $args expires employee_id referrer target 
    default expires "24 hours"
    default employee_id [auth]
    default referrer [conn_url]
    if { ![regexp {^https?://} $target] } {
        set target "[qc::conn_location]/[string trimleft $target /]"
    }
    set expiration_epoch [clock scan $expires]
    db_1row {
        select 
        sha1(concat(authorisation_key,:target,:referrer,:expiration_epoch)) as hash
        from employee
        where employee_id=:employee_id
    }
    return "$employee_id $expiration_epoch $hash"
}

doc qc::authorise_token_create {
    Parent authorisation
}

proc qc::authorise_token {} {
    #| Check the authorisation token of the current request
    #| and return the employee_id if authorised
    if { ![form_var_exists authorisation_token] } {
        error "Authorisation token missing" {} AUTHORISATION
    }
    set token [form_var_get authorisation_token]
    lassign $token employee_id expiration_epoch hash
    check employee_id INT
    check expiration_epoch INT

    if { $expiration_epoch < [clock seconds] } {
        error "Authorisation failed. Token has expired." {} AUTHORISATION
    }

    # referrer
    set header_set_id [ns_conn headers]
    if { [ns_set find $header_set_id Referer] == -1 } {
        set referrer ""
    } else {
        set referrer [url_root [ns_set get [ns_conn headers] Referer]]
    }

    set target [conn_url]
   
    set qry {
        select 
        sha1(concat(authorisation_key,:target,:referrer,:expiration_epoch)) as check_hash
        from employee
        where employee_id=:employee_id
    }
    db_0or1row $qry {
        error "Authorisation failed. No such employee_id \"$employee_id\"" {} AUTHORISATION
    } {
        if { $hash eq $check_hash } {
            return $employee_id
        } else {
            error "Authorisation failed. Invalid hash value." {} AUTHORISATION
        }
    }
}

doc qc::authorise_token {
    Parent authorisation
}