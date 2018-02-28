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

enum
{
	TF_AMMO_DUMMY = 0,
	TF_AMMO_PRIMARY,
	TF_AMMO_SECONDARY,
	TF_AMMO_METAL,
	TF_AMMO_GRENADES1,
	TF_AMMO_GRENADES2,
	TF_AMMO_COUNT,
};

char s_skeletonHatModels[][] = 
{
	"models/player/items/demo/crown.mdl",
	"models/player/items/all_class/skull_scout.mdl",
	"models/workshop/player/items/scout/hw2013_boston_bandy_mask/hw2013_boston_bandy_mask.mdl",
	"models/workshop/player/items/demo/hw2013_blackguards_bicorn/hw2013_blackguards_bicorn.mdl",
	"models/player/items/heavy/heavy_big_chief.mdl"
	
	//"models/player/items/all_class/xms_santa_hat_sniper.mdl"
}

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
Handle g_hDispatchAnimEvents;
Handle g_hGetMaxAcceleration;
Handle g_hGetGroundSpeed;
Handle g_hGetVectors;
Handle g_hGetGroundMotionVector;
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

//Player SDKCalls
Handle g_hGetMaxAmmo;
Handle g_hGetAmmoCount;

//PluginBot DHooks
Handle g_hGetEntity;
Handle g_hGetBot;

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

//Sentry Buster
//taunt_yeti

public Plugin myinfo = 
{
	name = "[TF2] Advanced Pets", 
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
		DispatchKeyValue(npc,       "model",      model);
		DispatchKeyValue(npc,       "modelscale", modelscale);
		DispatchKeyValue(npc,       "health",     health);
		DispatchSpawn(npc);
		
		CreateParticle("ghost_appearation", vecPos, vecAng);
		//CreateParticle("xms_snowburst", vecPos, vecAng);
		
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
		SetEntProp(npc, Prop_Data, "m_lifeState", 1); 
		SetEntProp(npc, Prop_Data, "m_nSolidType", 0); 

		ActivateEntity(npc);
		
		char strName[64];
		Format(strName, sizeof(strName), "basenpc_%x", EntIndexToEntRef(npc));
		
		Dynamic brain = Dynamic();
		brain.SetBool("Pathing", false);
		brain.SetInt ("Weapon",  INVALID_ENT_REFERENCE);
		brain.SetFloat("MoveSpeed", 150.0);
		brain.SetFloat("OutOfRange", 300.0);
		brain.SetBool("DoingSpecial", false);
		brain.SetVector("SpecialPos", NULL_VECTOR);
		brain.SetFloat("SpecialTime", 0.0);
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
	property bool DoingSpecial
	{
		public get()			
		{
			bool DoingSpecial = false;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				DoingSpecial = brain.GetBool("DoingSpecial");
			}
			
			return DoingSpecial;
		}
		public set(bool DoingSpecial)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetBool("DoingSpecial", DoingSpecial);
			}
		}
	}
	property float SpecialTime
	{
		public get()			
		{
			float SpecialTime = GetGameTime();
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				SpecialTime = brain.GetFloat("SpecialTime");
			}
			
			return SpecialTime;
		}
		public set(float SpecialTime)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("SpecialTime", SpecialTime);
			}
		}
	}
	
	public bool GetSpecialPos(float[3] value)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetBrainInterface().GetMemberOffset("SpecialPos");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic!");
		}
		this.GetBrainInterface().GetVectorByOffset(offset, value);
		return true;
	}
	public void SetSpecialPos(const float[3] value)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetBrainInterface().GetMemberOffset("SpecialPos");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetBrainInterface().SetVector("SpecialPos", value);
				return;
			}
		}
		this.GetBrainInterface().SetVectorByOffset(offset, value);
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
		PF_EnableCallback(this.index, PFCB_ClimbUpToLedge, PluginBot_Jump);
		PF_EnableCallback(this.index, PFCB_GetPathCost, PluginBot_PathCost);
		PF_EnableCallback(this.index, PFCB_OnMoveToFailure, PluginBot_PathFail);
		//PF_EnableCallback(this.index, PFCB_OnContact, PluginBot_OnContact);
		PF_EnableCallback(this.index, PFCB_OnActorEmoted, PluginBot_OnActorEmoted);
	}	
	public void Approach(const float vecGoal[3])
	{
		SDKCall(g_hApproach, this.GetLocomotionInterface(), vecGoal, 0.1);
	}	
	public void FaceTowards(const float vecGoal[3], float speed = 250.0)
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
			int iOwner = GetEntPropEnt(this.index, Prop_Send, "m_hOwnerEntity");
			
			this.DoingSpecial = false;
			PF_SetGoalEntity(this.index, iOwner);
		
			SDKCall(g_hClearStuckStatus, this.GetLocomotionInterface(), "Un-Stuck");
			TeleportEntity(this.index, WorldSpaceCenter(iOwner), NULL_VECTOR, NULL_VECTOR);
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

methodmap PetMedic < BaseNPC
{
	public PetMedic(int client, float vecPos[3], float vecAng[3], const char[] model)
	{
		BaseNPC pet = BaseNPC(vecPos, vecAng, model, "0.5");
		
		SetEntProp(pet.index,      Prop_Send, "m_nSkin",        GetClientTeam(client) - 2);
		SetEntPropEnt(pet.index,   Prop_Send, "m_hOwnerEntity", client);
		
		Dynamic brain = pet.GetBrainInterface();
		brain.SetBool ("Healing",      false);
		brain.SetInt  ("BeamEntity",   INVALID_ENT_REFERENCE);
		brain.SetFloat("NextHealTime", 0.0);
		
		//REQUIRED
		brain.SetString("MoveAnim", "run_SECONDARY");
		brain.SetFloat("MoveSpeed", 150.0);
		brain.SetString("IdleAnim", "stand_SECONDARY");
		brain.SetFloat("OutOfRange", 300.0);
		//////////
		
		pet.CreatePather(client, 18.0, 64.0, 1000.0, MASK_NPCSOLID | MASK_PLAYERSOLID, 50.0, 0.5, 1.0);
		pet.SetAnimation("run_SECONDARY");
		pet.Pathing = true;
		
		SDKUnhook(pet.index, SDKHook_Think, BasicPetThink);
		SDKHook(pet.index, SDKHook_Think, PetMedicThink);
		SDKHook(pet.index, SDKHook_Think, Blend9Think);
		
		//pet.EquipItem("head", "models/player/items/all_class/xms_santa_hat_medic.mdl");
		
		return view_as<PetMedic>(pet);
	}
	
	property int BeamEntity
	{
		public get()			
		{
			int ent = INVALID_ENT_REFERENCE;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				ent = EntRefToEntIndex(brain.GetInt("BeamEntity"));
			}
			
			return ent;
		}
		public set(int BeamEntity)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetInt("BeamEntity", EntIndexToEntRef(BeamEntity));
			}
		}
	}
	property bool Healing
	{
		public get()			
		{
			bool Healing = false;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				Healing = brain.GetBool("Healing");
			}
			
			return Healing;
		}
		public set(bool Healing)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetBool("Healing", Healing);
			}
		}
	}
	property float NextHealTime
	{
		public get()			
		{
			float NextHealTime = GetGameTime();
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				NextHealTime = brain.GetFloat("NextHealTime");
			}
			
			return NextHealTime;
		}
		public set(float NextHealTime)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("NextHealTime", NextHealTime);
			}
		}
	}
	
	public void StartHealing(int iEnt)
	{
		int client = GetEntPropEnt(this.index, Prop_Send, "m_hOwnerEntity");
		
		int iWeapon = this.Weapon;
		if(iWeapon != INVALID_ENT_REFERENCE)
		{
			this.BeamEntity = TF2_CreateBeam(iWeapon, "muzzle", client, "flag", GetClientTeam(client) == 2 ? "medicgun_beam_red" : "medicgun_beam_blue");
			this.Healing = true;
			
			EmitSoundToAll(")weapons/medigun_heal.wav", this.index, SNDCHAN_WEAPON);
		}
	}	
	public void StopHealing()
	{
		int iBeam = this.BeamEntity;
		if(iBeam != INVALID_ENT_REFERENCE)
		{
			int iBeamTarget = GetEntPropEnt(iBeam, Prop_Send, "m_hOwnerEntity");
			if(IsValidEntity(iBeamTarget))
			{
				AcceptEntityInput(iBeamTarget, "ClearParent");
				AcceptEntityInput(iBeamTarget, "Kill");
			}
			
			AcceptEntityInput(iBeam, "ClearParent");
			AcceptEntityInput(iBeam, "Kill");
			
			EmitSoundToAll(")weapons/medigun_no_target.wav", this.index, SNDCHAN_WEAPON);
			
			StopSound(this.index, SNDCHAN_WEAPON, ")weapons/medigun_heal.wav");
			
			this.Healing = false;
		}
	}
}

methodmap PetTank < BaseNPC
{
	public PetTank(int client, float vecPos[3], float vecAng[3], const char[] model)
	{
		BaseNPC pet = BaseNPC(vecPos, vecAng, model, "0.15", _, false);
		
		SetEntProp(pet.index,      Prop_Send, "m_nSkin",         GetRandomInt(0, 1));
		SetEntPropEnt(pet.index,   Prop_Send, "m_hOwnerEntity", client);
		
		Dynamic brain = pet.GetBrainInterface();
		brain.SetInt("LeftTrack", INVALID_ENT_REFERENCE);
		brain.SetInt("RightTrack", INVALID_ENT_REFERENCE);
		brain.SetInt("Bomb", INVALID_ENT_REFERENCE);
		brain.SetBool("Deploying", false);
		
		pet.CreatePather(client, 18.0, 64.0, 1000.0, MASK_NPCSOLID | MASK_PLAYERSOLID, 50.0, 0.5, 1.0);
		pet.SetAnimation("movement");
		pet.Pathing = true;
		
		EmitSoundToAll(")mvm/mvm_tank_start.wav", pet.index);
		//EmitSoundToAll(")mvm/mvm_tank_loop.wav",  pet.index, _, _, _, 0.20);
		
		TF2_CreateParticle(pet.index, "smoke_attachment", "buildingdamage_smoke3");
		
		SDKUnhook(pet.index, SDKHook_Think, BasicPetThink);
		SDKHook(pet.index, SDKHook_Think, PetTankThink);
		
		return view_as<PetTank>(pet);
	}
	
	property int LeftTrack
	{
		public get()
		{
			int ent = INVALID_ENT_REFERENCE;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				ent = EntRefToEntIndex(brain.GetInt("LeftTrack"));
			}
			
			return ent;
		}
		public set(int LeftTrack)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetInt("LeftTrack", EntIndexToEntRef(LeftTrack));
			}
		}
	}
	property int RightTrack
	{
		public get()			
		{
			int ent = INVALID_ENT_REFERENCE;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				ent = EntRefToEntIndex(brain.GetInt("RightTrack"));
			}
			
			return ent;
		}
		public set(int RightTrack)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetInt("RightTrack", EntIndexToEntRef(RightTrack));
			}
		}
	}
	property int Bomb
	{
		public get()			
		{
			int ent = INVALID_ENT_REFERENCE;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				ent = EntRefToEntIndex(brain.GetInt("Bomb"));
			}
			
			return ent;
		}
		public set(int Bomb)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetInt("Bomb", EntIndexToEntRef(Bomb));
			}
		}
	}
	property bool Deploying
	{
		public get()			
		{
			bool Deploying = false;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				Deploying = brain.GetBool("Deploying");
			}
			
			return Deploying;
		}
		public set(bool Deploying)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetBool("Deploying", Deploying);
			}
		}
	}
}

