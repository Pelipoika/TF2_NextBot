#include <sdktools>
#include <sdkhooks>
#include <PathFollower>
#include <PathFollower_Nav>
#include <dhooks>
#include <utilsext>
#include <dynamic>

#pragma newdecls required;

#define MOVING_MINIMUM_SPEED 0.25

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

//PluginBot DHooks
Handle g_hGetEntity;
Handle g_hGetBot;

//DHooks
Handle g_hGetFrictionSideways;
Handle g_hGetFrictionForward;
Handle g_hGetStepHeight;
Handle g_hGetGravity;
Handle g_hGetGroundNormal;
Handle g_hShouldCollideWith;
Handle g_hGetSolidMask;
Handle g_hStartActivity;
Handle g_hGetHullWidth;
Handle g_hGetStandHullHeight;
Handle g_hGetCrouchHullHeight;

static float m_flEstimateYaw[2049] = { 0.0, ... };

public Plugin myinfo = 
{
	name = "[TF2] Advanced Pets", 
	author = "Pelipoika", 
	description = "", 
	version = "1.0", 
	url = ""
};

methodmap BaseNPC __nullable__
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
		
		Address pNB =         SDKCall(g_hMyNextBotPointer,        npc);
		Address pLocomotion = SDKCall(g_hGetLocomotionInterface,  pNB);
		
		DHookRaw(g_hGetStepHeight,       true, pLocomotion);
		DHookRaw(g_hGetGravity,          true, pLocomotion);
		DHookRaw(g_hShouldCollideWith,   true, pLocomotion);
		DHookRaw(g_hGetFrictionSideways, true, pLocomotion);
		DHookRaw(g_hGetFrictionForward,  true, pLocomotion);
		
		if(bGroundNormal)
			DHookRaw(g_hGetGroundNormal, true, pLocomotion)
		
		Address pBody = SDKCall(g_hGetBodyInterface, pNB);
		
		DHookRaw(g_hGetSolidMask,        true, pBody);
		DHookRaw(g_hStartActivity,       true, pBody);
		DHookRaw(g_hGetHullWidth,        true, pBody);
		DHookRaw(g_hGetStandHullHeight,  true, pBody);
		DHookRaw(g_hGetCrouchHullHeight, true, pBody);
		
		SetEntityFlags(npc, FL_NOTARGET);
		
		SetEntData(npc, FindSendPropInfo("CTFBaseBoss", "m_lastHealthPercentage") + 28, false, 4, true);	//ResolvePlayerCollisions
		SetEntProp(npc, Prop_Data, "m_takedamage", 0);
		SetEntProp(npc, Prop_Data, "m_nSolidType", 0); 
		
		ActivateEntity(npc);
		
		char strName[64];
		Format(strName, sizeof(strName), "basenpc_%x", EntIndexToEntRef(npc));
		
		Dynamic brain = Dynamic();
		brain.SetBool ("Pathing", false);
		brain.SetInt  ("Weapon",  INVALID_ENT_REFERENCE);
		brain.SetName(strName);
		
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
		
		return Dynamic.FindByName(strName);
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
	
	public void SetAnimation(const char[] anim)
	{
		int iSequence = utils_EntityLookupSequence(this.index, anim);
		if(iSequence != -1)
			SDKCall(g_hResetSequence, this, iSequence);
	}
	
	public void PlayGesture(const char[] anim)
	{
		int iAnim = utils_EntityLookupSequence(this.index, anim);
		AnimOverlayHandler handler = AnimOverlayHandler(this.index);
		handler.AddGestureSequence(iAnim);
	}
	
	public void CreatePather(int iTarget, float flStep, float flJump, float flDrop, int iSolid, float flAhead, float flRePath, float flHull)
	{
		PF_Create(this.index, flStep, flJump, flDrop, 0.6, iSolid, flAhead, flRePath, flHull);
		PF_SetGoalEntity(this.index, iTarget);
		
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
		SDKCall(g_hFaceTowards, this.GetLocomotionInterface(), vecGoal);
	}
	
	public void Jump()
	{
		SDKCall(g_hJump, this.GetLocomotionInterface());
	}
	
	public void Update()
	{
		SDKCall(g_hStudioFrameAdvance, this.index);
		SDKCall(g_hRun,                this.GetLocomotionInterface());
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

methodmap PetMedic < BaseNPC
{
	public PetMedic(int client, float vecPos[3], float vecAng[3], const char[] model)
	{
		BaseNPC pet = new BaseNPC(vecPos, vecAng, model, "0.5");
		
		SetEntPropFloat(pet.index, Prop_Data, "m_speed",        150.0);
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
		brain.SetFloat("OutOfRange", 400.0);
		//////////
		
		pet.CreatePather(client, 18.0, 36.0, 1000.0, MASK_PLAYERSOLID, 150.0, 0.5, 1.0);
		pet.SetAnimation("run_SECONDARY");
		pet.Pathing = true;
		
		SDKHook(pet.index, SDKHook_Think, PetMedicThink);
		SDKHook(pet.index, SDKHook_Think, Blend9Think);
		
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
		BaseNPC pet = new BaseNPC(vecPos, vecAng, model, "0.15", _, false);
		SDKHook(pet.index, SDKHook_Think, PetTankThink);

		SetEntPropFloat(pet.index, Prop_Data, "m_speed",         GetEntPropFloat(client, Prop_Send, "m_flMaxspeed"));
		SetEntProp(pet.index,      Prop_Send, "m_nSkin",         GetRandomInt(0, 1));
		SetEntPropEnt(pet.index,   Prop_Send, "m_hOwnerEntity", client);
		
		Dynamic brain = pet.GetBrainInterface();
		brain.SetInt("LeftTrack", INVALID_ENT_REFERENCE);
		brain.SetInt("RightTrack",  INVALID_ENT_REFERENCE);
		
		pet.CreatePather(client, 18.0, 72.0, 1000.0, MASK_PLAYERSOLID, 150.0, 0.5, 1.0);
		pet.SetAnimation("movement");
		pet.Pathing = true;
		
		EmitSoundToAll(")mvm/mvm_tank_start.wav", pet.index);
		EmitSoundToAll(")mvm/mvm_tank_loop.wav",  pet.index, _, _, _, 0.10);
		
		TF2_CreateParticle(pet.index, "smoke_attachment", "buildingdamage_smoke3");
		
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
}

methodmap PetCrab < BaseNPC
{
	public PetCrab(int client, float vecPos[3], float vecAng[3], const char[] model)
	{
		BaseNPC pet = new BaseNPC(vecPos, vecAng, model);
		SDKHook(pet.index, SDKHook_Think, PetCrabThink);

		SetEntPropFloat(pet.index, Prop_Data, "m_speed",         75.0);
		SetEntPropEnt(pet.index,   Prop_Send, "m_hOwnerEntity", client);
		
		//REQUIRED
		Dynamic brain = pet.GetBrainInterface();
		brain.SetString("JumpAnim", "jumpattack_broadcast");
		//////////
		
		pet.CreatePather(client, 18.0, 200.0, 1000.0, MASK_PLAYERSOLID, 150.0, 0.5, 1.0);
		pet.SetAnimation("Idle01");
		pet.Pathing = true;
		
		return view_as<PetCrab>(pet);
	}
}

methodmap PetGhost < BaseNPC
{
	public PetGhost(int client, float vecPos[3], float vecAng[3], const char[] model)
	{
		BaseNPC pet = new BaseNPC(vecPos, vecAng, model, "0.5");
		SDKHook(pet.index, SDKHook_Think, PetGhostThink);
		
		SetEntPropFloat(pet.index, Prop_Data, "m_flGravity",    200.0);
		SetEntPropFloat(pet.index, Prop_Data, "m_speed",        GetEntPropFloat(client, Prop_Send, "m_flMaxspeed"));
		SetEntPropEnt(pet.index,   Prop_Send, "m_hOwnerEntity", client);
		
		pet.CreatePather(client, 18.0, 1000.0, 1000.0, MASK_PLAYERSOLID, 150.0, 0.5, 1.0);
		pet.Pathing = true;
		pet.SetAnimation("idle");
		
		return view_as<PetGhost>(pet);
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
//	PrintToServer("area_id %i from_area_id %i length %f", area_id, from_area_id, length);

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

methodmap PetHeavy < BaseNPC
{
	public PetHeavy(int client, float vecPos[3], float vecAng[3], const char[] model)
	{
		BaseNPC pet = new BaseNPC(vecPos, vecAng, model, "0.5");
		
		SetEntPropFloat(pet.index, Prop_Data, "m_speed",        230.0);
		SetEntProp(pet.index,      Prop_Send, "m_nSkin",        GetClientTeam(client) - 2);
		SetEntPropEnt(pet.index,   Prop_Send, "m_hOwnerEntity", client);
		
		Dynamic brain = pet.GetBrainInterface();
		
		//REQUIRED IF YOU'RE GOING TO USE Blend9Think
		brain.SetString("MoveAnim", "Run_PRIMARY");
		brain.SetFloat("MoveSpeed", 115.0);
		brain.SetString("IdleAnim", "Stand_PRIMARY");
		brain.SetFloat("OutOfRange", 400.0);
		//////////
		
		pet.CreatePather(client, 18.0, 36.0, 1000.0, MASK_PLAYERSOLID, 150.0, 0.5, 1.0);
		pet.SetAnimation("Stand_PRIMARY");
		pet.Pathing = true;
		
		//You can implement your own pet functions here.
		SDKHook(pet.index, SDKHook_Think, PetHeavyThink);
		//Controls 9 way blend animation managing
		SDKHook(pet.index, SDKHook_Think, Blend9Think);
		
		return view_as<PetHeavy>(pet);
	}
	
	public void StartFiring(int iEnt)
	{
		int iWeapon = this.Weapon;
		if(iWeapon != INVALID_ENT_REFERENCE)
		{
			
		}
	}
	
	public void StopFiring()
	{
		
	}
}

methodmap PetZombie < BaseNPC
{
	public PetZombie(int client, float vecPos[3], float vecAng[3], const char[] model)
	{
		BaseNPC pet = new BaseNPC(vecPos, vecAng, model, "0.5");
		
		SetEntPropFloat(pet.index, Prop_Data, "m_speed",        100.0);
		SetEntPropEnt(pet.index,   Prop_Send, "m_hOwnerEntity", client);
		
		Dynamic brain = pet.GetBrainInterface();
		
		//REQUIRED IF YOU'RE GOING TO USE Blend(8/9)Think
		brain.SetString("MoveAnim", "walk");
		brain.SetFloat("MoveSpeed", 22.5);
		brain.SetString("IdleAnim", "Idle01");
		brain.SetFloat("OutOfRange", 300.0);
		//////////
		
		pet.CreatePather(client, 18.0, 36.0, 1000.0, MASK_PLAYERSOLID, 150.0, 0.5, 1.0);
		pet.Pathing = true;
		
		//You can implement your own pet functions here.
		SDKHook(pet.index, SDKHook_Think, PetHeavyThink);
		//Controls 9 way blend animation managing
		SDKHook(pet.index, SDKHook_Think, Blend8Think);
		
		return view_as<PetZombie>(pet);
	}
}

methodmap PetAlyx < BaseNPC
{
	public PetAlyx(int client, float vecPos[3], float vecAng[3], const char[] model)
	{
		BaseNPC pet = new BaseNPC(vecPos, vecAng, model, "0.5");
		
		SetEntPropFloat(pet.index, Prop_Data, "m_speed",        100.0);
		SetEntPropEnt(pet.index,   Prop_Send, "m_hOwnerEntity", client);
		
		Dynamic brain = pet.GetBrainInterface();
		
		//REQUIRED IF YOU'RE GOING TO USE Blend(8/9)Think
		brain.SetString("MoveAnim", "run_all");
		brain.SetFloat("MoveSpeed", 105.0);
		brain.SetString("IdleAnim", "idle_subtle");
		brain.SetFloat("OutOfRange", 400.0);
		//////////
		
		pet.CreatePather(client, 18.0, 36.0, 1000.0, MASK_PLAYERSOLID, 150.0, 0.5, 1.0);
		pet.Pathing = true;
		
		//You can implement your own pet functions here.
		SDKHook(pet.index, SDKHook_Think, PetHeavyThink);
		//Controls 9 way blend animation managing
		SDKHook(pet.index, SDKHook_Think, Blend8Think);
		
		return view_as<PetAlyx>(pet);
	}
}

methodmap PetGman < BaseNPC
{
	public PetGman(int client, float vecPos[3], float vecAng[3], const char[] model)
	{
		BaseNPC pet = new BaseNPC(vecPos, vecAng, model, "0.5");
		
		SetEntPropFloat(pet.index, Prop_Data, "m_speed",        100.0);
		SetEntPropEnt(pet.index,   Prop_Send, "m_hOwnerEntity", client);
		
		Dynamic brain = pet.GetBrainInterface();
		
		//REQUIRED IF YOU'RE GOING TO USE Blend(8/9)Think
		brain.SetString("MoveAnim", "run_all");
		brain.SetFloat("MoveSpeed", 105.0);
		brain.SetString("IdleAnim", "idle_angry");
		brain.SetFloat("OutOfRange", 400.0);
		//////////
		
		pet.CreatePather(client, 18.0, 36.0, 1000.0, MASK_PLAYERSOLID, 150.0, 0.5, 1.0);
		pet.Pathing = true;
		
		//You can implement your own pet functions here.
		SDKHook(pet.index, SDKHook_Think, PetHeavyThink);
		//Controls 9 way blend animation managing
		SDKHook(pet.index, SDKHook_Think, Blend8Think);
		
		return view_as<PetGman>(pet);
	}
}

public void PetHeavyThink(int iEntity)
{
	PetHeavy npc = view_as<PetHeavy>(iEntity);
	npc.Update();
	
	float flOrigin[3], flAbsAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin",   flOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	
	float flCPos[3];
	GetClientAbsOrigin(client, flCPos);
	
	float flDistance = GetVectorDistance(flCPos, flOrigin);
	if(flDistance <= 150.0)	
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

public void PetGhostThink(int iEntity)
{
	PetGhost npc = view_as<PetGhost>(iEntity);
	npc.Update();
	
	float flOrigin[3], flAbsAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin",   flOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	
	float flCPos[3];
	GetClientAbsOrigin(client, flCPos);
	
	float flDistance = GetVectorDistance(flCPos, flOrigin);
	if(flDistance <= 150.0)	
	{
		if(npc.Pathing)
		{
			npc.Pathing = false;
		}
	}
	else
	{
		//We don't wanna fall too behind
		if(flDistance >= 300.0)
		{
			SetEntPropFloat(iEntity, Prop_Data, "m_speed", 300.0);
		}
		else
		{
			SetEntPropFloat(iEntity, Prop_Data, "m_speed", 100.0);
		}
		
		if(!npc.Pathing)
		{
			npc.Pathing = true;
		}
	}
}

public void PetCrabThink(int iEntity)
{
	PetCrab npc = view_as<PetCrab>(iEntity);
	npc.Update();
	
	float flOrigin[3], flAbsAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin",   flOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	
	float flCPos[3];
	GetClientAbsOrigin(client, flCPos);
	
	float flDistance = GetVectorDistance(flCPos, flOrigin);
	if(flDistance <= 125.0)	
	{
		if(npc.Pathing)
		{
			npc.SetAnimation("Idle01");
			npc.Pathing = false;
		}
	}
	else
	{
		//We don't wanna fall too behind
		if(flDistance >= 300.0)
		{
			SetEntPropFloat(iEntity, Prop_Data, "m_speed", 300.0);
			SetEntPropFloat(iEntity, Prop_Send, "m_flPlaybackRate", 2.0);
		}
		else
		{
			SetEntPropFloat(iEntity, Prop_Data, "m_speed", 75.0);
			SetEntPropFloat(iEntity, Prop_Send, "m_flPlaybackRate", 1.0);
		}
		
		if(!npc.Pathing)
		{
			npc.SetAnimation("Run1");
			npc.Pathing = true;
		}
	}
}

public void PetTankThink(int iEntity)
{
	PetTank npc = view_as<PetTank>(iEntity);
	npc.Update();
	
	float flOrigin[3], flAbsAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin",   flOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	
	float flCPos[3];
	GetClientAbsOrigin(client, flCPos);
	
	float flDistance = GetVectorDistance(flCPos, flOrigin);
	if(flDistance <= 125.0)	
	{
		if(npc.Pathing)
		{
			npc.Pathing = false;
			SetEntPropFloat(npc.LeftTrack,  Prop_Send, "m_flPlaybackRate", 0.0);
			SetEntPropFloat(npc.RightTrack, Prop_Send, "m_flPlaybackRate", 0.0);
		}
	}
	else
	{
		//We don't wanna fall too behind
		if(flDistance >= 300.0)
		{
			SetEntPropFloat(iEntity, Prop_Data, "m_speed", GetEntPropFloat(client, Prop_Send, "m_flMaxspeed"));
			SetEntPropFloat(npc.LeftTrack,  Prop_Send, "m_flPlaybackRate", 16.0);
			SetEntPropFloat(npc.RightTrack, Prop_Send, "m_flPlaybackRate", 16.0);
		}
		else
		{
			SetEntPropFloat(iEntity, Prop_Data, "m_speed", GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") / 4);
			SetEntPropFloat(npc.LeftTrack,  Prop_Send, "m_flPlaybackRate", 4.0);
			SetEntPropFloat(npc.RightTrack, Prop_Send, "m_flPlaybackRate", 4.0);
		}
		
		if(!npc.Pathing)
		{
			npc.Pathing = true;
		}
	}
}

public void PetMedicThink(int iEntity)
{
	PetMedic npc = view_as<PetMedic>(iEntity);
	npc.Update();
	
	float flOrigin[3], flAbsAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin",   flOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	
	float flCPos[3];
	GetClientAbsOrigin(client, flCPos);
	
	bool bHealing = npc.Healing;
	float flNextHealTime =  npc.NextHealTime - GetGameTime();
	
	if(bHealing)
	{
	/*	float v[3], ang[3], clientPos[3];
		GetClientEyePosition(client, clientPos);
		clientPos[2] -= 40.0;
		SubtractVectors(flOrigin, clientPos, v); 
		NormalizeVector(v, v);
		GetVectorAngles(v, ang); 
		
		int iPitch = utils_EntityLookupPoseParameter(iEntity, "body_pitch");
		if(iPitch >= 0)
		{
			float flPitch = utils_EntityGetPoseParameter(iEntity, iPitch);
			
			if (ang[0] > 180.0) 
				ang[0] -= 360.0;
			
			clamp(ang[0], -30.0, 30.0);
			clamp(flPitch, -30.0, 30.0);
			
			utils_EntitySetPoseParameter(iEntity, iPitch, ApproachAngle(ang[0], flPitch, 1.0));
		//	PrintToServer("ang[0] %f flNewPitch %f flPitch %f", ang[0], flNewPitch, flPitch);
		}*/
	
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
		
		npc.FaceTowards(flCPos);
	}
	
	float flDistance = GetVectorDistance(flCPos, flOrigin);
	if(flDistance <= 150.0)	
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
		}
	}
}

stock void EstimateYaw(int entity)
{
	// Get the frame time.
	float flDeltaTime = utils_GetFrameTime();
	if ( flDeltaTime == 0.0)
		return;
	
	// Get the player's velocity and angles.
	float vecEstVelocity[3];
	(view_as<BaseNPC>(entity)).GetVelocity(vecEstVelocity);
	
	float angles[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", angles);

	// If we are not moving, sync up the feet and eyes slowly.
	if ( vecEstVelocity[0] == 0.0 && vecEstVelocity[1] == 0.0 )
	{
		float flYawDelta = angles[1] - m_flEstimateYaw[entity];
		flYawDelta = AngleNormalize( flYawDelta );

		if ( flDeltaTime < 0.25 )
		{
			flYawDelta *= ( flDeltaTime * 4.0 );
		}
		else
		{
			flYawDelta *= flDeltaTime;
		}

		m_flEstimateYaw[entity] += flYawDelta;
		AngleNormalize( m_flEstimateYaw[entity] );
	}
	else
	{
		m_flEstimateYaw[entity] = (ArcTangent2(vecEstVelocity[1], vecEstVelocity[0]) * 180.0 / FLOAT_PI);
		m_flEstimateYaw[entity] = clamp(m_flEstimateYaw[entity], -180.0, 180.0);
	}
}

stock float CalcMovementPlaybackRate(int entity, bool &bIsMoving)
{
	// Get the player's current velocity and speed.
	float vecVelocity[3];
	(view_as<BaseNPC>(entity)).GetVelocity(vecVelocity);

	float flSpeed = GetVectorLength(vecVelocity, true); //SquareRoot(vecVelocity[0] * vecVelocity[0]) + (vecVelocity[1] * vecVelocity[1]);

	// Determine if the player is considered moving or not.
	bool bMoving = ( flSpeed > MOVING_MINIMUM_SPEED );

	// Initialize the return data.
	bIsMoving = false;
	float flReturn = 1.0;

	// If we are moving.
	if ( bMoving )
	{
		//float flGroundSpeed = GetInterpolatedGroundSpeed();
		float flGroundSpeed = GetCurrentMaxGroundSpeed(entity);
		
		if ( flGroundSpeed < 0.001 )
		{
			flReturn = 0.01;
		}
		else
		{
			// Note this gets set back to 1.0 if sequence changes due to ResetSequenceInfo below
			flReturn = flSpeed / flGroundSpeed;
			flReturn = clamp( flReturn, 0.01, 10.0);
		}
		
		bIsMoving = true;
	}
	
	return flReturn;
}

stock float GetCurrentMaxGroundSpeed(int entity)
{
	int iMoveX = utils_EntityLookupPoseParameter(entity, "move_x" );
	int iMoveY = utils_EntityLookupPoseParameter(entity, "move_y" );
	
	float prevX = utils_EntityGetPoseParameter(entity, iMoveX);
	float prevY = utils_EntityGetPoseParameter(entity, iMoveY);

	float d = SquareRoot(prevX * prevX + prevY * prevY);
	float newX, newY;
	if (d == 0.0)
	{ 
		newX = 1.0;
		newY = 0.0;
	}
	else
	{
		newX = prevX / d;
		newY = prevY / d;
	}
	
	utils_EntitySetPoseParameter(entity, iMoveX, newX);
	utils_EntitySetPoseParameter(entity, iMoveY, newY);
	
	float speed = utils_EntitySequenceGroundSpeed(entity, GetEntProp(entity, Prop_Data, "m_nSequence"));
	
	utils_EntitySetPoseParameter(entity, iMoveX, prevX);
	utils_EntitySetPoseParameter(entity, iMoveY, prevY);

	return speed;
}

stock float AngleNormalize(float angle)
{
	angle = angle - 360.0 * RoundToFloor(angle / 360.0);
	while (angle > 180.0) angle -= 360.0;
	while (angle < -180.0) angle += 360.0;
	return angle;
}

stock float clamp(float val, float minVal, float maxVal)
{
	if ( maxVal < minVal )
		return maxVal;
	else if( val < minVal )
		return minVal;
	else if( val > maxVal )
		return maxVal;
	else
		return val;
}

stock float AngleDiff(float ang1, float ang2)
{
	return AngleNormalize(ang1-ang2);
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

public void Blend9Think(int iEntity)
{
	BaseNPC npc = view_as<BaseNPC>(iEntity);
	
	char MoveAnim[32], IdleAnim[32];
	npc.MoveAnim(MoveAnim, sizeof(MoveAnim));
	npc.IdleAnim(IdleAnim, sizeof(IdleAnim));
	
	float flMoveSpeed = npc.MoveSpeed;
	float flOutOfRange = npc.OutOfRange;
	
	float flOrigin[3], flAbsAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin",   flOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	
	float flCPos[3];
	GetClientAbsOrigin(client, flCPos);
	
	float flDistance = GetVectorDistance(flCPos, flOrigin);
	
	//We don't wanna fall too behind
	if(flDistance >= flOutOfRange)
	{
		SetEntPropFloat(iEntity, Prop_Data, "m_speed", flMoveSpeed * 2);
		SetEntPropFloat(iEntity, Prop_Send, "m_flPlaybackRate", 2.0);
	}
	else
	{
		SetEntPropFloat(iEntity, Prop_Data, "m_speed", flMoveSpeed);
		SetEntPropFloat(iEntity, Prop_Send, "m_flPlaybackRate", 1.0);
	}
	
	int iMoveX = utils_EntityLookupPoseParameter(iEntity, "move_x");
	int iMoveY = utils_EntityLookupPoseParameter(iEntity, "move_y");
	
	// Get the estimated movement yaw.
	EstimateYaw(iEntity);
	
	// Get the view yaw.
	float flAngle = AngleNormalize(flAbsAngles[1]);

	// Calc side to side turning - the view vs. movement yaw.
	float flYaw = flAngle - m_flEstimateYaw[iEntity];
	flYaw = AngleNormalize( -flYaw );

	// Get the current speed the character is running.
	bool bIsMoving;
	float flPlaybackRate = CalcMovementPlaybackRate(iEntity, bIsMoving);
	
	// Setup the 9-way blend parameters based on our speed and direction.
	float vecCurrentMoveYaw[2] =  { 0.0, 0.0 };
	
	if (bIsMoving)
	{
		vecCurrentMoveYaw[0] = Cosine(DEG2RAD(flYaw)) * flPlaybackRate;
		vecCurrentMoveYaw[1] = -Sine(DEG2RAD(flYaw))  * flPlaybackRate;
		
		npc.SetAnimation(MoveAnim);
	}
	else
	{
		npc.SetAnimation(IdleAnim);
	}

	// Set the 9-way blend movement pose parameters.
	utils_EntitySetPoseParameter(iEntity, iMoveX, vecCurrentMoveYaw[0] * GetEntPropFloat(iEntity, Prop_Send, "m_flModelScale"));
	utils_EntitySetPoseParameter(iEntity, iMoveY, vecCurrentMoveYaw[1] * GetEntPropFloat(iEntity, Prop_Send, "m_flModelScale"));
}

public void Blend8Think(int iEntity)
{
	BaseNPC npc = view_as<BaseNPC>(iEntity);

	float flOrigin[3], flAbsAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin",   flOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", flAbsAngles);
	
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	
	float flOwnerPos[3];
	GetClientAbsOrigin(client, flOwnerPos);
	
	char MoveAnim[32], IdleAnim[32];
	npc.MoveAnim(MoveAnim, sizeof(MoveAnim));
	npc.IdleAnim(IdleAnim, sizeof(IdleAnim));
	
	float flMoveSpeed = npc.MoveSpeed;
	float flOutOfRange = npc.OutOfRange;
	
	float flDistance = GetVectorDistance(flOwnerPos, flOrigin);
	
	if (flDistance > 150.0)
	{	
		npc.SetAnimation(MoveAnim);
		
		//We don't wanna fall too behind
		if(flDistance >= flOutOfRange)
		{
			SetEntPropFloat(iEntity, Prop_Data, "m_speed", flMoveSpeed * 2);
			SetEntPropFloat(iEntity, Prop_Send, "m_flPlaybackRate", 2.0);
		}
		else
		{
			SetEntPropFloat(iEntity, Prop_Data, "m_speed", flMoveSpeed);
			SetEntPropFloat(iEntity, Prop_Send, "m_flPlaybackRate", 1.0);
		}
	}
	else
	{
		npc.SetAnimation(IdleAnim);
	}
	
	float vecDir[3];
	(view_as<BaseNPC>(iEntity)).GetVelocity(vecDir);
	
	//Strafe controller
	float flMoveYaw = 0.0;
	
	if (vecDir[1] == 0 && vecDir[0] == 0)
		flMoveYaw = 0.0;
	
	float yaw = ArcTangent2(vecDir[1], vecDir[0]);
	
	yaw = RAD2DEG(yaw);
	
	if (yaw < 0)
		yaw += 360;
	
	flMoveYaw = yaw;
	
	float flDiff = AngleDiff(flMoveYaw, flAbsAngles[1]);
	
	int index = utils_EntityLookupPoseParameter(iEntity, "move_yaw");
	float pose = utils_EntityGetPoseParameter(iEntity, index);
	
	utils_EntitySetPoseParameter(iEntity, index, ApproachAngle(flDiff, pose, 5.0));
}

public Action Command_PetMenu(int client, int argc)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		Menu menu = new Menu(PetSelectHandler);
		menu.SetTitle("Pets");
		menu.AddItem("0", "- Remove Pet");
		menu.AddItem("1", "Tank");
		menu.AddItem("2", "Medic");
		menu.AddItem("3", "Headcrab");
		menu.AddItem("4", "Ghost");
		menu.AddItem("5", "Robot Heavy");
		menu.AddItem("6", "Classic Zombie");
		menu.AddItem("7", "Alyx");
		menu.AddItem("8", "Gman");
		menu.Display(client, MENU_TIME_FOREVER);
	}
	
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
			//	AcceptEntityInput(pet, "Kill");
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
					
						PetTank npc = new PetTank(param1, flPos, flAng, strModel);
						
						npc.LeftTrack  = npc.EquipItem("smoke_attachment", "models/bots/tw2/boss_bot/tank_track_l.mdl", "forward");
						npc.RightTrack = npc.EquipItem("smoke_attachment", "models/bots/tw2/boss_bot/tank_track_r.mdl", "forward");
					}
					case 2:
					{
						PetTank npc = new PetTank(param1, flPos, flAng, "models/bots/boss_bot/boss_tank.mdl");
						
						npc.LeftTrack  = npc.EquipItem("smoke_attachment", "models/bots/boss_bot/tank_track_L.mdl", "forward");
						npc.RightTrack = npc.EquipItem("smoke_attachment", "models/bots/boss_bot/tank_track_R.mdl", "forward");
					}
				}
			}
			case 2:
			{
				PetMedic npc = new PetMedic(param1, flPos, flAng, "models/player/medic.mdl");
				
				npc.Weapon = npc.EquipItem("head", "models/weapons/c_models/c_medigun/c_medigun.mdl", _, 8);
				npc.EquipItem("head", "models/workshop/player/items/all_class/short2014_lil_moe/short2014_lil_moe_medic.mdl", _, GetClientTeam(param1) - 2);
				npc.EquipItem("head", "models/workshop/player/items/medic/hawaiian_shirt/hawaiian_shirt.mdl", _, GetClientTeam(param1) - 2);
				
				npc.StartHealing(param1);
			}
			case 3:
			{
				PetCrab npc = new PetCrab(param1, flPos, flAng, "models/headcrabclassic.mdl");
				npc.Update();
			}
			case 4:
			{
				switch(GetRandomInt(1, 2))
				{
					case 1:	
					{
						PetGhost npc = new PetGhost(param1, flPos, flAng, "models/props_halloween/ghost.mdl");
						npc.Update();
					}
					case 2:
					{
						PetGhost npc = new PetGhost(param1, flPos, flAng, GetClientTeam(param1) == 3 ? "models/props_halloween/ghost_no_hat_red.mdl" : "models/props_halloween/ghost_no_hat.mdl");
						npc.Update();
					}
				}
			}
			case 5:
			{
				PetHeavy npc = new PetHeavy(param1, flPos, flAng, "models/bots/heavy/bot_heavy.mdl");
				npc.Weapon = npc.EquipItem("head", "models/weapons/w_models/w_minigun.mdl", _, 8);
			}
			case 6:
			{
				PetZombie npc = new PetZombie(param1, flPos, flAng, "models/zombie/classic.mdl");
				npc.Update();
			}
			case 7:
			{
				PetAlyx npc = new PetAlyx(param1, flPos, flAng, "models/alyx.mdl");
				npc.Update();
			}
			case 8:
			{
				PetGman npc = new PetGman(param1, flPos, flAng, "models/gman.mdl");
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
	
	PrecacheModel("models/props_halloween/ghost.mdl");
	PrecacheModel("models/props_halloween/ghost_no_hat.mdl");
	PrecacheModel("models/props_halloween/ghost_no_hat_red.mdl");
	
	PrecacheModel("models/bots/heavy/bot_heavy.mdl");
	
	PrecacheModel("models/headcrabclassic.mdl");
	PrecacheModel("models/bots/skeleton_sniper_boss/skeleton_sniper_boss.mdl");
	PrecacheModel("models/zombie/classic.mdl");
	PrecacheModel("models/alyx.mdl");
	PrecacheModel("models/gman.mdl");
	
	PrecacheModel("models/bots/tw2/boss_bot/boss_tank.mdl");
	PrecacheModel("models/bots/boss_bot/boss_tank_damage1.mdl");
	PrecacheModel("models/bots/boss_bot/boss_tank_damage2.mdl");
	PrecacheModel("models/bots/boss_bot/boss_tank_damage3.mdl");
	PrecacheModel("models/bots/boss_bot/boss_tank.mdl");
	
	PrecacheModel("models/bots/tw2/boss_bot/tank_track_l.mdl");
	PrecacheModel("models/bots/tw2/boss_bot/tank_track_r.mdl");
	PrecacheModel("models/bots/boss_bot/tank_track_L.mdl");
	PrecacheModel("models/bots/boss_bot/tank_track_R.mdl");
}

public void OnPluginStart()
{
	RegAdminCmd("sm_pets", Command_PetMenu, ADMFLAG_ROOT);
	
	Handle hConf = LoadGameConfigFile("tf2.pets");
	
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
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "NextBotGroundLocomotion::Run");
	if((g_hRun = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for NextBotGroundLocomotion::Run!");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "NextBotGroundLocomotion::Approach");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	if((g_hApproach = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for NextBotGroundLocomotion::Approach!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "NextBotGroundLocomotion::FaceTowards");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	if((g_hFaceTowards = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for NextBotGroundLocomotion::FaceTowards!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "NextBotGroundLocomotion::Jump");
	if((g_hJump = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for NextBotGroundLocomotion::Jump!");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "NextBotGroundLocomotion::GetVelocity");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if((g_hGetVelocity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for NextBotGroundLocomotion::GetVelocity!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "NextBotGroundLocomotion::SetVelocity");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	if((g_hSetVelocity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for NextBotGroundLocomotion::SetVelocity!");
	
	//PluginBot SDKCalls
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBotComponent::GetBot");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hGetBot = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for INextBotComponent::GetBot!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBotComponent::GetEntity");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	if((g_hGetEntity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for INextBotComponent::GetEntity!");
	
	///
		
	int iOffset = GameConfGetOffset(hConf, "CTFBaseBossLocomotion::GetStepHeight");
	if(iOffset == -1) SetFailState("Failed to get offset of CTFBaseBossLocomotion::GetStepHeight");
	g_hGetStepHeight = DHookCreate(iOffset, HookType_Raw, ReturnType_Float, ThisPointer_Address, NextBotGroundLocomotion_GetStepHeight);

	iOffset = GameConfGetOffset(hConf, "NextBotGroundLocomotion::GetGravity");
	if(iOffset == -1) SetFailState("Failed to get offset of NextBotGroundLocomotion::GetGravity");
	g_hGetGravity = DHookCreate(iOffset, HookType_Raw, ReturnType_Float, ThisPointer_Address, NextBotGroundLocomotion_GetGravity);
	
	iOffset = GameConfGetOffset(hConf, "NextBotGroundLocomotion::GetFrictionForward");
	if(iOffset == -1) SetFailState("Failed to get offset of NextBotGroundLocomotion::GetFrictionForward");
	g_hGetFrictionForward = DHookCreate(iOffset, HookType_Raw, ReturnType_Float, ThisPointer_Address, NextBotGroundLocomotion_GetFriction);
	
	iOffset = GameConfGetOffset(hConf, "NextBotGroundLocomotion::GetFrictionSideways");
	if(iOffset == -1) SetFailState("Failed to get offset of NextBotGroundLocomotion::GetFrictionSideways");
	g_hGetFrictionSideways = DHookCreate(iOffset, HookType_Raw, ReturnType_Float, ThisPointer_Address, NextBotGroundLocomotion_GetFriction);
	
	iOffset = GameConfGetOffset(hConf, "NextBotGroundLocomotion::GetGroundNormal");
	if(iOffset == -1) SetFailState("Failed to get offset of NextBotGroundLocomotion::GetGroundNormal");
	g_hGetGroundNormal = DHookCreate(iOffset, HookType_Raw, ReturnType_VectorPtr, ThisPointer_Address, NextBotGroundLocomotion_GetGroundNormal);
	
	iOffset = GameConfGetOffset(hConf, "NextBotGroundLocomotion::ShouldCollideWith");
	if(iOffset == -1) SetFailState("Failed to get offset of NextBotGroundLocomotion::ShouldCollideWith");
	g_hShouldCollideWith = DHookCreate(iOffset, HookType_Raw, ReturnType_Bool, ThisPointer_Address, NextBotGroundLocomotion_ShouldCollideWith);
	DHookAddParam(g_hShouldCollideWith, HookParamType_CBaseEntity);
	
	iOffset = GameConfGetOffset(hConf, "IBody::GetSolidMask");
	if(iOffset == -1) SetFailState("Failed to get offset of IBody::GetSolidMask");
	g_hGetSolidMask = DHookCreate(iOffset, HookType_Raw, ReturnType_Int, ThisPointer_Address, IBody_GetSolidMask);
	
	iOffset = GameConfGetOffset(hConf, "IBody::StartActivity");
	g_hStartActivity = DHookCreate(iOffset, HookType_Raw, ReturnType_Bool, ThisPointer_Address, IBody_StartActivity);
	if (g_hStartActivity == null) SetFailState("Failed to create hook for IBody::StartActivity!");
	
	iOffset = GameConfGetOffset(hConf, "IBody::GetHullWidth");
	if(iOffset == -1) SetFailState("Failed to get offset of IBody::GetHullWidth");
	g_hGetHullWidth = DHookCreate(iOffset, HookType_Raw, ReturnType_Float, ThisPointer_Address, IBody_GetHullWidth);
	
	iOffset = GameConfGetOffset(hConf, "IBody::GetStandHullHeight");
	if(iOffset == -1) SetFailState("Failed to get offset of IBody::GetStandHullHeight");
	g_hGetStandHullHeight = DHookCreate(iOffset, HookType_Raw, ReturnType_Float, ThisPointer_Address, IBody_GetStandHullHeight);
	
	iOffset = GameConfGetOffset(hConf, "IBody::GetCrouchHullHeight");
	if(iOffset == -1) SetFailState("Failed to get offset of IBody::GetCrouchHullHeight");
	g_hGetCrouchHullHeight = DHookCreate(iOffset, HookType_Raw, ReturnType_Float, ThisPointer_Address, IBody_GetCrouchHullHeight);
	
	delete hConf;
}

public MRESReturn NextBotGroundLocomotion_GetStepHeight(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, 20.0);
	return MRES_Supercede;
}

public MRESReturn NextBotGroundLocomotion_GetFriction(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, 3.0);
	return MRES_Supercede;
}

public MRESReturn NextBotGroundLocomotion_GetGravity(Address pThis, Handle hReturn, Handle hParams)
{
	Address INextBot = SDKCall(g_hGetBot, pThis);
	int iEntity = SDKCall(g_hGetEntity, INextBot);

	float flGravity = GetEntPropFloat(iEntity, Prop_Data, "m_flGravity");
	if(flGravity <= 0.0)
		DHookSetReturn(hReturn, 800.0);
	else
		DHookSetReturn(hReturn, flGravity);
		
	return MRES_Supercede;
}

public MRESReturn IBody_GetSolidMask(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, 0x0201300B);
	return MRES_Supercede;
}

public MRESReturn IBody_GetHullWidth(Address pThis, Handle hReturn, Handle hParams)
{
	Address INextBot = SDKCall(g_hGetBot, pThis);
	int iEntity = SDKCall(g_hGetEntity, INextBot);

	float vecMaxs[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", vecMaxs);
	
	if(vecMaxs[1] > vecMaxs[0])
		DHookSetReturn(hReturn, vecMaxs[1] * 2);
	else
		DHookSetReturn(hReturn, vecMaxs[0] * 2);

	return MRES_Supercede;
}

public MRESReturn IBody_GetStandHullHeight(Address pThis, Handle hReturn, Handle hParams)
{
	Address INextBot = SDKCall(g_hGetBot, pThis);
	int iEntity = SDKCall(g_hGetEntity, INextBot);

	float vecMaxs[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", vecMaxs);
	
	DHookSetReturn(hReturn, vecMaxs[2]);

	return MRES_Supercede;
}

public MRESReturn IBody_GetCrouchHullHeight(Address pThis, Handle hReturn, Handle hParams)
{
	Address INextBot = SDKCall(g_hGetBot, pThis);
	int iEntity = SDKCall(g_hGetEntity, INextBot);

	float vecMaxs[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", vecMaxs);
	
	DHookSetReturn(hReturn, vecMaxs[2] / 2);

	return MRES_Supercede;
}

public MRESReturn IBody_StartActivity(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, true);
	return MRES_Supercede;
}

public MRESReturn NextBotGroundLocomotion_GetGroundNormal(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturnVector(hReturn, view_as<float>( { 0.0, 0.0, 1.0 } ));
	return MRES_Supercede;
}

public MRESReturn NextBotGroundLocomotion_ShouldCollideWith(Address pThis, Handle hReturn, Handle hParams)
{
	int iEntity = DHookGetParam(hParams, 1);
	if (IsValidEntity(iEntity))
	{
		char strClass[32];
		GetEdictClassname(iEntity, strClass, sizeof(strClass));
		
		if(StrEqual(strClass, "player") || StrEqual(strClass, "func_door") || StrEqual(strClass, "func_breakable") || StrEqual(strClass, "tf_pumpkin_bomb") || StrContains(strClass, "obj_") != -1)
		{
			DHookSetReturn(hReturn, false);
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
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