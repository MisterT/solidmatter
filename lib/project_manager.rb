#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'gtk2'
require 'geometry.rb'
require 'operators.rb'
require 'tools.rb'
require 'multi_user.rb'
require 'material_editor.rb'
require 'project_dialog.rb'
require 'make_public_dialog.rb'
require 'close_project_confirmation.rb'
require 'simulation_settings.rb'
require 'file_open_dialog.rb'
require 'export_dialog.rb'

class Selection
	def initialize
		@sel = []
	end
	
	def add( comp )
		comp.selected = true
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
	end
	
	def subract( comp )
		comp.selected = false
		@sel.delete comp
	end
	
	def select( *comps )
		deselect_all
		@sel = comps
		@sel.each{|c| c.selected = true }
	end
	
	def deselect_all
		@sel.each{|c| c.selected = false }
		@sel = []
	end
	
	def all
	 @sel
	end
	
	def method_missing( method, *args, &block )
		@sel.send( method, *args, &block )
	end
end

class ProjectManager
	attr_accessor :filename, :project_id, :focus_view, :materials, :save_btn, :return_btn, :previous_btn, :next_btn,
	              :main_assembly, :all_assemblies, :all_parts, :all_assembly_instances, 
	              :all_part_instances, :all_sketches, :name, :author, :main_win,
	              :point_snap, :grid_snap, :use_sketch_guides, :clipboard, :unit_system
	attr_reader :selection, :work_component, :work_sketch,
	            :glview, :op_view, :has_been_changed, :keys_pressed, :keymap, :work_operator
	def initialize( main_win, op_view, glview, asm_toolbar, prt_toolbar, sketch_toolbar, statusbar, main_vbox, op_view_controls )
	  $manager = self
	  @main_win = main_win
		@op_view = op_view
		@asm_toolbar = asm_toolbar
		@prt_toolbar = prt_toolbar
		@sketch_toolbar = sketch_toolbar
		@statusbar = statusbar
		@glview = glview
		@main_vbox = main_vbox
		@op_view_controls = op_view_controls
		@focus_view = true
		@keys_pressed = []
		@point_snap = true
		@grid_snap = false
		@use_sketch_guides = false
		@materials = [ Material.new( GetText._("Aluminum")),
                   Material.new( GetText._("Steel")),
                   Material.new( GetText._("Copper")),
                   Material.new( GetText._("Carbon")),
                   Material.new( GetText._("Glass")),
                   Material.new( GetText._("Polystyrol")),
                   Material.new( GetText._("Poly-acryl")) ]
    @keymap = { 65505 => :Shift,
                65507 => :Ctrl,
                65406 => :Alt,
                65307 => :Esc,
                65288 => :Backspace,
                65535 => :Del}  
    @unit_system = $preferences[:default_unit_system]
	  new_project
	end
	
