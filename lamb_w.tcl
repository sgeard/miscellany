package require Tk

namespace import ::tcl::mathop::* ::tcl::mathfunc::*

namespace eval solver {

    variable monitor {puts}
    variable g {}
    variable g'{}
    variable max_iter 128
    variable xt {}; # Tangent point
    variable params
    
    proc set_functions {f f'} {
        variable g
        variable g'
        set g f
        set g' f'
    }
    
    proc set_monitor_f {f} {
        variable monitor
        set monitor $f
    }
    
    proc is_in_solution_set {s e v} {
        for {set i 0} {$i < [llength $s]} {incr i} {
            if {abs([lindex $s $i]-$v) <= $e} {
                return $i
            }
        }
        return -1
    }
            
    proc set_params {a b c d e} {
        variable params
        array set params [list a $a b $b c [expr "$c"] d $d e $e]
        if {$params(a) eq {e}} {
            #set params(a) [expr {exp(1.0)}]
        }
        foreach an [lsort [array names params]] {
            trace::mess "params($an) = $params($an)"
        }
    }
    
    proc get_params {} {
        variable params
        return [array get params]
    }
    
    proc get_solution_frames {ns start end_stop} {
        variable g
        #trace::inout_off
        set nfound 0
        set start -10
        set ys [$g $start]
        set sframes [list]
        set delta_min 0.1
        set delta $delta_min
        while {$nfound < $ns} {
            set end [+ $start $delta]
            set ye [$g $end]
            trace::mess "nfound = $nfound ; ns = $ns ; s = ($start,$ys) ; e = ($end,$ye)"
            if {$ys * $ye < 0} {
                trace::mess "ys = $start,$ys ; ye = $end,$ye"
                if {$ys < 0 && $ye >= 0} {
                    set u $start
                    set v $end
                } elseif {$ys > 0 && $ye <= 0} {
                    set u $end
                    set v $start
                }
                lappend sframes [list $u $v]
                incr nfound
            }
            set start $end
            set ys $ye
            if {$start > $end_stop} {
                break
            }
            set delta [expr {$end > 10 ? 0.5*10**(int(log10($end))+1) : $delta_min}]
            trace::mess "end = $end ; delta = $delta"
        }
        #trace::inout_on
        return $sframes
    }
    
    proc bisection {a b e} {
        variable g
        trace::mess "Bisection on ($a,$b):\n"
        set fa [$g $a]
        set fb [$g $b]
        set i 1
        if {$fa * $fb > 0} {
            error "$a -> $b is not a valid interval"
        }
        set flast $fa
        while {$i > 0} {
            set r [expr {($a + $b)*0.5}]
            set fr [$g $r]
            if {(abs($fr) < $e) || abs($fr-$flast) < $e} {
                break
            }
            incr i
            if {$fr * $fa > 0} {
                set a $r
                set fa $fr
            } else {
                set b $r
                set fb $fr
            }
            set flast $fr
        }
        if {$::v > 0} {
            trace::mess "$i r = [format %0.7f $r]"
        }
        return [list $r $i]
    }

