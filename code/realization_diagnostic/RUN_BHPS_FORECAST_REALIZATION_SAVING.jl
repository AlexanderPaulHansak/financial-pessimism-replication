# ============================================================================
# BHPS FINANCIAL EXPECTATIONS / REALIZATIONS / SAVING -- DIAGNOSTIC EXTENSION
#
# Usage (in predecessor modeling project root):
#   include("RUN_BHPS_FORECAST_REALIZATION_SAVING.jl")
#
# Uses the existing locally derived cohort file (script 11) plus narrow date,
# financial-management, household-income and weight fields from the original
# BHPS TAB files. Does NOT modify existing source code or datasets.
#
# Purpose: distinguish forecast pessimism t followed by a *reported* financial
# deterioration t+1 from forecast pessimism that was not subsequently reported
# as realized. Subjective retrospective change is NOT a verified income shock.
#
# This is an observational robustness exercise; conditioning on a future
# subjective outcome does not identify a causal effect of beliefs or saving.
# ============================================================================
module BHPSForecastRealizationSaving

using CSV, DataFrames, Statistics, LinearAlgebra, Random, Printf

const ROOT = @__DIR__
const DERIVED = get(ENV, "FP_UK_DERIVED", raw"C:\Hansak\Data\UKHLS_derived")
const RAW_BHPS = get(ENV, "FP_BHPS_TAB_ROOT", raw"C:\Hansak\Data\UKDA-6614-tab\tab\bhps")
const LONGFILE = joinpath(DERIVED, "bhps_ukhls_cohort_long_raw.csv")
const OUT = get(ENV, "FP_PESSIMISM_OUTPUT", joinpath(ROOT, "output", "empirics", "pessimism_realization_diagnostic"))
const MIN_CELL = 40

function asnum(x)
    ismissing(x) && return missing
    z = try
        x isa Number ? Float64(x) : parse(Float64, strip(string(x)))
    catch
        return missing
    end
    return isfinite(z) ? z : missing
end

function code(x, allowed)
    z = asnum(x)
    ismissing(z) && return missing
    return isinteger(z) && Int(z) in allowed ? Int(z) : missing
end

three(x) = code(x, 1:3)          # 1 better, 2 worse, 3 same
saving(x) = code(x, 0:1)         # Already harmonized by script 11
manage(x) = code(x, 1:5)         # Current financial-management question
intyear(x) = code(x, 1989:2010)
intmonth(x) = code(x, 1:12)

function headers(path)
    open(path, "r") do io
        return String.(split(chomp(readline(io)), '\t'))
    end
end

function candidate(vars, choices)
    for v in choices
        v in vars && return v
    end
    return nothing
end