methodmap PetEngineer < BaseNPC
{
	public PetEngineer(int client, float vecPos[3], float vecAng[3])
	{
		BaseNPC pet = BaseNPC(vecPos, vecAng, "models/bots/engineer/bot_engineer.mdl", "0.5");
		
		SetEntProp(pet.index,      Prop_Send, "m_nSkin",        GetClientTeam(client) - 2);
		SetEntPropEnt(pet.index,   Prop_Send, "m_hOwnerEntity", client);
		
		Dynamic brain = pet.GetBrainInterface();
		
		//REQUIRED IF YOU'RE GOING TO USE Blend9Think
		brain.SetString("MoveAnim", "Run_MELEE", 64);
		brain.SetFloat("MoveSpeed", 115.0);
		brain.SetString("IdleAnim", "Stand_MELEE", 64);
		brain.SetFloat("OutOfRange", 300.0);
		//////////
		
		brain.SetBool("GettingAmmo", false);
		brain.SetBool("CarryingAmmo", false);
		brain.SetInt("AmmoRef", INVALID_ENT_REFERENCE);
		brain.SetFloat("NextAmmoCheckTime", GetGameTime() + 5.0);
		
		pet.CreatePather(client, 18.0, 64.0, 1000.0, MASK_NPCSOLID | MASK_PLAYERSOLID, 50.0, 0.5, 1.0);
		pet.SetAnimation("Stand_PRIMARY");
		pet.Pathing = true;
		
		//Unhook because we have our own think function.
		SDKUnhook(pet.index, SDKHook_Think, BasicPetThink);
		//You can implement your own pet functions here.
		SDKHook(pet.index, SDKHook_Think, PetEngineerThink);
		//Controls 9 way blend animation managing
		SDKHook(pet.index, SDKHook_Think, Blend9Think);
		
		//pet.EquipItem("head", "models/player/items/all_class/xms_santa_hat_engineer.mdl");
		
		return view_as<PetEngineer>(pet);
	}
	
	property int AmmoRef
	{
		public get()			
		{
			int ent = INVALID_ENT_REFERENCE;
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				ent = EntRefToEntIndex(brain.GetInt("AmmoRef"));
			}
			
			return ent;
		}
		public set(int AmmoRef)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetInt("AmmoRef", EntIndexToEntRef(AmmoRef));
			}
		}
	}
	property bool IsGettingAmmo
	{
		public get()
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				return brain.GetBool("GettingAmmo");
			}
			
			return false;
		}
		public set(bool state)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetBool("GettingAmmo", state);
			}
		}
	}
	property bool IsCarryingAmmo
	{
		public get()
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				return brain.GetBool("CarryingAmmo");
			}
			
			return false;
		}
		public set(bool state)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetBool("CarryingAmmo", state);
			}
		}
	}
	property float NextAmmoCheckTime
	{
		public get()			
		{
			float NextAmmoCheckTime = GetGameTime();
		
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				NextAmmoCheckTime = brain.GetFloat("NextAmmoCheckTime");
			}
			
			return NextAmmoCheckTime;
		}
		public set(float NextAmmoCheckTime)
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetFloat("NextAmmoCheckTime", NextAmmoCheckTime);
			}
		}
	}
	
	public void StopAmmoHunt()
	{
		int client = GetEntPropEnt(this.index, Prop_Send, "m_hOwnerEntity");
	
		PF_SetGoalEntity(this.index, client);
		
		this.IsGettingAmmo = false;
		this.Pathing = true;
		
		Dynamic brain = this.GetBrainInterface();
		brain.SetString("MoveAnim", "Run_MELEE", 64);
		brain.SetFloat("MoveSpeed", 115.0);
		brain.SetString("IdleAnim", "Stand_MELEE", 64);
		brain.SetFloat("OutOfRange", 300.0);
		
		AcceptEntityInput(this.Weapon, "Kill");
		this.Weapon = this.EquipItem("head", "models/weapons/w_models/w_wrench.mdl", _, GetClientTeam(client) - 2);
		
		SetVariantString("1.0");
		AcceptEntityInput(this.Weapon, "SetModelScale");
	}
}

methodmap PetMerasmus < BaseNPC
{
	public PetMerasmus(int client, float vecPos[3], float vecAng[3])
	{
		BaseNPC pet = BaseNPC(vecPos, vecAng, "models/bots/merasmus/merasmus.mdl", "0.25");
		
		SetEntProp(pet.index,      Prop_Send, "m_nSkin",        GetRandomInt(1, 2));
		SetEntPropEnt(pet.index,   Prop_Send, "m_hOwnerEntity", client);
		SetEntProp(pet.index, Prop_Send, "m_nBody", 2);
		
		Dynamic brain = pet.GetBrainInterface();
		//REQUIRED
		brain.SetString("MoveAnim", "run_MELEE");
		brain.SetFloat("MoveSpeed", 150.0);
		brain.SetString("IdleAnim", "stand_MELEE");
		brain.SetFloat("OutOfRange", 300.0);
		//////////
		
		pet.CreatePather(client, 18.0, 64.0, 1000.0, MASK_NPCSOLID | MASK_PLAYERSOLID, 50.0, 0.5, 1.0);
		pet.SetAnimation("run_MELEE");
		pet.Pathing = true;
		
		SDKUnhook(pet.index, SDKHook_Think, BasicPetThink);
		SDKHook(pet.index, SDKHook_Think, Blend9Think);
		SDKHook(pet.index, SDKHook_Think, PetMerasmusThink);
		
		//pet.EquipItem("head", "models/player/items/all_class/xms_santa_hat_sniper.mdl");
		
		return view_as<PetMerasmus>(pet);
	}
}

methodmap PetSkeletonKing < BaseNPC
{
	public PetSkeletonKing(int client, float vecPos[3], float vecAng[3])
	{
		BaseNPC pet = BaseNPC(vecPos, vecAng, "models/bots/skeleton_sniper_boss/skeleton_sniper_boss.mdl", "0.65");
		
		SetEntProp(pet.index,      Prop_Send, "m_nSkin",        GetRandomInt(0, 3));
		SetEntPropEnt(pet.index,   Prop_Send, "m_hOwnerEntity", client);
		
		Dynamic brain = pet.GetBrainInterface();
		//REQUIRED
		brain.SetString("MoveAnim", "run_MELEE");
		brain.SetFloat("MoveSpeed", 150.0);
		brain.SetString("IdleAnim", "stand_MELEE");
		brain.SetFloat("OutOfRange", 300.0);
		//////////
		
		pet.CreatePather(client, 18.0, 64.0, 1000.0, MASK_NPCSOLID | MASK_PLAYERSOLID, 50.0, 0.5, 1.0);
		pet.Pathing = true;
		
		SDKUnhook(pet.index, SDKHook_Think, BasicPetThink);
		SDKHook(pet.index, SDKHook_Think, Blend9Think);
		SDKHook(pet.index, SDKHook_Think, PetSkeleKingThink);
		
		return view_as<PetSkeletonKing>(pet);
	}
}

