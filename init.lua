--[[ mod subnodes_registerer by Tagada 2018, april 19th
]]

-- context :
subnodes_registerer = {}

local debug_msg = true		-- debug : execute the local function mydebug() that fill minetest.log and/or tchat ?


--[[ what this mod does :

	the idea is to allow any mod that do something like shaped blocks from a full block to
	be called by subnodes_registerer with needed parameters about a clicked full block.
	
]]

local function mydebug(context, msg, playername)
-- context may be 	"log" - then send msg to minetest.log;
--					"tchat" - then send msg to minetest.chat_send_player;
-- 					otherwise do nothing as if local debug_msg was false;
if debug_msg~=true then return end

	if context=="log" then 
		minetest.log(msg)
		return
	end
	
	if context=="tchat" then
		if playername~=nil then
			minetest.chat_send_player(playername, msg)
		end
		return
	end
	
	if context=="both" then
		minetest.log(msg)
		if playername~=nil then
			minetest.chat_send_player(playername, msg)
		end
	end
end


--[[ test for external call :
local test_func = "coucou" -- a function specialy writen in stairs/init.lua that write something in mt.log for testing
local test_params = {"param1","param2"}
_G[test_func](test_params)
local test_str = "stairs.coucou('dofile_mod_name',true,{value=13, string='a string', table={1,2}})"
local file = io.open(minetest.get_modpath(minetest.get_current_modname()).."/funcexec.lua","w")
file:write(test_str)
file:close()
dofile(minetest.get_modpath(minetest.get_current_modname()).."/funcexec.lua") -- test ok :)
local test_result = loadstring(test_str)
test_result()	-- test ok :)


-- test to see what is inside global lua variable _G :
mydebug("log","Lua global _G=\n"..dump(_G))

]]

--[[ compatibility with mod security :
As i meet an issue during development, it appear that mod "security" disallow file access 
in the mod directory at run-time, but access stay enabled to world path.
trying to make a world_path/my_subdir had failed (sure i'm not so good in programming), 
so :
all data files needed to be read/writen/updated at runtime (or supposed to be) are stored in
minetest.get_worldpath() / the_file_name;
for modders which would like to create a special data directory for subnodes_registerer to store 
it's own data files, i've implemented the data_dir variable that is yet an empty string but
 taken in account when build full files name.
]]

local data_dir = "" -- eventualy, a subdirectory in world path for subnodes_registerer to store datas
local files_prefix = minetest.get_worldpath()
local is_moreblocks = minetest.get_modpath("moreblocks")
local is_stairs = minetest.get_modpath("stairs")
local is_columnia = minetest.get_modpath("columnia")

if not is_moreblocks and not is_stairs and not is_columnia then
	return
end
-- end of prerequisite rule #1

-- function to check the "/" at the end of a directory name (and add if missing):
local function check_dir(path)
	if path:sub(-1)~= "/" and path:sub(-1)~="\\" and path~="" then
		mydebug("log","check_dir will add a slash ending : "..path)
		return path.."/"
	else
		mydebug("log", "check_dir will add nothing to :"..path)
		return path
	end
end

-- register privileges for this mod :
minetest.register_privilege("subnodes_registerer_user", {
    description = "Can uses the subnodes_registerer tool",
    give_to_singleplayer = false,
})
minetest.register_privilege("subnodes_registerer_controler", {
    description = "Can validate a request to add block to be processed into sub-blocks",
    give_to_singleplayer = false,
})
minetest.register_privilege("subnodes_registerer_admin", {
    description = "Can use all options of subnodes_registerer mod",
    give_to_singleplayer = false,
})

local block_already_in_csaw,
	  block_already_in_stairs,
	  block_already_in_columnia = nil,nil,nil

-- read settings file :
-- WIP : do nothing at this time else loading a txt file into context var
-- as it is done at load time (not runtime) the file is stored in mod_path.
local settings = io.open(minetest.get_modpath(minetest.get_current_modname()).."/settings.txt","r")
mydebug("log", "Subnodes_registerer : reading file settings.txt :")
subnodes_registerer.settings = { txt = {}}
local num = 0
for line in settings:lines() do
	num = num+1
	subnodes_registerer.settings.txt[num] = line
	mydebug("log", line)
end

--[[ read mods2call.dat file into subnodes_registerer.mods2call :
	minimal content of this file should reference mods stairs, stairsplus (for circular saw from moreblocks) and columnia.
	content will be :
]]
subnodes_registerer.mods2call = { 
	stairsplus = {
		{ func_name = "register_all",
		parameters = {
			{value_type = {"field"}, value = {"mode_name"}},
			{value_type = {"field"}, value = {"short_name"}},
			{value_type = {"field"}, value = {"full_name"}},
			{value_type = {"field"}, value = {"fields"}},
			},
		override_fields = true,
		override_rules = {never={types={"function"}}}
		},
		{ func_name = "table.insert",
		parameters = {
			{value_type = {"string"}, value = {"circular_saw.known_stairs"}},
			{value_type = {"field"},  value = {"full_name"}},
			}
		},
		typical_derivated = { -- will be used to check if a full block is already derivated by this mod
			field_to_check = "name",
			content = {
				{value_type = {"string", "field"}, value = {"moreblock:slope_", "short_name"}},
				{value_type = {"field","string","field"}, value = {"mod_name", ":slope_", "short_name"}},
			}
		}
	},
	stairs = {
		{ func_name = "stairs.register_stair_and_slab",
		parameters = {
			{value_type = {"field"}, value = {"short_name"}},
			{value_type = {"field"}, value = {"full_name"}},
			{value_type = {"field"}, value = {"groups"}},
			{value_type = {"field"}, value = {"tiles"}},
			{value_type = {"field","string"}, value = {"description"," stair"}},
			{value_type = {"field","string"}, value = {"description"," slab"}},
			{value_type = {"field"}, value = {"sounds"}},
			},
		override_fields = true,
-- override_rules is not said, so it will be nil and then replaced by default rule (no function)
		typical_derivated = { -- will be used to check if a full block is already derivated by this mod
			field_to_check = "name",
			content = {
				{value_type = {"string", "field"}, value = {"stairs:stair_", "short_name"}},
			}
		}

		},
	},
	columnia = {
		{ func_name = "register_column_ia",
		parameters = {
			{value_type = {"field"}, value = {"short_name"}},
			{value_type = {"field"}, value = {"full_name"}},
			{value_type = {"field"}, value = {"groups"}},
			{value_type = {"field"}, value = {"tiles"}},
			{value_type = {"field","string"}, value = {"description"," Column"}},
			{value_type = {"field","string"}, value = {"description"," Column Top"}},
			{value_type = {"field","string"}, value = {"description"," Column Bottom"}},
			{value_type = {"field","string"}, value = {"description"," Column Crosslink"}},
			{value_type = {"field","string"}, value = {"description"," Column Link"}},
			{value_type = {"field","string"}, value = {"description"," Column Linkdown"}},
			{value_type = {"field"}, value = {"sounds"}},
		},
		override_fields = true,
		typical_derivated = { -- will be used to check if a full block is already derivated by this mod
			field_to_check = "description",
			content = {
				{value_type = {"field","string"}, value = {"description", "Column"}},
			}
		}
		
		},
	}
}
--]]
--[[]]
files_prefix = check_dir(minetest.get_worldpath())..check_dir(data_dir)
local file_mods2call = io.open(files_prefix.."subnodes_registerer_mods2call.dat", "wb")

