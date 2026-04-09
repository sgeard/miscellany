package require Tk

source [file join [file dirname [info script]] solver.tcl]

namespace eval GUI {
    variable tx
    variable stored_p
    variable a {}
    variable b {}
    variable c {}
    variable d {}
    variable e {}
    variable w_arg {}
    variable fmt {%0.8f}
    variable methods [list nr]
    
    proc create {} {
        variable tx
        variable a
        variable b
        variable c
        variable d
        variable e
        variable w_arg
        wm title . "Exponential Equation Solver"
        wm resizable . 0 1
        #set a 27 ; set b 3 ; set c 4 ; set d 1; set e 1.0e-6
        #set a 2 ; set b -9 ; set c 0 ; set d 1; set e 1.0e-6
        #set a 9 ; set b -1 ; set c 0 ; set d 6; set e 1.0e-6
        set a 9 ; set b -1 ; set c 7 ; set d 1; set e 1.0e-9
        set fr [ttk::frame .fr]
        set lab [ttk::label $fr.lab -text "Solve: a\u02E3 + bx\u1D48 - c = 0" ]
        pack $lab -fill x -expand 0 -side top -pady 3 -fill x
        
        set psfr [ttk::frame $fr.ps]
        set pfr [ttk::frame $psfr.p]
        foreach v {a b c d e} {
            set le [labelentry $pfr $v]
            if {$v == "e"} {
                $le.lab configure -text " ; max error = "
                $le.en configure -textvariable "GUI::$v" -width 6
            } else {
                $le.lab configure -text "$v = "
                $le.en configure -textvariable "GUI::$v" -width 3
            }
            pack $le -side left -expand 0
        }
        pack $pfr -side left -anchor n -fill x -expand 0
        pack $psfr -side top -fill x -expand 0
        set sb [ttk::button $psfr.sb -text Solve -command "GUI::invoke_solver"]
        pack $sb -side right -padx 6 -pady 6                                                                                                                                               
        set wfr [ttk::frame $fr.w]
        set wle [labelentry $wfr {w}]
        $wle.lab configure -text {W(}
        $wle.en configure -width 10 -textvariable GUI::w_arg -validate key -validatecommand GUI::clear_result
        pack $wle -side left
        set rwle [labelentry $wfr {rwle}]
        $rwle.lab configure -text ") = "
        $rwle.en configure -width 21 -textvariable GUI::w_res
        set cc [ttk::button $wfr.cc -text Calculate -command "GUI::calculate"]
        pack $cc -side right -padx 6 -pady 6
        pack $rwle -side left
        pack $wfr -side top -fill x
        
        set tx [text $fr.tx -width 65 -height 50]
        set base_font [$tx cget -font]
        set ascent [font metrics $base_font -ascent]
        set base_size [font actual $base_font -size]
        set script_size [expr {max(6, int($base_size * 0.75))}]
        set script_font [font create {*}[font actual $base_font] -size $script_size]
        $tx tag configure sup -offset [expr {$ascent / 2}] -font $script_font
        $tx tag configure sub -offset [expr {-$ascent / 4}] -font $script_font
        $tx tag configure correct_val -background yellow \
            -font [font create {*}[font actual $base_font] -weight bold]
        $tx tag configure incorrect_val -background red
        pack $tx -fill both -expand 1 -side left
        pack $fr -fill both -expand 1
    }
    
    proc clear_result {} {
        variable w_res
        set w_res {}
        return 1
    }
    
    proc set_displayed_parameters {av bv cv dv ev} {
        variable tx

        $tx configure -state normal
        $tx insert end "Solving the exponential equation:\n\n"
        $tx insert end "\t${av}"
        $tx insert end "x" sup
        $tx insert end " "
        if {$bv > 0} {
            if {$bv == 1} {
                $tx insert end "+ x"
            } else {
                $tx insert end "+ ${bv}x"
            }
        } else {
            if {$bv == -1} {
                $tx insert end "- x"
            } else {
                $tx insert end "- [expr {-$bv}]x"
            }
        }
        if {$dv == 1} {
            $tx insert end " "
        } else {
            $tx insert end $dv sup
            $tx insert end " "
        }
        if {$cv == 0} {
            $tx insert end " = 0"
        } else {
            if {$cv > 0} {
                $tx insert end "- $cv = 0"
            } else {
                $tx insert end "+ [expr {-$cv}] = 0"
            }
        }
        $tx insert end " to an accuracy of $ev\n\n"
        $tx configure -state disabled
    }
    
    # Create a labelentry widget
    proc labelentry {parent name} {
        set fr [ttk::frame $parent.fr_$name]
        set lab [ttk::label $fr.lab]
        set en [ttk::entry $fr.en]
        pack $lab $en -side left
        return $fr
    }
    
    proc bold_unicode {s} {
        # Replace ASCII digits with Mathematical Bold digits (U+1D7CE-U+1D7D7)
        # Minus and decimal point have no bold Unicode equivalents
        set result ""
        foreach c [split $s ""] {
            set cp [scan $c %c]
            if {$cp >= 48 && $cp <= 57} {
                append result [format %c [expr {0x1D7CE + $cp - 48}]]
            } else {
                append result $c
            }
        }
        return $result
    }

    proc sub_unicode {s} {
        string map {
            0 \u2080  1 \u2081  2 \u2082  3 \u2083  4 \u2084
            5 \u2085  6 \u2086  7 \u2087  8 \u2088  9 \u2089
            - \u208B  + \u208A
        } $s
    }

    proc sup_unicode {s} {
        string map {
            0 \u2070  1 \u00B9  2 \u00B2  3 \u00B3  4 \u2074
            5 \u2075  6 \u2076  7 \u2077  8 \u2078  9 \u2079
            - \u207B  + \u207A
            x \u02E3  d \u1D48  s \u02E2  e \u1D49
        } $s
    }

    proc copy_to_clipboard {} {
        variable tx
        set text [$tx get 1.0 end]
        set n [string length $text]
        set result ""
        for {set i 0} {$i < $n} {incr i} {
            set c [string index $text $i]
            set tags [$tx tag names "1.0 + $i chars"]
            if {"sup" in $tags} {
                set c [sup_unicode $c]
            } elseif {"sub" in $tags} {
                set c [sub_unicode $c]
            }
            if {"correct_val" in $tags} {
                set c [bold_unicode $c]
            }
            append result $c
        }
        clipboard clear
        clipboard append $result
    }
    
    proc calculate {} {
        variable e
        variable w_arg
        variable w_res

        set fmt "%0.[expr {int(- [log10 $e]) - 1}]f"
        set warg [expr "$w_arg"]
        set s_value [solver::lambert_w $warg $e]
        lassign $s_value s1 s2
        set w_res [format $fmt $s1]
        trace::mess $w_res
        if {[llength $s_value] > 1} {
            append w_res ", [format $fmt $s2]"
        }
    }
    
    proc output_equations {a b c d e warg fmt} {
        if {$a eq {e}} {
            if {abs($b) == 1} {
                set xc [expr {$c/$b}]
                monitor "x = $xc - W(${a}**(${xc}))\n"
                monitor "  = $xc - W([format $fmt $warg])\n"
           } else {
                monitor "x = $c/$b - W(${a}**(${c}/$b))\n"
                monitor "  = $c/$b - W([format $fmt $warg])\n"
            }
        } else {
            if {$c == 0 && $b == -1} {
                if {$d == 1} {
                    monitor "x = - W(-log($a))/log($a)"
                    monitor_nl
                    monitor "  = - W([format $fmt $warg])/log($a)\n"
                } else {
                    set nd [expr {-$d}]
                    if {$nd == 1} {
                        set coeff {}
                    } elseif {$nd == -1} {
                        set coeff {- }
                    } else {
                        set coeff "${nd}*"
                    }
                    monitor "x = ${coeff}W(-log($a)/$d)/log($a)"
                    monitor_nl
                    monitor "  = ${coeff}W([format $fmt $warg])/log($a)\n"
                }
            } else {
                set xc [expr {$c/$b}]
                if {$b == 1} {
                    monitor "x = $xc - W(${a}**($xc)*log($a))/log($a)"
                } elseif {$b == -1} {
                    monitor "x = $xc - W(-${a}**($xc)*log($a))/log($a)"
                } else {
                    monitor "x = $xc - W(${a}**($xc)*log($a)/$b)/log($a)"
                }
                monitor_nl
                monitor "  = $xc - W([format $fmt $warg])/log($a)\n"
            }
        }
    }
    
    proc calculate_lambert_values {a b c d e warg nr_solns fmt} {
        trace::mess "warg = $warg ; e = $e"
        set s_value [solver::lambert_w $warg $e]
        if {[llength $s_value] == 0} {
            set w_res {No solutions}
            return
        }

        lassign $s_value s1 s2
        set w_arg $warg
        set w_res [format $fmt $s1]
        trace::mess $w_res
        if {[llength $s_value] > 1} {
            append w_res ", [format $fmt $s2]"
        }

        if {$warg < 0 && [llength $s_value] > 1} {
            monitor "     W__0([format $fmt $warg]) = [format $fmt $s1]\n"
            monitor "    W__-1([format $fmt $warg]) = [format $fmt $s2]\n"
        }
        monitor_nl

        monitor "therefore\n"
        monitor_nl
        foreach w $s_value {
            set ws [format $fmt $w]

            if {$a eq {e}} {
                if {$c == 0} {
                    monitor "    x = - $ws"
                    set xw [expr {-$w}]
                } else {
                    set op [expr {$w >= 0 ? {- } : {+ }}]
                    set abs_ws [format $fmt [expr {abs($w)}]]
                    monitor "    x = $c/$b ${op}${abs_ws}"
                    set xw [expr {$c/double($b) - $w}]
                }
            } else {
                # Compute the term -d*W/log(a) and derive sign to avoid double-negatives
                set term [expr {-$d * $w / log($a)}]
                set abs_ws [format $fmt [expr {abs($w)}]]
                set op [expr {$term >= 0 ? {+ } : {- }}]
                if {abs($d) == 1} {
                    set w_part "${abs_ws}/log($a)"
                } else {
                    set w_part "[expr {abs($d)}]*${abs_ws}/log($a)"
                }
                if {$c == 0} {
                    monitor "    x = [expr {$term >= 0 ? {} : {- }}]${w_part}"
                    set xw $term
                } else {
                    if {abs($b) == 1} {
                        set xc [expr {$c/double($b)}]
                        monitor "    x = $xc ${op}${w_part} "
                    } else {
                        monitor "    x = $c/$b ${op}${w_part} "
                    }
                    set xw [expr {$c/double($b) + $term}]
                }
            }
            solver::set_params $a $b $c $d $e
            lassign [solver::n-r-from $xw $e] xw
            monitor "  = "
            report_result $nr_solns $e $xw
        }
        monitor_nl
    }
    
    proc calculate_third_lambert_value {a b c d e nr_solns fmt} {
        monitor "Negative solution uses W(u) u > 0:\n"
        monitor_nl
        if {abs($b) == 1} {
            if {$d == 1} {
                set warg3 [expr {log($a)}]
                monitor "    u = ln($a) = [format $fmt $warg3]\n"
            } else {
                set warg3 [expr {log($a) / ($d)}]
                monitor "    u = ln($a)/$d = [format $fmt $warg3]\n"
            }
        } else {
            if {$d == 1} {
                set warg3 [expr {log($a) / abs($b)}]
                monitor "    u = ln($a)/$d = [format $fmt $warg3]\n"
            } else {
                set warg3 [expr {log($a) / ($d * abs($b) ** (1.0/$d))}]
                monitor "    u = ln($a) / ($d * |$b|^(1/$d)) = [format $fmt $warg3]\n"
            }
        }
        set w3_list [solver::lambert_w $warg3 $e]
        set w3 [lindex $w3_list 0]
        monitor "    W__0([format $fmt $warg3]) = [format $fmt $w3]\n"
        set x3 [expr {- double($d) * $w3 / log($a)}]
        solver::set_params $a $b $c $d $e
        lassign [solver::n-r-from $x3 $e] x3
        monitor_nl
        if {$d == 1} {
            monitor "    x = -W__0/log($a) = "
        } else {
            monitor "    x = -$d*W__0/log($a) = "
        }
        report_result $nr_solns $e $x3

    }
    
    proc invoke_solver {} {
        variable tx
        variable a
        variable b
        variable c
        variable d
        variable e
        variable w_arg
        variable w_res
        variable fmt
        variable methods
        
        namespace path {::tcl::mathop ::tcl::mathfunc}

        $tx configure -state normal
        $tx delete 1.0 end
        $tx configure -state disabled
        solver::set_functions f f'

        foreach k {a b c d e} an [list $a $b $c $d $e]  {
            if {$::v > 0} {
                trace::mess "$k -> $an"
            }
            if {$k eq {a} && $an eq {e}} {
                continue
            }
            if {! [string is double -strict [expr "$an"]]} {
                error "$an is not numeric"
            }
        }
        if {$d == 0} {
            monitor "d = 0 is not valid: the equation degenerates to a\u02e3 = c - b,\n"
            monitor "which is solved directly by x = log(c - b) / log(a).\n"
            return
        }

        set_displayed_parameters $a $b $c $d $e
        solver::set_params $a $b $c $d $e
        solver::set_monitor_f GUI::monitor

        set fmt "%0.[expr {int(- [log10 $e]) - 1}]f"
        trace::mess "fmt = $fmt"
        trace::mess {>>>=======================================================}
        set ns [solver::number_of_solns]

        trace::mess "Searching for $ns solutions"

        if {$ns == 0} {
            if {$c == 0 && $b == -1 && int($d)%2 == 1} {
                set e_lna [expr {exp(1.0)*log($a)}]
                monitor "No solutions\n"
                monitor "\tfor a^x = x^d with odd d, d > e\u00b7ln(a).\n"
                monitor "\tHere d = $d,  e\u00b7ln($a) \u2248 [format %.4f $e_lna]\n"
            } else {
                set xt [solver::get_tangent_point]
                monitor "No solutions: a^x lies entirely above b\u00b7x^d + c\n"
                monitor "    (curves are tangent at x \u2248 [format %.4f $xt])\n"
            }
            monitor "\n[string repeat = 60]\n"
            add_copy_button
            return
        }

        if {$ns >= 1} {
            set sframes [solver::get_solution_frames $ns -10 200]
            set str    "Numerically using Newton-Raphson\n"
            append str "--------------------------------\n"
            append str "\n[llength $sframes] intervals found \{"
            foreach s $sframes {
                lassign $s u v
                append str [format "%s%0.3f%s%0.3f%s" "(" $u "," $v ")"]
            }
            append str "\}"
            monitor "$str\n"
            monitor_nl
            foreach sf $sframes {
                lassign $sf u v
                if {"bisection" in $methods} {
                    lassign [solver::bisection $u $v $e] bres niter
                    lappend bisection_solns $bres
                    monitor "    Bisection result = [format $fmt $bres] ; niter = $niter\n"
                }
                if {"nr" in $methods} {
                    set xt [/ [+ $u $v] 2]
                    lassign [solver::n-r-from $xt $e] nres niter
                    monitor "    x = [format $fmt $nres] ; x0 = [format $fmt $xt] ;  niter = $niter\n"
                    lappend nr_solns $nres
                }
            }
            monitor_nl
        }
        trace::mess {<<<=======================================================}

        if {[info exists res]} {
            set cval $res
        }
        set has_lw 1
        if {$a eq {e}} {
            if {$d != 1 && $c != 0} {
                set has_lw 0
            } else {
                set warg [expr {exp(double($c)/$b)}]
            }
        } else {
            if {$c == 0 && $b == -1} {
                set warg [expr {-log($a)/$d}]
            } elseif {$d == 1} {
                set warg [expr {($a ** ($c / double($b))) * log($a) / $b}]
            } else {
                set has_lw 0
            }
        }
        
        # Nothing more to to if LambertW not applicable
        if {! $has_lw} {
            monitor "\n[string repeat = 60]\n"
            monitor "\nNo Lambert W solution for c\u22600 and d>1"
            monitor_nl
            return
        }

        # For a^x = x^d (c=0, b=-1) with even d, a negative-x solution always exists
        # and is found via the positive W argument in calculate_third_lambert_value.
        # When ns==1 there are no positive-x solutions, so skip calculate_lambert_values.
        set has_neg_soln [expr {$c == 0 && $b == -1 && int($d)%2 == 0}]

        monitor "[string repeat = 60]\n\n"
        monitor "Analytically using Lambert-W function\n"
        monitor "-------------------------------------\n"
        monitor_nl
        monitor "Rearrange:\n"
        monitor_nl
        output_equations $a $b $c $d $e $warg $fmt

        monitor_nl
        trace::mess {==========================================================}

        monitor "To calculate W(u):\n"
        monitor "    if u < 0, solve for s: e**s + s/u = 0        then W(u)=-s\n"
        monitor "    if u > 0, solve for s: e**s + s - ln(u) = 0  then W(u)=e**s\n"
        monitor_nl
        monitor "In this case u = [format $fmt $warg]"
         if {$warg < -exp(-1.0)} {
            monitor " is < -1/e so there are no solutions\n"
        } else {
            set actual_ns $ns
            if {$actual_ns == 1} {
                monitor " so there is 1 solution\n"
           } else {
                monitor " so there are $actual_ns solutions:\n"
                monitor_nl
            }
        }

        if {!($has_neg_soln && $ns == 1)} {
            calculate_lambert_values $a $b $c $d $e $warg $nr_solns $fmt
        }
        if {$has_neg_soln || $ns == 3} {
            calculate_third_lambert_value $a $b $c $d $e $nr_solns $fmt
        }
        monitor "\n[string repeat = 60]\n"
        monitor_nl
        
        # Add copy button
        add_copy_button
        
        return
        
        monitor "This suggests the the original equation can be solved by\n"
        monitor "using 's' directly instead of the Lambda W function:\n"
        monitor_nl
        monitor "x = (s + log(b) - log(log(a)))/log(a)"
        monitor_nl
        monitor "  = ($s + log($b) - log(log($a)))/log($a)"
        monitor_nl
        if {$a == {e}} {
            set xdval $s
        } else {
            set xdval [expr {($s + log($b) - log(log($a)))/log($a)}]
        }
        monitor "  = "
        report_result  $nr_solns $e $xdval


    }

    proc add_copy_button {} {
        variable tx
        set cpy_b [ttk::button $tx.cpy -text "Copy" -command "GUI::copy_to_clipboard"]
        $tx window create end -window $cpy_b
    }
       
    proc report_result {solns e v} {
        variable fmt
        if {[solver::is_in_solution_set $solns $e $v] >= 0} {
            monitor "[format $fmt $v]" correct_val
        } else {
            monitor "[format $fmt $v]" incorrect_val
        }
        monitor_nl
    }
    
    proc with_sup {s} {
        # Return a list of {text tag} pairs; exponents get tag "sup"
        set result {}
        set pos 0
        set len [string length $s]
        while {$pos < $len} {
            set fsup [string first {**} $s $pos]
            set fsub [string first {__} $s $pos]
            if {$fsup < 0} { set fsup $len }
            if {$fsub < 0} { set fsub $len }
            if {$fsup <= $fsub} {
                set found $fsup ; set tag sup
            } else {
                set found $fsub ; set tag sub
            }
            if {$found >= $len} {
                lappend result [list [string range $s $pos end] {}]
                set pos $len
            } else {
                if {$found > $pos} {
                    lappend result [list [string range $s $pos [expr {$found - 1}]] {}]
                }
                set pos [expr {$found + 2}]
                set exp {}
                if {$pos < $len && [string index $s $pos] eq {(}} {
                    incr pos
                    while {$pos < $len && [string index $s $pos] ne {)}} {
                        append exp [string index $s $pos]
                        incr pos
                    }
                    if {$pos < $len} { incr pos }
                } else {
                    while {$pos < $len} {
                        set c [string index $s $pos]
                        if {[string match {[-0-9a-zA-Z+]} $c]} {
                            append exp $c
                            incr pos
                        } else {
                            break
                        }
                    }
                }
                if {$exp ne {}} {
                    lappend result [list $exp $tag]
                }
            }
        }
        return $result
    }

    proc monitor {line {t {}}} {
        variable tx
        $tx configure -state normal
        foreach seg [with_sup $line] {
            lassign $seg text seg_tag
            if {$seg_tag ne {}} {
                $tx insert end $text [if {$t ne {}} {list $seg_tag $t} else {list $seg_tag}]
            } else {
                $tx insert end $text $t
            }
        }
        $tx configure -state disabled
    }
   
    proc monitor_nl {} {
        variable tx
        $tx configure -state normal
        $tx insert end "\n"
        $tx configure -state disabled
    }
    
}

# =================================================================================

set ::v 0
trace::inout_off

if {$argc == 3} {
    lassign $argv a b c
} else {
    lassign {0.5 -3 4} a b c
}
if {$a <=0} {
    puts "***Error: a must be > 0"
    exit 1
}
# if {$b == 1} {
#     puts "Solving $a**x + x - $c = 0"
# } else {
#     puts "Solving $a**x + ${b}x - $c = 0"
#}
if {$::v > -1} {
    foreach cmd {
        solver::number_of_solns
        solver::lambert_w
        solver::set_params
        GUI::invoke_solver
        GUI::calculate
        f f' solver::get_solution_frames solver::bisection} {
        trace add execution $cmd enter trace::in
        trace add execution $cmd leave trace::out
    }
}

GUI::create
#GUI::set_displayed_parameters $a $b $c
#set e [expr {abs([f 1.71])}]
#puts "e = $e"
#set a 1
#set b 2
#bisection f $a $b $e
#set e 1.e-6
solver::set_functions f f'
#set result [solver::n-r $e]

#puts [join $result \n]
