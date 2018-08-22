#include <sdkhooks>
#include <tf2_stocks>
#include <PathFollower>
#include <PathFollower_Nav>
#include <customkeyvalues>
#include <dhooks>

//#define DEBUG_UPDATE
//#define DEBUG_ANIMATION
//#define DEBUG_SOUND

#include <base/CBaseActor>

#pragma newdecls required;

#define GORE_HEAD         (1 << 0)
#define GORE_HEADLEFT     (1 << 1)
#define GORE_HEADRIGHT    (1 << 2)
#define GORE_HANDLEFT     (1 << 3)
#define GORE_HANDRIGHT    (1 << 4)
#define GORE_UPARMLEFT    (1 << 5)
#define GORE_UPARMRIGHT   (1 << 6)
#define GORE_FOREARMLEFT  (1 << 7)
#define GORE_FOREARMRIGHT (1 << 8)
#define GORE_ABDOMEN      (1 << 9)

char g_DeathSounds[][] = {
	")gorefast/gorefast_death_01.wav",
	")gorefast/gorefast_death_02.wav",
	")gorefast/gorefast_death_03.wav",
	")gorefast/gorefast_death_04.wav",
};

char g_HurtSounds[][] = {
	")gorefast/gorefast_hurt_01.wav",
	")gorefast/gorefast_hurt_02.wav",
	")gorefast/gorefast_hurt_03.wav",
	")gorefast/gorefast_hurt_04.wav",
};

char g_IdleSounds[][] = {
	")gorefast/gorefast_idle_wet_01.wav",
	")gorefast/gorefast_idle_wet_02.wav",
	")gorefast/gorefast_idle_wet_03.wav",
	")gorefast/gorefast_idle_wet_04.wav",
	")gorefast/gorefast_idle_wet_05.wav",
};

char g_IdleAlertedSounds[][] = {
	")gorefast/gorefast_idle_inhale_creepy_01.wav",
	")gorefast/gorefast_idle_inhale_creepy_02.wav",
	")gorefast/gorefast_idle_alerted_01.wav",
	")gorefast/gorefast_idle_alerted_02.wav",
	")gorefast/gorefast_idle_alerted_03.wav",
};

char g_MeleeHitSounds[][] = {
	")weapons/halloween_boss/knight_axe_hit.wav",
};

char g_MeleeMissSounds[][] = {
	")weapons/demo_sword_hit_world1.wav",
};

public Plugin myinfo = 
{
	name = "[TF2] KF2 Gorefast NPC", 
	author = "Pelipoika", 
	description = "", 
	version = "1.0", 
	url = ""
};

public void OnMapStart()
{
	for (int i = 0; i < (sizeof(g_DeathSounds)); i++)       { PrecacheSound(g_DeathSounds[i]);       }
	for (int i = 0; i < (sizeof(g_HurtSounds)); i++)        { PrecacheSound(g_HurtSounds[i]);        }
	for (int i = 0; i < (sizeof(g_IdleSounds)); i++)        { PrecacheSound(g_IdleSounds[i]);        }
	for (int i = 0; i < (sizeof(g_IdleAlertedSounds)); i++) { PrecacheSound(g_IdleAlertedSounds[i]); }
	for (int i = 0; i < (sizeof(g_MeleeHitSounds)); i++)    { PrecacheSound(g_MeleeHitSounds[i]);    }
	for (int i = 0; i < (sizeof(g_MeleeMissSounds)); i++)   { PrecacheSound(g_MeleeMissSounds[i]);   }

	InitNavGamedata();
}

public void OnPluginStart()
{
	RegAdminCmd("sm_gorefast", Command_PetMenu, ADMFLAG_ROOT);
	
	InitGamedata();
}

