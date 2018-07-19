//Thanks to sigsegv for his reversing work

#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <PathFollower>
#include <PathFollower_Nav>
#include <customkeyvalues>
#include <dhooks>

#pragma newdecls required;

#define RAD2DEG(%1) ((%1) * (180.0 / FLOAT_PI))
#define DEG2RAD(%1) ((%1) * FLOAT_PI / 180.0)

#define EF_BONEMERGE                (1 << 0)
#define EF_PARENT_ANIMATES          (1 << 9)

#define TF_WEAPON_PRIMARY_MODE		0
#define TF_WEAPON_SECONDARY_MODE	1

//SDKCalls
Handle g_hMyNextBotPointer;
Handle g_hGetLocomotionInterface;
Handle g_hGetBodyInterface;
Handle g_hGetVisionInterface;
Handle g_hGetPrimaryKnownThreat;
Handle g_hAddKnownEntity;
Handle g_hGetKnownEntity;
Handle g_hGetKnown;
Handle g_hUpdatePosition;
Handle g_hUpdateVisibilityStatus;
Handle g_hRun;
Handle g_hApproach;
Handle g_hFaceTowards
Handle g_hGetVelocity;
Handle g_hSetVelocity;
Handle g_hStudioFrameAdvance;
Handle g_hJump;
Handle g_hJumpAcrossGap;
Handle g_hDispatchAnimEvents;
Handle g_hGetMaxAcceleration;
Handle g_hGetGroundSpeed;
Handle g_hGetVectors;
Handle g_hGetGroundMotionVector;
Handle g_hLookupPoseParameter;
Handle g_hSetPoseParameter;
Handle g_hGetPoseParameter;
Handle g_hLookupActivity;
Handle g_hSDKWorldSpaceCenter;
Handle g_hStudio_FindAttachment;
Handle g_hGetAttachment;
Handle g_hAddGesture;
Handle g_hIsPlayingGesture;
Handle g_hFindBodygroupByName;
Handle g_hSetBodyGroup;
Handle g_hSelectWeightedSequence;
Handle g_hResetSequenceInfo;

//Stuck detection
Handle g_hStuckMonitor;
Handle g_hClearStuckStatus;
Handle g_hIsStuck;

//PluginBot SDKCalls
Handle g_hGetEntity;
Handle g_hGetBot;

//DHooks
Handle g_hGetCurrencyValue;
Handle g_hHandleAnimEvent;
Handle g_hGetFrictionSideways;
Handle g_hGetStepHeight;
Handle g_hGetGravity;
Handle g_hGetRunSpeed;
Handle g_hGetGroundNormal;
Handle g_hShouldCollideWith;
Handle g_hGetSolidMask;
Handle g_hStartActivity;
Handle g_hGetActivity;
Handle g_hIsActivity;

//NavAreas
Address TheNavAreas;
Address navarea_count;

public Plugin myinfo = 
{
	name = "[TF2] KF2 Clot NPC", 
	author = "Pelipoika", 
	description = "", 
	version = "1.0", 
	url = ""
};


//#define DEBUG_UPDATE
//#define DEBUG_ANIMATION

methodmap CKnownEntity
{
	// convert to address
	property Address Address {
		public get() { return view_as<Address>(this); } 
	}

	// return the entity index of the known entity
	public int GetEntity() {
		return SDKCall(g_hGetKnownEntity, this);
	}
	
	// could be seen or heard, but now the entity's position is known
	public void UpdatePosition() {
		SDKCall(g_hUpdatePosition, this);
	}
	
	// update target visibility status.
	public void UpdateVisibilityStatus(bool visible) {
		SDKCall(g_hUpdateVisibilityStatus, this, visible);
	}
}

methodmap CVision < CKnownEntity
{
	// return the biggest threat to ourselves that we are aware of
	public CKnownEntity GetPrimaryKnownThreat(bool onlyVisibleThreats = false) {
		return SDKCall(g_hGetPrimaryKnownThreat, this, onlyVisibleThreats);
	}
	
	// given an entity, return our known version of it (or NULL if we don't know of it)
	public CKnownEntity GetKnown(int entity) {
		return SDKCall(g_hGetKnown, this, entity);
	}
	
	// Introduce a known entity into the system. Its position is assumed to be known
	// and will be updated, and it is assumed to not yet have been seen by us, allowing for learning
	// of known entities by being told about them, hearing them, etc.
	public void AddKnownEntity(int entity) {
		SDKCall(g_hAddKnownEntity, this, entity);
	}
}


