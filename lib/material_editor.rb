#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-01-04.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'


class Material
  attr_accessor :name, :color, :specularity, :smoothness, :reflectivity, :opacity, :density
  def Material::from_reference ref
    mat = Material.new "#{ref.name} copy"
    mat.color        = ref.color
    mat.specularity  = ref.specularity
    mat.smoothness   = ref.smoothness
    mat.reflectivity = ref.reflectivity
    mat.opacity      = ref.opacity
    mat.density      = ref.density
    return mat
  end
  
  def initialize( name, color=nil, specularity=nil, smoothness=nil, reflectivity=nil, opacity=nil, density=nil )
    @name = name
    if color
      @color        = color
      @specularity  = specularity
      @smoothness   = smoothness
      @reflectivity = reflectivity
      @opacity      = opacity
      @density      = density
    else
      @color = [rand, rand, rand]
      @specularity  = rand
      @smoothness   = rand
      @reflectivity = rand
      @opacity      = 1.0
      @density      = rand
    end
  end
  
  def == other
  	@name == other.name
  end
end


class MaterialEditor
	def initialize( materials )
	  @materials = materials
	  @glade = GladeXML.new( "../data/glade/material_editor.glade", nil, 'openmachinist' ) {|handler| method(handler)}
	  @combo = @glade['material_combo']
	  @materials.each{|m| @combo.append_text m.name }
	  @combo.active = 0
	  show_current_material
  end
  
  def ok_handle w 
    @glade['material_editor'].destroy
  end
  
  def add_material w
    m = Material::from_reference @materials[@combo.active]
    @materials.push m
    @combo.append_text m.name
    @combo.active = @materials.size - 1
    show_current_material
  end
  
  def remove_material w
    @materials.delete_at @combo.active
    @combo.remove_text @combo.active
    @combo.active = 0
    show_current_material
  end
  
  def combo_changed w
    show_current_material
  end
  
  def show_current_material
    col = @materials[@combo.active].color
	  @glade['color_btn'].color = Gdk::Color.new( *col.map{|c| c * 65535.0 } )
    @glade['name_entry'].text = @materials[@combo.active].name

  end
  
  def settings_changed w
    unless @combo.active == -1
      name =  @glade['name_entry'].text
      @materials[@combo.active].name = name
      @combo.active_iter[0] = name
      col = @glade['color_btn'].color
      @materials[@combo.active].color = [col.red, col.green, col.blue].map{|c| c / 65535.0 }
    end
  end
end