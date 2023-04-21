import Git

function git_head()
    try
        s = if IN_SLURM()
            read(`git rev-parse HEAD`, String)
        else
            try
                read(`$(Git.git()) rev-parse HEAD`, String)
            catch
                read(`git rev-parse HEAD`, String)
            end
        end
        s[1:end-1]
    catch
        "0"
    end
end

function git_branch()
    try
        s = if IN_SLURM()
            read(`git rev-parse --symbolic-full-name --abbrev-ref HEAD`, String)
        else
            try
                read(`$(Git.git()) rev-parse --symbolic-full-name --abbrev-ref HEAD`, String)
            catch
                read(`git rev-parse --symbolic-full-name --abbrev-ref HEAD`, String)
            end
        end
        s[1:end-1]
    catch
        "0"
    end
end