methodmap PetMiniMe < BaseNPC
{
	public PetMiniMe(int client, float vecPos[3], float vecAng[3])
	{
		char strModel[PLATFORM_MAX_PATH];
		GetEntPropString(client, Prop_Data, "m_ModelName", strModel, PLATFORM_MAX_PATH);
		
		BaseNPC pet = BaseNPC(vecPos, vecAng, strModel, "0.5");
		
//		SetEntProp(pet.index, Prop_Data, "m_nBody", 2);
		SetEntProp(pet.index, Prop_Send, "m_nSkin", GetClientTeam(client) - 2);
		SetEntProp(pet.index, Prop_Send, "m_hOwnerEntity", client);
		SetEntPropEnt(pet.index, Prop_Send, "m_hOwnerEntity", client);
		
		Dynamic brain = pet.GetBrainInterface();
		//REQUIRED
		brain.SetString("MoveAnim", "run_MELEE");
		brain.SetFloat("MoveSpeed", 150.0);
		brain.SetString("IdleAnim", "stand_MELEE");
		brain.SetFloat("OutOfRange", 300.0);
		//////////
		
		pet.CreatePather(client, 18.0, 64.0, 1000.0, MASK_NPCSOLID | MASK_PLAYERSOLID, 50.0, 0.5, 1.0);
		pet.Pathing = true;
		
		SDKHook(pet.index, SDKHook_Think, Blend9Think);
		
		//Mirror wearables
		int iWearable = -1;
		while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable*")) != -1)
		{
			if(!GetEntProp(iWearable, Prop_Send, "m_bDisguiseWearable") && GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity") == client)
			{
				GetEntPropString(iWearable, Prop_Data, "m_ModelName", strModel, PLATFORM_MAX_PATH);
				int iItem = pet.EquipItem("head", strModel, _, GetClientTeam(client) - 2);
				
				SetVariantString("1.0");
				AcceptEntityInput(iItem, "SetModelScale");
			}
		}
		
		int iMelee = GetPlayerWeaponSlot(client, 2);
		
		int table = FindStringTable("modelprecache");
		ReadStringTable(table, GetEntProp(iMelee, Prop_Send, "m_iWorldModelIndex"), strModel, PLATFORM_MAX_PATH);  
		
		iMelee = pet.EquipItem("head", strModel, _, GetClientTeam(client) - 2);
		
		SetVariantString("1.0");
		AcceptEntityInput(iMelee, "SetModelScale");
		
		return view_as<PetMiniMe>(pet);
	}
}

methodmap PetYeti < BaseNPC
{
	public PetYeti(int client, float vecPos[3], float vecAng[3])
	{
		BaseNPC pet = BaseNPC(vecPos, vecAng, "models/player/heavy.mdl", "0.5");
		
		SetEntProp(pet.index,      Prop_Send, "m_nRenderFX", 6);
		SetEntProp(pet.index,      Prop_Send, "m_nSkin",        GetRandomInt(0, 3));
		SetEntPropEnt(pet.index,   Prop_Send, "m_hOwnerEntity", client);
		
		Dynamic brain = pet.GetBrainInterface();
		//REQUIRED
		brain.SetString("MoveAnim", "run_MELEE");
		brain.SetFloat("MoveSpeed", 150.0);
		brain.SetString("IdleAnim", "stand_MELEE");
		brain.SetFloat("OutOfRange", 300.0);
		//////////
		
		pet.CreatePather(client, 18.0, 64.0, 1000.0, MASK_NPCSOLID | MASK_PLAYERSOLID, 50.0, 0.5, 1.0);
		pet.Pathing = true;
		
		SDKUnhook(pet.index, SDKHook_Think, BasicPetThink);
		SDKHook(pet.index, SDKHook_Think, Blend9Think);
		SDKHook(pet.index, SDKHook_Think, PetYetiThink);
				
		pet.EquipItem("head", "models/player/items/taunts/yeti/yeti.mdl");
		//pet.EquipItem("head", "models/player/items/all_class/xms_santa_hat_heavy.mdl");
		
		return view_as<PetYeti>(pet);
	}
}

methodmap PetDeskBoy < BaseNPC
{
	public PetDeskBoy(int client, float vecPos[3], float vecAng[3])
	{
		BaseNPC pet = BaseNPC(vecPos, vecAng, "models/player/engineer.mdl", "0.5");
		
		SetEntProp(pet.index,      Prop_Send, "m_nSkin",        GetClientTeam(client) - 2);
		SetEntPropEnt(pet.index,   Prop_Send, "m_hOwnerEntity", client);
		
		Dynamic brain = pet.GetBrainInterface();
		//REQUIRED
		brain.SetString("MoveAnim", "taunt_russian");
		brain.SetFloat("MoveSpeed", 150.0);
		brain.SetString("IdleAnim", "taunt_russian");
		brain.SetFloat("OutOfRange", 300.0);
		//////////
		
		int iSequenceMove = SDKCall(g_hLookupSequence, pet.GetStudioHdr(), "taunt_russian");
		SDKCall(g_hResetSequence, pet.index, iSequenceMove);
		
		pet.CreatePather(client, 18.0, 64.0, 1000.0, MASK_NPCSOLID | MASK_PLAYERSOLID, 50.0, 0.5, 1.0);
		pet.Pathing = true;
		
		//SDKUnhook(pet.index, SDKHook_Think, BasicPetThink);
		SDKHook(pet.index, SDKHook_Think, DeskBoyThink);
		
		//pet.EquipItem("head", "models/player/items/all_class/xms_santa_hat_engineer.mdl");
		
		return view_as<PetDeskBoy>(pet);
	}
}

methodmap PetBuster < BaseNPC
{
	public PetBuster(int client, float vecPos[3], float vecAng[3])
	{
		BaseNPC pet = BaseNPC(vecPos, vecAng, "models/bots/demo/bot_sentry_buster.mdl", "0.5");
		SetEntPropEnt(pet.index,   Prop_Send, "m_hOwnerEntity", client);
		
		Dynamic brain = pet.GetBrainInterface();
		//REQUIRED
		brain.SetString("MoveAnim", "Run_MELEE");
		brain.SetFloat("MoveSpeed", 150.0);
		brain.SetString("IdleAnim", "Stand_MELEE");
		brain.SetFloat("OutOfRange", 300.0);
		//////////
		
		pet.CreatePather(client, 18.0, 64.0, 1000.0, MASK_NPCSOLID | MASK_PLAYERSOLID, 50.0, 0.5, 1.0);
		pet.Pathing = true;
		
		SDKUnhook(pet.index, SDKHook_Think, BasicPetThink);
		SDKHook(pet.index, SDKHook_Think, Blend9Think);
		SDKHook(pet.index, SDKHook_Think, SentryBusterThink);

		return view_as<PetBuster>(pet);
	}
}


//Stop when near owner
//Adjust speed near owner
//Run update
public void BasicPetThink(int iEntity)
{
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		AcceptEntityInput(iEntity, "Kill");
		return;
	}
	
	BaseNPC npc = view_as<BaseNPC>(iEntity);
	npc.Update();
	
	float flOrigin[3], flAbsAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin",   flOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	float flMoveSpeed  = npc.MoveSpeed;
	float flOutOfRange = npc.OutOfRange;
	
	float flCPos[3]; GetClientAbsOrigin(client, flCPos);
	float flDistance = GetVectorDistance(flCPos, flOrigin);
	
	//We don't wanna fall too behind.
	SetEntPropFloat(iEntity, Prop_Data, "m_speed", (flDistance >= flOutOfRange) ? (flMoveSpeed * 2) : (flMoveSpeed));
	
	//Do something 
	if(npc.DoingSpecial)
	{
		npc.DoingSpecial = false;
		PF_SetGoalEntity(npc.index, client);
		PrintToChat(client, "No.");
	}
	
	if(flDistance <= (flOutOfRange / 2))	
	{
		if(npc.Pathing)
		{
			npc.Pathing = false;
		}
	}
	else
	{
		if(!npc.Pathing)
		{
			npc.Pathing = true;
		}
	}
}

public void PetYetiThink(int iEntity)
{
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		AcceptEntityInput(iEntity, "Kill");
		return;
	}
	
	//taunt_demo_nuke_shroomcloud
	PetYeti npc = view_as<PetYeti>(iEntity);
	npc.Update();
	
	float flOrigin[3], flAbsAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin",   flOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	float flMoveSpeed  = npc.MoveSpeed;
	float flOutOfRange = npc.OutOfRange;
	
	float flCPos[3]; GetClientAbsOrigin(client, flCPos);
	float flDistance = GetVectorDistance(flCPos, flOrigin);
	
	//We don't wanna fall too behind.
	SetEntPropFloat(iEntity, Prop_Data, "m_speed", (flDistance >= flOutOfRange) ? (flMoveSpeed * 2) : (flMoveSpeed));

	//Stomp
	if(npc.DoingSpecial)
	{
		float SpecialPos[3];
		npc.GetSpecialPos(SpecialPos);
		
		if(GetVectorDistance(SpecialPos, flOrigin) <= 20.0 || !npc.Pathing)
		{
			if(npc.Pathing)
			{
				npc.PlayGesture("taunt_yeti", false);
				npc.SpecialTime = GetGameTime() + 5.3;
			}
			
			npc.Pathing = false;
			
			float SpecialTime = npc.SpecialTime - GetGameTime();
			if(SpecialTime <= 0.0)
			{
				CreateParticle("weightdrop", flOrigin, flAbsAngles);
				Explode(client, flOrigin, 100.0, 100.0, "", "");
				npc.SpecialTime = GetGameTime() + 10.0; //Don't repeat
			}
			
			//Needed because sometimes if i'm just calling !IsPlayingGesture it might miss it due to autokill.
			int iSequence = npc.LookupSequence("taunt_yeti");
			int iLayer = FindGestureLayer(npc.index, iSequence);
			if(iLayer != -1)
			{
				CBaseAnimatingOverlay overlay = CBaseAnimatingOverlay(npc.index);
				CAnimationLayer layer = overlay.GetLayer(iLayer);
				
				float flCycle = layer.Get(m_flCycle);
				if(flCycle >= 1.0)
				{
					layer.KillMe();
					npc.DoingSpecial = false;
					PF_SetGoalEntity(npc.index, client);
				}
			}
		}
	}
	else
	{
		if(flDistance <= (flOutOfRange / 2))
		{
			if(npc.Pathing)
			{
				npc.Pathing = false;
			}
		}
		else
		{
			if(!npc.Pathing)
			{
				npc.Pathing = true;
			}
		}
	}
}

public void SentryBusterThink(int iEntity)
{
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		AcceptEntityInput(iEntity, "Kill");
		return;
	}
	
	//taunt_demo_nuke_shroomcloud
	PetYeti npc = view_as<PetYeti>(iEntity);
	npc.Update();
	
	float flOrigin[3], flAbsAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin",   flOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	float flMoveSpeed  = npc.MoveSpeed;
	float flOutOfRange = npc.OutOfRange;
	
	float flCPos[3]; GetClientAbsOrigin(client, flCPos);
	float flDistance = GetVectorDistance(flCPos, flOrigin);
	
	//We don't wanna fall too behind.
	SetEntPropFloat(iEntity, Prop_Data, "m_speed", (flDistance >= flOutOfRange) ? (flMoveSpeed * 2) : (flMoveSpeed));

	//Stomp
	if(npc.DoingSpecial)
	{
		float SpecialPos[3];
		npc.GetSpecialPos(SpecialPos);
		
		if(GetVectorDistance(SpecialPos, flOrigin) <= 20.0 || !npc.Pathing)
		{
			if(npc.Pathing)
			{
				EmitSoundToAll(")mvm/sentrybuster/mvm_sentrybuster_spin.wav", npc.index, _, _, _, 0.30);
				
				StopSound(npc.index, SNDCHAN_STATIC, "mvm/sentrybuster/mvm_sentrybuster_loop.wav");
				
				npc.PlayGesture("sentry_buster_preExplode", false);
				npc.SpecialTime = GetGameTime() + 5.3;
			}
			
			npc.Pathing = false;
			
			float SpecialTime = npc.SpecialTime - GetGameTime();
			if(SpecialTime <= 0.0)
			{
				npc.SpecialTime = GetGameTime() + 10.0; //Don't repeat
			}
			
			//Needed because sometimes if i'm just calling !IsPlayingGesture it might miss it due to autokill.
			int iSequence = npc.LookupSequence("sentry_buster_preExplode");
			int iLayer = FindGestureLayer(npc.index, iSequence);
			if(iLayer != -1)
			{
				CBaseAnimatingOverlay overlay = CBaseAnimatingOverlay(npc.index);
				CAnimationLayer layer = overlay.GetLayer(iLayer);
				
				float flCycle = layer.Get(m_flCycle);
				if(flCycle >= 1.0)
				{
					layer.KillMe();
					npc.DoingSpecial = false;
					PF_SetGoalEntity(npc.index, client);
					
					StopSound(npc.index, SNDCHAN_STATIC, "mvm/sentrybuster/mvm_sentrybuster_loop.wav");
					
					EmitSoundToAll(")mvm/sentrybuster/mvm_sentrybuster_explode.wav", npc.index, _, _, _, 0.30);
					
					Explode(client, flOrigin, 200.0, 100.0, "eotl_pyro_pool_explosion", "");
				}
			}
		}
	}
	else
	{
		if(flDistance <= (flOutOfRange / 2))
		{
			if(npc.Pathing)
			{
				npc.Pathing = false;
			}
		}
		else
		{
			if(!npc.Pathing)
			{
				npc.Pathing = true;
			}
		}
	}
}

