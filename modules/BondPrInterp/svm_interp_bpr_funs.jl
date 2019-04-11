
# ##################################################################
# ######################### J2: f21, f22 ###########################
# ################################################################## 

# function f21_inputs(svm, vtgrid, ttmgrid; vmax=1.2, uN=10^3)
function f21_inputs(svm)   
    f21_fd_input = @spawn [f21_int(vt,
                                   svm.bi.vmax,
                                   svm.pm.lambda,
                                   svm.pm.sigmal,
                                   svm.pm.r,
                                   svm.pm.gross_delta,
                                   svm.pm.xi,
                                   svm.pm.kappa;
                                   ttm=tau, N=svm.bi.uN) for vt in svm.bs.vtgrid,
                                                            tau in svm.bs.ttmgrid]

    return fetch(f21_fd_input)
end


# function f22_inputs(svm, vtgrid, ttmgrid; vmax=1.2, uN=10^3)
function f22_inputs(svm)
    f22_fd_input = @spawn [f22_int(vt,
                                   svm.bi.vmax,
                                   svm.pm.lambda,
                                   svm.pm.sigmal,
                                   svm.pm.r,
                                   svm.pm.gross_delta,
                                   svm.pm.xi,
                                   svm.pm.kappa; 
				   ttm=tau, N=svm.bi.uN) for vt in svm.bs.vtgrid,
                                                            tau in svm.bs.ttmgrid]

    return fetch(f22_fd_input)
end


# ##################################################################
# ########################### f11_int ##############################
# ################################################################## 
# function f11_inputs(svm, vtgrid, ttmgrid;
#                        vmax=1.2, vN=10^3, uN=10^3)
function f11_inputs(svm)
    dv, vgrid = grid_creator(1e-4, svm.bi.vmax, svm.bi.vN)

    f11_vec = @spawn [f11v_int(vt,
                               grid_creator(0.0, ttm, svm.bi.uN)[2],
                               vgrid,
                               svm.pm.lambda,
                               svm.pm.sigmal,
                               svm.pm.r,
                               svm.pm.gross_delta,
                               svm.pm.xi,
                               svm.pm.kappa) for vt in svm.bs.vtgrid,
                                                ttm in svm.bs.ttmgrid]

    return fetch(f11_vec)
end

# ##################################################################
# ########################### f2_int ###############################
# ################################################################## 
# function f12_inputs(svm, vtgrid, ttmgrid, vbhlgrid;
# 		       vmax=1.2, vN=10^3, uN=10^3)
function f12_inputs(svm)
    _, vgrid = grid_creator(1e-4, svm.bi.vmax, svm.bi.vN)

    f12_surf = @spawn [f12_int(vt,
                               vbhl,
                               grid_creator(0.0, ttm, svm.bi.uN)[2],
                               vgrid,  
			       svm.pm.lambda,
                               svm.pm.sigmal,
                               svm.pm.sigmah,
                               svm.pm.r,
                               svm.pm.gross_delta, 
			       svm.pm.xi,
                               svm.pm.kappa) for vt in svm.bs.vtgrid,
                                                ttm in svm.bs.ttmgrid,
                                               vbhl in svm.bs.vbhlgrid]

    return fetch(f12_surf)
end
	
# ##################################################################
# ########################### f3_int ###############################
# ################################################################## 
# function f13_inputs(svm, vtgrid, ttmgrid, vbhlgrid;
# 		       vmax=1.2, vN=10^3, uN=10^3)
function f13_inputs(svm)
    _, vgrid = grid_creator(1e-4, svm.bi.vmax, svm.bi.vN)

    f13_surf = @spawn [f13_int(vt, vbhl,
                               grid_creator(0.0, ttm, svm.bi.uN)[2],
                               vgrid,  
			       svm.pm.lambda,
                               svm.pm.sigmal,
                               svm.pm.sigmah,
                               svm.pm.r,
                               svm.pm.gross_delta, 
			       svm.pm.xi,
                               svm.pm.kappa) for vt in svm.bs.vtgrid,
                                                ttm in svm.bs.ttmgrid,
                                               vbhl in svm.bs.vbhlgrid]

    return fetch(f13_surf)
