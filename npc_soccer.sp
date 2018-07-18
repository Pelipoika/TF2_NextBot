#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <pathfollower>
#include <tf2_stocks>

#pragma newdecls required


//SDKCalls
Handle g_hMyNextBotPointer;
Handle g_hGetLocomotionInterface;
Handle g_hGetBodyInterface;
Handle g_hGetVisionInterface;
Handle g_hRun;
Handle g_hApproach;
Handle g_hFaceTowards;
Handle g_hResetSequence;
Handle g_hStudioFrameAdvance;
Handle g_hJump;
Handle g_hDispatchAnimEvents;
Handle g_hGetMaxAcceleration;
Handle g_hGetGroundSpeed;
Handle g_hGetVectors;
Handle g_hGetGroundMotionVector;
Handle g_hLookupPoseParameter;
Handle g_hSetPoseParameter;
Handle g_hGetPoseParameter;
Handle g_hLookupSequence;
Handle g_hSDKWorldSpaceCenter;
Handle g_hStudio_FindAttachment;
Handle g_hGetAttachment;
Handle g_hAddGestureSequence;


//Stuck detection
Handle g_hStuckMonitor;
Handle g_hClearStuckStatus;
Handle g_hIsStuck;

//DHooks
Handle g_hGetStepHeight;
Handle g_hGetGravity;
Handle g_hGetGroundNormal;
Handle g_hShouldCollideWith;
Handle g_hGetSolidMask;

public Plugin myinfo = 
{
	name = "[TF2] Balls", 
	author = "Pelipoika", 
	description = "", 
	version = "1.0", 
	url = ""
};

public void OnPluginStart()
{
	RegAdminCmd("sm_spawnball", Command_SpawnBall, ADMFLAG_ROOT);
	RegAdminCmd("sm_spawnplayer", Command_SpawnPlayer, ADMFLAG_ROOT);
	
	Handle hConf = LoadGameConfigFile("tf2.pets");
	
	//SDKCalls
	//This call is used to get an entitys center position
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::WorldSpaceCenter");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if ((g_hSDKWorldSpaceCenter = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for CBaseEntity::WorldSpaceCenter offset!");
	
	//=========================================================
	// StudioFrameAdvance - advance the animation frame up some interval (default 0.1) into the future
	//=========================================================
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
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBot::GetVisionInterface");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hGetVisionInterface = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for INextBot::GetVisionInterface!");

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

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseAnimating::DispatchAnimEvents");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((g_hDispatchAnimEvents = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::DispatchAnimEvents offset!"); 
	
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
	
	//ILocomotion::IsStuck()
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::IsStuck");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if((g_hIsStuck = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::IsStuck!");
	
	//ILocomotion::ClearStuckStatus(char const* reason)
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::ClearStuckStatus");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if((g_hClearStuckStatus = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::ClearStuckStatus!");
	
	//ILocomotion::StuckMonitor
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::StuckMonitor");
	if((g_hStuckMonitor = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::StuckMonitor!");
	
	//CBaseEntity::GetVectors(Vector*, Vector*, Vector*) 
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::GetVectors");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if((g_hGetVectors = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for CBaseEntity::GetVectors!");

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
	
	//CBaseAnimatingOverlay::AddGestureSequence( int nSequence, bool autokill )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimatingOverlay::AddGestureSequence");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain); 
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hAddGestureSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimatingOverlay::AddGestureSequence");
	
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
	
	//DHooks
	g_hGetStepHeight       = DHookCreateEx(hConf, "ILocomotion::GetStepHeight",      HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetStepHeight);	
	g_hGetGravity          = DHookCreateEx(hConf, "ILocomotion::GetGravity",         HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetGravity);	
	g_hGetGroundNormal     = DHookCreateEx(hConf, "ILocomotion::GetGroundNormal",    HookType_Raw, ReturnType_VectorPtr, ThisPointer_Address, ILocomotion_GetGroundNormal);
	g_hGetMaxAcceleration  = DHookCreateEx(hConf, "ILocomotion::GetMaxAcceleration", HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetMaxAcceleration);
	g_hShouldCollideWith   = DHookCreateEx(hConf, "ILocomotion::ShouldCollideWith",  HookType_Raw, ReturnType_Bool,      ThisPointer_Address, ILocomotion_ShouldCollideWith);
	DHookAddParam(g_hShouldCollideWith, HookParamType_CBaseEntity);
	
	g_hGetSolidMask        = DHookCreateEx(hConf, "IBody::GetSolidMask",             HookType_Raw, ReturnType_Int,       ThisPointer_Address, IBody_GetSolidMask);
	
	delete hConf;
}

