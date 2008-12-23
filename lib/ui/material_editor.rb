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
      @smoothness   = rand * 10
      @reflectivity = rand
      @opacity      = 1.0
      @density      = rand
    end
  end
  
  def to_lux
    return case @name
      when "Aluminum"   : ""
      when "Steel"      : "MakeNamedMaterial \"#{@name}\" \"string type\" [\"shinymetal\"] \"color Kr\" [#{@color.join ' '}] \"color Ks\" [0.900000 0.900000 0.900000] \"float uroughness\" [0.002000] \"float vroughness\" [0.002000]"
      when "Copper"     : ""
      when "Carbon"     : ""
      when "ABS"        : "MakeNamedMaterial \"#{@name}\" \"string type\" [\"plastic\"] \"color Kd\" [#{@color.join ' '}] \"color Ks\" [0.900000 0.900000 0.900000] \"float uroughness\" [0.002000] \"float vroughness\" [0.002000]"
	    when "Glass"      : "MakeNamedMaterial \"#{@name}\" \"string type\" [\"glass\"] \"color Kr\" [0.900000 0.900000 0.900000] \"color Kt\" [#{@color.join ' '}] \"float index\" [1.458000] \"bool architectural\" [\"false\"]"
	                       #"MakeNamedMaterial \"#{m.name}\" \"string type\" [\"roughglass\"] \"color Kr\" [0.900000 0.900000 0.900000] \"color Kt\" [#{m.color.join ' '}] \"float uroughness\" [0.002000] \"float vroughness\" [0.002000] \"float index\" [1.458000] \"float cauchyb\" [0.003540]"
	    when "Polystyrol" : "MakeNamedMaterial \"#{@name}\" \"string type\" [\"matte\"] \"color Kd\" [#{@color.join ' '}]"
	    when "Poly-acryl" : "MakeNamedMaterial \"#{@name}\" \"string type\" [\"mattetranslucent\"] \"color Kr\" [0.900000 0.900000 0.900000] \"color Kt\" [0.900000 0.900000 0.900000]"
	    else ""
    end
  end
  
  def == other
  	@name == other.name
  end
end


class MaterialEditor
	def initialize materials 
	  @materials = materials
	  @starting_up = true
	  @glade = GladeXML.new( "../data/glade/material_editor.glade", nil, 'openmachinist' ) {|handler| method(handler)}
	  @combo = @glade['material_combo']
	  @materials.each{|m| @combo.append_text m.name }
	  @combo.active = 0
	  show_current_material
    @starting_up = false
  end
  
  def ok_handle w
    settings_changed
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
    mat = @materials[@combo.active]
	  @glade['color_btn'].color = Gdk::Color.new( *mat.color.map{|c| c * 65535.0 } )
    @glade['name_entry'].text = mat.name
    @glade['reflectivity_scale'].value = mat.reflectivity
    @glade['specularity_scale'].value = mat.specularity
    @glade['smoothness_scale'].value = mat.smoothness
  end
  
  def settings_changed
    unless @combo.active == -1 or @starting_up
      mat = @materials[@combo.active]
      name =  @glade['name_entry'].text
      mat.name = name
      #@combo.active_iter[0] = name
      col = @glade['color_btn'].color
      mat.color = [col.red, col.green, col.blue].map{|c| c / 65535.0 }
      mat.reflectivity = @glade['reflectivity_scale'].value
      mat.specularity = @glade['specularity_scale'].value
      mat.smoothness = @glade['smoothness_scale'].value
      $manager.glview.redraw
    end
  end
end
