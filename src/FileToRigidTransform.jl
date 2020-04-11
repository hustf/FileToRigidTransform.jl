"""
Example:
'''
using FileToRigidTransform; FileToRigidTransform.run()
'''
Follow directions, or update configuration files in ~/.julia_hid/ConfigFo/
"""
module FileToRigidTransform
using FileWatching
const FOLDER = joinpath(homedir(), ".julia_hid")
const CONFIGFO = joinpath(FOLDER, "ConfigFo")
const TRANSFORMFO = joinpath(FOLDER, "TransformFo")
const TIMEOUT = 30.0 # seconds
const RETRY_TIME = 0.5 # seconds
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
        @debug "Could not subtract, vecor lengths, x $(length(x.values)), y $(length(y.values))"
        x
    end
end

"Main, keyword argument timeout in seconds"
function run(timeout = TIMEOUT, func = logit)
    devconfig = devices_configuration_vector()
    monitor(devconfig, timeout, func)
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
    statevec = parse.(Int, strstatevec)
    timestamp = parse(Float64, split(tist, " ", keepempty = false)[1])
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

    ds = devstate(filename)
    t0 = time()
    while ds.values == Int[] && time() - t0 < RETRY_TIME
        # May occur if we are reading before the file is closed for writing. Retry twice before accepting.
        sleep(0.01)
        ds = devstate(filename)
    end
    if time() - t0 >= RETRY_TIME
        @warn "No state read from \n\t$filename \n\tin $RETRY_TIME s. If WinControllerToFile.subscribe() is running, you may have to populate the file by giving input through the device"
    end
    ds
end

"""
Monitor vector of devices. The given function argument is called at every update.
Arguments to func are (ios, d.channeldictionary, dsprev, ds)
"""
function monitor(devconfig, timeout, func)
    # Create file monitors
    monitors = Vector{Task}()
    for d in devconfig
        fina = joinpath(FOLDER, d.filename)
        monitor =  @async monitor_file(fina, d,timeout, func)
        push!(monitors, monitor)
    end
    monitors
end



"""
Monitor a single device. The given function argument is called at every update.
Arguments to func are (ios, d.channeldictionary, dsprev, ds)
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
            func(ios, d.channeldictionary, dsprev, ds)
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

"This is a byte logger, used as the default callback function"
function logit(ios, d::Dict{String,Int}, dsprev, ds)
    dic = Dict{Int, String}(value => key for (key, value) in d)
    Δds = minus_ds(ds, dsprev)
    sv = map((x , y)-> x * y==0 ? "" : string(x) , ds.values, Δds.values)
    str = join(lpad.(sv, 8))
    hv = map(sv, 1:length(sv)) do s, i
        s == "" ? "" : get(dic, i, "NA!")
    end
    strh = join(lpad.(hv, 8))
    println(ios, strh)
    println(stderr, strh)
    println(ios, str)
    println(stderr, str)
end

end # module
