
# SQL conf files are ini files...

function parse_ini(f)
    blockname = "default"
    seekstart(f); _data=Dict()
    for line in eachline(f)
        # skip comments and newlines
        occursin(r"^\s*(\n|\#|;)", line) && continue

        occursin(r"\w", line) || continue

        line = chomp(line)

        # parse blockname
        m = match(r"^\s*\[\s*([^\]]+)\s*\]$", line)
        if m !== nothing
            blockname = lowercase(m.captures[1])
            continue
        end

        # parse key/value
        m = match(r"^\s*([^=]*[^\s])\s*=\s*(.*)\s*$", line)
        if m !== nothing
            key::String, values::String = m.captures
            if !haskey(_data, blockname)
                _data[blockname] = Dict(key => parse_line(values))
            else
                merge!(_data[blockname], Dict(key => parse_line(values)))
            end
            continue
        end

        error("invalid syntax on line: $(line)")
    end
    _data
end
