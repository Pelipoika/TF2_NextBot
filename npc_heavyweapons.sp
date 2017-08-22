//Thanks to sigsegv for his reversing work

#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <PathFollower>
#include <PathFollower_Nav>
#include <dhooks>
#include <dynamic>

#pragma newdecls required;

#define RAD2DEG(%1) ((%1) * (180.0 / FLOAT_PI))
#define DEG2RAD(%1) ((%1) * FLOAT_PI / 180.0)

#define EF_BONEMERGE                (1 << 0)
#define EF_PARENT_ANIMATES          (1 << 9)

#define TF_WEAPON_PRIMARY_MODE		0
#define TF_WEAPON_SECONDARY_MODE	1

//int g_iPathLaserModelIndex = -1;

ConVar g_hDebug;
ConVar g_hAimRate; 
ConVar g_hHeadSteadyRate;
ConVar g_hSaccadeSpeed;
ConVar g_hHeadResettleAngle;
ConVar g_hHeadResettleTime;
ConVar g_hHeadAimSettleDuration;

char gibs[][] =
{
	"models/bots/gibs/heavybot_gib_boss_head.mdl",
	"models/bots/gibs/heavybot_gib_boss_arm.mdl",
	"models/bots/gibs/heavybot_gib_boss_arm2.mdl",
	"models/bots/gibs/heavybot_gib_boss_chest.mdl",
	"models/bots/gibs/heavybot_gib_boss_leg.mdl",
	"models/bots/gibs/heavybot_gib_boss_leg2.mdl",
	"models/bots/gibs/heavybot_gib_boss_pelvis.mdl"
}

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
Handle g_hFaceTowards;
Handle g_hResetSequence;
Handle g_hGetVelocity;
Handle g_hSetVelocity;
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

//PluginBot DHooks
Handle g_hGetEntity;
Handle g_hGetBot;

//DHooks
Handle g_hGetCurrencyValue;
Handle g_hHandleAnimEvent;
Handle g_hGetFrictionSideways;
Handle g_hGetStepHeight;
Handle g_hGetGravity;
Handle g_hGetGroundNormal;
Handle g_hShouldCollideWith;
Handle g_hGetSolidMask;
Handle g_hStartActivity;

public Plugin myinfo = 
{
	name = "[TF2] Heavy NPC", 
	author = "Pelipoika", 
	description = "", 
	version = "1.0", 
	url = ""
};

// Firing states.
enum
{
	AC_STATE_IDLE = 0,
	AC_STATE_STARTFIRING,
	AC_STATE_FIRING,
	AC_STATE_SPINNING,
	AC_STATE_DRYFIRE
};

// LookAtPriorityType
enum
{
	BORING       = 0,
	INTERESTING  = 1,
	IMPORTANT    = 2,
	CRITICAL     = 3,
	OVERRIDE_ALL = 4,
};

ArrayList arrayList;

/*
TODO:
- Make a member leaving the squad not spam a shitton of errors.
 - Happens because for some reason when a squad member leaves it also deletes the m_Members array
- https://github.com/sigsegv-mvm/mvm-reversed/blob/3c60e2448fa660ab513b2c455eec33f33cedeac5/server/tf/bot/behavior/squad/tf_bot_escort_squad_leader.cpp#L45
*/

