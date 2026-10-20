module BHPSUKHLSCohortInventory

using CSV
using DataFrames

const ROOT =
    raw"C:\Hansak\Data\UKDA-6614-tab\tab"

const PROJECT_ROOT =
    normpath(joinpath(@__DIR__, "..", ".."))

const OUTDIR =
    joinpath(PROJECT_ROOT, "output", "empirics", "ukhls")

# ==============================================================================
# Helpers
# ==============================================================================

function tab_header(path)
    open(path, "r") do io
        String.(split(chomp(readline(io)), '\t'))
    end
end

function firstmatch(vars, patterns)
    for p in patterns
        hit = findfirst(v -> occursin(p, lowercase(v)), vars)
        hit !== nothing && return vars[hit]
    end
    return ""
end

function exactvar(vars, prefix, suffix)
    v = "$(prefix)_$(suffix)"
    return v in vars ? v : ""
end

function listmatches(vars, patterns; maxn=5)
    hits = filter(vars) do v
        s = lowercase(v)
        any(p -> occursin(p, s), patterns)
    end

    isempty(hits) && return ""

    return join(hits[1:min(end, maxn)], "; ")
end

# BHPS: ba ... br = waves 1 ... 18
function bhps_wave(prefix)
    @assert length(prefix) == 2
    return Int(prefix[2] - 'a') + 1
end

# UKHLS: a ... o = waves 1 ... 15
function ukhls_wave(prefix)
    @assert length(prefix) == 1
    return Int(prefix[1] - 'a') + 1
end

# ==============================================================================
# Inspect one indresp file
# ==============================================================================

function inspect_file(source, path)

    file = basename(path)
    prefix = split(file, "_")[1]

    vars = tab_header(path)

    wave =
        source == "BHPS" ?
        bhps_wave(prefix) :
        ukhls_wave(prefix)

    # Nominal survey timing only for orientation.
    # We will use the actual interview-year variable in the real extract.
    nominal_start =
        source == "BHPS" ?
        1990 + wave :
        2008 + wave

    return (
        source = source,
        wave = wave,
        prefix = prefix,
        nominal_start = nominal_start,
        file = file,
        nvars = length(vars),

        # --------------------------------------------------------------
        # Expectations / subjective financial prospects
        # --------------------------------------------------------------

        finnow = exactvar(vars, prefix, "finnow"),
        finfut = exactvar(vars, prefix, "finfut"),

        # --------------------------------------------------------------
        # Saving
        # --------------------------------------------------------------

        save   = exactvar(vars, prefix, "save"),
        saved  = exactvar(vars, prefix, "saved"),
        savreg = exactvar(vars, prefix, "savreg"),
        savlt  = exactvar(vars, prefix, "savlt"),

        # --------------------------------------------------------------
        # Standard controls
        # --------------------------------------------------------------

        age_dv =
            exactvar(vars, prefix, "age_dv"),

        dvage =
            exactvar(vars, prefix, "dvage"),

        sex_dv =
            exactvar(vars, prefix, "sex_dv"),

        jbstat =
            exactvar(vars, prefix, "jbstat"),

        hiqual_dv =
            exactvar(vars, prefix, "hiqual_dv"),

        fimnnet_dv =
            exactvar(vars, prefix, "fimnnet_dv"),

        fimngrs_dv =
            exactvar(vars, prefix, "fimngrs_dv"),

        # --------------------------------------------------------------
        # Things whose exact naming can differ across BHPS / UKHLS
        # --------------------------------------------------------------

        interview_year_candidates =
            listmatches(
                vars,
                [
                    "intdaty",
                    "istrtdaty",
                    "intyear",
                    "ivyear"
                ];
                maxn=8
            ),

        birth_year_candidates =
            listmatches(
                vars,
                [
                    "birthy",
                    "birthyr",
                    "dobyear",
                    "dobyr"
                ];
                maxn=8
            ),

        tenure_candidates =
            listmatches(
                vars,
                [
                    "tenure",
                    "hsow",
                    "ownhome"
                ];
                maxn=8
            ),

        weight_candidates =
            listmatches(
                vars,
                [
                    "_xw",
                    "indin",
                    "indpx"
                ];
                maxn=10
            )
    )
end

# ==============================================================================
# Main
# ==============================================================================

