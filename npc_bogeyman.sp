#include <sdkhooks>
#include <dynamic>
#include <PathFollower>
#include <dhooks>
#include <navmesh>
#include <utilsext>

#pragma newdecls required

#define MODEL_NPC  "models/combine_soldier.mdl"//"models/vince_sf/bogeyman/bogeyman.mdl"
#define MODEL_SG   "models/weapons/w_shotgun.mdl"

//#define DEBUG

//Animations
#define ANIM_IDLE       "Idle1"
#define ANIM_COMBATIDLE "CombatIdle1_SG"

#define ANIM_WALK       "WalkEasy_ALL"
#define ANIM_COMBATWALK "RunAIMALL1_SG"

#define ANIM_SHOOT      "gesture_shoot_shotgun"
#define ANIM_FLINCH     "flinch_gesture"

//Speed
#define WALK_SPEED      77.907432
#define RUN_SPEED       246.997528

#define int(%1) view_as<int>(%1)

#define EF_BONEMERGE                (1 << 0)
#define EF_PARENT_ANIMATES          (1 << 9)

enum SolidType_t
{
	SOLID_NONE			= 0,	// no solid model
	SOLID_BSP			= 1,	// a BSP tree
	SOLID_BBOX			= 2,	// an AABB
	SOLID_OBB			= 3,	// an OBB (not implemented yet)
	SOLID_OBB_YAW		= 4,	// an OBB, constrained so that it can only yaw
	SOLID_CUSTOM		= 5,	// Always call into the entity for tests
	SOLID_VPHYSICS		= 6,	// solid vphysics object, get vcollide from the model and collide with that
	SOLID_LAST,
};

enum MoveToFailureType
{
	FAIL_INVALID_PATH = 0,
	FAIL_STUCK        = 1,
	FAIL_FELL_OFF     = 2,
};

//SDKCalls
Handle g_hStudioFrameAdvance;
Handle g_hDispatchAnimEvents;
Handle g_hMyNextBotPointer;
Handle g_hGetLocomotionInterface;
Handle g_hRun;
Handle g_hApproach;
Handle g_hFaceTowards;
Handle g_hResetSequence;

//DHooks
Handle g_hGetStepHeight;
Handle g_hGetGravity;
Handle g_hGetGroundNormal;
Handle g_hShouldCollideWith;
Handle g_hGetFrictionSideways;
Handle g_hGetFrictionForward;
Handle g_hOnMoveToSuccess;

int g_iPathLaserModelIndex = -1;