if file_mods2call then
	file_mods2call:write(minetest.serialize(subnodes_registerer.mods2call))
	file_mods2call:close()
end
-- recall the file to test :
--]]

-- file mods2call may be accessed at run-time by admin or by program, so file is stored in world path
files_prefix = check_dir(minetest.get_worldpath())..check_dir(data_dir)
local file_mods2call, error_msg = io.open(files_prefix.."subnodes_registerer_mods2call.dat", "rb")
if file_mods2call then
	subnodes_registerer.mods2call = minetest.deserialize(file_mods2call:read("*all"))
	mydebug("log", "subnode_registerer: the mods2call.dat file is loaded :\n"..dump(subnodes_registerer.mods2call))
	file_mods2call:close()
else
	minetest.log("subnodes_registerer error : the mods2call.dat file has not been loaded. "..
		"error message from io.open is :\n"..error_msg)
	minetest.log("there is no mod to call for subnodes_registerer to work, so subnodes_registerer will quit.")
	return false
end

--[[ read blocks2process.dat file and process blocks that have been validated by accredited player :
	by the time, this table will accumulate all the blocks to register with concerned mods per block

	each line of the file contain a definition for one full block
	the first time this mod is used, file blocks2process.dat contain the following table 
	(as example and minimal content) :

local blocks2process = {
	{node = "default:grass",						-- the full block to register with some mods
		mods = {"stairs","stairsplus"},				-- the mods to call to register the full block
		requested = {								
			playername = "singleplayer",			-- whitch player had request that action
			request_date = os.time(),				-- at what date-time
		},
		validated = {								
			playername = "server",					-- which player validated the request
			validate_on= os.time(),					-- at what date-time
		},},
	{node = "default:mese",							-- next full block to process
		mods = {"stairs", "stairsplus", "columnia"},
		requested = {
			playername = "singleplayer",
			request_date= os.time(),			
		},
		validated = {
			playername = "server",
			validate_on = os.time(),
		},},	
}

local file_name = minetest.get_modpath("subnodes_registerer").."/blocks2process.dat"
local file_block2process = io.open(file_name, "w")

if file_block2process then
	for i,v in ipairs(blocks2process) do
		file_block2process:write(minetest.serialize(v).."\n")
	end
	file_block2process:close()
end
blocks2process = {}
]]

