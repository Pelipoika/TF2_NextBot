#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <pathfollower>
#include <tf2_stocks>

#pragma newdecls required

#define MODEL_NPC "models/bots/demo/bot_sentry_buster.mdl"

Handle g_hMyNextBotPointer;
Handle g_hGetLocomotionInterface;
Handle g_hGetBodyInterface;
Handle g_hGetGroundNormal;
Handle g_hRun;
Handle g_hApproach;
Handle g_hFaceTowards;
Handle g_hResetSequence;
Handle g_hResetSequenceInfo;
Handle g_hGetStepHeight;
Handle g_hGetGravity;
Handle g_hGetSolidMask;
Handle g_hStudioFrameAdvance;
Handle g_hDispatchAnimEvents;

Handle g_hGetMaxAcceleration;
Handle g_hShouldCollideWith;
Handle g_hGetGroundSpeed;
Handle g_hGetVectors;
Handle g_hGetGroundMotionVector;
Handle g_hHandleAnimEvent;

Handle g_hLookupPoseParameter;
Handle g_hSetPoseParameter;

#define ANIM_MOVE 78
#define ANIM_IDLE 48
#define ANIM_EXPL 103
#define ANIM_FLOA 86

/*
struct animevent_t
{
	int				event;
	const char		*options;
	float			cycle;
	float			eventtime;
	int				type;
	CBaseAnimating	*pSource;
};

https://mxr.alliedmods.net/hl2sdk-sdk2013/source/game/server/hl2/npc_citizen17.cpp#1860
*/