public Plugin myinfo = 
{
	name = "[TF2] Bogeyman NPC",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_bogeyman", Command_FastZombie, ADMFLAG_ROOT);
	RegAdminCmd("sm_npctome",  Command_ComeToMe,   ADMFLAG_ROOT);
	
	Handle hConf = LoadGameConfigFile("tf2.siryouarehunted");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseAnimating::StudioFrameAdvance");
	if ((g_hStudioFrameAdvance = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::StudioFrameAdvance offset!"); 
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseAnimating::DispatchAnimEvents");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((g_hDispatchAnimEvents = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::DispatchAnimEvents offset!"); 
	
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
	
	int iOffset = GameConfGetOffset(hConf, "CTFBaseBossLocomotion::GetStepHeight");
	if(iOffset == -1) SetFailState("Failed to get offset of CTFBaseBossLocomotion::GetStepHeight");
	g_hGetStepHeight = DHookCreate(iOffset, HookType_Raw, ReturnType_Float, ThisPointer_Address, NextBotGroundLocomotion_GetStepHeight);
	
	iOffset = GameConfGetOffset(hConf, "NextBotGroundLocomotion::GetGravity");
	if(iOffset == -1) SetFailState("Failed to get offset of NextBotGroundLocomotion::GetGravity");
	g_hGetGravity = DHookCreate(iOffset, HookType_Raw, ReturnType_Float, ThisPointer_Address, NextBotGroundLocomotion_GetGravity);
	
	iOffset = GameConfGetOffset(hConf, "NextBotGroundLocomotion::GetGroundNormal");
	if(iOffset == -1) SetFailState("Failed to get offset of NextBotGroundLocomotion::GetGroundNormal");
	g_hGetGroundNormal = DHookCreate(iOffset, HookType_Raw, ReturnType_VectorPtr, ThisPointer_Address, NextBotGroundLocomotion_GetGroundNormal);
	
	iOffset = GameConfGetOffset(hConf, "ILocomotion::ShouldCollideWith");
	if(iOffset == -1) SetFailState("Failed to get offset of ILocomotion::ShouldCollideWith");
	g_hShouldCollideWith = DHookCreate(iOffset, HookType_Raw, ReturnType_Bool, ThisPointer_Address, NextBotGroundLocomotion_ShouldCollideWith);
	DHookAddParam(g_hShouldCollideWith, HookParamType_CBaseEntity);
	
	iOffset = GameConfGetOffset(hConf, "NextBotGroundLocomotion::GetFrictionForward");
	if(iOffset == -1) SetFailState("Failed to get offset of NextBotGroundLocomotion::GetFrictionForward");
	g_hGetFrictionForward = DHookCreate(iOffset, HookType_Raw, ReturnType_Float, ThisPointer_Address, NextBotGroundLocomotion_GetFriction);
	
	iOffset = GameConfGetOffset(hConf, "NextBotGroundLocomotion::GetFrictionSideways");
	if(iOffset == -1) SetFailState("Failed to get offset of NextBotGroundLocomotion::GetFrictionSideways");
	g_hGetFrictionSideways = DHookCreate(iOffset, HookType_Raw, ReturnType_Float, ThisPointer_Address, NextBotGroundLocomotion_GetFriction);
	
	iOffset = GameConfGetOffset(hConf, "NextBotGroundLocomotion::OnMoveToSuccess");
	if(iOffset == -1) SetFailState("Failed to get offset of NextBotGroundLocomotion::GetFrictionSideways");
	g_hOnMoveToSuccess = DHookCreate(iOffset, HookType_Raw, ReturnType_Unknown, ThisPointer_Address, NextBotGroundLocomotion_OnMoveToSuccess);
	
	delete hConf;
	
	PrintToServer("*** npc_bogeyman loaded ***");
}

public void OnMapStart()
{
	PrecacheModel(MODEL_NPC);
	PrecacheModel(MODEL_SG);
	
	PrecacheSound("weapons/shotgun/shotgun_dbl_fire7.wav");
	
	g_iPathLaserModelIndex = PrecacheModel("materials/sprites/laserbeam.vmt");
}

enum State
{
	FLEE        = 1, //Running away, I go back to Attack or Hunt when I feel brave again.
	ATTACK      = 2, //2 seconds, Glimpsing the player and preparing to attack if the glimpse "matures" into a confirmed target sighting, making with the murder, I go to Hunt when I lose LOS.
	HUNT        = 3, //Where'd that target go, better chase it down, I go to Search when the trail gets too cold.
	INVESTIGATE = 4, //Heard something, go look. Switch to Search once I get where I am going.
	SEARCH      = 5, //Damn, don't see anything at this point of interest, start combing the area. If I find nothing after a while, back to Roam or Guard.
	GUARDING    = 6, //Hang around an area and protect it, only Hunters can do this and only to some objects. Squires and Poachers have a similar state called Patrol.
	ISLANDROAM  = 7, //I want to go on some trips around the island, this is my travel agent.
	IDLE        = 8, //Time to chill out with tea and heads while I decide where to go next.
}

methodmap NPC
{
	public NPC(float vecPos[3], float vecAng[3], float flVisionRange = 99999.0)
	{
		int npc = CreateEntityByName("base_boss");
		DispatchKeyValueVector(npc, "origin", vecPos);
		DispatchKeyValueVector(npc, "angles", vecAng);
		DispatchKeyValue(npc, "model", MODEL_NPC);
		DispatchKeyValue(npc, "modelscale", "1.15");
		DispatchKeyValue(npc, "health", "5000");
		DispatchSpawn(npc);
		
		SDKHook(npc, SDKHook_OnTakeDamage, OnNPCTakeDamage);
		
		SetEntPropFloat(npc, Prop_Send, "m_flPlaybackRate", 1.0);
		SetEntProp(npc, Prop_Data, "m_nSolidType", SOLID_BBOX);
		SetEntData(npc, FindSendPropInfo("CTFBaseBoss", "m_lastHealthPercentage") + 28, false, 4, true);	//ResolvePlayerCollisions
		
		ActivateEntity(npc);
		
		int sg = CreateEntityByName("prop_dynamic");
		DispatchKeyValueVector(sg, "origin", vecPos);
		DispatchKeyValueVector(sg, "angles", vecAng);
		DispatchKeyValue(sg, "model", MODEL_SG);
		DispatchKeyValue(sg, "modelscale", "1.15");
		DispatchSpawn(sg);
		
		SetEntProp(sg, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_PARENT_ANIMATES);
	
		SetVariantString("!activator");
		AcceptEntityInput(sg, "SetParent", npc);
		
		SetVariantString("anim_attachment_LH");
		AcceptEntityInput(sg, "SetParentAttachmentMaintainOffset"); 
		
		char strName[64];
		Format(strName, sizeof(strName), "npc_%x", EntIndexToEntRef(npc));
		
		Dynamic brain = Dynamic();
		brain.SetName(strName);
		brain.SetInt("State", int(ISLANDROAM));
		brain.SetInt("Target", -1);
		brain.SetInt("GoalEntity", -1);
		brain.SetBool("Pathing", false);
		brain.SetInt("Weapon", EntIndexToEntRef(sg));
		brain.SetFloat("NextAttack", -1.0);
		
		//Vision data
		brain.SetFloat("MaxVisionRange", flVisionRange);
		brain.SetFloat("TargetConfirmTime", -1.0);
		brain.SetFloat("LastTargetSighting", -1.0);
		brain.SetInt("LastSeenTarget", -1);
		brain.SetVector("LastKnownEnemyPosition", NULL_VECTOR);
		
		//Search data
		brain.SetVector("SearchPoint", NULL_VECTOR);
		brain.SetFloat("SearchAreaEndTime", -1.0);
		brain.SetBool("WaitingAtSpot", false);
		brain.SetFloat("SearchSpotTimeOut", -1.0);
		brain.SetVector("CurrentDestination", NULL_VECTOR);
		
		return view_as<NPC>(npc);
	}
	
	public Dynamic GetBrainInterface()
	{
		char strName[64];
		Format(strName, sizeof(strName), "npc_%x", EntIndexToEntRef(int(this)));
		
		return Dynamic.FindByName(strName);
	}
	
	property int State
	{
		public get()
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				return brain.GetInt("State");
			}

			return int(IDLE);
		}
		public set(int state)
		{ 
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				int CurrentState = brain.GetInt("State");
				
				if (CurrentState != state)
				{
					#if defined DEBUG
					PrintToChatAll("[%i] Set state: %i", this, state);
					#endif
					
					brain.SetInt("State", int(state)); 
				}
			}
		}
	}
	
	property float Speed
	{
		public get()            { return GetEntPropFloat(int(this), Prop_Data, "m_speed"); }
		public set(float speed) { SetEntPropFloat(int(this), Prop_Data, "m_speed", speed); }
	}
	
	property int Target
	{
		public get()			
		{
			int target = -1;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				target = brain.GetInt("Target");
			}
			
			return target;
		}
		public set(int target)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetInt("Target", target);
			}
		}
	}
	
	property int Weapon
	{
		public get()			
		{
			int ent = INVALID_ENT_REFERENCE;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				ent = EntRefToEntIndex(brain.GetInt("Weapon"));
			}
			
			return ent;
		}
		public set(int weapon)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetInt("Weapon", EntIndexToEntRef(weapon));
			}
		}
	}
	
	property int GoalEntity
	{
		public get()			
		{
			int GoalEntity = -1;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				GoalEntity = brain.GetInt("GoalEntity");
			}
			
			return GoalEntity;
		}
		public set(int GoalEntity)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetInt("GoalEntity", GoalEntity);
			}
		}
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
				brain.SetInt("Pathing", path);
			}
		}
	}
	
	property float MaxVisionRange
	{
		public get()			
		{
			float range;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				range = brain.GetFloat("MaxVisionRange");
			}
			
			return range;
		}
		public set(float range)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("MaxVisionRange", range);
			}
		}
	}
	
	property float NextAttack
	{
		public get()			
		{
			float time = GetGameTime();
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				time = brain.GetFloat("NextAttack");
			}
			
			return time;
		}
		public set(float time)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("NextAttack", time);
			}
		}
	}
	
	property float TargetConfirmTime
	{
		public get()			
		{
			float time = GetGameTime();
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				time = brain.GetFloat("TargetConfirmTime");
			}
			
			return time;
		}
		public set(float time)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("TargetConfirmTime", time);
			}
		}
	}
	
	property float LastTargetSighting
	{
		public get()			
		{
			float time = GetGameTime();
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				time = brain.GetFloat("LastTargetSighting");
			}
			
			return time;
		}
		public set(float time)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("LastTargetSighting", time);
			}
		}
	}
	
	property int LastSeenTarget
	{
		public get()			
		{
			int LastSeenTarget = -1;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				LastSeenTarget = brain.GetInt("LastSeenTarget");
			}
			
			return LastSeenTarget;
		}
		public set(int LastSeenTarget)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetInt("LastSeenTarget", LastSeenTarget);
			}
		}
	}
	
	public bool GetLastKnownEnemyPosition(float[3] value)
	{
		Dynamic brain = this.GetBrainInterface();
		if(!brain.IsValid)
			return false;
		
		brain.GetVector("LastKnownEnemyPosition", value);
		return true;
	}

	public void SetLastKnownEnemyPosition(const float[3] value)
	{
		Dynamic brain = this.GetBrainInterface();
		if(!brain.IsValid)
			return;
		
		brain.SetVector("LastKnownEnemyPosition", value);
	}
	
	public bool GetSearchPoint(float[3] value)
	{
		Dynamic brain = this.GetBrainInterface();
		if(!brain.IsValid)
			return false;
		
		brain.GetVector("SearchPoint", value);
		return true;
	}

	public void SetSearchPoint(const float[3] value)
	{
		Dynamic brain = this.GetBrainInterface();
		if(!brain.IsValid)
			return;
		
		brain.SetVector("SearchPoint", value);
	}
	
	public bool GetCurrentDestination(float[3] value)
	{
		Dynamic brain = this.GetBrainInterface();
		if(!brain.IsValid)
			return false;
		
		brain.GetVector("CurrentDestination", value);
		return true;
	}

	public void SetCurrentDestination(const float[3] value)
	{
		Dynamic brain = this.GetBrainInterface();
		if(!brain.IsValid)
			return;
		
		brain.SetVector("CurrentDestination", value);
	}
	
	property float SearchAreaEndTime
	{
		public get()			
		{
			float time = GetGameTime();
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				time = brain.GetFloat("SearchAreaEndTime");
			}
			
			return time;
		}
		public set(float time)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("SearchAreaEndTime", time);
			}
		}
	}
	
	property float SearchSpotTimeOut
	{
		public get()			
		{
			float time = GetGameTime();
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				time = brain.GetFloat("SearchSpotTimeOut");
			}
			
			return time;
		}
		public set(float time)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("SearchSpotTimeOut", time);
			}
		}
	}
	
	public void SetAnimation(const char[] anim)
	{
		int iSequence = utils_EntityLookupSequence(int(this), anim);
		if(iSequence != -1)
			SDKCall(g_hResetSequence, this, iSequence);
			
		#if defined DEBUG
		PrintToChatAll("[%i] SetAnimation %s %i", this, anim, iSequence);
		#endif
	}
	
	public void PlayGesture(const char[] anim)
	{
		int iNPC = int(this);
		
		int iAnim = utils_EntityLookupSequence(iNPC, anim);
		AnimOverlayHandler handler = AnimOverlayHandler(iNPC);
		handler.AddGestureSequence(iAnim);
	}
	
	public void Approach(const float[3] flGoal)
	{
		Address pNB =         SDKCall(g_hMyNextBotPointer, this);
		Address pLocomotion = SDKCall(g_hGetLocomotionInterface, pNB);
		SDKCall(g_hRun,          pLocomotion);
		SDKCall(g_hApproach,     pLocomotion, flGoal, 1.0);
		
		//Only face towards goal path if we dont have target
		if(this.Target == -1)
		{
			SDKCall(g_hFaceTowards,  pLocomotion, flGoal);
		}
		
		int iNPC = int(this);
		float flOrigin[3], flAbsAngles[3];
		Entity_GetAbsOrigin(iNPC, flOrigin);
		GetEntPropVector(iNPC, Prop_Data, "m_angRotation", flAbsAngles);
		
		float vecDir[3];
		MakeVectorFromPoints(flOrigin, flGoal, vecDir);
		
		//Strafe controller
		float flMoveYaw = VecToYaw(vecDir);
		float flDiff = AngleDiff(flMoveYaw, VecAxis(flAbsAngles, 1));
		
		int index = utils_EntityLookupPoseParameter(iNPC, "move_yaw");
		float pose = utils_StudioGetPoseParameter(iNPC, index, GetEntPropFloat(iNPC, Prop_Send, "m_flPoseParameter", index));
		
		float newpose;
		utils_StudioSetPoseParameter(iNPC, index, ApproachAngle(flDiff, pose, 5.0), newpose);
		SetEntPropFloat(iNPC, Prop_Send, "m_flPoseParameter", newpose, index);
	}
	
	public void Update()
	{
		int iNPC = int(this);
		int iTarget = this.Target;
		int iState = this.State;
		
		if(iTarget > 0)
		{
			float flTargetPos[3];
			GetClientAbsOrigin(iTarget, flTargetPos);
			
			Address pNB =         SDKCall(g_hMyNextBotPointer, iNPC);
			Address pLocomotion = SDKCall(g_hGetLocomotionInterface, pNB);
			
			SDKCall(g_hFaceTowards,  pLocomotion, flTargetPos);
		
			float flNextAttack = this.NextAttack - GetGameTime();
			if (flNextAttack <= 0.0)
			{						
				int iWeapon = this.Weapon;
				if(iWeapon != INVALID_ENT_REFERENCE)
				{
					float flGunPos[3], flGunAng[3];
					utils_EntityGetAttachment(iWeapon, utils_EntityLookupAttachment(iWeapon, "muzzle"), flGunPos, flGunAng);
					CreateParticle("muzzle_shotgun", flGunPos, flGunAng);
					
					GetAngleVectors(flGunAng, flGunAng, NULL_VECTOR, NULL_VECTOR);
					
					FireBulletsInfo_t info = utils_CreateFireBulletsInfo();
					info.iShots = 10;
					info.SetVecSrc(flGunPos);
					info.SetVecDirShooting(flGunAng);
					info.SetVecSpread(view_as<float>({0.08, 0.08, 0.08}));
					info.flDistance = 8192.0;
					info.iAmmoType = 1;
					info.iTracerFreq = 1;
					info.iDamage = 10;
					info.iPlayerDamage = 5;
					info.nFlags = FIRE_BULLETS_TEMPORARY_DANGER_SOUND;
					info.flDamageForceScale = 0.0;
					info.bPrimaryAttack = true;
					utils_EntityFireBullets(iNPC, info);
					delete info;
				}
				
				this.PlayGesture(ANIM_SHOOT);
				
				EmitSoundToAll("weapons/shotgun/shotgun_dbl_fire7.wav", int(this), SNDCHAN_WEAPON);
				this.NextAttack = GetGameTime() + 1.0;
			}
		}
		
		SDKCall(g_hStudioFrameAdvance, iNPC);
		SDKCall(g_hDispatchAnimEvents, iNPC, iNPC);
		
		this.Speed = GetEntPropFloat(iNPC, Prop_Data, "m_flGroundSpeed");
		
		float vecEyePos[3], vecEyeAngles[3];
		Entity_GetEyePosition(iNPC, vecEyePos);
		GetEntPropVector(iNPC, Prop_Data, "m_angRotation", vecEyeAngles);
		
		//Constantly keep a list of all the players in our vision.
		int iPlayerArray[MAXPLAYERS+1];
		int iPlayerCount;
		
		if(!FindConVar("nb_blind").BoolValue)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i)/* && IsFakeClient(i)*/)
				{
					bool bVisible = IsInFieldOfViewAndVisible(iNPC, vecEyePos, vecEyeAngles, i, 0.5, this.MaxVisionRange);			
					if(bVisible/* && PF_IsPathToEntityPossible(iNPC, i)*/)
					{
						iPlayerArray[iPlayerCount] = i;
						iPlayerCount++;
					}
				}
			}
		}
		
		if(iPlayerCount > 0)
		{
			if(iState != int(ATTACK))
			{
				this.LastTargetSighting = GetGameTime();
				this.TargetConfirmTime = GetGameTime() + 2.0;
				this.State = int(ATTACK);
				
				float flBestDistance = 99999.0;
				int iBestTarget = -1;
			
				for (int i = 0; i < iPlayerCount; i++)
				{
					float flPos[3];
					GetClientEyePosition(iPlayerArray[i], flPos);
					
					float flDistance = GetVectorDistance(vecEyePos, flPos);
					if(flDistance < flBestDistance)
					{
						flBestDistance = flDistance;
						iBestTarget = iPlayerArray[i];
					}
				}
				
				if(iTarget != iBestTarget)
				{
					//Set last seen target.
					this.LastSeenTarget = iBestTarget;
					
					this.Target = iBestTarget;
					
					#if defined DEBUG
					Annotate(iNPC, "State: ATTACK");
					#endif
				}
			}
		}
		
		switch(iState)
		{
			case IDLE:
			{
				//Can't have targets while idling
				this.Target = -1;
				this.GoalEntity = -1;
				
				//Stop pathing if we were pathing
				if(this.Pathing)
				{
					PF_StopPathing(iNPC);
					
					#if defined DEBUG
					PrintToChatAll("[%i] Stop Pathing: Idle", this);
					#endif
					
					this.SetAnimation(ANIM_IDLE);
					this.Pathing = false;
				}
			}
			case ATTACK: //2 seconds, Glimpsing the player and preparing to attack if the glimpse "matures" into a confirmed target sighting, making with the murder, I go to Hunt when I lose LOS.
			{
				//Our target is no longer valid or has died, back to idle.
				if(iTarget <= 0 || iTarget > MaxClients || !IsClientInGame(iTarget) || !IsPlayerAlive(iTarget))
				{
					this.SetCurrentDestination(NULL_VECTOR);
					this.SetLastKnownEnemyPosition(NULL_VECTOR);
					this.Target = -1;
					this.GoalEntity = -1;
					PF_SetGoalVector(iNPC, view_as<float>({0.0, 0.0, 0.0}));	
					PF_StopPathing(iNPC);
					this.Pathing = false;
					this.State = int(ISLANDROAM);
					
					this.SetAnimation(ANIM_IDLE);
					
					#if defined DEBUG
					Annotate(iNPC, "State: ISLANDROAM");
					#endif
					
					return;
				}
				
				//Gotta have a registered pathfollower in order to chase anything.
				if(PF_Exists(iNPC))
				{
					bool bLOS = IsEntityVisible(iNPC, iTarget);
				
					//Update the last known target position
					if(bLOS)
					{
						//We don't want our goal position to be unreachable
						if(GetEntityFlags(iTarget) & FL_ONGROUND)
						{
							float vecTargetPos[3];
							GetClientAbsOrigin(iTarget, vecTargetPos);
							this.SetLastKnownEnemyPosition(vecTargetPos);
						}
						
						float flTargetPos[3], flNPCPos[3];
						GetClientAbsOrigin(iTarget, flTargetPos);
						Entity_GetAbsOrigin(iNPC, flNPCPos);
				/*		if (GetVectorDistance(flTargetPos, flNPCPos) <= 500.0)
						{
							if(this.Pathing)
							{
								PF_StopPathing(iNPC);
								this.Pathing = false;
								this.SetAnimation(ANIM_COMBATIDLE);
							}
						}
						else if(!this.Pathing)
						{
							PF_StartPathing(iNPC);
							this.SetAnimation(ANIM_COMBATWALK);
						}*/
						
						//Pitch controller
						float v[3], ang[3], vecTargetPos[3];
						GetClientAbsOrigin(iTarget, vecTargetPos);
						
						SubtractVectors(vecTargetPos, flNPCPos, v); 
						NormalizeVector(v, v);
						GetVectorAngles(v, ang); 
						
						int iPitch = utils_EntityLookupPoseParameter(iNPC, "aim_pitch");
						float flPitch = utils_StudioGetPoseParameter(iNPC, iPitch, GetEntPropFloat(iNPC, Prop_Send, "m_flPoseParameter", iPitch));
						
						if (ang[0] > 180.0) 
							ang[0] -= 360.0;
						
						if(ang[0] > 90.0)
							ang[0] = 90.0;
						else if(ang[0] < -90.0)
							ang[0] = -90.0
						
						float flNewPitch;
						utils_StudioSetPoseParameter(iNPC, iPitch, ApproachAngle(ang[0], flPitch, 0.5), flNewPitch);
						SetEntPropFloat(iNPC, Prop_Send, "m_flPoseParameter", flNewPitch, iPitch);
					}
					else
					{
						//Lost Line of Sight, start hunt.
						this.State = int(HUNT);
						this.Pathing = true;
						
						#if defined DEBUG
						Annotate(iNPC, "State: HUNT");
						PrintToChatAll("[%i] Line of sigh lost: Go to last known enemy position", this);
						#endif
						
						float vecTargetPos[3];
						this.GetLastKnownEnemyPosition(vecTargetPos);
						
						PF_SetGoalVector(iNPC, vecTargetPos);
						PF_StartPathing(iNPC);
					}
				
					//Chase our known target. If we don't have a goal entity, set our goal entity to our target.
					if(this.GoalEntity != iTarget)
					{
					//	this.Speed = RUN_SPEED;
						
						#if defined DEBUG
						PrintToChatAll("[%i] Target aquired: chase them (%N)", this, iTarget);
						#endif
						
						PF_SetGoalEntity(iNPC, iTarget);
						PF_StartPathing(iNPC);
						
						this.SetAnimation(ANIM_COMBATWALK);
						
						this.GoalEntity = iTarget;
						this.Pathing = true;
					}
				}
			}
			case HUNT:   //Where'd that target go, better chase it down, I go to Search when the trail gets too cold.
			{
				//No targets, go to last know targets position.
				this.Target = -1;
				this.GoalEntity = -1;
					
				float vecTargetPos[3];
				this.GetLastKnownEnemyPosition(vecTargetPos);
					
				float vecMyOrigin[3];
				Entity_GetAbsOrigin(iNPC, vecMyOrigin);
					
				if(GetVectorDistance(vecMyOrigin, vecTargetPos) <= 60.0)
				{
					//Once we arrive, start searching the area.
					#if defined DEBUG
					Annotate(iNPC, "State: SEARCH");
					PrintToChatAll("[%i] Arrived at last know enemy position", this);
					#endif
					
					PF_SetGoalVector(iNPC, vecTargetPos);
					PF_StartPathing(iNPC);
					
					this.Pathing = true;
					this.SetAnimation(ANIM_COMBATWALK);
					this.State = int(SEARCH);
					
					this.SetCurrentDestination(vecTargetPos);
					this.SetSearchPoint(vecTargetPos);
					this.SearchSpotTimeOut = GetGameTime() + 2.0;
					this.SearchAreaEndTime = GetGameTime() + 10.0; //Search last known position, then go back to roam or guard
				}
			}
			case SEARCH:
			{
				//Is it time to carry on?
				float flSearchAreaEndTime = this.SearchAreaEndTime - GetGameTime();
				if(flSearchAreaEndTime <= 0.0)
				{
					this.SetSearchPoint(NULL_VECTOR);
					this.SetCurrentDestination(NULL_VECTOR);
					this.SetLastKnownEnemyPosition(NULL_VECTOR);
					this.Target = -1;
					this.GoalEntity = -1;	
					this.State = int(ISLANDROAM);
					this.Pathing = false;
					PF_StopPathing(iNPC);
					
					#if defined DEBUG
					PrintToChatAll("[%i] Search timeout: Time to stop searching.", this);
					Annotate(iNPC, "State: ISLANDROAM");
					#endif
					
					return;
				}
			
				float vecSearchPos[3];
				this.GetSearchPoint(vecSearchPos);
				
				#if defined DEBUG
				TE_ShowPole(vecSearchPos, { 0, 255, 255, 255 } );
				#endif
				
				float vecMyOrigin[3], vecCurrentDestination[3];
				Entity_GetAbsOrigin(iNPC, vecMyOrigin);
				this.GetCurrentDestination(vecCurrentDestination);
				
				if(GetVectorDistance(vecMyOrigin, vecCurrentDestination) <= 60.0)
				{
					//Arrived at random location near our search position, hang around for 2 seconds and then pick new spot.
					if(this.Pathing)
					{
						PF_StopPathing(iNPC);
						this.Pathing = false;
						this.SetAnimation(ANIM_IDLE);
						this.SearchSpotTimeOut = GetGameTime() + 2.0;
					}

					//Have we searched this pos long enough?
					float flNextSpotPickTime = this.SearchSpotTimeOut - GetGameTime();
					if(flNextSpotPickTime <= 0.0)
					{
						#if defined DEBUG
						PrintToChatAll("[%i] Pick new search spot", this);
						#endif
						
						//Pick new spot to walk to in our search area
						CNavArea iTargetAreaIndex = NavMesh_GetNearestArea(vecSearchPos);
						if (iTargetAreaIndex != INVALID_NAV_AREA)
						{
							// Search outwards until travel distance is at maximum range.
							Handle hAreaArray = CreateArray(2);
							ArrayStack hAreas = CreateStack();
							NavMesh_CollectSurroundingAreas(hAreas, iTargetAreaIndex, 600.0, 1000.0, 10000.0);
							{
								while (!IsStackEmpty(hAreas))
								{
									int iAreaIndex = -1;
									PopStackCell(hAreas, iAreaIndex);
									int iIndex = PushArrayCell(hAreaArray, iAreaIndex);
									SetArrayCell(hAreaArray, iIndex, float(iTargetAreaIndex.CostSoFar), 1);
								}
								
								delete hAreas;
							}
							
							CNavArea iArea = view_as<CNavArea>(GetArrayCell(hAreaArray, GetRandomInt(0, GetArraySize(hAreaArray) - 1)));
							float flAreaCenter[3];
							iArea.GetRandomPoint(flAreaCenter);
							
							flAreaCenter[2] += 10.0;
							
							if (PF_IsPathToVectorPossible(iNPC, flAreaCenter))
							{
								PF_SetGoalVector(iNPC, flAreaCenter);
								PF_StartPathing(iNPC);
								
								this.Pathing = true;
								this.SetCurrentDestination(flAreaCenter);
								this.SetAnimation(ANIM_COMBATWALK);
								
								#if defined DEBUG
								TE_ShowPole(flAreaCenter, {255, 0, 0, 255}, 10.0);
								PrintToChatAll("[%i] Travelling to new search spot (%f %f %f Distance %.2f)", this, flAreaCenter[0], flAreaCenter[1], flAreaCenter[2], GetVectorDistance(vecSearchPos, flAreaCenter));
								#endif
							}
						}
					}
				}
			}
			case ISLANDROAM:
			{
				float vecMyOrigin[3], vecMyDestination[3];
				Entity_GetAbsOrigin(iNPC, vecMyOrigin);
				this.GetCurrentDestination(vecMyDestination);
				
		//		PrintToServer("GetCurrentDestination %f %f %f DISTANCE %f", vecMyDestination[0], vecMyDestination[1], vecMyDestination[2], GetVectorDistance(vecMyOrigin, vecMyDestination));
				
				#if defined DEBUG
				TE_ShowPole(vecMyDestination, {255, 255, 0, 255});
				#endif
				
				if(GetVectorDistance(vecMyOrigin, vecMyDestination) <= 60.0 || (vecMyDestination[0] == 0.0 && vecMyDestination[1] == 0.0) || !this.Pathing)
				{
					//Pick a random spot to walk to.
					CNavArea iTargetAreaIndex = NavMesh_GetNearestArea(vecEyePos);
					if (iTargetAreaIndex != INVALID_NAV_AREA)
					{					
						// Search outwards until travel distance is at maximum range.
						Handle hAreaArray = CreateArray(2);
						ArrayStack hAreas = CreateStack();

						NavMesh_CollectSurroundingAreas(hAreas, iTargetAreaIndex, 10000.0, 10000.0, 10000.0);
						{
							while (!IsStackEmpty(hAreas))
							{
								int iAreaIndex = -1;
								PopStackCell(hAreas, iAreaIndex);
								int iIndex = PushArrayCell(hAreaArray, iAreaIndex);
								SetArrayCell(hAreaArray, iIndex, float(NavMeshArea_GetCostSoFar(iAreaIndex)), 1);
							}
							
							delete hAreas;
						}
						
						CNavArea iArea = view_as<CNavArea>(GetArrayCell(hAreaArray, GetRandomInt(0, GetArraySize(hAreaArray) - 1)));
						float flAreaCenter[3];
						iArea.GetRandomPoint(flAreaCenter);
						
						flAreaCenter[2] += 30.0;
						
						if (PF_IsPathToVectorPossible(iNPC, flAreaCenter))
						{
							PF_SetGoalVector(iNPC, flAreaCenter);
							PF_StartPathing(iNPC);
							
							this.Pathing = true;
							this.SetCurrentDestination(flAreaCenter);
							this.SetAnimation(ANIM_WALK);
						//	this.Speed = WALK_SPEED;	//walk speed
							
							#if defined DEBUG
							PrintToServer("[%i] Roaming to a random spot. (Distance %.2f)", this, GetVectorDistance(vecEyePos, flAreaCenter));
							TE_ShowPole(flAreaCenter, {255, 0, 0, 255}, 10.0);
							#endif
						}
					}
				}
			}
		}
	}
	
	public Action OnTakeDamage(int &attacker, int &inflictor, float &damage, int &damagetype)
	{
		if(attacker > 0 && attacker <= MaxClients)
		{
			if(this.State != int(ATTACK))
			{
				this.PlayGesture(ANIM_FLINCH);
			
				float flDamagePos[3];
				Entity_GetAbsOrigin(attacker, flDamagePos);
				
				CNavArea iArea = NavMesh_GetNearestArea(flDamagePos);
				if(iArea != INVALID_NAV_AREA)
					iArea.GetRandomPoint(flDamagePos);
				else
					return Plugin_Continue;
				
				//Got shot, start hunt.
				#if defined DEBUG
				Annotate(int(this), "State: HUNT");
				#endif
				
				this.State = int(HUNT);
				this.Pathing = true;
			//	this.Speed = RUN_SPEED;
				this.SetAnimation(ANIM_COMBATWALK);
				
				this.SetCurrentDestination(flDamagePos);
				this.SetLastKnownEnemyPosition(flDamagePos);
				this.SetSearchPoint(flDamagePos);
				this.SearchSpotTimeOut = GetGameTime() + 2.0;
				this.SearchAreaEndTime = GetGameTime() + 10.0; //Search last known position, then go back to roam or guard
				
				PF_SetGoalVector(int(this), flDamagePos);
				PF_StartPathing(int(this));
			}
		}
		
		return Plugin_Continue;
	}
}

