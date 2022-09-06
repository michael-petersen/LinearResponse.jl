
inputfile = "ModelParamIsochrone_damped.jl"
include(inputfile)

import CallAResponse
using HDF5

# call the function to construct W matrices
CallAResponse.RunWmat(ψ,dψ,d2ψ,d3ψ,
                      wmatdir,
                      FHT,
                      Kv,Kw,
                      basis,
                      lharmonic,
                      n1max,
                      Ω₀,
                      modelname,
                      rmin,rmax,
                      VERBOSE=2)


# call the function to compute G(u) functions
CallAResponse.RunGfunc(ψ,dψ,d2ψ,d3ψ,d4ψ,
                     ndFdJ,
                     wmatdir,gfuncdir,
                     FHT,
                     Kv,Kw,
                     basis,
                     lharmonic,
                     n1max,
                     Ω₀,
                     modelname,dfname,
                     rmin,rmax,
                     VERBOSE=1)

# compute the matrix response at each location
tabdet = CallAResponse.RunM(tabomega,
                         dψ,d2ψ,
                         gfuncdir,modedir,
                         FHT,
                         Kv,Kw,
                         basis,
                         lharmonic,
                         n1max,
                         Ω₀,
                         modelname,dfname,
                         rmin,rmax,
                         VERBOSE=1)


# compute the determinants with a gradient descent: only along a given axis right now!
bestomg = CallAResponse.FindZeroCrossing(0.00,0.03,dψ,d2ψ,
                                        gfuncdir,modedir,
                                        K_u,K_v,K_w,
                                        basis,
                                        lharmonic,
                                        n1max,
                                        nradial,
                                        Ω₀,
                                        modelname,dfname,
                                        rb,
                                        rmin,rmax,NITER=16,VERBOSE=1)

#bestomg = 0.0 + 0.02271406012170436im
println("The zero-crossing frequency is $bestomg.")

# for the minimum, go back and compute the mode shape
EV,EF,EM = CallAResponse.ComputeModeTables(bestomg,dψ,d2ψ,
                                           gfuncdir,modedir,
                                           K_u,K_v,K_w,
                                           basis,
                                           lharmonic,
                                           n1max,
                                           nradial,
                                           Ω₀,
                                           modelname,dfname,
                                           rb,
                                           VERBOSE=1)

ModeRadius,ModePotentialShape,ModeDensityShape = CallAResponse.GetModeShape(basis,lharmonic,
                                            0.01,15.,100,EM,VERBOSE=1)
