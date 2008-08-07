#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'rubygems'
require 'ruby-prof'
require 'thread'
require 'main_win.rb'
require 'preferences.rb'
require 'gtk_threadsafe.rb'

GetText.bindtextdomain 'openmachinist'


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
# sketch button sollte eingedrückt bleiben wenn plane gewählt wird
# sicherheitsprüfungen im server ( is_valid(projectname, client_id) schreiben)
# network code auf thread-safety mit Gtk prüfen
# immer nach glDrawable fragen um redraw probleme zu vermeiden
# nicht selektierbare objekte sollten wie der background wirken und bei click die selection aufheben
# shortcuts über accelerators
# when selecting regions, select inner regions first
# automatically apply operator if there is only one unused sketch region
# parts/operators should communicate somehow that they could not be built correctly
# region select von vertikalen planes
# refactor delete_op_view_selected code into delete_object
# schnitte zwischen regions
# click wird nicht richtig registriert in region select tool wenn zu langsam
# polygon from chain should tesselate segments => dann RegionTool#init verändern und poly aus regionstruct nehmen
# typechecking => Bekommen faces WorkingPlanes zugewiesen?
# unterscheidung von instanzen bei selection unmöglich da beide die selbe displaylist haben

