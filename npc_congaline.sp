#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <PathFollower>
#include <PathFollower_Nav>
#include <dhooks>
#include <dynamic>
#include <CBaseAnimatingOverlay>

#pragma newdecls required;

#define RAD2DEG(%1) ((%1) * (180.0 / FLOAT_PI))
#define DEG2RAD(%1) ((%1) * FLOAT_PI / 180.0)

#define EF_BONEMERGE                (1 << 0)
#define EF_PARENT_ANIMATES          (1 << 9)

//SDKCalls
Handle g_hMyNextBotPointer;
Handle g_hGetLocomotionInterface;
Handle g_hGetBodyInterface;
Handle g_hRun;
Handle g_hApproach;
Handle g_hFaceTowards;
Handle g_hResetSequence;
Handle g_hGetVelocity;
Handle g_hSetVelocity;
Handle g_hStudioFrameAdvance;
Handle g_hJump;
Handle g_hGetMaxAcceleration;
Handle g_hGetGroundSpeed;
Handle g_hLookupPoseParameter;
Handle g_hSetPoseParameter;
Handle g_hGetPoseParameter;
Handle g_hLookupSequence;
Handle g_hAddGestureSequence;
Handle g_hSDKWorldSpaceCenter;
Handle g_hStudio_FindAttachment;
Handle g_hGetAttachment;

//Stuck detection
Handle g_hStuckMonitor;
Handle g_hClearStuckStatus;
Handle g_hIsStuck;

//DHooks
Handle g_hGetFrictionSideways;
Handle g_hGetStepHeight;
Handle g_hGetGravity;
Handle g_hGetGroundNormal;
Handle g_hShouldCollideWith;
Handle g_hGetSolidMask;
Handle g_hStartActivity;
Handle g_hGetHullWidth;
Handle g_hGetHullHeight;
Handle g_hGetStandHullHeight;
Handle g_hGetCrouchHullHeight;

char s_cast[][] = 
{
	"models/player/scout.mdl",
	"models/player/soldier.mdl",
	"models/player/pyro.mdl",
	"models/player/demo.mdl",
	"models/player/heavy.mdl",
	"models/player/engineer.mdl",
	"models/player/medic.mdl",
	"models/player/sniper.mdl",
	"models/player/spy.mdl"
}

public Plugin myinfo = 
{
	name = "[TF2] NextBot Conga Line", 
	author = "Pelipoika", 
	description = "", 
	version = "1.0", 
	url = ""
};