public void DeskBoyThink(int iEntity)
{
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		AcceptEntityInput(iEntity, "Kill");
		return;
	}
	
	SetEntProp(iEntity, Prop_Data, "m_bSequenceLoops", true);
	//SetEntPropFloat(iEntity, Prop_Send, "m_flPlaybackRate", Cosine(GetGameTime() * 0.5 + 2.0);
}

public void PetMerasmusThink(int iEntity)
{
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		AcceptEntityInput(iEntity, "Kill");
		return;
	}
	
	PetMerasmus npc = view_as<PetMerasmus>(iEntity);
	npc.Update();
	
	float flOrigin[3], flAbsAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin",   flOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	float flMoveSpeed  = npc.MoveSpeed;
	float flOutOfRange = npc.OutOfRange;
	
	float flCPos[3]; GetClientAbsOrigin(client, flCPos);
	float flDistance = GetVectorDistance(flCPos, flOrigin);
	
	//We don't wanna fall too behind.
	SetEntPropFloat(iEntity, Prop_Data, "m_speed", (flDistance >= flOutOfRange) ? (flMoveSpeed * 2) : (flMoveSpeed));

	//Stomp
	if(npc.DoingSpecial)
	{
		float SpecialTime = npc.SpecialTime - GetGameTime();
		if(SpecialTime <= 0.0)
		{	
			float SpecialPos[3];
			npc.GetSpecialPos(SpecialPos);
			npc.PlayGesture("ACT_MP_ATTACK_STAND_ITEM1", true);
			npc.FaceTowards(SpecialPos, 5000.0);
			
			float origin[3], angles[3];
			npc.GetAttachment("effect_hand_R", origin, angles);
			CreateParticle("merasmus_shoot", origin, angles);
			
			float flVelocity[3];
			
			float gravity = FindConVar("sv_gravity").FloatValue;
			
			float flActualHeight = SpecialPos[2] - flOrigin[2];
			float height = flActualHeight;
			if ( height < 16 )
			{
				height = 16.0;
			}
			
			float additionalHeight = 0.0;
			if ( height < 32 )
			{
				additionalHeight = 16.0;
			}
			
			height += additionalHeight;
			
			float speed = SquareRoot( 2 * gravity * height );
			float time = speed / gravity;
		
			time += SquareRoot( (2 * additionalHeight) / gravity );
			
			SubtractVectors( SpecialPos, flOrigin, flVelocity );
			flVelocity[0] /= time;
			flVelocity[1] /= time;
			flVelocity[2] /= time;
		
			flVelocity[2] = speed;
			
			// Don't jump too far/fast.
			float flJumpSpeed = GetVectorLength(flVelocity);
			float flMaxSpeed = 2000.0;
			if ( flJumpSpeed > flMaxSpeed )
			{
				ScaleVector(flVelocity, flMaxSpeed / flJumpSpeed);
			}
			
			if (GetRandomInt(1, 10) == 1)
				EmitGameSoundToAll("Halloween.MerasmusGrenadeThrowRare", iEntity);
			else
				EmitGameSoundToAll("Halloween.MerasmusGrenadeThrow", iEntity);
			
			MerasmusBomb(client, origin, flVelocity, 100.0);
			npc.SpecialTime = GetGameTime() + 2.0;
		}
		else
			npc.DoingSpecial = false;
		
		PF_SetGoalEntity(npc.index, client);
	}
	else
	{
		if(flDistance <= (flOutOfRange / 2))
		{
			if(npc.Pathing)
			{
				npc.Pathing = false;
			}
		}
		else
		{
			if(!npc.Pathing)
			{
				npc.Pathing = true;
			}
		}
	}
}

public void PetSkeleKingThink(int iEntity)
{
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		AcceptEntityInput(iEntity, "Kill");
		return;
	}
	
	//taunt_demo_nuke_shroomcloud
	PetSkeletonKing npc = view_as<PetSkeletonKing>(iEntity);
	npc.Update();
	
	float flOrigin[3], flAbsAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin",   flOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	float flMoveSpeed  = npc.MoveSpeed;
	float flOutOfRange = npc.OutOfRange;
	
	float flCPos[3]; GetClientAbsOrigin(client, flCPos);
	float flDistance = GetVectorDistance(flCPos, flOrigin);
	
	//We don't wanna fall too behind.
	SetEntPropFloat(iEntity, Prop_Data, "m_speed", (flDistance >= flOutOfRange) ? (flMoveSpeed * 2) : (flMoveSpeed));

	//Stomp
	if(npc.DoingSpecial)
	{
		float SpecialPos[3];
		npc.GetSpecialPos(SpecialPos);
		
		if(GetVectorDistance(SpecialPos, flOrigin) <= 20.0 || !npc.Pathing)
		{
			if(npc.Pathing)
			{
				npc.PlayGesture("MELEE_Swing3", false);
				npc.SpecialTime = GetGameTime() + 1.0;
			}
				
			npc.Pathing = false;
			
			float SpecialTime = npc.SpecialTime - GetGameTime();
			if(SpecialTime <= 0.0)
			{
				CreateParticle("duck_pickup_ring", flOrigin, flAbsAngles);
				Explode(client, flOrigin, 100.0, 100.0, "", "");
				npc.SpecialTime = GetGameTime() + 5.0; //Don't repeat
			}
			
			//Needed because sometimes if i'm just calling !IsPlayingGesture it might miss it due to autokill.
			int iSequence = npc.LookupSequence("MELEE_Swing3");
			int iLayer = FindGestureLayer(npc.index, iSequence);
			if(iLayer != -1)
			{
				CBaseAnimatingOverlay overlay = CBaseAnimatingOverlay(npc.index);
				CAnimationLayer layer = overlay.GetLayer(iLayer);
				
				float flCycle = layer.Get(m_flCycle);
				if(flCycle >= 1.0)
				{
					layer.KillMe();
					npc.DoingSpecial = false;
					PF_SetGoalEntity(npc.index, client);
				}
			}
		}
	}
	else
	{
		if(flDistance <= (flOutOfRange / 2))
		{
			if(npc.Pathing)
			{
				npc.Pathing = false;
			}
		}
		else
		{
			if(!npc.Pathing)
			{
				npc.Pathing = true;
			}
		}
	}
}

public void PetTankThink(int iEntity)
{
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		AcceptEntityInput(iEntity, "Kill");
		return;
	}
	
	//taunt_demo_nuke_shroomcloud
	PetTank npc = view_as<PetTank>(iEntity);
	npc.Update();
	
	float flOrigin[3], flAbsAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin",   flOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	float flMoveSpeed  = npc.MoveSpeed;
	float flOutOfRange = npc.OutOfRange;
	
	float flCPos[3]; GetClientAbsOrigin(client, flCPos);
	float flDistance = GetVectorDistance(flCPos, flOrigin);
	
	//We don't wanna fall too behind.
	SetEntPropFloat(iEntity, Prop_Data, "m_speed", (flDistance >= flOutOfRange) ? (flMoveSpeed * 2) : (flMoveSpeed));
	
	bool Deploying = npc.Deploying;
	int Bomb = npc.Bomb;
	
	float SpecialPos[3];
	npc.GetSpecialPos(SpecialPos);
	
	//Start Deploy
	if(!Deploying && npc.DoingSpecial)
	{
		if(GetVectorDistance(SpecialPos, flOrigin) < 20.0)
		{
			SetEntPropFloat(npc.LeftTrack, Prop_Send, "m_flPlaybackRate", 0.0);
			SetEntPropFloat(npc.RightTrack, Prop_Send, "m_flPlaybackRate", 0.0);
			
			EmitSoundToAll(")mvm/mvm_tank_deploy.wav", iEntity, _, _, _, 0.30);
			
			npc.SetSpecialPos(NULL_VECTOR);
			npc.Pathing = false;
			npc.SetAnimation("deploy");
			npc.Deploying = true;
			npc.SpecialTime = GetGameTime();
			view_as<BaseNPC>(Bomb).SetAnimation("deploy");
		}
	}
	
	//Finish Deploy
	if(Deploying)
	{
		float flDeployStart = GetGameTime() - npc.SpecialTime;
		if(flDeployStart >= 7.25)
		{
			float bombPos[3]; bombPos = flOrigin;
			bombPos[2] += 20.0;
			
			float vForward[3], vLeft[3];
			GetAngleVectors(flAbsAngles, vForward, vLeft, NULL_VECTOR);
			bombPos[0] += (vForward[0] * 15);
			bombPos[1] += (vForward[1] * 15);
			
			bombPos[0] += (vLeft[0] * -6);
			bombPos[1] += (vLeft[1] * -6);
			
			CreateParticle("taunt_demo_nuke_shroomcloud", bombPos, flAbsAngles);
			Explode(client, bombPos, 200.0, 200.0, "", "");
			EmitSoundToAll("mvm/mvm_bomb_explode.wav", iEntity, _, _, _, 0.30);
			
			npc.Deploying = false;
			PF_SetGoalEntity(npc.index, client);
			npc.Pathing = true;
			npc.SetSpecialPos(NULL_VECTOR);
			
			npc.SetAnimation("movement");			
			AcceptEntityInput(npc.Bomb, "Kill");
			npc.Bomb = npc.EquipItem("smoke_attachment", "models/bots/boss_bot/bomb_mechanism.mdl");
			
			npc.DoingSpecial = false;
		}
	}
	
	if(!Deploying && !npc.DoingSpecial)
	{
		if(flDistance <= (flOutOfRange / 2))	
		{
			if(npc.Pathing)
			{
				npc.Pathing = false;
				SetEntPropFloat(npc.LeftTrack, Prop_Send, "m_flPlaybackRate", 0.0);
				SetEntPropFloat(npc.RightTrack, Prop_Send, "m_flPlaybackRate", 0.0);
			}
		}
		else
		{
			if(!npc.Pathing)
			{
				npc.Pathing = true;
				SetEntPropFloat(npc.LeftTrack, Prop_Send, "m_flPlaybackRate", 1.0);
				SetEntPropFloat(npc.RightTrack, Prop_Send, "m_flPlaybackRate", 1.0);
			}
		}
	}
}

