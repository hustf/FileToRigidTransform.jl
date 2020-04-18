import Base.show

###############
# Bytevector
###############

# Long form, as in display(h) or REPL: h enter
function Base.show(io::IO, ::MIME"text/plain", v::Bytevector)
    ioc = IOContext(io)
    n = length(v.data)
    println(ioc, "  ", n, "-element Bytevector{UInt8}:")
    print(ioc, "\t")
    if get(ioc, :color, false)
        for i = 1:n
            printstyled(ioc, string(i)[end], "¹²³⁴ ⁵⁶⁷⁸", color = :green, bold = false)
        end
    else
        for i = 1:n
            print(ioc, string(i)[end], "¹²³⁴ ⁵⁶⁷⁸")
        end
    end
    println(ioc)
    print(ioc, "\t")
    for i = 1:n
        bs = string(v.data[i], base=2, pad = 8)
        print(ioc, " ", bs[1:4], " ", bs[5:8])
    end
    print(ioc," ")
end

# Short form, as in print(stdout, h)
function Base.show(io::IO, v::Bytevector)
    ioc = IOContext(io)
    n = length(v.data)
    print(ioc, "\t")
    if get(ioc, :color, false)
        for i = 1:n
            printstyled(ioc, string(i)[end], "¹²³⁴ ⁵⁶⁷⁸", color = :green, bold = false)
        end
    else
        for i = 1:n
            print(ioc, string(i)[end], "¹²³⁴ ⁵⁶⁷⁸")
        end
    end
    println(ioc)
    print(ioc, "\t")
    for i = 1:n
        bs = string(v.data[i], base=2, pad = 8)
        print(ioc, " ", bs[1:4], " ", bs[5:8])
    end
    print(ioc," ")
end
# Standard output is fine

# The default Juno / Atom display works nicely with standard output
Base.show(io::IO, ::MIME"application/prs.juno.inline", v::Bytevector) = Base.show(io, v)

###############
# DevState
###############

# Long form, as in display(h) or REPL: h enter
function Base.show(io::IO, ::MIME"text/plain", ds::DevState)
    print(io, "DevState:")
    show(io, MIME("text/plain"), ds.values)
    print(io, "\n\t timestamp = ", ds.timestamp, ", proceed = ", ds.proceed)
end

# Short form, as in print(stdout, h)
function Base.show(io::IO, ds::DevState)
    print(io, "DevState(")
    show(io, ds.values)
    print(io, ", ", ds.timestamp, ", ", ds.proceed, ")")
end



# The default Juno / Atom display works nicely with standard output
Base.show(io::IO, ::MIME"application/prs.juno.inline", ds::DevState) = Base.show(io, v)

###############
# Utilty
###############
function bytestring(b::UInt8)
    io = IOBuffer()
    bs = string(b, base=2, pad = 8)
    print(io, bs[1:4], " ", bs[5:8])
    String(take!(io))
end