methodmap Clot < CClotBody
{
	property int m_iState
	{
		public get()              { return this.ExtractStringValueAsInt("m_iState"); }
		public set(int iActivity) { char buff[8]; IntToString(iActivity, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iState", buff, true); }
	}
	property float m_flNextTargetTime
	{
		public get()                 { return this.ExtractStringValueAsFloat("m_flNextTargetTime"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flNextTargetTime", buff, true); }
	}
	property float m_flNextIdleSound
	{
		public get()                 { return this.ExtractStringValueAsFloat("m_flNextIdleSound"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flNextIdleSound", buff, true); }
	}	
	property float m_flNextHurtSound
	{
		public get()                 { return this.ExtractStringValueAsFloat("m_flNextHurtSound"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flNextHurtSound", buff, true); }
	}
	property float m_flNextBloodSpray
	{
		public get()                 { return this.ExtractStringValueAsFloat("m_flNextBloodSpray"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flNextBloodSpray", buff, true); }
	}
	
	//Stun
	property bool m_bStunned
	{
		public get()            { return !!this.ExtractStringValueAsInt("m_bStunned"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_bStunned", buff, true); }
	}
	property int m_iStunState
	{
		public get()              { return this.ExtractStringValueAsInt("m_iStunState"); }
		public set(int iActivity) { char buff[8]; IntToString(iActivity, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iStunState", buff, true); }
	}
	property float m_flStunEndTime
	{
		public get()                 { return this.ExtractStringValueAsFloat("m_flStunEndTime"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flStunEndTime", buff, true); }
	}
	
	public bool IsDecapitated()
	{
		int nBody = GetEntProp(this.index, Prop_Send, "m_nBody");
		int nNoHeadMask = (GORE_HEADRIGHT | GORE_HEADLEFT | GORE_HEAD);
		
		return ((nBody & nNoHeadMask) == nNoHeadMask);
	}
	
	public void PlayIdleSound() {
		if(this.m_flNextIdleSound > GetGameTime() || this.IsDecapitated())
			return;
		
		EmitSoundToAll(g_IdleSounds[GetRandomInt(0, sizeof(g_IdleSounds) - 1)], this.index, SNDCHAN_STATIC, 100, _, 1.0, GetRandomInt(95, 105));
		this.m_flNextIdleSound = GetGameTime() + GetRandomFloat(3.0, 6.0);
		
		#if defined DEBUG_SOUND
		PrintToServer("CGoreFast::PlayIdleSound()");
		#endif
	}
	
	public void PlayIdleAlertSound() {
		if(this.m_flNextIdleSound > GetGameTime() || this.IsDecapitated())
			return;
		
		EmitSoundToAll(g_IdleAlertedSounds[GetRandomInt(0, sizeof(g_IdleAlertedSounds) - 1)], this.index, SNDCHAN_STATIC, 100, _, 1.0, GetRandomInt(95, 105));
		this.m_flNextIdleSound = GetGameTime() + GetRandomFloat(3.0, 6.0);
		
		#if defined DEBUG_SOUND
		PrintToServer("CGoreFast::PlayIdleAlertSound()");
		#endif
	}
	
	public void PlayHurtSound() {
		if(this.m_flNextHurtSound > GetGameTime() || this.IsDecapitated())
			return;
		
		EmitSoundToAll(g_HurtSounds[GetRandomInt(0, sizeof(g_HurtSounds) - 1)], this.index, SNDCHAN_STATIC, 100, _, 1.0, GetRandomInt(95, 105));
		this.m_flNextHurtSound = GetGameTime() + GetRandomFloat(0.6, 1.6);
		
		#if defined DEBUG_SOUND
		PrintToServer("CGoreFast::PlayHurtSound()");
		#endif
	}
	
	public void PlayDeathSound() {
		if(this.IsDecapitated())
			return;
	
		EmitSoundToAll(g_DeathSounds[GetRandomInt(0, sizeof(g_DeathSounds) - 1)], this.index, SNDCHAN_STATIC, 100, _, 1.0, GetRandomInt(95, 105));
		
		#if defined DEBUG_SOUND
		PrintToServer("CGoreFast::PlayDeathSound()");
		#endif
	}
	
	public void PlayMeleeHitSound() {
		EmitSoundToAll(g_MeleeHitSounds[GetRandomInt(0, sizeof(g_MeleeHitSounds) - 1)], this.index, SNDCHAN_STATIC, 160, _, 1.0, GetRandomInt(95, 105));
		
		#if defined DEBUG_SOUND
		PrintToServer("CClot::PlayMeleeHitSound()");
		#endif
	}

	public void PlayMeleeMissSound() {
		EmitSoundToAll(g_MeleeMissSounds[GetRandomInt(0, sizeof(g_MeleeMissSounds) - 1)], this.index, SNDCHAN_STATIC, 160, _, 1.0, GetRandomInt(95, 105));
		
		#if defined DEBUG_SOUND
		PrintToServer("CGoreFast::PlayMeleeMissSound()");
		#endif
	}
	
	public bool IsAlert() { return this.m_iState == 1; }

	public float GetRunSpeed()      { return this.IsAlert() && !this.IsDecapitated() ? 300.0 : 110.0; }
	public float GetMaxJumpHeight() { return 50.0; }
	public float GetLeadRadius()    { return 500.0; }
	
	public Clot(int client, float vecPos[3], float vecAng[3], const char[] model)
	{
		Clot npc = view_as<Clot>(CBaseActor(vecPos, vecAng, model, "1.0", "200"));
		
		int iActivity = npc.LookupActivity("ACT_MP_STAND_MELEE");
		if(iActivity > 0) npc.StartActivity(iActivity);
		
		npc.CreatePather(18.0, npc.GetMaxJumpHeight(), 1000.0, npc.GetSolidMask(), 48.0, 0.25, 2.0);
		npc.m_flNextTargetTime  = GetGameTime() + GetRandomFloat(1.0, 4.0);
		npc.m_flNextMeleeAttack = npc.m_flNextTargetTime;
		
		SDKHook(npc.index, SDKHook_Think, ClotThink);
		SDKHook(npc.index, SDKHook_TraceAttack, ClotDamaged);
		
		//IDLE
		npc.m_iState = 0;
		npc.m_bStunned = false;
		
		return npc;
	}
	
	public bool DoSwingTrace(Handle &trace)
	{
		// Setup a volume for the melee weapon to be swung - approx size, so all melee behave the same.
		static float vecSwingMins[3]; vecSwingMins = view_as<float>({-48, -48, -48});
		static float vecSwingMaxs[3]; vecSwingMaxs = view_as<float>({48, 48, 48});
	
		// Setup the swing range.
		float vecForward[3], vecRight[3], vecUp[3];
		this.GetVectors(vecForward, vecRight, vecUp);
		
		float vecSwingStart[3]; vecSwingStart = GetAbsOrigin(this.index);
		vecSwingStart[2] += 54.0;
		
		float vecSwingEnd[3];
		vecSwingEnd[0] = vecSwingStart[0] + vecForward[0] * 100;
		vecSwingEnd[1] = vecSwingStart[1] + vecForward[1] * 100;
		vecSwingEnd[2] = vecSwingStart[2] + vecForward[2] * 100;
		
		// See if we hit anything.
		trace = TR_TraceRayFilterEx( vecSwingStart, vecSwingEnd, MASK_SOLID, RayType_EndPoint, FilterBaseActorsAndData, this.index );
		if ( TR_GetFraction(trace) >= 1.0 )
		{
			delete trace;
			trace = TR_TraceHullFilterEx( vecSwingStart, vecSwingEnd, vecSwingMins, vecSwingMaxs, MASK_SOLID, FilterBaseActorsAndData, this.index );
			if ( TR_GetFraction(trace) < 1.0 )
			{
				// This is the point on the actual surface (the hull could have hit space)
				TR_GetEndPosition(vecSwingEnd, trace);	
			}
		}
	
		return ( TR_GetFraction(trace) < 1.0 );
	}
}

//TODO 
//Rewrite
public void ClotThink(int iNPC)
{
	if(GetEntProp(iNPC, Prop_Data, "m_lifeState") == 1)
	{
		SDKUnhook(iNPC, SDKHook_Think, ClotThink);
		SDKUnhook(iNPC, SDKHook_TraceAttack, ClotDamaged);
		
		return;
	}

	Clot npc = view_as<Clot>(iNPC);
	
	//Don't let clients decide the bodygroups :angry:		
	SetEntProp(npc.index, Prop_Send, "m_nBody", GetEntProp(npc.index, Prop_Send, "m_nBody"));
	
	//Think throttling
	if(npc.m_flNextThinkTime > GetGameTime()) {
		return;
	}
	
	npc.m_flNextThinkTime = GetGameTime() + 0.02;
	
	if(npc.IsDecapitated() && npc.m_flNextBloodSpray < GetGameTime())
	{
		npc.DispatchParticleEffect(npc.index, "blood_bread_biting2", NULL_VECTOR, NULL_VECTOR, NULL_VECTOR, npc.FindAttachment("gore_headfrontright"), PATTACH_POINT_FOLLOW, true);
		npc.m_flNextBloodSpray = GetGameTime() + 5.0;
	}
	
	npc.Update();
	
	if(npc.m_bStunned)
	{
		//Begin stun
		if(npc.m_iStunState == -1) 
		{
			int iActivity = npc.LookupActivity("ACT_MP_STUN_BEGIN");
			
			PF_StopPathing(npc.index);
			
			npc.StartActivity(iActivity);
			npc.m_iStunState = 1;
			
			//Stunned effect
			npc.DispatchParticleEffect(npc.index, "conc_stars", NULL_VECTOR, NULL_VECTOR, NULL_VECTOR, npc.FindAttachment("gore_headfrontright"), PATTACH_POINT_FOLLOW, false);
		}
		
		//Stun loop
		if(npc.IsSequenceFinished() && npc.m_iStunState == 1)
		{
			int iActivity = npc.LookupActivity("ACT_MP_STUN_MIDDLE");
		
			npc.StartActivity(iActivity);
			npc.m_iStunState = 2;
		}
		
		//Stun end
		if(npc.m_flStunEndTime - GetGameTime() <= 0.0 && npc.m_iStunState == 2)
		{
			int iActivity = npc.LookupActivity("ACT_MP_STUN_END");
		
			npc.StartActivity(iActivity);
			npc.m_iStunState = 3;
			
			//Clear stunned effect
			npc.DispatchParticleEffect(npc.index, "killstreak_t1_lvl1", NULL_VECTOR, NULL_VECTOR, NULL_VECTOR, npc.FindAttachment("gore_headfrontright"), PATTACH_POINT_FOLLOW, true);
		}
		
		//Stun exit
		//Wait for stun anim to end and start pathing again.
		if(npc.IsSequenceFinished() && npc.m_iStunState == 3)
		{
			npc.m_bStunned = false;
			npc.m_iStunState = -1;
		}
		
		return;
	}
	
	CKnownEntity PrimaryThreat = npc.GetVisionInterface().GetPrimaryKnownThreat();

	if(PrimaryThreat.Address != Address_Null)
	{
		npc.m_iState = 1;
	
		int PrimaryThreatIndex = PrimaryThreat.GetEntity();	
		if(PrimaryThreatIndex <= MaxClients && !IsPlayerAlive(PrimaryThreatIndex))
		{
			//Stop chasing dead target.
			PF_StopPathing(npc.index);
			npc.m_bPathing = false;
		}
		else
		{
			float vecTarget[3]; vecTarget = WorldSpaceCenter(PrimaryThreatIndex);
			
			float flDistanceToTarget = GetVectorDistance(vecTarget, WorldSpaceCenter(npc.index));
			
			//Predict their pos.
			if(flDistanceToTarget < npc.GetLeadRadius()) {
				
				float vPredictedPos[3]; vPredictedPos = PredictSubjectPosition(npc, PrimaryThreatIndex);
				
			/*	int color[4];
				color[0] = 255;
				color[1] = 255;
				color[2] = 0;
				color[3] = 255;
			
				int xd = PrecacheModel("materials/sprites/laserbeam.vmt");
			
				TE_SetupBeamPoints(vPredictedPos, vecTarget, xd, xd, 0, 0, 0.25, 0.5, 0.5, 5, 5.0, color, 30);
				TE_SendToAllInRange(vecTarget, RangeType_Visibility);*/
				
				PF_SetGoalVector(npc.index, vPredictedPos);
			} else {
				PF_SetGoalEntity(npc.index, PrimaryThreatIndex);
			}
			
			//Target close enough to hit
			if(flDistanceToTarget < 100.0 && !npc.IsPlayingGesture("ACT_MP_GESTURE_FLINCH_CHEST"))
			{
				//Look at target so we hit.
				npc.FaceTowards(vecTarget);
				
				//Can we attack right now?
				if(npc.m_flNextMeleeAttack < GetGameTime())
				{
					//Play attack anim
					npc.AddGesture("ACT_MP_ATTACK_Stand_MELEE");
					
					Handle swingTrace;
					if(npc.DoSwingTrace(swingTrace)) 
					{
						int target = TR_GetEntityIndex(swingTrace);	
						
						float vecHit[3];
						TR_GetEndPosition(vecHit, swingTrace);
						
						if(target > 0)
						{
							SDKHooks_TakeDamage(target, npc.index, npc.index, 25.0, DMG_SLASH|DMG_ALWAYSGIB|DMG_BLAST|DMG_CLUB);
							
							//Snare players
							if(target <= MaxClients) {
								TF2_StunPlayer(target, 1.0, 0.75, 1);
							}
							
							// Hit particle
							npc.DispatchParticleEffect(npc.index, "halloween_boss_axe_hit_sparks", vecHit, NULL_VECTOR, NULL_VECTOR);
							
							// Hit sound
							npc.PlayMeleeHitSound();
							
							//Did we kill them?
							int iHealthPost = GetEntProp(target, Prop_Data, "m_iHealth");
							if(iHealthPost <= 0) 
							{
								npc.AddGesture("ACT_MP_GESTURE_VC_FISTBUMP_MELEE");
							}
						} 
						else 
						{
							// Miss
							npc.PlayMeleeMissSound();
							
							// Hit particle if we hit something.
							if(target >= 0) 
							{
								npc.DispatchParticleEffect(npc.index, "halloween_boss_axe_hit_world", vecHit, NULL_VECTOR, NULL_VECTOR);
								npc.DispatchParticleEffect(npc.index, "impact_dirt", vecHit, NULL_VECTOR, NULL_VECTOR);
							}
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
	}
	else
	{
		npc.m_iState = 0;
	}
	
	if(!npc.IsAlert()) {
		npc.PlayIdleSound();
		
		//Roam while idle
		
		//Is it time to pick a new place to go?
		if(npc.m_flNextTargetTime < GetGameTime())
		{
			//Pick a random goal area
			NavArea RandomArea = PickRandomArea();	
			
			if(RandomArea == NavArea_Null) 
				return;
			
			float vecGoal[3]; RandomArea.GetCenter(vecGoal);
			
			if(!PF_IsPathToVectorPossible(iNPC, vecGoal))
				return;
			
			PF_SetGoalVector(iNPC, vecGoal);
			PF_StartPathing(iNPC);
			npc.m_bPathing = true;
			
			//Timeout
			npc.m_flNextTargetTime = GetGameTime() + 10.0;
		}
	} else {
		npc.PlayIdleAlertSound();
	}
	
	//v Handle jumping and running v
	int idealActivity = -1;
	
	if(!npc.m_bJumping)
	{
		if(npc.m_bPathing) {
			if(npc.IsAlert() && !npc.IsDecapitated()) {
				idealActivity = npc.LookupActivity("ACT_MP_RUN_MELEE");
			} else {
				idealActivity = npc.LookupActivity("ACT_MP_CROUCHWALK_MELEE");
			}
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

public Action Command_PetMenu(int client, int argc)
{
	//What are you.
	if(!(client > 0 && client <= MaxClients && IsClientInGame(client)))
		return Plugin_Handled;
	
	float flPos[3], flAng[3];
	GetClientAbsOrigin(client, flPos);
	GetClientAbsAngles(client, flAng);
	
	Clot(client, flPos, flAng, "models/vince_sf_proxy/zed_gorefast/zed_gorefast_01.mdl");
	
	return Plugin_Handled;
}

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
	#if defined DEBUG_ANIMATION
	PrintToServer("IBody_GetActivity");	
	#endif

	DHookSetReturn(hReturn, view_as<Clot>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).GetActivity()); 
	return MRES_Supercede; 
}

public MRESReturn IBody_IsActivity(Address pThis, Handle hReturn, Handle hParams)              
{
	int iActivity = DHookGetParam(hParams, 1);
	
	#if defined DEBUG_ANIMATION
	PrintToServer("IBody_IsActivity %i", iActivity);	
	#endif

	DHookSetReturn(hReturn, view_as<Clot>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).IsActivity(iActivity));
	return MRES_Supercede; 
}

public MRESReturn IBody_StartActivity(Address pThis, Handle hReturn, Handle hParams)             
{ 
	int iActivity = DHookGetParam(hParams, 1);
	int fFlags    = DHookGetParam(hParams, 2);
	
	#if defined DEBUG_ANIMATION
	PrintToServer("IBody_StartActivity %i %i", iActivity, fFlags);	
	#endif
	
	DHookSetReturn(hReturn, view_as<Clot>(SDKCall(g_hGetEntity, SDKCall(g_hGetBot, pThis))).StartActivity(iActivity, fFlags)); 
	
	return MRES_Supercede; 
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
	
	//PrintToServer("ClotDamaged victim %i attacker %i inflictor %i damage %.1f hitbox %i hitgroup %i", victim, attacker, inflictor, damage, hitbox, hitgroup);
	
	Clot npc = view_as<Clot>(victim);
	
	Action result = Plugin_Continue;
	int nBody = GetEntProp(npc.index, Prop_Send, "m_nBody");
	
	//Headshots always crit
	if(hitgroup == HITGROUP_HEAD)
	{
		if(damage > GetEntProp(npc.index, Prop_Data, "m_iHealth"))
		{
			//Remove head on big head ache
			nBody |= (GORE_HEADRIGHT | GORE_HEADLEFT | GORE_HEAD);
		}
		else
		{
			//Randomized brain damage
			switch(GetRandomInt(1, 3))
			{
				case 1:
				{
					if ((nBody & GORE_HEADRIGHT)     != GORE_HEADRIGHT) nBody |= GORE_HEADRIGHT;
					else if ((nBody & GORE_HEADLEFT) != GORE_HEADLEFT)  nBody |= GORE_HEADLEFT;
					else if ((nBody & GORE_HEAD)     != GORE_HEAD)      nBody |= GORE_HEAD;
				}
				case 2:
				{
					if ((nBody & GORE_HEADLEFT)       != GORE_HEADLEFT)  nBody |= GORE_HEADLEFT;
					else if ((nBody & GORE_HEADRIGHT) != GORE_HEADRIGHT) nBody |= GORE_HEADRIGHT;
					else if ((nBody & GORE_HEAD)      != GORE_HEAD)      nBody |= GORE_HEAD;
				}
				case 3: 
				{
					if ((nBody & GORE_HEAD)           != GORE_HEAD)      nBody |= GORE_HEAD;
					else if ((nBody & GORE_HEADLEFT)  != GORE_HEADLEFT)  nBody |= GORE_HEADLEFT;
					else if ((nBody & GORE_HEADRIGHT) != GORE_HEADRIGHT) nBody |= GORE_HEADRIGHT;
				}
			}
		}
		
		//Unless they don't have a head...
		if(!npc.IsDecapitated())
		{
			if(!npc.IsPlayingGesture("ACT_MP_GESTURE_FLINCH_CHEST"))
			{
				npc.AddGesture("ACT_MP_GESTURE_FLINCH_CHEST");
				npc.PlayHurtSound();
			}
			
			npc.DispatchParticleEffect(npc.index, "crit_text", NULL_VECTOR, NULL_VECTOR, NULL_VECTOR, npc.FindAttachment("gore_headfrontright"), PATTACH_POINT_FOLLOW, true);
			damagetype |= DMG_CRIT;
		}
	
		result = Plugin_Changed;
	}
	else
	{
		if(!npc.IsPlayingGesture("ACT_MP_GESTURE_FLINCH_CHEST"))
		{
			npc.AddGesture("ACT_MP_GESTURE_FLINCH_CHEST");
			npc.PlayHurtSound();
		}
	}
	
	SetEntProp(npc.index, Prop_Send, "m_nBody", nBody);
	
	//Percentage of damage taken vs our max health
	float flDamagePercentage = (damage / GetEntProp(npc.index, Prop_Data, "m_iMaxHealth") * 100);
	
	//Critical hits increase the stun chance 2x
	if (damagetype & DMG_CRIT)
		flDamagePercentage *= 2.0;
	
	//I got hit with over 50% of my max health damage
	//Stun chance = percentage of damage vs max health
	if(!npc.m_bStunned && GetRandomFloat(0.0, 100.0) < flDamagePercentage)
	{
		//Off, ouch, owie
		npc.m_bStunned = true;
		npc.m_flStunEndTime = GetGameTime() + GetRandomFloat(5.0, 6.0);
	}

	bool bIsKnownAttacker = (npc.GetVisionInterface().GetKnown(attacker).Address != Address_Null);
	
	if(!bIsKnownAttacker)
	{
		npc.GetVisionInterface().AddKnownEntity(attacker);
	}
	
	return result;
}

stock float[] PredictSubjectPosition(Clot npc, int subject)
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
	float flLeadRadiusSq = npc.GetLeadRadius(); 
	flLeadRadiusSq *= flLeadRadiusSq;
	if ( flRangeSq > flLeadRadiusSq )
		return subjectPos;
	
	// Normalize in place
	float range = SquareRoot( flRangeSq );
	to[0] /= ( range + 0.0001 );	// avoid divide by zero
	to[1] /= ( range + 0.0001 );	// avoid divide by zero
	to[2] /= ( range + 0.0001 );	// avoid divide by zero
	
	// estimate time to reach subject, assuming maximum speed
	float leadTime = 0.5 + ( range / ( npc.GetRunSpeed() + 0.0001 ) );
	
	// estimate amount to lead the subject	
	float SubjectAbsVelocity[3];
	GetEntPropVector(subject, Prop_Data, "m_vecAbsVelocity", SubjectAbsVelocity);
	float lead[3];	
	lead[0] = leadTime * SubjectAbsVelocity[0];
	lead[1] = leadTime * SubjectAbsVelocity[1];
	lead[2] = 0.0;	

	if(GetVectorDotProduct(to, lead) < 0.0)
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
		if (!PF_IsPotentiallyTraversable( npc.index, subjectPos, pathTarget, IMMEDIATELY, fraction))
		{
			// tried to lead through an unwalkable area - clip to walkable space
			pathTarget[0] = subjectPos[0] + fraction * ( pathTarget[0] - subjectPos[0] );
			pathTarget[1] = subjectPos[1] + fraction * ( pathTarget[1] - subjectPos[1] );
			pathTarget[2] = subjectPos[2] + fraction * ( pathTarget[2] - subjectPos[2] );
		}
	}
	
	NavArea leadArea = TheNavMesh.GetNearestNavArea_Vec( pathTarget );
	
	if (leadArea == NavArea_Null || leadArea.GetZ(pathTarget[0], pathTarget[1]) < pathTarget[2] - npc.GetMaxJumpHeight())
	{
		// would fall off a cliff
		return subjectPos;	
	}
	
	return pathTarget;
}
