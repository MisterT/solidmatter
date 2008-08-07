#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-07.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'
require 'gconf2'


Bookmark = Struct.new( :adress, :port, :login, :password )

$preferences = { 
	:project_dir => Dir.pwd,
	:mouse_sensivity => 1.0,
	:create_part_on_new_project => true,
	:surface_resolution => 40,
	:dynamic_tesselation => true,
	:bookmarks => [ Bookmark.new( 'localhost', 2222, 'synthetic', 'bla' ) ],
	:anti_aliasing => true,
	:stencil_transparency => true,
	:manage_gc => true,
	:first_light_position => [0.5, 1.0, 1.0, 0.0],
	:second_light_position => [-0.8, -0.8, 0.35, 0.0],
	:first_light_color => [0.5, 0.5, 1.0, 0.0],
	:second_light_color => [1.0, 0.7, 0.5, 0.0],
	:view_transitions => true,
	:transition_duration => 20.0,#60.0,
	:animate_working_planes => true,
	:animation_duration => 10.0,
	:max_reference_points => 8,
	:thumb_res => 50,
	:snap_dist => 6,
	:merge_threshold => 0.001,
	:area_samples => 500,
	:dimension_offset => 0.1,
	:server_port => 50010,
	:default_unit_system => :mm
}

$non_gconf_types = [Bookmark]


def load_preferences_from_gconf
	gconf_prefix = '/apps/openmachinist/'
	cl = GConf::Client.default
	for key in $preferences.keys
		value = cl[gconf_prefix + key.to_s]
		$preferences[key] = value unless value.nil?
	end
end

def save_preferences_to_gconf
	gconf_prefix = '/apps/openmachinist/'
	cl = GConf::Client.default
	$preferences.each do |key, value|
		subtype_forbidden = value.flatten.map{|v| v.class }.any?{|clas| $non_gconf_types.include? clas } if value.is_a? Array
		cl[gconf_prefix + key.to_s] = value unless $non_gconf_types.include?(value.class) or subtype_forbidden
	end
end

load_preferences_from_gconf
           
                  
class PreferencesDialog
	def initialize manager
	  @manager = manager
	  @glade = GladeXML.new( "../data/glade/preferences.glade", nil, 'openmachinist' ) {|handler| method(handler)}
	  load_preferences_from_gconf
	  @react_to_changes = false
	  @glade['antialiasing_check'].active=	$preferences[:anti_aliasing]
		@glade['stencil_check'].active= $preferences[:stencil_transparency]
		@glade['gc_check'].active = $preferences[:manage_gc]
		@glade['transition_check'].active = $preferences[:view_transitions]
		@glade['transition_scale'].value = $preferences[:transition_duration] / 10.0
		@glade['animation_check'].active = $preferences[:animate_working_planes]
		@glade['animation_scale'].value = $preferences[:animation_duration] / 10.0
		@glade['snap_scale'].value = $preferences[:snap_dist]
		@glade['dir_chooser'].current_folder = $preferences[:project_dir]
		@glade['mouse_scale'].value = $preferences[:mouse_sensivity]
		@glade['resolution_scale'].value = $preferences[:surface_resolution]
		@glade['part_check'].active = $preferences[:create_part_on_new_project]
		@react_to_changes = true
  end
  
  def close w 
  	save_preferences_to_gconf
    @glade['preferences'].destroy
  end
  
  def preference_changed w
  	if @react_to_changes
			$preferences[:anti_aliasing] = @glade['antialiasing_check'].active?
			$preferences[:stencil_transparency] = @glade['stencil_check'].active?
			$preferences[:manage_gc] = @glade['gc_check'].active?
			$preferences[:view_transitions] = @glade['transition_check'].active?
			$preferences[:transition_duration] = @glade['transition_scale'].value * 10
			$preferences[:animate_working_planes] = @glade['animation_check'].active?
			$preferences[:animation_duration] = @glade['animation_scale'].value * 10
			$preferences[:snap_dist] = @glade['snap_scale'].value
			$preferences[:project_dir] = @glade['dir_chooser'].current_folder
			$preferences[:mouse_sensivity] = @glade['mouse_scale'].value
			$preferences[:surface_resolution] = @glade['resolution_scale'].value
			$preferences[:create_part_on_new_project] = @glade['part_check'].active?
			@manager.glview.realize
			@manager.glview.redraw
			save_preferences_to_gconf
		end
  end
end
                  
