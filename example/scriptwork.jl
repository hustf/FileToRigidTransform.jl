# Run this in another process:
#using WinControllerToFile;WinControllerToFile.subscribe()
using FileToRigidTransform
FileToRigidTransform.subscribe(logger= FileToRigidTransform.log_by_channel, timeout = 150)



#FileToRigidTransform.subscribe(timeout = 5)



#import FileToRigidTransform.Bytevector
#import FileToRigidTransform.DevState
#v = UInt8[0,127, 255]
#bv = Bytevector(v)
#sv = String(v)
#cu = codeunits(sv)


#drophighbits(1, UInt8(255))