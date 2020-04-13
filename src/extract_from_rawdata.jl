"""
    drophighbits(n, x::UInt8) -> UInt8
### Examples
    julia> drophighbits(0, 0b11111111)
    255

    julia> drophighbits(1, 0b11111111) |> FileToRigidTransform.bytestring
"""
function drophighbits(n::Int, x::UInt8)
    bitmask = 8:-1:(9 - n)
    mask = UInt8(sum(2^(bitno -1) for bitno in bitmask))
    UInt8(x & ~mask)
end
"Logical shift right n bits"
droplowbits(n::Int, x::T) where {T<:Unsigned} = x >>> n

"""
Given the value of the least significant byte, convert it to 
a type large enough to store bit length
"""
function convert_to_extracted_type(bitlength, lowbyte::UInt8)
    if bitlength <= 8
        UInt8(lowbyte)
    elseif bitlength <=16
        UInt16(lowbyte)
    elseif bitlength <=32
        UInt32(lowbyte)
    elseif bitlength <=64
        UInt64(lowbyte)
    elseif bitlength <=64
        UInt64(lowbyte)
    elseif bitlength <=128
        UInt128(lowbyte)
    else
        error("Can't extract bitlength > 128, modify configuration!")
    end
end

function exctract(bv::Bytevector, bytestartno, bitpad, bitlength, bigendian = true)
    firstbyte = drophighbits(bitpad, bv[bytestartno])
    # Smallest integer larger than or equal to (bitlength + bitpad) / 8
    bytesourcelength = cld(bitlength + bitpad, 8)
    dropbitsfromlastbyte = bytesourcelength * 8 - bitlength
    # move the type assignment to separate function...
    if bytesourcelength > 1
        if bigendian
            lastbyteindex = byteno + bytelength - 1
            lastbyte = droplowbits(dropbitsfromlastbyte, bv[lastbyteindex])
            # Deal with the last byte first, i.e. assume big-endian (unlikely)
            convert_to_extracted_type(lastbyte)
             # TO DO!! multiply by 255 and iterate, 
        else
            # TO DO!!
        for i = 2:(bytelength - 2)
        end
    else
        return UInt8(droplowbits(dropbitsfromlastbyte, firstbyte))
    end

end