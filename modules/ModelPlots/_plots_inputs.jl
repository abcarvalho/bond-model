# ########################################################################
# Directories & File Names ###############################################
main_dir_path = form_main_dir_path(main_dir)
plots_dir="Plots"


cvm_vs_svm_plots_dir = "CVMvsSVM"
rmp_plots_dir = "RMP"
heat_surf_graph_dir="HeatSurf"
obj_fun_dict = Dict{Symbol, String}(:firm_value => "fv",
                                    :MBR => "mbr")
# ########################################################################


# ########################################################################
# Auxiliary Functions ####################################################
function par_val_printer(x::Symbol)
    return !(x in [:iota, :kappa]) ? string(x, "_", xylabels[x][2]) : string(x, "_(bp)_", xylabels[x][2])
end

function par_val_adj(x::Symbol, val::Float64)
    return !(x in [:iota, :kappa]) ? val : val * 1e4
end
# ########################################################################


vartitles = Dict{Symbol, String}(:vb => "\$V^B\$",
                                 :c => "C",
                                 :p => "\$P = Debt\$",
                                 :equity => "Equity",
                                 :firm_value => "Firm Value",
                                 :leverage => "Leverage (\$\\%\$)",
                                 :MBR => "MBR (\$\\%\$)")


# ########################################################################
# CVM Plots ##############################################################

cvm_plots_title_params_order = [:mu_b, :m, :iota, :xi, :kappa, :sigmal]
# ########################################################################


# ########################################################################
# SVM HeatMap and Surface Plots ##########################################
xylabels = Dict{Symbol, Array{String,1}}(:mu_b => ["\\mu_b", comb_folder_dict[:mu_b][2]],
                                         :m => ["m", comb_folder_dict[:m][2]],
                                         :iota => ["\\iota \\, (b.p.)", comb_folder_dict[:iota][2]],
                                         :xi => ["\\xi", comb_folder_dict[:xi][2]],
                                         :kappa => ["\\kappa \\, (b.p.)", comb_folder_dict[:kappa][2]],
                                         :lambda => ["\\lambda", comb_folder_dict[:lambda][2]],
                                         :sigmal => ["\\sigma_l", comb_folder_dict[:sigmal][2]],
                                         :sigmah => ["\\sigma_h", comb_folder_dict[:sigmah][2]])


zlabels = Dict{Symbol, Array{String,1}}(:c => ["Coupon", "%.2f"],
                                        :p => ["Principal", "%.2f"],
                                        :vb => ["VB", "%.1f"],
                                        :debt => ["Debt", "%.1f"],
                                        :equity => ["Equity", "%.1f"],
                                        :firm_value => ["Debt + Equity", "%1d"],
                                        :leverage => ["Leverage", "%1d"],
                                        :MBR => ["Market-to-Book Ratio", "%1d"])

svm_plots_title_params_order = [:mu_b, :m, :iota, :xi, :kappa, :lambda, :sigmal, :sigmah]
# ########################################################################


# ########################################################################
# CVM v.s. SVM & Misrepresentation Plots #################################

fixed_vars = [:mu_b, :m, :xi, :sigmal]
cvs_xvars = [:kappa, :lambda, :sigmah]


# Subplots #######################################
ax_subplots = Dict{Int64, Array{Int64,1}}(1 => [111],
                                          2 => [211, 212])


# Axes ###########################################
cvs_xlabels = Dict{Symbol, Array{String,1}}(:mu_s => ["\\mu_{s}", "%.2f"],
                                            :kappa_ep => ["\\kappa^{{EP}}", comb_folder_dict[:kappa][2]],
                                            :kappa_otc => ["\\kappa^{OTC}", comb_folder_dict[:kappa][2]],
                                            :iota => ["\\iota", comb_folder_dict[:iota][2]],
                                            :lambda => ["\\lambda", comb_folder_dict[:lambda][2]],
                                            :sigmah => ["\\sigma_h", comb_folder_dict[:sigmah][2]])

cvs_ylabels = Dict(zip([:firm_value, :equity, :debt, 
                        :c, :p, :vb, :leverage, :MBR],
                       ["Firm Value", "Equity", "Debt", "Coupon", 
                        "Principal", "\$ V^B\$", "Leverage", "Market-to-Book Ratio (\$\\%\$)"]))


