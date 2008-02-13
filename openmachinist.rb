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
# grid animation mit transparenzen vervollständigen
# operatoren parallelisieren
# drag and drop im op-view
# undo/redo stack
# vererbung von parts
# use gtkuimanager for the menu
# point selection im sketcher
# drag darf alte selektion nicht zerstören
# shading modes
# Gtk::FileFilter - A filter for selecting a file subset
# extrusion toolbar wird nicht auf aktuellen depthwert gesetzt
# op_view klappzusatnd speichern
# direkt die iters manipulieren in server_win damit beim update scrollstand erhalten belibt
# checken ob clean_up von workplane udn sketch richtig erfolgt
# wenn ein teil selektiert ist und ein anderes erstellt wird muss die selection aufgehoben werden
# nach new local project screen refresh
# projekt name wird nicht mitgespeichert
# insert und library palette
# nach dem ladén einer anderen scene wird bis zum ersten build_displaylist noch altes Part angezeigt
# speichern im operator modus hinterlässt nach "return" den toolbar aktiv
# sketch button sollte eingedrückt bleib wenn plane gewählt wird
# sicherheitsprüfungen im server ( is_valid(projectname, client_id) schreiben)
