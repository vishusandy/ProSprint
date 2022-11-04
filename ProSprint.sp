#include <sourcemod>
#include <ProSprint.inc>

#define MAXTIMERS 2
#define TSFLUX 0
#define TMFLUX 1

/*
    This is just a modified version of the Sprint plugin from: Greyscale
        https://forums.alliedmods.net/showthread.php?p=567905
    
    Why?
        To add natives that can modify the amount of stamina specific players have
*/


new offsSpeed;

Handle cvarSpeed = INVALID_HANDLE;
Handle cvarDeplete = INVALID_HANDLE;
Handle cvarReplenish = INVALID_HANDLE;
Handle cvarIdleReplenish = INVALID_HANDLE;
Handle cvarAccel = INVALID_HANDLE;
Handle cvarDecel = INVALID_HANDLE;

Handle tHandles[MAXPLAYERS+1][MAXTIMERS];

ConVar cvarRoundDelay;

bool inSprint[MAXPLAYERS+1];
float defSpeed[MAXPLAYERS+1];
float pStamina[MAXPLAYERS+1];

bool inf_stamina = false;

bool mFlux[MAXPLAYERS+1];
float fSpeed[MAXPLAYERS+1];

float playerMaxStamina[MAXPLAYERS+1];

public Plugin:myinfo =
{
    name = "Pro Sprint",
    author = "Greyscale, Vishus, Fancy",
    description = "Modified sprint plugin",
    version = "1.0",
    url = "https://github.com/vishusandy/ProSprint"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    RegPluginLibrary("pro_sprint");
    CreateNative("ProSprint_SetPlayerStamina", Native_SetPlayerStamina);
    CreateNative("ProSprint_GetPlayerMaxStamina", Native_GetPlayerMaxStamina);
    CreateNative("ProSprint_SetInfiniteStamina", Native_SetInfiniteStamina);
    CreateNative("ProSprint_GetInfiniteStamina", Native_GetInfiniteStamina);
    return APLRes_Success;
}

public OnPluginStart()
{
    RegConsoleCmd("sprint", Sprint, "Toggles sprinting mode for clients");
    
    offsSpeed=FindSendPropInfo("CBasePlayer","m_flLaggedMovementValue");
    if(offsSpeed==-1)
    {
        SetFailState("Offset \"m_flLaggedMovementValue\" not found!");
    }
    
    HookEvent("round_start", RoundStart);
    HookEvent("player_spawn", PlayerSpawn);
    HookEvent("player_death", PlayerDeath, EventHookMode_Pre);
    
    cvarSpeed = CreateConVar("sprint_speed", "1.5", "Multiplier of player's speed while sprinting");
    cvarDeplete = CreateConVar("sprint_depletion_factor", "0.15", "Control how fast the player loses stamina");
    cvarReplenish = CreateConVar("sprint_replenish_factor", "0.1", "Control how fast the player replenishes stamina while moving");
    cvarIdleReplenish = CreateConVar("sprint_idle_replenish_factor", "0.15", "Control how fast the player replenishes stamina while idle");
    cvarAccel = CreateConVar("sprint_accel_factor", "0.1", "Control how fast the player accelerates into full speed sprint");
    cvarDecel = CreateConVar("sprint_decel_factor", "0.2", "Control how fast the player decelerates to normal speed");
    cvarRoundDelay = FindConVar("mp_round_restart_delay");
    
    AutoExecConfig(true, "sprint");
    
    for(int i=1; i<=MaxClients; i++) {
        playerMaxStamina[i] = DEFAULT_STAMINA;
    }
}

public void OnClientConnected(int client) {
    playerMaxStamina[client] = DEFAULT_STAMINA;
}
public void OnClientDisconnect(int client) {
    playerMaxStamina[client] = DEFAULT_STAMINA;
}

