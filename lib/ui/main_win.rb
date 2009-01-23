#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'gtkglext'
require 'gnome2'
require 'preferences.rb'
require 'widgets.rb'
require 'gl_view.rb'
require 'op_view.rb'
require 'manager.rb'
require 'geometry.rb'
require 'ui/about_dialog.rb'
require 'ui/new_dialog.rb'
require 'ui/component_browser.rb'
require 'ui/open_project_dialog.rb'
require 'ui/server_win.rb'
require 'ui/render_dialog.rb'

class SolidMatterMainWin < Gtk::Window
  def initialize
    super
    Gtk::Window.set_default_icon_list [Gdk::Pixbuf.new('../data/icons/small/preferences-system_small.png'), Gdk::Pixbuf.new('../data/icons/big/tools.png')]
    self.reallocate_redraws = true
    self.window_position = Gtk::Window::POS_CENTER
    op_view = OpView.new
    glview = GLView.new
    render_image = Gtk::Image.new
    render_view = Gtk::ScrolledWindow.new
    render_view.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
    render_view.add_with_viewport render_image
    assembly_toolbar = Gtk::Toolbar.new
    part_toolbar = Gtk::Toolbar.new
    sketch_toolbar = Gtk::Toolbar.new
    statusbar = Gtk::Statusbar.new
    @main_vbox = Gtk::VBox.new( false )
    @op_view_controls = Gtk::HBox.new
    Manager.new( self, op_view, glview, render_view, render_image, assembly_toolbar, part_toolbar, sketch_toolbar, statusbar, @main_vbox, @op_view_controls )
    signal_connect('delete-event') do
      CloseProjectConfirmation.new do |response|
        case response
          when :save then $manager.save_file and quit
          when :close then quit
        end
      end
    end
    op_view.manager = $manager
    signal_connect("key-press-event"  ){|w,e| $manager.key_pressed e.keyval }
    signal_connect("key-release-event"){|w,e| $manager.key_released e.keyval }
    # build interface
    main_box = Gtk::VBox.new(false)
    add(main_box)