# Only metadata, weights and optional household-resource information are read.
# Existing derived respondents remain local and are never exported.
function bhps_extras()
    frames = DataFrame[]
    records = NamedTuple[]
    for wi in 1:18
        prefix = "b" * string(Char(Int('a') + wi - 1))
        indpath = joinpath(RAW_BHPS, prefix * "_indresp.tab")
        isfile(indpath) || error("Missing original BHPS file: " * indpath)
        vars = Set(headers(indpath))
        yvar = candidate(vars, [prefix * "_istrtdaty", prefix * "_intdaty"])
        mvar = candidate(vars, [prefix * "_istrtdatm", prefix * "_intdatm"])
        hidvar = candidate(vars, [prefix * "_hidp"])
        # The financial-management item is "finnow" in BHPS (not "fisit").
        # Prior versions erroneously requested _fisit, making all adjusted
        # samples empty because the missing management item was compulsory.
        finvar = candidate(vars, [prefix * "_finnow"])
        finvar === nothing && error("BHPS financial management field missing in " *
            basename(indpath) * "; expected " * prefix * "_finnow")
        wtarget = wi <= 9 ? "indin91_lw" : wi <= 11 ? "indin99_lw" : "indin01_lw"
        wvar = candidate(vars, [prefix * "_" * wtarget])
        if yvar === nothing || mvar === nothing
            error("Actual interview year/month not found in " * basename(indpath) *
                  ". Check variables ending istrtdaty/istrtdatm before proceeding.")
        end
        selected = unique(["pidp", yvar, mvar])
        for v in (hidvar, finvar, wvar)
            v === nothing || push!(selected, v)
        end
        ind = CSV.read(indpath, DataFrame; delim='\t', select=selected, pool=false)
        n = nrow(ind)
        extra = DataFrame(pidp=ind.pidp, wave=fill(wi, n),
            actual_year=intyear.(ind[!, yvar]),
            actual_month=intmonth.(ind[!, mvar]),
            management=finvar === nothing ? fill(missing, n) : manage.(ind[!, finvar]),
            longitudinal_weight=wvar === nothing ? fill(missing, n) : asnum.(ind[!, wvar]),
            gross_household_income=Vector{Union{Missing,Float64}}(missing, n))
        has_income = false
        hhpath = joinpath(RAW_BHPS, prefix * "_hhresp.tab")
        if hidvar !== nothing && isfile(hhpath)
            hvars = Set(headers(hhpath))
            incomevar = candidate(hvars, [prefix * "_fihhmngrs_dv"])
            if incomevar !== nothing
                hh = CSV.read(hhpath, DataFrame; delim='\t',
                              select=[hidvar, incomevar], pool=false)
                if !any(nonunique(hh, Symbol(hidvar)))
                    temp = leftjoin(select(ind, :pidp, Symbol(hidvar)), hh; on=Symbol(hidvar))
                    nrow(temp) == n || error("Household join expanded individual records in wave $wi")
                    # Actual positive resources; nonpositive special codes are missing.
                    extra.gross_household_income = [
                        begin
                            x = asnum(z)
                            ismissing(x) || x <= 0 ? missing : x
                        end for z in temp[!, incomevar]
                    ]
                    has_income = true
                end
            end
        end
        any(nonunique(extra, [:pidp, :wave])) &&
            error("Duplicate pidp/wave in source metadata: " * prefix)
        push!(frames, extra)
        push!(records, (wave=wi, prefix=prefix, N=n, year_variable=string(yvar),
            month_variable=string(mvar), management_variable=something(finvar, ""),
            weight_variable=something(wvar, ""), gross_household_income_available=has_income,
            N_valid_dates=count(i -> !ismissing(extra.actual_year[i]) &&
                     !ismissing(extra.actual_month[i]), 1:n),
            N_positive_weights=count(x -> !ismissing(x) && x>0, extra.longitudinal_weight),
            N_valid_financial_management=count(!ismissing, extra.management),
            N_positive_gross_household_income=count(x -> !ismissing(x) && x>0, extra.gross_household_income)))
        println(@sprintf("  BHPS %-3s rows=%6d | date=%6d | endpoint-LW=%6d | HH-income=%s",
                prefix, n, records[end].N_valid_dates,
                records[end].N_positive_weights, has_income ? "yes" : "no"))
        println("        current-finances management=", records[end].N_valid_financial_management,
            " | positive household gross income=", records[end].N_positive_gross_household_income)
    end
    return vcat(frames...), DataFrame(records)
end

function prepare_long(extras)
    isfile(LONGFILE) || error("Derived BHPS long file missing: " * LONGFILE *
        "\nRun the existing scripts/empirics/11_bhps_ukhls_long_extract.jl first.")
    want = [:pidp,:source,:wave,:interview_year,:age,:fin_future_code,
            :fin_past_change,:save,:employment_status]
    long = CSV.read(LONGFILE, DataFrame; select=want, pool=false)
    long = filter(r -> r.source == "BHPS" && !ismissing(r.pidp) &&
                     !ismissing(r.wave), long)
    long.wave = Int.(long.wave)
    any(nonunique(long, [:pidp,:wave])) &&
        error("Derived BHPS file has duplicate pidp/wave. Fix wave duplicates before fitting models.")
    long = leftjoin(long, extras; on=[:pidp,:wave], validate=(true,true))
    long.expected = three.(long.fin_future_code)
    long.reported_past = three.(long.fin_past_change)
    long.saving_now = saving.(long.save)
    long.age_clean = [begin
        z=asnum(a)
        ismissing(z) || !(16<=z<=100) ? missing : z
    end for a in long.age]
    long.employment_clean = [begin
        z=asnum(v)
        ismissing(z) || z < 1 ? missing : Int(round(z))
    end for v in long.employment_status]
    disagree = count(i -> !ismissing(long.interview_year[i]) &&
                      !ismissing(long.actual_year[i]) &&
                      long.interview_year[i] != long.actual_year[i], 1:nrow(long))
    println("Long/actual interview year disagreements: ", disagree)
    disagree > 0 && println("WARNING: actual interview dates, not derived year, govern pairing.")
    return long
