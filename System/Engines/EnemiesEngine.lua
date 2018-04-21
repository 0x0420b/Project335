-- Function to create and populate table of enemies within a distance from player.
br.enemy	= {}
br.lootable = {}
br.units 	= {}
local findEnemiesThread = nil

-- Update Pet
local function UpdatePet(thisUnit)
	if br.player.spell.buffs.demonicEmpowerment ~= nil then
		demoEmpBuff = UnitBuffID(thisUnit,br.player.spell.buffs.demonicEmpowerment) ~= nil
	else
		demoEmpBuff = false
	end
	local unitCount = #br.player.enemies(10,thisUnit) or 0
	local pet 		= br.player.pet.list[thisUnit]
	pet.deBuff = demoEmpBuff
	pet.numEnemies = unitCount
end

-- Add Units
local function AddUnits(thisUnit)
	local startTime = debugprofilestop()
	if br.units[thisUnit] == nil then
		br.units[thisUnit] 	= {}
		local units 		= br.units[thisUnit]
		units.unit 			= thisUnit
		units.name 			= UnitName(thisUnit)
		units.guid 			= UnitGUID(thisUnit)
		units.id 			= GetObjectID(thisUnit)
	end
	br.debug.cpu.enemiesEngine.units.addTime = debugprofilestop()-startTime or 0
end

-- Add lootable
local function AddLootable(thisUnit)
	if br.lootable[thisUnit] == nil then
		br.lootable[thisUnit] = {}
		local lootable = br.lootable[thisUnit]
		lootable.unit 	= thisUnit
		lootable.name 	= UnitName(thisUnit)
		lootable.guid 	= UnitGUID(thisUnit)
		lootable.id 	= GetObjectID(thisUnit)
		lootable.hasLoot = hasLoot
		lootable.canLoot = canLoot
	end
end

-- Adds Enemies to the enemy table
local function AddEnemy(thisUnit)
	local startTime = debugprofilestop()
	if br.enemy[thisUnit] == nil then
		br.enemy[thisUnit] 	= {}
		local enemy 		= br.enemy[thisUnit]
		enemy.unit 			= thisUnit
		enemy.name 			= UnitName(thisUnit)
		enemy.guid 			= UnitGUID(thisUnit)
		enemy.id 			= GetObjectID(thisUnit)
	end
	br.debug.cpu.enemiesEngine.enemy.addTime = debugprofilestop()-startTime or 0
end

-- Check Critter
local function IsCritter(checkID)
	local numPets = C_PetJournal.GetNumPets(false)
	for i=1,numPets do
		local _, _, _, _, _, _, _, name, _, _, petID = C_PetJournal.GetPetInfoByIndex(i, false)
		if checkID == petID then return true end
	end
	return false
end

-- Add Pet
local function AddPet(thisUnit)
	if br.player ~= nil then
		if br.player.pet == nil then br.player.pet = {} end
		if br.player.pet.list == nil then br.player.pet.list = {} end
		local unitCreator = UnitCreator(thisUnit)
		if (unitCreator == GetObjectWithGUID(UnitGUID("player")) or GetObjectID(thisUnit) == 11492) and br.player.pet.list[thisUnit] == nil then
			if not isCritter(GetObjectID(thisUnit)) then
				br.player.pet.list[thisUnit] = {}
				local pet 		= br.player.pet.list[thisUnit]
				pet.unit 		= thisUnit
				pet.name 		= UnitName(thisUnit)
				pet.guid 		= UnitGUID(thisUnit)
				pet.id 			= GetObjectID(thisUnit)
				if UnitAffectingCombat("pet") or UnitAffectingCombat("player") then UpdatePet(thisUnit) end
			end
		end
	end
end

function FindEnemy()
	local startTime = debugprofilestop()
	br.debug.cpu.enemiesEngine.enemy.targets = 0