public Action OnNPCTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	return (view_as<NPC>(victim)).OnTakeDamage(attacker, inflictor, damage, damagetype);
}

public void BirdThink(int iEntity)
{
	(view_as<NPC>(iEntity)).Update();
}

public Action Command_FastZombie(int client, int args)
{
	float vecPos[3], vecAng[3];
	GetAimPos(client, vecPos);
	GetClientEyeAngles(client, vecAng);
	vecAng[0] = 0.0;
	
	int zombie = int(NPC(vecPos, vecAng, 1700.0));

	SetEntityFlags(zombie, FL_NOTARGET);
	
	SetEntProp(zombie, Prop_Send, "m_nSkin", GetRandomInt(0, 1));
	SetEntPropVector(zombie, Prop_Send, "m_vecMaxs", view_as<float>({ 10.0, 10.0, 80.0 }));
	SetEntPropVector(zombie, Prop_Send, "m_vecMins", view_as<float>({ -10.0, -10.0, 0.0 }));
	
	PF_Create(zombie, 18.0, 18.0, 18.0, 0.6, MASK_PLAYERSOLID, 300.0, 0.2, 3.0);
	PF_EnableCallback(zombie, PFCB_Approach, PluginBot_Approach);

	Address pNB =         SDKCall(g_hMyNextBotPointer,        zombie);
	Address pLocomotion = SDKCall(g_hGetLocomotionInterface,  pNB);

	if(pLocomotion != Address_Null)	
	{
		DHookRaw(g_hGetStepHeight,       true, pLocomotion);
		DHookRaw(g_hGetGravity,          true, pLocomotion);
		DHookRaw(g_hGetGroundNormal,     true, pLocomotion);
		DHookRaw(g_hShouldCollideWith,   true, pLocomotion);
		DHookRaw(g_hGetFrictionSideways, true, pLocomotion);
		DHookRaw(g_hGetFrictionForward,  true, pLocomotion);
		DHookRaw(g_hOnMoveToSuccess,     true, pLocomotion);
	}
	
	SDKHook(zombie, SDKHook_Think, BirdThink);

	return Plugin_Handled;
}

