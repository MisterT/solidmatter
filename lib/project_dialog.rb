#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-05.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'


class ProjectInformationDialog
	def initialize 
	  @glade = GladeXML.new( "../data/glade/project_dialog.glade", nil, 'openmachinist' ) {|handler| method(handler)}
	  @glade['name_entry'].text   = $manager.name  
	  @glade['author_entry'].text = $manager.author
	  @glade['tn_parts_label'].text = $manager.all_part_instances.size.to_s
	  @glade['n_parts_label'].text = $manager.all_parts.size.to_s
	  @glade['tn_assemblies_label'].text = $manager.all_assembly_instances.size.to_s
	  @glade['n_assemblies_label'].text = $manager.all_assemblies.size.to_s
	  @callback = Proc.new if block_given?
  end
  
  def ok_handle( w )
    $manager.name   = @glade['name_entry'].text    
    $manager.author = @glade['author_entry'].text  
    $manager.correct_title
    $manager.has_been_changed = true
    @callback.call if @callback
    puts "called callback" if @callback
    @glade['project_dialog'].destroy
  end
end
