#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'gtk2'
require 'lib/geometry.rb'
require 'lib/operators.rb'
require 'lib/tools.rb'
require 'lib/multi_user.rb'
require 'lib/material_editor.rb'
require 'lib/project_dialog.rb'
require 'lib/make_public_dialog.rb'
require 'lib/close_project_confirmation.rb'
require 'lib/simulation_settings.rb'

class Selection
	def initialize
		@sel = []
	end
	
	def add( comp )
		comp.selected = true
		comp.build_displaylist if comp.respond_to? :build_displaylist
		@sel.push comp
		@sel.uniq!
	end
	
	def switch( comp )
		if @sel.include? comp
			comp.selected = false
			@sel.delete(comp)
		else
			comp.selected = true
			@sel.push(comp)
		end
		rebuild comp
	end
	
	def subract( comp )
		comp.selected = false
		@sel.delete comp
		rebuild comp
	end
	
	def select( *comps )
		deselect_all
		buildables = []
		@sel = comps
		@sel.each do |c| 
		  c.selected = true 
		  buildables.push( c.is_a?(Segment) ? c.sketch : c )
	  end
	  buildables.uniq.each{|b| rebuild b }
	end
	
	def deselect_all
	  buildables = []
		@sel.each do |c| 
		  c.selected = false
		  buildables.push( c.is_a?(Segment) ? c.sketch : c )
	  end
	  buildables.uniq.each{|b| rebuild b }
		@sel = []
	end
	
	def rebuild( comp )
	  if comp.is_a? Segment
	    comp.sketch.build_displaylist
	  else
	    comp.build_displaylist
	  end
	end
	
	def method_missing( method, *args, &block )
		@sel.send( method, *args, &block )
	end
end

class ProjectManager
	attr_accessor :filename, :focus_view, :materials, :return_btn, :previous_btn, :next_btn,
	              :main_assembly, :all_assemblies, :all_parts, :all_instances, :all_assembly_instances, 
	              :all_part_instances, :all_sketches, :name, :author, :server_win, :main_win,
	              :point_snap, :grid_snap, :use_sketch_guides
	attr_reader :selection, :work_component, :work_sketch, 
	            :glview, :op_view, :has_been_changed, :keys_pressed, :keymap
	def initialize( main_win, op_view, glview, asm_toolbar, prt_toolbar, sketch_toolbar, statusbar, main_vbox, op_view_controls )
	  @main_win = main_win
		@op_view = op_view
		@asm_toolbar = asm_toolbar
		@prt_toolbar = prt_toolbar
		@sketch_toolbar = sketch_toolbar
		@statusbar = statusbar
		@glview = glview
		@glview.manager = self if @glview
		@main_vbox = main_vbox
		@op_view_controls = op_view_controls
		@focus_view = true
		@keys_pressed = []
		@point_snap = true
		@grid_snap = true
		@use_sketch_guides = true
		@server_win = nil
		@materials = [ Material.new("Aluminum"),
                   Material.new("Steel"),
                   Material.new("Copper"),
                   Material.new("Carbon"),
                   Material.new("Glass"),
                   Material.new("Polystyrol"),
                   Material.new("Poly-acryl") ]
    @keymap = { 65505 => :Shift,
                65507 => :Ctrl,
                65406 => :Alt,
                65307 => :Esc,
                65288 => :Backspace,
                65535 => :Del}
	  new_project
	end
	
