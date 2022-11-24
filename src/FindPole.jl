

function SetupDeterminantZero(FHT::FiniteHilbertTransform.FHTtype,
                              Parameters::ResponseParameters)

    # read the decomposition coefficients a_k (must be created elsewhere)
    tabaMcoef = StageaMcoef(Parameters)

    # allocate arrays for constructing the determinant
    MMat = zeros(Complex{Float64},Parameters.nradial,Parameters.nradial)
    IMat = makeIMat(Parameters.nradial)

    return IMat,MMat,tabaMcoef

end


function GoStep(omgval::Complex{Float64},
                IMat::Array{Complex{Float64},2},MMat::Array{Complex{Float64},2},
                FHT::FiniteHilbertTransform.FHTtype,
                tabaMcoef::Array{Float64,4},
                Parameters::ResponseParameters)

    nomg = 1

    tabdetXi = zeros(Float64,nomg) # real part of the determinant
    tabmevXi = zeros(Float64,nomg) # minimal eigenvalue at each frequency

    # fill the M matrix
    tabM!(omgval,MMat,tabaMcoef,FHT,Parameters)

    # compute the determinant of I-M
    detXival = detXi(IMat,MMat)

    # now compute a Jacobian via finite differences
    riomgval = omgval + 1.e-5
    upomgval = omgval + 1.e-5im

    tabM!(riomgval,MMat,tabaMcoef,FHT,Parameters)
    detXivalri = detXi(IMat,MMat)

    tabM!(upomgval,MMat,tabaMcoef,FHT,Parameters)
    detXivalup = detXi(IMat,MMat)

    dXirir = real(detXivalri-detXival)/1.e-5
    dXirii = imag(detXivalri-detXival)/1.e-5
    dXiupr = real(detXivalup-detXival)/1.e-5
    dXiupi = imag(detXivalup-detXival)/1.e-5

    jacobian = [dXirir dXiupr ; dXirii dXiupi]
    curpos = [real(detXival);imag(detXival)]
    increment = jacobian \ (-curpos)

    omgval += increment[1] + increment[2]*1im
    if Parameters.VERBOSE > 0
        println("detXi=$detXival")
        println("omega=$omgval")
    end

    return omgval,detXival

end




function FindDeterminantZero(startingomg::Complex{Float64},
                             IMat::Array{Complex{Float64},2},MMat::Array{Complex{Float64},2},
                             FHT::FiniteHilbertTransform.FHTtype,
                             tabaMcoef::Array{Float64,4},
                             Parameters::ResponseParameters;
                             TOL::Float64=1.e-12)

    # initial values
    detXival = 1.0
    omgval = startingomg

    while abs(detXival)^2 > TOL

        omgval,detXival = GoStep(omgval,IMat,MMat,FHT,tabaMcoef,Parameters)

        if abs(detXival) > 1.0
            break
        end
    end

    # what happens when this goes wrong?
    return omgval

end



function FindPole(startingomg::Complex{Float64},
                  FHT::FiniteHilbertTransform.FHTtype,
                  Parameters::ResponseParameters,
                  TOL::Float64=1.e-12)

    IMat,MMat,tabaMcoef = SetupDeterminantZero(FHT,Parameters)


    bestomg = FindDeterminantZero(startingomg,IMat,MMat,FHT,tabaMcoef,Parameters,TOL=TOL)

    (Parameters.VERBOSE >= 0) && println("Best O for n1max=$(Parameters.n1max),nradial=$(Parameters.nradial) == $bestomg")

    return bestomg

end