methodmap BaseNPC
{
	public BaseNPC(float vecPos[3], float vecAng[3], const char[] model, const char[] modelscale = "1.0", const char[] health = "100", bool bGroundNormal = true)
	{
		int npc = CreateEntityByName("base_boss");
		DispatchKeyValueVector(npc, "origin",     vecPos);
		DispatchKeyValueVector(npc, "angles",     vecAng);
		DispatchKeyValue(npc,       "model",      s_cast[GetRandomInt(0, sizeof(s_cast) - 1)]);
		DispatchKeyValue(npc,       "modelscale", modelscale);
		DispatchKeyValue(npc,       "health",     health);
		DispatchSpawn(npc);
		
		Address pNB =         SDKCall(g_hMyNextBotPointer,        npc);
		Address pLocomotion = SDKCall(g_hGetLocomotionInterface,  pNB);
		
		DHookRaw(g_hGetStepHeight,       true, pLocomotion);
		DHookRaw(g_hGetGravity,          true, pLocomotion);
		DHookRaw(g_hShouldCollideWith,   true, pLocomotion);
		DHookRaw(g_hGetMaxAcceleration,  true, pLocomotion);
		DHookRaw(g_hGetFrictionSideways, true, pLocomotion);
		
		if(bGroundNormal)
			DHookRaw(g_hGetGroundNormal, true, pLocomotion)
		
		Address pBody = SDKCall(g_hGetBodyInterface, pNB);
		
		DHookRaw(g_hGetSolidMask,        true, pBody);
		DHookRaw(g_hStartActivity,       true, pBody);
		DHookRaw(g_hGetHullWidth,        true, pBody);
		DHookRaw(g_hGetHullHeight,       true, pBody);
		DHookRaw(g_hGetStandHullHeight,  true, pBody);
		DHookRaw(g_hGetCrouchHullHeight, true, pBody);
		
		SetEntityFlags(npc, FL_NOTARGET);
		
		SetEntData(npc, FindSendPropInfo("CTFBaseBoss", "m_lastHealthPercentage") + 28, false, 4, true);	//ResolvePlayerCollisions
		SetEntProp(npc, Prop_Data, "m_takedamage", 0);
		SetEntProp(npc, Prop_Data, "m_nSolidType", 0); 
		SetEntProp(npc, Prop_Data, "m_lifeState",  1); 

		ActivateEntity(npc);
		
		char strName[64];
		Format(strName, sizeof(strName), "conganpc_%x", EntIndexToEntRef(npc));
		
		Dynamic brain = Dynamic();
		brain.SetBool("Pathing", false);
		brain.SetName(strName);
		
		SDKHook(npc, SDKHook_Think, BasicPetThink);
		
		//Fix collisions
		SetEntPropVector(npc, Prop_Send, "m_vecMaxs", view_as<float>( { 6.5, 6.5, 34.0 } ));
		SetEntPropVector(npc, Prop_Data, "m_vecMaxs", view_as<float>( { 6.5, 6.5, 34.0 } ));
		
		SetEntPropVector(npc, Prop_Send, "m_vecMins", view_as<float>( { -6.5, -6.5, 0.0 } ));
		SetEntPropVector(npc, Prop_Data, "m_vecMins", view_as<float>( { -6.5, -6.5, 0.0 } ));
		
		return view_as<BaseNPC>(npc);
	}
	
	property int index
	{
		public get() 
		{ 
			return view_as<int>(this); 
		}
	}
	public Dynamic GetBrainInterface()
	{
		char strName[64];
		Format(strName, sizeof(strName), "conganpc_%x", EntIndexToEntRef(this.index));
		
		Dynamic brain = Dynamic.FindByName(strName);
		if(!brain.IsValid)
		{
			AcceptEntityInput(this.index, "Kill");
		}
		
		return brain;
	}	
	public Address GetLocomotionInterface()
	{
		Address pNB = SDKCall(g_hMyNextBotPointer, this.index);
		return SDKCall(g_hGetLocomotionInterface, pNB);
	}	
	public Address GetBodyInterface()
	{
		Address pNB = SDKCall(g_hMyNextBotPointer, this.index);
		return SDKCall(g_hGetBodyInterface, pNB);
	}
	
	property bool Pathing
	{
		public get()			
		{
			bool Pathing = false;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				Pathing = brain.GetBool("Pathing");
			}
			
			return Pathing;
		}
		public set(bool path)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetBool("Pathing", path);
				
				path ? PF_StartPathing(this.index) : PF_StopPathing(this.index);
			}
		}
	}
	public Address GetStudioHdr()
	{
		return view_as<Address>(GetEntData(this.index, 283 * 4));
	}
	public float GetPoseParameter(int iParameter)
	{
		return SDKCall(g_hGetPoseParameter, this.index, iParameter);
	}	
	public void SetPoseParameter(int iParameter, float value)
	{
		Address pStudioHdr = this.GetStudioHdr();
		if(pStudioHdr == Address_Null)
			return;
			
		SDKCall(g_hSetPoseParameter, this.index, pStudioHdr, iParameter, value);
	}	
	public int LookupPoseParameter(const char[] szName)
	{
		Address pStudioHdr = this.GetStudioHdr();
		if(pStudioHdr == Address_Null)
			return -1;
			
		return SDKCall(g_hLookupPoseParameter, this.index, pStudioHdr, szName);
	}	
	public int LookupSequence(const char[] anim)
	{
		Address pStudioHdr = this.GetStudioHdr();
		if(pStudioHdr == Address_Null)
			return -1;
			
		return SDKCall(g_hLookupSequence, pStudioHdr, anim);
	}	
	public void SetAnimation(const char[] anim)
	{
		int iSequence = this.LookupSequence(anim);
		if(iSequence >= 0)
			SDKCall(g_hResetSequence, this.index, iSequence);
	}	
	public bool IsPlayingGesture(const char[] anim)
	{
		int iSequence = this.LookupSequence(anim);
		if(iSequence >= 0)
			return IsPlayingGesture(this.index, iSequence);
		
		return false;
	}	
	public int PlayGesture(const char[] anim, bool autokill = true)
	{
		int iSequence = this.LookupSequence(anim);
		if(iSequence < 0)
			return -1;
		
		return SDKCall(g_hAddGestureSequence, this.index, iSequence, autokill);
	}	
	public void CreatePather(int iTarget, float flStep, float flJump, float flDrop, int iSolid, float flAhead, float flRePath, float flHull)
	{
		PF_Create(this.index, flStep, flJump, flDrop, 0.6, iSolid, flAhead, flRePath, flHull);
		PF_SetGoalEntity(this.index, iTarget);
		
		PF_EnableCallback(this.index, PFCB_Approach, PluginBot_Approach);
		//PF_EnableCallback(this.index, PFCB_GetPathCost, PluginBot_PathCost);
	}	
	public void Approach(const float vecGoal[3])
	{
		SDKCall(g_hApproach, this.GetLocomotionInterface(), vecGoal, 0.1);
	}	
	public void FaceTowards(const float vecGoal[3], float speed = 200.0)
	{
		//Sad!
		ConVar flTurnRate = FindConVar("tf_base_boss_max_turn_rate");
		float flPrevValue = flTurnRate.FloatValue;
		
		flTurnRate.FloatValue = speed;
		SDKCall(g_hFaceTowards, this.GetLocomotionInterface(), vecGoal);
		flTurnRate.FloatValue = flPrevValue;
	}
	public void Jump()
	{
		SDKCall(g_hJump, this.GetLocomotionInterface());
	}	
	public void Update()
	{
		SDKCall(g_hStudioFrameAdvance, this.index);
		SDKCall(g_hRun,                this.GetLocomotionInterface());	
		SDKCall(g_hStuckMonitor,       this.GetLocomotionInterface());
		
		bool bStuck = SDKCall(g_hIsStuck, this.GetLocomotionInterface());
		if(bStuck)
		{
			PrintToServer("STUCK");
			SDKCall(g_hClearStuckStatus, this.GetLocomotionInterface(), "Un-Stuck");
			TeleportEntity(this.index, WorldSpaceCenter(GetEntPropEnt(this.index, Prop_Send, "m_hOwnerEntity")), NULL_VECTOR, NULL_VECTOR);
		}
	}	
	public void GetVelocity(float vecOut[3])
	{
		SDKCall(g_hGetVelocity, this.GetLocomotionInterface(), vecOut);
	}	
	public void SetVelocity(const float vec[3])
	{
		SDKCall(g_hSetVelocity, this.GetLocomotionInterface(), vec);
	}	
	public int FindAttachment(const char[] pAttachmentName)
	{
		Address pStudioHdr = this.GetStudioHdr();
		if(pStudioHdr == Address_Null)
			return -1;
			
		return SDKCall(g_hStudio_FindAttachment, pStudioHdr, pAttachmentName) + 1;
	}	
	public void GetAttachment(const char[] szName, float absOrigin[3], float absAngles[3])
	{
		SDKCall(g_hGetAttachment, this.index, this.FindAttachment(szName), absOrigin, absAngles);
	}
	public int EquipItem(const char[] attachment, const char[] model, const char[] anim = "", int skin = 0, float flScale = 1.0)
	{
		int item = CreateEntityByName("prop_dynamic");
		DispatchKeyValue(item, "model", model);
		DispatchKeyValueFloat(item, "modelscale", flScale == 1.0 ? GetEntPropFloat(this.index, Prop_Send, "m_flModelScale") : flScale);
		DispatchSpawn(item);
		
		SetEntProp(item, Prop_Send, "m_nSkin", skin);
		SetEntProp(item, Prop_Send, "m_hOwnerEntity", this.index);
		SetEntProp(item, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_PARENT_ANIMATES);
	
		if(!StrEqual(anim, ""))
		{
			SetVariantString(anim);
			AcceptEntityInput(item, "SetAnimation");
		}
	
		SetVariantString("!activator");
		AcceptEntityInput(item, "SetParent", this.index);
		
		SetVariantString(attachment);
		AcceptEntityInput(item, "SetParentAttachmentMaintainOffset"); 
		
		return item;
	}
}