public
  def project_name
    if @client
      @client.projectname
    else
      @name
    end
  end
  
  def correct_title
    file = @filename ? "(#{@filename})" : "<not saved>"
    previous_dir = Dir.pwd
    Dir.chdir
    file.gsub!( Dir.pwd, '~')
    Dir.chdir previous_dir
    @main_win.title = "#{@has_been_changed ? '*' : ''}#{project_name} #{file} - Open Machinist" if @main_win
  end
  
  def has_been_changed= v
    @has_been_changed = v
    correct_title
  end
  
	def new_project
    @client.exit if @client
    @client = nil
  	@name = "Untitled project"
  	@author = ""
  	@main_assembly = Instance.new( Assembly.new( "Untitled assembly", self ) )
  	@selection = Selection.new
  	@work_component = @main_assembly
  	@work_sketch = nil
  	@all_assemblies         = [@main_assembly]
  	@all_parts              = []
  	@all_instances          = []
  	@all_part_instances     = []
  	@all_assembly_instances = []
  	@all_sketches           = []
  	@colliding_instances    = []
  	@filename = nil
  	self.has_been_changed = false
  	@op_view.set_base_component( @main_assembly ) if @op_view
  	@toolstack = [ PartSelectionTool.new( glview, self ) ] if @glview
  	display_properties if @not_starting_up
  	@not_starting_up = true
	end
	
	def make_project_public
	  MakePublicDialog.new self do |server, port|
  	  @client = ProjectClient.new( server, port, self )
  	  if @client.working
    	  save_file
    	  if @filename and not @client.available_projects.map{|pr| pr.name }.include? @name
          @client.server.add_project self 
          valid = @client.join_project( @name, 'synthetic', 'bla' )
          if not valid
            @client.exit
    	      @client = nil
  	      end
        end
      end
    end
	end
	
	def join_project( server, port, projectname, login, password )
	  @client.exit if @client
	  @client = ProjectClient.new( server, port, self )
	  if @client.working
	    valid = @client.join_project( projectname, login, password ) 
	    if valid
	      self.has_been_changed = false
      else
	      @client.exit
	      @client = nil 
	    end
    end
	end
	
	def component_changed comp
	 @client.component_changed comp if @client
	end
  ###                                                                              ###
  ######---------------------- Creation of new components ----------------------######
  ###             	                                                               ###
	def new_instance( component )
		# make component instance the work component
		instance = Instance.new( component, @work_component )
		@work_component.components.push instance
		@all_instances.push instance
		@all_part_instances.push instance if instance.class == Part
		@all_assembly_instances.push instance if instance.class == Assembly
		change_working_level instance 
		instance.display_properties
	end
	
	def new_part
		# make sure we are inserting into an assembly
		working_level_up while @work_component.class == Part
		# create part and make its instance the work part
		part = Part.new( unique_name( "part" ), self, @glview.add_displaylist, @glview.add_displaylist )
		@all_parts.push part
		new_instance( part )
	end
	
	def new_assembly
		# make sure we are inserting into an assembly
		working_level_up while @work_component.class == Part
		# create assembly and make it the work assembly
		assembly = Assembly.new( unique_name("assembly"), self )
		@all_assemblies.push assembly
		new_instance( assembly )
	end

	def new_sketch
	  # pick plane for sketch
	  activate_tool('plane_select', true) do |plane|
	    if plane
    		# create sketch and make it the work sketch
    		sketch = Sketch.new( unique_name( "sketch" ), @work_component, plane, @glview )
    		@all_sketches.push sketch
    		@work_component.unused_sketches.push( sketch )
    		@op_view.update
    		sketch_mode( sketch )
		  end
	  end
	end
