# Read-only canonical replay of Codex's FINAL preferred BHPS / UKHLS regressions.
# Run from the NEW Financial_Pessimism project (source path kept in code):
#     include("RUN_PESSIMISM_CANONICAL_REPLAY.jl")
# All respondent-level files and unzipped code live under C:\Hansak\Data.
# Only aggregate CSV/MD verification outputs go to Dropbox.

module PessimismCanonicalReplay
using Dates

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const DATA_ROOT = get(ENV, "FP_UK_DERIVED", raw"C:\Hansak\Data\UKHLS_derived")
const CODEX_ZIP = joinpath(PROJECT_ROOT, "02_Canonical_Replication",
    "Original_Codex", "canonical_original_20261016.zip")
const HELPER = joinpath(PROJECT_ROOT, "02_Canonical_Replication",
    "Replay_Launcher_Original", "pessimism_canonical_replay_v1",
    "verify_canonical_headline.py")

function check_local_path(path::String)
    norm = lowercase(replace(abspath(path), '\\' => '/'))
    parts = split(norm, '/')
    if any(x -> x in ("dropbox", "onedrive", "google drive", "google_drive"), parts)
        error("REFUSING to store private respondent-level data in cloud-synced path: " * path)
    end
end

function python_commands()
    result = Vector{Vector{String}}()
    configured = get(ENV, "FP_PYTHON", "")
    if !isempty(configured)
        push!(result, [configured])
    end
    for name in ("py", "python", "python3")
        exe = Sys.which(name)
        if exe !== nothing
            if name == "py"
                push!(result, [exe, "-3"])
            else
                push!(result, [exe])
            end
        end
    end
    unique(result)
end

function python_ready(args::Vector{String})
    cmd = Cmd(vcat(args, ["-c", "import sys, pandas, numpy; assert sys.version_info >= (3, 9)"]))
    try
        return success(pipeline(cmd, stdout=devnull, stderr=devnull))
    catch
        return false
    end
end

function select_python()
    for args in python_commands()
        if python_ready(args)
            println("Python executable: ", join(args, " "))
            return args
        end
    end
    println("\nPython with pandas and NumPy was not found.")
    println("You do not need to rerun the R audit. The canonical source is in Python.")
    println("If Python is installed, point to it from Julia, for example:")
    println("  ENV[\"FP_PYTHON\"] = raw\"C:\\path\\to\\python.exe\"")
    println("If Python is installed but lacks packages, use the Python executable to install pandas and numpy.")
    println("Then execute: include(\"RUN_PESSIMISM_CANONICAL_REPLAY.jl\")")
    return nothing
end

function require_inputs()
    require_file(p, msg) = isfile(p) || error("Missing " * msg * ": " * p)
    require_file(CODEX_ZIP, "Codex final analysis ZIP")
    require_file(HELPER, "new verification helper script")
    require_file(joinpath(DATA_ROOT, "bhps_ukhls_cohort_long_raw.csv"), "original cohort extract")
    raw_root = joinpath(dirname(DATA_ROOT), "UKDA-6614-tab")
    require_file(joinpath(raw_root, "tab", "bhps", "ba_indresp.tab"), "BHPS raw data")
    require_file(joinpath(raw_root, "tab", "ukhls", "a_indresp.tab"), "UKHLS raw data")
    require_file(joinpath(raw_root, "mrdoc", "ukda_data_dictionaries.zip"), "UKDS data dictionary")
end

function run_step(label::String, args::Vector{String}, extra::Vector{String}=String[];
                  envvars=Pair{String,String}[])
    println("\n", repeat("=", 88))
    println(label)
    println(repeat("=", 88))
    cmd = Cmd(vcat(args, extra))
    isempty(envvars) || (cmd = addenv(cmd, envvars...))
    process = run(ignorestatus(cmd))
    ok = success(process)
    if !ok
        println("FAILED: ", label, " (process exit code ", process.exitcode, ")")
    end
    return ok
end

