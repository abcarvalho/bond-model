
function get_pv_rfdebt(svm; mu_b::Float64=NaN,
                       m::Float64=NaN,
                       c::Float64=NaN,
                       p::Float64=NaN)

    mu_b, m, c, p = get_k_struct(svm; mu_b=mu_b, m=m, c=c, p=p)
    
    return rf_debt(mu_b, m, c, p, 
                   svm.pm.r, svm.pm.xi, svm.pm.kappa)
end


function get_cvm_debt_price(svm, vb::Float64,
                            sigma::Float64; 
                            Vt::Float64=NaN,
                            mu_b::Float64=NaN,
                            m::Float64=NaN,
                            c::Float64=NaN,
                            p::Float64=NaN,
                            N1::Int64=100, N2::Int64=10^4)

    # ####################################
    # ######## Extract Parameters ########
    # ####################################
    if isnan(Vt)
        Vt=svm.pm.V0
    end

    mu_b, m, c, p = get_k_struct(svm; mu_b=mu_b, m=m, c=c, p=p)
    # ####################################
    
    # vb = get_cvm_vb(svm, sigma; c=c, p=p)
    v = log(Vt/float(vb))
	
    # Create time-to-maturity grids
    _, ttm_grid1 = grid_creator(0.01, m, N1)
    dt2, ttm_grid2 = grid_creator(0.0, m, N2)


    # Compute Bond Prices
    bond_vec = @spawn [get_cvm_bond_price(svm, ttm, sigma;
                                          Vt=Vt, vb=vb,
                                          mu_b=mu_b, m=m,
                                          c=c, p=p)
                       for ttm in ttm_grid1]

    # Interpolate	
    bond_interp_sitp = Dierckx.Spline1D(ttm_grid1, fetch(bond_vec); k=3, bc="extrapolate")

    # Refine Bond Price Grid
    bond_vec2 = @spawn [bond_interp_sitp(ttm) for ttm in ttm_grid2]
    
    # Integrate
    return mu_b * sum(fetch(bond_vec2)) * dt2
end


function get_svm_debt_price(svm, vbl::Float64; 
                            Vt::Float64=NaN,
                            mu_b::Float64=NaN,
                            c::Float64=NaN,
                            p::Float64=NaN,
                            ttmN0::Int64=10^2,
                            ttmN::Int64=10^4)

    # ####################################
    # ######## Extract Parameters ########
    # ####################################
    if isnan(Vt)
        Vt=svm.pm.V0
    end

    mu_b, _, c, p = get_k_struct(svm; mu_b=mu_b, m=NaN, c=c, p=p)
    # ####################################
    
    # Create  time-to-maturity grid
    _, ttm_grid = grid_creator(minimum(svm.bs.ttmgrid), 
                               maximum((svm.bs.ttmgrid)), ttmN0)

    # Get Bond Prices at Different Maturities
    bondpr_vec = fetch(@spawn [get_svm_bond_price(svm, vbl, ttm;
                                                  Vt=Vt, mu_b=mu_b, c=c, p=p)
                               for ttm in ttm_grid])
    bondpr_sitp = Dierckx.Spline1D(ttm_grid, bondpr_vec; k=3, bc="extrapolate")
    
    # Refine time-to-maturity grid
    dt2, ttm_grid2 = grid_creator(0.0, svm.m, ttmN)

    # Bond Prices
    bondpr_vec_ref = fetch(@spawn [bondpr_sitp(ttm) for ttm in ttm_grid2])

    return mu_b * sum(bondpr_vec_ref) * dt2
end
