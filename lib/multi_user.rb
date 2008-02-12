#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-01-06.
#  Copyright (c) 2008. All rights reserved.

require 'drb'
require 'lib/project_manager.rb'
require 'lib/account_editor.rb'


class UserAccount
  attr_accessor :server_win, :server, :login, :password, :registered_projects
  def initialize( server_win, login="", password="", projects=[] )
    @server_win = server_win
    @server = server_win.server
    @login = login
    @password = password
    @registered_projects = projects
    display_properties
  end
  
  def display_properties
    AccountEditor.new self
  end
end


Client = Struct.new( :client_id, :account, :locked_components )

Change = Struct.new( :obj, :client_ids_to_serve )


class ProjectServer
  attr_accessor :projects, :accounts, :clients, :server_win
  def initialize server_win
    @server_win = server_win
    $SAFE = 1
    DRb.start_service( "druby://localhost:2222", self )
    @projects = []
    @accounts = []
    @clients  = []
    @changes  = []
  end
  
  def get_projects
    # make sure objects get dumped
    prs = @projects.map{|p| p.strip_non_dumpable ; p.dup }
    for pr in prs
      pr.server_win = nil
      Marshal.dump pr
    end
    prs
  end
  
  def add_project( pr="Untitled Project" )
    # if there is no project with same name on server
    if not @projects.map{|p| p.name }.include?((pr.is_a? String) ? pr : pr.name)
      if pr.is_a? ProjectManager
        @projects.push pr
        pr.server_win = @server_win
      else
        new_pr = ProjectManager.new( nil, nil, nil, nil, nil, nil, nil, nil, nil )
        new_pr.name = pr
        new_pr.server_win = @server_win
        @projects.push new_pr
      end
    end
  end
  
  def remove_project pr
    @projects.delete pr
  end
  
  def add_client( login, password )
    for ac in @accounts
      if ac.login == login and ac.password == password
        client_id = new_client_id
        @clients.push Client.new( client_id, ac, [] )
        @clients.uniq!
        return client_id
      end
    end
  end
  
  def remove_client client_id
    @clients.delete_if{|c| c.client_id == client_id }
  end
  
  def exchange_object( projectname, new_object, client_id )
    # check if client is connected and ignore otherwise
    client = @clients.select{|c| c.client_id == client_id }.first
    if client
      # look up project the client wants to modify
      pr = @projects.select{|p| p.name == projectname }.first
      # check if he has the rights to 
      if client.account.registered_projects.include? pr
        # find all occurences of object with same id and replace them
        for inst in pr.all_instances
          if inst.real_component.component_id == new_object.component_id 
            inst.real_component = new_object
          end
        end
        # save change for other clients in this project
        client_ids_to_serve = @clients.select{|c| c.account.registered_projects.include? pr }.map{|c| c.client_id } - [client_id]
        @changes.push Change.new( new_object, client_ids_to_serve )
      end
    end
  end
  
  def get_changes_for client_id
    puts "in get changes"
    objects = []
    for change in @changes
      if change.client_ids_to_serve.include? client_id
        objects.push change.obj
        change.client_ids_to_serve.delete client_id
      end
    end
    puts "after for"
    @changes.delete_if{|c| c.client_ids_to_serve.empty? }
    puts "after delete"
    return objects
  end
  
  def new_client_id
    @used_client_ids ||= []
    new_id = rand 99999999999999999999999999999999999999999 while @used_client_ids.include? new_id
    @used_client_ids.push new_id
    return new_id
  end
  
  def exit
    DRb.stop_service
  end
end


class ProjectClient
  attr_reader :server, :working, :projectname
  def initialize( server, port, manager )
    @server = DRbObject.new_with_uri "druby://#{server}:#{port}" 
    @manager = manager
    # test if server is working
    begin
      @server.get_projects
    rescue
      dialog = Gtk::MessageDialog.new(@manager.main_win, 
                                      Gtk::Dialog::DESTROY_WITH_PARENT,
                                      Gtk::MessageDialog::WARNING,
                                      Gtk::MessageDialog::BUTTONS_CLOSE,
                                      "Connection error")
      dialog.secondary_text = "Could not connect to the requested server"
      dialog.run
      dialog.destroy
      @working = false
    else
      @working = true
    end
  end
  
  def available_projects
    @server.get_projects
  end
  
  def join_project( projectname, login, password )
    @projectname = projectname
    @login = login
    @client_id = @server.add_client( login, password )
    project = available_projects.select{|p| p.name == projectname }.first
    @manager.main_assembly      = project.main_assembly
    @manager.all_assemblies     = project.all_assemblies
    @manager.all_parts          = project.all_parts
    @manager.all_part_instances = project.all_part_instances
    @manager.all_sketches       = project.all_sketches
    @manager.readd_non_dumpable
    @manager.glview.redraw
    start_polling
  end
  
  def start_polling
    @poller = Thread.start do
      loop do
        puts "polling"
        sleep 1
        for new_obj in @server.get_changes_for @client_id
          puts "got change"
          exchange_object new_obj
        end
      end
    end
  end

  def exchange_object new_object
    # find all occurences of object with same id and replace them
    for inst in @manager.all_instances
        if inst.real_component.component_id == new_object.component_id
          inst.clean_up
          inst.real_component = new_object
        end
    end
    new_object.displaylist = @manager.glview.add_displaylist
    new_object.build_displaylist
    @manager.glview.redraw
  end
  
  def component_changed comp
   # @server.exchange_object( @projectname, comp, @client_id )
  end
  
  def exit
    @poller.stop if @poller
    @server.remove_client @client_id
  end
end
