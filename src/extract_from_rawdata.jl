"""
    drophighbits(n, x::UInt8) -> UInt8
### Examples
    julia> drophighbits(0, 0b11111111)
    255

    julia> drophighbits(1, 0b11111111) |> FileToRigidTransform.bytestring
"""
function drophighbits(n::Int, x::T) where {T<:Unsigned}
    (x << n) >> n
end
"Logical shift right n bits"
droplowbits(n::Int, x::T) where {T<:Unsigned} = x >>> n

"""
Given the value of the least significant byte, convert it to 
a type large enough to store bit length
"""
function extract_type(bitlength::Int)
    if bitlength <= 8
        UInt8
    elseif bitlength <=16
        UInt16
    elseif bitlength <=32
        UInt32
    elseif bitlength <=64
        UInt64
    elseif bitlength <=64
        UInt64
    elseif bitlength <=128
        UInt128
    else
        error("Can't work with > 128 bits, bitlength > 114")
    end
end

"""
    extract(bv::Bytevector, bytepos, bitpad, bitlength; bigendian = false) -> UIntXXX

Pull positive integer numbers from compact bit sequences. 
'Bitpad' is the number of bits to ignore at the start of the first byte.
"""
function extract(bv::Bytevector, bytepos, bitpad, bitlength; bigendian = true)
    @assert bitpad < 8  "At bytepos =  $bytepos bitpad = $bitpad is above range 0:7"
    @assert bitpad >=0  "At bytepos =  $bytepos bitpad = $bitpad is below range 0:7"
    # Smallest integer larger than or equal to (bitlength + bitpad) / 8
    bytesourcelength = cld(bitlength + bitpad, 8)
    drop_n_lowbit = bytesourcelength * 8 -bitpad - bitlength
    Extracttype = extract_type(bitlength)
    Temptype = extract_type(bitlength + 14)
    extractwithneighbours = Temptype(0)
    if bytesourcelength > 1
        for i = 0:(bytesourcelength-1)
             # i = 0: pick the least significant byte
            byteno = if bigendian
                    bytepos + i
                else
                    bytepos + bytesourcelength -1 -i
                end
            @assert byteno <= length(bv)  "bytepos =  $bytepos bitpad = $bitpad bitlength = $bitlength bigendian = $bigendian\n\texceeds data length = $(length(bv))"
            thisbyte = bv[byteno]
            extractwithneighbours += Temptype(thisbyte * 2^(i * 8))
        end
        if bigendian
            extractwith_1_neighbour = droplowbits(drop_n_lowbit, extractwithneighbours )            
            extractval = Extracttype(drophighbits(bitpad, extractwith_1_neighbour))
        else
            extractwith_1_neighbour = drophighbits(drop_n_lowbit, extractwithneighbours )                
            extractval = Extracttype(droplowbits(bitpad, extractwith_1_neighbour))
        end
        extractval
    else
        @assert bytepos <= length(bv)  "bytepos =  $bytepos bitpad = $bitpad\n\texceeds $(length(bv))"
        thisbyte = bv[bytepos]
        x = drophighbits(bitpad, thisbyte) 
        UInt8(droplowbits(drop_n_lowbit, x))
    end
end

