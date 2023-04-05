




"""MakeGuIsochrone
function to compute G(u), isochrone specific.

"""
function MakeGuIsochrone(ndFdJ::Function,
                         n1::Int64,n2::Int64,
                         tabWMat::Array{Float64},
                         Kuvals::Matrix{Float64},
                         Kv::Int64,nradial::Int64,
                         ωmin::Float64,ωmax::Float64,
                         vminarr::Array{Float64},vmaxarr::Array{Float64},
                         lharmonic::Int64;
                         dimension::Int64=3,
                         Ω₀::Float64=1.,bc::Float64=1.,M::Float64=1.,G::Float64=1.)

    # calculate the prefactor based on the dimensionality (defaults to 3d)
    if dimension==2
        pref = (2pi)^2
    else
        # this is averaging over the sphere already
        CMatrix = getCMatrix(lharmonic)
        pref    = -2.0*(2pi)^(3)*CYlm(CMatrix,lharmonic,n2)^(2)/(2lharmonic+1)
    end

    # get basic parameters
    Ku     = length(Kuvals)
    nradial= size(Wdata.tabW)[1]

    # set up a blank array
    tabGXi  = zeros(nradiual,nradial,Ku)

    for kuval in 1:Ku

        # retrieve integration values
        uval = Kuvals[kuval]
        vmin = vminarr[kuval]
        vmax = vmaxarr[kuval]

        # determine the step size in v
        deltav = (vmax - vmin)/(Kv)

        # initialise the result
        res = 0.0

        for kvval in 1:Kv
            vval = vmin + deltav*(kvval-0.5)

            # big step: convert input (u,v) to (rp,ra)
            # now we need (rp,ra) that corresponds to (u,v)
            α,β = OrbitalElements.αβFromUV(uval,vval,n1,n2,ωmin,ωmax)

            omega1,omega2 = α*Ω₀,α*β*Ω₀

            # convert from omega1,omega2 to (a,e) using isochrone exact version
            sma,ecc = OrbitalElements.IsochroneAEFromOmega1Omega2(omega1,omega2,bc,M,G)

            # get (rp,ra)
            rp,ra = OrbitalElements.RpRafromAE(sma,ecc)

            # need (E,L), use isochrone exact version
            Eval,Lval = OrbitalElements.isochroneELfromrpra(rp,ra,bc,M,G)

            # compute Jacobians
            #(α,β) -> (u,v)
            Jacαβ = OrbitalElements.JacαβToUV(n1,n2,ωmin,ωmax,vval)

            #(E,L) -> (α,β): Isochrone analytic
            JacEL        = OrbitalElements.IsochroneJacELtoαβ(α,β,bc,M,G)

            #(J) -> (E,L)
            JacJ         = (1/omega1)

            # remove dimensionality
            dimensionl   = (1/Ω₀)


            # get the resonance vector
            ndotOmega = n1*omega1 + n2*omega2

            # compute dF/dJ: call out for value
            valndFdJ  = ndFdJ(n1,n2,Eval,Lval,ndotOmega)

            # loop through all basis function combinations
            for np = 1:nradial
                for nq = 1:nradial

                    # get tabulated W values for different basis functions np,nq
                    Wp = tabWMat[np,kuval,kvval]
                    Wq = tabWMat[nq,kuval,kvval]

                    if dimension==2
                        # Local increment in the location (u,v)
                        res += deltav*pref*(dimensionl*Jacαβ*JacEL*JacJ*valndFdJ)*Wp*Wq

                    else
                        # add in extra Lval from the action-space volume element (Hamilton et al. 2018, eq 30)
                        res += deltav*pref*Lval*(dimensionl*Jacαβ*JacEL*JacJ*valndFdJ)*Wp*Wq # Local increment in the location (u,v)
                    end

                end
            end

        end

        # complete the integration
        res *= deltav
        tabGXi[kuval] = res

    end
    return tabGXi

