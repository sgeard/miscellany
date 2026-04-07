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
        set a 9 ; set b -1 ; set c 0 ; set d 6; set e 1.0e-6
        set fr [ttk::frame .fr]
        set lab [ttk::label $fr.lab -text {Solve: a**x + bx**d - c = 0} ]
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
        $tx tag configure correct_val -background yellow
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
        $tx insert end "\t${av}**x "
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
            $tx insert end "**$dv "
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
    
    proc copy_to_clipboard {} {                                                                                                                                                    
        variable tx                                                                                                                                                                
        clipboard clear                                                                                                                                                            
        clipboard append [$tx get 1.0 end]                                                                                                                                         
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
    
    proc output_equations {a b c d e warg} {
        if {$a eq {e}} {
            if {$b == 1} {
                monitor "x = $c - W(${a}**(${c}))\n"
                monitor "  = $c - W([format %0.8f $warg])\n"
            } else {
                monitor "x = $c/$b - W(${a}**(${c}/$b))\n"
                monitor "  = $c/$b - W([format %0.8f $warg])\n"
            }
        } else {
            if {$c == 0 && $b == -1} {
                monitor "x = - $d*W(-log($a)/$d)/log($a)"
                monitor_nl
                monitor "  = - $d*W([format %0.8f $warg])/log($a)\n"
            } else {
                monitor "x = $c/$b - W(${a}**(${c})*log($a)/$b)/log($a)"
                monitor_nl
                monitor "  = $c/$b - W([format %0.8f $warg])/log($a)\n"
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

        if {$warg < 0} {
            monitor "There are two solutions s1 and s2 such that s1 > s2:\n"
            monitor "     W0([format $fmt $warg]) = [format $fmt $s1]\n"
            monitor "    W-1([format $fmt $warg]) = [format $fmt $s2]"
        }
        monitor_nl

        monitor_nl
        monitor "therefore\n"
        monitor_nl
        foreach w $s_value {
            set ws [format $fmt $w]

            if {$a eq {e}} {
                if {$c == 0} {
                    monitor "    x = - $ws"
                    set xw [expr "- $w"]
                } else {
                    monitor "    x = $c/$b - $ws"
                    set xw [expr "$c/double($b) - $w"]
                }
            } else {
                if {$c == 0} {
                    monitor "    x = - $d*$ws/log($a)"
                    set xw [expr "- $d*$w/log($a)"]
                } else {
                    monitor "    x = $c/$b - $d*$ws/log($a) "
                    set xw [expr "$c/double($b) - $d*$ws/log($a)"]
                }
            }
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
        monitor "    W0([format $fmt $warg3]) = [format $fmt $w3]\n"
        set x3 [expr {- double($d) * $w3 / log($a)}]
        monitor_nl
        if {$d == 1} {
            monitor "    x = -W0/log($a) = "
        } else {
            monitor "    x = -$d*W0/log($a) = "
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
                monitor "No solutions: a^x lies entirely above b\u00b7x^d + c"
                monitor " (curves are tangent at x \u2248 [format %.4f $xt])\n"
            }
            monitor "\n[string repeat = 60]\n"
            add_copy_button
            return
        }

        if {$ns >= 1} {
            set sframes [solver::get_solution_frames $ns -10 1000000]
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
                set warg [* [** $a $c] [/ [log $a] $b]]
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
        output_equations $a $b $c $d $e $warg

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
            monitor_nl
        }
        monitor_nl
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
    
    proc monitor {line {t {}}} {
        variable tx
        $tx configure -state normal
        $tx insert end "${line}" $t
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