-- Clean Up
	for k, v in pairs(br.enemy) do if not isValidUnit(br.enemy[k].unit) then br.enemy[k] = nil end end
	if br.units ~= nil then
		for k,v in pairs(br.units) do
			local thisUnit = br.units[k].unit
			-- Enemies
			if isValidUnit(thisUnit) then
				br.debug.cpu.enemiesEngine.enemy.targets = br.debug.cpu.enemiesEngine.enemy.targets + 1
				AddEnemy(thisUnit)
			end
		end
	end
	-- Debugging
	br.debug.cpu.enemiesEngine.enemy.currentTime = debugprofilestop()-startTime
	br.debug.cpu.enemiesEngine.enemy.totalIterations = br.debug.cpu.enemiesEngine.enemy.totalIterations + 1
	br.debug.cpu.enemiesEngine.enemy.elapsedTime = br.debug.cpu.enemiesEngine.enemy.elapsedTime + debugprofilestop()-startTime
	br.debug.cpu.enemiesEngine.enemy.averageTime = br.debug.cpu.enemiesEngine.enemy.elapsedTime / br.debug.cpu.enemiesEngine.enemy.totalIterations
	-- coroutine.yield()
end

function getOMUnits()
	local startTime = debugprofilestop()
	br.debug.cpu.enemiesEngine.units.targets = 0
	-- Clean Up
	-- Units
	for k, v in pairs(br.units) do if not enemyListCheck(br.units[k].unit) then br.units[k] = nil end end
	-- Pets
	if br.player ~= nil and br.player.pet ~= nil and br.player.pet.list ~= nil then
		for k,v in pairs(br.player.pet.list) do br.player.pet.list[k] = nil end
	end
	-- Lootables
	for k, v in pairs(br.lootable) do
		local hasLoot,canLoot = CanLootUnit(br.lootable[k].guid)
		if not hasLoot or not GetObjectExists(br.lootable[k].unit) then br.lootable[k] = nil end
	end
	-- Cycle the Object Manager
	local objectCount = FireHack~=nil and GetObjectCount() or 0
	if FireHack ~= nil and objectCount > 0 then
		for i = 1, objectCount do
			if i == 1 then cycleTime = debugprofilestop() end
			-- define our unit
			local thisUnit = GetObjectWithIndex(i)
			local enemyListCheck = enemyListCheck
			if (ObjectIsType(thisUnit, ObjectTypes.Unit) or GetObjectID(thisUnit) == 11492)
			then
				-- Units
				if enemyListCheck(thisUnit)	then
					br.debug.cpu.enemiesEngine.units.targets = br.debug.cpu.enemiesEngine.units.targets + 1
					AddUnits(thisUnit)
				end
				-- Pet Info
				if UnitIsUnit(thisUnit,"pet") or UnitCreator(thisUnit) == GetObjectWithGUID(UnitGUID("player")) or GetObjectID(thisUnit) == 11492 then
					AddPet(thisUnit)
				end
				-- Lootable
				-- local hasLoot,canLoot = CanLootUnit(UnitGUID(thisUnit))
				-- if hasLoot and canLoot then
				-- 	AddLootable(thisUnit)
				-- end
			end
			if i == objectCount then
				br.debug.cpu.enemiesEngine.units.cycleTime = debugprofilestop()-cycleTime
			end
		end
	end
	-- Debugging
	br.debug.cpu.enemiesEngine.units.currentTime = debugprofilestop()-startTime
	br.debug.cpu.enemiesEngine.units.totalIterations = br.debug.cpu.enemiesEngine.units.totalIterations + 1
	br.debug.cpu.enemiesEngine.units.elapsedTime = br.debug.cpu.enemiesEngine.units.elapsedTime + debugprofilestop()-startTime
	br.debug.cpu.enemiesEngine.units.averageTime = br.debug.cpu.enemiesEngine.units.elapsedTime / br.debug.cpu.enemiesEngine.units.totalIterations
	-- coroutine.yield()
end

-- /dump UnitGUID("target")
-- /dump getEnemies("target",10)
function getEnemies(thisUnit,radius,checkNoCombat)
    local startTime = debugprofilestop()
	local enemiesTable = {}
	local radius = tonumber(radius)

    local enemyTable = checkNoCombat and br.units or br.enemy
    local thisEnemy, thisGUID, distance
	for k, v in pairs(enemyTable) do
		thisEnemy = enemyTable[k].unit
		thisGUID = enemyTable[k].guid
		distance =  getDistance(thisUnit,thisEnemy)
		if not UnitIsDeadOrGhost(thisEnemy) and thisGUID == UnitGUID(thisEnemy) and distance < radius then
			tinsert(enemiesTable,thisEnemy)
		end
    end
    ---
    br.debug.cpu.enemiesEngine.getEnemies = debugprofilestop()-startTime or 0
    ---
    return enemiesTable
