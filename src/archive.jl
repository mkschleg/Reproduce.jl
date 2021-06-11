

"""
    archive.jl

Archiving functionality so that we can keep number of files small on systems like CC's scratch.

Needs:
    - Incremental archiving
    - Restore when job failure
    - ensuring data never gets corrupted (checking how much time is left in process)
"""




