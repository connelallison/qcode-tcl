proc qc::http_post {args} {
    # usage http_post ?-timeout timeout? ?-encoding encoding? ?-content-type content-type? ?-soapaction soapaction? ?-accept accept? ?-authorization authorization? ?-data data? ?-valid_response_codes? url ?name value? ?name value?
    args $args -timeout 60 -encoding utf-8 -content-type ? -soapaction ? -accept ? -authorization ? -data ? -valid_response_codes {100 200} url args

    # args is name value name value ... list
    if { [llength $args]==1 } {set args [lindex $args 0]}
    
    if { ![info exists data]} {
	set pairs {}
	foreach {name value} $args {
	    lappend pairs "[ns_urlencode -charset $encoding $name]=[ns_urlencode -charset $encoding $value]"
	}
	set data [join $pairs &]

    }
    set httpheaders {}
    if { [info exists authorization] } {
	lappend httpheaders "Authorization: $authorization"
    }

    if { [info exists content-type] } {
	lappend httpheaders "Content-Type: ${content-type}"
    }

    if { [info exists accept] } {
	lappend httpheaders "Accept: $accept"
    }

    if { [info exists soapaction] } {
	lappend httpheaders "SOAPAction: $soapaction"
    }

    set curlHandle [curl::init]
    $curlHandle configure -headervar return_headers -url $url -sslverifypeer 0 -sslverifyhost 0 \
        -timeout $timeout -bodyvar html -post 1 -httpheader $httpheaders -postfields $data
    catch { $curlHandle perform } curlErrorNumber
    set responsecode [$curlHandle getinfo responsecode]
    $curlHandle cleanup
    if { ![in $valid_response_codes $responsecode] } {
        # we should raise an error
        switch $responsecode {
	    404 {return -code error -errorcode CURL "URL NOT FOUND $url"}
	    500 {return -code error -errorcode CURL "SERVER ERROR $url $html"}
	    default {return -code error -errorcode CURL "RESPONSE $responsecode while contacting $url $html"}
        }
    } else {
        # We should return the result
        switch $responsecode {
	    100 {
	        ns_log Notice "HTTP/1.1 100 $html"
	    }
        }
    }
    switch $curlErrorNumber {
	0 {
	    # OK
	    return [encoding convertfrom [httpheader2encoding [array get return_headers]] $html]
	}
	28 {
	    return -code error -errorcode TIMEOUT "Timeout after $timeout seconds trying to contact $url"
	}
	default {
	    return -code error -errorcode CURL [curl::easystrerror $curlErrorNumber]
	}
    }
}

proc qc::http_get {args} {
    # usage http_get ?-timeout timeout? ?-useragent useragent? ?-authorization authorization? ?-clientCustomerId ? url
    args $args -timeout 60 -useragent ? -authorization ? -clientCustomerId ? url

    set httpheaders {}
    if { [info exists authorization] } {
	lappend httpheaders "Authorization: $authorization"
    }
    if { [info exists clientCustomerId] } {
	lappend httpheaders "clientCustomerId: $clientCustomerId"
    }

    default useragent "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.0.7) Gecko/20060909 FreeBSD/i386 Firefox/1.5.0.7"
    #
    set curlHandle [curl::init]
    $curlHandle configure -headervar return_headers -url $url -sslverifypeer 0 -sslverifyhost 0 -timeout $timeout -followlocation 1 -httpheader $httpheaders  -bodyvar html
    catch { $curlHandle perform } curlErrorNumber
    set responsecode [$curlHandle getinfo responsecode]
    $curlHandle cleanup
    switch $responsecode {
	200 { 
	    # OK 
	}
	404 {return -code error -errorcode CURL "URL NOT FOUND $url"}
	500 {return -code error -errorcode CURL "SERVER ERROR $url"}
	default {return -code error -errorcode CURL "RESPONSE $responsecode while contacting $url"}
    }
    switch $curlErrorNumber {
	0 {
	    # OK
	    return [encoding convertfrom [httpheader2encoding [array get return_headers]] $html]
	}
	28 {
	    return -code error -errorcode TIMEOUT "Timeout after $timeout seconds trying to contact $url"
	}
	default {
	    return -code error -errorcode CURL [curl::easystrerror $curlErrorNumber]
	}
    }
}

proc httpheader2encoding { array_list } {
    array set return_headers $array_list
    # Defaults to utf-8 if no encoding is found in header. 
    set return_encoding "utf-8"
    # TODO Strictly speaking we should assume iso8859-1 when no charset is specified according to RFC2616
    # but perhaps utf-8 would be better for us these days?

    # Check for content-type in the return headers
    foreach x {Content-Type content-type} {
        if { [in [array names return_headers] $x] } {
            regexp -nocase {.*;.*charset=(.*)} $return_headers($x) match charset
            if { [info exists charset] } {
                set return_encoding [IANAEncoding2TclEncoding [string trim $charset]]
            }
            break
        }
    }
    return $return_encoding
}

#----------------------------------------------------------------------------
#   IANAEncoding2TclEncoding
#   From v0.82 tDom lib/tdom.tcl
#----------------------------------------------------------------------------