end



"""
    RunGfuncIsochrone(inputfile)

"""
function RunGfuncIsochrone(ndFdJ::Function,
                           wmatdir::String,gfuncdir::String,
                           Ku::Int64,Kv::Int64,Kw::Int64,
                           basis::AstroBasis.AbstractAstroBasis,
                           lharmonic::Int64,
                           n1max::Int64,
                           nradial::Int64,
                           Ω₀::Float64,
                           modelname::String,dfname::String,
                           rb::Float64;
                           bc::Float64=1.0,G::Float64=1.0,M::Float64=1.0,
                           VERBOSE::Int64=0)


    # Check directory names
    CheckConfigurationDirectories([wmatdir,gfuncdir]) || (return 0)

    # get basis parameters
    dimension = basis.dimension

    # legendre integration prep
    tabuGLquadtmp,tabwGLquad = FiniteHilbertTransform.tabuwGLquad(Ku)
    tabuGLquad = reshape(tabuGLquadtmp,Ku,1)

    # Resonance vectors
    nbResVec, tabResVec = MakeTabResVec(lharmonic,n1max,dimension)

    if VERBOSE > 0
        println("LinearResponse.GFuncIsochrone.RunGfuncIsochrone: Considering $nbResVec resonances.")
    end


    Threads.@threads for i = 1:nbResVec

        n1,n2 = tabResVec[1,i],tabResVec[2,i]
        if VERBOSE > 0
            println("LinearResponse.GFuncIsochrone.RunGfuncIsochrone: Starting on ($n1,$n2).")
        end

        # could compute the (u,v) boundaries here (or at least wmin,wmax)
        # compute the frequency scaling factors for this resonance
        ωmin,ωmax = OrbitalElements.FindWminWmaxIsochrone(n1,n2)
        if VERBOSE > 0
            println("LinearResponse.GFuncIsochrone.RunGfuncIsochrone: ωmin=$ωmin,ωmax=$ωmax")
        end

        # for some threading reason, make sure Ku is defined here
        Ku = length(tabwGLquad)

        # loop through once and design a v array for min, max
        vminarr,vmaxarr = zeros(Ku),zeros(Ku)
        for uval = 1:Ku
           vminarr[uval],vmaxarr[uval] = OrbitalElements.FindVminVmaxIsochrone(n1,n2,tabuGLquad[uval])
        end

        # load a value of tabWmat, plus (a,e) values
        filename = WMatFilename(wmatdir,modelname,lharmonic,n1,n2,rb,Ku,Kv,Kw)
        file = h5open(filename,"r")
        Wtab = read(file,"wmat")
        nradial,Ku,Kv = size(Wtab)

        # print the size of the found files if the first processor
        if (i==0) & (VERBOSE > 0)
            println("LinearResponse.GFuncIsochrone.RunGfuncIsochrone: Found nradial=$nradial,Ku=$Ku,Kv=$Kv")
        end

        outputfilename = GFuncFilename(gfuncdir,modelname,dfname,lharmonic,n1,n2,rb,Ku,Kv)
        if isfile(outputfilename)

            if VERBOSE > 0
                println("LinearResponse.GFuncIsochrone.RunGfuncIsochrone: file already exists for step $i of $nbResVec, ($n1,$n2).")
            end

            continue
        end

        # is having the file open bad?
        # need to loop through all combos of np and nq to make the full matrix.
        h5open(outputfilename, "w") do file


            @time tabGXi = MakeGuIsochrone(ndFdJ,
                                               n1,n2,
                                               Wtab,
                                               tabuGLquad,Kv,nradial,
                                               ωmin,ωmax,
                                               vminarr,vmaxarr,
                                               lharmonic,
                                               dimension=dimension,Ω₀=Ω₀)

            write(file, "GXinp"*string(np)*"nq"*string(nq),tabGXi)


        end # end open file
    end

end
