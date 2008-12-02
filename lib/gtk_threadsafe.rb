#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'gtkglext'
require 'thread'
require 'gnome2'

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

class GtkThread < Thread
  def start
    Gtk.init_add{ super }
  end
end

