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
  def initialize( *args )
    if args.size > 1
      width, height = args
      resize( width, height )
    else
      filename = args.first
      load filename
    end
  end
  
  def resize( width, height )
    @buffer = Array.new width
    for x in 0...width
      @buffer[x] = Array.new height
      for y in 0...height
        @buffer[x][y] = Pixel.new
      end
    end
  end
  
  def pixel( x,y )
    raise "BufferOverrun at x:#{x} y:#{y} for width:#{width} height:#{height}" if x >= width or y >= height
    @buffer[x][y]
  end
  
  def set_pixel( x,y, value )
  	#puts x,y
    raise "BufferOverrun at x:#{x} y:#{y} for width:#{width} height:#{height}" if x >= width or y >= height
    @buffer[x][y] = value
  end
  
  def each
    for x in 0...width
      for y in 0...height
        yield @buffer[x][y]
      end
    end
  end
  
  def each_pixel
    for x in 0...width
      for y in 0...height
        yield x,y, @buffer[x][y]
      end
    end
  end
  
  def load( filename )
    im = Magick::Image.read(filename).first
    resize( im.width, im.height )
    for x in 0...im.width
      for y in 0...im.height
        color = im.pixel_color( x,y )
        pixel = Pixel.new( color.red.to_f / Magick::MaxRGB, color.green.to_f / Magick::MaxRGB, color.blue.to_f / Magick::MaxRGB )
        set_pixel( x,y, pixel )
      end
    end
  end

  def save( filename )
    im = Magick::Image.new( width, height )
    each_pixel do |x,y, pix|
      pixel = Magick::Pixel.new( pix.red * Magick::MaxRGB, pix.green * Magick::MaxRGB, pix.blue * Magick::MaxRGB, 0 )
      im.pixel_color(x,y, pixel )
    end
    im.write filename
  end
  
  def width
    @buffer.size
  end
  
  def height
    @buffer[0].size
  end
end


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
	alias * multiply
  
  def add( pix )
    @red   += pix.red
		@green += pix.green
		@blue  += pix.blue
		@alpha += pix.alpha
  end
	alias + add
	
	def to_s
	 return "r:#{@red} g:#{@green} b:#{@blue}"
	end
end