local file_name = files_prefix.."subnodes_registerer_blocks2process.dat"
local file_block2process
local block2process
local mod_params
local a_param
local num_p
local fields_available = {}
local sep, i, str, node_name
local func_string = ""
local func2call = ""
local func_exec

-- block_registered will be global
block_registered = {}

file_block2process, error_msg = io.open(file_name, "r")

if file_block2process==nil then 
	minetest.log("Subnodes_registerer error? : it seems there is no block to register to some mod;\n"..
		"the error message from io.open is:\n"..error_msg)
else
	for line in io.lines(file_name) do
		block2process = minetest.deserialize(line)
		for _, mod in ipairs(block2process.mods) do
			if not minetest.get_modpath(mod) then 
				mydebug("log", "the mod "..mod.." is not installed for registering "..block2process.node..".")
				break 
			end
			mod_params = subnodes_registerer.mods2call[mod]
			if mod_params==nil then
				mydebug("log", "subnode_registerer error : the mod "..mod.." had not registered a function to call.")
				break
			end
			mydebug("log", "Process block "..block2process.node.." with mod "..mod.." and parameters :\n"..
				dump(mod_params))
			-- retrieve all the fields from minetest.registered_nodes :
			block_registered = {}
			node_name = block2process.node
			for k,v in pairs(minetest.registered_nodes[node_name]) do
				block_registered[k] = v
			end
			if block_registered==nil then
				minetest.log("subnode_registerer error: the block "..block2process.node..
					"designated in the file blocks2process.dat is not registered in minetest !")
				break
			end
			-- add to block_registered{} the fields we want to be available :
			sep = block2process.node:find(":")
			block_registered.short_name = block_registered.name:sub(sep+1)
			block_registered.full_name = block_registered.name

			mydebug("log", "block "..block2process.node.." to process is load from registered_nodes[] as :\n"..
				dump(block_registered))

			-- for the node block_registered, call each function :
			for _, params in ipairs(mod_params) do
				func_string = params.func_name.."("
				num_p = 1
				while params.parameters[num_p] do
					if num_p>1 then func_string = func_string..", " end
					a_param = params.parameters[num_p]
					i = 1
					str = ""
					while a_param.value_type[i] do
						if i>1 then str=str..".." end
						if a_param.value_type[i]=="field" then
							mydebug("log", "field to add to params2provide{} is "..
							a_param.value[i].." (type "..type(block_registered[a_param.value[i]])..
							")")
							if type(block_registered[a_param.value[i]]) == "table" then
								str = str.."block_registered."..a_param.value[i]
							else
								str = str..'"'..
								string.gsub(block_registered[a_param.value[i]],'"','\"')..'"'
							end
						else
							str = str.. '"' .. string.gsub(a_param.value[i],'"', '\"' ) .. '"'
						end						
						i = i+1
					end
					func_string = func_string..str
					num_p = num_p+1
				end
				func_string = func_string..")"
				
				-- call the function for registering in the mod designated :
				-- function call (parameters) will be include in a string, as it should be 
				-- written directly inside lua code file by a human codder, but surrounded by brackets
				-- like: func_string = [[register_function(parameter1, parameter2, ...)]]
				-- then local func_call = loadstring(func_string)
				-- and finally: func_call()
				-- func_call() will work exactly in the same way as if you had written
				-- register_function(parameter1, parameter2, ...) in the code
				
				-- to enable override, todo : take a copy of minetest.registered_nodes and after
				-- calling func_call(), take a new copy and compare to extract the new fresh nodes and then
				-- do the override operations.
				
				mydebug("log", "subnodes_registerer : function to call is written as :\n"..
					func_string)
				func_exec = loadstring(func_string)
				func_exec()
			end
		end
	end
	file_block2process:close()
end

-- check privileges for the player name :
local function check_privs(name)
	local privs = minetest.get_player_privs(name)
	subnodes_registerer.privs = {}
	subnodes_registerer.privs.subnodes_registerer_user = privs.subnodes_registerer_user
	subnodes_registerer.privs.subnodes_registerer_controler = privs.subnodes_registerer_controler
	subnodes_registerer.privs.subnodes_registerer_admin = privs.subnodes_registerer_admin or privs.server
	mydebug("tchat", "local privs = "..dump(subnodes_registerer.privs), name)
	mydebug("tchat", "mntst privs = "..dump(privs), name)
end

--[[ define formspecs for the differents privileges :
	defining formspec into something like an object-structure is a seed for an independant mod
	that should enable modder to visualy define formspecs in-game...

	user formspec (left click):
	user only can left click a block and confirm his request 
	to make the block registered for suitables mods
	usual string will be :
		"size[6,4]"..
		"label[1,1;"..msg.."]" ..
        "button_exit[1,3;2,1;proceed;OK]"..
		"button_exit[3,3;2,1;cancel;Cancel]"
]]

local formspecs = {}

