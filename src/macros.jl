# module Macros

using MacroTools: prewalk, postwalk, @capture
import Markdown: Markdown, MD, @md_str
import TOML


struct InfoStr
    str::String
end

function get_help_str(default_config, __module__)
    start_str = "# Automatically generated docs for $(__module__) config."
    help_str_strg = InfoStr[
        InfoStr(start_str)
    ]
    postwalk(default_config) do expr
        expr_str = string(expr)
        if length(expr_str) > 5 && (expr_str[1:5] == "help\"" || expr_str[1:5] == "info\"")
            push!(help_str_strg, InfoStr(string(expr)[6:end-1]))
        end
        expr
    end
    md_strs = [Markdown.parse(hs.str) for hs in help_str_strg]
    join(md_strs, "\n")
end

function get_args_and_order(expr)
    arg_order = String[]
    args = Expr[]
    prewalk(expr) do ex
        chk = @capture(ex, k_ => v_)
        if !chk
            ex
        elseif string(v)[1] == '{'
            k_str = string(k)
            v_str = string(v) # strip curly braces
            as, ao = get_args_and_order(Meta.parse(v_str))
            # dict_expr = Meta.parse("Dict(" * v_str * ")")
            dict_str = "Dict("
            for (key, value) in zip(ao, as)
                dict_str *= string(value) * ","
            end
            dict_str *= ")"
            dict_expr = Meta.parse(dict_str)
            push!(arg_order, k_str)
            push!(args, :($k_str=>$dict_expr))
            :(nothing)
        else
            k_str = string(k)
            push!(arg_order, k_str)
            push!(args, :($k_str=>$v))
            ex
        end

    end
    args, arg_order
end

"""
    @generate_config_funcs default_config

Generate a documented function `default_config()` which returns a default configuration Dict
for an experiment. The default configuration Dict is built using the `default_config`
argument, which should have the following form:

    .
    .
    .
    info\"\"\"
    DOCUMENTATION
    \"\"\"
    DICTIONARY ELEMENTS
    .
    .
    .

Where 'DOCUMENTATION' is a documentation for each element included in `DICTIONARY ELEMENTS`.
'DICTIONARY ELEMENTS' is a newline separated list of `key => value` pairs to be included in
the default configuration dictionary. See the Examples section for more detail.

# Examples
```julia-repl
julia> @generate_config_funcs begin
    info\"\"\"
    Experiment details.
    --------------------
    - `seed::Int`: seed of RNG
    - `steps::Int`: Number of steps taken in the experiment
    \"\"\"
    seed => 1
    steps => 200000

    info"\"\"
    Agent details
    -------------
    - `latent_size::Int`: The size of the hidden layers in the RNN.
    \"\"\"
    latent_size => 64

    info\"\"\"
    ### Optimizer details
    Flux optimizers are used. See flux documentation.
    - Parameters defined by the optimizer.
    \"\"\"
    eta => 0.001

    info\"\"\"
    ### Learning update and replay details including:
    - Replay:
        - `replay_size::Int`: How many transitions are stored in the replay.
        - `warm_up::Int`: How many steps for warm-up (i.e. before learning begins).
    \"\"\"
    replay_size => 10000
    warm_up => 1000

    info\"\"\"
    - Update details:
        - `lupdate::String`: Learning update name
        - `gamma::Float`: the discount for learning update.
        - `batch_size::Int`: size of batch
        - `truncation::Int`: Length of sequences used for training.
        - `update_wait::Int`: Time between updates (counted in agent interactions)
        - `target_update_wait::Int`: Time between target network updates (counted in agent interactions)
        - `hs_strategy::String`: Strategy for dealing w/ hidden state in buffer.
    \"\"\"
    update => "QLearningMSE"
    gamma => 1.0
    batch_size=>32
    hist => 1
    epsilon => 0.1
    update_freq => 1
    target_update_wait => 100
end

julia> default_config()
Dict{String, Any} with 13 entries:
  "steps"              => 200000
  "warm_up"            => 1000
  "batch_size"         => 32
  "replay_size"        => 10000
  "eta"                => 0.001
  "hist"               => 1
  "target_update_wait" => 100
  "latent_size"        => 64
  "update"             => "QLearningMSE"
  "update_freq"        => 1
  "epsilon"            => 0.1
  "gamma"              => 1.0
  "seed"               => 1
```
"""
macro generate_config_funcs(default_config)
    func_name = :default_config
    help_func_name = :help
    create_toml_func_name = :create_toml_template
    mdstrings = String[]
    src_file = relpath(String(__source__.file))


    docs = get_help_str(default_config, __module__)
    args, arg_order = get_args_and_order(default_config)

    create_toml_docs = """
        create_toml_template(save_file=nothing; database=false)

    Used to create toml template. If save_file is nothing just return toml string.
    If database is true, then generate using mysql backend otherwise generate using file backend.
    """
    quote
        @doc $(docs)
        function $(esc(func_name))(; kwargs...)
            config = Dict{String, Any}(
                $(args...)
            )
            for (n, v) in kwargs
                config[string(n)] = v
            end
            config
        end

        function $(esc(help_func_name))()
            local docs = Markdown.parse($(docs))
            display(docs)
        end

        function $(esc(create_toml_func_name))(save_file=nothing; database=false)
            local ao = filter((str)->str!="save_dir", $arg_order)
            cnfg = $(esc(func_name))()
            cnfg_filt = filter((p)->p.first != "save_dir", cnfg)
            sv_path = get(cnfg, "save_dir", "<<ADD_SAVE_DIR>>")

            mod = $__module__

            save_info = if database
                """
                save_backend="mysql" # mysql only database backend supported
                database="<<SET DATABASE NAME>>" # Database name
                save_dir="$(sv_path)" # Directory name for exceptions, settings, and more!"""
            else
                """
                save_backend="file" # file saving mode
                file_type = "jld2" # using JLD2 as save type
                save_dir="$(sv_path)" # save location"""
            end

            toml_str = """
            Config generated automatically from default_config. When you have finished
            making changes to this config for your experiment comment out this line.

            info \"\"\"

            \"\"\"

            [config]
            $(save_info)
            exp_file = "$($src_file)"
            exp_module_name = "$(mod)"
            exp_func_name = "main_experiment"
            arg_iter_type = "iter"

            [static_args]
            """
            buf = IOBuffer()

            TOML.print(buf,
                cnfg_filt, sorted=true, by=(str)->findfirst((strinner)->str==strinner, ao)
                       )
            toml_str *= String(take!(buf))

            toml_str *= """\n[sweep_args]
            # Put args to sweep over here.
            """

            if save_file === nothing
                toml_str
            else
                open(save_file, "w") do io
                    write(io, toml_str)
                end
            end

        end
    end
