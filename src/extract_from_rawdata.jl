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
droplowbits(n::Int, x::T) where {T<:Unsigned} = (x >>> n)




function bitlength_ceiling(bitlength::Int)
    if bitlength <= 8
        8
    elseif bitlength <=16
        16
    elseif bitlength <=32
        32
    elseif bitlength <=64
        64
    elseif bitlength <=128
        128
    else
        error("Can't work with > 128 bits, bitlength > 114")
    end
end


function extract_type(bitlength::Int)
    if bitlength == 8
        UInt8
    elseif bitlength == 16
        UInt16
    elseif bitlength == 32
        UInt32
    elseif bitlength == 64
        UInt64
    elseif bitlength == 128
        UInt128
    else
        error("No unsigned type with $bitlength bits")
    end
end


"""
    extract(bv::Bytevector, bytepos, bitpad, bitlength; bigendian = false) -> UIntXXX

Pull positive integer numbers from compact bit sequences. 
'Bitpad' is the number of bits to ignore at the start of the first byte.
"""
function extract(bv::Bytevector, bytepos, bitpad, bitlength; bigendian = true)
    @assert bitpad < 8  "At bytepos =  $bytepos bitpad = $bitpad bitlength = $bitlength is above range 0:7"
    @assert bitpad >= 0  "At bytepos =  $bytepos bitpad = $bitpad bitlength = $bitlength is below range 0:7"
    @assert bytepos >= 1  "At bytepos =  $bytepos bitpad = $bitpad bitlength = $bitlength, bytepos is below range 1:$length(bv)"
    @assert bytepos <= length(bv)  "At bytepos =  $bytepos bitpad = $bitpad bitlength = $bitlength, bytepos is above range 1:$length(bv)"
    @assert (bytepos - 1) * 8 + bitpad + bitlength <= length(bv) * 8  "At bytepos =  $bytepos bitpad = $bitpad bitlength = $bitlength: Can't read beyond byte $(length(bv))"
    # Smallest integer larger than or equal to (bitlength + bitpad) / 8
    bytesourcelength = cld(bitlength + bitpad, 8)
    if bytesourcelength > 1
        extractbitlength = bitlength_ceiling(bitlength)
        Extracttype = extract_type(extractbitlength)
        tempminbitlength = bitlength + 14
        tempbitlength = bitlength_ceiling(tempminbitlength)
        Temptype = extract_type(tempbitlength)
        extractwithneighbours = Temptype(0)
        drop_low_bits_from_lastbyte = bytesourcelength * 8 - bitpad - bitlength
        for i = 0:(bytesourcelength-1)
             # i = 0: pick the least significant byte
            byteno = if bigendian
                    bytepos + i
                else
                    bytepos + bytesourcelength -1 -i
                end
            thisbyte = bv[byteno]
            # If this byte is at one of the ends of extracted data, set the inconsequential bits to zero
            maskedbyte = if byteno == bytepos
                if bigendian
                    thisbyte << bitpad
                else
                    (thisbyte << bitpad ) >>> bitpad
                end
            elseif byteno == bytepos + bytesourcelength - 1
                if bigendian
                    thisbyte >>> drop_low_bits_from_lastbyte
                else
                    thisbyte >>> drop_low_bits_from_lastbyte << drop_low_bits_from_lastbyte
                end
            else
                thisbyte
            end
            extractwithneighbours += Temptype(maskedbyte * 2^(i * 8))
        end
        extract_no_lowbit_neighbours = if bigendian
            extractwithneighbours >> bitpad
        else
            extractwithneighbours >> drop_low_bits_from_lastbyte
        end
        Extracttype(extract_no_lowbit_neighbours)
    else
        @assert bytepos <= length(bv)  "bytepos =  $bytepos bitpad = $bitpad\n\texceeds $(length(bv))"
        thisbyte = bv[bytepos]
        x = drophighbits(bitpad, thisbyte)
        drop_n_lowbit = 8 - bitpad - bitlength
        @assert drop_n_lowbit >= 0  "Invalid drop_n_lowbit.... bytepos =  $bytepos bitpad = $bitpad bitlength = $bitlength"
        UInt8(droplowbits(drop_n_lowbit, x))
    end
end

