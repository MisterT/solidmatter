#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'project_dialog.rb'
require 'material_editor.rb'
require 'geometry.rb'


class Project
  attr_accessor :project_id, :materials, :main_assembly, :all_assemblies, :all_parts, :colliding_instances,
                :all_assembly_instances, :all_part_instances, :all_sketches, :name, :author, :unit_system
	def initialize
		@materials = [ Material.new( GetText._("Aluminum")),
                   Material.new( GetText._("Steel")),
                   Material.new( GetText._("Copper")),
                   Material.new( GetText._("Carbon")),
                   Material.new( GetText._("Glass")),
                   Material.new( GetText._("Polystyrol")),
                   Material.new( GetText._("Poly-acryl")) ]
    @unit_system = $preferences[:default_unit_system]
  	@name = GetText._("Untitled project")
  	@author = ""
  	@main_assembly = Instance.new( Assembly.new( GetText._("Untitled assembly") ) )
  	@all_assemblies         = [@main_assembly.real_component]
  	@all_parts              = []
  	@all_part_instances     = []
  	@all_assembly_instances = [@main_assembly]
  	@all_sketches           = []
  	new_part if $preferences[:create_part_on_new_project] and @not_starting_up
  	@colliding_instances = []
  	@filename = nil
	end
	
	def all_instances
    @all_part_instances + @all_assembly_instances
  end
	
	def rebuild
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
	
	def clean_up
	 	$manager.glview.delete_all_displaylists
    @all_parts.each{|p| p.clean_up ; p.working_planes.each{|pl| pl.clean_up } }
    @all_sketches.each{|sk| sk.clean_up }
	end
	
	###                                                                              ###
  ######---------------------- Creation of new components ----------------------######
  ###             	                                                               ###
	def new_instance( component, show_properties=true )
	  # make sure we are inserting into an assembly
		a = $manager.next_assembly
		instance = Instance.new( component, a )
		add_object instance
		$manager.change_working_level instance
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
	  $manager.activate_tool('plane_select', true) do |plane|
	    if plane
    		# create sketch and make it the work sketch
    		sketch = Sketch.new( unique_name( GetText._("sketch") ), $manager.work_component, plane )
    		if template
    		  sketch.segments = template.segments.map{|s| seg = s.dup ; seg.sketch = sketch ; seg }
    		  sketch.build_displaylist
		    end
    		@all_sketches.push sketch
    		$manager.work_component.unused_sketches.push sketch
    		$manager.op_view.update
    		$manager.sketch_mode sketch
		  end
	  end
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
        a = $manager.next_assembly
        a.components.push inst
        $manager.op_view.update
      end
    # add segment
    elsif inst.is_a? Segment and $manager.work_sketch
      $manager.work_sketch.segments.push inst
      $manager.work_sketch.build_displaylist
      @glview.rebuild_selection_pass_colors :select_segments_and_dimensions
    end
    $manager.glview.redraw
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
			  		$manager.work_component.unused_sketches.push sketch
			  		sketch.op = nil
			  		sketch.visible = true
					end
					dia.destroy
				end
	    end
	    $manager.work_component.remove_operator obj
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
    $manager.op_view.update
    $manager.glview.redraw
	end

  def display_properties
    ProjectInformationDialog.new(self){ yield if block_given? }
  end
  
  def unique_name base
		num = 1
		num += 1 while [@all_parts, @all_assemblies, @all_sketches].flatten.map{|e| e.name }.include? GetText._("Untitled") + " #{base} #{num}"
		return GetText._("Untitled") + " #{base} #{num}"
	end
end

