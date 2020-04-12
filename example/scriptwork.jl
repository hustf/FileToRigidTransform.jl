# Run this in another process:
#using WinControllerToFile;WinControllerToFile.subscribe()
using FileToRigidTransform
FileToRigidTransform.subscribe(func=FileToRigidTransform.logbitwise, timeout = 80)
sleep(90)
FileToRigidTransform.subscribe()


