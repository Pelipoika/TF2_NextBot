#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <pathfollower>
#include <pathfollower_Nav>

#pragma newdecls required

#define MODEL_NPC "models/delorean_drivable.mdl"

enum ParticleAttachment
{
	PATTACH_ABSORIGIN = 0,			// Create at absorigin, but don't follow
	PATTACH_ABSORIGIN_FOLLOW,		// Create at absorigin, and update to follow the entity
	PATTACH_CUSTOMORIGIN,			// Create at a custom origin, but don't follow
	PATTACH_POINT,					// Create on attachment point, but don't follow
	PATTACH_POINT_FOLLOW,			// Create on attachment point, and update to follow the entity
	PATTACH_WORLDORIGIN,			// Used for control points that don't attach to an entity
	PATTACH_ROOTBONE_FOLLOW,		// Create at the root bone of the entity, and update to follow
	MAX_PATTACH_TYPES,
};

#define EF_BONEMERGE                (1 << 0)
#define EF_PARENT_ANIMATES          (1 << 9)

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
Handle g_hGetVectors;

Handle g_hDispatchParticleEffect;

Handle g_hLookupPoseParameter;
Handle g_hSetPoseParameter;
Handle g_hGetPoseParameter;

Handle g_hGetFrictionSideways;
Handle g_hGetMaxAcceleration;

Handle g_hStudio_FindAttachment;
Handle g_hGetAttachment;

Handle g_hGetGroundMotionVector
Handle g_hGetGroundSpeed;

