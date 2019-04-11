
# function set_dir_obj(btc, main_dir, res_dir, mat_dir_prefix, coupon_dir_prefix=nothing)
#     batch["dir"] = Dict()
#     batch["dir"]["main"] = main_dir
#     batch["dir"]["res"] = string(res_dir, 
#                                  "CVM"^Int(occursin(btc["name"], "CVM")), 
#                                  "SVM"^Int(occursin(btc["name"], "SVM")))
#     batch["dir"]["mat_prefix"] = mat_dir_prefix

#     if !(coupon_dir_prefix==nothing)
#         batch["dir"]["coupon_prefix"] = coupon_dir_prefix
#     end
# end


# ############## Set Directories ##############
function form_main_dir_path(main_dir::String)
    return joinpath(pwd()[1:findfirst("artur", pwd())[end]],
                    "BondPricing", main_dir)
end

function set_main_dir_path(bt)
    # Main directory is called "Julia". Find it!
    # bt.mi.main_dir_path = joinpath(pwd()[1:findfirst("artur", pwd())[end]],
    #                                "BondPricing", bt.dfn.main_dir)
    bt.mi.main_dir_path = form_main_dir_path(bt.dfn.main_dir)
    return bt
end

function set_batch_res_dir(bt)
    # Path to the Results Directory
    cond = .&(bt.model == "svm",
              abs(bt.mi._svm_dict[:sigmah] - bt.mi._svm_dict[:sigmal]) < 1e-4)
    if cond
        bt.mi.batch_res_dir = string(bt.dfn.res_dir, "Tests")
    else
        bt.mi.batch_res_dir = string(bt.dfn.res_dir, "/", uppercase(bt.model))
    end

    return bt
end


function set_maturity_dir(bt)
    bt.mi.maturity_dir = string(bt.dfn.mat_dir_prefix, 
                                 get_par_dict(bt)[:m])
    return bt
end


function set_comb_res_dir(bt)
    folder_name = string("xi_", @sprintf("%.2f", get_par_dict(bt)[:xi]),
                         "__kappa_", @sprintf("%.0f", 1e4 * get_par_dict(bt)[:kappa]),
                         "_bp", 
                         "__gross_delta_", @sprintf("%.0f", 1e4 * get_par_dict(bt)[:gross_delta]),
                         "_bp",                      
                         "__iota_", @sprintf("%.0f", 1e4 * get_par_dict(bt)[:iota]), 
                         "_bp")
    
    # if "sigma" in bt.bp._params_order
    if bt.model == "cvm"
        bt.mi.comb_res_dir = string(folder_name, "__sigmal_", 
                                     @sprintf("%.2f", get_par_dict(bt)[:sigmal]))
    else
        bt.mi.comb_res_dir = string(folder_name, 
                                     "__lambda_", @sprintf("%.2f", get_par_dict(bt)[:lambda]),
                                     "__sigmal_", @sprintf("%.2f", get_par_dict(bt)[:sigmal]),
                                     "__sigmah_", @sprintf("%.2f", get_par_dict(bt)[:sigmah]))
    end
    
    return bt
end


# ############## Get Directories ##############
function get_batch_res_dir(bt)
    return bt.mi.batch_res_dir
end
    
function get_maturity_dir(bt)
    return bt.mi.maturity_dir
end
    
function get_comb_res_dir(bt)
    return bt.mi.comb_res_dir
end

# ############## Set Paths ##############
function get_main_dir_path(bt)
    return bt.mi.main_dir_path
end


function set_comb_res_paths(bt)
    
    # Path to Main Directory
    bt = set_main_dir_path(bt)

    # Generate Folder Names:
    bt = set_batch_res_dir(bt)
    bt = set_maturity_dir(bt)
    bt = set_comb_res_dir(bt)

    # ############ Set Paths ###########
    # Main Results 
    bt.mi.batch_res_path = joinpath(get_main_dir_path(bt), get_batch_res_dir(bt))

    # Maturity
    bt.mi.maturity_path = joinpath(bt.mi.batch_res_path, get_maturity_dir(bt))

    # Parameter Combination 
    bt.mi.comb_res_path = joinpath(bt.mi.maturity_path, get_comb_res_dir(bt))
    
    return bt
end


function get_coupon_res_path(bt, coupon::Float64)
    bt = set_comb_res_paths(bt)
    
    return joinpath(bt.mi.comb_res_path, 
                    string(bt.coupon_dir_prefix, @sprintf("%.2f", coupon)))    
end



# ############## Create Directories ##############
function mk_comb_res_dirs(bt)
    # Generate Paths
    bt = set_comb_res_paths(bt)

    # Main Results
    if occursin("Tests", bt.mi.batch_res_path)
        pos = findfirst("Tests", bt.mi.batch_res_path)[1] - 1
        path = bt.mi.batch_res_path[1:pos]
        if !isdir(path)
            mkdir(path)
        end
    end

    main_res_path = split(bt.mi.batch_res_path, uppercase(bt.model))[1]
    if !isdir(main_res_path)
        mkdir(main_res_path)
    end
    
    if !isdir(bt.mi.batch_res_path)
        mkdir(bt.mi.batch_res_path)
    end
        
    # Maturity
    if !isdir(bt.mi.maturity_path)
        mkdir(bt.mi.maturity_path)
    end

    # Parameter Combination 
    if !isdir(bt.mi.comb_res_path)
        mkdir(bt.mi.comb_res_path)
    end

    return bt
end

function mk_coupon_dir(bt, coupon::Float64)
    mk_comb_res_dirs(bt)
    coupon_res_dir = get_coupon_res_path(bt, coupon)
    
    # Create coupon sub-folder:
    if !isdir(coupon_res_dir)
        mkdir(coupon_res_dir)
    end

    return coupon_res_dir
end


# ############## Get Directories ##############
function get_results_path(bt, m::Float64)
    set_main_dir_path(bt)
    if bt.mi._svm_dict == nothing
        bt.mi.batch_res_dir = bt.dfn.res_dir    
    else
        set_batch_res_dir(bt)
    end

    return string(bt.mi.main_dir_path, "/", 
                  bt.mi.batch_res_dir, 
                  string(bt.dfn.mat_dir_prefix, @sprintf("%.1f", m)))
end

