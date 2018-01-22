using ParameterizedFunctions, DiffEqBase
using Base.Test

using SpecialFunctions

### ODE Macros

println("Build some examples")
f_t = @ode_def_nohes SymCheck begin # Checks for error due to symbol on 1
  dx = x
  dy = -c*y + d*x*y*t^2
end a b c d

@test has_syms(f_t)

f_t2 = @ode_def_noinvjac SymCheck2 begin # Checks for error due to symbol on 1
  dx = 1
  dy = -c*y + d*x*y*t^2
end a b c d

f_t3 = @ode_def_noinvjac ExprCheck begin # Checks for error due to symbol on 1
  dx = a*x - b*x*y
  dy = -c*y + d*x*y
end a b c d # Change to π after unicode fix

f = @ode_def_noinvhes LotkaVolterra begin
  dx = a*x - b*x*y
  dy = -c*y + d*x*y
end a b c d

f_2 = @ode_def_nohes LotkaVolterra3 begin
  dx = a*x - b^2*x*y
  dy = -c*y + d*x*y
end a b c d

println("Test Values")
@test num_params(f_t) == 4
@test num_params(f) == 4
t = 1.0
u = [2.0,3.0]
p = [1.5,1,3,1]
du = zeros(2)
grad = similar(du)
J = zeros(2,2)
iJ= zeros(2,2)
iW= zeros(2,2)
f(du,u,p,t)
@test du == [-3.0,-3.0]
@test du == f(u,p,t)
f_t(du,u,p,t)
@test du == [2.0,-3.0]
f_t2(du,u,p,t)
@test du == [1.0,-3.0]

println("Test t-gradient")
f(Val{:tgrad},grad,u,p,t)
@test grad == zeros(2)
f_t(Val{:tgrad},grad,u,p,t)
@test grad == [0.0;12.0]

println("Test Jacobians")
f(Val{:jac},J,u,p,t)
f(Val{:invjac},iJ,u,p,t)
@test J  == [-1.5 -2.0
             3.0 -1.0]
@test f(Val{:jac}, u, p, t) == [-1.5 -2.0; 3.0 -1.0]
@test minimum(iJ - inv(J) .< 1e-10)

println("Test Inv Rosenbrock-W")
f(Val{:invW},iW,u,p,2.0,t)
@test minimum(iW - inv(I - 2*J) .< 1e-10)

f(Val{:invW_t},iW,u,p,2.0,t)
@test minimum(iW - inv(I/2 - J) .< 1e-10)

println("Parameter Jacobians")
pJ = Matrix{Float64}(2,4)
f(Val{:paramjac},pJ,u,[2.0;2.5;3.0;1.0],t)
@test pJ == [2.0 -6.0 0 0.0
             0 0 -3.0 6.0]

@code_llvm has_jac(f)

println("Test booleans")
@test has_jac(f) == true
@test has_invjac(f) == true
@test has_hes(f) == false
@test has_invhes(f) == false
@test has_paramjac(f) == true

@code_llvm has_paramjac(f)

println("Test difficult differentiable")
NJ = @ode_def_nohes DiffDiff begin
  dx = a*x - b*x*y
  dy = -c*y + erf(x*y/d)
end a b c d
NJ(du,u,[1.5,1,3,4],t)
@test du == [-3.0;-3*3.0 + erf(2.0*3.0/4)]
@test du == NJ(u, [1.5,1,3,4], t)
# NJ(Val{:jac},t,u,J) # Currently gives E not defined, will be fixed by the next SymEgine

test_fail(x,y,d) = erf(x*y/d)
println("Test non-differentiable")
NJ = @ode_def NoJacTest begin
  dx = a*x - μ*x*y
  dy = -c*y + test_fail(x,y,d)
end a μ c d
NJ(du,u,[1.5,1,3,4],t)
@test du == [-3.0;-3*3.0 + erf(2.0*3.0/4)]
@test du == NJ(u,[1.5,1,3,4],t)
@test_throws MethodError NJ(Val{:jac},iJ,u,p,t)
# NJ(Val{:jac},t,u,J) # Currently gives E not defined, will be fixed by the next SymEgine

println("Make sure all of the problems in the problem library build")
using DiffEqProblemLibrary
