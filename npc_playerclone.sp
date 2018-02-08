#include <sdktools>
#include <sdkhooks>
#include <CBaseAnimatingOverlay>
#include <dhooks>

#pragma newdecls required

//Animation
Handle g_hResetSequence;
Handle g_hStudioFrameAdvance;
Handle g_hAllocateLayer;

//NextBoat
Handle g_hMyNextBotPointer;
Handle g_hGetLocomotionInterface;

//DHooks
Handle g_hGetStepHeight;

float g_vecLastClonePos[MAXPLAYERS + 1][3];

public Plugin myinfo = 
{
	name = "[TF2] Player Clone",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public Action test(int client, int args)
{
	SDKHook(client, SDKHook_GetMaxHealth, OnPlayerThink);
	
	ReplyToCommand(client, "[SM] Cloning you");
	
	return Plugin_Handled;
}

public void OnPlayerThink(int client)
{
	SpawnClone(client); 
}

stock void SpawnClone(int client)
{
	float pos[3]; GetClientAbsOrigin(client, pos);
	float ang[3]; GetClientAbsAngles(client, ang);
	float flDistance = GetVectorDistance(g_vecLastClonePos[client], pos, true);
	
	if(flDistance < 500)
		return;
	
	char strModel[PLATFORM_MAX_PATH];
	GetEntPropString(client, Prop_Data, "m_ModelName", strModel, PLATFORM_MAX_PATH);
	
	int npc = CreateEntityByName("base_boss");
	DispatchKeyValueVector(npc, "origin", pos);
	DispatchKeyValueVector(npc, "angles", ang);
	DispatchKeyValue(npc, "model", strModel);
	DispatchKeyValue(npc, "modelscale", "1.0");
	DispatchKeyValue(npc, "health", "0");
	DispatchSpawn(npc);
	
	////////////////////////////
	int table = FindStringTable("modelprecache");
	ReadStringTable(table, GetEntProp(GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon"), Prop_Send, "m_iWorldModelIndex"), strModel, PLATFORM_MAX_PATH);  
	
	if(!StrEqual(strModel, ""))
	{	
		int item = CreateEntityByName("prop_dynamic");
		DispatchKeyValue(item, "model", strModel);
		DispatchSpawn(item);
		
		SetEntProp(item, Prop_Send, "m_nSkin", GetEntProp(client, Prop_Send, "m_nSkin"));
		SetEntProp(item, Prop_Send, "m_hOwnerEntity", npc);
		SetEntProp(item, Prop_Send, "m_fEffects", (1 << 0)|(1 << 9));
	
		SetVariantString("!activator");
		AcceptEntityInput(item, "SetParent", npc);
		
		SetVariantString("head");
		AcceptEntityInput(item, "SetParentAttachmentMaintainOffset"); 
	}
	////////////////////////////
	
	//NextBot hack to get it to stay in air
	DHookRaw(g_hGetStepHeight, true, SDKCall(g_hGetLocomotionInterface, SDKCall(g_hMyNextBotPointer, npc)));
	
	SetEntProp(npc, Prop_Data, "m_takedamage", 0);
	
	SetEntityMoveType(npc, MOVETYPE_NONE);
	SetEntityRenderMode(npc, RENDER_NONE);
	
	SetEntProp(npc, Prop_Data, "m_bloodColor", -1); //Don't bleed
	SetEntProp(npc, Prop_Send, "m_nSkin", GetEntProp(client, Prop_Send, "m_nSkin")); //Don't bleed
	SetEntPropEnt(npc, Prop_Data, "m_hOwnerEntity", client);
	SetEntData(npc, FindSendPropInfo("CTFBaseBoss", "m_lastHealthPercentage") + 28, false, 4, true);	//ResolvePlayerCollisions
	
	ActivateEntity(npc);
	
	//Gotta wait a bit
	RequestFrame(SetupAnimations, npc);
	
	g_vecLastClonePos[client] = pos;
}

public void SetupAnimations(int iEntity)
{
	//Allocate 15 layers for max copycat
	for (int i = 0; i <= 12; i++)
		SDKCall(g_hAllocateLayer, iEntity, 0);

	int client = GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity");
	if(client <= 0)
		return;
		
	SDKCall(g_hResetSequence, iEntity, GetEntProp(client, Prop_Send, "m_nSequence"));
		
	CBaseAnimatingOverlay overlayP = CBaseAnimatingOverlay(client);
	CBaseAnimatingOverlay overlay = CBaseAnimatingOverlay(iEntity);
	
	for (int i = 0; i <= 12; i++)
	{
		CAnimationLayer layerP = overlayP.GetLayer(i);
		CAnimationLayer layer = overlay.GetLayer(i);
		
		if(!(layerP.IsActive()))
			continue;
		
		//PrintToServer("%i", i);
		
		layer.Set(m_fFlags, 			layerP.Get(m_fFlags));
		layer.Set(m_bSequenceFinished, 	layerP.Get(m_bSequenceFinished));
		layer.Set(m_bLooping,			layerP.Get(m_bLooping));
		layer.Set(m_nSequence,			layerP.Get(m_nSequence));
		layer.Set(m_flCycle,			layerP.Get(m_flCycle));
		layer.Set(m_flPrevCycle,		layerP.Get(m_flPrevCycle));
		layer.Set(m_flWeight,			layerP.Get(m_flWeight));
		layer.Set(m_flPlaybackRate,		layerP.Get(m_flPlaybackRate));
		layer.Set(m_flBlendIn,			layerP.Get(m_flBlendIn));
		layer.Set(m_flBlendOut,			layerP.Get(m_flBlendOut));
		layer.Set(m_flKillRate, 		0.0);
		layer.Set(m_flKillDelay, 		50000000000.0);
		layer.Set(m_flLayerAnimtime, 	layerP.Get(m_flLayerAnimtime));
		layer.Set(m_flLayerFadeOuttime, layerP.Get(m_flLayerFadeOuttime));
		layer.Set(m_nActivity,			layerP.Get(m_nActivity));
		layer.Set(m_nPriority,			layerP.Get(m_nPriority));
		layer.Set(m_nOrder, 			layerP.Get(m_nOrder));
	}
	
	for (int i = 0; i < 24; i++)
	{
		float flValue = GetEntPropFloat(client, Prop_Send, "m_flPoseParameter", i);
		SetEntPropFloat(iEntity, Prop_Send, "m_flPoseParameter", flValue, i);
	}
	
	//Done
	SetEntityRenderMode(iEntity, RENDER_NORMAL);
	SDKCall(g_hStudioFrameAdvance, iEntity);
	
	SDKHook(iEntity, SDKHook_Think, GroundEntChanged);
	
	SetEntityFlags(iEntity, FL_ONGROUND);
	SetEntPropEnt(iEntity, Prop_Data, "m_hGroundEntity", 0);
}

public void GroundEntChanged(int iEntity)
{
	SetEntityFlags(iEntity, FL_ONGROUND);
	SetEntPropEnt(iEntity, Prop_Data, "m_hGroundEntity", 0);
	
	SetEntPropVector(iEntity, Prop_Data, "m_vecAbsVelocity", NULL_VECTOR);
}

public void OnPluginStart()
{
	RegAdminCmd("sm_clone", test, ADMFLAG_ROOT);
	
	Handle hConf = LoadGameConfigFile("tf2.pets");
	
	//SDKCalls
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseAnimating::StudioFrameAdvance");
	if ((g_hStudioFrameAdvance = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::StudioFrameAdvance offset!"); 	

	//ResetSequence( int nSequence );
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::ResetSequence");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hResetSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::ResetSequence signature!"); 

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x83\xEC\x18\x8B\xC1\x33\xD2", 10);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//priority
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); //return iOpenLayer
	if((g_hAllocateLayer = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimatingOverlay::AllocateLayer");

	//MyNextBotPointer( );
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::MyNextBotPointer");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hMyNextBotPointer = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseEntity::MyNextBotPointer offset!"); 
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBot::GetLocomotionInterface");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hGetLocomotionInterface = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for INextBot::GetLocomotionInterface!");
	

	//DHooks
	//Dumbass base_boss quirk
	g_hGetStepHeight = DHookCreateEx(hConf, "ILocomotion::GetStepHeight", HookType_Raw, ReturnType_Float, ThisPointer_Address, ILocomotion_GetStepHeight);	
	
	delete hConf;
}

public Address GetLocomotionInterface(int index) { return SDKCall(g_hGetLocomotionInterface, SDKCall(g_hMyNextBotPointer, index)); }

public MRESReturn ILocomotion_GetStepHeight(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturn(hReturn, 0.0); return MRES_Supercede; }

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
