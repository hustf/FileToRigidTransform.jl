"""
Example:
'''
using FileToRigidTransform; FileToRigidTransform.subscribe()
'''
Follow directions, or update configuration files in ~/.julia_hid/ConfigFo/
"""
module FileToRigidTransform
import FileWatching.watch_file
import Base.getindex

const FOLDER = joinpath(homedir(), ".julia_hid")
const CONFIGFO = joinpath(FOLDER, "ConfigFo")
const TRANSFORMFO = joinpath(FOLDER, "TransformFo")
const TIMEOUT = 30.0 # seconds
const RETRY_TIME = 0.5 # seconds
const TIMEZERO = time()

"String descriptors for a device from file name"
struct DevConfig
    filename::String
    specbynamedict::Dict{String, NamedTuple}
end
DevConfig()= DevConfig("", Dict{String, Int}())

"""A structure for 'show' dispatching. Could 
otherwise use Base.CodeUnits <: DenseArray, but we don't 
need the functionality.
"""
struct Bytevector
    data::Vector{UInt8}
end
Bytevector() = Bytevector(UInt8[])
Bytevector(v::Array{Int8,1 }) = Bytevector(Array{UInt8,1}(v))
Base.getindex(bv::Bytevector, i::Int) = getindex(bv.data, i)
Base.length(bv::Bytevector) = length(bv.data)
struct DevState
    values::Bytevector
    timestamp::Float64
    proceed::Bool
end
DevState() = DevState(Bytevector(), localtime(), true)
DevState(v::Array, t, p) = DevState(Bytevector(v), t, p)

include("show_devstate.jl")
include("extract_from_rawdata.jl")
include("loggers.jl")
include("file_operations.jl")



"""
    subscribe(timeout = TIMEOUT, logger = log_by_channel) -> Vector{Task}

Start reacting to changes in device(s) state as given and updated in files. 
The files which are present in a folder structure defines how the state is interpreted.

Default behaviour is logging the interpreted device state to a file and to screen, see keyword arguments.

Tip: To see error messages from failed tasks, display them individually, e.g. 
    julia> ans[1]
"""
function subscribe(;timeout = TIMEOUT, logger = log_by_channel)
    devconfvec = devices_configuration_vector()
    monitor(devconfvec, timeout, logger)
end


"""
    devices_configuration_vector() -> Vector{DevConfig}

Use folder structure to locate: 
- devices monintored (subscribed), i.e. another process is updating a file with device state
- device configuration, i.e. a text file where the user can describe the conversion from device state to input variables for transformations

If a configuration file is missing, a template file is generated based on the number of bytes in the device state file.

Give warnings when folder structure is missing. Creating folders programmatically might cause difficulties concerning folder ownership.
"""
function devices_configuration_vector()
    dev_conf_vec = Vector{DevConfig}()
    if ispath(FOLDER)
        filenames = filter(isfile, readdir(FOLDER, join=true))
        shortfilenames = filenames .|> splitpath .|> last
        if length(filenames) != 0
            for (fi, shortfi) in zip(filenames, shortfilenames)
                if ispath(CONFIGFO)
                    configfi = joinpath(CONFIGFO, shortfi)
                    if isfile(configfi)
                        # Found both a device state and a device configuration file.
                        chdi = specbyname(configfi)
                        if length(chdi) > 0
                            devconfig = DevConfig(shortfi, chdi)
                            push!(dev_conf_vec, devconfig)
                            if !ispath(TRANSFORMFO)
                                @warn("Please create folder $TRANSFORMFO, then rerun")
                                #return dev_conf_vec
                            else
                                @info configfi
                            end
                        else
                            @warn "Empty device configuration $shortfi"
                        end
                    else
                        @info("Creating template configuration file\n\t$configfi")
                        sourcefile = joinpath(@__DIR__, "..", "example", "config_template.txt")
                        @assert isfile(sourcefile) joinpath(pwd(), sourcefile)
                        cp(sourcefile, configfi, force= false)
                        @warn "Retry with new device configuration by rerunning FileToRigidTransform.subscribe()"
                        return dev_conf_vec
                    end
                else
                    @warn("Please create folder $CONFIGFO, then rerun")
                    return dev_conf_vec
                end
            end
            @info("Configured $(length(dev_conf_vec)) usb pipelines")
        else
            @info "Could not find a *.txt file in $fo .\n\tGenerate one using WinControllerToFile."
        end
    else
        @info("You need to create folder $fo")
        return dev_conf_vec
    end
    dev_conf_vec
end



"""
    devstate_updated(timeout, filename) -> DevState

Read state from file when file is updated.
If the file is (momentarily) unreadable, retry during RETRY_TIME.
"""
function devstate_updated(timeout, filename)
    prevstate = devstate(filename)
    # Yield to other tasks while waiting for file change
    fileevent = watch_file(filename, timeout)  # does not exit by itself after timeout actually.
    if fileevent.renamed || fileevent.timedout
        return DevState(prevstate.values, prevstate.timestamp, false)
    end

    ds = devstate(filename)
    t0 = localtime()
    while length(ds.values) == 0 && localtime() - t0 < RETRY_TIME
        # May occur if we are reading before the file is closed for writing. Retry twice before accepting.
        sleep(0.01)
        ds = devstate(filename)
    end
    if localtime() - t0 >= RETRY_TIME + 0.01   ##?
        @warn "No state read from \n\t$filename \n\tin $RETRY_TIME s. If WinControllerToFile.subscribe() is running, you may have to populate the file by giving input through the device"
    end
    ds
end

"""
    monitor(devconfvec, timeout, logger) -> Vector{Task}

Monitor vector of devices. The 'logger' argument is typically used for 
for logging.

Arguments to 'func' are (ios::IOstream, d::DevConfig, dsprev::DevState, ds::DevState)
"""
function monitor(devconfvec, timeout, logger)
    # Create file monitors
    monitors = Vector{Task}()
    for d in devconfvec
        fina = joinpath(FOLDER, d.filename)
        monitor =  @async monitor_file(fina, d, timeout, logger)
        push!(monitors, monitor)
    end
    monitors
end


"""
Monitor a single device. The given function argument is called at every update.
Arguments to 'logger' are (ios::IOstream, d::DevConfig, dsprev::DevState, ds::DevState)
"""
function monitor_file(filename, d::DevConfig, timeout, logger)
    _, shfina = splitdir(filename)
    logfile = joinpath(TRANSFORMFO, shfina)
    t0 = localtime()
    accumulated = Vector{Float64}()
    open(logfile, write = true) do ios
        ds = DevState()
        dsprev = ds
        tpassed = localtime() - t0
        while true
            tpassed = localtime() - t0
            ds = devstate_updated(timeout-tpassed, filename)
            !dsprev.proceed && break
            accumulated = logger(ios, d, accumulated, dsprev, ds)
            dsprev = ds
            if (tpassed > timeout)
                @info "Exit monitor_file due to timeout $timeout s"
                break
            end
            flush(ios)
        end
        ds
    end
    @info "Exit logging to \n\t$logfile \n\tafter $(floor(localtime()-t0)) s"
end

localtime() = time() - TIMEZERO






end # module