formspecs.user = { -- formspec for privilege "user" :
	name = "user",
	size = {w=6, h=4},
	elements = {
		{name = "text_to_show",
			type = "label",
			x = 1,
			y = 1,
			label = "text"},
--[[ test:	{name = "TextList1",
			type = "textlist",
			x = 3.5,
			y = 0.2,
			w = 3,
			h = 2,
			name = "the_textlist",
			listelem = {"elem1","elem2","elem3","elem4","elem5"},
			label = "list-label:"},
]]
		{name = "proceed",
			type = "button_exit",
			x = 1,
			y = 3,
			w = 2,
			h = 1,
			label = "OK"},
		{name = "cancel",
			type = "button_exit",
			x = 3,
			y = 3,
			w = 2,
			h = 1,
			label = "Cancel"}
	}
}
formspecs.controler = {
	name = "controler",
	size = {w=12, h=8},
	elements = {
		{name = "text_to_show",
			type = "label",
			x = 1,
			y = 1,
			label = "text"},
		{name = "proceed",
			type = "button_exit",
			x = 1,
			y = 3,
			w = 2,
			h = 1,
			label = "OK"},
		{name = "cancel",
			type = "button_exit",
			x = 3,
			y = 3,
			w = 2,
			h = 1,
			label = "Cancel"}
	}
}


-- functions about administrating formspecs :
local forms = {}
forms.content = {}
forms.add_formspec = function(formspec, update)
	if formspec==nil then return false, "form spec was nil" end
	
	if update==nil then update=false end
	local name = formspec.name
	if name==nil then return false, "form spec's name was nil" end
	
	-- check if name already set
	if forms.content[formspec.name] then
		-- already set, what about "update" parameter ?
		if update==false then return false, "the form was already set" end
		-- update the form : same elements will be replaced
		forms.content[formspec.name] = formspec
		return true		
	else
		forms.content[formspec.name] = formspec
		return true
	end
end
forms.update_element = function(def_update)
-- update some field(s) of an element of a formspec;
-- def_update = { where_form_name = "name_of_the_form_to_update",
--			where_element_name = "name of the element to update",
--			update_fields = {field1 = value, field2 = value, ... } }
	mydebug("log", "forms.update_element called with parameter def_update=\n"..dump(def_update))
	
	if def_update==nil then return false, "form to update not defined (got nil)" end
	if def_update.where_form_name == nil then return false, "form name to update not defined (got nil)" end
	if def_update.where_element_name == nil then return false, "element name to update not defined (got nil)" end
	if def_update.update_fields == nil then return false, "parameter update_fields not defined (got nil)" end
	
	local frm2find = def_update.where_form_name
	local elm2find = def_update.where_element_name
	local updtflds = def_update.update_fields
	local updated = -1 -- number of updated fields; -1 at start means elm2find not found
		
	if forms.content[frm2find]==nil then 
		return false, "form "..frm2find.." not found" 
	end

	-- retrieve the element to update
	for k,v in pairs(forms.content[frm2find].elements) do
		if v.name==elm2find then
			-- we found the forms.elements to update some fields
			updated = 0
			for k2, v2 in pairs(updtflds) do
				-- for each field contained in updtflds, update the same field of forms[frm2find].elements{}
				v[k2] = v2
				updated = updated + 1
			end
			return true, tostring(updated).." field(s) updated"
		end
	end
	-- code execution come here if :
	-- form is found but element to update is not found : add the element :
	updated = 0
	for k,v in pairs(updtflds) do
		forms.content[frm2find].elements[k] = v
		updated = updated + 1
	end
	return true, tostring(updated).." fields added to form "..frm2find