end

function make_pairs(long)
    t = select(long, [:pidp,:wave,:actual_year,:actual_month,:age_clean,
        :expected,:reported_past,:saving_now,:management,:employment_clean,
        :gross_household_income])
    rename!(t, :wave=>:wave0, :actual_year=>:year0,
        :actual_month=>:month0, :saving_now=>:save0,
        :reported_past=>:past0, :management=>:management0,
        :employment_clean=>:employment0,
        :gross_household_income=>:income0)
    t.nextwave = t.wave0 .+ 1
    f = select(long, [:pidp,:wave,:actual_year,:actual_month,
        :saving_now,:reported_past,:longitudinal_weight,:gross_household_income])
    rename!(f, :wave=>:nextwave, :actual_year=>:year1,
        :actual_month=>:month1, :saving_now=>:save1,
        :reported_past=>:realized, :longitudinal_weight=>:endpoint_weight,
        :gross_household_income=>:income1)
    pairs = innerjoin(t, f; on=[:pidp,:nextwave], validate=(true,true))
    println("Adjacent-wave links before date/item restrictions: ",nrow(pairs))
    pairs.months_apart = [begin
        a,b,c,d=pairs.year0[i], pairs.month0[i], pairs.year1[i], pairs.month1[i]
        any(ismissing,(a,b,c,d)) ? missing : (12*(c-a)+(d-b))
    end for i in 1:nrow(pairs)]
    # Date restrictions are the same 6-18 month window used in the manuscript.
    core = filter(r -> !ismissing(r.age_clean) && 18<=r.age_clean<=59 &&
                !ismissing(r.months_apart) && 6<=r.months_apart<=18 &&
                !ismissing(r.expected) &&
                !ismissing(r.save0) && !ismissing(r.save1), pairs)
    println("Pairs with valid forecast, saving at both dates and 6-18-month gap: ", nrow(core))
    # Retrospective financial assessment may itself be missing. Track exclusion.
    aud = NamedTuple[]
    core.age_group = ifelse.(core.age_clean .<= 34, "18-34", "35-59")
    for g in groupby(core, [:age_group,:expected])
        push!(aud, (age_group=g.age_group[1], forecast=label3(g.expected[1]),
            N_eligible=nrow(g), N_with_realization=count(!ismissing,g.realized),
            share_with_realization=count(!ismissing,g.realized)/nrow(g)))
    end
    d = filter(r -> !ismissing(r.realized), core)
    d.delta_save = Float64.(d.save1 .- d.save0)
    d.change_income_nominal = [begin
        x,y=asnum(d.income0[i]),asnum(d.income1[i])
        ismissing(x) || ismissing(y) || x<=0 || y<=0 ? missing : log(y/x)
    end for i in 1:nrow(d)]
    return d, DataFrame(aud), core
end

label3(v) = v == 1 ? "better" : v == 2 ? "worse" : "same"

function descriptive_cells(d)
    out = NamedTuple[]
    for g in groupby(d, [:age_group,:expected,:realized])
        nrow(g) >= MIN_CELL || continue
        push!(out,(age_group=g.age_group[1],
            forecast=label3(g.expected[1]),
            realized=label3(g.realized[1]),
            N=nrow(g),people=length(unique(g.pidp)),
            current_saving=mean(Float64.(g.save0)),
            subsequent_saving=mean(Float64.(g.save1)),
            saving_change=mean(g.delta_save),
            N_income_changes=count(!ismissing,g.change_income_nominal),
            avg_nominal_log_income_change=begin
                x=collect(skipmissing(g.change_income_nominal))
                length(x)>=MIN_CELL ? mean(x) : missing
            end))
    end
    return DataFrame(out)
end

# Standardized 3x3 forecast/realization interaction design. Baselines:
# forecast SAME, realization SAME. First eight terms are mandatory.
const BASIC_TERMS = ["forecast_worse", "forecast_better", "realized_worse",
    "realized_better", "forecast_worse_x_realized_worse",
    "forecast_worse_x_realized_better", "forecast_better_x_realized_worse",
    "forecast_better_x_realized_better"]

