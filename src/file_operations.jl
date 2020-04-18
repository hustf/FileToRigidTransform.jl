"""
    read_dlm_line_after(filename, startpos = 0) -> (Vector{String}(), lastpos)
Read vector of strings from commented text file.
The result is from the first encountered line which doesn't start with '#'.
Also returns the last read position.
"""
function read_dlm_line_after(filename; startpos = 0)
    strconfig, lastpos = open(filename, read = true) do f
        seek(f, startpos)
        st = ""
        if !eof(f)
            st = readline(f)
            while !eof(f) && startswith(st, "#") || st == ""
                st = readline(f)
            end
        end
        st, position(f)
    end
    strip.(split(strconfig, " ", keepempty = false)), lastpos
end


"""
    specbyname(configfi) -> Dict{String, NamedTuple}

Make a channel name => [bytepos, bitpad, bitlength] dictionary.
Argument 'configfi' points to a user configuration file.
"""
function specbyname(configfi)
    # Names of channels
    chnam, lp = read_dlm_line_after(configfi)
    # address field values
    l2, lp = read_dlm_line_after(configfi, startpos = lp)
    l3, lp = read_dlm_line_after(configfi, startpos = lp)
    l4, lp = read_dlm_line_after(configfi, startpos = lp)
    v2 = parse.(Int64, l2)
    v3 = parse.(Int64, l3)
    v4 = parse.(Int64, l4)
    pairs = map(chnam, v2, v3, v4) do nam, va2, va3, va4
        (string(nam) => (; :bytepos => va2, :bitpad => va3, :bitlength => va4))
    end
    Dict{String, NamedTuple}(pairs)
end


"Read DevState given filename"
function devstate(filename)
    st, tist = open(filename, read = true) do f
        st = ""
        tist = ""
        if !eof(f)
            st = readline(f)
            while !eof(f) && startswith(st, "#") || st == ""
                st = readline(f)
            end
        end
        tist = ""
        if !eof(f)
            tist = readline(f)
            while !eof(f) && startswith(tist, "#") || tist == ""
                tist = readline(f)
            end
        end
        st, tist
    end
    if st == "" || tist == ""
        return DevState([], 0, false)
    end
    strstatevec =  split(st, " ", keepempty = false )
    statevec = parse.(UInt8, strstatevec)
    timestamp = parse(Float64, split(tist, " ", keepempty = false)[1])
    DevState(statevec, timestamp, true)
end