end
--[[ types of fields :

	size		[w,h]
	list		[inventory_location;list_name;X,Y;W,H[;OPTIONAL:starting_item_index] ]
	image		[X,Y;W,H;texture_name]
	field		[X,Y;W,H;name;label;default]
	pwdfield	[X,Y;W,H;name;label]
	textarea	[X,Y;W,H;name;label]
	label		[X,Y;label]
	vertlabel	[X,Y;label]
	button		[X,Y;W,H;name;label]
	image_button		[X,Y;W,H;image;name;label]
	item_image_button	[X,Y;W,H;item name;name;label]
	button_exit			[X,Y;W,H;name;label]
	image_button_exit	[X,Y;W,H;image;name;label]
	listcolors	[slot_bg_normal;slot_bg_hover [;OPTIONAL:slot_border [;tooltip_bgcolor;tooltip_fontcolor] ] ]
	bgcolor		[color;fullscreen;]
	background	[X,Y;W,H;texture_name [;auto_clip] ]
	textlist	[X,Y;W,H;name;listelem 1,listelem 2,...,listelem n [;selected idx;transparent] ]
	dropdown	[X,Y;W,H;name;item1,item2,item3...;selected_id]
	checkbox	[X,Y;name;label;selected]
	--- other elements (see at http://dev.minetest.net/Lua_Table_Formspec search "Formspec"
	or file lua_api.txt) :
	"tabheader", x=<X>, y=<Y>, name="<name>", captions=<array of strings>, 
				current_tab=<current_tab>, transparent=<transparent>, drawborder=<drawborder>
	"box", x=<X>, y=<Y>, w=<Width>, h=<Height>, color="<color>"
	
	Inventory location:
		context: Selected node metadata (deprecated: "current_name")
		current_player: Player to whom the menu is shown
		player:<name>: Any player
		nodemeta:<X>,<Y>,<Z>: Any node metadata
		detached:<name>: A detached inventory
	
]]
forms.fields2export = {
	{type = "size",
	fields= {[1]="w",[2]=",h"} },
	{type = "list",
	fields= {[1]="inventory_location", [2]=";list_name", [3]=";x", [4]=",y", [5]=";w", [6]=",h"},
	fields_optional = {[1]= {[1]= ";starting_item_index"}} },
	{type = "image",
	fields= {[1]="x", [2]=",y", [3]=";w", [4]=",h", [5]=";texture_name"} },
	{type = "field",
	fields= {[1]="x", [2]=",y", [3]=";w", [4]=",h", [5]=";name", [6]=";label", [7]=";default"} },
	{type = "pwdfield",
	fields= {[1]="x", [2]=",y", [3]=";w", [4]=",h", [5]=";name", [6]=";label"} },
	{type = "textarea",
	fields= {[1]="x", [2]=",y", [3]=";w", [4]=",h", [5]=";name", [6]=";label"} },	
	{type = "label",
	fields= {[1]="x", [2]=",y", [3]=";label"}},
	{type = "vertlabel",
	fields= {[1]="x", [2]=",y", [3]=";label"}},
	{type = "button",
	fields= {[1]="x", [2]=",y", [3]=";w", [4]=",h", [5]=";name", [6]=";label"}},
	{type = "image_button",
	fields= {[1]="x", [2]=",y", [3]=";w", [4]=",h", [5]=";image", [6]=";name", [7]=";label"}},
	{type = {"item_image_button"},
	fields= {[1]="x", [2]=",y", [3]=";w", [4]=",h", [5]=";item_name", [6]=";name", [7]=";label"}},
	{type = "button_exit",
	fields= {[1]="x", [2]=",y", [3]=";w", [4]=",h", [5]=";name", [6]=";label"}},
	{type = "image_button_exit",
	fields= {[1]="x", [2]=",y", [3]=";w", [4]=",h", [5]=";image", [6]=";name", [7]=";label"}},
	{type = "list_colors",
	fields= {[1]="slot_bg_normal", [2]=";slot_bg_hover"},
	fields_optional = {
		[1]={[1]=";slot_border"},
		[2]={[1]=";tooltip_bgcolor", [2]=";tooltip_fontcolor"}}},
	{type = "bgcolor",
	fields= {[1]="color", [2]=";fullscreen"}},
	{type = "background",
	fields= {[1]="x", [2]=",y", [3]=";w", [4]=",h", [5]=";texture_name"},
	fields_optional = {[1]= {[1]=";auto_clip"}} },
	{type = "textlist",
	fields= {[1]="x", [2]=",y", [3]=";w", [4]=",h", [5]=";name", [6]=";listelem{}"},
	fields_optional= {[1]= {[1]=";selected idx", [2]=";transparent"}} },
	{type = "dropdown",
	fields= {[1]="x", [2]=",y", [3]=";w", [4]=",h", [5]=";name", [6]=";item{}", [7]=";selected_id"}},
	{type = "checkbox",
	fields= {[1]="x", [2]=",y", [3]=";name", [4]=";label", [5]=";selected"}}
}

