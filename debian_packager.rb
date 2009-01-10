#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2009-01-10
#  Copyright (c) 2009. All rights reserved.

require 'fileutils'
include FileUtils

begin
  # create system directory structure
  v = VERSION[0..2]
  mkdir_p "debian/usr/lib/ruby/site_ruby/#{v}/solid_matter/data"
  cp_r 'bin', 'debian/usr/bin'
  cp_r 'lib', "debian/usr/lib/ruby/site_ruby/#{v}/solid_matter/lib"
  cp_r 'data/glade', "debian/usr/lib/ruby/site_ruby/#{v}/solid_matter/data/glade"
  cp_r 'data/schemas', "debian/usr/lib/ruby/site_ruby/#{v}/solid_matter/data/schemas"
  mkdir 'debian/DEBIAN'
  # create debian package description
  control = 'Package: solid-matter
Version: 0.1
Section: graphics 
Priority: optional
Architecture: all
Essential: no
Pre-Depends: gtkglext 
Depends: ruby-gnome2 (>= 0.17), librmagick-ruby, libdbus-ruby, libnarray-ruby
Recommends: luxrender
Installed-Size: 13746
Maintainer: Bjoern Breitgoff <breidibreit@web.de>
Description: Solid|matter
             A parametrical 3D-CAD application for
             the Gnome desktop enviroment.
'
  File.open('debian/DEBIAN/control', 'w' ){|f| f << control }
  # update translation file
  #require 'post-setup.rb'
  # create post-install script for schemas
  postinst = '#!/usr/bin/env ruby
    ENV["GCONF_CONFIG_SOURCE"] = `gconftool-2 --get-default-source`.chomp
    Dir["data/schemas/*.schemas"].each do |schema|
      system("gconftool-2 --makefile-install-rule \'#{schema}\'")
    end
  '
  File.open('debian/DEBIAN/postinst', 'w' ){|f| f << postinst ; f.chmod(0755) }
  postinst =
  # create debian package
  `dpkg -b debian solid-matter_0.1.0_all.deb`
ensure
  rm_r 'debian'
end