function statusfile(path, stages)
    open(path, "w") do io
        println(io, "stage,status")
        for (name, ok) in stages
            println(io, name, ",", ok ? "PASS" : "FAILED")
        end
    end
end

function main()
    println("FINANCIAL PESSIMISM | CANONICAL CODE REPLAY")
    println("The archived Codex source and results are never overwritten.")
    println("Original ZIP: ", CODEX_ZIP)
    println("Project root: ", PROJECT_ROOT)
    check_local_path(DATA_ROOT)
    if !isfile(CODEX_ZIP)
        println("Codex ZIP missing; verify Dropbox has synchronized it to this PC.")
        return nothing
    end
    if !isfile(HELPER)
        println("Verification helper missing; extract the supplied package into the project root.")
        return nothing
    end
    py = select_python()
    py === nothing && return nothing
    require_inputs()
    tag = get(ENV, "FP_CANONICAL_REPLAY_TAG", Dates.format(now(), "yyyymmdd_HHMMSS"))
    occursin(r"^[A-Za-z0-9_-]+$", tag) || error("Unsafe FP_CANONICAL_REPLAY_TAG")
    local_dir = joinpath(DATA_ROOT, "pessimism_canonical_replay_v1", tag)
    public_dir = joinpath(PROJECT_ROOT, "04_Verified_Results", "Canonical_Python_" * tag)
    check_local_path(local_dir)
    mkpath(local_dir)
    mkpath(public_dir)
    stage = Pair{String,Bool}[]

    println("\nPRIVATE work directory: ", local_dir)
    println("AGGREGATE results: ", public_dir)
    ok = run_step("[1/5] Extract ORIGINAL Codex archive into PRIVATE local directory", py,
                  ["-m", "zipfile", "-e", CODEX_ZIP, local_dir])
    push!(stage, "extract_original_zip"=>ok)
    if !ok
        statusfile(joinpath(public_dir,"CANONICAL_STAGE_STATUS.csv"),stage)
        return nothing
    end
    check_dir = joinpath(local_dir, "analysis", "checks")
    if !isfile(joinpath(check_dir,"check_stats.py")) ||
       !isfile(joinpath(local_dir,"analysis","prepare_pilot.py"))
        error("Archive contents do not match Codex source structure; stop without running")
    end

    # This helper is an ADDITIONAL script, never a modification to the original code.
    cp(HELPER,joinpath(check_dir,"verify_canonical_headline.py"),force=true)
    commands = [
      ("[2/5] Build canonical individual panel", joinpath(local_dir,"analysis","prepare_pilot.py")),
      ("[3/5] Load household controls, endpoint weights and PSU/strata IDs", joinpath(check_dir,"prepare_checks.py")),
      ("[4/5] Apply complete-household-roster equivalence scales", joinpath(check_dir,"complete_equivalence.py")),
      ("[5/5] Replay ONLY headline models; compare exact original estimates", joinpath(check_dir,"verify_canonical_headline.py")),
    ]
    for (label, script) in commands
        ok = run_step(label,py,[script],envvars=[
          "FP_CANONICAL_PUBLIC_OUT"=>public_dir,
          "FP_CANONICAL_LOCAL_SAMPLES"=>joinpath(local_dir,"private_model_ready_samples")
        ])
        push!(stage, basename(script)=>ok)
        if !ok
            statusfile(joinpath(public_dir,"CANONICAL_STAGE_STATUS.csv"),stage)
            println("\nCanonical replay stopped at: ",basename(script))
            println("Send the console output or aggregate stage status; no source data were uploaded.")
            return nothing
        end
    end
    statusfile(joinpath(public_dir,"CANONICAL_STAGE_STATUS.csv"),stage)
    println("\nCANONICAL STAGES COMPLETE")
    println("Check: ",joinpath(public_dir,"CANONICAL_REPLAY_REPORT.md"))
    println("Local canonical samples saved for follow-up independent R check.")
end

end # module

Base.invokelatest(PessimismCanonicalReplay.main)