public Action Command_ComeToMe(int client, int args)
{
	int iCount = 0;

	int ent = -1;
	while((ent = FindEntityByClassname(ent, "base_boss")) != -1)
	{		
		NPC npc = view_as<NPC>(ent);
		Dynamic brain = npc.GetBrainInterface();
		
		if(brain.IsValid)
		{
			iCount++;
		
			float flPos[3];
			GetClientAbsOrigin(client, flPos);
			CNavArea iArea = NavMesh_GetNearestArea(flPos);
			iArea.GetRandomPoint(flPos);
			
			npc.State = int(HUNT);
			npc.Pathing = true;
			npc.Speed = RUN_SPEED;
			npc.SetAnimation(ANIM_COMBATWALK);
			
			npc.SetCurrentDestination(flPos);
			npc.SetLastKnownEnemyPosition(flPos);
			npc.SetSearchPoint(flPos);
			npc.SearchSpotTimeOut = GetGameTime() + 2.0;
			npc.SearchAreaEndTime = GetGameTime() + 10.0; //Search last known position, then go back to roam or guard
			
			PF_SetGoalVector(int(npc), flPos);
			PF_StartPathing(int(npc));
		}
	}
	
	ReplyToCommand(client, "[SM] Commanded %d NPC's", iCount);
	
	return Plugin_Handled;
}