end

function getObjectEnemies(thisObject,radius)
	local thisObject = GetUnit(thisObject)
	local objectsTable = { }
	if thisObject ~= nil then
		for k, v in pairs(br.enemy) do
			local thisEnemy = br.enemy[k].unit
			local distance = GetDistanceBetweenObjects(thisEnemy,thisObject) or 0
			if distance < radius then
				tinsert(objectsTable,thisEnemy)
			end
		end
	end
	return objectsTable
end

local debugMax = 0
local debugMin = 999
local dynamicSum = 0
local dynamicCount = 0
local avgTime = 0
function findBestUnit(range,facing)
	local startTime = debugprofilestop()
	local bestUnitCoef = 0
	local dynRange = "dyn"..range
	if dynTargets == nil then dynTargets = {} end
	if getUpdateRate() > br.player.gcd then updateRate = getUpdateRate() else updateRate = br.player.gcd end
	if dynTargets[dynRange] ~= nil and (not isValidUnit(dynTargets[dynRange]) or br.timer:useTimer("dynamicUpdate"..range, updateRate)) then dynTargets[dynRange] = nil end
	if dynTargets[dynRange] ~= nil then return dynTargets[dynRange] end
	if dynTargets[dynRange] == nil then
		for k, v in pairs(br.enemy) do
			local thisUnit = v.unit
			local thisGUID = v.guid
			local distance = getDistance(thisUnit)
			if distance < range and thisGUID == UnitGUID(thisUnit) then
				local coeficient = getUnitCoeficient(thisUnit) or 0
				local isFacing = getFacing("player",thisUnit)
				if getOptionCheck("Don't break CCs") then isCC = isLongTimeCCed(thisUnit) else isCC = false end
				if coeficient >= 0 and coeficient >= bestUnitCoef and not isCC and (not facing or isFacing) then
					bestUnitCoef = coeficient
					bestUnit = thisUnit
					dynTargets[dynRange] = thisUnit
					-- Debug Print
					-- local currentTime = round2(debugprofilestop()-startTime,2)
					-- dynamicSum = dynamicSum + currentTime
					-- dynamicCount = dynamicCount + 1
					-- avgTime = round2(dynamicSum / dynamicCount,2)
					-- if currentTime > debugMax then debugMax = currentTime end
					-- if currentTime < debugMin then debugMin = currentTime end
					-- Print("["..dynamicCount.."] - Current: "..currentTime..", Max: "..debugMax..", Min: "..debugMin..", Avg: "..avgTime.." - Range: "..range)
				end
			end
		end
	end
	br.debug.cpu.enemiesEngine.bestUnitFinder = debugprofilestop()-startTime or 0
	return bestUnit
end

function dynamicTarget(range,facing)
	if range == nil or range > 100 then return nil end
	local startTime = debugprofilestop()
	local facing = facing or false
	if isChecked("Dynamic Targetting") then
		if getOptionValue("Dynamic Targetting") == 2 or (UnitAffectingCombat("player") and getOptionValue("Dynamic Targetting") == 1) then
			bestUnit = findBestUnit(range,facing)
		end
	end
	if UnitExists("target") and (not isChecked("Dynamic Targetting") or bestUnit == nil) and enemyListCheck("target") and isValidUnit("target")
		and getDistance("target") < range and (not facing or (facing and getFacing("player","target")))
	then
		bestUnit = "target"
	end
	if isChecked("Target Dynamic Target") and hasThreat(bestUnit) and (UnitExists("target") and not UnitIsUnit(bestUnit,"target")) then
		TargetUnit(bestUnit)
	elseif UnitAffectingCombat("player") and UnitIsDeadOrGhost("target") and hasThreat(bestUnit) then
		TargetUnit(bestUnit)
	end
	br.debug.cpu.enemiesEngine.dynamicTarget = debugprofilestop()-startTime or 0
	return bestUnit
end