methodmap BaseNPC __nullable__
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
		
		CreateParticle("ghost_appearation", vecPos, vecAng);
		
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
		SetEntProp(npc, Prop_Data, "m_bloodColor", -1); 
		
		//Play robot impact particles and death sound.
		SDKHook(npc, SDKHook_OnTakeDamageAlive, OnBotDamaged);
		
		ActivateEntity(npc);
		
		char strName[64];
		Format(strName, sizeof(strName), "basenpc_%x", EntIndexToEntRef(npc));
		
		Dynamic brain = Dynamic();
		brain.SetBool("Pathing", false);
		brain.SetInt ("Weapon",  INVALID_ENT_REFERENCE);
		brain.SetFloat("MoveSpeed", 150.0);
		brain.SetFloat("OutOfRange", 400.0);
		brain.SetName(strName);
		
		//Upper body anims
		brain.SetFloat("m_flGoalFeetYaw", 0.0);
		brain.SetFloat("m_flCurrentFeetYaw", 0.0);
		brain.SetFloat("m_flLastAimTurnTime", 0.0);
		brain.SetFloat("m_flEyeYaw", 0.0);
		
		//Attack
		brain.SetFloat("m_flNextPrimaryAttack", 0.0);
		brain.SetFloat("m_flNextSecondaryAttack", 0.0);
		brain.SetFloat("m_flTimeWeaponIdle", 0.0);
		brain.SetInt("m_iWeaponState", AC_STATE_IDLE);
		brain.SetInt("m_iMinigunSoundCur", -1);
		brain.SetInt("m_iWeaponMode", TF_WEAPON_PRIMARY_MODE);
		brain.SetInt("m_pMuzzleEffect", INVALID_ENT_REFERENCE);
		
		//Head movement
		brain.SetVector("m_angLastEyeAngles", NULL_VECTOR);
		brain.SetVector("m_vecAimTarget", NULL_VECTOR);
		brain.SetVector("m_vecTargetVelocity", NULL_VECTOR);
		brain.SetVector("m_vecLastEyeVectors", NULL_VECTOR);
		
		brain.SetFloat("m_ctAimTracking", -1.0);
		brain.SetFloat("m_ctAimDuration", -1.0);
		brain.SetFloat("m_ctResettle", -1.0);
		
		brain.SetFloat("m_itAimStart", -1.0);
		brain.SetFloat("m_itHeadSteady", -1.0);
		
		brain.SetInt("m_iAimPriority", BORING);
		brain.SetInt("m_hAimTarget", -1);
		
		brain.SetBool("m_bHeadOnTarget", false);
		brain.SetBool("m_bSightedIn", false);
		
		//Squad stuff
		brain.SetFloat("m_ctRecomputePath", 0.0);
		brain.SetVector("m_vecLeaderGoalDirection", NULL_VECTOR);
		brain.SetFloat("m_flFormationError", 0.0);
		brain.SetBool("m_bIsInFormation", false);
		brain.SetDynamic("m_Squad", view_as<Dynamic>(INVALID_DYNAMIC_OBJECT));
		
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
		Format(strName, sizeof(strName), "basenpc_%x", EntIndexToEntRef(this.index));
		
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
	property int m_pMuzzleEffect
	{
		public get()			
		{
			int ent = INVALID_ENT_REFERENCE;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				ent = EntRefToEntIndex(brain.GetInt("m_pMuzzleEffect"));
			}
			
			return ent;
		}
		public set(int m_pMuzzleEffect)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetInt("m_pMuzzleEffect", EntIndexToEntRef(m_pMuzzleEffect));
			}
		}
	}
	property float MoveSpeed
	{
		public get()			
		{
			float speed = 0.0;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				speed = brain.GetFloat("MoveSpeed");
			}
			
			return speed;
		}
		public set(float speed)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("MoveSpeed", speed);
			}
		}
	}
	property float OutOfRange
	{
		public get()			
		{
			float range = 0.0;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				range = brain.GetFloat("OutOfRange");
			}
			
			return range;
		}
		public set(float range)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("OutOfRange", range);
			}
		}
	} 
	
	//Weapon
	property float m_flNextPrimaryAttack
	{
		public get()			
		{
			float m_flNextPrimaryAttack = 0.0;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				m_flNextPrimaryAttack = brain.GetFloat("m_flNextPrimaryAttack");
			}
			
			return m_flNextPrimaryAttack;
		}
		public set(float m_flNextPrimaryAttack)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("m_flNextPrimaryAttack", m_flNextPrimaryAttack);
			}
		}
	}
	property float m_flNextSecondaryAttack
	{
		public get()			
		{
			float m_flNextSecondaryAttack = 0.0;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				m_flNextSecondaryAttack = brain.GetFloat("m_flNextSecondaryAttack");
			}
			
			return m_flNextSecondaryAttack;
		}
		public set(float m_flNextSecondaryAttack)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("m_flNextSecondaryAttack", m_flNextSecondaryAttack);
			}
		}
	}
	property float m_flTimeWeaponIdle
	{
		public get()			
		{
			float m_flTimeWeaponIdle = 0.0;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				m_flTimeWeaponIdle = brain.GetFloat("m_flTimeWeaponIdle");
			}
			
			return m_flTimeWeaponIdle;
		}
		public set(float m_flTimeWeaponIdle)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("m_flTimeWeaponIdle", m_flTimeWeaponIdle);
			}
		}
	}
	property int m_iWeaponState
	{
		public get()			
		{
			int m_iWeaponState = AC_STATE_IDLE;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				m_iWeaponState = brain.GetInt("m_iWeaponState");
			}
			
			return m_iWeaponState;
		}
		public set(int m_iWeaponState)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetInt("m_iWeaponState", m_iWeaponState);
			}
		}
	}
	property int m_iMinigunSoundCur
	{
		public get()			
		{
			int m_iMinigunSoundCur = -1;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				m_iMinigunSoundCur = brain.GetInt("m_iMinigunSoundCur");
			}
			
			return m_iMinigunSoundCur;
		}
		public set(int m_iMinigunSoundCur)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetInt("m_iMinigunSoundCur", m_iMinigunSoundCur);
			}
		}
	}	
	property int m_iWeaponMode
	{
		public get()			
		{
			int m_iWeaponMode = AC_STATE_IDLE;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				m_iWeaponMode = brain.GetInt("m_iWeaponMode");
			}
			
			return m_iWeaponMode;
		}
		public set(int m_iWeaponMode)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetInt("m_iWeaponMode", m_iWeaponMode);
			}
		}
	}
	
	//Animation
	property float m_flGoalFeetYaw
	{
		public get()			
		{
			float m_flGoalFeetYaw = 0.0;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				m_flGoalFeetYaw = brain.GetFloat("m_flGoalFeetYaw");
			}
			
			return m_flGoalFeetYaw;
		}
		public set(float m_flGoalFeetYaw)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("m_flGoalFeetYaw", m_flGoalFeetYaw);
			}
		}
	}
	property float m_flCurrentFeetYaw
	{
		public get()			
		{
			float m_flCurrentFeetYaw = 0.0;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				m_flCurrentFeetYaw = brain.GetFloat("m_flCurrentFeetYaw");
			}
			
			return m_flCurrentFeetYaw;
		}
		public set(float m_flCurrentFeetYaw)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("m_flCurrentFeetYaw", m_flCurrentFeetYaw);
			}
		}
	}
	property float m_flLastAimTurnTime
	{
		public get()			
		{
			float m_flLastAimTurnTime = 0.0;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				m_flLastAimTurnTime = brain.GetFloat("m_flLastAimTurnTime");
			}
			
			return m_flLastAimTurnTime;
		}
		public set(float m_flLastAimTurnTime)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("m_flLastAimTurnTime", m_flLastAimTurnTime);
			}
		}
	}
	property float m_flEyeYaw
	{
		public get()			
		{
			float m_flEyeYaw = 0.0;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				m_flEyeYaw = brain.GetFloat("m_flEyeYaw");
			}
			
			return m_flEyeYaw;
		}
		public set(float m_flEyeYaw)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("m_flEyeYaw", m_flEyeYaw);
			}
		}
	}
	property float m_flEyePitch
	{
		public get()			
		{
			float m_flEyePitch = 0.0;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				m_flEyePitch = brain.GetFloat("m_flEyePitch");
			}
			
			return m_flEyePitch;
		}
		public set(float m_flEyePitch)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("m_flEyePitch", m_flEyePitch);
			}
		}
	}
	
	public bool Getm_angLastEyeAngles(float[3] value)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetBrainInterface().GetMemberOffset("m_angLastEyeAngles");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic!");
		}
		this.GetBrainInterface().GetVectorByOffset(offset, value);
		return true;
	}
	public void Setm_angLastEyeAngles(const float[3] value)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetBrainInterface().GetMemberOffset("m_angLastEyeAngles");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().SetVector("m_angLastEyeAngles", value);
				return;
			}
		}
		this.GetBrainInterface().SetVectorByOffset(offset, value);
	}
	public bool Getm_vecAimTarget(float[3] value)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetBrainInterface().GetMemberOffset("m_vecAimTarget");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic!");
		}
		this.GetBrainInterface().GetVectorByOffset(offset, value);
		return true;
	}
	public void Setm_vecAimTarget(const float[3] value)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetBrainInterface().GetMemberOffset("m_vecAimTarget");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().SetVector("m_vecAimTarget", value);
				return;
			}
		}
		this.GetBrainInterface().SetVectorByOffset(offset, value);
	}
	public bool Getm_vecTargetVelocity(float[3] value)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetBrainInterface().GetMemberOffset("m_vecTargetVelocity");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic!");
		}
		this.GetBrainInterface().GetVectorByOffset(offset, value);
		return true;
	}
	public void Setm_vecTargetVelocity(const float[3] value)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetBrainInterface().GetMemberOffset("m_vecTargetVelocity");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().SetVector("m_vecTargetVelocity", value);
				return;
			}
		}
		this.GetBrainInterface().SetVectorByOffset(offset, value);
	}
	public bool Getm_vecLastEyeVectors(float[3] value)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetBrainInterface().GetMemberOffset("m_vecLastEyeVectors");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic!");
		}
		this.GetBrainInterface().GetVectorByOffset(offset, value);
		return true;
	}
	public void Setm_vecLastEyeVectors(const float[3] value)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetBrainInterface().GetMemberOffset("m_vecLastEyeVectors");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().SetVector("m_vecLastEyeVectors", value);
				return;
			}
		}
		this.GetBrainInterface().SetVectorByOffset(offset, value);
	}
	
	//Aim
	property float m_ctAimTracking
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_ctAimTracking");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBrainInterface().GetFloatByOffset(offset);
		}
		public set(float value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_ctAimTracking");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.GetBrainInterface().SetFloat("m_ctAimTracking", value);
					return;
				}
			}
			this.GetBrainInterface().SetFloatByOffset(offset, value);
		}
	}
	property float m_ctAimDuration
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_ctAimDuration");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBrainInterface().GetFloatByOffset(offset);
		}
		public set(float value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_ctAimDuration");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.GetBrainInterface().SetFloat("m_ctAimDuration", value);
					return;
				}
			}
			this.GetBrainInterface().SetFloatByOffset(offset, value);
		}
	}
	property float m_ctResettle
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_ctResettle");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBrainInterface().GetFloatByOffset(offset);
		}
		public set(float value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_ctResettle");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.GetBrainInterface().SetFloat("m_ctResettle", value);
					return;
				}
			}
			this.GetBrainInterface().SetFloatByOffset(offset, value);
		}
	}
	property float m_itAimStart
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_itAimStart");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBrainInterface().GetFloatByOffset(offset);
		}
		public set(float value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_itAimStart");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.GetBrainInterface().SetFloat("m_itAimStart", value);
					return;
				}
			}
			this.GetBrainInterface().SetFloatByOffset(offset, value);
		}
	}
	property float m_itHeadSteady
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_itHeadSteady");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBrainInterface().GetFloatByOffset(offset);
		}
		public set(float value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_itHeadSteady");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.GetBrainInterface().SetFloat("m_itHeadSteady", value);
					return;
				}
			}
			this.GetBrainInterface().SetFloatByOffset(offset, value);
		}
	}
	property int m_iAimPriority
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_iAimPriority");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBrainInterface().GetIntByOffset(offset);
		}
		public set(int value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_iAimPriority");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.GetBrainInterface().SetInt("m_iAimPriority", value);
					return;
				}
			}
			this.GetBrainInterface().SetIntByOffset(offset, value);
		}
	}
	property int m_hAimTarget
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_hAimTarget");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBrainInterface().GetIntByOffset(offset);
		}
		public set(int value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_hAimTarget");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.GetBrainInterface().SetInt("m_hAimTarget", value);
					return;
				}
			}
			this.GetBrainInterface().SetIntByOffset(offset, value);
		}
	}
	property bool m_bHeadOnTarget
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_bHeadOnTarget");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBrainInterface().GetBoolByOffset(offset);
		}
		public set(bool value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_bHeadOnTarget");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.GetBrainInterface().SetBool("m_bHeadOnTarget", value);
					return;
				}
			}
			this.GetBrainInterface().SetBoolByOffset(offset, value);
		}
	}
	property bool m_bSightedIn
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_bSightedIn");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBrainInterface().GetBoolByOffset(offset);
		}
		public set(bool value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_bSightedIn");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.GetBrainInterface().SetBool("m_bSightedIn", value);
					return;
				}
			}
			this.GetBrainInterface().SetBoolByOffset(offset, value);
		}
	}
	
	public bool IsHeadAimingOnTarget()
	{
		return this.m_bHeadOnTarget;
	}
	public bool IsHeadSteady()
	{
		return view_as<bool>(this.m_itHeadSteady != -1);
	}
	public float GetHeadSteadyDuration()
	{
		if (this.m_itHeadSteady == -1) {
			return 0.0;
		}
		
		return GetGameTime() - this.m_itHeadSteady;
	}
	public float GetMaxHeadAngularVelocity()
	{
		return g_hSaccadeSpeed.FloatValue;
	}
	public void Upkeep()
	{	
		float frametime = GetGameFrameTime();
		if(frametime < (1.0 * 10.0 ^ -5.0))
			return;
		
		float eye_ang[3];
		eye_ang[0] = this.m_flEyePitch;
		eye_ang[1] = this.m_flEyeYaw;
		
		float m_angLastEyeAngles[3];
		this.Getm_angLastEyeAngles(m_angLastEyeAngles);
		
		if (FloatAbs(float(RoundToFloor(AngleDiff(eye_ang[0], m_angLastEyeAngles[0])))) > (frametime * g_hHeadSteadyRate.FloatValue)
		 || FloatAbs(float(RoundToFloor(AngleDiff(eye_ang[1], m_angLastEyeAngles[1])))) > (frametime * g_hHeadSteadyRate.FloatValue))
		 {
			this.m_itHeadSteady = -1.0;
		} 
		else 
		{
			if (this.m_itHeadSteady == -1) 
			{
				this.m_itHeadSteady = GetGameTime();
			}
		}
		
		this.Setm_angLastEyeAngles(eye_ang);
		
		if (this.m_bSightedIn && this.m_ctAimDuration <= GetGameTime()) {
			return;
		}
		
		float eye_vec[3];
		GetAngleVectors(eye_ang, eye_vec, NULL_VECTOR, NULL_VECTOR);
		
		float m_vecLastEyeVectors[3];
		this.Getm_vecLastEyeVectors(m_vecLastEyeVectors);
		
		if(ArcCosine(GetVectorDotProduct(m_vecLastEyeVectors, eye_vec)) * (180.0 / FLOAT_PI) > g_hHeadResettleAngle.FloatValue)
		{
			this.m_ctResettle = GetGameTime() + g_hHeadResettleTime.FloatValue * GetRandomFloat(0.9, 1.1);
			this.Setm_vecLastEyeVectors(eye_vec);
		}
		else if (this.m_ctResettle == -1 || this.m_ctResettle <= GetGameTime())
		{
			this.m_ctResettle = -1.0;
			
			int target_ent = this.m_hAimTarget;
			if (target_ent > 0 && IsValidEntity(target_ent)) 
			{	
				float target_point[3];    target_point = WorldSpaceCenter(target_ent);
				float target_velocity[3]; GetAbsVelocity(target_ent, target_velocity);
				
				float m_vecAimTarget[3]; this.Getm_vecAimTarget(m_vecAimTarget);
				
				if (this.m_ctAimTracking <= GetGameTime()) 
				{
					float delta[3];
					SubtractVectors(target_point, m_vecAimTarget, delta)
					
					float flLeadTime = 0.0;
					delta[0] += (flLeadTime * target_velocity[0]);
					delta[1] += (flLeadTime * target_velocity[1]);
					delta[2] += (flLeadTime * target_velocity[2]);
					
					float track_interval = Max(frametime, g_hAimRate.FloatValue);
					
					float scale = GetVectorLength(delta) / track_interval;
					NormalizeVector(delta, delta);
					
					float m_vecTargetVelocity[3];
					m_vecTargetVelocity[0] = (scale * delta[0]) + target_velocity[0];
					m_vecTargetVelocity[1] = (scale * delta[1]) + target_velocity[1];
					m_vecTargetVelocity[2] = (scale * delta[2]) + target_velocity[2];
					this.Setm_vecTargetVelocity(m_vecTargetVelocity);
					
					this.m_ctAimTracking = GetGameTime() + (track_interval * GetRandomFloat(0.8, 1.2));
				}
				
				float m_vecTargetVelocity[3]; this.Getm_vecTargetVelocity(m_vecTargetVelocity);
				
				m_vecAimTarget[0] += frametime * m_vecTargetVelocity[0];
				m_vecAimTarget[1] += frametime * m_vecTargetVelocity[1];
				m_vecAimTarget[2] += frametime * m_vecTargetVelocity[2];
				
				this.Setm_vecAimTarget(m_vecAimTarget);
			}
		}
	
		float eye_to_target[3], myEyePosition[3];
		myEyePosition = WorldSpaceCenter(this.index);
		
		float m_vecAimTarget[3]; this.Getm_vecAimTarget(m_vecAimTarget);		
		SubtractVectors(m_vecAimTarget, myEyePosition, eye_to_target);
		NormalizeVector(eye_to_target, eye_to_target);
		
		float ang_to_target[3];
		GetVectorAngles(eye_to_target, ang_to_target);
		
		float cos_error = GetVectorDotProduct(eye_to_target, eye_vec);
		
		/* must be within ~11.5 degrees to be considered on target */
		if (cos_error <= 0.98)
		{
			this.m_bHeadOnTarget = false;
		}
		else 
		{
			this.m_bHeadOnTarget = true;
			
			if (!this.m_bSightedIn) 
			{
				this.m_bSightedIn = true;
				
				if (g_hDebug.BoolValue) 
				{
					PrintToServer("%3.2f: %i Look At SIGHTED IN\n",
						GetGameTime(), this.index);
				}
			}
		}
		
		float max_angvel = this.GetMaxHeadAngularVelocity();
		
		/* adjust angular velocity limit based on aim error amount */
		if (cos_error > 0.7){
			max_angvel *= Sine((3.14 / 2.0) * (1.0 + ((-49.0 / 15.0) * (cos_error - 0.7))));
		}
	
		if(this.m_itAimStart != -1 && (GetGameTime() - this.m_itAimStart < 0.25)){
			max_angvel *= 4.0 * (GetGameTime() - this.m_itAimStart);
		}
		
		float new_eye_angle[3];
		new_eye_angle[0] = ApproachAngle(ang_to_target[0], eye_ang[0], (max_angvel * frametime) * 0.5);
		new_eye_angle[1] = ApproachAngle(ang_to_target[1], eye_ang[1], (max_angvel * frametime));
		new_eye_angle[2] = 0.0;
		
		this.m_flEyeYaw = new_eye_angle[1];
		this.m_flEyePitch = new_eye_angle[0];
		
		float temp[3]; temp = WorldSpaceCenter(this.index);
		
		float shit[3];
		shit[0] = temp[0] + (100.0 * eye_vec[0]);
		shit[1] = temp[1] + (100.0 * eye_vec[1]);
		shit[2] = temp[2] + (100.0 * eye_vec[2]);
		
	//	TE_SetupBeamPoints(shit, WorldSpaceCenter(this.index), g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, 0.1, 0.1, 0.1, 5, 0.0, view_as<int>({255, 255, 0, 255}), 30);
	//	TE_SendToAll();
	}
	public void AimHeadTowards(const float vec[3], int priority, float duration = 0.0, const char[] reason)
	{
		if (duration <= 0.0) {
			duration = 0.1;
		}
		
		if (priority == this.m_iAimPriority && (!this.IsHeadSteady() || this.GetHeadSteadyDuration() < g_hHeadAimSettleDuration.FloatValue)) 
		{
			if (g_hDebug.BoolValue) 
			{
				PrintToServer("%3.2f: AimHeadTowards %i Look At '%s' rejected - previous aim not %s\n",
					GetGameTime(), this.index, reason, (this.IsHeadSteady() ? "settled long enough" : "head-steady"));
			}
		}
		
		if (priority > this.m_iAimPriority || this.m_ctAimDuration <= GetGameTime()) 
		{
			this.m_ctAimDuration = GetGameTime() + duration;
			this.m_iAimPriority = priority;
			
			/* only update our aim if the target vector changed significantly */
			float m_vecAimTarget[3]; this.Getm_vecAimTarget(m_vecAimTarget);
			if (GetVectorDistance(vec, m_vecAimTarget) >= 1.0)
			{
				this.m_hAimTarget = -1;
				this.Setm_vecAimTarget(vec);
				this.m_itAimStart = GetGameTime();
				this.m_bHeadOnTarget = false;
				
				if (g_hDebug.BoolValue) 
				{
					char pri_str[16];
					switch (priority) 
					{
						case BORING:      pri_str = "Boring";
						case INTERESTING: pri_str = "Interesting";
						case IMPORTANT:   pri_str = "Important";
						case CRITICAL:    pri_str = "Critical";
					}
					
					PrintToServer("%3.2f: %i Look At ( %f, %f, %f ) for %3.2f s, Pri = %s, Reason = %s\n", GetGameTime(), this.index, vec[0], vec[1], vec[2], duration, pri_str, reason);
				}
			}
		} 
		else 
		{			
			if (g_hDebug.BoolValue) 
			{
				PrintToServer("%3.2f: AimHeadTowards %i Look At '%s' rejected - higher priority aim in progress\n", 
					GetGameTime(), this.index, reason);
			}
		}
	}
	public void AimHeadTowardsEntity(int ent, int priority, float duration = 0.0, const char[] reason)
	{
		if (duration <= 0.0) {
			duration = 0.1;
		}
		
		if (priority == this.m_iAimPriority && (!this.IsHeadSteady() || this.GetHeadSteadyDuration() < g_hHeadAimSettleDuration.FloatValue)) 
		{
			if (g_hDebug.BoolValue) 
			{
				PrintToServer("%3.2f: AimHeadTowardsEntity %i Look At '%s' rejected - previous aim not %s\n",
					GetGameTime(), this.index, reason, (this.IsHeadSteady() ? "settled long enough" : "head-steady"));
			}
		}
		
		if (priority > this.m_iAimPriority || this.m_ctAimDuration <= GetGameTime()) 
		{
			this.m_ctAimDuration = GetGameTime() + duration;
			this.m_iAimPriority = priority;
			
			/* only update our aim if the target entity changed */
			int prev_target = this.m_hAimTarget;
			if (prev_target == -1 || ent != prev_target) 
			{
				this.m_hAimTarget = ent;
				this.m_itAimStart = GetGameTime();
				this.m_bHeadOnTarget = false;
				
				if (g_hDebug.BoolValue) 
				{
					char pri_str[16];
					switch (priority) 
					{
						case BORING:      pri_str = "Boring";
						case INTERESTING: pri_str = "Interesting";
						case IMPORTANT:   pri_str = "Important";
						case CRITICAL:    pri_str = "Critical";
					}
					
					char strClass[64];
					GetEntityClassname(ent, strClass, sizeof(strClass));
					
					PrintToServer("%3.2f: %i Look At subject %s for %3.2f s, Pri = %s, Reason = %s\n",
						GetGameTime(), this.index, strClass, duration, pri_str, reason);
				}
			}
		}
		else 
		{
			if (g_hDebug.BoolValue) 
			{
				PrintToServer("%3.2f: AimHeadTowardsEntity %i Look At '%s' rejected - higher priority aim in progress\n",
					GetGameTime(), this.index, reason);
			}
		}
	}
	
	//Squad
	property float m_ctRecomputePath
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_ctRecomputePath");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBrainInterface().GetFloatByOffset(offset);
		}
		public set(float value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_ctRecomputePath");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.GetBrainInterface().SetFloat("m_ctRecomputePath", value);
					return;
				}
			}
			this.GetBrainInterface().SetFloatByOffset(offset, value);
		}
	}
	public bool Getm_vecLeaderGoalDirection(float[3] value)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetBrainInterface().GetMemberOffset("m_vecLeaderGoalDirection");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic!");
		}
		this.GetBrainInterface().GetVectorByOffset(offset, value);
		return true;
	}
	public void Setm_vecLeaderGoalDirection(const float[3] value)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetBrainInterface().GetMemberOffset("m_vecLeaderGoalDirection");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().SetVector("m_vecLeaderGoalDirection", value);
				return;
			}
		}
		this.GetBrainInterface().SetVectorByOffset(offset, value);
	}	
	property float m_flFormationError
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_flFormationError");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBrainInterface().GetFloatByOffset(offset);
		}
		public set(float value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_flFormationError");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.GetBrainInterface().SetFloat("m_flFormationError", value);
					return;
				}
			}
			this.GetBrainInterface().SetFloatByOffset(offset, value);
		}
	}
	property bool m_bIsInFormation
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_bIsInFormation");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBrainInterface().GetBoolByOffset(offset);
		}
		public set(bool value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_bIsInFormation");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.GetBrainInterface().SetBool("m_bIsInFormation", value);
					return;
				}
			}
			this.GetBrainInterface().SetBoolByOffset(offset, value);
		}
	}
	property Dynamic m_Squad
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_Squad");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBrainInterface().GetDynamicByOffset(offset);
		}
		public set(Dynamic value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().GetMemberOffset("m_Squad");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.GetBrainInterface().SetDynamic("m_Squad", value);
					return;
				}
			}
			this.GetBrainInterface().SetDynamicByOffset(offset, value);
		}
	}
	
	public void JumpAnim(char[] buffer, int maxlength)
	{
		Dynamic brain = this.GetBrainInterface();
		if(brain.IsValid)
		{
			brain.GetString("JumpAnim", buffer, maxlength);
		}
	}	
	public void MoveAnim(char[] buffer, int maxlength)
	{
		Dynamic brain = this.GetBrainInterface();
		if(brain.IsValid)
		{
			brain.GetString("MoveAnim", buffer, maxlength);
		}
	}	
	public void IdleAnim(char[] buffer, int maxlength)
	{
		Dynamic brain = this.GetBrainInterface();
		if(brain.IsValid)
		{
			brain.GetString("IdleAnim", buffer, maxlength);
		}
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
		PF_EnableCallback(this.index, PFCB_ClimbUpToLedge, PluginBot_Jump);
		PF_EnableCallback(this.index, PFCB_GetPathCost, PluginBot_PathCost);
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
	public void GetVelocity(float vecOut[3])
	{
		SDKCall(g_hGetVelocity, this.GetLocomotionInterface(), vecOut);
	}	
	public void SetVelocity(const float vec[3])
	{
		SDKCall(g_hSetVelocity, this.GetLocomotionInterface(), vec);
	}	
	public int EquipItem(const char[] attachment, const char[] model, const char[] anim = "", int skin = 0)
	{
		int item = CreateEntityByName("prop_dynamic");
		DispatchKeyValue(item, "model", model);
		DispatchKeyValueFloat(item, "modelscale", GetEntPropFloat(this.index, Prop_Send, "m_flModelScale"));
		DispatchSpawn(item);
		
		SetEntProp(item, Prop_Send, "m_nSkin", skin);
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

methodmap CTFBotSquad < Dynamic
{
	public CTFBotSquad(int bot)
	{
		Dynamic myclass = Dynamic(64, 0);
		
		ArrayList members = new ArrayList();
		members.Push(bot);
		
		arrayList.Push(members);
		
		myclass.SetHandle("m_Members", members);
		myclass.SetInt("m_hLeader", bot);
		myclass.SetFloat("m_flFormationSize", -1.0);
		myclass.SetBool("m_bShouldPreserveSquad", false);
		
		view_as<BaseNPC>(bot).m_Squad = myclass;
		return view_as<CTFBotSquad>(myclass);
	}
	
	property ArrayList m_Members
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("m_Members");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return view_as<ArrayList>(this.GetHandleByOffset(offset));
		}
		public set(ArrayList value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("m_Members");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetHandle("m_Members", value);
					return;
				}
			}
			this.SetHandleByOffset(offset, value);
		}
	}
	property int m_hLeader
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("m_hLeader");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetIntByOffset(offset);
		}
		public set(int value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("m_hLeader");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetInt("m_hLeader", value);
					return;
				}
			}
			this.SetIntByOffset(offset, value);
		}
	}
	property float m_flFormationSize
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("m_flFormationSize");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetFloatByOffset(offset);
		}
		public set(float value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("m_flFormationSize");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetFloat("m_flFormationSize", value);
					return;
				}
			}
			this.SetFloatByOffset(offset, value);
		}
	}
	property bool m_bShouldPreserveSquad 
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("m_bShouldPreserveSquad");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBoolByOffset(offset);
		}
		public set(bool value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("m_bShouldPreserveSquad");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetBool("m_bShouldPreserveSquad", value);
					return;
				}
			}
			this.SetBoolByOffset(offset, value);
		}
	}
	
	public bool IsValidMember(int bot)
	{
		return (IsValidEntity(bot) && view_as<BaseNPC>(bot).GetBrainInterface() != INVALID_DYNAMIC_OBJECT);
	}
	public int GetMemberCount()
	{
		int count = 0;
		
		for (int i = 0; i < this.m_Members.Length; i++)
		{
			int bot = GetArrayCell(this.m_Members, i);
			if(this.IsValidMember(bot))
			{
				++count;
			}
		}
		
		return count;
	}
	public int GetLeader()
	{
		return this.m_hLeader;
	}
	public void DisbandAndDeleteSquad()
	{
		PrintToChatAll("DisbandAndDeleteSquad");
	
		for (int i = 0; i < this.m_Members.Length; i++)
		{
			int bot = GetArrayCell(this.m_Members, i);
			if(this.IsValidMember(bot))
			{
				view_as<BaseNPC>(bot).m_Squad = INVALID_DYNAMIC_OBJECT;	
			}
		}
		
		delete this.m_Members;
		this.Dispose();
	}
	public void Join(int bot)
	{
		if(this.m_Members.Length <= 0)
		{
			this.m_hLeader = bot;
		}
		
		this.m_Members.Push(bot);
		view_as<BaseNPC>(bot).m_Squad = this;
	}
	public void Leave(int bot)
	{
		ArrayList members = this.m_Members;
	//	if(members == null){
	//		return;
	//	}
		
		int idx = members.FindValue(bot);
		if (idx != -1) 
		{
			members.Erase(idx);
			view_as<BaseNPC>(bot).m_Squad = INVALID_DYNAMIC_OBJECT;
		}
		
		int leader = this.m_hLeader;
		if (bot == leader) 
		{
			this.m_hLeader = 0;
			
			if (this.m_bShouldPreserveSquad) 
			{
				for (int i = 0; i < members.Length; i++)
				{
					int bot_ = members.Get(i);
					if(this.IsValidMember(bot_))
					{
						this.m_hLeader = i;
						break;
					}
				}
			}
		}
		
		if (this.GetMemberCount() == 0) 
		{
			this.DisbandAndDeleteSquad();
		}
	}
	public float GetMaxSquadFormationError()
	{
		float error = 0.0;
		
		/* exclude squad leader */
		for (int i = 1; i < this.m_Members.Length; ++i) 
		{
			int member = this.m_Members.Get(i);
			if (!this.IsValidMember(member)) {
				continue;
			}
			
			error = Max(error, view_as<BaseNPC>(this.m_Members.Get(i)).m_flFormationError);
		}
		
		return error;
	}
	public bool IsInFormation()
	{
		/* exclude squad leader */
		for (int i = 1; i < this.m_Members.Length; ++i) 
		{
			int member = this.m_Members.Get(i);
			if (!this.IsValidMember(member)) {
				continue;
			}
			
			if (view_as<BaseNPC>(this.m_Members.Get(i)).m_bIsInFormation) {
				continue;
			}
			
			if (view_as<BaseNPC>(this.m_Members.Get(i)).IsStuck()) {
				continue;
			}
			
			if (view_as<BaseNPC>(this.m_Members.Get(i)).m_flFormationError > 0.75) {
				return false;
			}
		}
		
		return true;
	}
	public bool ShouldSquadLeaderWaitForFormation()
	{
		/* exclude squad leader */
		for (int i = 1; i < this.m_Members.Length; ++i) 
		{
			int member = this.m_Members.Get(i);
			if (!this.IsValidMember(member)) {
				continue;
			}
			
			if (view_as<BaseNPC>(this.m_Members.Get(i)).m_flFormationError < 1.0) {
				continue;
			}
			
			if (view_as<BaseNPC>(this.m_Members.Get(i)).m_bIsInFormation) {
				continue;
			}
			
			if (view_as<BaseNPC>(this.m_Members.Get(i)).IsStuck()) {
				continue;
			}
			
			return true;
		}
		
		return false;
	}
}