public void PluginBot_Approach(int bot_entidx, const float vec[3])
{
	NPC npc = view_as<NPC>(bot_entidx);
	npc.Approach(vec);
}

public void OnEntityDestroyed(int entity)
{
	if(entity > MaxClients && entity <= 2048)
	{
		NPC zombie = view_as<NPC>(entity);
		Dynamic brain = zombie.GetBrainInterface();
		
		if(brain.IsValid)
		{
			DeAnnotate(entity);
			brain.Dispose();
		}
	}
}

public MRESReturn NextBotGroundLocomotion_GetStepHeight(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, 25.0);
	
	return MRES_Supercede;
}

public MRESReturn NextBotGroundLocomotion_GetGravity(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, 800.0);
	
	return MRES_Supercede;
}

public MRESReturn NextBotGroundLocomotion_GetFriction(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, 6.0);
	
	return MRES_Supercede;
}

public MRESReturn NextBotGroundLocomotion_GetGroundNormal(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturnVector(hReturn, view_as<float>( { 0.0, 0.0, 1.0 } ));

	return MRES_Supercede;
}

public MRESReturn NextBotGroundLocomotion_OnMoveToSuccess(Address pThis, Handle hReturn, Handle hParams)
{
	PrintToServer("Hi boi");
	
	return MRES_Ignored;
}

