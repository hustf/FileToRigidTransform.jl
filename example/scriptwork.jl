# Run this in another process:
#using WinControllerToFile;WinControllerToFile.subscribe()
using FileToRigidTransform
FileToRigidTransform.subscribe(func=FileToRigidTransform.logbitwise, timeout = 5)
sleep(90)

FileToRigidTransform.subscribe()



import FileToRigidTransform.Bytevector
import FileToRigidTransform.DevState
v = UInt8[0,127, 255]
bv = Bytevector(v)
sv = String(v)
cu = codeunits(sv)


drophighbits(1, UInt8(255))