methodmap CBaseActor < CVision
{
	public CBaseActor(float vecPos[3], float vecAng[3], const char[] model, const char[] modelscale = "1.0", const char[] health = "100", bool bGroundNormal = true)
	{
		int npc = CreateEntityByName("base_boss");
		DispatchKeyValueVector(npc, "origin",     vecPos);
		DispatchKeyValueVector(npc, "angles",     vecAng);
		DispatchKeyValue(npc,       "model",      model);
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
		DHookRaw(g_hGetRunSpeed,         true, pLocomotion);
		
		if(bGroundNormal)
			DHookRaw(g_hGetGroundNormal, true, pLocomotion)
		
		Address pBody = SDKCall(g_hGetBodyInterface, pNB);
		
		
		DHookRaw(g_hGetActivity,         true, pBody);
		DHookRaw(g_hIsActivity,          true, pBody);

		//Collide with the correct stuff
		DHookRaw(g_hGetSolidMask,        true, pBody);
		
		//Allow jumping
		DHookRaw(g_hStartActivity,       true, pBody);
		
		//Don't drop money.
		DHookEntity(g_hGetCurrencyValue, true, npc);
		
		//Animevents 
		DHookEntity(g_hHandleAnimEvent,  true, npc);
		
		//trigger_hurts hurt and spawn doors open for us, etc.
		SetEntityFlags(npc, FL_CLIENT|FL_FAKECLIENT|FL_NPC);
		
		//Don't ResolvePlayerCollisions.
		SetEntData(npc, FindSendPropInfo("CTFBaseBoss", "m_lastHealthPercentage") + 28, false, 4, true);	
		
		//Don't bleed.
		//SetEntProp(npc, Prop_Data, "m_bloodColor", -1); 
		
		//Fix collisions
		SetEntPropVector(npc, Prop_Send, "m_vecMaxs", view_as<float>( { 26.0, 26.0, 82.0 } ));
		SetEntPropVector(npc, Prop_Data, "m_vecMaxs", view_as<float>( { 26.0, 26.0, 82.0 } ));
		
		SetEntPropVector(npc, Prop_Send, "m_vecMins", view_as<float>( { -26.0, -26.0, 0.0 } ));
		SetEntPropVector(npc, Prop_Data, "m_vecMins", view_as<float>( { -26.0, -26.0, 0.0 } ));
		
		return view_as<CBaseActor>(npc);
	}
	
	property int index 
	{ 
		public get() { return view_as<int>(this); } 
	}

	public int ExtractStringValueAsInt(const char[] key)
	{
		char buffer[64]; 
		bool bExists = GetCustomKeyValue(this.index, key, buffer, sizeof(buffer)); 
		if(!bExists)
			return -1;
		
		return StringToInt(buffer);
	}
	
	public float ExtractStringValueAsFloat(const char[] key)
	{
		char buffer[64]; 
		bool bExists = GetCustomKeyValue(this.index, key, buffer, sizeof(buffer)); 
		if(!bExists)
			return -1.0;
		
		return StringToFloat(buffer);
	}
	
	property bool m_bPathing
	{
		public get()            { return !!this.ExtractStringValueAsInt("m_bPathing"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_bPathing", buff, true); }
	}
	
	property bool m_bJumping
	{
		public get()            { return !!this.ExtractStringValueAsInt("m_bJumping"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_bJumping", buff, true); }
	}
	
	property bool m_bInAirWalk
	{
		public get()            { return !!this.ExtractStringValueAsInt("m_bInAirWalk"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_bInAirWalk", buff, true); }
	}
	
	property float m_flJumpStartTime
	{
		public get()                 { return this.ExtractStringValueAsFloat("m_flJumpStartTime"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flJumpStartTime", buff, true); }
	}
	
	public Address GetLocomotionInterface() { return SDKCall(g_hGetLocomotionInterface, SDKCall(g_hMyNextBotPointer, this.index)); }
	public Address GetBodyInterface()       { return SDKCall(g_hGetBodyInterface,       SDKCall(g_hMyNextBotPointer, this.index)); }
	public CVision GetVisionInterface()     { return SDKCall(g_hGetVisionInterface,     SDKCall(g_hMyNextBotPointer, this.index)); }	
	
	public bool IsStuck() { return SDKCall(g_hIsStuck, this.GetLocomotionInterface()); }
	public int GetTeam()  { return GetEntProp(this.index, Prop_Send, "m_iTeamNum"); }
	
	public Address GetModelPtr()
	{
		if(IsValidEntity(this.index)) {
			return view_as<Address>(GetEntData(this.index, 283 * 4));
		}
		
		return Address_Null;
	}	
	public void SetPoseParameter(int iParameter, float value)
	{
		Address pStudioHdr = this.GetModelPtr();
		if(pStudioHdr == Address_Null)
			return;
			
		SDKCall(g_hSetPoseParameter, this.index, pStudioHdr, iParameter, value);
	}	
	public int FindAttachment(const char[] pAttachmentName)
	{
		Address pStudioHdr = this.GetModelPtr();
		if(pStudioHdr == Address_Null)
			return -1;
			
		return SDKCall(g_hStudio_FindAttachment, pStudioHdr, pAttachmentName) + 1;
	}	
	public int LookupPoseParameter(const char[] szName)
	{
		Address pStudioHdr = this.GetModelPtr();
		if(pStudioHdr == Address_Null)
			return -1;
			
		return SDKCall(g_hLookupPoseParameter, this.index, pStudioHdr, szName);
	}	
	public int LookupActivity(const char[] activity)
	{
		Address pStudioHdr = this.GetModelPtr();
		if(pStudioHdr == Address_Null)
			return -1;
			
		return SDKCall(g_hLookupActivity, pStudioHdr, activity);
	}
	public void AddGesture(const char[] anim)
	{
		int iSequence = this.LookupActivity(anim);
		if(iSequence < 0)
			return;
		
		SDKCall(g_hAddGesture, this.index, iSequence, true);
	}
	public bool IsPlayingGesture(const char[] anim)
	{
		int iSequence = this.LookupActivity(anim);
		if(iSequence < 0)
			return;
		
		SDKCall(g_hIsPlayingGesture, this.index, iSequence);
	}
	public void CreatePather(float flStep, float flJump, float flDrop, int iSolid, float flAhead, float flRePath, float flHull)
	{
		PF_Create(this.index, flStep, flJump, flDrop, 0.6, iSolid, flAhead, flRePath, flHull);
		PF_EnableCallback(this.index, PFCB_Approach,        PluginBot_Approach);
		//PF_EnableCallback(this.index, PFCB_GetPathCost,     PluginBot_PathCost);
		PF_EnableCallback(this.index, PFCB_ClimbUpToLedge,  PluginBot_Jump);
		PF_EnableCallback(this.index, PFCB_OnMoveToSuccess, PluginBot_MoveToSuccess);
		PF_EnableCallback(this.index, PFCB_PathFailed,      PluginBot_MoveToFailure);
		PF_EnableCallback(this.index, PFCB_OnMoveToFailure, PluginBot_MoveToFailure);
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
	
	public void Update()
	{
		#if defined DEBUG_UPDATE
		PrintToServer("CBaseActor::Update()");
		#endif
	
		SDKCall(g_hRun,          this.GetLocomotionInterface());	
		SDKCall(g_hStuckMonitor, this.GetLocomotionInterface());
		
		bool bStuck = this.IsStuck();
		if(bStuck)
		{
			float there[3];
			bool bYes = false;
			
			for (int i = 2; i > 0; i--)
			{
				if (PF_GetFutureSegment(this.index, i, there)) 
				{
					bYes = true; 
					break;
				}
			}
			
			if(bYes) {
				there[2] += 18.0;
				TeleportEntity(this.index, there, NULL_VECTOR, NULL_VECTOR);
			} else {
				NavArea area = TheNavMesh.GetNearestNavArea_Vec(WorldSpaceCenter(this.index), true);
				if(area == NavArea_Null)
					return;
			
				float center[3]; area.GetCenter(center); center[2] += 18.0;
				TeleportEntity(this.index, center, NULL_VECTOR, NULL_VECTOR);
			}
			
			SDKCall(g_hClearStuckStatus, this.GetLocomotionInterface(), "Un-Stuck");
		}
	}	
		
	public float GetGroundSpeed()                                    { return SDKCall(g_hGetGroundSpeed, this.GetLocomotionInterface()); }
	public float GetPoseParameter(int iParameter)                    { return SDKCall(g_hGetPoseParameter, this.index, iParameter);                                       }
	public int FindBodygroupByName(const char[] name)                { return SDKCall(g_hFindBodygroupByName, this.index, name);                                          }
	public int SelectWeightedSequence(int activity, int curSequence) { return SDKCall(g_hSelectWeightedSequence, this.index, this.GetModelPtr(), activity, curSequence); }
	
	public void GetAttachment(const char[] szName, float absOrigin[3], float absAngles[3]) { SDKCall(g_hGetAttachment, this.index, this.FindAttachment(szName), absOrigin, absAngles); }
	public void SetBodygroup(int iGroup, int iValue)                                       { SDKCall(g_hSetBodyGroup, this.index, iGroup, iValue);                                     }
	public void Approach(const float vecGoal[3])                                           { SDKCall(g_hApproach, this.GetLocomotionInterface(), vecGoal, 0.1);                        }
	public void Jump()                                                                     { SDKCall(g_hJump, this.GetLocomotionInterface());                                          }
	public void JumpAcrossGap(const float landingGoal[3], const float landingForward[3])   { SDKCall(g_hJumpAcrossGap, this.GetLocomotionInterface(), landingGoal, landingForward);    }
	public void GetVelocity(float vecOut[3])                                               { SDKCall(g_hGetVelocity, this.GetLocomotionInterface(), vecOut);                           }	
	public void SetVelocity(const float vec[3])                                            { SDKCall(g_hSetVelocity, this.GetLocomotionInterface(), vec);                              }	
	
	public void SetSequence(int iSequence)    { SetEntProp(this.index, Prop_Send, "m_nSequence", iSequence); }
	public void SetPlaybackRate(float flRate) { SetEntPropFloat(this.index, Prop_Send, "m_flPlaybackRate", flRate); }
	public void SetCycle(float flCycle)       { SetEntPropFloat(this.index, Prop_Send, "m_flCycle", flCycle); }
	
	public void GetVectors(float pForward[3], float pRight[3], float pUp[3]) { SDKCall(g_hGetVectors, this.index, pForward, pRight, pUp); }
	public void GetGroundMotionVector(float vecMotion[3])                    { SDKCall(g_hGetGroundMotionVector, this.GetLocomotionInterface(), vecMotion); }
	
	public void ResetSequenceInfo()  { SDKCall(g_hResetSequenceInfo,  this.index); }
	public void StudioFrameAdvance() { SDKCall(g_hStudioFrameAdvance, this.index); }
	public void DispatchAnimEvents() { SDKCall(g_hDispatchAnimEvents, this.index, this.index); }
}


methodmap CClotBody < CBaseActor
{	
	property int m_iActivity
	{
		public get()              { return this.ExtractStringValueAsInt("m_iActivity"); }
		public set(int iActivity) { char buff[8]; IntToString(iActivity, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iActivity", buff, true); }
	}
	
	property int m_iPoseMoveX 
	{
		public get()              { return this.ExtractStringValueAsInt("m_iPoseMoveX"); }
		public set(int iActivity) { char buff[8]; IntToString(iActivity, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iPoseMoveX", buff, true); }
	}
	
	property int m_iPoseMoveY
	{
		public get()              { return this.ExtractStringValueAsInt("m_iPoseMoveY"); }
		public set(int iActivity) { char buff[8]; IntToString(iActivity, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iPoseMoveY", buff, true); }
	}

	property float m_flNextMeleeAttack
	{
		public get()                 { return this.ExtractStringValueAsFloat("m_flNextMeleeAttack"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flNextMeleeAttack", buff, true); }
	}
	
	property bool m_bAttacking
	{
		public get()                { return !!this.ExtractStringValueAsInt("m_bAttacking"); }
		public set(bool flNextTime) { char buff[8]; IntToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_bAttacking", buff, true); }
	}

	//Begin an animation activity, return false if we cant do that right now.
	public bool StartActivity(int iActivity, int flags = 0)
	{
		#if defined DEBUG_ANIMATION
		PrintToServer("CClotBody::StartActivity(%i, %i)", iActivity, flags);
		#endif
		
		//Translate jump anim
		if(iActivity == 29)
			iActivity = this.LookupActivity("ACT_MP_JUMP_START_MELEE");
		
		int nSequence = this.SelectWeightedSequence(iActivity, GetEntProp(this.index, Prop_Send, "m_nSequence"));
		if (nSequence == 0) 
			return false;
		
		this.m_iActivity = iActivity;
		
		this.SetSequence(nSequence);
		this.SetPlaybackRate(1.0);
		this.SetCycle(0.0);
		
		this.ResetSequenceInfo();
		
		return true;
	}

	public void Update()
	{
		#if defined DEBUG_UPDATE
		PrintToServer("CClotBody::Update()");
		#endif
		
		if (this.m_iPoseMoveX < 0) {
			this.m_iPoseMoveX = this.LookupPoseParameter("move_x");
		}
		if (this.m_iPoseMoveY < 0) {
			this.m_iPoseMoveY = this.LookupPoseParameter("move_y");
		}
		
		float flNextBotGroundSpeed = this.GetGroundSpeed();
		
		if (flNextBotGroundSpeed < 0.01) {
			if (this.m_iPoseMoveX >= 0) {
				this.SetPoseParameter(this.m_iPoseMoveX, 0.0);
			}
			if (this.m_iPoseMoveY >= 0) {
				this.SetPoseParameter(this.m_iPoseMoveY, 0.0);
			}
		} else {
			float vecFwd[3], vecRight[3], vecUp[3];
			this.GetVectors(vecFwd, vecRight, vecUp);
			
			float vecMotion[3]; this.GetGroundMotionVector(vecMotion);
			
			if (this.m_iPoseMoveX >= 0) {
				this.SetPoseParameter(this.m_iPoseMoveX, GetVectorDotProduct(vecMotion, vecFwd));
			}
			if (this.m_iPoseMoveY >= 0) {
				this.SetPoseParameter(this.m_iPoseMoveY, GetVectorDotProduct(vecMotion, vecRight));
			}
		}
		
		float m_flGroundSpeed = GetEntPropFloat(this.index, Prop_Data, "m_flGroundSpeed");
		if (m_flGroundSpeed != 0.0) {
			this.SetPlaybackRate(clamp((flNextBotGroundSpeed / m_flGroundSpeed), -4.0, 12.0));
		}
		
		this.StudioFrameAdvance();
		this.DispatchAnimEvents();
		
		//Run and StuckMonitor
		this.Update();
	}
	
	//return currently animating activity
	public int GetActivity()
	{
		#if defined DEBUG_ANIMATION
		PrintToServer("CClotBody::GetActivity()");
		#endif
	
		return this.m_iActivity;
	}
	
	//return true if currently animating activity matches the given one
	public bool IsActivity(int iActivity)
	{
		#if defined DEBUG_ANIMATION
		PrintToServer("CClotBody::IsActivity(%i)", iActivity);
		#endif
	
		return (iActivity == this.m_iActivity);
	}
	
	//return the bot's collision mask
	public int GetSolidMask()
	{
		return (MASK_NPCSOLID|MASK_PLAYERSOLID);
	}
	
	public void RestartMainSequence()
	{
		#if defined DEBUG_ANIMATION
		PrintToServer("CClotBody::RestartMainSequence()");
		#endif
	
		SetEntPropFloat(this.index, Prop_Data, "m_flAnimTime", GetGameTime());
		
		this.SetCycle(0.0);
	}
}

methodmap Clot < CClotBody
{
	property float m_flNextTargetTime
	{
		public get()                 { return this.ExtractStringValueAsFloat("m_flNextTargetTime"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flNextTargetTime", buff, true); }
	}
	
	public float GetRunSpeed() { return 300.0; }
	
	public Clot(int client, float vecPos[3], float vecAng[3], const char[] model, int team)
	{
		Clot npc = view_as<Clot>(CBaseActor(vecPos, vecAng, model, "1.0"));
		
		int iActivity = npc.LookupActivity("ACT_MP_RUN_MELEE");
		if(iActivity > 0)
			npc.StartActivity(iActivity);
		
		npc.CreatePather(18.0, 64.0, 1000.0, npc.GetSolidMask(), 300.0, 0.25, 1.0);
		npc.m_flNextTargetTime = GetGameTime() + GetRandomFloat(1.0, 4.0);
		
		SDKHook(npc.index, SDKHook_Think, ClotThink);
		SDKHook(npc.index, SDKHook_TraceAttack, ClotDamaged);
		
		return npc;
	}
	
	public bool DoSwingTrace(Handle &trace)
	{
		// Setup a volume for the melee weapon to be swung - approx size, so all melee behave the same.
		static float vecSwingMins[3]; vecSwingMins = view_as<float>({-18, -18, -18});
		static float vecSwingMaxs[3]; vecSwingMaxs = view_as<float>({18, 18, 18});
	
		// Setup the swing range.
		float vecForward[3], vecRight[3], vecUp[3];
		this.GetVectors(vecForward, vecRight, vecUp);
		
		float vecSwingStart[3]; vecSwingStart = WorldSpaceCenter(this.index);
		
		float vecSwingEnd[3];
		vecSwingEnd[0] = vecSwingStart[0] + vecForward[0] * 75;
		vecSwingEnd[1] = vecSwingStart[1] + vecForward[1] * 75;
		vecSwingEnd[2] = vecSwingStart[2] + vecForward[2] * 75;
		
		// See if we hit anything.
		trace = TR_TraceRayFilterEx( vecSwingStart, vecSwingEnd, MASK_SOLID, RayType_EndPoint, FilterData, this.index );
		if ( TR_GetFraction(trace) >= 1.0 )
		{
			delete trace;
			trace = TR_TraceHullFilterEx( vecSwingStart, vecSwingEnd, vecSwingMins, vecSwingMaxs, MASK_SOLID, FilterData, this.index );
			if ( TR_GetFraction(trace) < 1.0 )
			{
				// This is the point on the actual surface (the hull could have hit space)
				TR_GetEndPosition(vecSwingEnd, trace);	
			}
		}
	
		return ( TR_GetFraction(trace) < 1.0 );
	}
}

public void ClotThink(int iNPC)
{
	Clot npc = view_as<Clot>(iNPC);
	npc.Update();
		
	CKnownEntity PrimaryThreat = npc.GetVisionInterface().GetPrimaryKnownThreat();

	if(PrimaryThreat.Address != Address_Null)
	{
		int PrimaryThreatIndex = PrimaryThreat.GetEntity();	
		PF_SetGoalEntity(npc.index, PrimaryThreatIndex);
	
		float vecTarget[3]; vecTarget = WorldSpaceCenter(PrimaryThreatIndex);
		
		float flDistanceToTarget = GetVectorDistance(vecTarget, WorldSpaceCenter(npc.index));
		
	/*	if(flDistanceToTarget < 1000.0)
		{
			PF_DisableCallback(npc.index, PFCB_GetPathCost);
		}
		else
		{
			PF_EnableCallback(npc.index, PFCB_GetPathCost, PluginBot_PathCost);
		}
		*/
		if(flDistanceToTarget < 75.0)
		{
			npc.FaceTowards(vecTarget);
			
			if(npc.m_flNextMeleeAttack < GetGameTime()) 
			{
				npc.AddGesture("ACT_MP_ATTACK_Stand_MELEE_var1");
				
				Handle swingTrace;
				if(npc.DoSwingTrace(swingTrace)) 
				{
					int target = TR_GetEntityIndex(swingTrace);		
					if(IsValidEntity(target)) {
						SDKHooks_TakeDamage(target, npc.index, npc.index, 5.0, DMG_SLASH);
					}
				}
				
				delete swingTrace;
				
				npc.m_flNextMeleeAttack = GetGameTime() + 0.5;
			}
			
			PF_StopPathing(npc.index);
			npc.m_bPathing = false;
		}
		else
		{
			PF_StartPathing(npc.index);
			npc.m_bPathing = true;
		}
	}
	
	//Is it time to pick a new place to go?
/*	if(npc.m_flNextTargetTime < GetGameTime())
	{
		//Pick a random goal area
		NavArea RandomArea = PickRandomArea();	
		
		if(RandomArea == NavArea_Null) 
			return;
		
		float vecGoal[3]; RandomArea.GetCenter(vecGoal);
		
		if(!PF_IsPathToVectorPossible(iNPC, vecGoal))
			return;
		
		if(PrimaryKnownThreat.Address != Address_Null)
		{
			PF_SetGoalEntity(iNPC, PrimaryKnownThreat.GetEntity());
			
			PrintToServer("CHASE TARGET");
		}
		else
		{
			PF_SetGoalVector(iNPC, vecGoal);
			
			PrintToServer("RANDOM PLACE");
		}
		
		PF_StartPathing(iNPC);
		npc.m_bPathing = true;
		npc.m_flNextTargetTime = GetGameTime() + 1000.0;
	}*/
	
	/*
	bool bAttacking = npc.IsPlayingGesture("ACT_MP_ATTACK_Stand_MELEE_var1");
	
	if(npc.m_flNextMeleeAttack < GetGameTime())
	{
		if(!bAttacking)
			npc.AddGesture("ACT_MP_ATTACK_Stand_MELEE_var1");
		
		PrintToServer("PLAY ATTACK");
		
		npc.m_flNextMeleeAttack = GetGameTime() + 2.0;
		npc.m_bPathing = false;
		
		PF_StopPathing(iNPC);
	}
	*/
	
	//v Handle jumping and running v
	int idealActivity = -1;
	
	if(!npc.m_bJumping)
	{
		if(npc.m_bPathing) {
			idealActivity = npc.LookupActivity("ACT_MP_RUN_MELEE");
		} else {
			idealActivity = npc.LookupActivity("ACT_MP_STAND_MELEE");
		}
	}
	
	float vecVelocity[3];
	npc.GetVelocity(vecVelocity);
	
	// Handle air walking before handling jumping - air walking supersedes jump
	if(vecVelocity[2] > 300.0 || npc.m_bInAirWalk)
	{
		// Check to see if we were in an airwalk and now we are basically on the ground.
		if(GetEntityFlags(iNPC) & FL_ONGROUND && npc.m_bInAirWalk)
		{
			npc.RestartMainSequence();
			npc.m_bInAirWalk = false;
			
			npc.AddGesture("ACT_MP_JUMP_LAND_melee");
		}
		else if ((GetEntityFlags(iNPC) & FL_ONGROUND) == 0)
		{
			// In an air walk.
			idealActivity = npc.LookupActivity("ACT_MP_AIRWALK_MELEE");
			npc.m_bInAirWalk = true;
		}
	}
	//Jumping
	else
	{
		if(npc.m_bJumping)
		{
			// Don't check if he's on the ground for a sec.. sometimes the client still has the
			// on-ground flag set right when the message comes in.
			if ( GetGameTime() - npc.m_flJumpStartTime > 0.2 )
			{
				if ( GetEntityFlags(iNPC) & FL_ONGROUND )
				{
					npc.m_bJumping = false;
					npc.RestartMainSequence();
				}
			}
		
			// if we're still jumping
			if ( npc.m_bJumping )
			{
				if ( GetGameTime() - npc.m_flJumpStartTime > 0.3 ) {
					idealActivity = npc.LookupActivity("ACT_MP_JUMP_FLOAT_melee");
				} else {
					idealActivity = npc.LookupActivity("ACT_MP_JUMP_START_melee");
				}
			}
		}
	}
	
	if(idealActivity != -1)
	{
		if(npc.m_iActivity != idealActivity) {
			npc.StartActivity(idealActivity);
		}
	}
}


public float clamp(float a, float b, float c) { return (a > c ? c : (a < b ? b : a)); }

public Action Command_PetMenu(int client, int argc)
{
	//What are you.
	if(!(client > 0 && client <= MaxClients && IsClientInGame(client)))
		return Plugin_Handled;
	
	float flPos[3], flAng[3];
	GetClientAbsOrigin(client, flPos);
	GetClientAbsAngles(client, flAng);
	
	char arg1[16];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	Clot(client, flPos, flAng, "models/vince_sf_proxy/zed_clot/zed_clot_01.mdl", StringToInt(arg1));
	
	return Plugin_Handled;
}

public void OnPluginStart()
{
	RegAdminCmd("sm_clot", Command_PetMenu, ADMFLAG_ROOT);
	
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

	//CBaseAnimating::ResetSequenceInfo( );
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::ResetSequenceInfo");
	if ((g_hResetSequenceInfo = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::ResetSequenceInfo signature!"); 

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
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "IVision::GetPrimaryKnownThreat");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hGetPrimaryKnownThreat = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for IVision::GetPrimaryKnownThreat!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "IVision::GetKnown");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);	//CBaseEntity - Entity to check for
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//CKnownEntity
	if((g_hGetKnown = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for IVision::GetKnown!");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "IVision::AddKnownEntity");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if((g_hAddKnownEntity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for IVision::AddKnownEntity!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CKnownEntity::GetEntity");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	if((g_hGetKnownEntity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for CKnownEntity::GetEntity!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CKnownEntity::UpdatePosition");
	if((g_hUpdatePosition = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for CKnownEntity::UpdatePosition!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CKnownEntity::UpdateVisibilityStatus");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);	//bool visible now
	if((g_hUpdateVisibilityStatus = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for CKnownEntity::UpdateVisibilityStatus!");

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
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::JumpAcrossGap");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	if((g_hJumpAcrossGap = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::JumpAcrossGap!");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::GetVelocity");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if((g_hGetVelocity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::GetVelocity!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::SetVelocity");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	if((g_hSetVelocity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::SetVelocity!");
	
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
	
	//CBaseAnimating::FindBodygroupByName(const char* name)
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::FindBodygroupByName");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hFindBodygroupByName = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimating::FindBodygroupByName");
	
	//CBaseAnimating::SetBodygroup( int iGroup, int iValue )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::SetBodygroup");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hSetBodyGroup = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimating::SetBodygroup");
	
	//int SelectWeightedSequence( CStudioHdr *pstudiohdr, int activity, int curSequence );
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "SelectWeightedSequence");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//pstudiohdr
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//activity
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//curSequence
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//return sequence
	if((g_hSelectWeightedSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for SelectWeightedSequence");
	
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
	
	//CBaseAnimatingOverlay::AddGesture( Activity activity, bool autokill )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimatingOverlay::AddGesture");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain); 
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hAddGesture = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimatingOverlay::AddGesture");
	
	//CBaseAnimatingOverlay::IsPlayingGesture( Activity activity )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimatingOverlay::IsPlayingGesture");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if((g_hIsPlayingGesture = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimatingOverlay::IsPlayingGesture");
	
	
	//-----------------------------------------------------------------------------
	
	//-----------------------------------------------------------------------------
	// Purpose: Looks up an activity by name.
	// Input  : label - Name of the activity to look up, ie "ACT_IDLE"
	// Output : Activity index or ACT_INVALID if not found.
	//-----------------------------------------------------------------------------
	//int LookupActivity( CStudioHdr *pstudiohdr, const char *label )
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "LookupActivity");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//pStudioHdr
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//label
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//return index
	if((g_hLookupActivity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for LookupActivity");
	
	
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
	
	//PluginBot SDKCalls
	//Get NextBot pointer
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBotComponent::GetBot");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hGetBot = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for INextBotComponent::GetBot!");
	
	//Get NextBot entity index
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBotComponent::GetEntity");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	if((g_hGetEntity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for INextBotComponent::GetEntity!");
	
	
	//DHooks
	g_hHandleAnimEvent = DHookCreateEx(hConf, "CBaseAnimating::HandleAnimEvent",  HookType_Entity, ReturnType_Void,   ThisPointer_CBaseEntity, CBaseAnimating_HandleAnimEvent);
	DHookAddParam(g_hHandleAnimEvent, HookParamType_ObjectPtr, -1);
	
	g_hGetFrictionSideways = DHookCreateEx(hConf, "ILocomotion::GetFrictionSideways",HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetFrictionSideways);
	g_hGetStepHeight       = DHookCreateEx(hConf, "ILocomotion::GetStepHeight",      HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetStepHeight);	
	g_hGetGravity          = DHookCreateEx(hConf, "ILocomotion::GetGravity",         HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetGravity);	
	g_hGetRunSpeed         = DHookCreateEx(hConf, "ILocomotion::GetRunSpeed",        HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetRunSpeed);
	g_hGetGroundNormal     = DHookCreateEx(hConf, "ILocomotion::GetGroundNormal",    HookType_Raw, ReturnType_VectorPtr, ThisPointer_Address, ILocomotion_GetGroundNormal);
	g_hGetMaxAcceleration  = DHookCreateEx(hConf, "ILocomotion::GetMaxAcceleration", HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetMaxAcceleration);
	
	
	g_hShouldCollideWith = DHookCreateEx(hConf, "ILocomotion::ShouldCollideWith",  HookType_Raw, ReturnType_Bool, ThisPointer_Address, ILocomotion_ShouldCollideWith);
	DHookAddParam(g_hShouldCollideWith, HookParamType_CBaseEntity);
	
	g_hGetSolidMask = DHookCreateEx(hConf, "IBody::GetSolidMask", HookType_Raw, ReturnType_Int,  ThisPointer_Address, IBody_GetSolidMask);
	g_hGetActivity  = DHookCreateEx(hConf, "IBody::GetActivity",  HookType_Raw, ReturnType_Int,  ThisPointer_Address, IBody_GetActivity);
	
	g_hIsActivity   = DHookCreateEx(hConf, "IBody::IsActivity",   HookType_Raw, ReturnType_Bool, ThisPointer_Address, IBody_IsActivity);
	DHookAddParam(g_hIsActivity, HookParamType_Int);
	
	g_hStartActivity = DHookCreateEx(hConf, "IBody::StartActivity", HookType_Raw, ReturnType_Bool, ThisPointer_Address, IBody_StartActivity);
	DHookAddParam(g_hStartActivity, HookParamType_Int);
	DHookAddParam(g_hStartActivity, HookParamType_Int);
	
	g_hGetCurrencyValue    = DHookCreateEx(hConf, "CTFBaseBoss::GetCurrencyValue",   HookType_Entity, ReturnType_Int,    ThisPointer_Address, CTFBaseBoss_GetCurrencyValue);
	
	delete hConf;
}

public void OnMapStart()
{
	Handle hConf = LoadGameConfigFile("tf2.pets");

	navarea_count = GameConfGetAddress(hConf, "navarea_count");
	PrintToServer("[npc_clot] Found \"navarea_count\" @ 0x%X", navarea_count);
	
	if(LoadFromAddress(navarea_count, NumberType_Int32) <= 0)
	{
		SetFailState("[npc_clot] No nav mesh!");
		return;
	}
	
	//TheNavAreas is nicely above navarea_count
	TheNavAreas = view_as<Address>(LoadFromAddress(navarea_count + view_as<Address>(0x4), NumberType_Int32));
	PrintToServer("[npc_clot] Found \"TheNavAreas\" @ 0x%X", TheNavAreas);
	
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

public MRESReturn CBaseAnimating_HandleAnimEvent(int pThis, Handle hParams)
{
	int event = DHookGetParamObjectPtrVar(hParams, 1, 0, ObjectValueType_Int);
	PrintToServer("%i : %i", pThis, event);
}

public MRESReturn ILocomotion_GetGroundNormal(Address pThis, Handle hReturn, Handle hParams)     { DHookSetReturnVector(hReturn,    view_as<float>( { 0.0, 0.0, 1.0 } ));  return MRES_Supercede; }
public MRESReturn ILocomotion_GetStepHeight(Address pThis, Handle hReturn, Handle hParams)       { DHookSetReturn(hReturn, 18.0);	return MRES_Supercede; }
public MRESReturn ILocomotion_GetMaxAcceleration(Address pThis, Handle hReturn, Handle hParams)  { DHookSetReturn(hReturn, 800.0);  return MRES_Supercede; }
public MRESReturn ILocomotion_GetFrictionSideways(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturn(hReturn, 3.0);    return MRES_Supercede; }
public MRESReturn ILocomotion_ShouldCollideWith(Address pThis, Handle hReturn, Handle hParams)   { DHookSetReturn(hReturn, false);  return MRES_Supercede; }
public MRESReturn CTFBaseBoss_GetCurrencyValue(Address pThis, Handle hReturn, Handle hParams)    { DHookSetReturn(hReturn, 0);      return MRES_Supercede; }
public MRESReturn ILocomotion_GetGravity(Address pThis, Handle hReturn, Handle hParams)          { DHookSetReturn(hReturn, 800.0);  return MRES_Supercede; }


public MRESReturn ILocomotion_GetRunSpeed(Address pThis, Handle hReturn, Handle hParams)              
{ 
	DHookSetReturn(hReturn, view_as<Clot>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).GetRunSpeed()); 
	return MRES_Supercede; 
}

public MRESReturn IBody_GetSolidMask(Address pThis, Handle hReturn, Handle hParams)              
{ 
	DHookSetReturn(hReturn, view_as<Clot>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).GetSolidMask()); 
	return MRES_Supercede; 
}

public MRESReturn IBody_GetActivity(Address pThis, Handle hReturn, Handle hParams)              
{ 
	PrintToServer("IBody_GetActivity");	

	DHookSetReturn(hReturn, view_as<Clot>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).GetActivity()); 
	return MRES_Supercede; 
}

public MRESReturn IBody_IsActivity(Address pThis, Handle hReturn, Handle hParams)              
{
	int iActivity = DHookGetParam(hParams, 1);

	PrintToServer("IBody_IsActivity %i", iActivity);	

	DHookSetReturn(hReturn, view_as<Clot>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).IsActivity(iActivity));
	return MRES_Supercede; 
}

public MRESReturn IBody_StartActivity(Address pThis, Handle hReturn, Handle hParams)             
{ 
	int iActivity = DHookGetParam(hParams, 1);
	int fFlags    = DHookGetParam(hParams, 2);
	
	PrintToServer("IBody_StartActivity %i %i", iActivity, fFlags);	
	
	DHookSetReturn(hReturn, view_as<Clot>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).StartActivity(iActivity, fFlags)); 
	
	return MRES_Supercede; 
}

public MRESReturn IBody_GetHullWidth(Address pThis, Handle hReturn, Handle hParams)              { DHookSetReturn(hReturn, 24.0); return MRES_Supercede; }
public MRESReturn IBody_GetStandHullHeight(Address pThis, Handle hReturn, Handle hParams)        { DHookSetReturn(hReturn, 82.0); return MRES_Supercede; }
public MRESReturn IBody_GetHullHeight(Address pThis, Handle hReturn, Handle hParams)             { DHookSetReturn(hReturn, 82.0); return MRES_Supercede; }
public MRESReturn IBody_GetCrouchHullHeight(Address pThis, Handle hReturn, Handle hParams)       { DHookSetReturn(hReturn, 82.0); return MRES_Supercede; }
public MRESReturn IBody_GetHullMins(Address pThis, Handle hReturn, Handle hParams)               { DHookSetReturnVector(hReturn, view_as<float>( { -12.0, -12.0, 0.0 } )); return MRES_Supercede; }
public MRESReturn IBody_GetHullMaxs(Address pThis, Handle hReturn, Handle hParams)               { DHookSetReturnVector(hReturn, view_as<float>( { 12.0, 12.0, 82.0 } ));  return MRES_Supercede; }

public void PluginBot_Approach(int bot_entidx, const float vec[3])
{
	CBaseActor npc = view_as<CBaseActor>(bot_entidx);
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

public void PluginBot_MoveToSuccess(int bot_entidx, Address path)
{	
	PF_StopPathing(bot_entidx);
	view_as<Clot>(bot_entidx).m_bPathing = false;
	view_as<Clot>(bot_entidx).m_flNextTargetTime = GetGameTime() + GetRandomFloat(1.0, 4.0);
}

public void PluginBot_MoveToFailure(int bot_entidx, Address path, MoveToFailureType type)
{
	PF_StopPathing(bot_entidx);
	view_as<Clot>(bot_entidx).m_bPathing = false;
	view_as<Clot>(bot_entidx).m_flNextTargetTime = GetGameTime() + GetRandomFloat(1.0, 4.0);
}

public void PluginBot_Jump(int bot_entidx, const float vecPos[3], const float dir[2])
{
	Clot npc = view_as<Clot>(bot_entidx);
	
	float watchForClimbRange = 75.0;
	
	float vecNPC[3];
	GetEntPropVector(bot_entidx, Prop_Data, "m_vecOrigin", vecNPC);
	
	float flDistance = GetVectorDistance(vecNPC, vecPos);
	if(flDistance > watchForClimbRange || npc.IsStuck() || npc.m_bJumping)
		return;
	
	npc.JumpAcrossGap(vecPos, vecPos);
	
	npc.m_bJumping = true;
	npc.m_flJumpStartTime = GetGameTime();
}

enum //hitgroup_t
{
	HITGROUP_GENERIC,
	HITGROUP_HEAD,
	HITGROUP_CHEST,
	HITGROUP_STOMACH,
	HITGROUP_LEFTARM,
	HITGROUP_RIGHTARM,
	HITGROUP_LEFTLEG,
	HITGROUP_RIGHTLEG,
	
	NUM_HITGROUPS
};

public Action ClotDamaged(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& ammotype, int hitbox, int hitgroup)
{
	//Friendly fire
	if(view_as<CBaseActor>(attacker).GetTeam() == view_as<CBaseActor>(victim).GetTeam())
		return Plugin_Continue;
		
	//Valid attackers only.
	if(attacker <= 0 || attacker > MaxClients)
		return Plugin_Continue;
	
	
	//Valid inflictors only.
	if(inflictor <= 0 || inflictor > MaxClients)
		return Plugin_Continue;
	
	//PrintToServer("ClotDamaged victim %i attacker %i inflictor %i damage %.1f hitbox %i hitgroup %i", victim, attacker, inflictor, damage, hitbox, hitgroup);
	
	Clot npc = view_as<Clot>(victim);
	
	if(!npc.IsPlayingGesture("ACT_MP_GESTURE_FLINCH_CHEST")) {
		npc.AddGesture("ACT_MP_GESTURE_FLINCH_CHEST");
	}
	
/*	int m_nBody = GetEntProp(victim, Prop_Send, "m_nBody");
	
	switch(hitgroup)
	{
		case HITGROUP_HEAD:
		{
			npc.SetBodygroup(npc.FindBodygroupByName("gore_head"), 1);
			npc.SetBodygroup(npc.FindBodygroupByName("gore_headleft"), 1);
			npc.SetBodygroup(npc.FindBodygroupByName("gore_headright"), 1);
		}
		case HITGROUP_STOMACH:
		{
			npc.SetBodygroup(npc.FindBodygroupByName("gore_abdomen"), 1);
		}
		case HITGROUP_LEFTARM:
		{
			npc.SetBodygroup(npc.FindBodygroupByName("gore_handleft"), 1);
		}
		case HITGROUP_RIGHTARM:
		{
			int iGroupHandRight = npc.FindBodygroupByName("gore_handright");
			int iGroupUpArmRight = npc.FindBodygroupByName("gore_uparmright");
			int iGroupForeArmRight = npc.FindBodygroupByName("gore_forearmright");
			
			npc.SetBodygroup(iGroupHandRight, 1);
			
			//Break more of the arm.
			if(m_nBody & iGroupHandRight)
			{
				PrintToServer("1");
			
				npc.SetBodygroup(iGroupUpArmRight, 1);
				
				if(m_nBody & iGroupUpArmRight)
				{
					PrintToServer("2");
					
					npc.SetBodygroup(iGroupForeArmRight, 1);
				}
			}
		}
	}*/
	
	return Plugin_Continue;
}

stock float[] WorldSpaceCenter(int entity)
{
	float vecPos[3];
	SDKCall(g_hSDKWorldSpaceCenter, entity, vecPos);
	
	return vecPos;
}

stock NavArea PickRandomArea()
{
	int iAreaCount = LoadFromAddress(navarea_count, NumberType_Int32);
	
	//Pick a random goal area
	return view_as<NavArea>(LoadFromAddress(TheNavAreas + view_as<Address>(4 * GetRandomInt(0, iAreaCount - 1)), NumberType_Int32));
}

public bool FilterData(int entity, int contentsMask, any data)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	
	if(StrEqual(class, "base_boss"))
	{
		return false;
	}
	
	return !(entity == data);
}