function design(d; add_current=false, add_controls=false, stratify_realization=true)
    n=nrow(d)
    p=Float64.(d.expected .== 2)
    o=Float64.(d.expected .== 1)
    # The pooled benchmark intentionally includes respondents for whom the
    # next-wave retrospective financial assessment is MISSING.  Do not read
    # or convert d.realized unless the specification actually uses it.
    if stratify_realization
        any(ismissing, d.realized) &&
            error("Realization-stratified design requires nonmissing reported outcomes")
        w=Float64.(d.realized .== 2)
        b=Float64.(d.realized .== 1)
        terms=copy(BASIC_TERMS)
        cols=[p,o,w,b,p.*w,p.*b,o.*w,o.*b]
    else
        terms=["forecast_worse","forecast_better"]
        cols=[p,o]
    end
    if add_current
        push!(terms,"baseline_saving"); push!(cols, Float64.(d.save0))
    end
    if add_controls
        # The adjusted sample must have valid baseline retrospective status,
        # reported financial management, and gross household resources.
        push!(terms,"previous_year_worse"); push!(cols,Float64.(d.past0 .== 2))
        push!(terms,"previous_year_better"); push!(cols,Float64.(d.past0 .== 1))
        for k in 2:5
            push!(terms,"baseline_financial_management_$(k)")
            push!(cols,Float64.(d.management0 .== k))
        end
        push!(terms,"baseline_asinh_gross_household_income")
        push!(cols, asinh.(Float64.(d.income0)./1000))
        push!(terms,"age_squared_100")
        push!(cols, (Float64.(d.age_clean).^2)./100.0)
    end
    return hcat(cols...),terms
end

function group_codes(v)
    mp=Dict{Any,Int}(); codes=Vector{Int}(undef,length(v))
    for i in eachindex(v)
        key=v[i]
        if !haskey(mp,key)
            mp[key]=length(mp)+1
        end
        codes[i]=mp[key]
    end
    return codes,length(mp)
end

function weighted_demean!(a, groups, ng, weights)
    n,k=size(a)
    sums=zeros(ng,k); den=zeros(ng)
    @inbounds for i in 1:n
        g=groups[i]; wi=weights[i]
        den[g]+=wi
        for j in 1:k
            sums[g,j]+=wi*a[i,j]
        end
    end
    @inbounds for g in 1:ng
        den[g]>0 || error("Empty or zero-weight fixed-effect group")
        for j in 1:k
            sums[g,j]/=den[g]
        end
    end
    @inbounds for i in 1:n
        g=groups[i]
        for j in 1:k
            a[i,j]-=sums[g,j]
        end
    end
    return nothing
end

function absorb!(a,pid,time,w;maxiter=250,tol=1e-9)
    np=maximum(pid); nt=maximum(time)
    before=similar(a)
    for it in 1:maxiter
        copyto!(before,a)
        weighted_demean!(a,pid,np,w)
        weighted_demean!(a,time,nt,w)
        err=maximum(abs.(a .- before))
        if err <= tol*max(1.0,maximum(abs.(a)))
            return it,np,nt,err
        end
    end
    error("Person/time fixed-effect projections failed to converge in $maxiter iterations")
end

function fit_twfe(d, y, X, terms; weighted=false)
    n,k=size(X)
    n>400 || error("FE regression has fewer than 400 observations")
    pid,G=group_codes(d.pidp)
    G>=50 || error("FE regression has too few person clusters")
    # Survey-wave by calendar interview year, matching the manuscript's
    # interview-time definition (not arbitrary cohort period dummies).
    tkeys=[string(d.wave0[i],"/",d.year0[i]) for i in 1:n]
    time,T=group_codes(tkeys)
    w=weighted ? Float64.(d.endpoint_weight) : ones(n)
    w ./= mean(w)
    a=hcat(X,Float64.(y))
    it,_,_,err=absorb!(a,pid,time,w)
    x=a[:,1:k]; yd=a[:,k+1]
    sw=sqrt.(w)
    xw=x .* sw
    s=svdvals(xw)
    isempty(s) && error("Empty design after FE absorption")
    if minimum(s)/maximum(s)<1e-9
        error("Nonidentified or nearly singular FE design: "*join(terms,", "))
    end
    beta=xw \ (yd .* sw)
    res=yd-x*beta
    bread=inv(transpose(xw)*xw)
    scores=zeros(G,k)
    @inbounds for i in 1:n
        g=pid[i]; sc=w[i]*res[i]
        for j in 1:k
            scores[g,j]+=sc*x[i,j]
        end
    end
    # Cluster-robust covariance at person level. This is NOT the BHPS complex
    # survey PSU/stratum variance estimator used by Codex's main manuscript.
    denom=n-G-T-k
    denom>0 || error("Insufficient residual df for cluster correction")
    finite=(G/(G-1))*((n-1)/denom)
    vcov=finite*(bread*(transpose(scores)*scores)*bread)
    vcov=(vcov+transpose(vcov))/2
    se=sqrt.(max.(diag(vcov),0.0))
    return (beta=beta, se=se, vcov=vcov, N=n, clusters=G,
            groups_time=T, absorbed_iterations=it, absorbed_error=err,
            terms=terms)
