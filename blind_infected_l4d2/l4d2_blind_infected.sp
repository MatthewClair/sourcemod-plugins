#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include "weapons.inc"

#define SURVIVOR_TEAM 2
#define INFECTED_TEAM 3
#define ENT_CHECK_INTERVAL 1.0
#define TRACE_TOLERANCE 75.0

enum EntInfo
{
	iEntity,
	bool:hasBeenSeen
}

new const iIdsToBlock[] =
{
	_:WEPID_PISTOL,
	_:WEPID_SMG,
	_:WEPID_PUMPSHOTGUN,
	_:WEPID_AUTOSHOTGUN,
	_:WEPID_RIFLE,
	_:WEPID_HUNTING_RIFLE,
	_:WEPID_SMG_SILENCED,
	_:WEPID_SHOTGUN_CHROME,
	_:WEPID_RIFLE_DESERT,
	_:WEPID_SNIPER_MILITARY,
	_:WEPID_SHOTGUN_SPAS,
	_:WEPID_FIRST_AID_KIT,
	_:WEPID_MOLOTOV,
	_:WEPID_PIPE_BOMB,
	_:WEPID_PAIN_PILLS,
	_:WEPID_GASCAN,
	_:WEPID_PROPANE_TANK,
	_:WEPID_OXYGEN_TANK,
	_:WEPID_MELEE,
	_:WEPID_CHAINSAW,
	_:WEPID_GRENADE_LAUNCHER,
	_:WEPID_AMMO_PACK,
	_:WEPID_ADRENALINE,
	_:WEPID_DEFIBRILLATOR,
	_:WEPID_VOMITJAR,
	_:WEPID_RIFLE_AK47,
	_:WEPID_FIREWORKS_BOX,
	_:WEPID_INCENDIARY_AMMO,
	_:WEPID_FRAG_AMMO,
	_:WEPID_PISTOL_MAGNUM,
	_:WEPID_SMG_MP5,
	_:WEPID_RIFLE_SG552
};

new Handle:hBlockedEntities;

public OnPluginStart()
{
	//L4D2Weapons_Init();

	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);

	hBlockedEntities = CreateArray(_:EntInfo);

	CreateTimer(ENT_CHECK_INTERVAL, EntCheck_Timer, _, TIMER_REPEAT);
}

public Action:EntCheck_Timer(Handle:timer)
{
	new size = GetArraySize(hBlockedEntities);
	decl currentEnt[EntInfo];

	for (new i; i < size; i++)
	{
		GetArrayArray(hBlockedEntities, i, currentEnt[0]);
		if (!currentEnt[hasBeenSeen] && IsVisibleToSurvivors(currentEnt[iEntity]))
		{
			decl String:tmp[128];
			GetEntPropString(currentEnt[iEntity], Prop_Data, "m_ModelName", tmp, sizeof(tmp));
			currentEnt[hasBeenSeen] = true;
			SetArrayArray(hBlockedEntities, i, currentEnt[0]);
		}
	}
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	ClearArray(hBlockedEntities);
	CreateTimer(1.2, RoundStartDelay_Timer);
}

public Action:RoundStartDelay_Timer(Handle:timer)
{
	decl String:sModelName[128], String:sTemp[128], bhTemp[EntInfo];
	new psychonic = GetEntityCount();

	for (new i = MaxClients; i < psychonic; i++)
	{
		if (IsValidEntity(i))
		{
			GetEntPropString(i, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

			for (new j; j < sizeof(iIdsToBlock); j++)
			{
				Format(sTemp, sizeof(sTemp), "models%s", WeaponModels[iIdsToBlock[j]]);
				if (StrEqual(sTemp, sModelName, false))
				{
					SDKHook(i, SDKHook_SetTransmit, OnTransmit);
					bhTemp[iEntity] = i;
					bhTemp[hasBeenSeen] = false;
					PushArrayArray(hBlockedEntities, bhTemp[0]);
					break;
				}
			}
		}
	}
}

public Action:OnTransmit(entity, client)
{
	if (GetClientTeam(client) != INFECTED_TEAM) return Plugin_Continue;

	new size = GetArraySize(hBlockedEntities);
	decl currentEnt[EntInfo];

	for (new i; i < size; i++)
	{
		GetArrayArray(hBlockedEntities, i, currentEnt[0]);
		if (entity == currentEnt[iEntity])
		{
			if (currentEnt[hasBeenSeen]) return Plugin_Continue;
			else return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

// from http://code.google.com/p/srsmod/source/browse/src/scripting/srs.despawninfected.sp
stock bool:IsVisibleToSurvivors(entity)
{
	new iSurv;

	for (new i = 1; i < MaxClients && iSurv < 4; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == SURVIVOR_TEAM)
		{
			iSurv++
			if (IsPlayerAlive(i) && IsVisibleTo(i, entity)) 
			{
				return true;
			}
		}
	}

	return false;
}

stock bool:IsVisibleTo(client, entity) // check an entity for being visible to a client
{
	decl Float:vAngles[3], Float:vOrigin[3], Float:vEnt[3], Float:vLookAt[3];
	
	GetClientEyePosition(client,vOrigin); // get both player and zombie position
	
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vEnt);
	
	MakeVectorFromPoints(vOrigin, vEnt, vLookAt); // compute vector from player to zombie
	
	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace
	
	// execute Trace
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceFilter);
	
	new bool:isVisible = false;
	if (TR_DidHit(trace))
	{
		decl Float:vStart[3];
		TR_GetEndPosition(vStart, trace); // retrieve our trace endpoint
		
		if ((GetVectorDistance(vOrigin, vStart, false) + TRACE_TOLERANCE) >= GetVectorDistance(vOrigin, vEnt))
		{
			isVisible = true; // if trace ray lenght plus tolerance equal or bigger absolute distance, you hit the targeted zombie
		}
	}
	else
	{
		//Debug_Print("Zombie Despawner Bug: Player-Zombie Trace did not hit anything, WTF");
		isVisible = true;
	}
	CloseHandle(trace);
	return isVisible;
}

public bool:TraceFilter(entity, contentsMask)
{
	if (entity <= MaxClients || !IsValidEntity(entity)) // dont let WORLD, players, or invalid entities be hit
	{
		return false;
	}
	
	decl String:class[128];
	GetEdictClassname(entity, class, sizeof(class)); // Ignore prop_physics since some can be seen through
	
	return !StrEqual(class, "prop_physics", false);
}