proc IANAEncoding2TclEncoding {IANAName} {
    
    switch [string tolower $IANAName] {
        "us-ascii"    {return ascii}
        "utf-8"       {return utf-8}
        "utf-16"      {return unicode; # not sure about this}
        "iso-8859-1"  {return iso8859-1}
        "iso-8859-2"  {return iso8859-2}
        "iso-8859-3"  {return iso8859-3}
        "iso-8859-4"  {return iso8859-4}
        "iso-8859-5"  {return iso8859-5}
        "iso-8859-6"  {return iso8859-6}
        "iso-8859-7"  {return iso8859-7}
        "iso-8859-8"  {return iso8859-8}
        "iso-8859-9"  {return iso8859-9}
        "iso-8859-10" {return iso8859-10}
        "iso-8859-13" {return iso8859-13}
        "iso-8859-14" {return iso8859-14}
        "iso-8859-15" {return iso8859-15}
        "iso-8859-16" {return iso8859-16}
        "iso-2022-kr" {return iso2022-kr}
        "euc-kr"      {return euc-kr}
        "iso-2022-jp" {return iso2022-jp}
        "koi8-r"      {return koi8-r}
        "shift_jis"   {return shiftjis}
        "euc-jp"      {return euc-jp}
        "gb2312"      {return gb2312}
        "big5"        {return big5}
        "cp866"       {return cp866}
        "cp1250"      {return cp1250}
        "cp1253"      {return cp1253}
        "cp1254"      {return cp1254}
        "cp1255"      {return cp1255}
        "cp1256"      {return cp1256}
        "cp1257"      {return cp1257}

        "windows-1251" -
        "cp1251"      {return cp1251}

        "windows-1252" -
        "cp1252"      {return cp1252}    

        "iso_8859-1:1987" -
        "iso-ir-100" -
        "iso_8859-1" -
        "latin1" -
        "l1" -
        "ibm819" -
        "cp819" -
        "csisolatin1" {return iso8859-1}
        
        "iso_8859-2:1987" -
        "iso-ir-101" -
        "iso_8859-2" -
        "iso-8859-2" -
        "latin2" -
        "l2" -
        "csisolatin2" {return iso8859-2}

        "iso_8859-5:1988" -
        "iso-ir-144" -
        "iso_8859-5" -
        "iso-8859-5" -
        "cyrillic" -
        "csisolatincyrillic" {return iso8859-5}

        "ms_kanji" -
        "csshiftjis"  {return shiftjis}
        
        "csiso2022kr" {return iso2022-kr}

        "ibm866" -
        "csibm866"    {return cp866}
        
        default {
            error "Unrecognized encoding name '$IANAName'"
        }
    }
}
#----------------------------------------------------------------------------
# End of tDom code
#----------------------------------------------------------------------------

proc qc::http_head {args} {
    # usage http_head ?-timeout timeout? ?-useragent useragent? url
    args $args -timeout 60 -useragent ? url
    default useragent "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.0.7) Gecko/20060909 FreeBSD/i386 Firefox/1.5.0.7"
    #
    set curlHandle [curl::init]
    $curlHandle configure -nobody 1 -header 1 -headervar headers -url $url -sslverifypeer 0 -sslverifyhost 0 -timeout $timeout -followlocation 1
    catch { $curlHandle perform } curlErrorNumber
    set responsecode [$curlHandle getinfo responsecode]
    $curlHandle cleanup
    switch $responsecode {
	200 { 
	    # OK 
	}
	404 {return -code error -errorcode CURL "URL NOT FOUND $url"}
	500 {return -code error -errorcode CURL "SERVER ERROR $url"}
	default {return -code error -errorcode CURL "RESPONSE $responsecode while contacting $url"}
    }
    switch $curlErrorNumber {
	0 {
	    # OK
	    return [array get headers]
	}
	28 {
	    return -code error -errorcode TIMEOUT "Timeout after $timeout seconds trying to contact $url"
	}
	default {
	    return -code error -errorcode CURL [curl::easystrerror $curlErrorNumber]
	}
    }
}

proc qc::http_exists {args} {
    # usage http_head ?-timeout timeout? ?-useragent useragent? url
    args $args -timeout 60 -useragent ? -valid_response_codes {100 200} url
    default useragent "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.0.7) Gecko/20060909 FreeBSD/i386 Firefox/1.5.0.7"
    #
    set curlHandle [curl::init]
    $curlHandle configure -nobody 1 -header 1 -headervar headers -url $url -sslverifypeer 0 -sslverifyhost 0 -timeout $timeout -followlocation 1
    catch { $curlHandle perform } curlErrorNumber
    set responsecode [$curlHandle getinfo responsecode]
    $curlHandle cleanup
    if { [in $valid_response_codes $responsecode] } {
	return true
    } else {
	return false
    }
}

proc qc::http_save {url file} {
    set curlHandle [curl::init]
    $curlHandle configure -url $url -file $file -sslverifypeer 0 -sslverifyhost 0
    catch { $curlHandle perform } curlErrorNumber
    set responsecode [$curlHandle getinfo responsecode]
    $curlHandle cleanup
    if { $responsecode != 200 } {
	file delete $file
    }
    switch $responsecode {
	200 { 
	    # OK 
	}
	404 {return -code error -errorcode CURL "URL NOT FOUND $url"}
	500 {return -code error -errorcode CURL "SERVER ERROR $url"}
	default {return -code error -errorcode CURL "RESPONSE $responsecode while contacting $url"}
    }
    switch $curlErrorNumber {
	0 {
	    # OK
	    return 1
	}
	default {
	    file delete $file
	    return -code error -errorcode CURL [curl::easystrerror $curlErrorNumber]
	}
    }
}
