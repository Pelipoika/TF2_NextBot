#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <PathFollower>
#include <PathFollower_Nav>
#include <customkeyvalues>
#include <dhooks>

//#define DEBUG_ACTOR
//#define DEBUG_LOCOMOTION
//#define DEBUG_BODY

//Prints ::Update() function calls
//#define DEBUG_UPDATE

#include <base/CBaseActorZombie>

#pragma newdecls required;

public Plugin myinfo = 
{
	name = "[TF2] L4D2 Common Infected", 
	author = "Pelipoika", 
	description = "", 
	version = "1.0", 
	url = ""
};

/*int g_iInfectedRandomColorArray[][] =
{
	{ 255, 255, 255, 255 },
	{ 191, 191, 191, 255 },
	{ 127, 127, 127, 255 },
	{ 63,  63,  63,  255 },
	{ 125, 125, 155, 255 },
	{ 127, 140, 191, 255 },
	{ 178, 153, 153, 255 },
	{ 127, 89,  89,  255 },
	{ 191, 191, 127, 255 },
	{ 102, 76,  1,   255 },
	{ 127, 102, 76,  255 },
	{ 38,  76,  38,  255 },
	{ 76,  38,  38,  255 },
	{ 38,  38,  76,  255 },
	{ 0,   0,   0,   0   },
};
*/
public void OnPluginStart()
{
	RegAdminCmd("sm_infected", Command_Infected, ADMFLAG_ROOT);
	RegAdminCmd("sm_infecteddebug", Command_InfectedDebug, ADMFLAG_ROOT);
	
	InitGamedata();
}

public void OnMapStart()
{
	InitNavGamedata();
	
	PrecacheModel("models/infected/common_male_suit.mdl");
}

#define HEAD_VARIANTS 3
#define UPPERBODY_VARIANTS 2

enum InfectedBehavior
{
	BEHAVIOR_INVALID = -1, 
	
	InfectedWander, 
	InfectedStandDazed, 
	InfectedStandingActivity, 
	InfectedChangePosture,  //4
	InfectedStaggerAround, 
	InfectedSitDown, 
	InfectedLieDown, 
	InfectedLeanOnWall,  //8
	InfectedAlert, 
	InfectedAttack, 
	InfectedDying, 
	
	LostVictim, 
	PunchVictim, 
};

char InfectedBehaviorStrings[][] = 
{
	"InfectedWander", 
	"InfectedStandDazed", 
	"InfectedStandingActivity", 
	"InfectedChangePosture",  //4
	"InfectedStaggerAround", 
	"InfectedSitDown", 
	"InfectedLieDown", 
	"InfectedLeanOnWall",  //8
	"InfectedAlert", 
	"InfectedAttack", 
	"InfectedDying", 
	
	"LostVictim", 
	"PunchVictim", 
};

stock char[] GetBehaviorName(int beh)
{
	char name[64];
	
	if (beh <= 0)
		strcopy(name, sizeof(name), "BEHAVIOR_INVALID");
	else
		strcopy(name, sizeof(name), InfectedBehaviorStrings[view_as<int>(beh)]);
	
	return name;
}


// Chance that wandering infected will be lying down in a SPAWN_LYINGDOWN area.
int nav_lying_down_percent = 50;

// For testing.  0: default.  1: wandering zombies don't sit/lie down.  -1: wandering zombies always sit/lie down.
int z_must_wander = 0;

// Maximum degrees/sec turning while stumbling forward
float z_stumble_max_curve_rate = 10.0;

// Rate of turn increase per second
float z_stumble_max_curve_accel = 5.0;

// Rate of which to align ourself with our supporting wall
float z_lean_wall_align_speed = 300.0;

// For testing.  0: default.  1: unalerted common infected will stand still instead of wandering, turning, sitting, etc.
bool z_stand_still = false;

//The minimum time between vocalizing being shot
float z_vocalize_shot_interval = 0.5;

const float z_speed = 1000.0;

const float z_acquire_far_range = 2500.0;
const float z_acquire_far_time = 5.0;
const float z_acquire_near_range = 200.0;
const float z_acquire_near_time = 0.5;
const float z_acquire_time_variance_factor = 0.25;

const float z_attack_interval = 1.0;
const float z_attack_max_range = 68.0;
const float z_attack_min_range = 58.0;
const float z_attack_movement_penalty = 0.7;
const float z_attack_on_the_run_range = 83.0;
const float z_attack_change_target_range = 100.0;


