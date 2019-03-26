

using Blink
using Interact


mutable struct Viewer
    w::Window
end

function Viewer()

    w = Window()

    ui = button()
    body!(w, ui)
    on(println, ui)

    return Viewer(w)

end

close(v::Viewer) = close(v.w)


function create_ui()

    # Make a Blink Window
    w = Window()
    ui = button()
    body!(w, ui)
    on(println, ui)

    return w
end


close_ui(w) = close(w)





