

local GrenadeCast = {};
local Resources = require(game.ReplicatedStorage.Resources)
local Signal = Resources:LoadLibrary("Signal")
local RunService = game:GetService("RunService")
local  Typer = Resources:LoadLibrary("Typer")
local fastSpawn = Resources:LoadLibrary("FastSpawn")

function GrenadeCast.new(nade)
	
	local nadeC = {};
	local nadeCM = {};
	
	setmetatable(nadeC,nadeCM)
	
	local IgnoreDescendantsInstance = nil
	
	local TrajectoryLengthChanged = Signal.new()
	local RayHit = Signal.new()
	
	local function Cast(O,D,L)
		local gRay = Ray.new(O,D)
		return workspace:FindPartOnRay(gRay,IgnoreDescendantsInstance)
	end
	
	local function CastWhitelist(O,D,WL)
		assert(Typer.ArrayOfInstancesOrEmptyTable(WL));
		local gRay = Ray.new(O,D)
		return workspace:FindPartOnRayWithWhitelist(gRay,WL)
	end
	
	local function CastBlacklist(O,D,BL)
		assert(Typer.ArrayOfInstancesOrEmptyTable(BL))
		local gRay = Ray.new(O,D)
		return workspace:FindPartOnRayWithIgnoreList(gRay,BL)
	end
	
	local function GetPhysicsData(gPos,gT,gDT,gVel,gGrav)
		local Gravity1 = (gGrav or workspace.Gravity) * -1
		local GravForce = Vector3.new(0, (Gravity1/2), 0)
		return gPos + (gVel * gDT),  gVel + (gDT * GravForce)
	end
	
	local function MainTrajectoryFire(origin,direction,velocity,func,duration,CosmeticNade,mode,list,defaultRotation)
		if type(velocity) == "number" then
			velocity = direction.Unit * velocity
		end
		if CosmeticNade then
			if CosmeticNade:IsA("Model") then
				CosmeticNade = CosmeticNade.PrimaryPart
			end
		end
		local detonated = false
		local UpgradedDir = (direction.Unit + velocity).Unit
		local Velocity = (UpgradedDir * velocity.Magnitude)
		local Rotation = (CosmeticNade and (CosmeticNade.CFrame - CosmeticNade.CFrame.p) or defaultRotation)
		local LastPoint = origin
		local Acceleration = Rotation  * Vector3.new(20,5,0)
		local TotalDelta = 0;
		local Tick0 = tick()
		local Tick1 
		local offset = Vector3.new()
		local gravity =  Vector3.new(0, -(workspace.Gravity/2), 0)
		local Bounce = false
		while not detonated do
			local Delta = RunService.Heartbeat:Wait()
			TotalDelta = TotalDelta + Delta
			if TotalDelta < duration  then
				local At, Velocity2 = GetPhysicsData(LastPoint,TotalDelta,Delta,Velocity,gravity.Magnitude)
				Velocity = Velocity2
				local AtDifference = (At - LastPoint)
				local AtDirection = AtDifference.Unit
				local AtDistance = AtDifference.Magnitude
				local RayDir =  AtDirection * Velocity.Magnitude * Delta
				local H, P, N, M = func(LastPoint,RayDir,list)
				Tick1 = tick() - Tick0
				if H then
					if H ~= CosmeticNade then--and Hit.Parent.Name ~= "BulletStorage" then
							if mode == "impact" then
								RayHit:Fire(H, P, N, M, CosmeticNade and CosmeticNade or RayDir.Unit)
								detonated = true
							else
										if CosmeticNade then
											Rotation = (CosmeticNade.CFrame - CosmeticNade.CFrame.p)
										end
										
										offset = 0.2 * N
										
										Tick0 = tick()
										
										Acceleration = N:Cross(Velocity)/0.2
										
										At = At + (N * (1/1000))
										
										local nmVel = N:Dot(Velocity)*N
										local tanVel = Velocity - nmVel
										local gFric 
										if Bounce then
											gFric = 1 - 0.08 * gravity.Magnitude * Delta / tanVel.Magnitude
										else
											gFric = 1 - 0.08 * (gravity.Magnitude*1.2*nmVel.Magnitude * Delta) / tanVel.Magnitude
										end
										Velocity = tanVel * (gFric < 0  and 0 or gFric) - 0.2 * nmVel
										Bounce = true
							end
							
					end
				else
					At =  At + (Velocity * Delta)
					Bounce = false		
				end
				local LastToCurrent_Distance = (LastPoint - At).Magnitude
				TrajectoryLengthChanged:Fire(LastPoint, offset, Tick1, Acceleration, Rotation, CosmeticNade)
				LastPoint = At	
			else
				detonated = true
			end
		end
		RayHit:Fire(nil, LastPoint, nil, nil, CosmeticNade and CosmeticNade or direction.Unit)
	end
		
	function nadeC:Fire(Origin, Direction, Velocity, CosmeticNade, Duration, Mode, Rot)
			assert(nadeC == self, "Expected ':' not '.' calling member function Fire")
			fastSpawn(function ()
					MainTrajectoryFire(Origin,Direction,Velocity,Cast,Duration,CosmeticNade,Mode,{},Rot)
			end)
	end
		
		function nadeC:FireWithWhitelist(Origin, Direction, Velocity, Whitelist, CosmeticNade, Duration, Mode, Rot)
			assert(nadeC == self, "Expected ':' not '.' calling member function Fire")
				fastSpawn(function ()
						MainTrajectoryFire(Origin,Direction,Velocity,CastWhitelist,Duration,CosmeticNade,Mode,Whitelist,Rot)
				end)
		end
		
		function nadeC:FireWithBlacklist(Origin, Direction, Velocity, Blacklist, CosmeticNade, Duration, Mode, Rot)
			assert(nadeC == self, "Expected ':' not '.' calling member function Fire")
			fastSpawn(function ()
					MainTrajectoryFire(Origin,Direction,Velocity,CastBlacklist,Duration,CosmeticNade,Mode,Blacklist,Rot)
			end)
		end
			
		nadeCM.__index = function (Table, Index)
		if Table == nadeC then
			if Index == "IgnoreDescendantsInstance" then
				return IgnoreDescendantsInstance
			elseif Index == "RayHit" then
				return RayHit
			elseif Index == "LengthChanged" then
				return TrajectoryLengthChanged
			end
		end
		end
	
		local IgnoreMode = false 
		nadeCM.__newindex = function (Table, Index, Value)
			if IgnoreMode then return end
			if Table == nadeC then
				if Index == "IgnoreDescendantsInstance" then
					assert(Value == nil or typeof(Value) == "Instance", "Bad argument \"" .. Index .. "\" (Instance expected, got " .. typeof(Value) .. ")")
					IgnoreDescendantsInstance = Value
				elseif Index == "RayHit" or Index == "LengthChanged"  then
					error("Can't set value", 0)
				end
			end
		end

		IgnoreMode = true
		nadeC.RayHit = RayHit
		nadeC.LengthChanged = TrajectoryLengthChanged
		nadeC.IgnoreDescendantsInstance = IgnoreDescendantsInstance
		IgnoreMode = false
		
		nadeCM.__metatable = "FastCaster"
		
		return nadeC
end
		
		
return GrenadeCast