end	

# ##################################################################
# ########################### Interp ###############################
# ################################################################## 
# function bpr_surfs(svm; vtmax=.8, vtN=25, vtgrid=nothing,
#                    ttm_max=svm.m, ttmN=15, ttmgrid=nothing,
#                    vbhlmin=.75, vbhlmax=1.25, vbhlN=20, vbhlgrid=nothing,
#                    vmax=1.2, vN=10^3, uN=10^3)
#     # ####################################
#     # ##### Form Interpolation Grids #####
#     # ####################################
#     if vtgrid==nothing
#        _, vtgrid=grid_creator(0.0, vtmax, vtN)
#     end

#     if ttmgrid==nothing
#         _, ttmgrid = grid_creator(0.0, ttm_max, ttmN)
#     end
    
#     if vbhlgrid==nothing
#        _, vbhlgrid=grid_creator(vbhlmin, vbhlmax, vbhlN)
#     end
#     # ####################################
                                      
#     f11 = @spawn f11_inputs(svm, vtgrid, ttmgrid;
#                                vmax=vmax, vN=vN, uN=uN)
     
#     f12 = @spawn f12_inputs(svm, vtgrid, ttmgrid, vbhlgrid;
#                                vmax=vmax, vN=uN, uN=uN)
     
#     f13 = @spawn f13_inputs(svm, vtgrid, ttmgrid, vbhlgrid;
#                             vmax=vmax, vN=vN, uN=uN)
    
#     f21 = @spawn f21_inputs(svm, vtgrid, ttmgrid; vmax=vmax, uN=uN)
         
#     f22 = @spawn f22_inputs(svm, vtgrid, ttmgrid; vmax=vmax, uN=uN)

    
#     f11_surf = fetch(f11)
#     f12_surf = fetch(f12)
#     f13_surf = fetch(f13)
#     f21_surf = fetch(f21)
#     f22_surf = fetch(f22)

#     return Dict("vmax" => vmax,
#                 "vtmax" => vtmax,
#                 "vtgrid"=> vtgrid,
#                 "ttm_max" => ttm_max,
#                 "ttmgrid" => ttmgrid, 
#                 "vbhlmin" => vbhlmin,
#                 "vbhlmax" => vbhlmax, 
# 		"vbhlgrid"=> vbhlgrid,
# 	        "f11_surf"=> f11_surf,
# 	        "f12_surf"=> f12_surf,
# 	        "f13_surf"=> f13_surf,
#                 "f21_surf"=> f21_surf,
#                 "f22_surf"=> f22_surf)
# end


function bpr_surfs(svm)
    # ####################################
    # ##### Form Interpolation Grids #####
    # ####################################
    svm = set_bpr_grids(svm)
    # ####################################
    
    svm.bs.f11_surf = fetch(@spawn f11_inputs(svm))
    svm.bs.f12_surf = fetch(@spawn f12_inputs(svm))
    svm.bs.f13_surf = fetch(@spawn f13_inputs(svm))
    svm.bs.f21_surf = fetch(@spawn f21_inputs(svm))
    svm.bs.f22_surf = fetch(@spawn f22_inputs(svm))

    return svm
end




function gen_ref_surfs(svm)
    return Dict("ttmgrid_ref" => range(minimum(svm.bs.ttmgrid),
                                       stop=svm.bi.ttm_max,
                                       length=svm.bi.ttmN_ref),
                "vtgrid_ref" => range(minimum(svm.bs.vtgrid),
                                      stop=svm.bi.vtmax,
                                      length=svm.bi.vtN_ref),
                "vbhlgrid_ref" => range(minimum(svm.bs.vbhlgrid),
                                        stop=svm.bi.vbhlmax,
                                        length=svm.bi.vbhlN_ref))
end


