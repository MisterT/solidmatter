#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-08-07.
#  Copyright (c) 2008. All rights reserved.

module Units
  CONVERSION_FACTORS = {
    :mm => 10.0,
    :cm => 1.0,
    :m => 0.01
  }
  POWERS = {
    1 => '',
    2 => '²',
    3 => '³'
  }

  def enunit( value, power=1, usys=$manager.project.unit_system )
    power.times{ value *= CONVERSION_FACTORS[usys.to_sym] }
    value = value.to_s.gsub(/.[0-9]+/){|m| m[0..$preferences[:decimal_places]] }
    value + usys.to_s + POWERS[power]
  end

  def ununit( value, power=1, usys=$manager.project.unit_system )
    power.times{ value /= CONVERSION_FACTORS[usys.to_sym] }
    value
  end
end
