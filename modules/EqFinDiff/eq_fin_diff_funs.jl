
# function deriv_calculator(f, x, h)
#     return (f(x+h) - f(x))/h
# end
function eq_set_k_struct(svm, mu_b::Float64, m::Float64, c::Float64, p::Float64)
    mu_b, m, c, p = get_k_struct(svm; mu_b=mu_b, m=m, c=c, p=p)
    return Main.ModelObj.KStruct(mu_b, m, c, p, NaN)
end


function eq_get_boundary_vgrid(svm, ks, vbl; vtN::Int64=1500)
    # V MAX:
    println("Computing Equity Vmax")
    eq_Vmax = get_eq_Vmax(svm; mu_b=ks.mu_b, m=ks.m, c=ks.c, p=ks.p)
    println(string("Equity Vmax: ", eq_Vmax))
    println(" ")

    # vtgrid
    vtgrid = reverse(range(0.0, stop=log(eq_Vmax/float(vbl)), length=vtN))
    
    # #################################
    # ######## Boundary Values ########
    # #################################
    # Upper Barrier: Value of Equity
    eq_max = get_cvm_eq(svm, vbl * exp(vtgrid[1]), svm.pm.sigmal;
                        mu_b=ks.mu_b, m=ks.m, c=ks.c, p=ks.p)
    println(string("eq_max: ", eq_max))
    
    # Lower Barrier:
    eq_vbl = maximum([0., get_param(svm, :alpha) * vbl - get_pv_rfdebt(svm; mu_b=ks.mu_b, m=ks.m, c=ks.c, p=ks.p)])
    println(string("eq_vbl: ", eq_vbl))

    return vtgrid, eq_vbl, eq_max
end 


function eq_fd_newly_issued_bonds(svm, ks, vbl::Float64, vgrid;
                                  vtN::Int64=10^3, ftype::String="bf",
                                  spline_k::Int64=3,
                                  spline_bc::String="extrapolate")



    rfbond = rfbond_price(ks.m, ks.c, ks.p, svm.pm.r, svm.pm.xi, svm.pm.kappa)
    dpayoff = on_default_payoff(0., vbl, ks.m,
                                ks.mu_b, ks.m, ks.c, ks.p,
                                svm.pm.r, svm.pm.xi,
                                svm.pm.kappa, svm.pm.alpha)

    _, v_subgrid = grid_creator((1 + 1e-4) * minimum(svm.bs.vtgrid), maximum(vgrid), vtN)

    if get_obj_model(svm) == "cvm"
        bpr_vec = fetch(@spawn [get_cvm_bond_price(svm, ks.m, svm.pm.sigmal;
                                                   Vt=vbl * exp(v),
                                                   vb=vbl,
                                                   mu_b=ks.mu_b,
                                                   m=ks.m,
                                                   c=ks.c, p=ks.p)
                                for v in v_subgrid])
    else
        if abs.(svm.m - ks.m) > 1e-4  # use svm bst
            svm = bpr_interp_fixed_ttm(svm; ttm=ks.m)
            bpr_vec = fetch(@spawn [get_svm_bond_price(svm, vbl, ks.m;
                                                       Vt=vbl*exp(v), mu_b=ks.mu_b,
                                                       c=ks.c, p=ks.p,
                                                       ftype="bft") for v in v_subgrid])
        else
            bpr_vec = fetch(@spawn [get_svm_bond_price(svm, vbl, ks.m;
                                                       Vt=vbl*exp(v), mu_b=ks.mu_b,
                                                       c=ks.c, p=ks.p,
                                                       ftype=ftype) for v in v_subgrid])
        end
    end
    

    bpr = Dierckx.Spline1D(vcat(.0, v_subgrid), vcat(dpayoff, bpr_vec);
                           k=spline_k, bc=spline_bc)

    return Array([minimum([maximum([bpr(v)[1], dpayoff]), rfbond]) for v in vgrid])[2:end-1]
end


function eq_fd_core_cvmh_eq_values(svm, ks, vbl, vgrid)
    tic  = time()
    println("Computing Constant Volatility Equity Values")

    # vbh = get_cvm_vb(svm, svm.pm.sigmah; mu_b=mu_b, c=c, p=p)
    cvm_eqh_all = fetch(@spawn [get_cvm_eq(svm, vbl * exp(v), svm.pm.sigmah;
                                           mu_b=ks.mu_b, m=ks.m,
                                           c=ks.c, p=ks.p) for v in vgrid])
    
    println("Finished computing Constant Volatility Equity Values")
    println(string("Time to compute Constant Volatility Equity Values: ",  time() - tic))
    println(" ")

    return Array{Float64}(cvm_eqh_all)[2:end-1]
end


