"This is a channel logger, used as the default callback function"
function log_by_channel(ios, devconf, accumulated, dsprev, ds)
    #dic = Dict{Int, String}(value => key for (key, value) in devconf.specbynamedict)
    dic = devconf.specbynamedict
    chna = collect(keys(dic))
    if length(chna)!= 0
        # Channel names sorted by startbit
        startbits = map(chna) do na
            addressfields = dic[na]
            addressfields.bytepos + addressfields.bitpad
        end
        p = sortperm(startbits)
        sortna = chna[p]

        # Current channel values in sequence of sortna
        v = map(sortna) do s
            spec = dic[s]
            extract(ds.values, spec...)
        end
        # Previous channel values in sequence of sortna
        vprev = if length(dsprev.values) > 0
            map(sortna) do s
                spec = dic[s]
                extract(dsprev.values, spec...)
            end
        else
            v
        end
        # Change per channel
        Δv = v - vprev
  
        # Format values, blank for unchanged values
        sv = map((x , Δ)-> x * Δ==0 ? "" : string(x) , v, Δv)
        str = join(lpad.(sv, 7))
        
        # Plain headers for files
        strh = join(lpad.(sortna, 7))
        println(ios, strh * "\n" * str)

        # Colorful headers for repl, indicating changes
        iob = IOBuffer()
        ioc = IOContext(iob, :color => true)

        for (na, Δ) in zip(sortna, Δv)
            s = lpad(na, 7)
            if Δ == 0
                printstyled(ioc, s, color= :blue)
            else
                print(ioc, s)
            end
        end
        print(ioc, "\n")
        println(ioc, str)
        println(stderr, String(take!(iob)))
    else
        println(ios, "log_by_channel: No device configuration available for \n\t$(devconf.filename)")
        throw(ErrorException("log_by_channel: No device configuration available for \n\t$(devconf.filename)"))
    end
end

"""
This is a bit logger. It is useable for interpreting the ABI 
or 'Array fields', endinanness. In deed, it is easier to inspect 
this than to implement a general USB feature report.
Compare the log_by_bit output with the feature reports in 
'.julia_hid/DocumentationFo/'
"""
function log_by_bit(ios, devconf, accumulated, dsprev, ds)
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
end

"""
This is a bit logger which accumulates changes in single bits over time.
The number of times each bit has been set is shown.
Otherwise, works as log_by_bit.
"""
function log_by_bit_accumulate_changes(ios, devconf, accumulated, dsprev, ds)
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
    # accumulate changes in a vector, counting changes
    changevec = map(collect(sbitsdiff[2:end])) do c
        if c == '_' 
            1
        else
            0
        end
    end
    accumulatedchanges = if length(changevec) != length(accumulated)
        changevec
    else
        changevec + accumulated
    end

    println(ios, sbitsdiff)
    println(ios, ds)
    #print_barplot(io,
    println(stderr, sbitsdiff)
    println(stderr, ds.values)
    print(stderr, "\t")
    print_barplot(stderr, accumulatedchanges)
    accumulatedchanges
end

"Find device state change"
function minus_ds(x::T, y::T) where {T <: DevState}
    if length(x.values) == length(y.values)
        DevState(x.values.data - y.values.data, x.timestamp - y.timestamp, x.proceed || y.proceed)
    else
        @debug "Could not subtract, vecor lengths, x $(length(x.values.data)), y $(length(y.values.data))"
        x
    end
end

"Prints the vector as as a string of chars from minimum(blank) to maximum (full)"
function print_barplot(io, v::Vector{T}) where {T<:Real}
    # 1..12
    bars = [' ', '_','▁', '▂', '▃', '▄', '▅', '▆', '▇', '█', '▔']
    mx = maximum(v)
    @assert minimum(v) >= 0 "horplot_string: Can't handle negative numbers"
    for i = 1:length(v)
        val = mx > 0 ? v[i] / mx : v[i]
        bucket = Int((ceil(10 * val)) + 1)
        print(io, bars[bucket])
    end
    print(io, '\n')
end