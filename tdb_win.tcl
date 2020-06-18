#!/usr/bin/wish
#
# GUI Debugger Frontend for GDB (unix/win).

#############################################################################
# By George Peter Staplin
# See also the README for a list of contributors
# RCS: @(#) $Id: ctext.tcl,v 1.9 2011/04/18 19:49:48 andreas_kupries Exp $

package require Tk
package provide ctext 3.3

namespace eval ctext {}

#win is used as a unique token to create arrays for each ctext instance
proc ctext::getAr {win suffix name} {
    set arName __ctext[set win][set suffix]
    uplevel [list upvar \#0 $arName $name]
    return $arName
}

proc ctext {win args} {
    if {[llength $args] & 1} {
		return -code error \
		    "invalid number of arguments given to ctext (uneven number after window) : $args"
    }

    frame $win -class Ctext

    set tmp [text .__ctextTemp]

    ctext::getAr $win config ar

    set ar(-fg) [$tmp cget -foreground]
    set ar(-bg) [$tmp cget -background]
    set ar(-font) [$tmp cget -font]
    set ar(-relief) [$tmp cget -relief]
    destroy $tmp
    set ar(-yscrollcommand) ""
    set ar(-linemap) 1
    set ar(-linemapfg) $ar(-fg)
    set ar(-linemapbg) $ar(-bg)
    set ar(-linemap_mark_command) {}
    set ar(-linemap_markable) 1
    set ar(-linemap_select_fg) black
    set ar(-linemap_select_bg) yellow
    set ar(-tabset) 4
    set ar(-highlight) 1
    set ar(win) $win
    set ar(modified) 0
    set ar(commentsAfterId) ""
    set ar(highlightAfterId) ""
    set ar(blinkAfterId) ""
    set ar(commentColor) grey

    set ar(ctextFlags) [list -yscrollcommand -linemap -linemapfg -linemapbg \
		            -font -linemap_mark_command -highlight -linemap_markable \
		            -linemap_select_fg \
		            -linemap_select_bg -tabset]

    array set ar $args

    foreach flag {foreground background} short {fg bg} {
	if {[info exists ar(-$flag)] == 1} {
	    set ar(-$short) $ar(-$flag)
	    unset ar(-$flag)
	}
    }

    # Now remove flags that will confuse text and those that need
    # modification:
    foreach arg $ar(ctextFlags) {
		if {[set loc [lsearch $args $arg]] >= 0} {
		    set args [lreplace $args $loc [expr {$loc + 1}]]
		}
    }

    text $win.l -font $ar(-font) -width 1 -height 1 \
		-relief $ar(-relief) -fg $ar(-linemapfg) \
		-bg $ar(-linemapbg) -takefocus 0

    set topWin [winfo toplevel $win]
    bindtags $win.l [list $win.l $topWin all]

    if {$ar(-linemap) == 1} {
		grid $win.l -sticky ns -row 0 -column 0
    }

    set args [concat $args [list -yscrollcommand \
		[list ctext::event:yscroll $win $ar(-yscrollcommand)]]]

    #escape $win, because it could have a space
    eval text \$win.t -font \$ar(-font) $args

    grid $win.t -row 0 -column 1 -sticky news
    grid rowconfigure $win 0 -weight 100
    grid columnconfigure $win 1 -weight 100

    $win.t configure -tabs "[expr {$ar(-tabset) * [font measure $ar(-font) 0]}] left" -tabstyle wordprocessor

    bind $win.t <Configure> [list ctext::linemapUpdate $win]
    bind $win.l <ButtonPress-1> [list ctext::linemapToggleMark $win %y]
    bind $win.t <KeyRelease-Return> [list ctext::linemapUpdate $win]
    rename $win __ctextJunk$win
    rename $win.t $win._t

    bind $win <Destroy> [list ctext::event:Destroy $win %W]
    bindtags $win.t [linsert [bindtags $win.t] 0 $win]

    interp alias {} $win {} ctext::instanceCmd $win
    interp alias {} $win.t {} $win

    # If the user wants C comments they should call
    # ctext::enableComments
    ctext::disableComments $win
    ctext::modified $win 0
    ctext::buildArgParseTable $win

    return $win
}

proc ctext::event:yscroll {win clientData args} {
    ctext::linemapUpdate $win

    if {$clientData == ""} {
	return
    }
    uplevel \#0 $clientData $args
}

proc ctext::event:Destroy {win dWin} {
    if {![string equal $win $dWin]} {
	return
    }

    ctext::getAr $win config configAr

    catch {after cancel $configAr(commentsAfterId)}
    catch {after cancel $configAr(highlightAfterId)}
    catch {after cancel $configAr(blinkAfterId)}

    catch {rename $win {}}
    interp alias {} $win.t {}
    ctext::clearHighlightClasses $win
    array unset [ctext::getAr $win config ar]
}

# This stores the arg table within the config array for each instance.
# It's used by the configure instance command.
proc ctext::buildArgParseTable win {
    set argTable [list]

    lappend argTable any -linemap_mark_command {
		set configAr(-linemap_mark_command) $value
		break
    }

    lappend argTable {1 true yes} -linemap {
		grid $self.l -sticky ns -row 0 -column 0
		grid columnconfigure $self 0 -minsize [winfo reqwidth $self.l]
		set configAr(-linemap) 1
		break
    }

    lappend argTable {0 false no} -linemap {
		grid forget $self.l
		grid columnconfigure $self 0 -minsize 0
		set configAr(-linemap) 0
		break
    }

    lappend argTable any -yscrollcommand {
		set cmd [list $self._t config -yscrollcommand \
		     [list ctext::event:yscroll $self $value]]

		if {[catch $cmd res]} {
		    return $res
		}
		set configAr(-yscrollcommand) $value
		break
    }

    lappend argTable any -linemapfg {
		if {[catch {winfo rgb $self $value} res]} {
		    return -code error $res
		}
		$self.l config -fg $value
		set configAr(-linemapfg) $value
		break
    }

    lappend argTable any -linemapbg {
		if {[catch {winfo rgb $self $value} res]} {
		    return -code error $res
		}
		$self.l config -bg $value
		set configAr(-linemapbg) $value
		break
    }

    lappend argTable any -font {
		if {[catch {$self.l config -font $value} res]} {
		    return -code error $res
		}
		$self._t config -font $value
		set configAr(-font) $value
		break
    }

    lappend argTable {0 false no} -highlight {
		set configAr(-highlight) 0
		break
    }

    lappend argTable {1 true yes} -highlight {
		set configAr(-highlight) 1
		break
    }

    lappend argTable {0 false no} -linemap_markable {
		set configAr(-linemap_markable) 0
		break
    }

    lappend argTable {1 true yes} -linemap_markable {
	set configAr(-linemap_markable) 1
	break
    }

    lappend argTable any -linemap_select_fg {
		if {[catch {winfo rgb $self $value} res]} {
		    return -code error $res
		}
		set configAr(-linemap_select_fg) $value
		$self.l tag configure lmark -foreground $value
		break
    }

    lappend argTable any -linemap_select_bg {
		if {[catch {winfo rgb $self $value} res]} {
		    return -code error $res
		}
		set configAr(-linemap_select_bg) $value
		$self.l tag configure lmark -background $value
		break
    }

	lappend argTable any -tabset {
		set configAr(-tabset) $value
	    $self._t configure -tabs "[expr {$configAr(-tabset) * [font measure $configAr(-font) 0]}] left" -tabstyle wordprocessor
		break
	}
	
    ctext::getAr $win config ar
    set ar(argTable) $argTable
}

proc ctext::commentsAfterIdle {win} {
    ctext::getAr $win config configAr

    if {"" eq $configAr(commentsAfterId)} {
	set configAr(commentsAfterId) [after idle \
	   [list ctext::comments $win [set afterTriggered 1]]]
    }
}

proc ctext::highlightAfterIdle {win lineStart lineEnd} {
    ctext::getAr $win config configAr

    if {"" eq $configAr(highlightAfterId)} {
	set configAr(highlightAfterId) [after idle \
	    [list ctext::highlight $win $lineStart $lineEnd [set afterTriggered 1]]]
    }
}

proc ctext::instanceCmd {self cmd args} {
    #slightly different than the RE used in ctext::comments
    set commentRE {\"|\\|'|/|\*}

    switch -glob -- $cmd {
    see {
	    $self._t see $args
    }
	append {
	    if {[catch {$self._t get sel.first sel.last} data] == 0} {
		clipboard append -displayof $self $data
	    }
	}

	cget {
	    set arg [lindex $args 0]
	    ctext::getAr $self config configAr

	    foreach flag $configAr(ctextFlags) {
		        if {[string match ${arg}* $flag]} {
		            return [set configAr($flag)]
		        }
	    }
	    return [$self._t cget $arg]
	}

	conf* {
	    ctext::getAr $self config configAr
	    if {0 == [llength $args]} {
		        set res [$self._t configure]
		        set del [lsearch -glob $res -yscrollcommand*]
		        set res [lreplace $res $del $del]
		        foreach flag $configAr(ctextFlags) {
		            lappend res [list $flag [set configAr($flag)]]
		        }
		        return $res
	    }

	    array set flags {}
	    foreach flag $configAr(ctextFlags) {
		        set loc [lsearch $args $flag]
		        if {$loc < 0} {
		            continue
		        }

		        if {[llength $args] <= ($loc + 1)} {
		            #.t config -flag
		            return [set configAr($flag)]
		        }
	
		        set flagArg [lindex $args [expr {$loc + 1}]]
		        set args [lreplace $args $loc [expr {$loc + 1}]]
		        set flags($flag) $flagArg
		}
	
		foreach {valueList flag cmd} $configAr(argTable) {
		        if {[info exists flags($flag)]} {
		            foreach valueToCheckFor $valueList {
		                        set value [set flags($flag)]
		                        if {[string equal "any" $valueToCheckFor]} $cmd \
		                    elseif {[string equal $valueToCheckFor [set flags($flag)]]} $cmd
		            }
		        }
	    }

	    if {[llength $args]} {
		#we take care of configure without args at the top of this branch
		uplevel 1 [linsert $args 0 $self._t configure]
	    }
	}

	copy {
	    tk_textCopy $self
	}

	cut {
	    if {[catch {$self.t get sel.first sel.last} data] == 0} {
		clipboard clear -displayof $self.t
		clipboard append -displayof $self.t $data
		$self delete [$self.t index sel.first] [$self.t index sel.last]
		ctext::modified $self 1
	    }
	}

	delete {
	    #delete n.n ?n.n

	    set argsLength [llength $args]

	    #first deal with delete n.n
	    if {$argsLength == 1} {
		set deletePos [lindex $args 0]
		set prevChar [$self._t get $deletePos]

		$self._t delete $deletePos
		set char [$self._t get $deletePos]

		set prevSpace [ctext::findPreviousSpace $self._t $deletePos]
		set nextSpace [ctext::findNextSpace $self._t $deletePos]

		set lineStart [$self._t index "$deletePos linestart"]
		set lineEnd [$self._t index "$deletePos + 1 chars lineend"]

		#This pattern was used in 3.1.  We may want to investigate using it again
		#eventually to reduce flicker.  It caused a bug with some patterns.
		#if {[string equal $prevChar "#"] || [string equal $char "#"]} {
		#        set removeStart $lineStart
		#        set removeEnd $lineEnd
		#} else {
		#        set removeStart $prevSpace
		#        set removeEnd $nextSpace
		#}
		set removeStart $lineStart
		set removeEnd $lineEnd

		foreach tag [$self._t tag names] {
		    if {[string equal $tag "_cComment"] != 1} {
		        $self._t tag remove $tag $removeStart $removeEnd
		    }
		}

		set checkStr "$prevChar[set char]"

		if {[regexp $commentRE $checkStr]} {
		    ctext::commentsAfterIdle $self
		}

		ctext::highlightAfterIdle $self $lineStart $lineEnd
		ctext::linemapUpdate $self
	    } elseif {$argsLength == 2} {
		#now deal with delete n.n ?n.n?
		set deleteStartPos [lindex $args 0]
		set deleteEndPos [lindex $args 1]

		set data [$self._t get $deleteStartPos $deleteEndPos]

		set lineStart [$self._t index "$deleteStartPos linestart"]
		set lineEnd [$self._t index "$deleteEndPos + 1 chars lineend"]
		eval \$self._t delete $args

		foreach tag [$self._t tag names] {
		    if {[string equal $tag "_cComment"] != 1} {
		        $self._t tag remove $tag $lineStart $lineEnd
		    }
		}

		if {[regexp $commentRE $data]} {
		    ctext::commentsAfterIdle $self
		}

		ctext::highlightAfterIdle $self $lineStart $lineEnd
		if {[string first "\n" $data] >= 0} {
		    ctext::linemapUpdate $self
		}
	    } else {
		return -code error "invalid argument(s) sent to $self delete: $args"
	    }
	    ctext::modified $self 1
	}

	fastdelete {
	    eval \$self._t delete $args
	    ctext::modified $self 1
	    ctext::linemapUpdate $self
	}

	fastinsert {
	    eval \$self._t insert $args
	    ctext::modified $self 1
	    ctext::linemapUpdate $self
	}

	highlight {
	    ctext::highlight $self [lindex $args 0] [lindex $args 1]
	    ctext::comments $self
	}

	insert {
	    if {[llength $args] < 2} {
		return -code error "please use at least 2 arguments to $self insert"
	    }

	    set insertPos [lindex $args 0]
	    set prevChar [$self._t get "$insertPos - 1 chars"]
	    set nextChar [$self._t get $insertPos]
	    set lineStart [$self._t index "$insertPos linestart"]
	    set prevSpace [ctext::findPreviousSpace $self._t ${insertPos}-1c]
	    set data [lindex $args 1]
	    eval \$self._t insert $args

	    set nextSpace [ctext::findNextSpace $self._t insert]
	    set lineEnd [$self._t index "insert lineend"]

	    if {[$self._t compare $prevSpace < $lineStart]} {
		set prevSpace $lineStart
	    }

	    if {[$self._t compare $nextSpace > $lineEnd]} {
		set nextSpace $lineEnd
	    }

	    foreach tag [$self._t tag names] {
		if {[string equal $tag "_cComment"] != 1} {
		    $self._t tag remove $tag $prevSpace $nextSpace
		}
	    }

	    set REData $prevChar
	    append REData $data
	    append REData $nextChar
	    if {[regexp $commentRE $REData]} {
		ctext::commentsAfterIdle $self
	    }

	    ctext::highlightAfterIdle $self $lineStart $lineEnd

	    switch -- $data {
		"\}" {
		    ctext::matchPair $self "\\\{" "\\\}" "\\"
		}
		"\]" {
		    ctext::matchPair $self "\\\[" "\\\]" "\\"
		}
		"\)" {
		    ctext::matchPair $self "\\(" "\\)" ""
		}
		"\"" {
		    ctext::matchQuote $self
		}
	    }
	    ctext::modified $self 1
	    ctext::linemapUpdate $self
	}

	paste {
	    tk_textPaste $self
	    ctext::modified $self 1
	}

	edit {
	    set subCmd [lindex $args 0]
	    set argsLength [llength $args]

	    ctext::getAr $self config ar

	    if {"modified" == $subCmd} {
		if {$argsLength == 1} {
		    return $ar(modified)
		} elseif {$argsLength == 2} {
		    set value [lindex $args 1]
		    set ar(modified) $value
		} else {
		    return -code error "invalid arg(s) to $self edit modified: $args"
		}
	    } else {
		#Tk 8.4 has other edit subcommands that I don't want to emulate.
		return [uplevel 1 [linsert $args 0 $self._t $cmd]]
	    }
	}

	default {
	    return [uplevel 1 [linsert $args 0 $self._t $cmd]]
	}
    }
}

proc ctext::tag:blink {win count {afterTriggered 0}} {
    if {$count & 1} {
	$win tag configure __ctext_blink \
	    -foreground [$win cget -bg] -background [$win cget -fg]
    } else {
	$win tag configure __ctext_blink \
	    -foreground [$win cget -fg] -background [$win cget -bg]
    }

    ctext::getAr $win config configAr
    if {$afterTriggered} {
	set configAr(blinkAfterId) ""
    }

    if {$count == 4} {
	$win tag delete __ctext_blink 1.0 end
	return
    }

    incr count
    if {"" eq $configAr(blinkAfterId)} {
	set configAr(blinkAfterId) [after 50 \
		[list ctext::tag:blink $win $count [set afterTriggered 1]]]
    }
}

proc ctext::matchPair {win str1 str2 escape} {
    set prevChar [$win get "insert - 2 chars"]

    if {[string equal $prevChar $escape]} {
	#The char that we thought might be the end is actually escaped.
	return
    }

    set searchRE "[set str1]|[set str2]"
    set count 1

    set pos [$win index "insert - 1 chars"]
    set endPair $pos
    set lastFound ""
    while 1 {
	set found [$win search -backwards -regexp $searchRE $pos]

	if {$found == "" || [$win compare $found > $pos]} {
	    return
	}

	if {$lastFound != "" && [$win compare $found == $lastFound]} {
	    #The search wrapped and found the previous search
	    return
	}

	set lastFound $found
	set char [$win get $found]
	set prevChar [$win get "$found - 1 chars"]
	set pos $found

	if {[string equal $prevChar $escape]} {
	    continue
	} elseif {[string equal $char [subst $str2]]} {
	    incr count
	} elseif {[string equal $char [subst $str1]]} {
	    incr count -1
	    if {$count == 0} {
		set startPair $found
		break
	    }
	} else {
	    # This shouldn't happen.  I may in the future make it
	    # return -code error
	    puts stderr "ctext seems to have encountered a bug in ctext::matchPair"
	    return
	}
    }

    $win tag add __ctext_blink $startPair
    $win tag add __ctext_blink $endPair
    ctext::tag:blink $win 0
}

proc ctext::matchQuote {win} {
    set endQuote [$win index insert]
    set start [$win index "insert - 1 chars"]

    if {[$win get "$start - 1 chars"] == "\\"} {
	#the quote really isn't the end
	return
    }
    set lastFound ""
    while 1 {
	set startQuote [$win search -backwards \" $start]
	if {$startQuote == "" || [$win compare $startQuote > $start]} {
	    #The search found nothing or it wrapped.
	    return
	}

	if {$lastFound != "" && [$win compare $lastFound == $startQuote]} {
	    #We found the character we found before, so it wrapped.
	    return
	}
	set lastFound $startQuote
	set start [$win index "$startQuote - 1 chars"]
	set prevChar [$win get $start]

	if {$prevChar == "\\"} {
	    continue
	}
	break
    }

    if {[$win compare $endQuote == $startQuote]} {
	#probably just \"
	return
    }

    $win tag add __ctext_blink $startQuote $endQuote
    ctext::tag:blink $win 0
}

proc ctext::setCommentsColor {win color} {
	ctext::getAr $win config configAr
	set configAr(commentColor) $color
}

proc ctext::enableComments {win} {
	ctext::getAr $win config configAr
    $win tag configure _cComment -foreground $configAr(commentColor)
}
proc ctext::disableComments {win} {
    catch {$win tag delete _cComment}
}

proc ctext::comments {win {afterTriggered 0}} {
    if {[catch {$win tag cget _cComment -foreground}]} {
	#C comments are disabled
	return
    }

    if {$afterTriggered} {
	ctext::getAr $win config configAr
	set configAr(commentsAfterId) ""
    }

    set startIndex 1.0
    set commentRE {\\\\|\"|\\\"|\\'|'|/\*|\*/}
    set commentStart 0
    set isQuote 0
    set isSingleQuote 0
    set isComment 0
    $win tag remove _cComment 1.0 end
    while 1 {
	set index [$win search -count length -regexp $commentRE $startIndex end]

	if {$index == ""} {
	    break
	}

	set endIndex [$win index "$index + $length chars"]
	set str [$win get $index $endIndex]
	set startIndex $endIndex

	if {$str == "\\\\"} {
	    continue
	} elseif {$str == "\\\""} {
	    continue
	} elseif {$str == "\\'"} {
	    continue
	} elseif {$str == "\"" && $isComment == 0 && $isSingleQuote == 0} {
	    if {$isQuote} {
		set isQuote 0
	    } else {
		set isQuote 1
	    }
	} elseif {$str == "'" && $isComment == 0 && $isQuote == 0} {
	    if {$isSingleQuote} {
		set isSingleQuote 0
	    } else {
		set isSingleQuote 1
	    }
	} elseif {$str == "/*" && $isQuote == 0 && $isSingleQuote == 0} {
	    if {$isComment} {
		#comment in comment
		break
	    } else {
		set isComment 1
		set commentStart $index
	    }
	} elseif {$str == "*/" && $isQuote == 0 && $isSingleQuote == 0} {
	    if {$isComment} {
		set isComment 0
		$win tag add _cComment $commentStart $endIndex
		$win tag raise _cComment
	    } else {
		#comment end without beginning
		break
	    }
	}
    }
}

proc ctext::addHighlightClass {win class color keywords} {
    set ref [ctext::getAr $win highlight ar]
    foreach word $keywords {
	set ar($word) [list $class $color]
    }
    $win tag configure $class

    ctext::getAr $win classes classesAr
    set classesAr($class) [list $ref $keywords]
}

#For [ ] { } # etc.
proc ctext::addHighlightClassForSpecialChars {win class color chars} {
    set charList [split $chars ""]

    set ref [ctext::getAr $win highlightSpecialChars ar]
    foreach char $charList {
	set ar($char) [list $class $color]
    }
    $win tag configure $class

    ctext::getAr $win classes classesAr
    set classesAr($class) [list $ref $charList]
}

proc ctext::addHighlightClassForRegexp {win class color re} {
    set ref [ctext::getAr $win highlightRegexp ar]

    set ar($class) [list $re $color]
    $win tag configure $class

    ctext::getAr $win classes classesAr
    set classesAr($class) [list $ref $class]
}

#For things like $blah
proc ctext::addHighlightClassWithOnlyCharStart {win class color char} {
    set ref [ctext::getAr $win highlightCharStart ar]

    set ar($char) [list $class $color]
    $win tag configure $class

    ctext::getAr $win classes classesAr
    set classesAr($class) [list $ref $char]
}

proc ctext::deleteHighlightClass {win classToDelete} {
    ctext::getAr $win classes classesAr

    if {![info exists classesAr($classToDelete)]} {
	return -code error "$classToDelete doesn't exist"
    }

    foreach {ref keyList} [set classesAr($classToDelete)] {
	upvar #0 $ref refAr
	foreach key $keyList {
	    if {![info exists refAr($key)]} {
		continue
	    }
	    unset refAr($key)
	}
    }
    unset classesAr($classToDelete)
}

proc ctext::getHighlightClasses win {
    ctext::getAr $win classes classesAr

    array names classesAr
}

proc ctext::findNextChar {win index char} {
    set i [$win index "$index + 1 chars"]
    set lineend [$win index "$i lineend"]
    while 1 {
	set ch [$win get $i]
	if {[$win compare $i >= $lineend]} {
	    return ""
	}
	if {$ch == $char} {
	    return $i
	}
	set i [$win index "$i + 1 chars"]
    }
}

proc ctext::findNextSpace {win index} {
    set i [$win index $index]
    set lineStart [$win index "$i linestart"]
    set lineEnd [$win index "$i lineend"]
    #Sometimes the lineend fails (I don't know why), so add 1 and try again.
    if {[$win compare $lineEnd == $lineStart]} {
	set lineEnd [$win index "$i + 1 chars lineend"]
    }

    while {1} {
	set ch [$win get $i]

	if {[$win compare $i >= $lineEnd]} {
	    set i $lineEnd
	    break
	}

	if {[string is space $ch]} {
	    break
	}
	set i [$win index "$i + 1 chars"]
    }
    return $i
}

proc ctext::findPreviousSpace {win index} {
    set i [$win index $index]
    set lineStart [$win index "$i linestart"]
    while {1} {
	set ch [$win get $i]

	if {[$win compare $i <= $lineStart]} {
	    set i $lineStart
	    break
	}

	if {[string is space $ch]} {
	    break
	}

	set i [$win index "$i - 1 chars"]
    }
    return $i
}

proc ctext::clearHighlightClasses {win} {
    #no need to catch, because array unset doesn't complain
    #puts [array exists ::ctext::highlight$win]

    ctext::getAr $win highlight ar
    array unset ar

    ctext::getAr $win highlightSpecialChars ar
    array unset ar

    ctext::getAr $win highlightRegexp ar
    array unset ar

    ctext::getAr $win highlightCharStart ar
    array unset ar

    ctext::getAr $win classes ar
    array unset ar
}

#This is a proc designed to be overwritten by the user.
#It can be used to update a cursor or animation while
#the text is being highlighted.
proc ctext::update {} {

}

proc ctext::highlight {win start end {afterTriggered 0}} {
    ctext::getAr $win config configAr

    if {$afterTriggered} {
	set configAr(highlightAfterId) ""
    }

    if {!$configAr(-highlight)} {
	return
    }

    set si $start
    set twin "$win._t"

    #The number of times the loop has run.
    set numTimesLooped 0
    set numUntilUpdate 600

    ctext::getAr $win highlight highlightAr
    ctext::getAr $win highlightSpecialChars highlightSpecialCharsAr
    ctext::getAr $win highlightRegexp highlightRegexpAr
    ctext::getAr $win highlightCharStart highlightCharStartAr

    while 1 {
	set res [$twin search -count length -regexp -- {([^\s\(\{\[\}\]\)\.\t\n\r;\"'\|,]+)} $si $end]
	if {$res == ""} {
	    break
	}

	set wordEnd [$twin index "$res + $length chars"]
	set word [$twin get $res $wordEnd]
	set firstOfWord [string index $word 0]

	if {[info exists highlightAr($word)] == 1} {
	    set wordAttributes [set highlightAr($word)]
	    foreach {tagClass color} $wordAttributes break

	    $twin tag add $tagClass $res $wordEnd
	    $twin tag configure $tagClass -foreground $color

	} elseif {[info exists highlightCharStartAr($firstOfWord)] == 1} {
	    set wordAttributes [set highlightCharStartAr($firstOfWord)]
	    foreach {tagClass color} $wordAttributes break

	    $twin tag add $tagClass $res $wordEnd
	    $twin tag configure $tagClass -foreground $color
	}
	set si $wordEnd

	incr numTimesLooped
	if {$numTimesLooped >= $numUntilUpdate} {
	    ctext::update
	    set numTimesLooped 0
	}
    }

    foreach {ichar tagInfo} [array get highlightSpecialCharsAr] {
	set si $start
	foreach {tagClass color} $tagInfo break

	while 1 {
	    set res [$twin search -- $ichar $si $end]
	    if {"" == $res} {
		break
	    }
	    set wordEnd [$twin index "$res + 1 chars"]

	    $twin tag add $tagClass $res $wordEnd
	    $twin tag configure $tagClass -foreground $color
	    set si $wordEnd

	    incr numTimesLooped
	    if {$numTimesLooped >= $numUntilUpdate} {
		ctext::update
		set numTimesLooped 0
	    }
	}
    }

    foreach {tagClass tagInfo} [array get highlightRegexpAr] {
	set si $start
	foreach {re color} $tagInfo break
	while 1 {
	    set res [$twin search -nolinestop -count length -regexp -- $re $si $end]
	    if {"" == $res} {
		break
	    }

	    set wordEnd [$twin index "$res + $length chars"]
	    $twin tag add $tagClass $res $wordEnd
	    $twin tag configure $tagClass -foreground $color
	    set si $wordEnd

	    incr numTimesLooped
	    if {$numTimesLooped >= $numUntilUpdate} {
		ctext::update
		set numTimesLooped 0
	    }
	}
    }
}

proc ctext::linemapToggleMark {win y} {
    ctext::getAr $win config configAr

    if {!$configAr(-linemap_markable)} {
	return
    }

    set markChar [$win.l index @0,$y]
    set lineSelected [lindex [split $markChar .] 0]
    set line [$win.l get $lineSelected.0 $lineSelected.end]

    if {$line == ""} {
	return
    }

    ctext::getAr $win linemap linemapAr

    if {[info exists linemapAr($line)] == 1} {
	#It's already marked, so unmark it.
	array unset linemapAr $line
	ctext::linemapUpdate $win
	set type unmarked
    } else {
	#This means that the line isn't toggled, so toggle it.
	array set linemapAr [list $line {}]
	$win.l tag add lmark $markChar [$win.l index "$markChar lineend"]
	$win.l tag configure lmark -foreground $configAr(-linemap_select_fg) \
	    -background $configAr(-linemap_select_bg)
	set type marked
    }

    if {[string length $configAr(-linemap_mark_command)]} {
	uplevel #0 [linsert $configAr(-linemap_mark_command) end $win $type $line]
    }
}

#args is here because -yscrollcommand may call it
proc ctext::linemapUpdate {win args} {
    if {[winfo exists $win.l] != 1} {
	return
    }

    set pixel 0
    set lastLine {}
    set lineList [list]
    set fontMetrics [font metrics [$win._t cget -font]]
    set incrBy [expr {1 + ([lindex $fontMetrics 5] / 2)}]

    while {$pixel < [winfo height $win.l]} {
	set idx [$win._t index @0,$pixel]

	if {$idx != $lastLine} {
	    set line [lindex [split $idx .] 0]
	    set lastLine $idx
	    lappend lineList $line
	}
	incr pixel $incrBy
    }

    ctext::getAr $win linemap linemapAr

    $win.l delete 1.0 end
    set lastLine {}
    foreach line $lineList {
	if {$line == $lastLine} {
	    $win.l insert end "\n"
	} else {
	    if {[info exists linemapAr($line)]} {
		$win.l insert end "$line\n" lmark
	    } else {
		$win.l insert end "$line\n"
	    }
	}
	set lastLine $line
    }
    if {[llength $lineList] > 0} {
	linemapUpdateOffset $win $lineList
    }
    set endrow [lindex [split [$win._t index end-1c] .] 0]
    $win.l configure -width [string length $endrow]
}

# Starting with Tk 8.5 the text widget allows smooth scrolling; this
# code calculates the offset for the line numbering text widget and
# scrolls by the specified amount of pixels

if {![catch {
    package require Tk 8.5
}]} {
    proc ctext::linemapUpdateOffset {win lineList} {
	# reset view for line numbering widget
	$win.l yview 0.0

	# find the first line that is visible and calculate the
	# corresponding line in the line numbers widget
	set lline 1
	foreach line $lineList {
	    set tystart [lindex [$win.t bbox $line.0] 1]
	    if {$tystart != ""} {
		break
	    }
	    incr lline
	}

	# return in case the line numbers text widget is not up to
	# date
	if {[catch {
	    set lystart [lindex [$win.l bbox $lline.0] 1]
	}]} {
	    return
	}

	# return in case the bbox for any of the lines returned an
	# empty value
	if {($tystart == "") || ($lystart == "")} {
	    return
	}

	# calculate the offset and then scroll by specified number of
	# pixels
	set offset [expr {$lystart - $tystart}]
	$win.l yview scroll $offset pixels
    }
}  else  {
    # Do not try to perform smooth scrolling if Tk is 8.4 or less.
    proc ctext::linemapUpdateOffset {args} {}
}

proc ctext::modified {win value} {
    ctext::getAr $win config ar
    set ar(modified) $value
    event generate $win <<Modified>>
    return $value
}


#############################################################################
# debug utility
proc stacktrace {} {
    set stack "Stack trace:\n"
    for {set i 1} {$i < [info level]} {incr i} {
        set lvl [info level -$i]
        set pname [lindex $lvl 0]
        append stack [string repeat " " $i]$pname
        foreach value [lrange $lvl 1 end] arg [info args $pname] {
            if {$value eq ""} {
                info default $pname $arg value
            }
            append stack " $arg='$value'"
        }
        append stack \n
    }
    return $stack
}

 package provide Pstack 1.0

 # --------------------------------------------------
 # This package prints the sequence of calls that
 # preceeded the execution of a selected procedure.
 # Arguments are included in the printed output.
 #
 # Place $Pstack::print some where in the
 # procedure you are interested in tracing.
 #
 # Tracr printing is turned on and off with the
 # Pstack::printON and Pstack::printOFF commands.
 # --------------------------------------------------

 namespace eval Pstack {
     variable print
     set print Pstack::OFF
 }

 # ------------------------------
 # turn traccing on/off
 proc Pstack::printON { } {
     variable print
     set print Pstack::ON
 }
 proc Pstack::printOFF { } {
     variable print
     set print Pstack::OFF
 }
 # ------------------------------
 # no output
 proc Pstack::OFF { } { }

 # ------------------------------
 # print proc name and arguments
 proc Pstack::ON { } {
     puts stderr "--- pstack"
     set indent ""
     set up_level [expr [info level]-1]
     for {set i 1} {$i<=[expr [info level]-1]} {incr i} {
         set argList [info level ${i}]
         puts stderr "${indent}[lindex $argList 0] {[lrange $argList 1 end]}"
         append indent "  "
     }
 }
 
Pstack::printON

#############################################################################
proc balloon {w help} {
  bind $w <Any-Enter> "after 1000 [list balloon:show %W [list $help]]"
  bind $w <Any-Leave> "destroy %W.balloon"
}

proc balloon:show {w arg} {
  if {[eval winfo containing  [winfo pointerxy .]]!=$w} {return}
  set top $w.balloon
  catch {destroy $top}
  toplevel $top -bd 1 -bg black
  wm overrideredirect $top 1
  pack [message $top.txt -aspect 10000 -bg lightyellow -text $arg]
  set wmx [winfo rootx $w]
  set wmy [expr [winfo rooty $w]+[winfo height $w]]
  wm geometry $top \
      [winfo reqwidth $top.txt]x[winfo reqheight $top.txt]+$wmx+$wmy
  raise $top
}

#############################################################################
package require msgcat
#source ../ctext/ctext.tcl

namespace eval Tdb {
	set pchelp {
TDB is a simple, ultra-light debugger GUI interface for GDB. The debugger can be started from anywhere (but the project root seems a good idea). 

   tdb math/to/main.elf

The directory containing the executable becomes the default directory and root of the project. All pathes to source files are relative to this place. An project tree example can be:

   project
    +- include
    |   +- xxx.h
    |   `- yyy.h
    +- src
    |   +- xxx.c
    |   `- yyy.c
    +- Makefile
    `- main.elf
   

The GUI is just a window for the currently debugged/viewed source file and another for the log.
   
Commands can be sent to the gdb debugger, directly through the bottom 'GDB' entry or through the toolbar icons and the menu items. Commands sent are logged in the Log window, as well as their result. All gdb commands are available directly via the command/log window. Or use, Auto-step/Auto-next to animate-execute your program, hitting Escape to stop.

Only 1 file can be viewed at a time. But a hook in the file menu is provided to reference source files with the command 'open'
Though, 
      
   open src/main.c lib/*.c
    
will include, in the file menu, 'main.c' and all c files from the 'lib' directory. New files not referenced yet are added to the hook as you step in.
   
I. Debugging session setup and .tdbinit
   ------------------------------------
   The .tdbinit file at the project root contains actions to be done before the debug session can start : reset of the board, connection handling to the target, loading the code, breakpoint on main ...
   
   The first line, starting with #! gives the name of the debugger used. It must be available in the PATH of the system. Then all gdb valid commands can be used in the .tdbinit script, as well as 'open' (not a gdb command).

   * Config example to use the simulator
	#! arm-none-eabi-gdb
	open src/main.s startup/*.s
	target sim
	load
	tb main
	run
   
   
   * Config example to connect to a bare-metal remote target
	#! arm-none-eabi-gdb
	open src/main.c lib/*.c
	target remote localhost:3333
	monitor soft_reset_halt
	monitor mww 0xE01FC040 2
	monitor mww 0xE01FC0C4 0x801817BE
	load
	tbreak main
	continue

   
II.  Debugging
     ---------
     While debugging, the current line to be executed is shown highlighted in blue. Breakpoints are in red, or orange if they are also the current line.

     * Execution commands
	step, next, finish ... 
     
     * Frame context : usefull to navigate up and down through the execution stack. Indeed, you can see the point the processor was interrupted by an IRQ before servicing it.
	up, down
     
     * Breakpoints : double-click on the line (which toggles the line color) or with commands
	break main.c:34
	break 45
	break myfunc
	
	tbreak main.c:34
     for a temporary breakpoint
     
	info break
     for a breakpoint list
     
III. View the variables and memory
     -----------------------------
     * Printing/setting variables/registers
	p a
	print a
	set a=3
	
	p/x a	-- hexa
	p/x $r0	-- hexa
	p/x list->item1
	p *(int*)var
	
     * Watch a variable/register
     display var
     disp/x $pc
     
     * Watchpoints
	watch *(int *) 0x600850
	watch a
	
	info watch
     for a list of watchpoints
     
     * View memory: use the GUI
     
IV. Debugging native app

    Nothing special to be done
	
	tdb main.elf 1 2 3
	
    input/output in console.
	
V.  Debugging fork
VI. Debugging threaded code
A1.  .tdbinit file examples
     a. Linux native
     
	#! gdb
	set inferior-tty /dev/pts/6
	tb main
	run

     if the program uses console io, you have to open an xterm, get the tty with th command
     
     tty
     
     and to provide it to the 'set inferior-tty'
     
     b. Linux remote
     c. Gdb instruction simulator
     d. Bare metal remote target
     
TODO
- fonctionnalité auto-reload quand l'exécutable change
- vue mémoire ?
- vue variables ? 
- vue désassemblée ?
- vue registres ?
- revoir les paramètres optionnels
- opensrc : make a plugin system to add more syntax highliting filters

DONE
v1.1.1 2016.07.01
- add comand line args support for native applications (by Fabrice Harrouet)
- drop support fore core debug
- correction: breakpoint display bug

v1.1.0 2016.06.28
- code cleanup
- the path to the executable is the root of the project. Source files path 
  are relative to this place and must be at the same level or in 
  subdirectories
- bugs correction
  * file normalization relative to executable place whenever possible
  * view the right source file and debug is paused


v1.0 2016.01.28 initial release
- built than enhanced from an old version of tdb (v1.3) by Peter Mc Donald
  http://pdqi.com/browsex/TDB.html
  
  The key ideas were :
  * Learn tcl/tk :-)
  * Make a cross-platform gdb front end with no other dependancies than the 
    basic tcl/tk found on every Linux distro. All the code in a single file.
  * Simplify the GUI : no editing, on project handling. A debugger should be
    used for debugging programs. Project handling through makefile. Just
    enough GUI to ease the developper's life. For rest, rely on gdb capability
    to connect to targets, view variables ...
  * Have a simple configuration format that largely rely on gdb to be able
    to debug any C/C++/ARM asm program running on different target types from
    bare metal target to native programs, to embedded Linux targets debugged
    through the network.
    
- code simplification, GUI review complete event handling review
- syntax highlighting through a modified version of the ctext megawidget
- balloon help
- .tdbinit file contains the target connection parameters and gdb commands to
  be executed when loading the program (before user can interact with it)
- partial gdbmi protocol
- reload fonctionnality with breakpoints keeping


- serial tty
  st -l /dev/ttyUSB0 cs8 115200 &

	}

	# pc : program constants
	set pc(img:cont) [image create photo -format GIF -data {
		R0lGODdhGAAYAIAAAAAAAP///yH5BAEAAAEALAAAAAAYABgAAAIwjI+py+0PDYgOTLrsxUhvHngf
		Jo5RaT5o2qxs5lKxjHK1LYKhp+9W7wPuhCGiUVcAADs=
	}]
	
	set pc(img:stop) [image create photo -format GIF -data {
		R0lGODlhGAAYAKEAAMDAwPgQQPj8+AAAACH5BAEAAAAALAAAAAAYABgAAAJShI+py+0Bo3RH2kiv
		Dm3v5XkJJAhkeZ4mV60uCb9IsEYvjeNzDeemXMn1XkCD7eijoVhG5O03CQ6nvN00WQ0uhcusNGQB
		gaPicQZMaX7S7La7AAA7
	}]
	
	set pc(img:step) [image create photo -format GIF -data {
		R0lGODlhGAAYAMIAAAD/ANQAAGFhYSofVa2trcyZmQAAAAAAACH5BAEAAAAALAAAAAAYABgAAANW
		CLrc/jDKSesMGFsWWt+fByrCsISDIHUlcS5EGnWDCQQF/tUTD+SYgsIXIWYWRIhMkROSbEqoIjSU
		OpaPUs/KSD68XW4DjBQzWo+YaqK9rjfwuHy+SQAAOw==
	}]
	
	set pc(img:stepi) [image create photo -format GIF -data {
		R0lGODlhGAAYAMIAAAD/AMwAM9QAAGFhYSofVcyZma2trQAAACH5BAEAAAAALAAAAAAYABgAAANe
		CLrc/jDKSasMIudglXifFQ4EIBTnRwzSRxoAmhWAsUZq6WULoUc+RkgRlBQBgwOL+IPcFIfogmRs
		JpdMI9ZBrU6VvebjGD2EJ2RpVvKCqm1bSLdMjFOunbx+z+8DEgA7        
	}]
	set pc(img:next) [image create photo -format GIF -data {
		R0lGODlhGAAYAMIAAAD/AMwAM2FhYSofVa2trdQAAMyZmQAAACH5BAEAAAAALAAAAAAYABgAAANV
		CLrc/jDKSesMOOsaZPfUB33CoAwCIz5dSSgEuqxON5jLDRRGYBQSXc7UwxiCuBMuM5EtSoreMSJk
		CGkPpwJqAVS9ycr3SxmHKS6Y1sJdd9/wuDyeAAA7
	}]
	set pc(img:nexti) [image create photo -format GIF -data {
		R0lGODlhGAAYAMIAAAD/AMwAM2FhYSofVQAAANQAAMyZma2trSH5BAEAAAAALAAAAAAYABgAAANf
		CLrc/jDKSesMOOsaZPfUB33CwAiL+HQlIBDogAKq0w0moQN4YQSGggTngvEGP4xhaGIQMxNZEdX6
		LSNEgI6geFKkW1ezQgxnybnd+Wt6xcaU0mFxkFrEC/t9z+/7/QkAOw==
	}]
	set pc(img:finish) [image create photo -format GIF -data {
		R0lGODlhGAAYAMIAAAD/AMwAM2FhYSofVa2trdQAAMyZmQAAACH5BAEAAAAALAAAAAAYABgAAANW
		CLrc/jDKSatVIee7QvMX+FHCAHiDwIhQSZwAkXbTYMKADRRGYBQRHUPXyxiCt4VQI5kxSoreESJs
		LGuqZ5JSVXRr21y4Gf5KXAtZ1gL1rjnwuHxuSQAAOw==
	}]
	set pc(img:until) [image create photo ::img::until -format GIF -data {
		R0lGODlhGAAYAMIAAAD/AMwAM9mfqmFhYSofVaqfqgAAAAAAACH5BAEAAAAALAAAAAAYABgAAANI
		CLrc/jDKSasMwkIRsF5d2CkDoRDDxHlAWSgFemULYda3ZTO71p+5imxR8gWBvhTxOPkBnBQntBmc
		Slywoab4VH6+4LB4XEkAADs=
	}]
	set pc(img:down) [image create photo -format GIF -data {
		R0lGODlhGAAYAOMAAP8A/wAAAH9/fy0tLWFhYf/MZpJVAGlpaW2q/0lVqjMzmUNDQ2b/ZkmqVQAA
		AAAAACH5BAEAAAAALAAAAAAYABgAAARcEMhJq7046827x8EHildITmF6AkLgCivgmthg3/jQwhlR
		/EAgQbYJGI5IJC0zazpnmQMigahardRDZpBQJL5gsHfAfJqXlgVjzW4zFptBY06vN9CWwbkZ6/v/
		IhEAOw==
	}]
	set pc(img:up) [image create photo -format GIF -data {
		R0lGODlhGAAYAOMAAP8A/wAAAH9/fy0tLWFhYf/MZpJVAGlpaW2q/0lVqjMzmUNDQ2b/ZkmqVQAA
		AAAAACH5BAEAAAAALAAAAAAYABgAAARcEMhJq7046827x8F3CYEgVkF6TmRqrmG8TqE23Hgua0Th
		/z8CoJYJGI5IJLGYajqfmQMigahardRDZpBQJL5gsHfAfJpVmQVjzW4zFptBY06vN5aXwRk66/v/
		MxEAOw==
	}]
	set pc(img:backtrace) [image create photo -format GIF -data {
		R0lGODlhGAAYAOMAAP8A/y0tLQAAAGFhYduqVZJVAP8AAJIAAElVqgAAmW2q/22qqkmqVQAAAAAA
		AAAAACH5BAEAAAAALAAAAAAYABgAAARbEMhJq7046827/yAYjGQpdAOhruvQCUUsy6cm3HiOb4Ph
		/8Ca7UAsGoUXnTKXCSCe0Cg0kEkoEIqsVot1YZzSMIKKWZo1g4V6zV54m4y4fM5AXgJmZmjP7/st
		EQA7
	}]
	set pc(img:break) [image create photo -format GIF -data {
		R0lGODlhGAAYAMIAAP8A/////62trXh4eAAAAJIAANuqqgAAACH5BAEAAAAALAAAAAAYABgAAANV
		CLrc/jDKSVe4OAdBtR9dQIxjBk6edkoZSQZrlJoh5l4xNGP5UhiK1g0GMRR+O5zjyDyKhsqHEZns
		KX5B29DaSBJRwheX4R1bqhTBYM1umyvwuPyRAAA7
	}]
	set pc(img:print) [image create photo -format GIF -data {
		R0lGODlhGAAYAOMAAAD/AICAgAAAAKWfo7W5tQcHB2FhYS0wLQICApqZmi8aAgAAAAAAAAAAAAAA
		AAAAACH5BAEAAAAALAAAAAAYABgAAARmEMhJq7046827/1ogCCA1CAFACsNHFMYkGMdXywCBtNxx
		VzSOoUC46HiYxEiRmCQUAoUvkzgUCQdl9XogYRRFCUEBAE/GGS9OLWFXzGIyPEdOWnNZwBbfpEKZ
		Tn99JYSFhoeIiRgRADs=
	}]
	set pc(img:reg) [image create photo -format GIF -data {
		R0lGODlhGAAYAMIAAAD/AMwAAAAAACofVX9/fwAAAAAAAAAAACH5BAEAAAAALAAAAAAYABgAAANO
		CLrc/jDKSesMwcqclfgagC2CZ2EdIAylNpqtS5ohGJICQdjWp/+7WMQHLPIeHyIwKWy0mDomzVF6
		Mp8qSDWrwm6HXMaX0gzfzui02pEAADs=
	}]
	set pc(img:vars) [image create photo -format GIF -data {
		R0lGODlhGAAYAKEAAAD/ACofVQCZZujkryH5BAEAAAAALAAAAAAYABgAAAI/hI+py+0Po5wvUBWy
		0TN7wEXeGFbkKJ6oqa5NS7Kw5XjCnQ16udh4oBvwMJmbILejvYq/WI15PF2m1Kr12igAADs=
	}]
	set pc(img:reload) [image create photo -format GIF -data {
		R0lGODlhGAAYAIYAAPwCBBRSDKS+nLTCrBxWFKzCpIy6fJS6hIy2hIy6hIS2fHyudHyqdCROHAw2
		VAwmBFyGVFySVGyiZGyqbHyydFyaVCRKHLTe7Ex2RHSubFSOTBw+FIzG3ITC1Ex+RERyPEyGRFya
		XGSmXIS+1IzC3IS+3EyOTFymXGyqZBQ2DHS2zHy21DRqNEyKRHSuzAwqBDx2PESaRFSiVBQ+ZGyq
		xGSixFyavARCZBRSFDyCPDyKPESKRFSaVEyeTEyWTCRiHAQuPGSivFSStDR2nDyaRESWRESaTDyS
		PDSKNESGrFSOrER6lBxWdCxuLDyWPBx6JDRulFSSvDRmhBxWfCRuJCyONAwuREyKtDRylDRqjCSK
		LCRqJCxijCxihDx+pCxqlCxqjAwyPCxmhDR2pDx2nCRejCxunDRynCRehCRmlBQ2RAAAAAAAAAAA
		AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5
		BAEAAAAALAAAAAAYABgAAAf/gACCg4SFhoeEAYqKiI2KAgIDAwIEBI2FAQUDBgcIBwYCCJaXAAED
		CQoICwoKBqwMDZeZCg4PEBESE6sUChUWjhQOFxcPGBAQFRIUGRQaG4cBE8IcHB0PHh8gISIZGRIP
		0MIj4yQlDx8eJhUnKCcfKYbCKivz9Q8sICYhJyIt4ITCXAgcOPAFDAgxTsioAA+ggxkcaEisYeMG
		jhw6dvDoEcPHD0aEgLiwUSOIkCEPchAp4iNGDyNHkOT4NwhIEhtCbChZwuRFEyROgjrJ8YTmIAdQ
		hEQRclLKlAdUqkitUtTKIQdXkiTJiiULkwc/tGjZ8oALkKtdvGhV+wXM0ydFQ5mEaeRAzJAxXsaQ
		AVPm6wMmYs42AiJmzJAhZs58QYMGsOBLQNCYSTN5chomakjVBDIFTRrGQB5rFhS69OjTqFHLCAQA
		Ow==
	}]
#		R0lGODlhFgAWAIYAAPwCBCRSFCRSHBw+DBxCFCQ6FBwyDBQWBBxGFCxyLGTChMzqzLzmvHzKjDyOTER+RERyNDSqXNzy3LzivFS+fCyCPBQmBCQiBBxKFBQqDOTy3LTitES2dDR+PCxuJOT25KTarCx+PESSTCxKHDSeVCyKRNT21ESWVDSGPBQyDAQCBBQSFDRuLDSyZDySTGzChCRiJKSmpExKTDS2ZGzGhLy+vGxqbISChDSKRMzKzGxubDQ2NIyOjCQiJCwqLBQWFCwuLKSipERCRERGRHR2dAwKDDw6PFRWVIyKjCQmJFRSVBwaHKyurAQGBExOTBweHFxeXAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAWABYAAAf9gACCg4IBAgMEBQYHhI2ECAkKCwwNDg8QBAOOhAQREhMUFQgWBxcHGBmbggkaGxwPB4yDB6SbBJIKHQaqtY0eHyAhsqrDgx4aCiKpqoQHAyMjJBMKJaSxzAAHIRsmJgonKA0LHSmDKiuOBywRLSQuLyEwwyoxMuiN6iUzNBXy5jU2bsgoJugABBz95uXQsUMGD3vpPPgTpKIGwx4+HMr4kW4YkCA2hAzxAQSIECI+imBTwVIFESNHerRUgc0cEiFHkjiiyYzeDiVLdvLcySSkkKGEWiZVweSGkIHMmvQosoQlkaZOjvhosvKJjIAxoOAsgpRZkQNLnvSoqspAIAAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJzaW9uIDIuNQ0KqSBEZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVzZXJ2ZWQuDQpodHRwOi8vd3d3LmRldmVsY29yLmNvbQA7
#		R0lGODlhEAAQAIUAAPwCBCRaJBxWJBxOHBRGBCxeLLTatCSKFCymJBQ6BAwmBNzu3AQCBAQOBCRSJKzWrGy+ZDy+NBxSHFSmTBxWHLTWtCyaHCSSFCx6PETKNBQ+FBwaHCRKJMTixLy6vExOTKyqrFxaXDQyNDw+PBQSFHx6fCwuLJyenDQ2NISChLSytJSSlFxeXAwODCQmJBweHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAaBQIBQGBAMBALCcCksGA4IQkJBUDIDC6gVwGhshY5HlMn9DiCRL1MyYE8iiapaSKlALBdMRiPckDkdeXt9HgxkGhWDXB4fH4ZMGnxcICEiI45kQiQkDCUmJZskmUIiJyiPQgyoQwwpH35LqqgMKiEjq5obqh8rLCMtowAkLqovuH5BACH+aENyZWF0ZWQgYnkgQk1QVG9HSUYgUHJvIHZlcnNpb24gMi41DQqpIERldmVsQ29yIDE5OTcsMTk5OC4gQWxsIHJpZ2h0cyByZXNlcnZlZC4NCmh0dHA6Ly93d3cuZGV2ZWxjb3IuY29tADs=

	set pc(tdb:version) 1.1.1
	set pc(file:config) .tdbcnf
	set pc(file:init) .tdbinit
	set pc(path:home) $env(HOME)
	set pc(file:types) {
		{{All Files}        *             }
		{{C Source Files}   {.s .S .asm .c .h .cpp .cxx .hpp .hxx}      TEXT}
		{{Text Files}       {.txt}        }
	}
  
	# program configurable parameters
	array set pp {
		tdb:geom 	620x600
	}
	
	# load options : config file may be in $HOME or in current directory
	foreach i [list [file join $pc(path:home) $pc(file:config)] $pc(file:config)] {
		if {[file exists $i]} {
			set fp [open $i]
			if {[catch {read $fp} rc] || [catch {array set pp $rc} erc]} {
				puts "Opts corrupt: $erc"
			}
		}
	}
	
	wm withdraw .
  
	if {$::tcl_platform(platform) == {windows}} {
		encoding system "utf-8"
	}
     
	set id 0
}

##################################################################
# Projects.
###############################################################
proc highlight:setup:C {win} {
	ctext::addHighlightClassForSpecialChars $win brackets red {[]}
	ctext::addHighlightClassForSpecialChars $win braces red {{}}
	ctext::addHighlightClassForSpecialChars $win parentheses red {()}

	
    ctext::addHighlightClass $win types purple [list \
	char short int long double float unsigned signed int8_t int16_t \
	int32_t int64_t uint8_t uint16_t uint32_t uint64_t \
	struct union enum typedef sizeof const extern auto register static \
	volatile void bool
    ]
    ctext::addHighlightClass $win keywords "#0000A0" [list \
	break case continue default do else for goto if inline return switch \
	while asm catch class delete friend inline new operator private \
	protected public private: protected: public: template this throw \
	try virtual \
    ]
    ctext::addHighlightClassForRegexp $win numbers green \
	    {[[:<:]](0b[01]+|0x[[:xdigit:]]+|[0-9]+)[[:>:]]}
	ctext::addHighlightClassForSpecialChars $win math indianred {+=*-/&^%!|<>:;.}
	ctext::addHighlightClassForRegexp $win characters #E0A000 \
	    {\'\\?.\'}
	ctext::addHighlightClassForRegexp $win strings blue \
	{\"([^\\\"]|\\.)*\"}
    ctext::addHighlightClassForRegexp $win macros "#00A000" \
	{\#(define|undef|include|if|elif|else|endif|ifdef|ifndef|line|pragma)[^\n\r]*[\n\r]|\#((define|undef|include|if|elif|else|endif|ifdef|ifndef|line|pragma)[^\n\r]*[\\][\n\r])+[^\n\r]*[\n\r]}
	   ctext::addHighlightClassForRegexp $win cppcomments "#8080FF" \
		   {//[^\n\r]*[\n\r]}
	$win tag conf _cComment -foreground "#8080FF"
}

proc highlight:setup:arm {win} {
	set cond "(eq|ne|cs|hs|cc|lo|mi|pl|vs\vc|hi|ls|ge|lt|gt|le|al)"
	ctext::addHighlightClassForSpecialChars $win brackets red {[]}
	ctext::addHighlightClassForSpecialChars $win braces red {{}}
	ctext::addHighlightClassForSpecialChars $win parentheses red {()}
	
    ctext::addHighlightClassForRegexp $win keywords "#0000A0" \
    "(add$cond?(s)?|adc($cond)?(s)?|sub($cond)?(s)?|sbc($cond)?(s)?|rsb($cond)?(s)?|rsc($cond)?(s)?|and($cond)?(s)?|orr($cond)?(s)?|eor($cond)?(s)?|bic($cond)?(s)?|mov($cond)?(s)?|mvn($cond)?(s)?|cmp($cond)?(s)?|cmn($cond)?(s)?|tst($cond)?(s)?teq($cond)?(s)?|mul($cond)?(s)?|mla($cond)?(s)?|umull($cond)?(s)?|umlal($cond)?(s)?|smull($cond)?(s)?|smlal($cond)?(s)?|(ldr|str)($cond)?(b|sb|h|sh)?(t)?|lsr|lsl|asr|ror|(ldm|stm)($cond)?(fd|ed|fa|ea|ia|ib|da|db)|b\[lx\]?($cond)?|(mrs|msr)($cond)?|swi|svc)\[\t \]"

    ctext::addHighlightClassForRegexp $win numbers green \
	    {[[:<:]](0b[01]+|0x[[:xdigit:]]+|[0-9]+)[[:>:]]}
	ctext::addHighlightClassForRegexp $win characters #E0A000 \
	    {\'\\?.\'}
	ctext::addHighlightClassForRegexp $win directives brown \
		{\.[^\n\r \t]+}
	ctext::addHighlightClassForRegexp $win labels indianred \
		{^[^\n\r:\. \t]+:}
		
    ctext::addHighlightClassForRegexp $win registers purple \
	{r0|r1|r2|r3|r4|r5|r6|r7|r8|r9|r10|r11|r12|fp|sp|pc|lr|cpsr(_[cfxs])?}
	
	ctext::addHighlightClassForSpecialChars $win math red {+=*-/^!:}
	ctext::addHighlightClassForRegexp $win strings blue \
	{\"([^\\\"]|\\.)*\"}
    ctext::addHighlightClassForRegexp $win macros "#00A000" \
	{\#(define|undef|include|if|elif|else|endif|ifdef|ifndef|line|pragma)[^\n\r]*[\n\r]|\#((define|undef|include|if|elif|else|endif|ifdef|ifndef|line|pragma)[^\n\r]*[\\][\n\r])+[^\n\r]*[\n\r]}
	   ctext::addHighlightClassForRegexp $win cppcomments "#8080FF" \
		   {//[^\n\r]*[\n\r]}
	$win tag conf _cComment -foreground "#8080FF"
}

#
# Create a new instance of the debugger GUI
#
proc Tdb::new {args} {
	variable pc
	variable pp
	variable id
	
	set v $id
	# create new object instance
	set obj ::Tdb::inst$id
	upvar $obj self
	incr id
	
	toplevel [set w .tdb$v]
	wm protocol $w WM_DELETE_WINDOW "Tdb::quit $obj"
	wm geom $w $pp(tdb:geom)
	wm title $w {TDB Debugger}
	lappend pc(tdb:views) $obj
	
	### instance state array
	# cur:file     : current file in the source view
	# dbg:debugger : name of the debugger. The access path to the debugger 
	#                must be in the PATH environment variable of the system
	# dbg:path     : the path to the executable being debugged. It is
	#                considered as the root of the project. The pathes to the
	#                source files will be expressed relatively to this place.
	# dbg:prog     : the executable being debugged
	# FAB: added progargs
	# dbg:progargs : command line arguments for prog
	# dbg:file     : the source file with the code the PC points to
	# dbg:line     : the line in the dbg:file the PC points to
	# dbg:func     : the function the PC currently points to
	# dbg:stattus  : the state of the program (stopped, running)
	array set self [list \
		wid:base					$w \
		cur:file					{} \
		cur:line					0 \
		dbg:debugger				gdb \
		dbg:path					[pwd] \
		dbg:file					{} \
		dbg:line					1 \
		dbg:func					{} \
		dbg:prog					{} \
		dbg:progargs					{} \
		dbg:status					stopped \
		dbg:mode					C \
		file:list					{} \
		var:cmd:hist				{} \
		var:cmd:hist:pos			0 \
		var:search					search \
		animdelay					500 \
		data:size					8 \
		skip						0 \
		trace						off
	]


	# menus
	set mdesc {
		"&File"
		{
			{ "&Debug Program"	{::Tdb::MNC $obj open}				Ctrl-N	}
			{ "&Reload"			{::Tdb::gdb_cmd $obj reload}		Ctrl-R	}
			{ -																}
			{ "&Open Source"	{::Tdb::MNC $obj src}				Ctrl-O	}
			{ -																}
			{ "E&xit"			{::Tdb::MNC $obj exit}				Ctrl-X	}
			{ -																}
		}
	 	"&Debug"
		{
			{ "&Step"			{::Tdb::gdb_cmd $obj step}			F5		}
			{ "&Next"			{::Tdb::gdb_cmd $obj next}			F6		}
			{ "&Finish"			{::Tdb::gdb_cmd $obj finish}		F7		}
			{ "&Continue"		{::Tdb::gdb_cmd $obj cont}			F8		}
			{ "&Interrupt"		{::Tdb::gdb_cmd $obj stop}			Ctrl-F8	}
			{ -																}
			{ "&Up"				{::Tdb::gdb_cmd $obj up}					}
			{ "&Down"			{::Tdb::gdb_cmd $obj down}					}
			{ -																}
			{ "&Auto-step"		{::Tdb::MNC $obj anims}						}
			{ "&Auto-next"		{::Tdb::MNC $obj animn}						}
		}
		"&Show"
		{
			{ "&Registers"		{::Tdb::gdb_cmd $obj reg}					}
			{ "&Globals"		{::Tdb::gdb_cmd $obj {info var}}			}
			{ "&Locals"			{::Tdb::gdb_cmd $obj {info locals}}			}
			{ "&Breakpoints"	{::Tdb::gdb_cmd $obj {info break}}			}
			{ -																}
			{ "&Type"			{::Tdb::gdb_cmd $obj whatis}				}
			{ "&Struct"			{::Tdb::gdb_cmd $obj ptype}					}
		}
		"&Help"
		{
			{ "&Help"			{::Tdb::help $obj TDB}				F1		}
			{ "&About"			{::Tdb::MNC $obj about}						}
		}
	}

	$w config -menu [menu $w.m]
	foreach {name cascade} $mdesc {
		set n [string first & $name]
		set label $name
		if {$n == 0} {
		        set label [string range $name 1 end]
		} elseif {$n > 0} {
		        set label [string range $name 0 [expr {$n - 1}]]
		        append label [string range $name [expr {$n + 1} end]]
		}
		set menu $w.m.[string tolower $label]
		set self(wid:menu:[string tolower $label]) $menu
		$w.m add cascade -label $label -underline $n -menu [menu $menu -tearoff 0]
		foreach command $cascade  {
			foreach {name script key} $command {
				set n [string first & $name]
				set label $name
				if {$n == 0} {
					set label [string range $name 1 end]
				} elseif {$n > 0} {
					set label [string range $name 0 [expr {$n - 1}]]
					append label [string range $name [expr {$n + 1}] end]
				}
				if {$label == "-"} {
					$menu add separator
		        } else {
		        	$menu add command -label $label -underline $n -command "[lindex $script 0] $obj [lindex $script 2]" -accelerator $key
					if {$key != ""} {
						set key [string tolower $key]
						set map {ctrl Control ctl Control ctr Control \
							shft Shift sht Shift shf Shift \
							f1 F1 f2 F2 f3 F3 f4 F4 f5 F5 f6 F6 \
							f7 F7 f8 F8 f9 F9 f10 F10 f11 F11 f12 F12}
						bind $w <[string map $map $key]> "[lindex $script 0] $obj [lindex $script 2]"
					}
				}
			}
		}
	}
  
	# toolbar
	pack [frame [set self(wid:toolbar) [set b $w.tool]]] -fill x
	foreach {i tip} { 
	    reload {Reload}
		stop {Interrupt [Ctrl-C]} \
		cont {Continue [F8]} \
		step {Step [F5]} \
		next {Next [F6]} \
		finish {Finish [F7]} \
		up {Frame Up} \
		down {Frame Down} \
		backtrace {Call Stack}
		stepi {Step machine instruction} \
		nexti {Next machine instruction} \
		reg {Register (selected | all)} \
		print {Show selected variable} \
		{*} {Show value pointed to} \
		display {Add selected var to display} \
		{*} {Add pointed value to display} \
	} {
		if {$i == {*}} {
			set i "${ilast}*"
			set cmd "${ilast} *"
			set bttl *
		} else {
			set i $i
			set cmd $i
			set bttl [string totitle $i]
		}
		set ttl [string totitle $i]
		if {[info exists pc(img:$i)]} {
			pack [button $b.$i -image $pc(img:$i) -command [list Tdb::gdb_cmd $obj $cmd]\
				-relief flat -pady 0 -padx 0] -side left
			balloon $b.$i $tip
		} else {
			pack [button $b.$i -text $bttl -command [list Tdb::gdb_cmd $obj $cmd]\
				-relief flat -pady 0 -padx 0] -side left
			balloon $b.$i $tip
		}
		set ilast $i
	}
#	pack [label $b.lbl -text " "] -side left
#	pack [entry $b.search -textvariable ${obj}(var:search) -width 12] -side left
	
	# frames
	pack [panedwindow $w.pw -orient vertical] -fill both -expand y
	$w.pw add [frame $w.pw.file] [frame $w.pw.cmd]
	pack [frame $w.pw.cmd.tb] -fill x
	pack [frame $w.pw.cmd.t] -fill both -expand 1
	pack [frame $w.e] -fill x
	pack [frame $w.status] -side bottom -fill x
  
	# source file widget
	set f $w.pw.file
	pack [ttk::scrollbar $f.s -command "$f.text yview"] -side right -fill y
	pack [ctext $f.text -linemap 1 \
		-bg white -fg black -insertbackground red \
		-relief flat -wrap none -tabset 4 \
		-yscrollcommand "$f.s set"] -fill both -expand 1
	[set self(wid:file) $f.text] conf -state disabled -exportselection 1
	ctext::enableComments $f.text
	bind $f.text <Double-1> "Tdb::evDblClickCB $obj %x %y"
  
	## tag curr   : current debugged instruction line
	## tag bp     : breakpoint
	## tag currbp : current debugged instruction line is a breakpoint
	$f.text tag conf curr -background lightblue
	$f.text tag conf currbp -background orange
	$f.text tag conf bp -background red -foreground black

	# memory and disassembly address toolbar
	set tb $w.pw.cmd.tb
	pack [label $tb.l1 -text "Address :"] -side left
	pack [entry $tb.addr -textvariable ${obj}(data:address) -width 12] -side left
	pack [label $tb.l2 -text "Format :"] -side left
	tk_optionMenu $tb.format ${obj}(data:format) byte half word
	pack $tb.format -side left
	pack [label $tb.l3 -text "Nb :"] -side left
	pack [spinbox $tb.s -width 5 -from 0 -to 1000 -textvariable ${obj}(data:size)] -side left
	pack [button $tb.view -text "Show Memory" -command [list ::Tdb::MNC $obj mem]] -side left
	pack [button $tb.disasm -text "Disassemble" -command [list ::Tdb::MNC $obj disasm]] -side left
  
	# gdb log widget
	set c $w.pw.cmd.t
	pack [ttk::scrollbar $c.s -command "$c.text yview"] -side right -fill y
	pack [text $c.text -height 6 -yscrollcommand "$c.s set"] -fill both -expand y
	[set self(wid:cmdlog) $c.text] conf -state disabled -exportselection 1
  
	$c.text edit reset
  
	$c.text tag conf error -foreground red
	$c.text tag conf reply -foreground blue
	$c.text tag conf warn -foreground darkgreen
	$c.text tag conf info1 -foreground orange
	$c.text tag conf info2 -foreground green
	$c.text tag conf info3 -foreground lightgrey
	$c.text tag conf hilite -background #d1ffe7
	
	$c.text configure -tabs "[expr {8 * [font measure [$c.text cget -font] 0]}] left" -tabstyle wordprocessor
  
	# dbg cmd entry
	pack [label $w.e.l -text "GDB:"] -side left
	pack [entry [set self(wid:cmdentry) $w.e.e] -textvariable ${obj}(var:cmd) -width 20 \
		-bg white] -fill x
  
	# status frame
	pack [frame [set s $w.status.t]] -side bottom -fill x
	pack [label $s.s -textvariable ${obj}(var:stat) -width 30 -anchor w -relief sunken\
		] -side left
	pack [label $s.l -textvariable ${obj}(var:statl) -width 10 -anchor w -relief sunken\
		] -side left
	pack [label $s.f -textvariable ${obj}(var:file) -anchor w -relief sunken \
		] -side left -fill x -expand y
  
	catch {
		$s.l conf -disabledforeground black;
		$s.r conf -disabledforeground black
	}

	bind $self(wid:cmdentry) <Return> "Tdb::evCmdEntryReturnCB $obj"
	bind $self(wid:cmdentry) <Down> [list Tdb::evCmdEntryHistoryCB $obj 0]
	bind $self(wid:cmdentry) <Up> [list Tdb::evCmdEntryHistoryCB $obj 1]
	
#	bind $b.search <Return> "Tdb::search $obj"
	
	bind $w <Control-c> "Tdb::unanimate $obj;Tdb::gdb_cmd $obj stop"
	bind $w <Escape> "Tdb::unanimate $obj;Tdb::gdb_cmd $obj stop"
  
	bind $tb.addr <Return> "Tdb::MNC $obj mem"
  
	focus $self(wid:cmdentry)

	return $obj
}

proc Tdb::search {obj} {
	upvar $obj self

	set fw $self(wid:file)
    foreach {from to} [$fw tag ranges hilite] {
        $fw tag remove hilite $from $to
    }
    set pos [$fw search -count n -- $self(var:search) insert+2c]
    if {$pos eq ""} {
        set status "not found: $self(var:search)"
    } else {
        set status "found at $pos: $self(var:search)"
        $fw mark set insert $pos
        $fw see $pos
        $fw tag add hilite $pos $pos+${n}c
    }
	puts $status
}

proc Tdb::highlight_dbgline {obj highlight} {                
	upvar $obj self
	# update instruction pointer highlighting
	
	#puts "OPS line : $self(dbg:line)"
	
	set fw $self(wid:file)
	set line $self(dbg:line)

	$fw conf -state normal
	$fw tag remove curr 1.0 end
	if {$highlight} {
#		if {[set ot [$fw tag ranges currbp]] != {}} {
#			eval $fw tag add bp $ot
#			eval $fw tag remove currbp 1.0 end
#		}
		if {[lsearch [$fw tag names $line.0] bp] >= 0} {
			$fw tag remove bp $line.0 $line.end
			$fw tag add currbp $line.0 $line.end
		} else {
			$fw tag add curr $line.0 $line.end
		}
		set self(var:statl) "Line: $line"
	} else {
		set self(var:statl) ""
		if {[lsearch [$fw tag names $line.0] currbp] >= 0} {
			$fw tag remove currbp $line.0 $line.end
			$fw tag add bp $line.0 $line.end
		}
	}
	$fw conf -state disabled
	$fw see $line.0
}

#
# open a source file, update breakpoints enlightment for the viewed file
#
proc Tdb::open_src {obj args} {
	upvar $obj self
	set fname [lindex $args 0]
	if {$fname == {}} {
		return
	}
	set dat [read [set fp [open $fname]]]
	close $fp
	
	# setup syntax highlighting
	set fw $self(wid:file)
	ctext::clearHighlightClasses $fw
	$fw tag remove bp 1.0 end
	$fw tag remove currbp 1.0 end
	highlight_dbgline $obj 0
	
	$fw conf -state normal
	$fw delete 1.0 end
	$fw fastinsert end $dat
	$fw conf -state disabled
	if {[regexp {.*\.([hc]|cpp|cxx|hpp|hxx)$} $fname]} {
		#puts "c file : $fname"
		highlight:setup:C $fw
	} elseif {[regexp {.*\.[sS]$} $fname]} {
		#puts "asm file : $fname"
		highlight:setup:arm $fw
	} else {
		puts " unknown file : $fname"
	}
	$self(wid:file) highlight 1.0 end
	
	# append filename to file list and menu
	if {[lsearch $self(file:list) $fname]<0} {
		lappend self(file:list) $fname
		set id [Ind2Label [llength $self(file:list)]]
		set fnl "$id $fname"
		$self(wid:menu:file) add command -underline 0 -label $fnl\
		  -command [list Tdb::MNC $obj src $fname]
	}
	
	# the file becomes the current viewed file
	set self(var:file) $fname
	set self(cur:file) $fname
	
	# update breakpoint and instruction pointer highlighting
	BP $obj update -file $fname
	if {$self(cur:file) eq $self(dbg:file)} {
		highlight_dbgline $obj 1
	}
}

proc Tdb::Ind2Label {n} {
	if {$n < 10} {
		return $n
	}
	set m [expr {$n+87}]
	return [format %c $m]
}

# Handle menu command
proc Tdb::MNC {obj cmd args} {
    variable pc
    variable pp
    upvar $obj self

    set w $self(wid:file)
    switch $cmd {
	    open {
		    set fname [tk_getOpenFile -title {Open File} \
			        -initialdir $self(dbg:path) -parent $self(wid:base) \
			        -filetypes $pc(file:types)]
		    if {$fname != {}} {
		    	gdb_cmd $obj prog $fname
		    }
		}
	    src {
		    set fname [lindex $args 0]
		    if {$fname == {}} {
				set fname [tk_getOpenFile -title {Open File} \
			        -initialdir $self(dbg:path) -parent $self(wid:base) \
			        -filetypes $pc(file:types)]
		    }
			if {$fname != {}} {
				set dname [string range $fname 0 [expr [string length $self(dbg:path)] - 1]]
				if {$dname == $self(dbg:path)} {
					set fname [string range $fname [expr [string length $self(dbg:path)] + 1] end]
				}
				open_src $obj $fname
		    }
		}
	    exit {
		    if {[tk_messageBox -icon warning -type yesno -title "Exit TDB" \
		      -message [concat {Your Sure You Want To Exit} TDB?]] != "yes"} {
				return
		    }
		    foreach i $pc(tdb:views) { quit $i }
		}
	    anims {
		    InsMsg $obj "Hit ESCAPE to stop Auto-step\n"
		    set self(animate) [after $self(animdelay) Tdb::animate $obj step]
		}
	    animn {
		    InsMsg $obj "Hit ESCAPE to stop Auto-next\n"
		    set self(animate) [after $self(animdelay) Tdb::animate $obj next]
		}
		mem {
#           puts "Show memory : $self(data:address), $self(data:format), $self(data:size)"
			if {[string range $self(data:address) 0 1] eq "0x"} {
			        set s [format "x/%d%sx 0x%x" $self(data:size) [string range $self(data:format) 0 0] $self(data:address)]
			} else {
			        set s [format "x/%d%sx %s" $self(data:size) [string range $self(data:format) 0 0] $self(data:address)]
			}
			gdb_cmd $obj $s
		}
		disasm {
			if {[string range $self(data:address) 0 1] eq "0x"} {
			        set s [format "disassemble/rm 0x%x,0x%x" $self(data:address) [expr $self(data:address) + 4*$self(data:size)]]
			} elseif {$self(data:address) ne {}} {
			        set s [format "disassemble/rm %s" $self(data:address) ]
			}
			gdb_cmd $obj $s
		}
		about {
			tk_messageBox -message "TDB $::Tdb::pc(tdb:version) - A Debugger \n (C) 2016\n Eric Boucharé"
		}
    }
}

############################################################################
# Event callbacks
#

# Dbl click in the source code window event callback
#   toggle a breakpoint for cur:file
proc Tdb::evDblClickCB {obj x y} {
	upvar $obj self
	set w $self(wid:file)
	set id [$w index @$x,$y]
	foreach {r c} [split $id .] {
		break
	}
	BP $obj toggle -line $r
	after 1 "selection clear"
}

proc ::Tdb::evCmdEntryHistoryCB {obj dir} {
	upvar $obj self
	set l [llength $self(var:cmd:hist)]
	if {$dir} {
		if {$self(var:cmd:hist:pos) <= 0} {
			set self(var:cmd) [lindex $self(var:cmd:hist) 0]
			return
		}
		set self(var:cmd) [lindex $self(var:cmd:hist) [incr self(var:cmd:hist:pos) -1]]
	} else {
		set self(var:cmd) {}
		if {$self(var:cmd:hist:pos) >= $l} {
			return
		}
		set self(var:cmd) [lindex $self(var:cmd:hist) [incr self(var:cmd:hist:pos) 1]]
	}
	$self(wid:cmdentry) icursor end
}

proc Tdb::evCmdEntryReturnCB {obj} {
	upvar $obj self
	if {$self(var:cmd) != {}} {
		# update cmd history
		if {[lindex $self(var:cmd:hist) end] != $self(var:cmd)} {
			lappend self(var:cmd:hist) $self(var:cmd)
		}
		set self(var:cmd:hist:pos) [llength $self(var:cmd:hist)]
		set tmp $self(var:cmd)
		set self(var:cmd) {}
	} else {
		# recall last command from history
		set tmp [lindex $self(var:cmd:hist) [expr {[llength $self(var:cmd:hist)]-1}]]
		# if empty history, get out of here
		if {$tmp == {}} return
	}
	# split cmd and args
	regexp {(\S+)(\s+(.*))?} $tmp {} cmd {} args
	if [info exists args] {
		gdb_cmd $obj $cmd $args
	} else {
		gdb_cmd $obj $cmd
	}
}

proc Tdb::InsMsg {obj dat {tag {}}} {
	upvar $obj self
	if {$dat != {}} {
		$self(wid:cmdlog) conf -state normal
		if {$tag == "prompt"} {
			$self(wid:cmdlog) insert end "> $dat" 
		} else {
			$self(wid:cmdlog) insert end $dat $tag
		}
		$self(wid:cmdlog) conf -state disabled
	}
	$self(wid:cmdlog) see end
}

proc Tdb::quit {obj} {
	variable pc
	variable pp
	upvar $obj self
	set bg [wm geom $self(wid:base)]
	regexp {^[0-9]*x[0-9]*} $bg bg
	gdb_cmd $obj quit
	catch {fileevent $self(dbg:pipe) r {}}
	destroy $self(wid:base)
	unset self
	if {[llength $pc(tdb:views)] == 1} {
		set pp(tdb:geom) $bg
		# save config options in $HOME
		set fp [open [file join $pc(path:home) $pc(file:config)] w]
		puts $fp [array get pp]
		close $fp
		exit 0
	}
	if {[set i [lsearch $pc(tdb:views) $obj]] >= 0} {
		set pc(tdb:views) [lreplace $pc(tdb:views) $i $i]
	}
}

proc Tdb::animate {obj cmd} {
	upvar $obj self
	if {![info exists self(animate)]} {
		return
	}
	gdb_cmd $obj $cmd
	set self(animate) [after $self(animdelay) Tdb::animate $obj $cmd]
}

proc Tdb::unanimate {obj} {
	upvar $obj self
	if {[info exists self(animate)]} {
		after cancel $self(animate)
		unset self(animate)
	}
}

proc Tdb::help {obj nam} {
	variable pc
	variable pchelp
	set t .tdbhelp
	if {[catch {toplevel $t}]} {
		destroy $t
		toplevel $t
	}
	pack [scrollbar $t.s -command "$t.text yview"] -side right -fill y
	pack [text $t.text -exportselection 1 -wrap word \
		-yscrollcommand "$t.s set"] -fill both -expand y
	$t.text insert end $pchelp
	$t.text conf -state disabled
}

############################################################################
# Breakpoint info management
############################################################################
proc Tdb::bp_srch {idx lst pat} {
	set n 0
	foreach i $lst {
		if {[lindex $i $idx] == $pat} {
			return $n
		}
		incr n
	}
	return -1
}

proc Tdb::BP {obj cmd args} {
#puts "BP $cmd $args"
	variable pc
	upvar $obj self
	array set p [list -line $self(dbg:line) -file $self(cur:file)]
	array set p $args
	set file $p(-file)
	switch $cmd {
		set {
			set bp [list $p(-line) $p(-num)]
			if {![info exists self(bp%$file)]} {
				set self(bp%$file) [list $bp]
			} else {
				if {[bp_srch 0 $self(bp%$file) $p(-line)]>=0} {
					return
				}
				lappend self(bp%$file) $bp
			}
			if {$p(-file) == $self(cur:file)} {
				if {$p(-line) == $self(dbg:line)} {
					$self(wid:file) tag add currbp $p(-line).0 $p(-line).end
				} else {
					$self(wid:file) tag add bp $p(-line).0 $p(-line).end
				}
			}
		}
		unset {
			if {![info exists self(bp%$file)]} {
				return
			}
			if {[info exists p(-num)]} {
				if {[set i [bp_srch 1 $self(bp%$file) $p(-num)]]<0} {
		  			return
				}
	  		} else {
				if {[set i [bp_srch 0 $self(bp%$file) $p(-line)]]<0} {
		    		return
				}
	  		}
	  		foreach {line num} [lindex $self(bp%$file) $i] {
				break
	  		}
	  		set self(bp%$file) [lreplace $self(bp%$file) $i $i]
	  		$self(wid:file) tag remove bp $line.0 $line.end
	  		$self(wid:file) tag remove currbp $line.0 $line.end
			if {$line == $self(dbg:line)} {
				$self(wid:file) tag add curr $line.0 $line.end
			}
		}
    	find {
	  		if {![info exists self(bp%$file)]} {
				return
	  		}
	  		if {[info exists p(-num)]} {
	    		if {[set i [bp_srch 1 $self(bp%$file) $p(-num)]]<0} {
		  			return
				}
	 	 	} else {
				if {[set i [bp_srch 0 $self(bp%$file) $p(-line)]]<0} {
		  			return
				}
	  		}
	  		set rc [lindex $self(bp%$file) $i]
	  		return $rc
		}
    	del {
	  		catch {unset self(bp%$file)}
	  		$self(wid:file) tag delete bp
		}
    	update {
	  		if {![info exists self(bp%$file)]} {
	    		return
	  		}
	  		foreach i $self(bp%$file) {
				set line [lindex $i 0]
				$self(wid:file) tag add bp $line.0 $line.end
	  		}
		}
    	toggle {
	  		if {[set lup [BP $obj find -file $p(-file) -line $p(-line)]] == {}} {
				gdb_cmd $obj break $p(-file):$p(-line)
	  		} else {
				BP $obj unset -file $p(-file) -line $p(-line)
				gdb_cmd $obj delete [lindex $lup 1]
	  		}
	  		after idle "focus $self(wid:cmdentry)"
		}
  	}
}

################################################################################
# Begin GDB SPECIFIC COMMANDS

proc Tdb::gdb_load_elf {obj args {keep_bp {no}}} {
	variable pc
	upvar $obj self
	
	# Normalize path and change path to directory containing the executable.
	# Path to source files are relative to $self(dbg:path)
	set fname [file normalize [lindex $args 0]]
	set dname [file dirname $fname]
	if {$dname != {}} {
		set self(dbg:path) $dname
		cd $self(dbg:path)
	}
	set self(dbg:prog) [string range $fname [expr [string length $self(dbg:path)] + 1] end]
	wm title $self(wid:base) "TDB Debugger: $self(dbg:prog)"

	# FAB: memorised prog args
	# FIXME: does not deal well with corepid (specific syntax required)
	set self(dbg:progargs) [lrange $args 1 end]
	
	set self(dbg:func) {}
	set self(dbg:file) {}
	set self(dbg:line) {}
	
	# analyze .tdbinit file
	set initfile "$self(dbg:path)/$pc(file:init)"
	if [file exists $initfile] {
		set f [open $initfile r]
		set f_data [read $f]
		close $f
		set rcdata {}
		foreach d [split $f_data "\n"] {
			if [regexp {#![ \t]*(.+)} $d {} debug] {
				set self(dbg:debugger) $debug
				puts "debugger = $debug"
			} elseif [regexp {#.*} $d] {
			} elseif [string match {open*} $d] {
				gdb_cmd $obj open [lrange $d 1 end]
			} elseif {$d != ""} {
				lappend rcdata $d
			}
		}
	}

	# open connection with debugger
	if {$::tcl_platform(platform) == {windows}} {
		set cmd "|$self(dbg:debugger) -interpreter=mi -q -f \"$self(dbg:prog)\" "
	} else {
		set cmd "|$self(dbg:debugger) -interpreter=mi -q -f \"$self(dbg:prog)\" 2>@ stdout"
	}
	set self(dbg:pipe) [open $cmd r+]
	set self(dbg:gdbpid) [pid $self(dbg:pipe)]
	InsMsg $obj $cmd\n
	fconfigure $self(dbg:pipe) -blocking 0
	fileevent $self(dbg:pipe) r [list Tdb::gdb_in $obj]
	set self(starting) 0
	set self(restarting) 0
	if {$::tcl_platform(platform) == {windows}} {
		gdb_out $obj "set target-async on"
	}
	
	set self(starting) 1
	# execute .tdbinit commands if any
	if [file exists $initfile] {
		foreach line $rcdata {
		    gdb_out $obj $line
		} 
	} else {
		# FAB: use tty and prog args
		if {$::tcl_platform(platform) != {windows}} {
			set tty [exec tty]
			gdb_out $obj "tty $tty\nset args $self(dbg:progargs)"
		}
		gdb_out $obj "tb main\nrun"
	}
	gdb_out $obj  "info inferiors\nset print pretty on"
	
	if {$keep_bp == "yes"} {
		# record where breakpoints were set, prepare breakpoint commands
		set nbkpt {}
		foreach {key val} [array get self] {
			if {[string match {bp%*} $key]} {
				foreach bkpt $val {
					set f [string range $key 3 end]
					lappend nbkpt "break $f:[lindex $bkpt 0]"
					BP $obj unset -file "$f" -num [lindex $bkpt 1]
				}
			}
		}
		# replay breakpoint commands
		foreach cmd $nbkpt {
			gdb_cmd $obj $cmd
		}
	} else {
		# remove all breakpoints if any
		array unset self {bp%*}
	}
}

proc Tdb::gdb_in {obj} {
	variable pc
	upvar $obj self
	if {![info exists self(wid:file)]} {
		return
	}
	set fw $self(wid:file)
	if {[set rc [gets $self(dbg:pipe) data]] == -1} {
		if {[eof $self(dbg:pipe)]} {
			fileevent $self(dbg:pipe) r {}
			close $self(dbg:pipe)
			InsMsg $obj "gdb exited\n" error
		}
		return
	}
	
	if {$self(trace) == "on"} {
		puts $data
	}
	
	if {[catch {
		if {[string index $data 0] == "~"} {
			set e [lindex [string range $data 1 end] 0]
			if {[string index $e 0] != "\032"} {
				# workaround to avoid displays to print tracked data twice
				# "skip"==0 ==> normal display, else display inhibited
				if {!$self(skip)} {
					InsMsg $obj $e reply
				}
			} else {
				foreach {file line char func pos} [split [string range $e 2 end] :] break
				set file [string range $file [expr [string length $self(dbg:path)] + 1] end]
				set self(dbg:line) $line
				if {$file != $self(dbg:file)} {
					set self(dbg:file) $file
					open_src $obj $self(dbg:file)
				} else {
					highlight_dbgline $obj 1
				}
				set self(skip) 1
			}
		} elseif {[string index $data 0] == "&"} {
			set self(skip) 0
			set s [lindex [string range $data 1 end] 0]
			if {$s == "\n" || [string match {warning:*} $s]} {
				return
			} else {
				InsMsg $obj $s prompt
			}
		} elseif {[string index $data 0] == "@"} {
			InsMsg $obj [lindex [string range $data 1 end] 0] reply
		} elseif {[string match {\*stopped,*} $data]} {
			array set q { reason {} exit-code 0 func {} }
			set lst [gdb_split [string range $data 9 end] frame q]

			set self(var:stat) "Status: stopped \[$q(reason)\]"
			set self(dbg:status) stopped
			# stopped in new function ?
			if {$q(func) != $self(dbg:func)} {
				set self(dbg:func) $q(func)
				set s {}
				foreach params $q(args) {
					array set p $params
					set s "$s$p(name)=$p(value), "
				}
				InsMsg $obj "$q(func)\([string replace $s end-1 end]) at $q(file):$q(line)\n" reply
			}
			if [file exists $q(file)] {
				set self(dbg:mode) C
				set self(dbg:line) $q(line)
				if {$q(file) != $self(dbg:file) || $self(cur:file) != $self(dbg:file)} {
					set self(dbg:file) $q(file)
					open_src $obj $self(dbg:file)
				} else {
					highlight_dbgline $obj 1
				}
			} else {
				if {$self(dbg:mode) == "C"} {
					InsMsg $obj "source file \"$q(file)\" does not exist in current project\nfinishing function \"$q(func)\" ...\n" error
					set self(dbg:mode) asm
					gdb_cmd $obj finish
				}
			}
			set self(skip) 0
			
			switch -- $q(reason) {
				exited-normally -
				exited {
					break
				}
				signal-received {
				}
				breakpoint-hit {
				}
				access-watchpoint-trigger -
				read-watchpoint-trigger -
				watchpoint-trigger {
				
				}
				location-reached -
				end-stepping-range -
				default {
				
				}
			}
		} elseif {[string match {\*running,*} $data]} {
			set self(var:stat) "Status: running"
			set self(dbg:status) running
			if {$self(cur:file) eq $self(dbg:file)} {
				highlight_dbgline $obj 0
			}
		} elseif [string match {^error*} $data] {
			foreach {r c} [split [$self(wid:cmdlog) index end] .] break
			set i1 "[expr $r - 2 ].0"
			set i2 "[expr $r - 1 ].0"
			$self(wid:cmdlog) conf -state normal
			$self(wid:cmdlog) delete $i1 $i2
			$self(wid:cmdlog) conf -state disabled
			array set q {}
			gdb_split [string range $data 7 end] none q
			if {$q(msg) == "Quit"} {
				InsMsg $obj "Endless loop detected!\n" warn
			} else {
				InsMsg $obj "$q(msg)\n" error
			}
#		} elseif [regexp {^\(gdb\)(.*)} $data d] {
#			InsMsg $obj $d error
#		} elseif [regexp {^&\"([^\\]*)} $data {} d] {
#			InsMsg $obj $d\n prompt
		} elseif {[string match {=thread-group-started,*} $data]} {
			# get pid ...
			array set q {}
			gdb_split [string range $data 22 end] none q
			set self(dbg:progpid) $q(pid)
		} elseif {[string match {=breakpoint-created,*} $data]} {
			array set q { number 0 file {} line 0 }
			gdb_split [string range $data 20 end] bkpt q
			BP $obj set -num $q(number) -file "$q(file)" -line $q(line)
		} elseif {[string match {=breakpoint-deleted,*} $data]} {
			array set q {}
			gdb_split [string range $data 20 end] none q
			BP $obj unset -num $q(id)
		} elseif {[string match {=library-loaded,*} $data]} {
			array set q {}
			gdb_split [string range $data 16 end] none q
			InsMsg $obj "library $q(id) loaded\n" reply
		} elseif {[string match {=memory-changed,*} $data]} {
		} elseif [regexp {^=(.*)} $data {} d] {
#			InsMsg $obj $data\n info1
		} else {
#			InsMsg $obj $data\n info3
		}
	} rc]} {
#		puts "ERROR: $rc"
	}
}

proc Tdb::gdb_out {obj str} {
	upvar $obj self
	if [catch {puts $self(dbg:pipe) $str} rc] {
		InsMsg $obj "gdb seems to be gone\n"
		return
	}
	flush $self(dbg:pipe)
}

# Handle GDB commands
proc Tdb::gdb_cmd {obj cmd {args ""}} {
	upvar $obj self
	set args [lindex $args 0]
	switch -exact $cmd {
		stat {
			parray self
		}
		s - step {
			if {$self(dbg:status) != "running"} {
				if {$self(dbg:mode) == "C"} {
					InsMsg $obj "step $args\n" prompt
					gdb_out $obj -exec-step
				} else {
					gdb_cmd $obj si $args
				}
			} else {
				InsMsg $obj "The program is in running state!\n" warn
			}
		}
		si - stepi {
			if {$self(dbg:status) != "running"} {
				InsMsg $obj "stepi $args\n" prompt
				gdb_out $obj -exec-step-instruction
			} else {
				InsMsg $obj "The program is in running state!\n" warn
			}
		}
		n - next {
			if {$self(dbg:status) != "running"} {
				if {$self(dbg:mode) == "C"} {
					InsMsg $obj "next $args\n" prompt
					gdb_out $obj -exec-next
				} else {
					gdb_cmd $obj ni $args
				}
			} else {
				InsMsg $obj "The program is in running state!\n" warn
			}
		}
		ni - stepi {
			if {$self(dbg:status) != "running"} {
				InsMsg $obj "nexti $args\n" prompt
				gdb_out $obj -exec-next-instruction
			} else {
				InsMsg $obj "The program is in running state!\n" warn
			}
		}
		fin - fini - finish {
			if {$self(dbg:status) != "running"} {
				InsMsg $obj "finish\n" prompt
				gdb_out $obj -exec-finish
			} else {
				InsMsg $obj "The program is in running state!\n" warn
			}
		}
		c - con - cont - continue {
			if {$self(dbg:status) != "running"} {
				InsMsg $obj "continue\n" prompt
				gdb_out $obj -exec-continue
			} else {
				InsMsg $obj "The program is in running state!\n" warn
			}
		}
		run {
			if {$self(dbg:status) != "running"} {
				InsMsg $obj "run\n" prompt
				gdb_out $obj -exec-run
			} else {
				InsMsg $obj "The program is in running state!\n" warn
			}
		}
		u - until {
			if {$self(dbg:status) != "running"} {
				InsMsg $obj "until $args\n" prompt
				gdb_out $obj "-exec-until $args"
			} else {
				InsMsg $obj "The program is in running state!\n" warn
			}
		}
		stop {
			if {$self(dbg:status) == "running"} {
				if {$::tcl_platform(platform) != {windows}} {
					if {[info exists self(dbg:progpid)] && $self(dbg:progpid) != 42000} {
						exec kill -SIGINT $self(dbg:progpid)
					} else {
						exec kill -SIGINT $self(dbg:gdbpid)
					}
				} else {
					if {[info exists self(dbg:progpid)] && $self(dbg:progpid) != 42000} {
## !!bug!! can't stop program on Windows
##						exec kill -SIGINT $self(dbg:progpid)
					} else {
						gdb_out $obj interrupt
					}
				}
			}
		}
		q - quit {
			unanimate $obj
			gdb_cmd $obj stop
			gdb_out $obj "kill\nquit"
		}
		prog {
			if {$self(dbg:prog) != ""} {
				gdb_cmd $obj quit
			}
			# FAB: kept all args
			after 200 [list Tdb::gdb_load_elf $obj "$args" no]
		}
		trace {
			set self(trace) $args
		}
		reload {
			if {$self(dbg:prog) != ""} {
				gdb_cmd $obj quit
				# FAB: reused progargs
				after 200 [list Tdb::gdb_load_elf $obj [concat $self(dbg:prog) $self(dbg:progargs)] yes]
				# after 200 [list Tdb::gdb_load_elf $obj $self(dbg:prog) yes]
			} else {
				InsMsg $obj "No program specified!\n" error
			}
		}
		whatis -
		ptype -
		display -
		{display *} -
		{print *} -
		print {
			if {$args != {}} {
				gdb_out $obj "$cmd $args"
			} else {
				if {[catch {string trim [$self(wid:file) get sel.first sel.last]}\
				  dat] && [catch {string trim [$self(wid:cmdlog) get sel.first\
				  sel.last]} dat]} {
					return
				}
				if {$dat == {}} {
					return
				}
				gdb_out $obj "$cmd $dat"
			}
		}
		reg {
			if {[catch {string trim [$self(wid:file) get sel.first sel.last]}\
			  dat] && [catch {string trim [$self(wid:cmdlog) get sel.first\
			  sel.last]} dat]} {
				gdb_out $obj "info $cmd"
			} else {
				gdb_out $obj "info $cmd $dat"
			}
		}
		b - break - tb - tbreak {
			gdb_out $obj "$cmd \"$args\""
		}
		del - delete {
			BP $obj unset -num $args
			gdb_out $obj "$cmd $args"
		}
		open {
			InsMsg $obj "$cmd $args\n" prompt
			foreach f $args {
				foreach fname [glob $f] {
					# append filename to file list and menu
					if {[lsearch $self(file:list) $fname]<0} {
						lappend self(file:list) $fname
						set id [Ind2Label [llength $self(file:list)]]
						set fnl "$id $fname"
						$self(wid:menu:file) add command -underline 0 -label $fnl\
						  -command [list Tdb::MNC $obj src $fname]
					}
				}
			}
		}
		default {
			if {[string match {=*} $cmd]} {
				set cmd [string range $cmd 1 end]
			}
			gdb_out $obj [concat $cmd $args]
		}
	}
}


proc Tdb::gdb_split {str {flattens {}} {qvar {}}} {
	# Convert a GDB response string to a Tcl list.
	set o {}
	set last {}
	set instr 0
	set clst [split $str {}]
	foreach ch $clst {
		if {$instr} {
			if {$ch == "\\"} {
				append o $ch
			} elseif {$ch == "\""} {
				if {$last != "\\"} { set instr 0 }
				append o $ch
			} elseif {$ch == "\{"} {
				append o "\\\{"
			} elseif {$ch == "\}"} {
				append o "\\\}"
			} else {
				append o $ch
			}
				
		} else {
			if {$ch == "\\"} {
				append o $ch
			} elseif {$ch == "\""} {
				set instr 1
				append o $ch
			} elseif {$ch == "="} {
				append o " "
			} elseif {$ch == ","} {
				append o " "
			} elseif {$ch == "\["} {
				append o "\{"
			} elseif {$ch == "\]"} {
				append o "\}"
			} else {
				append o $ch
			}
		}
		set last $ch
		if {[string range $o end-2 end] == "\\\\\""} {
			set o [string replace $o end-2 end]
		}
	}
	if {$flattens == {}} {
		return $o
	}
	if {$qvar != {}} { upvar 1 $qvar q }
	foreach {nam val} $o {
		if {[lsearch $flattens $nam]>=0} {
			foreach {fnam fval} $val {
				set q($fnam) $fval
			}
		} else {
			set q($nam) $val
		}
	}
	if {$qvar == {}} {
		return [array get q]
	}
	return $o
}

# End GDB SPECIFIC COMMANDS
#############################################################################
if {
	[catch {
		set o [Tdb::new]
		if {[llength $argv]} {
			if {[file exists [lindex $argv 0]]} {
				# FAB: added {} around argv
				eval Tdb::gdb_load_elf $o {$argv}
			} else {
				Tdb::InsMsg $o "TDB $Tdb::pc(tdb:version) Ready...  Use \"File/Debug Program\" to start.\n" reply
				tk_messageBox -icon warning -title "File Not Found" \
				  -message "Object file not found"
			}
		} else {
			Tdb::InsMsg $o "TDB $Tdb::pc(tdb:version) Ready...  Use \"File/Debug Program\" to start.\n" reply
		}
	} rc]
} { puts "INIT: $rc: $errorInfo" }

#############################################################################
# END
#############################################################################