methodmap PetHeavy < BaseNPC
{
	public PetHeavy(int client, float vecPos[3], float vecAng[3], const char[] model, int team)
	{
		BaseNPC pet = new BaseNPC(vecPos, vecAng, model, "1.75");
		
		SetEntPropFloat(pet.index, Prop_Data, "m_speed", 230.0);
		SetEntProp(pet.index, Prop_Send, "m_nSkin", team - 2);
		SetEntProp(pet.index, Prop_Send, "m_iTeamNum", team);
		
		Dynamic brain = pet.GetBrainInterface();
		
		//REQUIRED IF YOU'RE GOING TO USE Blend9Think
		brain.SetString("MoveAnim", "Run_PRIMARY", 64);
		brain.SetFloat("MoveSpeed", 115.0);
		brain.SetString("IdleAnim", "Stand_PRIMARY", 64);
		brain.SetFloat("OutOfRange", 400.0);
		//////////
		
		pet.CreatePather(client, 18.0, 18.0, 1000.0, MASK_NPCSOLID | MASK_PLAYERSOLID, 60.0, 0.65, 0.65);
		pet.SetAnimation("Stand_PRIMARY");
		
		float pos[3];
		NavArea area = TheNavMesh.GetNearestNavArea_Vec(vecPos);
		area.GetCenter(pos);
		
		PF_SetGoalVector(pet.index, pos);
		
		pet.Pathing = true;
		
		//Controls 9 way blend animation managing
		SDKHook(pet.index, SDKHook_Think, Blend9Think);
		SDKHook(pet.index, SDKHook_Think, PetHeavyThink);
		
		EmitSoundToAll(")mvm/giant_heavy/giant_heavy_loop.wav", pet.index, SNDCHAN_STATIC, 83, _, 0.8);
		
		return view_as<PetHeavy>(pet);
	}
	
	public void WindUp()
	{
		this.PlayGesture("layer_attackStand_PRIMARY_spoolup");
		this.m_iWeaponState = AC_STATE_STARTFIRING;
		
		EmitSoundToAll(")mvm/giant_heavy/giant_heavy_gunwindup.wav", this.index, SNDCHAN_WEAPON, SNDLEVEL_AIRCRAFT, _, 0.9, 100);
		StopSound(this.index, SNDCHAN_STATIC, ")mvm/giant_heavy/giant_heavy_gunfire.wav");
		StopSound(this.index, SNDCHAN_STATIC, ")mvm/giant_heavy/giant_heavy_gunspin.wav");
	}

	public void WindDown()
	{
		Dynamic brain = this.GetBrainInterface();
		brain.SetString("MoveAnim", "Run_PRIMARY", 64);
		brain.SetString("IdleAnim", "Stand_PRIMARY", 64);
	
		this.PlayGesture("layer_attackStand_PRIMARY_spooldown");
		
		EmitSoundToAll(")mvm/giant_heavy/giant_heavy_gunwinddown.wav", this.index, SNDCHAN_WEAPON, SNDLEVEL_AIRCRAFT, _, 0.9, 100);
		StopSound(this.index, SNDCHAN_STATIC, ")mvm/giant_heavy/giant_heavy_gunfire.wav");
		StopSound(this.index, SNDCHAN_STATIC, ")mvm/giant_heavy/giant_heavy_gunspin.wav");
		
		this.m_iWeaponState = AC_STATE_IDLE;
		
		// Time to weapon idle.
		this.m_flTimeWeaponIdle = GetGameTime() + 2.0;
	}
	
	public void WeaponIdle()
	{
		if (GetGameTime() < this.m_flTimeWeaponIdle)
			return;
	
		// Always wind down if we've hit here, because it only happens when the player has stopped firing/spinning
		if (this.m_iWeaponState != AC_STATE_IDLE )
		{	
			this.WindDown();
			return;
		}
		
		this.m_flTimeWeaponIdle = GetGameTime() + 12.5;// how long till we do this again.
	}
	
	public void WeaponSoundUpdate()
	{
		// determine the desired sound for our current state
		int iSound = -1;
		switch ( this.m_iWeaponState )
		{
			case AC_STATE_FIRING: iSound = 1; // firing sound
			case AC_STATE_SPINNING:	iSound = 2;	// spinning sound
		}
		
		// if we're already playing the desired sound, nothing to do
		if ( this.m_iMinigunSoundCur == iSound )
			return;
			
		this.m_iMinigunSoundCur = iSound;
	
		// if we're playing some other sound, stop it
		if(iSound == 2)
		{
			StopSound(this.index, SNDCHAN_STATIC, ")mvm/giant_heavy/giant_heavy_gunfire.wav");
			EmitSoundToAll(")mvm/giant_heavy/giant_heavy_gunspin.wav", this.index, SNDCHAN_STATIC, SNDLEVEL_AIRCRAFT, _, SNDVOL_NORMAL, 100);
		}
		else
		{
			StopSound(this.index, SNDCHAN_STATIC, ")mvm/giant_heavy/giant_heavy_gunspin.wav");
			EmitSoundToAll(")mvm/giant_heavy/giant_heavy_gunfire.wav", this.index, SNDCHAN_STATIC, SNDLEVEL_AIRCRAFT, _, SNDVOL_NORMAL, 100);
		}
	}
	
	public void Attack()
	{
		this.WeaponSoundUpdate();
	
		this.m_iWeaponMode = TF_WEAPON_PRIMARY_MODE;

		switch(this.m_iWeaponState)
		{
			case AC_STATE_IDLE:
			{
				Dynamic brain = this.GetBrainInterface();
				brain.SetString("MoveAnim", "PRIMARY_Deployed_Movement", 64);
				brain.SetString("IdleAnim", "Stand_Deployed_PRIMARY", 64);
			
				this.m_iWeaponState = AC_STATE_STARTFIRING;
				this.m_flNextSecondaryAttack = this.m_flNextPrimaryAttack = this.m_flTimeWeaponIdle = GetGameTime() + 1.0;
				this.WindUp();
			}
			case AC_STATE_STARTFIRING:
			{
				if(this.m_flNextPrimaryAttack <= GetGameTime())
				{
					if(this.m_iWeaponMode == TF_WEAPON_SECONDARY_MODE)
					{
						this.m_iWeaponState = AC_STATE_SPINNING;
					}
					else
					{
						this.m_iWeaponState = AC_STATE_FIRING;
					}
					
					this.m_flNextSecondaryAttack = this.m_flNextPrimaryAttack = this.m_flTimeWeaponIdle = GetGameTime() + 0.1;
				}
			}
			case AC_STATE_FIRING:
			{
				if (this.m_iWeaponMode == TF_WEAPON_SECONDARY_MODE)
				{
					this.m_iWeaponState = AC_STATE_SPINNING;
	
					this.m_flNextSecondaryAttack = this.m_flNextPrimaryAttack = this.m_flTimeWeaponIdle = GetGameTime() + 0.1;
				}
				else
				{
					// Only fire if we're actually shooting
					if (GetGameTime() >= this.m_flNextPrimaryAttack)
					{
						this.m_iWeaponMode = TF_WEAPON_PRIMARY_MODE;
						
						float eyePitch[3];
						eyePitch[1] = this.m_flEyeYaw;
						eyePitch[0] = this.m_flEyePitch;
					
						float vecSpread = 0.1;
						
						for (int i = 0; i < 4; i++)
						{
							float x, y;
							x = GetRandomFloat( -0.5, 0.5 ) + GetRandomFloat( -0.5, 0.5 );
							y = GetRandomFloat( -0.5, 0.5 ) + GetRandomFloat( -0.5, 0.5 );
							
							float vecDirShooting[3], vecRight[3], vecUp[3];
							GetAngleVectors(eyePitch, vecDirShooting, vecRight, vecUp);
							
							//add the spray
							float vecDir[3];
							vecDir[0] = vecDirShooting[0] + x * vecSpread * vecRight[0] + y * vecSpread * vecUp[0]; 
							vecDir[1] = vecDirShooting[1] + x * vecSpread * vecRight[1] + y * vecSpread * vecUp[1]; 
							vecDir[2] = vecDirShooting[2] + x * vecSpread * vecRight[2] + y * vecSpread * vecUp[2]; 
							NormalizeVector(vecDir, vecDir);
							
							FireBullet(this.index, this.Weapon, WorldSpaceCenter(this.index), vecDir, 4.5, 9000.0, DMG_BULLET, "bullet_tracer02_blue");
						}
						
						float origin[3], angles[3];
						view_as<BaseNPC>(this.Weapon).GetAttachment("muzzle", origin, angles);
						CreateParticle("muzzle_minigun", origin, angles);
						
						this.m_flTimeWeaponIdle = GetGameTime() + 0.2;
						this.m_flNextPrimaryAttack = GetGameTime() + 0.1;
					}
				}
			}
			case AC_STATE_DRYFIRE:
			{
				if (this.m_iWeaponMode == TF_WEAPON_SECONDARY_MODE)
				{
					this.m_iWeaponState = AC_STATE_SPINNING;
				}
			}
			case AC_STATE_SPINNING:
			{
				if (this.m_iWeaponMode == TF_WEAPON_PRIMARY_MODE)
				{
					this.m_iWeaponState = AC_STATE_FIRING;
				}
			}
		}
	}
}

