#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <pathfollower>
#include <tf2_stocks>

#pragma newdecls required

#define MODEL_NPC "models/bots/skeleton_sniper/skeleton_sniper.mdl"

Handle g_hMyNextBotPointer;
Handle g_hGetLocomotionInterface;
Handle g_hGetBodyInterface;
Handle g_hGetGroundNormal;
Handle g_hRun;
Handle g_hApproach;
Handle g_hFaceTowards;
Handle g_hResetSequence;
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

#define ANIM_MOVE 3
#define ANIM_IDLE 144
#define ANIM_FLOAT 4

public Plugin myinfo = 
{
	name = "[TF2] NextBot Weeper",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnMapStart()
{
	PrecacheModel(MODEL_NPC);

	//Absolutely fucking retarded.
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_01.wav");
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_02.wav");
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_03.wav");
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_04.wav");
	
	PrecacheScriptSound("MVM.SentryBusterStep");
}

public Action test(int client, int args)
{
	SpawnBuster(GetClientTeam(client), client); 
	ReplyToCommand(client, "[SM] Spawned");
	
	return Plugin_Handled;
}

stock void SpawnBuster(int iTeam, int iTarget = -1)
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
	DispatchKeyValue(npc, "modelscale", "1.0");
	DispatchKeyValue(npc, "health", "200");
	DispatchSpawn(npc);
	
	//trigger_hurts hurt.
	SetEntityFlags(npc, FL_CLIENT|FL_NOTARGET);
	
	SetEntProp(npc, Prop_Data, "m_bloodColor", -1); //Don't bleed
	SetEntPropEnt(npc, Prop_Data, "m_hOwnerEntity", iTarget);
	SetEntPropFloat(npc, Prop_Data, "m_speed", 200.0);
	SetEntProp(npc, Prop_Data, "m_takedamage", 0.0);
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
	PF_SetGoalEntity(npc, iTarget);
	PF_EnableCallback(npc, PFCB_Approach,            PluginBot_Approach);	
	PF_EnableCallback(npc, PFCB_IsEntityTraversable, PluginBot_Traversible);
	PF_StartPathing(npc);
	
	SDKHook(npc, SDKHook_Think, OnBotThink);
}

bool bSeen = false;

public void OnBotThink(int iEntity)
{
	float vecMe[3];
	GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", vecMe);

	float vecMeAng[3];
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", vecMeAng);

	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		if(!IsPlayerAlive(i))
			continue;
			
		if(GetClientTeam(i) == 0)
			continue;
			
		if(GetClientTeam(i) == 1)
			continue;
		
		float vecThem[3];
		GetClientEyePosition(i, vecThem);
		
		TR_TraceRayFilter(vecMe, vecThem, MASK_SHOT|CONTENTS_GRATE, RayType_EndPoint, AimTargetFilter, iEntity);
		if(TR_DidHit())
		{
			int entity = TR_GetEntityIndex();
			if(entity == i)
			{		
				vecThem[2] = 0.0;
				vecMe[2] = 0.0;
				
				float wsc_spy_to_victim[3]
				SubtractVectors(vecThem, vecMe, wsc_spy_to_victim);
				NormalizeVector(wsc_spy_to_victim, wsc_spy_to_victim);
				
				float vecTheirEye[3];
				GetEntPropVector(iEntity, Prop_Data, "m_angRotation", vecTheirEye);
				GetAngleVectors(vecTheirEye, vecTheirEye, NULL_VECTOR, NULL_VECTOR);
				vecTheirEye[2] = 0.0;
				NormalizeVector(vecTheirEye, vecTheirEye);
				
				float eye_victim[3];
				GetClientEyeAngles(i, eye_victim);
				GetAngleVectors(eye_victim, eye_victim, NULL_VECTOR, NULL_VECTOR);
				eye_victim[2] = 0.0;
				NormalizeVector(eye_victim, eye_victim);
				
				bSeen = (GetVectorDotProduct(wsc_spy_to_victim, eye_victim) <= 0.0);
				if(bSeen)
					break;
			}
		}
	}

	if(bSeen)
	{
		SetEntPropFloat(iEntity, Prop_Data, "m_speed", 0.0);
		return;
	}
	else
	{
		SetEntPropFloat(iEntity, Prop_Data, "m_speed", 400.0);
	}
	
	Address pLocomotion = GetLocomotionInterface(iEntity);
	if(pLocomotion == Address_Null)
		return;
	
	Address pStudioHdr = view_as<Address>(GetEntData(iEntity, 283 * 4));
	
	int m_iMoveX = SDKCall(g_hLookupPoseParameter, iEntity, pStudioHdr, "move_x");
	int m_iMoveY = SDKCall(g_hLookupPoseParameter, iEntity, pStudioHdr, "move_y");
	
	if ( m_iMoveX < 0 || m_iMoveY < 0 )
		return;
	
	int iSequence = GetEntProp(iEntity, Prop_Send, "m_nSequence");
	
	float flGroundSpeed = SDKCall(g_hGetGroundSpeed, pLocomotion);
	if ( flGroundSpeed != 0.0 )
	{
		if(iSequence != ANIM_MOVE)
		{
			SDKCall(g_hResetSequence, iEntity, ANIM_MOVE);
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
	
	SDKCall(g_hStudioFrameAdvance, iEntity);
	SDKCall(g_hDispatchAnimEvents, iEntity, iEntity);
}

public bool PluginBot_Traversible(int bot_entidx, int other_entidx) { return true; }

public void PluginBot_Approach(int bot_entidx, const float vec[3])
{
	Address pLocomotion = GetLocomotionInterface(bot_entidx);
	SDKCall(g_hRun, pLocomotion);

	if(bSeen)
		return;
	
	int iGoalEntity = GetEntPropEnt(bot_entidx, Prop_Data, "m_hOwnerEntity");
	if(iGoalEntity != -1)
	{
		float vTargetPos[3];
		GetEntPropVector(iGoalEntity, Prop_Data, "m_vecAbsOrigin", vTargetPos);
		
		float vOrigin[3];
		GetEntPropVector(bot_entidx, Prop_Data, "m_vecAbsOrigin", vOrigin);
		
		if(GetVectorDistance(vOrigin, vTargetPos) > 99.0)
		{
			SDKCall(g_hApproach, pLocomotion, vec, 1.0);
			
			ConVar flTurnRate = FindConVar("tf_base_boss_max_turn_rate");
			float flPrevValue = flTurnRate.FloatValue;
			flTurnRate.FloatValue = 500.0;
			SDKCall(g_hFaceTowards, pLocomotion, vec);
			flTurnRate.FloatValue = flPrevValue;
		}
	}
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

public void OnPluginStart()
{
	RegAdminCmd("sm_weeper", test, ADMFLAG_ROOT);
	
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

public bool AimTargetFilter(int entity, int contentsMask, any iExclude)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	
	if(StrEqual(class, "entity_medigun_shield"))
	{
		if(GetEntProp(entity, Prop_Send, "m_iTeamNum") == GetClientTeam(iExclude))
		{
			return false;
		}
	}
	else if(StrEqual(class, "func_respawnroomvisualizer"))
	{
		return false;
	}
	else if(StrContains(class, "tf_projectile_", false) != -1)
	{
		return false;
	}
	
	return !(entity == iExclude);
}