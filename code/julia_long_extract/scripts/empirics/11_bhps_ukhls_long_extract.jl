module BHPSUKHLSLongExtract

using CSV
using DataFrames
using Statistics

const ROOT =
    raw"C:\Hansak\Data\UKDA-6614-tab\tab"

const LOCAL_OUT =
    raw"C:\Hansak\Data\UKHLS_derived"

const PROJECT_ROOT =
    normpath(joinpath(@__DIR__, "..", ".."))

const DROPBOX_OUT =
    joinpath(PROJECT_ROOT, "output", "empirics", "ukhls")

# ==============================================================================
# Helpers
# ==============================================================================

function tab_header(path)
    open(path, "r") do io
        String.(split(chomp(readline(io)), '\t'))
    end
end

function exact(vars, name)
    name in vars ? name : ""
end

function first_existing(vars, names)
    for name in names
        name in vars && return name
    end
    return ""
end

function value(df, var, i)
    isempty(var) && return missing
    return df[i, Symbol(var)]
end

function clean_year(x)
    ismissing(x) && return missing
    y = try
        Int(round(Float64(x)))
    catch
        return missing
    end
    1980 <= y <= 2030 ? y : missing
end

function clean_age(x)
    ismissing(x) && return missing
    a = try
        Float64(x)
    catch
        return missing
    end
    16 <= a <= 100 ? a : missing
end

function clean_birthyear(x)
    ismissing(x) && return missing
    y = try
        Int(round(Float64(x)))
    catch
        return missing
    end
    1900 <= y <= 2010 ? y : missing
end

function future_code(x)
    ismissing(x) && return missing

    y = try
        Int(round(Float64(x)))
    catch
        return missing
    end

    # Harmonized:
    # 1 = better
    # 2 = worse
    # 3 = same
    y in (1, 2, 3) ? y : missing
end

function future_score(x)
    ismissing(x) && return missing

    x == 1 && return  1.0
    x == 2 && return -1.0
    x == 3 && return  0.0

    return missing
end

function pessimistic(x)
    ismissing(x) && return missing
    return x == 2 ? 1.0 : 0.0
end

function save01(x)
    ismissing(x) && return missing

    y = try
        Int(round(Float64(x)))
    catch
        return missing
    end

    y == 1 && return 1.0
    y == 2 && return 0.0

    return missing
end

function saving_amount(save, amount)

    ismissing(save) && return missing

    if save == 0.0
        return 0.0
    end

    if save == 1.0
        ismissing(amount) && return missing

        a = try
            Float64(amount)
        catch
            return missing
        end

        a >= 0 || return missing
        return a
    end

    return missing
end

function numeric_or_missing(x)
    ismissing(x) && return missing

    try
        return Float64(x)
    catch
        return missing
    end
end

function positive_weight(x)
    ismissing(x) && return missing

    w = try
        Float64(x)
    catch
        return missing
    end

    w > 0 ? w : missing
end

# ==============================================================================
# Wave numbering
# ==============================================================================

bhps_wave(prefix) =
    Int(prefix[2] - 'a') + 1

ukhls_wave(prefix) =
    Int(prefix[1] - 'a') + 1

# ==============================================================================
# Provisional cross-sectional MAIN-INTERVIEW weight
#
# We save BOTH:
#   weight_xw
#   weight_var
#
# so every choice remains auditable.
# ==============================================================================

function choose_weight(source, wave, prefix, vars)

    candidates = String[]

    if source == "BHPS"

        if wave <= 8
            push!(candidates, "$(prefix)_indin91_xw")

        elseif wave <= 10
            push!(candidates, "$(prefix)_indin99_xw")
            push!(candidates, "$(prefix)_indin91_xw")

        else
            push!(candidates, "$(prefix)_indin01_xw")
            push!(candidates, "$(prefix)_indin99_xw")
            push!(candidates, "$(prefix)_indin91_xw")
        end

    else # UKHLS

        if wave == 1
            push!(candidates, "$(prefix)_indinus_xw")

        elseif wave <= 5
            push!(candidates, "$(prefix)_indinub_xw")

        elseif wave <= 13
            push!(candidates, "$(prefix)_indinui_xw")
            push!(candidates, "$(prefix)_indinub_xw")

        else
            push!(candidates, "$(prefix)_inding2_xw")
            push!(candidates, "$(prefix)_indinui_xw")
        end
    end

    for v in candidates
        v in vars && return v
    end

    return ""
end

# ==============================================================================
# Extract one wave
# ==============================================================================

