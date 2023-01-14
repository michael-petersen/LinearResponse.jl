


function CheckValidDirectory(dir::String)

    # check that this is in fact a directory
    if !isdir(dir)
        println("CallAResponse.IO.CheckValidDirectory: nonexistent directory $dir.")
        return false
    end

    # check the trailing slash
    if last(dir)!='/'
        println("CallAResponse.IO.CheckValidDirectory: bad dir (needs trailing /) $dir")
        return false
    end

    # finally, try opening a file to check write permissions
    try
        tst = open(dir*"tst.dat", "w")
        close(tst)
        rm(dir*"tst.dat")
    catch e
        println("CallAResponse.IO.CheckValidDirectory: cannot write test file to $dir")
        return false
    end

    return true
end

"""
check for existence of directories
"""
function CheckConfigurationDirectories(dirs::Array{String})

    # check for all specified directories (will succeed if no directory is specified, just might annoyingly print to wherever code is executed,)
    for dir in dirs
        ((dir=="") || CheckValidDirectory(dir)) || (return false)
    end
    return true
end


"""
    WMatFilename()

filename for a given wmat result
"""
function WMatFilename(n1::Int64,n2::Int64,Parameters::ResponseParameters)

    return Parameters.wmatdir*"wmat_"*Parameters.modelname*"_l_"*string(Parameters.lharmonic)*"_n1_"*string(n1)*"_n2_"*string(n2)*"_rb_"*string(Parameters.rbasis)*"_Ku_"*string(Parameters.Ku)*"_Kv_"*string(Parameters.Kv)*"_Kw_"*string(Parameters.Kw)*".h5"
end

"""
    GFuncFilename()

filename for a given Gfunc result
"""
function GFuncFilename(n1::Int64,n2::Int64,Parameters::ResponseParameters)

    return Parameters.gfuncdir*"Gfunc_"*Parameters.modelname*"_df_"*Parameters.dfname*"_l_"*string(Parameters.lharmonic)*"_n1_"*string(n1)*"_n2_"*string(n2)*"_rb_"*string(Parameters.rbasis)*"_Ku_"*string(Parameters.Ku)*"_Kv_"*string(Parameters.Kv)*".h5"
end

"""
    mode_filename()

"""
function ModeFilename(Parameters::ResponseParameters)

    return Parameters.modedir*"ModeShape_"*Parameters.modelname*"_df_"*Parameters.dfname*"_l_"*string(Parameters.lharmonic)*"_n1_"*string(Parameters.n1max)*"_rb_"*string(Parameters.rbasis)*"_Ku_"*string(Parameters.Ku)*"_Kv_"*string(Parameters.Kv)*".h5"
end


"""
    det_filename()

"""
function DetFilename(Parameters::ResponseParameters)

    return Parameters.modedir*"Determinant_"*Parameters.modelname*"_df_"*Parameters.dfname*"_l_"*string(Parameters.lharmonic)*"_n1_"*string(Parameters.n1max)*"_rb_"*string(Parameters.rbasis)*"_Ku_"*string(Parameters.Ku)*"_Kv_"*string(Parameters.Kv)*".h5"
end

"""
Create and (over)write the determinant array to a file
"""
function WriteDeterminant(detname::String,
                          tabomega::Array{Complex{Float64}},
                          tabdet::Array{Complex{Float64}})

    h5open(detname, "w") do file
        #write(file,"nx",)
        write(file,"omega",real(tabomega))
        write(file,"eta",imag(tabomega))
        write(file,"det",tabdet)
    end
end

"""
    AxiFilename()

"""
function AxiFilename(n1::Int64,n2::Int64,
                     Parameters::ResponseParameters)

    return Parameters.modedir*"TabAXi_"*Parameters.modelname*"_df_"*Parameters.dfname*"_l_"*string(Parameters.lharmonic)*"_n1_"*string(n1)*"_n2_"*string(n2)*"_rb_"*string(Parameters.rbasis)*"_Ku_"*string(Parameters.Ku)*"_Kv_"*string(Parameters.Kv)*".h5"
end


"""
    MFilename()

"""
function MFilename(Parameters::ResponseParameters)

    return Parameters.modedir*"TabM_"*Parameters.modelname*"_df_"*Parameters.dfname*"_l_"*string(Parameters.lharmonic)*"_rb_"*string(Parameters.rbasis)*"_Ku_"*string(Parameters.Ku)*"_Kv_"*string(Parameters.Kv)*".h5"

end

"""
write all the parameters to a file
"""
function WriteParameters(filename::String,
                         Parameters::ResponseParameters,
                         mode::String="r+")

    h5open(filename, mode) do file
        WriteParameters(file,Parameters)
    end
end

function WriteParameters(file::HDF5.File,
                         Parameters::ResponseParameters)

    group = create_group(file,"ResponseParameters")
    for i = 1:fieldcount(ResponseParameters)
        varname = string(fieldname(ResponseParameters,i))
        if (varname == "tabResVec")
            continue
        elseif (varname == "OEparams")
            OrbitalElements.WriteParameters(file,Parameters.OEparams)
        else
            try write(group,varname,getfield(Parameters,i)) catch; println("Unable to write parameter: "*varname) end
        end
    end
end


"""
    Check if a file exist, has enough basis elements / if overwritting is expected
    Return true if computation needed, and false if not, i.e. if all following conditions are satisfied:
        - the file already exists,
        - overwritting is not mandatory (OVERWRITE == false)
        - the old file has been created with enough basis elements (nradial sufficiently high)
"""
function CheckFileNradial(filename::String,
                          Parameters::ResponseParameters,
                          preprint::String="")
        
    if isfile(filename)
        oldnradial = h5read(filename,"ResponseParameters/nradial")
        if (Parameters.OVERWRITE == false) && (Parameters.nradial <= oldnradial)
            (Parameters.VERBOSE > 0) && println(preprint*" file already exists with higher nradial: no computation.")
            return false
        else
            (Parameters.VERBOSE > 0) && println(preprint*" file already exists (possibly with lower nradial) : recomputing and overwriting.")
            return true
        end
    else 
        return true
    end
end