# FileToRigidTransform
This package polls the last recorded state of Usb controllers like spacemice or joysticks. The state is recorded in files by [WinControllerToFile](https://github.com/hustf/WinControllerToFile.jl). The files are updated at state changes, and contain a time stamp.

This package integrates the controller(s) state(s) over time, and updates corresponding states for rigid transforms. You assign controller axes to rotations and translations through configuration files for each controller. 

Rotations are based on quaternions to facilitate screen-aligned rotation axes.

## Installation


## Configuration
![Image of configuration](images/configuration.png)
![Image of bitlogger](images/bitlogger.png)

## Usage

See example/scriptwork.jl 

## TODO
1) Interpretation logger
2) (In configuration, add bit specification and possibly scalers..)
3) Current quaternion logger
4) Current quaternion callback
5) Current transformation logger
6) Current transformation callback