function extract_wave(source, path)

    file = basename(path)
    prefix = split(file, "_")[1]

    vars = Set(tab_header(path))

    wave =
        source == "BHPS" ?
        bhps_wave(prefix) :
        ukhls_wave(prefix)

    # ------------------------------------------------------------------
    # Source-specific harmonization map
    # ------------------------------------------------------------------

    agevar =
        source == "BHPS" ?
        exact(vars, "$(prefix)_age") :
        first_existing(
            vars,
            [
                "$(prefix)_age_dv",
                "$(prefix)_dvage"
            ]
        )

    birthvar =
        exact(vars, "$(prefix)_birthy")

    yearvar =
        exact(vars, "$(prefix)_istrtdaty")

    futurevar =
        source == "BHPS" ?
        exact(vars, "$(prefix)_fisitx") :
        exact(vars, "$(prefix)_finfut")

    pastvar =
        source == "BHPS" ?
        exact(vars, "$(prefix)_fisitc") :
        ""

    savevar =
        exact(vars, "$(prefix)_save")

    savedvar =
        exact(vars, "$(prefix)_saved")

    incomevar =
        exact(vars, "$(prefix)_fimnnet_dv")

    jbstatvar =
        exact(vars, "$(prefix)_jbstat")

    hiqualvar =
        exact(vars, "$(prefix)_hiqual_dv")

    sexvar =
        first_existing(
            vars,
            [
                "$(prefix)_sex_dv",
                "$(prefix)_sex"
            ]
        )

    weightvar =
        choose_weight(
            source,
            wave,
            prefix,
            vars
        )

    # ------------------------------------------------------------------
    # Read only required variables
    # ------------------------------------------------------------------

    selected =
        unique(
            filter(
                x -> !isempty(x),
                [
                    "pidp",
                    agevar,
                    birthvar,
                    yearvar,
                    futurevar,
                    pastvar,
                    savevar,
                    savedvar,
                    incomevar,
                    jbstatvar,
                    hiqualvar,
                    sexvar,
                    weightvar
                ]
            )
        )

    println(
        rpad(source, 7),
        " wave ",
        lpad(wave, 2),
        " [", prefix, "]",
        " | columns=", lpad(length(selected), 2),
        " | weight=",
        isempty(weightvar) ? "<none>" : weightvar
    )

    raw =
        CSV.read(
            path,
            DataFrame;
            delim='\t',
            select=selected,
            pool=false
        )

    n = nrow(raw)

    interview_year =
        Vector{Union{Missing,Int}}(missing, n)

    age =
        Vector{Union{Missing,Float64}}(missing, n)

    birth_year =
        Vector{Union{Missing,Int}}(missing, n)

    cohort_year =
        Vector{Union{Missing,Int}}(missing, n)

    fin_future_code =
        Vector{Union{Missing,Int}}(missing, n)

    fin_future_score =
        Vector{Union{Missing,Float64}}(missing, n)

    fin_pessimistic =
        Vector{Union{Missing,Float64}}(missing, n)

    fin_past_change =
        Vector{Union{Missing,Int}}(missing, n)

    save =
        Vector{Union{Missing,Float64}}(missing, n)

    saved_monthly =
        Vector{Union{Missing,Float64}}(missing, n)

    personal_net_income =
        Vector{Union{Missing,Float64}}(missing, n)

    employment_status =
        Vector{Union{Missing,Float64}}(missing, n)

    education =
        Vector{Union{Missing,Float64}}(missing, n)

    sex =
        Vector{Union{Missing,Float64}}(missing, n)

    weight_xw =
        Vector{Union{Missing,Float64}}(missing, n)

    for i in 1:n

        yr =
            clean_year(
                value(raw, yearvar, i)
            )

        ag =
            clean_age(
                value(raw, agevar, i)
            )

        by =
            clean_birthyear(
                value(raw, birthvar, i)
            )

        # Wave 1 BHPS has no birthy in indresp.
        # Use interview year - age as a fallback.
        cy =
            if !ismissing(by)
                by
            elseif !ismissing(yr) && !ismissing(ag)
                round(Int, yr - ag)
            else
                missing
            end

        fc =
            future_code(
                value(raw, futurevar, i)
            )

        pc =
            future_code(
                value(raw, pastvar, i)
            )

        sv =
            save01(
                value(raw, savevar, i)
            )

        interview_year[i] = yr
        age[i] = ag
        birth_year[i] = by
        cohort_year[i] = cy

        fin_future_code[i] = fc
        fin_future_score[i] = future_score(fc)
        fin_pessimistic[i] = pessimistic(fc)

        fin_past_change[i] = pc

        save[i] = sv

        saved_monthly[i] =
            saving_amount(
                sv,
                value(raw, savedvar, i)
            )

        personal_net_income[i] =
            numeric_or_missing(
                value(raw, incomevar, i)
            )

        employment_status[i] =
            numeric_or_missing(
                value(raw, jbstatvar, i)
            )

        education[i] =
            numeric_or_missing(
                value(raw, hiqualvar, i)
            )

        sex[i] =
            numeric_or_missing(
                value(raw, sexvar, i)
            )

        weight_xw[i] =
            positive_weight(
                value(raw, weightvar, i)
            )
    end

    return DataFrame(
        pidp = raw.pidp,

        source = fill(source, n),
        wave = fill(wave, n),
        prefix = fill(prefix, n),

        interview_year = interview_year,
        age = age,
        birth_year = birth_year,
        cohort_year = cohort_year,

        # 1 better, 2 worse, 3 same
        fin_future_code = fin_future_code,

        # +1 better, 0 same, -1 worse
        fin_future_score = fin_future_score,

        # 1 if expects worse, 0 otherwise
        fin_pessimistic = fin_pessimistic,

        # BHPS only at this stage
        fin_past_change = fin_past_change,

        # 1 saver, 0 non-saver
        save = save,

        # Explicit non-savers = £0
        saved_monthly = saved_monthly,

        personal_net_income = personal_net_income,
        employment_status = employment_status,
        education = education,
        sex = sex,

        weight_xw = weight_xw,
        weight_var = fill(weightvar, n)
    )
