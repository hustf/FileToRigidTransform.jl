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
    bytebynamedict::Dict{String,Int}
end
DevConfig()= DevConfig("", Dict{String, Int}())

"A structure for 'show' dispatching. Could otherwise use Base.CodeUnits <: DenseArray, but we don't need the functionality."
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

"Find device state change"
function minus_ds(x::T, y::T) where {T <: DevState}
    if length(x.values) == length(y.values)
        DevState(x.values.data - y.values.data, x.timestamp - y.timestamp, x.proceed || y.proceed)
    else
        @debug "Could not subtract, vecor lengths, x $(length(x.values.data)), y $(length(y.values.data))"
        x
    end
end

"""
    subscribe(timeout = TIMEOUT, func = logbytewise) -> Vector{Task}

Start reacting to changes in device(s) state as given and updated in files. 
The files which are present in a folder structure defines how the state is interpreted.

Default behaviour is logging the interpreted device state to a file and to screen, see keyword arguments.

Tip: To see error messages from failed tasks, display them individually, e.g. 
    julia> ans[1]
"""
function subscribe(;timeout = TIMEOUT, func = logbytewise)
    devconfvec = devices_configuration_vector()
    monitor(devconfvec, timeout, func)
end


"""
    devices_configuration_vector() -> Vector{DevConfig}

Use folder structure to locate: 
- devices monintored (subscribed), i.e. another process is updating a file with device state
- device configuration, i.e. a text file where the user can describe the conversion from device state to input variables for transformations

If a configuration file is missing, a template file is generated based on the number of bytes in the device state file.

We give warnings when folder structure is missing. Creating folders programmatically might cause difficulties concerning folder ownership.
"""
function devices_configuration_vector()
    dev_conf_vec = Vector{DevConfig}()
    if ispath(FOLDER)
        filenames = filter(isfile, readdir(FOLDER, join=true))
        shortfilenames = filenames .|> splitpath .|> last
        if length(filenames) == 0
            @info "Could not find a *.txt file in $fo .\n\tGenerate one using WinControllerToFile."
        else
            for (fi, shortfi) in zip(filenames, shortfilenames)
                if ispath(CONFIGFO)
                    configfi = joinpath(CONFIGFO, shortfi)
                    if isfile(configfi)
                        # Found both a device state and a device configuration file.
                        chdi = bytebyname(fi, configfi)
                        if length(chdi) > 0
                            devconfig = DevConfig(shortfi, chdi)
                            push!(dev_conf_vec, devconfig)
                            if !ispath(TRANSFORMFO)
                                @warn("Please create folder $TRANSFORMFO, then rerun")
                                return dev_conf_vec
                            end
                        else
                            @warn "Empty device configuration $shortfi"
                        end
                    else
                        @info("Creating template configuration file $configfi")
                        open(configfi, write = true) do ios
                            println(ios, "# This file is read when calling FileToRigidTransformations.run()")
                            println(ios, "# Assign names to byte positions. A channel is one byte. Reserved names for translation:")
                            println(ios, "#Surge1 Surge2 Sway1  Sway2  Heave1 Heave2")
                            println(ios, "# Reserved names for rotation:")
                            println(ios, "#Roll1  Roll2  Pitch1 Pitch2 Yaw1   Yaw2  ")
                            println(ios, " chn1 chn2 chn3 chn4 chn5 chn6 chn7 chn8 chn9 chn10 chn11 chn12 chn13 chn14 chn15 chn16")
                        end
                        @warn "Retry with new device configuration by rerunning FileToRigidTransform.run()"
                        return dev_conf_vec
                    end
                else
                    @warn("Please create folder $CONFIGFO, then rerun")
                    return dev_conf_vec
                end
            end
            @info("Configured $(length(dev_conf_vec)) usb pipelines")
        end
    else
        @info("You need to create folder $fo")
        return dev_conf_vec
    end
    dev_conf_vec
end
"""
    bytebyname(fi, configfi) -> Dict{String, Int}

Make a channel name => byte no. dictionary given two corresponding file names.
"""
function bytebyname(fi, configfi)
    statevec = devstate(fi).values
    strconfigvec = configuration_vector(configfi)
    pairs = (s=>i for (i, s) in enumerate(strconfigvec))
    Dict{String, Int}(pairs)
end

"Read vector of strings from commented text file"
function configuration_vector(filename)
    strconfig = open(filename, read = true) do f
        st = ""
        if !eof(f)
            st = readline(f)
            while !eof(f) && startswith(st, "#") || st == ""
                st = readline(f)
            end
        end
        st
    end
    strip.(split(strconfig, " ", keepempty = false))
end
"Read current state from file"
function devstate(filename)
    st, tist = open(filename, read = true) do f
        st = ""
        tist = ""
        if !eof(f)
            st = readline(f)
            while !eof(f) && startswith(st, "#") || st == ""
                st = readline(f)
            end
        end
        tist = ""
        if !eof(f)
            tist = readline(f)
            while !eof(f) && startswith(tist, "#") || tist == ""
                tist = readline(f)
            end
        end
        st, tist
    end
    if st == "" || tist == ""
        return DevState([], 0, false)
    end
    strstatevec =  split(st, " ", keepempty = false )
    statevec = parse.(UInt8, strstatevec)
    timestamp = parse(Float64, split(tist, " ", keepempty = false)[1])
    DevState(statevec, timestamp, true)
end

"""
    devstate_updated(timeout, filename) -> DevState

Read state from file when file is updated.
If the file is (momentarily) unreadable, retry during RETRY_TIME.
"""
function devstate_updated(timeout, filename)
    prevstate = devstate(filename)
    # Yield to other tasks while waiting for file change
    fileevent = watch_file(filename, timeout)
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
    if localtime() - t0 >= RETRY_TIME + 0.01
        @warn "No state read from \n\t$filename \n\tin $RETRY_TIME s. If WinControllerToFile.subscribe() is running, you may have to populate the file by giving input through the device"
    end
    ds
end

"""
    monitor(devconfvec, timeout, func) -> Vector{Task}

Monitor vector of devices. The 'func' argument is typically used for 
for logging.

Arguments to 'func' are (ios::IOstream, d::DevConfig, dsprev::DevState, ds::DevState)
"""
function monitor(devconfvec, timeout, func)
    # Create file monitors
    monitors = Vector{Task}()
    for d in devconfvec
        fina = joinpath(FOLDER, d.filename)
        monitor =  @async monitor_file(fina, d, timeout, func)
        push!(monitors, monitor)
    end
    monitors
end



"""
Monitor a single device. The given function argument is called at every update.
Arguments to 'func' are (ios::IOstream, d::DevConfig, dsprev::DevState, ds::DevState)
"""
function monitor_file(filename, d::DevConfig, timeout, func)
    _, shfina = splitdir(filename)
    logfile = joinpath(TRANSFORMFO, shfina)
    t0 = localtime()
    open(logfile, write = true) do ios
        ds = DevState()
        dsprev = ds
        tpassed = localtime() - t0
        while true
            tpassed = localtime() - t0
            ds = devstate_updated(timeout-tpassed, filename)
            !dsprev.proceed && break
            func(ios, d, dsprev, ds)
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