function eq_fd_core_coeffs(svm, vgrid)
    deltav = vgrid[1] - vgrid[2] 
    nu = get_rgrow(svm) - .5 * svm.pm.sigmal^2

    qu = .5 * (nu / deltav + svm.pm.sigmal^2 / (deltav^2))
    qd = .5 * (-nu / deltav + svm.pm.sigmal^2 / (deltav^2))

    lambda = get_param(svm, :lambda)
    qm = - (svm.pm.r + [!isnan(lambda) ? lambda : 0.0][1] + svm.pm.sigmal^2 / (deltav^2))

    return Dict{Symbol,Float64}(:deltav => deltav,
                                :nu => nu,
                                :qu => qu,
                                :qd => qd,
                                :qm => qm)
end


function eq_fd_core_matrices(svm, ks, vbl::Float64,
                             vgrid,
                             eq_vbl::Float64, eq_max::Float64,
                             bond_prices, cvm_eqh,
                             coeffs)

    # Gamma Vector:
    if get_obj_model(svm) == "cvm" 
        Gamma = (get_param(svm, :delta) * vbl * exp.(vgrid[2:end-1]) .+ 
                 ks.mu_b .* (-(1 - get_param(svm, :pi)) .* (ks.m * ks.c) .+ 
                             bond_prices .- ks.p))
    else
        lambda_cvm_eqh = [isnan(x) ? 0.0 : x for x in
                          get_param(svm, :lambda) * cvm_eqh]
        Gamma = (get_param(svm, :delta) * vbl * exp.(vgrid[2:end-1]) .+ 
                 ks.mu_b .* (-(1 - get_param(svm, :pi)) .* (ks.m * ks.c) .+ 
                             bond_prices .- ks.p) .+
                 lambda_cvm_eqh)
    end
 
    
    println(string("Shape of Gamma matrix: ", size(Gamma)))
    Gamma[1] += coeffs[:qu] * eq_max    
    Gamma[end] += coeffs[:qd] * eq_vbl

    # A Matrix:
    A = (coeffs[:qm] * Array(Diagonal(ones(size(Gamma, 1)))) +
         coeffs[:qu] * [1. *(y==x-1) for x in 1:size(Gamma, 1), y in 1:size(Gamma, 1)] +
         coeffs[:qd] * [1. *(y==x+1) for x in 1:size(Gamma, 1), y in 1:size(Gamma, 1)])

    return Gamma, A
end


function eq_fd_core_eq_values(svm, vbl, vgrid, eq_vbl, eq_max, Gamma, A; V0::Float64=NaN)
    # ###### Compute Pre-Volatility Shock Equity Function: ######
    # Form Function and add lim_v->infty E(v)
    eq_vals = vcat(eq_max, - A \ Gamma, eq_vbl)

    # Interpolate to back-out equity value at VB:
    eq_spl = Dierckx.Spline1D([vbl * exp(v) for v in reverse(vgrid)],
                              reverse(eq_vals); k=3, bc="extrapolate")

    # eq_spl = sp_interpolate.interp1d((vbl * exp.(reverse(vgrid))),
    # reverse(eq_vals), kind="cubic", fill_value="extrapolate")
    # eq_spl = sp_interpolate.PchipInterpolator((vbl * exp.(reverse(vgrid))),
    #                                   reverse(eq_vals))

    
    # Compute Derivative at Default Barrier:
    eq_spl_deriv = fetch(@spawn [Dierckx.derivative(eq_spl, vbl * exp(v)) for v in vgrid])
    eq_deriv = eq_spl_deriv[end]

    # Compute Derivative at Default Barrier:
    # eq_spl_deriv = eq_spl.derivative()(vbl .* exp(reverse(vgrid)))
    # eq_deriv = eq_pchip_deriv[1]
    # println(string("eq_deriv: ", eq_deriv))
    
    # # #######################################
    # h = 1e-5
    # eq_spl_deriv = fetch(@spawn [deriv_calculator(eq_spl, vbl * exp(v), h) 
    #                               for v=reverse(vgrid)])
    # eq_deriv = eq_spl_deriv[1]
    # # #######################################

    # Equity Values
    # Equity set as function of V:
    if any([isnan(V0), V0 > vbl * exp(maximum(vgrid))])
        V0 = get_param(svm, :V0)
    end

    if V0 < vbl
        e0 = 0.0
    else
        e0 = eq_spl(V0)
    end
    println(string("V0: ", V0, "; equity: ", e0))
    # e0 = eq_sitp(log(get_param(svm, :V0)/float(vbl)))

    # Look for negative values
    eq_min_val = minimum(reverse(eq_vals)[2:end])  # interpolate in a neighborhood
    eq_negative = eq_min_val .< -0.05 
    eq_deriv_min_val = minimum(eq_spl_deriv) 

    eq_dict = Dict(:V0 => V0,
                   :e0 => e0,
                   :eq_max => eq_max,
                   :eq_vals=>  eq_vals,
                   :eq_deriv => eq_deriv,
                   :eq_spl_deriv => eq_spl_deriv, 
                   :eq_vb => eq_vbl,
                   :eq_min_val => eq_min_val,
                   :eq_negative => eq_negative,
                   :eq_deriv_min_val => eq_deriv_min_val)