methodmap BaseNPC 
{
	public BaseNPC(float vecPos[3], float vecAng[3], const char[] model, const char[] modelscale = "1.0", const char[] health = "5000", bool bGroundNormal = true)
	{
		int npc = CreateEntityByName("base_boss");
		DispatchKeyValueVector(npc, "origin",     vecPos);
		DispatchKeyValueVector(npc, "angles",     vecAng);
		DispatchKeyValue(npc,       "model",      model);
		DispatchKeyValue(npc,       "modelscale", modelscale);
		DispatchKeyValue(npc,       "health",     health);
		DispatchSpawn(npc);
		
		//CreateParticle("ghost_appearation", vecPos, vecAng);
		
		Address pNB =         SDKCall(g_hMyNextBotPointer,        npc);
		Address pLocomotion = SDKCall(g_hGetLocomotionInterface,  pNB);
		
		DHookRaw(g_hGetStepHeight,       true, pLocomotion);
		DHookRaw(g_hGetGravity,          true, pLocomotion);
		DHookRaw(g_hShouldCollideWith,   true, pLocomotion);
		DHookRaw(g_hGetMaxAcceleration,  true, pLocomotion);
		
		if(bGroundNormal)
			DHookRaw(g_hGetGroundNormal, true, pLocomotion)
		
		Address pBody = SDKCall(g_hGetBodyInterface, pNB);
		
		//Collide with the correct stuff
		DHookRaw(g_hGetSolidMask,        true, pBody);
		
		//trigger_hurts hurt and spawn doors open for us, etc.
		SetEntityFlags(npc, FL_CLIENT|FL_FAKECLIENT|FL_NPC);
		
		//Don't ResolvePlayerCollisions.
		SetEntData(npc, FindSendPropInfo("CTFBaseBoss", "m_lastHealthPercentage") + 28, false, 4, true);	
		
		//Don't bleed.
		SetEntProp(npc, Prop_Data, "m_bloodColor", -1); 

		ActivateEntity(npc);
		
		return view_as<BaseNPC>(npc);
	}
	
	property int index
	{
		public get() 
		{ 
			return view_as<int>(this); 
		}
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
	public Address GetVisionInterface()
	{
		Address pNB = SDKCall(g_hMyNextBotPointer, this.index);
		return SDKCall(g_hGetVisionInterface, pNB);
	}	
	public bool IsStuck()
	{
		return SDKCall(g_hIsStuck, this.GetLocomotionInterface());
	}
	public int GetTeam()
	{
		return GetEntProp(this.index, Prop_Send, "m_iTeamNum");
	}
	public Address GetStudioHdr()
	{
		if(IsValidEntity(this.index))
		{
			return view_as<Address>(GetEntData(this.index, 283 * 4));
		}
		
		return Address_Null;
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
	public void PlayGesture(const char[] anim)
	{
		int iSequence = this.LookupSequence(anim);
		if(iSequence < 0)
			return;
		
		SDKCall(g_hAddGestureSequence, this.index, iSequence, true);
	}	
	public void CreatePather(int iTarget, float flStep, float flJump, float flDrop, int iSolid, float flAhead, float flRePath, float flHull)
	{
		PF_Create(this.index, flStep, flJump, flDrop, 0.6, iSolid, flAhead, flRePath, flHull);
		PF_EnableCallback(this.index, PFCB_Approach, PluginBot_Approach);
		PF_EnableCallback(this.index, PFCB_GetPathCost, PluginBot_PathCost);
		
		if(IsValidEntity(iTarget) && PF_IsEntityACombatCharacter(iTarget))
		{
			PF_SetGoalEntity(this.index, iTarget);
		}
	}	
	public void Approach(const float vecGoal[3])
	{
		SDKCall(g_hApproach, this.GetLocomotionInterface(), vecGoal, 0.1);
	}	
	public void FaceTowards(const float vecGoal[3])
	{
		//Sad!
		ConVar flTurnRate = FindConVar("tf_base_boss_max_turn_rate");
		float flPrevValue = flTurnRate.FloatValue;
		
		flTurnRate.FloatValue = 200.0;
		SDKCall(g_hFaceTowards, this.GetLocomotionInterface(), vecGoal);
		flTurnRate.FloatValue = flPrevValue;
	}	
	public void Jump()
	{
		SDKCall(g_hJump, this.GetLocomotionInterface());
	}	
	public void Update()
	{
		SDKCall(g_hRun,                this.GetLocomotionInterface());	
		SDKCall(g_hStudioFrameAdvance, this.index);
		SDKCall(g_hDispatchAnimEvents, this.index, this.index);
		SDKCall(g_hStuckMonitor,       this.GetLocomotionInterface());
		
		bool bStuck = this.IsStuck();
		if(bStuck)
		{
			float there[3];
			bool bYes = false;
			
			if (PF_GetFutureSegment(this.index, 1, there)) 
			{ 
				bYes = true; 
			}
			else if(PF_GetFutureSegment(this.index, 0, there)) 
			{ 
				bYes = true; 
			}
			
			if(bYes)
			{
				SDKCall(g_hClearStuckStatus, this.GetLocomotionInterface(), "Un-Stuck");
				there[2] += 18.0;
				TeleportEntity(this.index, there, NULL_VECTOR, NULL_VECTOR);
			}
			else
			{
				NavArea area = TheNavMesh.GetNearestNavArea_Vec(WorldSpaceCenter(this.index), true);
				if(area != NavArea_Null)
				{
					SDKCall(g_hClearStuckStatus, this.GetLocomotionInterface(), "Un-Stuck");
					float center[3];
					area.GetCenter(center);
					center[2] += 18.0;
					TeleportEntity(this.index, center, NULL_VECTOR, NULL_VECTOR);
				}
			}
		}
	}	
}

public Action Command_SpawnBall(int client, int argc)
{
	float vOrigin[3];
	GetClientAbsOrigin(client, vOrigin);

	int ball = CreateEntityByName("prop_soccer_ball");
	DispatchKeyValue(ball, "targetname", "NextBot_SoccerBall");
	DispatchKeyValue(ball, "model", "models/player/items/scout/soccer_ball.mdl");
	DispatchKeyValueVector(ball, "origin", vOrigin);	
	DispatchSpawn(ball);

	return Plugin_Handled;
}

public Action Command_SpawnPlayer(int client, int argc)
{
	float vOrigin[3];
	GetClientAbsOrigin(client, vOrigin);

	SpawnPlayer(vOrigin);

	return Plugin_Handled;
}


char s_cast[][] = 
{
	{"models/bots/skeleton_sniper/skeleton_sniper.mdl"},
	{"models/bots/skeleton_sniper_boss/skeleton_sniper_boss.mdl"},
	{"models/bots/engineer/bot_engineer.mdl"},
	{"models/player/demo.mdl"},
	{"models/player/engineer.mdl"},
	{"models/player/heavy.mdl"},
	{"models/player/medic.mdl"},
	{"models/player/pyro.mdl"},
	{"models/player/scout.mdl"},
	{"models/player/sniper.mdl"},
	{"models/player/soldier.mdl"},
	{"models/player/spy.mdl"}
}

stock void SpawnPlayer(float vOrigin[3])
{
	BaseNPC npc = BaseNPC(vOrigin, NULL_VECTOR, s_cast[GetRandomInt(0, sizeof(s_cast) - 1)], "0.6", "5000", true);
	
	AcceptEntityInput(npc.index, "DisableShadow");	
	
	SetEntityFlags(npc.index, FL_NOTARGET);
	
	SetEntProp(npc.index, Prop_Data, "m_takedamage", 0);
	SetEntProp(npc.index, Prop_Data, "m_lifeState",  1); 

	int skin = GetRandomInt(0, 1);
	SetEntProp(npc.index, Prop_Send, "m_nSkin", skin); 

	SetEntPropFloat(npc.index, Prop_Data, "m_speed", 300.0);
	
	npc.SetAnimation("run_LOSER");
	
	SDKHook(npc.index, SDKHook_Think, OnBotThink);
	SDKHook(npc.index, SDKHook_TouchPost, OnBotTouch);
}

const float g_flBallerCoolDownAmount = 0.1;

public void OnBotThink(int entity)
{
	BaseNPC iEntity = view_as<BaseNPC>(entity);

	Do9WayBlendAnimation(iEntity);
	iEntity.Update();

	int iBallClosest = INVALID_ENT_REFERENCE;
	float flClosestDistance = 99999999.0;
	
	int iBall = INVALID_ENT_REFERENCE;
	while ((iBall = FindEntityByClassname(iBall, "prop_soccer_ball")) != -1)
	{
		float flDistance = GetVectorDistance(WorldSpaceCenter(iBall), WorldSpaceCenter(iEntity.index), true);
		
		if(flDistance > flClosestDistance)
			continue;

		flClosestDistance = flDistance;
		iBallClosest = iBall;
	}
	
	if(iBallClosest == INVALID_ENT_REFERENCE)
		return;
	
	if(!PF_Exists(iEntity.index))
	{
		iEntity.CreatePather(-1, 18.0, 18.0, 1000.0, MASK_PLAYERSOLID, 100.0, g_flBallerCoolDownAmount, 1.0);
		PF_SetGoalVector(iEntity.index, WorldSpaceCenter(iBallClosest));
		PF_StartPathing(iEntity.index);
	}
	else
	{
		PF_SetGoalVector(iEntity.index, WorldSpaceCenter(iBallClosest));
	}
		
	//PrintToServer("flClosestDistance %f, iBallClosest %i", flClosestDistance, iBallClosest);
}

public void OnBotTouch(int entity, int ball)
{
	if(ball <= 0)
		return;
		
	if(!IsValidEntity(ball))
		return;
		
	char class[64]; GetEntityClassname(ball, class, sizeof(class));
	if(!StrEqual(class, "prop_soccer_ball"))
		return;

	BaseNPC iEntity = view_as<BaseNPC>(entity);
	
	float m_vecAbsVelocity[3]; 
	SDKCall(g_hGetGroundMotionVector, iEntity.GetLocomotionInterface(), m_vecAbsVelocity);
	
	ScaleVector(m_vecAbsVelocity, GetEntPropFloat(iEntity.index, Prop_Data, "m_flGroundSpeed"));
	
	m_vecAbsVelocity[2] = 0.0;
	
	//PrintToServer("%f %f %f", m_vecAbsVelocity[0], m_vecAbsVelocity[1], m_vecAbsVelocity[2]);
	
	float velocity_2d_dot = SquareRoot(GetVectorDotProduct(m_vecAbsVelocity, m_vecAbsVelocity));
	m_vecAbsVelocity[2] = 0.0;
	
	NormalizeVector(m_vecAbsVelocity, m_vecAbsVelocity);
	//VMX_VectorNormalize(m_vecAbsVelocity);
	
	float soccer_ball_up_max        = FindConVar("tf_soccer_ball_up_max").FloatValue;
	float halloween_kart_dash_speed = FindConVar("tf_halloween_kart_dash_speed").FloatValue;
	float soccer_ball_min_speed     = FindConVar("tf_soccer_ball_min_speed").FloatValue;
	float soccer_ball_multiplier    = FindConVar("tf_soccer_ball_multiplier").FloatValue;
	float soccer_front_hit_range    = FindConVar("tf_soccer_front_hit_range").FloatValue;
	
	float soccerball_up_amount = (velocity_2d_dot / halloween_kart_dash_speed) * soccer_ball_up_max;
	
	float up_multiplier = 5.0;
	
	if ( soccerball_up_amount >= 5.0 )
	{
		if ( soccerball_up_amount <= soccer_ball_up_max ) {
			up_multiplier = (velocity_2d_dot / halloween_kart_dash_speed) * soccer_ball_up_max;
		} else {
			up_multiplier = soccer_ball_up_max;
		}
	}
		
	//POSITION
	float ball_to_kicker[3];
	SubtractVectors(GetAbsOrigin(ball), GetAbsOrigin(iEntity.index), ball_to_kicker);
	ball_to_kicker[2] = 0.0;

	NormalizeVector(ball_to_kicker, ball_to_kicker);
	//VMX_VectorNormalize(ball_to_kicker);
	
	float kick_dot = GetVectorDotProduct(ball_to_kicker, m_vecAbsVelocity);
	
	if ( kick_dot < 0.1 )
		kick_dot = 0.1;
	
	float kick_speed_scaled = kick_dot * velocity_2d_dot;
	
	if ( (kick_dot * velocity_2d_dot) <= soccer_ball_min_speed )
		kick_speed_scaled = soccer_ball_min_speed;
		
	float final_multiplier = kick_speed_scaled * soccer_ball_multiplier;
	
	
	if ( kick_dot < soccer_front_hit_range )
	{
		m_vecAbsVelocity[0] = ball_to_kicker[0];
		m_vecAbsVelocity[1] = ball_to_kicker[1];
	}
	
	//v17 = *(_DWORD *)(ball + 500);
	
	float final_vel[3];
	final_vel[0] = m_vecAbsVelocity[0] * final_multiplier;
	final_vel[1] = m_vecAbsVelocity[1] * final_multiplier;
	final_vel[2] = up_multiplier * soccer_ball_multiplier;
	
	//PrintToServer("%f %f %f", final_vel[0], final_vel[1], final_vel[2]);
	
	TeleportEntity(ball, NULL_VECTOR, NULL_VECTOR, final_vel);
}

stock void Do9WayBlendAnimation(BaseNPC iEntity)
{
	Address pLocomotion = iEntity.GetLocomotionInterface();
	if(pLocomotion == Address_Null)
		return;
	
	int m_iMoveX = iEntity.LookupPoseParameter("move_x");
	int m_iMoveY = iEntity.LookupPoseParameter("move_y");
	
	if ( m_iMoveX < 0 || m_iMoveY < 0 )
		return;
	
	float flGroundSpeed = SDKCall(g_hGetGroundSpeed, pLocomotion);
	if ( flGroundSpeed != 0.0 )
	{
		float vecForward[3], vecRight[3], vecUp[3];
		SDKCall(g_hGetVectors, iEntity, vecForward, vecRight, vecUp);
		
		float vecMotion[3]
		SDKCall(g_hGetGroundMotionVector, pLocomotion, vecMotion);
		
		iEntity.SetPoseParameter(m_iMoveX, GetVectorDotProduct(vecMotion, vecForward));
		iEntity.SetPoseParameter(m_iMoveY, GetVectorDotProduct(vecMotion, vecRight));
	}
	
	float m_flGroundSpeed = GetEntPropFloat(iEntity.index, Prop_Data, "m_flGroundSpeed");
	if(m_flGroundSpeed != 0.0)
	{
		float flReturnValue = clamp(flGroundSpeed / m_flGroundSpeed, -4.0, 12.0);
		
		SetEntPropFloat(iEntity.index, Prop_Send, "m_flPlaybackRate", flReturnValue);
	}
}


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
	
	/* very similar to CTFBot::TransientlyConsistentRandomValue */
	int seed = RoundToFloor(GetGameTime() * 0.1) + 1;
	seed *= area.GetID();
	seed *= bot_entidx;
	
	/* huge random cost modifier [0, 100] for non-giant bots! */
	multiplier += (Cosine(float(seed)) + 1.0) * 50.0;
	
	float cost = dist * multiplier;
	
	return from_area.GetCostSoFar() + cost;
}

stock float[] GetAbsOrigin(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", v);
	return v;
}

stock float[] WorldSpaceCenter(int entity)
{
	float vecPos[3];
	SDKCall(g_hSDKWorldSpaceCenter, entity, vecPos);
	
	return vecPos;
}

public float clamp(float a, float b, float c) { return (a > c ? c : (a < b ? b : a)); }

public MRESReturn IBody_GetSolidMask(Address pThis, Handle hReturn, Handle hParams)             { DHookSetReturn(hReturn, MASK_PLAYERSOLID);                          return MRES_Supercede; }
public MRESReturn ILocomotion_GetGravity(Address pThis, Handle hReturn, Handle hParams)         { DHookSetReturn(hReturn, 800.0);                                     return MRES_Supercede; }
public MRESReturn ILocomotion_GetStepHeight(Address pThis, Handle hReturn, Handle hParams)      { DHookSetReturn(hReturn, 20.0);                                      return MRES_Supercede; }
public MRESReturn ILocomotion_GetMaxAcceleration(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturn(hReturn, 1700.0);                                    return MRES_Supercede; }
public MRESReturn ILocomotion_GetGroundNormal(Address pThis, Handle hReturn, Handle hParams)    { DHookSetReturnVector(hReturn, view_as<float>( { 0.0, 0.0, 1.0 } )); return MRES_Supercede; }
public MRESReturn ILocomotion_ShouldCollideWith(Address pThis, Handle hReturn, Handle hParams)  { DHookSetReturn(hReturn, false);                                     return MRES_Supercede; }

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
