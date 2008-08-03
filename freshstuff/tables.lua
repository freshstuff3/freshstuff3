--[[
	TABLE.SAVE 0.4
 
	table.save( table, file ) 0.4
		Save Table to File
		Functions, Userdata and indices of these will not be saved
		Strings will be converted to enclosed long brakets, makes it easier to save regardingly special chars,
		now hopefull for sure thx to 'bastya_elvtars'
		References are preserved
 
	table.load( file )
		returns a previously saved table
 


by chill
Distributed under the terms of the Common Development and Distribution License (CDDL) Version 1.0
]]--

function table.save( t, sfile )
	local tables = {}
	table.insert( tables, t )
	local lookup = { [t] = 1 }
	local file = io.open( sfile, "w" )
	file:write( "return {" )
	for i,v in ipairs( tables ) do
		table.pickle( v, file, tables, lookup )
	end
	file:write( "}" )
	file:close()
end
 
function table.pickle( t, file, tables, lookup )
	file:write( "{" )
	for i,v in pairs( t) do
		-- escape functions
		if type( v ) ~= "function" and type( v ) ~= "userdata" then
			-- handle index
			if type( i ) == "table" then
				if not lookup[i] then
					table.insert( tables, i )
					lookup[i] = table.maxn( tables )
				end
				file:write( "[{"..lookup[i].."}] = " )
			else
				local index = ( type( i ) == "string" and "[ "..string.enclose( i, 50 ).." ]" ) or string.format( "[%d]", i )
				file:write( index.." = " )
			end
			-- handle value
			if type( v ) == "table" then
				if not lookup[v] then
					table.insert( tables, v )
					lookup[v] = table.maxn( tables )
				end
				file:write( "{"..lookup[v].."}," )
			else
				local value =  ( type( v ) == "string" and string.enclose( v, 50 ) ) or tostring( v )
				file:write( value.."," )
			end
		end
	end
	file:write( "},\n" )		
end
 
-- enclose string by long brakets ( string, maxlevel )
function string.enclose( s, maxlevel )
	s = "["..s.."]"
	local level = 0
	while 1 do
		if maxlevel and level == maxlevel then
			error( "error: maxlevel too low, "..maxlevel )
		-- 
		elseif string.find( s, "%["..string.rep( "=", level ).."%[" ) or string.find( s, "]"..string.rep( "=", level ).."]" ) then
			level = level + 1
		else
			return "["..string.rep( "=", level )..s..string.rep( "=", level ).."]"
		end
	end
end
 
function table.load( sfile )
  -- Return empty table if the file cannot be loaded // bastya_elvtars
  if not loadfile(sfile) then return {} end
	local tables = dofile( sfile )
	if tables then
		local tcopy = {}
		table.unpickle( tables[1], tables, tcopy )
		return tcopy
	end
end
 
function table.unpickle( t, tables, tcopy, pickled )
	pickled = pickled or {}
	pickled[t] = tcopy
	for i,v in pairs( t ) do
		local i2 = i
		if type( i ) == "table" then
			local pointer = tables[ i[1] ]
			if pickled[pointer] then
				i2 = pickled[pointer]
			else
				i2 = {}
				table.unpickle( pointer, tables, i2, pickled )
			end
		end
		local v2 = v
		if type( v ) == "table" then
			local pointer = tables[ v[1] ]
			if pickled[pointer] then
				v2 = pickled[pointer]
			else
				v2 = {}
				table.unpickle( pointer, tables, v2, pickled )
			end
		end
		tcopy[i2] = v2
	end
end