public Plugin myinfo = 
{
	name = "[TF2] ",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_npctest", test, ADMFLAG_ROOT);
	
	Handle hConf = LoadGameConfigFile("tf2.pets");
	
	//DispatchParticleEffect(const char *pszParticleName, ParticleAttachment_t iAttachType, CBaseEntity *pEntity, const char *pszAttachmentName, bool bResetAllParticlesOnEntity)
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x56\x8B\x75\x10\x57\x83\xCF\xFF", 11);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//pszParticleName
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//iAttachType
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);	//pEntity
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//pszAttachmentName
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);			//bResetAllParticlesOnEntity 
	if ((g_hDispatchParticleEffect = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for DispatchParticleEffect signature!");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseAnimating::StudioFrameAdvance");
	if ((g_hStudioFrameAdvance = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::StudioFrameAdvance offset!"); 	

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::ResetSequence");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hResetSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::ResetSequence signature!"); 

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
	
	//CBaseAnimating::GetPoseParameter(int iParameter)
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::GetPoseParameter");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	if((g_hGetPoseParameter = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimating::GetPoseParameter");
	
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
	
	//CBaseEntity::GetVectors(Vector*, Vector*, Vector*) 
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::GetVectors");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if((g_hGetVectors = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for CBaseEntity::GetVectors!");
	
	//-----------------------------------------------------------------------------
	// Purpose: lookup attachment by name
	//-----------------------------------------------------------------------------
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "Studio_FindAttachment");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//pStudioHdr
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//pAttachmentName
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//return index
	if((g_hStudio_FindAttachment = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for Studio_FindAttachment");
	
	//-----------------------------------------------------------------------------
	// Purpose: Returns the world location and world angles of an attachment
	// Input  : attachment name
	// Output :	location and angles
	//-----------------------------------------------------------------------------
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::GetAttachment");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//iAttachment
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK); //absOrigin
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK); //absAngles
	if((g_hGetAttachment = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimating::GetAttachment");
	
	g_hGetStepHeight       = DHookCreateEx(hConf, "ILocomotion::GetStepHeight",      HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetStepHeight);	
	g_hGetGravity          = DHookCreateEx(hConf, "ILocomotion::GetGravity",         HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetGravity);	
	g_hGetGroundNormal     = DHookCreateEx(hConf, "ILocomotion::GetGroundNormal",    HookType_Raw, ReturnType_VectorPtr, ThisPointer_Address, ILocomotion_GetGroundNormal);
	g_hGetFrictionSideways = DHookCreateEx(hConf, "ILocomotion::GetFrictionSideways",HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetFrictionSideways);
	g_hGetMaxAcceleration  = DHookCreateEx(hConf, "ILocomotion::GetMaxAcceleration", HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetMaxAcceleration);
	g_hGetSolidMask        = DHookCreateEx(hConf, "IBody::GetSolidMask",             HookType_Raw, ReturnType_Int,       ThisPointer_Address, IBody_GetSolidMask);
	
	delete hConf;
}

public void OnMapStart()
{
	PrecacheModel(MODEL_NPC);
	
	PrecacheSound("dejavu.mp3");
	
	PrecacheSound("vehicles/v8/skid_highfriction.wav");
	PrecacheSound("vehicles/delorean/v8_turbo_on_loop1.wav");
	PrecacheSound("vehicles/v8/v8_turbo_on_loop1.wav");
	
	PrecacheSound("vehicles/v8/vehicle_impact_heavy1.wav");
}

public Action test(int client, int args)
{
	float vecPos[3], vecAng[3];
	GetAimPos(client, vecPos);
	GetClientEyeAngles(client, vecAng);
	vecAng[0] = 0.0;
	
	int npc = CreateEntityByName("base_boss");
	DispatchKeyValueVector(npc, "origin", vecPos);
	DispatchKeyValueVector(npc, "angles", vecAng);
	DispatchKeyValue(npc, "model", MODEL_NPC);
	DispatchKeyValue(npc, "modelscale", "0.5");
	DispatchKeyValue(npc, "health", "100");
	DispatchSpawn(npc);
	
	ActivateEntity(npc);
	
	//trigger_hurts hurt and spawn doors open for us, etc.
	SetEntityFlags(npc, FL_CLIENT|FL_NPC);
	
	//Don't bleed.
	SetEntProp(npc, Prop_Data, "m_bloodColor", -1); 
	
	//Speedster
	SetEntPropFloat(npc, Prop_Data, "m_speed", 800.0);
	
	//I won'd touch you.
	SetEntData(npc, FindSendPropInfo("CTFBaseBoss", "m_lastHealthPercentage") + 28, false, 4, true);	//ResolvePlayerCollisions
	
	//Don't touch me.
	SetEntProp(npc, Prop_Data, "m_nSolidType", 0); 

	SetEntPropVector(npc, Prop_Send, "m_vecMaxs", view_as<float>( { 32.0, 32.0, 16.0 } ));
	SetEntPropVector(npc, Prop_Data, "m_vecMaxs", view_as<float>( { 32.0, 32.0, 16.0 } ));
	SetEntPropVector(npc, Prop_Send, "m_vecMins", view_as<float>( { -32.0, -32.0, 0.0 } ));
	SetEntPropVector(npc, Prop_Data, "m_vecMins", view_as<float>( { -32.0, -32.0, 0.0 } ));

	float pos[3];
	NavArea area = TheNavMesh.GetNearestNavArea_Vec(vecPos);
	area.GetCenter(pos);
	
	PF_Create(npc, 18.0, 18.0, 1000.0, 0.6, MASK_PLAYERSOLID|MASK_NPCSOLID, 200.0, 0.1, 1.0, 1.0);
	PF_SetGoalVector(npc, pos);
	PF_EnableCallback(npc, PFCB_Approach, PluginBot_Approach);
	PF_EnableCallback(npc, PFCB_GetPathCost, PluginBot_PathCost);
	PF_StartPathing(npc);
	
	SDKHook(npc, SDKHook_Think, DeloreanThink);
	
	Address pLoco = GetLocomotionInterface(npc);
	Address pBody = GetBodyInterface(npc);
	
	DHookRaw(g_hGetStepHeight,       true, pLoco);
	DHookRaw(g_hGetGravity,          true, pLoco);
	DHookRaw(g_hGetGroundNormal,     true, pLoco);
	DHookRaw(g_hGetSolidMask,        true, pBody);
	DHookRaw(g_hGetMaxAcceleration,  true, pBody);
	DHookRaw(g_hGetFrictionSideways, true, pBody);
	
	EmitSoundToAll("dejavu.mp3", npc);
	EmitSoundToAll("dejavu.mp3", npc);
	EmitSoundToAll("vehicles/v8/v8_turbo_on_loop1.wav", npc);
	EmitSoundToAll("vehicles/v8/v8_turbo_on_loop1.wav", npc);
	EmitSoundToAll("vehicles/v8/v8_turbo_on_loop1.wav", npc);
	
	DispatchParticleEffect("speed_boost_trail", PATTACH_ABSORIGIN_FOLLOW, npc, "vehicle_engine");
	
	DispatchParticleEffect("kart_dust_trail_red", PATTACH_POINT_FOLLOW, npc, "rearlight_right");
	DispatchParticleEffect("kart_dust_trail_red", PATTACH_POINT_FOLLOW, npc, "rearlight_left");
	
	return Plugin_Handled;
}

void DispatchParticleEffect(const char[] pszParticleName, ParticleAttachment iAttachType, int pEntity, const char[] pszAttachmentName, bool bResetAllParticlesOnEntity = false)
{
	SDKCall(g_hDispatchParticleEffect, pszParticleName, iAttachType, pEntity, pszAttachmentName, bResetAllParticlesOnEntity);
}

public void DeloreanThink(int iEntity)
{
	Address pLocomotion = GetLocomotionInterface(iEntity);

	float flGroundSpeed = SDKCall(g_hGetGroundSpeed, pLocomotion);
	if (flGroundSpeed != 0.0)
	{
		float vecMyPos[3], vecAngles[3];
		GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", vecMyPos);
		GetEntPropVector(iEntity, Prop_Data, "m_angAbsRotation", vecAngles);

		//Current direction accroding to our movement.
		float vecMotion[3]
		SDKCall(g_hGetGroundMotionVector, pLocomotion, vecMotion);
		
		//Our direction according to our angles.
		float vecMyForward[3];
		GetAngleVectors(vecAngles, NULL_VECTOR, vecMyForward, NULL_VECTOR);
		
		//Our vecMotion as an angle.
		float vecMovementAngle[3];
		GetVectorAngles(vecMotion, vecMovementAngle);
		
		//Our vecMyForward as an angle.
		float vecMyForwardAngle[3];
		GetVectorAngles(vecMyForward, vecMyForwardAngle);
		vecMyForwardAngle[1] = AngleNormalizePositive(vecMyForwardAngle[1] - 180);
		
		float ang1 = vecMovementAngle[1];
		float ang2 = vecMyForwardAngle[1];
		float angDiff = FloatAbs(ang1 - ang2);
		
		int m_nSkin = GetEntProp(iEntity, Prop_Send, "m_nSkin");
		
		if (angDiff > 30.0 && flGroundSpeed >= 120.0 && GetEntityFlags(iEntity) & FL_ONGROUND)
		{
			float origin[3], angles[3];
			GetAttachment(iEntity, "wheel_rr", origin, angles);
			CreateParticle("doublejump_puff", origin, angles);
			
			GetAttachment(iEntity, "wheel_rl", origin, angles);
			CreateParticle("doublejump_puff", origin, angles);
			
			if(m_nSkin != 1)
			{
				SetEntProp(iEntity, Prop_Send, "m_nSkin", 1);
				EmitSoundToAll("vehicles/v8/skid_highfriction.wav", iEntity);
				EmitSoundToAll("vehicles/v8/skid_highfriction.wav", iEntity);
				EmitSoundToAll("vehicles/v8/skid_highfriction.wav", iEntity);
			}
		}
		else
		{
			if(m_nSkin != 0)
			{
				SetEntProp(iEntity, Prop_Send, "m_nSkin", 0);
			}
		}
		
		int m_iSteer = LookupPoseParameter(iEntity, "vehicle_steer");
		if ( m_iSteer < 0 )
			return;
		
		float flCurrentGoal[3];
		PF_GetFutureSegment(iEntity, 0, flCurrentGoal);
		
		float vecToGoal[3];
		MakeVectorFromPoints(vecMyPos, flCurrentGoal, vecToGoal);
		NormalizeVector(vecToGoal, vecToGoal);
		
		float vecForward[3], vecRight[3], vecUp[3];
		SDKCall(g_hGetVectors, iEntity, vecForward, vecRight, vecUp);
		
		float flDot = GetVectorDotProduct(vecForward, vecToGoal) * 2;
		SetPoseParameter(iEntity, m_iSteer, flDot);
	//	PrintCenterText(1, "  vecMovementAngle %f\n- vecMyForwardAngle %f\n = %f\nGroundspeed %f\nflDot %f", ang1, ang2, angDiff, flGroundSpeed, flDot);
		
		int m_iWheel_rl_spin = LookupPoseParameter(iEntity, "vehicle_wheel_rl_spin");
		int m_iWheel_rr_spin = LookupPoseParameter(iEntity, "vehicle_wheel_rr_spin");
		int m_iWheel_fl_spin = LookupPoseParameter(iEntity, "vehicle_wheel_fl_spin");
		int m_iWheel_fr_spin = LookupPoseParameter(iEntity, "vehicle_wheel_fr_spin");
		
		float flSpinRate = 20.0;
		SetPoseParameter(iEntity, m_iWheel_rl_spin, GetPoseParameter(iEntity, m_iWheel_rl_spin) + flSpinRate);
		SetPoseParameter(iEntity, m_iWheel_rr_spin, GetPoseParameter(iEntity, m_iWheel_rr_spin) + flSpinRate);
		SetPoseParameter(iEntity, m_iWheel_fl_spin, GetPoseParameter(iEntity, m_iWheel_fl_spin) + flSpinRate);
		SetPoseParameter(iEntity, m_iWheel_fr_spin, GetPoseParameter(iEntity, m_iWheel_fr_spin) + flSpinRate);
	}
}

public void PluginBot_Approach(int bot_entidx, const float vec[3])
{
	Address pLocomotion = GetLocomotionInterface(bot_entidx);
	
	SDKCall(g_hStudioFrameAdvance, bot_entidx);
	SDKCall(g_hRun, pLocomotion);
	SDKCall(g_hApproach, pLocomotion, vec, 1.0);
	
	float vecMyPos[3];
	GetEntPropVector(bot_entidx, Prop_Data, "m_vecAbsOrigin", vecMyPos);
	
	float trash[3], trash2[3];
	bool bSeg1 = PF_GetFutureSegment(bot_entidx, 0, trash);
	bool bSeg2 = PF_GetFutureSegment(bot_entidx, 1, trash2);
	
	if(bSeg1 && GetVectorDistance(trash, vecMyPos) <= 200.0 && !bSeg2)
	{
		float vecDirection[3];
		vecDirection[0] = GetRandomFloat(-1.0, 1.0);
		vecDirection[1] = GetRandomFloat(-1.0, 1.0);
		vecDirection[2] = 0.0;
		
		ScaleVector(vecDirection, 2000.0);
		
		AddVectors(vecMyPos, vecDirection, vecMyPos);
		
		//We've arrived.
		float pos[3];
		NavArea area = TheNavMesh.GetNearestNavArea_Vec(vecMyPos, true);
		if(area != NavArea_Null)
		{
			area.GetCenter(pos);
			
			if(PF_IsPathToVectorPossible(bot_entidx, pos))
			{
				PF_SetGoalVector(bot_entidx, pos);
			}
		}
	}
	
	float vecToTarget[3];
	SubtractVectors(vecMyPos, vec, vecToTarget);
	
	float vecAngles[3];
	GetVectorAngles(vecToTarget, vecAngles);
	
	float vRight[3];
	GetAngleVectors(vecAngles, NULL_VECTOR, vRight, NULL_VECTOR);
	
	vecMyPos[0] += vRight[0] * -90.0;
	vecMyPos[1] += vRight[1] * -90.0;
	vecMyPos[2] += vRight[2] * -90.0;
	
	ConVar flTurnRate = FindConVar("tf_base_boss_max_turn_rate");
	float flPrevValue = flTurnRate.FloatValue;
	flTurnRate.FloatValue = 200.0;
	SDKCall(g_hFaceTowards, pLocomotion, vecMyPos);
	flTurnRate.FloatValue = flPrevValue;
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
	
	float multiplier = 50.0;
	
	float cost = dist * multiplier;
	
	return from_area.GetCostSoFar() + cost;
}

public MRESReturn IBody_GetSolidMask(Address pThis, Handle hReturn, Handle hParams)              { DHookSetReturn(hReturn, (MASK_NPCSOLID|MASK_PLAYERSOLID)); return MRES_Supercede; }
public MRESReturn ILocomotion_GetGroundNormal(Address pThis, Handle hReturn, Handle hParams)     { DHookSetReturnVector(hReturn,    view_as<float>( { 0.0, 0.0, 1.0 } ));  return MRES_Supercede; }
public MRESReturn ILocomotion_GetStepHeight(Address pThis, Handle hReturn, Handle hParams)       { DHookSetReturn(hReturn, 18.0);	return MRES_Supercede; }
public MRESReturn ILocomotion_GetMaxAcceleration(Address pThis, Handle hReturn, Handle hParams)  { DHookSetReturn(hReturn, 100.0);  return MRES_Supercede; }
public MRESReturn ILocomotion_GetFrictionSideways(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturn(hReturn, 3.0);    return MRES_Supercede; }
public MRESReturn ILocomotion_GetGravity(Address pThis, Handle hReturn, Handle hParams)          { DHookSetReturn(hReturn, 800.0);  return MRES_Supercede; }

public int FindAttachment(int iEntity, const char[] pAttachmentName)
{
	Address pStudioHdr = view_as<Address>(GetEntData(iEntity, 283 * 4));
	if(pStudioHdr == Address_Null)
		return -1;
		
	return SDKCall(g_hStudio_FindAttachment, pStudioHdr, pAttachmentName) + 1;
}

public void GetAttachment(int iEntity, const char[] szName, float absOrigin[3], float absAngles[3])
{
	SDKCall(g_hGetAttachment, iEntity, FindAttachment(iEntity, szName), absOrigin, absAngles);
}

public float GetPoseParameter(int iEntity, int iParameter)
{
	return SDKCall(g_hGetPoseParameter, iEntity, iParameter);
}

public void SetPoseParameter(int iEntity, int iParameter, float value)
{
	Address pStudioHdr = view_as<Address>(GetEntData(iEntity, 283 * 4));
	if(pStudioHdr == Address_Null)
		return;
		
	SDKCall(g_hSetPoseParameter, iEntity, pStudioHdr, iParameter, value);
}

public int LookupPoseParameter(int iEntity, const char[] szName)
{
	Address pStudioHdr = view_as<Address>(GetEntData(iEntity, 283 * 4));
	if(pStudioHdr == Address_Null)
		return -1;
		
	return SDKCall(g_hLookupPoseParameter, iEntity, pStudioHdr, szName);
}	

stock void CreateParticle(char[] particle, float pos[3], float ang[3], int iEntityIndex = -1, int iAttachType = 5)
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
    
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", pos[0]);
	TE_WriteFloat("m_vecOrigin[1]", pos[1]);
	TE_WriteFloat("m_vecOrigin[2]", pos[2]);
	TE_WriteVector("m_vecAngles", ang);
	TE_WriteNum("m_iParticleSystemIndex", stridx);
	TE_WriteNum("entindex", iEntityIndex);
	TE_WriteNum("m_iAttachType", iAttachType);
	TE_SendToAll();
}

stock float AngleNormalizePositive( float angle )
{
	angle = fmodf(angle, 360.0);
	if (angle < 0.0)
	{
		angle += 360.0;
	}
	return angle;
}

stock float AngleNormalize( float angle )
{
	angle = fmodf(angle, 360.0);
	if (angle > 180) 
	{
		angle -= 360;
	}
	if (angle < -180)
	{
		angle += 360;
	}
	return angle;
}

stock float fmodf(float num, float denom)
{
	return num - denom * RoundToFloor(num / denom);
}

stock float operator%(float oper1, float oper2)
{
	return fmodf(oper1, oper2);
}

public float clamp(float a, float b, float c)
{
	return (a > c ? c : (a < b ? b : a));
}

public Address GetLocomotionInterface(int index)
{
	Address pNB = SDKCall(g_hMyNextBotPointer, index);
	return SDKCall(g_hGetLocomotionInterface, pNB);
}

public Address GetBodyInterface(int index)
{
	Address pNB = SDKCall(g_hMyNextBotPointer, index);
	return SDKCall(g_hGetBodyInterface, pNB);
}

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