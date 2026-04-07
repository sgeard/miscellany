namespace import ::tcl::mathop::* ::tcl::mathfunc::*

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
                set e_lna  [expr {exp(1.0)*log($params(a))}]
                set d_even [expr {$params(d)%2 == 0}]
                if {$params(d) > $e_lna} {
                    return [expr {$d_even ? 3 : 2}]
                } elseif {abs($params(d) - $e_lna) < 1.0e-4} {
                    return [expr {$d_even ? 2 : 1}]
                } else {
                    return [expr {$d_even ? 1 : 0}]
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
            # W(u) = -s  where e**s+s/u = 0
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

# =================================================================================
# Equation functions: evaluate the current solver equation and its derivative.
# These read solver::params set by solver::set_params.

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