public void PetHeavyThink(int iEntity)
{
	PetHeavy npc = view_as<PetHeavy>(iEntity);
	npc.Update();
	npc.Upkeep();
	
	Address iVision = npc.GetVisionInterface();
	Address KnownEntity = SDKCall(g_hGetPrimaryKnownThreat, iVision, true);
	if(KnownEntity != Address_Null)
	{
		int iEnemy = SDKCall(g_hGetKnownEntity, KnownEntity);
		npc.AimHeadTowardsEntity(iEnemy, IMPORTANT, 1.0, "Aiming at a visible threat");
		
		if(npc.IsHeadAimingOnTarget())
		{
			npc.Attack();
		}
		else
		{
			npc.m_iWeaponMode = TF_WEAPON_SECONDARY_MODE;
		}
	}
	else if(npc.m_iWeaponState > AC_STATE_IDLE)
	{
		npc.WeaponIdle();
	}
	
	ComputePoseParam_AimYaw(iEntity);
	ComputePoseParam_AimPitch(iEntity);
	
	Dynamic squad = npc.m_Squad;
	if(squad != INVALID_DYNAMIC_OBJECT)
	{
		int leader = view_as<CTFBotSquad>(squad).m_hLeader;
		if(!IsValidEntity(leader))
		{
			ServerCommand("sm_box %d", npc.index);
			PrintToChatAll("%i: Squad leader (leader %i) invalid, leaving squad... (squad %i)", iEntity, leader, squad);
			view_as<CTFBotSquad>(npc.m_Squad).Leave(npc.index);
		}
	}
}

