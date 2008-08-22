#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2007-01-19.
#  Copyright (c) 2007. All rights reserved.

require 'RMagick'

class Magick::Image
  alias width columns
  alias height rows
end

class Image
include Enumerable
attr_accessor :im
  def initialize( *args )
    if args.size > 1
      width, height = args
      @im = Magick::Image.new( width , height ) do
      	self.background_color = 'dimgrey'
      end
    else
      filename = args.first
      load filename
    end
  end
  
  def pixel( x,y )
    #raise "BufferOverrun at x:#{x} y:#{y} for width:#{width} height:#{height}" if x >= width or y >= height
    color = @im.get_pixels( x,y, 1,1 ).first
    return Pixel.new( color.red.to_f / Magick::MaxRGB, color.green.to_f / Magick::MaxRGB, color.blue.to_f / Magick::MaxRGB, 1.0 - (color.opacity.to_f / Magick::MaxRGB) )
  end
  
  def set_pixel( x,y, value )
    #raise "BufferOverrun at x:#{x} y:#{y} for width:#{width} height:#{height}" if x >= width or y >= height
    pixel = Magick::Pixel.new( value.red * Magick::MaxRGB, value.green * Magick::MaxRGB, value.blue * Magick::MaxRGB, (1.0 - value.alpha) * Magick::MaxRGB )
    @im.pixel_color(x,y, pixel )
  end
  
  def each
    for x in 0...width
      for y in 0...height
        yield pixel( x,y )
      end
    end
  end
  
  def each_pixel
    for x in 0...width
      for y in 0...height
        yield x,y, pixel( x,y )
      end
    end
  end
  
  def load( filename )
    @im = Magick::Image.read(filename).first
  end

  def save( filename )
    @im.write filename
  end
  
  def width
    @im.width
  end
  
  def height
    @im.height
  end
  
  def to_tiny
    self #TinyImage.new self
  end
  
  def marshal_dump
    [width, height, @im.export_pixels_to_str( 0, 0, width, height, "RGBA" )]
  end
  
  def marshal_load data
    width, height, raw = data
    initialize(width, height)
    @im.import_pixels( 0, 0, width, height, "RGBA", raw )
  end
  
	def method_missing( method, *args )
		args.map!{|a| (a.is_a? Image) ? a.im : a }
		new_im = @im.send( method, *args )
		if new_im.is_a? Magick::Image
		  native_im = Image.new( new_im.width, new_im.height )
		  native_im.im = new_im
		  return native_im
	  else
	    return new_im
    end
	end
end

=begin
class TinyImage
  def initialize image
    @im = Array.new image.width
    for x in 0...image.width
      @im[x] = []
      for y in 0...image.height
        @im[x].push image.pixel( x,y )
      end
    end
    @width = image.columns
    @height = image.rows
    #@im = image.export_pixels_to_str( 0, 0, @width, @height, "RGBA" )
  end
  
  def to_native
    native = Image.new( @im.size, @im[0].size )
    for x in 0...native.width
      for y in 0...native.height
        native.set_pixel( x,y, @im[x][y])
      end
    end
    #native = Image.new @width, @height
    #native.import_pixels( 0, 0, @width, @height, "RGBA", @im )
    return native
  end
end
=end

class Pixel
	attr_accessor :red, :green, :blue, :alpha
	alias hue red
	alias saturation green
	alias value blue
  def initialize( r=0.0, g=0.0, b=0.0, a=1.0)
    @red   = r
    @green = g 
    @blue  = b
    @alpha = a
  end

	# h = 0..360, s = 0..1, v = 0..1
  def hsv
		min = [@red, @green, @blue].min
		max = [@red, @green, @blue].max
		value = max
		delta = max - min
		if max == 0 
			saturation = 0
		else
			saturation = delta / max
		end
		if @red == max 
			# between yellow & magenta
			hue = ( @green - @blue ) / delta		
		elsif @green == max 
			# between cyan & yellow
			hue = 2 + ( @blue - @red ) / delta
		else
			# between magenta & cyan
			hue = 4 + ( @red - @green ) / delta
		end
		hue = 1 if hue.nan? or hue.infinite?
		# degrees
		hue *= 60				
		hue += 360 if hue < 0 
		return Pixel.new( hue, saturation, value )
  end
  
  def difference( pix )
    (@red   - pix.red).abs   +
    (@green - pix.green).abs +
    (@blue  - pix.blue).abs  +
    (@alpha - pix.alpha).abs 
  end
  
  def multiply( value )
    @red   *= value
    @green *= value
    @blue  *= value
    @alpha *= value
  end
  
  def add( pix )
    @red   += pix.red
		@green += pix.green
		@blue  += pix.blue
		@alpha += pix.alpha
  end
	
	def to_s
	 return "r:#{@red} g:#{@green} b:#{@blue} a:#{@alpha}"
	end
	
	def to_a
	  [@red, @green, @blue, @alpha]
	end
end
