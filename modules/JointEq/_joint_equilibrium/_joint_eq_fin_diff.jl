 
function joint_eq_get_Vmax_vgrid(jf, jks, vbl::Float64; vtN::Int64=1500)
    # V MAX ######################################
    println("Computing Equity Vmax")
    # Safe Firm
    sf_eq_Vmax = get_eq_Vmax(jf.sf; mu_b=jks.mu_b, m=jks.m, c=jks.c, p=jks.p)

    # Risky Firm
    rf_eq_Vmax = get_eq_Vmax(jf.rf; mu_b=jks.mu_b, m=jks.m, c=jks.c, p=jks.p)

    # Take the Maximum Value:
    eq_Vmax = maximum([sf_eq_Vmax, rf_eq_Vmax])
    println(string("Equity Vmax: ", eq_Vmax))
    println(" ")
    # ############################################
    
    # vtgrid
    vtgrid = reverse(range(0.0, stop=log(eq_Vmax/float(vbl)), length=vtN))
    
    # #################################
    # ######## Boundary Values ########
    # #################################
        
    println(string("eq_max: ", vtgrid[1]))
    
    # Lower Barrier:
    
    return eq_Vmax, vtgrid
end 

                   
function joint_eq_get_boundary_values(tj, jks,
                                      vbj::Float64, vbl::Float64, eq_Vmax::Float64)
    # Lower Barriers
    if abs(vbj - vbl) < 1e-4 #|| get_obj_model(tj) == "cvm"   
        tj_eq_vbl = maximum([0., get_param(tj, :alpha) * vbl -
                             get_pv_rfdebt(tj; mu_b=jks.mu_b,
                                           m=jks.m, c=jks.c, p=jks.p)])
    else
        eqvals = eq_fd(tj; vbl=vbj, mu_b=jks.mu_b, m=jks.m, c=jks.c, p=jks.p, V0=vbl)

        if .&(eqvals[1, :eq_min_val] > -1e-2,
              eqvals[1, :eq_deriv_min_val] > -1e-2)
            tj_eq_vbl = maximum([0.0, eqvals[1, :equity]])
        else
            tj_eq_vbl = 0.0
        end
    end
    println(string("eq_vbl: ", tj_eq_vbl))

    # Upper Barriers: Value of Equity
    tj_eq_max = get_cvm_eq(tj, eq_Vmax, tj.pm.sigmal;
                           mu_b=jks.mu_b, m=jks.m, c=jks.c, p=jks.p)

    return tj_eq_vbl, tj_eq_max 
end


# DATAFRAME COLUMNS
# K Structure
jks_cols = [:mu_s, :m, :mu_b, :c, :p]

# Default Barrier
vb_cols = [:fi_vb, :sf_vb, :rf_vb, :vb]

# EFD
share_cols = [:eq_deriv, :eq_deriv_min_val, 
              :eq_min_val, :eq_negative, 
              :eq_vb, :ROE, :debt, :equity, 
              :firm_value, :leverage]

# Parameters
param_cols = [:iota, :lambda, :sigmah, 
              :gross_delta, :delta, :kappa, 
              :sigmal, :V0, :xi, :r, :alpha, :pi]

jks_eq_fd_cols = vcat(jks_cols, vb_cols, share_cols, param_cols)


# Joint Equilibrium Equity Finite Differences
function joint_eq_fd(jf; V0::Float64=NaN,
                     jks=JointKStruct(fill(NaN, 10)...),
                     mu_s::Float64=NaN,
                     mu_b::Float64=NaN,
                     m::Float64=NaN,
                     c::Float64=NaN,
                     p::Float64=NaN,
                     vbl::Float64=NaN,
                     sf_vb::Float64=NaN,
                     rf_vb::Float64=NaN,
                     fi_sf_vb::Float64=NaN,
                     fi_rf_vb::Float64=NaN,
                     debt::Float64=NaN,
                     sf_ftype::String="bf",
                     rf_ftype::String="bf",
                     lb::Float64=.75, ub::Float64=1.25, vbN::Int64=15,
                     vtN::Int64=1500)

    tic = time()

    # Common Parameters #############################
    if !check_param_consistency(jf)
        println("Exiting...")
        return
    end
    # ###############################################

    # Set Capital Structure #########################
    jks = joint_eq_set_k_struct!(jf; jks=jks,
                                 mu_s=mu_s,
                                 mu_b=mu_b,
                                 m=m, c=c, p=p,
                                 fi_sf_vb=fi_sf_vb,
                                 sf_vb=sf_vb,
                                 fi_rf_vb=fi_rf_vb,
                                 rf_vb=rf_vb)
    # ###############################################

    # if !isnan(vbl)
    #     setfield!(jks, :vbl, vbl)
    # end
    
    # Equity Boundary Values ########################
    eq_Vmax, vtgrid = joint_eq_get_Vmax_vgrid(jf, jks, jks.vbl; vtN=vtN)

    sf_eq_vbl, sf_eq_max = joint_eq_get_boundary_values(jf.sf, jks,
                                                        jks.sf_vb,
                                                        jks.vbl, eq_Vmax)
    rf_eq_vbl, rf_eq_max = joint_eq_get_boundary_values(jf.rf, jks,
                                                        jks.rf_vb,
                                                        jks.vbl, eq_Vmax)
    # ###############################################

    # Store Parameters ############################## 
    fdp = JointFDParams(sf_eq_vbl,
                        sf_eq_max,
                        rf_eq_vbl,
                        rf_eq_max)
     # ###############################################   

    # Newly-Issued Bond Prices ######################
    bond_prices = joint_eq_fd_newly_issued_bonds(jf, jks, jks.vbl,
                                                 vtgrid;
                                                 vtN=vtN,
                                                 sf_ftype=sf_ftype,
                                                 rf_ftype=rf_ftype)

    # ###############################################

    # Debt Price ###################################
    debt_pr = joint_debt_price(jf; jks=jks)

    # ##############################################
    
    # Compute Equity Values #########################
    # No adjustments to vtgrid, because
    # bond_prices and sf_eq_vbl already adjust for 
    # the differences in the default barrier.
    sf_eq_dict = eq_fd_core(jf.sf, jks, jks.vbl,
                            sf_eq_vbl, sf_eq_max,
                            vtgrid, bond_prices) # no adjustments
                            # vtgrid .-log(jks.vbl/jks.sf_vb), bond_prices)
    _, sf_df = eq_fd_export_results(jf.sf, jks, jks.vbl, sf_eq_dict; debt=debt_pr)

    sf_df[:mu_s] = jks.mu_s
    sf_df[:fi_vb] = jks.fi_sf_vb 
    sf_df[:sf_vb] = jks.sf_vb
    sf_df[:rf_vb] = NaN   
    
    rf_eq_dict = eq_fd_core(jf.rf, jks, jks.vbl,
                            rf_eq_vbl, rf_eq_max,
                            vtgrid, bond_prices)
                            # vtgrid .-log(jks.vbl/jks.rf_vb), bond_prices)
    _, rf_df = eq_fd_export_results(jf.rf, jks, jks.vbl, rf_eq_dict; debt=debt_pr)
    rf_df[:mu_s] = jks.mu_s
    rf_df[:fi_vb] = jks.fi_rf_vb 
    rf_df[:sf_vb] = NaN
    rf_df[:rf_vb] = jks.rf_vb
    # ##############################################

    println(string("Total computation time: ", time() - tic))

    return vcat([sf_df, rf_df]...)[jks_eq_fd_cols]
end