#define MAX_ANIMTIME_INTERVAL 0.2
stock float GetAnimTimeInterval(int iEntity)
{
	float flInterval;
	
	float m_flAnimTime = GetEntPropFloat(iEntity, Prop_Data, "m_flAnimTime");
	float m_flPrevAnimTime = GetEntPropFloat(iEntity, Prop_Data, "m_flPrevAnimTime");
	
	if(m_flAnimTime < GetGameTime())
	{
		// estimate what it'll be this frame
		flInterval = clamp( GetGameTime() - m_flAnimTime, 0.0, MAX_ANIMTIME_INTERVAL );
	}
	else
	{
		// report actual
		flInterval = clamp( m_flAnimTime - m_flPrevAnimTime, 0.0, MAX_ANIMTIME_INTERVAL );
	}
	
	return flInterval;
}

stock void FireBullet(int m_pAttacker, int iWeapon, float m_vecSrc[3], float m_vecDirShooting[3], float m_flDamage, float m_flDistance, int nDamageType, const char[] tracerEffect)
{
	float vecEnd[3];
	vecEnd[0] = m_vecSrc[0] + m_vecDirShooting[0] * m_flDistance; 
	vecEnd[1] = m_vecSrc[1] + m_vecDirShooting[1] * m_flDistance;
	vecEnd[2] = m_vecSrc[2] + m_vecDirShooting[2] * m_flDistance;
	
	// Fire a bullet (ignoring the shooter).
	Handle trace = TR_TraceRayFilterEx(m_vecSrc, vecEnd, ( MASK_SOLID | CONTENTS_HITBOX ), RayType_EndPoint, WorldOnly, m_pAttacker);

	if ( TR_GetFraction(trace) < 1.0 )
	{
		// Verify we have an entity at the point of impact.
		if(TR_GetEntityIndex(trace) == -1)
		{
			delete trace;
			return;
		}
		
		float endpos[3];    TR_GetEndPosition(endpos, trace);
		
		if(TR_GetEntityIndex(trace) <= 0 || TR_GetEntityIndex(trace) > MaxClients)
		{
			float vecNormal[3];	TR_GetPlaneNormal(trace, vecNormal);
			GetVectorAngles(vecNormal, vecNormal);
			CreateParticle("impact_concrete", endpos, vecNormal);
		}
		
		// Regular impact effects.
		char effect[PLATFORM_MAX_PATH];
		Format(effect, PLATFORM_MAX_PATH, "%s", tracerEffect);
		
		if (tracerEffect[0])
		{
			if ( nDamageType & DMG_CRIT )
			{
				Format( effect, sizeof(effect), "%s_crit", tracerEffect );
			}

			float origin[3], angles[3];
			view_as<BaseNPC>(iWeapon).GetAttachment("muzzle", origin, angles);
			ShootLaser(iWeapon, effect, origin, endpos, false );
		}
		
	//	TE_SetupBeamPoints(m_vecSrc, endpos, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, 0.1, 0.1, 0.1, 5, 0.0, view_as<int>({255, 0, 255, 255}), 30);
	//	TE_SendToAll();
		
		SDKHooks_TakeDamage(TR_GetEntityIndex(trace), m_pAttacker, m_pAttacker, m_flDamage, nDamageType, -1, CalculateBulletDamageForce(m_vecDirShooting, 1.0), endpos);
	}
	
	delete trace;
}

float[] CalculateBulletDamageForce( const float vecBulletDir[3], float flScale )
{
	float vecForce[3]; vecForce = vecBulletDir;
	NormalizeVector( vecForce, vecForce );
	ScaleVector(vecForce, FindConVar("phys_pushscale").FloatValue);
	ScaleVector(vecForce, flScale);
	return vecForce;
}

public void Blend9Think(int iEntity)
{
	BaseNPC npc = view_as<BaseNPC>(iEntity);
	Address pLocomotion = npc.GetLocomotionInterface();
	if(pLocomotion == Address_Null)
		return;
	
	char MoveAnim[64], IdleAnim[64];
	npc.MoveAnim(MoveAnim, sizeof(MoveAnim));
	npc.IdleAnim(IdleAnim, sizeof(IdleAnim));
	
	int m_iMoveX = npc.LookupPoseParameter("move_x");
	int m_iMoveY = npc.LookupPoseParameter("move_y");
	
	if ( m_iMoveX < 0 || m_iMoveY < 0 )
		return;
	
	int iCurrSequence = GetEntProp(iEntity, Prop_Send, "m_nSequence");
	
	float flGroundSpeed = SDKCall(g_hGetGroundSpeed, pLocomotion);
	if ( flGroundSpeed != 0.0 )
	{
		int iSequenceMove = npc.LookupSequence(MoveAnim);
		
		if(!(GetEntityFlags(iEntity) & FL_ONGROUND))
		{
			if(iCurrSequence != iSequenceMove)
			{
				npc.SetAnimation(MoveAnim);
			}
		}
		else
		{
			if(iCurrSequence != iSequenceMove)
			{
				npc.SetAnimation(MoveAnim);
			}
		}

		float vecForward[3], vecRight[3], vecUp[3];
		SDKCall(g_hGetVectors, iEntity, vecForward, vecRight, vecUp);
		
		float vecMotion[3]
		SDKCall(g_hGetGroundMotionVector, pLocomotion, vecMotion);
		
		npc.SetPoseParameter(m_iMoveX, GetVectorDotProduct(vecMotion, vecForward));
		npc.SetPoseParameter(m_iMoveY, GetVectorDotProduct(vecMotion, vecRight));
	}
	else
	{
		int iSequenceIdle = npc.LookupSequence(IdleAnim);
		
		//Set Idle anim when not moving and if it's not already set
		if(iCurrSequence != iSequenceIdle)
		{
			npc.SetPoseParameter(m_iMoveX, 0.0);
			npc.SetPoseParameter(m_iMoveY, 0.0);
			
			npc.SetAnimation(IdleAnim);
		}
	}
	
	float m_flGroundSpeed = GetEntPropFloat(iEntity, Prop_Data, "m_flGroundSpeed");
	if(m_flGroundSpeed != 0.0)
	{
		float flReturnValue = clamp(flGroundSpeed / m_flGroundSpeed, -4.0, 12.0);
		
		SetEntPropFloat(iEntity, Prop_Send, "m_flPlaybackRate", flReturnValue);
		SetEntPropFloat(iEntity, Prop_Data, "m_speed", m_flGroundSpeed);
	}
}