###                                                                 ###
######---------------------- Main menu bar ----------------------######
###                                                                 ###
    accel_group = Gtk::AccelGroup.new
    add_accel_group(accel_group)
    item_factory = Gtk::ItemFactory.new(Gtk::ItemFactory::TYPE_MENU_BAR, '<main>', accel_group)
    # create menu items
    menu_items = [
      [GetText._("/_File")],
        [GetText._("/File/New project..."),          "<StockItem>", nil, Gtk::Stock::NEW,  lambda{ NewProjectDialog.new }],
        [GetText._("/File/Open project..."),         "<StockItem>", nil, Gtk::Stock::OPEN, lambda{ OpenProjectDialog.new }],
        [GetText._("/File/_Save project"),           "<StockItem>", nil, Gtk::Stock::SAVE, lambda{ $manager.save_file }],
        [GetText._("/File/Save project as..."),      "<StockItem>", nil, Gtk::Stock::SAVE, lambda{ $manager.save_file_as }],
        [GetText._("/File/Export selection..."),     "<StockItem>", nil, Gtk::Stock::SAVE, lambda{ $manager.export_selection }],
        [GetText._("/File/sep1"), "<Separator>"],
        [GetText._("/File/Project information"),    "<StockItem>", nil, Gtk::Stock::INFO, lambda{ $manager.project.display_properties }],
        [GetText._("/File/Make project public..."), "<StockItem>", nil, Gtk::Stock::NETWORK, lambda{ $manager.make_project_public }],
        [GetText._("/File/sep1"), "<Separator>"],
        [GetText._("/File/Print..."), "<StockItem>", nil, Gtk::Stock::PRINT_PREVIEW, lambda{}],
        [GetText._("/File/sep2"), "<Separator>"],
        [GetText._("/File/Quit"), "<StockItem>", nil, Gtk::Stock::QUIT, lambda{ quit }],
      [GetText._("/_Edit")],
        [GetText._("/Edit/Undo"),        "<StockItem>", nil, Gtk::Stock::UNDO,  lambda{}],
        [GetText._("/Edit/Redo"),        "<StockItem>", nil, Gtk::Stock::REDO,  lambda{}],
        [GetText._("/Edit/sep4"), "<Separator>"],
        [GetText._("/Edit/Cut"),         "<StockItem>", nil, Gtk::Stock::CUT,  lambda{ $manager.cut_to_clipboard }],
        [GetText._("/Edit/Copy"),        "<StockItem>", nil, Gtk::Stock::COPY,  lambda{ $manager.copy_to_clipboard }],
        [GetText._("/Edit/Paste"),       "<StockItem>", nil, Gtk::Stock::PASTE,  lambda{ $manager.paste_from_clipboard }],
        [GetText._("/Edit/Delete"),      "<StockItem>", nil, Gtk::Stock::DELETE,  lambda{ $manager.delete_selected }],
        [GetText._("/Edit/sep4"), "<Separator>"],
        [GetText._("/Edit/Preferences"), "<StockItem>", nil, Gtk::Stock::PREFERENCES,  lambda{ PreferencesDialog.new }],
      [GetText._("/_View")],
        [GetText._("/View/Front"),         "<Item>", nil, nil, lambda{}],
        [GetText._("/View/Back"),          "<Item>", nil, nil, lambda{}],
        [GetText._("/View/Right"),         "<Item>", nil, nil, lambda{}],
        [GetText._("/View/Left"),          "<Item>", nil, nil, lambda{}],
        [GetText._("/View/Top"),           "<Item>", nil, nil, lambda{}],
        [GetText._("/View/Bottom"),        "<Item>", nil, nil, lambda{}],
        [GetText._("/View/Isometric"),     "<Item>", nil, nil, lambda{}],
        [GetText._("/View/sep4"), "<Separator>"],
        [GetText._("/View/Stereo vision"),       "<CheckItem>", nil, nil, lambda{|e,w| $manager.glview.stereo = w.active? }],
        [GetText._("/View/Diagnostic shading"),  "<CheckItem>", nil, nil, lambda{}],      
        [GetText._("/View/Render shadows"),      "<CheckItem>", nil, nil, lambda{|e,w| $manager.glview.render_shadows = w.active? }],
        [GetText._("/View/sep4"), "<Separator>"],
        [GetText._("/View/Fullscreen"),   "<StockItem>", nil, Gtk::Stock::FULLSCREEN,  lambda{ @fullscreen ? (self.unfullscreen and @fullscreen = false) : (self.fullscreen and @fullscreen = true) }],
      [GetText._("/_Tools")],
        [GetText._("/Tools/Measure distance"), "<Item>", nil, nil, lambda{ $manager.activate_tool('measure_distance') }],
        [GetText._("/Tools/Measure area"),     "<Item>", nil, nil, lambda{}],
        [GetText._("/Tools/Measure angle"),    "<Item>", nil, nil, lambda{}],
        [GetText._("/Tools/sep4"), "<Separator>"],
        [GetText._("/Tools/Analyze interference"),      "<Item>", nil, nil, lambda{}],
        [GetText._("/Tools/Bill of materials"),         "<Item>", nil, nil, lambda{}],
        [GetText._("/Tools/sep4"), "<Separator>"],
        [GetText._("/Tools/Material editor"),  "<Item>", nil, nil, lambda{ $manager.show_material_editor }],
      [GetText._("/_Simulation")],
        [GetText._("/Simulation/Update constraints"),                   "<Item>", nil, nil, lambda{}],
        [GetText._("/Simulation/Update sub-assembly constraints"),      "<Item>", nil, nil, lambda{}],
        [GetText._("/Simulation/sep4"), "<Separator>"],
        [GetText._("/Simulation/Auto-update constraints"),              "<CheckItem>", nil, nil, lambda{}],
        [GetText._("/Simulation/Auto-update sub-assembly constraints"), "<CheckItem>", nil, nil, lambda{}],
        [GetText._("/Simulation/sep4"), "<Separator>"],
        [GetText._("/Simulation/Activate contact solver"),              "<CheckItem>", nil, nil, lambda{}],
        [GetText._("/Simulation/Define contact set..."),                "<Item>", nil, nil, lambda{ $manager.display_contact_set }],
      [GetText._("/_Render")],
        [GetText._("/Render/Render..."),                   "<Item>", nil, nil, lambda{ @render_dia = RenderDialog.new }],
        [GetText._("/Render/Save current image..."),       "<Item>", nil, nil, lambda{ @render_dia.save_image if @render_dia }],
        [GetText._("/Render/Stop rendering"),              "<Item>", nil, nil, lambda{ @render_dia.stop_rendering if @render_dia }],
      [GetText._("/_Help")],
        [GetText._("/Help/_About Solid|matter"), "<StockItem>", nil, Gtk::Stock::ABOUT, lambda{ AboutDialog.new }
        ] 
    ]
    # create menuitems and attach them to the main window
    item_factory.create_items(menu_items)
    main_box.pack_start(item_factory.get_widget('<main>'), false, true)
