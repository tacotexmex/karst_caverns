

local function remap(val, min_val, max_val, min_map, max_map)
	return (val-min_val)/(max_val-min_val) * (max_map-min_map) + min_map
end

local function lerp(var_a, var_b, ratio)
	return (1-ratio)*var_a + (ratio*var_b)
end

-- karst height controls, if a heightmap is provided by mapgen then that is used for max height


local min_height = -2000
local fallback_max_height = 50

-- 2d, low only
local np_caverns_connector_x = {
	offset = -.75,
	scale = 2,
	spread = {x=30, y=5, z=4},
	octaves = 3,
	seed = 20000,
	persist = 0.4,
	lacunarity = 2,
}


-- 2d, low only
local np_caverns_connector_z = {
	offset = -.75, -- lowering makes
	scale = 2,
	spread = {x=5, y=30, z=30},
	octaves = 3,
	seed = 20000,
	persist = 0.4,
	lacunarity = 2,
}

-- 2d, low only
local np_caverns_rooms = {
	offset = 1.25,
	scale = 2,
	spread = {x=20, y=20, z=20},
	octaves = 2,
	persist = .2,
	lacunarity = 4,
}

-- 2d, low only, a large scale noise that prevents cavern formation in large areas
local np_caverns_region = {
	offset = -.3,
	scale = 1,
	spread = {x=100, y=100, z=100},
	octaves = 6,
	persist = 0.4,
	lacunarity = 1,
}



local np_caverns_modulator = {
	offset = 0,
	scale = 1.3,
	spread = {x=120, y=25, z=120},
	octaves = 4,
	persist = .5,
	lacunarity = 2.5,
}


local np_caverns_rooms_modulator = {
	offset = 0,
	scale = 1.5,
	spread = {x=60, y=13, z=60},
	octaves = 3,
	persist = .5,
	lacunarity = 2.5,
}




local c_air = minetest.get_content_id("air")

local c_stone = minetest.get_content_id("mapgen_stone")



local nobj_caverns_modulator = nil
local nvals_caverns_modulator = {}

local nobj_caverns_rooms_modulator = nil
local nvals_caverns_rooms_modulator = {}

local data = {}


minetest.register_on_generated(function(minp, maxp, seed)

	local t0 = os.clock()

    local heightmap = minetest.get_mapgen_object("heightmap")


	local sidelen = maxp.x - minp.x + 1

	local permapdims3d = {x = sidelen, y = sidelen, z = sidelen}



	nobj_caverns_modulator = nobj_caverns_modulator or
		minetest.get_perlin_map(np_caverns_modulator, permapdims3d)
	nobj_caverns_modulator:get3dMap_flat(minp, nvals_caverns_modulator)

	nobj_caverns_rooms_modulator = nobj_caverns_rooms_modulator or
		minetest.get_perlin_map(np_caverns_rooms_modulator, permapdims3d)
	nobj_caverns_rooms_modulator:get3dMap_flat(minp, nvals_caverns_rooms_modulator)


	local nvals_caverns_connector_x = minetest.get_perlin_map(np_caverns_connector_x, permapdims3d):get2dMap_flat({x=minp.x, y=minp.z})
	local nvals_caverns_connector_z = minetest.get_perlin_map(np_caverns_connector_z, permapdims3d):get2dMap_flat({x=minp.x, y=minp.z})
	local nvals_caverns_caverns_rooms = minetest.get_perlin_map(np_caverns_rooms, permapdims3d):get2dMap_flat({x=minp.x, y=minp.z})
	local nvals_caverns_region = minetest.get_perlin_map(np_caverns_region, permapdims3d):get2dMap_flat({x=minp.x, y=minp.z})


	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")

	local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}

	vm:get_data(data)

	local ni = 1

	for z = minp.z, maxp.z do
	for y = minp.y, maxp.y do

		local vi = area:index(minp.x, y, z)
		for x = minp.x, maxp.x do
            local pos = vector.new(x,y,z)
            local hm_i = (pos.x - minp.x + 1) + (((pos.z - minp.z)) * 80)
			local height
			if heightmap then 
            	height = heightmap[hm_i]
			else
				height = fallback_max_height
			end
			


			local caverns_caverns_rooms = nvals_caverns_caverns_rooms[hm_i]
			local caverns_region = nvals_caverns_region[hm_i]
			local surface_break_adder = 1.5



			if y > min_height and y < height - (surface_break_adder) + caverns_caverns_rooms and y > height - (75 + caverns_region) and caverns_region > .2 then	
				

				local caverns_connector_x = nvals_caverns_connector_x[hm_i]
				local caverns_connector_z =	nvals_caverns_connector_z[hm_i]


				local density_caverns_modulator = nvals_caverns_modulator[ni]*.5 --+ .75
				local density_caverns_rooms_modulator = nvals_caverns_rooms_modulator[ni]*.5
	
				density_caverns_modulator = remap(density_caverns_modulator,-2,2,-20,20)
				if (density_caverns_modulator < 2.8 and density_caverns_modulator > 1
					and ( 
							lerp(lerp(caverns_connector_x - .9,lerp(density_caverns_rooms_modulator,density_caverns_rooms_modulator,.8) ,.4),density_caverns_rooms_modulator,.3) > 0
						or lerp(lerp(caverns_connector_z - .9,lerp(density_caverns_rooms_modulator,density_caverns_rooms_modulator,.8) ,.4),density_caverns_rooms_modulator,.3) > 0
					))
				or (density_caverns_modulator > 2.5
					and lerp(density_caverns_rooms_modulator - .3,1-caverns_caverns_rooms -.4,.4) > 0
				)

				then 
					data[vi] = c_air
				end
					
			end
				-- if math.random(1,100) == 1 then
				-- 	minetest.chat_send_all(caverns_region)
				-- end

			-- Increment noise index.
			ni = ni + 1
			vi = vi + 1
		end
	end
	end

	vm:set_data(data)
	vm:calc_lighting()
	vm:write_to_map()
	vm:update_liquids()
end)