-- return a formated string containing the formspec "name" usable by mt.show_formspec() :
forms.make_formspec = function(name)
	mydebug("log", "forms.make_formspec called to make a string from form '"..name.."'")
	
	-- return a formspec-formated string for an element of a form (e.g. button, or textlist, or label, etc)
	local function process_fields(element, fields_def)
		local formated_string = nil
		local field_num -- , set_num
		local field_proto -- def for a field containing eventualy a first char as separator and 2 last chars as {} specifiing a table
		local char1, mrk = "", ""
		local list_elem = ""
		
		formated_string = ""
		field_num = 1
		while fields_def[field_num] do			
			field_proto = fields_def[field_num]
			--  field_proto can contain :
			--	 - séparator like , or ;
			-- 	 - field name
			--	 - marker like {} to say it is a list and elems will be separate by ","
			mydebug("log", "-field #"..field_num.." contain :\n"..dump(field_proto))
			char1 = field_proto:sub(1,1)
			if field_proto:len()>2 then
				mrk = field_proto:sub(-2) -- the 2 last characters
			else
				mrk = ""
			end
			if char1=="," or char1==";" then
				formated_string = formated_string..char1
				field_proto = field_proto:sub(2) -- substract first char
			else
				char1="" -- was a part of field name so erase it
			end
			mydebug("log", "field_proto="..field_proto.."; first char, if separator, is '"..char1.."';\n")				
			if mrk=="{}" then				
				field_proto = field_proto:sub(1,-3) -- substract 2 last chars
				mydebug("log","the 2 last chars are significant: '{}' so field_proto finaly ="..field_proto)
				-- browse element as a table (an array) with n elements
				-- example : element={"textelem1","textelem2",...,"textelem n"}
				-- so element is expected to contain element[field_proto]={array of elements searched}
				list_elem = ""
				if element[field_proto] then					
					for _, elem in ipairs(element[field_proto]) do
						if list_elem ~= "" then list_elem=list_elem.."," end
						list_elem = list_elem..minetest.formspec_escape(elem)
					end	
				else
					-- here should be an error to manage : we need a list of elements expected in
					-- element[field_proto] but it is nil, so the list of elements is empty.
				end
				mydebug("log","we find element."..field_proto.."="..list_elem)
				formated_string = formated_string..list_elem
			else
				-- element contain the field 'field_proto' we are looking for :
				-- example : element={x=1, y=2, w=4, ... label="MyLabel"}
				minetest.log("looking for element[\""..field_proto.."\"]=")
				if element[field_proto] then
				mydebug("log",element[field_proto])
				formated_string = formated_string..element[field_proto]
				else
					-- this happen when the element do not contain the field field_proto :
					mydebug("log","Error ! element[\""..field_proto.."\"]=nil")
				end
			end
			mydebug("log","String for element "..element.name.." is now :\n"..formated_string)
			field_num = field_num + 1
		end
		
		return formated_string
	end
	
	
	local form = forms.content[name]
	if (form==nil) then return false, "no form named '"..name.."'" end
	
	mydebug("log","make_formspec is called to make a string representing the form '"..form.name.."'")
	-- form contain the formspec definition researched; make a string :
	local form_str = "size["..form.size.w..","..form.size.h.."]"
	local type2xport, fields2process
	--local char1, mrk  -- for character#1 and marker-at-the-end in the string "field_proto"
	local nb_fields -- for debug 
	--local field_num  -- for iterating table of fields in order
	local set_num	-- for iterating table of set of optionals fields
	local field_proto 
	--local list_elem = "" -- when we have to construct a string made of list of elements
	
	for i,element in ipairs(form.elements) do
		form_str = form_str..element.type.."["
		type2xport = element.type -- the type of the element to export in a string
		-- search for what fields to export for this type:
		fields2process = nil
		for i2, v2 in ipairs(forms.fields2export) do
			if v2.type == type2xport then
				fields2process = v2
				break
			end
		end			
		if fields2process then
		-- fields2process contain now the definition of the fields of v that have to be export
		-- for example :
		--  fields2process = {type = "textlist",
		-- 		fields= {1="x", 2=",y", 3=";w", 4=",h", 5=";name", 6=";listelem{}"},
		--		fields_optional= {1= {1=";selected idx", 2=";transparent"}} }
			mydebug("log","make string for element:\n"..tostring(dump(element)).."\nof type "..
			type2xport.." needed fields: "..dump(fields2process.fields))
			
			-- only for debug :
			nb_fields=0
			for j,k in pairs(fields2process.fields) do nb_fields=nb_fields+1 end
			mydebug("log","there is "..tostring(nb_fields).." fields to process.")
			-- end of "only for debug" --
			
			form_str = form_str..process_fields(element, fields2process.fields)
					
			-- parse now the fields_optional :
			-- may contain :
			-- 1°) nil : no optional field;
			-- 2°) numeric index = table : numeric index = field name
			-- 		e.g. fields_optional= {1 = {1 = ";selected idx", 2 = ";transparent"},
			-- 							   2 = {1 = ";tooltip_bgcolor", 2 = ";tooltip_fontcolor"}}
			-- that minds : each line is an optional set of fields where all fields in a set must be present
			-- at this step of dev, we only consider if an option is not defined (field not present) then
			-- the string will be <separator><nothing>. e.g. "element[1,1;4,2;mylabel;;;]" where 
			-- successives semicolon show optionals options are replaced by nil value
			-- later todo should be to parse optional fields to determine what to do if an option is not present.
			if fields2process.fields_optional then
				set_num = 1
				while fields2process.fields_optional[set_num] do
					form_str = form_str..process_fields(element, fields2process.fields_optional[set_num])
					set_num = set_num + 1
				end
			end
		end
		form_str = form_str.."]"
	end
	-- form_str = minetest.formspec_escape(form_str)
	mydebug("log","the formspec "..name.." had been formated in the string :\n"..form_str)
	return form_str
end


forms.add_formspec(formspecs.user)
forms.add_formspec({name="show_msg",
	size = {w=6, h=4},
	elements = {
		{name="text_to_show",
		type = "label",
		x = 0.5,
		y = 0.5,
		label = "the text to be shown"},
		{name = "btn_exit",
		type = "button_exit",
		x = 1,
		y = 3,
		w = 2,
		h = 1,
		label = "OK"}
	}
	})