public
  def all_instances
    @all_part_instances + @all_assembly_instances
  end

  def project_name
    if @client
      @client.projectname
    else
      @name
    end
  end
  
  def correct_title
    file = @filename ? "(#{@filename})" : GetText._("<not saved>")
    previous_dir = Dir.pwd
    Dir.chdir
    file.gsub!( Dir.pwd, '~')
    Dir.chdir previous_dir
    @main_win.title = "#{@has_been_changed ? '*' : ''}#{project_name} #{file} - Solid|matter" if @main_win
  end
  
  def has_been_changed= v
    @has_been_changed = v
    @save_btn.sensitive = v if @save_btn
    correct_title
  end
  
	def new_project
	  CloseProjectConfirmation.new do |response|
	    save_file if response == :save
      @client.exit if @client
      @client = nil
    	@name = GetText._("Untitled project")
    	@author = ""
    	@main_assembly = Instance.new( Assembly.new( GetText._("Untitled assembly") ) )
    	@selection = Selection.new
    	@work_component = @main_assembly
    	@work_sketch = nil
    	exchange_all_gl_components do
      	@all_assemblies         = [@main_assembly.real_component]
      	@all_parts              = []
      	@all_part_instances     = []
      	@all_assembly_instances = [@main_assembly]
      	@all_sketches           = []
  	  end
    	new_part if $preferences[:create_part_on_new_project] and @not_starting_up
    	@colliding_instances    = []
    	@filename = nil
    	self.has_been_changed = false
    	@op_view.set_base_component( @main_assembly ) if @op_view
    	@toolstack = [ PartSelectionTool.new ] if @glview
    	display_properties if @not_starting_up
    	@glview.redraw if @not_starting_up
    	@not_starting_up = true
    	@op_view.update if @op_view
    	yield if block_given?
  	end
	end
	
	def exchange_all_gl_components
		if @not_starting_up
			@glview.delete_all_displaylists
	    @all_parts.each{|p| p.clean_up ; p.working_planes.each{|pl| pl.clean_up } }
	    @all_sketches.each{|sk| sk.clean_up }
    end
	  yield
	  if @not_starting_up
	  	@all_sketches.each do |sk| 
        sk.displaylist = @glview.add_displaylist
        sk.build_displaylist
      end
	  	progress = ProgressDialog.new
	  	progress.fraction = 0.0
	  	num_ops = @all_parts.map{|p| p.operators}.flatten.size
  		op_i = 1
  		increment = 1.0 / num_ops
  	  @all_parts.each do |p| 
  	    p.displaylist = @glview.add_displaylist
  	    p.wire_displaylist = @glview.add_displaylist
  	    p.selection_displaylist = @glview.add_displaylist
  	    p.build do |op| 
  				progress.fraction += increment
  				progress.text = GetText._("Rebuilding operator ") + "'#{op.name}' (#{op_i}/#{num_ops})" 
  				op_i += 1
  			end
  	    p.working_planes.each do |pl| 
  	      pl.displaylist = @glview.add_displaylist
  	      pl.build_displaylists
	      end
      end
      progress.close
    end
	end
	
	def make_project_public
	  MakePublicDialog.new self do |server, port|
  	  @client = ProjectClient.new( server, port )
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
	  @client = ProjectClient.new( server, port )
	  if @client.working
	    valid = @client.join_project( projectname, login, password ) 
	    if valid
	      puts "successfully joined project"
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
	def new_instance( component, show_properties=true )
	  # make sure we are inserting into an assembly
		working_level_up while @work_component.class == Part
		# make component instance the work component
		instance = Instance.new( component, @work_component )
		#@work_component.components.push instance
		#@all_part_instances.push instance if instance.class == Part
		#@all_assembly_instances.push instance if instance.class == Assembly
		add_object instance
		change_working_level instance
		instance.display_properties if show_properties
		instance
	end
	
	def new_part
		# create part and make its instance the work part
		part = Part.new( unique_name( GetText._("part") ) )
		@all_parts.push part
		new_instance( part )
	end
	
	def new_assembly
		# create assembly and make it the work assembly
		assembly = Assembly.new( unique_name(GetText._("assembly")) )
		@all_assemblies.push assembly
		new_instance( assembly )
	end

	def new_sketch( template=nil )
	  # pick plane for sketch
	  activate_tool('plane_select', true) do |plane|
	    if plane
    		# create sketch and make it the work sketch
    		sketch = Sketch.new( unique_name( GetText._("sketch") ), @work_component, plane )
    		if template
    		  sketch.segments = template.segments.map{|s| seg = s.dup ; seg.sketch = sketch ; seg }
    		  sketch.build_displaylist
		    end
    		@all_sketches.push sketch
    		@work_component.unused_sketches.push( sketch )
    		#@work_component.working_planes.push sketch.plane
    		@op_view.update
    		sketch_mode sketch
		  end
	  end
	end
	
	def share_sketch
	  
	end
	
	def add_object( inst, insert=true )
    if inst.is_a? Instance
      # check if we already know the real_component
      real_comp = (@all_parts + @all_assemblies).select{|e| e.component_id == inst.real_component.component_id }.first
      # add part
      if inst.class == Part
        @all_part_instances.push inst
        @all_part_instances.uniq!
        if real_comp
          inst.real_component = real_comp
        else
          @all_parts.push inst.real_component
          inst.displaylist = @glview.add_displaylist
          inst.build
        end
      # add assembly
      elsif inst.class == Assembly
        @all_assembly_instances.push inst
        if real_comp
          inst.real_component = real_comp
        else
          @all_assemblies.push inst.real_component
          inst.components.each{|c| add_object( c, false ) }
        end
      end
      if insert
        working_level_up while @work_component.class == Part
        @work_component.components.push inst
        @op_view.update
      end
      @client.component_added inst if @client and @client.working
    # add segment
    elsif inst.is_a? Segment and @work_sketch
      @work_sketch.segments.push inst
      @work_sketch.build_displaylist
    end
    @glview.redraw
	end
	
	def delete_object obj_or_id
	  obj = (obj_or_id.is_a? Integer) ? all_instances.select{|inst| inst.instance_id == obj_or_id }.first : obj_or_id
	  if obj.is_a? Instance and obj.parent
      obj.parent.remove_component obj
      @all_assembly_instances.delete obj
      @all_part_instances.delete obj
    elsif obj.is_a? Component
    	all_instances.each{|inst| delete_object inst if inst.real_component == obj }
    	@all_parts.delete obj
    elsif obj.is_a? Operator 
      sketch = obj.settings[:sketch]
      if sketch
     	  dia = Gtk::MessageDialog.new(@main_win, 
                                     Gtk::Dialog::DESTROY_WITH_PARENT,
                                     Gtk::MessageDialog::QUESTION,
                                     Gtk::MessageDialog::BUTTONS_NONE,
                                     GetText._("Delete Sketch?"))
        dia.add_buttons( [Gtk::Stock::NO, Gtk::Dialog::RESPONSE_NO],
         		             [Gtk::Stock::DELETE, Gtk::Dialog::RESPONSE_YES] )
	      dia.secondary_text = GetText._("The operator includes an associated sketch.\nDo you want to delete it?")
			  dia.run do |resp|
					if resp == Gtk::Dialog::RESPONSE_YES
						@all_sketches.delete sketch
			  		sketch.clean_up	
			  	else
			  		@work_component.unused_sketches.push sketch
			  		sketch.op = nil
			  		sketch.visible = true
					end
					dia.destroy
				end
	    end
	    @work_component.remove_operator obj
    elsif obj.is_a? Sketch
    	if obj.op
    		obj.op.settings[:segments] = nil
    		obj.op.settings[:sketch] = nil
    		obj.op.part.build obj.op
    	end
    	obj.parent.unused_sketches.delete obj
    	@all_sketches.delete obj
			obj.clean_up	
    elsif obj.is_a? Segment
      obj.sketch.segments.delete obj
      obj.sketch.build_displaylist
    end
    @op_view.update
    @glview.redraw
	end
