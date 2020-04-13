using FileToRigidTransform

using Test
@testset "FileToRigidTransform.jl" begin
    import FileToRigidTransform: Bytevector, DevState
    ds = DevState([1,2,3],time(),true)
    dsprev = DevState([2,4,6],time(),true)
    import FileToRigidTransform.DevConfig
    devconf = DevConfig()
    ios = IOBuffer()
    import FileToRigidTransform: logbitwise, logbytewise
    ds = DevState([1,2,3],time(),true)
    dsprev = DevState([2,4,6],time(),true)
    logbitwise(ios, devconf, dsprev, ds)
    dsprev = DevState([1,2,3],time(),true)
    logbitwise(ios, devconf, dsprev, ds)
    dsprev = DevState([],time(),true)
    logbitwise(ios, devconf, dsprev, ds)
end
using Test
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
@testset "extract" begin
    import FileToRigidTransform: Bytevector
    v = [0,127, 255]
    bv = Bytevector(v)
    bv[2]
end