function bpr_interp_f1f(svm, mat, ref_surfs)
    xN = size(svm.bs.vtgrid, 1)
    # spl = Dierckx.Spline2D(svm.bs.vtgrid, svm.bs.ttmgrid, mat;
    #                        kx=3, ky=3, s=0.0)
    spl = Dierckx.Spline2D(svm.bs.vtgrid, svm.bs.ttmgrid, mat;
                           kx=3, ky=3, s=xN)


    tmp_surf = fetch(@spawn [Dierckx.evaluate(spl, vt, ttm) for
                             vt in ref_surfs["vtgrid_ref"],
                             ttm in ref_surfs["ttmgrid_ref"]])
    f_itp = Interpolations.interpolate(tmp_surf,
                                       BSpline(Cubic(Line(Interpolations.OnGrid()))))

    return Interpolations.scale(f_itp, ref_surfs["vtgrid_ref"],
                                ref_surfs["ttmgrid_ref"])
end


function bpr_interp_f2f(svm, mat)
    f_itp = Interpolations.interpolate(mat, BSpline(Cubic(Line(Interpolations.OnGrid()))))
    return Interpolations.scale(f_itp, svm.bs.vtgrid,
                                svm.bs.ttmgrid, svm.bs.vbhlgrid)
end


function bpr_interp(svm)
    ref_surfs = gen_ref_surfs(svm)

    svm.bf.f11 = bpr_interp_f1f(svm, svm.bs.f11_surf, ref_surfs)
    svm.bf.f12 = bpr_interp_f2f(svm, svm.bs.f12_surf)
    svm.bf.f13 = bpr_interp_f2f(svm, svm.bs.f13_surf)
    svm.bf.f21 = bpr_interp_f1f(svm, svm.bs.f21_surf, ref_surfs)
    svm.bf.f22 = bpr_interp_f1f(svm, svm.bs.f22_surf, ref_surfs)

    return svm
end


# function gen_ref_grids(bprf; ttmN_ref=400, vtN_ref=600, vbhlN_ref=500)

#     return Dict{String, Any}("ttmgrid_ref" => range(svm.bs.ttmgrid),
#                                        stop=svm.bi.ttm_max,
#                                        length=svm.bi.ttmN_ref),
#                 "vtgrid_ref" => range(minimum(svm.bs.vtgrid),
#                                       stop=svm.bi.vtmax,
#                                       length=svm.bi.vtN_ref),
#                 "vbhlgrid_ref" => range(minimum(svm.bs.vbhlgrid),
#                                         stop=svm.bi.vbhlmax,
#                                         length=svm.bi.vbhlN_ref))
# end


# function bpr_interp(bprf; vtN_ref=600, ttmN_ref=450, vbhlN_ref=550)

#     ref_surfs = gen_ref_grids(bprf;
#                               vtN_ref=vtN_ref,
#                               ttmN_ref=ttmN_ref,
#                               vbhlN_ref=vbhlN_ref)
#     # ref_surfs = gen_ref_cubes(bprf, ref_surfs)

#     for f in ["f11", "f21", "f22"]
#         spl = Dierckx.Spline2D(bprf["vtgrid"], bprf["ttmgrid"],
#                                 bprf[string(f, "_surf")]; kx=3, ky=3, s=0.0)
#         tmp_surf = fetch(@spawn [Dierckx.evaluate(spl, vt, ttm) for vt in ref_surfs["vtgrid_ref"], 
#                                               ttm in ref_surfs["ttmgrid_ref"]])
#         f_itp = Interpolations.interpolate(tmp_surf,
#                                            BSpline(Cubic(Line(Interpolations.OnGrid()))))
#         bprf[f] = Interpolations.scale(f_itp, ref_surfs["vtgrid_ref"], ref_surfs["ttmgrid_ref"])

        
#         # f_itp = Interpolations.interpolate(bprd[string(f, "_surf")], BSpline(Cubic(Line(Interpolations.OnGrid()))))
#         # bprd[f] = Interpolations.scale(f_itp, bprd["vtgrid"], bprd["ttmgrid"])
#     end

#     for f in ["f12", "f13"]
#         f_itp = Interpolations.interpolate(bprf[string(f, "_surf")],
#                                            BSpline(Cubic(Line(Interpolations.OnGrid()))))
#         bprf[f] = Interpolations.scale(f_itp,
#                                        bprf["vtgrid"],
#                                        bprf["ttmgrid"],
#                                        bprf["vbhlgrid"])

