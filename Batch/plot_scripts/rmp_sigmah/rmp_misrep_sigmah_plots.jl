using Interpolations
using Distributed
using DataFrames
using Printf
using JLD
using CSV
using Dierckx
using Dates
using PyPlot
# using PyCall
using Seaborn
using LaTeXStrings

main_path = "/home/artur/BondPricing"
module_path = string(main_path, "/", "Julia/modules/")
modls = ["Batch", "ModelObj", "AnalyticFunctions", 
         "BondPrInterp", "EqFinDiff", "ModelPlots", "JointEq"]
for modl in modls
    include(string(joinpath(module_path, modl), ".jl"))
end

plot_script_path = string(main_path, "/Julia/Batch/plot_scripts")
plots_xvar_dir = "rmp_sigmah"
rerun_misrep = false
save_misrepdf = true


# * Load Full Information Results
# Set Parameters ##########################################
cvmdict = Dict{Symbol,Array{Float64,1}}(:sigmal => [0.15],
                                        :m  => [1.],
                                        :gross_delta => [0.02],
                                        :kappa  => [25 * 1e-4],
                                        :mu_b => [1.0],
                                        :xi => [1.0],
                                        :iota => [0.0, 1 * 1e-3])

svmdict = deepcopy(cvmdict)
svmdict[:lambda] = [.1]
# svmdict[:kappa] = [25 * 1e-4]
svmdict[:iota] = [.0]
svmdict[:sigmah] = Batch.svm_param_values_dict[:sigmah]

# #########################################################
# Get Safe and Risky Firms' Full Info Optimal Results #####
firm_obj_fun = :firm_value 
cvmdf, svmdf, _ = ModelPlots.get_cvm_svm_dfs(cvmdict, svmdict;
                                             firm_obj_fun=firm_obj_fun)


# Set Targeted Safe Firm
sf_model = "cvm"
sf_comb_num = cvmdf[1, :comb_num]
rf_comb_nums = svmdf[:, :comb_num]
# sf_sigmah = unique(svmdf[:, :sigmah])[1]
# loc = abs.(svmdf[:, :sigmah] .- sf_sigmah) .< 1e-4
# if svmdf[loc, :firm_value][1] > cvmdf[1, :firm_value] 
#     sf_model = "svm"
#     sf_comb_num = svmdf[loc, :comb_num][1]
#     rf_comb_nums = [x for x in rf_comb_nums if x != sf_comb_num]
# end

tmp = deepcopy(DataFrame(cvmdf[1, :]))
tmp[!, :eq_deriv_min_val] .= NaN
tmp[!, :eq_negative] .= false
tmp[!, :sigmah] .= tmp[:, :sigmal]
svmdf = vcat(tmp, svmdf)
cvmdf = deepcopy(DataFrame(cvmdf[2, :]))

# #########################################################


# * Compute Misrepresentation DF
# Misrepresentation Payoffs ###############################
script_dir = string(plot_script_path, "/", plots_xvar_dir)
misrepdf_fn = "misrepdf.csv"

if rerun_misrep | !(misrepdf_fn in readdir(script_dir))
    # Form Misrepresentation DF 
    LL = [ ]
    # Preliminary Objects #####################################
    sf_bt, sf = Batch.get_bt_mobj(; model=sf_model, comb_num=sf_comb_num)
    # sf_df = (sf_model == "cvm") ? cvmdf : svmdf
    sf_df = tmp
    sf = ModelObj.set_opt_k_struct(sf, sf_df)
    
    # Capital Structure -> Fixed
    jks = JointEq.JointKStruct(1., 
                               sf.optKS.mu_b,
                               sf.optKS.m, sf.optKS.c, sf.optKS.p, 
                               NaN, NaN, NaN, NaN, NaN)
    #  #########################################################
    
    for rf_comb_num in rf_comb_nums
        rf_bt, rf = Batch.get_bt_svm(; comb_num=rf_comb_num)
        
        # Joint Equilibrium Parameters
        jep = JointEq.store_joint_eq_parameters(jks.mu_s, sf.pm.kappa, sf.pm.kappa;
                                                s_iota=sf.pm.iota,
                                                s_lambda=sf.pm.lambda,
                                                s_sigmah=sf.pm.sigmah,
                                                r_iota=rf.pm.iota,
                                                r_lambda=rf.pm.lambda,
                                                r_sigmah=rf.pm.sigmah)
        
        # Compute Misrepresentation
        jeq = JointEq.ep_constructor(jep, sf_bt, rf_bt;
                                     ep_jks=jks,
                                     run_pool_eq=false,
                                     run_sep_eq=false,                       
                                     sf_obj_fun=firm_obj_fun,
                                     rf_obj_fun=firm_obj_fun,
                                     rerun_full_info=false,
                                     run_misrep=true,
                                     rerun_pool=false,
                                     rerun_sep=false)
        
        
        push!(LL, getfield(jeq, :misrep))
    end

    # Form Misrepresentation DataFrame
    misrepdf = vcat(LL...)

    cols = [:eq_deriv, :eq_min_val, :mu_b, :eq_deriv_min_val, 
            :eq_negative, :eq_vb, :MBR, :debt, :equity, :firm_value, 
            :leverage, :iota, :lambda, :sigmah, :delta, :sigmal, :obj_fun]
    tmp2 = DataFrame(misrepdf[1, :])
    for col in cols
        tmp2[!, Symbol(:r_, col)] .= tmp2[!, Symbol(:s_, col)]
    end
    tmp2[!, :rf_vb] .= tmp2[:, :sf_vb]
    tmp2[!, :r_sigmah] .= tmp2[:, :r_sigmal]
    tmp2[!, :r_obj_fun] .= "misrep" 
    misrepdf = vcat(tmp2, misrepdf)
    misrepdf[!, :s_sigmah] .= misrepdf[:, :s_sigmal]
    # Save the DataFrame
    if save_misrepdf
        CSV.write(string(script_dir, "/", misrepdf_fn), misrepdf)
    end
