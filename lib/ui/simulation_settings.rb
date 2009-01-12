#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-15.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'


class SimulationSettingsDialog
  def initialize( all_parts, colliding_parts )
    @all_parts = all_parts
    @colliding_parts = colliding_parts
    @glade = GladeXML.new( "../data/glade/simulation_settings.glade", nil, 'solidmatter' ) {|handler| method(handler)}
    # ------- create unused parts view ------- #
    pix = Gtk::CellRendererPixbuf.new
		text = Gtk::CellRendererText.new
		column = Gtk::TreeViewColumn.new GetText._("All part instances")
		column.pack_start(pix,false)
		column.set_cell_data_func(pix) do |col, cell, model, iter|
			cell.pixbuf = iter.get_value(0)
		end
		column.pack_start(text, true)
		column.set_cell_data_func(text) do |col, cell, model, iter|
			cell.markup = iter.get_value(1)
		end
		@all_view = @glade['all_parts_view']
		@all_view.append_column( column )
		# ------- create colliding parts view ------- #
		column = Gtk::TreeViewColumn.new GetText._("Parts checked for collisions")
		column.pack_start(pix,false)
		column.set_cell_data_func(pix) do |col, cell, model, iter|
			cell.pixbuf = iter.get_value(0)
		end
		column.pack_start(text, true)
		column.set_cell_data_func(text) do |col, cell, model, iter|
			cell.markup = iter.get_value(1)
		end
		@colliding_view = @glade['colliding_parts_view']
		@colliding_view.append_column column 
		@all_view.selection.mode = Gtk::SELECTION_MULTIPLE
		@colliding_view.selection.mode = Gtk::SELECTION_MULTIPLE
		update
  end
  
  def ok_handle
    @glade['simulation_settings'].destroy
  end
  
  def move_to_colliding
    selected_parts.each{|pr| @colliding_parts.push pr }
    update
  end
  
  def remove_from_colliding
    selected_colliding_parts.each{|pr| @colliding_parts.delete pr }
    update
  end
  
  def selected_parts
    sel = []
    @all_view.selection.selected_each do |model, path, iter|
      sel.push( (@all_parts - @colliding_parts)[path.indices[0]] )
    end
    return sel
  end
  
  def selected_colliding_parts
    sel = []
    @colliding_view.selection.selected_each do |model, path, iter|
      sel.push @colliding_parts[path.indices[0]]
    end
    return sel
  end
  
  def update
    # all parts view
    model = Gtk::ListStore.new(Gdk::Pixbuf, String)
    im = Gtk::Image.new('../data/icons/small/part_small.png').pixbuf
    for part in (@all_parts - @colliding_parts)
		  iter = model.append
  		iter[0] = im
  		iter[1] = part.name
		end
		@all_view.model = model
		# colliding parts view
		model = Gtk::ListStore.new(Gdk::Pixbuf, String)
    for part in @colliding_parts
		  iter = model.append
  		iter[0] = im
  		iter[1] = part.name
		end
		@colliding_view.model = model
  end
end