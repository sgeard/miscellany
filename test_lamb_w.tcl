package require tcltest
namespace import tcltest::*

set ::v 0
source [file join [file dirname [info script]] solver.tcl]
solver::set_functions f f'

# Helper: true if two reals agree to tolerance
proc approx {a b {tol 1e-6}} {
    expr {abs($a - $b) < $tol}
}

# Helper: true if a list has exactly n elements
proc nvals {lst n} {
    expr {[llength $lst] == $n}
}

# =============================================================================
# solver::lambert_w
# =============================================================================

# W(0) = 0 (special-cased in the code)
test lambert_w-1 {W(0) = 0} -body {
    lindex [solver::lambert_w 0.0 1e-8] 0
} -result 0.0

# W(e) = 1  (because 1*e^1 = e)
test lambert_w-2 {W(e) = 1} -body {
    approx [lindex [solver::lambert_w [expr {exp(1.0)}] 1e-8] 0] 1.0
} -result 1

# W(1) ≈ 0.56714329  (Omega constant)
test lambert_w-3 {W(1) = Omega constant} -body {
    approx [lindex [solver::lambert_w 1.0 1e-8] 0] 0.56714329
} -result 1

# W(2*e^2) = 2  (because 2*e^2 = u where w*e^w=u has solution w=2)
test lambert_w-4 {W(2*e^2) = 2} -body {
    approx [lindex [solver::lambert_w [expr {2*exp(2.0)}] 1e-8] 0] 2.0
} -result 1

# For u < 0 (but > -1/e) there are two branches W0 and W-1
# u = -0.1: W0 ≈ -0.11183255 , W-1 ≈ -3.57715469
test lambert_w-5 {W(-0.1) returns two values} -body {
    nvals [solver::lambert_w -0.1 1e-8] 2
} -result 1

test lambert_w-6 {W0(-0.1) ≈ -0.11183255} -body {
    approx [lindex [solver::lambert_w -0.1 1e-8] 0] -0.11183255
} -result 1

test lambert_w-7 {W-1(-0.1) ≈ -3.5772} -body {
    approx [lindex [solver::lambert_w -0.1 1e-8] 1] -3.57715469 1e-4
} -result 1

# Verify the defining relation W(u)*exp(W(u)) = u for several values
test lambert_w-8 {defining relation holds for u=2} -body {
    set w [lindex [solver::lambert_w 2.0 1e-8] 0]
    approx [expr {$w * exp($w)}] 2.0 1e-6
} -result 1

test lambert_w-9 {defining relation holds for u=10} -body {
    set w [lindex [solver::lambert_w 10.0 1e-8] 0]
    approx [expr {$w * exp($w)}] 10.0 1e-5
} -result 1

test lambert_w-10 {defining relation holds for u=-0.2} -body {
    set ws [solver::lambert_w -0.2 1e-8]
    set w0 [lindex $ws 0]
    approx [expr {$w0 * exp($w0)}] -0.2 1e-6
} -result 1

# =============================================================================
# solver::number_of_solns
# =============================================================================

# a>1, b>0 -> always 1 solution  (e.g. 2^x + x = 3)
test nsolns-1 {a>1 b>0 -> 1 solution} -body {
    solver::set_params 2 1 3 1 1e-6
    solver::number_of_solns
} -result 1

# a>1, b<0, c=0, d=6 (even) -> 3 solutions  (e.g. 9^x = x^6)
test nsolns-2 {9^x = x^6 -> 3 solutions} -body {
    solver::set_params 9 -1 0 6 1e-6
    solver::number_of_solns
} -result 3

# a>1, b<0, c≠0, d=1 with tangent point below line -> 2 solutions (2^x = 9x+4)
test nsolns-3 {2^x = 9x+4 -> 2 solutions} -body {
    solver::set_params 2 -9 4 1 1e-6
    solver::number_of_solns
} -result 2

# a=2, b=-1, c=0, d=3 (odd, d=3 > e*ln(2) ≈ 1.88) -> 2 positive solutions, no negative-x solution
test nsolns-3b {2^x = x^3 odd d > e*ln(a) -> 2 solutions} -body {
    solver::set_params 2 -1 0 3 1e-6
    solver::number_of_solns
} -result 2

# a=9, b=-1, c=0, d=3 (odd, d=3 < e*ln(9) ≈ 5.97) -> no solutions
test nsolns-3c {9^x = x^3 odd d < e*ln(a) -> 0 solutions} -body {
    solver::set_params 9 -1 0 3 1e-6
    solver::number_of_solns
} -result 0

# a=9, b=-1, c=0, d=7 (odd, d=7 > e*ln(9) ≈ 5.97) -> 2 positive solutions
test nsolns-3d {9^x = x^7 odd d > e*ln(a) -> 2 solutions} -body {
    solver::set_params 9 -1 0 7 1e-6
    solver::number_of_solns
} -result 2

# a=9, b=-1, c=0, d=4 (even, d=4 < e*ln(9) ≈ 5.97) -> 1 solution (negative x only)
test nsolns-3e {9^x = x^4 even d < e*ln(a) -> 1 solution} -body {
    solver::set_params 9 -1 0 4 1e-6
    solver::number_of_solns
} -result 1

# a>1, b<0, c=0, d=4, b=-2 (even, b!=-1) -> 3 solutions
test nsolns-4 {2^x = 2x^4 -> 3 solutions} -body {
    solver::set_params 2 -2 0 4 1e-6
    solver::number_of_solns
} -result 3

# =============================================================================
# solver::is_in_solution_set
# =============================================================================

test is_in_soln-1 {value present within tolerance} -body {
    solver::is_in_solution_set {1.0 2.0 3.0} 1e-6 2.0000005
} -result 1

test is_in_soln-2 {value absent} -body {
    solver::is_in_solution_set {1.0 2.0 3.0} 1e-6 2.5
} -result -1

test is_in_soln-3 {empty set} -body {
    solver::is_in_solution_set {} 1e-6 1.0
} -result -1

cleanupTests
