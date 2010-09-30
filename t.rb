#!/usr/bin/env ruby

require 'rubygems'
require 'builder'

builder = Builder::XmlMarkup.new


builder.top do |top|
    top.cdata! do |cdata|
        "joejoejoejoe"
    end
end

p builder