else
    misrepdf = CSV.read(string(script_dir, "/", misrepdf_fn)) #, types=JointEq.mps_col_types)
end
# #########################################################


# Iota and Kappa in Basis Points ##########################
for x in [:iota, :kappa]
    cvmdf[!, x] = cvmdf[:, x] .* 1e4
    svmdf[!, x] = svmdf[:, x] .* 1e4
end
misrepdf[!, :kappa] = misrepdf[:, :kappa] .* 1e4
for pf in [:s_, :r_]
    misrepdf[!, Symbol(pf, :iota)] = misrepdf[:, Symbol(pf, :iota)] .* 1e4
end
# #########################################################


# Cut-off Values ##########################################
xgrid = range(minimum(svmdf[:, :sigmah]), stop=maximum(svmdf[:, :sigmah]), length=10^5)

# sigmah : RM Firm Value = NRM Firm Value
fv_sigmah = ModelPlots.get_cutoff_value(svmdf, :sigmah,
                                        :firm_value, cvmdf[1, :firm_value];
                                        xgrid=xgrid)

# sigmah : RM Firm Value = NRM Firm Value
mbr_sigmah = ModelPlots.get_cutoff_value(svmdf, :sigmah,
                                         :MBR, cvmdf[1, :MBR];
                                         xgrid=xgrid)

# sigmah : FI MBR = Misrep MBR
cvm_misrep_sigmah, svm_misrep_sigmah = ModelPlots.get_misrep_cutoff_value(:sigmah, :MBR, 
                                                                          deepcopy(cvmdf),
                                                                          deepcopy(svmdf),
                                                                          deepcopy(misrepdf),
                                                                          xgrid=xgrid)

cvm_misrep_sigmah=fv_sigmah

# sigmah : FI Firm_Value = Misrep Firm Value
# cvm_misrep_sigmah, svm_misrep_sigmah = ModelPlots.get_misrep_cutoff_value(:sigmah, :firm_value, 
#                                                                           deepcopy(cvmdf),
#                                                                           deepcopy(svmdf),
#                                                                           deepcopy(misrepdf),
#                                                                           xgrid=xgrid)

# #########################################################

# Firm Value
fv_fig = ModelPlots.rmp_fi_plotfun(:sigmah, [:firm_value], 
                                   deepcopy(cvmdf), deepcopy(svmdf),
                                   interp_yvar=true,
                                   misrepdf=deepcopy(misrepdf),
                                   fv_xvar=fv_sigmah,
                                   mbr_xvar=mbr_sigmah,
                                   cvm_misrep_xvar=cvm_misrep_sigmah,
                                   svm_misrep_xvar=svm_misrep_sigmah,
                                   color_rm_region=false,
                                   color_nrm_region=false,
                                   color_conflict_region=false,
                                   color_misrep_region=true, 
                                   save_fig=true)


# # Market-to-Book Ratio
mbr_fig = ModelPlots.rmp_fi_plotfun(:sigmah, [:MBR], 
                                    deepcopy(cvmdf), deepcopy(svmdf),
                                    interp_yvar=true,
                                    misrepdf=deepcopy(misrepdf),
                                    fv_xvar=fv_sigmah,
                                    mbr_xvar=mbr_sigmah,
                                    cvm_misrep_xvar=cvm_misrep_sigmah,
                                    svm_misrep_xvar=svm_misrep_sigmah,
                                    color_rm_region=false,
                                    color_nrm_region=false,
                                    color_conflict_region=false,
                                    color_misrep_region=true, 
                                    save_fig=true)

# Firm Value and MBR Multiplot
fv_mbr_fig = ModelPlots.rmp_fi_plotfun(:sigmah, [:firm_value, :MBR], 
                                       deepcopy(cvmdf), deepcopy(svmdf),
                                       interp_yvar=true,
                                       misrepdf=deepcopy(misrepdf),
                                       fv_xvar=fv_sigmah,
                                       mbr_xvar=mbr_sigmah,
                                       cvm_misrep_xvar=cvm_misrep_sigmah,
                                       svm_misrep_xvar=svm_misrep_sigmah,
                                       color_rm_region=false,
                                       color_nrm_region=false,
                                       color_conflict_region=false,
                                       color_misrep_region=true, 
                                       save_fig=true)
