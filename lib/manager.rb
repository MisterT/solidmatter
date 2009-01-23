#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'geometry.rb'
require 'operators.rb'
require 'tools.rb'
require 'multi_user.rb'
require 'ui/material_editor.rb'
require 'ui/make_public_dialog.rb'
require 'ui/close_project_confirmation.rb'
require 'ui/simulation_settings.rb'
require 'ui/file_open_dialog.rb'
require 'export.rb'

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


class Manager
  attr_accessor :focus_view, :save_btn, :return_btn, :previous_btn, :next_btn, :clipboard,
                :main_win, :point_snap, :grid_snap, :use_sketch_guides, :filename
  attr_reader :selection, :work_component, :work_sketch, :work_operator, :project,
              :glview, :render_view, :render_image, :op_view, :keys_pressed, :keymap, :has_been_changed
              
  def initialize( main_win, op_view, glview, render_view, render_image, asm_toolbar, prt_toolbar, sketch_toolbar, statusbar, main_vbox, op_view_controls )
    $manager = self
    @main_win = main_win
    @op_view = op_view
    @asm_toolbar = asm_toolbar
    @prt_toolbar = prt_toolbar
    @sketch_toolbar = sketch_toolbar
    @statusbar = statusbar
    @glview = glview
    @render_view = render_view
    @render_image = render_image
    @main_vbox = main_vbox
    @op_view_controls = op_view_controls
    @focus_view = true
    @keys_pressed = []
    @point_snap = true
    @grid_snap = false
    @use_sketch_guides = false
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
    elsif @project
      @project.name
    else
      ""
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
      @project.save if response == :save
      @client.exit if @client
      @client = nil
      @selection = Selection.new
      @glview.ground.clean_up if @not_starting_up
      @project = Project.new
      @work_component = @project.main_assembly
      @work_sketch = nil
      @filename = nil
      self.has_been_changed = false
      @op_view.set_base_component( @project.main_assembly ) if @op_view
      @toolstack = [ PartSelectionTool.new ] if @glview
      @project.display_properties if @not_starting_up
      @glview.redraw if @not_starting_up
      @not_starting_up = true
      @op_view.update if @op_view
      yield if block_given?
    end
  end

  def make_project_public
    MakePublicDialog.new do |server, port|
      @client = ProjectClient.new( server, port )
      if @client.working
        @project.save
        if @project.filename and not @client.available_projects.map{|pr| pr.name }.include? @project.name
          @client.server.add_project @project 
          valid = @client.join_project( @project.name, 'synthetic', 'bla' )
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

  def add_object( inst, insert=true )
    @project.add_object( inst, insert )
    @client.component_added inst if inst.is_a? Instance and @client and @client.working
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
        begin
          @project = Project.load filename
          change_working_level @project.main_assembly 
          self.has_been_changed = false
          @project.rebuild
          @project.all_parts.each{|p| p.build } #XXX this shouldn't really be needed
          @glview.zoom_onto @project.all_part_instances.select{|i| i.visible }
        rescue
          dialog = Gtk::MessageDialog.new(@main_win, 
                                          Gtk::Dialog::DESTROY_WITH_PARENT,
                                          Gtk::MessageDialog::WARNING,
                                          Gtk::MessageDialog::BUTTONS_CLOSE,
                                          GetText._("Bad file format"))
          dialog.secondary_text = GetText._("The file format is unsupported.\nMaybe this file was saved with an older version of Solid|matter")
          dialog.run
          dialog.destroy
        end
      else
        dia.destroy
      end
    end
  end
  
  def save_file_as 
    @project.save_as
  end
  
  def save_file
    if @client
      @client.save_request
    else
      @selection.deselect_all
      @project.save
      self.has_been_changed = false
    end
  end
  
  def export_selection
    parts = @selection.map{|s| s.class == Assembly ? s.contained_parts : s }.flatten
    parts = @project.main_assembly.contained_parts.select{|p| p.visible } if parts.empty?
    Exporter.new.export parts
  end
###                                                                                      ###
######---------------------- Working level and mode transitions ----------------------######
###                                                                                      ###
  def change_working_level component
    @selection.deselect_all
    # display only current part's sketches
    @work_component.unused_sketches.each{|sk| sk.visible = false } if @work_component.class == Part
    @work_component = component
    @work_component.unused_sketches.each{|sk| sk.visible = true } if @work_component.class == Part
    # make other components transparent
    @project.main_assembly.transparent = @focus_view ? true : false
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
    @work_component == @project.main_assembly
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
  
  def next_assembly
    working_level_up while @work_component.class == Part
    @work_component
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
    @op_toolbar.show_all
    @prt_toolbar.visible = false
    @asm_toolbar.visible = false
    @sketch_toolbar.visible = false
    @work_operator = op
  end
  
  def tool_mode tool
    if tool.uses_toolbar
      @main_vbox.pack_start( tool.toolbar, false, true )
      tool.toolbar.show_all
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
      when 'fem'
        op = FEMOperator.new @work_component
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
    @project.delete_object sel if sel
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
      when 'face_select'
        tool = FaceSelectionTool.new( &block )
      when 'measure_distance'
        tool = MeasureDistanceTool.new( &block )
      when 'line'
        tool = LineTool.new( @work_sketch, &block )
      when 'arc'
        tool = ArcTool.new( @work_sketch, &block )
      when 'circle'
        tool = TwoPointCircleTool.new( @work_sketch, &block )
      when 'spline'
        tool = SplineTool.new( @work_sketch, &block )
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

  def select comp
    comp = top_ancestor comp
    @selection.select comp if comp
    comp
  end
  
  def delete_selected
    for comp in @selection
      @project.delete_object comp
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
        end
        add_object copy
        @selection.add copy
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
    @status_text_mutex ||= Mutex.new
    @status_text_mutex.synchronize do
      @statusbar.pop( @statusbar.get_context_id('') )
      @statusbar.push( @statusbar.get_context_id(''),  " " + text )
    end
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
    SimulationSettingsDialog.new( @project.all_part_instances, @project.colliding_instances )
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
    MaterialEditor.new @project.materials
  end
  
  def sketch2part( v, sk )
    
  end
  
  def part2world( v, p )
    
  end
  
  def world2part( v, p )
  
  end
  
  def part2sketch( v, sk )
    
  end
  
  def world2sketch( v, sk )
    
  end
  
  def sketch2world( v, sk )
    
  end
end


























