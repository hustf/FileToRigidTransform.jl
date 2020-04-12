using FileToRigidTransform
using Test

@testset "FileToRigidTransform.jl" begin
    import FileToRigidTransform.Bytevector
    import FileToRigidTransform.DevState
    ds = DevState([1,2,3],time(),true)
    dsprev = DevState([2,4,6],time(),true)
    import FileToRigidTransform.DevConfig
    devconf = DevConfig()
    ios = IOBuffer()
    import FileToRigidTransform.logbitwise
    ds = DevState([1,2,3],time(),true)
    dsprev = DevState([2,4,6],time(),true)
    logbitwise(ios, devconf, dsprev, ds)
    dsprev = DevState([1,2,3],time(),true)
    logbitwise(ios, devconf, dsprev, ds)
    dsprev = DevState([],time(),true)
    logbitwise(ios, devconf, dsprev, ds)
    
end
