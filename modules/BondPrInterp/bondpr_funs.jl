function get_cvm_bond_price(svm, ttm::Float64,
                            sigma::Float64;
                            Vt::Float64=NaN,
                            vb::Float64=NaN,
                            mu_b::Float64=NaN,
                            m::Float64=NaN,
                            c::Float64=NaN,
                            p::Float64=NaN)
    # ####################################
    # ######## Extract Parameters ########
    # ####################################
    if isnan(Vt)
        Vt=svm.pm.V0
    end

    mu_b, m, c, p = get_k_struct(svm; mu_b=mu_b, m=m, c=c, p=p)
    
    if isnan(vb)
        vb = get_cvm_vb(svm, sigma; mu_b=mu_b, m=m, c=c, p=p)
    end
    # ####################################

    return cvm_bond_price(vb, log(Vt/float(vb)), ttm,
                          mu_b, m, c, p, sigma,
                          svm.pm.r, svm.pm.gross_delta,
                          svm.pm.xi, svm.pm.kappa,
                          svm.pm.alpha, svm.pm.pi)

end


# ##########################################################
# #################### Fin Diff Method #####################
# ##########################################################
# 1. Notice the value of ttm passed to
# the function call must match the 
# value of ttm used to calibrate the 
# functions f0, f1, f2 and f3.
# 2. Notice also the order of the 
# arguments in the f2 and f3 functions:
# first vt, then vbhl.
# 3. Finally, vbhl in the f2 and f3 
# functions below is the ratio of the 
# post- to -pre-volatility shock
# bankruptcy barriers.

# ##########################################################
# ############# Prices at Different Maturities #############
# ##########################################################


# ##########################################################
# ##########################################################
function compute_jbpr_inputs(svm, Vt::Float64,
                             vbl::Float64,
                             mu_b::Float64,
                             c::Float64,
                             p::Float64)
    vt = log(Vt/float(vbl))
    
    # Default Barrier Ratio
    vbh = get_cvm_vb(svm, svm.pm.sigmah; mu_b=mu_b, c=c, p=p)
    vbhl = vbh/float(vbl)

    return vt, vbh, vbhl 
end


# function get_interp_values(svm, vt::Float64,
#                            ttm::Float64,
#                            vbhl::Float64)
#     return svm.bf.f11(vt, ttm)[1],
# 	   svm.bf.f12(vt, ttm, vbhl), 
# 	   svm.bf.f13(vt, ttm, vbhl),
#            svm.bf.f21(vt, ttm)[1],
#            svm.bf.f22(vt, ttm)[1]
# end


function get_interp_values(svm, vt::Float64,
                           ttm::Float64,
                           vbhl::Float64;
                           ftype::String="bf")
    if ftype == "bf"
        return svm.bf.f11(vt, ttm)[1],
               svm.bf.f12(vt, ttm, vbhl), 
               svm.bf.f13(vt, ttm, vbhl),
               svm.bf.f21(vt, ttm)[1],
               svm.bf.f22(vt, ttm)[1]
    elseif .&(ftype == "bft", abs.(ttm - svm.bit.ttm) < 1e-6)
        return svm.bft.f11(vt),
               svm.bft.f12(vt, vbhl), 
               svm.bft.f13(vt, vbhl),
               svm.bft.f21(vt),
               svm.bft.f22(vt)
    else
        println("Unable to compute bond pricing function values.")
        println(string("Function type: ", ftype))
        return 
    end
end


function get_svm_bond_price(svm, vbl::Float64,
                            ttm::Float64;
                            Vt::Float64=NaN,
                            mu_b::Float64=NaN,
                            c::Float64=NaN,
                            p::Float64=NaN,
                            ftype::String="bf")
    # ####################################
    # ######## Extract Parameters ########
    # ####################################
    if isnan(Vt)
        Vt = svm.pm.V0
    end

    mu_b, _, c, p = get_k_struct(svm; mu_b=mu_b, m=NaN, c=c, p=p)
    # ####################################
    
    # Maximum vt
    vtmax = svm.bi.vtmax 

    vt, vbh, vbhl = compute_jbpr_inputs(svm, Vt, vbl, mu_b, c, p) 
    # ####################################
    if vt <= 0
        return on_default_payoff(vt, vbl, ttm,
                                 mu_b, svm.m, c, p,
                                 svm.pm.r, svm.pm.xi,
                                 svm.pm.kappa, svm.pm.alpha)
    elseif vt > minimum(svm.bs.vtgrid)
        rfbond = rfbond_price(ttm, c, p,
                              svm.pm.r, svm.pm.xi, svm.pm.kappa)

        if vt > vtmax
               return rfbond 
        end

        # Maturity or Default prior to Volatility Shock:
        cf0 = no_vol_shock_cf_pv(vt, vbl, ttm,
                                 mu_b, svm.m,
                                 c, p,
                                 svm.pm.sigmal,
                                 svm.pm.r, svm.pm.gross_delta,
                                 svm.pm.xi, svm.pm.kappa,
                                 svm.pm.alpha, svm.pm.lambda)
       
        f11, f12, f13, f21, f22 = get_interp_values(svm, vt, ttm, vbhl; ftype=ftype)
        
        # Volatility Shock Prior to Maturity:
        cf1 = c/get_rdisc(svm) * f11 +
              (p - c/get_rdisc(svm)) * f12 +
              (svm.pm.alpha * vbh/float(mu_b * svm.m) - c/get_rdisc(svm)) * f13
       
        cf2 = c/get_rdisc(svm) * f21 + (p - c/get_rdisc(svm)) * f22 
       
        return min(cf0 + cf1 + cf2, rfbond)
    else
        # In this case, firm is so close to default that I just
        # return the CVM bond price for sigma = sigmal:
        return get_cvm_bond_price(svm, ttm, svm.pm.sigmal;
                            Vt=Vt, vb=vbl, mu_b=mu_b, c=c, p=p)
    end
end


# Objective is to find V such that the value of the
# newly-issued (tau = m) risky bond price when sigma = sigmah
# is sufficiently close to the credit-risk-free bond price.
function get_bond_Vmax(svm; mu_b::Float64=NaN,
                       c::Float64=NaN,
                       p::Float64=NaN,
                       initV::Float64=NaN,
                       tol::Float64=.5 * 1e-3,
                       print::Bool=false)
    if isnan(mu_b)
        mu_b = svm.mu_b
    end
    
    if isnan(c)
        c=svm.c
    end

    if isnan(p)
        p=svm.p
    end

    if isnan(initV)
	initV = svm.pm.V0
    end

    bondVmax = 1.25 * initV
    vb = get_cvm_vb(svm, svm.pm.sigmah; mu_b=mu_b, c=c, p=p)
    rfbond = rfbond_price(svm.m, c, p,
                          svm.pm.r, svm.pm.xi, svm.pm.kappa)
    bondpr = get_cvm_bond_price(svm, svm.m, svm.pm.sigmah;
                                Vt=bondVmax, vb=vb, mu_b=mu_b, c=c, p=p)
    per_diff = (rfbond - bondpr) / rfbond
    
    cond = per_diff > tol 
    while cond
	bondVmax = 1.025 * bondVmax
        bondpr = get_cvm_bond_price(svm, svm.m, svm.pm.sigmah;
                                    Vt=bondVmax, vb=vb,
                                    mu_b=mu_b, c=c, p=p)
	per_diff = (rfbond - bondpr) / rfbond
	cond = per_diff > tol
    end
    
    if print
	println(string("Bond Percentage Difference: ", per_diff))
    end
    
    return bondVmax
end