public MRESReturn NextBotGroundLocomotion_ShouldCollideWith(Address pThis, Handle hReturn, Handle hParams)
{
	int iEntity = DHookGetParam(hParams, 1);
	if (IsValidEntity(iEntity))
	{
		char strClass[32];
		GetEdictClassname(iEntity, strClass, sizeof(strClass));
		if(StrEqual(strClass, "base_boss"))
		{
			DHookSetReturn(hReturn, false);
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

stock void Annotate(int entity, char[] strMsg)
{
	float flPos[3];
	Entity_GetEyePosition(entity, flPos);

	Event event = CreateEvent("show_annotation");
	event.SetFloat("worldPosX", flPos[0]);
	event.SetFloat("worldPosY", flPos[1]);
	event.SetFloat("worldPosZ", flPos[2]);
	event.SetInt("follow_entindex", entity);
	event.SetFloat("lifetime", 30.0);
	event.SetInt("id", entity + 8750);
	event.SetString("text", strMsg);
	event.SetString("play_sound", "vo/null.wav");
	event.SetString("show_effect", "0");
	event.SetString("show_distance", "0");
	event.Fire(false);
}

stock void DeAnnotate(int entity)
{
	Event event = CreateEvent("hide_annotation");
	event.SetInt("id", entity + 8750);
	event.Fire(false);
}

stock bool IsEntityVisible(int iLooker, int iEntity, float flMaxDistance = 9999.0)
{
	float vecEyePosition[3]
	Entity_GetEyePosition(iLooker, vecEyePosition);

	float vecAbsOrigin[3];
	Entity_GetAbsOrigin(iEntity, vecAbsOrigin);
	if(IsPointVisible(iLooker, vecEyePosition, vecAbsOrigin, flMaxDistance))
		return true;

	float vecCenter[3];
	Entity_GetCenter(iEntity, vecCenter);
	if(IsPointVisible(iLooker, vecEyePosition, vecCenter, flMaxDistance))
		return true;

	float vecEntityEyePosition[3];
	Entity_GetEyePosition(iEntity, vecEntityEyePosition);
	return (IsPointVisible(iLooker, vecEyePosition, vecEntityEyePosition, flMaxDistance));
}

stock bool IsInFieldOfViewAndVisible(int iLooker, float vecEyePosition[3], float vecEyeAngles[3], int iEntity, float flTolerance = -1.0, float flMaxDistance = 9999.0)
{
	float vecForward[3];
	GetAngleVectors(vecEyeAngles, vecForward, NULL_VECTOR, NULL_VECTOR);

	// Check 3 spots, or else when standing right next to someone looking at their eyes, 
	// the angle will be too great to see their center.
	float vecToTarget[3];
	float vecAbsOrigin[3];
	Entity_GetAbsOrigin(iEntity, vecAbsOrigin);
	SubtractVectors(vecAbsOrigin, vecEyePosition, vecToTarget);
	NormalizeVector(vecToTarget, vecToTarget);
	if(GetVectorDotProduct(vecForward, vecToTarget) >= flTolerance && IsPointVisible(iLooker, vecEyePosition, vecAbsOrigin, flMaxDistance))
		return true;

	float vecCenter[3];
	Entity_GetCenter(iEntity, vecCenter);
	SubtractVectors(vecCenter, vecEyePosition, vecToTarget);
	NormalizeVector(vecToTarget, vecToTarget);
	if(GetVectorDotProduct(vecForward, vecToTarget) >= flTolerance && IsPointVisible(iLooker, vecEyePosition, vecCenter, flMaxDistance))
		return true;

	float vecEntityEyePosition[3];
	Entity_GetEyePosition(iEntity, vecEntityEyePosition);
	SubtractVectors(vecEntityEyePosition, vecEyePosition, vecToTarget);
	NormalizeVector(vecToTarget, vecToTarget);
	return (GetVectorDotProduct(vecForward, vecToTarget) >= flTolerance && IsPointVisible(iLooker, vecEyePosition, vecEntityEyePosition, flMaxDistance));
}

stock float Entity_GetEyePosition(int iEntity, float flOut[3])
{
	if(iEntity > 0 && iEntity <= MaxClients && IsClientInGame(iEntity))
	{
		GetClientEyePosition(iEntity, flOut);
	}
	else
	{
		float flMaxs[3], flOrigin[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", flOrigin);
		GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", flMaxs);
		
		flOut[0] = flOrigin[0];
		flOut[1] = flOrigin[1];
		flOut[2] = flOrigin[2] += flMaxs[2];
	}
}

stock float Entity_GetCenter(int iEntity, float flOut[3])
{
	float flMaxs[3], flOrigin[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", flOrigin);
	GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", flMaxs);
	
	flOut[0] = flOrigin[0];
	flOut[1] = flOrigin[1];
	flOut[2] = flOrigin[2] -= (flMaxs[2] / 2);
}

stock float Entity_GetAbsOrigin(int iEntity, float flOut[3])
{
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", flOut);
}

stock bool IsPointVisible(int iExclude, float flStart[3], float vecPoint[3], float flDistance = 9999.0)
{
	bool bSee = true;
	
	if(GetVectorDistance(flStart, vecPoint) > flDistance)
		return false;
	
	Handle hTrace = TR_TraceRayFilterEx(flStart, vecPoint, MASK_ALL, RayType_EndPoint, ExcludeFilter, iExclude);
	if(hTrace != INVALID_HANDLE)
	{
		if(TR_DidHit(hTrace))
			bSee = false;
			
		delete hTrace;
	}
	
	return bSee;
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

stock void TE_ShowPole(float flPos[3], int Color[4], float flDuration = 0.1)
{
	float flToPos[3];
	flToPos[0] = flPos[0];
	flToPos[1] = flPos[1];
	flToPos[2] = flPos[2];
	flToPos[2] += 60.0;
	
	//Show a giant vertical beam at our goal node
	TE_SetupBeamPoints(flPos, flToPos, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, flDuration, 5.0, 5.0, 5, 0.0, Color, 30);
	TE_SendToAll();
}

stock float ApproachAngle(float target, float value, float speed)
{
	float delta = AngleDiff(target, value);
	
	if (speed < 0.0) 
		speed = -speed;
	
	if (delta > speed) 
		value += speed;
	else if (delta < -speed) 
		value -= speed;
	else
		value = target;
	
	return AngleNormalize(value);
}

 stock float VecToYaw(const float vec[3])
{
	if (vec[1] == 0 && vec[0] == 0) 
		return 0.0;
	
	float yaw = ArcTangent2(vec[1], vec[0]);
	yaw = RadToDeg(yaw);
	
	if (yaw < 0) 
		yaw += 360;
		
	return yaw;
}

stock float VecAxis(float vector[3], int axis)
{
	return vector[axis];
}

stock float AngleDiff(float ang1, float ang2)
{
	return AngleNormalize(ang1-ang2);
}

stock float AngleNormalize(float angle)
{
	angle = angle - 360.0 * RoundToFloor(angle / 360.0);
	while (angle > 180.0) angle -= 360.0;
	while (angle < -180.0) angle += 360.0;
	return angle;
}

stock void CreateParticle(char[] particle, float pos[3], float ang[3])
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
	TE_WriteNum("entindex", -1);
	TE_WriteNum("m_iAttachType", 5);	//Dont associate with any entity
	TE_SendToAll();
}