forms.add_formspec({name="summarize",
	size = {w=6, h=4},
	elements = {
		{name = "text_to_show",
		type = "label",
		x = 1,
		y = 1,
		label = "the text to be shown"},
		{name = "proceed",
        type = "button_exit",
		x = 1, y = 3,
		w = 2, h = 1,
		label = "OK"},
		{name = "cancel",
		type = "button_exit",
		x = 3, y = 3,
		w = 2, h = 1,
		label = "Cancel"}
	}}
)	

--[[ function to check at run time if a block is already derivated by some mod registered to do that.
	e.g. : mod 'moreblocks' is registered as a mod we can call to derivate a block into slopes (and many other shapes);
	block 'default:leaves' was hit by player : does a typical block like 
	'moreblocks:slope_leaves' or
	'default:slope_leaves' already registered ?
	
	We must know an example of derivated block to check that, so we have a field :
	"typical_derivated" in
	subnodes_registerer.mods2call["moreblocks"]typical_derivated :
		typical_derivated = { 
		field_to_check = "name",
		content = {
			{value_type = {"string", "field"}, value = {"moreblock:slope_", "short_name"}},
			{value_type = {"field","string","field"}, value = {"mod_name", ":slope_", "short_name"}},
		}}
	that means : check if exist a block whitch have field "name" equal to
		"moreblocks:slope_" .. "leaves"
		OR "default" .. ":slope_" .. "leaves"
		then derivated blocks from 'default:leaves' are already registered
]]
already_derivated = {
	mods = {},
	block_name = "", -- some useless, but may simplify info 
	-- that say mods{} is filled regarding to block_name :)
	check = function(a_block)
		already_derivated.mods = {function()
			local tmp = {}
			for k, v in pairs(subnodes_registerer.mods2call) do
				table.insert(tmp, {k = false})
			end
			return tmp
		end}
		already_derivated.block_name = ""
		if a_block==nil then a_block = block end
		if a_block==nil then return false end
		already_derivated.block_name = a_block.name
		
		local look_at ="" -- content to search
		local found = false -- content is found
		for k, v in pairs(subnodes_registerer.mods2call) do -- for each mod to call :
			if not v.typical_derivated then
				-- no typical_derivated info, unable to check block for this mod,
				-- doing nothing will prepare to call this mod to enable it to do it's work with the block
				break
			end
			-- construct the content to look for :
			for ci, cv in ipairs(v.typical_derivated.content) do
				look_at = ""
				for vi, vv in ipairs(cv.value_type) do
					if vv=="string" then look_at = look_at..vv end
					if vv=="field" then look_at = look_at..tostring(a_block[cv.value[vi]]) end
				end
				if v.typical_derivated.field_to_check == "name" then
					if minetest.registered_nodes[look_at] then
						already_derivated.mods[k] = true
						found = true
					end
				else
					for k2, v2 in pairs(minetest.registered_nodes) do
						if v2[v.typical_derivated.field_to_check] == look_at then
							already_derivated.mods[k] = true
							found = true
							break
						end
					end
				end
				if found then break end
			end
		end
		return found
		-- if block was already derivated, mods{} contain now the list of mods that have
		-- created some blocks from it and block_name contain the full name of checked block.
	end,
} -- end of already_derivated structure

-- function to show messages in a formspec when nothing to do, with a specific reason and only
-- one button "OK" to close the formspec :
local function show_msg(player_name, msg)
	msg = minetest.formspec_escape(msg)
	local str = "Nothing to do because \n"..msg
	local updated, reason
	
	updated, reason = forms.update_element(
			{where_form_name = "show_msg",
			where_element_name = "text_to_show",
			update_fields = {label = str} } )

	--mydebug("log","function show_msg return "..tostring(updated).." : "..reason.."\n"..
	--	"dump(forms)="..dump(forms))
	str = forms.make_formspec("show_msg")
	minetest.show_formspec(player_name,"subnodes_registerer:nothing_todo",str)
end

