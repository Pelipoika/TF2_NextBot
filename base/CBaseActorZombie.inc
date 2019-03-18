#if defined _CBaseActor_included
#endinput
#endif
#define _CBaseActor_included

#define EF_BONEMERGE                (1 << 0)
#define EF_PARENT_ANIMATES          (1 << 9)

enum ParticleAttachment
{
	PATTACH_ABSORIGIN = 0,  // Create at absorigin, but don't follow
	PATTACH_ABSORIGIN_FOLLOW,  // Create at absorigin, and update to follow the entity
	PATTACH_CUSTOMORIGIN,  // Create at a custom origin, but don't follow
	PATTACH_POINT,  // Create on attachment point, but don't follow
	PATTACH_POINT_FOLLOW,  // Create on attachment point, and update to follow the entity
	PATTACH_WORLDORIGIN,  // Used for control points that don't attach to an entity
	PATTACH_ROOTBONE_FOLLOW,  // Create at the root bone of the entity, and update to follow
	MAX_PATTACH_TYPES, 
};

//SDKCalls
Handle g_hMyNextBotPointer;
Handle g_hGetLocomotionInterface;
Handle g_hGetIntentionInterface;
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
Handle g_hDriveTo;
Handle g_hFaceTowards
Handle g_hGetVelocity;
Handle g_hGetAcceleration;
Handle g_hSetVelocity;
Handle g_hSetAcceleration;
Handle g_hStudioFrameAdvance;
Handle g_hJump;
Handle g_hJumpAcrossGap;
Handle g_hDispatchAnimEvents;
Handle g_hGetMaxAcceleration;
Handle g_hIsClimbingUpToLedge;
Handle g_hGetDesiredSpeed;
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
Handle g_hLookupSequence;
Handle g_hGetSequenceActivity;
Handle g_hIsPlayingGesture;
Handle g_hFindBodygroupByName;
Handle g_hSetBodyGroup;
Handle g_hSelectWeightedSequence;
Handle g_hResetSequenceInfo;

Handle g_hSGetSequenceCycleRate;
Handle g_hStudio_SeqMovement;

//Death
Handle g_hNextBotCombatCharacter_Event_Killed;
Handle g_hCBaseCombatCharacter_Event_Killed;

//Stuck detection
Handle g_hStuckMonitor;
Handle g_hClearStuckStatus;
Handle g_hIsStuck;

//PluginBot SDKCalls
Handle g_hGetEntity;
Handle g_hGetBot;

//DHooks
//Handle g_hGetCurrencyValue;
Handle g_hEvent_Killed;
Handle g_hHandleAnimEvent;
Handle g_hGetFrictionSideways;
Handle g_hGetStepHeight;
Handle g_hGetGravity;
Handle g_hGetRunSpeed;
Handle g_hGetGroundNormal;
Handle g_hShouldCollideWith;
Handle g_hOnContact;
Handle g_hGetSolidMask;
Handle g_hStartActivity;
Handle g_hGetActivity;
Handle g_hIsActivity;
Handle g_hHasActivityType;

Handle g_hSetDesiredPosture;
Handle g_hGetDesiredPosture;
Handle g_hIsDesiredPosture;
Handle g_hIsInDesiredPosture;
Handle g_hGetActualPosture;
Handle g_hIsActualPosture;
Handle g_hIsPostureMobile;


Handle g_hGetHullWidth;
Handle g_hGetHullHeight;
Handle g_hGetStandHullHeight;

//NavAreas
Address TheNavAreas;
Address navarea_count;