###                                                                ###
######---------------------- Main toolbar ----------------------######
###                                                                ###
    hbox = Gtk::HBox.new(false)
    main_box.pack_start(hbox, false, true)
    toolbar = Gtk::Toolbar.new
    toolbar.show_arrow = true
    #toolbar.toolbar_style = Gtk::Toolbar::BOTH
    toolbar.icon_size = Gtk::IconSize::SMALL_TOOLBAR
    hbox.pack_start(toolbar, false, true)
    new_btn = Gtk::ToolButton.new( Gtk::Image.new(Gtk::Stock::NEW, Gtk::IconSize::SMALL_TOOLBAR), GetText._(" New") )
    new_btn.important = true
    new_btn.signal_connect("clicked"){ NewDialog.new }
    toolbar.append( new_btn, GetText._("Create a new project, part or assembly"), "Toolbar/New" )
    save_btn = Gtk::ToolButton.new( Gtk::Image.new(Gtk::Stock::SAVE, Gtk::IconSize::SMALL_TOOLBAR), GetText._(" Save") )
    save_btn.sensitive = false
    save_btn.important = false
    save_btn.signal_connect("clicked"){ $manager.save_file }
    toolbar.append( save_btn, GetText._("Save current part or assembly"), "Toolbar/Save" )
    $manager.save_btn = save_btn
    toolbar.append( Gtk::SeparatorToolItem.new){}
    select_button = Gtk::MenuToolButton.new( Gtk::Image.new( '../data/icons/middle/list-add_middle.png' ), GetText._('Select') )
    select_button.signal_connect("clicked"){|b| $manager.activate_tool 'select' }
    toolbar.append( select_button, GetText._("Choose selection mode") )
    return_btn = toolbar.append( GetText._("Return"), GetText._("Work on parent assembly"),"Toolbar/Return", Gtk::Image.new('../data/icons/middle/edit-undo_middle.png') ){ $manager.working_level_up }
    return_btn.sensitive = false
    $manager.return_btn = return_btn
    toolbar.append( Gtk::SeparatorToolItem.new){}
    cam_btn = Gtk::ToolButton.new( Gtk::Image.new('../data/icons/middle/camera_middle.png'), GetText._(" Camera") )
    cam_btn.important = false
    cam_btn.signal_connect("clicked"){$manager.activate_tool('camera', true) }
    toolbar.append( cam_btn, GetText._("Position the 3d viewpoint"), "Toolbar/Camera" )
    zoom_btn = Gtk::ToolButton.new( Gtk::Image.new('../data/icons/middle/system-search_middle.png'), GetText._(" Zoom selection") )
    zoom_btn.important = false
    zoom_btn.signal_connect("clicked"){ $manager.glview.zoom_selection}
    toolbar.append( zoom_btn, GetText._("Fit all selected objects into view"),"Toolbar/ZoomAll" )
    look_btn = Gtk::ToolButton.new( Gtk::Image.new('../data/icons/middle/go-bottom_middle.png'), GetText._(" Look at") )
    look_btn.important = false
    look_btn.signal_connect("clicked"){ glview.look_at_selection }
    toolbar.append( look_btn, GetText._("Make view orthogonal to selected plane"),"Toolbar/ViewSelected" )
    toolbar.append( Gtk::SeparatorToolItem.new ){}
    previous_btn = toolbar.append( GetText._("Previous"), GetText._("Previous camera location"), "Toolbar/Previous", Gtk::Image.new('../data/icons/middle/go-previous_middle.png') ){ glview.previous_view }
    previous_btn.sensitive = false
    $manager.previous_btn = previous_btn
    next_btn = Gtk::ToolButton.new( Gtk::Image.new('../data/icons/middle/go-next_middle.png'), " Next" )
    next_btn.sensitive = false
    look_btn.important = false
    next_btn.signal_connect("clicked"){ glview.next_view }
    toolbar.append( next_btn, GetText._("Next camera location"),"Toolbar/Next" )
    $manager.next_btn = next_btn
    toolbar.append( Gtk::SeparatorToolItem.new ){}
    toolbar.append( ShadingButton.new($manager), GetText._("Select shading mode for the viewport") )
    focus_btn = Gtk::ToggleToolButton.new
    focus_btn.icon_widget = Gtk::Image.new('../data/icons/middle/emblem-important_middle.png').show
    focus_btn.label = GetText._("Focus")
    focus_btn.active = true
    focus_btn.signal_connect("toggled") do |b| 
      $manager.focus_view = b.active?
      $manager.project.main_assembly.transparent = $manager.focus_view
      $manager.work_component.transparent = false
      glview.redraw
    end
    toolbar.append( focus_btn, GetText._("Make all components except the current one transparent") ){}
    hbox.pack_end( SearchEntry.new, false, true )
