# This file is a part of Julia. License is MIT: https://julialang.org/license

@eval(Main, module JuliaTestEnv
        if haskey(ENV, "JULIA_TEST_EXEFLAGS")
            const exeflags = `$(Base.shell_split(ENV["JULIA_TEST_EXEFLAGS"]))`
        else
            inline_flag = Base.JLOptions().can_inline == 1 ? `` : `--inline=no`
            cov_flag = ``
            if Base.JLOptions().code_coverage == 1
                cov_flag = `--code-coverage=user`
            elseif Base.JLOptions().code_coverage == 2
                cov_flag = `--code-coverage=all`
            end
            const exeflags = `$cov_flag $inline_flag --check-bounds=yes --startup-file=no --depwarn=error`
        end

        if haskey(ENV, "JULIA_TEST_EXENAME")
            const exename = `$(Base.shell_split(ENV["JULIA_TEST_EXENAME"]))`
        else
            const exename = `$(joinpath(JULIA_HOME, Base.julia_exename()))`
        end

        addprocs(X; kwargs...) = Base.addprocs(X; exename=exename, exeflags=exeflags, kwargs...)
    end)

function runtests(name, isolate=true)
    old_print_setting = Base.Test.TESTSET_PRINT_ENABLE[]
    Base.Test.TESTSET_PRINT_ENABLE[] = false
    try
        if isolate
            # Simple enough to type and random enough so that no one will hard
            # code it in the test
            mod_name = Symbol("Test", rand(1:100), "Main_", replace(name, '/', '_'))
            m = @eval(Main, module $mod_name end)
        else
            m = Main
        end
        @eval(m, import JuliaTestEnv)
        @eval(m, using Base.Test)
        ex = quote
            @timed @testset $"$name" begin
                include($"$name.jl")
            end
        end
        res_and_time_data = eval(m, ex)
        rss = Sys.maxrss()
        #res_and_time_data[1] is the testset
        passes,fails,error,broken,c_passes,c_fails,c_errors,c_broken = Base.Test.get_test_counts(res_and_time_data[1])
        if res_and_time_data[1].anynonpass == false
            res_and_time_data = (
                                 (passes+c_passes,broken+c_broken),
                                 res_and_time_data[2],
                                 res_and_time_data[3],
                                 res_and_time_data[4],
                                 res_and_time_data[5])
        end
        vcat(collect(res_and_time_data), rss)
    finally
        Base.Test.TESTSET_PRINT_ENABLE[] = old_print_setting
    end
end

# looking in . messes things up badly
filter!(x->x!=".", LOAD_PATH)

nothing # File is loaded via a remotecall to "include". Ensure it returns "nothing".
