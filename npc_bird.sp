#define GAME_TF2

#include <sdkhooks>

#include <thelpers/thelpers>
#include <dynamic>
#include <PathFollower>
#include <dhooks>

#pragma newdecls required

#define MODEL_CROW    "models/crow.mdl"
#define MODEL_PIGEON  "models/pigeon.mdl"

#define int(%1) view_as<int>(%1)

//SDKCalls
Handle g_hGetSmoothedVelocity;
Handle g_hStudioFrameAdvance;
Handle g_hDispatchAnimEvents;
Handle g_hMyNextBotPointer;
Handle g_hGetLocomotionInterface;
Handle g_hRun;
Handle g_hApproach;
Handle g_hFaceTowards;
Handle g_hResetSequence;
Handle g_hLookupSequence;
Handle g_hStuckMonitor;
Handle g_hSetVelocity;
Handle g_hIsOnGround;

//DHooks
Handle g_hGetStepHeight;
Handle g_hGetGravity;
Handle g_hGetGroundNormal;
Handle g_hShouldCollideWith;

public Plugin myinfo = 
{
	name = "[TF2] NPC Testing",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_bird", Command_FastZombie, ADMFLAG_ROOT);

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
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::LookupSequence");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hLookupSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::LookupSequence signature!"); 
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::GetSmoothedVelocity");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByValue);
	if((g_hGetSmoothedVelocity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for CBaseEntity::GetSmoothedVelocity!");
	
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
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::StuckMonitor");
	if((g_hStuckMonitor = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::StuckMonitor!");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::Approach");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hApproach = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::Approach!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::FaceTowards");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hFaceTowards = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::FaceTowards!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "NextBotGroundLocomotion::SetVelocity");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	if((g_hSetVelocity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for NextBotGroundLocomotion::SetVelocity!");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "NextBotGroundLocomotion::IsOnGround");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if((g_hIsOnGround = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for NextBotGroundLocomotion::IsOnGround!");

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
	
	delete hConf;
}

public void OnMapStart()
{
	PrecacheModel(MODEL_CROW);
	PrecacheModel(MODEL_PIGEON);
}

enum NPCState
{
	ERROR =  0,
	IDLE =   1,
	ROAM =   2,
	SEARCH = 3
}

methodmap Bird
{
	public Bird(float vecPos[3], float vecAng[3])
	{
		CBaseEntity zombie = CBaseEntity.CreateByName("base_boss");
		zombie.KeyValueVector("origin", vecPos);
		zombie.KeyValueVector("angles", vecAng);
		
		switch(GetRandomInt(1, 2))
		{
			case 1: zombie.KeyValue("model", MODEL_CROW);
			case 2: zombie.KeyValue("model", MODEL_PIGEON);
		}
		
		zombie.KeyValue("modelscale", "2");
		zombie.KeyValue("health", "100000");
		zombie.Spawn();
		
		zombie.SetPropFloat(Prop_Send, "m_flPlaybackRate", 1.0);
		
		char strName[64];
		Format(strName, sizeof(strName), "npc_%x", zombie.Ref);
		
		Dynamic brain = Dynamic();
		brain.SetName(strName);
		brain.SetInt("State", int(IDLE));
		brain.SetInt("Target", -1);
		
		return view_as<Bird>(zombie.Index);
	}
	
	public Dynamic GetBrainInterface()
	{
		char strName[64];
		Format(strName, sizeof(strName), "npc_%x", EntIndexToEntRef(int(this)));
		
		return Dynamic.FindByName(strName);
	}
	
	property NPCState State
	{
		public get()
		{
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				return view_as<NPCState>(brain.GetInt("State"));
			}

			return ERROR;
		}
		public set(NPCState state)
		{ 
			Dynamic brain = this.GetBrainInterface();
			if(brain.IsValid)
			{
				brain.SetInt("State", int(state)); 
			}
		}
	}
	
	public void Approach(float x, float y, float z)
	{
		Address pNB =         SDKCall(g_hMyNextBotPointer, this);
		Address pLocomotion = SDKCall(g_hGetLocomotionInterface, pNB);
		
		float flGoal[3];
		flGoal[0] = x;
		flGoal[1] = y;
		flGoal[2] = z;
		
		SDKCall(g_hStuckMonitor, pLocomotion);
		SDKCall(g_hRun,          pLocomotion);
		SDKCall(g_hApproach,     pLocomotion, flGoal, 1.0, 666);

		if(pLocomotion != Address_Null)	
		{
			bool bOnGround = SDKCall(g_hIsOnGround, pLocomotion);
			if(bOnGround)
			{
				SDKCall(g_hFaceTowards,  pLocomotion, flGoal, 666);
			}
		}
	}
	
	public void Update()
	{
		Dynamic brain = this.GetBrainInterface();
		
		if(brain.IsValid)
		{
			int iCurrentTarget = brain.GetInt("Target");
		
			int iTarget = FindNearestEnemy(int(this));
			if(iTarget > 0)
			{
				if(PF_Exists(int(this)) && iTarget != iCurrentTarget)
				{
					brain.SetInt("Target", iTarget);
					PF_SetGoalEntity(int(this), iTarget);
				}
			
				float flZPos[3];
				GetEntPropVector(int(this), Prop_Data, "m_vecOrigin", flZPos);
				float flCPos[3];
				GetClientAbsOrigin(iTarget, flCPos);
				
				float flDistance = GetVectorDistance(flZPos, flCPos);
				
				int iSequence = -1;
				
				Address pNB =         SDKCall(g_hMyNextBotPointer, int(this));
				Address pLocomotion = SDKCall(g_hGetLocomotionInterface, pNB);
				bool bOnGround
				
				if(pLocomotion != Address_Null)	
				{
					bOnGround = SDKCall(g_hIsOnGround, pLocomotion);
					if(bOnGround)
					{
						if (flDistance <= 100.0)
						{
							iSequence = SDKCall(g_hLookupSequence, this, "Idle01");
							
							PF_StopPathing(int(this));
						}
						else if(flDistance <= 300)
						{
							PF_StartPathing(int(this));
						
							iSequence = SDKCall(g_hLookupSequence, this, "Walk");
							
							SetEntDataFloat(int(this), FindSendPropInfo("CTFBaseBoss", "m_lastHealthPercentage") + 8, 35.0, true);
						}
						else
						{
							PF_StartPathing(int(this));
						
							iSequence = SDKCall(g_hLookupSequence, this, "Run");
							
							SetEntDataFloat(int(this), FindSendPropInfo("CTFBaseBoss", "m_lastHealthPercentage") + 8, 150.0, true);
						}
					}
					else
					{
						iSequence = SDKCall(g_hLookupSequence, this, "Fly01");
					}
				}
				
				if(iSequence != -1)
					SDKCall(g_hResetSequence, this, iSequence);
			}
		}
	}
}

public void BirdThink(int iEntity)
{
	CBaseEntity CBird = new CBaseEntity(iEntity);

	Bird bird = view_as<Bird>(iEntity);
	
	SDKCall(g_hStudioFrameAdvance, CBird);
	SDKCall(g_hDispatchAnimEvents, CBird, CBird);
	
	CBird.SetProp(Prop_Data, "m_bSequenceLoops", true);
	
	if(CBird.GetPropFloat(Prop_Send, "m_flCycle") < 0.0) 
		CBird.SetPropFloat(Prop_Send, "m_flCycle", 1.0);
	
	if(CBird.GetPropFloat(Prop_Send, "m_flCycle") >= 1.0) 
		CBird.SetPropFloat(Prop_Send, "m_flCycle", 0.0);
	
	bird.Update();
}

public Action Command_FastZombie(int client, int args)
{
	CBasePlayer player = new CBasePlayer(client);

	float vecPos[3], vecAng[3];
	GetAimPos(client, vecPos);
	player.GetEyeAngles(vecAng);

	int zombie = int(Bird(vecPos, vecAng));
	
	SetEntityFlags(zombie, FL_NOTARGET);
	
	PF_Create(zombie, 18.0, 1.0, 10000.0, MASK_NPCSOLID, 1000.0, 0.50);
	PF_SetGoalEntity(zombie, client);
	PF_StartPathing(zombie);
	
	Address pNB =         SDKCall(g_hMyNextBotPointer, zombie);
	Address pLocomotion = SDKCall(g_hGetLocomotionInterface, pNB);
	if(pLocomotion != Address_Null)	
	{
		DHookRaw(g_hGetStepHeight,     true, pLocomotion);
		DHookRaw(g_hGetGravity,        true, pLocomotion);
		DHookRaw(g_hGetGroundNormal,   true, pLocomotion);
		DHookRaw(g_hShouldCollideWith, true, pLocomotion);
	}
	
	SDKHook(zombie, SDKHook_Think, BirdThink);
	
//	CreateTimer(2.0, velocity, zombie);

	return Plugin_Handled;
}

public Action velocity(Handle timer, int entity)
{
	Address pNB =         SDKCall(g_hMyNextBotPointer, entity);
	Address pLocomotion = SDKCall(g_hGetLocomotionInterface, pNB);
	
	float flPos[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", flPos);
	
	flPos[2] += 10.0;
	
	TeleportEntity(entity, flPos, NULL_VECTOR, NULL_VECTOR);
	
	float flVelocity[3];
	SDKCall(g_hGetSmoothedVelocity, entity, flVelocity);
	
	PrintToChatAll("%f %f %f", flVelocity[0], flVelocity[1], flVelocity[2]);
	
	flVelocity[2] = 100.0;
	
	SDKCall(g_hSetVelocity, pLocomotion, flVelocity);	
}

public void PF_Approach(int entity, float x, float y, float z)
{
	if(entity > MaxClients && entity <= 2048)
	{
		Bird zombie = view_as<Bird>(entity);
		Dynamic brain = zombie.GetBrainInterface();
		
		if(brain.IsValid)
		{
			zombie.Approach(x, y, z);
		}
	}
}

public void OnEntityDestroyed(int entity)
{
	if(entity > MaxClients && entity <= 2048)
	{
		Bird zombie = view_as<Bird>(entity);
		Dynamic brain = zombie.GetBrainInterface();
		
		if(brain.IsValid)
		{
			brain.Dispose();
		}
	}
}

public MRESReturn NextBotGroundLocomotion_GetStepHeight(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, 18.0);
	
	return MRES_Supercede;
}

public MRESReturn NextBotGroundLocomotion_GetGravity(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, 50.0);
	
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
		if(StrEqual(strClass, "base_boss"))
		{
			DHookSetReturn(hReturn, false);
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

stock bool GetAimPos(int client, float vecPos[3])
{
	float StartOrigin[3], Angles[3];
	GetClientEyeAngles(client, Angles);
	GetClientEyePosition(client, StartOrigin);

	Handle TraceRay = TR_TraceRayFilterEx(StartOrigin, Angles, MASK_VISIBLE_AND_NPCS, RayType_Infinite, ExcludeFilter, client);
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

stock int FindNearestEnemy(int iEntity, float flMaxDistance = 999999.0)
{
	float flPos[3];
	GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", flPos);
	
	float flBestDistance = flMaxDistance;
	int iBestTarget = -1;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			float flTPos[3];
			GetClientEyePosition(i, flTPos);
			
			if(PF_Exists(iEntity) && !PF_IsPathToEntityPossible(iEntity, i))
				continue;
			
			float flDistance = GetVectorDistance(flPos, flTPos);
			
			if(flDistance < flBestDistance)
			{
				flBestDistance = flDistance;
				iBestTarget = i;
			}
		}
	}

	return iBestTarget;
}
