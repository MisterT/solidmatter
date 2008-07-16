#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'thread'
require 'main_win.rb'
require 'preferences.rb'

GetText.bindtextdomain 'openmachinist'

module Gtk
  GTK_PENDING_BLOCKS = []
  GTK_PENDING_BLOCKS_LOCK = Mutex.new

  def Gtk.queue &block
    if Thread.current == Thread.main
      block.call
    else
      GTK_PENDING_BLOCKS_LOCK.synchronize do
        GTK_PENDING_BLOCKS << block
      end
    end
  end

  def Gtk.main_with_queue timeout
    Gtk.timeout_add timeout do
      GTK_PENDING_BLOCKS_LOCK.synchronize do
        for block in GTK_PENDING_BLOCKS
          block.call
        end
        GTK_PENDING_BLOCKS.clear
      end
      true
    end
    Gtk.main
  end
end

Gtk.init
Gtk::GL.init
win = OpenMachinistMainWin.new
win.show_all
Gtk.main_with_queue 100


# TODO :
# select features groups
# select other half of constraint
# cam animation nich mehr linear
# limit der selektierbaren objekte von 768 auf 16.7M hochschrauben
# operatoren parallelisieren
# drag and drop im op-view
# undo/redo stack
# vererbung von parts
# use gtkuimanager for the menu
# extrusion toolbar wird nicht auf aktuellen depthwert gesetzt
# op_view klappzustand speichern
# direkt die iters manipulieren in server_win damit beim update scrollstand erhalten belibt
# checken ob clean_up von workplane und sketch richtig erfolgt
# sketch button sollte eingedrückt bleib wenn plane gewählt wird
# sicherheitsprüfungen im server ( is_valid(projectname, client_id) schreiben)
# immer nach glDrawable fragen um redraw probleme zu vermeiden
# nicht selektierbare objekte sollten wie der background wirken und bei click die selection aufheben
# shortcuts über accelerators
# when selecting regions, select inner regions first
# automatically apply operator if there is only one unused sketch region
# parts/operatos should communicate somehow that they could not be built correctly
# region select von vertikalen planes
# refactor delete_op_view_selected code into delete_object
# schnitte zwischen regions
# editsketchtool sollte eigenschaften von segments ändern können (kreisgrösse)