methodmap CongaLeader < BaseNPC
{
	public CongaLeader(int client, float vecPos[3], float vecAng[3])
	{
		BaseNPC pet = BaseNPC(vecPos, vecAng, "models/player/engineer.mdl", "0.4");
		
		SetEntProp(pet.index, Prop_Send, "m_nSkin", GetRandomInt(0, 1));
		
		pet.CreatePather(client, 18.0, 18.0, 1000.0, MASK_NPCSOLID | MASK_PLAYERSOLID, 50.0, 1.0, 1.0);
		pet.Pathing = true;
		
		pet.SetAnimation("taunt_conga");
		
		SetEntPropEnt(pet.index, Prop_Send, "m_hOwnerEntity", client);
		
		return view_as<CongaLeader>(pet);
	}
}

methodmap CongaMember < BaseNPC
{
	public CongaMember(CongaMember leader, float vecPos[3], float vecAng[3])
	{
		BaseNPC pet = BaseNPC(vecPos, vecAng, "models/player/engineer.mdl", "0.35");
		
		SetEntProp(pet.index, Prop_Send, "m_nSkin", GetRandomInt(0, 1));
		
		pet.CreatePather(view_as<int>(leader), 18.0, 18.0, 1000.0, MASK_NPCSOLID | MASK_PLAYERSOLID, 50.0, 1.0, 1.0);
		pet.Pathing = true;
		
		pet.SetAnimation("taunt_conga");
		
		SetEntPropEnt(pet.index, Prop_Send, "m_hOwnerEntity", view_as<int>(leader));
		
		return view_as<CongaMember>(pet);
	}
}

