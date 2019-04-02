

using Blink
using CSV, DataFrames, Interact, Plots

mutable struct Viewer
    window::Window
    observables::Dict{String, Observable}
    widgets::Dict{String, Widget}
end

function makebuttons(view::Viewer)
    buttons = button.(string.(names(view.observables["data"])))
    for (btn, name) in zip(buttons, names(view.observables["data"]))
        map!(t -> histogram(view.observables["data"][name]), view.observables["plt"], btn)
    end
    dom"div"(hbox(buttons))
end

function makebuttons(df, view)
    buttons = button.(string.(names(df)))
    for (btn, name) in zip(buttons, names(df))
        map!(t -> histogram(df[name]), view.observables["plt"], btn)
    end
    dom"div"(hbox(buttons))
end

function read(dir::String)
    buttons = button.(string.(readdir(dir)))
    dom"div"(vbox(buttons))
end

function Viewer()

    view = Viewer(Window(), Dict{String, Observable}(), Dict{String, Widget}())
    window = view.window
    o = view.observables
    w = view.widgets

    w["loadbutton"] = filepicker()
    o["folder_list"] = Observable{Any}(dom"div"())

    map!(read, o["folder_list"], w["loadbutton"])
    # map!((df) -> makebuttons(df, view), o["columnbuttons"], o["data"])
    ui = dom"div"(w["loadbutton"], o["folder_list"])

    body!(window, ui)

    return view

end


Base.close(v::Viewer) = begin; close(v.window); end


function create_ui()

    # Make a Blink Window
    w = Window()
    ui = button()
    body!(w, ui)
    on(println, ui)

    return w
end


close_ui(w) = close(w)