###                                                                 ###
######---------------------- File handling ----------------------######
###                                                                 ###
	def open_file
	  CloseProjectConfirmation.new do |response|
	    save_file if response == :save
	    dia = FileOpenDialog.new
      if dia.run == Gtk::Dialog::RESPONSE_ACCEPT
      	filename = dia.filename
      	dia.destroy
      	#begin
					File::open( filename ) do |file|
						scene = Marshal::restore file 
						exchange_all_gl_components do
						  thumbnail               = scene[0]
							@name                   = scene[1]
							@main_assembly          = scene[2]
							@all_assemblies         = scene[3]
							@all_parts              = scene[4]
      				@all_part_instances     = scene[5]
      				@all_assembly_instances = scene[6]
							@all_sketches           = scene[7]
						end
					end
					@glview.ground.clean_up
					change_working_level @main_assembly 
					@filename = filename
					self.has_been_changed = false
					#@all_parts.each{|p| p.build } #XXX this shouldn't really be needed
					@glview.zoom_onto @all_part_instances.select{|i| i.visible }
  			#rescue
  			#  dialog = Gtk::MessageDialog.new(@main_win, 
				#                                  Gtk::Dialog::DESTROY_WITH_PARENT,
				#                                  Gtk::MessageDialog::WARNING,
				#                                  Gtk::MessageDialog::BUTTONS_CLOSE,
				#                                  GetText._("Bad file format"))
				#  dialog.secondary_text = GetText._("The file format is unsupported.\nMaybe this file was saved with an older version of Solid|matter")
				#  dialog.run
				#  dialog.destroy
  			#end
  		else
  		  dia.destroy
      end
    end
	end
	
	def save_file_as 
    dia = FileOpenDialog.new :save
    if dia.run == Gtk::Dialog::RESPONSE_ACCEPT
      @filename = dia.filename
      @filename += '.omp' unless @filename =~ /.omp/
			save_file
			dia.destroy
			return true
    end
    dia.destroy
    return false
	end
	
	def save_file
	  if @client
	    @client.save_request
    else
  		if @filename
  		  @selection.deselect_all
  			File::open( @filename, "w" ) do |file|
  			  @all_parts.each{|p| p.solid = Solid.new }
  			  puts "projectname: " + project_name
  				Marshal::dump( [@glview.image_of_instances(@all_part_instances,8,100,project_name).to_tiny, 
  												@name, @main_assembly, @all_assemblies,	@all_parts, @all_part_instances,
  												@all_assembly_instances, @all_sketches], file )
  				@all_parts.each{|p| p.build } 
  			end
  			self.has_been_changed = false
  			return true
  		else
  			save_file_as
  		end
	  end
	end
	
	def export_selection
	  parts = @selection.map{|s| s.class == Assembly ? s.contained_parts : s }.flatten
	  parts = @main_assembly.contained_parts.select{|p| p.visible } if parts.empty?
	  ExportDialog.new do |filetype|
      dia = FileOpenDialog.new filetype
      if dia.run == Gtk::Dialog::RESPONSE_ACCEPT
        filename = dia.filename
        filename += filetype unless filename =~ Regexp.new(filetype)
        data = case filetype
          when '.stl' : generate_stl parts
        end
	      File::open(filename,"w"){|f| f << data }
      end
      dia.destroy
    end
	end
	
	def generate_stl parts
	  stl = "solid #{@name}\n"
	  for p in parts
	    for tri in p.solid.tesselate
	      n = tri[0].vector_to(tri[1]).cross_product(tri[0].vector_to(tri[2])).normalize
	      n = Vector[0.0, 0.0, 0.0] if n.x.nan?
	      stl += "  facet normal #{n.x} #{n.y} #{n.z}\n"
        stl += "    outer loop\n"
        for v in tri
          stl += "      vertex #{v.x} #{v.y} #{v.z}\n"
        end
        stl += "    endloop\n"
	      stl += "  endfacet\n"
	    end
	  end
	  stl += "endsolid #{@name}\n"
    return stl
	end

  def display_properties
    ProjectInformationDialog.new(self){ yield if block_given? ; puts "found myself having the name #{@name}" }
  end