public void BasicPetThink(int iEntity)
{
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if(client <= 0)
	{
		AcceptEntityInput(iEntity, "Kill");
		return;
	}
	
	SetEntProp(iEntity, Prop_Data, "m_bSequenceLoops", true);
	
	BaseNPC npc = view_as<BaseNPC>(iEntity);
	npc.Update();
	
	float flOrigin[3], flAbsAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin",   flOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	float flCPos[3]; flCPos = WorldSpaceCenter(client);
	float flDistance = GetVectorDistance(flCPos, flOrigin);
	
	const float flDistanceLimit = 40.0;
	const float flMoveSpeed = 10.0
	
	//We don't wanna fall too behind.
	SetEntPropFloat(iEntity, Prop_Data, "m_speed", (flDistance >= flDistanceLimit) ? (flMoveSpeed * 3) : (flMoveSpeed));
	npc.Pathing = (flDistance > flDistanceLimit);
	
	float flGroundSpeed = SDKCall(g_hGetGroundSpeed, npc.GetLocomotionInterface());
	
	float m_flGroundSpeed = GetEntPropFloat(iEntity, Prop_Data, "m_flGroundSpeed");
	if(m_flGroundSpeed != 0.0)
	{
		float flReturnValue = clamp(flGroundSpeed / m_flGroundSpeed, -4.0, 12.0);
		
		SetEntPropFloat(iEntity, Prop_Send, "m_flPlaybackRate", flReturnValue);
	}
}

stock float[] WorldSpaceCenter(int entity)
{
	float vecPos[3];
	SDKCall(g_hSDKWorldSpaceCenter, entity, vecPos);
	
	return vecPos;
}

public float clamp(float a, float b, float c) { return (a > c ? c : (a < b ? b : a)); }

