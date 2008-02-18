#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'gtkglext'
require 'gnome2'
require 'lib/widgets.rb'
require 'lib/gl_view.rb'
require 'lib/op_view.rb'
require 'lib/project_manager.rb'
require 'lib/geometry.rb'
require 'lib/about_dialog.rb'
require 'lib/new_dialog.rb'
require 'lib/open_project_dialog.rb'
require 'lib/server_win.rb'

class OpenMachinistMainWin < Gtk::Window
	def initialize
		super
		self.title = "Untitled project - Open Machinist"
		self.reallocate_redraws = true
		self.window_position = Gtk::Window::POS_CENTER
		signal_connect('destroy'){Gtk.main_quit}
		op_view = OpView.new
		glview = GLView.new
		assembly_toolbar = Gtk::Toolbar.new
		part_toolbar = Gtk::Toolbar.new
		sketch_toolbar = Gtk::Toolbar.new
		statusbar = Gtk::Statusbar.new
		@main_vbox = Gtk::VBox.new( false )
		@op_view_controls = Gtk::HBox.new
		@manager = ProjectManager.new( self, op_view, glview, assembly_toolbar, part_toolbar, sketch_toolbar, statusbar, @main_vbox, @op_view_controls )
		op_view.manager = @manager
		signal_connect("key-press-event"  ){|w,e| @manager.key_pressed e.keyval }
		signal_connect("key-release-event"){|w,e| @manager.key_released e.keyval }
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
			["/_File"],
				["/File/New project...",  "<StockItem>", nil, Gtk::Stock::NEW,  Proc.new{ NewProjectDialog.new @manager }],
				["/File/Open project...",         "<StockItem>", nil, Gtk::Stock::OPEN, Proc.new{ OpenProjectDialog.new @manager }],
				["/File/_Save project",           "<StockItem>", nil, Gtk::Stock::SAVE, Proc.new{ @manager.save_file }],
				["/File/Save project as...",      "<StockItem>", nil, Gtk::Stock::SAVE, Proc.new{ @manager.save_file_as }],
				["/File/sep1", "<Separator>"],
				["/File/Project information...", "<StockItem>", nil, Gtk::Stock::INFO, Proc.new{ @manager.display_properties }],
				["/File/Make project public", "<StockItem>", nil, Gtk::Stock::NETWORK, Proc.new{ @manager.make_project_public }],
				["/File/sep1", "<Separator>"],
				["/File/Print...",        "<StockItem>", nil, Gtk::Stock::PRINT_PREVIEW,Proc.new{}],
				["/File/sep2", "<Separator>"],
				["/File/Quit",            "<StockItem>", nil, Gtk::Stock::QUIT, Proc.new{ Gtk.main_quit }],
			["/_Edit"],
				["/Edit/Undo",        "<StockItem>", nil, Gtk::Stock::UNDO,  Proc.new{}],
				["/Edit/Redo",        "<StockItem>", nil, Gtk::Stock::REDO,  Proc.new{}],
				["/Edit/sep4", "<Separator>"],
				["/Edit/Copy",        "<StockItem>", nil, Gtk::Stock::COPY,  Proc.new{}],
				["/Edit/Paste",       "<StockItem>", nil, Gtk::Stock::PASTE,  Proc.new{}],
				["/Edit/Delete",      "<StockItem>", nil, Gtk::Stock::DELETE,  Proc.new{}],
				["/Edit/sep4", "<Separator>"],
				["/Edit/Preferences", "<StockItem>", nil, Gtk::Stock::PREFERENCES,  Proc.new{}],
			["/_View"],
				["/View/Front",         "<Item>", nil, nil, Proc.new{}],
				["/View/Back",          "<Item>", nil, nil, Proc.new{}],
				["/View/Right",         "<Item>", nil, nil, Proc.new{}],
				["/View/Left",          "<Item>", nil, nil, Proc.new{}],
				["/View/Top",           "<Item>", nil, nil, Proc.new{}],
				["/View/Bottom",        "<Item>", nil, nil, Proc.new{}],
				["/View/Isometric",     "<Item>", nil, nil, Proc.new{}],
				["/View/sep4", "<Separator>"],
				["/View/Show working planes", "<CheckItem>", nil, nil, Proc.new{}],
				["/View/Diagnostic shading",  "<CheckItem>", nil, nil, Proc.new{}],			
				["/View/Render shadows",      "<CheckItem>", nil, nil, Proc.new{}],
			["/_Tools"],
				["/Tools/Measure distance", "<Item>", nil, nil, Proc.new{ @manager.activate_tool('measure_distance') }],
				["/Tools/Measure area",     "<Item>", nil, nil, Proc.new{}],
				["/Tools/Measure angle",    "<Item>", nil, nil, Proc.new{}],
				["/Tools/sep4", "<Separator>"],
				["/Tools/Analyze interference",      "<Item>", nil, nil, Proc.new{}],
				["/Tools/Display center of gravity", "<CheckItem>", nil, nil, Proc.new{}],
				["/Tools/Bill of materials",         "<Item>", nil, nil, Proc.new{}],
				["/Tools/sep4", "<Separator>"],
				["/Tools/Material editor",  "<Item>", nil, nil, Proc.new{ @manager.show_material_editor }],
			["/_Simulation"],
				["/Simulation/Update constraints",                   "<Item>", nil, nil, Proc.new{}],
				["/Simulation/Update sub-assembly constraints",      "<Item>", nil, nil, Proc.new{}],
				["/Simulation/sep4", "<Separator>"],
				["/Simulation/Auto-update constraints",              "<CheckItem>", nil, nil, Proc.new{}],
				["/Simulation/Auto-update sub-assembly constraints", "<CheckItem>", nil, nil, Proc.new{}],
				["/Simulation/sep4", "<Separator>"],
				["/Simulation/Activate contact solver",              "<CheckItem>", nil, nil, Proc.new{}],
				["/Simulation/Define contact set...",                "<Item>", nil, nil, Proc.new{ @manager.display_contact_set }],
			["/_Help"],
				["/Help/_About Open Machinist", "<Item>", nil, nil, Proc.new{ about = Gnome::About.new('Open Machinist', '0.1',
                         										   										    'Copyright (c) 2006 Elektrokultur',
                         										 										      'A parametrical, 3D, mechanical design application',
                         										 										      ['Bjoern Breitgoff <breidibreit@web.de>'], [], nil)
                         										 					                about.logo = Gdk::Pixbuf.new('icons/big/assembly.png')
                         										 					                about.show
                                                                     # Gtk::AboutDialog.show(self, {:name => "Open Machinist", :authors => ["Björn Breitgoff"], 
                                                                     #                              :copyright => "Copyright (c) 2006 Elektrokultur", 
                                                                     #                              :logo => Gdk::Pixbuf.new('icons/search.png'),
                                                                     #                              :version => "0.1"})
																						  }
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
		toolbar.toolbar_style = Gtk::Toolbar::BOTH
		toolbar.icon_size = Gtk::IconSize::SMALL_TOOLBAR
		hbox.pack_start(toolbar, false, true)
		toolbar.append( "New", "Create a new project, part or assembly", "Toolbar/New", Gtk::Image.new('icons/big/new.png') ){ NewDialog.new @manager }
		toolbar.append( "Save", "Save current part or assembly", "Toolbar/Save", Gtk::Image.new('icons/big/save.png') ){ @manager.save_file }
		toolbar.append( Gtk::SeparatorToolItem.new){}
		select_button = Gtk::MenuToolButton.new( Gtk::Image.new( 'icons/big/list-add.png' ), 'Select' )
		toolbar.append( select_button, "Choose selection mode" ){ @manager.activate_tool 'select' }
		return_btn = toolbar.append( "Return", "Work on parent assembly","Toolbar/Return", Gtk::Image.new('icons/big/undo.png') ){ @manager.working_level_up }
		return_btn.sensitive = false
		@manager.return_btn = return_btn
		toolbar.append( Gtk::SeparatorToolItem.new){}
		toolbar.append( "Camera", "Position the 3d viewpoint","Toolbar/Camera", Gtk::Image.new('icons/big/camera.png') ) {@manager.activate_tool('camera') }
		toolbar.append( "Zoom selection", "Fit all selected objects into view","Toolbar/ZoomAll", Gtk::Image.new('icons/big/search.png') ){}
		toolbar.append( "Look at", "Make view orthogonal to selected plane","Toolbar/ViewSelected", Gtk::Image.new('icons/big/look_at.png') ){glview.look_at_selection}
		toolbar.append( Gtk::SeparatorToolItem.new ){}
		previous_btn = toolbar.append( "Previous", "Previous camera location","Toolbar/Previous", Gtk::Image.new('icons/big/go-previous.png') ){ glview.previous_view }
		previous_btn.sensitive = false
		@manager.previous_btn = previous_btn
		next_btn = toolbar.append( "Next", "Next camera location","Toolbar/Next", Gtk::Image.new('icons/big/go-next.png') ){ glview.next_view }
		next_btn.sensitive = false
		@manager.next_btn = next_btn
		toolbar.append( Gtk::SeparatorToolItem.new ){}
		toolbar.append( Gtk::MenuToolButton.new( Gtk::Image.new( 'icons/big/information.png' ), 'Shading' ), "Select shading mode for the viewport" ){}
		focus_btn = Gtk::ToggleToolButton.new
		focus_btn.icon_widget = Gtk::Image.new('icons/big/focus.png').show
		focus_btn.label = "Focus"
		focus_btn.active = true
		focus_btn.signal_connect("toggled") do |b| 
		  @manager.focus_view = b.active?
		  @manager.main_assembly.transparent = @manager.focus_view
  		@manager.work_component.transparent = false
  		glview.redraw
		end
		toolbar.append( focus_btn, "Make all components except the current one transparent" ){}
		hbox.pack_end( SearchEntry.new(@manager), false, true )
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
		up_btn.image = Gtk::Image.new 'icons/small/up_small.png'
		up_btn.set_size_request( 30, 30 )
		up_btn.signal_connect("clicked"){|w,e| @manager.move_selected_operator_up }
		@op_view_controls.pack_start up_btn
		down_btn = Gtk::Button.new
		down_btn.image = Gtk::Image.new 'icons/small/down_small.png'
		down_btn.set_size_request( 30, 30 )
		down_btn.signal_connect("clicked"){|w,e| @manager.move_selected_operator_down }
		@op_view_controls.pack_start down_btn
		enable_btn = Gtk::Button.new
		enable_btn.image = Gtk::Image.new 'icons/small/wheel_small.png'
		enable_btn.set_size_request( 30, 30 )
		enable_btn.signal_connect("clicked"){|w,e| @manager.enable_selected_operator }
		@op_view_controls.pack_start enable_btn
		delete_btn = Gtk::Button.new
		delete_btn.image = Gtk::Image.new 'icons/small/delete_small.png'
		delete_btn.set_size_request( 30, 30 )
		delete_btn.signal_connect("clicked"){|w,e| @manager.delete_op_view_selected }
		@op_view_controls.pack_start delete_btn
		vbox.pack_start( @op_view_controls, false )
		hpaned.pack1(vbox,false,true)
		# create main display area
		hpaned.pack2(@main_vbox,true,true)
		@main_vbox.pack_start(glview, true, true)
###                                                                  ###
######---------------------- Lower toolbars ----------------------######
###                                                                  ###
		assembly_toolbar.toolbar_style = Gtk::Toolbar::BOTH
		assembly_toolbar.icon_size = Gtk::IconSize::SMALL_TOOLBAR
		@main_vbox.pack_start(assembly_toolbar, false, true)
		assembly_toolbar.append( "Insert", "Insert an existing component","AssemblyToolbar/Insert", Gtk::Image.new('icons/big/part.png') ){}
		assembly_toolbar.append( "Library", "Insert a library part","AssemblyToolbar/Lib", Gtk::Image.new('icons/big/assembly.png') ){}
		assembly_toolbar.append( Gtk::SeparatorToolItem.new )
		assembly_toolbar.append( "Constrain", "Define a relation between two components", "AssemblyToolbar/Constrain", Gtk::Image.new('icons/big/constrain.png') ){}
		assembly_toolbar.append( "Contacts", "Define contact set for current assembly", "AssemblyToolbar/Contact", Gtk::Image.new('icons/big/contacts.png') ){ @manager.display_contact_set }
		assembly_toolbar.append( "Spring", "Insert a simulated spring", "AssemblyToolbar/Spring", Gtk::Image.new('icons/big/spring.png') ){}
		assembly_toolbar.append( "Belt", "Create a (tooth)belt", "AssemblyToolbar/Belt", Gtk::Image.new('icons/big/belt.png') ){}
		assembly_toolbar.append( "Animate", "Induce motion into assembly", "AssemblyToolbar/Animate", Gtk::Image.new('icons/big/wheel.png') ){}
		assembly_toolbar.append( Gtk::SeparatorToolItem.new )
		assembly_toolbar.append( "Grid pattern", "Duplicate assembly in a 1/2/3 dimensional grid", "AssemblyToolbar/Grid", Gtk::Image.new('icons/big/assembly.png') ){}
		assembly_toolbar.append( "Circular pattern", "Duplicate assembly with a radial offset", "AssemblyToolbar/Circular", Gtk::Image.new('icons/big/circular.png') ){}
		assembly_toolbar.append( "Mirror", "Mirror assembly along a plane", "AssemblyToolbar/Mirror", Gtk::Image.new('icons/big/mirror.png') ){}
		part_toolbar.toolbar_style = Gtk::Toolbar::BOTH
		part_toolbar.icon_size = Gtk::IconSize::SMALL_TOOLBAR
		@main_vbox.pack_start(part_toolbar, false, true)
		part_toolbar.append( "Sketch", "Sketch on selected plane","Toolbar/Sketch", Gtk::Image.new('icons/big/sketch.png') ){@manager.new_sketch}
		part_toolbar.append( Gtk::SeparatorToolItem.new )
		part_toolbar.append( "Extrude", "Extrude sketch", "PartToolbar/Extrude", Gtk::Image.new('icons/big/extrude.png') ){ @manager.add_operator('extrude')}
		part_toolbar.append( "Revolve", "Rotate a sketch around an axis to produce geometry", "PartToolbar/Revolve", Gtk::Image.new('icons/big/revolve.png') ){}
		part_toolbar.append( "Hole", "Drill hole", "PartToolbar/Hole", Gtk::Image.new('icons/hole.png') ){}
		part_toolbar.append( "Shell", "Shell out solid", "PartToolbar/Shell", Gtk::Image.new('icons/big/shell.png') ){}
		part_toolbar.append( "Loft", "Connect several sketches with a surface", "PartToolbar/Loft", Gtk::Image.new('icons/big/loft.png') ){}
		part_toolbar.append( "Sweep", "Sweep sketch along path", "PartToolbar/Sweep", Gtk::Image.new('icons/big/sweep.png') ){}
		part_toolbar.append( "Coil", "Extrude sketch in a coiled fashion", "PartToolbar/Coil", Gtk::Image.new('icons/big/coil.png') ){}
		part_toolbar.append( Gtk::SeparatorToolItem.new )
		part_toolbar.append( "Fillet", "Fillet edge", "PartToolbar/Filet", Gtk::Image.new('icons/big/fillet.png') ){}
		part_toolbar.append( "Chamfer", "Chamfer ege", "PartToolbar/Chamfer", Gtk::Image.new('icons/big/chamfer.png') ){}
		part_toolbar.append( "Draft", "Draft faces", "PartToolbar/Draft", Gtk::Image.new('icons/big/draft.png') ){}
		part_toolbar.append( Gtk::SeparatorToolItem.new )
		part_toolbar.append( "Grid pattern", "Duplicate feature in a 1/2/3 dimensional grid", "PartToolbar/Grid", Gtk::Image.new('icons/big/assembly.png') ){}
		part_toolbar.append( "Circular pattern", "Duplicate feature with a radial offset", "PartToolbar/Circular", Gtk::Image.new('icons/big/circular.png') ){}
		part_toolbar.append( "Mirror", "Mirror feature along a plane", "PartToolbar/Mirror", Gtk::Image.new('icons/big/mirror.png') ){}
		sketch_toolbar.toolbar_style = Gtk::Toolbar::ICONS
		sketch_toolbar.icon_size = Gtk::IconSize::SMALL_TOOLBAR
		@main_vbox.pack_start(sketch_toolbar, false, true)
		line_button = Gtk::MenuToolButton.new( Gtk::Image.new( 'icons/big/list-remove.png' ), 'Line' )
		line_button.signal_connect('clicked'){ @manager.activate_tool('line', true) }
		sketch_toolbar.append( line_button, "Line tool" )
		sketch_toolbar.append( Gtk::MenuToolButton.new( Gtk::Image.new( 'icons/big/circle.png' ),    'Circle' ) )    { @manager.activate_tool('circle') }
		sketch_toolbar.append( Gtk::MenuToolButton.new( Gtk::Image.new( 'icons/big/arc.png' ),       'Arc' ) )       { @manager.activate_tool('arc') }
		sketch_toolbar.append( Gtk::MenuToolButton.new( Gtk::Image.new( 'icons/big/rectangle.png' ), 'Rectangle' ) ) { @manager.activate_tool('rectangle') }
		sketch_toolbar.append( Gtk::MenuToolButton.new( Gtk::Image.new( 'icons/big/fillet.png' ),    'Fillet' ) )    { @manager.activate_tool('fillet') }
		sketch_toolbar.append( "Polygon", "Create regular convex polygon with variable number of segments", "SketchToolbar/Polygon", Gtk::Image.new('icons/big/polygon.png') ){}
		sketch_toolbar.append( Gtk::SeparatorToolItem.new )
		sketch_toolbar.append( "Dimension", "Add dimensions to the sketch", "SketchToolbar/Dimension", Gtk::Image.new('icons/big/dimension.png') ){}
		sketch_toolbar.append( "Constrain", "Constrain the sketch", "SketchToolbar/Constrain", Gtk::Image.new('icons/big/constrain.png') ){}
		sketch_toolbar.append( Gtk::SeparatorToolItem.new )
		sketch_toolbar.append( "Trim", "Cut away parts of a segment", "SketchToolbar/Trim", Gtk::Image.new('icons/big/trim.png') ){}
		sketch_toolbar.append( Gtk::SeparatorToolItem.new )
		sketch_toolbar.append( "Project", "Project external features onto the sketch plane", "SketchToolbar/Project", Gtk::Image.new('icons/big/look_at.png') ){}
		sketch_toolbar.append( Gtk::SeparatorToolItem.new )
		sketch_toolbar.append( "Grid pattern", "Duplicate segments in a 1/2/3 dimensional grid", "SketchToolbar/Grid", Gtk::Image.new('icons/big/assembly.png') ){}
		sketch_toolbar.append( "Circular pattern", "Duplicate segments with a radial offset", "SketchToolbar/Circular", Gtk::Image.new('icons/big/circular.png') ){}
		sketch_toolbar.append( "Mirror", "Mirror segments along an axis", "SketchToolbar/Mirror", Gtk::Image.new('lib/big/icons/mirror.png') ){}
		sketch_toolbar.append( "Offset", "Offset segments with a constant distance", "SketchToolbar/Offset", Gtk::Image.new('icons/big/offset.png') ){}
		# hide unneeded toolbars as soons as we are drawn
		self.signal_connect_after('realize'){ @manager.assembly_toolbar; @op_view_controls.hide }
		# create Statusbar
		main_box.pack_start(statusbar, false, true)
	end
end







