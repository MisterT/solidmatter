#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-07.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'
require 'export.rb'
require 'image.rb'
            
class RenderDialog
	def initialize
	  @glade = GladeXML.new( "../data/glade/render_dialog.glade", nil, 'openmachinist' ) {|handler| method(handler)}
  end

  def ok
    close
    parts = $manager.project.main_assembly.contained_parts.select{|p| p.visible }
    luxdata = generate_luxrender parts, $manager.glview.allocation.width, $manager.glview.allocation.height, false
    File::open("tmp/lux.lxs",'w'){|f| f << luxdata }
    Thread.start{ `./../bin/luxconsole tmp/lux.lxs` }
    $manager.glview.visible = false
    $manager.render_view.visible = true
    @render_thread = Thread.start do
      sleep 4  # to compensate luxrender startup
      loop do
        sleep $preferences[:lux_display_interval]
        if File.exist? "tmp/lux.tga"
          Gtk.queue do
            gtkim = native2gtk Image.new("tmp/lux.tga")
            $manager.render_view.pixbuf = gtkim.pixbuf
          end
        end
      end
    end
  end
	
  def close
    @glade['render_dialog'].destroy
  end
  
  def save_image
    dia = FileOpenDialog.new '.png'
    if dia.run == Gtk::Dialog::RESPONSE_ACCEPT
      filename = dia.filename
      filename += '.png' unless filename =~ /.png/
      im = Image.new "tmp/lux.tga"
      im.save filename
    end
    dia.destroy
  end
  
  def stop_rendering
    `killall luxconsole`
    @render_thread.kill if @render_thread
    $manager.render_view.visible = false
    $manager.glview.visible = true 
  end
  
  def generate_luxrender parts, width, height, heal_mesh
    lxs =  "# Lux Render Scene File\n"
    lxs << "# Exported by Solid|matter\n"
    # setup camera
    cam = $manager.glview.cameras[$manager.glview.current_cam_index]
    lxs << "LookAt #{cam.position.x} #{cam.position.y} #{cam.position.z} #{cam.target.x} #{cam.target.y} #{cam.target.z} 0 1 0 \n"
    lxs << 'Camera "perspective" "float fov" [49.134342] "float hither" [0.100000] "float yon" [100.000000] 
                   "float lensradius" [0.050000] "bool autofocus" ["true"] "float shutteropen" [0.000000] 
                   "float shutterclose" [1.000000] "float screenwindow" [-1.000000 1.000000 -0.750000 0.750000]
           '
    # setup frame and render settings
    lxs << "Film \"fleximage\" \"integer xresolution\" [#{width}] \"integer yresolution\" [#{height}] \"integer haltspp\" [0] 
                 \"float reinhard_prescale\" [1.000000] \"float reinhard_postscale\" [1.800000] \"float reinhard_burn\" [6.000000] 
                 \"bool premultiplyalpha\" [\"true\"] \"integer displayinterval\" [10] \"integer writeinterval\" [#{$preferences[:lux_display_interval]}] 
                 \"string filename\" [\"lux\"] \"bool write_tonemapped_tga\" [\"true\"] 
                 \"bool write_tonemapped_exr\" [\"false\"] \"bool write_untonemapped_exr\" [\"false\"] \"bool write_tonemapped_igi\" [\"false\"] 
                 \"bool write_untonemapped_igi\" [\"false\"] \"bool write_resume_flm\" [\"false\"] \"bool restart_resume_flm\" [\"false\"] 
                 \"integer reject_warmup\" [3] \"bool debug\" [\"false\"] \"float colorspace_white\" [0.314275 0.329411] 
                 \"float colorspace_red\" [0.630000 0.340000] \"float colorspace_green\" [0.310000 0.595000]
                 \"float colorspace_blue\" [0.155000 0.070000] \"float gamma\" [2.200000]
           PixelFilter \"gaussian\" \"float xwidth\" [1.000000] \"float ywidth\" [1.000000] \"float alpha\" [2.000000]
           Sampler \"metropolis\" \"float largemutationprob\" [0.400000] \"integer maxconsecrejects\" [128]
           SurfaceIntegrator \"path\" \"integer maxdepth\" [5] \"string strategy\" [\"auto\"] \"string rrstrategy\" [\"efficiency\"]
           VolumeIntegrator \"single\" \"float stepsize\" [1.000000]
           Accelerator \"tabreckdtree\" \"integer intersectcost\" [80] \"integer traversalcost\" [1] \"float emptybonus\" [0.200000]
                       \"integer maxprims\" [1] \"integer maxdepth\" [-1]
          "
    lxs << "WorldBegin\n"
    # create lights
    lxs << 'AttributeBegin
            	LightSource "infinite" "color L" [0.0565629 0.220815 0.3]
            AttributeEnd
           '
    lxs << 'AttributeBegin
           	Transform [-0.290864646435 1.35517116785 -0.0551890581846 0.0  -0.771100819111 -0.19988335669 0.604524731636 0.0  0.566393196583 0.21839119494 0.794672250748 0.0  4.07624530792 1.00545394421 5.90386199951 1.0]
           	AreaLightSource "area" "color L" [0.900000 0.900000 0.900000] "float gain" [10.427602]
            "color L" [0.900000 0.900000 0.900000] "float gain" [15.0]	Shape "trianglemesh" "integer indices" [0 1 2 0 2 3] "point P" [-1.000000 1.000000 0.0 1.000000 1.000000 0.0 1.000000 -1.000000 0.0 -1.000000 -1.000000 0.0]
           AttributeEnd
           '
    puts "static stuff finished"
    # create materials
    lxs << 'MakeNamedMaterial "lux_clayMat" "string type" ["matte"] "color Kd" [0.900000 0.900000 0.900000]
    '
    # convert geometry
    for p in parts
      puts "building part"
      lxs << "AttributeBegin\n"
      lxs << "Transform [#{p.position.to_a.join ' '} #{p.position.to_a.join ' '} 1.0]\n"
      lxs << 'NamedMaterial "lux_clayMat"
      '
      tris = p.solid.tesselate heal_mesh
      puts "tesselated"
      lxs << 'Shape "trianglemesh" "integer indices" ['
      tris.size.times{|i| lxs << "#{i*3} #{i*3+1} #{i*3+2} \n" }
      puts "generated indices"
      lxs << "]\n"
      lxs << '"point P" ['
      tris.flatten.each{|v| lxs << v.to_a.map{|e| e * 1.0 }.join(" ") << "\n" }
      puts "generated vertices"
      lxs << "]\n"
      lxs << "AttributeEnd\n"
    end
    # create groundplane
    tris = [ [Vector[-100, 0, -100], Vector[-100, 0, 100], Vector[100, 0, -100]], 
             [Vector[-100, 0, 100],  Vector[100, 0, 100],  Vector[100, 0, -100]] ]
    lxs << "AttributeBegin\n"
    lxs << 'NamedMaterial "lux_clayMat"
    '
    lxs << 'Shape "trianglemesh" "integer indices" ['
    tris.size.times{|i| lxs << "#{i*3} #{i*3+1} #{i*3+2} \n" }
    lxs << "]\n"
    lxs << '"point P" ['
    tris.flatten.each{|v| lxs << v.to_a.join(" ") << "\n" }
    lxs << "]\n"
    lxs << "AttributeEnd\n"
    lxs << "WorldEnd\n"
  end
end