end


"""
    @generate_working_function

Generate a documented function `working_experiment()` which wraps the main experiment
function (`main_experiment()`) of a module and sets the arguments `progress=true` and
`testing=true`, and uses the default experiment configuration (see
[`@generate_config_funcs`](@ref)).
"""
macro generate_working_function()
    quote
        """
            working_experiment

        Creates a wrapper experiment where the main experiment is called with progress=true, testing=true
        and the config is the default_config with the addition of the keyword arguments.
        """
        function $(esc(:working_experiment))(progress=true; kwargs...)
            config = $__module__.default_config(; kwargs...)
            $__module__.main_experiment(config; progress=progress, testing=true)
        end
    end
end

"""
    @param_from param config_dict

Set the value of variable `param` to `config_dict[string(param)]`. There is also the capability to
assign a type (or abstract type) you expect to recieve from the config for the key.

# Examples
```jldoctest; setup = :(import Reproduce: @param_from)
julia> d = Dict(
           "key1" => 1,
           "key2" => 2
       )
Dict{String, Int64} with 2 entries:
  "key2" => 2
  "key1" => 1

julia> @param_from key1 d
1

julia> @param_from key2::Int d
2

julia> println(key1, " ", key2)
1 2

julia> println(key1 + key2)
3
```
"""
macro param_from(param, config_dict)
    
    # param_str = string(param)
    chk = @capture(param, pname_::ptype_)
    param_str, param_type_str = if chk
        string(pname), string(ptype)
    else
        string(param), "Any"
    end
    # chk = @capture(ex, k_ => v_)
    if chk
        quote
            @assert $(param_str) ∈ keys($(esc(config_dict))) "Expected " * $(param_str) * " in config dictionary."
            @assert $(esc(config_dict))[$(param_str)] isa getproperty(Main, Symbol($(param_type_str))) "Expected " * $(param_str) * " to be of type `" * $(param_type_str) * "`."
            $(esc(param)) = $(esc(config_dict))[$(param_str)]
        end
    else
        quote
            @assert $(param_str) ∈ keys($(esc(config_dict))) "Expected $(param_str) in config dictionary."
            $(esc(param)) = $(esc(config_dict))[$(param_str)]
        end
    end
end


macro generate_ann_size_helper(construct_env=:construct_env, construct_agent=:construct_agent)
    const_env_sym = construct_env
    quote
        """
            get_ann_size

        Helper function which constructs the environment and agent using default config and kwargs then returns
        the number of parameters in the model.
        """
        function $(esc(:get_ann_size))(;kwargs...)
            config = $__module__.default_config()
            for (k, v) in kwargs
                config[string(k)] = v
            end
            env = $(esc(const_env_sym))(config, $__module__.Random.GLOBAL_RNG)
            agent = $(esc(construct_agent))(env, config, $__module__.Random.GLOBAL_RNG)
            sum(length, $__module__.Flux.params($__module__.Intrinsic.get_model(agent)))
        end
    end
end



# Lets figure out dataset error logging...
const DATA_SETS = Dict{Symbol, Union{AbstractArray, Dict}}()

function get_dataset(name::Symbol)
    get!(DATA_SETS, name) do
        load_dataset(Val(name))
    end
end
function load_dataset(val::Val)
    throw("Load dataset not implemented")
end

macro declare_dataset(name, load_func)
    quote
        function $__module__.Macros.load_dataset(::Val{$name})
            $(esc(load_func))
        end
    end
end



# end # end Macros