    proc n-r-from {x0 e {vb {0}}} {
        variable g
        variable g'
        variable monitor
        variable max_iter
        set i 1
        if {$vb > 0} {
            $monitor "\tx(0) = [format %0.8f $x0]; f(x) = [format %0.8f [$g $x0]]\n"
        }
        set x1 $x0
        while {$i > 0 && $i < $max_iter} {
            set f1 [$g $x1]
            if {! [info exists flast]} {
                set flast $f1
            }
            set fp1 [$g' $x1]
            set x2 [expr {$x1 - $f1/$fp1}]
            set f2 [$g $x2]
            if {$vb > 0} {
                $monitor "\tx($i) = [format %0.8f $x2]; f(x) = [format %0.8f $f2]\n"
            }
            set x1 $x2
            if {abs($f2) < $e || abs($f2-$flast) < $e} {
                break
            }
            incr i
            set flast $f2
        # puts {}
        }
        if {$vb > 0} {
            $monitor "\t$i iterations, x = [format %0.8f $x1]\n"
        }
        return [list $x1 $i $x0]
    }
    
    proc ok {n} {
        variable max_iter
        return [expr {$n < $max_iter}]
    }
    
    proc number_of_solns {} {
        variable g
        variable xt
        variable params
        
        #
        # a**x - bx = c
        #
        # where a>0 & a!=1
        #
        # Consider this as intersecting the curve a**x and the line bx + c
        #
        # If a > 1 the gradient is > 0 everywhere so if b < 0 there is exactly intersection,
        #                                               b > 0 there are 0, 1 or 2 solutions
        #
        # In the b>0 case compute the tangent point t on a**x.
        #    then if a**t > bt+c there is no solution
        #            a**t = bt+c there is one solution (x = t)
        #            a**t < bt+c there are two solutions
        # In  the 2 solutions case the startng points for NR iteration are t-a and t+a
        #
        # The same logic applies if a<1 
        
        # If c=0 b<0 d>1
        # d even => n = 3
        # d odd  => n = 2
        
        # Note that for a**x = x**2n the tangency condition is 2n = e*ln(a)
        # so if 2n > e*ln(a) there will be 2 solutions > 0
        
        set xt {}
        if {$params(a) eq {e}} {
            set params(a) [expr {exp(1.0)}]
        }
        if {$params(a) == 1 || $params(a) <= 0} {
            return 0
        }
        foreach {k v} [array get params] {
            trace::mess "$k -> $v -> [expr $v]"
        }
        if {($params(a) > 1 && $params(b) > 0) ||
            ($params(a) < 1 && $params(b) < 0)} {
            # Always exactly one solution
            return 1
        }
        
        if {$params(c) == 0 && $params(b) < 0} {
            if {$params(b) == -1} {
                if {$params(d) > exp(1.0)*log($params(a))} {
                    return 3
                } elseif {abs($params(d) - exp(1.0)*log($params(a))) < 1.0e-4} {
                    return 2
                } else {
                    return 1
                }
                
            } else {
                if {$params(d)%2 == 0} {                    
                    return 3
                } else {
                    return 2
                }
            }
        }
        
        # Calculate the tangent point. If a is < 1 then replace it with 1/a and change the sign of b
        if {$params(a) < 1} {
            set params(a) [expr {1.0/$params(a)}]
            set params(b) [expr {-$params(b)}]
        }
        set xt [expr {(log(abs($params(b))) - log(log($params(a)))/log($params(a)))}]
        if {$params(a) < 1} {
            set xt [expr {-$xt}]
        }
        if {$::v > 0} {
            trace::mess "xt = $xt ; b*xt+c = [expr {$params(b)*$xt+$params(c)}] ; f(xt) = [$g $xt]"
        }
        if {$params(d) == 1} {
            set xt 0
        } else {
            if {[$g $xt] > 0} {
                trace::mess "No solutions"
                return 0
            }
        }
        return 2
    }
    
    proc get_tangent_point {} {
        variable xt
        return $xt
    }
    
    proc lambert_w {u e} {
        variable params
        
        trace::mess " $::v : ==> u = $u <=="
        # If ln(u) > 0
        if {$u > 0} {
            set_params {e} 1 [expr {log($u)}] 1 $e
            
        } elseif {abs($u) < $e} {
            return [list 0.0]
        
        } else {
            # W(-u) = -s  where e**s-s/u = 0
            set_params {e} [expr {1/$u}] 0 1 $e
            
        }
        set ns [number_of_solns]
        trace::mess "ns = $ns"
        set frames [get_solution_frames $ns -10 1000000]
        trace::mess "frames = $frames"
        set w_values [list]
        foreach f $frames {
            lassign $f f t
            trace::mess "$f -> $t"
            lassign [n-r-from [expr {($f+$t)/2}] $e 0] s niter x0
            if {[ok $niter]} {
                if {$u > 0} {
                    lappend w_values [expr {exp($s)}]
                } else {
                    lappend w_values [expr {-$s}]
                }
            }
        }
        set w_values [lsort -real -decreasing $w_values]
        return $w_values
    }
}

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
                $le.en configure -textvariable "GUI::$v" -width 6
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
        
        set tx [text $fr.tx -width 60 -height 45]
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
        $tx insert end "Solving the exponential equation:\n"
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