function main()

    mkpath(OUTDIR)

    println("="^110)
    println("BHPS + UKHLS COHORT-EMPIRICS INVENTORY")
    println("Headers only — no respondent data loaded")
    println("="^110)

    rows = NamedTuple[]

    # ------------------------------------------------------------------
    # BHPS
    # ------------------------------------------------------------------

    bhpsdir =
        joinpath(ROOT, "bhps")

    bhpsfiles =
        sort(
            filter(
                f -> endswith(f, "_indresp.tab"),
                readdir(bhpsdir)
            )
        )

    for file in bhpsfiles
        push!(
            rows,
            inspect_file(
                "BHPS",
                joinpath(bhpsdir, file)
            )
        )
    end

    # ------------------------------------------------------------------
    # UKHLS
    # ------------------------------------------------------------------

    ukhlsdir =
        joinpath(ROOT, "ukhls")

    ukhlsfiles =
        sort(
            filter(
                f -> occursin(r"^[a-o]_indresp\.tab$", f),
                readdir(ukhlsdir)
            )
        )

    for file in ukhlsfiles
        push!(
            rows,
            inspect_file(
                "UKHLS",
                joinpath(ukhlsdir, file)
            )
        )
    end

    inv = DataFrame(rows)

    sort!(inv, [:source, :wave])

    # ------------------------------------------------------------------
    # Compact console table
    # ------------------------------------------------------------------

    println("\n", "="^110)
    println("CORE VARIABLE COVERAGE")
    println("="^110)

    println(
        rpad("Source", 7),
        rpad("Wave", 6),
        rpad("Prefix", 8),
        rpad("Year*", 7),
        rpad("Now", 6),
        rpad("Future", 8),
        rpad("Save", 6),
        rpad("Amount", 8),
        rpad("Reg", 6),
        rpad("LT", 6),
        rpad("Age", 6),
        rpad("Income", 8)
    )

    for r in eachrow(inv)

        ageok =
            !isempty(r.age_dv) ||
            !isempty(r.dvage)

        incok =
            !isempty(r.fimnnet_dv) ||
            !isempty(r.fimngrs_dv)

        println(
            rpad(r.source, 7),
            rpad(string(r.wave), 6),
            rpad(r.prefix, 8),
            rpad(string(r.nominal_start), 7),

            rpad(isempty(r.finnow) ? "-" : "Y", 6),
            rpad(isempty(r.finfut) ? "-" : "Y", 8),
            rpad(isempty(r.save)   ? "-" : "Y", 6),
            rpad(isempty(r.saved)  ? "-" : "Y", 8),
            rpad(isempty(r.savreg) ? "-" : "Y", 6),
            rpad(isempty(r.savlt)  ? "-" : "Y", 6),
            rpad(ageok ? "Y" : "-", 6),
            rpad(incok ? "Y" : "-", 8)
        )
    end

    println(
        "\n* Year is only the nominal wave start for orientation;",
        " actual interview year will be used in analysis."
    )

    # ------------------------------------------------------------------
    # Candidate variables that we need to pin down
    # ------------------------------------------------------------------

    println("\n", "="^110)
    println("DATE / BIRTH-YEAR / WEIGHT CANDIDATES")
    println("="^110)

    for r in eachrow(inv)

        println(
            "\n",
            r.source,
            " wave ",
            r.wave,
            " [",
            r.prefix,
            "]"
        )

        println(
            "  interview year: ",
            isempty(r.interview_year_candidates) ?
            "<none found>" :
            r.interview_year_candidates
        )

        println(
            "  birth year:     ",
            isempty(r.birth_year_candidates) ?
            "<none found>" :
            r.birth_year_candidates
        )

        println(
            "  tenure:         ",
            isempty(r.tenure_candidates) ?
            "<none found>" :
            r.tenure_candidates
        )

        println(
            "  weights:        ",
            isempty(r.weight_candidates) ?
            "<none found>" :
            r.weight_candidates
        )
    end

    # ------------------------------------------------------------------
    # Save metadata-only inventory to Dropbox
    # ------------------------------------------------------------------

    outfile =
        joinpath(
            OUTDIR,
            "bhps_ukhls_cohort_inventory.csv"
        )

    CSV.write(outfile, inv)

    println("\n", "="^110)
    println("OUTPUT")
    println("="^110)

    println(outfile)
    println("\nThis file contains variable metadata only — no respondent records.")
end

end

BHPSUKHLSCohortInventory.main()