###                                                                 ###
######---------------------- File handling ----------------------######
###                                                                 ###
	def open_file
		dia = Gtk::FileChooserDialog.new("Choose project file",
                                      nil,
                                      Gtk::FileChooser::ACTION_OPEN,
                                      nil,
                                      [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                      [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])
    if dia.run == Gtk::Dialog::RESPONSE_ACCEPT
      @filename = dia.filename
      dia.destroy
      progress = ProgressDialog.new
			File::open( @filename ) do |file|
				scene = Marshal::restore file 
				@main_assembly      = scene[0]
				@all_assemblies     = scene[1]
				@all_parts          = scene[2]
				@all_part_instances = scene[3]
				@all_sketches       = scene[4]
				readd_non_dumpable
				increment = 1.0 / @all_parts.map{|p| p.operators}.flatten.size
				@all_parts.each do |p| 
				  p.build( p.operators.first ){ progress.fraction += increment } if p.operators.first
				  p.working_planes.each{|pl| pl.build_displaylists }
			  end
				@all_sketches.each{|sk| sk.build_displaylist }
			end
			change_working_level @main_assembly 
			progress.close
			self.has_been_changed = false
		else
		  dia.destroy
    end
	end
	
	def save_file_as
	  dia = Gtk::FileChooserDialog.new("Save project as..",
                                      nil,
                                      Gtk::FileChooser::ACTION_SAVE,
                                      nil,
                                      [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                      [Gtk::Stock::SAVE, Gtk::Dialog::RESPONSE_ACCEPT])
		dia.set_property('do-overwrite-confirmation', true)  
    if dia.run == Gtk::Dialog::RESPONSE_ACCEPT
      @filename = dia.filename
			save_file
    end
    dia.destroy
	end
	
	def save_file
	  if @client
	    @client.save_request
    else
  		if @filename
  			File::open( @filename, "w" ) do |file|
  			  strip_non_dumpable
  				Marshal::dump( [@main_assembly, @all_assemblies,	@all_parts, @all_part_instances, @all_sketches], file )
  				readd_non_dumpable  
  			end
  			self.has_been_changed = false
  		else
  			save_file_as
  		end
	  end
	end
	
	def strip_non_dumpable
	  @all_parts.each do |p| 
	    p.manager = nil
	    p.working_planes.each{|pl| pl.glview = nil }
	    p.unused_sketches.each{|sk| sk.glview = nil; sk.plane.glview = nil }
	    p.operators.each do |op|
	      op.manager = nil
	      op.toolbar = nil
	      op.settings[:sketch].glview = nil
      end
	  end
	  @all_assemblies.each{|a| a.manager = nil }
	end
	
	def readd_non_dumpable
	  @all_parts.each do |p| 
	    p.manager = self
	    p.working_planes.each{|pl| pl.glview = @glview }
	    p.unused_sketches.each{|sk| sk.glview = @glview; sk.plane.glview = @glview }
	    p.operators.each do |op|
	      op.manager = self
	      op.create_toolbar
	      op.settings[:sketch].glview = @glview
      end
	  end
	  @all_assemblies.each{|a| a.manager = self }
	end
	
	def close_project_confirmation
	  dialog = Gtk::MessageDialog.new(@main_win, 
                                    Gtk::Dialog::DESTROY_WITH_PARENT,
                                    Gtk::MessageDialog::WARNING,
                                    [Gtk::MessageDialog::BUTTONS_CANCEL, Gtk::MessageDialog::BUTTONS_SAVE],
                                    "Save changes to project '#{project_name}?'")
    dialog.secondary_text = "Your changes will be lost if you don't save them"
    dialog.run
    dialog.destroy
	end
	
  def display_properties
    ProjectInformationDialog.new self
  end
###                                                                                      ###
######---------------------- Working level and mode transitions ----------------------######
###                                                                                      ###
	def change_working_level( component )
	  # display only current part's sketches
	  @work_component.unused_sketches.each{|sk| sk.visible = false } if @work_component.class == Part
	  @work_component = component
	  @work_component.unused_sketches.each{|sk| sk.visible = true } if @work_component.class == Part
	  # make other components transparent
	  @main_assembly.transparent = @focus_view ? true : false
		@work_component.transparent = false
		@selection.deselect_all
		@op_view.set_base_component( @work_component )
		@glview.redraw
		assembly_toolbar if @work_component.class == Assembly
		if @work_component.class == Part
		  part_toolbar 
		  @op_view_controls.show
	  else
	    @op_view_controls.hide
	  end
	  @return_btn.sensitive = (not upmost_working_level?)
		activate_tool 'select'
	end
	
	def working_level_up
		unless exit_current_mode
			parent = @work_component.parent 
			change_working_level( parent ) if parent
		end
	end
	
	def upmost_working_level?
	  @work_component == @main_assembly
	end
	
	# return from drawing or operator mode
	def exit_current_mode
		if @work_sketch
			@work_sketch.plane.visible = false
			op = @work_sketch.op
			op.part.build op if op
			@glview.redraw
			@work_sketch = nil
			part_toolbar
  		activate_tool 'select'
  		@selection.deselect_all
			return true
		elsif @work_operator
			@main_vbox.remove( @work_operator.toolbar )
			@work_operator = nil
			part_toolbar
			cancel_current_tool
			@selection.deselect_all
			return true
		end
		return false
	end
	
	def sketch_mode( sketch )
		sketch.visible = true
		sketch.plane.visible = true
		@glview.redraw
		@work_sketch = sketch
		sketch_toolbar
		activate_tool 'select'
	end
	
	def operator_mode( op )
		@main_vbox.pack_start( op.show_toolbar, false, true )
		@main_vbox.show_all
		@prt_toolbar.visible = false
		@asm_toolbar.visible = false
		@sketch_toolbar.visible = false
		@work_operator = op
	end
###                                                                       ###
######---------------------- Operators and tools ----------------------######
###                                                                       ###
	def add_operator( type )
		case type
			when 'extrude'
				op = ExtrudeOperator.new( @work_component, self )
			when 'revolve'
				op = RevolveOperator.new( @work_component, self )
		end
		@work_component.add_operator op 
		@op_view.update
		operator_mode op 
	end
	
	def move_selected_operator_up
	  op = @op_view.selections.first
	  op.part.move_operator_up op if op
	end
	
	def move_selected_operator_down
	  op = @op_view.selections.first
	  op.part.move_operator_down op if op
	end
	
	def enable_selected_operator
	  op = @op_view.selections.first
	  if op and op.is_a? Operator
	    op.enabled = (not op.enabled)
	    op.part.build op
	    @glview.redraw
    end
	end
	
	def delete_op_view_selected
	  sel = @op_view.selections.first
	  if sel
	    if sel.is_a? Operator
	      @work_component.remove_operator sel 
	      if sel.settings[:sketch]
	        @all_sketches.delete sel.settings[:sketch]
	        sel.settings[:sketch].clean_up
        end
      elsif sel.is_a? Instance and not sel == @op_view.base_component 
	      sel.parent.remove_component sel 
	      @all_part_instances.delete sel
	      @all_assemblies.delete sel 
      end
	    exit_current_mode or @glview.redraw
	    @op_view.update
    end
	end
	
	def activate_tool( name, temporary=false )
		block = block_given? ? Proc.new : Proc.new{}
		if temporary
			@toolstack.last.pause
		else
			@toolstack.pop.exit until @toolstack.empty?
		end
		case name
			when 'camera'
				tool = CameraTool.new( @glview, self, &block )
			when 'select'
			  if @work_sketch
			    tool = EditSketchTool.new( @glview, self, @work_sketch, &block )
		    elsif @work_component.class == Part
		      tool = OperatorSelectionTool.new( @glview, self, &block )
	      elsif @work_component.class == Assembly
	        tool = PartSelectionTool.new( @glview, self, &block )
        end
			when 'part_select'
				tool = PartSelectionTool.new( @glview, self, &block )
			when 'operator_select'
  			tool = PartSelectionTool.new( @glview, self, &block )
			when 'sketch_select'
				tool = SketchSelectionTool.new( @glview, self, &block )
			when 'plane_select'
				tool = PlaneSelectionTool.new( @glview, self, &block )
			when 'measure_distance'
				tool = MeasureDistanceTool.new( @glview, self, &block )
			when 'line'
				tool = LineTool.new( @glview, self, @work_sketch, &block )
		end
		@toolstack.push tool
		@glview.redraw
	end
	
	def current_tool
		@toolstack.last
	end
	
	def cancel_current_tool
		unless @toolstack.size == 1
			@toolstack.pop.exit 
			current_tool.resume
			@glview.redraw
		end
	end

	def select( comp )
		while comp
			break if comp.parent == @work_component
			comp = comp.parent
		end
		# parent now contains the topmost ancestor of comp that is directly in the work assembly.
		# if not, the component selected is in an assembly on top of the work asm and neglected
		@selection.select comp if comp
	end
	
	def delete_selected
	  for comp in @selection
      if comp.is_a? Instance and comp.parent
        comp.parent.remove_component comp
      elsif comp.is_a? Segment
        comp.sketch.segments.delete comp
        comp.sketch.build_displaylist
      end
    end
    @selection.deselect_all
    @op_view.update
    @glview.redraw
	end
###                                                                            ###
######---------------------- Interface customizations ----------------------######
###                                                                            ###
	def set_status_text( text )
		@statusbar.pop( @statusbar.get_context_id('') )
		@statusbar.push( @statusbar.get_context_id(''),  " " + text )
	end
	
	def assembly_toolbar
		@asm_toolbar.visible = true
		@prt_toolbar.visible = false
		@sketch_toolbar.visible = false
	end

	def part_toolbar
		@asm_toolbar.visible = false
		@prt_toolbar.visible = true
		@sketch_toolbar.visible = false
	end
	
	def sketch_toolbar
		@asm_toolbar.visible = false
		@prt_toolbar.visible = false
		@sketch_toolbar.visible = true
	end
	
	def display_contact_set
		SimulationSettingsDialog.new( @all_part_instances, @colliding_instances )
	end
	
	def key_pressed( key )
	  puts key
		@keys_pressed.push key
		activate_tool( "camera", true ) if @keymap[key] == :Ctrl
		cancel_current_tool             if @keymap[key] == :Esc
		working_level_up                if @keymap[key] == :Backspace
		delete_selected                 if @keymap[key] == :Del
	end
	
	def key_released( key )
		@keys_pressed.delete key
		cancel_current_tool if @keymap[key] == :Ctrl
	end
	
	def show_material_editor
	  MaterialEditor.new @materials
	end
	
private
###                                                         ###
######---------------------- Stuff ----------------------######
###                                                         ###
	def unique_name( base )
		number = 0
		begin
			found = true
			if @work_component.class == Part
				other_elements = @work_component.unused_sketches + @work_component.operators
			else
				other_elements = @work_component.components
			end
			other_elements.each do |e| 
				if e.name == "Untitled #{base} #{number}"
					number += 1
					found = false
					break
				end
			end
		end while not found
		return "Untitled #{base} #{number}"
	end
end


























