using FileToRigidTransform

using Test
@testset "Configuration" begin
    import FileToRigidTransform: specbyname, 
                                read_dlm_line_after, 
                                DevConfig,
                                devices_configuration_vector
    configfi = joinpath(@__DIR__, "..", "example", "config_template.txt")
    if !isfile(configfi)
        configfi = joinpath(@__DIR__, "example", "config_template.txt")
    end
    reserved = Set(["Surge", "Sway", "Heave", "Roll", "Pitch", "Yaw"])
    defined, lp = read_dlm_line_after(configfi)
    @test lp == 626
    @test intersect(reserved, defined) == reserved
    nextline, lastpos = read_dlm_line_after(configfi, startpos = lp)
    @test nextline ==  ["2", "4", "6", "8", "10", "12", "1", "1"]
    spec = specbyname(configfi)
    @test length(spec) == 8
    @test typeof(DevConfig("template", spec)) <: DevConfig
    # test would only work after configuration:
    #@test typeof(devices_configuration_vector()) <: Vector{DevConfig}
end
@testset "Interactive tests of show methods and loggers" begin
    import FileToRigidTransform: Bytevector, DevState
    ds = DevState([1,2,3],time(),true)
    dsprev = DevState([2,4,6],time(),true)
    import FileToRigidTransform.DevConfig
    devconf = DevConfig()
    accumulated = Vector{Int64}()
    ios = IOBuffer()
    import FileToRigidTransform: log_by_channel,
                                 log_by_bit,
                                 log_by_bit_accumulate_changes,
                                 minus_ds, specbyname, extract
    # Empty device configuration
    ds = DevState([1,2,3],time(),true)
    dsprev = DevState([2,4,6],time(),true)

    log_by_bit(ios, devconf, accumulated, dsprev, ds)
    @test_throws AssertionError log_by_channel(ios, devconf, accumulated, dsprev, ds)
    log_by_bit_accumulate_changes(ios, devconf, accumulated, dsprev, ds);

    # Template device configuration
    configfi = begin
        configfi = joinpath(@__DIR__, "..", "example", "config_template.txt")
        if !isfile(configfi)
            configfi = joinpath(@__DIR__, "example", "config_template.txt")
        end
        configfi
    end
    devconf = DevConfig("template", specbyname(configfi))
    ds = DevState(collect(1:13),time(),true)
    dsprev = DevState(collect(2:14),time(),true)
    log_by_bit(ios, devconf,  accumulated, dsprev, ds)
    log_by_channel(ios, devconf,  accumulated, dsprev, ds)
    log_by_bit_accumulate_changes(ios, devconf, accumulated, dsprev, ds);
    dsprev = DevState([],time(),true)
    log_by_bit(ios, devconf, accumulated, dsprev, ds)
    log_by_channel(ios, devconf, accumulated, dsprev, ds)
    log_by_bit_accumulate_changes(ios, devconf, accumulated, dsprev, ds)
end
using Test, FileToRigidTransform
@testset "bits manipulation" begin
    import FileToRigidTransform: drophighbits, bytestring, droplowbits
    @test bytestring(0b1100) == "0000 1100"
    @test drophighbits(7,0b11) == 1
    @test drophighbits(7,0b10) == 0
    @test drophighbits(5,0b1111) == 0b111
    @test drophighbits(5,0b1111) |> bytestring == "0000 0111"
    @test drophighbits(5,0b0100) |> bytestring == "0000 0100"
    droplowbits(1, UInt8(16)) == 8
    droplowbits(8, UInt8(255)) == 0
    droplowbits(1, UInt128(5)) == 2
end
using Test, FileToRigidTransform
@testset "Extract 1 byte or less from within one byte" begin
    import FileToRigidTransform: Bytevector, extract_type,
                                 extract, bytestring,
                                 droplowbits, drophighbits,
                                 bitlength_ceiling
    v = [0, 127, 255]
    bv = Bytevector(v)
    bytepos = 1
    bitpad = 0
    bitlength = 8
    bigendian = true
    @test extract(bv, bytepos, bitpad, bitlength, bigendian = bigendian) == 0
    bytepos = 2
    @test extract(bv, bytepos, bitpad, bitlength, bigendian = bigendian) == 127
    bytepos = 3
    @test extract(bv, bytepos, bitpad, bitlength, bigendian = bigendian) == 255
    bitpad = 1; bitlength = 7
    @test extract(bv, bytepos, bitpad, bitlength, bigendian = bigendian) == 127
    bitpad = 2; bitlength = 6
    @test extract(bv, bytepos, bitpad, bitlength, bigendian = bigendian) == 63
    bytepos = 2
    bitpad = 1
    bitlength = 7
    @test extract(bv, bytepos, 1, 7) == 127
    @test extract(bv, bytepos, 1, 6) == 63
    bitpad = 2; bitlength = 6
    @test extract(bv, bytepos, bitpad, bitlength) == 63
end

@testset "Extract 1 byte or less, crossing two source bytes" begin
    import FileToRigidTransform: Bytevector, extract_type,
                                 extract, bytestring,
                                 droplowbits, drophighbits,
                                 bitlength_ceiling
    v = [1, 192]
    bv = Bytevector(v)
    bytepos = 1
    bitpad = 7
    bitlength = 3
    bigendian = true
    @test extract(bv, bytepos, bitpad, bitlength, bigendian = bigendian) == 0b111
    bigendian = false
    @test extract(bv, bytepos, bitpad, bitlength, bigendian = bigendian) == 0b111
    v = [255, 255]
    bv = Bytevector(v)
    bigendian = true
    @test extract(bv, bytepos, bitpad, bitlength, bigendian = bigendian) == 0b111
    bigendian = false
    @test extract(bv, bytepos, bitpad, bitlength, bigendian = bigendian) == 0b111
    v = [0, 255, 0, 255]
    bv = Bytevector(v)
    bytepos = 1
    bitpad = 7
    bitlength = 11
    bigendian = true
    @test extract(bv, bytepos, bitpad, bitlength, bigendian = bigendian) == 0b00111111110
    bigendian = false
    @test extract(bv, bytepos, bitpad, bitlength, bigendian = bigendian) == 0b01111111100
end



















using Test
@testset "extract more than 1 byte or less" begin
    import FileToRigidTransform: Bytevector, extract_type,
        extract, bytestring,
        droplowbits, drophighbits
    v = [255, 255, 255]
    bv = Bytevector(v)
    bytepos = 1; bitpad = 0; bitlength = 16;     bigendian = true
    @test extract(bv, bytepos, bitpad, bitlength, bigendian=bigendian) == 0b1111111111111111
    bigendian = false
    @test extract(bv, bytepos, bitpad, bitlength, bigendian=bigendian) == 0b1111111111111111
    bytepos = 1; bitpad = 1; bitlength = 16;     bigendian = true
    @test extract(bv, bytepos, bitpad, bitlength, bigendian=bigendian) == 0b1111111111111111
end