end

function contrast(fit, weights, description)
    c=zeros(length(fit.terms))
    for (term,value) in weights
        ix=findfirst(==(term),fit.terms)
        ix === nothing && error("Contrast term missing: "*term)
        c[ix]=value
    end
    b=dot(c,fit.beta)
    v=max(dot(c,fit.vcov*c),0.0)
    se=sqrt(v)
    return (contrast=description, estimate_pp=100b, se_pp=100se,
            lo95_pp=100(b-1.96se), hi95_pp=100(b+1.96se))
end

function contrasts(fit)
    p="forecast_worse"; rw="realized_worse"; rb="realized_better"
    pw="forecast_worse_x_realized_worse"
    pb="forecast_worse_x_realized_better"
    return [
        contrast(fit,[(p,1.0)],"Pessimism versus same forecast | realized SAME"),
        contrast(fit,[(p,1.0),(pw,1.0)],"Pessimism versus same forecast | realized WORSE"),
        contrast(fit,[(p,1.0),(pb,1.0)],"Pessimism versus same forecast | realized BETTER"),
        contrast(fit,[(pw,1.0)],"Difference in pessimism gradient | WORSE minus SAME realization"),
        contrast(fit,[(pb,1.0)],"Difference in pessimism gradient | BETTER minus SAME realization"),
        contrast(fit,[(rw,1.0),(pw,1.0)],"Among pessimists | realized WORSE versus SAME"),
        contrast(fit,[(rw,1.0),(pw,1.0),(rb,-1.0),(pb,-1.0)],
            "Among pessimists | realized WORSE versus BETTER")
    ]
end

function sample_for(d; adjusted=false, weighted=false)
    return filter(r ->
        (!weighted || (!ismissing(asnum(r.endpoint_weight)) &&
                        asnum(r.endpoint_weight)>0)) &&
        (!adjusted || (!ismissing(r.past0) && !ismissing(r.management0) &&
                       !ismissing(asnum(r.income0)) && asnum(r.income0)>0)), d)
end

