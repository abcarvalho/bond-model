
function cvm_vs_svm_plotfun(pt, yvar::Symbol, 
                            pardict::Dict{String,Array{Any,1}};
                            figaspect::Float64=.5,
                            figpad::AbstractFloat=1.8, 
                            plot_vlines::Bool=false, 
                            figPath::String="")
    
    fixed_vars = [:m, :xi, :sigmal]
    yvars = [:kappa, :lambda, :sigmah]
    xvars = [:kappa, :lambda, :sigmah]
    
    cvmcombs = pardict["cvm"]
    svmcombs = pardict["svm"]

    # x-axis variable:
    xvar = [x for x in xvars if !(x in keys(svmcombs[1]))][1]
 
    svmlinestyles = ["-", "-.", "--"]
    cvmlinestyles = ["-", "-.", "--"]
    svmmarkers = ["", "d", "o"]
    cvmmarkers = ["d", "1", "2"]


    Seaborn.set(style="darkgrid")
    fig = PyPlot.figure(figsize=Tuple(PyPlot.figaspect(figaspect)))
    ax = fig.add_subplot(111)
    
    # Plot SVM Curves
    pchipflist = []
    xpos=0.
    for i in 1:size(svmcombs, 1)
        tmp = svmcombs[i]
                   
        # Slice SVM DataFrame - sort by x-axis variable:
        svmloc = sum([abs.(pt.svm_data[x] .- tmp[x]) .< 1e-4 
                      for x in keys(tmp)]) .== length(keys(tmp))
        svm_slice = sort!(pt.svm_data[svmloc, :], xvar)

        # Plot Curve
        ax.plot(svm_slice[xvar], svm_slice[yvar],
                    color="blue", 
                    linewidth=1,
                    linestyle=svmlinestyles[i],
                    marker=svmmarkers[i], 
                    markersize=3)

        # Add Legend to the Curves
        svm_label = latexstring("(\$\\kappa^{{EP}} =\$", 
                           svm_slice[1, :kappa] * 1e4,
                           ", \$\\lambda =\$",
                           svm_slice[1, :lambda], ")")
       
        ax.text(svm_slice[end, xvar], svm_slice[end, yvar],
                  svm_label, fontsize=10, va="bottom")


        # Interpolate SVM Curves and Store Them
        pchipf = Dierckx.Spline1D(svm_slice[xvar], svm_slice[yvar], k=3, bc="extrapolate")
        push!(pchipflist, pchipf)
        
        if i == 1
            xvals = range(minimum(svm_slice[xvar]),
                          stop=maximum(svm_slice[xvar]), length=10^4)
#         ax.plot(xvals, pchipf(xvals), color='red')
        end

        if i == size(svmcombs,1)
            xpos = svm_slice[end, xvar]
        end
        
    end 
            

    # Plot CVM Curves
    for i in 1:size(cvmcombs, 1)
        tmp = cvmcombs[i]

        # Slice CVM DataFrame
        cvmloc = sum([abs.(pt.cvm_data[x] .- tmp[x]) .< 1e-4 
                      for x in keys(tmp)]) .== length(keys(tmp))
        cvm_slice = pt.cvm_data[cvmloc, :]
 
        # Plot Curve
        ax.axhline(cvm_slice[1, yvar], 
                     color="green",
                     linewidth=1, 
                     linestyle=cvmlinestyles[i], 
                     marker=cvmmarkers[i])

        # Add Legend to the Curves
        cvm_label = string("(\$\\kappa^{{OTC}}\$, \$\\iota\$) = ", 
                           "(", cvm_slice[1, :kappa] * 1e4,
                           ", ", cvm_slice[1, :iota] * 1e4, ")")
        ax.text(xpos, 
                cvm_slice[1, yvar],
                cvm_label, fontsize=10, va="bottom")


        # Plot Vertical Lines
        if plot_vlines
            for pchipf in pchipflist
                sigstar = xvals[argmin([abs(pchipf(x) - cvm_slice[1, yvar]) for x in xvals])]
                ax.axvline(sigstar, color="black", linewidth=.5, linestyle="-.")
            end
        end        
    end

    # Label Axes 
    ylabels = Dict(zip([:firm_value, :equity, :debt, 
                        :c, :p, :vb, :leverage, :ROE],
                        ["Firm Value", "Equity", "Debt", "Coupon", 
                         "Principal", "\$ V^B\$", "Leverage", "ROE"]))
    xlabels = Dict(zip(xvars, ["\\kappa^{EP}", "\$\\lambda\$", "\$\\sigma_h\$"]))
    ax.set_xlabel(xlabels[xvar], labelpad=10)
    ax.set_ylabel(ylabels[yvar], labelpad=10)
    
    # Set Title            
    tlabels = Dict(zip(vcat(fixed_vars, yvars), 
                        ["m", "\\xi", "\\sigma_l", 
                         "\\kappa^{EP}", "\\lambda", "\\sigma_h"]))
    title_params = join([string("\$", tlabels[x], "= \$ ", svmcombs[1][x])
                         for x in vcat(fixed_vars, yvars) if 
                         !(x in [:sigmah, :lambda, :kappa, :iota])], ", ")

    plot_title = latexstring("Optimal RMP-Conditional ", ylabels[yvar], " for ", title_params)
    fig.suptitle(plot_title, fontsize=14)
    ax.set_title("(\$\\kappa\$ and \$\\iota\$ values in b.p.)", fontsize=12)

    if !isnan(figpad)
        fig.tight_layout(pad=figpad)
    end

    if !isempty(figPath)
        figFolder = string(figPath, "/m_", convert(Integer, svmcombs[1][:m]))
        figName = string("cvm_vs_svm_", ylabels[yvar], "__", 
                         join([string(x, '_', svmcombs[1][x])
                               for x in vcat(fixed_vars, yvars) if 
                               !(x in [:sigmah, :lambda, :kappa, :iota])], "__"),
                        ".png")

        # plt.savefig(string(figFolder, "/", figName), dpi=300, bbox_inches="tight")
    end
#     display(fig)
    return fig
end