/*
	"ceda"
	"crawler"
	"undistractable"
	"fallen"
	"riot_control"
	"clown"
	"jimmy"
	"hospital_patient"
	
	char UncommonGenderToString(_DWORD *gender)
	{
		char *result; // eax@1
		unsigned int v2; // edx@1
		
		result = "";
		
		v2 = *gender - 11;
		
		if ( v2 <= 7 )
			result = *(&UncommonGenderToString(gender_t const&)::szUncommonNames + v2);
			
		return result;
	}
*/

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
	public CBaseActor(float vecPos[3], float vecAng[3], const char[] model, const char[] modelscale = "1.0", const char[] health = "125", bool bGroundNormal = true)
	{
		int zombie = CreateEntityByName("base_boss");
		DispatchKeyValueVector(zombie, "origin", vecPos);
		DispatchKeyValueVector(zombie, "angles", vecAng);
		DispatchKeyValue(zombie, "model", model);
		DispatchKeyValue(zombie, "modelscale", modelscale);
		DispatchKeyValue(zombie, "health", health);
		DispatchSpawn(zombie);
		
		Address pNB = SDKCall(g_hMyNextBotPointer, zombie);
		Address pLocomotion = SDKCall(g_hGetLocomotionInterface, pNB);
		
		DHookRaw(g_hGetStepHeight, true, pLocomotion);
		DHookRaw(g_hGetGravity, true, pLocomotion);
		DHookRaw(g_hShouldCollideWith, true, pLocomotion);
		DHookRaw(g_hOnContact, true, pLocomotion);
		DHookRaw(g_hGetMaxAcceleration, true, pLocomotion);
		DHookRaw(g_hIsClimbingUpToLedge, true, pLocomotion);
		DHookRaw(g_hGetDesiredSpeed, true, pLocomotion);
		DHookRaw(g_hGetFrictionSideways, true, pLocomotion);
		DHookRaw(g_hGetRunSpeed, true, pLocomotion);
		
		if (bGroundNormal)
			DHookRaw(g_hGetGroundNormal, true, pLocomotion);
		
		Address pBody = SDKCall(g_hGetBodyInterface, pNB);
		
		DHookRaw(g_hGetHullWidth, true, pBody);
		DHookRaw(g_hGetHullHeight, true, pBody);
		DHookRaw(g_hGetStandHullHeight, true, pBody);
		DHookRaw(g_hGetActivity, true, pBody);
		DHookRaw(g_hIsActivity, true, pBody);
		DHookRaw(g_hHasActivityType, true, pBody);
		
		DHookRaw(g_hSetDesiredPosture, true, pBody);
		DHookRaw(g_hGetDesiredPosture, true, pBody);
		DHookRaw(g_hIsDesiredPosture, true, pBody);
		DHookRaw(g_hIsInDesiredPosture, true, pBody);
		DHookRaw(g_hGetActualPosture, true, pBody);
		DHookRaw(g_hIsActualPosture, true, pBody);
		DHookRaw(g_hIsPostureMobile, true, pBody);
		
		//Collide with the correct stuff
		DHookRaw(g_hGetSolidMask, true, pBody);
		
		//Allow jumping
		DHookRaw(g_hStartActivity, true, pBody);
		
		//Don't drop money.
		//DHookEntity(g_hGetCurrencyValue, true, zombie);
		
		//Ragdoll, hopefully
		DHookEntity(g_hEvent_Killed, false, zombie);
		
		//Animevents 
		DHookEntity(g_hHandleAnimEvent, true, zombie);
		
		//trigger_hurts hurt and spawn doors open for us, etc.
		SetEntityFlags(zombie, FL_CLIENT | FL_FAKECLIENT | FL_NPC);
		
		//Don't ResolvePlayerCollisions.
		SetEntData(zombie, FindSendPropInfo("CTFBaseBoss", "m_lastHealthPercentage") + 28, false, 4, true);
		
		//SetAIWalkable false EFL_DONTWALKON = 1 << 26
		SetEntProp(zombie, Prop_Data, "m_iEFlags", GetEntProp(zombie, Prop_Data, "m_iEFlags") | (1 << 26));
		
		//Don't bleed.
		//SetEntProp(zombie, Prop_Data, "m_bloodColor", -1); 
		
		static float m_vecMaxs[3]; m_vecMaxs = view_as<float>( { 16.0, 16.0, 72.0 } );
		static float m_vecMins[3]; m_vecMins = view_as<float>( { -16.0, -16.0, 0.0 } );
		
		//Fix collisions
		SetEntPropVector(zombie, Prop_Send, "m_vecMaxs", m_vecMaxs);
		SetEntPropVector(zombie, Prop_Data, "m_vecMaxs", m_vecMaxs);
		
		SetEntPropVector(zombie, Prop_Send, "m_vecMins", m_vecMins);
		SetEntPropVector(zombie, Prop_Data, "m_vecMins", m_vecMins);
		
		return view_as<CBaseActor>(zombie);
	}
	
	property int index
	{
		public get() { return view_as<int>(this); }
	}
	
	public int ExtractStringValueAsInt(const char[] key)
	{
		char buffer[64];
		bool bExists = GetCustomKeyValue(this.index, key, buffer, sizeof(buffer));
		return bExists ? StringToInt(buffer) : -1;
	}
	
	public float ExtractStringValueAsFloat(const char[] key)
	{
		char buffer[64];
		bool bExists = GetCustomKeyValue(this.index, key, buffer, sizeof(buffer));
		return bExists ? StringToFloat(buffer) : -1.0;
	}
	
	property bool m_bIsOnGround
	{
		public get() { return !!this.ExtractStringValueAsInt("m_bIsOnGround"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_bIsOnGround", buff, true); }
	}
	
	property bool m_bHasValidPath
	{
		public get() { return !!this.ExtractStringValueAsInt("m_bHasValidPath"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_bHasValidPath", buff, true); }
	}
	
	property bool m_bJumping
	{
		public get() { return !!this.ExtractStringValueAsInt("m_bJumping"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_bJumping", buff, true); }
	}
	
	property bool m_isClimbingUpToLedge
	{
		public get() { return !!this.ExtractStringValueAsInt("m_isClimbingUpToLedge"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_isClimbingUpToLedge", buff, true); }
	}
	
	property bool m_bInAirWalk
	{
		public get() { return !!this.ExtractStringValueAsInt("m_bInAirWalk"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_bInAirWalk", buff, true); }
	}
	
	property float m_flJumpStartTime
	{
		public get() { return this.ExtractStringValueAsFloat("m_flJumpStartTime"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flJumpStartTime", buff, true); }
	}
	
	property float m_flNextThinkTime
	{
		public get() { return this.ExtractStringValueAsFloat("m_flNextThinkTime"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flNextThinkTime", buff, true); }
	}
	
	property float m_flNextMeleeAttack
	{
		public get() { return this.ExtractStringValueAsFloat("m_flNextMeleeAttack"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flNextMeleeAttack", buff, true); }
	}
	
	property bool m_bAttacking
	{
		public get() { return !!this.ExtractStringValueAsInt("m_bAttacking"); }
		public set(bool flNextTime) { char buff[8]; IntToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_bAttacking", buff, true); }
	}
	
	public Address GetLocomotionInterface() { return SDKCall(g_hGetLocomotionInterface, SDKCall(g_hMyNextBotPointer, this.index)); }
	public Address GetIntentionInterface() { return SDKCall(g_hGetIntentionInterface, SDKCall(g_hMyNextBotPointer, this.index)); }
	public Address GetBodyInterface() { return SDKCall(g_hGetBodyInterface, SDKCall(g_hMyNextBotPointer, this.index)); }
	public CVision GetVisionInterface() { return SDKCall(g_hGetVisionInterface, SDKCall(g_hMyNextBotPointer, this.index)); }
	
	property float m_actualSpeed
	{
		public get()
		{
			const int m_actualSpeed = 0x90;
			
			Address m_nextBot = this.GetLocomotionInterface();
			return view_as<float>(LoadFromAddress(m_nextBot + view_as<Address>(m_actualSpeed), NumberType_Int32));
		}
	}
	
	
	public bool IsStuck() { return SDKCall(g_hIsStuck, this.GetLocomotionInterface()); }
	
	public bool IsOnGround()
	{
		return (GetEntPropEnt(this.index, Prop_Data, "m_hGroundEntity") != INVALID_ENT_REFERENCE);
	}
	
	public Address GetModelPtr()
	{
		//const int offset = FindSendPropInfo("CBaseAnimating", "m_flFadeScale ") + 28;
		
		if (IsValidEntity(this.index)) {
			return view_as<Address>(GetEntData(this.index, 283 * 4));
		}
		
		return Address_Null;
	}
	public float SetPoseParameter(int iParameter, float value)
	{
		Address pStudioHdr = this.GetModelPtr();
		if (pStudioHdr == Address_Null)
			return 0.0;
		
		return SDKCall(g_hSetPoseParameter, this.index, pStudioHdr, iParameter, value);
	}
	public int FindAttachment(const char[] pAttachmentName)
	{
		Address pStudioHdr = this.GetModelPtr();
		if (pStudioHdr == Address_Null)
			return -1;
		
		return SDKCall(g_hStudio_FindAttachment, pStudioHdr, pAttachmentName) + 1;
	}
	public void DispatchParticleEffect(int entity, const char[] strParticle, float flStartPos[3], float vecAngles[3], float flEndPos[3], 
		int iAttachmentPointIndex = 0, ParticleAttachment iAttachType = PATTACH_CUSTOMORIGIN, bool bResetAllParticlesOnEntity = false)
	{
		int tblidx = FindStringTable("ParticleEffectNames");
		if (tblidx == INVALID_STRING_TABLE)
		{
			LogError("Could not find string table: ParticleEffectNames");
			return;
		}
		char tmp[256];
		int count = GetStringTableNumStrings(tblidx);
		int stridx = INVALID_STRING_INDEX;
		for (int i = 0; i < count; i++)
		{
			ReadStringTable(tblidx, i, tmp, sizeof(tmp));
			if (StrEqual(tmp, strParticle, false))
			{
				stridx = i;
				break;
			}
		}
		if (stridx == INVALID_STRING_INDEX)
		{
			LogError("Could not find particle: %s", strParticle);
			return;
		}
		
		TE_Start("TFParticleEffect");
		TE_WriteFloat("m_vecOrigin[0]", flStartPos[0]);
		TE_WriteFloat("m_vecOrigin[1]", flStartPos[1]);
		TE_WriteFloat("m_vecOrigin[2]", flStartPos[2]);
		TE_WriteVector("m_vecAngles", vecAngles);
		TE_WriteNum("m_iParticleSystemIndex", stridx);
		TE_WriteNum("entindex", entity);
		TE_WriteNum("m_iAttachType", view_as<int>(iAttachType));
		TE_WriteNum("m_iAttachmentPointIndex", iAttachmentPointIndex);
		TE_WriteNum("m_bResetParticles", bResetAllParticlesOnEntity);
		TE_WriteNum("m_bControlPoint1", 0);
		TE_WriteNum("m_ControlPoint1.m_eParticleAttachment", 0);
		TE_WriteFloat("m_ControlPoint1.m_vecOffset[0]", flEndPos[0]);
		TE_WriteFloat("m_ControlPoint1.m_vecOffset[1]", flEndPos[1]);
		TE_WriteFloat("m_ControlPoint1.m_vecOffset[2]", flEndPos[2]);
		TE_SendToAll();
	}
	public int LookupPoseParameter(const char[] szName)
	{
		Address pStudioHdr = this.GetModelPtr();
		if (pStudioHdr == Address_Null)
			return -1;
		
		return SDKCall(g_hLookupPoseParameter, this.index, pStudioHdr, szName);
	}
	public int LookupSequence(const char[] anim)
	{
		Address pStudioHdr = this.GetModelPtr();
		if (pStudioHdr == Address_Null)
			return -1;
		
		return SDKCall(g_hLookupSequence, pStudioHdr, anim);
	}
	public int GetSequenceActivity(int iSequence)
	{
		return SDKCall(g_hGetSequenceActivity, this.index, iSequence);
	}
	public int LookupActivity(const char[] activity)
	{
		Address pStudioHdr = this.GetModelPtr();
		if (pStudioHdr == Address_Null)
			return -1;
		
		return SDKCall(g_hLookupActivity, pStudioHdr, activity);
	}
	public void AddGesture(const char[] anim, bool bAutoKill = true)
	{
		int iSequence = this.LookupActivity(anim);
		if (iSequence < 0)
			return;
		
		SDKCall(g_hAddGesture, this.index, iSequence, bAutoKill);
	}
	public bool IsPlayingGesture(const char[] anim)
	{
		int iSequence = this.LookupActivity(anim);
		if (iSequence < 0)
			return;
		
		SDKCall(g_hIsPlayingGesture, this.index, iSequence);
	}
	public void CreatePather(float flStep, float flJump, float flDrop, int iSolid, float flAhead, float flRePath, float flHull)
	{
		PF_Create(this.index, flStep, flJump, flDrop, 0.6, iSolid, flAhead, flRePath, flHull);
		PF_EnableCallback(this.index, PFCB_Approach, PluginBot_Approach);
		PF_EnableCallback(this.index, PFCB_IsEntityTraversable, PluginBot_IsEntityTraversable);
		//PF_EnableCallback(this.index, PFCB_GetPathCost,         PluginBot_PathCost);
		PF_EnableCallback(this.index, PFCB_ClimbUpToLedge, PluginBot_Jump);
		
		PF_EnableCallback(this.index, PFCB_OnMoveToSuccess, PluginBot_MoveToSuccess);
		PF_EnableCallback(this.index, PFCB_PathSuccess, PluginBot_PathSuccess);
		
		PF_EnableCallback(this.index, PFCB_OnMoveToFailure, PluginBot_MoveToFailure);
		PF_EnableCallback(this.index, PFCB_PathFailed, PluginBot_PathFail);
	}
	
	public void Update()
	{
		#if defined DEBUG_ACTOR && defined DEBUG_UPDATE
		PrintToServer("CBaseActor::Update()");
		#endif
		
		SDKCall(g_hRun, this.GetLocomotionInterface());
	}
	
	public float GetAnimTimeInterval()
	{
		static float MAX_ANIMTIME_INTERVAL = 0.2;
		
		float m_flAnimTime = GetEntPropFloat(this.index, Prop_Data, "m_flAnimTime");
		float m_flPrevAnimTime = GetEntPropFloat(this.index, Prop_Data, "m_flPrevAnimTime");
		
		float flInterval;
		if (m_flAnimTime < GetGameTime())
		{
			// estimate what it'll be this frame
			flInterval = clamp(GetGameTime() - m_flAnimTime, 0.0, MAX_ANIMTIME_INTERVAL);
		}
		else
		{
			// report actual
			flInterval = clamp(m_flAnimTime - m_flPrevAnimTime, 0.0, MAX_ANIMTIME_INTERVAL);
		}
		
		return flInterval;
	}
	
	
	// Helper function to look nicer
	public void SinCos(float radian, float &sine, float &cosine)
	{
		sine = Sine(radian);
		cosine = Cosine(radian);
	}
	
	
	// Rotate a vector around the Z axis (YAW)
	public void VectorYawRotate(const float vin[3], float flYaw, float out[3])
	{
		float tmp[3]; tmp = vin;
		
		float sy, cy;
		
		this.SinCos(DegToRad(flYaw), sy, cy);
		
		out[0] = tmp[0] * cy - tmp[1] * sy;
		out[1] = tmp[0] * sy + tmp[1] * cy;
		out[2] = tmp[2];
	}
	
	public bool GetIntervalMovement(float flIntervalUsed, bool &bMoveSeqFinished, float newPosition[3], float newAngles[3])
	{
		Address pStudioHdr = this.GetModelPtr();
		if (pStudioHdr == Address_Null)
			return false;
		
		float m_flPlaybackRate = GetEntPropFloat(this.index, Prop_Data, "m_flPlaybackRate");
		float m_flCycle = GetEntPropFloat(this.index, Prop_Data, "m_flCycle");
		int m_nSequence = GetEntProp(this.index, Prop_Data, "m_nSequence");
		
		float flComputedCycleRate = SDKCall(g_hSGetSequenceCycleRate, this.index, m_nSequence);
		float flNextCycle = m_flCycle + flIntervalUsed * flComputedCycleRate * m_flPlaybackRate;
		
		if ((!GetEntProp(this.index, Prop_Data, "m_bSequenceLoops")) && flNextCycle > 1.0)
		{
			flIntervalUsed = m_flCycle / (flComputedCycleRate * m_flPlaybackRate);
			flNextCycle = 1.0;
			bMoveSeqFinished = true;
		}
		else
		{
			bMoveSeqFinished = false;
		}
		
		float deltaPos[3]; float deltaAngles[3];
		
		float vLocalAngles[3]; GetEntPropVector(this.index, Prop_Data, "m_angRotation", vLocalAngles);
		
		if (SDKCall(g_hStudio_SeqMovement, pStudioHdr, m_nSequence, m_flCycle, flNextCycle, (GetEntData(this.index, FindDataMapInfo(this.index, "m_flPoseParameter"))), deltaPos, deltaAngles))
		{
			this.VectorYawRotate(deltaPos, vLocalAngles[1], deltaPos);
			
			AddVectors(GetAbsOrigin(this.index), deltaPos, newPosition);
			
			newAngles[1] = vLocalAngles[1] + deltaAngles[1];
			
			return true;
		}
		else
		{
			newPosition = GetAbsOrigin(this.index);
			newAngles = vLocalAngles;
			return false;
		}
	}
	
	public float GetGroundSpeed() { return SDKCall(g_hGetGroundSpeed, this.GetLocomotionInterface()); }
	public float GetPoseParameter(int iParameter) { return SDKCall(g_hGetPoseParameter, this.index, iParameter); }
	public int FindBodygroupByName(const char[] name) { return SDKCall(g_hFindBodygroupByName, this.index, name); }
	public int SelectWeightedSequence(int activity, int curSequence) { return SDKCall(g_hSelectWeightedSequence, this.index, this.GetModelPtr(), activity, curSequence); }
	
	public void GetAttachment(const char[] szName, float absOrigin[3], float absAngles[3]) { SDKCall(g_hGetAttachment, this.index, this.FindAttachment(szName), absOrigin, absAngles); }
	public void SetBodygroup(int iGroup, int iValue) { SDKCall(g_hSetBodyGroup, this.index, iGroup, iValue); }
	public void GetVelocity(float vecOut[3]) { SDKCall(g_hGetVelocity, this.GetLocomotionInterface(), vecOut); }
	
	public void GetAcceleration(float out[3])
	{
		//X of 
		const int m_acceleration = 0x74;
		
		Address m_nextBot = this.GetLocomotionInterface();
		out[0] = view_as<float>(LoadFromAddress(m_nextBot + view_as<Address>(m_acceleration + 0x0), NumberType_Int32));
		out[1] = view_as<float>(LoadFromAddress(m_nextBot + view_as<Address>(m_acceleration + 0x4), NumberType_Int32));
		out[2] = view_as<float>(LoadFromAddress(m_nextBot + view_as<Address>(m_acceleration + 0x8), NumberType_Int32));
	}
	
	
	public void SetVelocity(const float vec[3]) { SDKCall(g_hSetVelocity, this.GetLocomotionInterface(), vec); }
	public void SetAcceleration(const float vec[3]) { SDKCall(g_hSetAcceleration, this.GetLocomotionInterface(), vec); }
	
	public void SetSequence(int iSequence) { SetEntProp(this.index, Prop_Send, "m_nSequence", iSequence); }
	public void SetPlaybackRate(float flRate) { SetEntPropFloat(this.index, Prop_Send, "m_flPlaybackRate", flRate); }
	public void SetCycle(float flCycle) { SetEntPropFloat(this.index, Prop_Send, "m_flCycle", flCycle); }
	
	public void GetVectors(float pForward[3], float pRight[3], float pUp[3]) { SDKCall(g_hGetVectors, this.index, pForward, pRight, pUp); }
	public void GetGroundMotionVector(float vecMotion[3]) { SDKCall(g_hGetGroundMotionVector, this.GetLocomotionInterface(), vecMotion); }
	
	public void ResetSequenceInfo() { SDKCall(g_hResetSequenceInfo, this.index); }
	public void StudioFrameAdvance() { SDKCall(g_hStudioFrameAdvance, this.index); }
	public void DispatchAnimEvents() { SDKCall(g_hDispatchAnimEvents, this.index, this.index); }
	
	
	//This belongs in locomotion but cant have it there with sp :/
	public void DriveTo(float vecGoal[3])
	{
		SDKCall(g_hDriveTo, this.GetLocomotionInterface(), vecGoal);
	}
	
	//This belongs in body but cant have it there with sp :/
	
	//return the bot's collision mask
	public int GetSolidMask()
	{
		//return (0x202400B); //L4D2
		return (MASK_NPCSOLID | MASK_PLAYERSOLID);
	}
	
	public bool IsUsingLadder()
	{
		//return this->m_ladder != 0;
		return false;
	}
}

enum //ActivityType 
{
	MOTION_CONTROLLED_XY = 0x0001,  // XY position and orientation of the bot is driven by the animation.
	MOTION_CONTROLLED_Z = 0x0002,  // Z position of the bot is driven by the animation.
	ACTIVITY_UNINTERRUPTIBLE = 0x0004,  // activity can't be changed until animation finishes
	ACTIVITY_TRANSITORY = 0x0008,  // a short animation that takes over from the underlying animation momentarily, resuming it upon completion
	ENTINDEX_PLAYBACK_RATE = 0x0010,  // played back at different rates based on entindex
};

enum //PostureType
{
	STAND, 
	CROUCH, 
	SIT, 
	CRAWL, 
	LIE
};

/**
 * "Arousal" is the level of excitedness/arousal/anxiety of the body.
 * Is changes instantaneously to avoid complex interactions with posture transitions.
 */
enum //ArousalType
{
	NEUTRAL, 
	ALERT, 
	INTENSE
};

/*
	Actor
	|
	|-> Locomotion
	|
	|-> Body
	|
	|-> Vision
	
	InfectedExecAction
	-> InfectedBehavior
		-> InfectedAttack
			-> PunchVictim
				-> ChaseVictim
			-> ChaseVictim
			
		-> InfectedWander
			-> InfectedStandDazed
			-> InfectedStaggerAround
			
			-> InfectedStandingActivity
				-> InfectedStandDazed
			
			-> InfectedLeanOnWall
				-> InfectedStaggerAround
*/

methodmap CZombieBotBody < CBaseActor
{
	//Hack to get OldActivity iin OnAniMAtionactcompelete
	property int m_iLastCompletedActivity
	{
		public get() { return this.ExtractStringValueAsInt("m_iLastActivity"); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iLastActivity", buff, true); }
	}
	property int m_iActivityBackupNeverNull
	{
		public get() { return this.ExtractStringValueAsInt("m_iActivity"); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iActivity", buff, true); }
	}
	property int m_iActivity
	{
		public get() { return this.ExtractStringValueAsInt("m_iActivity"); }
		public set(int iInt) {
			char buff[8]; IntToString(iInt, buff, sizeof(buff));
			SetCustomKeyValue(this.index, "m_iActivity", buff, true);
			
			if (iInt > 0) {
				this.m_iActivityBackupNeverNull = iInt;
			}
		}
	}
	property int m_iActivityFlags
	{
		public get() { return (this.ExtractStringValueAsInt("m_iActivityFlags")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iActivityFlags", buff, true); }
	}
	property int m_iActivity2
	{
		public get() { return this.ExtractStringValueAsInt("m_iActivity2"); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iActivity2", buff, true); }
	}
	property int m_iActivityFlags2
	{
		public get() { return (this.ExtractStringValueAsInt("m_iActivityFlags2")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iActivityFlags2", buff, true); }
	}
	property int m_iAttachmentForward
	{
		public get() { return (this.ExtractStringValueAsInt("m_iAttachmentForward")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iAttachmentForward", buff, true); }
	}
	property int m_iMoveX
	{
		public get() { return (this.ExtractStringValueAsInt("m_iMoveX")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iMoveX", buff, true); }
	}
	property int m_iMoveY
	{
		public get() { return (this.ExtractStringValueAsInt("m_iMoveY")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iMoveY", buff, true); }
	}
	property int m_iBodyYaw
	{
		public get() { return (this.ExtractStringValueAsInt("m_iBodyYaw")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iBodyYaw", buff, true); }
	}
	property int m_iBodyPitch
	{
		public get() { return (this.ExtractStringValueAsInt("m_iBodyPitch")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iBodyPitch", buff, true); }
	}
	property int m_iLeanYaw
	{
		public get() { return (this.ExtractStringValueAsInt("m_iLeanYaw")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iLeanYaw", buff, true); }
	}
	property int m_iLeanPitch
	{
		public get() { return (this.ExtractStringValueAsInt("m_iLeanPitch")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iLeanPitch", buff, true); }
	}
	property bool m_bChangingPosture
	{
		public get() { return !!this.ExtractStringValueAsInt("m_bChangingPosture"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_bChangingPosture", buff, true); }
	}
	property int m_nPosture
	{
		public get() { return (this.ExtractStringValueAsInt("m_nPosture")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_nPosture", buff, true); }
	}
	property int m_nDesiredPosture
	{
		public get() { return (this.ExtractStringValueAsInt("m_nDesiredPosture")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_nDesiredPosture", buff, true); }
	}
	property int m_arousal
	{
		public get() { return (this.ExtractStringValueAsInt("m_arousal")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_arousal", buff, true); }
	}
	
	//return true if currently animating activity has any of the given flags
	public bool HasActivityType(int flags)
	{
		return (flags & this.m_iActivityFlags) != 0;
	}
	
	//return true if currently animating activity matches the given one
	public bool IsActivity(int iActivity)
	{
		#if defined DEBUG_BODY
		PrintToServer("CZombieBotBody::IsActivity(%i)", iActivity);
		#endif
		
		return (iActivity == this.m_iActivity);
	}
	
	//return currently animating activity
	public int GetActivity()
	{
		#if defined DEBUG_BODY
		PrintToServer("CZombieBotBody::GetActivity()");
		#endif
		
		return this.m_iActivity;
	}
	
	public bool IsPostureMobile()
	{
		if (!this.m_bChangingPosture)
		{
			if (this.m_nPosture != SIT)
			{
				return this.m_nPosture != LIE;
			}
		}
		
		return false
	}
	
	public bool IsPostureChanging()
	{
		return this.m_bChangingPosture;
	}
	
	public int GetDesiredPosture()
	{
		return this.m_nDesiredPosture;
	}
	
	public bool IsDesiredPosture(int posture)
	{
		return posture == this.m_nDesiredPosture;
	}
	
	public bool IsInDesiredPosture()
	{
		return this.m_nDesiredPosture == this.m_nPosture;
	}
	
	public int GetActualPosture()
	{
		return this.m_nPosture;
	}
	
	public bool IsActualPosture(int posture)
	{
		return posture == this.m_nPosture;
	}
	
	public void SetArousal(int arousal)
	{
		this.m_arousal = arousal;
	}
	
	public int GetArousal()
	{
		return this.m_arousal;
	}
	
	public bool IsArousal(int arousal)
	{
		return arousal == this.m_arousal;
	}
	
	public void GetViewVector(float out[3])
	{
		
	}
	
	public float GetHullWidth()
	{
		return 26.0;
	}
	
	public float GetStandHullHeight()
	{
		return 68.0;
	}
	
	public float GetCrouchHullHeight()
	{
		return 32.0;
	}
	
	public float GetHullHeight()
	{
		int ActualPosture = this.GetActualPosture();
		
		if (ActualPosture < CROUCH)
			return this.GetStandHullHeight();
		
		if (ActualPosture <= SIT)
			return this.GetCrouchHullHeight();
		
		if (ActualPosture != LIE)
			return this.GetStandHullHeight();
		
		return 16.0;
	}
	
	public void GetHullMins(float out[3])
	{
		out[0] = -(this.GetHullWidth() / 2);
		out[1] = -(this.GetHullWidth() / 2);
		out[2] = 0.0;
	}
	
	public void GetHullMaxs(float out[3])
	{
		out[0] = (this.GetHullWidth() / 2);
		out[1] = (this.GetHullWidth() / 2);
		out[2] = this.GetHullHeight();
	}
	
	public bool IsClimbingUpToLedge()
	{
		#if defined DEBUG_BODY
		PrintToServer("CZombieBotBody::IsClimbingUpToLedge()");
		#endif
		
		return this.m_isClimbingUpToLedge;
	}
	
	public void RestartMainSequence()
	{
		#if defined DEBUG_BODY
		PrintToServer("CZombieBotBody::RestartMainSequence()");
		#endif
		
		SetEntPropFloat(this.index, Prop_Data, "m_flAnimTime", GetGameTime());
		
		this.SetCycle(0.0);
	}
	
	public bool IsSequenceFinished()
	{
		//return !!GetEntProp(this.index, Prop_Data, "m_bSequenceFinished");
		return GetEntPropFloat(this.index, Prop_Data, "m_flCycle") >= 1.0;
	}
	
	public bool SequenceLoops()
	{
		return !!GetEntProp(this.index, Prop_Data, "m_bSequenceLoops");
	}
	
	public void OnAnimationActivityInterrupted(int iActivity)
	{
		#if defined DEBUG_BODY
		PrintToServer("CZombieBotBody::OnAnimationActivityInterrupted(%i)", iActivity);
		#endif
	}
	
	//Actually belongs to locomotion but fuckitdood
	//TODO 
	public void OnAnimationActivityComplete(int iOldActivity)
	{
		#if defined DEBUG_BODY
		PrintToServer("CZombieBotBody::OnAnimationActivityComplete(%i)", iOldActivity);
		#endif
		
		this.m_iLastCompletedActivity = iOldActivity;
		
		//Notify CBaseActor
		//this.OnAnimationActivityComplete(currentActivity);
		
		/*	if ( activity == 717 && *(this + 58) )
		{
			v2 = *(this + 30);
			v3 = *(this + 30);
			
			if ( *(v2 + 333) & 8 )
			{
				CBaseEntity::CalcAbsolutePosition(*(this + 30));
				v2 = *(this + 30);
			}
			
			v4 = *(v3 + 896);
			v5 = 0;
			v6 = v4;
			v7 = *(v3 + 900);
			CBaseEntity::SetAbsAngles(v2, &v5);
			
			*(this + 58) = 0;
		}*/
	}
	
	public int SelectAnimationSequence(int iActivity)
	{
		#if defined DEBUG_BODY
		PrintToServer("CZombieBotBody::SelectAnimationSequence(%i)", iActivity);
		#endif
		
		/*	int ACT_TERROR_DIE_FROM_STAND    = this.LookupActivity("ACT_TERROR_DIE_FROM_STAND");
		int ACT_TERROR_DIE_WHILE_RUNNING = this.LookupActivity("ACT_TERROR_DIE_WHILE_RUNNING");
		
		if(iActivity == ACT_TERROR_DIE_FROM_STAND || iActivity == ACT_TERROR_DIE_WHILE_RUNNING)
		{
			//TODO
			int lastAttacker = this.GetLastAttacker();
			
			int bShotDirection = 1;
			
			if(lastAttacker)
			{
				float vAttackerToMe[3];
				MakeVectorFromPoints(GetAbsOrigin(lastAttacker), GetAbsOrigin(this.index), vAttackerToMe);
				
				float vecFwd[3], vecRight[3], vecUp[3];
				this.GetVectors(vecFwd, vecRight, vecUp);
				
				bShotDirection = GetVectorDotProduct(vAttackerToMe, vecFwd) != 0.0;
			}
		}*/
		
		return this.SelectWeightedSequence(iActivity, GetEntProp(this.index, Prop_Data, "m_nSequence"));
	}
	
	//Begin an animation activity, return false if we cant do that right now.
	public bool StartActivity(int iActivity, int flags = 0)
	{
		#if defined DEBUG_BODY
		PrintToServer("CZombieBotBody::StartActivity(%i, %i)", iActivity, flags);
		#endif
		
		if (iActivity <= 0)
		{
			#if defined DEBUG_BODY
			PrintToServer("CZombieBotBody::StartActivity failed, activity is invalid.");
			#endif
			
			return false;
		}
		
		if (!this.HasActivityType(ACTIVITY_UNINTERRUPTIBLE))
		{
			bool bStartedActivity = false;
			
			if (this.m_iActivity == this.LookupActivity("ACT_TERROR_FALL"))
			{
				if (!this.IsOnGround() && !this.IsUsingLadder())
				{
					#if defined DEBUG_BODY
					PrintToServer("CZombieBotBody::StartActivity failed, actor is falling");
					#endif
					
					bStartedActivity = false;
					
					return bStartedActivity;
				}
			}
			
			int nSequence = -1;
			
			if (iActivity != this.LookupActivity("ACT_TERROR_SHOVED_BACKWARD") || /*gender != 15 || */GetRandomInt(1, 100) > 50)
			{
				nSequence = this.SelectAnimationSequence(iActivity);
			}
			else
			{
				bool bShove = !!GetRandomInt(0, 1);
				if (bShove) {
					nSequence = this.LookupSequence("shoved_backward_04j");
				} else {
					nSequence = this.LookupSequence("shoved_backward_04g");
				}
			}
			
			if (nSequence <= 0)
			{
				#if defined DEBUG_BODY
				PrintToServer("CZombieBotBody::StartActivity failed, activity not available");
				#endif
				
				bStartedActivity = false;
			}
			else
			{
				//Current activity was interrupted
				if (this.m_iActivity != -1)
				{
					this.OnAnimationActivityInterrupted(this.m_iActivity);
				}
				
				this.SetSequence(nSequence);
				this.SetPlaybackRate(1.0);
				this.SetCycle(0.0);
				this.ResetSequenceInfo();
				
				
				//Gay shit
				char fallActivitites[][] =  {
					"ACT_TERROR_JUMP_LANDING", 
					"ACT_TERROR_JUMP_LANDING_HARD", 
					"ACT_TERROR_JUMP_LANDING_NEUTRAL", 
					"ACT_TERROR_JUMP_LANDING_HARD_NEUTRAL", 
					"ACT_TERROR_FALL", 
					"ACT_TERROR_DIE_FROM_STAND"
				};
				
				bool bIsFallActivity = false;
				for (int i = 0; i < sizeof(fallActivitites); i++) {
					if (iActivity == this.LookupActivity(fallActivitites[i])) {
						bIsFallActivity = true;
						break;
					}
				}
				
				char transitionalActivitites[][] =  {
					"ACT_TERROR_SIT_FROM_STAND", 
					"ACT_TERROR_SIT_TO_STAND", 
					"ACT_TERROR_SIT_TO_STAND_ALERT", 
					"ACT_TERROR_SIT_TO_LIE", 
					//"ACT_TERROR_LIE_IDLE", 
					"ACT_TERROR_LIE_FROM_STAND", 
					"ACT_TERROR_LIE_TO_STAND", 
					"ACT_TERROR_LIE_TO_STAND_ALERT", 
					"ACT_TERROR_LIE_TO_SIT", 
				};
				
				bool bIsTransitionalActivity = false;
				for (int i = 0; i < sizeof(transitionalActivitites); i++) {
					if (iActivity == this.LookupActivity(transitionalActivitites[i])) {
						bIsTransitionalActivity = true;
						break;
					}
				}
				
				char facingActivitites[][] =  {
					"ACT_TERROR_FACE_LEFT_NEUTRAL", 
					"ACT_TERROR_FACE_LEFT_ALERT", 
					"ACT_TERROR_FACE_LEFT_INTENSE", 
					"ACT_TERROR_FACE_RIGHT_NEUTRAL", 
					"ACT_TERROR_FACE_RIGHT_ALERT", 
					"ACT_TERROR_FACE_RIGHT_INTENSE", 
					"ACT_TERROR_ABOUT_FACE_NEUTRAL", 
					"ACT_TERROR_ABOUT_FACE_ALERT", 
					"ACT_TERROR_ABOUT_FACE_INTENSE", 
				};
				
				bool bIsFacingActivity = false;
				for (int i = 0; i < sizeof(facingActivitites); i++) {
					if (iActivity == this.LookupActivity(facingActivitites[i])) {
						bIsFacingActivity = true;
						break;
					}
				}
				////////////////
				
				
				this.m_iActivity = iActivity;
				this.m_iActivityFlags = flags;
				
				if (!bIsFallActivity && !(flags & ACTIVITY_TRANSITORY))
				{
					//PrintToServer("CZombieBotBody::StartActivity TRANSITIONAL ACTIVITY");
					
					this.m_iActivity2 = iActivity;
					this.m_iActivityFlags2 = flags;
				}
				
				if ((bIsTransitionalActivity || bIsFacingActivity) && iActivity != this.LookupActivity("ACT_TERROR_LIE_IDLE") && iActivity != this.LookupActivity("ACT_TERROR_FALL"))
				{
					//PrintToServer("CZombieBotBody::StartActivity POSTURE CHANGING ACTIVITY!");
					this.m_bChangingPosture = true;
				}
				else
				{
					this.m_bChangingPosture = false;
				}
				
				bStartedActivity = true;
			}
			
			return bStartedActivity;
		}
		
		#if defined DEBUG_BODY
		PrintToServer("CZombieBotBody::StartActivity %i failed, current activity %i is ACTIVITY_UNINTERRUPTIBLE", iActivity, this.m_iActivity);
		#endif
		
		return false;
	}
	
	public int GetPostureTransitionActivity(int goalPosture)
	{
		#if defined DEBUG_BODY
		PrintToServer("CZombieBotBody::GetPostureTransitionActivity");
		#endif
		
		int iTransitionActivity = -1;
		
		if (goalPosture == SIT)
		{
			if (this.m_nPosture == SIT)
			{
				iTransitionActivity = -1;
			}
			else if (this.m_nPosture == LIE)
			{
				iTransitionActivity = this.LookupActivity("ACT_TERROR_LIE_TO_SIT");
			}
			else
			{
				int ACT_TERROR_SIT_FROM_STAND = this.LookupActivity("ACT_TERROR_SIT_FROM_STAND");
				iTransitionActivity = 8 * ((this.m_nPosture == LIE) ? 1 : 0) + ACT_TERROR_SIT_FROM_STAND;
			}
		}
		else if (goalPosture == LIE)
		{
			iTransitionActivity = this.LookupActivity("ACT_TERROR_SIT_TO_LIE");
			
			if (this.m_nPosture != SIT)
			{
				iTransitionActivity = -1;
				
				if (this.m_nPosture != LIE)
				{
					iTransitionActivity = this.LookupActivity("ACT_TERROR_LIE_FROM_STAND");
				}
			}
		}
		else
		{
			if (this.m_nPosture == SIT)
			{
				if (this.GetArousal() < ALERT) {
					iTransitionActivity = this.LookupActivity("ACT_TERROR_SIT_TO_STAND");
				} else {
					iTransitionActivity = this.LookupActivity("ACT_TERROR_SIT_TO_STAND_ALERT");
				}
			}
			else
			{
				iTransitionActivity = -1;
				
				if (this.m_nPosture == LIE)
				{
					if (this.GetArousal() < ALERT) {
						iTransitionActivity = this.LookupActivity("ACT_TERROR_LIE_TO_STAND");
					} else {
						iTransitionActivity = this.LookupActivity("ACT_TERROR_LIE_TO_STAND_ALERT");
					}
				}
			}
		}
		
		return iTransitionActivity;
	}
	
	public void SetDesiredPosture(int desiredPosture)
	{
		#if defined DEBUG_BODY
		PrintToServer("CZombieBotBody::SetDesiredPosture");
		#endif
		
		int transitionActivity = this.GetPostureTransitionActivity(desiredPosture);
		
		if (this.GetActivity() == transitionActivity)
			return;
		
		if (transitionActivity == -1)
		{
			//PrintToServer("CZombieBotBody::SetDesiredPosture -> Failed to find transitional activity");
			
			//Instant transition.
			this.m_nDesiredPosture = desiredPosture;
			this.m_nPosture = desiredPosture;
			
			float vecMaxs[3], vecMins[3];
			this.GetHullMaxs(vecMaxs);
			this.GetHullMins(vecMins);
			
			SetEntPropVector(this.index, Prop_Send, "m_vecMaxs", vecMaxs);
			SetEntPropVector(this.index, Prop_Data, "m_vecMaxs", vecMaxs);
			SetEntPropVector(this.index, Prop_Send, "m_vecMins", vecMins);
			SetEntPropVector(this.index, Prop_Data, "m_vecMins", vecMins);
		}
		else
		{
			//PrintToServer("CZombieBotBody::SetDesiredPosture -> Playing transitional activity %i", transitionActivity);
			
			this.StartActivity(transitionActivity, MOTION_CONTROLLED_XY);
			
			this.SetPlaybackRate(1.0);
			
			this.m_nDesiredPosture = desiredPosture;
			this.m_bChangingPosture = true;
		}
	}
	
	public void OnLandOnGround(int ground)
	{
		#if defined DEBUG_BODY
		PrintToServer("CZombieBotBody::OnLandOnGround");
		#endif
		
		// Minimum falling speed to cause a stumbling forward landing animation to occur
		const float z_falling_land_forward_speed = 200.0;
		
		// Minimum falling speed to cause a 'hard' landing animation to occur
		const float z_falling_land_hard_speed = 200.0;
		
		// Minimum falling speed to cause a landing animation to occur
		const float z_falling_land_speed = 200.0;
		
		if (!this.HasActivityType(MOTION_CONTROLLED_Z))
		{
			//BUG Always 0 0 0 durint this time
			float vVelocity[3]; vVelocity = GetAbsVelocity(this.index);
			
			if (this.GetGroundSpeed() <= z_falling_land_forward_speed)
			{
				if (z_falling_land_hard_speed > vVelocity[2])
				{
					#if defined DEBUG_BODY
					PrintToServer("CZombieBotBody::OnLandOnGround -> StartActivity ACT_TERROR_JUMP_LANDING_HARD_NEUTRAL");
					#endif
					
					int iAct = this.LookupActivity("ACT_TERROR_JUMP_LANDING_HARD_NEUTRAL");
					this.StartActivity(iAct, MOTION_CONTROLLED_XY | ACTIVITY_UNINTERRUPTIBLE);
					return;
				}
				
				if (z_falling_land_speed > vVelocity[2])
				{
					#if defined DEBUG_BODY
					PrintToServer("CZombieBotBody::OnLandOnGround -> StartActivity ACT_TERROR_JUMP_LANDING_NEUTRAL");
					#endif
					
					int iAct = this.LookupActivity("ACT_TERROR_JUMP_LANDING_NEUTRAL");
					this.StartActivity(iAct, MOTION_CONTROLLED_XY | ACTIVITY_UNINTERRUPTIBLE);
					return;
				}
			}
			else
			{
				if (z_falling_land_hard_speed > vVelocity[2])
				{
					#if defined DEBUG_BODY
					PrintToServer("CZombieBotBody::OnLandOnGround -> StartActivity ACT_TERROR_JUMP_LANDING_HARD");
					#endif
					
					int iAct = this.LookupActivity("ACT_TERROR_JUMP_LANDING_HARD");
					this.StartActivity(iAct, MOTION_CONTROLLED_XY | ACTIVITY_UNINTERRUPTIBLE);
					return;
				}
				
				if (z_falling_land_speed > vVelocity[2])
				{
					#if defined DEBUG_BODY
					PrintToServer("CZombieBotBody::OnLandOnGround -> StartActivity ACT_TERROR_JUMP_LANDING");
					#endif
					
					int iAct = this.LookupActivity("ACT_TERROR_JUMP_LANDING");
					this.StartActivity(iAct, MOTION_CONTROLLED_XY | ACTIVITY_UNINTERRUPTIBLE);
					return;
				}
			}
			
			this.StartActivity(this.m_iActivity2, this.m_iActivityFlags2);
		}
	}
	
	//LIL TODO
	public void Update()
	{
		Address pStudioHdr = this.GetModelPtr();
		if (pStudioHdr == Address_Null)
			return;
		
		#if defined DEBUG_BODY && defined DEBUG_UPDATE
		PrintToServer("CZombieBotBody::Update()");
		#endif
		
		//Params
		float newPosition[3]; float newAngles[3];
		bool bMoveSeqFinished;
		
		float flIntervalUsed = this.GetAnimTimeInterval();
		
		if (this.HasActivityType(MOTION_CONTROLLED_XY | MOTION_CONTROLLED_Z)
			 && this.GetIntervalMovement(flIntervalUsed, bMoveSeqFinished, newPosition, newAngles))
		{
			float vFeet[3]; vFeet = GetAbsOrigin(this.index);
			
			float newVelocity[3];
			newVelocity[0] = (newPosition[0] - vFeet[0]) * (1.0 / flIntervalUsed);
			newVelocity[1] = (newPosition[1] - vFeet[1]) * (1.0 / flIntervalUsed);
			newVelocity[2] = (newPosition[2] - vFeet[2]) * (1.0 / flIntervalUsed);
			
			float vMyVelocity[3]; GetEntPropVector(this.index, Prop_Data, "m_vecVelocity", vMyVelocity);
			
			if (!this.HasActivityType(MOTION_CONTROLLED_XY))
			{
				newVelocity[0] = vMyVelocity[0];
				newVelocity[1] = vMyVelocity[1];
			}
			
			if (!this.HasActivityType(MOTION_CONTROLLED_Z))
			{
				newVelocity[2] = vMyVelocity[2];
			}
			
			//this.SetVelocity(newVelocity);
			
			TeleportEntity(this.index, NULL_VECTOR, newAngles, newVelocity);
			
			if ((newVelocity[0] <= -0.01
					 || newVelocity[0] >= 0.01
					 || newVelocity[1] <= -0.01
					 || newVelocity[1] >= 0.01
					 || newVelocity[2] <= -0.01
					 || newVelocity[2] >= 0.01))
			{
				
				if (this.m_isClimbingUpToLedge)
				{
					float start[3]; start = newPosition;
					float end[3]; end = newPosition;
					end[2] = vFeet[2];
					
					float traceMin[3]; this.GetHullMins(traceMin); traceMin[2] += (17.9);
					float traceMax[3]; this.GetHullMaxs(traceMax);
					
					Handle trace = TR_TraceHullFilterEx(start, vFeet, traceMin, traceMax, this.GetSolidMask(), FilterBaseActorsAndData, this.index);
					
					if (TR_DidHit(trace))
					{
						newPosition[0] = vFeet[0];
						newPosition[1] = vFeet[1];
						
						//PrintToServer("Tried to move into a wall LMAO DUMBASS");
					}
					
					delete trace;
				}
				
				this.DriveTo(newPosition);
				
				//TeleportEntity(this.index, newPosition, newAngles, newVelocity);
			}
		}
		
		if (!this.IsOnGround() && !this.IsUsingLadder())
		{
			float vAbsVel[3]; vAbsVel = GetAbsVelocity(this.index);
			if (vAbsVel[2] < -5.0)
			{
				this.StartActivity(this.LookupActivity("ACT_TERROR_FALL"), 0);
			}
		}
		
		if (this.IsSequenceFinished() && !this.SequenceLoops())
		{
			int currentActivity = this.m_iActivity;
			
			char landingAnimations[][] =  {
				"ACT_TERROR_JUMP", 
				"ACT_TERROR_JUMP_UP_TO_LEDGE", 
				"ACT_TERROR_JUMP_DOWN_FROM_LEDGE", 
				"ACT_TERROR_JUMP_OVER_GAP", 
				"ACT_TERROR_JUMP_LANDING", 
				"ACT_TERROR_JUMP_LANDING_HARD", 
				"ACT_TERROR_JUMP_LANDING_NEUTRAL", 
				"ACT_TERROR_JUMP_LANDING_HARD_NEUTRAL", 
				"ACT_TERROR_FALL"
			};
			
			bool bIsJumpOrLandingActivity = false;
			for (int i = 0; i < sizeof(landingAnimations); i++) {
				if (currentActivity == this.LookupActivity(landingAnimations[i])) {
					bIsJumpOrLandingActivity = true;
					break;
				}
			}
			
			if (bIsJumpOrLandingActivity)
			{
				this.m_iActivity = -1;
				this.m_iActivityFlags = 0;
				
				this.StartActivity(this.m_iActivity2, this.m_iActivityFlags2);
			}
			else
			{
				if (currentActivity == -1)
					currentActivity = this.GetSequenceActivity(GetEntProp(this.index, Prop_Data, "m_nSequence"));
				
				this.m_iActivity = -1;
				this.m_iActivityFlags = 0;
				
				this.OnAnimationActivityComplete(currentActivity);
			}
			
			if (this.m_bChangingPosture)
			{
				this.m_bChangingPosture = false;
				this.m_nPosture = this.m_nDesiredPosture;
				
				float vecMaxs[3], vecMins[3];
				this.GetHullMaxs(vecMaxs);
				this.GetHullMins(vecMins);
				
				//this.SetCollisionBounds(vecMins, vecMaxs);
				SetEntPropVector(this.index, Prop_Send, "m_vecMaxs", vecMaxs);
				SetEntPropVector(this.index, Prop_Data, "m_vecMaxs", vecMaxs);
				SetEntPropVector(this.index, Prop_Send, "m_vecMins", vecMins);
				SetEntPropVector(this.index, Prop_Data, "m_vecMins", vecMins);
				
				int iCurrentPosture = this.m_nPosture;
				
				if (iCurrentPosture == SIT)
				{
					this.StartActivity(this.LookupActivity("ACT_TERROR_SIT_IDLE"), MOTION_CONTROLLED_XY);
				}
				else
				{
					int actToAct = this.LookupActivity((iCurrentPosture == LIE) ? ("ACT_TERROR_LIE_IDLE") : ("ACT_TERROR_IDLE_NEUTRAL"));
					
					this.StartActivity(actToAct, MOTION_CONTROLLED_XY);
				}
			}
		}
		
		if (this.HasActivityType(ENTINDEX_PLAYBACK_RATE))
		{
			//TODO
			
			//v52 = *(*(v1 + 5) + 24);
			
			//if ( v52 )
			//v79 = (v52 - GetGameTime());
			//else
			//v79 = 0;
			
			//v53 = v79;
			//v54 = (Cosine(v79) - -1.0) * 0.10000002 + 0.89999998;
			//
			//SetEntPropFloat(
		}
		
		if (!this.m_bChangingPosture && this.m_nPosture != SIT && this.m_nPosture != LIE
			 && !this.HasActivityType(MOTION_CONTROLLED_XY | MOTION_CONTROLLED_Z))
		{
			if (this.m_iMoveX < 0) {
				this.m_iMoveX = this.LookupPoseParameter("move_x");
			}
			if (this.m_iMoveY < 0) {
				this.m_iMoveY = this.LookupPoseParameter("move_y");
			}
			
			if (this.m_iLeanYaw < 0) {
				this.m_iLeanYaw = this.LookupPoseParameter("lean_yaw");
			}
			if (this.m_iLeanPitch < 0) {
				this.m_iLeanPitch = this.LookupPoseParameter("lean_pitch");
			}
			
			float vDesiredLean[3];
			//this.GetDesiredLean(vDesiredLean);			
			vDesiredLean[0] = this.ExtractStringValueAsFloat("m_flDesiredLean_X");
			vDesiredLean[1] = this.ExtractStringValueAsFloat("m_flDesiredLean_Y");
			vDesiredLean[2] = this.ExtractStringValueAsFloat("m_flDesiredLean_Z");
			
			//PrintToServer("vDesiredLean %f %f %f", vDesiredLean[0], vDesiredLean[1], vDesiredLean[2]);
			
			if (this.m_iLeanYaw >= 0) {
				this.SetPoseParameter(this.m_iLeanYaw, vDesiredLean[1]);
			}
			if (this.m_iLeanPitch >= 0) {
				this.SetPoseParameter(this.m_iLeanPitch, vDesiredLean[0]);
			}
			
			//Infected::SetClientLeanYaw(MyInfectedPointer(), vDesiredLean.y);
			
			
			float vecFwd[3], vecRight[3], vecUp[3];
			this.GetVectors(vecFwd, vecRight, vecUp);
			
			float vecMotion[3];
			this.GetGroundMotionVector(vecMotion);
			
			if (this.m_iMoveX >= 0) {
				this.SetPoseParameter(this.m_iMoveX, GetVectorDotProduct(vecFwd, vecMotion));
			}
			if (this.m_iMoveY >= 0) {
				this.SetPoseParameter(this.m_iMoveY, GetVectorDotProduct(vecRight, vecMotion));
			}
			
			float flGroundSpeed = SDKCall(g_hGetGroundSpeed, this.GetLocomotionInterface());
			
			float m_flGroundSpeed = GetEntPropFloat(this.index, Prop_Data, "m_flGroundSpeed");
			
			if (this.HasActivityType(ENTINDEX_PLAYBACK_RATE) || !this.HasActivityType(MOTION_CONTROLLED_XY) && m_flGroundSpeed > 0.0 && this.IsOnGround())
			{
				float flReturnValue = clamp(flGroundSpeed / m_flGroundSpeed, -4.0, 12.0);
				SetEntPropFloat(this.index, Prop_Send, "m_flPlaybackRate", flReturnValue);
			}
			else
			{
				SetEntPropFloat(this.index, Prop_Send, "m_flPlaybackRate", 1.0);
			}
		}
		
		this.StudioFrameAdvance();
		this.DispatchAnimEvents();
		
		//Run and StuckMonitor
		this.Update();
	}
}

const float nb_lean_max_angle = 30.0;
const float nb_lean_rate = 3.0;

methodmap CZombieBotLocomotion < CZombieBotBody
{
	property float m_flRunSpeed
	{
		public get() { return this.ExtractStringValueAsFloat("m_flRunSpeed"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flRunSpeed", buff, true); }
	}
	
	property float m_flDesiredLean_X
	{
		public get() { return this.ExtractStringValueAsFloat("m_flDesiredLean_X"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flDesiredLean_X", buff, true); }
	}
	property float m_flDesiredLean_Y
	{
		public get() { return this.ExtractStringValueAsFloat("m_flDesiredLean_Y"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flDesiredLean_Y", buff, true); }
	}
	property float m_flDesiredLean_Z
	{
		public get() { return this.ExtractStringValueAsFloat("m_flDesiredLean_Z"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flDesiredLean_Z", buff, true); }
	}
	
	property float m_flDesiredSpeed
	{
		public get() { return this.ExtractStringValueAsFloat("m_flDesiredSpeed"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flDesiredSpeed", buff, true); }
	}
	
	property bool m_isClimbingUpToLedge
	{
		public get() { return !!this.ExtractStringValueAsInt("m_isClimbingUpToLedge"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_isClimbingUpToLedge", buff, true); }
	}
	
	property bool m_bJumpingAcrossGap
	{
		public get() { return !!this.ExtractStringValueAsInt("m_bJumpingAcrossGap"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_bJumpingAcrossGap", buff, true); }
	}
	
	/*
	public int GetGround()
	{
		return GetEntPropEnt(this.index, Prop_Data, "m_hGroundEntity");
	}
	
	public void GetGroundNormal(float out[3])
	{
		
	}
	*/
	
	public void SetDesiredLean(float lean[3])
	{
		//#if defined DEBUG_LOCOMOTION
		//PrintToServer("CZombieBotLocomotion::SetDesiredLean");
		//#endif	
		
		this.m_flDesiredLean_X = lean[0];
		this.m_flDesiredLean_Y = lean[1];
		this.m_flDesiredLean_Z = lean[2];
		
		//PrintToServer("SetDesiredLean %f %f %f", lean[0], lean[1], lean[2]);
	}
	
	public void GetDesiredLean(float lean[3])
	{
		//#if defined DEBUG_LOCOMOTION
		//PrintToServer("CZombieBotLocomotion::GetDesiredLean");
		//#endif	
		
		lean[0] = this.m_flDesiredLean_X;
		lean[1] = this.m_flDesiredLean_Y;
		lean[2] = this.m_flDesiredLean_Z;
		
		//PrintToServer("GetDesiredLean %f %f %f", lean[0], lean[1], lean[2]);
	}
	
	public void SetDesiredSpeed(float flSpeed)
	{
		#if defined DEBUG_LOCOMOTION
		PrintToServer("CZombieBotLocomotion::SetDesiredSpeed");
		#endif	
		
		this.m_flDesiredSpeed = flSpeed;
	}
	
	public float GetDesiredSpeed()
	{
		#if defined DEBUG_LOCOMOTION
		PrintToServer("CZombieBotLocomotion::GetDesiredSpeed (is %f)", this.m_flDesiredSpeed);
		#endif	
		
		return this.m_flDesiredSpeed;
	}
	
	public float GetRunSpeed()
	{
		#if defined DEBUG_LOCOMOTION
		PrintToServer("CZombieBotLocomotion::GetRunSpeed (is %f)", this.m_flRunSpeed);
		#endif	
		
		//z_speed = 250.0
		return this.m_flRunSpeed;
	}
	
	public bool IsClimbingOrJumping()
	{
		#if defined DEBUG_LOCOMOTION
		PrintToServer("CZombieBotLocomotion::IsClimbingOrJumping");
		#endif	
		
		return this.m_bJumping;
	}
	
	public bool IsClimbingUpToLedge()
	{
		#if defined DEBUG_LOCOMOTION
		PrintToServer("CZombieBotLocomotion::IsClimbingUpToLedge");
		#endif	
		
		return this.m_isClimbingUpToLedge;
	}
	
	public bool IsJumpingAcrossGap()
	{
		#if defined DEBUG_LOCOMOTION
		PrintToServer("CZombieBotLocomotion::IsJumpingAcrossGap");
		#endif	
		
		return this.m_bJumpingAcrossGap;
	}
	
	public bool IsRunning()
	{
		#if defined DEBUG_LOCOMOTION
		PrintToServer("CZombieBotLocomotion::IsRunning");
		#endif	
		
		return this.m_actualSpeed > 0.9 * this.GetRunSpeed();
	}
	
	public float GetStepHeight()
	{
		return 18.0;
	}
	
	public float GetMaxJumpHeight()
	{
		return 180.0;
	}
	
	public float GetMaxDeathDropHeight()
	{
		return 200.0;
	}
	
	public float GetDeathDropHeight()
	{
		return 200.0;
	}
	
	public float GetMaxDropHeight()
	{
		return 200.0;
	}
	
	public float GetWalkSpeed()
	{
		return 75.0;
	}
	
	public void GetMoveVector(float out[3])
	{
		//return this.m_moveVector;
		
		//X of 
		const int m_moveVector = 0x108;
		
		Address m_nextBot = this.GetLocomotionInterface();
		out[0] = view_as<float>(LoadFromAddress(m_nextBot + view_as<Address>(m_moveVector + 0x0), NumberType_Int32));
		out[1] = view_as<float>(LoadFromAddress(m_nextBot + view_as<Address>(m_moveVector + 0x4), NumberType_Int32));
		out[2] = view_as<float>(LoadFromAddress(m_nextBot + view_as<Address>(m_moveVector + 0x8), NumberType_Int32));
	}
	
	// set desired movement speed to running
	public void Run()
	{
		#if defined DEBUG_LOCOMOTION
		PrintToServer("CZombieBotLocomotion::Run");
		#endif	
		
		this.m_flDesiredSpeed = this.GetRunSpeed();
	}
	
	// set desired movement speed to walking
	public void Walk()
	{
		#if defined DEBUG_LOCOMOTION
		PrintToServer("CZombieBotLocomotion::Walk");
		#endif	
		
		this.m_flDesiredSpeed = this.GetWalkSpeed();
	}
	
	// set desired movement speed to stopped
	public void Stop()
	{
		#if defined DEBUG_LOCOMOTION
		PrintToServer("CZombieBotLocomotion::Stop");
		#endif	
		
		this.m_flDesiredSpeed = 0.0;
	}
	
	public float GetGroundAcceleration()
	{
		//nb_acceleration
		return 500.0;
	}
	
	public float GetYawRate()
	{
		//nb_yaw_rate
		return 250.0;
	}
	
	public bool IsAscendingOrDescendingLadder()
	{
		return this.IsUsingLadder();
	}
	
	public void GetFeet(float out[3])
	{
		//return m_nextBot->GetPosition();
		out = GetAbsOrigin(this.index);
	}
	
	/*
	public void GetVelocity(float out[3])
	{
		
	}
	
	public void OnMoveToSuccess(Address path) { }
	public void OnNavAreaChanged(CNavArea oldArea, CNavArea newArea) { }
	public void OnContact(int entity) { }
	*/
	public void FaceTowards(const float vecGoal[3])
	{
		//Sad!
		ConVar flTurnRate = FindConVar("tf_base_boss_max_turn_rate");
		float flPrevValue = flTurnRate.FloatValue;
		
		flTurnRate.FloatValue = this.GetYawRate();
		SDKCall(g_hFaceTowards, this.GetLocomotionInterface(), vecGoal);
		flTurnRate.FloatValue = flPrevValue;
	}
	
	public bool IsOnGround()
	{
		return (GetEntPropEnt(this.index, Prop_Data, "m_hGroundEntity") != INVALID_ENT_REFERENCE);
	}
	
	public void Approach(const float vecGoal[3], float weight = 1.0)
	{
		#if defined DEBUG_LOCOMOTION
		PrintToServer("CZombieBotLocomotion::Approach");
		#endif	
		
		SDKCall(g_hApproach, this.GetLocomotionInterface(), vecGoal, weight);
	}
	/*
	public float GetSpeedLimit()
	{
		
	}
	
	*/
	public void Jump()
	{
		#if defined DEBUG_LOCOMOTION
		PrintToServer("CZombieBotLocomotion::Jump");
		#endif	
		
		SDKCall(g_hJump, this.GetLocomotionInterface());
	}
	
	public void JumpAcrossGap(float landingGoal[3], float landingForward[3])
	{
		#if defined DEBUG_LOCOMOTION
		PrintToServer("CZombieBotLocomotion::JumpAcrossGap");
		#endif	
		
		SDKCall(g_hJumpAcrossGap, this.GetLocomotionInterface(), landingGoal, landingForward);
	}
	
	/*	public void OnLandOnGround(int ground) 
	{
		#if defined DEBUG_LOCOMOTION
		PrintToServer("CZombieBotLocomotion::OnLandOnGround");
		#endif
	}*/
	
	/*
	public bool IsAreaTraversable(CNavArea area)
	{
		v2 = 0;
		
		if ( *(a2 + 86) & 1 )
			return v2;
		
		if ( CNavArea::IsBlocked(a2, 3, 0) )
			return v2;
		
		v2 = 1;
		if ( !(*(a2 + 86) & 2) )
			return v2;
		
		v4 = (*(*this + 176))(this);
		v5 = (*(*v4 + 196))(v4);
		if ( !v5 )
			return 0;
			
		return (*(*v5 + 276))(v5, 2);
	}
	
	public void OnMoveToFailure(Address path, MoveToFailureType reason) { }
	
	public bool IsEntityTraversable(int obstacle, TraverseWhenType when)
	{
			
	}
	
	public void OnLeaveGround(int ground) { }
	
	public void Reset()
	{
		
	}
*/
	
	public bool ClimbUpToLedge(const float landingGoal[3], const float landingForward[3], int obstacle)
	{
		#if defined DEBUG_LOCOMOTION
		PrintToServer("CZombieBotLocomotion::ClimbUpToLedge");
		#endif
		
		if (!this.IsOnGround() || this.m_bJumping || this.m_isClimbingUpToLedge)
			return false;
		
		float vFeet[3]; this.GetFeet(vFeet);
		
		int ClimbActivity;
		float flClimbHeight = (landingGoal[2] - vFeet[2]);
		
		//flClimbHeight += this.GetStepHeight();
		
		float flClimbDistance;
		
		if (flClimbHeight < 30.0)
		{
			ClimbActivity = this.LookupActivity("ACT_TERROR_CLIMB_24_FROM_STAND");
			flClimbDistance = flClimbHeight - 24.0;
		}
		else if (flClimbHeight >= 42.0)
		{
			if (flClimbHeight < 54.0)
			{
				ClimbActivity = this.LookupActivity("ACT_TERROR_CLIMB_48_FROM_STAND");
				flClimbDistance = flClimbHeight - 48.0;
			}
			else if (flClimbHeight >= 66.0)
			{
				if (flClimbHeight >= 78.0)
				{
					if (flClimbHeight >= 90.0)
					{
						if (flClimbHeight >= 102.0)
						{
							if (flClimbHeight >= 114.0)
							{
								if (flClimbHeight >= 126.0)
								{
									if (flClimbHeight >= 138.0)
									{
										if (flClimbHeight >= 150.0)
										{
											if (flClimbHeight >= 162.0)
											{
												ClimbActivity = this.LookupActivity("ACT_TERROR_CLIMB_168_FROM_STAND");
												flClimbDistance = flClimbHeight - 168.0;
											}
											else
											{
												ClimbActivity = this.LookupActivity("ACT_TERROR_CLIMB_156_FROM_STAND");
												flClimbDistance = flClimbHeight - 156.0;
											}
										}
										else
										{
											ClimbActivity = this.LookupActivity("ACT_TERROR_CLIMB_144_FROM_STAND");
											flClimbDistance = flClimbHeight - 144.0;
										}
									}
									else
									{
										ClimbActivity = this.LookupActivity("ACT_TERROR_CLIMB_132_FROM_STAND");
										flClimbDistance = flClimbHeight - 132.0;
									}
								}
								else
								{
									ClimbActivity = this.LookupActivity("ACT_TERROR_CLIMB_120_FROM_STAND");
									flClimbDistance = flClimbHeight - 120.0;
								}
							}
							else
							{
								ClimbActivity = this.LookupActivity("ACT_TERROR_CLIMB_108_FROM_STAND");
								flClimbDistance = flClimbHeight - 108.0;
							}
						}
						else
						{
							ClimbActivity = this.LookupActivity("ACT_TERROR_CLIMB_96_FROM_STAND");
							flClimbDistance = flClimbHeight - 96.0;
						}
					}
					else
					{
						ClimbActivity = this.LookupActivity("ACT_TERROR_CLIMB_84_FROM_STAND");
						flClimbDistance = flClimbHeight - 84.0;
					}
				}
				else
				{
					ClimbActivity = this.LookupActivity("ACT_TERROR_CLIMB_72_FROM_STAND");
					flClimbDistance = flClimbHeight - 72.0;
				}
			}
			else
			{
				ClimbActivity = this.LookupActivity("ACT_TERROR_CLIMB_60_FROM_STAND");
				flClimbDistance = flClimbHeight - 60.0;
			}
		}
		else
		{
			ClimbActivity = this.LookupActivity("ACT_TERROR_CLIMB_36_FROM_STAND");
			flClimbDistance = flClimbHeight - 36.0;
		}
		
		float hullWidth = this.GetHullWidth();
		float stepHeight = this.GetStepHeight();
		
		float probeMin[3]; probeMin = view_as<float>( { -1.0, -1.0, -1.0 } );
		this.GetHullMins(probeMin);
		probeMin[2] = (stepHeight + 0.1);
		
		float probeMax[3]; probeMax = view_as<float>( { 1.0, 1.0, 1.0 } );
		this.GetHullMaxs(probeMax);
		probeMax[2] = (landingGoal[2] - vFeet[2]);
		
		if (probeMin[2] > probeMax[2])
		{
			probeMax[2] = probeMin[2];
			probeMin[2] = probeMax[2];
		}
		
		float pos[3];
		pos[0] = landingGoal[0];
		pos[1] = landingGoal[1];
		pos[2] = vFeet[2];
		
		Handle trace;
		
		float trace1_plane_normal[3];
		float trace1_distance_covered = 0.0;
		
		bool bStartSolid = true;
		
		//PrintToServer("StartSolid %i || fraction %f && AllSolid %i | HIT %i", bStartSolid, TR_GetFraction(trace), TR_AllSolid(trace), TR_GetEntityIndex(trace));
		
		//while( trace.startsolid || trace.fraction >= 1.0 && !trace.allsolid )
		while (bStartSolid || TR_GetFraction(trace) >= 1.0 && !TR_AllSolid(trace))
		{
			float start[3];
			start[0] = pos[0] - (trace1_distance_covered * landingForward[0]);
			start[1] = pos[1] - (trace1_distance_covered * landingForward[1]);
			start[2] = pos[2] - (trace1_distance_covered * landingForward[2]);
			
			float end[3];
			end[0] = vFeet[0] + ((hullWidth * 10.0) * landingForward[0]);
			end[1] = vFeet[1] + ((hullWidth * 10.0) * landingForward[1]);
			end[2] = vFeet[2] + ((hullWidth * 10.0) * landingForward[2]);
			
			//Line(start, end, 255, 0, 255, 0.2);
			
			trace = TR_TraceHullFilterEx(start, end, probeMin, probeMax, this.GetSolidMask(), FilterBaseActorsAndData, this.index);
			
			bStartSolid = TR_StartSolid(trace);
			
			TR_GetPlaneNormal(trace, trace1_plane_normal);
			
			if (trace1_distance_covered > (hullWidth * 3.0))
			{
				//#if defined DEBUG_LOCOMOTION
				PrintToServer("%3.2f: Can't find climb surface normal", GetGameTime());
				//#endif
				
				//this.SetVelocity(view_as<float>( { 0.0, 0.0, 0.0 } ));
				//this.SetAcceleration(view_as<float>( { 0.0, 0.0, 0.0 } ));
				
				//TeleportEntity(this.index, NULL_VECTOR, NULL_VECTOR, view_as<float>( { 0.0, 0.0, 0.0 } ));
				
				//this->m_velocity     = vec3_origin;
				//this->m_acceleration = vec3_origin;
				
				//Cannot climb.
				
				delete trace;
				return true;
			}
			
			trace1_distance_covered += (hullWidth / 8);
			
			delete trace;
		}
		
		//Yay we found a direction to climb! Proceed.
		
		//Not sure what the point in this is
		trace1_plane_normal[2] = 0.0;
		NormalizeVector(trace1_plane_normal, trace1_plane_normal);
		
		//Reset distance traveled
		trace1_distance_covered = 0.0;
		
		float traceStep = (hullWidth / 8);
		
		//Delete previous trace for reusing
		delete trace;
		
		float climbStartPos[3];
		
		for (; ; )
		{
			float start[3];
			start[0] = pos[0] + trace1_plane_normal[0] * traceStep;
			start[1] = pos[1] + trace1_plane_normal[1] * traceStep;
			start[2] = pos[2] + trace1_plane_normal[2] * traceStep;
			
			float end[3];
			end[0] = pos[0] + trace1_plane_normal[0] * traceStep;
			end[1] = pos[1] + trace1_plane_normal[1] * traceStep;
			end[2] = landingGoal[2];
			
			float traceMin[3];
			this.GetHullMins(traceMin);
			traceMin[2] += (stepHeight + 0.1);
			
			float traceMax[3];
			this.GetHullMaxs(traceMax);
			
			trace = TR_TraceHullFilterEx(start, end, traceMin, traceMax, this.GetSolidMask(), FilterBaseActorsAndData, this.index);
			
			climbStartPos = end;
			
			// Find Ledge Forward Edge
			if (!TR_DidHit(trace)) {
				break;
			}
			
			pos = start;
			
			if (trace1_distance_covered > (hullWidth * 3.0))
			{
				//#if defined DEBUG_LOCOMOTION
				PrintToServer("%3.2f: Can't find climb forward ledge", GetGameTime());
				//#endif
				
				delete trace;
				return true;
			}
			
			trace1_distance_covered += (hullWidth / 4);
			
			delete trace;
		}
		
		delete trace;
		
		//PF_SetGoalVector(this.index, climbStartPos);
		//Line(vFeet, climbStartPos, 255, 255, 0, 0.1);
		
		float angleNegative[3];
		angleNegative[0] = -trace1_plane_normal[0];
		angleNegative[1] = -trace1_plane_normal[1];
		angleNegative[2] = -trace1_plane_normal[2];
		
		float faceWallAngle[3];
		GetVectorAngles(angleNegative, faceWallAngle);
		
		faceWallAngle[0] = faceWallAngle[2] = 0.0;
		
		climbStartPos[2] = vFeet[2];
		climbStartPos[2] += flClimbDistance;
		
		if (GetVectorDistance(climbStartPos, vFeet) > 32.0)
			return true;
		
		TeleportEntity(this.index, NULL_VECTOR, faceWallAngle, NULL_VECTOR);
		
		this.DriveTo(climbStartPos);
		
		if (this.StartActivity(ClimbActivity, MOTION_CONTROLLED_Z | ACTIVITY_TRANSITORY))
		{
			//#if defined DEBUG_LOCOMOTION
			PrintToServer("%3.2f: Start climb (%d) distance %.1f remaining %.1f.", GetGameTime(), ClimbActivity, flClimbHeight, flClimbDistance);
			//#endif
			
			this.SetVelocity(view_as<float>( { 0.0, 0.0, 0.0 } ));
			this.SetAcceleration(view_as<float>( { 0.0, 0.0, 0.0 } ));
			
			this.m_isClimbingUpToLedge = true;
			//this->m_ledgeJumpGoalPos = *landingGoal;
			
			this.SetDesiredPosture(STAND);
			
			//this.m_bIsOnGround = false;
			//this.m_bJumping = true;
			
			//GetBot()->OnLeaveGround( m_nextBot->GetGroundEntity() );
			//return true;
		}
		//#if defined DEBUG_LOCOMOTION
		else
		{
			PrintToServer("%3.2f: Can't start climb activity.", GetGameTime());
		}
		//#endif
		
		return true;
	}
	
	/*
	ZombieBotLocomotion::DescendLadder(CNavLadder const*,CNavArea const*) .text 009F5E20 00000174 0000005C 0000000C R . . . B T .
	ZombieBotLocomotion::ClimbLadder(CNavLadder const*,CNavArea const*)   .text 009F5FA0 0000010C 0000003C 0000000C R . . . B T .
	*/
	
	public bool TraverseLadder()
	{
		return false;
	}
	
	public bool DidJustJump()
	{
		float absVelocity[3]; absVelocity = GetAbsVelocity(this.index);
		return this.IsClimbingOrJumping() && (absVelocity[2] > 0.0);
	}
	
	/*
	ZombieBotLocomotion::ApplyAccumulatedApproach(void)                   .text 009F64D0 000005DF 0000009C 00000004 R . . . B T .
	ZombieBotLocomotion::UpdateGroundConstraint(void)                     .text 009F6B00 00000B06 0000015C 00000004 R . . . B T .
	*/
	
	//BIG TODO TODO TODO!!!!
	public void Update()
	{
		#if defined DEBUG_LOCOMOTION && defined DEBUG_UPDATE
		PrintToServer("CZombieBotLocomotion::Update");
		#endif
		
		
		float m_velocity[3]; this.GetVelocity(m_velocity);
		float m_moveVector[3]; this.GetMoveVector(m_moveVector);
		
		float right[3];
		right[0] = m_moveVector[1];
		right[1] = -m_moveVector[0];
		right[2] = 0.0;
		
		float forwardSpeed = GetVectorDotProduct(m_velocity, m_moveVector);
		float forwardVelocity[3]; forwardVelocity = m_moveVector;
		ScaleVector(forwardVelocity, forwardSpeed);
		
		float sideVelocity[3]; sideVelocity = right;
		ScaleVector(right, GetVectorDotProduct(m_velocity, right));
		
		float frictionAccel[3];
		
		// always apply lateral friction to counteract sideslip		
		frictionAccel[0] += -3.0 * sideVelocity[0];
		frictionAccel[1] += -3.0 * sideVelocity[1];
		frictionAccel[2] += -3.0 * sideVelocity[2];
		
		float m_acceleration[3];
		m_acceleration[0] += frictionAccel[0];
		m_acceleration[1] += frictionAccel[1];
		
		//PrintToServer("CZombieBotLocomotion::Update m_acceleration %f %f %f", m_acceleration[0], m_acceleration[1], m_acceleration[2]);
		
		// lean sideways proportional to lateral acceleration
		float lean[3];
		this.GetDesiredLean(lean);
		
		float sideAccel = GetVectorDotProduct(right, m_acceleration);
		float slide = sideAccel / this.GetGroundAcceleration();
		
		// max lean depends on how fast we're actually moving
		float maxLeanAngle = nb_lean_max_angle * this.m_actualSpeed / this.GetRunSpeed();
		
		// actual lean angle is proportional to lateral acceleration (sliding)
		float desiredSideLean = -maxLeanAngle * slide;
		
		lean[1] += (desiredSideLean - lean[1]) * nb_lean_rate * GetGameFrameTime();
		
		this.SetDesiredLean(lean);
		
		//PrintToServer("CZombieBotLocomotion::Update SetDesiredLean %f %f %f", lean[0], lean[1], lean[2]);
		
		//Body update
		this.Update();
	}
}

//Trash below!

































public void InitGamedata()
{
	Handle hConf = LoadGameConfigFile("tf2.pets");
	
	//SDKCalls
	//This call is used to get an entitys center position
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::WorldSpaceCenter");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if ((g_hSDKWorldSpaceCenter = EndPrepSDKCall()) == null)SetFailState("Failed to create SDKCall for CBaseEntity::WorldSpaceCenter offset!");
	
	//=========================================================
	// StudioFrameAdvance - advance the animation frame up some interval (default 0.1) into the future
	//=========================================================
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseAnimating::StudioFrameAdvance");
	if ((g_hStudioFrameAdvance = EndPrepSDKCall()) == null)SetFailState("Failed to create SDKCall for CBaseAnimating::StudioFrameAdvance offset!");
	
	//CBaseAnimating::ResetSequenceInfo( );
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::ResetSequenceInfo");
	if ((g_hResetSequenceInfo = EndPrepSDKCall()) == null)SetFailState("Failed to create SDKCall for CBaseAnimating::ResetSequenceInfo signature!");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::MyNextBotPointer");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hMyNextBotPointer = EndPrepSDKCall()) == null)SetFailState("Failed to create SDKCall for CBaseEntity::MyNextBotPointer offset!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBot::GetLocomotionInterface");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hGetLocomotionInterface = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for INextBot::GetLocomotionInterface!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBot::GetIntentionInterface");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hGetIntentionInterface = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for INextBot::GetIntentionInterface!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBot::GetBodyInterface");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hGetBodyInterface = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for INextBot::GetBodyInterface!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBot::GetVisionInterface");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hGetVisionInterface = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for INextBot::GetVisionInterface!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "IVision::GetPrimaryKnownThreat");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hGetPrimaryKnownThreat = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for IVision::GetPrimaryKnownThreat!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "IVision::GetKnown");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer); //CBaseEntity - Entity to check for
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); //CKnownEntity
	if ((g_hGetKnown = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for IVision::GetKnown!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "IVision::AddKnownEntity");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((g_hAddKnownEntity = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for IVision::AddKnownEntity!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CKnownEntity::GetEntity");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((g_hGetKnownEntity = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for CKnownEntity::GetEntity!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CKnownEntity::UpdatePosition");
	if ((g_hUpdatePosition = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for CKnownEntity::UpdatePosition!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CKnownEntity::UpdateVisibilityStatus");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain); //bool visible now
	if ((g_hUpdateVisibilityStatus = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for CKnownEntity::UpdateVisibilityStatus!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::Run");
	if ((g_hRun = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for ILocomotion::Run!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::Approach");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	if ((g_hApproach = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for ILocomotion::Approach!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::DriveTo");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	if ((g_hDriveTo = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for ILocomotion::DriveTo!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::FaceTowards");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	if ((g_hFaceTowards = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for ILocomotion::FaceTowards!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::Jump");
	if ((g_hJump = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for ILocomotion::Jump!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::JumpAcrossGap");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	if ((g_hJumpAcrossGap = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for ILocomotion::JumpAcrossGap!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::GetVelocity");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if ((g_hGetVelocity = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for ILocomotion::GetVelocity!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::GetAcceleration");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if ((g_hGetAcceleration = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for ILocomotion::GetAcceleration!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::SetVelocity");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	if ((g_hSetVelocity = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for ILocomotion::SetVelocity!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::SetAcceleration");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	if ((g_hSetAcceleration = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for ILocomotion::SetAcceleration!");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseAnimating::DispatchAnimEvents");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((g_hDispatchAnimEvents = EndPrepSDKCall()) == null)SetFailState("Failed to create SDKCall for CBaseAnimating::DispatchAnimEvents offset!");
	
	//ILocomotion::GetGroundSpeed() 
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::GetGroundSpeed");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	if ((g_hGetGroundSpeed = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for ILocomotion::GetGroundSpeed!");
	
	//ILocomotion::GetGroundMotionVector() 
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::GetGroundMotionVector");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if ((g_hGetGroundMotionVector = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for ILocomotion::GetGroundMotionVector!");
	
	//ILocomotion::IsStuck()
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::IsStuck");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if ((g_hIsStuck = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for ILocomotion::IsStuck!");
	
	//ILocomotion::ClearStuckStatus(char const* reason)
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::ClearStuckStatus");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if ((g_hClearStuckStatus = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for ILocomotion::ClearStuckStatus!");
	
	//ILocomotion::StuckMonitor
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::StuckMonitor");
	if ((g_hStuckMonitor = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for ILocomotion::StuckMonitor!");
	
	//CBaseEntity::GetVectors(Vector*, Vector*, Vector*) 
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::GetVectors");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if ((g_hGetVectors = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for CBaseEntity::GetVectors!");
	
	//CBaseAnimating::GetPoseParameter(int iParameter)
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::GetPoseParameter");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	if ((g_hGetPoseParameter = EndPrepSDKCall()) == null)SetFailState("Failed to create Call for CBaseAnimating::GetPoseParameter");
	
	//CBaseAnimating::FindBodygroupByName(const char* name)
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::FindBodygroupByName");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hFindBodygroupByName = EndPrepSDKCall()) == null)SetFailState("Failed to create Call for CBaseAnimating::FindBodygroupByName");
	
	//CBaseAnimating::SetBodygroup( int iGroup, int iValue )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::SetBodygroup");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hSetBodyGroup = EndPrepSDKCall()) == null)SetFailState("Failed to create Call for CBaseAnimating::SetBodygroup");
	
	//int SelectWeightedSequence( CStudioHdr *pstudiohdr, int activity, int curSequence );
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "SelectWeightedSequence");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //pstudiohdr
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //activity
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //curSequence
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); //return sequence
	if ((g_hSelectWeightedSequence = EndPrepSDKCall()) == null)SetFailState("Failed to create Call for SelectWeightedSequence");
	
	//SetPoseParameter( CStudioHdr *pStudioHdr, int iParameter, float flValue );
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::SetPoseParameter");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	if ((g_hSetPoseParameter = EndPrepSDKCall()) == null)SetFailState("Failed to create Call for CBaseAnimating::SetPoseParameter");
	
	//LookupPoseParameter( CStudioHdr *pStudioHdr, const char *szName );
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::LookupPoseParameter");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hLookupPoseParameter = EndPrepSDKCall()) == null)SetFailState("Failed to create Call for CBaseAnimating::LookupPoseParameter");
	
	//CBaseAnimatingOverlay::AddGesture( Activity activity, bool autokill )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimatingOverlay::AddGesture");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hAddGesture = EndPrepSDKCall()) == null)SetFailState("Failed to create Call for CBaseAnimatingOverlay::AddGesture");
	
	//-----------------------------------------------------------------------------
	// Purpose: Looks up a sequence by sequence name first, then by activity name.
	// Input  : label - The sequence name or activity name to look up.
	// Output : Returns the sequence index of the matching sequence, or ACT_INVALID.
	//-----------------------------------------------------------------------------
	//LookupSequence( CStudioHdr *pStudioHdr, const char *label );
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "LookupSequence");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //pStudioHdr
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer); //label
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); //return index
	if ((g_hLookupSequence = EndPrepSDKCall()) == null)SetFailState("Failed to create Call for LookupSequence");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::GetSequenceActivity");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hGetSequenceActivity = EndPrepSDKCall()) == null)SetFailState("Failed to create Call for CBaseAnimating::GetSequenceActivity");
	
	//CBaseAnimatingOverlay::IsPlayingGesture( Activity activity )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimatingOverlay::IsPlayingGesture");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if ((g_hIsPlayingGesture = EndPrepSDKCall()) == null)SetFailState("Failed to create Call for CBaseAnimatingOverlay::IsPlayingGesture");
	
	//CBaseAnimating::GetSequenceCycleRate( int iSequence ) 
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x56\x8B\xF1\x80\xBE\x41\x03\x00\x00\x00\x75\x2A\x83\xBE\x6C\x04\x00\x00\x00\x75\x2A\xE8\x2A\x2A\x2A\x2A\x85\xC0\x74\x2A\x8B\xCE\xE8\x2A\x2A\x2A\x2A\x8B\x86\x6C\x04\x00\x00\x85\xC0\x74\x2A\x83\x38\x00\x75\x2A\x33\xC0\xFF\x75\x08\x8B\xCE\x50\xE8\x2A\x2A\x2A\x2A\xD9\x55\x08", 71);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //int iSequence
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain); //float rate
	if ((g_hSGetSequenceCycleRate = EndPrepSDKCall()) == null)SetFailState("Failed to create Call for GetSequenceCycleRate");
	
	
	//-----------------------------------------------------------------------------
	// Purpose: calculate changes in position and angle between two points in a sequences cycle
	// Output:	updated position and angle, relative to CycleFrom being at the origin
	//			returns false if sequence is not a movement sequence
	//-----------------------------------------------------------------------------
	//bool Studio_SeqMovement( const CStudioHdr *pStudioHdr, int iSequence, float flCycleFrom, float flCycleTo, const float poseParameter[], Vector &deltaPos, QAngle &deltaAngles )
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x83\xEC\x70\x56\x8B\x75\x0C", 10);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //pStudioHdr
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //iSequence
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain); //flCycleFrom
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain); //flCycleTo
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Pointer); //poseParameter[]
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK); //&deltaPos
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK); //&deltaAngles
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain); //bool
	if ((g_hStudio_SeqMovement = EndPrepSDKCall()) == null)SetFailState("Failed to create Call for Studio_SeqMovement");
	
	
	//-----------------------------------------------------------------------------
	// Purpose: Looks up an activity by name.
	// Input  : label - Name of the activity to look up, ie "ACT_IDLE"
	// Output : Activity index or ACT_INVALID if not found.
	//-----------------------------------------------------------------------------
	//int LookupActivity( CStudioHdr *pstudiohdr, const char *label )
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "LookupActivity");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //pStudioHdr
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer); //label
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); //return index
	if ((g_hLookupActivity = EndPrepSDKCall()) == null)SetFailState("Failed to create Call for LookupActivity");
	
	
	//-----------------------------------------------------------------------------
	// Purpose: lookup attachment by name
	//-----------------------------------------------------------------------------
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "Studio_FindAttachment");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //pStudioHdr
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer); //pAttachmentName
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); //return index
	if ((g_hStudio_FindAttachment = EndPrepSDKCall()) == null)SetFailState("Failed to create Call for Studio_FindAttachment");
	
	//-----------------------------------------------------------------------------
	// Purpose: Returns the world location and world angles of an attachment
	// Input  : attachment name
	// Output :	location and angles
	//-----------------------------------------------------------------------------
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::GetAttachment");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //iAttachment
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK); //absOrigin
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK); //absAngles
	if ((g_hGetAttachment = EndPrepSDKCall()) == null)SetFailState("Failed to create Call for CBaseAnimating::GetAttachment");
	
	//PluginBot SDKCalls
	//Get NextBot pointer
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBotComponent::GetBot");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hGetBot = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for INextBotComponent::GetBot!");
	
	//Get NextBot entity index
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBotComponent::GetEntity");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((g_hGetEntity = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for INextBotComponent::GetEntity!");
	
	//
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "NextBotCombatCharacter::Event_Killed");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer);
	if ((g_hNextBotCombatCharacter_Event_Killed = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for NextBotCombatCharacter::Event_Killed!");
	
	//Get NextBot entity index
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseCombatCharacter::Event_Killed");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer);
	if ((g_hCBaseCombatCharacter_Event_Killed = EndPrepSDKCall()) == null)SetFailState("Failed to create Virtual Call for CBaseCombatCharacter::Event_Killed!");
	
	
	//DHooks
	g_hHandleAnimEvent = DHookCreateEx(hConf, "CBaseAnimating::HandleAnimEvent", HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, CBaseAnimating_HandleAnimEvent);
	DHookAddParam(g_hHandleAnimEvent, HookParamType_ObjectPtr);
	
	g_hGetFrictionSideways = DHookCreateEx(hConf, "ILocomotion::GetFrictionSideways", HookType_Raw, ReturnType_Float, ThisPointer_Address, ILocomotion_GetFrictionSideways);
	g_hGetStepHeight = DHookCreateEx(hConf, "ILocomotion::GetStepHeight", HookType_Raw, ReturnType_Float, ThisPointer_Address, ILocomotion_GetStepHeight);
	g_hGetGravity = DHookCreateEx(hConf, "ILocomotion::GetGravity", HookType_Raw, ReturnType_Float, ThisPointer_Address, ILocomotion_GetGravity);
	g_hGetRunSpeed = DHookCreateEx(hConf, "ILocomotion::GetRunSpeed", HookType_Raw, ReturnType_Float, ThisPointer_Address, ILocomotion_GetRunSpeed);
	g_hGetGroundNormal = DHookCreateEx(hConf, "ILocomotion::GetGroundNormal", HookType_Raw, ReturnType_VectorPtr, ThisPointer_Address, ILocomotion_GetGroundNormal);
	g_hGetMaxAcceleration = DHookCreateEx(hConf, "ILocomotion::GetMaxAcceleration", HookType_Raw, ReturnType_Float, ThisPointer_Address, ILocomotion_GetMaxAcceleration);
	g_hIsClimbingUpToLedge = DHookCreateEx(hConf, "ILocomotion::IsClimbingUpToLedge", HookType_Raw, ReturnType_Bool, ThisPointer_Address, ILocomotion_IsClimbingUpToLedge);
	g_hGetDesiredSpeed = DHookCreateEx(hConf, "ILocomotion::GetDesiredSpeed", HookType_Raw, ReturnType_Float, ThisPointer_Address, ILocomotion_GetDesiredSpeed);
	
	g_hOnContact = DHookCreateEx(hConf, "INextBotEventResponder::OnContact", HookType_Raw, ReturnType_Void, ThisPointer_Address, ILocomotion_OnContact);
	DHookAddParam(g_hOnContact, HookParamType_CBaseEntity); //CBaseEntity *other
	DHookAddParam(g_hOnContact, HookParamType_Int); //CGameTrace *result
	
	g_hShouldCollideWith = DHookCreateEx(hConf, "ILocomotion::ShouldCollideWith", HookType_Raw, ReturnType_Bool, ThisPointer_Address, ILocomotion_ShouldCollideWith);
	DHookAddParam(g_hShouldCollideWith, HookParamType_CBaseEntity);
	
	
	g_hGetSolidMask = DHookCreateEx(hConf, "IBody::GetSolidMask", HookType_Raw, ReturnType_Int, ThisPointer_Address, IBody_GetSolidMask);
	g_hGetActivity = DHookCreateEx(hConf, "IBody::GetActivity", HookType_Raw, ReturnType_Int, ThisPointer_Address, IBody_GetActivity);
	g_hGetHullWidth = DHookCreateEx(hConf, "IBody::GetHullWidth", HookType_Raw, ReturnType_Float, ThisPointer_Address, IBody_GetHullWidth);
	g_hGetHullHeight = DHookCreateEx(hConf, "IBody::GetHullHeight", HookType_Raw, ReturnType_Float, ThisPointer_Address, IBody_GetHullHeight);
	g_hGetStandHullHeight = DHookCreateEx(hConf, "IBody::GetStandHullHeight", HookType_Raw, ReturnType_Float, ThisPointer_Address, IBody_GetStandHullHeight);
	
	g_hIsActivity = DHookCreateEx(hConf, "IBody::IsActivity", HookType_Raw, ReturnType_Bool, ThisPointer_Address, IBody_IsActivity);
	DHookAddParam(g_hIsActivity, HookParamType_Int);
	
	g_hHasActivityType = DHookCreateEx(hConf, "IBody::HasActivityType", HookType_Raw, ReturnType_Bool, ThisPointer_Address, IBody_HasActivityType);
	DHookAddParam(g_hHasActivityType, HookParamType_Int);
	
	g_hStartActivity = DHookCreateEx(hConf, "IBody::StartActivity", HookType_Raw, ReturnType_Bool, ThisPointer_Address, IBody_StartActivity);
	DHookAddParam(g_hStartActivity, HookParamType_Int);
	DHookAddParam(g_hStartActivity, HookParamType_Int);
	
	
	g_hSetDesiredPosture = DHookCreateEx(hConf, "IBody::SetDesiredPosture", HookType_Raw, ReturnType_Void, ThisPointer_Address, IBody_SetDesiredPosture);
	DHookAddParam(g_hSetDesiredPosture, HookParamType_Int); //(IBody::PostureType)
	
	g_hGetDesiredPosture = DHookCreateEx(hConf, "IBody::GetDesiredPosture", HookType_Raw, ReturnType_Int, ThisPointer_Address, IBody_GetDesiredPosture);
	
	g_hIsDesiredPosture = DHookCreateEx(hConf, "IBody::IsDesiredPosture", HookType_Raw, ReturnType_Bool, ThisPointer_Address, IBody_IsDesiredPosture);
	DHookAddParam(g_hIsDesiredPosture, HookParamType_Int); //(IBody::PostureType)
	
	g_hIsInDesiredPosture = DHookCreateEx(hConf, "IBody::IsInDesiredPosture", HookType_Raw, ReturnType_Bool, ThisPointer_Address, IBody_IsInDesiredPosture);
	g_hGetActualPosture = DHookCreateEx(hConf, "IBody::GetActualPosture", HookType_Raw, ReturnType_Int, ThisPointer_Address, IBody_GetActualPosture);
	
	g_hIsActualPosture = DHookCreateEx(hConf, "IBody::IsActualPosture", HookType_Raw, ReturnType_Bool, ThisPointer_Address, IBody_IsActualPosture);
	DHookAddParam(g_hIsActualPosture, HookParamType_Int); //(IBody::PostureType)
	
	g_hIsPostureMobile = DHookCreateEx(hConf, "IBody::IsPostureMobile", HookType_Raw, ReturnType_Bool, ThisPointer_Address, IBody_IsPostureMobile);
	
	g_hEvent_Killed = DHookCreateEx(hConf, "CTFBaseBoss::Event_Killed", HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, CTFBaseBoss_Event_Killed);
	DHookAddParam(g_hEvent_Killed, HookParamType_Int); //( const CTakeDamageInfo &info )
	
	delete hConf;
}

public MRESReturn IBody_SetDesiredPosture(Address pThis, Handle hParams)
{
	int iPosture = DHookGetParam(hParams, 1);
	PrintToServer("IBody_SetDesiredPosture(%i)", iPosture);
	view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).SetDesiredPosture(iPosture);
	return MRES_Supercede;
}
public MRESReturn IBody_GetDesiredPosture(Address pThis, Handle hReturn, Handle hParams)
{
	//PrintToServer("IBody_GetDesiredPosture");
	DHookSetReturn(hReturn, view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).GetDesiredPosture());
	return MRES_Supercede;
}
public MRESReturn IBody_IsDesiredPosture(Address pThis, Handle hReturn, Handle hParams)
{
	int iPosture = DHookGetParam(hParams, 1);
	//PrintToServer("IBody_IsDesiredPosture(%i)", iPosture);
	DHookSetReturn(hReturn, view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).IsDesiredPosture(iPosture));
	return MRES_Supercede;
}
public MRESReturn IBody_IsInDesiredPosture(Address pThis, Handle hReturn, Handle hParams)
{
	//PrintToServer("IBody_IsInDesiredPosture");
	DHookSetReturn(hReturn, view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).IsInDesiredPosture());
	return MRES_Supercede;
}
public MRESReturn IBody_GetActualPosture(Address pThis, Handle hReturn, Handle hParams)
{
	//PrintToServer("IBody_GetActualPosture");
	DHookSetReturn(hReturn, view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).GetActualPosture());
	return MRES_Supercede;
}
public MRESReturn IBody_IsActualPosture(Address pThis, Handle hReturn, Handle hParams)
{
	int iPosture = DHookGetParam(hParams, 1);
	//PrintToServer("IBody_IsActualPosture(%i)", iPosture);
	DHookSetReturn(hReturn, view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).IsActualPosture(iPosture));
	return MRES_Supercede;
}
public MRESReturn IBody_IsPostureMobile(Address pThis, Handle hReturn, Handle hParams)
{
	//PrintToServer("IBody_IsPostureMobile");
	DHookSetReturn(hReturn, view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).IsPostureMobile());
	return MRES_Supercede;
}

Handle DHookCreateEx(Handle gc, const char[] key, HookType hooktype, ReturnType returntype, ThisPointerType thistype, DHookCallback callback)
{
	int iOffset = GameConfGetOffset(gc, key);
	if (iOffset == -1)
	{
		SetFailState("Failed to get offset of %s", key);
		return null;
	}
	
	return DHookCreate(iOffset, hooktype, returntype, thistype, callback);
}

public MRESReturn ILocomotion_GetGroundNormal(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturnVector(hReturn, view_as<float>( { 0.0, 0.0, 1.0 } )); return MRES_Supercede; }
public MRESReturn ILocomotion_GetStepHeight(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturn(hReturn, 18.0); return MRES_Supercede; }
public MRESReturn ILocomotion_GetMaxAcceleration(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturn(hReturn, 500.0); return MRES_Supercede; }
public MRESReturn ILocomotion_GetFrictionSideways(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturn(hReturn, 3.0); return MRES_Supercede; }
public MRESReturn ILocomotion_GetGravity(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturn(hReturn, 1000.0); return MRES_Supercede; }
public MRESReturn ILocomotion_ShouldCollideWith(Address pThis, Handle hReturn, Handle hParams)
{
	int otherindex = DHookGetParam(hParams, 1);
	
	if (otherindex > 0 && otherindex <= MaxClients)
	{
		DHookSetReturn(hReturn, true);
		return MRES_Supercede;
	}
	
	int entindex = SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis));
	
	bool bCollide = !PluginBot_IsEntityTraversable(entindex, otherindex, IMMEDIATELY);
	
	DHookSetReturn(hReturn, bCollide);
	
	return MRES_Supercede;
}
public MRESReturn ILocomotion_IsClimbingUpToLedge(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, (view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).IsClimbingUpToLedge()));
	return MRES_Supercede;
}
public MRESReturn ILocomotion_GetDesiredSpeed(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, (view_as<CZombieBotLocomotion>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).GetDesiredSpeed()));
	return MRES_Supercede;
}
public MRESReturn ILocomotion_GetRunSpeed(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, view_as<CZombieBotLocomotion>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).GetRunSpeed());
	return MRES_Supercede;
}
public MRESReturn IBody_GetSolidMask(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).GetSolidMask());
	return MRES_Supercede;
}


//2 * m_vecMaxs
public MRESReturn IBody_GetHullWidth(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).GetHullWidth());
	return MRES_Supercede;
}
public MRESReturn IBody_GetHullHeight(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).GetHullHeight());
	return MRES_Supercede;
}
public MRESReturn IBody_GetStandHullHeight(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).GetStandHullHeight());
	return MRES_Supercede;
}
public MRESReturn IBody_GetActivity(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).GetActivity());
	return MRES_Supercede;
}
public MRESReturn IBody_IsActivity(Address pThis, Handle hReturn, Handle hParams)
{
	int iActivity = DHookGetParam(hParams, 1);
	
	DHookSetReturn(hReturn, view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).IsActivity(iActivity));
	return MRES_Supercede;
}
public MRESReturn IBody_HasActivityType(Address pThis, Handle hReturn, Handle hParams)
{
	int flags = DHookGetParam(hParams, 1);
	
	DHookSetReturn(hReturn, view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).HasActivityType(flags));
	return MRES_Supercede;
}
public MRESReturn IBody_StartActivity(Address pThis, Handle hReturn, Handle hParams)
{
	int iActivity = DHookGetParam(hParams, 1);
	int fFlags = DHookGetParam(hParams, 2);
	
	DHookSetReturn(hReturn, view_as<CZombieBotBody>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).StartActivity(iActivity, fFlags));
	
	return MRES_Supercede;
}


stock bool IsLengthGreaterThan(float vector[3], float length)
{
	return (SquareRoot(GetVectorLength(vector, false)) > length * length);
}

public float clamp(float a, float b, float c) { return (a > c ? c : (a < b ? b : a)); }

public void InitNavGamedata()
{
	Handle hConf = LoadGameConfigFile("tf2.pets");
	
	navarea_count = GameConfGetAddress(hConf, "navarea_count");
	//PrintToServer("[CBaseActor] Found \"navarea_count\" @ 0x%X", navarea_count);
	
	if (LoadFromAddress(navarea_count, NumberType_Int32) <= 0)
	{
		SetFailState("[CBaseActor] No nav mesh!");
		return;
	}
	
	//TheNavAreas is nicely above navarea_count
	TheNavAreas = view_as<Address>(LoadFromAddress(navarea_count + view_as<Address>(0x4), NumberType_Int32));
	//PrintToServer("[CBaseActor] Found \"TheNavAreas\" @ 0x%X", TheNavAreas);
	
	delete hConf;
}

stock NavArea PickRandomArea()
{
	int iAreaCount = LoadFromAddress(navarea_count, NumberType_Int32);
	
	//Pick a random goal area
	return view_as<NavArea>(LoadFromAddress(TheNavAreas + view_as<Address>(4 * GetRandomInt(0, iAreaCount - 1)), NumberType_Int32));
}

public bool FilterBaseActorsAndData(int entity, int contentsMask, any data)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	
	if (StrEqual(class, "base_boss"))return false;
	if (StrEqual(class, "player"))return false;
	
	return !(entity == data);
}

public bool FilterBaseActorsAndDataButNotPlayer(int entity, int contentsMask, any data)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	
	if (StrEqual(class, "base_boss"))return false;
	
	return !(entity == data);
}


public bool PluginBot_IsEntityTraversable(int bot_entidx, int other_entidx, TraverseWhenType when)
{
	if (other_entidx == 0) {
		return false;
	}
	
	if (other_entidx > 0 && other_entidx <= MaxClients)
	{
		return true;
	}
	
	char className[64];
	GetEntityClassname(other_entidx, className, sizeof(className));
	
	if (StrEqual(className, "base_boss")) {
		return true;
	}
	
	if (StrEqual(className, "func_brush")) {
		return true;
	}
	
	//PrintToServer("IsEntityTraversable \"%s\" other %i when %i", className, other_entidx, when);
	
	if (StrContains(className, "prop_door") != -1
		 || StrContains(className, "func_door") != -1)
	{
		if (HasEntProp(other_entidx, Prop_Data, "m_eDoorState")
			 && GetEntProp(other_entidx, Prop_Data, "m_eDoorState") == 2) //DOOR_STATE_OPEN
		{
			return false;
		}
		
		return true;
	}
	
	if (when == IMMEDIATELY) {
		return false;
	}
	
	return false;
}

public void PluginBot_Approach(int bot_entidx, const float vec[3])
{
	CZombieBotBody body = view_as<CZombieBotBody>(bot_entidx);
	
	if (body.IsClimbingUpToLedge())
		return;
	
	CZombieBotLocomotion locomotion = view_as<CZombieBotLocomotion>(bot_entidx);
	
	locomotion.Approach(vec);
	
	if (locomotion.IsOnGround()) {
		locomotion.FaceTowards(vec);
	}
}

public bool PluginBot_Jump(int bot_entidx, float vecPos[3], const float dir[3])
{
	return view_as<CZombieBotLocomotion>(bot_entidx).ClimbUpToLedge(vecPos, dir, INVALID_ENT_REFERENCE);
}

//-----------------------------------------------------------------------------
// Purpose: Draw a colored 3D cross of the given size at the given position
//-----------------------------------------------------------------------------
stock void Cross3D(float position[3], float size, int r, int g, int b, float flDuration)
{
	//...
	static int g_iPathLaserModelIndex;
	if (g_iPathLaserModelIndex == 0) {
		g_iPathLaserModelIndex = PrecacheModel("materials/sprites/laserbeam.vmt");
	}
	
	Line(AddVectorFloatOnAxis(position, size, 0.0, 0.0), SubtractVectorFloatOnAxis(position, size, 0.0, 0.0), r, g, b, flDuration);
	Line(AddVectorFloatOnAxis(position, 0.0, size, 0.0), SubtractVectorFloatOnAxis(position, 0.0, size, 0.0), r, g, b, flDuration);
	Line(AddVectorFloatOnAxis(position, 0.0, 0.0, size), SubtractVectorFloatOnAxis(position, 0.0, 0.0, size), r, g, b, flDuration);
}

//-----------------------------------------------------------------------------
// Purpose: Draws a line from one position to another
//-----------------------------------------------------------------------------
stock void Line(float origin[3], float target[3], int r, int g, int b, float duration)
{
	static int g_iPathLaserModelIndex;
	if (g_iPathLaserModelIndex == 0) {
		g_iPathLaserModelIndex = PrecacheModel("materials/sprites/laserbeam.vmt");
	}
	
	int color[4];
	color[0] = r;
	color[1] = g;
	color[2] = b;
	color[3] = 255;
	
	TE_SetupBeamPoints(origin, target, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 0, duration, 0.5, 0.5, 5, 5.0, color, 30);
	TE_SendToAllInRange(origin, RangeType_Visibility);
}

stock float[] AddVectorFloatOnAxis(float vector[3], float x = 0.0, float y = 0.0, float z = 0.0)
{
	float v[3]; v = vector;
	
	v[0] += x;
	v[1] += y;
	v[2] += z;
	
	return v;
}

stock float[] SubtractVectorFloatOnAxis(float vector[3], float x = 0.0, float y = 0.0, float z = 0.0)
{
	float v[3]; v = vector;
	
	v[0] -= x;
	v[1] -= y;
	v[2] -= z;
	
	return v;
}

public void PluginBot_PathSuccess(int bot_entidx, Address path)
{
	PF_StopPathing(bot_entidx);
	view_as<CBaseActor>(bot_entidx).m_bHasValidPath = true;
	
}

public void PluginBot_PathFail(int bot_entidx, Address path, MoveToFailureType type)
{
	PF_StopPathing(bot_entidx);
	view_as<CBaseActor>(bot_entidx).m_bHasValidPath = false;
}

public void PluginBot_MoveToSuccess(int bot_entidx, Address path)
{
	PF_StopPathing(bot_entidx);
	view_as<CBaseActor>(bot_entidx).SetAcceleration(view_as<float>( { 0.0, 0.0, 0.0 } ));
	view_as<CBaseActor>(bot_entidx).SetVelocity(view_as<float>( { 0.0, 0.0, 0.0 } ));
	
}

public void PluginBot_MoveToFailure(int bot_entidx, Address path, MoveToFailureType type)
{
	PF_StopPathing(bot_entidx);
	view_as<CBaseActor>(bot_entidx).SetAcceleration(view_as<float>( { 0.0, 0.0, 0.0 } ));
	view_as<CBaseActor>(bot_entidx).SetVelocity(view_as<float>( { 0.0, 0.0, 0.0 } ));
}

stock float[] WorldSpaceCenter(int entity)
{
	float vecPos[3];
	SDKCall(g_hSDKWorldSpaceCenter, entity, vecPos);
	
	return vecPos;
}

stock float[] GetAbsOrigin(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", v);
	return v;
}

stock float[] GetAbsVelocity(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", v);
	return v;
}

stock bool IsAlive(int entity)
{
	return GetEntProp(entity, Prop_Data, "m_lifeState") == 0;
}

stock bool IsPlayer(int entity)
{
	return entity <= MaxClients;
}

stock int GetSolidFlags(int entity)
{
	return GetEntProp(entity, Prop_Send, "m_usSolidFlags");
}

stock int GetTeam(int entity)
{
	return GetEntProp(entity, Prop_Send, "m_iTeamNum");
}


//--------------------------------------------------------------------------------------------------------
/**
 * Return true if ground is fairly level within the given radius around an entity
 * Trace 4 vertical hull-quadrants and test their collisions and ground heights and normals
 */
stock bool UTIL_IsGroundLevel(float radius, const float position[3], float hullHeight, int mask, const int ignore)
{
	const int subdivisions = 3;
	const int samples = subdivisions * subdivisions;
	
	// trace down below floor level to detect ledges and overhangs
	Handle result[samples];
	float size = 2.0 * radius / subdivisions;
	
	int i, j, s = 0;
	float x, y = -radius;
	
	for (j = 0; j < subdivisions; ++j)
	{
		x = -radius;
		
		for (i = 0; i < subdivisions; ++i)
		{
			float start[3]; start = position;
			start[2] += hullHeight;
			
			float end[3]; end = position;
			end[2] -= 100.0;
			
			float probeMin[3];
			probeMin[0] = x;
			probeMin[1] = y;
			probeMin[2] = 0.0;
			
			float probeMax[3];
			probeMax[0] = x + size;
			probeMax[1] = y + size;
			probeMax[2] = 10.0;
			
			//Line(start, end, 0, 255, 0, 5.0);
			
			result[s] = TR_TraceHullFilterEx(start, end, probeMin, probeMax, mask, FilterBaseActorsAndData, ignore);
			
			/*	UTIL_TraceHull( position + Vector( 0, 0, hullHeight ), 
							position + Vector( 0, 0, -100 ), 
							Vector( x, y, 0 ), 
							Vector( x + size, y + size, 10.0 ), 
							mask, ignore, COLLISION_GROUP_PLAYER_MOVEMENT, 
							&result[ s ] );

			if ( debugTraces )
			{
				NDebugOverlay::SweptBox( position + Vector( 0, 0, hullHeight ), 
										 result[ s ].endpos, 
										 Vector( x, y, 0 ), 
										 Vector( x + size, y + size, 10.0f ), 
										 vec3_angle, 255, 255, 0, 255, 5.0f );
			}*/
			
			++s;
			x += size;
		}
		
		y += size;
	}
	
	for (i = 0; i < samples; ++i)
	{
		if (TR_StartSolid(result[i]))
		{
			return false;
		}
		
		if (TR_DidHit(result[i]))
		{
			const float flat = 0.9;
			
			float t_normal[3]; TR_GetPlaneNormal(result[i], t_normal);
			
			if (t_normal[2] < flat)
			{
				// too steep to sit here
				
				//PrintToServer("Too steep to sit here");
				
				return false;
			}
			
			const float maxZDelta = 10.0;
			
			float t_i_endpos[3]; TR_GetEndPosition(t_i_endpos, result[i]);
			
			for (j = 0; j < samples; ++j)
			{
				float t_j_endpos[3]; TR_GetEndPosition(t_j_endpos, result[j]);
				
				if (i != j && FloatAbs(t_i_endpos[2] - t_j_endpos[2]) > maxZDelta)
				{
					return false;
				}
			}
		}
	}
	
	return true;
}

stock float ApproachAngle(float target, float value, float speed)
{
	float delta = AngleDiff(target, value);
	
	// Speed is assumed to be positive
	if (speed < 0)
		speed = -speed;
	
	if (delta < -180)
		delta += 360;
	else if (delta > 180)
		delta -= 360;
	
	if (delta > speed)
		value += speed;
	else if (delta < -speed)
		value -= speed;
	else
		value = target;
	
	return value;
}

stock float AngleDiff(float destAngle, float srcAngle)
{
	float delta = fmodf(destAngle - srcAngle, 360.0);
	if (destAngle > srcAngle)
	{
		if (delta >= 180)
			delta -= 360;
	}
	else
	{
		if (delta <= -180)
			delta += 360;
	}
	
	return delta;
}

stock float fmodf(float num, float denom)
{
	return num - denom * RoundToFloor(num / denom);
}

stock float operator % (float oper1, float oper2)
{
	return fmodf(oper1, oper2);
} 