end

# ==============================================================================
# Aggregate wave audit
# ==============================================================================

function make_audit(long)

    audit =
        DataFrame(
            source=String[],
            wave=Int[],
            prefix=String[],
            N=Int[],
            N_year=Int[],
            N_age=Int[],
            N_cohort=Int[],
            N_future=Int[],
            N_save=Int[],
            N_saved_amount=Int[],
            N_weight=Int[],
            N_age18_40_future=Int[],
            weight_var=String[]
        )

    for g in groupby(long, [:source, :wave, :prefix])

        n = nrow(g)

        youngfuture =
            count(
                i ->
                    !ismissing(g.age[i]) &&
                    18 <= g.age[i] <= 40 &&
                    !ismissing(g.fin_future_code[i]),
                1:n
            )

        wvars =
            unique(g.weight_var)

        push!(
            audit,
            (
                source=g.source[1],
                wave=g.wave[1],
                prefix=g.prefix[1],
                N=n,

                N_year=count(!ismissing, g.interview_year),
                N_age=count(!ismissing, g.age),
                N_cohort=count(!ismissing, g.cohort_year),

                N_future=count(!ismissing, g.fin_future_code),
                N_save=count(!ismissing, g.save),
                N_saved_amount=count(!ismissing, g.saved_monthly),

                N_weight=count(!ismissing, g.weight_xw),

                N_age18_40_future=youngfuture,

                weight_var=
                    isempty(wvars) ? "" : first(wvars)
            )
        )
    end

    sort!(audit, [:source, :wave])

    return audit
end

# ==============================================================================
# Main
# ==============================================================================

function main()

    mkpath(LOCAL_OUT)
    mkpath(DROPBOX_OUT)

    println("="^110)
    println("BHPS + UKHLS LONG COHORT EXTRACT")
    println("Respondent-level output stays LOCAL")
    println("="^110)

    frames = DataFrame[]

    # ------------------------------------------------------------------
    # BHPS 1991–2008
    # ------------------------------------------------------------------

    bhpsdir =
        joinpath(ROOT, "bhps")

    bhpsfiles =
        sort(
            filter(
                f -> occursin(r"^b[a-r]_indresp\.tab$", f),
                readdir(bhpsdir)
            )
        )

    for file in bhpsfiles

        push!(
            frames,
            extract_wave(
                "BHPS",
                joinpath(bhpsdir, file)
            )
        )
    end

    # ------------------------------------------------------------------
    # UKHLS waves 1–15
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
            frames,
            extract_wave(
                "UKHLS",
                joinpath(ukhlsdir, file)
            )
        )
    end

    # ------------------------------------------------------------------
    # Stack
    # ------------------------------------------------------------------

    long =
        vcat(frames...)

    sort!(
        long,
        [:pidp, :interview_year, :source, :wave]
    )

    println("\n", "="^110)
    println("LONG FILE")
    println("="^110)

    println("Rows              : ", nrow(long))
    println("Columns           : ", ncol(long))
    println("Unique persons    : ", length(unique(long.pidp)))

    println(
        "Valid expectations : ",
        count(!ismissing, long.fin_future_code)
    )

    println(
        "Valid saving status: ",
        count(!ismissing, long.save)
    )

    # ------------------------------------------------------------------
    # LOCAL respondent-level output
    # ------------------------------------------------------------------

    localfile =
        joinpath(
            LOCAL_OUT,
            "bhps_ukhls_cohort_long_raw.csv"
        )

    CSV.write(
        localfile,
        long
    )

    # ------------------------------------------------------------------
    # Aggregate audit only -> Dropbox
    # ------------------------------------------------------------------

    audit =
        make_audit(long)

    auditfile =
        joinpath(
            DROPBOX_OUT,
            "bhps_ukhls_long_extract_audit.csv"
        )

    CSV.write(
        auditfile,
        audit
    )

    println("\n", "="^110)
    println("WAVE AUDIT")
    println("="^110)

    for r in eachrow(audit)

        println(
            rpad(r.source, 7),
            " wave ",
            lpad(r.wave, 2),
            " | N=", lpad(r.N, 6),
            " | future=", lpad(r.N_future, 6),
            " | save=", lpad(r.N_save, 6),
            " | age18-40 future=", lpad(r.N_age18_40_future, 6),
            " | weight=", r.weight_var
        )
    end

    println("\n", "="^110)
    println("OUTPUT")
    println("="^110)

    println("LOCAL MICRODATA:")
    println(localfile)

    println("\nDROPBOX AGGREGATE AUDIT:")
    println(auditfile)

    println(
        "\nNo respondent-level BHPS/UKHLS data were written to Dropbox."
    )
end

end # module

BHPSUKHLSLongExtract.main()