#         # f_itp = Interpolations.interpolate(ref_surfs[string(f, "_ref_surf")],
#         #                                    BSpline(Cubic(Line(Interpolations.OnGrid()))))
#         # bprf[f] = Interpolations.scale(f_itp,
#         #                                ref_surfs["vtgrid_ref"],
#         #                                ref_surfs["ttmgrid_ref"],
#         #                                ref_surfs["vbhlgrid_ref"]) 
        
#     end
    
#     return bprf
# end


# # Refine f surfs for f in ["f11", "f21", "f22"]
# function gen_ref_surfs(bprf, ref_surfs)
#     for f in ["f11", "f21", "f22"]
#         tmpf = sp_interpolate.interp2d(bprf["ttmgrid"],
#                                        bprf["vtgrid"],
#                                        bprf[string(f, "_surf")],
#                                           kind="cubic")

#         ref_surfs[string(f, "_ref_surf")] = tmpf(ref_surfs["ttmgrid_ref"],
#                                    ref_surfs["vtgrid_ref"])
#     end
    
#     return ref_surfs
# end


# function gen_ref_cubes(bprf, ref_surfs)
#     # Pre-Interpolate f12 and f13 in vbhl:
#     for f in ["f12", "f13"]
#         f_itp = Interpolations.interpolate(bprf[string(f, "_surf")], 
#                                            BSpline(Cubic(Line(Interpolations.OnGrid()))))
#         f_sitp = Interpolations.scale(f_itp,
#                                       bprf["vtgrid"],
#                                       bprf["ttmgrid"],
#                                       bprf["vbhlgrid"])

#         tmp_surf = [f_sitp(vt, ttm, vbhl) for vt in bprf["vtgrid"], 
#                                              ttm in bprf["ttmgrid"], 
#                                             vbhl in ref_surfs["vbhlgrid_ref"]]


#         ref_surfs[string(f, "_ref_surf")] = zeros((length(ref_surfs["vtgrid_ref"]),
#                                                    length(ref_surfs["ttmgrid_ref"]),
#                                                    length(ref_surfs["vbhlgrid_ref"])))

#         for i in 1:length("vbhlgrid_ref")
#             tmpf = sp_interpolate.interp2d(bprf["ttmgrid"], 
#                                            bprf["vtgrid"], 
#                                            tmp_surf[:,:,i], 
#                                            kind="cubic")
        
#             ref_surfs[string(f, "_ref_surf")][:, :, i] = tmpf(ref_surfs["ttmgrid_ref"], 
#                                                               ref_surfs["vtgrid_ref"])

#             # tmpf_itp = Interpolations.interpolate(tmp_surf[:,:,i],
#             #                                       BSpline(Cubic(Line(Interpolations.OnGrid()))))
#             # tmpf = Interpolations.scale(tmpf_itp, bprf["vtgrid"], bprf["ttmgrid"])
            
#             # ref_surfs[string(f, "_ref_surf")][:, :, i] = [tmpf(vt, ttm)
#             #                                               for vt in ref_surfs["vtgrid_ref"],
#             #                                               ttm in ref_surfs["ttmgrid_ref"]]
#         end
#     end

#     return ref_surfs
# end


# function gen_ref_surfs_cubes(bprf; vtN_ref=500, ttmN_ref=350, vbhlN_ref=400)

#     ref_surfs = gen_ref_grids(bprf;
#                               vtN_ref=vtN_ref,
#                               ttmN_ref=ttmN_ref,
#                               vbhlN_ref=vbhlN_ref)

#     ref_surfs = gen_ref_surfs(bprf, ref_surfs)
#     # ref_surfs = gen_ref_cubes(bprf, ref_surfs)
    
#     return ref_surfs
# end


# function bpr_interp(bprd; vtN_ref=600, ttmN_ref=450, vbhlN_ref=550)