public bool TraceRayProp(int entityhit, int mask, any entity)
{
	if (entityhit > MaxClients && entityhit != entity)
	{
		return true;
	}
	
	return false;
}

public void PetEngineerThink(int iEntity)
{
	PetEngineer npc = view_as<PetEngineer>(iEntity);
	npc.Update();
	
	float flOrigin[3], flAbsAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin",   flOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if(client == -1)
	{
		SDKUnhook(iEntity, SDKHook_Think, PetEngineerThink);
		AcceptEntityInput(iEntity, "Kill");
		return;
	}
	
	float flCPos[3];
	GetClientAbsOrigin(client, flCPos);
	
	//Do something 
	if(npc.DoingSpecial)
	{
		npc.DoingSpecial = false;
		PF_SetGoalEntity(npc.index, client);
		PrintToChat(client, "No.");
	}
	
	if(npc.NextAmmoCheckTime - GetGameTime() <= 0.0)
	{
		npc.NextAmmoCheckTime = GetGameTime() + 5.0;
		
		if(IsAmmoLow(client) && !npc.IsGettingAmmo && !npc.IsCarryingAmmo)
		{
			float flPos[3];
			int ammo = FindNearestAmmoPack(iEntity, flPos);
			if(IsValidEntity(ammo))
			{			
				Dynamic brain = npc.GetBrainInterface();
				brain.SetFloat("MoveSpeed", 300.0);
				
				PF_SetGoalVector(iEntity, flPos);
				npc.Pathing = true;
				npc.IsGettingAmmo = true;
				npc.AmmoRef = ammo;
			}
		}
	}
	
	if(npc.IsGettingAmmo)
	{	
		//Update ammo progression
		int iAmmoTarget = npc.AmmoRef;
		if (iAmmoTarget == INVALID_ENT_REFERENCE || GetEntProp(iAmmoTarget, Prop_Send, "m_fEffects") & 32)	//Ammo has been taken
		{	
			npc.StopAmmoHunt();
		}
		else if(!npc.IsCarryingAmmo && npc.IsGettingAmmo)	//Getting / Got ammo
		{
			//Check for ammo distance
			if (GetVectorDistance(WorldSpaceCenter(iAmmoTarget), WorldSpaceCenter(iEntity)) <= 50.0)
			{
				//Grabbed some ammo, lets head back. 
				npc.StopAmmoHunt();
				npc.IsCarryingAmmo = true;
				
				Dynamic brain = npc.GetBrainInterface();
				brain.SetString("MoveAnim", "run_BUILDING_DEPLOYED", 64);
				brain.SetString("IdleAnim", "stand_BUILDING_DEPLOYED", 64);
				brain.SetFloat("OutOfRange", 300.0);
				
				AcceptEntityInput(npc.Weapon, "Kill");
				npc.Weapon = npc.EquipItem("head", "models/weapons/w_models/w_toolbox.mdl", _, GetClientTeam(client) - 2);
			}
		}
	}
	else
	{
		float flDistance = GetVectorDistance(flCPos, flOrigin);
		
		float flMoveSpeed  = npc.MoveSpeed;
		float flOutOfRange = npc.OutOfRange;
		SetEntPropFloat(iEntity, Prop_Data, "m_speed", (flDistance >= flOutOfRange) ? (flMoveSpeed * 2) : (flMoveSpeed));
		
		if(flDistance <= (flOutOfRange / 2))	
		{
			if(npc.Pathing)
			{
				if(npc.IsCarryingAmmo)
				{
					float vecForward[3], vecRight[3], vecUp[3];
					SDKCall(g_hGetVectors, iEntity, vecForward, vecRight, vecUp);
					
					float flStartPos[3]; flStartPos = WorldSpaceCenter(npc.index);
					flStartPos[0] += vecForward[0] * 50.0;
					flStartPos[1] += vecForward[1] * 50.0;
					
					ScaleVector(vecForward, 50.0);
					vecForward[2] += 50.0;
					
					int ammo = CreateEntityByName("tf_ammo_pack");
					DispatchKeyValueVector(ammo, "origin", flStartPos);
					DispatchKeyValueVector(ammo, "angles", flAbsAngles);
					DispatchKeyValueVector(ammo, "basevelocity", vecForward);
					DispatchKeyValueVector(ammo, "velocity", vecForward);
					DispatchKeyValue(ammo, "model", "models/weapons/w_models/w_toolbox.mdl");
					DispatchKeyValue(ammo, "modelscale", "0.65");
					DispatchSpawn(ammo);
					
					//SetEntData(ammo, (TF_AMMO_METAL * 4) + (311 * 4), 100, _, true);
					int Offset = ((TF_AMMO_METAL * 4) + (FindSendPropInfo("CTFAmmoPack", "m_vOriginalSpawnAngles") + 20));
					SetEntData(ammo, Offset, 100, _, true);
					
					SetEntProp(ammo, Prop_Send, "m_nSkin", GetClientTeam(client) - 2);
					
					TeleportEntity(ammo, NULL_VECTOR, NULL_VECTOR, vecForward);
					
					SetVariantString("OnUser1 !self:kill::60:1");
					AcceptEntityInput(ammo, "AddOutput");
					AcceptEntityInput(ammo, "FireUser1");
					
					npc.StopAmmoHunt();
					npc.IsCarryingAmmo = false;
					npc.NextAmmoCheckTime = GetGameTime() + 30.0;
				}
			
				npc.Pathing = false;
			}
		}
		else
		{
			if(!npc.Pathing)
			{
				npc.Pathing = true;
			}
		}
	}
}

public void PetMedicThink(int iEntity)
{
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		AcceptEntityInput(iEntity, "Kill");
		return;
	}
	
	PetMedic npc = view_as<PetMedic>(iEntity);
	npc.Update();
	
	//Do something 
	if(npc.DoingSpecial)
	{
		npc.DoingSpecial = false;
		PF_SetGoalEntity(npc.index, client);
		PrintToChat(client, "No.");
	}
	
	float flAbsAngles[3]; GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	float flCPos[3]; GetClientAbsOrigin(client, flCPos);
	float flCAng[3]; GetClientEyeAngles(client, flCAng);
	
	bool bHealing = npc.Healing;
	float flNextHealTime =  npc.NextHealTime - GetGameTime();
	
	if(bHealing)
	{
		int iPitch = npc.LookupPoseParameter("body_pitch");
		if(iPitch < 0)
			return;		
	
		//Body pitch
		float v[3], ang[3];
		SubtractVectors(WorldSpaceCenter(iEntity), WorldSpaceCenter(client), v); 
		NormalizeVector(v, v);
		GetVectorAngles(v, ang); 
		
		float flPitch = npc.GetPoseParameter(iPitch);
		
		ang[0] = clamp(ang[0], -44.0, 89.0);
		npc.SetPoseParameter(iPitch, ApproachAngle(ang[0], flPitch, 1.0));
		
		if(!IsPlayerAlive(client))
		{
			npc.StopHealing();
			npc.Healing = false;
		}
		else
		{	
			if(flNextHealTime <= 0.0)
			{
				if(GetClientHealth(client) < GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client))
				{
					SetEntityHealth(client, GetClientHealth(client) + 1);
				}
				
				npc.NextHealTime = GetGameTime() + 0.5;
			}
		}
		
		npc.FaceTowards(WorldSpaceCenter(client));
	}
	else
	{
		//Aim head to regular pos
		int iPitch = npc.LookupPoseParameter("body_pitch");
		if(iPitch < 0)
			return;
		
		npc.SetPoseParameter(iPitch, ApproachAngle(0.0, npc.GetPoseParameter(iPitch), 0.5));
	}
	
	//We don't wanna fall too behind.
	float flDistance = GetVectorDistance(flCPos, WorldSpaceCenter(iEntity));
	float flMoveSpeed  = npc.MoveSpeed;
	float flOutOfRange = npc.OutOfRange;
	SetEntPropFloat(iEntity, Prop_Data, "m_speed", (flDistance >= flOutOfRange) ? (flMoveSpeed * 2) : (flMoveSpeed));
	
	if(flDistance <= (flOutOfRange / 2))	
	{
		if(npc.Pathing)
		{
			if(!bHealing && IsPlayerAlive(client))
			{
				npc.StartHealing(client);
				npc.Healing = true;
			}
			
			npc.Pathing = false;
		}
	}
	else
	{
		if(flDistance >= 400.0)
		{
			if(bHealing)
			{
				npc.StopHealing();
				npc.Healing = false;
			}
		}
		
		if(!npc.Pathing)
		{
			npc.Pathing = true;
		}
	}
}