###                                                                 ###
######---------------------- UI components ----------------------######
###                                                                 ###
    # create horizontal resizer
    hpaned = Gtk::HPaned.new
    main_box.pack_start(hpaned,true,true)
    # pack in OpView
    vbox = Gtk::VBox.new
    vbox.pack_start op_view
    op_view.set_size_request(200,500)
    # ... with controls
    up_btn = Gtk::Button.new
    up_btn.image = Gtk::Image.new '../data/icons/small/up_small.png'
    up_btn.set_size_request( 30, 30 )
    up_btn.signal_connect("clicked"){|w,e| $manager.move_selected_operator_up }
    @op_view_controls.pack_start up_btn
    down_btn = Gtk::Button.new
    down_btn.image = Gtk::Image.new '../data/icons/small/down_small.png'
    down_btn.set_size_request( 30, 30 )
    down_btn.signal_connect("clicked"){|w,e| $manager.move_selected_operator_down }
    @op_view_controls.pack_start down_btn
    enable_btn = Gtk::Button.new
    enable_btn.image = Gtk::Image.new '../data/icons/small/wheel_small.png'
    enable_btn.set_size_request( 30, 30 )
    enable_btn.signal_connect("clicked"){|w,e| $manager.enable_selected_operator }
    @op_view_controls.pack_start enable_btn
    delete_btn = Gtk::Button.new
    delete_btn.image = Gtk::Image.new '../data/icons/small/delete_small.png'
    delete_btn.set_size_request( 30, 30 )
    delete_btn.signal_connect("clicked"){|w,e| $manager.delete_op_view_selected }
    @op_view_controls.pack_start delete_btn
    vbox.pack_start( @op_view_controls, false )
    hpaned.pack1(vbox,false,true)
    # create main display area
    hpaned.pack2(@main_vbox,true,true)
    @main_vbox.pack_start(glview, true, true)
    @main_vbox.pack_start( render_view, true, true )
