package provide qcode 1.1
package require doc
namespace eval qc {}

doc forms {
    Title "Qcode Forms"
    Description {
	<h3>Widgets</h3>
	<ul>
	<li>Form Label <proc>widget_label</proc></li>
	<li>Text Input Box <proc>widget_text</proc></li>
	<li>Combo Input Widget <proc>widget_combo</proc></li>
	<li>HTML Editor Control <proc>widget_htmlarea</proc></li>
	<li>Textarea Input <proc>widget_textarea</proc></li>
	<li>Compare Input Control <proc>widget_compare</proc></li>
	<li>Drop Down List <proc>widget_select</proc></li>
	<li>Checkbox Control <proc>widget_checkbox</proc></li>
	<li>Boolean Checkbox <proc>widget_bool</proc></li>
	<li>Password Text Input <proc>widget_password</proc></li>
	<li>Submit Button <proc>widget_submit</proc></li>
	<li>Button <proc>widget_button</proc></li>
	<li>Radio Button <proc>widget_radio</proc></li>
	<li>Radio Button Group <proc>widget_radiogroup</proc></li>
	<li>Span <proc>widget_span</proc></li>
	</ul>
	<h3>Form Layout</h3>
	<ul>
	<li><proc>form_layout_tbody</proc></li>
	<li><proc>form_layout_table</proc></li>
	<li><proc>form_layout_tables</proc></li>
	<li><proc>form_layout_list</proc></li>
	</ul>
    }

}

proc qc::form_layout_table { args } {
    args $args -sticky -- conf
    set cols {
	{class clsLabel}
	{}
    }
    set class clsForm
    if { [info exists sticky] } {
	set tbody [uplevel 1 [list qc::form_layout_tbody -sticky -- $conf]]
    } else {
	set tbody [uplevel 1 [list qc::form_layout_tbody $conf]]
    }
    return [qc::html_table cols $cols class $class tbody $tbody]
}

proc qc::form_layout_tables { args } {
    args $args -sticky -- args
    set cols {
	{class clsLabel}
	{}
    }
    set class clsForm
    foreach conf $args {
	if { [info exists sticky] } {
	    set tbody [uplevel 1 [list qc::form_layout_tbody -sticky -- $conf]]
	} else {
	    set tbody [uplevel 1 [list qc::form_layout_tbody $conf]]
	}
	lappend row [qc::html_table cols $cols class $class tbody $tbody]
    }
    set class clsColumar
    set tbody [list $row]
    return [qc::html_table class $class tbody $tbody]
}
    
proc qc::form_layout_tbody { args } {
    args $args -sticky -- conf
    set level 1
    set tbody {}
    foreach dict $conf {
	array set this $dict
	default this(label) Unknown
	default this(type) text
	# sticky used if set for the widget or globally
	# can be turned off for the widget by setting "sticky no"
	if { [info exists sticky] } {
	    default this(sticky) yes
	} else {
	    default this(sticky) no
	}
	if {[true $this(sticky)] && [sticky_exists $this(name)]} {
	    # sticky values
	    set this(value) [sticky_get $this(name)]
	}
	if { ![info exists this(value)]} {
	    # check caller variable for value
	    upcopy $level $this(name) value
	    if { [info exists value] } {
		set this(value) $value
	    } else {
		set this(value) ""
	    }
	}
    
	
	switch $this(type) {
	    checkbox -
	    bool {
		lappend tbody [list "" "[qc::widget {*}[array get this]] [qc::widget_label {*}[array get this]]"]
	    }
	    radiogroup {
		lappend tbody [list [qc::widget_label {*}[array get this]] [qc::widget_radiogroup {*}[array get this]]]
	    }
	    default {
		set cell [qc::widget {*}[array get this]]
		if { [info exists this(units)] } {
		    append cell [html span " $this(units)"]
		} 
		lappend tbody [list [qc::widget_label {*}[array get this]] $cell]
	    }
	}

	unset this
    }
    return $tbody
}

proc qc::form_layout_list {conf} {
    set level 1
    set html {}
    foreach dict $conf {
	array set this $dict
	default this(label) Unknown
	default this(type) text
	if { ![info exists this(value)]} {
	    upcopy $level $this(name) value
	    if { [info exists value] } {
		set this(value) $value
	    } else {
		set this(value) ""
	    }
	}

	set label [qc::widget_label {*}[array get this]]

	set widget [qc::widget {*}[array get this]]

	if { [in {checkbox bool} $this(type)] } {
	    append html "<div style=\"padding-bottom:1em;\">$widget $label</div>"
	} else {
	    set lines {}
	    if { [ne $this(label) ""] } { lappend lines $label }
	    if { [info exists this(note)] } { lappend lines $this(note) }
	    lappend lines $widget
	    append html "<div style=\"padding-bottom:1em;\">[join $lines "<br>"]</div>"
	}
	unset this
    }
    return $html
}