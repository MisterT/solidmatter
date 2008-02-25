#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-01-06.
#  Copyright (c) 2008. All rights reserved.

require 'drb'
require 'lib/project_manager.rb'
require 'lib/account_editor.rb'
require 'lib/save_request_dialog.rb'
require 'lib/wait_for_save_dialog.rb'


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

Change = Struct.new( :obj_or_id, :type, :client_ids_to_serve )

Request = Struct.new( :type, :what, :client_ids_to_serve, :client_ids_received, :num_accepted, :id )


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
    @requests = []
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
        client_id = new_id
        @clients.push Client.new( client_id, ac, [] )
        @clients.uniq!
        return client_id
      end
    end
    return nil
  end
  
  def remove_client client_id
    @clients.delete_if{|c| c.client_id == client_id }
  end
  
  def exchange_object( projectname, new_object, client_id )
    on_project_if_valid( projectname, client_id ) do |pr|
      # find all occurences of object with same id and replace them
      for inst in pr.all_instances
        if inst.real_component.component_id == new_object.component_id 
          inst.real_component = new_object
        end
      end
      # save change for other clients in this project
      client_ids_to_serve = @clients.select{|c| c.account.registered_projects.include? pr }.map{|c| c.client_id } - [client_id]
      @changes.push Change.new( new_object, :change, client_ids_to_serve )
    end
  end
  
  def add_object( projectname, new_object, client_id )
    on_project_if_valid( projectname, client_id ) do |pr|
      pr.add_object new_object
      client_ids_to_serve = @clients.select{|c| c.account.registered_projects.include? pr }.map{|c| c.client_id } - [client_id]
      @changes.push Change.new( new_object, :add, client_ids_to_serve )
    end
  end
  
  def delete_object( projectname, obj_id, client_id )
    on_project_if_valid( projectname, client_id ) do |pr|
      pr.delete_object obj_id
      client_ids_to_serve = @clients.select{|c| c.account.registered_projects.include? pr }.map{|c| c.client_id } - [client_id]
      @changes.push Change.new( obj_id, :delete, client_ids_to_serve )
    end
  end
  
  def on_project_if_valid( projectname, client_id )
    # check if client is connected and ignore otherwise
    client = @clients.select{|c| c.client_id == client_id }.first
    if client
      # look up project the client wants to modify
      pr = @projects.select{|p| p.name == projectname }.first
      # check if he has the rights to 
      if client.account.registered_projects.include? pr
        yield pr
      end
    end
  end
  
  def get_changes_for client_id
    objects = []
    for change in @changes
      # if there is still something for client
      if change.client_ids_to_serve.include? client_id
        objects.push [change.obj_or_id, change.type]
        # make sure client's not changed twice
        change.client_ids_to_serve.delete client_id
      end
    end
    # delete change when everybody already has it
    @changes.delete_if{|c| c.client_ids_to_serve.empty? }
    return objects
  end
  
  def new_request( type, projectname, client_id )
    ids_to_serve = @clients.select{|c| c.account.registered_projects.include? projectname }.map{|c| c.client_id } - [client_id]
    re = Request.new( type, projectname, ids_to_serve, [], 0, new_id )
    @requests.push re
    return re.id
  end
  
  def accept_request( request_id, client_id )
    # memorize that client accepted
    re = @requests.select{|r| r.id == request_id }.first
    re.num_accepted += 1
    # take action if everybody accepted
    if re.num_accepted == re.client_ids_to_serve.size + 1
      case re.type
      when :save then
        pr = @projects.select{|p| p.name == re.what }.first
        pr.filename = "hosted_projects/#{pr.name}"
        pr.save_file
      end
      @requests.delete re
      @requests.push Request.new( :accepted, re.id, re.ids_to_serve, 0, new_id )
    end
  end
  
  def cancel_request( request_id, client_id )
    # delete original request
    re = @requests.select{|r| r.id == request_id }.first
    @requests.delete re
    # create cancel-request to make sure clients cancel too
    @request.push Request.new( :cancel, re.id, re.ids_to_serve, 0, new_id )
  end
  
  def get_requests_for client_id
    requests = []
    for re in @requests
      # if there is still something for client
      unless re.client_ids_received.include? client_id
        requests.push [re.type, re.what, re.id]
        # make sure client's not requested twice
        re.client_ids_received.push client_id
      end
    end
    # delete all informational requests. Save requests must be kept around until cancelled or accepted
    @requests.delete_if{|r| r.type == :save ? false : (r.client_ids_received.size == r.client_ids_to_serve.size) }
    return requests
  end
  
  def new_id
    @used_ids ||= []
    id = rand 99999999999999999999999999999999999999999 while @used_ids.include? id
    @used_ids.push id
    return id
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
    if @client_id
      project = available_projects.select{|p| p.name == projectname }.first
      @manager.exchange_all_gl_components do 
        @manager.main_assembly      = project.main_assembly
        @manager.all_assemblies     = project.all_assemblies
        @manager.all_parts          = project.all_parts
        @manager.all_part_instances = project.all_part_instances
        @manager.all_sketches       = project.all_sketches
      end
      @manager.readd_non_dumpable
      @manager.op_view.update
      @manager.glview.redraw
      start_polling
      return true
    else
      dialog = Gtk::MessageDialog.new(@manager.main_win, 
                                      Gtk::Dialog::DESTROY_WITH_PARENT,
                                      Gtk::MessageDialog::WARNING,
                                      Gtk::MessageDialog::BUTTONS_CLOSE,
                                      "Login failed")
      dialog.secondary_text = "Please make sure that your login information is correct"
      dialog.run
      dialog.destroy
      return false
    end
  end
  
  def start_polling
    @poller = Thread.start do
      loop do
        # get model changes from server
        for changes in @server.get_changes_for @client_id
          for obj_or_id, type in changes
            case type
            when :change then
              exchange_object obj_or_id
            when :add then
              @manager.add_object obj_or_id
            when :delete then
              @manager.delete_object obj_or_id
            end
          end
        end
        # get action requests from server
        for type, what, id in @server.get_requests_for @client_id
          case type
          when :save then
            puts "save request received"
            @save_request_id = id
            @save_dialog = SaveRequestDialog.new self
          when :cancel then
            @wait_dialog.close if @wait_dialog
            @save_dialog.close if @save_dialog
            dialog = Gtk::MessageDialog.new(@manager.main_win, 
                                            Gtk::Dialog::DESTROY_WITH_PARENT,
                                            Gtk::MessageDialog::INFO,
                                            Gtk::MessageDialog::BUTTONS_CLOSE,
                                            "Request canceled")
            dialog.secondary_text = "The save request was cancelled by another user"
            dialog.run
            dialog.destroy
          when :accepted then
            puts "accepted message received"
            @wait_dialog.close
          end
        end
        sleep 1
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
    # setup open gl
    new_object.displaylist = @manager.glview.add_displaylist
    new_object.build_displaylist
    @manager.glview.redraw
  end
  
  def save_request
    if @save_request_id
      accept_save_request
    else
      @save_request_id = @server.new_request( :save, @projectname, @client_id )
      accept_save_request
      @wait_dialog = WaitForSaveDialog.new self
    end
  end
  
  def accept_save_request 
    @server.accept_request( @save_request_id, @client_id )
    @save_request_id = nil
    @wait_dialog = WaitForSaveDialog.new self
  end
  
  def cancel_save_request
    @server.cancel_request( @save_request_id, @client_id )
    @save_request_id = nil
  end
  
  def component_changed comp
    @server.exchange_object( @projectname, comp, @client_id ) if @client_id
  end
  
  def component_added comp
    @server.add_object( @projectname, comp, @client_id )
  end
  
  def component_deleted inst_id
    @server.delete_object( @projectname, inst_id, @client_id )
  end
  
  def exit
    @poller.kill if @poller
    @server.remove_client @client_id if @client_id
  end
end
