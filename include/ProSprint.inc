#if defined _sprint_included
    #endinput
#endif
#define _sprint_included

public SharedPlugin __pl_pro_sprint = 
{
    name = "pro_sprint",
    file = "ProSprint.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_pro_sprint_SetNTVOptional()
{
    MarkNativeAsOptional("ProSprint_SetPlayerStamina");
    MarkNativeAsOptional("ProSprint_GetPlayerMaxStamina");
    MarkNativeAsOptional("ProSprint_SetInfiniteStamina");
    MarkNativeAsOptional("ProSprint_GetInfiniteStamina");
}
#endif


#define DEFAULT_STAMINA 10.0


/**
 * Set the max stamina of a player.
 * 
 * Specify -1 as duration to set the stamina without a timed expiration.
 * 
 * @param client       Client index
 * @param stamina      Amount of total stamina they should have
 * @param duration     Number of seconds they should have the stamina before reverting to default stamina
 */
native void ProSprint_SetPlayerStamina(int client, float stamina, float duration);

/**
 * Returns the maximum amount of stamina the player can have
 * 
 * @param client    Client index
 * @return          Returns the max amount of stamina the player can have
 */
native float ProSprint_GetPlayerMaxStamina(int client);

/**
 * Changes whether stamina will be depleted when sprinting.
 * 
 * @param on    Whether to use stamina or not
 */
native void ProSprint_SetInfiniteStamina(bool on);

/**
 * Returns whether infinite stamina is on or not
 * 
 * @return      Whether infinite stamina is on
 */
native bool ProSprint_GetInfiniteStamina();
