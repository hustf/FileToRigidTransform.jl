using WinControllerToFile
WinControllerToFile.subscribe()
# TODO check for existing subscriptions
using FileToRigidTransform
tsk = FileToRigidTransform.run()[1]