#     ref_surfs = gen_ref_surfs_cubes(bprd, vtN_ref=vtN_ref,
#                                     ttmN_ref=ttmN_ref, vbhlN_ref=vbhlN_ref)
#     for f in ["f11", "f21", "f22"]
#         f_itp = Interpolations.interpolate(ref_surfs[string(f, "_ref_surf")],
#                                             BSpline(Cubic(Line(Interpolations.OnGrid()))))
#         bprd[f] = Interpolations.scale(f_itp, ref_surfs["vtgrid_ref"], ref_surfs["ttmgrid_ref"])

#         # f_itp = Interpolations.interpolate(bprd[string(f, "_surf")], BSpline(Cubic(Line(Interpolations.OnGrid()))))
#         # bprd[f] = Interpolations.scale(f_itp, bprd["vtgrid"], bprd["ttmgrid"])
#         # bprf[f] = ref_surfs[string(f, "_ref_surf")
#     end

#     for f in ["f12", "f13"]
#         # bprd[f] = sp_interpolate.RegularGridInterpolator((ref_surfs["vtgrid_ref"],
#         #                                               ref_surfs["ttmgrid_ref"],
#         #                                               ref_surfs["vbhlgrid_ref"]),
#         #                                               ref_surfs[string(f, "_ref_surf")],
#         #                                               method="linear")

#         # tmp_cube = [tmp([vt, ttm, vbhl]) for vt in ref_surfs["vtgrid_ref"],
#         #                                   ttm in ref_surfs["ttmgrid_ref"],
#         #                                  vbhl in ref_surfs["vbhlgrid_ref"]]
#         # # ref_surfs[string(f, "_ref_surf")]


#         # f_itp = Interpolations.interpolate(ref_surfs[string(f, "_ref_surf")],
#         #                                    BSpline(Cubic(Line(Interpolations.OnGrid()))))
#         # bprd[f] = Interpolations.scale(f_itp,
#         #                                ref_surfs["vtgrid_ref"],
#         #                                ref_surfs["ttmgrid_ref"],
#         #                                ref_surfs["vbhlgrid_ref"])

#         f_itp = Interpolations.interpolate(bprd[string(f, "_surf")], BSpline(Cubic(Line(Interpolations.OnGrid()))))
#         bprd[f] = Interpolations.scale(f_itp,
#                                        bprd["vtgrid"],
#                                        bprd["ttmgrid"],
#                                        bprd["vbhlgrid"])
#     end
    
#     return bprd 
# end


# function gen_ref_cubes(bprf, ref_surfs)
#     # Pre-Interpolate f12 and f13 in vbhl:
#     for f in ["f12", "f13"]
#         f_itp = Interpolations.interpolate(bprf[string(f, "_surf")], 
#                                            BSpline(Cubic(Line(Interpolations.OnGrid()))))
#         f_sitp = Interpolations.scale(f_itp,
#                                       bprf["vtgrid"],
#                                       bprf["ttmgrid"],
#                                       bprf["vbhlgrid"])

#         tmp_surf = [f_sitp(vt, ttm, vbhl) for vt in bprf["vtgrid"], 
#                                              ttm in bprf["ttmgrid"], 
#                                             vbhl in ref_surfs["vbhlgrid_ref"]]


#         ref_surfs[string(f, "_ref_surf")] = zeros((length(ref_surfs["vtgrid_ref"]),
#                                                    length(ref_surfs["ttmgrid_ref"]),
#                                                    length(ref_surfs["vbhlgrid_ref"])))

#         for i in 1:length("vbhlgrid_ref")
#             spl = Dierckx.Spline2D(bprf["vtgrid"], bprf["ttmgrid"],
#                                     tmp_surf[:,:,i];
#                                    kx=3, ky=3, s=0.0)
#             ref_surfs[string(f, "_ref_surf")][:, :, i] = fetch(@spawn [Dierckx.evaluate(spl, vt, ttm)
#                                                                        for vt in ref_surfs["vtgrid_ref"],
#                                                                           ttm in ref_surfs["ttmgrid_ref"]])
#         end
#     end

#     return ref_surfs
# end