public void Blend9Think(int iEntity)
{
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		AcceptEntityInput(iEntity, "Kill");
		return;
	}
	
	BaseNPC npc = view_as<BaseNPC>(iEntity);
	Address pLocomotion = npc.GetLocomotionInterface();
	if(pLocomotion == Address_Null)
		return;
	
	Address pStudioHdr = npc.GetStudioHdr(); 
	
	char MoveAnim[64], IdleAnim[64];
	npc.MoveAnim(MoveAnim, sizeof(MoveAnim));
	npc.IdleAnim(IdleAnim, sizeof(IdleAnim));
	
	int m_iMoveX = SDKCall(g_hLookupPoseParameter, iEntity, pStudioHdr, "move_x");
	int m_iMoveY = SDKCall(g_hLookupPoseParameter, iEntity, pStudioHdr, "move_y");
	
	if ( m_iMoveX < 0 || m_iMoveY < 0 )
		return;
	
	int iCurrSequence = GetEntProp(iEntity, Prop_Send, "m_nSequence");
	
	float flGroundSpeed = SDKCall(g_hGetGroundSpeed, pLocomotion);
	if ( flGroundSpeed != 0.0 )
	{
		int iSequenceMove = SDKCall(g_hLookupSequence, pStudioHdr, MoveAnim);
		
		if(!(GetEntityFlags(iEntity) & FL_ONGROUND))
		{
			if(iCurrSequence != iSequenceMove)
			{
				SDKCall(g_hResetSequence, iEntity, iSequenceMove);
			}
		}
		else
		{			
			if(iCurrSequence != iSequenceMove)
			{
				SDKCall(g_hResetSequence, iEntity, iSequenceMove);
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
		int iSequenceIdle = SDKCall(g_hLookupSequence, pStudioHdr, IdleAnim);
		
		//Set Idle anim when not moving and if it's not already set
		if(iCurrSequence != iSequenceIdle)
		{
			SDKCall(g_hSetPoseParameter, iEntity, pStudioHdr, m_iMoveX, 0.0);
			SDKCall(g_hSetPoseParameter, iEntity, pStudioHdr, m_iMoveY, 0.0);	
			
			SDKCall(g_hResetSequence, iEntity, iSequenceIdle);
		}
	}
	
	float m_flGroundSpeed = GetEntPropFloat(iEntity, Prop_Data, "m_flGroundSpeed");
	if(m_flGroundSpeed != 0.0)
	{
		float flReturnValue = clamp(flGroundSpeed / m_flGroundSpeed, -4.0, 12.0);
		
		SetEntPropFloat(iEntity, Prop_Send, "m_flPlaybackRate", flReturnValue);
	}
	
	SDKCall(g_hDispatchAnimEvents, iEntity, iEntity);
}

stock int FindNearestAmmoPack(int robot, float flPosOut[3])
{
	float flPos[3];
	GetEntPropVector(robot, Prop_Data, "m_vecOrigin", flPos);
	
	int iBestTarget = -1;
	float flSmallestDistance = 999999.0;
	
	int index = -1;
	while ((index = FindEntityByClassname(index, "item_ammopack_*")) != -1)
	{
		if (!(GetEntProp(index, Prop_Send, "m_fEffects") & 32))
		{
			float flAmmoPos[3];
			GetEntPropVector(index, Prop_Data, "m_vecOrigin", flAmmoPos);
			
			float flDistance = GetVectorDistance(flPos, flAmmoPos);
			
			float no;
			if (flDistance <= flSmallestDistance && PF_IsPathToVectorPossible(robot, flAmmoPos, no))
			{
				iBestTarget = index;
				flPosOut = flAmmoPos;
				flSmallestDistance = flDistance;
			}
		}
	}
	
	return iBestTarget;
}

stock bool IsAmmoLow(int client)
{
	int iMaxAmmo   = GetMaxAmmo(client, TF_AMMO_PRIMARY);
	int iAmmoCount = TF2_GetPlayerClass(client) == TFClass_Spy ? GetAmmoCount(client, TF_AMMO_SECONDARY) : GetAmmoCount(client, TF_AMMO_PRIMARY);
	int iAmmoMetal = GetAmmoCount(client, TF_AMMO_METAL);
	
	float flAmmoPercentage = (float(iAmmoCount) / float(iMaxAmmo));
	return (flAmmoPercentage <= 0.5) || (iAmmoMetal <= 50);	//50% ammo or < 51 metal is considered low.
}

stock int GetMaxAmmo(int client, int iAmmoType, int iClassNumber = -1)
{
	return SDKCall(g_hGetMaxAmmo, client, iAmmoType, iClassNumber);
}

stock int GetAmmoCount(int client, int iAmmoType)
{
	return SDKCall(g_hGetAmmoCount, client, iAmmoType);
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

stock int TF2_CreateBeam(int hStart, const char[] startAttach, int hEnd, const char[] endAttach, const char[] particle)
{
	//Parent end ent to hEnd so we can then parent the particle system to it
	int b = CreateEntityByName("info_particle_system");
	DispatchKeyValue(b, "effect_name", particle);
	DispatchSpawn(b);
	
	SetVariantString("!activator");
	AcceptEntityInput(b, "SetParent", hEnd);
	
	SetVariantString(endAttach);
	AcceptEntityInput(b, "SetParentAttachment", hEnd);
	////////////////
	
	int a = CreateEntityByName("info_particle_system");
	DispatchKeyValue(a, "effect_name", particle);
	DispatchSpawn(a);
	
	SetVariantString("!activator");
	AcceptEntityInput(a, "SetParent", hStart);
	
	SetVariantString(startAttach);
	AcceptEntityInput(a, "SetParentAttachment", hStart);
	
	for (int i = 0; i < GetEntPropArraySize(a, Prop_Data, "m_hControlPointEnts"); i++)
	{
		//Find a free control point index to attach the end ent to.
		if(GetEntPropEnt(a, Prop_Data, "m_hControlPointEnts", i) == -1)
		{
			SetEntPropEnt(a, Prop_Data, "m_hControlPointEnts", b, i);
			break;
		}
	}
	
	ActivateEntity(a);
	AcceptEntityInput(a, "Start");	
	
	//Store the end entity of the beam.
	SetEntPropEnt(a, Prop_Send, "m_hOwnerEntity", b);
	
	return a;
}

public void OnEntityDestroyed(int entity)
{
	if(entity > MaxClients && entity <= 2048)
	{
		BaseNPC npc = view_as<BaseNPC>(entity);
		Dynamic brain = npc.GetBrainInterface();
		
		if(brain.IsValid)
		{
			(view_as<PetMedic>(entity)).StopHealing();
			
			StopSound(npc.index, SNDCHAN_AUTO, ")mvm/mvm_tank_loop.wav");
			
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
	
	//No pets for spectators, ever.
	if(TF2_GetClientTeam(client) == TFTeam_Spectator)
		return Plugin_Handled;
		
	//No pets for blue team in MvM, ever.
	if(TF2_IsMvM() && TF2_GetClientTeam(client) == TFTeam_Blue)
		return Plugin_Handled;
	
	Menu menu = new Menu(PetSelectHandler);
	menu.SetTitle("Pets - \"Move Up!\" for special attack\n");
	menu.AddItem("0", "- Remove Pet");
	menu.AddItem("1", "Tank");
	menu.AddItem("2", "Medic");
	menu.AddItem("3", "Robot Engineer");
	menu.AddItem("4", "Merasmus");
	menu.AddItem("5", "Skeleton King");
	menu.AddItem("6", "Mini-Me");
	menu.AddItem("7", "Yeti");
	menu.AddItem("8", "Deskboye");
	menu.AddItem("9", "Sentry Buster");
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public int PetSelectHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		float flPos[3], flAng[3];
		GetClientAbsOrigin(param1, flPos);
		GetClientAbsAngles(param1, flAng);
		
		int pet = -1;
		while((pet = FindEntityByClassname(pet, "base_boss")) != -1)
		{
			int iOwner = GetEntPropEnt(pet, Prop_Send, "m_hOwnerEntity");
			if(iOwner > 0 && iOwner <= MaxClients && iOwner == param1)
			{
				AcceptEntityInput(pet, "Kill");
			}
		}
		
		switch(param2)
		{
			case 1:
			{
				switch(GetRandomInt(1, 2))
				{
					case 1:
					{
						bool bDamaged = !!GetRandomInt(0, 1);
						
						char strDamage[32];
						Format(strDamage, sizeof(strDamage), "_damage%i", GetRandomInt(1, 3));
						
						char strModel[PLATFORM_MAX_PATH];
						Format(strModel, sizeof(strModel), "models/bots/tw2/boss_bot/boss_tank%s.mdl", bDamaged ? strDamage : "");
					
						PetTank npc = PetTank(param1, flPos, flAng, strModel);
						
						npc.LeftTrack  = npc.EquipItem("smoke_attachment", "models/bots/tw2/boss_bot/tank_track_l.mdl", "forward");
						npc.RightTrack = npc.EquipItem("smoke_attachment", "models/bots/tw2/boss_bot/tank_track_r.mdl", "forward");
						npc.Bomb = npc.EquipItem("smoke_attachment", "models/bots/boss_bot/bomb_mechanism.mdl");
					}
					case 2:
					{
						PetTank npc = PetTank(param1, flPos, flAng, "models/bots/boss_bot/boss_tank.mdl");
						
						npc.LeftTrack  = npc.EquipItem("smoke_attachment", "models/bots/boss_bot/tank_track_l.mdl", "forward");
						npc.RightTrack = npc.EquipItem("smoke_attachment", "models/bots/boss_bot/tank_track_r.mdl", "forward");
						npc.Bomb = npc.EquipItem("smoke_attachment", "models/bots/boss_bot/bomb_mechanism.mdl");
					}
				}
			}
			case 2:
			{
				PetMedic npc = PetMedic(param1, flPos, flAng, "models/player/medic.mdl");
				
				npc.Weapon = npc.EquipItem("head", "models/weapons/c_models/c_medigun/c_medigun.mdl", _, 8);
				//npc.EquipItem("head", "models/workshop/player/items/all_class/short2014_lil_moe/short2014_lil_moe_medic.mdl", _, GetClientTeam(param1) - 2);
				npc.EquipItem("head", "models/workshop/player/items/medic/hawaiian_shirt/hawaiian_shirt.mdl", _, GetClientTeam(param1) - 2);
				
				npc.StartHealing(param1);
			}
			case 3:
			{
				PetEngineer npc = PetEngineer(param1, flPos, flAng);
				npc.Weapon = npc.EquipItem("head", "models/weapons/w_models/w_wrench.mdl", _, GetClientTeam(param1) - 2);
				SetVariantString("1.0");
				AcceptEntityInput(npc.Weapon, "SetModelScale");
			}
			case 4:
			{
				PetMerasmus npc = PetMerasmus(param1, flPos, flAng);
				npc.Update();
			}
			case 5:
			{
				PetSkeletonKing npc = PetSkeletonKing(param1, flPos, flAng);
				npc.EquipItem("head", s_skeletonHatModels[GetRandomInt(0, sizeof(s_skeletonHatModels) - 1)], _, GetClientTeam(param1) - 2, 0.9999);
				npc.Update();
			}
			case 6:
			{
				PetMiniMe npc = PetMiniMe(param1, flPos, flAng);
				npc.Update();
			}
			case 7:
			{
				PetYeti npc = PetYeti(param1, flPos, flAng);
				npc.Update();
			}
			case 8:
			{
				PetDeskBoy npc = PetDeskBoy(param1, flPos, flAng);
				npc.Update();
			}
			case 9:
			{
				PetBuster npc = PetBuster(param1, flPos, flAng);
				npc.Update();
			}
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public void OnMapStart()
{
	PrecacheSound("weapons/medigun_heal.wav");
	PrecacheSound("weapons/medigun_no_target.wav");
	
	PrecacheSound(")mvm/mvm_tank_start.wav");
	PrecacheSound(")mvm/mvm_tank_loop.wav");
	PrecacheSound(")mvm/mvm_tank_deploy.wav");
	PrecacheSound("mvm/mvm_bomb_explode");
	PrecacheSound("ui/quest_status_tick.wav"); 
	
	PrecacheSound("vo/halloween_merasmus/sf12_ranged_attack04.mp3"); 
	PrecacheSound("vo/halloween_merasmus/sf12_ranged_attack05.mp3"); 
	PrecacheSound("vo/halloween_merasmus/sf12_ranged_attack06.mp3"); 
	PrecacheSound("vo/halloween_merasmus/sf12_ranged_attack07.mp3"); 
	
	PrecacheSound("vo/halloween_merasmus/sf12_grenades03.mp3"); 
	PrecacheSound("vo/halloween_merasmus/sf12_grenades04.mp3"); 
	PrecacheSound("vo/halloween_merasmus/sf12_grenades05.mp3"); 
	PrecacheSound("vo/halloween_merasmus/sf12_grenades06.mp3"); 
	
	PrecacheModel("models/bots/merasmus/merasmus.mdl");
	
	for (int i = 0; i < sizeof(s_skeletonHatModels); i++)
	{
		PrecacheModel(s_skeletonHatModels[i]);
	}
	
	PrecacheModel("models/bots/skeleton_sniper_boss/skeleton_sniper_boss.mdl");
	
	PrecacheModel("models/props_lakeside_event/bomb_temp.mdl");
	
	PrecacheModel("models/props_halloween/ghost.mdl");
	PrecacheModel("models/props_halloween/ghost_no_hat.mdl");
	PrecacheModel("models/props_halloween/ghost_no_hat_red.mdl");
	
	PrecacheModel("models/bots/heavy/bot_heavy.mdl");
	
	PrecacheModel("models/bots/engineer/bot_engineer.mdl");
	PrecacheModel("models/weapons/w_models/w_toolbox.mdl");
	
	PrecacheModel("models/headcrabclassic.mdl");
	PrecacheModel("models/bots/skeleton_sniper/skeleton_sniper.mdl");
	PrecacheModel("models/zombie/classic.mdl");
	PrecacheModel("models/alyx.mdl");
	PrecacheModel("models/gman.mdl");
	
	PrecacheModel("models/bots/tw2/boss_bot/boss_tank.mdl");
	PrecacheModel("models/bots/tw2/boss_bot/bomb_mechanism.mdl");
	PrecacheModel("models/bots/boss_bot/boss_tank_damage1.mdl");
	PrecacheModel("models/bots/boss_bot/boss_tank_damage2.mdl");
	PrecacheModel("models/bots/boss_bot/boss_tank_damage3.mdl");
	PrecacheModel("models/bots/boss_bot/boss_tank.mdl");
	
	PrecacheModel("models/bots/tw2/boss_bot/tank_track_l.mdl");
	PrecacheModel("models/bots/tw2/boss_bot/tank_track_r.mdl");
	PrecacheModel("models/bots/boss_bot/tank_track_L.mdl");
	PrecacheModel("models/bots/boss_bot/tank_track_R.mdl");
	
	PrecacheModel("models/bots/demo/bot_sentry_buster.mdl");
	
	PrecacheSound(")mvm/sentrybuster/mvm_sentrybuster_explode.wav");
	PrecacheSound(")mvm/sentrybuster/mvm_sentrybuster_spin.wav");
	PrecacheSound("mvm/sentrybuster/mvm_sentrybuster_loop.wav");
	PrecacheSound(")mvm/sentrybuster/mvm_sentrybuster_intro.wav");
}

public void OnPluginStart()
{
	RegAdminCmd("sm_pets", Command_PetMenu, 0);
	RegAdminCmd("sm_pests", Command_PetMenu, 0);
	
	HookEvent("player_team", Event_PlayerTeam);
	
	Handle hConf = LoadGameConfigFile("tf2.pets");
	
	//CTFPlayer
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hGetMaxAmmo = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for CTFPlayer::GetMaxAmmo!");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFPlayer::GetAmmoCount");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hGetAmmoCount = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for CTFPlayer::GetAmmoCount offset!");
	
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
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::IsStuck");
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

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	int iEntity = -1;
	while((iEntity = FindEntityByClassname(iEntity, "base_boss")) != -1)
	{
		int iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
		if(iOwner > 0 && iOwner <= MaxClients && iOwner == client)
		{
			AcceptEntityInput(iEntity, "Kill");
		}
	}
	
	return Plugin_Continue;
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

public MRESReturn ILocomotion_GetGroundNormal(Address pThis, Handle hReturn, Handle hParams)     { DHookSetReturnVector(hReturn, view_as<float>( { 0.0, 0.0, 1.0 } ));  return MRES_Supercede; }
public MRESReturn ILocomotion_GetStepHeight(Address pThis, Handle hReturn, Handle hParams)       { DHookSetReturn(hReturn, 18.0);	return MRES_Supercede; }
public MRESReturn ILocomotion_GetMaxAcceleration(Address pThis, Handle hReturn, Handle hParams)  { DHookSetReturn(hReturn, 1700.0); return MRES_Supercede; }
public MRESReturn ILocomotion_GetFrictionSideways(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturn(hReturn, 3.0);    return MRES_Supercede; }
public MRESReturn ILocomotion_ShouldCollideWith(Address pThis, Handle hReturn, Handle hParams)   { DHookSetReturn(hReturn, false); return MRES_Supercede; }
public MRESReturn ILocomotion_GetGravity(Address pThis, Handle hReturn, Handle hParams)
{
	float flGravity = GetEntPropFloat(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis)), Prop_Data, "m_flGravity");
	DHookSetReturn(hReturn, flGravity == 0.0 ? 800.0 : flGravity);
	
	return MRES_Supercede;
}

public MRESReturn IBody_GetSolidMask(Address pThis, Handle hReturn, Handle hParams)        { DHookSetReturn(hReturn, MASK_NPCSOLID | MASK_PLAYERSOLID); return MRES_Supercede; }
public MRESReturn IBody_StartActivity(Address pThis, Handle hReturn, Handle hParams)       { DHookSetReturn(hReturn, true); return MRES_Supercede; }
public MRESReturn IBody_GetCrouchHullHeight(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturn(hReturn, 16.0); return MRES_Supercede; }
public MRESReturn IBody_GetStandHullHeight(Address pThis, Handle hReturn, Handle hParams)  { DHookSetReturn(hReturn, 34.0); return MRES_Supercede; }
public MRESReturn IBody_GetHullWidth(Address pThis, Handle hReturn, Handle hParams)        { DHookSetReturn(hReturn, 13.0); return MRES_Supercede; }
public MRESReturn IBody_GetHullHeight(Address pThis, Handle hReturn, Handle hParams)       { DHookSetReturn(hReturn, 34.0); return MRES_Supercede; }

/*
min -6.500000 -6.500000 0.000000
max 6.500000 6.500000 34.000000
*/

public MRESReturn IBody_GetHullMins(Address pThis, Handle hReturn, Handle hParams)         
{ 
	//DHookSetReturnVector(hReturn, view_as<float>( { -6.5, -6.5, 0.0 } )); 
	//return MRES_Supercede; 
	
	float vec[3]; 
	DHookGetReturnVector(hReturn, vec);
	
	PrintToServer("min %f %f %f", vec[0], vec[1], vec[2]);
	
	return MRES_Ignored; 
}

public MRESReturn IBody_GetHullMaxs(Address pThis, Handle hReturn, Handle hParams)         
{ 
	//DHookSetReturnVector(hReturn, view_as<float>( { 6.5, 6.5, 68.0 } ));  
	//return MRES_Supercede; 
	
	float vec[3]; 
	DHookGetReturnVector(hReturn, vec);
	
	PrintToServer("max %f %f %f", vec[0], vec[1], vec[2]);
	
	return MRES_Ignored; 
}

public void PluginBot_Approach(int bot_entidx, const float vec[3])
{
	BaseNPC npc = view_as<BaseNPC>(bot_entidx);
	npc.Approach(vec);
	npc.FaceTowards(vec);
}

public float PluginBot_PathCost(int bot_entidx, NavArea area, NavArea from_area, float length)
{
	//	PrintToServer("area %i (%x) from_area %i (%x) length %f", area.GetID(), area, from_area.GetID(), from_area, length);
	//Make me https://github.com/sigsegv-mvm/mvm-reversed/blob/3c60e2448fa660ab513b2c455eec33f33cedeac5/server/tf/bot/tf_bot.cpp

/*	int TFNavAreaAttribs = LoadFromAddress(view_as<Address>(area) + view_as<Address>(0x54), NumberType_Int32);
	if(TFNavAreaAttribs != 0)
	{
		char strAttribs[PLATFORM_MAX_PATH];
		if(TFNavAreaAttribs & NAV_MESH_CROUCH) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_CROUCH");
		if(TFNavAreaAttribs & NAV_MESH_JUMP) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_JUMP");
		if(TFNavAreaAttribs & NAV_MESH_PRECISE) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_PRECISE");
		if(TFNavAreaAttribs & NAV_MESH_NO_JUMP) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_NO_JUMP");
		if(TFNavAreaAttribs & NAV_MESH_STOP) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_STOP");
		if(TFNavAreaAttribs & NAV_MESH_RUN) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_RUN");
		if(TFNavAreaAttribs & NAV_MESH_WALK) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_WALK");
		if(TFNavAreaAttribs & NAV_MESH_AVOID) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_AVOID");
		if(TFNavAreaAttribs & NAV_MESH_TRANSIENT) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_TRANSIENT");
		if(TFNavAreaAttribs & NAV_MESH_DONT_HIDE) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_DONT_HIDE");
		if(TFNavAreaAttribs & NAV_MESH_STAND) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_STAND");
		if(TFNavAreaAttribs & NAV_MESH_NO_HOSTAGES) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_NO_HOSTAGES");
		if(TFNavAreaAttribs & NAV_MESH_STAIRS) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_STAIRS");
		if(TFNavAreaAttribs & NAV_MESH_NO_MERGE) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_NO_MERGE");
		if(TFNavAreaAttribs & NAV_MESH_OBSTACLE_TOP) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_OBSTACLE_TOP");
		if(TFNavAreaAttribs & NAV_MESH_CLIFF) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_CLIFF");
		if(TFNavAreaAttribs & NAV_MESH_FIRST_CUSTOM) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_FIRST_CUSTOM");
		if(TFNavAreaAttribs & NAV_MESH_LAST_CUSTOM) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_LAST_CUSTOM");
		if(TFNavAreaAttribs & NAV_MESH_FUNC_COST) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_FUNC_COST");
		if(TFNavAreaAttribs & NAV_MESH_HAS_ELEVATOR) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_HAS_ELEVATOR");
		if(TFNavAreaAttribs & NAV_MESH_NAV_BLOCKER) strcopy(strAttribs, PLATFORM_MAX_PATH, " NAV_MESH_NAV_BLOCKER");
		
		float center[3];
		area.GetCenter(center);
		PrintToServer("%s on #%i %f %f %f", strAttribs, area.GetID(), center[0], center[1], center[2]);
	}
	
	int CTFNavAreaAttribs = LoadFromAddress(view_as<Address>(area) + view_as<Address>(0x1C0), NumberType_Int32);
	if(CTFNavAreaAttribs != 0)
	{
		char strAttribs[PLATFORM_MAX_PATH];
		if(CTFNavAreaAttribs & BLOCKED) strcopy(strAttribs, PLATFORM_MAX_PATH, " BLOCKED");
		if(CTFNavAreaAttribs & RED_SPAWN_ROOM) strcopy(strAttribs, PLATFORM_MAX_PATH, " RED_SPAWN_ROOM");
		if(CTFNavAreaAttribs & BLUE_SPAWN_ROOM) strcopy(strAttribs, PLATFORM_MAX_PATH, " BLUE_SPAWN_ROOM");
		if(CTFNavAreaAttribs & SPAWN_ROOM_EXIT) strcopy(strAttribs, PLATFORM_MAX_PATH, " SPAWN_ROOM_EXIT");
		if(CTFNavAreaAttribs & AMMO) strcopy(strAttribs, PLATFORM_MAX_PATH, " AMMO");
		if(CTFNavAreaAttribs & HEALTH) strcopy(strAttribs, PLATFORM_MAX_PATH, " HEALTH");
		if(CTFNavAreaAttribs & CONTROL_POINT) strcopy(strAttribs, PLATFORM_MAX_PATH, " CONTROL_POINT");
		if(CTFNavAreaAttribs & BLUE_SENTRY) strcopy(strAttribs, PLATFORM_MAX_PATH, " BLUE_SENTRY");
		if(CTFNavAreaAttribs & RED_SENTRY) strcopy(strAttribs, PLATFORM_MAX_PATH, " RED_SENTRY");
		if(CTFNavAreaAttribs & BLUE_SETUP_GATE) strcopy(strAttribs, PLATFORM_MAX_PATH, " BLUE_SETUP_GATE");
		if(CTFNavAreaAttribs & RED_SETUP_GATE) strcopy(strAttribs, PLATFORM_MAX_PATH, " RED_SETUP_GATE");
		if(CTFNavAreaAttribs & BLOCKED_AFTER_POINT_CAPTURE) strcopy(strAttribs, PLATFORM_MAX_PATH, " BLOCKED_AFTER_POINT_CAPTURE");
		if(CTFNavAreaAttribs & BLOCKED_UNTIL_POINT_CAPTURE) strcopy(strAttribs, PLATFORM_MAX_PATH, " BLOCKED_UNTIL_POINT_CAPTURE");
		if(CTFNavAreaAttribs & BLUE_ONE_WAY_DOOR) strcopy(strAttribs, PLATFORM_MAX_PATH, " BLUE_ONE_WAY_DOOR");
		if(CTFNavAreaAttribs & RED_ONE_WAY_DOOR) strcopy(strAttribs, PLATFORM_MAX_PATH, " RED_ONE_WAY_DOOR");
		if(CTFNavAreaAttribs & WITH_SECOND_POINT) strcopy(strAttribs, PLATFORM_MAX_PATH, " WITH_SECOND_POINT");
		if(CTFNavAreaAttribs & WITH_THIRD_POINT) strcopy(strAttribs, PLATFORM_MAX_PATH, " WITH_THIRD_POINT");
		if(CTFNavAreaAttribs & WITH_FOURTH_POINT) strcopy(strAttribs, PLATFORM_MAX_PATH, " WITH_FOURTH_POINT");
		if(CTFNavAreaAttribs & WITH_FIFTH_POINT) strcopy(strAttribs, PLATFORM_MAX_PATH, " WITH_FIFTH_POINT");
		if(CTFNavAreaAttribs & SNIPER_SPOT) strcopy(strAttribs, PLATFORM_MAX_PATH, " SNIPER_SPOT");
		if(CTFNavAreaAttribs & SENTRY_SPOT) strcopy(strAttribs, PLATFORM_MAX_PATH, " SENTRY_SPOT");
		if(CTFNavAreaAttribs & NO_SPAWNING) strcopy(strAttribs, PLATFORM_MAX_PATH, " NO_SPAWNING");
		if(CTFNavAreaAttribs & RESCUE_CLOSET) strcopy(strAttribs, PLATFORM_MAX_PATH, " RESCUE_CLOSET");
		if(CTFNavAreaAttribs & BOMB_DROP) strcopy(strAttribs, PLATFORM_MAX_PATH, " BOMB_DROP");
		if(CTFNavAreaAttribs & DOOR_NEVER_BLOCKS) strcopy(strAttribs, PLATFORM_MAX_PATH, " DOOR_NEVER_BLOCKS");
		if(CTFNavAreaAttribs & DOOR_ALWAYS_BLOCKS) strcopy(strAttribs, PLATFORM_MAX_PATH, " DOOR_ALWAYS_BLOCKS");
		if(CTFNavAreaAttribs & UNBLOCKABLE) strcopy(strAttribs, PLATFORM_MAX_PATH, " UNBLOCKABLE");
		
		PrintToServer("%s on %x #%i GetPlayerCount %i CombatIntensity %f", strAttribs, area, area.GetID(), area.GetPlayerCount(), GetCombatIntensity(area));
	}*/

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
	
	multiplier += (Cosine(float(seed)) + 1.0) * 5.0;
	
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
	/*	else
		{
			float flMaxHeight = 120.0;
			if ( height > flMaxHeight )
			{
				height = flMaxHeight;
			}
		}*/
		
		// overshoot the jump by an additional 8 inches
		// NOTE: This calculation jumps at a position INSIDE the box of the enemy (player)
		// so if you make the additional height too high, the crab can land on top of the
		// enemy's head.  If we want to jump high, we'll need to move vecPos to the surface/outside
		// of the enemy's box.
	
		float additionalHeight = 0.0;
		if ( height < 32 )
		{
			additionalHeight = 16.0;
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

public void PluginBot_PathFail(int bot_entidx, Address path, MoveToFailureType fail)
{
	PrintToServer(">>>>>>>>>> PluginBot_PathFail %i path 0x%X reason %i", bot_entidx, path, fail);
}

public void PluginBot_OnContact(int bot_entidx, int other)
{
	PrintToServer(">>>>>>>>>> PluginBot_OnContact %i other %i", bot_entidx, other);
}

public void PluginBot_OnActorEmoted(int bot_entidx, int who, int concept)
{
	//PrintToServer(">>>>>>>>>> PluginBot_OnActorEmoted %i who %i concept %i", bot_entidx, who, concept);
	
	//"Move Up!"
	if (concept == 14 )
	{
		int iOwner = GetEntPropEnt(bot_entidx, Prop_Send, "m_hOwnerEntity");
		if(iOwner != who) //You are not my dad!
			return;
		
		BaseNPC npc = view_as<BaseNPC>(bot_entidx);
		if (npc.DoingSpecial) //Already doing special
			return;
		
		float StartOrigin[3], Angles[3], vecPos[3];
		GetClientEyeAngles(who, Angles);
		GetClientEyePosition(who, StartOrigin);
		
		Handle TraceRay = TR_TraceRayFilterEx(StartOrigin, Angles, (CONTENTS_SOLID|CONTENTS_WINDOW|CONTENTS_GRATE), RayType_Infinite, TraceRayProp);
		if (TR_DidHit(TraceRay))
			TR_GetEndPosition(vecPos, TraceRay);
			
		delete TraceRay;
		
		float no;
		if(PF_IsPathToVectorPossible(bot_entidx, vecPos, no))
		{
			npc.SetSpecialPos(vecPos);
			PF_SetGoalVector(bot_entidx, vecPos);
			npc.Pathing = true;
			npc.DoingSpecial = true;
			
			CreateParticle("ping_circle", vecPos, NULL_VECTOR);
		}
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

stock void MerasmusBomb(int client, float flPos[3], float flVelocity[3], float flDamage)
{
	int bomb = CreateEntityByName("tf_weaponbase_merasmus_grenade");
	DispatchKeyValueVector(bomb, "origin", flPos);
	DispatchKeyValueFloat(bomb, "modelscale", 0.5);
	SetEntityModel(bomb, "models/props_lakeside_event/bomb_temp.mdl");
	SetEntProp(bomb, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(bomb, Prop_Data, "m_iTeamNum", GetClientTeam(client));
	SetEntPropEnt(bomb, Prop_Send, "m_hThrower", client);
	SetEntPropEnt(bomb, Prop_Data, "m_hThrower", client);
	SetEntPropEnt(bomb, Prop_Send, "m_hOwnerEntity", client);
	SetEntPropEnt(bomb, Prop_Data, "m_hOwnerEntity", client);
	DispatchSpawn(bomb);
	
	
	TeleportEntity(bomb, NULL_VECTOR, NULL_VECTOR, flVelocity);
	
	SetEntPropFloat(bomb, Prop_Data, "m_flDamage", flDamage);
	SetEntPropFloat(bomb, Prop_Data, "m_flModelScale", 1.0);
	SetEntPropFloat(bomb, Prop_Send, "m_flModelScale", 1.0);
	SetEntDataFloat(bomb, FindSendPropInfo("CTFWeaponBaseMerasmusGrenade", "m_hThrower") + 48, GetGameTime() + 2.0);	//Fuse time
	SetEntProp(bomb, Prop_Send, "m_CollisionGroup", 24);
	SetEntProp(bomb, Prop_Data, "m_CollisionGroup", 24);
}

stock bool TF2_IsMvM()
{
	return view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
}