###                                                                                      ###
######---------------------- Working level and mode transitions ----------------------######
###                                                                                      ###
	def change_working_level( component )
	  @selection.deselect_all
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
		cancel_current_tool
		unless exit_current_mode
			parent = @work_component.parent 
			change_working_level( parent ) if parent
		end
	end
	
	def upmost_working_level?
	  @work_component == @main_assembly
	end
	
	# return from drawing, tool or operator mode
	def exit_current_mode
		if @work_sketch
		  @work_sketch.visible = false unless @work_component.unused_sketches.include? @work_sketch
		  @work_sketch.plane.animate -1
			@work_sketch.plane.visible = false
			op = @work_sketch.op
			op.part.build op if op
			@work_sketch = nil
			@glview.redraw
			part_toolbar
  		activate_tool 'select'
  		@selection.deselect_all
			return true
		elsif @work_operator
			@main_vbox.remove( @op_toolbar )
			@op_toolbar = nil
			@work_operator = nil
			part_toolbar
			@selection.deselect_all
			return true
		elsif @work_tool
			@work_tool = nil
			cancel_current_tool
			@selection.deselect_all
			return false
		end
		return false
	end
	
	def sketch_mode sketch
	  # roll back operators up to this point in history
	  op = sketch.op
	  if op
  	  i = op.part.operators.index op
  	  old_limit = op.part.history_limit
  	  op.part.history_limit = i
  	  op.previous ? op.part.build(op.previous) : op.part.build
  	  op.part.history_limit = old_limit
	  end
		@work_sketch = sketch
		sketch_toolbar
		sketch.parent.cog = nil
		sketch.plane.visible = true
		sketch.plane.animate
		sketch.visible = true
		activate_tool 'select'
	end
	
	def operator_mode op
		@op_toolbar ||= op.show_toolbar
		@main_vbox.pack_start( @op_toolbar, false, true )
		@main_vbox.show_all
		@prt_toolbar.visible = false
		@asm_toolbar.visible = false
		@sketch_toolbar.visible = false
		@work_operator = op
	end
	
	def tool_mode tool
	  if tool.uses_toolbar
		  @main_vbox.pack_start( tool.toolbar, false, true )
		  @main_vbox.show_all
		  @prt_toolbar.visible = false
		  @asm_toolbar.visible = false
		  @sketch_toolbar.visible = false
	  end
		@work_tool = tool
	end