public Action Command_CongaLine(int client, int argc)
{
	//What are you.
	if(!(client > 0 && client <= MaxClients && IsClientInGame(client)))
		return Plugin_Handled;
		
	float wsc[3]; wsc = WorldSpaceCenter(client);
	
	CongaMember leader = view_as<CongaMember>(CongaLeader(client, wsc, NULL_VECTOR));
	SetEntProp(leader.index, Prop_Send, "m_hEffectEntity", view_as<int>(leader));
	
	//First congaer in the line.
	CongaMember iLineLeader = leader;
	
	for (int i = 0; i <= 32; i++)
	{	
		leader = CongaMember(leader, wsc, NULL_VECTOR);
		SetEntProp(leader.index, Prop_Send, "m_hEffectEntity", view_as<int>(iLineLeader));
	}
	
	return Plugin_Handled;
}

public Action Command_CongaStop(int client, int argc)
{
	//What are you.
	if(!(client > 0 && client <= MaxClients && IsClientInGame(client)))
		return Plugin_Handled;
	
	int pet = -1;
	while((pet = FindEntityByClassname(pet, "base_boss")) != -1)
	{
		AcceptEntityInput(pet, "Kill");
	}
	
	return Plugin_Handled;
}

public void OnPluginStart()
{
	RegAdminCmd("sm_congaline", Command_CongaLine, ADMFLAG_ROOT);
	RegAdminCmd("sm_congastop", Command_CongaStop, ADMFLAG_ROOT);
	
	Handle hConf = LoadGameConfigFile("tf2.pets");
	
	//SDKCalls
	//This call is used to get an entitys center position
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::WorldSpaceCenter");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if ((g_hSDKWorldSpaceCenter = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for CBaseEntity::WorldSpaceCenter offset!");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseAnimating::StudioFrameAdvance");
	if ((g_hStudioFrameAdvance = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::StudioFrameAdvance offset!"); 	

	//ResetSequence( int nSequence );
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
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::Jump");
	if((g_hJump = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::Jump!");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::GetVelocity");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if((g_hGetVelocity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::GetVelocity!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::SetVelocity");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	if((g_hSetVelocity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::SetVelocity!");

	//ILocomotion::GetGroundSpeed() 
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::GetGroundSpeed");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	if((g_hGetGroundSpeed = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::GetGroundSpeed!");

	//ILocomotion::IsStuck()
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::IsStuck");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if((g_hIsStuck = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::IsStuck!");
	
	//ILocomotion::ClearStuckStatus(char const* reason)
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::IsStuck");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if((g_hClearStuckStatus = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::ClearStuckStatus!");
	
	//ILocomotion::StuckMonitor
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::StuckMonitor");
	if((g_hStuckMonitor = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::StuckMonitor!");
	
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
	
	//-----------------------------------------------------------------------------
	// Purpose: Looks up a sequence by sequence name first, then by activity name.
	// Input  : label - The sequence name or activity name to look up.
	// Output : Returns the sequence index of the matching sequence, or ACT_INVALID.
	//-----------------------------------------------------------------------------
	//LookupSequence( CStudioHdr *pStudioHdr, const char *label );
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "LookupSequence");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//pStudioHdr
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//label
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//return index
	if((g_hLookupSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for LookupSequence");
	
	//int CBaseAnimatingOverlay::AddGestureSequence( int nSequence, bool autokill )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimatingOverlay::AddGestureSequence");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain); 
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hAddGestureSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimatingOverlay::AddGestureSequence");
	
	//DHooks
	g_hGetFrictionSideways = DHookCreateEx(hConf, "ILocomotion::GetFrictionSideways",HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetFrictionSideways);
	g_hGetStepHeight       = DHookCreateEx(hConf, "ILocomotion::GetStepHeight",      HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetStepHeight);	
	g_hGetGravity          = DHookCreateEx(hConf, "ILocomotion::GetGravity",         HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetGravity);	
	g_hGetGroundNormal     = DHookCreateEx(hConf, "ILocomotion::GetGroundNormal",    HookType_Raw, ReturnType_VectorPtr, ThisPointer_Address, ILocomotion_GetGroundNormal);
	g_hGetMaxAcceleration  = DHookCreateEx(hConf, "ILocomotion::GetMaxAcceleration", HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetMaxAcceleration);
	g_hShouldCollideWith   = DHookCreateEx(hConf, "ILocomotion::ShouldCollideWith",  HookType_Raw, ReturnType_Bool,      ThisPointer_Address, ILocomotion_ShouldCollideWith);
	DHookAddParam(g_hShouldCollideWith, HookParamType_CBaseEntity);
	
	g_hGetSolidMask        = DHookCreateEx(hConf, "IBody::GetSolidMask",             HookType_Raw, ReturnType_Int,       ThisPointer_Address, IBody_GetSolidMask);
	g_hGetHullWidth        = DHookCreateEx(hConf, "IBody::GetHullWidth",             HookType_Raw, ReturnType_Float,     ThisPointer_Address, IBody_GetHullWidth);
	g_hGetHullHeight       = DHookCreateEx(hConf, "IBody::GetHullHeight",            HookType_Raw, ReturnType_Float,     ThisPointer_Address, IBody_GetHullHeight);
	g_hGetStandHullHeight  = DHookCreateEx(hConf, "IBody::GetStandHullHeight",       HookType_Raw, ReturnType_Float,     ThisPointer_Address, IBody_GetStandHullHeight);
	g_hGetCrouchHullHeight = DHookCreateEx(hConf, "IBody::GetCrouchHullHeight",      HookType_Raw, ReturnType_Float,     ThisPointer_Address, IBody_GetCrouchHullHeight);
	g_hStartActivity       = DHookCreateEx(hConf, "IBody::StartActivity",            HookType_Raw, ReturnType_Bool,      ThisPointer_Address, IBody_StartActivity);
	
	delete hConf;
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

public MRESReturn ILocomotion_GetGroundNormal(Address pThis, Handle hReturn, Handle hParams)     { DHookSetReturnVector(hReturn, view_as<float>({0.0, 0.0, 1.0})); return MRES_Supercede; }
public MRESReturn ILocomotion_GetStepHeight(Address pThis, Handle hReturn, Handle hParams)       { DHookSetReturn(hReturn, 18.0);	return MRES_Supercede; }
public MRESReturn ILocomotion_GetMaxAcceleration(Address pThis, Handle hReturn, Handle hParams)  { DHookSetReturn(hReturn, 1700.0); return MRES_Supercede; }
public MRESReturn ILocomotion_GetFrictionSideways(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturn(hReturn, 3.0);    return MRES_Supercede; }
public MRESReturn ILocomotion_ShouldCollideWith(Address pThis, Handle hReturn, Handle hParams)   { DHookSetReturn(hReturn, false);  return MRES_Supercede; }
public MRESReturn ILocomotion_GetGravity(Address pThis, Handle hReturn, Handle hParams)          { DHookSetReturn(hReturn, 800.0);	return MRES_Supercede; }

public MRESReturn IBody_GetSolidMask(Address pThis, Handle hReturn, Handle hParams)        { DHookSetReturn(hReturn, MASK_NPCSOLID | MASK_PLAYERSOLID); return MRES_Supercede; }
public MRESReturn IBody_StartActivity(Address pThis, Handle hReturn, Handle hParams)       { DHookSetReturn(hReturn, true); return MRES_Supercede; }
public MRESReturn IBody_GetCrouchHullHeight(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturn(hReturn, 16.0); return MRES_Supercede; }
public MRESReturn IBody_GetStandHullHeight(Address pThis, Handle hReturn, Handle hParams)  { DHookSetReturn(hReturn, 34.0); return MRES_Supercede; }
public MRESReturn IBody_GetHullWidth(Address pThis, Handle hReturn, Handle hParams)        { DHookSetReturn(hReturn, 13.0); return MRES_Supercede; }
public MRESReturn IBody_GetHullHeight(Address pThis, Handle hReturn, Handle hParams)       { DHookSetReturn(hReturn, 34.0); return MRES_Supercede; }

public void PluginBot_Approach(int bot_entidx, const float vec[3])
{
	BaseNPC npc = view_as<BaseNPC>(bot_entidx);
	npc.Approach(vec);
	npc.FaceTowards(vec);
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
	seed *= GetEntPropEnt(bot_entidx, Prop_Send, "m_hEffectEntity");
	
	multiplier += (Cosine(float(seed)) + 1.0) * 5.0;
	
	float cost = dist * multiplier;
	
	return from_area.GetCostSoFar() + cost;
}