local function targetNearestEnemy(range)
	for k,v in pairs(getEnemies("player",range)) do
		local thisUnit = br.enemy[v]
		if not UnitIsDeadOrGhost(thisUnit.unit) and getDistance("player",thisUnit.unit) <= range and ObjectIsFacing("player",thisUnit.unit) and getFacing("player", thisUnit.unit) and UnitInPhase(thisUnit.unit) then
			if not isChecked("Hostiles Only") or (getOptionCheck("Hostiles Only") and UnitReaction(thisUnit.unit,"player") <= 2 or (UnitExists("pet") and UnitReaction(thisUnit.unit,"pet") <= 2)) then
				bestUnit = thisUnit.unit
				if isChecked("Target Dynamic Target") and bestUnit ~= nil and (getOptionValue("Dynamic Targetting") == 2 or (getOptionValue("Dynamic Targetting") == 1 and inCombat)) then
					TargetUnit(bestUnit)
				end
			end
		end
	end
end

local enemyUpdateRate = enemyUpdateRate or 0
function getEnemyUpdateRate()
	if getOptionValue("Dynamic Target Rate") ~= nil and getOptionValue("Dynamic Target Rate") > 0.5 then enemyUpdateRate = getOptionValue("Dynamic Target Rate")
		else enemyUpdateRate = 0.5
	end
	if enemyUpdateRate < #getEnemies("player",50, true)/2 then
		enemyUpdateRate = #getEnemies("player",50, true)/2
	end
	return enemyUpdateRate
end

-- get the best aoe interupt unit for a given range
function getBestAoEInterupt(Range)
	-- pulse our function that add casters around to castersTable
	findCastersAround(Range)
	-- dummy var
	local bestAoEInteruptAmount = 0
	local bestAoEInteruptTarget = "target"
	-- cycle spellCasters to find best case
	local spellCastersTable = br.im.casters
	for i = 1, #spellCastersTable do
		-- check if unit is valid
		if GetObjectExists(spellCastersTable[i].unit) then
			-- if dummy beat old dummy, update
			if spellCastersTable[i].castersAround > bestAoEInteruptAmount then
				bestAoEInteruptAmount = spellCastersTable[i].castersAround
				bestAoEInteruptTarget = spellCastersTable[i].unit
			end
		end
	end
	-- return best case
	return bestAoEInteruptTarget
end

function getDebuffCount(spellID)
	local counter = 0
	for k, v in pairs(br.enemy) do
		local thisUnit = br.enemy[k].unit
		-- check if unit is valid
		if GetObjectExists(thisUnit) then
			-- increase counter for each occurences
			if UnitDebuffID(thisUnit,spellID,"player") then
				counter = counter + 1
			end
		end
	end
	return tonumber(counter)
end

-- to enlight redundant checks in getDistance within getEnemies
function getDistanceXYZ(unit1,unit2)
	-- check if unit is valid
	if GetObjectExists(unit1) and GetObjectExists(unit2) then
		local x1, y1, z1 = GetObjectPosition(unit1)
		local x2, y2, z2 = GetObjectPosition(unit2)
		return math.sqrt(((x2-x1)^2)+((y2-y1)^2)+((z2-z1)^2));
	end
end

function getTableEnemies(unit,Range,table)
	local getTableEnemies = { }
	if table == nil then return getTableEnemies end
	for i = 1, #table do
		local thisUnit = table[i]
		if getDistance(unit,thisUnit) <= Range then
			tinsert(getTableEnemies,thisUnit)
		end
	end
	return getTableEnemies
end

function isInside(x,y,ax,ay,bx,by,dx,dy)
	bax = bx - ax
	bay = by - ay
	dax = dx - ax
	day = dy - ay

	if ((x - ax) * bax + (y - ay) * bay <= 0.0) then return false end
	if ((x - bx) * bax + (y - by) * bay >= 0.0) then return false end
	if ((x - ax) * dax + (y - ay) * day <= 0.0) then return false end
	if ((x - dx) * dax + (y - dy) * day >= 0.0) then return false end

	return true
end