public Action RoundStart(Handle event, const char[] name, bool dontBroadcast) {
    int delay = GetConVarInt(cvarRoundDelay);
    for (int i=1; i<=MaxClients; i++) {
        if(IsClientInGame(i) && !IsFakeClient(i)) {
            CreateTimer(float(delay), RoundStartStamina, i, TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

public Action RoundStartStamina(Handle timer, int client) {
    pStamina[client] = playerMaxStamina[client];
}


public Action:PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new index = GetClientOfUserId(GetEventInt(event, "userid"));
    
    pStamina[index] = playerMaxStamina[index];
    
    inSprint[index] = false;
    mFlux[index] = false;
}

public Action:PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new index = GetClientOfUserId(GetEventInt(event, "userid"));
    
    StopSprint(index);
}

public Action:Sprint(client, args)
{
    if (IsPlayerAlive(client))
    {
        if (inSprint[client])
        {
            StopSprint(client);
        }
        else
        {
            StartSprint(client);
        }
    }
    
    return Plugin_Handled;
}

public Action:FluxStamina(Handle:timer, any:index) {
    if (index) {
        if (IsClientInGame(index) && !IsFakeClient(index)) {
            float stam = playerMaxStamina[index];
            int istam = RoundToFloor(stam);
            int fluxLen = RoundToCeil(stam)*2 + 3;
            char[] fluxBuff = new char[fluxLen];
            if (inSprint[index]) {
                if (IsClientMovingForward(index)) {
                    if(!inf_stamina) {
                        pStamina[index] -= GetConVarFloat(cvarDeplete);
                    }
                    
                    for (new i=1; i<=istam; i++) {
                        if(i <= RoundFloat(pStamina[index]))
                            StrCat(fluxBuff,fluxLen,"I");
                        else
                            StrCat(fluxBuff,fluxLen," ");
                    }
                    PrintHintText(index,"SPRINT Stamina\n\n[%s]",fluxBuff);
                    
                    if (pStamina[index] <= 0.0) {
                        pStamina[index] = 0.0;
                        StopSprint(index);
                    }
                    return;
                } else {
                    tHandles[index][TSFLUX] = INVALID_HANDLE;
                    KillTimer(timer);
                    StopSprint(index);
                    return;
                }
            } else {
                if (IsClientMovingForward(index)) {
                    pStamina[index] += GetConVarFloat(cvarReplenish);
                    for (new i=1; i<=istam; i++) {
                        if(i <= RoundFloat(pStamina[index]))
                            StrCat(fluxBuff,fluxLen,"I");
                        else
                            StrCat(fluxBuff,fluxLen," ");
                    }
                    PrintHintText(index,"SPRINT Stamina\n\n[%s]",fluxBuff);
                } else {
                    new buttons = GetClientButtons(index);
                    if (buttons == 0 || buttons == 4) {
                        pStamina[index] += GetConVarFloat(cvarIdleReplenish);
                        for (new i=1; i<=istam; i++) {
                            if(i <= RoundFloat(pStamina[index]))
                                StrCat(fluxBuff,fluxLen,"I");
                            else
                                StrCat(fluxBuff,fluxLen," ");
                        }
                        PrintHintText(index,"SPRINT Stamina\n\n[%s]",fluxBuff);
                    }
                }
                
                if (pStamina[index] >= stam) {
                    pStamina[index] = stam;
                } else {
                    return;
                }
            }
        }
    }
    
    tHandles[index][TSFLUX] = INVALID_HANDLE;
    KillTimer(timer);
}

public Action:FluxMovement(Handle:timer, any:index)
{
    if (index)
    {
        if (IsClientInGame(index))
        {
            new Float:speed = GetClientSpeed(index);
            if (inSprint[index])
            {
                if (speed < fSpeed[index])
                {
                    speed += GetConVarFloat(cvarAccel);
                    if (speed > fSpeed[index])
                    {
                        speed = fSpeed[index];
                        SetClientSpeed(index, speed);
                    }
                    else
                    {
                        SetClientSpeed(index, speed);
                        return;
                    }
                }
            }
            else
            {
                if (speed > defSpeed[index])
                {
                    speed -= GetConVarFloat(cvarDecel);
                    if (speed < defSpeed[index])
                    {
                        speed = defSpeed[index];
                        SetClientSpeed(index, speed);
                    }
                    else
                    {
                        SetClientSpeed(index, speed);
                        return;
                    }
                }
            }
        }
    }
    
    mFlux[index] = false;
    tHandles[index][TMFLUX] = INVALID_HANDLE;
    KillTimer(timer);
}

StartSprint(client)
{
    if (IsClientMovingForward(client))
    {
        if (!mFlux[client] && pStamina[client] >= 1.5)
        {
            defSpeed[client] = GetClientSpeed(client);
            
            inSprint[client] = true;
            
            new Float:curspeed = GetClientSpeed(client);
            fSpeed[client] = curspeed * GetConVarFloat(cvarSpeed);
            
            if (tHandles[client][TMFLUX] == INVALID_HANDLE)
            {
                mFlux[client] = true;
                tHandles[client][TMFLUX] = CreateTimer(0.1, FluxMovement, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
            }
            
            if (tHandles[client][TSFLUX] == INVALID_HANDLE)
            {
                tHandles[client][TSFLUX] = CreateTimer(0.1, FluxStamina, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
            }
        }
    }
}

StopSprint(client)
{
    inSprint[client] = false;
    
    if (tHandles[client][TSFLUX] == INVALID_HANDLE)
    {
        tHandles[client][TSFLUX] = CreateTimer(0.1, FluxStamina, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
           
    if (tHandles[client][TMFLUX] == INVALID_HANDLE)
    {
        mFlux[client] = true;
        tHandles[client][TMFLUX] = CreateTimer(0.1, FluxMovement, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
}

SetClientSpeed(client, Float:speed)
{
    if (speed < 1.0)
    {
        new Float:curspeed = GetClientSpeed(client);
        SetEntDataFloat(client, offsSpeed, curspeed);
    }
    else
    {
        SetEntDataFloat(client, offsSpeed, speed);
    }
}

Float:GetClientSpeed(client)
{
    return GetEntDataFloat(client, offsSpeed);
}

bool:IsClientMovingForward(client)
{
    new buttons = GetClientButtons(client);
    
    // modified this to allow continue sprinting after shooting as well as when moving backwards/left/right
    return (buttons == 8 || buttons == 520 || buttons == 1032 || buttons & IN_BACK || buttons & (IN_BACK | IN_MOVELEFT) || buttons & (IN_BACK | IN_MOVERIGHT)) || buttons & IN_ATTACK;
}

public int Native_SetInfiniteStamina(Handle plugin, int numParams) {
    bool on = GetNativeCell(1);
    inf_stamina = on;
}

public int Native_GetInfiniteStamina(Handle plugin, int numParams) {
    return inf_stamina;
}

public any Native_GetPlayerMaxStamina(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    return playerMaxStamina[client];
}

public any Native_SetPlayerStamina(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    float stamina = view_as<float>(GetNativeCell(2));
    float duration = view_as<float>(GetNativeCell(3));
    if(client > MAXPLAYERS+1) {
        return;
    }
    
    playerMaxStamina[client] = stamina;
    pStamina[client] = stamina;
    
    if(duration > 0.0) {
        CreateTimer(duration, ResetMaxStamina, client);
        PrintToChat(client, "Stamina set to %.1f for %.1f seconds", stamina, duration);
    }
}


public Action ResetMaxStamina(Handle timer, int client) {
    playerMaxStamina[client] = DEFAULT_STAMINA;
    if(pStamina[client] > DEFAULT_STAMINA) {
        pStamina[client] = DEFAULT_STAMINA;
    }
    PrintToChat(client, "Extra stamina ended");
}


