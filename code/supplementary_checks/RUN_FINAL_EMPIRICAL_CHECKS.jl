# FINANCIAL PESSIMISM -- supplementary empirical checks, v1.0
# Place this folder at:
# C:\path\to\Financial_Pessimism\05_Supplementary_Analyses\Final_Empirical_Checks
# In a Julia REPL run:
# include(raw"C:\path\to\Financial_Pessimism\05_Supplementary_Analyses\Final_Empirical_Checks\RUN_FINAL_EMPIRICAL_CHECKS.jl")
#
# Read-only: frozen estimates, source files, raw UKDS TABs, respondent-level CSVs.
# Only new aggregate results are written to a NEW Dropbox subfolder.
# No Julia packages required: the estimator is the already-verified R/fixest design.

module FinancialPessimismFinalChecks
using Dates

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const RSOURCE = joinpath(@__DIR__, "FINAL_EMPIRICAL_CHECKS.R")

function find_rscript()
    configured = get(ENV, "FP_RSCRIPT", "")
    if !isempty(configured)
        return configured
    end
    found = Sys.which("Rscript")
    found !== nothing && return String(found)
    home = homedir()
    candidates = [
        joinpath(home, "AppData", "Local", "Programs", "R", "R-4.6.1", "bin", "x64", "Rscript.exe"),
        joinpath(home, "AppData", "Local", "Programs", "R", "R-4.6.1", "bin", "Rscript.exe"),
        raw"C:\Program Files\R\R-4.6.1\bin\Rscript.exe"
    ]
    for file in candidates
        isfile(file) && return file
    end
    return ""
end

function main()
    println(repeat("=", 100))
    println("FINANCIAL PESSIMISM -- FINAL EMPIRICAL CHECKS")
    println("Project: ", PROJECT_ROOT)
    println("Read-only canonical samples and licensed data; aggregate outputs only to Dropbox")
    println(repeat("=", 100))
    isfile(RSOURCE) || error("Missing companion source: " * RSOURCE)
    rscript = find_rscript()
    if isempty(rscript) || !isfile(rscript)
        println("Rscript not found. Set ENV[\"FP_RSCRIPT\"] to the full path to Rscript.exe.")
        return nothing
    end
    tag = get(ENV, "FP_FINAL_CHECKS_TAG", Dates.format(now(), "yyyymmdd_HHMMSS"))
    occursin(r"^[A-Za-z0-9_-]+$", tag) || error("Invalid FP_FINAL_CHECKS_TAG")
    canonical_tag = get(ENV, "FP_CANONICAL_REPLAY_TAG", "20261016_140555")
    occursin(r"^[A-Za-z0-9_-]+$", canonical_tag) || error("Invalid FP_CANONICAL_REPLAY_TAG")
    localroot = get(ENV, "FP_UK_DERIVED", raw"C:\Hansak\Data\UKHLS_derived")
    println("R executable: ", rscript)
    println("Canonical replay: ", canonical_tag)
    println("Local licensed-data directory: ", localroot)
    println("Run tag: ", tag)
    if get(ENV, "FP_FINAL_CHECKS_SKIP_SYNTHETIC", "no") != "yes"
        smoke = joinpath(@__DIR__, "SELFTEST_FINAL_CHECKS.R")
        isfile(smoke) || error("Missing synthetic smoke test: " * smoke)
        println("[0] R/fixest synthetic smoke check (no licensed data)")
        smokeproc = run(ignorestatus(`$rscript --vanilla $smoke`))
        if !success(smokeproc)
            println("Synthetic estimator check FAILED; empirical analysis was NOT started.")
            return nothing
        end
        println("[0] Synthetic smoke check PASS")
    end
    cmd = addenv(`$rscript --vanilla $RSOURCE`,
        "FP_PROJECT_ROOT" => PROJECT_ROOT,
        "FP_FINAL_CHECKS_DIR" => @__DIR__,
        "FP_FINAL_CHECKS_TAG" => tag,
        "FP_CANONICAL_REPLAY_TAG" => canonical_tag,
        "FP_UK_DERIVED" => localroot)
    proc = run(ignorestatus(cmd))
    out = joinpath(PROJECT_ROOT,"05_Supplementary_Analyses", "Final_Empirical_Checks", "Results_" * tag)
    println("\n", repeat("=",100))
    println("Aggregate diagnostics: ", out)
    if success(proc)
        println("RUN COMPLETE. Review FINAL_CHECKS_REPORT.md and STAGE_STATUS.csv.")
    else
        println("Some checks did not pass or did not run (R exit ", proc.exitcode, ").")
        println("Inspect STAGE_STATUS.csv and console errors. Any successful stages remain available.")
    end
    nothing
end
end

Base.invokelatest(FinancialPessimismFinalChecks.main)