void ComputePoseParam_AimYaw(int iEntity)
{
	BaseNPC npc = view_as<BaseNPC>(iEntity);
	
	Address pLocomotion = npc.GetLocomotionInterface();
	if(pLocomotion == Address_Null)
		return;
	
	// Check to see if we are moving.
	bool bMoving = SDKCall(g_hGetGroundSpeed, pLocomotion) != 0;
	
	if ( bMoving )
	{
		// The feet match the eye direction when moving - the move yaw takes care of the rest.
		npc.m_flGoalFeetYaw = npc.m_flEyeYaw;
	}
	// Else if we are not moving.
	else
	{
		// Initialize the feet.
		if ( npc.m_flLastAimTurnTime <= 0.0 )
		{
			npc.m_flGoalFeetYaw	= npc.m_flEyeYaw;
			npc.m_flCurrentFeetYaw = npc.m_flEyeYaw;
			npc.m_flLastAimTurnTime = GetGameTime();
		}
		// Make sure the feet yaw isn't too far out of sync with the eye yaw.
		else
		{
			float flYawDelta = AngleNormalize( npc.m_flGoalFeetYaw - npc.m_flEyeYaw );

			if ( FloatAbs( flYawDelta ) > 45.0 )
			{
				float flSide = ( flYawDelta > 0.0 ) ? -1.0 : 1.0;
				npc.m_flGoalFeetYaw += ( 45.0 * flSide );
			}
		}
	}

	// Fix up the feet yaw.
	npc.m_flGoalFeetYaw = AngleNormalize( npc.m_flGoalFeetYaw );
	if ( npc.m_flGoalFeetYaw != npc.m_flCurrentFeetYaw )
	{
		float temp = npc.m_flCurrentFeetYaw;
		ConvergeYawAngles( npc.m_flGoalFeetYaw, 720.0, GetGameFrameTime(), temp );
		npc.m_flCurrentFeetYaw = temp;
		npc.m_flLastAimTurnTime = GetGameTime();
	}

	// Find the aim(torso) yaw base on the eye and feet yaws.
	float flAimYaw = npc.m_flEyeYaw - npc.m_flCurrentFeetYaw;
	flAimYaw = clamp(AngleNormalize( flAimYaw ), -44.9, 44.9);
	
	int m_iAimYaw = npc.LookupPoseParameter("body_yaw");
	if ( m_iAimYaw < 0 )
		return;
	
	// Set the aim yaw and save.
	npc.SetPoseParameter( m_iAimYaw, -flAimYaw );
	
	float angle[3]; GetEntPropVector(iEntity, Prop_Data, "m_angRotation", angle);
	angle[1] = npc.m_flCurrentFeetYaw;
	TeleportEntity(iEntity, NULL_VECTOR, angle, NULL_VECTOR);
}

void ComputePoseParam_AimPitch(int iEntity)
{
	BaseNPC npc = view_as<BaseNPC>(iEntity);
	
	// Get the view pitch.
	float flAimPitch = npc.m_flEyePitch;
	
	int m_iAimPitch = npc.LookupPoseParameter("body_pitch");
	if ( m_iAimPitch < 0 )
		return;
	
	// Set the aim pitch pose parameter and save.
	npc.SetPoseParameter( m_iAimPitch, -flAimPitch );
}

