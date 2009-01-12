#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-05.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'


class ProjectInformationDialog
	def initialize project
	  @glade = GladeXML.new( "../data/glade/project_dialog.glade", nil, 'solidmatter' ) {|handler| method(handler)}
	  @glade['name_entry'].text   = project.name  
	  @glade['author_entry'].text = project.author
	  @glade['tn_parts_label'].text = project.all_part_instances.size.to_s
	  @glade['n_parts_label'].text = project.all_parts.size.to_s
	  @glade['tn_assemblies_label'].text = project.all_assembly_instances.size.to_s
	  @glade['n_assemblies_label'].text = project.all_assemblies.size.to_s
	  @callback = Proc.new if block_given?
	  @project = project
  end
  
  def ok_handle( w )
    @project.name   = @glade['name_entry'].text    
    @project.author = @glade['author_entry'].text  
    $manager.correct_title if $manager
    $manager.has_been_changed = true if $manager
    @callback.call if @callback
    puts "called callback" if @callback
    @glade['project_dialog'].destroy
  end
end