# Markers and Line Styles ########################
cvmlinestyles = ["-", "-.", "--"]
cvmmarkers = ["d", "1", "2"]
svmlinestyles = ["-", "-.", "--"]
svmmarkers = ["", "d", "o"]


# Title ###########################################
cvs_plots_title_params_order = [:mu_b, :m, :xi, :sigmal]
tlabels = deepcopy(xylabels)


# Curves ##########################################
cvm_curve_label = "\\overline{\\iota} \\geqslant 0"
cvm_curve_color = "green"
svm_curve_color = "blue"
misrep_curve_color = "red"
# svm_curve_fv_label_ypos = 


# Vertical Lines ##################################
fv_color = "black"
mbr_color = "blueviolet"
misrep_color = "red"
                                              
function return_xsym_dict(xvar::Symbol)
    sub_sup = (xvar == :iota) ? "_" : "^"
    return Dict{Symbol, String}(:fv => string("\n \$", cvs_xlabels[xvar][1], sub_sup, "{fv}\$"),
                                :mbr => string("\n \$", cvs_xlabels[xvar][1], sub_sup, "{mbr}\$"),
                                :misrep => string("\n \$", cvs_xlabels[xvar][1], sub_sup, "{mp}\$"))
end

function vlines_labels_dict(xvar; fv_xvar::Float64=NaN,
                            fv_color::String=fv_color,
                            mbr_xvar::Float64=NaN,
                            mbr_color::String=mbr_color,
                            misrep_xvar::Float64=NaN,
                            misrep_color::String=misrep_color)
    xsym_dict = return_xsym_dict(xvar)
    return Dict(:firm_value => Dict(zip([:value, :xsym, :color],
                                          [fv_xvar, xsym_dict[:fv], fv_color])),
                  :MBR => Dict(zip([:value, :xsym, :color],
                                   [mbr_xvar, xsym_dict[:mbr], mbr_color])),
                  :misrep => Dict(zip([:value, :xsym, :color],
                                   [misrep_xvar, xsym_dict[:misrep], misrep_color])))
end


# Region Colors ####################################
rm_region_color = "blue"
nrm_region_color = "#76D7C4"
conflict_region_color = "#EB984E"
misrep_region_color = "#F1948A"
box_color = "#EE0839"


# ##################################################
# tlabels = Dict(zip(vcat(fixed_vars, yvars), 
#                         ["\\mu_b", "m", "\\xi", "\\sigma_l", 
#                          "\\kappa^{EP}", "\\lambda", "\\sigma_h"]))
# title_params = join([string("\$", tlabels[x], "= \$ ", svmcombs[1][x])
#                      for x in vcat(fixed_vars, yvars) if 
#                      !(x in [:sigmah, :lambda, :kappa, :iota])], ", ")
# ########################################################################


# ########################################################################
# Misrepresentation Plots ################################################
rmp_plots_title_params_order =  [:mu_b, :m, :xi, :kappa, :sigmal]
rmp_fn_prefix = "rmp"
rmp_full_info_prefix = "fi"
rmp_misrep_prefix = "misrep"
rmp_fig_aspect = .5
rmp_multi_plot_fig_size = (10., 8.)
rmp_multi_plot_figpad = .9

# ########################################################################

jeq_xlabels = Dict{Symbol, Array{String,1}}(:mu_s => ["\\mu_{s}", "%.2f"])

# Markers and Line Styles ########################
fi_linestyles = ["-", "-.", "--"]
fi_markers = ["d", "1", "2"]


# Line Styles
jeq_linestyles = ["-", "-.", "--"]


# Curve Colors
fi_ep_curve_color = "blue"
fi_otc_curve_color = "#DC7633"
# fi_otc_curve_color = "#A569BD"
pool_curve_color = "red"
sep_curve_color = "#17A589"


jeq_markers = ["", "d", "o"]
fi_curve_color = "blue"

jeq_plots_title_params_order =  [:m, :xi, :sigmal]
otc_region_color = "#F0B27A"