public void OnEntityDestroyed(int entity)
{
	if(entity > MaxClients && entity <= 2048)
	{
		StopSound(entity, SNDCHAN_STATIC, ")mvm/giant_heavy/giant_heavy_gunfire.wav");
		StopSound(entity, SNDCHAN_STATIC, ")mvm/giant_heavy/giant_heavy_gunspin.wav");
		StopSound(entity, SNDCHAN_STATIC, ")mvm/giant_heavy/giant_heavy_loop.wav");
		
		BaseNPC npc = view_as<BaseNPC>(entity);
		Dynamic brain = npc.GetBrainInterface();
		
		if(brain.IsValid)
		{
			brain.Dispose();
			brain = INVALID_DYNAMIC_OBJECT;
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

	if(StrEqual(arg1, "squad", false))
	{
		PrintToChat(client, "Spawning a squad...");
		
		PetHeavy npc = new PetHeavy(client, flPos, flAng, "models/bots/heavy_boss/bot_heavy_boss.mdl", GetClientTeam(client));
		npc.Weapon = npc.EquipItem("head", "models/weapons/w_models/w_minigun.mdl", _, GetClientTeam(client) - 2);
		
		int hat = npc.EquipItem("head", "models/player/items/mvm_loot/heavy/robo_ushanka.mdl", _, GetClientTeam(client) - 2);
		SetVariantString("1.0"); AcceptEntityInput(hat, "SetModelScale");
		Dynamic squad = npc.m_Squad = CTFBotSquad(npc.index);
		
		BaseNPC	iLeader = npc;
		
		npc = new PetHeavy(client, flPos, flAng, "models/bots/heavy_boss/bot_heavy_boss.mdl", GetClientTeam(client));
		npc.Weapon = npc.EquipItem("head", "models/weapons/w_models/w_minigun.mdl", _, GetClientTeam(client) - 2);
		SetVariantString("1.5"); AcceptEntityInput(npc.index, "SetModelScale");
		view_as<CTFBotSquad>(iLeader.m_Squad).Join(npc.index);
		
		npc = new PetHeavy(client, flPos, flAng, "models/bots/heavy_boss/bot_heavy_boss.mdl", GetClientTeam(client));
		npc.Weapon = npc.EquipItem("head", "models/weapons/w_models/w_minigun.mdl", _, GetClientTeam(client) - 2);
		SetVariantString("1.5"); AcceptEntityInput(npc.index, "SetModelScale");
		view_as<CTFBotSquad>(iLeader.m_Squad).Join(npc.index);
		
		PrintToChatAll("GetMemberCount %i", view_as<CTFBotSquad>(squad).GetMemberCount());
		PrintToChatAll("m_hLeader %i", view_as<CTFBotSquad>(squad).m_hLeader);
	}
	else
	{
		int iTeam = StringToInt(arg1);
	
		PetHeavy npc = new PetHeavy(client, flPos, flAng, "models/bots/heavy_boss/bot_heavy_boss.mdl", iTeam);
		npc.Weapon = npc.EquipItem("head", "models/weapons/w_models/w_minigun.mdl", _, 8);
		int hat = npc.EquipItem("head", "models/player/items/mvm_loot/heavy/robo_ushanka.mdl", _, iTeam - 2);
		SetVariantString("1.0");
		AcceptEntityInput(hat, "SetModelScale");
	}
	
	return Plugin_Handled;
}

public Action Command_PetMenuNo(int client, int argc)
{
	//What are you.
	if(!(client > 0 && client <= MaxClients && IsClientInGame(client)))
		return Plugin_Handled;
	
	int pet = -1;
	while((pet = FindEntityByClassname(pet, "base_boss")) != -1)
	{
		PetHeavy npc = view_as<PetHeavy>(pet);
		bool isHeavy = (npc.m_iWeaponState != -1);
		if(isHeavy)
		{
			AcceptEntityInput(pet, "Kill");
		}
	}
	
	return Plugin_Handled;
}

public void OnMapStart()
{
	PrecacheModel("models/bots/heavy/bot_heavy.mdl");
	
	for (int i = 0; i < sizeof(gibs); i++)
	{
		PrecacheModel(gibs[i]);
	}
	
	PrecacheSound(")mvm/giant_heavy/giant_heavy_loop.wav");
	PrecacheSound(")mvm/giant_heavy/giant_heavy_gunwinddown.wav");
	PrecacheSound(")mvm/giant_heavy/giant_heavy_gunwindup.wav");
	PrecacheSound(")mvm/giant_heavy/giant_heavy_gunspin.wav");
	PrecacheSound(")mvm/giant_heavy/giant_heavy_gunfire.wav");
	PrecacheSound("mvm/sentrybuster/mvm_sentrybuster_explode.wav");
	
	PrecacheSound("^mvm/giant_common/giant_common_step_01.wav");
	PrecacheSound("^mvm/giant_common/giant_common_step_02.wav");
	PrecacheSound("^mvm/giant_common/giant_common_step_03.wav");
	PrecacheSound("^mvm/giant_common/giant_common_step_04.wav");
	PrecacheSound("^mvm/giant_common/giant_common_step_05.wav");
	PrecacheSound("^mvm/giant_common/giant_common_step_06.wav");
	PrecacheSound("^mvm/giant_common/giant_common_step_07.wav");
	PrecacheSound("^mvm/giant_common/giant_common_step_08.wav");
	
//	g_iPathLaserModelIndex = PrecacheModel("materials/sprites/laserbeam.vmt");
}

public void OnPluginStart()
{
	arrayList = new ArrayList();
	
	g_hDebug                 = CreateConVar("sm_heavynpc_debug",                      "0.0",    "Debug aiming", _, true, 0.0, true, 1.0);
	g_hAimRate               = CreateConVar("sm_heavynpc_head_aim_tracking_interval", "0.25",   "Aim Recalculate Interval");
	g_hHeadSteadyRate        = CreateConVar("sm_heavynpc_head_aim_steady_max_rate",   "100.0",  "Head aim steady max rate");
	g_hSaccadeSpeed          = CreateConVar("sm_heavynpc_saccade_speed",              "1000.0", "Max head angular velocity");
	g_hHeadResettleAngle     = CreateConVar("sm_heavynpc_head_resettle_angle",        "100.0",  "After rotating through this angle, the bot pauses to 'recenter' its virtual mouse on its virtual mousepad");
	g_hHeadResettleTime      = CreateConVar("sm_heavynpc_head_resettle_time",         "0.3",    "How long the bot pauses to 'recenter' its virtual mouse on its virtual mousepad");
	g_hHeadAimSettleDuration = CreateConVar("sm_heavynpc_head_aim_settle_duration",   "0.3",    "");

	RegAdminCmd("sm_heavy", Command_PetMenu, ADMFLAG_ROOT);
	RegAdminCmd("sm_heavyno", Command_PetMenuNo, ADMFLAG_ROOT);
	
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
	g_hHandleAnimEvent    = DHookCreateEx(hConf, "CBaseAnimating::HandleAnimEvent",  HookType_Entity, ReturnType_Void,   ThisPointer_CBaseEntity, CBaseAnimating_HandleAnimEvent);
	DHookAddParam(g_hHandleAnimEvent, HookParamType_ObjectPtr, -1);
	
	g_hGetFrictionSideways = DHookCreateEx(hConf, "ILocomotion::GetFrictionSideways",HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetFrictionSideways);
	g_hGetStepHeight       = DHookCreateEx(hConf, "ILocomotion::GetStepHeight",      HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetStepHeight);	
	g_hGetGravity          = DHookCreateEx(hConf, "ILocomotion::GetGravity",         HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetGravity);	
	g_hGetGroundNormal     = DHookCreateEx(hConf, "ILocomotion::GetGroundNormal",    HookType_Raw, ReturnType_VectorPtr, ThisPointer_Address, ILocomotion_GetGroundNormal);
	g_hGetMaxAcceleration  = DHookCreateEx(hConf, "ILocomotion::GetMaxAcceleration", HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetMaxAcceleration);
	g_hShouldCollideWith   = DHookCreateEx(hConf, "ILocomotion::ShouldCollideWith",  HookType_Raw, ReturnType_Bool,      ThisPointer_Address, ILocomotion_ShouldCollideWith);
	DHookAddParam(g_hShouldCollideWith, HookParamType_CBaseEntity);
	
	g_hGetSolidMask        = DHookCreateEx(hConf, "IBody::GetSolidMask",             HookType_Raw, ReturnType_Int,       ThisPointer_Address, IBody_GetSolidMask);
	g_hStartActivity       = DHookCreateEx(hConf, "IBody::StartActivity",            HookType_Raw, ReturnType_Bool,      ThisPointer_Address, IBody_StartActivity);
	g_hGetCurrencyValue    = DHookCreateEx(hConf, "CTFBaseBoss::GetCurrencyValue",   HookType_Entity, ReturnType_Int,    ThisPointer_Address, CTFBaseBoss_GetCurrencyValue);
	
	//Memory patches
	//Patch for the server not sending anim events above 4999 ( >= EVENT_CLIENT) by upping the number to 9999
	Address iAddr = GameConfGetAddress(hConf, "GetAnimationEvent");
	if(iAddr == Address_Null) SetFailState("Can't find GetAnimationEvent address for patch.");
	
	StoreToAddress(iAddr += view_as<Address>(131), 9999, NumberType_Int16);
	
/*	iAddr -= view_as<Address>(4);
	for (int i = 0; i < 7; i++)
	{
		int instruction = LoadFromAddress(iAddr + view_as<Address>(i), NumberType_Int8);
		PrintToServer("0x%x Int8: %i", instruction, instruction);
		
		instruction = LoadFromAddress(iAddr + view_as<Address>(i), NumberType_Int16);
		PrintToServer("0x%x Int16: %i", instruction, instruction);
		
		instruction = LoadFromAddress(iAddr + view_as<Address>(i), NumberType_Int32);
		PrintToServer("0x%x Int32: %i\n", instruction, instruction);
	}*/

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
	if(event == 7001)	//Footstep
	{
		EmitGameSoundToAll("MVM.GiantHeavyStep", pThis);
	}
	
//	PrintToServer("%i : %i", pThis, event);
}

public MRESReturn ILocomotion_GetGroundNormal(Address pThis, Handle hReturn, Handle hParams)     { DHookSetReturnVector(hReturn,    view_as<float>( { 0.0, 0.0, 1.0 } ));  return MRES_Supercede; }
public MRESReturn ILocomotion_GetStepHeight(Address pThis, Handle hReturn, Handle hParams)       { DHookSetReturn(hReturn, 18.0);	return MRES_Supercede; }
public MRESReturn ILocomotion_GetMaxAcceleration(Address pThis, Handle hReturn, Handle hParams)  { DHookSetReturn(hReturn, 1700.0); return MRES_Supercede; }
public MRESReturn ILocomotion_GetFrictionSideways(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturn(hReturn, 3.0);    return MRES_Supercede; }
public MRESReturn ILocomotion_ShouldCollideWith(Address pThis, Handle hReturn, Handle hParams)   { DHookSetReturn(hReturn, false);  return MRES_Supercede; }
public MRESReturn CTFBaseBoss_GetCurrencyValue(Address pThis, Handle hReturn, Handle hParams)    {DHookSetReturn(hReturn, 0);       return MRES_Supercede; }
public MRESReturn ILocomotion_GetGravity(Address pThis, Handle hReturn, Handle hParams)
{
	float flGravity = GetEntPropFloat(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis)), Prop_Data, "m_flGravity");
	DHookSetReturn(hReturn, flGravity == 0.0 ? 800.0 : flGravity);
	
	return MRES_Supercede;
}
public MRESReturn IBody_GetSolidMask(Address pThis, Handle hReturn, Handle hParams)              { DHookSetReturn(hReturn, (MASK_NPCSOLID|MASK_PLAYERSOLID)); return MRES_Supercede; }
public MRESReturn IBody_StartActivity(Address pThis, Handle hReturn, Handle hParams)             { DHookSetReturn(hReturn, true); return MRES_Supercede; }
public MRESReturn IBody_GetHullWidth(Address pThis, Handle hReturn, Handle hParams)              { DHookSetReturn(hReturn, 26.0); return MRES_Supercede; }
public MRESReturn IBody_GetStandHullHeight(Address pThis, Handle hReturn, Handle hParams)        { DHookSetReturn(hReturn, 68.0); return MRES_Supercede; }
public MRESReturn IBody_GetHullHeight(Address pThis, Handle hReturn, Handle hParams)             { DHookSetReturn(hReturn, 68.0); return MRES_Supercede; }
public MRESReturn IBody_GetCrouchHullHeight(Address pThis, Handle hReturn, Handle hParams)       { DHookSetReturn(hReturn, 32.0); return MRES_Supercede; }
public MRESReturn IBody_GetHullMins(Address pThis, Handle hReturn, Handle hParams)               { DHookSetReturnVector(hReturn, view_as<float>( { -13.0, -13.0, 0.0 } )); return MRES_Supercede; }
public MRESReturn IBody_GetHullMaxs(Address pThis, Handle hReturn, Handle hParams)               { DHookSetReturnVector(hReturn, view_as<float>( { 13.0, 13.0, 68.0 } ));  return MRES_Supercede; }