        set fmt "%0.[int [- [log10 $e]]]f"
        set warg [expr "$w_arg"]
        set s_value [solver::lambert_w $warg $e]
        lassign $s_value s1 s2
        set w_res [format $fmt $s1]
        trace::mess $w_res
        if {[llength $s_value] > 1} {
            append w_res ", [format $fmt $s2]"
        }
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

        set fmt "%0.[int [- [log10 $e]]]f"
        trace::mess "fmt = $fmt"
        trace::mess {>>>=======================================================}
        set ns [solver::number_of_solns]

        trace::mess "Searching for $ns solutions"

        if {$ns >= 1} {
            set sframes [solver::get_solution_frames $ns -10 1000000]
            set str "[llength $sframes] intervals found \{"
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
                    monitor "\tBisection result = [format $fmt $bres] ; niter = $niter\n"
                }
                if {"nr" in $methods} {
                    set xt [/ [+ $u $v] 2]
                    lassign [solver::n-r-from $xt $e] nres niter
                    monitor "\tN-R result = [format $fmt $nres] ; x0 = [format $fmt $xt] ;  niter = $niter\n\n"
                    lappend nr_solns $nres
                }
            }
        } else {
            monitor "$ns   "
        }
        trace::mess {<<<=======================================================}

        if {[info exists res]} {
            set cval $res
        }
        #monitor ", $niter iterations ; x0 = [format %0.8f $x0]\n"
        #monitor_nl
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
        monitor "Rearranging to use the Lambert W-function method:\n"
        monitor_nl
        if {$has_lw} {
            if {$a eq {e}} {
                monitor "x = $c/$b - W(${a}**(${c}/$b))"
                monitor_nl
                monitor "  = $c/$b - W([format %0.8f $warg])\n"
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
        } else {
            monitor "\n[string repeat = 60]\n"
            monitor "\nNo Lambert W solution for c\u22600 and d>1"
            monitor_nl
        }
        monitor_nl
        monitor "[string repeat = 60]\n"
        monitor_nl
        trace::mess {==========================================================}

        if {$has_lw} {
            #stack::push $::v
            #set ::v 1
            monitor "To calculate W(u), first solve the basic equation:\n"
            monitor_nl
            monitor "u = [format $fmt $warg] ; eps = $e"
            monitor_nl
            trace::mess "warg = $warg ; e = $e"
            set s_value [solver::lambert_w $warg $e]
            if {[llength $s_value] == 0} {
                set w_res {No solutions}
            } else {
                lassign $s_value s1 s2
                set w_arg $warg
                set w_res [format $fmt $s1]
                trace::mess $w_res
                if {[llength $s_value] > 1} {
                    append w_res ", [format $fmt $s2]"
                }
                if {$warg > 0} {
                    monitor "e**x + x - ln(u) = 0\n"
                    monitor "Let s = x, then W($warg) = log(u) - s = e**s"
                } else {
                    monitor "e**x - x/u = 0\n"
                    monitor_nl

                    monitor "There are two solutions s1 and s2 such that s1 > s2:\n"
                    monitor "\t W0([format $fmt $warg]) = [format $fmt $s1]\n"
                    monitor "\tW-1([format $fmt $warg]) = [format $fmt $s2]"
                }
                monitor_nl
            }
            monitor_nl
            monitor "therefore\n"
            foreach w $s_value {
                set ws [format $fmt $w]
                monitor_nl
                if {$a eq {e}} {
                    if {$c == 0} {
                        monitor "\tx = - $ws\n"
                        set xw [expr "- $w"]
                    } else {
                        monitor "\tx = $c/$b - $ws\n"
                        set xw [expr "$c/double($b) - $w"]
                    }
                } else {
                    if {$c == 0} {
                        monitor "\tx = - $d*$ws/log($a)\n"
                        set xw [expr "- $d*$w/log($a)"]
                    } else {
                        monitor "\tx = $c/$b - $d*$ws/log($a)\n"
                        set xw [expr "$c/double($b) - $d*$ws/log($a)"]
                    }
                }
                monitor "\t  = "
                report_result $nr_solns $e $xw
            }
            monitor_nl
            if {$ns == 3} {
                monitor "\nThird (negative) solution uses W0 of positive argument:\n"
                monitor_nl
                if {abs($b) == 1} {
                    if {$d == 1} {
                        set warg3 [expr {log($a)}]
                        monitor "  u = ln($a) = [format $fmt $warg3]\n"
                    } else {
                        set warg3 [expr {log($a) / ($d)}]
                        monitor "  u = ln($a)/$d = [format $fmt $warg3]\n"
                    }
                } else {
                    if {$d == 1} {
                        set warg3 [expr {log($a) / abs($b)}]
                        monitor "  u = ln($a)/$d = [format $fmt $warg3]\n"
                    } else {
                        set warg3 [expr {log($a) / ($d * abs($b) ** (1.0/$d))}]
                        monitor "  u = ln($a) / ($d * |$b|^(1/$d)) = [format $fmt $warg3]\n"
                    }
                }
                set w3_list [solver::lambert_w $warg3 $e]
                set w3 [lindex $w3_list 0]
                monitor "  W0([format $fmt $warg3]) = [format $fmt $w3]\n"
                set x3 [expr {- double($d) * $w3 / log($a)}]
                monitor_nl
                if {$d == 1} {
                    monitor "  x = -W0/log($a) = "
                } else {
                    monitor "  x = -$d*W0/log($a) = "
                }
                report_result $nr_solns $e $x3
                monitor_nl
            }
            monitor "\n[string repeat = 60]\n"
        }

        monitor_nl
        
        # Add copy button
        set cpy_b [ttk::button $tx.cpy -text "Copy" -command "GUI::copy_to_clipboard"]
        $tx window create end -window $cpy_b
        
        #set ::v [stack::pop]
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

    proc report_result {solns e v} {
        variable fmt
        if {[solver::is_in_solution_set $solns $e $v] >= 0} {
            monitor "[format $fmt $v]" correct_val
        } else {
            monitor "[format $fmt $v]" incorrect_val
        }
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

proc f {x} {
    array set pars [solver::get_params]
    set r [expr {$pars(a)**$x + double($pars(b))*$x**$pars(d) - $pars(c)}]
    if {$::v > 2} {
        trace::mess "$pars(a)**$x + double($pars(b))*$x**$pars(d) - $pars(c)"
        trace::mess "f([format %0.7f $x]) = [format %0.7f $r]"
    }
    return $r
}

proc f' {x} {
    array set pars [solver::get_params]
    set r [expr {(log($pars(a)))*($pars(a)**$x) + $pars(d)*$pars(b)*$x**($pars(d)-1)}]
    if {$::v > 2} {
        trace::mess "f'([format %0.6f $x]) = [format %0.6f $r]"
    }
    return $r
}

# =================================================================================

namespace eval stack {
    variable data {}
    proc push {d} {
        variable data
        lappend data $d
    }
    proc pop {} {
        variable data
        set e [lindex $data end]
        set data [lrange $data 0 end-1]
        return $e
    }
    proc clear {} {
        variable data
        set data [list]
    }
    proc size {} {
        variable data
        return [llength $data]
    }
}

# =================================================================================

namespace eval trace {
    variable level 0
    variable inout 0
    
    proc inout_on {} {
        variable inout
        set inout 1
    }
    
    proc inout_off {} {
        variable inout
        set inout 0
    }
    proc in {args} {
        variable level
        variable inout
        if {$inout} {
            puts "[indent][lindex $args 0 0]<in>"
        }
        incr level
        if {$inout} {
            set in_args [lrange [lindex $args 0] 1 end]
            if {[llength $in_args] > 0} {
                puts "[indent]called with: $in_args"
            }
        }
    }
    proc out {args} {
        variable level
        variable inout
        set out_val [lindex $args 2]
        if {$inout} {
            if {[llength $out_val] > 0} {
                puts "[indent]returning $out_val"
            }
        }
        incr level -1
        if {$inout} {
            puts "[indent][lindex $args 0 0]<out>"
        }
    }
    proc mess {str} {
        if {$::v > 0} {
            puts "[indent]${str}"
        }
    }
    proc indent {} {
        variable level
        if {$level <= 0} {
            return {}
        } else {
            return [string repeat {   } $level]
        }
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