--[[function getEnemiesInCone(degrees,length,showLines,checkNoCombat)
	local LibDraw = LibStub("LibDraw-1.0")
	local playerX, playerY, playerZ = GetObjectPosition("player")
	local facing = ObjectFacing("player") or 0
	-- Left
	local lX, lY, lZ = GetPositionFromPosition(playerX, playerY, playerZ, 0, facing + math.rad(90+(degrees)), 0)
	-- Right
	local rX, rY, rZ = GetPositionFromPosition(playerX, playerY, playerZ, 0, facing + math.rad(90*2+(degrees)), 0)

	if showLines then
		-- Left
		LibDraw.Line(lX, lY, lZ, playerX, playerY, playerZ)
		-- Right
		LibDraw.Line(rX, rY, rZ, playerX, playerY, playerZ)
		-- Cone Complete
		LibDraw.Line(lX, lY, lZ, rX, rY, rZ)
	end

	if checkNoCombat == nil then checkNoCombat = false end
    if checkNoCombat then
    	enemiesTable = getEnemies("player",length,true)
    else
    	enemiesTable = getEnemies("player",length)
    end
	local enemyCounter = 0
	local maxX = math.max(rX,lX)
	local minX = math.min(rX,lX)
	local maxY = math.max(rY,lY)
	local minY = math.min(rY,lY)
	for i = 1, #enemiesTable do
		local thisUnit = enemiesTable[i]
		local tX, tY, tZ = GetObjectPosition(thisUnit)
		if isInside(tX,tY,lX,lY,rX,rY,playerX,playerY) then
			if showLines then
				LibDraw.Circle(tX, tY, playerZ, UnitBoundingRadius(thisUnit))
			end
			enemyCounter = enemyCounter + 1
		end
		-- end
	end
	return enemyCounter
end--]]

-- Cone Logic for Enemies
function getEnemiesInCone(angle,length,showLines,checkNoCombat)
    local playerX, playerY, playerZ = GetObjectPosition("player")
    local facing = ObjectFacing("player")
    local units = 0

    if checkNoCombat == nil then checkNoCombat = false end
    if checkNoCombat then
    	enemiesTable = getEnemies("player",length,true)
    else
    	enemiesTable = getEnemies("player",length)
    end

    for i = 1, #enemiesTable do
        local thisUnit = enemiesTable[i]
        local unitX, unitY, unitZ = GetObjectPosition(thisUnit)
        if playerX and unitX then
            local angleToUnit = getAngles(playerX,playerY,playerZ,unitX,unitY,unitZ)
            local angleDifference = facing > angleToUnit and facing - angleToUnit or angleToUnit - facing
            local shortestAngle = angleDifference < math.pi and angleDifference or math.pi*2 - angleDifference
            local finalAngle = shortestAngle/math.pi*180
            if finalAngle < angle then
                units = units + 1
            end
        end
    end
    return units
end

function getEnemiesInRect(width,length,showLines,checkNoCombat)
	local LibDraw = LibStub("LibDraw-1.0")
	local playerX, playerY, playerZ = GetObjectPosition("player")
	local facing = ObjectFacing("player") or 0

	-- Near Left
	local nlX, nlY, nlZ = GetPositionFromPosition(playerX, playerY, playerZ, width/2, facing + math.rad(90), 0)
	-- Near Right
	local nrX, nrY, nrZ = GetPositionFromPosition(playerX, playerY, playerZ, width/2, facing + math.rad(270), 0)
	-- Far Left
	local flX, flY, flZ = GetPositionFromPosition(nlX, nlY, nlZ, length, facing + math.rad(0), 0)
	-- Far Right
	local frX, frY, frZ = GetPositionFromPosition(nrX, nrY, nrZ, length, facing + math.rad(0), 0)

	if showLines then
		-- Near Left
		LibDraw.Line(nlX, nlY, nlZ, playerX, playerY, playerZ)
		-- Near Right
		LibDraw.Line(nrX, nrY, nrZ, playerX, playerY, playerZ)
		-- Far Left
		LibDraw.Line(flX, flY, flZ, nlX, nlY, nlZ)
		-- Far Right
		LibDraw.Line(frX, frY, frZ, nrX, nrY, nrZ)
		-- Box Complete
		LibDraw.Line(frX, frY, frZ, flX, flY, flZ)
	end

	if checkNoCombat == nil then checkNoCombat = false end
    if checkNoCombat then
    	enemiesTable = getEnemies("player",length,true)
    else
    	enemiesTable = getEnemies("player",length)
    end
	local enemyCounter = 0
	for i = 1, #enemiesTable do
		local thisUnit = enemiesTable[i]
		local tX, tY, tZ = GetObjectPosition(thisUnit)
		if isInside(tX,tY,nlX,nlY,nrX,nrY,frX,frY) then
			if showLines then
				LibDraw.Circle(tX, tY, playerZ, UnitBoundingRadius(thisUnit))
			end
			enemyCounter = enemyCounter + 1
		end
		-- end
	end
	return enemyCounter
