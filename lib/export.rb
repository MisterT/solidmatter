#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'ui/file_open_dialog.rb'
require 'ui/export_dialog.rb'


class Exporter
  def export parts
    ExportDialog.new do |filetype, heal_mesh|
      dia = FileOpenDialog.new filetype
      if dia.run == Gtk::Dialog::RESPONSE_ACCEPT
        filename = dia.filename
        filename += filetype unless filename =~ Regexp.new(filetype)
        data = case filetype
          when '.stl' : generate_stl parts, heal_mesh
          when '.lxs' : generate_luxrender parts, heal_mesh
        end
        File::open(filename,"w"){|f| f << data }
      end
      dia.destroy
    end
  end

  def generate_stl parts, heal_mesh
    stl = "solid #{@name}\n"
    for p in parts
      for tri in p.solid.tesselate heal_mesh
        n = tri[0].vector_to(tri[1]).cross_product(tri[0].vector_to tri[2]).normalize
        n = Vector[0.0, 0.0, 0.0] if n.x.nan?
        stl += "  facet normal #{n.x} #{n.y} #{n.z}\n"
        stl += "    outer loop\n"
        for v in tri
          stl += "    vertex #{v.x} #{v.y} #{v.z}\n"
        end
        stl += "    endloop\n"
        stl += "  endfacet\n"
      end
    end
    stl += "endsolid #{@name}\n"
    return stl
  end
  
  def generate_luxrender parts, heal_mesh
    lxs =  "# Lux Render Scene File\n"
    lxs << "# Exported by Solid|matter\n"
    # setup camera
    cam = $manager.glview.cameras[$manager.glview.current_cam_index]
    lxs << "LookAt #{cam.position.x} #{cam.position.y} #{cam.position.z} #{cam.target.x} #{cam.target.y} #{cam.target.z} 0 1 0 \n"
    lxs << 'Camera "perspective" "float fov" [49.134342] "float hither" [0.100000] "float yon" [100.000000] 
                   "float lensradius" [0.000000] "bool autofocus" ["true"] "float shutteropen" [0.000000] 
                   "float shutterclose" [1.000000] "float screenwindow" [-1.000000 1.000000 -0.750000 0.750000]
           '
    # setup frame and render settings
    lxs << 'Film "fleximage" "integer xresolution" [640] "integer yresolution" [480] "integer haltspp" [0] 
                 "float reinhard_prescale" [1.000000] "float reinhard_postscale" [1.800000] "float reinhard_burn" [6.000000] 
                 "bool premultiplyalpha" ["true"] "integer displayinterval" [6] "integer writeinterval" [10] 
                 "string filename" ["lux"] "bool write_tonemapped_tga" ["true"] 
                 "bool write_tonemapped_exr" ["false"] "bool write_untonemapped_exr" ["false"] "bool write_tonemapped_igi" ["false"] 
                 "bool write_untonemapped_igi" ["false"] "bool write_resume_flm" ["false"] "bool restart_resume_flm" ["false"] 
                 "integer reject_warmup" [3] "bool debug" ["false"] "float colorspace_white" [0.314275 0.329411] 
                 "float colorspace_red" [0.630000 0.340000] "float colorspace_green" [0.310000 0.595000]
                 "float colorspace_blue" [0.155000 0.070000] "float gamma" [2.200000]
           PixelFilter "gaussian" "float xwidth" [1.000000] "float ywidth" [1.000000] "float alpha" [2.000000]
           Sampler "metropolis" "float largemutationprob" [0.400000] "integer maxconsecrejects" [128]
           SurfaceIntegrator "path" "integer maxdepth" [5] "string strategy" ["auto"] "string rrstrategy" ["efficiency"]
           VolumeIntegrator "single" "float stepsize" [1.000000]
           Accelerator "tabreckdtree" "integer intersectcost" [80] "integer traversalcost" [1] "float emptybonus" [0.200000]
                       "integer maxprims" [1] "integer maxdepth" [-1]
          '
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


