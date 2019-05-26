

function get_otc_values(firm_type::String, fidf::DataFrame,
                        yvar::Symbol; iota::Float64=NaN, kappa::Float64=NaN)

    
    # Transaction Costs and Volatility Risk Parameters
    cvmdict = Dict{Symbol,Array{Float64,1}}(:sigmal => [fidf[1, :sigmal]],
                                            :m  => [parse(Float64, string(fidf[1, :m]))],
                                            :gross_delta => [parse(Float64, 
                                                                   string(fidf[1, :gross_delta]))],
                                            :mu_b => [1.0],
                                            :xi => [parse(Float64, string(fidf[1, :xi]))])
    
    xvar = :iota
    if !isnan(iota)
        cvmdict[:kappa] = [fidf[1, :kappa] * 1e-4]
    elseif !isnan(kappa)
        cvmdict[:iota] = [fidf[1, :iota] * 1e-4]
        xvar = :kappa
    else
        println("Please enter a value for iota or for kappa. Exiting...")
        return
    end
    
    svmdict = deepcopy(cvmdict)
    svmdict[:lambda] = [fidf[2, :lambda]]
    svmdict[:iota] = [.0]
    svmdict[:sigmah] = [fidf[2, :sigmah]]
    # #########################################################

    # Get Safe and Risky Firms' Full Info Optimal Results #####
    firm_obj_fun = :firm_value 
    cvmdf, svmdf, _ = get_cvm_svm_dfs(cvmdict, svmdict;
                                      firm_obj_fun=firm_obj_fun)
    # #########################################################

    df = (firm_type == "safe") ? cvmdf : svmdf
    yinterp = Dierckx.Spline1D(df[xvar], df[yvar], k=3, bc="extrapolate")
    xval = (isnan(iota)) ? kappa : iota
    return yinterp(xval)
end



function get_otc_cut_off(y_otc::Float64,
                         yfun::Spline1D,
                         xgrid::StepRangeLen{Float64,
                                             Base.TwicePrecision{Float64},
                                             Base.TwicePrecision{Float64}})
               
    otc_diffs = yfun(xgrid) .- y_otc

    if all(otc_diffs .> .0)
        return Inf
    elseif all(otc_diffs .< .0)
        return -Inf
    else
        return (minimum(abs.(otc_diffs)) < 1e-4) ?  xgrid[argmin(abs.(otc_diffs))] : NaN
    end
end
               

function get_otc_cut_off_values(y_otc::Float64,
                                sep_yinterp::Spline1D, pool_yinterp::Spline1D,
                                xgrid::StepRangeLen{Float64,
                                             Base.TwicePrecision{Float64},
                                             Base.TwicePrecision{Float64}};
                                sep_otc::Float64=NaN,
                                pool_otc::Float64=NaN)

    if !isnan(y_otc)
        sep_otc = get_otc_cut_off(y_otc, sep_yinterp, xgrid)
        pool_otc = get_otc_cut_off(y_otc, pool_yinterp, xgrid)
    end

    if any([.&(isinf(sep_otc), sep_otc > 0), .&(isinf(pool_otc), pool_otc > 0)])
        return NaN
    elseif any(isnan.([sep_otc, pool_otc]) .== false)
        return maximum([x for x in [sep_otc, pool_otc] if !isnan(x)])
    else
        return NaN
    end
end