function run_regressions(d, core)
    results=NamedTuple[]
    specifications=[
        ("MAIN_change",:delta_save,false,false,false),
        ("ADJUSTED_change",:delta_save,false,true,false),
        ("ADJUSTED_next_conditional_on_current",:save1,true,true,false),
        ("ADJUSTED_change_LW_sensitivity",:delta_save,false,true,true)
    ]
    sample_audit=NamedTuple[]
    for group in ("18-34","35-59")
        dg=filter(r->r.age_group==group,d)
        adj=sample_for(dg;adjusted=true)
        adjw=sample_for(dg;adjusted=true,weighted=true)
        audit_row=(age_group=group,N_complete_realization=nrow(dg),
            N_valid_past=count(!ismissing,dg.past0),
            N_valid_management=count(!ismissing,dg.management0),
            N_positive_income=count(x -> !ismissing(x) && x>0, dg.income0),
            N_positive_endpoint_LW=count(x -> !ismissing(x) && x>0,dg.endpoint_weight),
            N_adjusted=nrow(adj),N_adjusted_with_endpoint_LW=nrow(adjw))
        push!(sample_audit,audit_row)
        println("  SAMPLE AUDIT ",group," | realized=",nrow(dg),
            " | past=",audit_row.N_valid_past,
            " | manage=",audit_row.N_valid_management,
            " | income=",audit_row.N_positive_income,
            " | adjusted=",audit_row.N_adjusted,
            " | adjusted+LW=",audit_row.N_adjusted_with_endpoint_LW)
        if audit_row.N_adjusted == 0
            println("  WARNING: No observations survive controls for ",group,
                "; inspect 31_adjusted_sample_coverage.csv before interpreting adjusted models")
        end
        # Is the original timing contrast distorted just by requiring a
        # response to next wave's retrospective financial-change question?
        for (name,base) in (("POOLED_change_all_forecast_pairs",core),
                             ("POOLED_change_realization_complete",d))
            bb=filter(r->r.age_group==group,base)
            if nrow(bb)>=400 && length(unique(bb.pidp))>=50
                X0,t0=design(bb;stratify_realization=false)
                f0=try
                    fit_twfe(bb,Float64.(bb.save1 .- bb.save0),X0,t0)
                catch err
                    println("  FAILED ",name," ",group,": ",sprint(showerror,err))
                    nothing
                end
                if f0!==nothing
                    c0=contrast(f0,[("forecast_worse",1.0)],
                        "Pessimism versus same forecast | POOLED across realizations")
                    push!(results,merge((age_group=group,model=name,outcome="delta_save",
                        adjusted=false,endpoint_longitudinal_weighted=false,
                        inference="cluster_pidp_NOT_survey_PSU",N=f0.N,
                        people=f0.clusters,interview_time_cells=f0.groups_time),c0))
                    println(@sprintf("  %-38s age=%s | N=%6d | pooled contrast %+.2f pp (SE %.2f)",
                        name,group,f0.N,c0.estimate_pp,c0.se_pp))
                end
            end
        end
        for (name,yvar,add_current,adjusted,weighted) in specifications
            dd=sample_for(dg;adjusted=adjusted,weighted=weighted)
            N=nrow(dd)
            npeople=length(unique(dd.pidp))
            if N<400 || npeople<50
                println("  SKIP ",rpad(name,38)," age=",group,
                    " insufficient matched observations: ",N)
                continue
            end
            X,terms=design(dd;add_current=add_current,add_controls=adjusted)
            y=Float64.(dd[!,yvar])
            fit=try
                fit_twfe(dd,y,X,terms;weighted=weighted)
            catch err
                println("  FAILED ",name," ",group,": ",sprint(showerror,err))
                continue
            end
            println(@sprintf("  %-38s age=%s | N=%6d | people=%5d | FE iterations=%d",
                name,group,N,fit.clusters,fit.absorbed_iterations))
            for c in contrasts(fit)
                push!(results, merge((age_group=group, model=name, outcome=string(yvar),
                    adjusted=adjusted, endpoint_longitudinal_weighted=weighted,
                    inference="cluster_pidp_NOT_survey_PSU", N=fit.N,
                    people=fit.clusters, interview_time_cells=fit.groups_time),c))
                if occursin("Pessimism versus same forecast",c.contrast)
                    println(@sprintf("    %-65s %+7.2f pp (SE %5.2f)",
                        c.contrast,c.estimate_pp,c.se_pp))
                end
            end
        end
    end
    isempty(results) && error("All FE models failed; no results generated.")
    return DataFrame(results),DataFrame(sample_audit)
end

function test_synthetic()
    @assert three(1)==1 && three(2)==2 && three(3)==3
    @assert ismissing(three(-9)) && ismissing(saving(2))
    @assert saving(0)==0 && saving(1)==1
    rng=MersenneTwister(20261016)
    npeople=140; nperiods=9
    ids=Int[]; yr=Int[]; waves=Int[]; fore=Int[]; real=Int[]
    for i in 1:npeople, t in 1:nperiods
        push!(ids,i);push!(yr,1990+t);push!(waves,t)
        push!(fore,rand(rng,1:3)); push!(real,rand(rng,1:3))
    end
    s=DataFrame(pidp=ids,year0=yr,wave0=waves,
        expected=fore,realized=real)
    # The FE fitter must recover known coefficients even when person and
    # interview-time intercepts have been added to the outcome.
    X,terms=design(s)
    truebeta=[0.13,-0.02,0.03,-0.01,-0.06,0.02,0.015,-0.03]
    outcome=X*truebeta + [0.2*sin(i)+0.03*t for (i,t) in zip(ids,waves)]
    fitted=fit_twfe(s,outcome,X,terms)
    @assert maximum(abs.(fitted.beta-truebeta))<1e-6
    r=contrasts(fitted)
    @assert abs(r[2].estimate_pp - 100*(truebeta[1]+truebeta[5]))<1e-6
    # Regression-coverage test: the *pooled* forecast sample need not have
    # a reported realization at the next interview. This previously caused
    # Float64(::Missing) at the very first pooled regression.
    s_pooled=copy(s)
    s_pooled.realized = Union{Missing,Int}[
        i % 7 == 0 ? missing : s.realized[i]
        for i in 1:nrow(s)
    ]
    Xp,tp=design(s_pooled;stratify_realization=false)
    @assert size(Xp,2)==2 && tp==["forecast_worse","forecast_better"]
    @assert all(isfinite,Xp)
    bp=[0.08,-0.04]
    yp=Xp*bp + [0.2*sin(i)+0.03*t for (i,t) in zip(ids,waves)]
    fitp=fit_twfe(s_pooled,yp,Xp,tp)
    @assert maximum(abs.(fitp.beta-bp)) < 1e-6
    # Regression controls must include the 1--5 current-finances management
    # answer and never mistake an unavailable response for category 1.
    @assert manage(1)==1 && manage(5)==5 && ismissing(manage(-9))
    audit_toy=DataFrame(past0=Union{Missing,Int}[1,2,3,missing],
        management0=Union{Missing,Int}[1,5,missing,2],
        income0=Union{Missing,Float64}[100.0,500.0,1000.0,missing],
        endpoint_weight=Union{Missing,Float64}[1.0,2.0,3.0,4.0])
    @assert nrow(sample_for(audit_toy;adjusted=true))==2
    @assert nrow(sample_for(audit_toy;adjusted=true,weighted=true))==2
    println("Synthetic test PASS: question coding; person/time FE; interaction contrasts; pooled missing realizations; adjusted sample controls")
