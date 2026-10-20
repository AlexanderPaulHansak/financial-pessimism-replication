# A single reporting-only extraction from the FROZEN canonical BHPS model-ready CSV.
# Run from the main predecessor modeling project project root.
module BHPSCanonicalOptimismReporting
using Dates
root = normpath(joinpath(@__DIR__, "..", "..", ".."))
script = joinpath(@__DIR__, "EXPORT_OPTIMISM_PORTABLE.R")
rbin = get(ENV, "FP_RSCRIPT", raw"C:\Users\hansakal\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe")
if !isfile(rbin)
    cmd = Sys.which("Rscript")
    cmd === nothing && error("Set ENV[\"FP_RSCRIPT\"] to your Rscript.exe path")
    rbin = cmd
end
isfile(script) || error("Extract submission_reporting_tools into the project root: "*script)
get(ENV,"FP_CANONICAL_REPLAY_TAG","")=="" && (ENV["FP_CANONICAL_REPLAY_TAG"]="20261016_140555")
ENV["FP_PROJECT_ROOT"] = root
println("Exporting canonical BHPS optimism coefficients (no sample rebuilding)")
run(`$rbin $script`)
end