end


function eq_fd_core(svm, ks, vbl, eq_vbl,
                    eq_max, vgrid, bond_prices; V0::Float64=NaN)
    core_tic = time()

    # ##################################
    # ######## CVM Equity Values #######
    # ##################################
    if get_obj_model(svm) == "cvm" 
        cvm_eqh = NaN
    else
        cvm_eqh = eq_fd_core_cvmh_eq_values(svm, ks, vbl, vgrid)
    end

    # #################################
    # ######### Coefficients: #########
    # #################################
    coeffs = eq_fd_core_coeffs(svm, vgrid)

    # #################################
    # ########### Matrices: ###########
    # #################################
    Gamma, A = eq_fd_core_matrices(svm, ks, vbl,
                                   vgrid, eq_vbl, eq_max,
                                   bond_prices, cvm_eqh,
                                   coeffs)  

    # #################################
    # ######### Equity Values #########
    # #################################
    println("Computing equity values... ")
    core_eq_tic = time()
    eq_dict = eq_fd_core_eq_values(svm, vbl, vgrid,
                                   eq_vbl, eq_max,
                                   Gamma, A; V0=V0)
    
    println(string("Equity Core Function Computation Time: ", time() - core_eq_tic))
    
    println(string("Total Equity FD Core Function Computation Time: ", time() - core_tic))

    # return Gamma, A, eq_dict
    return eq_dict
end


function eq_fd_export_results(svm, ks, vbl::Float64,
                              eq_dict;
                              debt::Float64=NaN)

    # Compute Debt Price ########################
    if isnan(debt)
        if get_obj_model(svm) == "cvm"
            debt = get_cvm_debt_price(svm, vbl, svm.pm.sigmal;
                                      Vt=eq_dict[:V0],
                                      mu_b=ks.mu_b,
                                      c=ks.c, p=ks.p)
        else
            debt = get_svm_debt_price(svm, vbl;
                                      Vt=eq_dict[:V0],
                                      mu_b=ks.mu_b,
                                      c=ks.c, p=ks.p)
        end
    end
    # ##########################################
        
    # Get Firm Value:
    firm_value = debt + eq_dict[:e0]

    # Compute Leverage:
    lev = (debt / firm_value) * 100

    # Compute ROE:
    roe = (eq_dict[:e0] / (eq_dict[:V0] - debt) - 1.) * 100

    results = Dict(:V0 =>  eq_dict[:V0],
                   :r =>  svm.pm.r,
                   :gross_delta =>  get_param(svm, :gross_delta),
                   :iota=> svm.pm.iota,
 		   :delta=> get_param(svm, :delta),
                   :alpha=> svm.pm.alpha,
                   :pi=> svm.pm.pi,
                   :xi=> svm.pm.xi,
                   :kappa=> svm.pm.kappa,
                   :lambda=> svm.pm.lambda,
                   :sigmal => svm.pm.sigmal,
                   :sigmah => svm.pm.sigmah,
                   :mu_b => ks.mu_b,
                   :m =>  ks.m,
                   :c =>  ks.c,
                   :p =>  ks.p,
                   :vb =>  vbl,
                   :debt =>  debt,
                   :equity =>  eq_dict[:e0],
                   :eq_deriv =>  eq_dict[:eq_deriv],
                   :firm_value =>  firm_value,
                   :eq_min_val =>  eq_dict[:eq_min_val],
                   :eq_vb =>  eq_dict[:eq_vb],
                   :eq_negative =>  eq_dict[:eq_negative],
                   :eq_deriv_min_val =>  eq_dict[:eq_deriv_min_val],
                   :leverage =>  lev,
                   :ROE =>  roe)

    df = DataFrame(results)

    return results, df
end


function eq_fd(svm; vbl::Float64=NaN,
               mu_b::Float64=NaN,
               m::Float64=NaN,
               c::Float64=NaN,
               p::Float64=NaN,
               V0::Float64=NaN,
               debt::Float64=NaN,
               ftype::String="bf",
               vtN::Int64=1500)

    tic = time()

    # Set Capital Structure
    ks = eq_set_k_struct(svm, mu_b, m, c, p)

    # Get boundary values and form vtgrid
    vtgrid, eq_vbl, eq_max = eq_get_boundary_vgrid(svm, ks, vbl; vtN=vtN) 

    # #################################
    # ###### Newly-Issued Bonds #######
    # #################################
    # Newly-Issued Bond Prices

    bond_prices = eq_fd_newly_issued_bonds(svm, ks,
                                           vbl, vtgrid;
                                           ftype=ftype)
    
    eq_dict = eq_fd_core(svm, ks, vbl,
                         eq_vbl, eq_max,
                         vtgrid, bond_prices; V0=V0)
    _, df = eq_fd_export_results(svm, ks, vbl, eq_dict)

    println(string("Total computation time: ", time() - tic))

    return df
end

