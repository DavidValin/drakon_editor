

namespace eval gen_drakon_tech {

variable keywords {
abstract 	arguments 	boolean 	break 	byte
case 	catch 	char 	class 	const
continue 	debugger 	default 	delete 	do
double 	else 	enum 	eval 	export
extends 	false 	final 	finally 	float
for 	function 	goto 	if 	implements
import 	in 	instanceof 	int 	interface
let 	long 	native 	new 	null
package 	private 	protected 	public 	return
short 	static 	super 	switch 	synchronized
this 	throw 	throws 	transient 	true
try 	typeof 	var 	void 	volatile
while 	with 	yield
}

variable handlers {}

variable variables {}

proc extract_variables { gdb diagram_id } {
	variable variables
	set vars [ gen::extract_variables $gdb $diagram_id  "var" ]
	if {$vars != "" } {
		lappend variables $diagram_id
		lappend variables $vars
	}
}


proc highlight { tokens } {
	variable keywords
	return [ gen_cs::highlight_generic $keywords $tokens ]
}

proc shelf { primary secondary } {
	return "$secondary = $primary;"
}


proc foreach_init { item_id first second } {
	set index_var "_ind$item_id"
	set keys_var "_keys$item_id"
	set coll_var "_col$item_id"
	set length_var "_len$item_id"
	lassign [ parse_key_value $first ] key value
	if { $key == "" } {
		return "var $index_var = 0;\nvar $coll_var = $second;\nvar $length_var = $coll_var.length;"
	} else {
		return "var $index_var = 0;\nvar $coll_var = $second;\nvar $keys_var = Object.keys\($coll_var\); \nvar $length_var = $keys_var.length;"
	}
}

proc foreach_check { item_id first second } {
	set index_var "_ind$item_id"
	set length_var "_len$item_id"
	return "$index_var < $length_var"
}

proc foreach_current { item_id first second } {
	set index_var "_ind$item_id"
	set coll_var "_col$item_id"
	set keys_var "_keys$item_id"
	lassign [ parse_key_value $first ] key value
	if { $key == "" } {
        return "var $first = $coll_var\[$index_var\];"
    } else {
        return "var $key = $keys_var\[$index_var\]; var $value = $coll_var\[$key\];"
    }
}

proc compare { variable constant } {
    return "$variable === $constant"
}

proc foreach_incr { item_id first second } {
	set index_var "_ind$item_id"
	return "$index_var++;"
}

proc parse_key_value { item } {
    set parts [ split $item "," ]
    if { [ llength $parts ] > 1 } {
        set key [ string trim [ lindex $parts 0 ] ]
        set value [ string trim [ lindex $parts 1 ] ]
    } else {
        set value [ string trim [ lindex $parts 0 ] ]
        set key ""
    }
    
    return [ list $key $value ]
}

proc make_callbacks { } {
	set callbacks {}
	
	gen::put_callback callbacks assign			gen_java::assign
	gen::put_callback callbacks compare			gen_js::compare
	gen::put_callback callbacks compare2		gen_js::compare
	gen::put_callback callbacks while_start 	gen_java::while_start
	gen::put_callback callbacks if_start		gen_java::if_start
	gen::put_callback callbacks elseif_start	gen_java::elseif_start
	gen::put_callback callbacks if_end			gen_java::if_end
	gen::put_callback callbacks else_start		gen_java::else_start
	gen::put_callback callbacks pass			gen_java::pass
	gen::put_callback callbacks continue		gen_java::p.continue
	
	gen::put_callback callbacks return_none		gen_js::p.return_none
	
	gen::put_callback callbacks block_close		gen_java::block_close
	gen::put_callback callbacks comment			gen_java::commentator
	
	gen::put_callback callbacks bad_case		gen_js::p.bad_case
	gen::put_callback callbacks for_init		gen_js::foreach_init
	gen::put_callback callbacks for_check		gen_js::foreach_check
	gen::put_callback callbacks for_current		gen_js::foreach_current
	gen::put_callback callbacks for_incr		gen_js::foreach_incr
	gen::put_callback callbacks body			gen_js::generate_body
	gen::put_callback callbacks signature		gen_js::extract_signature
	gen::put_callback callbacks and				gen_java::p.and
	gen::put_callback callbacks or				gen_java::p.or
	gen::put_callback callbacks not				gen_java::p.not
	gen::put_callback callbacks break			"break;"
	gen::put_callback callbacks declare			gen_js::p.declare
	gen::put_callback callbacks for_declare		gen_js::for_declare
	gen::put_callback callbacks shelf		gen_js::shelf
	
    gen::put_callback callbacks change_state 	gen_js::change_state
    gen::put_callback callbacks shutdown 	""
    gen::put_callback callbacks fsm_merge   0
    
	return $callbacks
}

proc extract_signature { text name } {
	set lines [ gen::separate_from_comments $text ]
	set first_line [ lindex $lines 0 ]
	set first [ lindex $first_line 0 ]
	if { $first == "#comment" } {
		return [ list {} [ gen::create_signature "comment" {} {} {} ]]
	}

    variable handlers
    set is_handler [ contains $handlers $name ]
    
	set parameters {}
	if { $is_handler } {
        lappend parameters {self {}}
	}
	foreach current $lines {
        if { $is_handler } {
            set left [ lindex $current 0 ]
            if { $left == "private" || $left == "state machine" } {
                continue
            }
        }
		lappend parameters $current
	}

	return [ list {} [ gen::create_signature procedure public $parameters "" ] ]
}


proc change_state { next_state machine_name returns } {
    #item 1832
    
    if {$next_state == ""} {
        #item 1836
        set change "self.state = null;"
    } else {
        #item 1835
        set change "self.state = \"${next_state}\";"
    }
    
    if {$returns == {}} {
		return $change
	} else {
		set output [lindex $returns 1]
		return "$change\n$output"
	}
}

proc p.declare { type name value } {
	return "var $name = $value;"
}

proc generate_body { gdb diagram_id start_item node_list sorted incoming } {
	set callbacks [ make_callbacks ]
	return [ cbody::generate_body $gdb $diagram_id $start_item $node_list \
		$sorted $incoming $callbacks ]
}


proc p.return_none { } {
	return "return null;"
}

proc p.block_close { output depth } {
	upvar 1 $output result
	set line [ gen::make_indent $depth ]
	append line "\}"
	lappend result $line
}

proc p.bad_case { switch_var select_icon_number } {
    if {[ string compare -nocase $switch_var "select" ] == 0} {
    	return "throw \"Not expected condition.\";"
    } else {	
		return "throw \"Unexpected switch value: \" + $switch_var;"
	}
	
}

proc for_declare { item_id first second } {
	return ""
}

proc generate_drakon_tech { db filename } {
	puts "$db $filename"
	array set properties [ mwc::get_file_properties ]
	if { ![ info exists properties(language) ] } {
		puts "Language not configured. Choose a language."
		puts "In main menu: File / File properties..."
		exit 1
	}
	
	set language $properties(language)


	newfor::clear
	graph::verify_all $db

	if { ![ graph::errors_occured ] } {
		set outputFolder [string range $filename 0 end-4]
		file delete -force $outputFolder
		file mkdir $outputFolder
		set exported_functions [get_exported_functions]
		convert_folder $db 0 $outputFolder $exported_functions $language

		write_module $outputFolder	
	}
	

	set error_list [ graph::get_error_list ]

	if { [ llength $error_list ] != 0 } {
		foreach error_line $error_list {
			puts $error_line
		}
		return 0
	}
	return 1
}

proc write_module { outputFolder } {
	set header [get_header]
	set content [create_module $header ]
	set outputFilename [file join $outputFolder "module.drakon"]
	write_file $outputFilename [toJson $content]	
}

proc parse_description {text} {
    set lines [split $text "\n"]
    set header_index -1
    set footer_index -1
    set i 0
    foreach line $lines {
        if {[string match "*=== header ==*" $line]} {set header_index $i}
        if {[string match "*=== footer ==*" $line]} {set footer_index $i}
        incr i
    }
    if {$header_index != -1} {
        if {$footer_index != -1} {
            if {$footer_index < $header_index} {
                set header {}; set footer {}
            } else {
                set header [lrange $lines [expr {$header_index+1}] [expr {$footer_index-1}]]
                set footer [lrange $lines [expr {$footer_index+1}] end]
            }
        } else {
            set header [lrange $lines [expr {$header_index+1}] end]
            set footer {}
        }
    } else {
        set header {}
        if {$footer_index != -1} {
            set footer [lrange $lines [expr {$footer_index+1}] end]
        } else {set footer {}}
    }
    return [list $header $footer]
}

proc extract_values {lines} {
    set result {}
    foreach line $lines {
        if {[string match "*=*" $line]} {
            set raw_value [string trim [lindex [split $line "="] end]]
            set value [string trimright $raw_value ",;"]
            dict set result $value 1
        }
    }
    return $result
}

# Procedure: convert_lines_to_blocks
# Splits a list of lines into blocks separated by empty lines or max 4 lines per block
proc convert_lines_to_blocks {lines} {
    set blocks [list]
    set buffer [list]
    
    foreach line $lines {
        set dry [string trim $line]
        
        if {$dry eq ""} {
            # Empty line - finalize current block if not empty
            if {[llength $buffer] > 0} {
                set block [join $buffer "\n"]
                lappend blocks $block
                set buffer [list]
            }
        } else {
            # Non-empty line - add to buffer
            lappend buffer $line
            
            # If buffer reaches 5 lines, finalize the block
            if {[llength $buffer] >= 5} {
                set block [join $buffer "\n"]
                lappend blocks $block
                set buffer [list]
            }
        }
    }
    
    # Handle any remaining lines in buffer
    if {[llength $buffer] > 0} {
        set block [join $buffer "\n"]
        lappend blocks $block
    }
    
    return $blocks
}

# Procedure: convert_block_to_item
# Converts a text block to an item structure with a "next" reference
proc convert_block_to_item {text next} {
    return [list obj [list \
        type [list str "action"] \
        content [list str $text] \
        one [list str $next] \
    ]]
}

# Procedure: Create_module
# Main procedure that converts lines to a diagram structure
proc create_module {lines} {
    set blocks [convert_lines_to_blocks $lines]
    set items [dict create]
    set counter 1
    
    # Add initial branch item
    set next [expr {$counter + 1}]
    dict set items $counter [list obj [list \
        type [list str "branch"] \
        branchId [list num 0] \
        one [list str $next] \
    ]]
    incr counter
    
    # Process each block
    foreach block $blocks {
        set next [expr {$counter + 1}]
        set item [convert_block_to_item $block $next]
        dict set items $counter $item
        incr counter
    }
    
    # Add end marker
    dict set items $counter [list obj [list \
        type [list str "end"] \
    ]]
    
    # Create the diagram structure
    set diagram [list obj [list \
        name [list str "module"] \
        type [list str "drakon"] \
        items [list obj $items] \
    ]]
    
    return $diagram
}


proc convert_folder { db parent parentFolder exported_functions language} {
	set nodes [ $db eval {
		select node_id from tree_nodes where parent = :parent} ]
	foreach node_id $nodes {
		lassign [ $db eval {
			select name, type, diagram_id from tree_nodes where node_id = :node_id
		}] name type diagram_id
		if { $type == "folder" } {
			set outputFolder [file join $parentFolder $name]
			file mkdir $outputFolder
			convert_folder $db $node_id $outputFolder $exported_functions $language
		} else {
			lassign [ $db eval { select name from diagrams where diagram_id = :diagram_id}] name
			set exported [ dict exists $exported_functions $name ]
			if {$language == "DrakonLua"} {
		    	set keys {"=" "" "end"}
				gen::rewrite_clean gdb $diagram_id $keys
			}
			set content [convert_diagram $name $diagram_id $exported]
			set outputFilename [file join $parentFolder "${name}.drakon"]
			write_file $outputFilename $content
		}
	}
}

proc get_exported_functions {} {
	set description [ db onecolumn { select description from state where row = 1 } ]
	lassign [parse_description $description] header footer
	return [extract_values $footer]
}

proc get_header {} {
	set description [ db onecolumn { select description from state where row = 1 } ]
	lassign [parse_description $description] header footer
	return $header	
}

proc get_text_by_vertex {vertex_id} {
	set item_id [gdb onecolumn {select item_id
	from vertices
	where vertex_id = :vertex_id}]
	return [gdb onecolumn {
		select text
		from items
		where item_id = :item_id
	}]
}

proc find_after_arrow { vertices } {
	set result {}
	foreach vertex_id $vertices {
		set arrow_nodes [gdb eval {
			select dst
			from links	
			where src = :vertex_id and direction = 'arrow'
		}]
		foreach arrow_node $arrow_nodes {
			set down [gdb onecolumn {
				select dst
				from links
				where src = :arrow_node and ordinal = 1
			}]
			set down_item [gdb onecolumn {
				select item_id
				from vertices
				where vertex_id = :down
			}]
			lappend result $down_item
		}
	}
	return $result
}

proc rewire_selects_for_tech {diagram_id} {
	set selects [ gdb eval {
		select vertex_id
		from vertices
		where type = 'select' 
			and diagram_id = :diagram_id } ]

	foreach select $selects {
		rewire_select_for_tech $select
	}
}

proc rewire_select_for_tech { select } {
	set ordinals [gdb eval {
		select ordinal
		from links
		where src = :select
		order by ordinal
	}]
	foreach ordinal $ordinals {
		set below [gdb onecolumn {
			select dst
			from links
			where src = :select and ordinal = :ordinal
		}]
		if {$ordinal > 1} {					
			gdb eval {
				insert into links (src, ordinal, dst)
				values (:prev, 2, :below )
			}
			gdb eval {
				delete from links
				where src = :select and ordinal = :ordinal
			}			
		}
		set prev $below
	}
}

proc convert_diagram { name diagram_id exported} {
	rewire_selects_for_tech $diagram_id
	set diagram [ dict create type [type_str drakon] ]
	if {$exported} {
		dict set diagram keywords [type_obj [dict create export [type_bool 1]]]
	}
	set items [dict create]
	set params ""
	# puts "---------------------"
	# puts $name
	if {$name != "_bad_name_"} {
	set ordinals [ gdb eval {
		select ordinal
		from branches
		where diagram_id = :diagram_id		
		order by ordinal
	}]
	set start [ gdb onecolumn {
		select start_icon
		from branches
		where diagram_id = :diagram_id and ordinal = 1
	}]
	foreach ordinal $ordinals {
		lassign [ gdb eval {
			select ordinal, start_icon, first_icon, params_icon
			from branches
			where diagram_id = :diagram_id and ordinal = :ordinal
		}] ordinal start_icon first_icon params_icon
		if {$params_icon != ""} {
			dict set diagram params [type_str [get_text_by_vertex $params_icon]]
		}
		#puts "$ordinal $start_icon $first_icon"
	}
	#puts "vertices"
	set vertices [ gdb eval {
		select vertex_id
		from vertices
		where diagram_id = :diagram_id
	}]
	set after_arrow [find_after_arrow $vertices]
	#puts "after_arrow: $after_arrow"
	set has_branch 0
	set max_id 0
	set to_arrow [dict create]

	foreach vertex_id $vertices {
		lassign [gdb eval {
			select item_id, type, text, parent, right
			from vertices
			where vertex_id = :vertex_id
		}] item_id type text parent right
		if {$type == "branch"} {
			set has_branch 1
		} elseif {$type == "address"} {
			set one [ get_link $vertex_id 1 ]
			dict set to_arrow $item_id $one
			continue
		}
		# puts "$item_id $vertex_id $type $parent $right"
	
		if { $type != "" && $vertex_id != $start } {
			if {$item_id > $max_id} {
				set max_id $item_id
			}
			set item [ build_dt_item $item_id $vertex_id $type $parent $text]
			if {$item == ""} {
				continue
			}
			dict set items $item_id $item

			#puts "$item_id: $item"
		}
	}
	if {$has_branch == 0} {
		incr max_id
		set ord [lindex $ordinals 0]
		set first [gdb onecolumn {
			select first_icon
			from branches
			where ordinal = :ord and diagram_id = :diagram_id
		}]
		set first_item [get_item_id_for_vertex_id $first]
		#puts " ORD $ord $first $first_item"
		set fb [dict create type [type_str "branch"] branchId [type_num 0] one [type_str $first_item]]
		dict set items $max_id [type_obj $fb ]

	}
	set items [insert_arrow_loops $items $after_arrow $max_id $to_arrow]
	}
	dict set diagram items [type_obj $items]

	return [toJson [type_obj $diagram]]
}

proc get_item_id_for_vertex_id {vertex_id} {
	while {1} {
		set item_id [gdb onecolumn {
			select item_id
			from vertices
			where vertex_id = :vertex_id
		}]
		if {$item_id != ""} {
			return $item_id
		}
		set vertex_id [gdb onecolumn {
			select dst
			from links
			where src = :vertex_id and ordinal = 1
		}]
	}
}

proc insert_arrow_loops { items after_arrow max_id to_arrow} {
	set keys [dict keys $items]
	foreach item_id $after_arrow {
		incr max_id
		dict set to_arrow $item_id $max_id
		set arrow_item [dict create type [type_str "arrow-loop"] one [type_str $item_id]]
		dict set items $max_id [type_obj $arrow_item]
	}
	foreach item_id $keys {
		set bucket [dict get $items $item_id]
		set item [dict get $bucket obj]
		if {[dict exists $item one]} {
			set prop [dict get $item one]
			set one [dict get $prop str]
			if {[dict exists $to_arrow $one]} {
				set prop [type_str [dict get $to_arrow $one]]
				dict set item one $prop
				dict set items $item_id [type_obj $item]
			}
		}
		if {[dict exists $item two]} {
			set prop [dict get $item two]
			set two [dict get $prop str]
			if {[dict exists $to_arrow $two]} {
				set prop [type_str [dict get $to_arrow $two]]
				dict set item two $prop
				dict set items $item_id [type_obj $item]
			}
		}		
	}
	return $items
}

proc build_dt_item { item_id vertex_id type parent text} {
	lassign [
		gdb eval {
			select b
			from items
			where item_id = :item_id
		}
	] b
	set one [ get_link $vertex_id 1 ]
	set two [ get_link $vertex_id 2 ]
	set item [ dict create type [type_str $type] content [type_str $text] ]
	if { $type == "if" } {
		dict set item type [type_str "question"]
		if { $b == 1 } {
			dict set item flag1 [type_num 1]
		} else {
			dict set item flag1 [type_num 0]
		}
		dict set item one [type_str $one]
		dict set item two [type_str $two]
	} elseif { $type == "loopstart" } {
		dict set item type [type_str "loopbegin"]
		dict set item one [type_str $two]
		dict set item content [type_str [strip_foreach $text]]
	} elseif { $type == "loopend" } {
		set one [get_one_from_loopstart $parent]
		dict set item one [type_str $one]
	} elseif { $type == "branch" } {
		dict set item branchId [type_num [ get_branch_ordinal $vertex_id ]]
		dict set item one [type_str $one]
	} else {
		if {$type == "beginend"} {
			dict set item type [type_str "end"]
		}
		if { $one != "" } {
			dict set item one [type_str $one]
		}
		if { $two != "" } {
			dict set item two [type_str $two]
		}

		if {$type == "action" && $one == ""} {
			return ""
		}
	}

	return [type_obj $item]		
}

proc type_str {value} {
	return [list str $value]
}

proc type_num {value} {
	return [list num $value]
}

proc type_obj {value} {
	return [list obj $value]
}

proc type_bool {value} {
	if {$value} {
		set bool_value true
	} else {
		set bool_value false
	}
	return [list bool $bool_value]
}

proc get_branch_ordinal { vertex_id } {
	set dst_vertex [ gdb onecolumn {
		select dst
		from links
		where src = :vertex_id and ordinal = 1
	}]
	set ordinal [gdb onecolumn {
		select ordinal
		from branches
		where first_icon = :dst_vertex
	}]
	return $ordinal
}

proc get_one_from_loopstart { parent } {
	set parent_vertex [gdb onecolumn {
		select vertex_id
		from vertices
		where vertex_id = :parent
	}]
	return [get_link $parent_vertex 1]
}

proc strip_foreach { text } {
	if {[string first "foreach " $text] == 0} {
		set x [string range $text 8 end]
	} else {
		set x $text
	}
	return $x
}

proc get_link { vertex_id ordinal } {
	set result [get_link_core $vertex_id $ordinal]

	return [format "%s" $result]
}

proc get_link_core { vertex_id ordinal } {
	set dst_vertex [ gdb onecolumn {
		select dst
		from links
		where src = :vertex_id and ordinal = :ordinal
	}]
	if { $dst_vertex == "" } {
		return ""
	}
	set result [ gdb onecolumn {
		select item_id
		from vertices
		where vertex_id = :dst_vertex
	}]

	return $result
}

proc toJson {value} {
    if {[llength $value] != 2} {
        error "Invalid encoded value: expected {type value}, got: $value"
    }

    set type [lindex $value 0]
    set data [lindex $value 1]

    switch -- $type {
        str {
            return [json::write string $data]
        }
		bool {
			return $data
		}
        num {
            if {
                ![string is integer -strict $data] &&
                ![string is double -strict $data]
            } {
                error "Invalid number: $data"
            }
            return $data
        }
        obj {
            set parts {}
            dict for {key subvalue} $data {
                lappend parts $key [toJson $subvalue]
            }
            return [json::write object {*}$parts]
        }
        default {
            error "Unknown type: $type"
        }
    }
}

proc write_file { outputFilename content } {
	set f [open $outputFilename w]
	fconfigure $f -encoding utf-8
	puts -nonewline $f $content
	close $f
}

proc generate_clean_js { db gdb filename } {
	generate $db $gdb $filename 1
}


proc generate { db gdb filename is_clean} {
    # prepare
    
	variable variables
	set variables {}    
    
	set callbacks [ make_callbacks ]
	lassign [ gen::scan_file_description $db { header footer } ] header footer
	
	# state machines
	
    set machines [ sma::extract_many_machines $gdb $callbacks ]
     
    variable handlers
    set handlers [ append_sm_names $gdb ]
    set machine_ctrs [ make_machine_ctrs $gdb $machines ]

    #set machine_decl [ make_machine_declares $machines ]	
    set machine_decl {}
	
	# fix
	
    set diagrams [ $gdb eval {
        select diagram_id from diagrams } ]
    
    set keys {":" "\{" "\}"}
    
    foreach diagram_id $diagrams {
		if {$is_clean} {
			extract_variables $gdb $diagram_id
			gen::rewrite_clean $gdb $diagram_id $keys
		}
        gen::fix_graph_for_diagram $gdb $callbacks 1 $diagram_id
    }

    if { [ graph::errors_occured ] } { return }
    
    # generate
    
	set use_nogoto 1
	set functions [ gen::generate_functions $db $gdb $callbacks $use_nogoto ]
	
	set functions [ build_tasks $functions ]

	if { [ graph::errors_occured ] } { return }

    # write output
    
	set hfile [ replace_extension $filename "js" ]
	set f [ open_output_file $hfile ]
	catch {
		p.print_to_file $f $functions $header $footer $machine_decl $machine_ctrs
	} error_message

	catch { close $f }
	if { $error_message != "" } {
		error $error_message
	}
}

proc make_machine_ctrs { gdb machines } {
    set result ""
    foreach machine $machines {
        set states [ dict get $machine "states"]
        set param_names [ dict get $machine "param_names" ]
        set messages [ dict get $machine "messages" ]
        set name [ dict get $machine "name" ]

        set ctr [make_machine_ctr $gdb $name $states $param_names $messages]

        append result "\n$ctr\n"
    }
    return $result
}

proc get_function { gdb name state message} {
    set diagram_name "${name}_${state}_${message}"
    set found [ $gdb onecolumn {
        select count(*)
        from diagrams
        where name = :diagram_name
    } ]
    
    if { $found == 1 } {
        return $diagram_name
    } else {
        return "function\(\) \{\}"
    }
}

proc make_machine_ctr { gdb name states param_names messages } {
    set lines {}
    
    if {0} {
		foreach state $states {
			foreach message $messages {
				set fun [ get_function $gdb $name $state $message ]
				lappend lines \
				 "${name}_state_${state}.$message = $fun;"            
			}
			lappend lines "${name}_state_${state}.state_name = \"$state\";"
		}
	}
    
    
    set params [ lrange $param_names 1 end ]
    set params_str [ join $params ", " ]

    lappend lines "function ${name}\(\) \{"

    lappend lines \
     "  var _self = this;"
    lappend lines \
     "  _self.type_name = \"$name\";"

    set first [ lindex $states 0 ]
    lappend lines "  _self.state = \"${first}\";"
    
    foreach message $messages {
        lappend lines \
         "  _self.$message = function\($params_str\) \{"
        
        lappend lines \
         "    var _state_ = _self.state;"
        set first 1
        foreach state $states {

			set call ""
			set method [gen::make_normal_state_method $name $state $message ]
			if {[gen::diagram_exists $gdb $method ]} {
				set call "      return ${method}(_self, $params_str\);"
			} else {
				set method [gen::make_default_state_method $name $state]
				if {[gen::diagram_exists $gdb $method ]} {
					set call "      return ${method}(_self, $params_str\);"
				}				
			}

			if { $call != "" } {
				if {$first} {
					lappend lines \
					 "    if \(_state_ == \"$state\"\) \{"
				} else {
					lappend lines \
					 "    else if \(_state_ == \"$state\"\) \{"				
				}
				
				lappend lines $call				
				
				lappend lines \
				 "    \}"
				 
				 set first 0
			}
		}
        lappend lines \
         "    return null;"
        lappend lines \
         "  \};"
    }
    
    lappend lines \
     "\}"
    
    return [ join $lines "\n" ]
}

proc make_machine_declares { machines } {
    set lines {}
    foreach machine $machines {
        set states [ dict get $machine "states"]
        set name [ dict get $machine "name" ]
        foreach state $states {
            lappend lines "var ${name}_state_${state} = \{\};"
        }
    }
    return [ join $lines "\n" ]
}

proc append_sm_names { gdb } {
    #item 1852
    set ids {}
    #item 1825
    $gdb eval {
    	select diagram_id, original, name
    	from diagrams
    	where original is not null
    } {
    	set sm_name $original
    	set new_name "${sm_name}_$name"
    	$gdb eval {
    		update diagrams
    		set name = :new_name
    		where diagram_id = :diagram_id
    	}
    	lappend ids $new_name
    }
    #item 1853
    return $ids
}

proc is_closure { name } {
    if { [ string match "* function" $name ] } {
        return 1
    }
    
    if { [ string match "*=function" $name ] } {
        return 1
    }
    
    return 0
}    

proc build_declaration { name signature } {
	lassign $signature type access parameters returns
	if { [ is_closure $name ] } {
        set result "$name\("
    } else {
        set result "function $name\("
    }
    
	set params [ gen::get_param_names $parameters ]
	set params_list [ join $params ", " ]
	append result $params_list
	append result "\) \{"
	return $result
}

proc p.print_to_file { fhandle functions header footer machine_decl machine_ctrs } {
	variable variables
	if { $header != "" } {
		puts $fhandle $header
	}
	set version [ version_string ]
	puts $fhandle \
	    "// Autogenerated with DRAKON Editor $version"

    puts $fhandle $machine_decl
	foreach function $functions {
		lassign $function diagram_id name signature body
		set name [ normalize_name $name ]
		set type [ lindex $signature 0 ]
		if { $type != "comment" } {
			puts $fhandle ""
			set declaration [ build_declaration $name $signature ]
			puts $fhandle $declaration
			set vars [gen::print_variables $variables $diagram_id $signature "var"]
			if {$vars != "" } {
				puts $fhandle $vars
			}
			set lines [ gen::indent $body 1 ]
			puts $fhandle $lines
			puts $fhandle "\}"
		}
	}
	puts $fhandle $machine_ctrs
	puts $fhandle ""
	puts $fhandle $footer
}





}