methodmap CInfected < CZombieBotLocomotion
{
	property InfectedBehavior m_iCurrentAction
	{
		public get() { return view_as<InfectedBehavior>(this.ExtractStringValueAsInt("m_iCurrentAction")); }
		public set(InfectedBehavior iInt) { char buff[8]; IntToString(view_as<int>(iInt), buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iCurrentAction", buff, true); }
	}
	property InfectedBehavior m_iDesiredAction
	{
		public get() { return view_as<InfectedBehavior>(this.ExtractStringValueAsInt("m_iDesiredAction")); }
		public set(InfectedBehavior iInt) { char buff[8]; IntToString(view_as<int>(iInt), buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iDesiredAction", buff, true); }
	}
	property InfectedBehavior m_iActionOnComplete
	{
		public get() { return view_as<InfectedBehavior>(this.ExtractStringValueAsInt("m_iActionOnComplete")); }
		public set(InfectedBehavior iInt) { char buff[8]; IntToString(view_as<int>(iInt), buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iActionOnComplete", buff, true); }
	}
	
	property int m_iVariant
	{
		public get() { return (this.ExtractStringValueAsInt("m_iVariant")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iVariant", buff, true); }
	}
	
	property int m_iStandingActivity
	{
		public get() { return (this.ExtractStringValueAsInt("m_iStandingActivity")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iStandingActivity", buff, true); }
	}
	property float m_flNextVocalizeTime
	{
		public get() { return this.ExtractStringValueAsFloat("m_flNextVocalizeTime"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flNextVocalizeTime", buff, true); }
	}
	property float m_ctBecomeAlert
	{
		public get() { return this.ExtractStringValueAsFloat("m_ctBecomeAlert"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_ctBecomeAlert", buff, true); }
	}
	property float m_ctStandUp
	{
		public get() { return this.ExtractStringValueAsFloat("m_ctStandUp"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_ctStandUp", buff, true); }
	}
	property float m_ctStandingTimeout
	{
		public get() { return this.ExtractStringValueAsFloat("m_ctStandingTimeout"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_ctStandingTimeout", buff, true); }
	}
	property float m_ctShotVocalizeCooldown
	{
		public get() { return this.ExtractStringValueAsFloat("m_ctShotVocalizeCooldown"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_ctShotVocalizeCooldown", buff, true); }
	}
	property bool m_bCanStopStanding
	{
		public get() { return !!this.ExtractStringValueAsInt("m_bCanStopStanding"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_bCanStopStanding", buff, true); }
	}
	property float m_flRandomCurve
	{
		public get() { return this.ExtractStringValueAsFloat("m_flRandomCurve"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flRandomCurve", buff, true); }
	}
	property float m_flCurveRate
	{
		public get() { return this.ExtractStringValueAsFloat("m_flCurveRate"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flCurveRate", buff, true); }
	}
	
	//InfectedLeanOnWall
	property float m_ctLeanExpire
	{
		public get() { return this.ExtractStringValueAsFloat("m_ctLeanExpire"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_ctLeanExpire", buff, true); }
	}
	property float m_flAngleToWall
	{
		public get() { return this.ExtractStringValueAsFloat("m_flAngleToWall"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flAngleToWall", buff, true); }
	}
	property float lean_x
	{
		public get() { return this.ExtractStringValueAsFloat("lean_x"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "lean_x", buff, true); }
	}
	property float lean_y
	{
		public get() { return this.ExtractStringValueAsFloat("lean_y"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "lean_y", buff, true); }
	}
	property float lean_z
	{
		public get() { return this.ExtractStringValueAsFloat("lean_z"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "lean_z", buff, true); }
	}
	property int m_iLeanActivity
	{
		public get() { return (this.ExtractStringValueAsInt("m_iLeanActivity")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iLeanActivity", buff, true); }
	}
	public void GetLeanPosition(float pos[3])
	{
		pos[0] = this.lean_x;
		pos[1] = this.lean_y;
		pos[2] = this.lean_z;
	}
	public void SetLeanPosition(float pos[3])
	{
		this.lean_x = pos[0];
		this.lean_y = pos[1];
		this.lean_z = pos[2];
	}
	
	//InfectedAlert
	property float m_ctAlertExpireTime
	{
		public get() { return this.ExtractStringValueAsFloat("m_ctAlertExpireTime"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_ctAlertExpireTime", buff, true); }
	}
	property float m_ctNextAlertVocalize
	{
		public get() { return this.ExtractStringValueAsFloat("m_ctNextAlertVocalize"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_ctNextAlertVocalize", buff, true); }
	}
	property float m_ctAttackDisturbance
	{
		public get() { return this.ExtractStringValueAsFloat("m_ctAttackDisturbance"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_ctAttackDisturbance", buff, true); }
	}
	property float m_timer4
	{
		public get() { return this.ExtractStringValueAsFloat("m_timer4"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_timer4", buff, true); }
	}
	property float m_timer5
	{
		public get() { return this.ExtractStringValueAsFloat("m_timer5"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_timer5", buff, true); }
	}
	property int m_iAlertCauseType
	{
		public get() { return (this.ExtractStringValueAsInt("m_iAlertCauseType")); }
		public set(int iInt) { char buff[8]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iAlertCauseType", buff, true); }
	}
	property float m_vDisturbancePos_x
	{
		public get() { return this.ExtractStringValueAsFloat("m_vDisturbancePos_x"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_vDisturbancePos_x", buff, true); }
	}
	property float m_vDisturbancePos_y
	{
		public get() { return this.ExtractStringValueAsFloat("m_vDisturbancePos_y"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_vDisturbancePos_y", buff, true); }
	}
	property float m_vDisturbancePos_z
	{
		public get() { return this.ExtractStringValueAsFloat("m_vDisturbancePos_z"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_vDisturbancePos_z", buff, true); }
	}
	
	//InfectedAttack
	property int m_hTarget
	{
		public get()
		{
			return EntRefToEntIndex(this.ExtractStringValueAsInt("m_hTarget"));
		}
		public set(int iInt)
		{
			char buff[32];
			IntToString(iInt == INVALID_ENT_REFERENCE ? -1 : EntIndexToEntRef(iInt), buff, sizeof(buff));
			SetCustomKeyValue(this.index, "m_hTarget", buff, true);
		}
	}
	property bool m_bTargetIsPlayer
	{
		public get() { return !!this.ExtractStringValueAsInt("m_bTargetIsPlayer"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_bTargetIsPlayer", buff, true); }
	}
	
	//ChaseVictim	
	property float m_ctNextRageTime
	{
		public get() { return this.ExtractStringValueAsFloat("m_ctNextRageTime"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_ctNextRageTime", buff, true); }
	}
	
	//PunchVictim
	property float m_ctNextAttack
	{
		public get() { return this.ExtractStringValueAsFloat("m_ctNextAttack"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_ctNextAttack", buff, true); }
	}
	property float m_ctRageAtVictim
	{
		public get() { return this.ExtractStringValueAsFloat("m_ctRageAtVictim"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_ctRageAtVictim", buff, true); }
	}
	property float m_itAttackStart
	{
		public get() { return this.ExtractStringValueAsFloat("m_itAttackStart"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_itAttackStart", buff, true); }
	}
	property float m_ctAttackExpire
	{
		public get() { return this.ExtractStringValueAsFloat("m_ctAttackExpire"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_ctAttackExpire", buff, true); }
	}
	
	//LostVictim
	property float m_ctStumbleTimeout
	{
		public get() { return this.ExtractStringValueAsFloat("m_ctStumbleTimeout"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_ctStumbleTimeout", buff, true); }
	}
	
	//InfectedDying
	property int m_LastHitGroup
	{
		public get() { return (this.ExtractStringValueAsInt("m_LastHitGroup")); }
		public set(int iInt) { char buff[32]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_LastHitGroup", buff, true); }
	}
	
	property int m_LastDamageBits
	{
		public get() { return (this.ExtractStringValueAsInt("m_LastDamageBits")); }
		public set(int iInt) { char buff[32]; IntToString(iInt, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_LastDamageBits", buff, true); }
	}
	
	
	public CInfected(int client, float vecPos[3], float vecAng[3], const char[] model)
	{
		CInfected infected = view_as<CInfected>(CBaseActor(vecPos, vecAng, model, "1.0", "50"));
		
		int iActivity = infected.LookupActivity("ACT_TERROR_IDLE_NEUTRAL");
		
		infected.CreatePather(infected.GetStepHeight(), infected.GetMaxJumpHeight(), infected.GetDeathDropHeight(), infected.GetSolidMask(), 100.0, 0.15, 1.0);
		infected.m_flNextMeleeAttack = GetGameTime() + 1.0;
		
		SDKHook(infected.index, SDKHook_Think, InfectedThink);
		SDKHook(infected.index, SDKHook_TraceAttack, InfectedTraceAttack);
		SDKHook(infected.index, SDKHook_OnTakeDamageAlive, InfectedOnTakeDamage);
		
		//IDLE
		infected.m_bJumping = false;
		infected.m_isClimbingUpToLedge = false;
		
		infected.m_bIsOnGround = (GetEntityFlags(infected.index) & FL_ONGROUND != 0);
		
		infected.m_arousal = 0;
		
		infected.m_iActivity = iActivity;
		infected.m_iActivityFlags = 0;
		
		infected.m_iActivity2 = iActivity;
		infected.m_iActivityFlags2 = MOTION_CONTROLLED_XY;
		
		infected.m_iDesiredAction = InfectedWander;
		infected.m_iCurrentAction = BEHAVIOR_INVALID;
		infected.m_iActionOnComplete = BEHAVIOR_INVALID;
		
		infected.m_nPosture = STAND;
		infected.m_nDesiredPosture = STAND;
		
		//int iHead = infected.FindBodygroupByName("Head");
		//infected.SetBodygroup(iHead, GetRandomInt(0, HEAD_VARIANTS));
		
		//int iUpperBody = infected.FindBodygroupByName("UpperBody");
		//infected.SetBodygroup(iUpperBody, GetRandomInt(0, UPPERBODY_VARIANTS));
		
		infected.m_iAlertCauseType = 1;
		
		infected.m_iVariant = 0;
		
		infected.m_flRunSpeed = GetRandomFloat(0.9, 1.1) * 250.0;
		
		if (infected.m_iVariant == 1)
		{
			infected.m_flRunSpeed = infected.m_flRunSpeed * 0.5;
		}
		
		//TODO
		//Randomize bodygroups properly
		
		//Random skin
		SetEntProp(infected.index, Prop_Send, "m_nSkin", GetRandomInt(0, 1));
		
		//Random color
		//int iColor = GetRandomInt(0, sizeof(g_iInfectedRandomColorArray) - 1);
		//SetEntityRenderColor(infected.index, g_iInfectedRandomColorArray[iColor][0], g_iInfectedRandomColorArray[iColor][1], g_iInfectedRandomColorArray[iColor][2], g_iInfectedRandomColorArray[iColor][3]);
		
		float vecMaxs[3], vecMins[3];
		infected.GetHullMaxs(vecMaxs);
		infected.GetHullMins(vecMins);
		
		SetEntPropVector(infected.index, Prop_Send, "m_vecMaxs", vecMaxs);
		SetEntPropVector(infected.index, Prop_Data, "m_vecMaxs", vecMaxs);
		SetEntPropVector(infected.index, Prop_Send, "m_vecMins", vecMins);
		SetEntPropVector(infected.index, Prop_Data, "m_vecMins", vecMins);
		
		SetEntityMoveType(infected.index, MOVETYPE_VPHYSICS);
		
		return infected;
	}
	
	public bool ReactToSurvivorContact()
	{
		return true;
	}
	
	public bool DoSwingTrace(Handle &trace)
	{
		// Setup a volume for the melee weapon to be swung - approx size, so all melee behave the same.
		static float vecSwingMins[3]; vecSwingMins = view_as<float>( { -68, -68, -68 } );
		static float vecSwingMaxs[3]; vecSwingMaxs = view_as<float>( { 68, 68, 68 } );
		
		// Setup the swing range.
		float vecForward[3], vecRight[3], vecUp[3];
		this.GetVectors(vecForward, vecRight, vecUp);
		
		float vecSwingStart[3]; vecSwingStart = GetAbsOrigin(this.index);
		vecSwingStart[2] += 54.0;
		
		float vecSwingEnd[3];
		vecSwingEnd[0] = vecSwingStart[0] + vecForward[0] * 68;
		vecSwingEnd[1] = vecSwingStart[1] + vecForward[1] * 68;
		vecSwingEnd[2] = vecSwingStart[2] + vecForward[2] * 68;
		
		// See if we hit anything.
		trace = TR_TraceRayFilterEx(vecSwingStart, vecSwingEnd, (MASK_NPCSOLID | MASK_PLAYERSOLID), RayType_EndPoint, FilterBaseActorsAndDataButNotPlayer, this.index);
		if (TR_GetFraction(trace) >= 1.0)
		{
			delete trace;
			trace = TR_TraceHullFilterEx(vecSwingStart, vecSwingEnd, vecSwingMins, vecSwingMaxs, (MASK_NPCSOLID | MASK_PLAYERSOLID), FilterBaseActorsAndDataButNotPlayer, this.index);
			if (TR_GetFraction(trace) < 1.0)
			{
				// This is the point on the actual surface (the hull could have hit space)
				TR_GetEndPosition(vecSwingEnd, trace);
			}
		}
		
		return (TR_GetFraction(trace) < 1.0);
	}
	
	//TODO
	public void Vocalize(const char[] sound, bool bUnknown = false)
	{
		int[] clients = new int[MaxClients];
		int total = 0;
		
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				clients[total++] = i;
			}
		}
		
		if (!total) {
			return;
		}
		
		int channel;
		int level;
		float volume;
		int pitch;
		char sample[PLATFORM_MAX_PATH];
		
		if (GetGameSoundParams(sound, channel, level, volume, pitch, sample, sizeof(sample), this.index)) {
			
			if (StrContains(sample, "$gender") != -1)
			{
				PrintToServer("%i Vocalize gendered \"%s\"", this.index, sample);
			}
			else
			{
				PrecacheSound(sample);
				
				EmitSound(clients, total, sample, this.index, channel, level, _, volume, pitch);
				
				//PrintToServer("%i Vocalize(\"%s\", %d)", this.index, sound, bUnknown);
			}
		} else {
			//PrintToServer("%i Vocalize(\"%s\", %d) FAILED", this.index, sound, bUnknown);
		}
	}
	
	public void PlayStepSound(const char[] sound, float vPosition[3])
	{
		int[] clients = new int[MaxClients];
		int total = 0;
		
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				clients[total++] = i;
			}
		}
		
		if (!total) {
			return;
		}
		
		int channel;
		int level;
		float volume;
		int pitch;
		char sample[PLATFORM_MAX_PATH];
		
		if (GetGameSoundParams(sound, channel, level, volume, pitch, sample, sizeof(sample), this.index)) {
			
			PrecacheSound(sample);
			
			EmitSound(clients, total, sample, this.index, channel, level, _, volume, pitch, .origin = vPosition);
			
			//PrintToServer("%i PlayStepSound(\"%s\")", this.index, sound);
		} else {
			//PrintToServer("%i PlayStepSound(\"%s\") FAILED", this.index, sound);
		}
	}
	
	public void PlaySoundEffect(const char[] sound)
	{
		int[] clients = new int[MaxClients];
		int total = 0;
		
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				clients[total++] = i;
			}
		}
		
		if (!total) {
			return;
		}
		
		int channel;
		int level;
		float volume;
		int pitch;
		char sample[PLATFORM_MAX_PATH];
		
		if (GetGameSoundParams(sound, channel, level, volume, pitch, sample, sizeof(sample), this.index)) {
			
			PrecacheSound(sample);
			
			EmitSound(clients, total, sample, this.index, channel, level, _, volume, pitch);
			
			PrintToServer("%i PlaySoundEffect(\"%s\")", this.index, sound);
		} else {
			PrintToServer("%i PlaySoundEffect(\"%s\") FAILED", this.index, sound);
		}
	}
	
	public bool WasAttackedFromFront(int attacker, int inflictor, int bitsDamageType, float damgePosition[3])
	{
		float damageDirection[3];
		
		if (bitsDamageType & DMG_BUCKSHOT) {
			SubtractVectors(WorldSpaceCenter(this.index), WorldSpaceCenter(attacker), damageDirection);
		} else {
			SubtractVectors(damgePosition, WorldSpaceCenter(inflictor), damageDirection);
		}
		
		NormalizeVector(damageDirection, damageDirection);
		
		float vChest[3], aChest[3];
		this.GetAttachment("forward", vChest, aChest);
		
		return ((damageDirection[0] * aChest[0]) + (damageDirection[1] * aChest[1]) + (damageDirection[2] * aChest[2])) < 0.0;
	}
	
	public void DoBloodEffect(float flDamage, float vecDir[3], int attacker, int inflictor, int bitsDamageType, float damgePosition[3])
	{
		//CBaseEntity::TraceBleed(this, flDamage, vecDir, trace, a4->m_bitsDamageType);
		
		float vNegDmgDire[3]; vNegDmgDire = vecDir;
		NegateVector(vNegDmgDire);
		
		float vPartyAngles[3];
		GetVectorAngles(vNegDmgDire, vPartyAngles);
		
		//blood_impact_backscatter
		//breadjar_impact
		this.DispatchParticleEffect(this.index, "breadjar_impact", damgePosition, vPartyAngles, NULL_VECTOR);
	}
	
	public bool IsOutside()
	{
		TR_TraceRayFilter(GetAbsOrigin(this.index), view_as<float>( { -90.0, -90.0, -90.0 } ), MASK_SOLID, RayType_Infinite, FilterBaseActorsAndData, this.index);
		
		return !!(TR_GetSurfaceFlags() & SURF_SKY);
	}
	//TODO
	public bool CanRelax()
	{
		bool bCanRelax = false;
		
		if (!z_must_wander && this.m_bCanStopStanding)
		{
			bCanRelax = true;
		}
		
		return bCanRelax;
	}
	//TODO
	public bool IsStandingInWater()
	{
		float pos[3];
		pos = GetAbsOrigin(this.index);
		pos[2] += this.GetStepHeight();
		
		Handle trace = TR_TraceRayFilterEx(GetAbsOrigin(this.index), view_as<float>( { 90.0, 90.0, 90.0 } ), MASK_WATER, RayType_Infinite, FilterBaseActorsAndData, this.index);
		
		bool bStandingInWater = false;
		
		TR_GetEndPosition(pos, trace);
		
		if (TR_GetPointContents(pos) & MASK_WATER)
		{
			bStandingInWater = true;
		}
		
		delete trace;
		
		return bStandingInWater;
	}
	
	//InfectedAlert::
	public bool LookTowardsDisturbance()
	{
		float vFeet[3]; vFeet = GetAbsOrigin(this.index);
		
		float vToDisturbance[3];
		vToDisturbance[0] = this.m_vDisturbancePos_x - vFeet[0];
		vToDisturbance[1] = this.m_vDisturbancePos_y - vFeet[1];
		vToDisturbance[2] = 0.0;
		
		NormalizeVector(vToDisturbance, vToDisturbance);
		
		float vBodyDir[3];
		GetEntPropVector(this.index, Prop_Data, "m_angRotation", vBodyDir);
		vBodyDir[2] = 0.0;
		
		int iLookActivity = -1;
		
		int bInjured = this.m_iAlertCauseType != 1;
		
		float flDotToDisturbance = GetVectorDotProduct(vBodyDir, vToDisturbance);
		
		float FOURTH_PI = (FLOAT_PI / 4);
		
		if (flDotToDisturbance <= FOURTH_PI) {
			if (flDotToDisturbance >= -FOURTH_PI) {
				if (GetVectorDotProduct(vToDisturbance, vBodyDir) <= FOURTH_PI) {
					if (bInjured) {
						iLookActivity = this.LookupActivity("ACT_TERROR_IDLE_ALERT_INJURED_RIGHT");
						PrintToServer("ACT_TERROR_IDLE_ALERT_INJURED_RIGHT");
					} else {
						iLookActivity = this.LookupActivity("ACT_TERROR_IDLE_ALERT_RIGHT");
						PrintToServer("ACT_TERROR_IDLE_ALERT_RIGHT");
					}
				} else {
					if (bInjured) {
						iLookActivity = this.LookupActivity("ACT_TERROR_IDLE_ALERT_INJURED_LEFT");
						PrintToServer("ACT_TERROR_IDLE_ALERT_INJURED_LEFT");
					} else {
						iLookActivity = this.LookupActivity("ACT_TERROR_IDLE_ALERT_LEFT");
						PrintToServer("ACT_TERROR_IDLE_ALERT_LEFT");
					}
				}
			} else {
				if (bInjured) {
					iLookActivity = this.LookupActivity("ACT_TERROR_IDLE_ALERT_INJURED_BEHIND");
					PrintToServer("ACT_TERROR_IDLE_ALERT_INJURED_BEHIND");
				} else {
					iLookActivity = this.LookupActivity("ACT_TERROR_IDLE_ALERT_BEHIND");
					PrintToServer("ACT_TERROR_IDLE_ALERT_BEHIND");
				}
			}
		} else {
			if (bInjured) {
				iLookActivity = this.LookupActivity("ACT_TERROR_IDLE_ALERT_INJURED_AHEAD");
				PrintToServer("ACT_TERROR_IDLE_ALERT_INJURED_AHEAD");
			} else {
				iLookActivity = this.LookupActivity("ACT_TERROR_IDLE_ALERT_AHEAD");
				PrintToServer("ACT_TERROR_IDLE_ALERT_AHEAD");
			}
		}
		
		if (!this.StartActivity(iLookActivity, MOTION_CONTROLLED_XY | ENTINDEX_PLAYBACK_RATE))
			return false;
		
		//PrintToServer("InfectedAlert::LookTowardsDisturbance() iLookActivity %i", iLookActivity);
		
		this.m_timer4 = GetGameTime() + GetRandomFloat(1.0, 2.0);
		this.m_ctAlertExpireTime = GetGameTime() + GetRandomFloat(5.0, 15.0);
		
		return true;
	}
	
	//InfectedWander::
	public void BecomeAlert()
	{
		if (!this.IsArousal(INTENSE))
		{
			this.SetArousal(INTENSE);
			this.Vocalize("Zombie.BecomeEnraged", true);
		}
		
		if (this.IsActualPosture(SIT) || this.IsActualPosture(LIE))
		{
			this.SetDesiredPosture(STAND);
			
			this.m_iDesiredAction = InfectedChangePosture;
		}
	}
	
	//InfectedAttack::
	public bool IsValidEnemy(int enemy)
	{
		bool bValid = false;
		
		if (IsPlayerAlive(enemy)) {
			bValid = true;
		}
		
		if (enemy > 0 && enemy <= MaxClients) {
			bValid = GetTeam(enemy) != GetTeam(this.index);
		}
		
		return bValid;
	}
	
	public float GetBaseCommonAttackDamage()
	{
		return 2.0;
	}
	
	public float GetZombieAttackDamage()
	{
		/*
			long double __cdecl CDirector::GetZombieAttackDamage(CDirector *this, CTerrorPlayer *a2)
			{
				long double result; // fst7@3
				int Difficultry; // eax@5
				float v4; // xmm0_4@5
				float flBaseDamage; // [sp+1Ch] [bp-1Ch]@5
				
				if ( !a2 )
					goto LABEL_17;
					
				if ( (*(*a2 + 2020))(a2) )
					// z_attack_incapacitated_damage
					return *(dword_FA205C + 44);
					
				if ( CBaseEntity::GetTeamNumber(a2) == 3 && (*(*a2 + 1356))(a2) )
				{
					// z_attack_pz_it_damage
					result = *(dword_FA1FFC + 44);
				}
				else
				{
					LABEL_17:
					
					flBaseDamage = CDirector::GetBaseCommonAttackDamage(this);
					Difficultry = GetDifficulty();
					
					v4 = flBaseDamage;
					
					switch ( Difficultry )
					{
						case 2:
							v4 = flBaseDamage * 5.0;
							break;
						case 3:
							v4 = flBaseDamage * 20.0;
							break;
						case 1:
							v4 = flBaseDamage + flBaseDamage;
							break;
					}
					result = fmaxf(v4, 1.0);
				}
				return result;
			}
		*/
		
		return this.GetBaseCommonAttackDamage();
	}
	
	public void OnPunch()
	{
		if (this.m_hTarget == INVALID_ENT_REFERENCE)
			return;
		
		if (GetVectorDistance(GetAbsOrigin(this.index), GetAbsOrigin(this.m_hTarget)) < z_attack_max_range)
		{
			Handle swingTrace;
			if (this.DoSwingTrace(swingTrace))
			{
				int target = TR_GetEntityIndex(swingTrace);
				
				if (target <= 0)
				{
					delete swingTrace;
					return;
				}
				
				//TODO
				float flDamage = this.GetZombieAttackDamage();
				
				if (IsPlayer(target))
				{
					TF2_StunPlayer(target, 2.0, z_attack_movement_penalty, 1);
					
					this.PlaySoundEffect("Zombie.Punch");
				}
				
				//EmitPrivateSound target HitInternal
				
				SDKHooks_TakeDamage(target, this.index, this.index, flDamage, 128);
			}
			
			delete swingTrace;
		}
	}
	
	//InfectedDying::
	public bool IsStumbling()
	{
		char stumblingActivities[][] = 
		{
			"ACT_TERROR_SHOVED_FORWARD", 
			"ACT_TERROR_SHOVED_BACKWARD", 
			"ACT_TERROR_SHOVED_LEFTWARD", 
			"ACT_TERROR_SHOVED_RIGHTWARD", 
			
			"ACT_BLUDGEON_DEATH_BACK", 
			"ACT_BLUDGEON_DEATH_FORWARD", 
			"ACT_BLUDGEON_DEATH_LEFT", 
			"ACT_BLUDGEON_DEATH_RIGHT", 
			
			"ACT_SLICING_DEATH_BACK", 
			"ACT_SLICING_DEATH_FORWARD", 
			"ACT_SLICING_DEATH_LEFT", 
			"ACT_SLICING_DEATH_RIGHT", 
		};
		
		int iActivity = this.GetActivity();
		
		for (int i = 0; i < sizeof(stumblingActivities); i++)
		{
			if (iActivity != this.LookupActivity(stumblingActivities[i]))
				continue;
			
			return true;
		}
		
		return false;
	}
	
	//TODO
	//Not reversed fully beacuse no point for sourcepawn because we cant do most of the shit
	public bool TryToStartDeathThroes()
	{
		bool bStartedDeath = false;
		
		/*	damageTypeBits = this->m_vDeathInfo.m_bitsDamageType;
		if ( damageTypeBits & 0x1000000 )
		{
			this->m_vDeathInfo.m_vecDamageForce.x = this->m_vDeathInfo.m_vecDamageForce.x * 20.0;
			this->m_vDeathInfo.m_vecDamageForce.y = this->m_vDeathInfo.m_vecDamageForce.y * 20.0;
			this->m_vDeathInfo.m_vecDamageForce.z = this->m_vDeathInfo.m_vecDamageForce.z * 20.0;
		}
		bStartedDeath = 0;*/
		
		//Headshots insta ragdoll.
		if (this.m_LastHitGroup == 1)
		{
			return true;
		}
		
		if (!this.IsStumbling())
		{
			if (this.m_LastDamageBits & DMG_BUCKSHOT) {
				PrintToServer("Shotgunned");
			}
			
			if (this.m_LastDamageBits & DMG_CLUB) {
				PrintToServer("Meleed");
			}
			
			int iDeathActivity = this.LookupActivity(GetRandomInt(1, 2) == 1 ? "ACT_TERROR_DIE_FROM_STAND1" : "ACT_TERROR_DIE_FROM_STAND");
			
			if (GetVectorLength(GetAbsVelocity(this.index), true) >= 100.0)
			{
				iDeathActivity = this.LookupActivity("ACT_TERROR_DIE_WHILE_RUNNING");
			}
			
			if (this.StartActivity(iDeathActivity, MOTION_CONTROLLED_XY | ACTIVITY_UNINTERRUPTIBLE))
			{
				bStartedDeath = true;
			}
			
			//float flDamageDot = GetVectorDotProduct(
		}
		
		return bStartedDeath;
	}
	
	public bool IsGroundLevel(float flRadius)
	{
		return UTIL_IsGroundLevel(flRadius, GetAbsOrigin(this.index), this.GetCrouchHullHeight(), (MASK_NPCSOLID | MASK_PLAYERSOLID), this.index);
	}
}

//ON BEHAVIOR START
stock void Behavior_OnStart(CInfected me, InfectedBehavior behavior)
{
	switch (behavior)
	{
		case InfectedWander:
		{
			PrintToServer("InfectedWander::OnStart()");
			
			//InfectedWander::OnStart()
			me.SetArousal(NEUTRAL);
			
			me.m_flNextVocalizeTime = GetGameTime() + GetRandomFloat(0.0, 6.0);
			/////////////////////////////////////////////////////////////////////////
			
			
			//InfectedWander::InitialContainedAction()
			//1: wandering zombies don't sit/lie down.
			if (z_must_wander > 0)
			{
				me.m_iDesiredAction = GetRandomInt(0, 1) == 0 ? InfectedStandDazed : InfectedStaggerAround;
				return;
			}
			
			//-1: wandering zombies always sit/lie down.
			if (z_must_wander < 0)
			{
				me.m_iDesiredAction = GetRandomInt(0, 1) == 0 ? InfectedSitDown : InfectedLieDown;
				return;
			}
			
			int iRandomChance = GetRandomInt(0, 100);
			if (iRandomChance < nav_lying_down_percent) {
				me.m_iDesiredAction = InfectedLieDown;
			} else {
				if (me.IsOutside())
				{
					if (iRandomChance <= 4) {
						me.m_iDesiredAction = InfectedLieDown;
					} else {
						if (iRandomChance > 9) {
							me.m_iDesiredAction = InfectedStandDazed;
						} else {
							me.m_iDesiredAction = InfectedSitDown;
						}
					}
				} else if (iRandomChance <= 14) {
					me.m_iDesiredAction = InfectedLieDown;
					me.m_iActionOnComplete = InfectedLieDown;
				} else {
					if (iRandomChance > 29) {
						me.m_iDesiredAction = InfectedStandDazed;
					} else {
						me.m_iDesiredAction = InfectedSitDown;
					}
				}
			}
		}
		case InfectedStandingActivity:
		{
			PrintToServer("InfectedStandingActivity::OnStart()");
			
			me.StartActivity(me.m_iStandingActivity, MOTION_CONTROLLED_XY);
		}
		case InfectedStandDazed:
		{
			PrintToServer("InfectedStandDazed::OnStart()");
			
			/*
			InfectedStandDazed::OnResume()
			{
				me.StartActivity(me.LookupActivity("ACT_TERROR_IDLE_NEUTRAL"), MOTION_CONTROLLED_XY);
			}
			*/
			
			if (me.IsActualPosture(SIT) || me.IsActualPosture(LIE))
			{
				me.m_bCanStopStanding = false;
				
				me.SetDesiredPosture(STAND);
				
				me.m_iDesiredAction = InfectedChangePosture;
				me.m_iActionOnComplete = InfectedStandDazed;
			}
			else
			{
				me.m_bCanStopStanding = true;
				
				//TODO Change back to >= 50
				if (z_stand_still || GetRandomFloat(0.0, 100.0) >= 50.0)
				{
					me.StartActivity(me.LookupActivity("ACT_TERROR_IDLE_NEUTRAL"), MOTION_CONTROLLED_XY);
				}
				else
				{
					int iStandingActivity = me.LookupActivity("ACT_TERROR_FACE_LEFT_NEUTRAL");
					
					int iRandomFaceChance = GetRandomInt(0, 100);
					if (iRandomFaceChance > 32)
					{
						bool bDirection = iRandomFaceChance < 65;
						
						if (bDirection)
						{
							iStandingActivity = me.LookupActivity("ACT_TERROR_FACE_RIGHT_NEUTRAL");
						}
						else
						{
							iStandingActivity = me.LookupActivity("ACT_TERROR_FACE_LEFT_NEUTRAL");
						}
					}
					
					me.m_ctStandingTimeout = GetGameTime() + GetRandomFloat(3.0, 15.0);
					
					me.m_iDesiredAction = InfectedStandingActivity;
					me.m_iStandingActivity = iStandingActivity;
					me.m_iActionOnComplete = InfectedStandDazed;
					
					PrintToServer(" -> Starting with random facing (%i)", iStandingActivity);
				}
			}
		}
		case InfectedSitDown:
		{
			PrintToServer("InfectedSitDown::OnStart()");
			
			if (me.IsStandingInWater())
			{
				PrintToServer(" -> I don't want to sit in the water here - standing instead");
				me.m_iDesiredAction = InfectedStandDazed;
			}
			else
			{
				if (me.IsGroundLevel(30.0))
				{
					me.m_ctStandUp = GetGameTime() + GetRandomFloat(10.0, 30.0);
					
					if (!me.IsActualPosture(SIT))
					{
						me.SetDesiredPosture(SIT);
						
						me.m_iDesiredAction = InfectedChangePosture;
						me.m_iActionOnComplete = InfectedSitDown;
					}
				}
				else
				{
					PrintToServer(" -> No room to sit down - standing instead");
					me.m_iDesiredAction = InfectedStandDazed;
				}
			}
		}
		case InfectedLieDown:
		{
			PrintToServer("InfectedLieDown::OnStart()");
			
			if (me.IsStandingInWater())
			{
				me.m_iDesiredAction = InfectedStandDazed;
				PrintToServer(" -> I don't want to lie down in the water here - standing instead");
			}
			else
			{
				if (me.IsGroundLevel(50.0))
				{
					me.m_ctStandUp = GetGameTime() + GetRandomFloat(15.0, 30.0);
					
					if (!me.IsActualPosture(LIE))
					{
						me.SetDesiredPosture(LIE);
						
						me.m_iDesiredAction = InfectedChangePosture;
						me.m_iActionOnComplete = InfectedLieDown;
					}
				}
				else
				{
					PrintToServer(" -> No room to lie down - sitting instead");
					me.m_iDesiredAction = InfectedSitDown;
				}
			}
		}
		case InfectedChangePosture:
		{
			PrintToServer("InfectedChangePosture::OnStart()");
			
			me.m_bChangingPosture = true;
		}
		case InfectedStaggerAround:
		{
			PrintToServer("InfectedStaggerAround::OnStart()");
			
			//InfectedStaggerAround::StartStaggering
			me.StartActivity(me.LookupActivity("ACT_TERROR_WALK_NEUTRAL"), MOTION_CONTROLLED_XY);
			
			me.m_flRandomCurve = GetRandomFloat(-z_stumble_max_curve_rate, z_stumble_max_curve_rate);
			me.m_flCurveRate = 0.0;
		}
		case InfectedLeanOnWall:
		{
			PrintToServer("InfectedLeanOnWall::OnStart()");
			
			float vecFwd[3], vecRight[3], vecUp[3];
			me.GetVectors(vecFwd, vecRight, vecUp);
			
			float vLeanPos[3];
			me.GetLeanPosition(vLeanPos);
			
			float vLeanAngles[3];
			
			float flDotForward = GetVectorDotProduct(vecFwd, vLeanPos);
			if (flDotForward < 0.7071)
			{
				me.m_iLeanActivity = me.LookupActivity("ACT_TERROR_LEAN_FORWARD_IDLE");
				
				float vLeanDir[3];
				vLeanDir[0] = -vLeanPos[0];
				vLeanDir[1] = -vLeanPos[1];
				vLeanDir[2] = -vLeanPos[2];
				
				GetVectorAngles(vLeanDir, vLeanAngles);
			}
			else if (flDotForward > -0.7071)
			{
				me.m_iLeanActivity = me.LookupActivity("ACT_TERROR_LEAN_BACKWARD_IDLE");
				
				GetVectorAngles(vLeanPos, vLeanAngles);
			}
			else if (GetVectorDotProduct(vecRight, vLeanPos))
			{
				me.m_iLeanActivity = me.LookupActivity("ACT_TERROR_LEAN_RIGHTWARD_IDLE");
				
				float vLeanDir[3];
				vLeanDir[0] = vLeanPos[0];
				vLeanDir[1] = -vLeanPos[1];
				vLeanDir[2] = 0.0;
				
				GetVectorAngles(vLeanDir, vLeanAngles);
			}
			else
			{
				me.m_iLeanActivity = me.LookupActivity("ACT_TERROR_LEAN_LEFTWARD_IDLE");
				
				float vLeanDir[3];
				vLeanDir[0] = vLeanPos[1];
				vLeanDir[1] = -vLeanPos[0];
				vLeanDir[2] = 0.0;
				
				GetVectorAngles(vLeanDir, vLeanAngles);
			}
			
			//PrintToServer("vLeanAngles %f %f %f", vLeanAngles[0], vLeanAngles[1], vLeanAngles[2]);
			//PrintToServer("vLeanPos %f %f %f", vLeanPos[0], vLeanPos[1], vLeanPos[2]);
			//PrintToServer("flDotForward %f", flDotForward);
			
			float flHullWidth = me.GetHullWidth();
			float flStandHullHeight = me.GetStandHullHeight();
			
			float traceMax[3];
			traceMax[0] = flHullWidth;
			traceMax[1] = flHullWidth;
			
			if (me.m_iLeanActivity == me.LookupActivity("ACT_TERROR_LEAN_BACKWARD_IDLE"))
			{
				traceMax[0] = flStandHullHeight * 0.4;
				traceMax[1] = flStandHullHeight * 0.4;
				traceMax[2] = flStandHullHeight * 0.6;
			}
			else
			{
				traceMax[0] = flStandHullHeight * 0.75;
				traceMax[1] = flStandHullHeight * 0.75;
			}
			
			traceMax[2] = flStandHullHeight;
			
			float traceMin[3];
			traceMin[0] = -traceMax[0];
			traceMin[1] = -traceMax[1];
			traceMin[2] = 0.0;
			
			float start[3]; start = GetAbsOrigin(me.index);
			float end[3]; end = GetAbsOrigin(me.index);
			
			start[2] += flStandHullHeight;
			
			Handle trace = TR_TraceHullFilterEx(start, end, traceMin, traceMax, me.GetSolidMask(), FilterBaseActorsAndData, me.index);
			
			if (TR_DidHit(trace))
			{
				me.StartActivity(me.m_iLeanActivity, MOTION_CONTROLLED_XY);
				
				me.m_flAngleToWall = vLeanAngles[1];
				me.m_ctLeanExpire = GetGameTime() + GetRandomFloat(5.0, 20.0);
			}
			else
			{
				me.m_iDesiredAction = InfectedStandingActivity;
				me.m_iActionOnComplete = InfectedStandDazed;
				me.m_iStandingActivity = me.LookupActivity("ACT_TERROR_ABOUT_FACE_NEUTRAL");
				
				PrintToServer(" -> No support for lean");
			}
			
			delete trace;
		}
		case InfectedAlert:
		{
			me.Run();
			
			PrintToServer("InfectedAlert::OnStart()");
			
			me.SetArousal(ALERT);
			me.Vocalize("Zombie.BecomeAlert");
			
			me.m_ctNextAlertVocalize = GetGameTime() + GetRandomFloat(2.0, 4.0);
			
			//Stand up.
			if (me.IsActualPosture(SIT) || me.IsActualPosture(LIE))
			{
				me.SetDesiredPosture(STAND);
				
				me.m_iDesiredAction = InfectedChangePosture;
				me.m_iActionOnComplete = InfectedStandDazed;
			}
			else if (me.LookTowardsDisturbance())
			{
				me.m_ctAttackDisturbance = -1.0;
			}
			else
			{
				me.m_iDesiredAction = InfectedWander;
				me.m_bCanStopStanding = true;
			}
		}
		case InfectedAttack:
		{
			me.Run();
			
			PrintToServer("InfectedAttack::OnStart()");
			
			PF_StartPathing(me.index);
			
			me.BecomeAlert();
			
			me.m_iActionOnComplete = InfectedAttack;
		}
		case LostVictim:
		{
			if (me.IsRunning() && me.StartActivity(me.LookupActivity("ACT_TERROR_RUN_INTENSE_TO_STAND_ALERT"), MOTION_CONTROLLED_XY))
			{
				me.m_ctStumbleTimeout = GetGameTime() + 5.0;
				me.m_iActionOnComplete = InfectedWander;
				me.m_bCanStopStanding = true;
			}
		}
		case InfectedDying:
		{
			//Some debug trash
			
			//if(me->m_lifeState)
			//	Infected::Event_Killed(CTakeDamageInfo const&)
			//ForEachPlayer<ZombieDeath>(&v24); Finds players to play deathsound to and increases danger for survivor(s)
			//CBaseAnimatingOverlay::RemoveAllGestures
			
			//DYING
			//SetEntProp(me.index, Prop_Data, "m_lifeState", 1);
			
			char deathSound[64] = "Zombie.Die";
			
			if (!me.TryToStartDeathThroes())
			{
				if (me.m_LastHitGroup == 1) // head
				{
					//Infected::SetDamagedBodyGroupVariant(me, "Head", "Head");
					//Infected::SetDamagedBodyGroupVariant(me, "UpperBody", "Head");
					deathSound = "Zombie.HeadlessCough";
				}
				
				//deathForce.x = a3->m_vDeathInfo.m_vecDamageForce.x;
				//deathForce.y = a3->m_vDeathInfo.m_vecDamageForce.y;
				//deathForce.z = a3->m_vDeathInfo.m_vecDamageForce.z;
				
				//NextBotCombatCharacter::BecomeRagdoll(me, &a3->m_vDeathInfo, &deathForce);
			}
			
			me.PlaySoundEffect(deathSound);
		}
		case PunchVictim:
		{
			//TODO Worthless z_destroy_on_attack stuff
			
			me.m_itAttackStart = GetGameTime();
		}
	}
}


Address g_lastDamgageInfo = Address_Null;

//UPDATE CURRENT BEHAVIOR
stock void Behavior_Update(CInfected me, InfectedBehavior behavior)
{
	//TODO Implement InfectedBehavior here before other stuff.
	
	//PrintToServer("Behavior_Update (#%i) %i", me, behavior);
	
	switch (behavior)
	{
		case InfectedWander:
		{
			// Infected::GetVisionInterface()
			if (me.m_ctBecomeAlert <= GetGameTime()) //HasStarted
			{
				/*	if ( CDirector::IsFinale(TheDirector) || **(TheDirector + 352) )
				{
					iRandomSurvivor = CDirectorTacticalServices::GetRandomSurvivor();
					if ( iRandomSurvivor )
					{
						InfectedWander::BecomeAlert(infected, zombie, CBaseEntity::WorldSpaceCenter(iRandomSurvivor));
					}
				}*/
				
				CKnownEntity PrimaryThreat = me.GetVisionInterface().GetPrimaryKnownThreat();
				
				if (PrimaryThreat.Address != Address_Null)
				{
					float pos[3]; pos = WorldSpaceCenter(PrimaryThreat.GetEntity());
					me.m_vDisturbancePos_x = pos[0];
					me.m_vDisturbancePos_y = pos[1];
					me.m_vDisturbancePos_z = pos[2];
					
					me.BecomeAlert();
					me.m_iActionOnComplete = InfectedAttack;
				}
			}
			else
			{
				if (GetGameTime() >= me.m_ctBecomeAlert)
				{
					me.m_iDesiredAction = InfectedAlert;
					
					float myPos[3]; myPos = WorldSpaceCenter(me.index);
					me.m_vDisturbancePos_x = myPos[0];
					me.m_vDisturbancePos_y = myPos[1];
					me.m_vDisturbancePos_z = myPos[2];
					return;
				}
			}
			
			if (GetGameTime() >= me.m_flNextVocalizeTime)
			{
				me.m_flNextVocalizeTime = GetGameTime() + GetRandomFloat(4.0, 6.0);
				
				/*	if ( CBaseEntity::GetGender(zombie) == CLOW && RandomInt(1, 100) <= 49 )
				{
					v23 = CBaseAnimating::LookupAttachment(zombie, "flower");
					DispatchParticleEffect("blood_spray_clown", PATTACH_WORLDORIGIN, zombie, v23, 0);
					CBaseEntity::EmitSound(zombie, "Blood.Spurt", 0.0, 0);
				}*/
				
				me.Vocalize(me.IsActualPosture(STAND) ? "Zombie.Wander" : "Zombie.Sleeping", false);
			}
		}
		case InfectedStandingActivity:
		{
			//InfectedStandingActivity::OnAnimationActivityComplete()
			if (me.IsSequenceFinished())
			{
				//PrintToServer("InfectedStandingActivity::OnAnimationActivityComplete()");
				
				if (me.m_iActionOnComplete != BEHAVIOR_INVALID) {
					me.m_iDesiredAction = me.m_iActionOnComplete;
				} else {
					me.m_iDesiredAction = InfectedWander;
				}
			}
			/////////////////////////
		}
		case InfectedStandDazed:
		{
			if (z_stand_still) {
				return;
			}
			
			//InfectedStandDazed::OnAnimationActivityComplete
			if (me.IsSequenceFinished())
			{
				//PrintToServer("InfectedStandDazed::OnAnimationActivityComplete()");
				
				if (z_must_wander > 0)
				{
					me.m_iDesiredAction = InfectedStaggerAround;
					return;
				}
				
				if (z_must_wander < 0)
				{
					me.m_iDesiredAction = (GetRandomInt(0, 10) >= 5) ? InfectedSitDown : InfectedLieDown;
					return;
				}
				
				if (!me.CanRelax())
				{
					me.m_iDesiredAction = InfectedStaggerAround;
					return;
				}
				
				int iRandomChance = GetRandomInt(0, 100);
				if (!me.IsOutside())
				{
					//15% chance to lie down inside
					if (iRandomChance < 15)
					{
						me.m_iDesiredAction = InfectedLieDown;
						return;
					}
					//30% chance to sit down inside
					if (iRandomChance < 30)
					{
						me.m_iDesiredAction = InfectedSitDown;
						return;
					}
					
					//Else, stagger around
					me.m_iDesiredAction = InfectedStaggerAround;
				}
				else
				{
					//5% chance to lie down outside
					if (iRandomChance < 5)
					{
						me.m_iDesiredAction = InfectedLieDown;
						return;
					}
					//90% chance to stagger around outside
					if (iRandomChance >= 10)
					{
						me.m_iDesiredAction = InfectedStaggerAround;
						return;
					}
					
					//Else, sit down. bitch.
					me.m_iDesiredAction = InfectedSitDown;
				}
			}
			/////////////////////////
		}
		case InfectedSitDown:
		{
			if (GetGameTime() < me.m_ctStandUp) {
				return;
			}
			
			//Time to do something else.
			int iRandomChance = GetRandomInt(0, 100);
			
			if (me.IsOutside())
			{
				//75% chance to lie down outside.
				if (iRandomChance > 24) {
					me.m_iDesiredAction = InfectedLieDown;
				} else {
					me.m_iDesiredAction = InfectedStandDazed;
				}
			} else {
				if (iRandomChance <= 49) {
					me.m_iDesiredAction = InfectedLieDown;
				} else {
					me.m_iDesiredAction = InfectedStandDazed;
				}
			}
		}
		case InfectedLieDown:
		{
			if (GetGameTime() < me.m_ctStandUp) {
				return;
			}
			
			//Time to do something else.
			int iRandomChance = GetRandomInt(0, 100);
			
			if (me.IsOutside()) {
				//75% chance to lie down outside.
				if (iRandomChance > 24) {
					me.m_iDesiredAction = InfectedStandDazed;
				} else {
					me.m_iDesiredAction = InfectedSitDown;
				}
			} else {
				if (iRandomChance < 75) {
					me.m_iDesiredAction = InfectedSitDown;
				} else {
					me.m_iDesiredAction = InfectedStandDazed;
				}
			}
		}
		case InfectedChangePosture:
		{
			if (me.IsInDesiredPosture())
			{
				if (me.m_iActionOnComplete != BEHAVIOR_INVALID) {
					me.m_iDesiredAction = me.m_iActionOnComplete;
				}
			} else {
				if (!me.IsPostureChanging()) {
					me.SetDesiredPosture(me.m_nDesiredPosture);
				}
			}
		}
		case InfectedStaggerAround:
		{
			//InfectedStaggerAround::OnAnimationActivityComplete
			if (me.IsSequenceFinished())
			{
				//PrintToServer("InfectedStaggerAround::OnAnimationActivityComplete %i", me.m_iActivityBackupNeverNull);
				
				//if(me.m_iActivityBackupNeverNull == me.LookupActivity("ACT_TERROR_WALK_NEUTRAL"))
				//{
				me.m_iDesiredAction = InfectedStandDazed;
				return;
				//}
			}
			/////////////////////////
			
			float flNewCurve = (GetGameFrameTime() * z_stumble_max_curve_accel) + me.m_flCurveRate;
			float flCurrentCurve = me.m_flRandomCurve;
			
			me.m_flCurveRate = flNewCurve;
			
			if (flNewCurve > flCurrentCurve)
			{
				me.m_flCurveRate = flCurrentCurve;
				flNewCurve = flCurrentCurve;
			}
			
			float vLocalAngles[3]; GetEntPropVector(me.index, Prop_Data, "m_angRotation", vLocalAngles);
			
			vLocalAngles[1] += (flNewCurve * GetGameFrameTime());
			
			TeleportEntity(me.index, NULL_VECTOR, vLocalAngles, NULL_VECTOR);
		}
		case InfectedLeanOnWall:
		{
			if (GetGameTime() < me.m_ctLeanExpire)
			{
				float vFeet[3];
				GetEntPropVector(me.index, Prop_Data, "m_angRotation", vFeet);
				
				float vNewAngle[3];
				vNewAngle[0] = vFeet[0];
				vNewAngle[1] = ApproachAngle(me.m_flAngleToWall, vFeet[1], GetGameFrameTime() * z_lean_wall_align_speed);
				vNewAngle[2] = 0.0;
				
				TeleportEntity(me.index, NULL_VECTOR, vNewAngle, NULL_VECTOR);
			}
			/*	else if(me.m_iLeanActivity == me.LookupActivity("ACT_TERROR_LEAN_BACKWARD_IDLE"))
			{
				
			}*/
			else
			{
				me.m_iDesiredAction = InfectedStandingActivity;
				me.m_iActionOnComplete = InfectedStandDazed;
				me.m_iStandingActivity = me.LookupActivity("ACT_TERROR_ABOUT_FACE_NEUTRAL");
				
				PrintToServer(" -> Finished with lean");
			}
		}
		case InfectedAlert:
		{
			int m_iLastCompletedActivity = me.m_iLastCompletedActivity;
			
			//PrintToServer("InfectedAlert::OnAnimationActivityComplete(%i)", m_iLastCompletedActivity);
			
			if (m_iLastCompletedActivity == me.LookupActivity("ACT_TERROR_NEUTRAL_TO_ALERT"))
			{
				me.StartActivity(me.LookupActivity("ACT_TERROR_IDLE_ALERT"), MOTION_CONTROLLED_XY);
				//PrintToServer("InfectedAlert::OnAnimationActivityComplete(ACT_TERROR_NEUTRAL_TO_ALERT)");
			}
			else if (m_iLastCompletedActivity == me.LookupActivity("ACT_TERROR_IDLE_ALERT_BEHIND")
				 || m_iLastCompletedActivity == me.LookupActivity("ACT_TERROR_IDLE_ALERT_AHEAD")
				 || m_iLastCompletedActivity == me.LookupActivity("ACT_TERROR_IDLE_ALERT_RIGHT")
				 || m_iLastCompletedActivity == me.LookupActivity("ACT_TERROR_IDLE_ALERT_LEFT"))
			{
				int ACT_TERROR_ALERT_TO_NEUTRAL = me.LookupActivity("ACT_TERROR_ALERT_TO_NEUTRAL");
				
				if (!me.IsActivity(ACT_TERROR_ALERT_TO_NEUTRAL))
				{
					me.StartActivity(me.LookupActivity("ACT_TERROR_ALERT_TO_NEUTRAL"), MOTION_CONTROLLED_XY);
					//PrintToServer("InfectedAlert::OnAnimationActivityComplete(ACT_TERROR_IDLE_ALERT_?)");
				}
			}
			else if (m_iLastCompletedActivity == me.LookupActivity("ACT_TERROR_ALERT_TO_NEUTRAL"))
			{
				me.m_iDesiredAction = InfectedWander;
				//PrintToServer("InfectedAlert::OnAnimationActivityComplete(ACT_TERROR_ALERT_TO_NEUTRAL)");
			}
			
			//OnAnimationActivityComplete ^
			//Update v
			
			/*
			if ( CDirector::IsFinale(TheDirector) || **(TheDirector + 352) )
			{
				v4 = *(TheDirector + 346);
				v44 = CDirectorTacticalServices::GetRandomSurvivor();
				if ( v44 )
				{
					v5 = operator new(0x48u);
					InfectedAttack::InfectedAttack(v5, v44);
					LABEL_8:
					this->m_type = 1;
					this->m_action = v5;
					this->m_reason = 0;
					goto LABEL_24;
				}
			}
			*/
			
			if (GetGameTime() > me.m_ctNextAlertVocalize)
			{
				me.Vocalize("Zombie.Alert", false);
				
				me.m_ctNextAlertVocalize = GetGameTime() + GetRandomFloat(2.0, 4.0);
			}
			
			if (me.m_timer5 != -1.0 && GetGameTime() > me.m_timer5)
			{
				PrintToServer("m_timer5 LookTowardsDisturbance");
				
				me.LookTowardsDisturbance();
				
				me.m_timer5 = -1.0;
			}
			
			CKnownEntity target = me.GetVisionInterface().GetPrimaryKnownThreat();
			
			if (target.Address != Address_Null)
			{
				if (me.m_ctAttackDisturbance <= 0.0)
				{
					//INextBot::GetRangeTo(CBaseEntity*)
					float flRangeToTarget = GetVectorDistance(GetAbsOrigin(me.index), GetAbsOrigin(target.GetEntity()));
					
					float flVarianceMultiplier = GetRandomFloat((1.0 - z_acquire_time_variance_factor), (z_acquire_time_variance_factor + 1.0));
					
					float flReactionTime = flVarianceMultiplier * clamp((flRangeToTarget - z_acquire_near_range) / (z_acquire_far_range - z_acquire_near_range), 0.0, 1.0) * (z_acquire_far_time - z_acquire_near_time) + z_acquire_near_time;
					
					me.m_ctAttackDisturbance = GetGameTime() + flReactionTime;
					
					int ACT_TERROR_IDLE_ACQUIRE = me.LookupActivity("ACT_TERROR_IDLE_ACQUIRE");
					if (!me.IsActivity(ACT_TERROR_IDLE_ACQUIRE))
					{
						me.StartActivity(ACT_TERROR_IDLE_ACQUIRE, MOTION_CONTROLLED_XY);
					}
					
					//Infected::SetAlertBodyGroupVariant(me, "Head", "Head");
				}
				else
				{
					//ZombieBotBody::AimHeadTowards(target, IMPORTANT, 0.1, 0, "Watch our victim")
					
					if (GetGameTime() >= me.m_ctAttackDisturbance)
					{
						me.m_hTarget = target.GetEntity();
						PF_SetGoalEntity(me.index, target.GetEntity());
						
						me.m_iDesiredAction = InfectedAttack;
						return;
					}
				}
			}
			else
			{
				if (me.m_ctAttackDisturbance != 0.0)
				{
					me.m_ctAttackDisturbance = -1.0;
					
					int ACT_TERROR_IDLE_ALERT = me.LookupActivity("ACT_TERROR_IDLE_ALERT");
					if (!me.IsActivity(ACT_TERROR_IDLE_ALERT))
					{
						me.StartActivity(ACT_TERROR_IDLE_ALERT, MOTION_CONTROLLED_XY);
					}
					
					//Infected::SetIdleBodyGroupVariant(me, "Head");
				}
			}
			
			if (GetGameTime() >= me.m_ctAlertExpireTime)
			{
				int ACT_TERROR_ALERT_TO_NEUTRAL = me.LookupActivity("ACT_TERROR_ALERT_TO_NEUTRAL");
				
				if (!me.IsActivity(ACT_TERROR_ALERT_TO_NEUTRAL))
				{
					me.StartActivity(ACT_TERROR_ALERT_TO_NEUTRAL, MOTION_CONTROLLED_XY);
				}
			}
		}
		case InfectedAttack:
		{
			int iTarget = me.m_hTarget;
			if (iTarget == INVALID_ENT_REFERENCE)
			{
				if (me.m_bTargetIsPlayer)
				{
					//We were chasing a player but they seem to have disappeared.
					float vFeet[3]; vFeet = GetAbsOrigin(me.index);
					float vMotion[3]; me.GetGroundMotionVector(vMotion);
					
					me.m_vDisturbancePos_x = (vMotion[0] * 100.0) + vFeet[0];
					me.m_vDisturbancePos_y = (vMotion[1] * 100.0) + vFeet[1];
					me.m_vDisturbancePos_z = (vMotion[2] * 100.0) + vFeet[2];
					
					
					me.m_iAlertCauseType = 0;
					me.m_iDesiredAction = InfectedAlert;
				}
				else
				{
					//Vision.Reset();
					me.m_bCanStopStanding = false;
					me.m_iDesiredAction = InfectedWander;
				}
			}
			else
			{
				//ChaseVictim::Update()
				//PrintToServer("ChaseVictim::Update()");
				
				if (!IsAlive(iTarget))
				{
					me.m_iDesiredAction = LostVictim;
					
					PF_StopPathing(me.index);
					
					PrintToServer(" -> Victim died");
				}
				else if (PF_IsEntityACombatCharacter(iTarget))
				{
					float flDistanceToTarget = GetVectorDistance(WorldSpaceCenter(iTarget), WorldSpaceCenter(me.index));
					
					//Predict their pos.
					if (flDistanceToTarget < 500.0) {
						PF_SetGoalVector(me.index, PredictSubjectPosition(me, iTarget));
					} else {
						PF_SetGoalEntity(me.index, iTarget);
					}
					
					PF_StartPathing(me.index);
					
					/*	
					//TODO
					//Stuck detection and culling.
					if(me.IsImmobile())
					{
						float flImmobileDuration = me.GetImmobileDuration();
						
						if(flImmobileDuration > 3.0)
						{
							CNavArea lastArea = PF_GetLastKnownArea(me.index);
							
							if(lastArea != NavArea_Null)
							{
								
							}
							
							//if ( !CDirectorTacticalServices::IsVisibleToTeam(*(TheDirector + 346), me, 2, 0, 0.0, 0) )
								//...
							
							if(z_debug_stuck)
							{
								//...
							}
						}
					}*/
					
					//TODO
					//AimHeadTowards(iTarget, IMPORTANT, 0.1, 0, "Watch our victim", true, 0.25);
					
					float vVictim[3]; vVictim = GetAbsOrigin(iTarget);
					float vMe[3]; vMe = GetAbsOrigin(me.index); //Actually eyes
					
					//TODO
					if (me.IsOnGround() && !me.IsUsingLadder())
					{
						float flDistanceToVictim = GetVectorDistance(vVictim, vMe);
						
						//IsRangeLessThan
						if (flDistanceToVictim < z_attack_min_range)
						{
							//me.SetVelocity(view_as<float>({0.0, 0.0, 0.0}));
							//me.SetAcceleration(view_as<float>({0.0, 0.0, 0.0}));
							
							me.m_hTarget = iTarget;
							me.m_ctAttackExpire = -1.0;
							me.m_iDesiredAction = PunchVictim;
							
							PrintToServer("PunchVictim");
						}
						
						//Before this is an if check for !CTerrorPlayer::IsIncapacitated() 
						if (flDistanceToVictim < z_attack_on_the_run_range)
						{
							//TODO
							
							if (GetGameTime() > me.m_ctNextAttack && !me.IsPlayingGesture("ACT_TERROR_ATTACK"))
								//&& me.IsInFieldOfView(iTarget))
							{
								me.AddGesture("ACT_TERROR_ATTACK", true);
								
								me.m_ctNextAttack = GetGameTime() + z_attack_interval;
							}
						}
					}
					
					//IsPlayer
					if (iTarget > 0 && iTarget <= MaxClients)
					{
						CKnownEntity target = me.GetVisionInterface().GetPrimaryKnownThreat();
						
						if (target.Address != Address_Null)
						{
							int iNewTarget = target.GetEntity();
							if (me.IsValidEnemy(iNewTarget))
							{
								float flRangeToCurrentTarget = GetVectorDistance(vMe, vVictim, true);
								float flRangeToPotentialTarget = GetVectorDistance(vMe, GetAbsOrigin(iNewTarget), true);
								
								if (flRangeToCurrentTarget > flRangeToPotentialTarget)
								{
									if (GetVectorDistance(vMe, GetAbsOrigin(iNewTarget)) < z_attack_change_target_range)
									{
										me.m_hTarget = iNewTarget;
									}
								}
							}
						}
					}
					
					if (!me.IsClimbingOrJumping() && !me.IsUsingLadder() && me.IsOnGround())
					{
						if (me.m_bHasValidPath)
						{
							//TODO Something here for ACT_TERROR_CRAWL_RUN
							//else
							
							
							if (me.m_iVariant == 1)
							{
								int ACT_TERROR_CRAWL_RUN = me.LookupActivity("ACT_TERROR_CRAWL_RUN");
								if (!me.IsActivity(ACT_TERROR_CRAWL_RUN))
								{
									me.StartActivity(ACT_TERROR_CRAWL_RUN, 0);
								}
							}
							else
							{
								bool bStanding = me.IsActualPosture(STAND);
								
								if (!bStanding)
								{
									int ACT_TERROR_CROUCH_RUN_INTENSE = me.LookupActivity("ACT_TERROR_CROUCH_RUN_INTENSE");
									if (!me.IsActivity(ACT_TERROR_CROUCH_RUN_INTENSE))
									{
										me.StartActivity(ACT_TERROR_CROUCH_RUN_INTENSE, 0);
									}
								}
								else
								{
									int ACT_TERROR_RUN_INTENSE = me.LookupActivity("ACT_TERROR_RUN_INTENSE");
									if (!me.IsActivity(ACT_TERROR_RUN_INTENSE))
									{
										me.StartActivity(ACT_TERROR_RUN_INTENSE, 0);
									}
								}
							}
						}
						else
						{
							int ACT_TERROR_UNABLE_TO_REACH_TARGET = me.LookupActivity("ACT_TERROR_UNABLE_TO_REACH_TARGET");
							if (!me.IsActivity(ACT_TERROR_UNABLE_TO_REACH_TARGET))
							{
								me.StartActivity(ACT_TERROR_UNABLE_TO_REACH_TARGET, MOTION_CONTROLLED_XY);
							}
							
							//TODO
							//Face target
							
							//float vecToTarget[3];
							//MakeVectorFromPoints(vMe, vVictim, vecToTarget);
							
							//float angToTarget[3];
							//GetVectorAngles(vecToTarget, angToTarget);
							
							//angToTarget[0] = 0.0;
							
							me.FaceTowards(vVictim);
							
							//TeleportEntity(me.index, NULL_VECTOR, angToTarget, NULL_VECTOR);
						}
					}
					
					if (GetGameTime() >= me.m_ctNextRageTime)
					{
						//TODO
						// if(!GetPrimaryRecognizedThreat())
						//Infected::Vocalize(me, &"Zombie.Rage", 0);
						//else
						//Infected::Vocalize(me, &"Zombie.RageAtVictim", 0);
						
						me.Vocalize("Zombie.Rage", false);
						
						me.m_ctNextRageTime = GetGameTime() + GetRandomFloat(1.0, 2.0);
					}
				}
			}
		}
		case LostVictim:
		{
			if (me.IsActivity(me.LookupActivity("ACT_TERROR_RUN_INTENSE_TO_STAND_ALERT")))
			{
				if (GetGameTime() >= me.m_ctStumbleTimeout)
				{
					PrintToServer(" -> Spent too long in this state");
					me.m_iAlertCauseType = 0;
					me.m_iDesiredAction = InfectedAlert;
				}
			}
			else
			{
				PrintToServer(" -> No longer stumbling to a stop");
				me.m_iAlertCauseType = 0;
				me.m_iDesiredAction = InfectedAlert;
			}
		}
		case InfectedDying: //TODO
		{
			if (me.IsSequenceFinished())
			{
				SetEntProp(me.index, Prop_Data, "m_lifeState", 2);
				//PrintToServer("KUOLE PERKELE");
				
				int attacker = me.m_hTarget;
				if (attacker == INVALID_ENT_REFERENCE)
					attacker = 0;
				
				//SDKHooks_TakeDamage(me.index, attacker, attacker, 50.0, me.m_LastDamageBits);
				
				SDKCall(g_hNextBotCombatCharacter_Event_Killed, me.index, g_lastDamgageInfo);
				SDKCall(g_hCBaseCombatCharacter_Event_Killed, me.index, g_lastDamgageInfo);
				
				//AcceptEntityInput(me.index, "BecomeRagdoll");
			}
			
			/*	if(!me.IsStumbling())
			{
			}*/
		}
		case PunchVictim:
		{
			//ZombieBotBody::AimHeadTowards(me.m_hTarget, 2, 0.1, "Watch our victim");
			
			int m_hTarget = me.m_hTarget;
			
			if (m_hTarget == INVALID_ENT_REFERENCE)
			{
				//TODO
				me.m_iDesiredAction = LostVictim;
				return;
			}
			
			if (GetGameTime() >= me.m_ctRageAtVictim)
			{
				me.Vocalize("Zombie.RageAtVictim", false);
				
				me.m_ctRageAtVictim = GetGameTime() + GetRandomFloat(1.0, 2.0);
			}
			
			if (IsPlayer(m_hTarget))
			{
				if (IsAlive(m_hTarget))
				{
					me.m_ctAttackExpire = GetGameTime() + GetRandomFloat(1.0, 2.0);
				}
				else
				{
					if (GetGameTime() >= me.m_ctAttackExpire)
					{
						//TODO We can stop attacking now
						PrintToServer("PunchVictim::SUSPEND m_ctAttackExpire");
						me.m_iDesiredAction = InfectedAttack;
						return;
					}
				}
			}
			else if (GetSolidFlags(m_hTarget) & 0x4) //FSOLID_NOT_SOLID
			{
				//TODO We can stop attacking now
				PrintToServer("PunchVictim::SUSPEND FSOLID_NOT_SOLID");
				me.m_iDesiredAction = InfectedAttack;
				return;
			}
			
			if (GetVectorDistance(GetAbsOrigin(me.index), GetAbsOrigin(m_hTarget)) > z_attack_max_range)
			{
				PrintToServer("PunchVictim::SUSPEND z_attack_max_range");
				me.m_iDesiredAction = InfectedAttack;
				return;
			}
			
			if (PF_IsEntityACombatCharacter(m_hTarget))
			{
				if (me.IsActualPosture(STAND))
				{
					/*int ACT_TERROR_ATTACK_LOW_CONTINUOUSLY = me.LookupActivity("ACT_TERROR_ATTACK_LOW_CONTINUOUSLY");
				
					if(!me.IsActivity(ACT_TERROR_ATTACK_LOW_CONTINUOUSLY)) {
						me.StartActivity(ACT_TERROR_ATTACK_CONTINUOUSLY, MOTION_CONTROLLED_XY);
					}*/
					
					int ACT_TERROR_ATTACK_CONTINUOUSLY = me.LookupActivity("ACT_TERROR_ATTACK_CONTINUOUSLY");
					
					if (!me.IsActivity(ACT_TERROR_ATTACK_CONTINUOUSLY)) {
						me.StartActivity(ACT_TERROR_ATTACK_CONTINUOUSLY, MOTION_CONTROLLED_XY);
					}
					
				}
			}
			
			me.FaceTowards(GetAbsOrigin(m_hTarget));
		}
	}
}

//TODO Rewrite
public void InfectedThink(int iNPC)
{
	if (!IsAlive(iNPC))
		return;
	
	CInfected npc = view_as<CInfected>(iNPC);
	
	npc.Update();
	
	//Always update InfectedWander
	Behavior_Update(npc, InfectedWander);
	
	if (npc.IsClimbingUpToLedge()) {
		
		if (npc.IsSequenceFinished()) {
			npc.m_isClimbingUpToLedge = false;
		}
		
		return;
	}
	
	if (!npc.m_bIsOnGround && (GetEntityFlags(npc.index) & FL_ONGROUND) != 0)
	{
		npc.m_bIsOnGround = true;
		npc.m_bJumping = false;
		
		float vVelocity[3]; vVelocity = GetAbsVelocity(npc.index);
		PrintToServer("%f %f %f", vVelocity[0], vVelocity[1], vVelocity[2]);
		
		npc.OnLandOnGround(0);
	}
	else if (npc.m_bIsOnGround && (GetEntityFlags(npc.index) & FL_ONGROUND) == 0)
	{
		npc.m_bIsOnGround = false;
	}
	
	InfectedBehavior currAction = npc.m_iCurrentAction;
	InfectedBehavior desiredAction = npc.m_iDesiredAction;
	
	if (currAction != desiredAction)
	{
		npc.m_iCurrentAction = desiredAction;
		Behavior_OnStart(npc, desiredAction);
	}
	else
	{
		Behavior_Update(npc, currAction);
	}
}

public Action InfectedTraceAttack(int victim, int & attacker, int & inflictor, float & damage, int & damagetype, int & ammotype, int hitbox, int hitgroup)
{
	PrintToServer("InfectedDamaged victim %i attacker %i inflictor %i damage %.1f hitbox %i hitgroup %i", victim, attacker, inflictor, damage, hitbox, hitgroup);
	
	//Friendly fire
	if (GetTeam(attacker) == GetTeam(victim))
		return Plugin_Continue;
	
	//Valid attackers only.
	if (attacker <= 0 || attacker > MaxClients)
		return Plugin_Continue;
	
	CInfected npc = view_as<CInfected>(victim);
	
	if (damagetype & DMG_BULLET)
	{
		if (GetGameTime() >= npc.m_ctShotVocalizeCooldown)
		{
			npc.PlaySoundEffect("Zombie.Shot");
			npc.m_ctShotVocalizeCooldown = GetGameTime() + z_vocalize_shot_interval;
		}
	}
	
	if (damagetype & DMG_BURN == 0
		 && damagetype & DMG_CLUB == 0)
	{
		npc.PlaySoundEffect("Zombie.BulletImpact");
	}
	
	if (damagetype & DMG_BURN)
	{
		npc.PlaySoundEffect("Zombie.Ignited");
		npc.PlaySoundEffect("Zombie.IgniteScream");
		
		//CBaseAnimating::Scorch(5, 75);
	}
	
	npc.m_LastHitGroup = hitgroup;
	npc.m_LastDamageBits = damagetype;
	
	npc.AddGesture("ACT_TERROR_FLINCH", true);
	
	bool bIsKnownAttacker = (npc.GetVisionInterface().GetKnown(attacker).Address != Address_Null);
	if (!bIsKnownAttacker)
	{
		npc.GetVisionInterface().AddKnownEntity(attacker);
	}
	
	if (npc.m_iCurrentAction != InfectedDying && damage >= GetEntProp(npc.index, Prop_Data, "m_iHealth"))
	{
		npc.m_iDesiredAction = InfectedDying;
		
		damage = 0.0;
		return Plugin_Changed;
	}
	
	return Plugin_Changed;
}

public Action InfectedOnTakeDamage(int victim, int & attacker, int & inflictor, float & damage, int & damagetype, int & weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	PrintToServer("InfectedOnTakeDamage victim %i attacker %i inflictor %i damage %.1f", victim, attacker, inflictor, damage);
	
	//Friendly fire
	if (GetTeam(attacker) == GetTeam(victim))
		return Plugin_Continue;
	
	CInfected npc = view_as<CInfected>(victim);
	
	float vDir[3]; SubtractVectors(WorldSpaceCenter(attacker), damagePosition, vDir);
	
	npc.DoBloodEffect(damage, vDir, attacker, inflictor, damagetype, damagePosition);
	
	return Plugin_Continue;
}

//FIX TODO HACK
public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "env_entity_dissolver"))
	{
		RemoveEntity(entity);
	}
}

public Action Command_Infected(int client, int argc)
{
	//What are you.
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
		return Plugin_Handled;
	
	float flPos[3], flAng[3];
	GetClientAbsAngles(client, flAng);
	
	float StartOrigin[3], Angles[3];
	GetClientEyeAngles(client, Angles);
	GetClientEyePosition(client, StartOrigin);
	
	
	Handle TraceRay = TR_TraceRayFilterEx(StartOrigin, Angles, (MASK_NPCSOLID | MASK_PLAYERSOLID), RayType_Infinite, FilterBaseActorsAndData, client);
	if (TR_DidHit(TraceRay))
	{
		TR_GetEndPosition(flPos, TraceRay);
	}
	
	delete TraceRay;
	
	flAng[0] = 0.0;
	flAng[1] = GetRandomFloat(0.0, 360.0);
	flAng[2] = 0.0;
	
	//CInfected(client, flPos, flAng, "models/infected/common_male_suit.mdl");
	CInfected(client, flPos, flAng, "models/player/kirillian/infected/scout_l4d2_zombie.mdl");
	
	return Plugin_Handled;
}

public Action Command_InfectedDebug(int client, int argc)
{
	if (argc > 0)
	{
		char strCmd[32];
		GetCmdArgString(strCmd, sizeof(strCmd));
		
		int iEnt = -1;
		while ((iEnt = FindEntityByClassname(iEnt, "base_boss")) != -1)
		{
			CInfected z = view_as<CInfected>(iEnt);
			
			if (StrEqual(strCmd, "z_sit_down", false)) {
				z.m_iDesiredAction = InfectedSitDown;
			} else if (StrEqual(strCmd, "z_lie_down", false)) {
				z.m_iDesiredAction = InfectedLieDown;
			} else if (StrEqual(strCmd, "z_stand", false)) {
				z.m_iDesiredAction = InfectedStandDazed;
			} else if (StrEqual(strCmd, "z_stagger", false)) {
				z.m_iDesiredAction = InfectedStaggerAround;
			} else if (StrEqual(strCmd, "z_punch", false)) {
				z.m_iDesiredAction = PunchVictim;
			} else {
				ReplyToCommand(client, "[Infected] Invalid command \"%s\"", strCmd);
				break;
			}
		}
		
		return Plugin_Handled;
	}
	
	int iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, "base_boss")) != -1)
	{
		Event event = CreateEvent("show_annotation");
		event.SetFloat("lifetime", 10.0);
		event.SetInt("id", client + 40 + iEnt);
		event.SetInt("follow_entindex", iEnt);
		
		char strMsg[2048];
		Format(strMsg, sizeof(strMsg), "%sm_iDesiredAction = %s\nm_iCurrentAction = %s\nm_iActionOnComplete = %s\n%s%s%s", 
			InfectedVariableAsString(iEnt, "m_arousal"), 
			GetBehaviorName(view_as<CInfected>(iEnt).ExtractStringValueAsInt("m_iDesiredAction")), 
			GetBehaviorName(view_as<CInfected>(iEnt).ExtractStringValueAsInt("m_iCurrentAction")), 
			GetBehaviorName(view_as<CInfected>(iEnt).ExtractStringValueAsInt("m_iActionOnComplete")), 
			InfectedVariableAsString(iEnt, "m_bChangingPosture"), 
			InfectedVariableAsString(iEnt, "m_nPosture"), 
			InfectedVariableAsString(iEnt, "m_nDesiredPosture"));
		
		event.SetString("text", strMsg);
		
		event.SetString("play_sound", "vo/null.mp3");
		
		event.SetString("show_effect", "0");
		event.SetString("show_distance", "0");
		
		event.SetInt("visibilityBitfield", 1 << client);
		event.Fire(false);
	}
	
	return Plugin_Handled;
}

stock char[] InfectedVariableAsString(int z, const char[] variable)
{
	char strVar[32];
	Format(strVar, sizeof(strVar), "%s = %i\n", variable, view_as<CInfected>(z).ExtractStringValueAsInt(variable));
	
	return strVar;
}

//Ragdoll.
public MRESReturn CTFBaseBoss_Event_Killed(int pThis, Handle hParams)
{
	SetEntProp(pThis, Prop_Data, "m_lifeState", 1);
	
	PrintToServer("!!!!!!!!!!!! CTFBaseBoss_Event_Killed %i", pThis);
	
	Address CTakeDamageInfo = DHookGetParam(hParams, 1);
	
	//SDKCall(g_hNextBotCombatCharacter_Event_Killed, pThis, CTakeDamageInfo);
	//SDKCall(g_hCBaseCombatCharacter_Event_Killed,   pThis, CTakeDamageInfo);
	
	g_lastDamgageInfo = CTakeDamageInfo;
	
	return MRES_Supercede;
}

public MRESReturn CBaseAnimating_HandleAnimEvent(int pThis, Handle hParams)
{
	//#if defined DEBUG_LOCOMOTION
	
	CInfected me = view_as<CInfected>(pThis);
	
	int iEvent = DHookGetParamObjectPtrVar(hParams, 1, 0, ObjectValueType_Int);
	//PrintToServer("CBaseAnimating_HandleAnimEvent(%i, %i)", pThis, iEvent);
	
	if (iEvent == 54)
	{
		//PrintToServer("InfectedAttack::OnPunch");
		me.OnPunch();
	}
	
	char strSound[64];
	
	float vSoundPos[3], vFootAngles[3];
	if (iEvent == 53) {
		me.GetAttachment("lfoot", vSoundPos, vFootAngles);
	} else if (iEvent == 52) {
		me.GetAttachment("rfoot", vSoundPos, vFootAngles);
	}
	
	TR_TraceRayFilter(vSoundPos, view_as<float>( { 90.0, 90.0, 90.0 } ), me.GetSolidMask(), RayType_Infinite, FilterBaseActorsAndData, me.index);
	char material[PLATFORM_MAX_PATH]; TR_GetSurfaceName(null, material, PLATFORM_MAX_PATH);
	
	Format(strSound, sizeof(strSound), "Infected.%s.%s%s", GetStepSoundForMaterial(material), me.IsRunning() ? "Run" : "Walk", iEvent == 53 ? "Left" : "Right");
	
	//PrintToServer("Step on %s", material);
	
	me.PlayStepSound(strSound, vSoundPos);
	
	
	//#endif
}

stock char[] GetStepSoundForMaterial(const char[] material)
{
	char sound[32]; sound = "Default";
	
	if (StrContains(material, "wood", false) != -1)sound = "Wood";
	else if (StrContains(material, "Metal", false) != -1)sound = "SolidMetal";
	else if (StrContains(material, "Tile", false) != -1)sound = "Tile";
	else if (StrContains(material, "Concrete", false) != -1)sound = "Concrete";
	else if (StrContains(material, "Gravel", false) != -1)sound = "Gravel";
	else if (StrContains(material, "ChainLink", false) != -1)sound = "ChainLink";
	else if (StrContains(material, "Flesh", false) != -1)sound = "Flesh";
	
	return sound;
}

public MRESReturn ILocomotion_OnContact(Address pThis, Handle hParams)
{
	if (DHookIsNullParam(hParams, 1)) {
		return MRES_Ignored;
	}
	
	Address CGameTrace = DHookGetParam(hParams, 2);
	if (CGameTrace == Address_Null) {
		return MRES_Ignored;
	}
	
	bool bStartSolid = !!LoadFromAddress((CGameTrace + view_as<Address>(0x37)), NumberType_Int8);
	
	float plane_normal[3];
	plane_normal[0] = view_as<float>(LoadFromAddress((CGameTrace + view_as<Address>(0x18)), NumberType_Int32));
	plane_normal[1] = view_as<float>(LoadFromAddress((CGameTrace + view_as<Address>(0x1C)), NumberType_Int32));
	plane_normal[2] = view_as<float>(LoadFromAddress((CGameTrace + view_as<Address>(0x20)), NumberType_Int32));
	
	int iOther = DHookGetParam(hParams, 1);
	
	CInfected me = view_as<CInfected>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis)));
	
	switch (me.m_iCurrentAction)
	{
		case InfectedAlert:
		{
			if (!IsPlayer(iOther) && PF_IsEntityACombatCharacter(iOther))
			{
				if (GetTeam(me.index) != GetTeam(iOther))
				{
					float vDist[3]; vDist = WorldSpaceCenter(iOther);
					me.m_vDisturbancePos_x = vDist[0];
					me.m_vDisturbancePos_y = vDist[1];
					me.m_vDisturbancePos_z = vDist[2];
					
					me.m_iDesiredAction = InfectedAttack;
					me.m_hTarget = iOther;
					return MRES_Ignored;
				}
			}
		}
		case InfectedWander: //BIG TODO
		{
			if (!IsAlive(iOther)) {
				return MRES_Ignored;
			}
			
			if (!IsPlayer(iOther) && PF_IsEntityACombatCharacter(iOther))
			{
				//TODO NOT CORRECT FIX
				
				/*if (GetTeam(me.index) != GetTeam(iOther))
				{
					float vDist[3]; vDist = WorldSpaceCenter(iOther);
					me.m_vDisturbancePos_x = vDist[0];
					me.m_vDisturbancePos_y = vDist[1];
					me.m_vDisturbancePos_z = vDist[2];
					
					me.m_iDesiredAction = InfectedAttack;
					me.m_hTarget = iOther;
					return MRES_Ignored;
				}*/
			}
			
			//TODO InfectedShoved
			/*	if(GetTeam(me.index) == GetTeam(iOther)) //Make believe !IsASurvivorTeam(other->team)
			{
				me.m_iDesiredAction = InfectedShoved;
				me.m_hShovedBy = iOther;
				
				return MRES_Ignored;
			}*/
			
			if (me.ReactToSurvivorContact())
			{
				me.m_iDesiredAction = InfectedAttack;
				me.m_hTarget = iOther;
			}
		}
		case InfectedDying:
		{
			if (PF_IsEntityACombatCharacter(iOther))
			{
				//TODO 
				/*
					if ( Other isplayer)
					{
						// CBaseEntity::WorldSpaceCenter() 
						InfectedDying::ComputeShoveForce(a2, a3, other_WSC);
					}
					InfectedDying::BecomeRagdoll(a2, a3);
				*/
				//AcceptEntityInput(me.index, "BecomeRagdoll");
			}
		}
		case InfectedStaggerAround:
		{
			if (bStartSolid) {
				return MRES_Ignored;
			}
			
			if (iOther > 0 && PF_IsEntityACombatCharacter(iOther))
			{
				if (GetTeam(me.index) != GetTeam(iOther)) //Make believe IsASurvivorTeam
				{
					if (me.ReactToSurvivorContact())
					{
						float vDist[3]; vDist = WorldSpaceCenter(iOther);
						me.m_vDisturbancePos_x = vDist[0];
						me.m_vDisturbancePos_y = vDist[1];
						me.m_vDisturbancePos_z = vDist[2];
						
						me.m_iDesiredAction = InfectedAlert;
						me.m_hTarget = iOther;
						return MRES_Ignored;
					}
				}
			}
			
			if (plane_normal[2] >= 0.1 || iOther != 0)
			{
				PrintToServer(" -> Bumped into something");
				
				me.m_iDesiredAction = InfectedStandingActivity;
				me.m_iActionOnComplete = InfectedStandDazed;
				me.m_iStandingActivity = me.LookupActivity("ACT_TERROR_ABOUT_FACE_NEUTRAL");
			}
			else
			{
				PrintToServer(" -> Bumped into a wall");
				
				me.SetLeanPosition(plane_normal);
				me.m_iDesiredAction = InfectedLeanOnWall;
			}
		}
	}
	
	//PrintToServer("ILocomotion::OnContact(%i, 0x%X)", iOther, CGameTrace);
	
	return MRES_Ignored;
}


stock float[] PredictSubjectPosition(CInfected npc, int subject)
{
	float botPos[3];
	GetEntPropVector(npc.index, Prop_Data, "m_vecAbsOrigin", botPos);
	
	float subjectPos[3];
	GetEntPropVector(subject, Prop_Data, "m_vecAbsOrigin", subjectPos);
	
	float to[3];
	SubtractVectors(subjectPos, botPos, to);
	to[2] = 0.0;
	
	float flRangeSq = GetVectorLength(to, true);
	
	// don't lead if subject is very far away
	float flLeadRadiusSq = 500.0;
	flLeadRadiusSq *= flLeadRadiusSq;
	if (flRangeSq > flLeadRadiusSq)
		return subjectPos;
	
	// Normalize in place
	float range = SquareRoot(flRangeSq);
	to[0] /= (range + 0.0001); // avoid divide by zero
	to[1] /= (range + 0.0001); // avoid divide by zero
	to[2] /= (range + 0.0001); // avoid divide by zero
	
	// estimate time to reach subject, assuming maximum speed
	float leadTime = 0.5 + (range / (npc.GetRunSpeed() + 0.0001));
	
	// estimate amount to lead the subject	
	float SubjectAbsVelocity[3];
	GetEntPropVector(subject, Prop_Data, "m_vecAbsVelocity", SubjectAbsVelocity);
	float lead[3];
	lead[0] = leadTime * SubjectAbsVelocity[0];
	lead[1] = leadTime * SubjectAbsVelocity[1];
	lead[2] = 0.0;
	
	if (GetVectorDotProduct(to, lead) < 0.0)
	{
		// the subject is moving towards us - only pay attention 
		// to his perpendicular velocity for leading
		float to2D[3]; to2D = to;
		to2D[2] = 0.0;
		NormalizeVector(to2D, to2D);
		
		float perp[2];
		perp[0] = -to2D[1];
		perp[1] = to2D[0];
		
		float enemyGroundSpeed = lead[0] * perp[0] + lead[1] * perp[1];
		
		lead[0] = enemyGroundSpeed * perp[0];
		lead[1] = enemyGroundSpeed * perp[1];
	}
	
	// compute our desired destination
	float pathTarget[3];
	AddVectors(subjectPos, lead, pathTarget);
	
	// validate this destination
	
	// don't lead through walls
	if (GetVectorLength(lead, true) > 36.0)
	{
		float fraction;
		if (!PF_IsPotentiallyTraversable(npc.index, subjectPos, pathTarget, IMMEDIATELY, fraction))
		{
			// tried to lead through an unwalkable area - clip to walkable space
			pathTarget[0] = subjectPos[0] + fraction * (pathTarget[0] - subjectPos[0]);
			pathTarget[1] = subjectPos[1] + fraction * (pathTarget[1] - subjectPos[1]);
			pathTarget[2] = subjectPos[2] + fraction * (pathTarget[2] - subjectPos[2]);
		}
	}
	
	NavArea leadArea = TheNavMesh.GetNearestNavArea_Vec(pathTarget);
	
	if (leadArea == NavArea_Null || leadArea.GetZ(pathTarget[0], pathTarget[1]) < pathTarget[2] - npc.GetMaxJumpHeight())
	{
		// would fall off a cliff
		return subjectPos;
	}
	
	return pathTarget;
}
