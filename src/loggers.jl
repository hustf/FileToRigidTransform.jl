"This is a byte logger, used as the default callback function"
function logbytewise(ios, devconf, dsprev, ds)
    dic = Dict{Int, String}(value => key for (key, value) in devconf.bytebynamedict)
    Δds = minus_ds(ds, dsprev)
    sv = map((x , y)-> x * y==0 ? "" : string(x) , ds.values.data, Δds.values.data)
    str = join(lpad.(sv, 8))
    hv = map(sv, 1:length(sv)) do s, i
        s == "" ? "" : get(dic, i, "NA!")
    end
    strh = join(lpad.(hv, 8))
    println(ios, strh)
    println(stderr, strh)
    println(ios, str)
    println(stderr, str)
end

"""
This is a bit logger. It is useable for interpreting the ABI 
or 'Array fields', endinanness. In deed, it is easier to inspect 
this than to implement a general USB feature report.
Compare the bitlogger output with the feature reports in 
'.julia_hid/DocumentationFo/'
"""
function logbitwise(ios, devconf, dsprev, ds)
    stringbits = string(ds.values)
    stringbitsprev = if length(dsprev.values) != length(ds.values)
        stringbits
    else
        string(dsprev.values)
    end
    stringbitsdiff = map(stringbits, stringbitsprev) do c, cprev
        if c == '\n'
            '\n'
        else
            c == cprev ? " " : "_"
        end
    end |> join
    # align the difference indication to what 'show' outputs
    sbitsdiff = "\t" * split(stringbitsdiff, '\n')[2][2:end]
    
    println(ios, sbitsdiff)
    println(ios, ds)
    println(stderr, sbitsdiff)
    println(stderr, ds.values)
        # DEBUG
        println(stderr, localtime())
end