end

-- local function intersects(circle, rect)
local function intersects(tX,tY,tR,aX,aY,cX,cY)
	-- if circle ~= nil then
	local circleDistance_x = math.abs(tX + tR - aX - (aX - cX)/2)
	local circleDistance_y = math.abs(tY + tR - aY - (aY - cY)/2)

	if (circleDistance_x > ((aX - cX)/2 + tR)) then
		return false
	end
	if (circleDistance_y > ((aY - cY)/2 + tR)) then
		return false
	end

	if (circleDistance_x <= ((aX - cX)/2)) then
		return true
	end

	if (circleDistance_y <= ((aY - cY)/2)) then
		return true
	end

	cornerDistance_sq = (circleDistance_x - (aX - cX)/2)^2 + (circleDistance_y - (aY - cY)/2)^2

	return (cornerDistance_sq <= (tR^2));
	-- else
	--     return false
	-- end
end

-- returns true if unit have an Offensive Buff that we should dispel
function getOffensiveBuffs(unit,guid)
	if GetObjectExists(unit) then
		local targets = br.read.enraged
		for i = 1,#targets do
			if guid == targets[i].guid then
				return targets[i].spellType
			end
		end
	end
	return false
end
-- returns true if Unit is a valid enemy
function getSanity(unit)
	if  GetUnitIsVisible(unit) == true and getCreatureType(unit) == true
			and ((UnitCanAttack(unit, "player") == true or not UnitIsFriend(unit,"player") or isDummy(unit)) and getLineOfSight(unit, "player"))
			and UnitIsDeadOrGhost(unit) == false
	then
		return true
	else
		return false
	end
end
-- This function will set the prioritisation of the units, ie which target should i attack
function getUnitCoeficient(unit)
	local coef = 0
	-- if distance == nil then distance = getDistance("player",unit) end
	local distance = getDistance("player",unit)
	-- check if unit is valid
	if GetObjectExists(unit) then
		-- if unit is out of range, bad prio(0)
		if distance < 50 then
			local unitHP = getHP(unit)
			-- if its our actual target we give it a bonus
			if UnitIsUnit("target",unit) == true then
				coef = coef + 1
			end
			-- if wise target checked, we look for best target by looking to the lowest or highest hp, otherwise we look for target
			if getOptionCheck("Wise Target") == true then
				if getOptionValue("Wise Target") == 1 then 	   -- Highest
					-- if highest is selected
					coef = unitHP
				elseif getOptionValue("Wise Target") == 3 then -- abs Highest
					coef = UnitHealth(unit)
				elseif getOptionValue("Wise Target") == 4 then -- Furthest
					coef = 100 - distance
				elseif getOptionValue("Wise Target") == 5 then -- Nearest
					coef = distance
				else 										   -- Lowest
					-- if lowest is selected
					coef = 100 - unitHP
				end
			end
			-- raid target management
			-- if the unit have the skull and we have param for it add 50
			if getOptionCheck("Skull First") and GetRaidTargetIndex(unit) == 8 then
				coef = coef + 50
			end
			-- if threat is checked, add 100 points of prio if we lost aggro on that target
			if getOptionCheck("Tank Threat") then
				local threat = UnitThreatSituation("player",unit) or -1
				if select(6, GetTalentTabInfo(GetPrimaryTalentTree())) == "TANK" and threat < 3 and unitHP > 10 then
					coef = coef + 100
				end
			end
			-- if user checked burn target then we add the value otherwise will be 0
			if getOptionCheck("Forced Burn") then
				coef = coef + isBurnTarget(unit)
			end
			-- if user checked avoid shielded, we add the % this shield remove to coef
			if getOptionCheck("Avoid Shields") then
				coef = coef + isShieldedTarget(unit)
			end
			local displayCoef = math.floor(coef*10)/10
			local displayName = UnitName(unit) or "invalid"
			-- Print("Unit "..displayName.." - "..displayCoef)
		end
	end
	return coef