###                                                                       ###
######---------------------- Operators and tools ----------------------######
###                                                                       ###
	def add_operator( type )
		case type
			when 'extrude'
				op = ExtrudeOperator.new @work_component
			when 'revolve'
				op = RevolveOperator.new @work_component
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
	
	def enable_operator op
	  op.enabled = (not op.enabled)
	  op.part.build op
	  @glview.redraw
	end
	
	def enable_selected_operator
	  op = @op_view.selections.first
	  if op and op.is_a? Operator
      enable_operator op
    end
	end
	
	def delete_op_view_selected
		exit_current_mode
	  sel = @op_view.selections.first
    delete_object sel if sel
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
				tool = CameraTool.new( &block )
			when 'select'
			  if @work_sketch
			    tool = EditSketchTool.new( @work_sketch, &block )
		    elsif @work_component.class == Part
		      tool = OperatorSelectionTool.new( &block )
	      elsif @work_component.class == Assembly
	        tool = PartSelectionTool.new( &block )
        end
			when 'part_select'
				tool = PartSelectionTool.new( &block )
			when 'operator_select'
  			tool = OperatorSelectionTool.new( &block )
			when 'region_select'
				tool = RegionSelectionTool.new( &block )
			when 'sketch_select'
  			tool = SketchSelectionTool.new( &block )
			when 'plane_select'
				tool = PlaneSelectionTool.new( &block )
			when 'measure_distance'
				tool = MeasureDistanceTool.new( &block )
			when 'line'
				tool = LineTool.new( @work_sketch, &block )
			when 'arc'
				tool = ArcTool.new( @work_sketch, &block )
			when 'circle'
				tool = TwoPointCircleTool.new( @work_sketch, &block )
			when 'dimension'
				tool = DimensionTool.new( @work_sketch, &block )
			when 'trim'
				tool = TrimTool.new( @work_sketch, &block )
		end
		tool_mode tool
		@toolstack.push tool
		@glview.redraw
	end
	
	def current_tool
		@toolstack.last
	end
	
	def cancel_current_tool
		unless @toolstack.size == 1
			tool = @toolstack.pop
			tool.exit
			@work_tool = nil
			@main_vbox.remove tool.toolbar if tool.uses_toolbar
			current_tool.resume
			if current_tool.uses_toolbar 
			  tool_mode current_tool
		  elsif @work_operator
		    operator_mode @work_operator
			elsif @work_sketch
			  sketch_toolbar
		  elsif @work_component.class == Part
		    part_toolbar
	    else
	      assembly_toolbar
      end
			@glview.redraw
		end
	end
	
	def top_ancestor comp
		while comp
			break if comp.parent == @work_component
			comp = comp.parent
		end
		# comp now contains the topmost ancestor of the original comp that is directly in the work assembly.
		# if not, the component selected is in an assembly on top of the work asm and neglected
		return comp
	end

	def select comp
		comp = top_ancestor comp
		@selection.select comp if comp
		comp
	end
	
	def delete_selected
	  for comp in @selection
      delete_object comp
    end
    @selection.deselect_all
	end
	
	def cut_to_clipboard
	 copy_to_clipboard
	 delete_selected
	end
	
	def copy_to_clipboard
    @clipboard = @selection.map{|c| c.dup } unless @selection.empty?
	end
	
	def paste_from_clipboard
	  @selection.deselect_all
	  if @clipboard
      for obj in @clipboard
        copy = obj.dup
        if copy.is_a? Segment and @work_sketch
          copy.sketch = @work_sketch
          add_object copy
          @selection.add copy
        else
          add_object copy
          @selection.add copy
        end
      end
    end
	end
	
	def duplicate_instance
	  copy_to_clipboard
	  paste_from_clipboard
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
	
	def key_pressed? name
		keys_pressed.include? @keymap.invert[name]
	end
	
	def show_material_editor
	  MaterialEditor.new @materials
	end
	
###                                                         ###
######---------------------- Stuff ----------------------######
###                                                         ###
private

	def unique_name base
		num = 1
		num += 1 while [@all_parts, @all_assemblies, @all_sketches].flatten.map{|e| e.name }.include? GetText._("Untitled") + " #{base} #{num}"
		return GetText._("Untitled") + " #{base} #{num}"
	end
end


