-- define the functions for left-click with the intended tool :
local function registerer_tool_has_lclicked(player, pointed_thing)
	-- check if player have priv "subnodes_registerer_user" to use the tool :
	local pname = player:get_player_name()
	check_privs(pname)
	if not minetest.get_player_privs(pname).subnodes_registerer_user then
		show_msg(pname, pname.." haven't the necessary privilege to use this tool.")
		return
	end
	-- check if clicked block follow the rules so that it is processable for circular saw, stairs and/or columnia :
	local pt = pointed_thing
	local msg = "nothing to say"
	
	-- RULE #1 : is it a node ?
	if pt.type ~= "node" then
		show_msg(pname, "you haven't click on a node")
		return
	end
	
	-- RULE #2 : is it a registered node ? (it may be other thing than a block, like mesh, entity or so)
	local node = minetest.get_node(pt.under)	
	block = minetest.registered_nodes[node.name]	-- global block
	if not block then 
		show_msg(player:get_player_name(), "this is not a block")
		return
	end
	
	-- RULE #3 : is drawtype in allowed drawtypes ?
	local block_dtype = block["drawtype"]
	local dtype_ok = false
	local allowed_drawtypes = "normal liquid glasslike glasslike_framed glasslike_framed_optional allfaces_optional"
	if (block_dtype==nil) or (string.find(allowed_drawtypes, block_dtype)) then 
		dtype_ok = true
	end
	if not dtype_ok then 
		show_msg(player:get_player_name(), "this block's drawtype ("..block_dtype..") is not suitable :/")
		return 
	end
	
	-- block is processable, let's go on next checks to see what mod should be call for processing :
	
	local sep = block.name:find(":")
	block.mod_name = block.name:sub(1,sep-1) -- the mod that have registered the block (example : "default")
	block.short_name = block.name:sub(sep+1) -- the name of the block not prefixed with it's mod name (example : "wood")

	if not block.groups then block["groups"]={oddly_breakable_by_hand=1} end
	if not block.sounds then block["sounds"]=default.node_sound_glass_defaults() end

	already_derivated.check() -- check if the block was already processed and by which mod
	
	local mods2register={}	
	for k, v in pairs(already_derivated.mods) do
		if not already_derivated.mods[k] then
			table.insert(mods2register, k)
		end
	end
	
	-- prepare a form to summarize the checks :
	msg = "You left-clicked block "..block.name..";\n"
	if #mods2register==0 then	
		-- no mod to register with
		msg = msg.."but the targets mods aren't installed or\nthe block is already defined in"
		show_msg(player:get_player_name(), msg)
		return
	end
		
	msg = msg.."it will be registered for mod"
	if #mods2register>1 then msg=msg.."s" end
	for i,v in ipairs(mods2register) do
		msg = msg.." "..v
	end	
	
	-- prepare to register pending work (can be finaly confirmed or canceled in mt.on_receive_fields) :
	subnodes_registerer.pending = {
		mods = mods2register,
		block_name = block.name,
		player_name = pname,
		requested = os.time(),
	}


	msg = msg.."\nat next server restart."
	msg = minetest.formspec_escape(msg)
	
	local updated, reason
	local tmp_fname = "summarize" -- "user" or "summarize"
	updated, reason = forms.update_element(
			{where_form_name = tmp_fname,
			where_element_name = "text_to_show",
			update_fields = {label = msg} } )

	msg = forms.make_formspec(tmp_fname)
	minetest.show_formspec(player:get_player_name(),"subnodes_registerer:confirm",msg)
	
--	3°) add <mod_name> as optional in depends.txt if not yet;
--	4°) add <block_name> in blocks_list.txt if not yet;

end

-- register pending work when 'user' confirm his choice in order to enable 'controler' or
-- 'admin' to validate it
local function register_pending_work(player_name)	
	
	local file = io.open(files_prefix.."subnodes_registerer_pending.dat", "a+")
	file:write(minetest.serialize(subnodes_registerer.pending))
	file:close()
end

-- callback for leftclick after exit formspec:
minetest.register_on_player_receive_fields(function(player, formname, fields)
    -- Return true to stop other minetest.register_on_player_receive_fields
    -- from receiving this submission.
    if formname== "subnodes_registerer:nothing_todo" then
		mydebug("tchat", "Subnodes Registerer Tool : nothing was prepended to be done", player:get_player_name())
		fields = nil
        return true
    elseif formname== "subnodes_registerer:confirm" then
		-- Send message to player.
		local msg=""
		if fields.proceed then
			msg = "You confirmed the prepended work which will now be registered for next restart..."
			register_pending_work(player:get_player_name())
		end
		if fields.cancel then
			msg = "You canceled the prepended work. Nothing will be done"
		end
		mydebug("tchat", msg, player:get_player_name())
		fields = nil
		return true    
	else
		return false
	end
end)

minetest.register_craftitem("subnodes_registerer:registerer_tool",{
	description = "register punched block as processable by circular saw, stairs & columnia.",
	groups = {},
	inventory_image = "registerer_tool.png",
	wield_image = "registerer_tool.png",
	wield_scale = 1,

	stack_max = 1,
	liquids_pointable = true,
	-- function to handle right click :
	on_place = function(itemstack, placer, pointed_thing)
		mydebug("tchat", "registerer tool right clicked", placer:get_player_name())
		return itemstack
	end,
	
	-- function to handle left click :
	on_use = function(itemstack, user, pointed_thing)
		mydebug("tchat", "registerer tool left clicked", user:get_player_name())
		registerer_tool_has_lclicked(user, pointed_thing)
		return itemstack
	end,
	
})

-- craft recipe for registerer tool :
minetest.register_craft({	
	output = "subnodes_registerer:registerer_tool",
	recipe = { {"stairs:stair_cobble"},
			   {"default:stick"},
			 }
})