public Plugin myinfo = 
{
	name = "[TF2] NextBot Sentry Buster",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnMapStart()
{
	PrecacheModel(MODEL_NPC);

	//Absolutely fucking retarded.
	PrecacheSound(")mvm/sentrybuster/mvm_sentrybuster_explode.wav");
	PrecacheSound(")mvm/sentrybuster/mvm_sentrybuster_spin.wav");
	PrecacheSound("mvm/sentrybuster/mvm_sentrybuster_loop.wav");
	PrecacheSound(")mvm/sentrybuster/mvm_sentrybuster_intro.wav");
	
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_01.wav");
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_02.wav");
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_03.wav");
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_04.wav");

	PrecacheScriptSound("MVM.SentryBusterExplode");
	PrecacheScriptSound("MVM.SentryBusterSpin");
	PrecacheScriptSound("MVM.SentryBusterLoop");
	PrecacheScriptSound("MVM.SentryBusterIntro");
	PrecacheScriptSound("MVM.SentryBusterStep");
}

public Action test(int client, int args)
{
	int iTarget = GetClientAimTarget(client, false);	
	if(IsValidEntity(iTarget) && PF_IsEntityACombatCharacter(iTarget))
	{
		SpawnBuster(GetEntProp(iTarget, Prop_Send, "m_iTeamNum") == 3 ? 2 : 3, iTarget, NULL_VECTOR); 
		ReplyToCommand(client, "[SM] Spawned a Sentry Buster after whatever you aimed at");
	}	
	else
	{
		SpawnBuster(GetClientTeam(client), client, NULL_VECTOR); 
		ReplyToCommand(client, "[SM] Spawned a Sentry Buster after YOU!");
		
		//Go det at aimpos.
	//	float vPos[3];
	//	GetAimPos(client, vPos);
		
	//	SpawnBuster(GetClientTeam(client) == 2 ? 3 : 2, -1, vPos); 
	}
	
	return Plugin_Handled;
}

stock void SpawnBuster(int iTeam, int iTarget = -1, float vGoal[3])
{
	int spawn = -1;
	while((spawn = FindEntityByClassname(spawn, "info_player_teamspawn")) != -1)
	{
		bool bDisabled = !!GetEntProp(spawn, Prop_Data, "m_bDisabled");
		int iSpawnTeam = GetEntProp(spawn, Prop_Data, "m_iTeamNum");
		
		if(!bDisabled && iSpawnTeam == iTeam)
			break;
	}
	
	if(spawn == -1)
		return;
	
	float vSpawn[3];
	GetEntPropVector(spawn, Prop_Data, "m_vecAbsOrigin", vSpawn);
	
	int npc = CreateEntityByName("base_boss");
	DispatchKeyValueVector(npc, "origin", vSpawn);
	DispatchKeyValue(npc, "model", MODEL_NPC);
	DispatchKeyValue(npc, "modelscale", "1.75");
	DispatchKeyValue(npc, "health", "1000");
	DispatchSpawn(npc);
	
	//trigger_hurts hurt.
	SetEntityFlags(npc, FL_CLIENT);
	
	SetEntProp(npc, Prop_Data, "m_bloodColor", -1); //Don't bleed
	SetEntPropEnt(npc, Prop_Data, "m_hOwnerEntity", iTarget);
	SetEntPropFloat(npc, Prop_Data, "m_speed", 500.0);
	SetEntData(npc, FindSendPropInfo("CTFBaseBoss", "m_lastHealthPercentage") + 28, false, 4, true);	//ResolvePlayerCollisions
	
	SDKCall(g_hResetSequence, npc, ANIM_IDLE);
	
	ActivateEntity(npc);
	
	DHookEntity(g_hHandleAnimEvent, false, npc);
	
	Address pLoco = GetLocomotionInterface(npc);
	DHookRaw(g_hGetStepHeight,      true, pLoco);
	DHookRaw(g_hGetGravity,         true, pLoco);
	DHookRaw(g_hGetGroundNormal,    true, pLoco);
	DHookRaw(g_hShouldCollideWith,  true, pLoco);
	DHookRaw(g_hGetMaxAcceleration, true, pLoco);
	
	Address pBody = GetBodyInterface(npc);
	DHookRaw(g_hGetSolidMask,      true, pBody);
	
	PF_Create(npc, 18.0, 18.0, 1000.0, 0.6, MASK_PLAYERSOLID, 200.0, 1.0, 1.0, 0.3);
	iTarget == -1 ? PF_SetGoalVector(npc, vGoal) : PF_SetGoalEntity(npc, iTarget);
	PF_EnableCallback(npc, PFCB_Approach,            PluginBot_Approach);	
	PF_EnableCallback(npc, PFCB_IsEntityTraversable, PluginBot_Traversible);
	PF_EnableCallback(npc, PFCB_GetPathCost,         PluginBot_PathCost);
	PF_EnableCallback(npc, PFCB_PathFailed,          PluginBot_PathFailed);	
	PF_StartPathing(npc);
	
	SDKHook(npc, SDKHook_Think, OnBotThink);
	SDKHook(npc, SDKHook_OnTakeDamageAlive, OnBotDamaged);
	
	//Spawn sounds
	EmitGameSoundToAll("MVM.SentryBusterIntro", npc);
	EmitGameSoundToAll("MVM.SentryBusterLoop",  npc);
}

public Action OnBotDamaged(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	int iHealth = GetEntProp(victim, Prop_Data, "m_iHealth");
	
	CreateParticle("bot_impact_heavy", victim);
	
	if(damage > iHealth)
	{
		damage = 0.0;		
		Buster_StartDetonation(victim);
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public void OnBotThink(int iEntity)
{
	Address pLocomotion = GetLocomotionInterface(iEntity);
	if(pLocomotion == Address_Null)
		return;
	
	Address pStudioHdr = view_as<Address>(GetEntData(iEntity, 283 * 4));
	
	int m_iMoveX = SDKCall(g_hLookupPoseParameter, iEntity, pStudioHdr, "move_x");
	int m_iMoveY = SDKCall(g_hLookupPoseParameter, iEntity, pStudioHdr, "move_y");
	
	if ( m_iMoveX < 0 || m_iMoveY < 0 )
		return;
	
	int iSequence = GetEntProp(iEntity, Prop_Send, "m_nSequence");
	
	if(iSequence != ANIM_EXPL)
	{
		float flGroundSpeed = SDKCall(g_hGetGroundSpeed, pLocomotion);
		if ( flGroundSpeed != 0.0 )
		{
			if(!(GetEntityFlags(iEntity) & FL_ONGROUND))
			{
				if(iSequence != ANIM_FLOA)
				{
					SDKCall(g_hResetSequence, iEntity, ANIM_FLOA);
				}
			}
			else
			{			
				if(iSequence != ANIM_MOVE)
				{
					SDKCall(g_hResetSequence, iEntity, ANIM_MOVE);
				}
			}
			
			float vecForward[3], vecRight[3], vecUp[3];
			SDKCall(g_hGetVectors, iEntity, vecForward, vecRight, vecUp);
			
			float vecMotion[3]
			SDKCall(g_hGetGroundMotionVector, pLocomotion, vecMotion);
			
			SDKCall(g_hSetPoseParameter, iEntity, pStudioHdr, m_iMoveX, GetVectorDotProduct(vecMotion, vecForward));
			SDKCall(g_hSetPoseParameter, iEntity, pStudioHdr, m_iMoveY, GetVectorDotProduct(vecMotion, vecRight));
		}
		else
		{
			if(iSequence != ANIM_IDLE)
			{
				SDKCall(g_hSetPoseParameter, iEntity, pStudioHdr, m_iMoveX, 0.0);
				SDKCall(g_hSetPoseParameter, iEntity, pStudioHdr, m_iMoveY, 0.0);
				
				SDKCall(g_hResetSequence, iEntity, ANIM_IDLE);			
			}
		}
		
		float m_flGroundSpeed = GetEntPropFloat(iEntity, Prop_Data, "m_flGroundSpeed");
		if(m_flGroundSpeed != 0.0)
		{
			float flReturnValue = clamp(flGroundSpeed / m_flGroundSpeed, -4.0, 12.0);
			
			SetEntPropFloat(iEntity, Prop_Send, "m_flPlaybackRate", flReturnValue);
		}
	}
	else
	{
		float flCycle = GetEntPropFloat(iEntity, Prop_Data, "m_flCycle");
		if(flCycle >= 1.0) //PreDetonate animation complete.
		{
			Buster_Detonate(iEntity);
		}
	}

	SDKCall(g_hStudioFrameAdvance, iEntity);
	SDKCall(g_hDispatchAnimEvents, iEntity, iEntity);
}

public bool PluginBot_Traversible(int bot_entidx, int other_entidx) { return true; }

public void PluginBot_PathFailed(int bot_entidx) 
{
	PF_DisableCallback(bot_entidx, PFCB_PathFailed);
	PF_StopPathing(bot_entidx);
	
	Buster_StartDetonation(bot_entidx);
}

public float PluginBot_PathCost(int bot_entidx, NavArea area, NavArea from_area, float length)
{
	float dist;
	if (length != 0.0) 
	{
		dist = length;
	}
	else 
	{
		float vecCenter[3], vecFromCenter[3];
		area.GetCenter(vecCenter);
		from_area.GetCenter(vecFromCenter);
		
		float vecSubtracted[3]
		SubtractVectors(vecCenter, vecFromCenter, vecSubtracted)
		
		dist = GetVectorLength(vecSubtracted);
	}
	
	float multiplier = 1.0;
	
	int seed = RoundToFloor(GetGameTime() * 0.1) + 1;
	seed *= area.GetID();
	seed *= bot_entidx;
	
	multiplier += (Cosine(float(seed)) + 1.0) * 10.0;
	
	float cost = dist * multiplier;
	
	return from_area.GetCostSoFar() + cost;
}

public void PluginBot_Approach(int bot_entidx, const float vec[3])
{
	Address pLocomotion = GetLocomotionInterface(bot_entidx);
	
	SDKCall(g_hRun, pLocomotion);
	SDKCall(g_hApproach, pLocomotion, vec, 1.0);
	
	ConVar flTurnRate = FindConVar("tf_base_boss_max_turn_rate");
	float flPrevValue = flTurnRate.FloatValue;
	flTurnRate.FloatValue = 200.0;
	SDKCall(g_hFaceTowards, pLocomotion, vec);
	flTurnRate.FloatValue = flPrevValue;

	float vOrigin[3];
	GetEntPropVector(bot_entidx, Prop_Data, "m_vecAbsOrigin", vOrigin);
	
	int iGoalEntity = GetEntPropEnt(bot_entidx, Prop_Data, "m_hOwnerEntity");
	if(iGoalEntity != -1)
	{
		float vTargetPos[3];
		GetEntPropVector(iGoalEntity, Prop_Data, "m_vecAbsOrigin", vTargetPos);
		
		if(GetVectorDistance(vOrigin, vTargetPos) <= 99.0)
		{
			Buster_StartDetonation(bot_entidx);
		}
	}
}

void Buster_StartDetonation(int bot)
{
	//Start Detonation
	EmitGameSoundToAll("MVM.SentryBusterSpin",  bot);
	SDKCall(g_hResetSequence, bot, ANIM_EXPL);
	SDKCall(g_hResetSequence, bot, ANIM_EXPL);
	PF_StopPathing(bot);
	
	SetEntProp(bot, Prop_Data, "m_takedamage", 0);
	SetEntPropFloat(bot, Prop_Send, "m_flPlaybackRate", 1.0);
	
	StopSound(bot, SNDCHAN_STATIC, "mvm/sentrybuster/mvm_sentrybuster_loop.wav");
	
	SDKUnhook(bot, SDKHook_OnTakeDamageAlive, OnBotDamaged);
}

void Buster_Detonate(int bot)
{
	//Finish Detonation
	float vPos[3];
	GetEntPropVector(bot, Prop_Data, "m_vecAbsOrigin", vPos);
	vPos[2] += 64.0;
	
	CreateParticle("fluidSmokeExpl_ring_mvm", bot);
	Explode(vPos, 5000.0, 300.0, "explosionTrail_seeds_mvm", "MVM.SentryBusterExplode");
	
	StopSound(bot, SNDCHAN_STATIC, "mvm/sentrybuster/mvm_sentrybuster_loop.wav");
	
	AcceptEntityInput(bot, "Kill");
}

public MRESReturn IBody_GetSolidMask(Address pThis, Handle hReturn, Handle hParams)             { DHookSetReturn(hReturn, 0x203400B);                                 return MRES_Supercede; }
public MRESReturn ILocomotion_GetGravity(Address pThis, Handle hReturn, Handle hParams)         { DHookSetReturn(hReturn, 800.0);                                     return MRES_Supercede; }
public MRESReturn ILocomotion_GetStepHeight(Address pThis, Handle hReturn, Handle hParams)      { DHookSetReturn(hReturn, 20.0);                                      return MRES_Supercede; }
public MRESReturn ILocomotion_GetMaxAcceleration(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturn(hReturn, 1700.0);                                    return MRES_Supercede; }
public MRESReturn ILocomotion_ShouldCollideWith(Address pThis, Handle hReturn, Handle hParams)  { DHookSetReturn(hReturn, false);                                     return MRES_Supercede; }
public MRESReturn ILocomotion_GetGroundNormal(Address pThis, Handle hReturn, Handle hParams)    { DHookSetReturnVector(hReturn, view_as<float>( { 0.0, 0.0, 1.0 } )); return MRES_Supercede; }

public MRESReturn CBaseAnimating_HandleAnimEvent(int pThis, Handle hParams)
{
	int event = DHookGetParamObjectPtrVar(hParams, 1, 0, ObjectValueType_Int);
	if(event == 7001)	//Footstep
	{
		EmitGameSoundToAll("MVM.SentryBusterStep", pThis);
	}
}

public float clamp(float a, float b, float c) { return (a > c ? c : (a < b ? b : a)); }

public Address GetLocomotionInterface(int index) { return SDKCall(g_hGetLocomotionInterface, SDKCall(g_hMyNextBotPointer, index)); }
public Address GetBodyInterface(int index)       { return SDKCall(g_hGetBodyInterface,       SDKCall(g_hMyNextBotPointer, index)); }

stock void Explode(float flPos[3], float flDamage, float flRadius, const char[] strParticle, const char[] strSound)
{
    int iBomb = CreateEntityByName("tf_generic_bomb");
    DispatchKeyValueVector(iBomb, "origin", flPos);
    DispatchKeyValueFloat(iBomb, "damage", flDamage);
    DispatchKeyValueFloat(iBomb, "radius", flRadius);
    DispatchKeyValue(iBomb, "health", "1");
    DispatchKeyValue(iBomb, "explode_particle", strParticle);
    DispatchKeyValue(iBomb, "sound", strSound);
    DispatchSpawn(iBomb);

    AcceptEntityInput(iBomb, "Detonate");
}  

stock void CreateParticle(char[] particle, int iEntity)
{
	int tblidx = FindStringTable("ParticleEffectNames");
	char tmp[256];
	int count = GetStringTableNumStrings(tblidx);
	int stridx = INVALID_STRING_INDEX;
	
	for(int i = 0; i < count; i++)
	{
		ReadStringTable(tblidx, i, tmp, sizeof(tmp));
		if(StrEqual(tmp, particle, false))
		{
			stridx = i;
			break;
		}
	}
	
	float vPos[3], vAng[3];
	GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", vPos);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", vAng);
	
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", vPos[0]);
	TE_WriteFloat("m_vecOrigin[1]", vPos[1]);
	TE_WriteFloat("m_vecOrigin[2]", vPos[2]);
	TE_WriteVector("m_vecAngles", vAng);
	TE_WriteNum("m_iParticleSystemIndex", stridx);
	TE_WriteNum("entindex", iEntity);
	TE_WriteNum("m_iAttachType", 0);
	TE_SendToAll();
}

stock bool GetAimPos(int client, float vecPos[3])
{
	float StartOrigin[3], Angles[3];
	GetClientEyeAngles(client, Angles);
	GetClientEyePosition(client, StartOrigin);

	Handle TraceRay = TR_TraceRayFilterEx(StartOrigin, Angles, MASK_ALL, RayType_Infinite, ExcludeFilter, client);
	if (TR_DidHit(TraceRay))
	{
		TR_GetEndPosition(vecPos, TraceRay);
	}
	
	delete TraceRay;
}

public bool ExcludeFilter(int entityhit, int mask, any entity)
{
	if (entityhit > MaxClients && entityhit != entity)
	{
		return true;
	}
	
	return false;
}

public void OnPluginStart()
{
	RegAdminCmd("sm_bust", test, ADMFLAG_ROOT);
	
	Handle hConf = LoadGameConfigFile("tf2.pets");
	
	//SDKCalls
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseAnimating::StudioFrameAdvance");
	if ((g_hStudioFrameAdvance = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::StudioFrameAdvance offset!"); 	

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseAnimating::DispatchAnimEvents");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((g_hDispatchAnimEvents = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::DispatchAnimEvents offset!"); 
	
	//ResetSequence( int nSequence );
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::ResetSequence");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hResetSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::ResetSequence signature!"); 

	//ResetSequenceInfo( );
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::ResetSequenceInfo");
	if((g_hResetSequenceInfo = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimating::ResetSequenceInfo");

	//MyNextBotPointer( );
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::MyNextBotPointer");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hMyNextBotPointer = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseEntity::MyNextBotPointer offset!"); 
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBot::GetLocomotionInterface");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hGetLocomotionInterface = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for INextBot::GetLocomotionInterface!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBot::GetBodyInterface");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hGetBodyInterface = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for INextBot::GetBodyInterface!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::Run");
	if((g_hRun = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::Run!");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::Approach");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	if((g_hApproach = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::Approach!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::FaceTowards");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	if((g_hFaceTowards = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::FaceTowards!");
	
	//ILocomotion::GetGroundSpeed() 
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::GetGroundSpeed");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	if((g_hGetGroundSpeed = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::GetGroundSpeed!");
	
	//ILocomotion::GetGroundMotionVector() 
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::GetGroundMotionVector");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if((g_hGetGroundMotionVector = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::GetGroundMotionVector!");
	
	//CBaseEntity::GetVectors(Vector*, Vector*, Vector*) 
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::GetVectors");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if((g_hGetVectors = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for CBaseEntity::GetVectors!");

	//SetPoseParameter( CStudioHdr *pStudioHdr, int iParameter, float flValue );
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::SetPoseParameter");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	if((g_hSetPoseParameter = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimating::SetPoseParameter");
	
	//LookupPoseParameter( CStudioHdr *pStudioHdr, const char *szName );
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::LookupPoseParameter");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hLookupPoseParameter = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimating::LookupPoseParameter");
	
	//DHooks
	g_hGetSolidMask       = DHookCreateEx(hConf, "IBody::GetSolidMask",             HookType_Raw, ReturnType_Int,       ThisPointer_Address, IBody_GetSolidMask);
	g_hGetStepHeight      = DHookCreateEx(hConf, "ILocomotion::GetStepHeight",      HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetStepHeight);	
	g_hGetGravity         = DHookCreateEx(hConf, "ILocomotion::GetGravity",         HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetGravity);	
	g_hGetGroundNormal    = DHookCreateEx(hConf, "ILocomotion::GetGroundNormal",    HookType_Raw, ReturnType_VectorPtr, ThisPointer_Address, ILocomotion_GetGroundNormal);
	g_hGetMaxAcceleration = DHookCreateEx(hConf, "ILocomotion::GetMaxAcceleration", HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetMaxAcceleration);

	g_hShouldCollideWith  = DHookCreateEx(hConf, "ILocomotion::ShouldCollideWith",  HookType_Raw, ReturnType_Bool,      ThisPointer_Address, ILocomotion_ShouldCollideWith);
	DHookAddParam(g_hShouldCollideWith, HookParamType_CBaseEntity);
	
	g_hHandleAnimEvent    = DHookCreateEx(hConf, "CBaseAnimating::HandleAnimEvent",  HookType_Entity, ReturnType_Void,   ThisPointer_CBaseEntity, CBaseAnimating_HandleAnimEvent);
	DHookAddParam(g_hHandleAnimEvent, HookParamType_ObjectPtr, -1);
		
	delete hConf;
}

//I should of have done this long ago.
Handle DHookCreateEx(Handle gc, const char[] key, HookType hooktype, ReturnType returntype, ThisPointerType thistype, DHookCallback callback)
{
	int iOffset = GameConfGetOffset(gc, key);
	if(iOffset == -1)
	{
		SetFailState("Failed to get offset of %s", key);
		return null;
	}
	
	return DHookCreate(iOffset, hooktype, returntype, thistype, callback);
}