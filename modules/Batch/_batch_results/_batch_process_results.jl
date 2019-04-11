
function p_tol_search(svm, pgrid, toldf, interpf; quietly=false)
    for i in range(1, stop=size(toldf, 1))
        # Find V satisfying the Slope condition:
        slope_cond = (abs.(interpf[:eq_deriv](pgrid)) .<= toldf[i, :eq_deriv])

        # Find V satisfying the Debt at Par Condition:
        aggP = [get_agg_p(svm, p=p) for p in pgrid]
        debt_at_par_cond = (abs.(interpf[:debt](pgrid) .- aggP) .<
                            toldf[i, :debt_diff])

        # Check if condition is satisfied:
        # Find Intersection of debt and equity conditions
        p_filtered = pgrid[.&(debt_at_par_cond, slope_cond)]

        if !isempty(p_filtered) 
            if !quietly
                println("P Filter Conditions Satisfied! Exiting...")
            end
            return p_filtered
        end
    end
    return []
end


function p_interp_fun(svm, x::DataFrame, toldf::DataFrame; N::Integer=10^5, quietly::Bool=false)
    c = unique(x[:c])[1]
    pgrid = range(minimum(x[:p]), stop=maximum(x[:p]), length=N)

    interpf = Dict()
    for col in [:eq_deriv, :vb, :eq_min_val, :debt, :equity]
        interpf[col] = Dierckx.Spline1D(x[:p], x[col]; k=3, bc="extrapolate")
    end
    
    # Filter by (i) Debt Principal Difference,
    #           (ii) Equity Derivative
    p_filtered = p_tol_search(svm, pgrid, toldf,
                              interpf,
                              quietly=quietly)
    
    # Take the last occurrence of the minimum
    # that is, the largest VB value yielding the smallest derivative.
    p_filter_success = false
    if !isempty(p_filtered)
        p_filter_success = true
        if !quietly
            println(string("c: ", c, " -> P Filter success!"))
        end
        # inv_p_filtered = reverse(p_filtered)

        # Back-out solution -> Equity Derivative
        abs_debt_diffs = abs.(interpf[:debt](p_filtered) .-
                              [get_agg_p(svm, p=p) for p in p_filtered])
        optp = p_filtered[argmin(abs_debt_diffs)]
    else
        if !quietly
            println(string("c: ", c, " -> P Filter failed..."))
        end

        # Back-out solution -> Debt-At-Par + Equity Derivative:
        aggP = [get_agg_p(svm, p=p) for p in pgrid]
        debt_at_par_cond = reverse(abs.(interpf[:debt](pgrid) .- aggP))
        optp = reverse(pgrid)[argmin(debt_at_par_cond)]
        # eq_deriv_cond = abs.(interpf[:eq_deriv](inv_p_filtered))
        # optp = inv_p_filtered[argmin(.75 * debt_at_par_cond .+ .25 * eq_deriv_cond)]
    end

    # Back-out solutions:
    opt_debt = interpf[:debt](optp)
    aggP = get_agg_p(svm, p=optp)
    opt_eq = interpf[:equity](optp)
    opt_firm_val = opt_debt + opt_eq
    return DataFrame(c = c,
                     p = optp,
                     opt_vb = interpf[:vb](optp),
                     cvml_vb = get_cvm_vb(svm, svm.pm.sigmal; 
                                          mu_b=svm.mu_b, c=c, p=optp),
                     cvmh_vb = get_cvm_vb(svm, svm.pm.sigmah; 
                                          mu_b=svm.mu_b, c=c, p=optp),
                     debt_diff = opt_debt - aggP,
                     debt_per_diff = (opt_debt - aggP) / aggP,
                     eq_deriv = interpf[:eq_deriv](optp),
                     eq_min_val = interpf[:eq_min_val](optp),
                     debt = opt_debt,
                     equity = opt_eq,
                     firm_value = opt_firm_val,
                     leverage = (opt_debt / opt_firm_val) * 100,
                     ROE = (opt_eq / (svm.pm.V0 - opt_debt) - 1) * 100,
                     p_filter_success = p_filter_success)
    
end


function process_combination_results(bt, svm;
                                     toldf::DataFrame=toldf,
                                     use_all_eqdf::Bool=true,
                                     drop_fail::Bool=false,
                                     save_df::Bool=true,
                                     dfname="soldf" )


    # Load Equity Finite Differences Files (eqdf_final)
    eqfds_final = [x for x in readdir(bt.mi.comb_res_path) if 
                   .&(occursin("eq_fd", x), !occursin("all", x))]
    LL = @time fetch(@spawn [load_eq_results(bt, svm, dfn;
                                             use_all_eqdf=use_all_eqdf)
                             for dfn in eqfds_final])
    LL = [x for x in LL if !isempty(x)]
    eqdf_final = sort(vcat(LL...), [:c, :p])

    # Drop duplicates
    unique!(eqdf_final, [:c, :p])

    # For each coupon value, interpolate and extract results
    LL = @time fetch(@spawn [p_interp_fun(svm, 
                             eqdf_final[abs.(eqdf_final[:c] .- c).<1e-4, :], 
                             toldf) for c in unique(eqdf_final[:c])])
    soldf = sort(vcat(LL...), [:c])
    
    # Add Columns with Parameter Values
    cols = [x for x in vcat(bt.dfc.main_params, bt.dfc.fixed_params, [:mu_b, :m])
            if x !=:delta]
    for col in cols
        soldf[col] = bt.mi._svm_dict[col]
    end
    soldf[:delta] = soldf[:gross_delta] .- soldf[:iota]
    
    # Reoder columns
    cols1 = vcat(bt.dfc.main_params, [x for x in bt.dfc.k_struct_params if x !=:vb])
    cols2 = [x for x in names(soldf) if .&(!(x in cols1), !(x in bt.dfc.fixed_params))]
    soldf = unique!(soldf[vcat(cols1, cols2, bt.dfc.fixed_params)])

    # Save DataFrame
    if save_df
        CSV.write(string(bt.mi.comb_res_path, "/", dfname, ".csv"), soldf)
    end
    
    return soldf 
end



