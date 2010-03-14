--[[
=pod

=head1 NAME

cpu.lua - wmiirc-lua plugin for monitoring acpi stuff

=head1 SYNOPSIS

    -- in your wmiirc.lua:
    wmii.load_plugin("cpu")


=head1 DESCRIPTION

=head1 SEE ALSO

L<wmii(1)>, L<lua(1)>

=head1 AUTHOR

Jan-David Quesel <jdq@gmx.net>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Jan-David Quesel <jdq@gmx.net>

This is free software.  You may redistribute copies of it under the terms of
the GNU General Public License L<http://www.gnu.org/licenses/gpl.html>.  There
is NO WARRANTY, to the extent permitted by law.

=cut
--]]

local wmii = require("wmii")
local os = require("os")
local posix = require("posix")
local io = require("io")
local type = type
local error = error
local pairs = pairs
local tostring = tostring
local string = string

module("cpugraph")
api_version = 0.1

-- ------------------------------------------------------------
-- MODULE VARIABLES
local widget = nil
local timer  = nil

widget = wmii.widget:new ("400_cpugraph")

-- global var.. do these exist?
local history = { }

-- ------------------------------------------------------------
-- looks into /sys/devices/system/cpu and gets a list of all 
-- 	cpus in the system.. returns it as a list
local function cpu_list()
	local dir = "/sys/devices/system/cpu/"
	local _,cpu
	local list = {}
	for _,cpu in pairs(posix.glob(dir .. 'cpu[0-9]*')) do
		local stat
		if cpu then
			stat = posix.stat(cpu)
			if stat and stat.type == 'directory' then
				list[#list+1] = cpu
			end
		end
	end
	return list
end


function read_file(path)
	local fd = io.open(path, "r")
	if fd == nil then
		return nil
	end

	local text = fd:read("*a")
	fd:close()

	if type(text) == 'string' then
		text = text:match('(%w+)')
	end

	return text
end


local function create_string(cpu)

	-- read all the info we need and define other vars
	local curfreq = (read_file(cpu .. '/cpufreq/scaling_cur_freq') / 1) or 0
	local minfreq = (read_file(cpu .. '/cpufreq/scaling_min_freq') / 1) or 0
	local maxfreq = (read_file(cpu .. '/cpufreq/scaling_max_freq') / 1) or 0
	local increment = (maxfreq - minfreq) / 3
	local freqsym = " "
	local cpuname = string.gsub(cpu, ".*/", "")

	-- figure out what symbol to use.. we split the bar into 3
	if (curfreq <= minfreq + increment) then
		freqsym = "."
	elseif (curfreq <= (minfreq + 2*increment)) then
		freqsym = "o"
	else 
		freqsym = 'O'
	end

	-- now shift over the history if needed and glue on this char
	history[cpuname] = string.sub(history[cpuname], 2, -1)
	history[cpuname] = history[cpuname] .. freqsym

	-- now that we are done, return it
	return history[cpuname]
end


function update ()
	local txt = ""
	local _, cpu
	local list = cpu_list()
	local space = ""
	for _,cpu in pairs(list) do
		txt = txt .. space .. create_string(cpu)
		space = "   "
	end

	widget:show(txt)
end

local function cpu_timer ( timer )
	update()
	return 3
end


local function init_history ()
	local txt = ""
	local _, cpu
	local list = cpu_list()
	local space = ""
	for _,cpu in pairs(list) do
		local cpuname = string.gsub(cpu, ".*/", "")
		history[cpuname] = string.rep("_", 10)
	end
end

-- initialize the values in our history var for all the cpus we have
init_history()

-- now setup our timer to call the update function
timer = wmii.timer:new (cpu_timer, 3)