public void PluginBot_Approach(int bot_entidx, const float vec[3])
{
	BaseNPC npc = view_as<BaseNPC>(bot_entidx);
	npc.Approach(vec);	
	
	Address iVision = npc.GetVisionInterface();
	Address KnownEntity = SDKCall(g_hGetPrimaryKnownThreat, iVision, true);
	if(KnownEntity == Address_Null)
	{
		float vecTemp[3];
		
		for (int i = 5; i > 0; i--)
		{
			if(PF_GetFutureSegment(bot_entidx, i, vecTemp))
			{
				break;
			}
		}
		
		vecTemp[2] += 40.0;
		npc.AimHeadTowards(vecTemp, INTERESTING, 0.5, "Looking into the future");
	}
	
	float trash[3], trash2[3];
	bool bSeg1 = PF_GetFutureSegment(bot_entidx, 0, trash);
	bool bSeg2 = PF_GetFutureSegment(bot_entidx, 1, trash2);
	
	if(bSeg1 && GetVectorDistance(trash, WorldSpaceCenter(bot_entidx)) <= 80.0 && !bSeg2)
	{
		float vecDirection[3];
		vecDirection[0] = GetRandomFloat(-1.0, 1.0);
		vecDirection[1] = GetRandomFloat(-1.0, 1.0);
		vecDirection[2] = 0.0;
		
		ScaleVector(vecDirection, 2000.0);
		
		trash = WorldSpaceCenter(bot_entidx);
		AddVectors(trash, vecDirection, trash);
		
		//We've arrived.
		float pos[3];
		NavArea area = TheNavMesh.GetNearestNavArea_Vec(trash, true, 10000.0, false, true, 3);
		if(area != NavArea_Null)
		{
			area.GetCenter(pos);
			
			float unused;
			if(PF_IsPathToVectorPossible(bot_entidx, pos, unused))
			{
				PF_SetGoalVector(bot_entidx, pos);
			}
		}
	}
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

public void PluginBot_Jump(int bot_entidx, const float vecPos[3], const float dir[2])
{
	bool bOnGround = (GetEntPropEnt(bot_entidx, Prop_Data, "m_hGroundEntity") != -1);
	
	if(bOnGround)
	{
		float vecNPC[3], vecJumpVel[3];
		GetEntPropVector(bot_entidx, Prop_Data, "m_vecOrigin", vecNPC);
		
		float gravity = GetEntPropFloat(bot_entidx, Prop_Data, "m_flGravity");
		if(gravity <= 0.0)
			gravity = FindConVar("sv_gravity").FloatValue;
		
		// How fast does the headcrab need to travel to reach the position given gravity?
		float flActualHeight = vecPos[2] - vecNPC[2];
		float height = flActualHeight;
		if ( height < 16 )
		{
			height = 16.0;
		}

		// overshoot the jump by an additional 8 inches
		// NOTE: This calculation jumps at a position INSIDE the box of the enemy (player)
		// so if you make the additional height too high, the crab can land on top of the
		// enemy's head.  If we want to jump high, we'll need to move vecPos to the surface/outside
		// of the enemy's box.
	
		float additionalHeight = 0.0;
		if ( height < 32 )
		{
			additionalHeight = 8.0;
		}
		
		height += additionalHeight;
		
		// NOTE: This equation here is from vf^2 = vi^2 + 2*a*d
		float speed = SquareRoot( 2 * gravity * height );
		float time = speed / gravity;
	
		// add in the time it takes to fall the additional height
		// So the impact takes place on the downward slope at the original height
		time += SquareRoot( (2 * additionalHeight) / gravity );
		
		// Scale the sideways velocity to get there at the right time
		SubtractVectors( vecPos, vecNPC, vecJumpVel );
		vecJumpVel[0] /= time;
		vecJumpVel[1] /= time;
		vecJumpVel[2] /= time;
	
		// Speed to offset gravity at the desired height.
		vecJumpVel[2] = speed;
		
		// Don't jump too far/fast.
		float flJumpSpeed = GetVectorLength(vecJumpVel);
		float flMaxSpeed = 650.0;
		if ( flJumpSpeed > flMaxSpeed )
		{
			vecJumpVel[0] *= flMaxSpeed / flJumpSpeed;
			vecJumpVel[1] *= flMaxSpeed / flJumpSpeed;
			vecJumpVel[2] *= flMaxSpeed / flJumpSpeed;
		}
		
		BaseNPC npc = view_as<BaseNPC>(bot_entidx);
		npc.Jump();
		npc.SetVelocity(vecJumpVel);
		
		char JumpAnim[32];
		npc.JumpAnim(JumpAnim, sizeof(JumpAnim));
		
		if(!StrEqual(JumpAnim, ""))
		{
			npc.SetAnimation(JumpAnim);
		}
	}
}

public Action OnBotDamaged(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	float pos[3]; GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", pos);
	float ang[3]; GetEntPropVector(victim, Prop_Data, "m_angRotation", ang);
	
	if(view_as<BaseNPC>(attacker).GetTeam() != view_as<BaseNPC>(victim).GetTeam())
	{
		//Little baby men make heavy M A D.
		if (attacker > 0 && attacker <= MaxClients
		&& inflictor > 0 && inflictor <= MaxClients)
			AddThreat(victim, attacker);
		else
			AddThreat(victim, inflictor);
		
		CreateParticle("bot_impact_heavy", pos, ang);
	}
	
	if(damage >= GetEntProp(victim, Prop_Data, "m_iHealth"))
	{
		CreateParticle("bot_death", pos, ang);
		EmitSoundToAll("mvm/sentrybuster/mvm_sentrybuster_explode.wav", SOUND_FROM_WORLD, SNDCHAN_STATIC, 125, _, _, _, _, pos);
		
		// Spawn head gib.
		pos = WorldSpaceCenter(victim);
		pos[2] -= 100.0;
	
		float vel[3];
		vel[2] = 325.0; // Have the head shoot upwards.
		
		char model[PLATFORM_MAX_PATH];
		strcopy(model, sizeof(model), gibs[0]);
		
		if(strlen(model) > 0)
		{
			int gib = CreateEntityByName("prop_physics_multiplayer");
			DispatchKeyValue(gib, "model", model);
			DispatchKeyValue(gib, "physicsmode", "2");
	
			DispatchSpawn(gib);
	
			SetEntProp(gib, Prop_Send, "m_CollisionGroup", 1); // 24
			SetEntProp(gib, Prop_Send, "m_usSolidFlags", 0); // 8
			SetEntProp(gib, Prop_Send, "m_nSolidType", 2); // 6
			SetEntProp(gib, Prop_Send, "m_nSkin", view_as<BaseNPC>(victim).GetTeam() - 2);
	
			int effects = 16|64;
			SetEntProp(gib, Prop_Send, "m_fEffects", effects);
	
			TeleportEntity(gib, pos, ang, vel);
			
			SetVariantString("OnUser1 !self:Kill::10.0:1");
			AcceptEntityInput(gib, "AddOutput");
			AcceptEntityInput(gib, "FireUser1");
		}
		
		// Spawn arm/leg/torso gibs.
		for(int numGibs = 1; numGibs < sizeof(gibs) - 1; numGibs++)
		{
			for(int i = 0; i < 2; i++) pos[i] += GetRandomFloat(-42.0, 42.0);
	
			ang[1] = GetRandomFloat(-180.0, 180.0);
	
			for(int i = 0; i < 2; i++) vel[i] += GetRandomFloat(-100.0, 100.0);
			vel[2] = 300.0;
			
			strcopy(model, sizeof(model), gibs[numGibs]);
		
			if(strlen(model) > 0)
			{
				int gib = CreateEntityByName("prop_physics_multiplayer");
				DispatchKeyValue(gib, "model", model);
				DispatchKeyValue(gib, "physicsmode", "2");
		
				DispatchSpawn(gib);
		
				SetEntProp(gib, Prop_Send, "m_CollisionGroup", 1); // 24
				SetEntProp(gib, Prop_Send, "m_usSolidFlags", 0); // 8
				SetEntProp(gib, Prop_Send, "m_nSolidType", 2); // 6
				SetEntProp(gib, Prop_Send, "m_nSkin", view_as<BaseNPC>(victim).GetTeam() - 2);
		
				int effects = 16|64;
				SetEntProp(gib, Prop_Send, "m_fEffects", effects);
		
				TeleportEntity(gib, pos, ang, vel);
				
				SetVariantString("OnUser1 !self:Kill::10.0:1");
				AcceptEntityInput(gib, "AddOutput");
				AcceptEntityInput(gib, "FireUser1");
			}
		}
	}
	
	return Plugin_Continue;
}

public void AddThreat(int npc, int threat)
{
	if(!IsValidEntity(threat))
		return;
		
	Address iVision = view_as<BaseNPC>(npc).GetVisionInterface();
	if(iVision == Address_Null)
		return;
	
	Address KnownEntity = SDKCall(g_hGetKnown, iVision, threat);		
	if(KnownEntity == Address_Null)
	{
		SDKCall(g_hAddKnownEntity, iVision, threat);
		KnownEntity = SDKCall(g_hGetKnown, iVision, threat);
	}

	if(KnownEntity != Address_Null)
	{
		SDKCall(g_hUpdateVisibilityStatus, KnownEntity, true);
		SDKCall(g_hUpdatePosition, KnownEntity);
	}
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

stock void Explode(int client, float flPos[3], float flDamage, float flRadius, const char[] strParticle, const char[] strSound)
{
	int iBomb = CreateEntityByName("tf_generic_bomb");
	DispatchKeyValueVector(iBomb, "origin", flPos);
	DispatchKeyValueFloat(iBomb, "damage", flDamage);
	DispatchKeyValueFloat(iBomb, "radius", flRadius);
	DispatchKeyValue(iBomb, "health", "1");
	DispatchKeyValue(iBomb, "explode_particle", strParticle);
	DispatchKeyValue(iBomb, "sound", strSound);
	DispatchSpawn(iBomb);

//    AcceptEntityInput(iBomb, "Detonate");
	SDKHooks_TakeDamage(iBomb, client, client, 500.0);
}  

stock bool TF2_IsMvM()
{
	return view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
}

stock void ShootLaser(int weapon, const char[] strParticle, float flStartPos[3], float flEndPos[3], bool bResetParticles = false)
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
	TE_WriteNum("m_iParticleSystemIndex", stridx);
	TE_WriteNum("entindex", weapon);
	TE_WriteNum("m_iAttachType", 2);
	TE_WriteNum("m_iAttachmentPointIndex", 0);
	TE_WriteNum("m_bResetParticles", bResetParticles);    
	TE_WriteNum("m_bControlPoint1", 1);    
	TE_WriteNum("m_ControlPoint1.m_eParticleAttachment", 5);  
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[0]", flEndPos[0]);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[1]", flEndPos[1]);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[2]", flEndPos[2]);
	TE_SendToAll();
}

stock int TF2_CreateParticle(int iEnt, const char[] attachment, const char[] particle)
{
	int b = CreateEntityByName("info_particle_system");
	DispatchKeyValue(b, "effect_name", particle);
	DispatchSpawn(b);
	
	SetVariantString("!activator");
	AcceptEntityInput(b, "SetParent", iEnt);
	
	SetVariantString(attachment);
	AcceptEntityInput(b, "SetParentAttachment", iEnt);
	
	ActivateEntity(b);
	AcceptEntityInput(b, "Start");	
	
	return b;
}

void ConvergeYawAngles( float flGoalYaw, float flYawRate, float flDeltaTime, float &flCurrentYaw )
{
	// Find the yaw delta.
	float flDeltaYaw = flGoalYaw - flCurrentYaw;
	float flDeltaYawAbs = FloatAbs( flDeltaYaw );
	flDeltaYaw = AngleNormalize( flDeltaYaw );

	// Always do at least a bit of the turn (1%).
	float flScale = 1.0;
	flScale = flDeltaYawAbs / 60.0;
	flScale = clamp( flScale, 0.01, 1.0 );

	float flYaw = flYawRate * flDeltaTime * flScale;
	if ( flDeltaYawAbs < flYaw )
	{
		flCurrentYaw = flGoalYaw;
	}
	else
	{
		float flSide = ( flDeltaYaw < 0.0 ) ? -1.0 : 1.0;
		flCurrentYaw += ( flYaw * flSide );
	}

	flCurrentYaw = AngleNormalize( flCurrentYaw );
}

stock float[] WorldSpaceCenter(int entity)
{
	float vecPos[3];
	SDKCall(g_hSDKWorldSpaceCenter, entity, vecPos);
	
	return vecPos;
}

stock float fmodf(float num, float denom)
{
	return num - denom * RoundToFloor(num / denom);
}

stock float operator%(float oper1, float oper2)
{
	return fmodf(oper1, oper2);
}

stock float VecToYaw(float vec[3])
{
	if(vec[1] == 0.0 && vec[0] == 0.0)
		return 0.0;
		
	float yaw = ArcTangent2(vec[1], vec[0]);
	yaw = RAD2DEG(yaw);
	
	if(yaw < 0)
		yaw += 360;
		
	return yaw;
}

stock float AngleDiff( float destAngle, float srcAngle )
{
	float delta = fmodf(destAngle - srcAngle, 360.0);
	if ( destAngle > srcAngle )
	{
		if ( delta >= 180 )
			delta -= 360;
	}
	else
	{
		if ( delta <= -180 )
			delta += 360;
	}
	
	return delta;
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

stock float ApproachAngle( float target, float value, float speed )
{
	float delta = AngleDiff(target, value);
	
	// Speed is assumed to be positive
	if ( speed < 0 )
		speed = -speed;
	
	if ( delta < -180 )
		delta += 360;
	else if ( delta > 180 )
		delta -= 360;
	
	if ( delta > speed )
		value += speed;
	else if ( delta < -speed )
		value -= speed;
	else 
		value = target;
	
	return value;
}

stock float Approach( float target, float value, float speed )
{
	float delta = target - value;
	
	if ( delta > speed )
		value += speed;
	else if ( delta < -speed )
		value -= speed;
	else 
		value = target;
	
	return value;
}

stock float Max(float one, float two)
{
	if(one > two)
		return one;
	else if(two > one)
		return two;
		
	return two;
}

stock float Min(float one, float two)
{
	if(one < two)
		return one;
	else if(two < one)
		return two;
		
	return one;
}

stock void GetAbsVelocity(int client, float out[3])
{
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", out);
}

public bool WorldOnly(int entity, int contentsMask, any iExclude)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	
	if(StrEqual(class, "func_respawnroomvisualizer"))
	{
		return false;
	}
	else if(StrContains(class, "tf_projectile_", false) != -1)
	{
		return false;
	}
	
	return !(entity == iExclude);
}
