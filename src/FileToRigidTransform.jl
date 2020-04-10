"""
Example:
'''
using FileToRigidTransform; FileToRigidTransform.run()
'''
Follow directions, or update configuration files in ~/.julia_hid/ConfigFo/
"""
module FileToRigidTransform
using Base, FileWatching
const FOLDER = joinpath(homedir(), ".julia_hid")
const CONFIGFO = joinpath(FOLDER, "ConfigFo")
const TRANSFORMFO = joinpath(FOLDER, "TransformFo")
const TIMEOUT = 30 # seconds
const TIMEZERO = time()
"String descriptors for a device from file name"
struct DevConfig
    filename::String
    channeldictionary::Dict{String,Int}
end
DevConfig()= DevConfig("", Dict{String, Int}())

struct DevState
    values::Vector{Int}
    timestamp::Float64
    proceed::Bool
end
DevState() = DevState(Vector{Int}(), localtime(), true)

function minus_ds(x::T, y::T) where T <: DevState
    if length(x.values) == length(y.values)
        DevState(x.values - y.values, x.timestamp - y.timestamp, x.proceed || y.proceed)
    else
        @warn "Could not subtract, vecor lengths, x $(length(x.values)), y $(length(y.values))"
        DevState()
    end
end
function run()
    devconfig = devices_configuration_vector()
    monitor(devconfig)
end

function monitor(devconfig)
    # Create file monitors
    monitors = Vector{Task}()
    for d in devconfig
        fina = joinpath(FOLDER, d.filename)
        monitor =  @async monitor_file(fina)
        push!(monitors, monitor)
    end
    monitors
end

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
                        chdi = channeldict(fi, configfi)
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
                        open(configfi, write = true) do f
                            println(f, "# This file is read when calling FileToRigidTransformations.run()")
                            println(f, "# Assign names to axes. ")
                            println(f, "# Reserved for rigid transformations: ")
                            println(f, "#     Surge, Sway, Heave, Roll, Pitch, Yaw")
                            println(f, "[Surge, Sway, Heave, Roll, Pitch, Yaw, But1, But2, But3, But4]")
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
"Make a channel name => channel no. dictionary from files.
Also checks that state and configuration files have the same number of elements"
function channeldict(fi, configfi)
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
    strip.(split(strconfig[2:findfirst(']', strconfig) - 1], ","))
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
    @assert st !="" "No state read from $filename \n\t - If WinControllerToFile.subscribe() is running, you may have to give input through the device"
    @assert tist !="" "No time stamp read from $filename"
    strstatevec =  split(st[2:findfirst(']', st) - 1], ",")
    statevec = parse.(Int, strstatevec)
    timestamp = parse(Float64, split(tist, " ")[1])
    DevState(statevec, timestamp, true)
end

"Read state from file when file is updated."
function devstate_updated(timeout, filename)
    prevstate = devstate(filename)
    # Yield to other tasks while waiting for file change
    fileevent = watch_file(filename, timeout)
    if fileevent.renamed || fileevent.timedout
        return DevState(prevstate.values, prevstate.timestamp, false)
    end
    devstate(filename)
end

function monitor_file(filename)
    _, shfina = splitdir(filename)
    logfile = joinpath(TRANSFORMFO, shfina)
    t0 = localtime()
    open(logfile, write = true) do f
        ds = DevState()
        dsprev = ds
        tpassed = localtime() - t0
        while true
            tpassed = localtime() - t0
            ds = devstate_updated(TIMEOUT-tpassed, filename)
            logit(f, dsprev, ds)
            dsprev = ds
            !dsprev.proceed && break
            if (tpassed > TIMEOUT)
                @info "Exit monitor_file due to timeout"
                break
            end
            flush(f)
        end
        ds
    end
    @info "Exit logging to $logfile after $(floor(localtime()-t0))"
end
localtime() = time() - TIMEZERO
function logit(f, dsprev, ds)
    Δds = minus_ds(ds, dsprev)
    if length(Δds.values) > 0
        # Log channels with change
        for (i, Δx, x) in zip(1:length(ds.values), Δds.values, ds.values)
            if Δx != 0
                if i == 10 #∉ (2, 4, 6, 8, 10, 12)
                    print(f, i, " => ", x, " \t")
                    print(stderr, i, " => ", x, " \t")
                end
            end
        end
        print(f, "\n")
        print(stderr, "\n")
    end
end
end # module