###                                                                  ###
######---------------------- Lower toolbars ----------------------######
###                                                                  ###
    assembly_toolbar.toolbar_style = Gtk::Toolbar::BOTH
    assembly_toolbar.icon_size = Gtk::IconSize::SMALL_TOOLBAR
    assembly_toolbar.show_arrow = true
    @main_vbox.pack_start(assembly_toolbar, false, false)
    assembly_toolbar.append( GetText._("Insert"), "Insert an existing component","AssemblyToolbar/Insert", Gtk::Image.new('../data/icons/middle/part_middle.png') ){ ComponentBrowser.new }
    assembly_toolbar.append( GetText._("Library"), "Insert a library part","AssemblyToolbar/Lib", Gtk::Image.new('../data/icons/middle/assembly_middle.png') ){}
    assembly_toolbar.append( Gtk::SeparatorToolItem.new )
    assembly_toolbar.append( GetText._("Constrain"), "Define a relation between two components", "AssemblyToolbar/Constrain", Gtk::Image.new('../data/icons/middle/constrain_middle.png') ){}
    assembly_toolbar.append( GetText._("Contacts"), "Define contact set for current assembly", "AssemblyToolbar/Contact", Gtk::Image.new('../data/icons/middle/measure_middle.png') ){ $manager.display_contact_set }
    assembly_toolbar.append( GetText._("Spring"), "Insert a simulated spring", "AssemblyToolbar/Spring", Gtk::Image.new('../data/icons/middle/spring.png') ){}
    assembly_toolbar.append( GetText._("Belt"), "Create a (tooth)belt", "AssemblyToolbar/Belt", Gtk::Image.new('../data/icons/big/belt.png') ){}
    assembly_toolbar.append( GetText._("Animate"), "Induce motion into assembly", "AssemblyToolbar/Animate", Gtk::Image.new('../data/icons/middle/applications-system_middle.png') ){}
    assembly_toolbar.append( Gtk::SeparatorToolItem.new )
    assembly_toolbar.append( GetText._("Grid pattern"), "Duplicate assembly in a 1/2/3 dimensional grid", "AssemblyToolbar/Grid", Gtk::Image.new('../data/icons/middle/assembly_middle.png') ){}
    assembly_toolbar.append( GetText._("Circular pattern"), "Duplicate assembly with a radial offset", "AssemblyToolbar/Circular", Gtk::Image.new('../data/icons/middle/view-refresh_middle.png') ){}
    assembly_toolbar.append( GetText._("Mirror"), "Mirror assembly along a plane", "AssemblyToolbar/Mirror", Gtk::Image.new('../data/icons/middle/align-vertical-center_middle.png') ){}
    part_toolbar.toolbar_style = Gtk::Toolbar::BOTH
    part_toolbar.icon_size = Gtk::IconSize::SMALL_TOOLBAR
    part_toolbar.show_arrow = true
    @main_vbox.pack_start(part_toolbar, false, false)
    part_toolbar.append( GetText._("Sketch"), "Sketch on selected plane","Toolbar/Sketch", Gtk::Image.new('../data/icons/middle/sketch_middle.png') ){$manager.project.new_sketch}
    part_toolbar.append( Gtk::SeparatorToolItem.new )
    part_toolbar.append( GetText._("Extrude"), "Extrude sketch", "PartToolbar/Extrude", Gtk::Image.new('../data/icons/middle/extrude_middle.png') ){ $manager.add_operator('extrude')}
    part_toolbar.append( GetText._("Revolve"), "Rotate a sketch around an axis to produce geometry", "PartToolbar/Revolve", Gtk::Image.new('../data/icons/middle/revolve_middle.png') ){}
    part_toolbar.append( GetText._("Hole"), "Drill hole", "PartToolbar/Hole", Gtk::Image.new('../data/icons/hole.png') ){}
    part_toolbar.append( GetText._("Shell"), "Shell out solid", "PartToolbar/Shell", Gtk::Image.new('../data/icons/big/shell.png') ){}
    part_toolbar.append( GetText._("Loft"), "Connect several sketches with a surface", "PartToolbar/Loft", Gtk::Image.new('../data/icons/big/loft.png') ){}
    part_toolbar.append( GetText._("Sweep"), "Sweep sketch along path", "PartToolbar/Sweep", Gtk::Image.new('../data/icons/big/sweep.png') ){}
    part_toolbar.append( GetText._("Coil"), "Extrude sketch in a coiled fashion", "PartToolbar/Coil", Gtk::Image.new('../data/icons/big/coil.png') ){}
    part_toolbar.append( Gtk::SeparatorToolItem.new )
    part_toolbar.append( GetText._("Fillet"), "Fillet edge", "PartToolbar/Filet", Gtk::Image.new('../data/icons/big/fillet.png') ){}
    part_toolbar.append( GetText._("Chamfer"), "Chamfer ege", "PartToolbar/Chamfer", Gtk::Image.new('../data/icons/big/chamfer.png') ){}
    part_toolbar.append( GetText._("Draft"), "Draft faces", "PartToolbar/Draft", Gtk::Image.new('../data/icons/big/draft.png') ){}
    part_toolbar.append( Gtk::SeparatorToolItem.new )
    part_toolbar.append( GetText._("FEM"), "Analyze physical properties", "PartToolbar/FEM", Gtk::Image.new('../data/icons/middle/extrude_middle.png') ){ $manager.add_operator('fem') }
    part_toolbar.append( Gtk::SeparatorToolItem.new )
    part_toolbar.append( GetText._("Pattern"), "Pattern feature along an axis or in a grid", "PartToolbar/Pattern", Gtk::Image.new('../data/icons/middle/assembly_middle.png') ){}
    sketch_toolbar.toolbar_style = Gtk::Toolbar::ICONS
    sketch_toolbar.icon_size = Gtk::IconSize::SMALL_TOOLBAR
    sketch_toolbar.show_arrow = true
    @main_vbox.pack_start(sketch_toolbar, false, false)
    line_button = Gtk::MenuToolButton.new( Gtk::Image.new( '../data/icons/big/list-remove.png' ), GetText._('Line') )
    line_button.signal_connect('clicked'){ $manager.activate_tool('line', true) }
    sketch_toolbar.append( line_button, GetText._("Line tool") )
    sketch_toolbar.append( GetText._("Spline"), "Draw a freeform curve", "SketchToolbar/Spline", Gtk::Image.new('../data/icons/big/list-remove.png') ){ $manager.activate_tool('spline', true) }
    circle_button = Gtk::MenuToolButton.new( Gtk::Image.new( '../data/icons/big/circle.png' ), GetText._('Circle') )
    circle_button.signal_connect('clicked'){ $manager.activate_tool('circle', true) }
    sketch_toolbar.append( circle_button, GetText._("Circle tool") )
    arc_button = Gtk::MenuToolButton.new( Gtk::Image.new( '../data/icons/big/arc.png' ), GetText._('Arc') )
    arc_button.signal_connect('clicked'){ $manager.activate_tool('arc', true) }
    sketch_toolbar.append( arc_button, GetText._("Arc tool") )
    sketch_toolbar.append( Gtk::MenuToolButton.new( Gtk::Image.new( '../data/icons/big/rectangle.png' ), GetText._('Rectangle') ) ) { $manager.activate_tool('rectangle', true) }
    sketch_toolbar.append( Gtk::MenuToolButton.new( Gtk::Image.new( '../data/icons/big/fillet.png' ),    GetText._('Fillet') ) )    { $manager.activate_tool('fillet', true) }
    sketch_toolbar.append( GetText._("Polygon"), "Create regular convex polygon with variable number of segments", "SketchToolbar/Polygon", Gtk::Image.new('../data/icons/big/polygon.png') ){}
    sketch_toolbar.append( Gtk::SeparatorToolItem.new )
    sketch_toolbar.append( GetText._("Dimension"), "Add dimensions to the sketch", "SketchToolbar/Dimension", Gtk::Image.new('../data/icons/big/list-remove.png') ){ $manager.activate_tool('dimension', true) }
    sketch_toolbar.append( GetText._("Constrain"), "Constrain the sketch", "SketchToolbar/Constrain", Gtk::Image.new('../data/icons/big/constrain.png') ){}
    sketch_toolbar.append( Gtk::SeparatorToolItem.new )
    sketch_toolbar.append( GetText._("Trim"), "Cut away parts of a segment", "SketchToolbar/Trim", Gtk::Image.new('../data/icons/big/trim.png') ){ $manager.activate_tool('trim', true) }
    sketch_toolbar.append( Gtk::SeparatorToolItem.new )
    sketch_toolbar.append( GetText._("Project"), "Project external features onto the sketch plane", "SketchToolbar/Project", Gtk::Image.new('../data/icons/big/look_at.png') ){}
    sketch_toolbar.append( Gtk::SeparatorToolItem.new )
    sketch_toolbar.append( GetText._("Grid pattern"), "Duplicate segments in a 1/2/3 dimensional grid", "SketchToolbar/Grid", Gtk::Image.new('../data/icons/big/assembly.png') ){}
    sketch_toolbar.append( GetText._("Circular pattern"), "Duplicate segments with a radial offset", "SketchToolbar/Circular", Gtk::Image.new('../data/icons/big/circular.png') ){}
    sketch_toolbar.append( GetText._("Mirror"), "Mirror segments along an axis", "SketchToolbar/Mirror", Gtk::Image.new('big/icons/mirror.png') ){}
    sketch_toolbar.append( GetText._("Offset"), "Offset segments with a constant distance", "SketchToolbar/Offset", Gtk::Image.new('../data/icons/big/offset.png') ){}
    # hide unneeded toolbars as soons as we are drawn
    self.signal_connect_after('realize'){ $manager.assembly_toolbar; @op_view_controls.hide }
    # create Statusbar
    main_box.pack_start(statusbar, false, false)
    show_all
    render_view.visible = false
  end
  
  def quit
    @render_dia.stop_rendering if @render_dia
    Gtk.main_quit
  end
end