end
-- function to see if our unit is a blacklisted unit
function isBlackListed(Unit)
	-- check if unit is valid
	if GetObjectExists(Unit) then
		for i = 1, #castersBlackList do
			-- check if unit is valid
			if GetObjectExists(castersBlackList[i].unit) then
				if castersBlackList[i].unit == Unit then
					return true
				end
			end
		end
	end
end
-- returns true if target should be burnt
function isBurnTarget(unit)
	local coef = 0
	-- check if unit is valid
	if getOptionCheck("Forced Burn") then
		local unitID = GetObjectID(unit)
		local burnUnit = br.lists.burnUnits[unitID]
		-- if unit have selected debuff
		if burnUnit then
			if burnUnit.buff and UnitBuffID(unit,burnUnit.buff) then
				coef = burnUnit.coef
			end
			if not burnUnit.buff and (UnitName(unit) == burnUnit.name or burnUnit) then
				TargetUnit(unit)
				coef = burnUnit.coef
			end
		end
	end
	return coef
end
-- check for a unit see if its a cc candidate
function isCrowdControlCandidates(Unit)
	-- check if unit is valid
	if GetObjectExists(Unit) then
		local unitID = GetObjectID(Unit)
	end
	-- cycle list of candidates
	local crowdControlUnit = br.lists.ccUnits[unitID]
	if crowdControlUnit then
		-- check if unit is valid
		if GetObjectExists(crowdControlUnit.unit) then
			-- is in the list of candidates
			if (crowdControlUnit.buff == nil or UnitBuffID(Unit,crowdControlUnit.buff))
					and (crowdControlUnit.spell == nil or getCastingInfo(Unit) == GetSpellInfo(crowdControlUnit.spell))
			then -- doesnt have more requirements or requirements are met
				return true
			end
		end
	end
	return false
end
--if isLongTimeCCed("target") then
-- CCs with >=20 seconds
-- function isLongTimeCCed(Unit)
-- 	if Unit == nil then return false end
-- 	-- check if unit is valid
-- 	if GetObjectExists(Unit) then
-- 		for i = 1, #longTimeCC do
-- 			--local checkCC=longTimeCC[i]
-- 			if UnitDebuffID(Unit,longTimeCC[i]) ~= nil then
-- 				return true
-- 			end
-- 		end
-- 	end
-- 	return false
-- end
-- returns true if we can safely attack this target
function isSafeToAttack(unit)
	if getOptionCheck("Safe Damage Check") == true then
		-- check if unit is valid
		local unitID = GetObjectExists(unit) and GetObjectID(unit) or 0
		for i = 1, #br.lists.noTouchUnits do
			local noTouch = br.lists.noTouchUnits[i]
			if noTouch.unitID == 1 or noTouch.unitID == unitID then
				if noTouch.buff > 0 then
					if UnitBuffID(unit,noTouch.buff) or UnitDebuffID(unit,noTouch.buff) then
						return false
					end
				else
					local posBuff = -(noTouch.buff)
					if not UnitBuffID(unit,posBuff) or UnitDebuffID(unit,posBuff) then
						return false
					end
				end
			end
		end
	end
	-- if all went fine return true
	return true
end
-- returns true if target is shielded or should be avoided
function isShieldedTarget(unit)
	local coef = 0
	if getOptionCheck("Avoid Shields") then
		-- check if unit is valid
		local unitID = GetObjectID(unit)
		local shieldedUnit = br.lists.shieldUnits[unitID]
		-- if unit have selected debuff
		if shieldedUnit and shieldedUnit.buff and UnitBuffID(unit,shieldedUnit.buff) then
			-- if it's a frontal buff, see if we are in front of it
			if shieldedUnit.frontal ~= true or getFacing(unit,"player") then
				coef = shieldedUnit.coef
			end
		end
	end
	return coef
end
