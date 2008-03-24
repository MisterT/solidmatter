#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.
require 'lib/main_win.rb'
require 'lib/preferences.rb'


Gtk.init
Gtk::GL.init
win = OpenMachinistMainWin.new
win.show_all
Gtk::main


# TODO :
# select features groups
# select other half of constraint
# cam animation nich mehr linear
# preferences Dialog
# limit der selektierbaren objekte von 768 auf 16.7M hochschrauben
# operatoren parallelisieren
# drag and drop im op-view
# undo/redo stack
# vererbung von parts
# use gtkuimanager for the menu
# point selection im sketcher
# shading modes
# Gtk::FileFilter - A filter for selecting a file subset
# extrusion toolbar wird nicht auf aktuellen depthwert gesetzt
# op_view klappzustand speichern
# direkt die iters manipulieren in server_win damit beim update scrollstand erhalten belibt
# checken ob clean_up von workplane und sketch richtig erfolgt
# insert und library palette
# sketch button sollte eingedrückt bleib wenn plane gewählt wird
# sicherheitsprüfungen im server ( is_valid(projectname, client_id) schreiben)
# immer nach glDrawable fragen um redraw probleme zu vermeiden
# nicht selektierbare objekte sollten wie der background wirken und bei click die selection aufheben
# confirm application quit
# wenn ein alter sketch bearbeitet wird sollten die nachfolgenden features zurückgespult werden, oder view geclippt, oder part transparent
# shortcuts über accelerators
# when selecting regions, select inner regions first
# automatically apply operator if there is only one unused sketch region
# create MIME type
# segmente mit nulllänge verhindern
# beim pasten von segmenten müssen die gegebenenfalls neuen sketch referenzieren
# wenn part keine Instanz mehr besitzt crash bei screenshot