end

function save_aggregates(name, df)
    # Stage aggregate-only results outside the Dropbox-synced tree first.
    # A temporary Dropbox lock must not destroy a completed calculation.
    local_dir=joinpath(DERIVED,"pessimism_realization_diagnostic","aggregate_staging")
    mkpath(local_dir)
    localfile=joinpath(local_dir,name)
    CSV.write(localfile,df)
    destination=joinpath(OUT,name)
    for attempt in 1:3
        try
            mkpath(OUT)
            cp(localfile,destination;force=true)
            println("AGGREGATE [Dropbox]: ",destination)
            return nothing
        catch err
            println("WARN Dropbox sync attempt ",attempt," for ",name,": ",
                sprint(showerror,err))
            attempt<3 && sleep(0.5*attempt)
        end
    end
    println("AGGREGATE KEPT LOCALLY: ",localfile)
    return nothing
end

function main()
    println("="^115)
    println("BHPS | FORECAST PESSIMISM x REPORTED FINANCIAL REALIZATION | SAVING TIMING")
    println("="^115)
    println("Input derived: ",LONGFILE)
    println("Original BHPS: ",RAW_BHPS)
    println("Main FE inference: individual clustering; not the manuscript PSU/strata estimator")
    println("Design fix: financial-management control uses BHPS *_finnow (not nonexistent *_fisit)")
    println("Pooled regressions do not require realized financial-change answers")
    test_synthetic()
    isdir(RAW_BHPS) || error("Raw BHPS directory not found: "*RAW_BHPS)
    extras,audit=bhps_extras()
    long=prepare_long(extras)
    d,coverage,core=make_pairs(long)
    nrow(d)>=400 || error("Too few valid pairs with realized financial change")
    println("Forecast/realization-complete pairs: ",nrow(d),
            " | unique people: ",length(unique(d.pidp)))
    cells=descriptive_cells(d)
    regs,regression_coverage=run_regressions(d,core)
    save_aggregates("31_adjusted_sample_coverage.csv",regression_coverage)
    save_aggregates("31_wave_metadata_audit.csv",audit)
    save_aggregates("31_realization_response_coverage.csv",coverage)
    save_aggregates("31_forecast_by_realization_saving_cells.csv",cells)
    save_aggregates("31_forecast_realization_FE_contrasts.csv",regs)
    println("="^115)
    println("INTERPRETATION")
    println("* Realized=fisitc at next interview: retrospectively REPORTED financial change,")
    println("  NOT verified objective income or an exogenous shock.")
    println("* Δ saving = next reported saver indicator minus current reported saver indicator.")
    println("* Conditional FE contrasts are within-person associations, not causal effects.")
    println("* Conditioning on a future realization can introduce post-treatment/collider bias.")
    println("* These are standalone diagnostic samples and person-clustered standard errors.")
    println("  Do NOT substitute these coefficients for the manuscript's stratified PSU results.")
    println("* No respondent-level records were exported to Dropbox.")
    println("DONE")
end

end # module

# Julia 1.12: enter the newly defined module method in the latest world.
Base.invokelatest(BHPSForecastRealizationSaving.main)
